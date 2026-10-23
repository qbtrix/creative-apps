// HaloFrameRateCommandTests.swift (frame-rates FR-8b, slice FR-halo): a 29.97 composition by command and on
// screen. `composition.set-frame-rate` sets one of the nine rates as one "Set Frame Rate" step and refuses any
// other; the header reads the exact rate ("29.97 fps"); and the movie clock times frame n at n x 1001 / 30000 s
// on a track whose timescale is a whole multiple of 30000, never at a rate rounded to 30. Linux and macOS.
@testable import HaloModel
import SuiteKernel
import Testing

@Suite struct HaloFrameRateCommandTests {
    static let ntsc = FrameRate(numerator: 30000, denominator: 1001)
    static let id = "composition.set-frame-rate"

    static func rate(_ num: Int, _ den: Int) -> JSONValue { .object(["num": .number(Double(num)), "den": .number(Double(den))]) }

    @Test func movieClockCountsByTheExactRate() throws {
        let clock = try #require(HaloMovieClock(Self.ntsc))
        #expect(clock.trackTimescale == 30000)
        let last = try #require(clock.time(ofFrame: 299))
        #expect(last.value == 299 * 1001 && last.timescale == 30000, "frame 299 isn't at 299 x 1001 / 30000 s")
        let end = try #require(clock.time(ofFrame: 300))
        #expect(end.value == 300_300 && end.timescale == 30000, "300 frames don't end at 10.01 s")
        let film = try #require(HaloMovieClock(FrameRate(whole: 24)))
        let two = try #require(film.time(ofFrame: 48))
        #expect(film.trackTimescale == 600 && two.value == 48 && two.timescale == 24)
        #expect(HaloMovieClock(FrameRate(numerator: 24000, denominator: 1001))?.trackTimescale == 24000)
        for rate in FrameRate.common {
            let each = try #require(HaloMovieClock(rate), "\(rate)")
            #expect(each.trackTimescale >= 600 && Int(each.trackTimescale) % rate.numerator == 0, "\(rate)")
        }
        #expect(clock.time(ofFrame: -1) == nil && clock.time(ofFrame: .max) == nil)
    }

    @Test func aPlanCarriesItsClock() throws {
        let comp = HaloComposition(id: "comp-1", name: "NTSC", width: 320, height: 180, frameRate: Self.ntsc, durationFrames: 300)
        let plan = try HaloRenderRules.plan(comp, HaloRenderSettings(format: .movie))
        #expect(plan.movieClock == HaloMovieClock(Self.ntsc))
    }

    @Test(arguments: [(FrameRate(numerator: 30000, denominator: 1001), "29.97 fps"),
                      (FrameRate(numerator: 24000, denominator: 1001), "23.976 fps"), (FrameRate(whole: 30), "30 fps")])
    func headerReadsTheExactRate(rate: FrameRate, text: String) {
        let comp = HaloComposition(id: "comp-1", name: "C", width: 320, height: 180, frameRate: rate, durationFrames: 300)
        #expect(comp.frameRateText == text)
        #expect(comp.headerDetails.last?.hasPrefix(text) == true)
    }

    @Test func setFrameRateRunsAsOneStep() throws {
        var project = HaloCommandCatalogTests.ballSelected()
        let outcome = try HaloProject.catalog.run(Self.id, params: Self.rate(30000, 1001), on: &project)
        #expect(outcome.undoStep == "Set Frame Rate" && project.history.undo.count == 1)
        #expect(outcome.result == Self.rate(30000, 1001))
        #expect(project.selectedComposition?.frameRate == Self.ntsc)
        #expect(project.selectedComposition?.frameRateText == "29.97 fps")
        project.undo()
        #expect(project.selectedComposition?.frameRate == FrameRate(whole: 24))
    }

    @Test func aRateOffTheListIsRefused() {
        var project = HaloCommandCatalogTests.ballSelected()
        let before = project
        #expect(throws: CatalogError.failed(id: Self.id, message: CompositionSettings.frameRateProblem)) {
            try HaloProject.catalog.run(Self.id, params: Self.rate(23, 1), on: &project)
        }
        #expect(project == before)
    }

    @Test func theSameRateIsNoStep() throws {
        var project = HaloCommandCatalogTests.ballSelected()
        let outcome = try HaloProject.catalog.run(Self.id, params: Self.rate(24, 1), on: &project)
        #expect(outcome.undoStep == nil && project.history.undo.isEmpty)
    }

    @Test func noCompositionIsUnavailable() {
        let project = HaloProject(services: .fake)
        let why = HaloProject.catalog.availability(Self.id, on: project).why
        #expect(why != nil && why == project.unavailableHelp(for: .duplicateComposition))
        #expect(HaloHeadless.catalog.ids.contains(Self.id))
    }
}
