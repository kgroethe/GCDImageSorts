//
//  main.swift
//  sortbench
//
//  Times the Swift ports against each other on an identical scrambled buffer.
//  The numbers this prints are the raw material for Part 3, so it verifies that
//  each run actually finished sorted rather than trusting the algorithm.
//

import Foundation
import SortCore

struct Case { let name: String; let bigO: String; let run: (inout PixelCanvas) -> SortStats; let run2: (UnsafeMutableBufferPointer<UInt32>) -> SortStats }

let args = CommandLine.arguments
func intArg(_ flag: String, _ fallback: Int) -> Int {
    guard let i = args.firstIndex(of: flag), i + 1 < args.count,
          let v = Int(args[i + 1]) else { return fallback }
    return v
}

// 640x480 = 307,200 pixels is the size Parts 1 and 2 measured. It is not the
// default here because naive bubble sort at that size runs for minutes.
let width = intArg("--width", 256)
let height = intArg("--height", 192)
let seed = UInt64(intArg("--seed", 0x1234_5678))

var cases: [Case] = [
    Case(name: NaiveBubbleSort.name, bigO: NaiveBubbleSort.bigO, run: { NaiveBubbleSort().sort(&$0) }, run2: { NaiveBubbleSort().sort($0) }),
    Case(name: BranchlessBubbleSort.name, bigO: BranchlessBubbleSort.bigO, run: { BranchlessBubbleSort().sort(&$0) }, run2: { BranchlessBubbleSort().sort($0) }),
    Case(name: SIMDOddEvenSort.name, bigO: SIMDOddEvenSort.bigO, run: { SIMDOddEvenSort().sort(&$0) }, run2: { SIMDOddEvenSort().sort($0) }),
    Case(name: ParallelOddEvenSort.name, bigO: ParallelOddEvenSort.bigO, run: { ParallelOddEvenSort().sort(&$0) }, run2: { ParallelOddEvenSort().sort($0) }),
    Case(name: SelectionSort.name, bigO: SelectionSort.bigO, run: { SelectionSort().sort(&$0) }, run2: { SelectionSort().sort($0) }),
    Case(name: InsertionSort.name, bigO: InsertionSort.bigO, run: { InsertionSort().sort(&$0) }, run2: { InsertionSort().sort($0) }),
    Case(name: ShellSort.name, bigO: ShellSort.bigO, run: { ShellSort().sort(&$0) }, run2: { ShellSort().sort($0) }),
    Case(name: HeapSort.name, bigO: HeapSort.bigO, run: { HeapSort().sort(&$0) }, run2: { HeapSort().sort($0) }),
    Case(name: MergeSort.name, bigO: MergeSort.bigO, run: { MergeSort().sort(&$0) }, run2: { MergeSort().sort($0) }),
    Case(name: QuickSort.name, bigO: QuickSort.bigO, run: { QuickSort().sort(&$0) }, run2: { QuickSort().sort($0) }),
    Case(name: ParallelQuickSort.name, bigO: ParallelQuickSort.bigO, run: { ParallelQuickSort().sort(&$0) }, run2: { ParallelQuickSort().sort($0) }),
    Case(name: RadixSortLSD.name, bigO: RadixSortLSD.bigO, run: { RadixSortLSD().sort(&$0) }, run2: { RadixSortLSD().sort($0) }),
]
if let i = args.firstIndex(of: "--only"), i + 1 < args.count {
    let wanted = args[i + 1].lowercased().split(separator: ",").map(String.init)
    cases = cases.filter { c in wanted.contains { c.name.lowercased().contains($0) } }
}

// --indices N sorts a scrambled 0..<N index array, which is what the
// Objective-C++ version sorts. Used for the head-to-head against it.
if let i = args.firstIndex(of: "--indices"), i + 1 < args.count, let n = Int(args[i + 1]) {
    let seed = UInt64(intArg("--seed", 0x1234_5678))
    let chunks = intArg("--chunks", ProcessInfo.processInfo.activeProcessorCount)
    var data = (0 ..< UInt32(n)).map { $0 }
    var rng = SplitMix64(seed: seed)
    for k in stride(from: n - 1, to: 0, by: -1) {
        data.swapAt(k, Int(rng.next() % UInt64(k + 1)))
    }
    let sorter: any PixelSorter = ParallelOddEvenSort(chunks: chunks)
    let t0 = ContinuousClock.now
    let stats = data.withUnsafeMutableBufferPointer { sorter.sort($0) }
    let d = (ContinuousClock.now - t0).components
    let secs = Double(d.seconds) + Double(d.attoseconds) / 1e18
    let ok = data.indices.dropFirst().allSatisfy { data[$0 - 1] <= data[$0] }
    print("Swift ParallelOddEvenSort (no rendering)")
    print("  \(n) elements, seed 0x\(String(seed, radix: 16)), \(chunks) chunks")
    print(String(format: "  %.3f s   swaps %llu   comparisons %llu   sorted: %@",
                 secs, stats.swaps, stats.comparisons, ok ? "yes" : "NO"))
    exit(0)
}

