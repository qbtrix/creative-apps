// HaloKeysBudgetTests.swift: HB-1, HB-3 and HB-4 (blueprint 7.1) for
// layer-keys (LK-8) on `reference` (50 layers, 4,000 keys), over `.fake` and
// `.live` services, with W0's `HaloBudget` helper (the quietest p95 of three
// rounds of 100 runs). HB-1: a viewer drag step (`moveViewerDrag(to:)`,
// `viewerDrawList`) under 3 ms on a device; HB-3: `ViewerDragging.hit` under
// 1 ms; HB-4: an inspector scrub step (`setProperty(_:to:)` with `edit`'s copy
// and coalesced record, `propertyRows`) under 1 ms. Ten times each in debug
// CI. Runs on Linux and macOS.
@testable import HaloModel
import Testing

private let keysServices: [String] = ["fake", "live"]

struct HaloKeysBudgetTests {
    /// `reference` on `.fake` or `.live`, its playhead at frame 0.
    private func reference(_ name: String) throws -> HaloProject {
        var project = HaloProject(services: name == "live" ? .live : .fake)
        project.restore(try #require(HaloFixtures.project("reference")))
        return project
    }

    /// A point (composition pixels) over a drawn layer at the playhead: the
    /// box center of the first layer, top first, that `hit` finds there.
    private func hitPoint(_ project: HaloProject) throws -> HaloPoint {
        let comp = try #require(project.selectedComposition)
        let frame = comp.playheadFrame
        for layer in comp.layers {
            guard let world = HaloKeyRules.worldMatrix(of: layer.id, in: comp, at: frame) else { continue }
            let b = layer.bounds(in: comp)
            let center = world.apply(HaloPoint(x: b.x + b.width / 2, y: b.y + b.height / 2))
            if project.services.dragging.hit(comp, at: frame, point: center) != nil { return center }
        }
        return try #require(nil as HaloPoint?, "no layer of reference is hit at its center")
    }

    @Test(arguments: keysServices)
    func viewerDragStep(services name: String) throws {
        var project = try reference(name)
        let start = try hitPoint(project)
        project.beginViewerDrag(at: start)
        let dragged = try #require(project.viewerDrag?.layerID)
        let budget = haloBudget(device: 3)
        var step = 0.0
        var drawn = 0
        let cost = haloP95("viewerDragStep-\(name)", budget: budget) {
            step = step >= 200 ? 1 : step + 1
            project.moveViewerDrag(to: HaloPoint(x: start.x + step, y: start.y - step / 2))
            drawn = project.viewerDrawList?.items.count ?? 0
        }
        #expect(cost <= budget)
        #expect(drawn > 0)
        #expect(project.viewerDrag?.layerID == dragged)
        #expect(project.viewerDrag?.delta.x == step)
        #expect(project.history.undoTitle == nil)
    }

    @Test(arguments: keysServices)
    func hit(services name: String) throws {
        let project = try reference(name)
        let comp = try #require(project.selectedComposition)
        let point = try hitPoint(project)
        let dragging = project.services.dragging
        let budget = haloBudget(device: 1)
        var id: String?
        let cost = haloP95("hit-\(name)", budget: budget) {
            id = dragging.hit(comp, at: comp.playheadFrame, point: point)
        }
        #expect(cost <= budget)
        #expect(id != nil)
    }

    @Test(arguments: keysServices)
    func inspectorScrubStep(services name: String) throws {
        var project = try reference(name)
        let comp = try #require(project.selectedComposition)
        let animated = comp.layers.first { $0.tracks[HaloProperty.x.rawValue]?.isEmpty == false } ?? comp.layers.first
        project.selectLayer(try #require(animated).id)
        let budget = haloBudget(device: 1)
        var x = 0.0
        var rows = 0
        let cost = haloP95("inspectorScrubStep-\(name)", budget: budget) {
            x = x >= 500 ? 0 : x + 1
            project.setProperty(.x, to: x)
            rows = project.propertyRows.count
        }
        #expect(cost <= budget)
        #expect(rows == HaloProperty.allCases.count)
        #expect(project.propertyRows.first { $0.property == .x }?.value == x)
        #expect(project.history.undo.count == 1)
        #expect(project.history.undoTitle == "Undo Change \(HaloProperty.x.title)")
    }
}
