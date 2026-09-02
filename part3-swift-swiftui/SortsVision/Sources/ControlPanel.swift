//
//  ControlPanel.swift
//  SortsVision
//
//  The 2D window that drives the immersive scene.
//

import SwiftUI
import SortCore

struct ControlPanel: View {
    @Environment(VolumeRunner.self) private var runner
    @Environment(\.openImmersiveSpace) private var openSpace
    @Environment(\.dismissImmersiveSpace) private var dismissSpace
    @State private var spaceOpen = false
    @State private var showAbout = false

    var body: some View {
        @Bindable var runner = runner
        VStack(spacing: 18) {
            Text("Sorting in Three Dimensions")
                .font(.title3.weight(.semibold))
            Text(runner.isPreparing
                 ? "Building \(runner.size) × \(runner.size) × \(runner.size) …"
                 : "\(runner.size) × \(runner.size) × \(runner.size) = \(runner.voxelCountText) voxels. Scramble the structure, then sort it back.")
                .font(.caption).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                Picker("Subject", selection: $runner.subject) {
                    ForEach(Subject.all) { Text($0.label).tag($0) }
                }
                Picker("Algorithm", selection: $runner.algorithm) {
                    ForEach(VolumeAlgorithm.allCases) { Text($0.title).tag($0) }
                }
            }
            .pickerStyle(.menu)
            .disabled(runner.isRunning)

            HStack(spacing: 14) {
                Button("Scramble") { runner.reset() }.disabled(runner.isRunning || runner.isPreparing)
                Button(runner.isRunning ? "Sorting…" : "Sort") { runner.start() }
                    .buttonStyle(.borderedProminent).disabled(runner.isRunning || runner.isPreparing)
                Text(formatDuration(runner.elapsed))
                    .font(.system(.title3, design: .monospaced)).monospacedDigit()
            }

            Button("What am I looking at?") { showAbout = true }
                .buttonStyle(.bordered)

            Button(spaceOpen ? "Leave Immersive Space" : "Enter Immersive Space") {
                Task {
                    if spaceOpen {
                        await dismissSpace(); spaceOpen = false
                    } else {
                        if case .opened = await openSpace(id: "space") { spaceOpen = true }
                    }
                }
            }

            if let info = Explain.info(for: runner.algorithm.title) {
                Text(info.whatToWatch)
                    .font(.caption).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 460)
            }

            if let n = runner.importNote {
                Text(n).font(.caption2).foregroundStyle(.secondary)
            }
            if let r = runner.lastResult {
                Text(r).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(28)
        .sheet(isPresented: $showAbout) { VisionAboutView() }
        .task {
            // Opening straight away can land before the scene is ready, so give
            // it a few attempts rather than silently staying in passthrough.
            for attempt in 1 ... 5 {
                if spaceOpen { return }
                let result = await openSpace(id: "space")
                switch result {
                case .opened:
                    spaceOpen = true
                    NSLog("SORTS3D immersive space opened on attempt \(attempt)")
                    return
                case .error:
                    NSLog("SORTS3D immersive open ERROR on attempt \(attempt)")
                case .userCancelled:
                    NSLog("SORTS3D immersive open cancelled on attempt \(attempt)")
                    return
                @unknown default:
                    NSLog("SORTS3D immersive open unknown result")
                }
                try? await Task.sleep(for: .milliseconds(600))
            }
        }
    }
}
