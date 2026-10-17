// FlareReadoutHelpTests.swift: the timeline readouts say their units (#1844) and split into the current value and
// the total, so the view draws the current value in primary text and the total in secondary (#1859). On the bounce
// fixture (24 fps, 48 frames) at frame 47 the readouts stay "01:23 / 02:00" and "47 / 48", which journeys read;
// their tooltips say the timecode is seconds:frames and that frames count from 0.
import FlareCore
@testable import FlareModel
import Testing

private func bounce(at frame: Int) -> FlareWorkspace {
    var w = FlareWorkspace(services: .fake())
    w.load(FlareFixtures.bounce)
    w.setCurrentFrame(frame)
    return w
}

@Test func timecodeHelpNamesSecondsFramesAndTheRate() throws {
    let w = bounce(at: 47)
    #expect(w.timecode == "01:23 / 02:00")
    let help = try #require(w.timecodeHelp)
    #expect(help.contains("seconds") && help.contains("frames") && help.contains("24 fps"))
    #expect(help.contains("1 second and 23 frames"))
    #expect(help.contains("2 seconds and 0 frames"))
}

@Test func frameReadoutHelpSaysFramesCountFromZero() throws {
    let w = bounce(at: 47)
    #expect(w.frameReadout == "47 / 48")
    let help = try #require(w.frameReadoutHelp)
    #expect(help.contains("Frame 47 of 48"))
    #expect(help.contains("count from 0"))
    #expect(help.contains("last frame is 47"))
}

@Test func readoutsSplitIntoCurrentAndTotal() throws {
    let w = bounce(at: 47)
    let timecode = try #require(w.timecodeParts)
    #expect(timecode.current == "01:23" && timecode.total == " / 02:00")
    #expect(timecode.current + timecode.total == w.timecode)
    let frame = try #require(w.frameReadoutParts)
    #expect(frame.current == "47" && frame.total == " / 48")
    #expect(frame.current + frame.total == w.frameReadout)
}

@Test func noTimelineMeansNoReadoutHelp() {
    let w = FlareWorkspace(services: .fake())
    #expect(w.timecodeHelp == nil && w.frameReadoutHelp == nil)
    #expect(w.timecodeParts == nil && w.frameReadoutParts == nil)
}
