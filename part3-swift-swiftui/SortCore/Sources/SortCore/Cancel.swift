//
//  Cancel.swift
//  SortCore
//
//  A way out of a sort that is going to run for hours.
//
//  Task.isCancelled is no use here: these are tight synchronous loops that
//  never suspend, so nothing would ever observe it. The flag is checked in the
//  outer loop of each algorithm, which runs O(n) times rather than O(n²), so
//  the cost is negligible against the work being done.
//

import Foundation

public final class SortCancel: @unchecked Sendable {
    private var flag = false
    private let lock = NSLock()

    public init() {}

    public func cancel() {
        lock.lock(); flag = true; lock.unlock()
    }

    public var isCancelled: Bool {
        lock.lock(); defer { lock.unlock() }
        return flag
    }
}
