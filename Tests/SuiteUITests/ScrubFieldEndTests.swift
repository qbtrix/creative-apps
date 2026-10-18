// ScrubFieldEndTests.swift: one gesture, one end, for ScrubField (#718,
// IC-2). A drag of several changes, a typed value and each key press end
// exactly once; a press at the range's end that changes nothing still ends
// once; a drag that changed nothing ends nothing. The public init takes
// `onEnd`, and the exact field's samples carry series `exact-field`.
// Mutating calls go into a local first: #expect can't call a mutating member.
// macOS only.
import SwiftUI
@testable import SuiteUI
import Testing

@Test func dragTypedCommitAndTwoKeyPressesGiveFourEnds() {
    var ends = ScrubEnds()
    var fired = 0
    var opened = 0
    for _ in 0..<3 where ends.changed() { opened += 1 }
    if ends.released() { fired += 1 }
    if ends.released() { fired += 1 }
    if ends.stepped() { fired += 1 }   // a typed value
    if ends.stepped() { fired += 1 }   // ↑
    if ends.stepped() { fired += 1 }   // ↓
    #expect(opened == 1)
    #expect(fired == 4)
    #expect(ends.ends == 4)
    #expect(!ends.isOpen)
}

@Test func pressAtTheRangeEndThatChangesNothingStillEndsOnce() {
    // ↑ at the top of the range: ScrubValue.pressed gives the same value back.
    #expect(ScrubValue.pressed(.increment, from: 100, step: 1, in: 0...100) == 100)
    var ends = ScrubEnds()
    let first = ends.stepped()
    let again = ends.released()
    #expect(first)
    #expect(!again)
    #expect(ends.ends == 1)
}

@Test func dragThatChangedNothingEndsNothing() {
    var ends = ScrubEnds()
    let released = ends.released()
    #expect(!released)
    #expect(ends.ends == 0)
}

@Test func publicInitTakesOnEnd() {
    let withEnd = ScrubField("X", value: 1, in: 0...10, unit: "pt", onChange: { _ in }, onEnd: {})
    let withoutEnd = ScrubField("Y", value: 1, in: 0...10) { _ in }
    _ = (withEnd, withoutEnd)
}

@Test func exactFieldSamplesCarryTheirSeries() {
    let sample = ScrubProbe.sample(eventTime: 1, shownAt: 1.01)
    #expect(sample == ProbeSample(series: "exact-field", eventTime: 1, shownAt: 1.01))
    var probe = FakeFrameProbe()
    probe.record(sample)
    #expect(probe.summary(of: "exact-field", refreshInterval: 1.0 / 60).count == 1)
}
