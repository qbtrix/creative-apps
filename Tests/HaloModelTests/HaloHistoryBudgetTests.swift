// HaloHistoryBudgetTests.swift: HB-8 (blueprint 7.1). One `undo()` or
// `redo()` on `crowd` (300 layers, 5,000 keys) stays under 2 ms on a device
// and 20 ms in debug CI, with W0's `HaloBudget` helper. Runs on Linux and macOS.
import HaloModel
import Testing

struct HaloHistoryBudgetTests {
    @Test func undoStep() throws {
        let crowd = try #require(HaloFixtures.project("crowd"))
        var start = HaloProject(services: .live, document: crowd)
        start.selectLayer(crowd.compositions.first?.layers.first?.id ?? "")
        let selected = start.document
        start.setSelectedLayerOpacity(0.5)
        var project = start
        let budget = haloBudget(device: 2)
        let undoCost = haloP95("undoCrowd", budget: budget) {
            project = start
            project.undo()
        }
        #expect(undoCost <= budget)
        #expect(project.document == selected)
        #expect(project.redoTitle == "Redo Change Opacity")

        let undone = project
        let redoCost = haloP95("redoCrowd", budget: budget) {
            project = undone
            project.redo()
        }
        #expect(redoCost <= budget)
        #expect(project.selectedLayer?.opacity == 0.5)
        #expect(project.undoTitle == "Undo Change Opacity")
    }
}
