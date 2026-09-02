//
//  SorterTests.swift
//  SortCoreTests
//
//  The property that matters is not "does it run" but "does every algorithm
//  agree". Twelve implementations sorting the same permutation must produce
//  the same buffer, and the ones that move data the same way must report the
//  same swap count. That catches an off-by-one an eyeball never would.
//

import XCTest
@testable import SortCore

final class SorterTests: XCTestCase {

    /// Every sorter, so a new one cannot be added without being covered.
    private var allSorters: [any PixelSorter] {
        [NaiveBubbleSort(), BranchlessBubbleSort(), SIMDOddEvenSort(),
         ParallelOddEvenSort(), SelectionSort(), InsertionSort(), ShellSort(),
         HeapSort(), MergeSort(), QuickSort(), ParallelQuickSort(), RadixSortLSD()]
    }

    private func scrambled(_ n: Int, seed: UInt64 = 0x1234_5678) -> [UInt32] {
        var v = (0 ..< UInt32(n)).map { $0 }
        var rng = SplitMix64(seed: seed)
        guard n > 1 else { return v }
        for i in stride(from: n - 1, to: 0, by: -1) {
            v.swapAt(i, Int(rng.next() % UInt64(i + 1)))
        }
        return v
    }

    func testEverySorterSorts() {
        for n in [0, 1, 2, 3, 17, 1000, 4096] {
            for sorter in allSorters {
                var data = scrambled(n)
                _ = data.withUnsafeMutableBufferPointer { type(of: sorter).self; return sorter.sort($0) }
                XCTAssertEqual(data, (0 ..< UInt32(n)).map { $0 },
                               "\(type(of: sorter)) failed at n=\(n)")
            }
        }
    }

    func testSortersAgreeOnResult() {
        let n = 2048
        let expected = (0 ..< UInt32(n)).map { $0 }
        for sorter in allSorters {
            var data = scrambled(n, seed: 0xABCD)
            _ = data.withUnsafeMutableBufferPointer { sorter.sort($0) }
            XCTAssertEqual(data, expected, "\(type(of: sorter)) disagreed")
        }
    }

    /// Anything that sorts by adjacent exchange performs exactly the inversion
    /// count of the input, so these must match each other exactly.
    func testAdjacentExchangeSortsShareSwapCount() {
        let n = 1024
        var counts: [String: UInt64] = [:]
        for sorter in [NaiveBubbleSort(), BranchlessBubbleSort(),
                       SIMDOddEvenSort(), ParallelOddEvenSort()] as [any PixelSorter] {
            var data = scrambled(n, seed: 7)
            let stats = data.withUnsafeMutableBufferPointer { sorter.sort($0) }
            counts["\(type(of: sorter))"] = stats.swaps
        }
        XCTAssertEqual(Set(counts.values).count, 1,
                       "adjacent-exchange sorts disagreed on swaps: \(counts)")
    }

    /// Radix never compares. If this regresses it has stopped being radix.
    func testRadixPerformsNoComparisons() {
        var data = scrambled(4096)
        let stats = data.withUnsafeMutableBufferPointer { RadixSortLSD().sort($0) }
        XCTAssertEqual(stats.comparisons, 0)
    }

    func testAlreadySortedInputStaysSorted() {
        let n = 512
        for sorter in allSorters {
            var data = (0 ..< UInt32(n)).map { $0 }
            _ = data.withUnsafeMutableBufferPointer { sorter.sort($0) }
            XCTAssertEqual(data, (0 ..< UInt32(n)).map { $0 },
                           "\(type(of: sorter)) disturbed sorted input")
        }
    }

    func testDuplicateValuesAreHandled() {
        for sorter in allSorters {
            var data: [UInt32] = [5, 1, 5, 1, 9, 5, 1, 9, 0, 0]
            _ = data.withUnsafeMutableBufferPointer { sorter.sort($0) }
            XCTAssertEqual(data, [0, 0, 1, 1, 1, 5, 5, 5, 9, 9],
                           "\(type(of: sorter)) mishandled duplicates")
        }
    }
}
