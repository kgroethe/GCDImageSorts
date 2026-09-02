//
//  VoxelImport.swift
//  SortCore
//
//  Voxelise a 3D model into a volume the sorters can scramble and rebuild.
//
//  The generated structures are the test cards of this series: they prove the
//  machinery. An imported mesh is the equivalent of Part 1 using a real photo
//  instead of a gradient, and it is where the complexity actually comes from.
//
//  ModelIO does the hard part. MDLVoxelArray reads any format ModelIO opens
//  (USDZ, OBJ, STL, PLY) and reports the occupied cells; everything here is
//  fitting those cells into a cubic grid and giving them colour.
//

#if canImport(ModelIO)
import Foundation
import ModelIO
import simd

public enum VoxelImportError: Error, CustomStringConvertible {
    case cannotOpen(URL)
    case noMesh
    case noVoxels

    public var description: String {
        switch self {
        case .cannotOpen(let u): "could not open \(u.lastPathComponent)"
        case .noMesh: "the asset contains no mesh"
        case .noVoxels: "voxelisation produced nothing, try a larger size"
        }
    }
}

public extension VoxelVolume {

    /// How to colour an imported model, which arrives as bare occupancy.
    enum ImportPalette: Sendable {
        /// Rainbow up the model's height. Reads well against a dark room.
        case height
        /// Rainbow by distance from the centre, which picks out limbs.
        case radial
        /// Hue from height, brightness from how deep inside the surface a cell
        /// sits, so the shell and the interior separate.
        case depth
    }

    /// Voxelise a model file into a cubic grid.
    ///
    /// - Parameters:
    ///   - url: any format ModelIO can read.
    ///   - size: edge length of the cube. 64 keeps parity with the 2D parts.
    ///   - palette: how to colour the occupied cells.
    static func imported(contentsOf url: URL,
                         size: Int = 64,
                         palette: ImportPalette = .height) throws -> VoxelVolume {
        let asset = MDLAsset(url: url)
        guard asset.count > 0 else { throw VoxelImportError.cannotOpen(url) }

        // patchRadius 0 keeps the shell tight to the surface. MDLVoxelArray
        // resolves against the asset's own bounds, so models of any scale work.
        let array = MDLVoxelArray(asset: asset, divisions: Int32(size), patchRadius: 0)
        guard array.count > 0, let data = array.voxelIndices() else {
            throw VoxelImportError.noVoxels
        }

        let indices: [MDLVoxelIndex] = data.withUnsafeBytes { raw in
            Array(raw.bindMemory(to: MDLVoxelIndex.self))
        }
        guard !indices.isEmpty else { throw VoxelImportError.noVoxels }

        // ModelIO's indices sit in their own range, so rescale into 0..<size
        // while preserving proportions: a squashed bunny is not a bunny.
        var lo = SIMD3<Int32>(Int32.max, Int32.max, Int32.max)
        var hi = SIMD3<Int32>(Int32.min, Int32.min, Int32.min)
        for v in indices {
            lo = simd_min(lo, SIMD3(v.x, v.y, v.z))
            hi = simd_max(hi, SIMD3(v.x, v.y, v.z))
        }
        let span = SIMD3<Double>(Double(hi.x - lo.x), Double(hi.y - lo.y), Double(hi.z - lo.z))
        let longest = max(span.x, max(span.y, span.z), 1)
        let scale = Double(size - 1) / longest
        // centre the model in the cube on the two shorter axes
        let pad = SIMD3<Double>(
            (Double(size - 1) - span.x * scale) / 2,
            (Double(size - 1) - span.y * scale) / 2,
            (Double(size - 1) - span.z * scale) / 2
        )

        var colors = [UInt32](repeating: 0, count: size * size * size)
        let mid = Double(size - 1) / 2
        var filled = 0

        for v in indices {
            let x = Int((Double(v.x - lo.x) * scale + pad.x).rounded())
            let y = Int((Double(v.y - lo.y) * scale + pad.y).rounded())
            let z = Int((Double(v.z - lo.z) * scale + pad.z).rounded())
            guard x >= 0, y >= 0, z >= 0, x < size, y < size, z < size else { continue }

            let i = x + y * size + z * size * size
            if colors[i] != 0 { continue }
            filled += 1

            let t: Double
            switch palette {
            case .height:
                t = Double(y) / Double(size - 1)
            case .radial:
                let (dx, dy, dz) = (Double(x) - mid, Double(y) - mid, Double(z) - mid)
                t = min((dx * dx + dy * dy + dz * dz).squareRoot() / (mid * 1.733), 0.999)
            case .depth:
                // w carries the shell level: 0 is the surface, deeper is inside
                let shell = min(abs(Double(v.w)) / 8.0, 1.0)
                t = (Double(y) / Double(size - 1)) * 0.75 + shell * 0.25
            }
            colors[i] = hueRGBA(t)
        }

        guard filled > 0 else { throw VoxelImportError.noVoxels }
        return VoxelVolume(size: size, colors: colors)
    }

    /// Occupied cell count, for reporting how dense an import came out.
    static func occupancy(_ colors: [UInt32]) -> Int {
        colors.reduce(into: 0) { if $1 != 0 { $0 += 1 } }
    }

    private static func hueRGBA(_ t: Double) -> UInt32 {
        let h = min(max(t, 0), 0.999) * 5.0
        let seg = Int(h), f = h - Double(seg)
        let (r, g, b): (Double, Double, Double)
        switch seg {
        case 0: (r, g, b) = (1, f, 0)
        case 1: (r, g, b) = (1 - f, 1, 0)
        case 2: (r, g, b) = (0, 1, f)
        case 3: (r, g, b) = (0, 1 - f, 1)
        default: (r, g, b) = (f, 0, 1)
        }
        let R = UInt32(r * 255), G = UInt32(g * 255), B = UInt32(b * 255)
        return (255 << 24) | (B << 16) | (G << 8) | R
    }
}
#endif
