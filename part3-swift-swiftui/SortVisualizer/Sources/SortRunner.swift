//
//  SortRunner.swift
//  SortVisualizer
//
//  Drives one sort at a time and keeps a table of what each run measured.
//
//  Part 1's key fix was to stop redrawing on every swap and redraw on a clock
//  instead. That lesson carries over unchanged: the sort runs flat out on a
//  background queue and the UI samples it at a fixed rate.
//

import CoreGraphics
import Foundation
import Observation
import SortCore

enum Algorithm: String, CaseIterable, Identifiable {
    case radix, gcdQuick, quick, merge, heap, shell
    case parallelOddEven, simdOddEven, insertion, selection, branchlessBubble, bubble

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bubble: NaiveBubbleSort.name
        case .branchlessBubble: BranchlessBubbleSort.name
        case .simdOddEven: SIMDOddEvenSort.name
        case .parallelOddEven: ParallelOddEvenSort.name
        case .selection: SelectionSort.name
        case .insertion: InsertionSort.name
        case .shell: ShellSort.name
        case .heap: HeapSort.name
        case .merge: MergeSort.name
        case .quick: QuickSort.name
        case .gcdQuick: ParallelQuickSort.name
        case .radix: RadixSortLSD.name
        }
    }

    var bigO: String {
        switch self {
        case .bubble: NaiveBubbleSort.bigO
        case .branchlessBubble: BranchlessBubbleSort.bigO
        case .simdOddEven: SIMDOddEvenSort.bigO
        case .parallelOddEven: ParallelOddEvenSort.bigO
        case .selection: SelectionSort.bigO
        case .insertion: InsertionSort.bigO
        case .shell: ShellSort.bigO
        case .heap: HeapSort.bigO
        case .merge: MergeSort.bigO
        case .quick: QuickSort.bigO
        case .gcdQuick: ParallelQuickSort.bigO
        case .radix: RadixSortLSD.bigO
        }
    }

    /// True for the ones that will sit there for minutes on a big canvas.
    var isQuadratic: Bool {
        switch self {
        case .bubble, .branchlessBubble, .selection, .insertion: true
        default: false
        }
    }

    func makeSorter() -> any PixelSorter {
        switch self {
        case .bubble: NaiveBubbleSort()
        case .branchlessBubble: BranchlessBubbleSort()
        case .simdOddEven: SIMDOddEvenSort()
        case .parallelOddEven: ParallelOddEvenSort()
        case .selection: SelectionSort()
        case .insertion: InsertionSort()
        case .shell: ShellSort()
        case .heap: HeapSort()
        case .merge: MergeSort()
        case .quick: QuickSort()
        case .gcdQuick: ParallelQuickSort()
        case .radix: RadixSortLSD()
        }
    }
}

struct CanvasSize: Identifiable, Hashable, Sendable {
    let width: Int, height: Int
    var id: String { "\(width)x\(height)" }
    var pixels: Int { width * height }
    var label: String {
        if isNative { return "Full size" }
        return pixels >= 1_000_000
            ? String(format: "%dx%d (%.1fMP)", width, height, megapixels)
            : "\(width)×\(height)"
    }

    static let small = CanvasSize(width: 128, height: 96)
    static let medium = CanvasSize(width: 256, height: 192)
    /// The size Parts 1 and 2 measured.
    static let full = CanvasSize(width: 640, height: 480)
    /// Larger canvases exist because the good algorithms are otherwise too fast
    /// to see: radix sorts 307K pixels in about 3 ms. At 4.9M it takes long
    /// enough to read off a clock.
    static let hd = CanvasSize(width: 1280, height: 960)
    static let large = CanvasSize(width: 1920, height: 1440)
    static let huge = CanvasSize(width: 2560, height: 1920)
    /// Sentinel: use the picked photo's own resolution. Meaningless for the
    /// generated test pattern, which has no natural size.
    static let native = CanvasSize(width: 0, height: 0)
    static let all = [small, medium, full, hd, large, huge, native]

    var isNative: Bool { width == 0 }

    var megapixels: Double { Double(pixels) / 1_000_000 }
    /// Quadratic sorts are hopeless past the original size.
    var punishesQuadratic: Bool { pixels > CanvasSize.full.pixels }
}

struct RunResult: Identifiable {
    let id = UUID()
    let algorithm: String
    let pixels: Int
    let seconds: Double
    let swaps: UInt64
    let comparisons: UInt64
    let verified: Bool
}

@MainActor
@Observable
final class SortRunner {
    private(set) var image: CGImage?
    private(set) var isRunning = false
    private(set) var elapsed: Double = 0
    private(set) var results: [RunResult] = []
    private(set) var lastError: String?

    var algorithm: Algorithm = .parallelOddEven { didSet { reset() } }
    var size: CanvasSize = .medium { didSet { rebuildCustom(); reset() } }

    /// The source image. Never reordered, so it is safe to read while sorting.
    private var colors: [UInt32] = []
    /// The permutation the sorters rearrange.
    private var buffer: UnsafeMutableBufferPointer<UInt32>
    /// A picked photo, if any. Nil means the built in test pattern.
    private var custom: (colors: [UInt32], width: Int, height: Int, name: String)?
    /// Kept so changing canvas size re-derives from the original rather than
    /// forcing another trip through the picker.
    private var sourceImage: (image: CGImage, name: String)?
    private(set) var sourceName = "Test pattern"
    private var ticker: Timer?
    private var cancelToken: SortCancel?
    private(set) var wasCancelled = false
    private var startedAt: ContinuousClock.Instant?

