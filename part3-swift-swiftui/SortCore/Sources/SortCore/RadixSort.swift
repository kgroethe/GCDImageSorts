//
//  RadixSort.swift
//  SortCore
//
//  LSD radix sort, four passes over the four bytes of a packed pixel.
//  This is the algorithm that made Part 2's point: it beat every micro-optimized
//  comparison sort not by being tuned, but by being O(n) instead of O(n²).
//
//  The Objective-C++ version used NEON to load four pixels at a time while
//  counting. That part is memory bound on scattered bucket increments, so the
//  scalar Swift form is written plainly here and the benchmark says whether it
//  costs anything.
//

import Foundation

public struct RadixSortLSD: PixelSorter {
    public static let name = "Radix Sort"
    public static let bigO = "O(n)"
    private static let radix = 256

    public init() {}

    public func sort(_ p: UnsafeMutableBufferPointer<UInt32>, cancel: SortCancel?) -> SortStats {
        var stats = SortStats()
        let n = p.count
        guard n > 1 else { return stats }

        var scratch = [UInt32](repeating: 0, count: n)
        var counts = [Int](repeating: 0, count: Self.radix)

        scratch.withUnsafeMutableBufferPointer { temp in
            var src = p
            var dst = temp

            for byteIndex in 0 ..< 4 {
                let shift = UInt32(byteIndex * 8)
                for i in 0 ..< Self.radix { counts[i] = 0 }

                for i in 0 ..< n {
                    counts[Int((src[i] >> shift) & 0xFF)] += 1
                }
                // prefix sum turns the histogram into bucket start offsets
                var running = 0
                for b in 0 ..< Self.radix {
                    let c = counts[b]
                    counts[b] = running
                    running += c
                }
                for i in 0 ..< n {
                    let bucket = Int((src[i] >> shift) & 0xFF)
                    dst[counts[bucket]] = src[i]
                    counts[bucket] += 1
                }
                // radix moves every element each pass and compares nothing
                stats.swaps &+= UInt64(n)
                swap(&src, &dst)
            }
            // four passes is even, so the data ended back in p; if that ever
            // changes, copy rather than silently returning the scratch buffer.
            if src.baseAddress != p.baseAddress {
                p.baseAddress!.update(from: src.baseAddress!, count: n)
            }
        }
        return stats
    }
}
