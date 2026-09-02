//
//  VolumeRunner.swift
//  SortsVision
//
//  Holds the voxel structure, runs a sort on it, and hands out slice colours.
//
//  The buffer being sorted is a single heap allocation that both the sorter and
//  the renderer look at. That is deliberate. VoxelVolume is a struct, so passing
//  it to a background queue copies it, the sort mutates the copy, and the view
//  keeps drawing the original until the whole thing finishes and jumps to
//  sorted. Watching the sort happen requires sharing the memory, exactly as the
//  Objective-C++ DrawThread did.
//

import Foundation
import Observation
import CoreGraphics
import SortCore

@MainActor
@Observable
final class VolumeRunner {
    /// 256^3 = 16,777,216 voxels. 64^3 matched the pixel count of the 2D parts
    /// but RadixSort finished it in 2 ms, which is nothing to watch.
    let size = 256
    /// Every eighth slice. 32 layers reads as a volume; drawing 256 transparent
    /// planes of 256x256 would cost far more than it shows.
    let sliceStride = 8

    private(set) var generation = 0
    private(set) var structureGeneration = 0
    private(set) var isRunning = false
    private(set) var isPreparing = true
    private(set) var elapsed = 0.0
    private(set) var lastResult: String?
    private(set) var importNote: String?

    var subject: Subject = .structure(.gyroid) { didSet { structureGeneration += 1; reset() } }
    var algorithm: VolumeAlgorithm = .heap { didSet { reset() } }

    var structure: VoxelStructure {
        if case .structure(let s) = subject { return s }
        return .gradient
    }

    /// Colours of the finished structure. Never reordered, so it is safe to read
    /// while the sort runs.
    private var colors: [UInt32] = []
    /// The permutation. Sorted by the algorithms, read by the renderer, shared
    /// on purpose.
    private var order: UnsafeMutableBufferPointer<UInt32>
    private var ticker: Timer?
    private var startedAt: ContinuousClock.Instant?

    init() {
        order = UnsafeMutableBufferPointer<UInt32>.allocate(capacity: 1)
        order.initialize(repeating: 0)
        prepare()
    }

    var voxelCountText: String {
        NumberFormatter.localizedString(from: NSNumber(value: size * size * size), number: .decimal)
    }

    var sliceIndices: [Int] { Array(stride(from: 0, to: size, by: sliceStride)) }

    /// Premultiplied RGBA for one z-slice, read live from the shared buffer.
    /// Empty voxels stay fully transparent so you can see into the structure.
    func sliceBytes(z: Int) -> [UInt8] {
        let plane = size * size
        let start = z * plane
        var out = [UInt8](repeating: 0, count: plane * 4)
        guard order.count >= start + plane, colors.count >= order.count else { return out }
        for i in 0 ..< plane {
            let v = colors[Int(order[start + i])]
            let a = UInt8((v >> 24) & 0xFF)
            guard a > 0 else { continue }
            out[i * 4 + 0] = UInt8(v & 0xFF)
            out[i * 4 + 1] = UInt8((v >> 8) & 0xFF)
            out[i * 4 + 2] = UInt8((v >> 16) & 0xFF)
            out[i * 4 + 3] = a
        }
        return out
    }

    func reset() {
        guard !isRunning else { return }
        prepare()
    }

    /// Build the structure and shuffle it off the main thread. At 256^3 this is
    /// tens of millions of cells; doing it on the main thread blocks long enough
    /// that opening the immersive space fails outright.
    private func prepare() {
        isPreparing = true
        elapsed = 0
        lastResult = nil
        let subject = self.subject
        let size = self.size

        DispatchQueue.global(qos: .userInitiated).async {
            var note: String?
            var v = Self.build(subject: subject, size: size) { note = $0 }
            v.scramble()
            let colors = v.colors
            let order = v.order
            Task { @MainActor in
                self.install(colors: colors, order: order, note: note)
            }
        }
    }

    private func install(colors: [UInt32], order newOrder: [UInt32], note: String?) {
        self.order.deallocate()
        self.colors = colors
        let buf = UnsafeMutableBufferPointer<UInt32>.allocate(capacity: newOrder.count)
        _ = buf.initialize(fromContentsOf: newOrder)
        self.order = buf
        self.importNote = note
        self.isPreparing = false
        self.generation += 1
    }

