// HaloViewerBudgetTests.swift: HB-2, HB-5 and HB-11 (blueprint 7.1) for the
// viewer and playback (VP-6) on `reference` (50 layers, 4,000 keys), with
// W0's `HaloBudget` helper. HB-2: `drawList` on fake and live drawing (live
// placed by FakeLayerPlacing) under 2 ms on a device; HB-5: a scrub step
// (`scrub(to:)`, `timelineRows`, `viewerDrawList`) under 3 ms; HB-11: a
// playback tick (`tick(now:)`, `viewerDrawList`) under 2 ms. Ten times each
// in debug CI. Runs on Linux and macOS.
@testable import HaloModel
import Testing

struct HaloViewerBudgetTests {
    /// `reference` on `services`, its playhead at frame 0.
    private func reference(_ services: HaloServices = .fake) throws -> HaloProject {
        var project = HaloProject(services: services)
        project.restore(try #require(HaloFixtures.project("reference")))
        return project
    }

    @Test(arguments: ["fake", "live"])
    func drawList(drawing name: String) throws {
        var services = HaloServices.fake
        services.drawing = name == "live" ? LiveFrameDrawing(placing: FakeLayerPlacing()) : FakeFrameDrawing()
        let project = try reference(services)
        let comp = try #require(project.selectedComposition)
        let budget = haloBudget(device: 2)
        var frame = 0
        var drawn = 0
        let cost = haloP95("drawList-\(name)", budget: budget) {
            frame = (frame + 7) % comp.durationFrames
            drawn = services.drawing.drawList(comp, at: frame).items.count
        }
        #expect(cost <= budget)
        #expect(drawn > 0)
    }

    @Test func playheadScrubStep() throws {
        var project = try reference()
        let budget = haloBudget(device: 3)
        var frame = 0
        var rows = 0
        var drawn = 0
        let cost = haloP95("playheadScrubStep", budget: budget) {
            frame = (frame + 7) % 300
            project.scrub(to: frame)
            rows = project.timelineRows.count
            drawn = project.viewerDrawList?.items.count ?? 0
        }
        #expect(cost <= budget)
        #expect(rows == 50)
        #expect(drawn > 0)
        #expect(project.selectedComposition?.playheadFrame == frame)
    }

    @Test func playbackTick() throws {
        var project = try reference()
        project.setLoops(true)
        project.play(at: 0)
        let budget = haloBudget(device: 2)
        var now = 0.0
        var playing = false
        var drawn = 0
        let cost = haloP95("playbackTick", budget: budget) {
            now += 1.0 / 30
            playing = project.tick(now: now)
            drawn = project.viewerDrawList?.items.count ?? 0
        }
        #expect(cost <= budget)
        #expect(playing)
        #expect(drawn > 0)
        #expect(project.history.undoTitle == nil)
    }
}
