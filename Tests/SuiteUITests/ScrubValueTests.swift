// ScrubValueTests.swift: the drag, snap, step and zoom rules behind ScrubField
// and ViewerStatusBar, plus a seeded fuzz run that every result stays in range
// and is never NaN. No SwiftUI here. macOS only.
import CoreGraphics
import SuiteUI
import Testing

@Test func dragMovesOneStepPerPoint() {
    #expect(ScrubValue.dragged(from: 50, by: 12, step: 1, in: 0...100) == 62)
    #expect(ScrubValue.dragged(from: 50, by: -7, step: 1, in: 0...100) == 43)
}

@Test func decimalStepsLandOnCleanDecimals() {
    #expect(ScrubValue.dragged(from: 0, by: 3, step: 0.1, in: -5...5) == 0.3)
    #expect(ScrubValue.dragged(from: 0.5, by: 7, step: 0.01, in: 0...1) == 0.57)
    #expect(ScrubValue.snapped(1.0000000000000002, to: 0.1, in: 0...10) == 1)
}

@Test func dragClampsToTheRange() {
    #expect(ScrubValue.dragged(from: 90, by: 500, step: 1, in: 0...100) == 100)
    #expect(ScrubValue.dragged(from: 10, by: -500, step: 1, in: 0...100) == 0)
}

@Test func dragSnapsToTheStepGrid() {
    #expect(ScrubValue.dragged(from: 12.3, by: 0, step: 1, in: 0...100) == 12)
    #expect(ScrubValue.dragged(from: 0, by: 2.6, step: 5, in: 0...100) == 15)
}

@Test func modifiersChangeTheSpeed() {
    #expect(ScrubValue.multiplier(shift: false, option: false) == 1)
    #expect(ScrubValue.multiplier(shift: true, option: false) == 10)
    #expect(ScrubValue.multiplier(shift: false, option: true) == 0.1)
    #expect(ScrubValue.multiplier(shift: true, option: true) == 0.1)
    #expect(ScrubValue.dragged(from: 0, by: 4, step: 1, multiplier: 10, in: 0...1000) == 40)
    #expect(ScrubValue.dragged(from: 1, by: 5, step: 1, multiplier: 0.1, in: 0...10) == 1.5)
}

@Test func badStepOrDistanceKeepsTheValueInRange() {
    for step in [0, -1, Double.nan, .infinity] {
        #expect(ScrubValue.dragged(from: 40, by: 10, step: step, in: 0...100) == 40)
    }
    #expect(ScrubValue.dragged(from: 40, by: .nan, step: 1, in: 0...100) == 40)
    #expect(ScrubValue.dragged(from: 40, by: .infinity, step: 1, in: 0...100) == 40)
    #expect(ScrubValue.dragged(from: .nan, by: 3, step: 1, in: 2...10) == 2)
    #expect(ScrubValue.dragged(from: 0, by: .greatestFiniteMagnitude, step: 10, in: 0...100) == 100)
}

@Test func defaultStepIsAPowerOfTenNearAHundredthOfTheRange() {
    #expect(ScrubValue.defaultStep(for: 0...100) == 1)
    #expect(ScrubValue.defaultStep(for: -180...180) == 1)
    #expect(ScrubValue.defaultStep(for: -5...5) == 0.1)
    #expect(ScrubValue.defaultStep(for: 0...1) == 0.01)
    #expect(ScrubValue.defaultStep(for: 1...4096) == 10)
    #expect(ScrubValue.defaultStep(for: 3...3) == 1)
    #expect(ScrubValue.defaultStep(for: -Double.greatestFiniteMagnitude...Double.greatestFiniteMagnitude) == 1)
}

@Test func zoomReadsAsAWholePercent() {
    #expect(ViewerZoom.percentText(1) == "100%")
    #expect(ViewerZoom.percentText(0.514) == "51%")
    #expect(ViewerZoom.percentText(4) == "400%")
    for bad in [0, -1, Double.nan, .infinity] { #expect(ViewerZoom.percentText(bad) == "–") }
    #expect(ViewerZoom.percentText(.greatestFiniteMagnitude) == "1000000%")
}

@Test func fitScaleFitsInsideTheInsetAndNeverZoomsIn() {
    let photo = CGSize(width: 1920, height: 1080)
    #expect(ViewerZoom.fitScale(artboard: photo, in: CGSize(width: 1088, height: 1000), inset: 64) == 0.5)
    #expect(ViewerZoom.fitScale(artboard: CGSize(width: 100, height: 100), in: CGSize(width: 1000, height: 1000)) == 1)
    #expect(ViewerZoom.fitScale(artboard: photo, in: CGSize(width: 100, height: 100)) == 0)
    #expect(ViewerZoom.fitScale(artboard: CGSize(width: 0, height: -5), in: CGSize(width: 200, height: 200), inset: 0) == 1)
    #expect(ViewerZoom.fitScale(artboard: photo, in: CGSize(width: CGFloat.nan, height: 500)) == 0)
}

@Test func seededFuzzDragStaysInRangeAndIsNeverNaN() {
    var rng = SplitMix(seed: 0x5C2B)
    let specials: [Double] = [0, -0.0, .nan, .infinity, -.infinity, .greatestFiniteMagnitude, .leastNonzeroMagnitude]
    for _ in 0..<5000 {
        let low = rng.double(in: -1e6...1e6)
        let range = low...(low + rng.double(in: 0...1e6))
        let pick = { (r: inout SplitMix, scale: Double) in
            r.next() % 8 == 0 ? specials[Int(r.next() % UInt64(specials.count))] : r.double(in: -scale...scale)
        }
        let start = pick(&rng, 1e7)
        let points = pick(&rng, 1e4)
        let step = pick(&rng, 100)
        let value = ScrubValue.dragged(
            from: start, by: points, step: step, multiplier: ScrubValue.multiplier(
                shift: rng.next() % 2 == 0, option: rng.next() % 3 == 0), in: range)
        #expect(!value.isNaN && range.contains(value), "start \(start) points \(points) step \(step) range \(range)")
        if !range.contains(value) { return }
    }
}

/// A small deterministic generator, so a failing fuzz case reproduces.
private struct SplitMix {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
    mutating func double(in range: ClosedRange<Double>) -> Double {
        range.lowerBound + Double(next() >> 11) / Double(1 << 53) * (range.upperBound - range.lowerBound)
    }
}
