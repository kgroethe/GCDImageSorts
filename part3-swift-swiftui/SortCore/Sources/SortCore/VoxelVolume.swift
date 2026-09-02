//
//  VoxelVolume.swift
//  SortCore
//
//  The 3D equivalent of the image Parts 1 to 3 sorted.
//
//  A picture is a 2D grid of pixels, so the spatial version is a 3D grid of
//  voxels. 64^3 is 262,144 voxels against the 307,200 pixels of a 640x480
//  image, so the workload is the same order of magnitude.
//
//  This follows the original PThreadSorts model rather than sorting colours.
//  SortablePicture::InOrder compares entries of pixelIndexArray, which holds
//  indices into the original bitmap, so sorting puts every pixel back where it
//  started and the picture reassembles. The same applies here: `order` is what
//  gets scrambled and sorted, `colors` never moves, and a sorted volume is the
//  structure restored rather than a gradient.
//

import Foundation

/// What the volume contains once it is sorted.
public enum VoxelStructure: String, CaseIterable, Sendable {
    /// Fractal with holes all the way through, so you can see into the volume.
    case mengerSponge
    /// The spatial answer to a broadcast test card: shells, axis stripes and a
    /// checkerboard, each in its own octant.
    case testCard
    /// Hollow nested shells, like an onion cut open.
    case shells
    /// Triply periodic minimal surface. Endless interlocking channels, and it
    /// fills the whole cube rather than clustering in the middle.
    case gyroid
    /// The 8th power Mandelbulb, coloured by how fast each point escapes.
    case mandelbulb
    /// Sierpinski tetrahedron: sparse, sharp, obviously self similar.
    case sierpinski
    /// Quaternion Julia set. The densest and least regular of the set.
    case julia
    /// Plain ramp. Useful as a control, dull to look at.
    case gradient
}

public struct VoxelVolume: Sendable {
    /// Colour of each cell of the finished structure. Never reordered.
    public let colors: [UInt32]
    /// The permutation under sort. Sorted ascending means the structure is whole.
    public private(set) var order: [UInt32]
    public let size: Int
    public let structure: VoxelStructure

    public var count: Int { order.count }
    public var sliceCount: Int { size }

    /// Build from an already voxelised colour grid, for imported models.
    public init(size: Int, colors: [UInt32], structure: VoxelStructure = .gradient) {
        precondition(colors.count == size * size * size, "colour grid must be size^3")
        self.size = size
        self.structure = structure
        self.colors = colors
        self.order = (0 ..< UInt32(size * size * size)).map { $0 }
    }

    public init(size: Int = 64, structure: VoxelStructure = .mengerSponge) {
        self.size = size
        self.structure = structure
        self.colors = Self.build(size: size, structure: structure)
        self.order = (0 ..< UInt32(size * size * size)).map { $0 }
    }

    public func index(x: Int, y: Int, z: Int) -> Int { x + y * size + z * size * size }

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

    /// Colours currently occupying one z-slice, following the permutation.
    public func slice(z: Int) -> [UInt32] {
        let start = z * size * size
        return (start ..< start + size * size).map { colors[Int(order[$0])] }
    }

    public mutating func withBuffer<R>(_ body: (UnsafeMutableBufferPointer<UInt32>) throws -> R) rethrows -> R {
        try order.withUnsafeMutableBufferPointer { try body($0) }
    }

    // MARK: - Structures

