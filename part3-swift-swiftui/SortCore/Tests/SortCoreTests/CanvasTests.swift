//
//  CanvasTests.swift
//  SortCoreTests
//
//  The premise of the whole series is that sorting restores the picture. If
//  that breaks, the app still runs and still looks busy, and the thing it is
//  demonstrating is gone. These tests exist because that exact bug shipped
//  twice: once in the 3D volume and once in the 2D canvas.
//

import XCTest
@testable import SortCore

final class CanvasTests: XCTestCase {

    func testSortingRestoresTheImage() {
        var canvas = PixelCanvas(width: 64, height: 48)
        let original = canvas.rendered()
        canvas.scramble()
        XCTAssertNotEqual(canvas.rendered(), original, "scramble did nothing")

        _ = RadixSortLSD().sort(&canvas)
        XCTAssertEqual(canvas.rendered(), original,
                       "a completed sort must reproduce the source image exactly")
        XCTAssertTrue(canvas.isSorted)
    }

    func testScrambleIsReproducible() {
        var a = PixelCanvas(width: 32, height: 32); a.scramble(seed: 42)
        var b = PixelCanvas(width: 32, height: 32); b.scramble(seed: 42)
        var c = PixelCanvas(width: 32, height: 32); c.scramble(seed: 43)
        XCTAssertEqual(a.order, b.order, "same seed must give the same permutation")
        XCTAssertNotEqual(a.order, c.order, "different seeds must differ")
    }

    func testCanvasFromSuppliedColors() {
        let colors: [UInt32] = (0 ..< 64).map { UInt32(0xFF00_0000 | $0) }
        var canvas = PixelCanvas(width: 8, height: 8, colors: colors, sourceName: "test")
        XCTAssertEqual(canvas.sourceName, "test")
        canvas.scramble()
        _ = QuickSort().sort(&canvas)
        XCTAssertEqual(canvas.rendered(), colors)
    }

    func testVolumeSortingRestoresTheStructure() {
        var vol = VoxelVolume(size: 16, structure: .gyroid)
        let filled = VoxelVolume.occupancy(vol.colors)
        XCTAssertGreaterThan(filled, 0, "the structure should not be empty")
        vol.scramble()
        _ = vol.withBuffer { RadixSortLSD().sort($0) }
        XCTAssertTrue(vol.isSorted)
        XCTAssertEqual(vol.order, (0 ..< UInt32(vol.count)).map { $0 })
    }

    func testEveryStructureProducesSomething() {
        for s in VoxelStructure.allCases {
            let v = VoxelVolume(size: 16, structure: s)
            XCTAssertGreaterThan(VoxelVolume.occupancy(v.colors), 0, "\(s) was empty")
        }
    }
}

final class CancelTests: XCTestCase {

    func testCancelStopsALongSort() {
        let n = 200_000                      // minutes of work if left alone
        var data = (0 ..< UInt32(n)).map { $0 }
        var rng = SplitMix64(seed: 5)
        for i in stride(from: n - 1, to: 0, by: -1) {
            data.swapAt(i, Int(rng.next() % UInt64(i + 1)))
        }

        let token = SortCancel()
        let finished = expectation(description: "sort returned")
        let start = ContinuousClock.now
        nonisolated(unsafe) var elapsed = 0.0

        data.withUnsafeMutableBufferPointer { buf in
            nonisolated(unsafe) let b = buf
            DispatchQueue.global().async {
                _ = NaiveBubbleSort().sort(b, cancel: token)
                let d = (ContinuousClock.now - start).components
                elapsed = Double(d.seconds) + Double(d.attoseconds) / 1e18
                finished.fulfill()
            }
            Thread.sleep(forTimeInterval: 0.3)
            token.cancel()
            wait(for: [finished], timeout: 20)
        }
        XCTAssertLessThan(elapsed, 5, "cancel did not interrupt the sort")
    }

    func testUncancelledSortStillCompletes() {
        var data: [UInt32] = [4, 2, 9, 1]
        _ = data.withUnsafeMutableBufferPointer { NaiveBubbleSort().sort($0, cancel: SortCancel()) }
        XCTAssertEqual(data, [1, 2, 4, 9])
    }
}

final class FormattingTests: XCTestCase {
    func testDurationUnitsSwitchAtTheRightBoundaries() {
        XCTAssertTrue(formatDuration(0.0005).hasSuffix("µs"))
        XCTAssertTrue(formatDuration(0.05).hasSuffix("ms"))
        XCTAssertTrue(formatDuration(2.5).hasSuffix("s"))
        XCTAssertTrue(formatDuration(95).contains("m"))
        XCTAssertEqual(formatDuration(0.0032), "3.20 ms")
    }
}
