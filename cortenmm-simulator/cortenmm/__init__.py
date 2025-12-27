"""
CortenMM Simulator

Python 模拟器实现 SOSP '25 论文：
"CortenMM: Efficient Memory Management with Strong Correctness Guarantees"

核心组件：
- core: 核心数据结构（PTE, PageDescriptor, PageTablePage）
- cursor: 事务性接口（RCursor）
- addrspace: 地址空间管理和高级锁协议
- syscalls: 系统调用实现（mmap, munmap, page fault, COW）
"""

from .core import (
    Status,
    PTE,
    PTEMetadata,
    PageDescriptor,
    PageTablePage,
    PTES_PER_PAGE,
    PAGE_SIZE,
    parse_vaddr,
    make_vaddr
)

from .cursor import RCursor

from .addrspace import AddrSpace, RCUReclaimer

from .syscalls import CortenMMSystem

__version__ = '1.0.0'

__all__ = [
    # Core data structures
    'Status',
    'PTE',
    'PTEMetadata',
    'PageDescriptor',
    'PageTablePage',
    'PTES_PER_PAGE',
    'PAGE_SIZE',
    'parse_vaddr',
    'make_vaddr',

    # Transactional interface
    'RCursor',

    # Address space management
    'AddrSpace',
    'RCUReclaimer',

    # System interface
    'CortenMMSystem',
]
