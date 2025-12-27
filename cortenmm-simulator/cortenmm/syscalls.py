"""
CortenMM System Call Implementation

这个模块实现了基于 CortenMM 的系统调用和缺页异常处理

核心功能：
1. mmap - 延迟分配（Lazy Allocation）
2. Page Fault 处理
3. Copy-on-Write (COW)
4. munmap
"""

from typing import Optional
from .core import Status, PTE, PTEMetadata
from .addrspace import AddrSpace


# ============================================================================
# CortenMM 系统调用实现
# ============================================================================

class CortenMMSystem:
    """
    CortenMM 系统 - 实现系统调用和异常处理
    """

    def __init__(self):
        self.addr_space = AddrSpace()

        # COW 页面的引用计数（pfn -> refcount）
        # 在真实系统中，这应该在 struct page 中
        self.cow_refcounts = {}

    def do_syscall_mmap(self, vaddr: int, length: int, prot: int) -> int:
        """
        mmap 系统调用 - 延迟分配

        CortenMM 的 mmap 实现：
        1. 不立即分配物理页
        2. 只在页表元数据中标记状态为 PrivateAnon
        3. 缺页异常时才真正分配

        这比传统 Linux 更高效：
        - Linux: 分配 VMA 结构，插入红黑树
        - CortenMM: 直接在页表元数据中标记

        Args:
            vaddr: 起始虚拟地址
            length: 长度（字节）
            prot: 保护标志（bit 0: read, bit 1: write, bit 2: exec）

        Returns:
            成功返回 vaddr，失败返回 -1
        """
        # 对齐到页边界
        vaddr = vaddr & ~0xFFF
        vaddr_end = (vaddr + length + 0xFFF) & ~0xFFF

        try:
            # 使用 RCursor 锁定范围
            with self.addr_space.lock(vaddr, vaddr_end) as cursor:
                # 批量标记为 PrivateAnon（延迟分配）
                cursor.mark(Status.PrivateAnon, soft_perm=prot)

            return vaddr
        except Exception as e:
            print(f"mmap failed: {e}")
            return -1

    def do_syscall_munmap(self, vaddr: int, length: int) -> int:
        """
        munmap 系统调用 - 解除映射

        Args:
            vaddr: 起始虚拟地址
            length: 长度（字节）

        Returns:
            成功返回 0，失败返回 -1
        """
        vaddr = vaddr & ~0xFFF
        vaddr_end = (vaddr + length + 0xFFF) & ~0xFFF

        try:
            # 锁定范围（可能需要 deep=True 来处理大范围）
            with self.addr_space.lock(vaddr, vaddr_end) as cursor:
                # 批量解除映射
                cursor.unmap_range()

            return 0
        except Exception as e:
            print(f"munmap failed: {e}")
            return -1

    def handle_page_fault(self, vaddr: int, is_write: bool) -> bool:
        """
        缺页异常处理 - CortenMM 的核心逻辑

        处理流程：
        1. 锁定包含该地址的页表页
        2. 查询元数据状态
        3. 根据状态执行相应操作：
           - PrivateAnon: 分配物理页并建立映射
           - COW + Write: 执行写时复制
           - Mapped + Write: 检查权限
           - Invalid: 返回 SIGSEGV

        这个流程展示了 CortenMM 如何消除 VMA：
        - 传统 Linux: 在 VMA 树中查找区域，再在页表中查找 PTE
        - CortenMM: 直接在页表树中查找，读取元数据即可

        Args:
            vaddr: 发生异常的虚拟地址
            is_write: 是否是写操作

        Returns:
            True if handled, False if should SIGSEGV
        """
        vaddr_page = vaddr & ~0xFFF

        try:
            # 锁定包含该地址的页表页
            with self.addr_space.lock(vaddr_page, vaddr_page + 0x1000) as cursor:
                # 查询状态
                status = cursor.query(vaddr)

                # === 情况 1: PrivateAnon - 延迟分配 ===
                if status == Status.PrivateAnon:
                    # 分配物理页
                    pfn = self.addr_space.allocate_pfn()

                    # 建立映射（可写）
                    cursor.map(vaddr, pfn, writable=True)

                    print(f"Page fault: allocated pfn={hex(pfn)} for vaddr={hex(vaddr)}")
                    return True

                # === 情况 2: COW - 写时复制 ===
                elif status == Status.COW:
                    if not is_write:
                        # 读操作，不需要复制
                        # 但需要确保有映射
                        result = cursor.get_pte_and_metadata(vaddr)
                        if result is None:
                            return False

                        pte, metadata = result
                        if not pte.is_valid():
                            # 建立只读映射（共享物理页）
                            # 这里简化处理，实际应该从 metadata 获取 pfn
                            return False

                        return True
                    else:
                        # 写操作，需要复制
                        return self._handle_cow_write(cursor, vaddr)

                # === 情况 3: Mapped - 权限检查 ===
                elif status == Status.Mapped:
                    result = cursor.get_pte_and_metadata(vaddr)
                    if result is None:
                        return False

                    pte, metadata = result

                    if is_write and not pte.rw:
                        # 写操作但页面只读
                        # 检查软件权限
                        if metadata.soft_perm & 0b010:
                            # 软件层面可写，可能是 COW
                            # （这里简化处理）
                            return False
                        else:
                            # 真的只读，SIGSEGV
                            return False

                    return True

                # === 情况 4: Invalid - SIGSEGV ===
                else:
                    print(f"Page fault: invalid access to {hex(vaddr)}")
                    return False

        except Exception as e:
            print(f"Page fault handler error: {e}")
            return False

    def _handle_cow_write(self, cursor, vaddr: int) -> bool:
        """
        处理 COW 写操作

        流程：
        1. 获取当前 PTE 和元数据
        2. 检查引用计数
        3. 如果 refcount > 1: 分配新页，复制数据，减少旧页引用计数
        4. 如果 refcount == 1: 直接修改权限为可写

        Args:
            cursor: RCursor 对象
            vaddr: 虚拟地址

        Returns:
            True if handled
        """
        result = cursor.get_pte_and_metadata(vaddr)
        if result is None:
            return False

        pte, metadata = result

        if not pte.is_valid():
            return False

        old_pfn = pte.pfn

        # 获取引用计数
        refcount = self.cow_refcounts.get(old_pfn, 1)

        if refcount > 1:
            # === Copy-on-Write ===
            # 分配新的物理页
            new_pfn = self.addr_space.allocate_pfn()

            # 复制数据（在真实系统中需要实际复制内存）
            # 这里只是模拟
            print(f"COW: copied pfn {hex(old_pfn)} -> {hex(new_pfn)} for vaddr {hex(vaddr)}")

            # 更新映射
            cursor.map(vaddr, new_pfn, writable=True)

            # 更新引用计数
            self.cow_refcounts[old_pfn] = refcount - 1
            self.cow_refcounts[new_pfn] = 1

            # 更新状态为 PrivateAnon
            metadata.status = Status.PrivateAnon
            metadata.refcount = 1

        else:
            # === 只有一个引用，直接修改为可写 ===
            pte.rw = True
            metadata.status = Status.PrivateAnon
            metadata.refcount = 1

            print(f"COW: last reference, made writable: vaddr={hex(vaddr)}")

        return True

    def do_fork_cow(self, vaddr: int, length: int) -> bool:
        """
        fork 时的 COW 设置

        将指定范围的页面标记为 COW，增加引用计数

        Args:
            vaddr: 起始地址
            length: 长度

        Returns:
            是否成功
        """
        vaddr = vaddr & ~0xFFF
        vaddr_end = (vaddr + length + 0xFFF) & ~0xFFF

        try:
            with self.addr_space.lock(vaddr, vaddr_end) as cursor:
                # 遍历范围内的所有页面
                current_vaddr = vaddr
                while current_vaddr < vaddr_end:
                    result = cursor.get_pte_and_metadata(current_vaddr)
                    if result is not None:
                        pte, metadata = result

                        if pte.is_valid() and metadata.status == Status.Mapped:
                            # 标记为 COW
                            metadata.status = Status.COW

                            # 设置硬件只读（触发写时异常）
                            pte.rw = False

                            # 增加引用计数
                            pfn = pte.pfn
                            self.cow_refcounts[pfn] = self.cow_refcounts.get(pfn, 1) + 1
                            metadata.refcount = self.cow_refcounts[pfn]

                    current_vaddr += 0x1000

            return True
        except Exception as e:
            print(f"fork COW setup failed: {e}")
            return False


# ============================================================================
# 模块导出
# ============================================================================

__all__ = ['CortenMMSystem']
