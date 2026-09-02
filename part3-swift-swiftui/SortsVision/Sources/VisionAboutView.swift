//
//  VisionAboutView.swift
//  SortsVision
//
//  The same explanation the iOS app carries, sized for a vision window.
//

import SwiftUI
import SortCore

struct VisionAboutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    group("What you are watching", Explain.howItWorks)
                    group("In three dimensions", """
                    A picture is a grid of pixels, so its spatial equivalent is a grid of \
                    voxels. This cube holds 16,777,216 of them, which is 54 times the \
                    307,200 pixels the earlier parts of this series sorted. The same \
                    algorithms sort it without a single change: only the meaning of the \
                    index changes, from (x, y) to (x, y, z).
                    """)
                    group("Why it matters", Explain.whyItMatters)
                    group("Where this came from", Explain.credits)

                    Link("Read the series on \(Explain.blogTitle)", destination: Explain.seriesURL)
                        .font(.headline)
                }
                .padding(30)
                .frame(maxWidth: 620, alignment: .leading)
            }
            .navigationTitle("Sorting in Three Dimensions")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }

    private func group(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            Text(body).font(.subheadline).foregroundStyle(.secondary)
        }
    }
}
