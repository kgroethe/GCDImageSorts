//
//  SortVisualizerApp.swift
//  SortVisualizer
//
//  Part 3 of the GCDImageSorts series: the same sorting visualisation the
//  original PThreadSorts did in 2000, now in Swift and SwiftUI.
//

import SwiftUI

@main
struct SortVisualizerApp: App {
    var body: some Scene {
        WindowGroup {
            // -benchmark runs the suite and shows a results table, so device
            // timings can be captured without driving the normal UI.
            if Benchmark.requested {
                BenchmarkView()
            } else {
                ContentView()
            }
        }
        #if os(macOS)
        .defaultSize(width: 900, height: 720)
        #endif
    }
}
