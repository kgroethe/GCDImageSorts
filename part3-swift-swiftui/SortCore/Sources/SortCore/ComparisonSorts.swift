//
//  ComparisonSorts.swift
//  SortCore
//
//  Swift ports of the remaining algorithms from the original PThreadSorts set.
//  Kept deliberately plain: the point of Part 3 is the migration, so these read
//  the way the textbook versions read and let the benchmark do the arguing.
//

import Foundation

// MARK: - Quicksort

public struct QuickSort: PixelSorter {
    public static let name = "QuickSort"
    public static let bigO = "O(n log n)"
    /// Below this a partition is finished with insertion sort, which wins on
    /// small runs because it has almost no bookkeeping.
    static let insertionCutoff = 24

    public init() {}

    public func sort(_ p: UnsafeMutableBufferPointer<UInt32>, cancel: SortCancel?) -> SortStats {
        var stats = SortStats()
        guard p.count > 1 else { return stats }
        Self.quick(p, 0, p.count - 1, &stats)
        return stats
    }

    static func medianOfThree(_ p: UnsafeMutableBufferPointer<UInt32>,
                              _ lo: Int, _ hi: Int, _ s: inout SortStats) -> UInt32 {
        let mid = lo + (hi - lo) / 2
        s.comparisons &+= 3
        let a = p[lo], b = p[mid], c = p[hi]
        return Swift.max(Swift.min(a, b), Swift.min(Swift.max(a, b), c))
    }

    static func quick(_ p: UnsafeMutableBufferPointer<UInt32>,
                      _ low: Int, _ high: Int, _ s: inout SortStats) {
        var lo = low, hi = high
        while lo < hi {
            if hi - lo + 1 <= insertionCutoff {
                insertion(p, lo, hi, &s)
                return
            }
            let pivot = medianOfThree(p, lo, hi, &s)
            var i = lo, j = hi
            while i <= j {
                while p[i] < pivot { i += 1; s.comparisons &+= 1 }
                while p[j] > pivot { j -= 1; s.comparisons &+= 1 }
                s.comparisons &+= 2
                if i <= j {
                    if i != j { p.swapAt(i, j); s.swaps &+= 1 }
                    i += 1; j -= 1
                }
            }
            // recurse into the smaller side, loop on the larger: bounds stack depth
            if j - lo < hi - i {
                quick(p, lo, j, &s); lo = i
            } else {
                quick(p, i, hi, &s); hi = j
            }
        }
    }

    static func insertion(_ p: UnsafeMutableBufferPointer<UInt32>,
                          _ lo: Int, _ hi: Int, _ s: inout SortStats,
                          _ cancel: SortCancel? = nil) {
        guard hi > lo else { return }
        for i in (lo + 1) ... hi {
            if cancel?.isCancelled == true { return }
            let v = p[i]
            var j = i - 1
            while j >= lo {
                s.comparisons &+= 1
                if p[j] <= v { break }
                p[j + 1] = p[j]; j -= 1; s.swaps &+= 1
            }
            p[j + 1] = v
        }
    }
}

/// Quicksort with the top partitions handed to GCD, mirroring the
/// GCDQuickSortPicture from Part 1.
/// Quicksort with the top partitions handed to GCD, mirroring the
/// GCDQuickSortPicture from Part 1.
public struct ParallelQuickSort: PixelSorter {
    public static let name = "GCD QuickSort"
    public static let bigO = "O(n log n / p)"
    /// Partitions smaller than this are not worth a dispatch.
    static let parallelCutoff = 32_768

    public init() {}

    /// Shared counters. Workers own disjoint ranges of the buffer, so the lock
    /// guards only the statistics, never the pixels.
    private final class Accumulator: @unchecked Sendable {
        private let lock = NSLock()
        private(set) var stats = SortStats()
        func add(_ s: SortStats) {
            lock.lock()
            stats.swaps &+= s.swaps
            stats.comparisons &+= s.comparisons
            lock.unlock()
        }
    }

    private static func run(_ px: UnsafeMutableBufferPointer<UInt32>,
                            _ lo: Int, _ hi: Int,
                            _ group: DispatchGroup, _ acc: Accumulator) {
        if lo >= hi { return }
        if hi - lo + 1 < parallelCutoff {
            var local = SortStats()
            QuickSort.quick(px, lo, hi, &local)
            acc.add(local)
            return
        }
        var local = SortStats()
        let pivot = QuickSort.medianOfThree(px, lo, hi, &local)
        var i = lo, j = hi
        while i <= j {
            while px[i] < pivot { i += 1; local.comparisons &+= 1 }
            while px[j] > pivot { j -= 1; local.comparisons &+= 1 }
            local.comparisons &+= 2
            if i <= j {
                if i != j { px.swapAt(i, j); local.swaps &+= 1 }
                i += 1; j -= 1
            }
        }
        acc.add(local)

        nonisolated(unsafe) let buf = px
        let l0 = lo, l1 = j
        group.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            run(buf, l0, l1, group, acc)
            group.leave()
        }
        run(px, i, hi, group, acc)
    }

    public func sort(_ p: UnsafeMutableBufferPointer<UInt32>, cancel: SortCancel?) -> SortStats {
        guard p.count > 1 else { return SortStats() }
        let group = DispatchGroup()
        let acc = Accumulator()
        Self.run(p, 0, p.count - 1, group, acc)
        group.wait()
        return acc.stats
    }
}

