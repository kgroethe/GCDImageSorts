//
//  PixelSorter.swift
//  SortCore
//
//  The contract every algorithm implements. In the Objective-C++ version this
//  was a virtual Sort() on a class that also owned the window; here it is a
//  protocol over a plain buffer.
//

import Foundation

/// Work counters, kept so the Swift and Objective-C++ builds can be compared on
/// operations performed and not only on wall-clock time.
public struct SortStats: Sendable, Equatable {
    public var swaps: UInt64 = 0
    public var comparisons: UInt64 = 0
    public init() {}
}

public protocol PixelSorter: Sendable {
    /// Display name, matching the window titles used in Parts 1 and 2.
    static var name: String { get }
    /// Complexity, shown in the UI beside the name.
    static var bigO: String { get }
    /// Sorts the buffer in place and reports the work done.
    ///
    /// A cancel token, if given, is polled in the outer loop. A cancelled sort
    /// returns early and leaves the buffer partly ordered, which the caller must
    /// treat as unsorted rather than as a result.
    func sort(_ buffer: UnsafeMutableBufferPointer<UInt32>, cancel: SortCancel?) -> SortStats
}

public extension PixelSorter {
    /// Uncancellable form, for benchmarks and tests.
    func sort(_ buffer: UnsafeMutableBufferPointer<UInt32>) -> SortStats {
        sort(buffer, cancel: nil)
    }

    /// Convenience for callers holding a canvas rather than a raw buffer.
    func sort(_ canvas: inout PixelCanvas, cancel: SortCancel? = nil) -> SortStats {
        canvas.withBuffer { self.sort($0, cancel: cancel) }
    }
}
