// HaloEasingBudgetTests.swift: HB-7 (blueprint 7.1) for easing (EZ-4, #428)
// on `reference` (50 layers, 4,000 keys), over `.fake` and `.live` services,
// with W0's `HaloBudget` helper (the quietest p95 of three rounds of 100
// runs). An easing chip step, `setEasing(_:)` on two picked keys of the first
// layer plus reading `keySegments`, stays under 1 ms on a device, ten times
// that in debug CI. Presets alternate so every run records a real step. Runs
// on Linux and macOS.
@testable import HaloModel
import Testing

private let easingBudgetServices: [String] = ["fake", "live"]

struct HaloEasingBudgetTests {
    /// `reference` on `.fake` or `.live`, its first layer selected.
    private func reference(_ name: String) throws -> HaloProject {
        var project = HaloProject(services: name == "live" ? .live : .fake)
        project.restore(try #require(HaloFixtures.project("reference")))
        let first = try #require(project.selectedComposition?.layers.first)
        project.selectLayer(first.id)
        return project
    }

    @Test(arguments: easingBudgetServices)
    func easingStep(services name: String) throws {
        var project = try reference(name)
        let segments = project.keySegments
        try #require(segments.count >= 2, "the first layer of reference has fewer than two segments")
        let picked = [segments[0].key, segments[1].key]
        project.selectKey(picked[0], extending: false)
        project.selectKey(picked[1], extending: true)
        #expect(project.pickedKeys == Set(picked))
        project.setEasing(.linear)
        let presets: [HaloEasingPreset] = [.easeIn, .easeOut]
        let budget = haloBudget(device: 1)
        var run = 0
        var rows: [HaloKeySegment] = []
        var applied = 0
        let cost = haloP95("easingStep-\(name)", budget: budget) {
            let preset = presets[run % 2]
            project.setEasing(preset)
            rows = project.keySegments
            if rows.filter(\.isPicked).allSatisfy({ $0.preset == preset }) { applied += 1 }
            run += 1
        }
        #expect(cost <= budget)
        #expect(run == 300)
        #expect(rows.count == segments.count)
        let last = presets[(run - 1) % 2]
        #expect(rows.filter(\.isPicked).map(\.preset) == [last, last])
        #expect(applied == run)
        #expect(project.history.undoTitle == "Undo Keyframe Easing")
    }
}
