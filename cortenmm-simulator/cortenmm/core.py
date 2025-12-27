"""
CortenMM Core Data Structures

这个模块实现了 CortenMM 的核心数据结构，体现了"无 VMA"的设计理念。

核心设计思想：
1. **单层抽象（Single-Level Abstraction）**：
   - 移除传统 Linux 的 VMA（Virtual Memory Area）红黑树结构
   - 所有内存状态直接存储在与硬件页表绑定的元数据中
   - 不需要在用户空间维护一个独立的区域管理数据结构

2. **为什么不需要红黑树（VMA）**：
   - 传统 Linux 使用 VMA 红黑树来跟踪内存区域（文件映射、匿名内存等）
   - 这导致了双重簿记（double bookkeeping）：VMA 和页表都存储状态
   - CortenMM 将所有状态直接存储在页表的元数据中，消除了冗余
   - 查询内存状态时，直接遍历页表树即可，无需额外的树结构

3. **PageDescriptor 作为软硬件桥梁**：
   - 硬件页表（PTE）只存储物理地址和基本标志位
   - PageDescriptor 存储软件需要的额外信息（状态、权限、引用计数等）
   - 两者通过结构绑定，保证同步更新
"""

import threading
from enum import Enum
from typing import Optional, List
from dataclasses import dataclass, field


# ============================================================================
# 常量定义
# ============================================================================

# 每个页表页包含 512 个条目（4KB 页面，每个 PTE 8 字节）
PTES_PER_PAGE = 512

# 页面大小（4KB）
PAGE_SIZE = 4096


# ============================================================================
# 枚举类型：内存状态
# ============================================================================

class Status(Enum):
    """
    内存条目的状态枚举

    这些状态完全在软件层面维护，硬件页表只知道 Present/Not-Present
    CortenMM 通过 PageDescriptor 将这些状态与硬件 PTE 关联
    """

    # 无效状态：该地址范围未被使用
    Invalid = "Invalid"

    # 已映射：存在有效的硬件映射（PTE.Present = 1）
    Mapped = "Mapped"

    # 私有匿名页：已分配但可能未映射（延迟分配）
    PrivateAnon = "PrivateAnon"

    # 写时复制：多个进程共享，写入时需要复制
    COW = "COW"

    # 文件映射（可扩展）
    FileMapped = "FileMapped"


# ============================================================================
# PTE：模拟硬件页表条目
# ============================================================================

@dataclass
class PTE:
    """
    Page Table Entry - 模拟硬件页表条目

    这是硬件层面的数据结构，只包含 CPU 需要的信息：
    - pfn: 物理页框号（Physical Frame Number）
    - flags: 硬件标志位（Present, RW, User, etc.）

    注意：硬件不知道这个页面是 COW 还是 PrivateAnon，
    这些信息存储在 PageDescriptor 的元数据中
    """

    pfn: Optional[int] = None  # 物理页框号，None 表示未映射
    present: bool = False       # Present bit：是否存在物理映射
    rw: bool = False           # Read/Write bit：是否可写
    user: bool = True          # User bit：用户态是否可访问
    accessed: bool = False     # Accessed bit：是否被访问过
    dirty: bool = False        # Dirty bit：是否被写入过

    def clear(self):
        """清除 PTE，模拟 unmap 操作"""
        self.pfn = None
        self.present = False
        self.rw = False
        self.accessed = False
        self.dirty = False

    def is_valid(self) -> bool:
        """检查 PTE 是否有效"""
        return self.present and self.pfn is not None

    def __repr__(self):
        if not self.present:
            return "PTE(Not-Present)"
        flags = []
        if self.rw:
            flags.append("RW")
        if self.user:
            flags.append("U")
        if self.dirty:
            flags.append("D")
        return f"PTE(pfn={self.pfn}, {'/'.join(flags)})"


# ============================================================================
# PTEMetadata：每个 PTE 的软件元数据
# ============================================================================

@dataclass
class PTEMetadata:
    """
    每个 PTE 的软件元数据

    这是 CortenMM 的关键创新：将软件状态直接与硬件 PTE 绑定
    而不是在一个独立的 VMA 树中维护
    """

    # 软件状态（Invalid, Mapped, PrivateAnon, COW 等）
    status: Status = Status.Invalid

    # 软件权限（可能与硬件权限不同，例如 COW 页在软件层面可写）
    soft_perm: int = 0  # bit 0: read, bit 1: write, bit 2: exec

    # 引用计数（用于 COW）
    refcount: int = 0

    # 文件映射相关（可扩展）
    file_offset: Optional[int] = None

    def __repr__(self):
        perm = []
        if self.soft_perm & 1:
            perm.append("R")
        if self.soft_perm & 2:
            perm.append("W")
        if self.soft_perm & 4:
            perm.append("X")
        perm_str = ''.join(perm) if perm else "---"
        return f"Meta(status={self.status.value}, perm={perm_str}, ref={self.refcount})"


# ============================================================================
# PageDescriptor：页表页的元数据描述符
# ============================================================================

