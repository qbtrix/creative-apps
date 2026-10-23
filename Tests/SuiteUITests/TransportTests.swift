// TransportTests.swift: SuiteTransport, the transport capsule's live rule
// (EC-5b). A step clamps with Loop off and wraps with it on, never overflows,
// and pauses; nothing moves when nothing can play; the timecode reads
// seconds:frames with its spoken tooltip and never divides by a rate of 0.
// No SwiftUI. macOS only.
import SuiteUI
import Testing

private let rule = SuiteTransport()

@Test func stepClampsAtTheEndWithLoopOffAndWrapsWithItOn() {
    #expect(rule.stepped(TransportState(frame: 47, frameCount: 48, fps: 24), by: 1).frame == 47)
    #expect(rule.stepped(TransportState(frame: 47, frameCount: 48, fps: 24, loops: true), by: 1).frame == 0)
    #expect(rule.stepped(TransportState(frame: 0, frameCount: 48, fps: 24, loops: true), by: -1).frame == 47)
    #expect(rule.stepped(TransportState(frame: 0, frameCount: 48, fps: 24), by: -1).frame == 0)
    #expect(rule.stepped(TransportState(frame: 10, frameCount: 48, fps: 24), by: 2).frame == 12)
}

@Test func hugeStepsClampAndWrapWithoutOverflow() {
    let middle = TransportState(frame: 40, frameCount: 48, fps: 24)
    #expect(rule.stepped(middle, by: .max).frame == 47)
    #expect(rule.stepped(middle, by: .min).frame == 0)
    var looping = middle
    looping.loops = true
    // Int.max % 48 is 31, so 40 + 31 wraps to 23; Int.min % 48 is -32, so 40 - 32 is 8.
    #expect(rule.stepped(looping, by: .max).frame == 23)
    #expect(rule.stepped(looping, by: .min).frame == 8)
}

@Test func aStepPauses() {
    let playing = TransportState(frame: 3, frameCount: 48, fps: 24, isPlaying: true)
    let next = rule.stepped(playing, by: 1)
    #expect(next.frame == 4)
    #expect(next.isPlaying == false)
}

@Test func startAndEndGoToTheFirstAndLastFrame() {
    let s = TransportState(frame: 12, frameCount: 48, fps: 24, loops: true)
    #expect(rule.toStart(s).frame == 0)
    #expect(rule.toEnd(s).frame == 47)
}

@Test func nothingToPlayChangesNothing() {
    let empty = TransportState(frame: 0, frameCount: 0, fps: 24, isPlaying: true, loops: true)
    #expect(rule.face(empty).unavailableHelp == "Nothing to play.")
    #expect(rule.face(empty).timecodeHelp == nil)
    #expect(rule.stepped(empty, by: 1) == empty)
    #expect(rule.stepped(empty, by: -1) == empty)
    #expect(rule.toStart(empty) == empty)
    #expect(rule.toEnd(empty) == empty)
}

@Test func timecodeReadsSecondsAndFrames() {
    let face = rule.face(TransportState(frame: 36, frameCount: 48, fps: 24))
    #expect(face.timecode == "01:12 / 02:00")
    #expect(face.timecodeHelp == "Seconds:frames at 24 fps: 1 second and 12 frames of 2 seconds and 0 frames.")
    #expect(face.unavailableHelp == nil)
    #expect(face.playTitle == "Play")
    let one = rule.face(TransportState(frame: 25, frameCount: 300, fps: 24, isPlaying: true))
    #expect(one.timecode == "01:01 / 12:12")
    #expect(one.timecodeHelp == "Seconds:frames at 24 fps: 1 second and 1 frame of 12 seconds and 12 frames.")
    #expect(one.playTitle == "Pause")
}

@Test func aRateOfZeroShowsDashesWithoutDividing() {
    let still = TransportState(frame: 3, frameCount: 48, fps: 0)
    let face = rule.face(still)
    #expect(face.timecode == "--:-- / --:--")
    #expect(face.timecodeHelp == nil)
    #expect(face.unavailableHelp == "No frame rate to play at.")
    #expect(rule.stepped(still, by: 1) == still)
}
