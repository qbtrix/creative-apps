// HaloLayerEditsBudgetTests.swift: HB-9 (blueprint 7.1) for layer
// housekeeping: duplicating and deleting a layer on `crowd` (300 layers,
// 5,000 keys), each one `edit` step, stays under 2 ms on a device and 20 ms in
// debug CI, with W0's `HaloBudget` helper. Runs on Linux and macOS.
@testable import HaloModel
import Testing

struct HaloLayerEditsBudgetTests {
    /// `crowd` on `.fake` with its top layer selected.
    private func crowd() throws -> HaloProject {
        let crowd = try #require(HaloFixtures.project("crowd"))
        var project = HaloProject(services: .fake)
        project.restore(crowd)
        project.selectLayer(crowd.compositions.first?.layers.first?.id ?? "")
        return project
    }

    @Test func duplicateCrowd() throws {
        let start = try crowd()
        var project = start
        let budget = haloBudget(device: 2)
        let cost = haloP95("duplicateCrowd", budget: budget) {
            project = start
            project.duplicateSelectedLayer()
        }
        #expect(cost <= budget)
        #expect(project.selectedComposition?.layers.count == (start.selectedComposition?.layers.count ?? 0) + 1)
        #expect(project.history.undoTitle == "Undo Duplicate Layer")
    }

    @Test func deleteCrowd() throws {
        let start = try crowd()
        var project = start
        let budget = haloBudget(device: 2)
        let cost = haloP95("deleteCrowd", budget: budget) {
            project = start
            project.deleteSelectedLayer()
        }
        #expect(cost <= budget)
        #expect(project.selectedComposition?.layers.count == (start.selectedComposition?.layers.count ?? 0) - 1)
        #expect(project.history.undoTitle == "Undo Delete Layer")
    }
}
