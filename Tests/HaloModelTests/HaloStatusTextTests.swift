// HaloStatusTextTests.swift: the inspector header lines and the viewer status
// bar's timecode line (timecode and frame, then the total), exact for a 1920×1080, 30 fps, 10 s composition, and
// trap-free at the edges. Runs on Linux and macOS.
@testable import HaloModel
import Testing

private func composition(width: Int = 1920, height: Int = 1080, fps: Int = 30, seconds: Double = 10) -> HaloComposition {
    var project = HaloProject()
    project.newComposition(
        CompositionSettings(name: "Intro", width: width, height: height, framesPerSecond: fps, durationSeconds: seconds))
    return project.compositions[0]
}

@Test func headerAndStatusTextForTenSecondsAt30() {
    let comp = composition()
    #expect(comp.headerDetails == ["1920 × 1080", "30 fps · 10 s"])
    #expect(comp.sizeText == "1920 × 1080")
    #expect(comp.frameRateText == "30 fps")
    #expect(comp.durationText == "10 s")
    #expect(comp.statusTimecode == "00:00:00:00 · frame 0 / 10 s at 30 fps")
}

@Test func statusTimecodeFollowsThePlayhead() {
    var project = HaloProject()
    project.newComposition()
    project.scrub(to: 45)
    #expect(project.selectedComposition?.statusTimecode == "00:00:01:15 · frame 45 / 10 s at 30 fps")
}

@Test(arguments: [(2.5, "2.5 s"), (10.03, "10.03 s"), (0.04, "0.03 s"), (86_400, "86400 s")] as [(Double, String)])
func fractionalDurationsKeepTwoDecimals(seconds: Double, text: String) {
    #expect(composition(fps: 30, seconds: seconds).durationText == text)
}

@Test func oneFpsAndTheLargestSizeFormatWithoutTrapping() {
    let slow = HaloComposition(id: "c", name: "Slow", width: 1, height: 1, framesPerSecond: 1, durationFrames: 7)
    #expect(slow.headerDetails == ["1 × 1", "1 fps · 7 s"])
    #expect(slow.statusTimecode == "00:00:00:00 · frame 0 / 7 s at 1 fps")
    let largest = CompositionSettings.sizeRange.upperBound
    var project = HaloProject()
    project.newComposition(
        CompositionSettings(
            name: "Day", width: largest, height: largest, framesPerSecond: 60,
            durationSeconds: CompositionSettings.maxDurationSeconds))
    project.scrub(to: .max)
    let big = project.compositions[0]
    #expect(big.sizeText == "8192 × 8192")
    #expect(big.statusTimecode == "23:59:59:59 · frame 5183999 / 86400 s at 60 fps")
}

@Test func aNonPositiveRateReadsAsTheStart() {
    let broken = HaloComposition(id: "c", name: "Broken", width: 10, height: 10, framesPerSecond: 0, durationFrames: 30)
    #expect(broken.durationText == "0 s")
    #expect(broken.statusTimecode == "00:00:00:00 · frame 0 / 0 s at 0 fps")
}

/// The readout names the frame after the timecode, so it matches the ruler,
/// and splits into the current part (primary) and the total (secondary).
@Test func statusReadoutNamesTheFrameAndSplitsCurrentFromTotal() throws {
    var project = HaloProject(services: .fake)
    project.restore(try #require(HaloFixtures.project("three-layers")))
    project.scrub(to: 20)
    let comp = try #require(project.selectedComposition)
    #expect(comp.statusTimecode.hasPrefix("00:00:00:20"))
    #expect(comp.statusTimecode.contains("frame 20"))
    #expect(comp.statusPlayheadText == "00:00:00:20 · frame 20")
    #expect(comp.statusLengthText == " / 3 s at 24 fps")
    #expect(comp.statusTimecode == comp.statusPlayheadText + comp.statusLengthText)
}
