// PhotoLayerOpsTests.swift: the workspace's Duplicate Layer, Merge Down and
// Flatten Image (E-4 of photo-edit): the duplicate's own tiles, Merge Down
// keeping the lower layer's id and name, Flatten resetting the whole-image
// adjustments, the help texts on `.live` and `.fake`, one named undo step each
// (QB-F3) and QB-F1. Runs on Linux and macOS.
import CoreRaster
@testable import PhotoModel
import Testing

@Suite struct PhotoLayerOpsTests {
    /// A merging service that refuses everything.
    private struct RefusingMerging: LayerMerging {
        var unavailableHelp: String? { nil }
        func mergeDown(_ upper: LayerContent, onto lower: LayerContent) throws -> PlacedPixels {
            throw PhotoRefusal("No merging today.")
        }
        func flatten(_ layers: [LayerContent], canvas: CanvasSize, adjustments: AdjustmentSettings) throws
            -> TiledPixels
        {
            throw PhotoRefusal("No flattening today.")
        }
    }

    /// A white image with a red layer above Background, on `services`.
    private func twoLayers(_ services: PhotoServices = .live) throws -> PhotoWorkspace {
        var workspace = try whiteImage(48, 40)
        workspace.services = services
        addFilledLayer(&workspace, red: 220, green: 30, blue: 30)
        return workspace
    }

    /// "Paint" over an adjustment layer over Background, Paint selected.
    private func overAdjustment(_ services: PhotoServices) throws -> PhotoWorkspace {
        var workspace = try whiteImage(32, 32)
        workspace.services = services
        var curves = AdjustmentSettings()
        curves.apply(.exposure(0.5))
        _ = workspace.insertLayer(named: "Curves 1", pixels: nil, kind: .adjustment(curves), at: 0)
        let clear = try TiledPixels(width: 32, height: 32)
        workspace.selectedLayerID = workspace.insertLayer(named: "Paint", pixels: clear, kind: .pixels, at: 0)
        return workspace
    }

    private func sameDocument(_ a: PhotoWorkspace, _ b: PhotoWorkspace) -> Bool {
        a.layers == b.layers && a.pixels == b.pixels && a.masks == b.masks && a.adjustments == b.adjustments
            && a.selectedLayerID == b.selectedLayerID
    }

    @Test func duplicateGivesACopyAboveWithItsOwnTiles() throws {
        var workspace = try whiteImage(48, 40)
        let background = try #require(workspace.selectedLayerID)
        let original = try #require(workspace.pixels[background])
        let before = workspace
        workspace.duplicateSelectedLayer()
        #expect(workspace.layers.map(\.name) == ["Background copy", "Background"])
        let copy = try #require(workspace.selectedLayerID)
        #expect(copy == workspace.layers[0].id && copy != background)
        #expect(workspace.pixels[copy] == original)
        #expect(workspace.geometryChangeCount == before.geometryChangeCount + 1)
        #expect(workspace.lastGeometryChange?.id == copy)
        #expect(workspace.lastGeometryChange?.change == .duplicated(from: background))
        #expect(workspace.undoActionName == "Undo Duplicate Layer")

        // Painting the copy leaves Background alone.
        workspace.setToolOption(.color(red: 0, green: 0, blue: 0))
        stroke(&workspace, .brush, from: point(4, 20), to: point(44, 20))
        #expect(workspace.pixels[copy] != original)
        #expect(workspace.pixels[background] == original)

        workspace.undo()
        workspace.undo()
        #expect(sameDocument(workspace, before))
    }

    @Test func duplicateKeepsTheLayersLookAndMask() throws {
        var workspace = try PhotoWorkspace.fixture(.layered)
        let paint = try #require(workspace.selectedLayer)
        workspace.duplicateSelectedLayer()
        let copy = try #require(workspace.selectedLayer)
        #expect(copy.name == "Paint copy")
        #expect(copy.blendMode == paint.blendMode && copy.opacity == paint.opacity && copy.hasMask)
        #expect(workspace.masks[copy.id] == workspace.masks[paint.id])
        #expect(workspace.layers.map(\.name) == ["Paint copy", "Paint", "Curves 1", "Background"])
    }

