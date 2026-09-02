//
//  AboutView.swift
//  SortVisualizer
//
//  Explains what the app is showing, and where the longer story lives.
//

import SwiftUI
import SortCore

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("What you are watching") {
                    Text(Explain.howItWorks)
                }
                Section("Why it matters") {
                    Text(Explain.whyItMatters)
                }
                Section("The algorithms") {
                    ForEach(orderedInfo, id: \.name) { info in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(info.name).font(.headline)
                                Spacer()
                                Text(info.bigO)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                            Text(info.summary).font(.subheadline)
                            Text(info.whatToWatch).font(.caption).foregroundStyle(.secondary)
                            Text(info.verdict).font(.caption).foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 2)
                    }
                }
                Section("Where this came from") {
                    Text(Explain.credits)
                    Link("Read the series on \(Explain.blogTitle)", destination: Explain.seriesURL)
                }
            }
            .navigationTitle("About")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }

    /// Slowest to fastest, which is the order the story is told in.
    private var orderedInfo: [AlgorithmInfo] {
        ["BubbleSort", "Branchless BubbleSort", "SIMD Odd-Even", "Parallel Odd-Even",
         "Selection Sort", "Insertion Sort", "Shell Sort", "Heap Sort",
         "Merge Sort", "QuickSort", "GCD QuickSort", "RadixSort"]
            .compactMap { Explain.info(for: $0) }
    }
}