    func start() {
        guard !isRunning, !isPreparing else { return }
        isRunning = true
        elapsed = 0
        let sorter = algorithm.makeSorter()
        let began = ContinuousClock.now
        startedAt = began

        // The sorter writes into the same allocation the renderer reads from.
        nonisolated(unsafe) let shared = order

        ticker = Timer.scheduledTimer(withTimeInterval: 1.0 / 10.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if let s = self.startedAt { self.elapsed = Self.seconds(since: s) }
                self.generation += 1
            }
        }

        DispatchQueue.global(qos: .userInitiated).async {
            _ = sorter.sort(shared)
            let secs = Self.seconds(since: began)
            var ok = true
            for i in 1 ..< shared.count where shared[i - 1] > shared[i] { ok = false; break }
            Task { @MainActor in self.finish(seconds: secs, ok: ok) }
        }
    }

    private static func seconds(since i: ContinuousClock.Instant) -> Double {
        let d = (ContinuousClock.now - i).components
        return Double(d.seconds) + Double(d.attoseconds) / 1e18
    }

    private func finish(seconds: Double, ok: Bool) {
        ticker?.invalidate(); ticker = nil
        startedAt = nil
        isRunning = false
        elapsed = seconds
        generation += 1
        lastResult = ok
            ? String(format: "%@ rebuilt the %@ in %@", algorithm.title, subject.label, formatDuration(seconds))
            : "\(algorithm.title) did not finish sorted"
    }

    private static func build(subject: Subject, size: Int, note: (String?) -> Void) -> VoxelVolume {
        switch subject {
        case .structure(let s):
            note(nil)
            return VoxelVolume(size: size, structure: s)
        case .model(let name, let ext):
            guard let url = Bundle.main.url(forResource: name, withExtension: ext) else {
                note("\(name).\(ext) is not in the bundle")
                return VoxelVolume(size: size, structure: .gyroid)
            }
            do {
                let v = try VoxelVolume.imported(contentsOf: url, size: size, palette: .height)
                let filled = VoxelVolume.occupancy(v.colors)
                note(String(format: "%@: %d cells (%.1f%%)", name, filled,
                            Double(filled) / Double(v.count) * 100))
                return v
            } catch {
                note("\(name): \(error)")
                return VoxelVolume(size: size, structure: .gyroid)
            }
        }
    }
}

/// What the volume contains: a computed structure, or a voxelised model.
enum Subject: Hashable, Identifiable {
    case structure(VoxelStructure)
    case model(String, String)

    var id: String {
        switch self {
        case .structure(let s): "s:" + s.rawValue
        case .model(let n, _): "m:" + n
        }
    }

    var label: String {
        switch self {
        case .structure(let s): s.label
        case .model(let n, _): n.replacingOccurrences(of: "r", with: "").capitalized
        }
    }

    /// Only generated structures ship. The importer still works, but on files
    /// the user supplies: bundling third-party geometry would mean shipping
    /// somebody else's model under a licence we do not have.
    static let all: [Subject] = VoxelStructure.allCases.map { .structure($0) }
}

extension VoxelStructure {
    var label: String {
        switch self {
        case .mengerSponge: "Menger sponge"
        case .testCard: "test card"
        case .shells: "shells"
        case .gyroid: "gyroid"
        case .mandelbulb: "Mandelbulb"
        case .sierpinski: "Sierpinski"
        case .julia: "Julia set"
        case .gradient: "gradient"
        }
    }
}

enum VolumeAlgorithm: String, CaseIterable, Identifiable {
    case radix, gcdQuick, quick, merge, heap, shell, parallelOddEven
    var id: String { rawValue }

    var title: String {
        switch self {
        case .radix: RadixSortLSD.name
        case .gcdQuick: ParallelQuickSort.name
        case .quick: QuickSort.name
        case .merge: MergeSort.name
        case .heap: HeapSort.name
        case .shell: ShellSort.name
        case .parallelOddEven: ParallelOddEvenSort.name
        }
    }

    func makeSorter() -> any PixelSorter {
        switch self {
        case .radix: RadixSortLSD()
        case .gcdQuick: ParallelQuickSort()
        case .quick: QuickSort()
        case .merge: MergeSort()
        case .heap: HeapSort()
        case .shell: ShellSort()
        case .parallelOddEven: ParallelOddEvenSort()
        }
    }
}
