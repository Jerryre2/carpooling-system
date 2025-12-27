"""
Traditional Linux Memory Management Mock

这个模块模拟传统 Linux 的内存管理，用于性能对比

关键特征：
1. **全局锁（Global VM Lock）**：
   - 类似 Linux 的 mmap_sem
   - 所有操作都需要获取这个锁
   - 严重限制并发性能

2. **VMA 红黑树**：
   - 维护独立的区域管理结构
   - 需要在 VMA 和页表之间同步

3. **双重簿记（Double Bookkeeping）**：
   - VMA 记录区域信息
   - 页表记录实际映射
   - 两者必须保持一致
"""

import threading
from typing import List, Dict, Optional, Tuple
from dataclasses import dataclass
from enum import Enum


# ============================================================================
# VMA：虚拟内存区域
# ============================================================================

@dataclass
class VMA:
    """
    Virtual Memory Area - 传统 Linux 的核心数据结构

    问题：
    1. 额外的内存开销（每个区域都需要一个 VMA 对象）
    2. 查找开销（需要在红黑树中搜索）
    3. 并发开销（需要全局锁保护）
    """
    start: int  # 起始地址
    end: int    # 结束地址
    prot: int   # 保护标志
    flags: int  # 标志（匿名、文件映射等）

    def contains(self, vaddr: int) -> bool:
        """检查地址是否在此 VMA 中"""
        return self.start <= vaddr < self.end

    def __repr__(self):
        return f"VMA({hex(self.start)}-{hex(self.end)}, prot={self.prot})"


# ============================================================================
# 简化的页表（不需要像 CortenMM 那样复杂）
# ============================================================================

@dataclass
class SimplePTE:
    """简化的页表项"""
    pfn: Optional[int] = None
    present: bool = False
    rw: bool = False

    def clear(self):
        self.pfn = None
        self.present = False
        self.rw = False

    def is_valid(self) -> bool:
        return self.present and self.pfn is not None


# ============================================================================
# LinuxMock：传统 Linux 内存管理模拟
# ============================================================================

class LinuxMock:
    """
    传统 Linux 内存管理的模拟实现

    核心问题：
    1. **全局锁瓶颈**：
       - 所有操作必须串行化
       - 多核无法并行处理不同的地址范围

    2. **双重查找**：
       - 查找 VMA（红黑树搜索）
       - 查找 PTE（页表遍历）

    3. **内存开销**：
       - VMA 结构的额外开销
       - 红黑树节点的额外开销
    """

    def __init__(self):
        # === 全局锁（这是性能瓶颈！）===
        # 类似 Linux 的 mmap_sem（现在是 mmap_lock）
        self.mmap_lock = threading.Lock()

        # === VMA 列表（简化版，实际是红黑树）===
        # 每次查找都需要线性搜索或树搜索
        self.vmas: List[VMA] = []

        # === 页表（简化为字典）===
        # vaddr -> PTE
        self.page_table: Dict[int, SimplePTE] = {}

        # === 物理页分配器 ===
        self.next_pfn = 0x1000
        self.pfn_lock = threading.Lock()

        # === COW 引用计数 ===
        self.cow_refcounts: Dict[int, int] = {}

    def allocate_pfn(self) -> int:
        """分配物理页框号"""
        with self.pfn_lock:
            pfn = self.next_pfn
            self.next_pfn += 1
            return pfn

    def do_mmap(self, vaddr: int, length: int, prot: int) -> int:
        """
        mmap 实现 - 需要全局锁

        与 CortenMM 的对比：
        - CortenMM: 只锁定相关的页表页，O(1) 操作
        - Linux: 获取全局锁，搜索 VMA 树，插入新 VMA，O(log n) 操作
        """
        vaddr = vaddr & ~0xFFF
        vaddr_end = (vaddr + length + 0xFFF) & ~0xFFF

        # === 获取全局锁（瓶颈！）===
        with self.mmap_lock:
            # 检查是否与现有 VMA 重叠（简化版）
            for vma in self.vmas:
                if not (vaddr_end <= vma.start or vaddr >= vma.end):
                    return -1  # 重叠

            # 创建新的 VMA
            new_vma = VMA(start=vaddr, end=vaddr_end, prot=prot, flags=0)
            self.vmas.append(new_vma)

            # 排序 VMA 列表（真实系统用红黑树维护顺序）
            self.vmas.sort(key=lambda v: v.start)

        return vaddr

    def do_munmap(self, vaddr: int, length: int) -> int:
        """
        munmap 实现 - 需要全局锁

        操作步骤：
        1. 获取全局锁
        2. 查找并删除 VMA
        3. 清理页表
        """
        vaddr = vaddr & ~0xFFF
        vaddr_end = (vaddr + length + 0xFFF) & ~0xFFF

        # === 获取全局锁（瓶颈！）===
        with self.mmap_lock:
            # 查找并删除 VMA
            self.vmas = [vma for vma in self.vmas
                         if not (vma.start >= vaddr and vma.end <= vaddr_end)]

            # 清理页表
            current = vaddr
            while current < vaddr_end:
                if current in self.page_table:
                    pte = self.page_table[current]
                    pte.clear()
                    del self.page_table[current]
                current += 0x1000

        return 0

    def handle_page_fault(self, vaddr: int, is_write: bool) -> bool:
        """
        缺页异常处理 - 需要全局锁

        与 CortenMM 的对比：
        - CortenMM: 只锁定相关页表页，其他线程可以并发处理不同地址
        - Linux: 获取全局锁，阻塞所有其他线程
        """
        vaddr_page = vaddr & ~0xFFF

        # === 获取全局锁（瓶颈！）===
        with self.mmap_lock:
            # === 第一步：查找 VMA（双重查找的第一步）===
            vma = None
            for v in self.vmas:
                if v.contains(vaddr):
                    vma = v
                    break

            if vma is None:
                # 无效访问
                return False

            # === 第二步：查找/创建 PTE（双重查找的第二步）===
            if vaddr_page not in self.page_table:
                # 分配物理页
                pfn = self.allocate_pfn()

                # 创建 PTE
                pte = SimplePTE(pfn=pfn, present=True, rw=(vma.prot & 0b010) != 0)
                self.page_table[vaddr_page] = pte

                return True
            else:
                # PTE 已存在
                pte = self.page_table[vaddr_page]

                if is_write and not pte.rw:
                    # 可能是 COW
                    # （简化处理）
                    return False

                return True

    def do_fork_cow(self, vaddr: int, length: int) -> bool:
        """fork 时的 COW 设置"""
        vaddr = vaddr & ~0xFFF
        vaddr_end = (vaddr + length + 0xFFF) & ~0xFFF

        # === 获取全局锁（瓶颈！）===
        with self.mmap_lock:
            current = vaddr
            while current < vaddr_end:
                if current in self.page_table:
                    pte = self.page_table[current]
                    if pte.is_valid():
                        # 设置为只读
                        pte.rw = False

                        # 增加引用计数
                        pfn = pte.pfn
                        self.cow_refcounts[pfn] = self.cow_refcounts.get(pfn, 1) + 1

                current += 0x1000

        return True


# ============================================================================
# 模块导出
# ============================================================================

__all__ = ['LinuxMock', 'VMA']
