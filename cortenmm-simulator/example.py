#!/usr/bin/env python3
"""
CortenMM 使用示例

展示如何使用 CortenMM 系统进行基本的内存操作
"""

import sys
import os
sys.path.insert(0, os.path.dirname(__file__))

from cortenmm import CortenMMSystem, Status


def example_basic_operations():
    """
    示例 1: 基本操作 - mmap, page fault, munmap
    """
    print("="*70)
    print("示例 1: 基本内存操作")
    print("="*70)

    # 创建 CortenMM 系统实例
    system = CortenMMSystem()

    # === mmap: 分配虚拟内存 ===
    print("\n1. mmap: 分配 4KB 虚拟内存")
    vaddr = 0x10000
    length = 0x1000  # 4KB
    result = system.do_syscall_mmap(vaddr, length, prot=0b111)  # RWX

    if result != -1:
        print(f"   ✓ mmap 成功: vaddr={hex(vaddr)}, length={hex(length)}")
    else:
        print(f"   ✗ mmap 失败")
        return

    # === Page Fault: 首次访问触发缺页异常 ===
    print("\n2. Page Fault: 首次访问触发缺页异常")
    print(f"   访问地址: {hex(vaddr)}")

    if system.handle_page_fault(vaddr, is_write=True):
        print(f"   ✓ 缺页异常处理成功，物理页已分配")
    else:
        print(f"   ✗ 缺页异常处理失败")

    # === 查询状态 ===
    print("\n3. 查询内存状态")
    with system.addr_space.lock(vaddr, vaddr + 0x1000) as cursor:
        status = cursor.query(vaddr)
        print(f"   地址 {hex(vaddr)} 的状态: {status}")

    # === munmap: 释放内存 ===
    print("\n4. munmap: 释放内存")
    result = system.do_syscall_munmap(vaddr, length)

    if result == 0:
        print(f"   ✓ munmap 成功")
    else:
        print(f"   ✗ munmap 失败")

    print("\n" + "="*70 + "\n")


def example_cow():
    """
    示例 2: Copy-on-Write (COW)
    """
    print("="*70)
    print("示例 2: Copy-on-Write (COW)")
    print("="*70)

    system = CortenMMSystem()

    # === 1. 分配并映射内存 ===
    print("\n1. 分配并映射内存")
    vaddr = 0x20000
    system.do_syscall_mmap(vaddr, 0x1000, prot=0b111)
    system.handle_page_fault(vaddr, is_write=True)

    print(f"   ✓ 内存已分配: {hex(vaddr)}")

    # 获取原始 PFN
    with system.addr_space.lock(vaddr, vaddr + 0x1000) as cursor:
        result = cursor.get_pte_and_metadata(vaddr)
        if result:
            pte, metadata = result
            original_pfn = pte.pfn
            print(f"   物理页框号 (PFN): {hex(original_pfn)}")

    # === 2. 设置为 COW ===
    print("\n2. 模拟 fork() - 设置为 COW")
    system.do_fork_cow(vaddr, 0x1000)

    with system.addr_space.lock(vaddr, vaddr + 0x1000) as cursor:
        status = cursor.query(vaddr)
        result = cursor.get_pte_and_metadata(vaddr)
        if result:
            pte, metadata = result
            print(f"   状态: {status}")
            print(f"   PTE.rw: {pte.rw} (已设置为只读)")
            print(f"   引用计数: {metadata.refcount}")

    # === 3. 写操作触发 COW ===
    print("\n3. 写操作触发 COW")
    system.handle_page_fault(vaddr, is_write=True)

    with system.addr_space.lock(vaddr, vaddr + 0x1000) as cursor:
        result = cursor.get_pte_and_metadata(vaddr)
        if result:
            pte, metadata = result
            new_pfn = pte.pfn
            print(f"   ✓ COW 完成")
            print(f"   原始 PFN: {hex(original_pfn)}")
            print(f"   新 PFN: {hex(new_pfn)}")
            print(f"   PTE.rw: {pte.rw} (已恢复可写)")

    print("\n" + "="*70 + "\n")


