//
//  BenchmarkView.swift
//  SortVisualizer
//
//  Results table for the on-device benchmark. Deliberately plain: this exists
//  to be read off a phone screen and screenshotted into a blog post.
//

import SwiftUI
import SortCore

struct BenchmarkView: View {
    @State private var bench = Benchmark()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(bench.header.isEmpty ? "starting…" : bench.header)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text(Benchmark.deviceModel())
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                if let c = bench.current {
                    Section { Label("running \(c)", systemImage: "timer").font(.caption) }
                }
                if let f = bench.frame {
                    Section {
                        Image(decorative: f, scale: 1, orientation: .up)
                            .interpolation(.none).resizable()
                            .aspectRatio(4.0/3.0, contentMode: .fit)
                    }
                }
                Section("Results") {
                    ForEach(bench.results) { r in
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(r.name).font(.subheadline)
                                Text(r.bigO)
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if !r.verified {
                                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
                            }
                            Text(formatDuration(r.seconds))
                                .font(.system(.body, design: .monospaced))
                                .monospacedDigit()
                        }
                    }
                }
            }
            .navigationTitle(bench.running ? "Benchmarking…" : "Benchmark")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
        .task { bench.run() }
    }
}