    private static func rgba(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> UInt32 {
        let R = UInt32(max(0, min(255, r * 255))), G = UInt32(max(0, min(255, g * 255)))
        let B = UInt32(max(0, min(255, b * 255))), A = UInt32(max(0, min(255, a * 255)))
        return (A << 24) | (B << 16) | (G << 8) | R
    }

    /// Empty space. Alpha zero, so the renderer draws nothing and you can see
    /// through to the structure behind.
    private static let empty: UInt32 = 0

    private static func hue(_ t: Double) -> (Double, Double, Double) {
        let h = min(max(t, 0), 0.999) * 5.0
        let seg = Int(h), f = h - Double(seg)
        switch seg {
        case 0: return (1, f, 0)
        case 1: return (1 - f, 1, 0)
        case 2: return (0, 1, f)
        case 3: return (0, 1 - f, 1)
        default: return (f, 0, 1)
        }
    }

    /// Escape iterations for the 8th power Mandelbulb, or nil if the point
    /// never escapes (inside the solid).
    private static func mandelbulb(_ p: (Double, Double, Double), maxIter: Int = 8) -> Int? {
        var (zx, zy, zz) = p
        var dr = 1.0, r = 0.0
        for i in 0 ..< maxIter {
            r = (zx * zx + zy * zy + zz * zz).squareRoot()
            if r > 2 { return i }
            let theta = acos(zz / max(r, 1e-9)), phi = atan2(zy, zx)
            let zr = pow(r, 8.0)
            dr = pow(r, 7.0) * 8.0 * dr + 1.0
            let st = sin(theta * 8), ct = cos(theta * 8)
            zx = zr * st * cos(phi * 8) + p.0
            zy = zr * st * sin(phi * 8) + p.1
            zz = zr * ct + p.2
            _ = dr
        }
        return nil
    }

    /// Quaternion Julia, kept to the ijk slice so it lands in three dimensions.
    private static func juliaEscape(_ p: (Double, Double, Double), maxIter: Int = 12) -> Int? {
        var (a, b, c, d) = (p.0, p.1, p.2, 0.0)
        let (ca, cb, cc, cd) = (-0.2, 0.6, 0.2, 0.0)
        for i in 0 ..< maxIter {
            if a * a + b * b + c * c + d * d > 4 { return i }
            let na = a * a - b * b - c * c - d * d + ca
            let nb = 2 * a * b + cb
            let nc = 2 * a * c + cc
            let nd = 2 * a * d + cd
            (a, b, c, d) = (na, nb, nc, nd)
        }
        return nil
    }

    /// True when the point is part of a Sierpinski tetrahedron.
    private static func inSierpinski(_ x: Int, _ y: Int, _ z: Int, size: Int) -> Bool {
        var (a, b, c) = (x, y, z)
        var s = size
        while s > 1 {
            let h = s / 2
            let (i, j, k) = (a >= h ? 1 : 0, b >= h ? 1 : 0, c >= h ? 1 : 0)
            // keep only the four corners whose coordinate parity sums even
            if (i + j + k) % 2 == 1 { return false }
            if i == 1 { a -= h }; if j == 1 { b -= h }; if k == 1 { c -= h }
            s = h
        }
        return true
    }

    /// True when the point is part of a Menger sponge carved `levels` deep.
    private static func inSponge(_ x: Int, _ y: Int, _ z: Int, size: Int, levels: Int) -> Bool {
        var s = size
        var (a, b, c) = (x, y, z)
        for _ in 0 ..< levels {
            let third = max(s / 3, 1)
            let (i, j, k) = (a / third % 3, b / third % 3, c / third % 3)
            let mids = (i == 1 ? 1 : 0) + (j == 1 ? 1 : 0) + (k == 1 ? 1 : 0)
            if mids >= 2 { return false }   // carved out
            a %= third; b %= third; c %= third
            s = third
            if s <= 1 { break }
        }
        return true
    }

    private static func build(size n: Int, structure: VoxelStructure) -> [UInt32] {
        var out = [UInt32](repeating: empty, count: n * n * n)
        let mid = Double(n - 1) / 2

        for z in 0 ..< n {
            for y in 0 ..< n {
                for x in 0 ..< n {
                    let i = x + y * n + z * n * n
                    let (dx, dy, dz) = (Double(x) - mid, Double(y) - mid, Double(z) - mid)
                    let r = (dx * dx + dy * dy + dz * dz).squareRoot() / (mid * 1.733)

                    switch structure {
                    case .gradient:
                        let t = Double(i) / Double(n * n * n - 1)
                        let (cr, cg, cb) = hue(t)
                        out[i] = rgba(cr, cg, cb)

                    case .mengerSponge:
                        if inSponge(x, y, z, size: n, levels: 3) {
                            // colour by distance from the centre, so the
                            // fractal shells read apart from each other
                            let (cr, cg, cb) = hue(r)
                            out[i] = rgba(cr, cg, cb)
                        }

                    case .shells:
                        // concentric hollow shells: keep thin bands of radius
                        let band = r * 6
                        if band.truncatingRemainder(dividingBy: 1) < 0.35 && r < 1 {
                            let (cr, cg, cb) = hue(r)
                            out[i] = rgba(cr, cg, cb)
                        }

                    case .gyroid:
                        // sin x cos y + sin y cos z + sin z cos x, thin shell
                        let k = 3.0 * 2 * Double.pi
                        let (u, v, w) = (Double(x) / Double(n) * k, Double(y) / Double(n) * k, Double(z) / Double(n) * k)
                        let f = sin(u) * cos(v) + sin(v) * cos(w) + sin(w) * cos(u)
                        if abs(f) < 0.42 {
                            let (cr, cg, cb) = hue((f + 0.42) / 0.84 * 0.7 + Double(z) / Double(n) * 0.3)
                            out[i] = rgba(cr, cg, cb)
                        }

                    case .mandelbulb:
                        let p = (dx / mid * 1.25, dy / mid * 1.25, dz / mid * 1.25)
                        if let esc = mandelbulb(p) {
                            // only the boundary shell, or the cube fills with fog
                            if esc >= 2 {
                                let (cr, cg, cb) = hue(Double(esc) / 8.0)
                                out[i] = rgba(cr, cg, cb)
                            }
                        } else {
                            out[i] = rgba(0.10, 0.05, 0.35)   // the solid core
                        }

                    case .sierpinski:
                        if inSierpinski(x, y, z, size: n) {
                            let (cr, cg, cb) = hue(Double(x + y + z) / Double(3 * n))
                            out[i] = rgba(cr, cg, cb)
                        }

                    case .julia:
                        let p = (dx / mid * 1.5, dy / mid * 1.5, dz / mid * 1.5)
                        if let esc = juliaEscape(p) {
                            if esc >= 3 {
                                let (cr, cg, cb) = hue(Double(esc) / 12.0)
                                out[i] = rgba(cr, cg, cb)
                            }
                        } else {
                            out[i] = rgba(0.9, 0.95, 1.0)
                        }

                    case .testCard:
                        let octant = (x > n / 2 ? 1 : 0) + (y > n / 2 ? 2 : 0) + (z > n / 2 ? 4 : 0)
                        switch octant % 4 {
                        case 0:   // axis stripes
                            if (x / 4 + y / 4) % 2 == 0 {
                                let (cr, cg, cb) = hue(Double(x) / Double(n)); out[i] = rgba(cr, cg, cb)
                            }
                        case 1:   // spherical shells
                            if (r * 8).truncatingRemainder(dividingBy: 1) < 0.4 {
                                let (cr, cg, cb) = hue(r); out[i] = rgba(cr, cg, cb)
                            }
                        case 2:   // 3D checkerboard
                            if (x / 6 + y / 6 + z / 6) % 2 == 0 {
                                let (cr, cg, cb) = hue(Double(z) / Double(n)); out[i] = rgba(cr, cg, cb)
                            }
                        default:  // solid ramp
                            let (cr, cg, cb) = hue(Double(y) / Double(n)); out[i] = rgba(cr, cg, cb)
                        }
                    }
                }
            }
        }
        return out
    }
}