    init() {
        buffer = UnsafeMutableBufferPointer<UInt32>.allocate(capacity: CanvasSize.medium.pixels)
        buffer.initialize(repeating: 0)
        reset()
    }

    // No deinit: the ticker captures self weakly and is invalidated when a run
    // finishes, and deinit is nonisolated so it cannot touch it anyway.

    private func allocate() {
        buffer.deallocate()
        buffer = UnsafeMutableBufferPointer<UInt32>.allocate(capacity: size.pixels)
        buffer.initialize(repeating: 0)
    }

    /// Rebuild the gradient and shuffle it with the fixed seed, so every run of
    /// a given size starts from exactly the same arrangement.
    func reset() {
        guard !isRunning else { return }
        var canvas: PixelCanvas
        if let c = custom {
            canvas = PixelCanvas(width: c.width, height: c.height, colors: c.colors, sourceName: c.name)
        } else {
            // "Full size" is the picked photo's resolution, so it means nothing
            // for the generated pattern. Fall back to the size Parts 1 and 2
            // measured rather than building a 0x0 canvas.
            let s = size.isNative ? CanvasSize.full : size
            canvas = PixelCanvas(width: s.width, height: s.height)
        }
        canvas.scramble()
        sourceName = canvas.sourceName
        colors = canvas.colors

        // withBuffer is mutating, so the count has to be read before the call
        // rather than inside the closure.
        let n = canvas.count
        if buffer.count != n {
            buffer.deallocate()
            buffer = UnsafeMutableBufferPointer<UInt32>.allocate(capacity: n)
            buffer.initialize(repeating: 0)
        }
        canvas.withBuffer { src in
            buffer.baseAddress!.update(from: src.baseAddress!, count: n)
        }
        elapsed = 0
        lastError = nil
        redraw()
    }

    /// Replace the test pattern with a picked image. Scaled down first: a full
    /// resolution photo would take a quadratic sort past any useful runtime.
    func load(image: CGImage, named name: String) {
        guard !isRunning else { return }
        sourceImage = (image, name)
        rebuildCustom()
        reset()
    }

    /// Derive the canvas from the stored image at whatever size is selected.
    private func rebuildCustom() {
        guard let src = sourceImage else { custom = nil; return }
        // Full size means the photo's own resolution, capped so a very large
        // image cannot exhaust memory: colours and order are 4 bytes each.
        let cap = 32_000_000
        let maxW = size.isNative ? min(src.image.width, cap) : size.width
        let maxH = size.isNative ? min(src.image.height, cap) : size.height
        guard let c = CanvasImage.canvasColors(from: src.image, maxWidth: maxW, maxHeight: maxH) else {
            custom = nil; return
        }
        custom = (c.colors, c.width, c.height, src.name)
    }

    func useTestPattern() {
        guard !isRunning else { return }
        custom = nil
        sourceImage = nil
        reset()
    }

    /// Dimensions actually in use, which follow a picked image's aspect ratio.
    var pixelWidth: Int { custom?.width ?? (size.isNative ? CanvasSize.full.width : size.width) }
    var pixelHeight: Int { custom?.height ?? (size.isNative ? CanvasSize.full.height : size.height) }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        wasCancelled = false
        elapsed = 0
        let token = SortCancel()
        cancelToken = token
        let sorter = algorithm.makeSorter()
        let name = algorithm.title
        let pixels = buffer.count
        nonisolated(unsafe) let buf = buffer
        let began = ContinuousClock.now
        startedAt = began

        ticker = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let stats = sorter.sort(buf, cancel: token)
            let d = (ContinuousClock.now - began).components
            let seconds = Double(d.seconds) + Double(d.attoseconds) / 1e18
            var ok = true
            for i in 1 ..< pixels where buf[i - 1] > buf[i] { ok = false; break }
            Task { @MainActor in
                self.finish(name: name, pixels: pixels, seconds: seconds, stats: stats, ok: ok)
            }
        }
    }

    private func tick() {
        if let startedAt { elapsed = seconds(since: startedAt) }
        redraw()
    }

    private func seconds(since instant: ContinuousClock.Instant) -> Double {
        let d = (ContinuousClock.now - instant).components
        return Double(d.seconds) + Double(d.attoseconds) / 1e18
    }

    /// Ask the running sort to stop. It returns at the next outer-loop check,
    /// leaving the buffer partly ordered.
    func cancelSort() {
        guard isRunning else { return }
        cancelToken?.cancel()
    }

    private func finish(name: String, pixels: Int, seconds: Double, stats: SortStats, ok: Bool) {
        ticker?.invalidate(); ticker = nil
        startedAt = nil
        let cancelled = cancelToken?.isCancelled == true
        cancelToken = nil
        wasCancelled = cancelled
        isRunning = false
        elapsed = seconds
        redraw()
        if cancelled {
            lastError = "\(name) cancelled after \(formatDuration(seconds)), the image is part sorted"
        } else if !ok {
            lastError = "\(name) finished but the buffer is not in order"
        }
        if !cancelled {
            results.insert(RunResult(algorithm: name, pixels: pixels, seconds: seconds,
                                     swaps: stats.swaps, comparisons: stats.comparisons,
                                     verified: ok), at: 0)
        }
    }

    private func redraw() {
        image = CanvasImage.make(colors: colors, order: buffer,
                                 width: pixelWidth, height: pixelHeight,
                                 label: algorithm.title)
    }
}
