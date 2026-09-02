//
//  ContentView.swift
//  SortVisualizer
//
//  One sort at a time, chosen from a picker, with the measured result kept
//  underneath. The Mac version in Parts 1 and 2 opened nine windows at once,
//  which is not a thing a phone can do, so the race became a table.
//

import SwiftUI
import SortCore

struct ContentView: View {
    @State private var runner = SortRunner()
    @State private var showAbout = false

    /// Launch with -autosort to start a run on appear. Used for screenshots and
    /// for driving the app from a test without tapping anything.
    private var autoSort: Bool { CommandLine.arguments.contains("-autosort") }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                canvas
                controls
                Divider()
                resultsList
            }
            .navigationTitle("Pixel Sorts")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showAbout = true } label: { Image(systemName: "info.circle") }
                        .accessibilityLabel("About")
                }
            }
            .sheet(isPresented: $showAbout) { AboutView() }
            .task {
                guard autoSort else { return }
                if let raw = value(forFlag: "-algorithm"),
                   let choice = Algorithm(rawValue: raw) {
                    runner.algorithm = choice
                }
                runner.start()
            }
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
    }

    private var canvas: some View {
        ZStack {
            Rectangle().fill(.black)
            if let image = runner.image {
                Image(decorative: image, scale: 1, orientation: .up)
                    .interpolation(.none)          // the subject is pixels
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(4.0 / 3.0, contentMode: .fit)
        .clipped()
    }

    private var controls: some View {
        VStack(spacing: 12) {
            HStack {
                Picker("Algorithm", selection: $runner.algorithm) {
                    ForEach(Algorithm.allCases) { a in
                        Text(a.title).tag(a)
                    }
                }
                .pickerStyle(.menu)
                .disabled(runner.isRunning)

                Spacer()

                Picker("Size", selection: $runner.size) {
                    ForEach(CanvasSize.all) { s in
                        Text(s.label).tag(s)
                    }
                }
                .pickerStyle(.menu)
                .disabled(runner.isRunning)
            }

            HStack(spacing: 16) {
                Text(runner.sourceName)
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text(runner.algorithm.bigO)
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(runner.elapsed > 0 ? formatDuration(runner.elapsed) : "—")
                    .font(.system(.title3, design: .monospaced))
                    .monospacedDigit()
            }

            if let info = Explain.info(for: runner.algorithm.title) {
                Text(info.whatToWatch)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if runner.algorithm.isQuadratic && runner.size.punishesQuadratic {
                Label(String(format: "O(n²) on %.1fM pixels will take hours. Pick a smaller canvas or a better algorithm.", runner.size.megapixels), systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let error = runner.lastError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            ImageSourceControls(runner: runner)

            HStack {
                Button("Scramble") { runner.reset() }
                    .disabled(runner.isRunning)
                Spacer()
                if runner.isRunning {
                    Button("Cancel", role: .destructive) { runner.cancelSort() }
                        .buttonStyle(.bordered)
                } else {
                    Button("Sort") { runner.start() }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding()
    }

    private var resultsList: some View {
        Group {
            if runner.results.isEmpty {
                ContentUnavailableView("No runs yet",
                                       systemImage: "chart.bar",
                                       description: Text("Sort something and the timing lands here."))
            } else {
                List(runner.results) { r in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(r.algorithm).font(.headline)
                            if !r.verified {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.red)
                            }
                            Spacer()
                            Text(formatDuration(r.seconds))
                                .font(.system(.body, design: .monospaced))
                                .monospacedDigit()
                        }
                        Text("\(r.pixels) px · \(r.swaps) swaps · \(r.comparisons) comparisons")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .listStyle(.plain)
            }
        }
        .frame(maxHeight: 240)
    }
}

private func value(forFlag flag: String) -> String? {
    let args = CommandLine.arguments
    guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }
    return args[i + 1]
}
