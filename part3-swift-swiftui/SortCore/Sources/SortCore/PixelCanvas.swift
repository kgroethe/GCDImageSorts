//
//  PixelCanvas.swift
//  SortCore
//
//  The image model, with no AppKit, UIKit or SwiftUI in it.
//
//  Like VoxelVolume, this follows the original PThreadSorts design rather than
//  sorting colours. SortablePicture::InOrder compares entries of
//  pixelIndexArray, which holds indices into the original bitmap, so sorting
//  puts every pixel back where it started and the picture reassembles. Sorting
//  the colours themselves would only ever produce a gradient, which is a
//  different and much less interesting thing to watch.
//
//  `colors` is the source image and never moves. `order` is the permutation
//  that gets scrambled and sorted.
//

import Foundation

/// A deterministic 64-bit generator, so a scramble can be reproduced exactly.
public struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64
    public init(seed: UInt64) { self.state = seed }
    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

public struct PixelCanvas: Sendable {
    /// The source image, packed BGRA to match CoreGraphics' little-endian
    /// premultipliedFirst layout. Never reordered.
    public let colors: [UInt32]
    /// The permutation under sort. Ascending means the picture is whole.
    public private(set) var order: [UInt32]
    public let width: Int
    public let height: Int
    /// Where this came from, for display.
    public let sourceName: String

    public var count: Int { order.count }

    /// The built in test pattern, ported from SortablePicture::CreateGradientPattern
    /// so the Swift build shows the same image the Objective-C++ one did.
    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
        self.sourceName = "Test pattern"
        self.colors = Self.testPattern(width: width, height: height)
        self.order = (0 ..< UInt32(width * height)).map { $0 }
    }

    /// From an arbitrary image: a photo, a file, anything the caller can decode.
    public init(width: Int, height: Int, colors: [UInt32], sourceName: String = "Image") {
        precondition(colors.count == width * height, "colors must be width*height")
        self.width = width
        self.height = height
        self.colors = colors
        self.sourceName = sourceName
        self.order = (0 ..< UInt32(width * height)).map { $0 }
    }

    public mutating func scramble(seed: UInt64 = 0x5EED_1234_ABCD_0001) {
        var rng = SplitMix64(seed: seed)
        guard order.count > 1 else { return }
        for i in stride(from: order.count - 1, to: 0, by: -1) {
            let j = Int(rng.next() % UInt64(i + 1))
            order.swapAt(i, j)
        }
    }

    public var isSorted: Bool {
        order.indices.dropFirst().allSatisfy { order[$0 - 1] <= order[$0] }
    }

    /// Current appearance: the colour sitting at each position.
    public func rendered() -> [UInt32] {
        var out = [UInt32](repeating: 0, count: order.count)
        for i in 0 ..< order.count { out[i] = colors[Int(order[i])] }
        return out
    }

    /// The sorters work on the permutation.
    public mutating func withBuffer<R>(_ body: (UnsafeMutableBufferPointer<UInt32>) throws -> R) rethrows -> R {
        try order.withUnsafeMutableBufferPointer { try body($0) }
    }

    // MARK: - The test pattern

    private static func testPattern(width w: Int, height h: Int) -> [UInt32] {
        var out = [UInt32](repeating: 0, count: w * h)
        // The original reserves 50 rows of black for the overlay text at
        // 640x480. Hardcoding that makes any canvas under 50px tall come out
        // entirely black, so scale it and keep the same proportion.
        let reserved = min(max(h * 50 / 480, 0), max(h - 8, 0))
        let cx = Double(w) / 2, cy = Double(h) / 2

        for i in 0 ..< w * h {
            let x = i % w, y = i / w
            if y < reserved { out[i] = pack(0, 0, 0); continue }

            let ay = y - reserved
            let diagonal = (x + y) / 20
            let dx = Double(x) - cx, dy = Double(y) - cy
            let ring = Int((dx * dx + dy * dy).squareRoot() / 15) % 7
            let band = (ay * 6) / max(h - reserved, 1)

            var r = 0, g = 0, b = 0
            switch band {
            case 0:  r = 255; g = 0;   b = (ring % 2) * 255
            case 1:  r = 255; g = 255; b = ((x / 20) % 2) * 255
            case 2:  r = (ring % 2) * 255; g = 255; b = 0
            case 3:  r = 255; g = (diagonal % 2 == 0) ? 165 : 0; b = 0
            case 4:  r = 0;   g = (ring % 3) * 127; b = 255
            default: let c = ((x / 15) + (y / 15)) % 2 * 255; r = c; g = c; b = c
            }

            // centre checkerboard, blended toward mid grey
            let ah = h - reserved
            if x > w / 3, x < w * 2 / 3, ay > ah / 3, ay < ah * 2 / 3 {
                let kx = (x - w / 3) / 15, ky = (ay - ah / 3) / 15
                if (kx + ky) % 2 == 0 { r = (r + 100) / 2; g = (g + 100) / 2; b = (b + 100) / 2 }
            }
            out[i] = pack(UInt32(min(r, 255)), UInt32(min(g, 255)), UInt32(min(b, 255)))
        }
        return out
    }

    /// BGRA in a little-endian UInt32, which is what CGContext expects for
    /// premultipliedFirst + byteOrder32Little.
    @inline(__always)
    private static func pack(_ r: UInt32, _ g: UInt32, _ b: UInt32) -> UInt32 {
        (0xFF << 24) | (r << 16) | (g << 8) | b
    }
}