def example_concurrent_access():
    """
    示例 3: 并发访问演示
    """
    import threading

    print("="*70)
    print("示例 3: 并发访问不同地址范围")
    print("="*70)

    system = CortenMMSystem()

    def worker(thread_id, base_addr, num_pages):
        """工作线程：分配和访问内存"""
        print(f"\n[线程 {thread_id}] 开始工作")

        # 分配内存
        vaddr = base_addr
        length = num_pages * 0x1000
        system.do_syscall_mmap(vaddr, length, prot=0b111)

        # 触发缺页异常
        for i in range(num_pages):
            addr = vaddr + (i * 0x1000)
            system.handle_page_fault(addr, is_write=True)

        print(f"[线程 {thread_id}] 完成: 分配并访问了 {num_pages} 个页面")

    # 创建多个线程，操作不同的地址范围
    threads = []
    for i in range(4):
        base_addr = 0x100000 + (i * 0x100000)  # 每个线程 1MB 地址空间
        t = threading.Thread(target=worker, args=(i, base_addr, 10))
        threads.append(t)

    print("\n启动 4 个线程，并发操作不同的地址范围...")

    # 启动所有线程
    for t in threads:
        t.start()

    # 等待所有线程完成
    for t in threads:
        t.join()

    print("\n✓ 所有线程完成！")
    print("  这展示了 CortenMM 的细粒度锁如何支持真正的并发")
    print("  传统 Linux 的全局锁会强制这些操作串行化")

    print("\n" + "="*70 + "\n")


def example_lazy_allocation():
    """
    示例 4: 延迟分配（Lazy Allocation）
    """
    print("="*70)
    print("示例 4: 延迟分配（Lazy Allocation）")
    print("="*70)

    system = CortenMMSystem()

    vaddr = 0x50000
    length = 0x10000  # 64KB

    # === 1. mmap 不分配物理页 ===
    print("\n1. mmap 64KB 内存（延迟分配）")
    system.do_syscall_mmap(vaddr, length, prot=0b111)

    with system.addr_space.lock(vaddr, vaddr + 0x1000) as cursor:
        status = cursor.query(vaddr)
        result = cursor.get_pte_and_metadata(vaddr)

        print(f"   状态: {status}")
        if result:
            pte, metadata = result
            print(f"   PTE.present: {pte.present} (物理页尚未分配)")

    # === 2. 只访问其中几页 ===
    print("\n2. 访问其中 3 个页面")
    pages_to_access = [0, 5, 10]

    for page_offset in pages_to_access:
        addr = vaddr + (page_offset * 0x1000)
        system.handle_page_fault(addr, is_write=True)
        print(f"   ✓ 页面 {page_offset} ({hex(addr)}) 已分配物理内存")

    # === 3. 验证其他页面仍未分配 ===
    print("\n3. 验证其他页面仍未分配物理内存")
    with system.addr_space.lock(vaddr + 0x3000, vaddr + 0x4000) as cursor:
        result = cursor.get_pte_and_metadata(vaddr + 0x3000)
        if result:
            pte, metadata = result
            print(f"   页面 3 ({hex(vaddr + 0x3000)})")
            print(f"   状态: {metadata.status}")
            print(f"   PTE.present: {pte.present} (仍未分配)")

    print("\n   这就是延迟分配的优势：")
    print("   - mmap 1GB 内存，实际只使用 1MB")
    print("   - CortenMM 只分配真正访问的页面")

    print("\n" + "="*70 + "\n")


def main():
    """
    运行所有示例
    """
    print("\n")
    print("*" * 70)
    print(" " * 15 + "CortenMM 系统使用示例")
    print("*" * 70)
    print("\n")

    try:
        example_basic_operations()
        example_cow()
        example_concurrent_access()
        example_lazy_allocation()

        print("\n" + "*" * 70)
        print(" " * 20 + "所有示例运行完成！")
        print("*" * 70)
        print("\n提示：运行 'python visualize.py' 查看性能对比测试\n")

    except Exception as e:
        print(f"\n错误: {e}")
        import traceback
        traceback.print_exc()


if __name__ == '__main__':
    main()
