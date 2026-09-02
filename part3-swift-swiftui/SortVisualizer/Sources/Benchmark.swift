//
//  Benchmark.swift
//  SortVisualizer
//
//  Runs the whole algorithm suite once and reports timings, so device numbers
//  are directly comparable with `sortbench` on the Mac.
//
//  Launch with -benchmark to run it without touching the UI:
//    -benchmark            256x192, the quick calibration size
//    -benchmark full       640x480, the size Parts 1 and 2 measured
//    -benchmark full -all  include the quadratic sorts, which take minutes
//
//  Results are printed with NSLog as well as shown on screen, so they can be
//  read off a console when the device is tethered.
//

import Foundation
import Observation
import CoreGraphics
import SortCore

struct BenchResult: Identifiable {
    let id = UUID()
    let name: String
    let bigO: String
    let seconds: Double
    let swaps: UInt64
    let comparisons: UInt64
    let verified: Bool
}

@MainActor
@Observable
final class Benchmark {
    private(set) var results: [BenchResult] = []
    private(set) var running = false
    private(set) var current: String?
    private(set) var header = ""
    /// Live frame, published only in -render mode.
    private(set) var frame: CGImage?
    private var renderTicker: Timer?

    /// Start a 60fps redraw off the buffer the sorter is writing. Reading a
    /// buffer mid-mutation is deliberate: a torn frame is what a sort in
    /// progress looks like, and it is what the Objective-C++ version drew too.
    private func startRender(_ colors: [UInt32], _ buf: UnsafeMutableBufferPointer<UInt32>, _ w: Int, _ h: Int) {
        renderTicker?.invalidate()
        // The timer closure is @Sendable, so the buffer has to cross into it
        // explicitly. Only the sorter writes; this reads.
        nonisolated(unsafe) let shared = buf
        let t = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.frame = CanvasImage.make(colors: colors, order: shared, width: w, height: h)
            }
        }
        RunLoop.main.add(t, forMode: .common)
        renderTicker = t
    }

    private func stopRender(_ colors: [UInt32], _ buf: UnsafeMutableBufferPointer<UInt32>, _ w: Int, _ h: Int) {
        renderTicker?.invalidate(); renderTicker = nil
        frame = CanvasImage.make(colors: colors, order: buf, width: w, height: h)
    }

    static var requested: Bool { CommandLine.arguments.contains("-benchmark") }
    private static var wantsFull: Bool { CommandLine.arguments.contains("full") }
    private static var wantsAll: Bool { CommandLine.arguments.contains("-all") }
    /// -render drives a 60fps redraw off the shared buffer while each sort
    /// runs, matching what Part 2 measured. Its AppDelegate ran an NSTimer at
    /// 1.0/60 on the main thread while the sort worked on background threads,
    /// so 15.89 s was a figure that included drawing. A benchmark that renders
    /// nothing is not comparable with it.
    static var renders: Bool { CommandLine.arguments.contains("-render") }

    /// The quadratic sorts take minutes at 640x480, so they are opt-in there.
    private static let quadratic = ["Bubble Sort", "Branchless Bubble Sort",
                                    "Selection Sort", "Insertion Sort",
                                    "SIMD Odd-Even Bubble Sort"]

    func run() {
        guard !running else { return }
        running = true
        results = []

        let size = Self.wantsFull ? CanvasSize.full : CanvasSize.medium
        let all = Self.wantsAll || !Self.wantsFull
        let device = ProcessInfo.processInfo
        header = "\(size.width)x\(size.height) = \(size.pixels) px, \(device.activeProcessorCount) cores"
            + (Self.renders ? ", rendering at 60fps" : ", no rendering")
        NSLog("SORTBENCH device=%@ %@", Self.deviceModel(), header)

        // @Sendable: each closure captures only value types and builds its own
        // canvas, so it is safe to run off the main actor. The compiler cannot
        // infer that from a plain closure type.
        let algos = Algorithm.allCases.filter { Self.wantsAll || !Self.quadratic.contains($0.title) || !Self.wantsFull }
        let renders = Self.renders
        let w = size.width, h = size.height, count = size.pixels

        Task.detached(priority: .userInitiated) { [weak self] in
            for algo in algos {
                await MainActor.run { self?.current = algo.title }

                // Fresh scrambled canvas copied into a heap buffer both the
                // sorter and the renderer can see.
                var canvas = PixelCanvas(width: w, height: h)
                canvas.scramble()
                let buf = UnsafeMutableBufferPointer<UInt32>.allocate(capacity: count)
                canvas.withBuffer { src in
                    buf.baseAddress!.update(from: src.baseAddress!, count: count)
                }

                nonisolated(unsafe) let shared = buf
                let srcColors = canvas.colors
                if renders { await self?.startRender(srcColors, shared, w, h) }

                let sorter = algo.makeSorter()
                let t0 = ContinuousClock.now
                let stats = sorter.sort(buf)
                let d = (ContinuousClock.now - t0).components
                let secs = Double(d.seconds) + Double(d.attoseconds) / 1e18

                var ok = true
                for i in 1 ..< count where buf[i - 1] > buf[i] { ok = false; break }

                if renders { await self?.stopRender(srcColors, shared, w, h) }
                NSLog("SORTBENCH %@ | %.3f s | swaps %llu | comps %llu | sorted %@",
                      algo.title, secs, stats.swaps, stats.comparisons, ok ? "yes" : "NO")
                await MainActor.run {
                    self?.results.append(BenchResult(name: algo.title, bigO: algo.bigO, seconds: secs,
                                                     swaps: stats.swaps, comparisons: stats.comparisons,
                                                     verified: ok))
                }
                buf.deallocate()
            }
            await MainActor.run {
                self?.current = nil
                self?.running = false
                NSLog("SORTBENCH complete")
            }
        }
    }

    static func deviceModel() -> String {
        var sysinfo = utsname()
        uname(&sysinfo)
        let raw = withUnsafePointer(to: &sysinfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) { String(validatingCString: $0) ?? "?" }
        }
        return raw
    }
}