class PageDescriptor:
    """
    页表页的元数据描述符

    这是 CortenMM 中"软硬件桥梁"的核心组件：

    1. **锁机制**：
       - 每个 PageDescriptor 有自己的锁，实现细粒度并发控制
       - 对比传统 Linux 的全局 mmap_sem，这大大提高了并发性能

    2. **元数据存储**：
       - 为这个页表页中的每个 PTE 维护软件元数据
       - 包括状态、权限、引用计数等硬件不关心的信息

    3. **版本控制**（用于 RCU）：
       - is_stale 标志用于 RCU 式的延迟释放
       - 当页表页被删除时，先标记 stale，等待宽限期后再回收
    """

    def __init__(self):
        # 细粒度锁：只保护这一个页表页
        self.lock = threading.Lock()

        # 每个 PTE 的元数据（512 个）
        self.per_pte_metadata: List[PTEMetadata] = [
            PTEMetadata() for _ in range(PTES_PER_PAGE)
        ]

        # RCU 延迟释放标志
        self.is_stale = False

        # 版本号（用于调试和验证）
        self.version = 0

    def mark_stale(self):
        """标记为过时，准备进入 RCU 宽限期"""
        self.is_stale = True

    def increment_version(self):
        """增加版本号（用于检测并发修改）"""
        self.version += 1

    def __repr__(self):
        valid_count = sum(1 for m in self.per_pte_metadata if m.status != Status.Invalid)
        return f"PageDesc(valid={valid_count}/{PTES_PER_PAGE}, stale={self.is_stale}, v{self.version})"


# ============================================================================
# PageTablePage：页表页
# ============================================================================

class PageTablePage:
    """
    页表页 - 模拟一个硬件页表页

    结构设计：
    1. **硬件部分**（ptes）：
       - 512 个 PTE 条目，这是 CPU/MMU 实际读取的内容

    2. **软件部分**（descriptor）：
       - 关联的 PageDescriptor，包含所有软件元数据
       - CPU 看不到这些信息，只有 OS 使用

    3. **多级页表支持**：
       - children: 子页表页（模拟多级页表树）
       - level: 当前页表的级别（0=PTE, 1=PMD, 2=PUD, 3=PGD）

    为什么这样设计能消除 VMA：
    - 传统系统：VMA 树记录"[0x1000-0x2000) 是匿名内存，可读写"
    - CortenMM：直接在页表树中查找 0x1000，读取其 PageDescriptor 即可
    - 结果：不需要额外的数据结构来记录内存区域
    """

    def __init__(self, level: int = 0):
        # 硬件 PTE 数组
        self.ptes: List[PTE] = [PTE() for _ in range(PTES_PER_PAGE)]

        # 关联的软件元数据描述符
        self.descriptor = PageDescriptor()

        # 子页表（用于多级页表）
        # children[i] 是 ptes[i] 指向的下一级页表
        self.children: List[Optional['PageTablePage']] = [None] * PTES_PER_PAGE

        # 页表级别：0=叶子(PTE), 1=PMD, 2=PUD, 3=PGD
        self.level = level

    def is_leaf(self) -> bool:
        """是否是叶子页表（直接映射物理页）"""
        return self.level == 0

    def get_pte(self, index: int) -> PTE:
        """获取指定索引的 PTE"""
        assert 0 <= index < PTES_PER_PAGE
        return self.ptes[index]

    def get_metadata(self, index: int) -> PTEMetadata:
        """获取指定索引的元数据"""
        assert 0 <= index < PTES_PER_PAGE
        return self.descriptor.per_pte_metadata[index]

    def get_child(self, index: int) -> Optional['PageTablePage']:
        """获取子页表"""
        assert 0 <= index < PTES_PER_PAGE
        return self.children[index]

    def set_child(self, index: int, child: Optional['PageTablePage']):
        """设置子页表"""
        assert 0 <= index < PTES_PER_PAGE
        self.children[index] = child

    def __repr__(self):
        return f"PTPage(level={self.level}, {self.descriptor})"


# ============================================================================
# 辅助函数：虚拟地址解析
# ============================================================================

def parse_vaddr(vaddr: int, levels: int = 4) -> List[int]:
    """
    解析虚拟地址为页表索引

    假设 4 级页表，每级 9 bits（512 条目）
    vaddr: [63:48 unused] [47:39 L3] [38:30 L2] [29:21 L1] [20:12 L0] [11:0 offset]

    Args:
        vaddr: 虚拟地址
        levels: 页表级数（默认 4）

    Returns:
        索引列表，从高到低 [L3_idx, L2_idx, L1_idx, L0_idx]
    """
    indices = []
    # 去掉页内偏移（低 12 bits）
    vpn = vaddr >> 12

    # 提取每级索引（每级 9 bits）
    for _ in range(levels):
        indices.append(vpn & 0x1FF)  # 取低 9 bits
        vpn >>= 9

    # 反转，使其从高级到低级
    return list(reversed(indices))


def make_vaddr(indices: List[int], offset: int = 0) -> int:
    """
    从页表索引构造虚拟地址

    Args:
        indices: [L3_idx, L2_idx, L1_idx, L0_idx]
        offset: 页内偏移

    Returns:
        虚拟地址
    """
    vaddr = 0
    for idx in indices:
        vaddr = (vaddr << 9) | idx
    vaddr = (vaddr << 12) | offset
    return vaddr


# ============================================================================
# 模块导出
# ============================================================================

__all__ = [
    'Status',
    'PTE',
    'PTEMetadata',
    'PageDescriptor',
    'PageTablePage',
    'PTES_PER_PAGE',
    'PAGE_SIZE',
    'parse_vaddr',
    'make_vaddr',
]
