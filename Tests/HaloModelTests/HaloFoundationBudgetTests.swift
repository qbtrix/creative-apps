// HaloFoundationBudgetTests.swift: HB-9 (blueprint 7.1), any edit: `edit`'s
// copy, compare and record on `crowd` (300 layers, 5,000 keys) stays under
// 2 ms on a device and 20 ms in debug CI. Runs on Linux and macOS.
@testable import HaloModel
import Testing

struct HaloFoundationBudgetTests {
    @Test func editRecord() throws {
        let crowd = try #require(HaloFixtures.project("crowd"))
        var project = HaloProject(services: .fake)
        project.restore(crowd)
        project.selectLayer(crowd.compositions.first?.layers.first?.id ?? "")
        let budget = haloBudget(device: 2)
        var opacity = 0.0
        let cost = haloP95("editRecord", budget: budget) {
            opacity = opacity == 0 ? 1 : 0
            project.setSelectedLayerOpacity(opacity)
        }
        #expect(cost <= budget)
        #expect(project.history.undo.count == project.services.history.limit)
        #expect(project.history.undo.last?.name == "Change Opacity")
    }
}