// --canceltest proves the cancel token actually interrupts a running sort.
if args.contains("--canceltest") {
    let n = 640 * 480
    var data = (0 ..< UInt32(n)).map { $0 }
    var rng = SplitMix64(seed: 99)
    for k in stride(from: n - 1, to: 0, by: -1) { data.swapAt(k, Int(rng.next() % UInt64(k + 1))) }

    let token = SortCancel()
    let done = DispatchSemaphore(value: 0)
    nonisolated(unsafe) var elapsed = 0.0
    nonisolated(unsafe) var sortedAfter = false

    data.withUnsafeMutableBufferPointer { buf in
        nonisolated(unsafe) let b = buf
        let t0 = ContinuousClock.now
        DispatchQueue.global().async {
            _ = NaiveBubbleSort().sort(b, cancel: token)   // would run for a minute
            let d = (ContinuousClock.now - t0).components
            elapsed = Double(d.seconds) + Double(d.attoseconds) / 1e18
            sortedAfter = b.indices.dropFirst().allSatisfy { b[$0 - 1] <= b[$0] }
            done.signal()
        }
        Thread.sleep(forTimeInterval: 0.4)
        token.cancel()
        done.wait()
    }
    print("  cancelled a 640x480 bubble sort after 0.4 s")
    print(String(format: "  returned in %.3f s (uncancelled it runs for about a minute)", elapsed))
    print("  buffer left sorted: \(sortedAfter)  <- expected false, it stopped part way")
    exit(elapsed < 5 ? 0 : 1)
}

// --genbench times structure generation, which is a real startup cost at scale.
if args.contains("--genbench") {
    for st in [VoxelStructure.gyroid, .mengerSponge, .shells, .mandelbulb, .julia] {
        for n in [128, 256] {
            let t0 = ContinuousClock.now
            let v = VoxelVolume(size: n, structure: st)
            let d = (ContinuousClock.now - t0).components
            let secs = Double(d.seconds) + Double(d.attoseconds) / 1e18
            let filled = VoxelVolume.occupancy(v.colors)
            print(String(format: "  %-14s %4d^3  build %6.2f s  %5.1f%% filled  %4.0f MB",
                         (st.rawValue as NSString).utf8String!, n, secs,
                         Double(filled) / Double(v.count) * 100,
                         Double(v.count) * 8 / 1_048_576))
        }
    }
    exit(0)
}

// --import PATH voxelises a model file and sorts the result.
if let i = args.firstIndex(of: "--import"), i + 1 < args.count {
    let url = URL(fileURLWithPath: (args[i + 1] as NSString).expandingTildeInPath)
    let n = intArg("--size", 64)
    do {
        var vol = try VoxelVolume.imported(contentsOf: url, size: n, palette: .height)
        let filled = VoxelVolume.occupancy(vol.colors)
        let pct = Double(filled) / Double(vol.count) * 100
        print(String(format: "%@  %dx%dx%d  %d of %d cells filled (%.1f%%)",
                     url.lastPathComponent, n, n, n, filled, vol.count, pct))
        vol.scramble()
        let t0 = ContinuousClock.now
        _ = vol.withBuffer { RadixSortLSD().sort($0) }
        let d = (ContinuousClock.now - t0).components
        let secs = Double(d.seconds) + Double(d.attoseconds) / 1e18
        print(String(format: "  rebuilt by RadixSort in %.3f s, sorted: %@", secs, vol.isSorted ? "yes" : "NO"))
    } catch {
        print("  import failed: \(error)")
    }
    exit(0)
}

// --volume N sorts an NxNxN voxel cube instead of a 2D image, to show the
// same algorithms handling the 3D case with no changes.
if let i = args.firstIndex(of: "--volume"), i + 1 < args.count, let n = Int(args[i + 1]) {
    var vol = VoxelVolume(size: n)
    vol.scramble()
    print("volume \(n)x\(n)x\(n) = \(vol.count) voxels\n")
    print("algorithm                 time        sorted")
    print(String(repeating: "-", count: 50))
    // the quadratic sorts are hopeless past a small cube, so drop them there
    var skip = ["Bubble Sort", "Branchless Bubble Sort", "Selection Sort", "Insertion Sort", "SIMD Odd-Even Bubble Sort"]
    if n > 64 { skip.append("Parallel Odd-Even Bubble Sort") }
    for c in cases where !skip.contains(c.name) {
        var v = VoxelVolume(size: n); v.scramble()
        let t0 = ContinuousClock.now
        _ = v.withBuffer { c.run2($0) }
        let d = (ContinuousClock.now - t0).components
        let secs = Double(d.seconds) + Double(d.attoseconds) / 1e18
        print(String(format: "%-24s %8.3f s  %@", (c.name as NSString).utf8String!, secs, v.isSorted ? "yes" : "NO"))
    }
    exit(0)
}

let pixels = width * height
print("sortbench  \(width)x\(height) = \(pixels) pixels  seed 0x\(String(seed, radix: 16))")
print("cores: \(ProcessInfo.processInfo.activeProcessorCount)\n")
print("algorithm                 time        swaps          comparisons    sorted")
print(String(repeating: "-", count: 76))

var baseline: Double?
for c in cases {
    var canvas = PixelCanvas(width: width, height: height)
    canvas.scramble(seed: seed)
    let start = ContinuousClock.now
    let stats = c.run(&canvas)
    // .components splits into (seconds, attoseconds); the attoseconds field is
    // only the fractional part, so both have to be added or whole seconds vanish.
    let d = (ContinuousClock.now - start).components
    let elapsed = Double(d.seconds) + Double(d.attoseconds) / 1e18
    let ok = canvas.isSorted
    if baseline == nil { baseline = elapsed }
    let speedup = baseline.map { $0 / elapsed } ?? 1
    print(String(format: "%-24s %8.3f s  %13llu  %13llu  %@  %5.2fx",
                 (c.name as NSString).utf8String!, elapsed,
                 stats.swaps, stats.comparisons,
                 ok ? "yes" : "NO ", speedup))
    if !ok { print("  !! \(c.name) did not produce a sorted buffer") }
}
