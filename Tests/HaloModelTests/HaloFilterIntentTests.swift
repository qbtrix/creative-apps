// HaloFilterIntentTests.swift (adjust-everywhere AJ-13): the FILTERS section's gestures on the selected layer:
// Add puts one entry on at its start, a slider drag is one step clamped to its range that keeps the other
// values, hide, remove and move are a step each, no gesture touches another layer, and with nothing to filter
// nothing changes.
@testable import HaloModel
import SuiteImaging
import SuiteKernel
import Testing

@Suite struct HaloFilterIntentTests {
    static let ball = "comp-1-layer-2", floor = "comp-1-layer-1"

    static func selected(_ id: String = ball) -> HaloProject {
        var project = commandProject("keyed", .fake)
        project.selectLayer(id)
        return project
    }

    static func filters(_ project: HaloProject, _ id: String) -> [HaloLayerFilter] {
        project.selectedComposition?.layers.first { $0.id == id }?.filters ?? []
    }

    @Test func addPutsOneEntryOnAtItsStart() {
        var project = Self.selected()
        let before = project.history.undo.count
        project.runFilter(.add("gaussian-blur"))
        project.runFilter(.add("gaussian-blur"))
        project.runFilter(.add("invert"))
        #expect(project.layerFilters.map(\.step) == [.filter(.gaussianBlur(radius: 2)), .kind(.invert)])
        #expect(project.history.undo.count == before + 2)
    }

    @Test func aDragIsOneStepClampedAndKeepsTheOtherValues() {
        var project = Self.selected()
        project.runFilter(.add("sharpen"))
        let before = project.history.undo.count
        for v in [20.0, 140, 900] { project.runFilter(.value("sharpen", slider: "amount", v, drag: "d1")) }
        #expect(project.layerFilters.first?.step == .filter(.sharpen(amount: 500, radius: 1, threshold: 0)))
        #expect(project.history.undo.count == before + 1)
        project.runFilter(.value("sharpen", slider: "radius", 6, drag: "d2"))
        #expect(project.layerFilters.first?.values == ["amount": 500, "radius": 6, "threshold": 0])
        #expect(project.history.undo.count == before + 2)
    }

    @Test func noGestureTouchesAnotherLayer() {
        var project = Self.selected()
        project.runFilter(.add("gaussian-blur"))
        project.runFilter(.value("gaussian-blur", slider: "radius", 6, drag: nil))
        project.runFilter(.hide("gaussian-blur", true))
        #expect(Self.filters(project, Self.floor).isEmpty)
        #expect(Self.filters(project, Self.ball) == [HaloLayerFilter(.filter(.gaussianBlur(radius: 6)), hidden: true)])
    }

    @Test func removeAndMoveChangeTheList() {
        var project = Self.selected()
        for id in ["gaussian-blur", "sharpen", "black-and-white"] { project.runFilter(.add(id)) }
        project.runFilter(.move("black-and-white", to: 0))
        #expect(project.layerFilters.map(\.id) == ["black-and-white", "gaussian-blur", "sharpen"])
        project.runFilter(.move("black-and-white", to: 9))
        #expect(project.layerFilters.map(\.id) == ["gaussian-blur", "sharpen", "black-and-white"])
        project.runFilter(.remove("sharpen"))
        #expect(project.layerFilters.map(\.id) == ["gaussian-blur", "black-and-white"])
        #expect(project.history.undo.last?.name == "Remove Filter")
    }

    @Test func nothingChangesWithoutALayer() {
        var project = HaloProject(services: .fake)
        let before = project
        project.runFilter(.add("gaussian-blur"))
        project.runFilter(.value("gaussian-blur", slider: "radius", 6, drag: nil))
        #expect(project == before && project.layerFilters.isEmpty)
    }

    @Test func aKindHasNoSliders() {
        let entry = HaloLayerFilter(.kind(.invert))
        #expect(entry.values.isEmpty && entry.setting("amount", to: 1) == nil)
        #expect(HaloLayerFilter(.filter(.gaussianBlur(radius: 2))).setting("amount", to: 1) == nil)
    }
}
