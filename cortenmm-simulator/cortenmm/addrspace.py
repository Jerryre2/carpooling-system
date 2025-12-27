"""
CortenMM Address Space Management with Advanced Locking Protocol

这个模块实现了：
1. 地址空间（AddrSpace）的基本管理
2. CortenMM_adv 高级锁协议（RCU 风格的无锁遍历）
3. Lock & Validate 机制

核心算法复现（对应论文 Figure 6）：
- Traverse Phase: 无锁 RCU 遍历找到覆盖页表页
- Locking Phase: 获取锁并验证节点是否 stale
- DFS Locking: 递归锁定子树
- RCU Grace Period: 延迟释放被删除的页表页
"""

import contextlib
import threading
import time
from typing import List, Optional, Set
from collections import deque

from .core import (
    Status, PTE, PTEMetadata, PageDescriptor, PageTablePage,
    PTES_PER_PAGE, parse_vaddr, make_vaddr
)
from .cursor import RCursor


# ============================================================================
# RCU 回收队列
# ============================================================================

class RCUReclaimer:
    """
    RCU 回收器 - 模拟 RCU 宽限期（Grace Period）

    当页表页被删除时，不能立即释放，因为可能有其他线程正在无锁遍历：
    1. 先标记为 stale
    2. 放入回收队列
    3. 等待宽限期（模拟：等待所有读者退出）
    4. 真正释放内存

    这防止了 Use-After-Free 问题
    """

    def __init__(self):
        self.queue = deque()
        self.lock = threading.Lock()

    def defer_free(self, pt_page: PageTablePage):
        """
        延迟释放页表页

        Args:
            pt_page: 要释放的页表页
        """
        with self.lock:
            # 标记为 stale
            pt_page.descriptor.mark_stale()

            # 记录释放时间
            self.queue.append((time.time(), pt_page))

    def try_reclaim(self, grace_period: float = 0.001):
        """
        尝试回收超过宽限期的页表页

        Args:
            grace_period: 宽限期（秒）
        """
        with self.lock:
            now = time.time()
            while self.queue:
                timestamp, pt_page = self.queue[0]
                if now - timestamp >= grace_period:
                    # 超过宽限期，可以安全回收
                    self.queue.popleft()
                    # 在 Python 中，让 GC 自动回收即可
                    # 这里可以添加统计信息
                else:
                    # 队列是按时间排序的，后面的还没到期
                    break


# ============================================================================
# AddrSpace：地址空间
# ============================================================================

