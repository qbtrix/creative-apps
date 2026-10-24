// PhotoRetouchToolsTests.swift: fill-heal FH-3, FH-8. The palette holds
// Paint Bucket, Spot Heal and Remove, enabled since FH-8 wired them to their
// commands; G and J reach them first; their drags act only on release, never
// on a live copy; the bucket's options change and clamp.
import CoreRaster
@testable import PhotoModel
import Testing

@Suite struct PhotoRetouchToolsTests {
    @Test func theRetouchToolsAreOnThePaletteAndEnabled() {
        let order = PhotoTool.allCases
        for tool in [PhotoTool.bucket, .spotHeal, .remove] {
            #expect(order.contains(tool))
            #expect(tool.unavailableHelp == nil && tool.isEnabled)
            #expect(PhotoWorkspace(services: .fake).toolHelp(tool) == nil)
            #expect(PhotoWorkspace().toolHelp(tool) == nil)
        }
        #expect(PhotoTool.spotHeal.rawValue == "spot-heal")
        // ToolKeys picks the first enabled tool with a key, so the new tools come first in their groups.
        #expect((order.firstIndex(of: .bucket) ?? 99) < (order.firstIndex(of: .gradient) ?? 0))
        #expect((order.firstIndex(of: .spotHeal) ?? 99) < (order.firstIndex(of: .heal) ?? 0))
        #expect((order.firstIndex(of: .heal) ?? 99) < (order.firstIndex(of: .remove) ?? 0))
    }

    @Test func aRetouchToolsDragChangesNothingUntilRelease() throws {
        for tool in [PhotoTool.bucket, .spotHeal, .remove] {
            var model = try PhotoWorkspace.fixture(.sample)
            model.selectTool(tool)
            let before = model
            // From the sun's edge, so a spot heal at the press has an edge to rebuild.
            model.drag(from: Mask.Point(x: 475, y: 220), to: Mask.Point(x: 600, y: 260), modifiers: [])
            #expect(model.pixels == before.pixels, "\(tool)")
            #expect(!model.dragPaintsOnly)
            model.endDrag()
            #expect(model.pixels != before.pixels, "\(tool)")
            #expect(model.historySteps.count == before.historySteps.count + 1, "\(tool)")
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