// MARK: - The rest of the original set

public struct HeapSort: PixelSorter {
    public static let name = "Heap Sort"
    public static let bigO = "O(n log n)"
    public init() {}

    public func sort(_ p: UnsafeMutableBufferPointer<UInt32>, cancel: SortCancel?) -> SortStats {
        var s = SortStats()
        let n = p.count
        guard n > 1 else { return s }

        func siftDown(_ start: Int, _ end: Int) {
            var root = start
            while root * 2 + 1 <= end {
                let child = root * 2 + 1
                var swapIdx = root
                s.comparisons &+= 1
                if p[swapIdx] < p[child] { swapIdx = child }
                if child + 1 <= end {
                    s.comparisons &+= 1
                    if p[swapIdx] < p[child + 1] { swapIdx = child + 1 }
                }
                if swapIdx == root { return }
                p.swapAt(root, swapIdx); s.swaps &+= 1
                root = swapIdx
            }
        }

        for start in stride(from: n / 2 - 1, through: 0, by: -1) { siftDown(start, n - 1) }
        for end in stride(from: n - 1, to: 0, by: -1) {
            if cancel?.isCancelled == true { return s }
            p.swapAt(0, end); s.swaps &+= 1
            siftDown(0, end - 1)
        }
        return s
    }
}

public struct MergeSort: PixelSorter {
    public static let name = "Merge Sort"
    public static let bigO = "O(n log n)"
    public init() {}

    public func sort(_ p: UnsafeMutableBufferPointer<UInt32>, cancel: SortCancel?) -> SortStats {
        var s = SortStats()
        let n = p.count
        guard n > 1 else { return s }
        var scratch = [UInt32](repeating: 0, count: n)

        scratch.withUnsafeMutableBufferPointer { tmp in
            // bottom up, so there is no recursion to pay for
            var width = 1
            while width < n {
                if cancel?.isCancelled == true { return }
                var i = 0
                while i < n {
                    let mid = Swift.min(i + width, n)
                    let end = Swift.min(i + 2 * width, n)
                    var l = i, r = mid, k = i
                    while l < mid && r < end {
                        s.comparisons &+= 1
                        if p[l] <= p[r] { tmp[k] = p[l]; l += 1 } else { tmp[k] = p[r]; r += 1; s.swaps &+= 1 }
                        k += 1
                    }
                    while l < mid { tmp[k] = p[l]; l += 1; k += 1 }
                    while r < end { tmp[k] = p[r]; r += 1; k += 1 }
                    i += 2 * width
                }
                p.baseAddress!.update(from: tmp.baseAddress!, count: n)
                width *= 2
            }
        }
        return s
    }
}

public struct ShellSort: PixelSorter {
    public static let name = "Shell Sort"
    public static let bigO = "O(n^1.25)"
    public init() {}

    public func sort(_ p: UnsafeMutableBufferPointer<UInt32>, cancel: SortCancel?) -> SortStats {
        var s = SortStats()
        let n = p.count
        guard n > 1 else { return s }
        // Ciura's gaps, extended by the usual 2.25 factor
        var gaps = [701, 301, 132, 57, 23, 10, 4, 1]
        var g = 701
        while g < n / 2 { g = Int(Double(g) * 2.25); gaps.insert(g, at: 0) }

        for gap in gaps where gap < n {
            if cancel?.isCancelled == true { return s }
            for i in gap ..< n {
                let v = p[i]
                var j = i
                while j >= gap {
                    s.comparisons &+= 1
                    if p[j - gap] <= v { break }
                    p[j] = p[j - gap]; j -= gap; s.swaps &+= 1
                }
                p[j] = v
            }
        }
        return s
    }
}

public struct InsertionSort: PixelSorter {
    public static let name = "Insertion Sort"
    public static let bigO = "O(n²)"
    public init() {}

    public func sort(_ p: UnsafeMutableBufferPointer<UInt32>, cancel: SortCancel?) -> SortStats {
        var s = SortStats()
        guard p.count > 1 else { return s }
        QuickSort.insertion(p, 0, p.count - 1, &s, cancel)
        return s
    }
}

public struct SelectionSort: PixelSorter {
    public static let name = "Selection Sort"
    public static let bigO = "O(n²)"
    public init() {}

    public func sort(_ p: UnsafeMutableBufferPointer<UInt32>, cancel: SortCancel?) -> SortStats {
        var s = SortStats()
        let n = p.count
        guard n > 1 else { return s }
        for i in 0 ..< n - 1 {
            if cancel?.isCancelled == true { return s }
            var m = i
            for j in (i + 1) ..< n {
                s.comparisons &+= 1
                if p[j] < p[m] { m = j }
            }
            if m != i { p.swapAt(i, m); s.swaps &+= 1 }
        }
        return s
    }
}