class AddrSpace:
    """
    地址空间 - CortenMM 的顶层接口

    设计要点：
    1. **无 VMA**：
       - 不维护红黑树或任何区域列表
       - 所有状态存储在页表树的 PageDescriptor 中

    2. **多级页表**：
       - 4 级页表（PGD -> PUD -> PMD -> PTE）
       - 按需分配（页表页在需要时才创建）

    3. **细粒度锁**：
       - 每个页表页有独立的锁
       - 支持高并发访问不同的地址范围
    """

    def __init__(self, levels: int = 4):
        """
        初始化地址空间

        Args:
            levels: 页表级数（默认 4 级）
        """
        # 根页表（PGD）
        self.root = PageTablePage(level=levels - 1)

        # 页表级数
        self.levels = levels

        # RCU 回收器
        self.rcu_reclaimer = RCUReclaimer()

        # 全局锁（用于结构性修改，如创建新页表页）
        # 注意：这个锁只用于树结构修改，不保护数据访问
        self.structure_lock = threading.Lock()

        # 物理页分配器（简单的计数器）
        self.next_pfn = 0x1000  # 从 0x1000 开始分配
        self.pfn_lock = threading.Lock()

    def allocate_pfn(self) -> int:
        """
        分配一个物理页框号

        Returns:
            物理页框号
        """
        with self.pfn_lock:
            pfn = self.next_pfn
            self.next_pfn += 1
            return pfn

    def _traverse_rcu(self, vaddr: int) -> Optional[PageTablePage]:
        """
        RCU 风格的无锁遍历 - 找到覆盖指定地址的叶子页表页

        这是 CortenMM_adv 的核心算法第一步：Traverse Phase

        关键特性：
        1. **无锁读取**：
           - 不获取任何锁
           - 依赖 Python 的单条指令原子性（对象引用读取）

        2. **Stale 检测**：
           - 读取过程中不检查 stale（允许读到旧数据）
           - 只在锁定后才验证

        3. **可能的结果**：
           - 找到有效的页表页（需要后续验证）
           - 返回 None（地址未映射）
           - 读到 stale 节点（后续验证会发现）

        Args:
            vaddr: 虚拟地址

        Returns:
            叶子页表页或 None
        """
        indices = parse_vaddr(vaddr, self.levels)
        current = self.root

        # 从根开始向下遍历，不加锁
        for i, index in enumerate(indices[:-1]):
            # 读取子页表（可能读到旧值或新值）
            child = current.get_child(index)

            if child is None:
                # 页表页不存在
                return None

            # 继续向下（不检查 stale）
            current = child

        # 返回找到的叶子页表（可能是 stale 的）
        return current

    def _lock_and_validate(self, pt_page: PageTablePage) -> bool:
        """
        Lock & Validate - 获取锁并验证节点是否有效

        这是 CortenMM_adv 的核心算法第二步：Locking Phase

        为什么需要验证：
        - 在无锁遍历和获取锁之间，节点可能被其他线程删除
        - 删除操作会标记节点为 stale
        - 我们必须检测这种情况，否则会读到无效数据

        验证失败的处理：
        - 释放锁
        - 返回 False，调用者应该重试整个流程

        Args:
            pt_page: 要锁定的页表页

        Returns:
            True if valid, False if stale (需要重试)
        """
        # 获取锁
        pt_page.descriptor.lock.acquire()

        # 检查是否在我们获取锁之前被标记为 stale
        if pt_page.descriptor.is_stale:
            # 节点已过时，释放锁并返回失败
            pt_page.descriptor.lock.release()
            return False

        # 节点有效，保持锁定状态
        return True

    def _dfs_lock_subtree(self, pt_page: PageTablePage, locked_pages: List[PageTablePage]):
        """
        DFS 锁定子树 - 递归锁定所有后代页表页

        用途：
        - 当操作需要修改整个子树时（例如 munmap 大范围）
        - 必须原子地锁定所有相关页表页，防止并发修改

        锁定顺序：
        - 深度优先，从上到下
        - 这个顺序很重要，可以避免死锁

        Args:
            pt_page: 根页表页（已锁定）
            locked_pages: 已锁定页表页列表（输出参数）
        """
        locked_pages.append(pt_page)

        # 如果是叶子节点，直接返回
        if pt_page.is_leaf():
            return

        # 遍历所有子节点
        for i in range(PTES_PER_PAGE):
            child = pt_page.get_child(i)
            if child is not None:
                # 锁定子节点
                if self._lock_and_validate(child):
                    # 递归锁定子树
                    self._dfs_lock_subtree(child, locked_pages)
                else:
                    # 子节点 stale，这不应该发生（父节点已锁定）
                    # 在真实系统中这里应该恐慌
                    raise RuntimeError("Unexpected stale child while parent is locked")

    @contextlib.contextmanager
    def lock(self, vaddr_start: int, vaddr_end: int, deep: bool = False):
        """
        锁定地址范围并返回 RCursor

        这是 CortenMM 的核心 API，使用 context manager 确保锁自动释放

        完整流程（CortenMM_adv 算法）：
        1. **Traverse Phase**（无锁）：
           - 找到覆盖地址范围的页表页

        2. **Lock & Validate**：
           - 获取页表页的锁
           - 验证节点是否 stale
           - 如果 stale，释放锁并重试

        3. **DFS Locking**（可选）：
           - 如果 deep=True，递归锁定子树

        4. **返回 RCursor**：
           - RCursor 持有所有锁
           - 在 __exit__ 时自动释放

        Args:
            vaddr_start: 起始地址
            vaddr_end: 结束地址
            deep: 是否深度锁定子树

        Yields:
            RCursor 对象

        示例：
            with addr_space.lock(0x1000, 0x2000) as cursor:
                status = cursor.query(0x1000)
                cursor.map(0x1000, pfn=0x5000)
        """
        # 确保地址对齐
        vaddr_start = vaddr_start & ~0xFFF
        vaddr_end = (vaddr_end + 0xFFF) & ~0xFFF

        # 重试循环（处理 stale 情况）
        max_retries = 10
        for retry in range(max_retries):
            # === Traverse Phase（无锁）===
            # 简化版本：只处理单个页表页
            # 真实系统需要找到覆盖整个范围的所有页表页
            pt_page = self._ensure_leaf_page(vaddr_start)

            if pt_page is None:
                # 页表页不存在，需要创建
                pt_page = self._create_leaf_page(vaddr_start)

            # === Lock & Validate ===
            if not self._lock_and_validate(pt_page):
                # 节点 stale，重试
                continue

            # === DFS Locking（可选）===
            locked_pages = []
            if deep:
                try:
                    self._dfs_lock_subtree(pt_page, locked_pages)
                except:
                    # 锁定失败，释放所有已获取的锁
                    for page in locked_pages:
                        page.descriptor.lock.release()
                    continue
            else:
                locked_pages = [pt_page]

            # === 创建并返回 RCursor ===
            cursor = RCursor(vaddr_start, vaddr_end)
            for page in locked_pages:
                cursor.add_locked_page(page)

            try:
                yield cursor
            finally:
                # 确保释放所有锁
                cursor.release()
                # 尝试回收 stale 节点
                self.rcu_reclaimer.try_reclaim()

            return

        # 重试次数耗尽
        raise RuntimeError(f"Failed to lock address range after {max_retries} retries")

    def _ensure_leaf_page(self, vaddr: int) -> Optional[PageTablePage]:
        """
        确保叶子页表页存在（不创建）

        Args:
            vaddr: 虚拟地址

        Returns:
            叶子页表页或 None
        """
        indices = parse_vaddr(vaddr, self.levels)
        current = self.root

        for i, index in enumerate(indices[:-1]):
            child = current.get_child(index)
            if child is None:
                return None
            current = child

        return current

    def _create_leaf_page(self, vaddr: int) -> PageTablePage:
        """
        创建叶子页表页（按需分配）

        这需要获取结构锁，因为涉及树的修改

        Args:
            vaddr: 虚拟地址

        Returns:
            新创建的叶子页表页
        """
        with self.structure_lock:
            indices = parse_vaddr(vaddr, self.levels)
            current = self.root

            # 从根开始，确保路径上所有节点都存在
            for i, index in enumerate(indices[:-1]):
                child = current.get_child(index)
                if child is None:
                    # 创建新的页表页
                    new_level = self.levels - 2 - i
                    child = PageTablePage(level=new_level)
                    current.set_child(index, child)
                current = child

            return current

    def remove_page_table(self, vaddr: int):
        """
        删除页表页（模拟 munmap 导致的页表收缩）

        删除流程：
        1. 找到页表页
        2. 锁定它
        3. 标记为 stale
        4. 从父节点断开链接
        5. 放入 RCU 回收队列

        Args:
            vaddr: 要删除的地址
        """
        with self.structure_lock:
            indices = parse_vaddr(vaddr, self.levels)
            parent = self.root

            # 找到父节点和目标节点
            for i, index in enumerate(indices[:-2]):
                child = parent.get_child(index)
                if child is None:
                    return  # 不存在
                parent = child

            # 获取目标节点
            target_index = indices[-2]
            target = parent.get_child(target_index)

            if target is not None:
                # 锁定目标节点
                target.descriptor.lock.acquire()

                # 从父节点断开
                parent.set_child(target_index, None)

                # 释放锁
                target.descriptor.lock.release()

                # 延迟释放
                self.rcu_reclaimer.defer_free(target)

    def __repr__(self):
        return f"AddrSpace(levels={self.levels}, root={self.root})"


# ============================================================================
# 模块导出
# ============================================================================

__all__ = ['AddrSpace', 'RCUReclaimer']
