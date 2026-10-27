// PhotoRetouchToolsTests.swift: fill-heal FH-3. The palette holds Paint
// Bucket, Spot Heal and Remove, disabled with their help until FH-8; G and J
// reach them first once they work; the bucket's options change and clamp.
import CoreRaster
@testable import PhotoModel
import Testing

@Suite struct PhotoRetouchToolsTests {
    @Test func theRetouchToolsAreOnThePaletteWithHelp() {
        let order = PhotoTool.allCases
        for tool in [PhotoTool.bucket, .spotHeal, .remove] {
            #expect(order.contains(tool))
            #expect(tool.unavailableHelp == PhotoTool.retouchHelp)
            #expect(PhotoWorkspace(services: .fake).toolHelp(tool) == PhotoTool.retouchHelp)
        }
        #expect(PhotoTool.spotHeal.rawValue == "spot-heal")
        // ToolKeys picks the first enabled tool with a key, so the new tools come first in their groups.
        #expect((order.firstIndex(of: .bucket) ?? 99) < (order.firstIndex(of: .gradient) ?? 0))
        #expect((order.firstIndex(of: .spotHeal) ?? 99) < (order.firstIndex(of: .heal) ?? 0))
        #expect((order.firstIndex(of: .heal) ?? 99) < (order.firstIndex(of: .remove) ?? 0))
    }

    @Test func aRetouchToolsDragChangesNothingYet() throws {
        for tool in [PhotoTool.bucket, .spotHeal, .remove] {
            var model = try PhotoWorkspace.fixture(.sample)
            model.selectTool(tool)
            let before = model
            model.drag(from: Mask.Point(x: 10, y: 10), to: Mask.Point(x: 40, y: 40), modifiers: [])
            model.endDrag()
            #expect(model.pixels == before.pixels)
            #expect(model.historySteps == before.historySteps)
            #expect(!model.dragPaintsOnly)
        }
    }

    @Test func theBucketsOptionsChangeAndClamp() {
        var model = PhotoWorkspace()
        #expect(model.bucketOptions.tolerance == 32)
        #expect(model.bucketOptions.contiguous && !model.bucketOptions.sampleAllLayers)
        model.setBucketOption(.tolerance(80))
        #expect(model.bucketOptions.tolerance == 80)
        model.setBucketOption(.tolerance(400))
        #expect(model.bucketOptions.tolerance == 255)
        model.setBucketOption(.tolerance(-3))
        #expect(model.bucketOptions.tolerance == 0)
        model.setBucketOption(.contiguous(false))
        #expect(!model.bucketOptions.contiguous)
        model.setBucketOption(.sampleAllLayers(true))
        #expect(model.bucketOptions.sampleAllLayers)
        #expect(model.bucketOptions.antiAlias)
        #expect(model.historySteps.isEmpty)
    }
}
