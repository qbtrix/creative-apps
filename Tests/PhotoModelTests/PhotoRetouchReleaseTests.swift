// PhotoRetouchReleaseTests.swift (fill-heal FH-8): the Paint Bucket, Spot
// Heal and Remove tools act through `drag` and `endDrag`. A bucket click
// fills the region under the press, a spot-heal click heals the spot there
// and a Remove stroke fills what it passed over, each as one undo step named
// for its tool however many samples the drag brought, and undo restores the
// layer byte for byte. A tool that can't act says why and records nothing.
// Runs on Linux and macOS.
import CoreRaster
@testable import PhotoModel
import Testing

@Suite struct PhotoRetouchReleaseTests {
    /// A white image with a black dot at (32, 32) and a red paint colour.
    private func dotted() throws -> PhotoWorkspace {
        var workspace = try whiteImage()
        workspace.setToolOption(.size(8))
        stroke(&workspace, .brush, from: point(32, 32), to: point(32, 32))
        workspace.setToolOption(.color(red: 255, green: 0, blue: 0))
        return workspace
    }

    /// Presses at `path[0]`, moves through the rest one sample at a time, lifts.
    private func drag(_ workspace: inout PhotoWorkspace, _ tool: PhotoTool, _ path: [Mask.Point]) {
        workspace.selectTool(tool)
        guard let first = path.first else { return }
        var last = first
        for next in path {
            workspace.drag(from: last, to: next, modifiers: [])
            last = next
        }
        workspace.endDrag()
    }

    /// Gesture `index`: its tool, its undo name and its pointer samples.
    private static func gesture(_ index: Int) -> (tool: PhotoTool, name: String, path: [Mask.Point]) {
        switch index {
        case 0: (.bucket, "Paint Bucket", [point(4, 4)])
        case 1: (.bucket, "Paint Bucket", [point(4, 4), point(10, 6), point(20, 8)])
        case 2: (.spotHeal, "Spot Heal", [point(32, 32)])
        case 3: (.spotHeal, "Spot Heal", [point(32, 32), point(33, 32), point(34, 33)])
        default: (.remove, "Remove", (0...10).map { point(26 + Double($0), 32) })
        }
    }

    @Test(arguments: 0..<5)
    func aGestureIsOneUndoStep(_ index: Int) throws {
        let (tool, name, path) = Self.gesture(index)
        var workspace = try dotted()
        let before = workspace.pixels, steps = workspace.historySteps.count
        drag(&workspace, tool, path)
        #expect(workspace.pixels != before, "\(name) changed the layer")
        #expect(workspace.historySteps.count == steps + 1, "\(name) is one undo step")
        #expect(workspace.undoActionName == "Undo \(name)")
        #expect(!workspace.isDragging && workspace.removeStroke == nil)
        workspace.undo()
        #expect(workspace.pixels == before, "undo restores \(name)")
    }

    @Test func theBucketFillsAtThePressWithItsOptions() throws {
        var workspace = try dotted()
        workspace.setBucketOption(.contiguous(true))
        drag(&workspace, .bucket, [point(4, 4)])
        let corner = try #require(try layerPixel(workspace, 4, 4))
        #expect(corner.r > 0.9 && corner.g < 0.1 && corner.b < 0.1, "the white around the dot is red")
        let dot = try #require(try layerPixel(workspace, 32, 32))
        #expect(dot.r < 0.1, "the black dot is another region, left alone")
    }

    @Test func spotHealTakesTheDotAway() throws {
        var workspace = try dotted()
        workspace.setToolOption(.size(16))
        drag(&workspace, .spotHeal, [point(32, 32)])
        let healed = try #require(try layerPixel(workspace, 32, 32))
        #expect(healed.r > 0.5 && healed.g > 0.5, "the dot healed from the white around it")
    }

    @Test func aRemoveStrokeFillsAllItPassedOver() throws {
        var workspace = try dotted()
        drag(&workspace, .remove, (0...32).map { point(16 + Double($0), 32) })
        let filled = try #require(try layerPixel(workspace, 32, 32))
        #expect(filled.r > 0.5 && filled.g > 0.5, "the dot halfway along the stroke is gone")
    }

    @Test func aToolThatCantActSaysWhyAndRecordsNothing() throws {
        for tool in [PhotoTool.bucket, .spotHeal, .remove] {
            var workspace = try dotted()
            workspace.addAdjustmentLayer(.exposure)
            let before = workspace.pixels, steps = workspace.historySteps.count
            drag(&workspace, tool, [point(30, 30), point(40, 30)])
            #expect(workspace.pixels == before && workspace.historySteps.count == steps, "\(tool)")
            #expect(workspace.statusMessage == workspace.retouchHelp, "\(tool)")
        }
    }
}
