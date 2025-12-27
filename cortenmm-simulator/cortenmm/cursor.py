"""
CortenMM Transactional Interface - RCursor

这个模块实现了 CortenMM 的核心编程接口：事务性接口（Transactional Interface）

核心设计理念：
1. **强制事务性**：
   - 所有对地址空间的操作必须通过 RCursor 进行
   - 确保操作的原子性和并发安全性

2. **操作与并发控制解耦**：
   - 传统系统：每个操作内部都要处理加锁逻辑
   - CortenMM：锁由 RCursor 统一管理，操作函数只关注业务逻辑
   - 这简化了代码，减少了死锁风险

3. **自动锁管理**：
   - 使用 Python 的 context manager 自动获取和释放锁
   - with addr_space.lock(...) as cursor: 保证异常安全
"""

import contextlib
from typing import List, Optional, Tuple, Set
from .core import (
    Status, PTE, PTEMetadata, PageDescriptor, PageTablePage,
    PTES_PER_PAGE, parse_vaddr, make_vaddr
)


# ============================================================================
# RCursor：事务性游标
# ============================================================================

class RCursor:
    """
    Range Cursor - 事务性游标

    RCursor 是 CortenMM 中所有操作的入口点。它提供：

    1. **锁管理**：
       - 持有一组页表页的锁
       - 在 __exit__ 时自动释放所有锁

    2. **原子性操作**：
       - query: 查询地址状态
       - map: 建立映射
       - mark: 批量标记状态（延迟分配）
       - unmap: 解除映射

    3. **安全保障**：
       - 所有操作都在锁保护下进行
       - 防止并发修改导致的不一致
    """

    def __init__(self, vaddr_start: int, vaddr_end: int):
        """
        初始化 RCursor

        Args:
            vaddr_start: 范围起始地址（包含）
            vaddr_end: 范围结束地址（不包含）
        """
        self.vaddr_start = vaddr_start
        self.vaddr_end = vaddr_end

        # 持有的锁（页表页 -> 锁对象）
        self.locked_pages: List[Tuple[PageTablePage, PageDescriptor]] = []

        # 是否已经释放
        self._released = False

    def add_locked_page(self, pt_page: PageTablePage):
        """
        添加一个已锁定的页表页

        Args:
            pt_page: 页表页对象
        """
        self.locked_pages.append((pt_page, pt_page.descriptor))

    def query(self, vaddr: int) -> Status:
        """
        查询指定虚拟地址的状态

        这个操作展示了 CortenMM 如何消除 VMA：
        - 传统 Linux：需要在 VMA 红黑树中搜索该地址属于哪个区域
        - CortenMM：直接遍历页表树，读取 PageDescriptor 中的状态

        Args:
            vaddr: 虚拟地址

        Returns:
            该地址的状态（Invalid, Mapped, PrivateAnon, COW 等）
        """
        assert self.vaddr_start <= vaddr < self.vaddr_end, \
            f"Address {hex(vaddr)} out of cursor range"

        # 遍历已锁定的页表页，找到覆盖该地址的叶子页表
        for pt_page, _ in self.locked_pages:
            if pt_page.is_leaf():
                # 解析地址，提取页表索引
                indices = parse_vaddr(vaddr)
                pte_index = indices[-1]  # 叶子页表的索引

                # 读取元数据
                metadata = pt_page.get_metadata(pte_index)
                return metadata.status

        # 如果没有找到，说明该地址范围未被锁定
        return Status.Invalid

    def map(self, vaddr: int, pfn: int, writable: bool = True):
        """
        在 RCursor 保护下建立硬件映射并更新元数据

        这个操作展示了软硬件状态的同步更新：
        1. 更新硬件 PTE（pfn, present, rw）
        2. 更新软件元数据（status = Mapped）
        3. 两者在同一个锁保护下，保证一致性

        Args:
            vaddr: 虚拟地址
            pfn: 物理页框号
            writable: 是否可写
        """
        assert self.vaddr_start <= vaddr < self.vaddr_end

        # 找到对应的叶子页表
        for pt_page, descriptor in self.locked_pages:
            if pt_page.is_leaf():
                indices = parse_vaddr(vaddr)
                pte_index = indices[-1]

                # 更新硬件 PTE
                pte = pt_page.get_pte(pte_index)
                pte.pfn = pfn
                pte.present = True
                pte.rw = writable
                pte.user = True

                # 更新软件元数据
                metadata = pt_page.get_metadata(pte_index)
                metadata.status = Status.Mapped
                metadata.soft_perm = 0b111 if writable else 0b101  # RWX or R-X

                # 增加描述符版本号
                descriptor.increment_version()
                return

        raise RuntimeError(f"No leaf page table locked for address {hex(vaddr)}")

    def mark(self, status: Status, soft_perm: int = 0b111):
        """
        批量标记指定范围的元数据

        这是 CortenMM 实现延迟分配（Lazy Allocation）的关键：
        - 不立即分配物理页（不修改 PTE）
        - 只在元数据中标记状态（例如 PrivateAnon）
        - 缺页异常时再真正分配物理页

        这比传统 Linux 的 VMA 方式更高效：
        - Linux：在 VMA 树中插入一个区域
        - CortenMM：直接在页表元数据中标记

        Args:
            status: 要设置的状态
            soft_perm: 软件权限
        """
        # 遍历范围内的所有地址
        vaddr = self.vaddr_start
        while vaddr < self.vaddr_end:
            for pt_page, descriptor in self.locked_pages:
                if pt_page.is_leaf():
                    indices = parse_vaddr(vaddr)
                    pte_index = indices[-1]

                    # 只更新元数据，不修改硬件 PTE
                    metadata = pt_page.get_metadata(pte_index)
                    metadata.status = status
                    metadata.soft_perm = soft_perm

                    # 增加版本号
                    descriptor.increment_version()

            vaddr += 4096  # 移动到下一页

    def unmap(self, vaddr: int):
        """
        解除映射并清理元数据

        操作步骤：
        1. 清除硬件 PTE（模拟 TLB flush）
        2. 重置软件元数据为 Invalid
        3. 增加版本号

        Args:
            vaddr: 要解除映射的虚拟地址
        """
        assert self.vaddr_start <= vaddr < self.vaddr_end

        for pt_page, descriptor in self.locked_pages:
            if pt_page.is_leaf():
                indices = parse_vaddr(vaddr)
                pte_index = indices[-1]

                # 清除硬件 PTE
                pte = pt_page.get_pte(pte_index)
                pte.clear()

                # 重置元数据
                metadata = pt_page.get_metadata(pte_index)
                metadata.status = Status.Invalid
                metadata.soft_perm = 0
                metadata.refcount = 0

                # 增加版本号
                descriptor.increment_version()
                return

        raise RuntimeError(f"No leaf page table locked for address {hex(vaddr)}")

    def unmap_range(self):
        """
        解除整个范围的映射

        批量 unmap 操作，用于 munmap 系统调用
        """
        vaddr = self.vaddr_start
        while vaddr < self.vaddr_end:
            # 尝试 unmap，如果地址无效则跳过
            try:
                for pt_page, descriptor in self.locked_pages:
                    if pt_page.is_leaf():
                        indices = parse_vaddr(vaddr)
                        pte_index = indices[-1]

                        # 检查是否有效
                        metadata = pt_page.get_metadata(pte_index)
                        if metadata.status != Status.Invalid:
                            # 清除 PTE 和元数据
                            pte = pt_page.get_pte(pte_index)
                            pte.clear()
                            metadata.status = Status.Invalid
                            metadata.soft_perm = 0
                            metadata.refcount = 0
                            descriptor.increment_version()
                        break
            except:
                pass

            vaddr += 4096

    def get_pte_and_metadata(self, vaddr: int) -> Optional[Tuple[PTE, PTEMetadata]]:
        """
        获取指定地址的 PTE 和元数据（用于高级操作）

        Args:
            vaddr: 虚拟地址

        Returns:
            (PTE, PTEMetadata) 或 None
        """
        assert self.vaddr_start <= vaddr < self.vaddr_end

        for pt_page, _ in self.locked_pages:
            if pt_page.is_leaf():
                indices = parse_vaddr(vaddr)
                pte_index = indices[-1]
                pte = pt_page.get_pte(pte_index)
                metadata = pt_page.get_metadata(pte_index)
                return (pte, metadata)

        return None

    def release(self):
        """
        释放所有持有的锁

        这个方法由 context manager 的 __exit__ 自动调用
        """
        if self._released:
            return

        # 按相反顺序释放锁（避免死锁）
        for pt_page, descriptor in reversed(self.locked_pages):
            descriptor.lock.release()

        self.locked_pages.clear()
        self._released = True

    def __enter__(self):
        """Context manager 入口"""
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        """Context manager 出口 - 自动释放锁"""
        self.release()
        return False  # 不抑制异常

    def __repr__(self):
        return f"RCursor({hex(self.vaddr_start)}-{hex(self.vaddr_end)}, " \
               f"locked={len(self.locked_pages)})"


# ============================================================================
# 模块导出
# ============================================================================

__all__ = ['RCursor']
