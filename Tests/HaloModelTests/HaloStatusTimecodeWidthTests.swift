// HaloStatusTimecodeWidthTests.swift: the status bar's timecode pill is sized
// to `statusTimecodeWidest`, the last frame's line, so no playhead the
// composition can reach reads longer and a playing timecode never changes the
// status row's width (the transport keeps one identity while it plays, #4586).
// Runs on Linux and macOS.
@testable import HaloModel
import Testing

private func project(fps: Int, seconds: Double) -> HaloProject {
    var project = HaloProject()
    project.newComposition(
        CompositionSettings(name: "Intro", width: 1920, height: 1080, framesPerSecond: fps, durationSeconds: seconds))
    return project
}

@Test func widestTimecodeIsTheLastFramesLine() {
    var tenSeconds = project(fps: 30, seconds: 10)
    #expect(tenSeconds.selectedComposition?.statusTimecodeWidest == "00:00:09:29 · frame 299")
    tenSeconds.scrub(to: 45)
    #expect(tenSeconds.selectedComposition?.statusTimecodeWidest == "00:00:09:29 · frame 299", "the playhead moves nothing")
}

@Test(arguments: [(24, 3.0), (30, 10.0), (25, 4.0)] as [(Int, Double)])
func noPlayheadReadsLongerThanTheWidest(fps: Int, seconds: Double) {
    var project = project(fps: fps, seconds: seconds)
    guard let widest = project.selectedComposition?.statusTimecodeWidest,
          let last = project.selectedComposition?.lastFrame else { return #expect(Bool(false), "no composition") }
    for frame in 0...last {
        project.scrub(to: frame)
        let line = project.selectedComposition?.statusTimecode ?? ""
        #expect(line.count <= widest.count, "frame \(frame) reads \(line), longer than \(widest)")
    }
}

@Test func aOneFrameCompositionsWidestIsFrameZero() {
    let one = HaloComposition(id: "c", name: "One", width: 1, height: 1, framesPerSecond: 24, durationFrames: 1)
    #expect(one.statusTimecodeWidest == one.statusTimecode)
    #expect(one.statusTimecodeWidest == "00:00:00:00 · frame 0")
}
