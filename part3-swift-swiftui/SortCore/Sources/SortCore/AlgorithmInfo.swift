//
//  AlgorithmInfo.swift
//  SortCore
//
//  What each algorithm is, and what you are actually looking at while it runs.
//
//  The visualisation is only interesting if you know what the shapes mean, so
//  this text ships with the apps rather than living only in the blog posts.
//  Kept in the package so iOS, macOS and visionOS all say the same thing.
//

import Foundation

public struct AlgorithmInfo: Sendable, Hashable {
    public let name: String
    public let bigO: String
    /// One line on how it works.
    public let summary: String
    /// What the pattern on screen tells you. This is the part worth reading.
    public let whatToWatch: String
    /// Where it lands in practice, measured rather than asserted.
    public let verdict: String

    public init(name: String, bigO: String, summary: String, whatToWatch: String, verdict: String) {
        self.name = name; self.bigO = bigO
        self.summary = summary; self.whatToWatch = whatToWatch; self.verdict = verdict
    }
}

public enum Explain {
    public static let credits = """
    Based on PThreadSorts, an Apple sample code project written in 2000 to \
    demonstrate pthreads on Mac OS X. It scrambled an image and sorted the \
    pixels back into place so you could watch algorithmic complexity happen.
    """

    public static let howItWorks = """
    Every pixel is given its original position as a number. Scrambling shuffles \
    those numbers; sorting puts them back in order, and the picture reassembles. \
    So you are not watching colours being sorted. You are watching a permutation \
    being undone, and the picture is the progress bar.
    """

    public static let whyItMatters = """
    Sorting the same data with the same hardware, the fastest algorithm here \
    finishes about 20,000 times sooner than the slowest. No amount of \
    micro-optimisation closes that gap. Choosing the right algorithm is the \
    optimisation; everything else is a rounding error.
    """

    public static let blogTitle = "Karl's Code Adventures"
    public static let blogURL = URL(string: "https://karl.groethe.com/posts/")!
    public static let seriesURL = URL(string: "https://karl.groethe.com/series/gcdimagesorts-modernization/")!

    public static func info(for name: String) -> AlgorithmInfo? { table[name] }

    public static let table: [String: AlgorithmInfo] = {
        let all: [AlgorithmInfo] = [
            .init(name: "Bubble Sort", bigO: "O(n²)",
                  summary: "Repeatedly walks the data swapping neighbours that are out of order.",
                  whatToWatch: "Slow ripples. Each pass carries one element to its final place, so order accumulates at one end while the rest stays chaotic.",
                  verdict: "The worst practical choice, and the reason it is here. On 307K pixels it takes minutes."),
            .init(name: "Branchless Bubble Sort", bigO: "O(n²)",
                  summary: "Bubble sort with the comparison branch replaced by min/max, so the CPU never has to predict.",
                  whatToWatch: "Identical to bubble sort. The difference is invisible, which is the point.",
                  verdict: "Measurably SLOWER than plain bubble sort, in both C++ and Swift. It trades a cheap predicted branch for a write that always happens."),
            .init(name: "SIMD Odd-Even Bubble Sort", bigO: "O(n²/p)",
                  summary: "Compares four pairs at a time using vector instructions.",
                  whatToWatch: "The same ripples, converging from both ends at once rather than one.",
                  verdict: "Faster than naive, but the gather and scatter around the vector work eats much of the gain."),
            .init(name: "Parallel Odd-Even Bubble Sort", bigO: "O(n²/p)",
                  summary: "Alternates comparing even and odd pairs. Within a phase every pair is independent, so the work splits across cores.",
                  whatToWatch: "Order growing inward from both ends simultaneously.",
                  verdict: "The fastest quadratic sort here, and a surprise: it runs faster on a 10-core M4 than an 18-core M5 Max, because each phase ends in a barrier."),
            .init(name: "Selection Sort", bigO: "O(n²)",
                  summary: "Finds the smallest remaining element and puts it in place. Once.",
                  whatToWatch: "Methodical and tidy. A clean sorted band grows from one end at a steady rate.",
                  verdict: "Does the fewest swaps of anything here and is still hopeless, because it compares everything to find each one."),
            .init(name: "Insertion Sort", bigO: "O(n²)",
                  summary: "Takes each element and slides it back into the sorted region behind it.",
                  whatToWatch: "A sorted region that grows smoothly, with visible churn at its edge.",
                  verdict: "Genuinely good on small or nearly sorted data, which is why quicksort here hands off to it below 24 elements."),
            .init(name: "Shell Sort", bigO: "O(n^1.25)",
                  summary: "Insertion sort done at decreasing gaps, so elements travel far early and little later.",
                  whatToWatch: "Coarse structure appearing first, then detail. The image resolves rather than sweeps.",
                  verdict: "Enormously better than the quadratic sorts for a handful of extra lines."),
            .init(name: "Heap Sort", bigO: "O(n log n)",
                  summary: "Builds a heap, then repeatedly removes the largest element.",
                  whatToWatch: "An initial scramble as the heap forms, then order filling in from one end.",
                  verdict: "Reliable and in place, with no worst case. Loses to quicksort in practice because it jumps around memory."),
            .init(name: "Merge Sort", bigO: "O(n log n)",
                  summary: "Sorts small runs, then merges them into larger sorted runs.",
                  whatToWatch: "A zipper. Sorted strips double in width with every pass.",
                  verdict: "Predictable and stable, at the cost of a second buffer the size of the data."),
            .init(name: "QuickSort", bigO: "O(n log n)",
                  summary: "Partitions around a pivot, then sorts each side.",
                  whatToWatch: "Regions snapping into order in bursts as partitions resolve.",
                  verdict: "Usually the fastest comparison sort, because it works on contiguous memory the cache likes."),
            .init(name: "GCD QuickSort", bigO: "O(n log n / p)",
                  summary: "Quicksort where large partitions are handed to Grand Central Dispatch.",
                  whatToWatch: "Several regions resolving at once instead of one at a time.",
                  verdict: "The fastest comparison sort here. Partitions are independent by construction, which is what makes it parallelise cleanly."),
            .init(name: "Radix Sort", bigO: "O(n)",
                  summary: "Never compares anything. Buckets by one byte at a time, four passes for a 32-bit value.",
                  whatToWatch: "Four sweeps, each leaving the data more organised than the last.",
                  verdict: "Beats every comparison sort at scale by refusing to play the game. It cannot be applied to arbitrary data, which is the trade."),
        ]
        return Dictionary(uniqueKeysWithValues: all.map { ($0.name, $0) })
    }()
}