    @Test func mergeDownKeepsTheLowerIDAndName() throws {
        var workspace = try twoLayers()
        let upper = try #require(workspace.selectedLayerID)
        let lower = try #require(workspace.layers.last?.id)
        let before = workspace
        let count = workspace.geometryChangeCount
        #expect(workspace.mergeDownHelp == nil)
        workspace.mergeDown()
        #expect(workspace.layers.map(\.id) == [lower])
        #expect(workspace.layers.map(\.name) == ["Background"])
        #expect(workspace.selectedLayerID == lower && workspace.pixels[upper] == nil)
        #expect(workspace.geometryChangeCount == count + 2)
        #expect(workspace.lastGeometryChange?.id == upper && workspace.lastGeometryChange?.change == .removed)
        #expect(try workspace.composite() == before.composite())
        #expect(workspace.undoActionName == "Undo Merge Down")
        workspace.undo()
        #expect(sameDocument(workspace, before))
    }

    @Test func aRefusalChangesOnlyTheStatusLine() throws {
        var services = PhotoServices.live
        services.merging = RefusingMerging()
        var workspace = try twoLayers(services)
        workspace.adjust(.exposure(0.3))
        let before = workspace
        workspace.mergeDown()
        #expect(workspace.statusMessage == "No merging today.")
        #expect(sameDocument(workspace, before) && workspace.historySteps == before.historySteps)
        workspace.flattenImage()
        #expect(workspace.statusMessage == "No flattening today.")
        #expect(sameDocument(workspace, before) && workspace.historySteps == before.historySteps)
    }

    @Test func flattenResetsTheWholeImageAdjustments() throws {
        var workspace = try twoLayers()
        workspace.adjust(.exposure(0.4))
        workspace.endAdjust()
        let before = workspace
        workspace.flattenImage()
        #expect(workspace.layers.map(\.name) == ["Background"])
        #expect(workspace.adjustments == AdjustmentSettings())
        #expect(workspace.selectedLayerID == workspace.layers.first?.id)
        #expect(workspace.undoActionName == "Undo Flatten Image")
        #expect(workspace.flattenHelp == "The image already has one layer.")
        workspace.undo()
        #expect(sameDocument(workspace, before))
        workspace.redo()
        #expect(workspace.layers.count == 1 && workspace.adjustments == AdjustmentSettings())
    }

    @Test(arguments: [true, false]) func helpTexts(live: Bool) throws {
        let services: PhotoServices = live ? .live : .fake
        var empty = PhotoWorkspace()
        empty.services = services
        #expect(empty.duplicateLayerHelp == "Open an image first.")
        #expect(empty.mergeDownHelp == "Open an image first.")
        #expect(empty.flattenHelp == "Open an image first.")

        var one = try whiteImage(16, 16)
        one.services = services
        #expect(one.duplicateLayerHelp == nil)
        #expect(one.mergeDownHelp == "There's no layer below to merge into.")
        #expect(one.flattenHelp == "The image already has one layer.")
        one.adjust(.exposure(0.2))
        #expect(one.flattenHelp == nil)

        var adjusted = try overAdjustment(services)
        #expect(adjusted.mergeDownHelp == "Merge Down needs a pixel layer below.")
        #expect(adjusted.flattenHelp == nil && adjusted.duplicateLayerHelp == nil)
        let before = adjusted
        adjusted.mergeDown()
        #expect(adjusted.statusMessage == "Merge Down needs a pixel layer below.")
        #expect(sameDocument(adjusted, before))
    }

    @Test func layeredFixtureRefusesMergeDownOnTheFakes() throws {
        let workspace = try PhotoWorkspace.fixture(.layered)
        #expect(workspace.selectedLayer?.name == "Paint")
        #expect(workspace.mergeDownHelp == "Merge Down needs a pixel layer below.")
    }

    @Test func everyItemActsOrSaysWhy() throws {
        for services in [PhotoServices.live, .fake] {
            var empty = PhotoWorkspace()
            empty.services = services
            empty.duplicateSelectedLayer()
            empty.mergeDown()
            empty.flattenImage()
            #expect(empty.canvas == nil && empty.statusMessage == "Open an image first.")

            var workspace = try twoLayers(services)
            let items: [(String, String?, (inout PhotoWorkspace) -> Void)] = [
                ("Duplicate Layer", workspace.duplicateLayerHelp, { $0.duplicateSelectedLayer() }),
                ("Merge Down", workspace.mergeDownHelp, { $0.mergeDown() }),
                ("Flatten Image", workspace.flattenHelp, { $0.flattenImage() }),
            ]
            for (name, help, act) in items {
                #expect(help == nil, "\(name)")
                var acted = workspace
                act(&acted)
                #expect(acted != workspace, "\(name)")
                #expect(acted.undoActionName == "Undo \(name)")
            }
            workspace.flattenImage()
            #expect(workspace.layers.count == 1)
            let flat = workspace
            workspace.mergeDown()
            workspace.flattenImage()
            #expect(sameDocument(workspace, flat) && workspace.statusMessage == "The image already has one layer.")
        }
    }
}
