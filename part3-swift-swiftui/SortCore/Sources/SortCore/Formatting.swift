//
//  Formatting.swift
//  SortCore
//
//  Shared duration formatting, so every surface reads the same way.
//
//  The spread here is enormous: radix finishes 307K pixels in about 3 ms while
//  bubble sort takes 94 seconds on the same data. Printing both as seconds
//  renders the fast half as "0.003 s", which reads as zero and throws away the
//  most interesting part of the comparison.
//

import Foundation

public func formatDuration(_ seconds: Double) -> String {
    if seconds < 0.001 {
        return String(format: "%.0f µs", seconds * 1_000_000)
    } else if seconds < 1 {
        return String(format: "%.2f ms", seconds * 1000)
    } else if seconds < 60 {
        return String(format: "%.2f s", seconds)
    } else {
        let m = Int(seconds) / 60
        return String(format: "%dm %.1fs", m, seconds - Double(m * 60))
    }
}
