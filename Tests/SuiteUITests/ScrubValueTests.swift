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

/// #591: a log10 track over 0.1...10 whose value snaps a band of four steps
/// either side of the middle to exactly 1, and whose `stepped` jumps out of
/// that band, so one arrow from 1 leaves it and one back lands on exactly 1.
@Test func aTracksSteppedLeavesTheDetentAndComesBackToOne() {
    let detent = 0.04
    let track = ScrubTrack(
        positions: -1...1, step: 0.01, position: { log10($0) }, value: { abs($0) <= detent ? 1 : pow(10, $0) },
        stepped: { position, delta in
            position == 0 && abs(delta) <= detent ? (delta > 0 ? detent : -detent) + delta : position + delta
        })
    let up = ScrubValue.pressed(.increment, from: track.position(1), on: track)
    #expect(track.value(up) != 1)
    #expect(abs(up - 0.05) < 1e-12)
    #expect(track.value(ScrubValue.pressed(.decrement, from: up, on: track)) == 1)
    let down = ScrubValue.pressed(.decrement, from: track.position(1), on: track)
    #expect(track.value(down) < 1)
    #expect(ScrubValue.pressed(.home, from: up, on: track) == -1)
    #expect(ScrubValue.pressed(.end, from: up, on: track) == 1)
    // Shift folds ten steps into the delta the track receives; the result stays on the track.
    #expect(abs(ScrubValue.pressed(.increment, from: 0, shift: true, on: track) - 0.1) < 1e-12)
    #expect(ScrubValue.pressed(.increment, from: 0.99, shift: true, on: track) == 1)
}

/// The track's TrackStepping face is its closures; with no `stepped` it steps
/// as ScrubValue.pressed does.
@Test func aTrackConformsToTrackStepping() {
    let track: any TrackStepping = ScrubTrack(
        positions: -1...1, step: 0.01, position: { log10($0) }, value: { pow(10, $0) })
    #expect(track.position(of: 10) == 1)
    #expect(track.value(at: -1) == 0.1)
    #expect(track.stepped(0.5, by: 0.1) == 0.6)
    let custom: any TrackStepping = ScrubTrack(
        positions: 0...1, step: 0.1, position: { $0 }, value: { $0 }, stepped: { _, _ in 0.25 })
    #expect(custom.stepped(0.5, by: 0.1) == 0.25)
}

/// `stepped: nil` keeps today's result for every key, modifier and start.
@Test func aTrackWithNoSteppedStepsAsToday() {
    let keys: [ScrubKey] = [.increment, .decrement, .home, .end]
    for (step, positions) in [(0.01, -1.0...1.0), (1, -180...180), (0.1, -5...5), (0, 0...10), (.nan, 0...10)] {
        let track = ScrubTrack(positions: positions, step: step, position: { $0 }, value: { $0 })
        for key in keys {
            for (shift, option) in [(false, false), (true, false), (false, true), (true, true)] {
                for start in [positions.lowerBound, 0.37, 0, 4.5, positions.upperBound, .nan, 1e9] {
                    let today = ScrubValue.pressed(
                        key, from: start, step: step, shift: shift, option: option, in: positions)
                    let now = ScrubValue.pressed(key, from: start, shift: shift, option: option, on: track)
                    #expect(now == today, "\(key) from \(start) step \(step) shift \(shift) option \(option)")
                }
            }
        }
    }
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
