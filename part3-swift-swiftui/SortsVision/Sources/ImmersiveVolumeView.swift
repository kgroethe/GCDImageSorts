//
//  ImmersiveVolumeView.swift
//  SortsVision
//
//  The structure, alone in a dark room, updating while it sorts.
//
//  16.7 million voxels cannot each be an entity, so the volume is drawn as
//  parallel planes through it, each carrying one z-slice as a texture. Empty
//  voxels have zero alpha, which is what lets you see into the structure
//  instead of at its front face.
//
//  Two things keep it smooth. The textures and materials are built once and
//  their contents replaced in place, rather than rebuilding a material per
//  slice per frame. And only a few slices are refreshed per tick, cycling
//  through the stack, so the per-frame cost is a fraction of the volume rather
//  than all of it.
//

import RealityKit
import SwiftUI
import simd
import SortCore

@MainActor
final class SliceStack {
    var root = Entity()
    var entities: [ModelEntity] = []
    var textures: [TextureResource] = []
    var subscription: EventSubscription?
    /// Where the round-robin refresh got to last tick.
    var cursor = 0
    var busy = false
}

struct ImmersiveVolumeView: View {
    @Environment(VolumeRunner.self) private var runner
    @State private var stack = SliceStack()

    private let extent: Float = 1.1
    /// Slices refreshed per tick. The whole stack cycles roughly 4 times a
    /// second at 10 ticks, which is plenty to read a sort in progress.
    private let slicesPerTick = 8

    var body: some View {
        RealityView { content in
            await build(content)
        }
        .onChange(of: runner.generation) { _, _ in Task { await refreshSome() } }
        .onChange(of: runner.structureGeneration) { _, _ in Task { await refreshAll() } }
        .task {
            let args = CommandLine.arguments
            if let i = args.firstIndex(of: "-structure"), i + 1 < args.count,
               let st = VoxelStructure(rawValue: args[i + 1]) {
                runner.subject = .structure(st)
            }
            if let i = args.firstIndex(of: "-model"), i + 1 < args.count {
                let parts = args[i + 1].split(separator: ".")
                if parts.count == 2 { runner.subject = .model(String(parts[0]), String(parts[1])) }
            }
            guard args.contains("-autosort") else { return }
            if let i = args.firstIndex(of: "-autosort"), i + 1 < args.count,
               let a = VolumeAlgorithm(rawValue: args[i + 1]) {
                runner.algorithm = a
            }
            // wait for the structure to finish building before sorting it
            while runner.isPreparing { try? await Task.sleep(for: .milliseconds(200)) }
            runner.start()
        }
    }

    private func build(_ content: RealityViewContent) async {
        let root = stack.root
        let idx = runner.sliceIndices
        let n = runner.size

        for (i, z) in idx.enumerated() {
            guard let tex = Self.texture(from: runner.sliceBytes(z: z), width: n, height: n) else { continue }
            var m = UnlitMaterial(color: .white)
            m.color = .init(tint: .white, texture: .init(tex))
            // 32 planes accumulate, so each contributes a little. Against a
            // black room this reads as glowing volume, not stacked sheets.
            m.blending = .transparent(opacity: 0.16)
            m.faceCulling = .none

            let plane = ModelEntity(mesh: .generatePlane(width: extent, height: extent), materials: [m])
            let t = Float(i) / Float(max(idx.count - 1, 1))
            plane.position = [0, 0, (t - 0.5) * extent]
            root.addChild(plane)
            stack.entities.append(plane)
            stack.textures.append(tex)
        }

        // Sorted order runs x, then y, then z, so a sorted cube seen straight
        // down the z axis is one flat colour. Turning it shows the ramp.
        root.orientation = simd_quatf(angle: .pi / 5, axis: [0, 1, 0])
            * simd_quatf(angle: .pi / 12, axis: [1, 0, 0])
        root.position = [0, 1.4, -1.9]
        content.add(root)

        stack.subscription = content.subscribe(to: SceneEvents.Update.self) { event in
            let d = Float(event.deltaTime)
            stack.root.orientation *= simd_quatf(angle: d * 0.18, axis: [0, 1, 0])
        }
    }

    /// Refresh a slice of the stack, then advance the cursor.
    private func refreshSome() async {
        guard !stack.busy, !stack.textures.isEmpty else { return }
        stack.busy = true
        defer { stack.busy = false }

        let idx = runner.sliceIndices
        let n = runner.size
        for _ in 0 ..< min(slicesPerTick, stack.textures.count) {
            let i = stack.cursor % stack.textures.count
            stack.cursor += 1
            guard i < idx.count else { continue }
            if let cg = Self.image(from: runner.sliceBytes(z: idx[i]), width: n, height: n) {
                try? await stack.textures[i].replace(withImage: cg, options: .init(semantic: .color))
            }
        }
    }

    private func refreshAll() async {
        guard !stack.textures.isEmpty else { return }
        let idx = runner.sliceIndices
        let n = runner.size
        for (i, z) in idx.enumerated() where i < stack.textures.count {
            if let cg = Self.image(from: runner.sliceBytes(z: z), width: n, height: n) {
                try? await stack.textures[i].replace(withImage: cg, options: .init(semantic: .color))
            }
        }
    }

    private static func image(from rgba: [UInt8], width: Int, height: Int) -> CGImage? {
        guard let provider = CGDataProvider(data: Data(rgba) as CFData) else { return nil }
        return CGImage(width: width, height: height,
                       bitsPerComponent: 8, bitsPerPixel: 32,
                       bytesPerRow: width * 4,
                       space: CGColorSpaceCreateDeviceRGB(),
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                       provider: provider, decode: nil,
                       shouldInterpolate: false, intent: .defaultIntent)
    }

    private static func texture(from rgba: [UInt8], width: Int, height: Int) -> TextureResource? {
        guard let cg = image(from: rgba, width: width, height: height) else { return nil }
        return try? TextureResource(image: cg, options: .init(semantic: .color))
    }
}
