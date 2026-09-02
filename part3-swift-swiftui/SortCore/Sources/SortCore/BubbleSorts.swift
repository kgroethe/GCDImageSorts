//
//  BubbleSorts.swift
//  SortCore
//
//  Swift ports of the bubble sort variants from Part 2, in the same order they
//  were built there, so each step can be timed against its Objective-C++
//  counterpart. Part 2 finished at 15.89 s for 307K pixels (366.0 s -> 23.0x).
//  Whether Swift can hold that without arm_neon.h is the open question, and it
//  is answered by measuring, not by asserting.
//

import Foundation

/// The starting point: textbook bubble sort, branch per comparison.
public struct NaiveBubbleSort: PixelSorter {
    public static let name = "Bubble Sort"
    public static let bigO = "O(n²)"
    public init() {}

    public func sort(_ p: UnsafeMutableBufferPointer<UInt32>, cancel: SortCancel?) -> SortStats {
        var stats = SortStats()
        let n = p.count
        guard n > 1 else { return stats }
        var end = n - 1
        while end > 0 {
            if cancel?.isCancelled == true { return stats }
            var lastSwap = 0
            for i in 0 ..< end {
                stats.comparisons &+= 1
                if p[i] > p[i + 1] {
                    p.swapAt(i, i + 1)
                    stats.swaps &+= 1
                    lastSwap = i
                }
            }
            end = lastSwap          // skip the tail already known to be sorted
        }
        return stats
    }
}

/// No branch in the inner loop: min/max lower to conditional selects.
public struct BranchlessBubbleSort: PixelSorter {
    public static let name = "Branchless Bubble Sort"
    public static let bigO = "O(n²)"
    public init() {}

    public func sort(_ p: UnsafeMutableBufferPointer<UInt32>, cancel: SortCancel?) -> SortStats {
        var stats = SortStats()
        let n = p.count
        guard n > 1 else { return stats }
        for pass in 0 ..< (n - 1) {
            if cancel?.isCancelled == true { return stats }
            var dirty = false
            for i in 0 ..< (n - 1 - pass) {
                let a = p[i], b = p[i + 1]
                let lo = Swift.min(a, b), hi = Swift.max(a, b)
                p[i] = lo; p[i + 1] = hi
                stats.comparisons &+= 1
                if lo != a { stats.swaps &+= 1; dirty = true }
            }
            if !dirty { break }
        }
        return stats
    }
}

/// Odd-even transposition, the shape that parallelises: within a phase every
/// pair is independent, so blocks can run concurrently without locking.
public struct ParallelOddEvenSort: PixelSorter {
    public static let name = "Parallel Odd-Even Bubble Sort"
    public static let bigO = "O(n²/p)"
    public let chunks: Int

    public init(chunks: Int = ProcessInfo.processInfo.activeProcessorCount) {
        self.chunks = Swift.max(1, chunks)
    }

    public func sort(_ p: UnsafeMutableBufferPointer<UInt32>, cancel: SortCancel?) -> SortStats {
        var stats = SortStats()
        let n = p.count
        guard n > 1 else { return stats }

        // One slot per chunk rather than an atomic: each worker owns its slot,
        // so the phase needs no synchronisation at all.
        let flags = UnsafeMutableBufferPointer<UInt8>.allocate(capacity: chunks)
        let swapCounts = UnsafeMutableBufferPointer<UInt64>.allocate(capacity: chunks)
        defer { flags.deallocate(); swapCounts.deallocate() }

        var rounds = 0
        while rounds < n {
            if cancel?.isCancelled == true { return stats }
            var movedThisRound = false
            for phase in 0 ..< 2 {
                flags.initialize(repeating: 0)
                swapCounts.initialize(repeating: 0)
                let pairs = (n - phase) / 2
                guard pairs > 0 else { continue }
                let per = (pairs + chunks - 1) / chunks

                // Swift 6 will not let a buffer pointer cross into a @Sendable
                // closure on its own. Each worker touches a disjoint range of
                // pairs and its own flag slot, so the sharing is safe and is
                // asserted here rather than worked around with a lock.
                nonisolated(unsafe) let px = p.baseAddress!
                nonisolated(unsafe) let flagsBase = flags.baseAddress!
                nonisolated(unsafe) let swapsBase = swapCounts.baseAddress!

                DispatchQueue.concurrentPerform(iterations: chunks) { c in
                    let lo = c * per
                    let hi = Swift.min(pairs, lo + per)
                    guard lo < hi else { return }
                    var moved: UInt8 = 0
                    var swaps: UInt64 = 0
                    for k in lo ..< hi {
                        let i = phase + 2 * k
                        let a = px[i], b = px[i + 1]
                        let mn = Swift.min(a, b), mx = Swift.max(a, b)
                        px[i] = mn; px[i + 1] = mx
                        if mn != a { swaps &+= 1; moved = 1 }
                    }
                    flagsBase[c] = moved
                    swapsBase[c] = swaps
                }

                stats.comparisons &+= UInt64(pairs)
                for c in 0 ..< chunks {
                    stats.swaps &+= swapCounts[c]
                    if flags[c] == 1 { movedThisRound = true }
                }
            }
            if !movedThisRound { break }
            rounds += 1
        }
        return stats
    }
}

/// Odd-even again, but four pairs at a time through Swift's SIMD types.
///
/// Swift has no arm_neon.h, so there is no vcgtq_u32/vbslq_u32 to call directly.
/// pointwiseMin/pointwiseMax are the closest equivalent and should lower to
/// NEON umin/umax. The cost is the gather and scatter around them, because the
/// pairs are interleaved in memory and there is no vld2q here.
public struct SIMDOddEvenSort: PixelSorter {
    public static let name = "SIMD Odd-Even Bubble Sort"
    public static let bigO = "O(n²/p)"
    public init() {}

    public func sort(_ p: UnsafeMutableBufferPointer<UInt32>, cancel: SortCancel?) -> SortStats {
        var stats = SortStats()
        let n = p.count
        guard n > 1 else { return stats }

        var rounds = 0
        while rounds < n {
            if cancel?.isCancelled == true { return stats }
            var moved = false
            for phase in 0 ..< 2 {
                let pairs = (n - phase) / 2
                guard pairs > 0 else { continue }
                stats.comparisons &+= UInt64(pairs)
                var k = 0
                while k + 4 <= pairs {
                    let base = phase + 2 * k
                    var evens = SIMD4<UInt32>(), odds = SIMD4<UInt32>()
                    for l in 0 ..< 4 {
                        evens[l] = p[base + 2 * l]
                        odds[l] = p[base + 2 * l + 1]
                    }
                    let lo = pointwiseMin(evens, odds)
                    let hi = pointwiseMax(evens, odds)
                    if lo != evens {
                        moved = true
                        // count the lanes that actually moved
                        let changed = SIMD4<Int32>.zero
                            .replacing(with: SIMD4<Int32>(repeating: 1), where: lo .!= evens)
                        stats.swaps &+= UInt64(changed.wrappedSum())
                    }
                    for l in 0 ..< 4 {
                        p[base + 2 * l] = lo[l]
                        p[base + 2 * l + 1] = hi[l]
                    }
                    k += 4
                }
                while k < pairs {                    // tail
                    let i = phase + 2 * k
                    let a = p[i], b = p[i + 1]
                    let mn = Swift.min(a, b), mx = Swift.max(a, b)
                    p[i] = mn; p[i + 1] = mx
                    if mn != a { stats.swaps &+= 1; moved = true }
                    k += 1
                }
            }
            if !moved { break }
            rounds += 1
        }
        return stats
    }
}
