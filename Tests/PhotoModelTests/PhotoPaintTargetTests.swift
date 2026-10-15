// PhotoPaintTargetTests.swift: paint goes through `paintTarget()` and the
// selection's coverage (photo-seams S-7c). A paint drag on an adjustment layer
// refuses at once with a status message (QB-F2); with the coverage forced to 0
// outside a rectangle, brush, eraser, clone, heal, Delete and Fill change no
// pixel outside it; Select All, Deselect and Apply Crop clear the selection
// mask, and Apply Crop calls the geometry hook once per layer. Runs on Linux
// and macOS.
import CoreRaster
@testable import PhotoModel
import Testing

@Suite struct PhotoPaintTargetTests {
    /// The rectangle the forced coverage keeps: 1 inside, 0 outside.
    private let inside = PixelRect(x: 20, y: 20, width: 24, height: 24)

    private func forced(_ rect: PixelRect) -> @Sendable (Int, Int) -> Float {
        { x, y in x >= rect.x && x < rect.maxX && y >= rect.y && y < rect.maxY ? 1 : 0 }
    }

    /// The pixels of `layer` outside `rect`, row-major.
    private func outside(_ rect: PixelRect, of tiled: TiledPixels) throws -> [RGBA] {
        var kept: [RGBA] = []
        for y in 0..<tiled.height {
            for x in 0..<tiled.width where !(x >= rect.x && x < rect.maxX && y >= rect.y && y < rect.maxY) {
                kept.append(try tiled.pixel(x: x, y: y))
            }
        }
        return kept
    }

    /// A white image with a red line along y = 10, so clone and heal have
    /// texture to copy, and the clone source sampled at (10, 10).
    private func paintedImage() throws -> PhotoWorkspace {
        var workspace = try whiteImage()
        workspace.setToolOption(.size(16))
        workspace.setToolOption(.color(red: 255, green: 0, blue: 0))
        stroke(&workspace, .brush, from: point(2, 10), to: point(62, 10))
        workspace.setToolOption(.color(red: 0, green: 200, blue: 0))
        workspace.setCloneSource(at: point(10, 10))
        return workspace
    }

    /// `edit` applied to a painted image, the selected layer's pixels after.
    /// `edit` applied to a painted image, with the coverage forced to 1 in
    /// `rect` and 0 outside it when given; the selected layer's pixels
    /// before and after.
    private func layerAfter(
        forcing rect: PixelRect? = nil, _ edit: (inout PhotoWorkspace) -> Void
    ) throws -> (before: TiledPixels, after: TiledPixels) {
        var workspace = try paintedImage()
        let id = try #require(workspace.selectedLayerID)
        let before = try #require(workspace.pixels[id])
        if let rect {
            PhotoWorkspace.$forcedCoverage.withValue(forced(rect)) { edit(&workspace) }
        } else {
            edit(&workspace)
        }
        return (before, try #require(workspace.pixels[id]))
    }

    @Test func refusalIsImmediate() throws {
        var workspace = try PhotoWorkspace.fixture(.layered)
        let curves = try #require(workspace.layers.first { $0.name == "Curves 1" })
        workspace.selectLayer(curves.id)
        workspace.selectTool(.brush)
        let pixels = workspace.pixels, steps = workspace.historySteps.count
        workspace.drag(from: point(100, 100), to: point(100, 100))
        #expect(workspace.statusMessage == "Pick a pixel layer to paint on.")
        workspace.drag(from: point(100, 100), to: point(300, 200))
        workspace.endDrag()
        #expect(workspace.pixels == pixels)
        #expect(workspace.historySteps.count == steps)
        #expect(workspace.paintTarget() == nil)
    }

    @Test func aPixelLayerIsThePaintTarget() throws {
        var workspace = try PhotoWorkspace.fixture(.layered)
        let id = try #require(workspace.selectedLayerID)
        #expect(workspace.paintTarget() == .pixels(id))
        #expect(workspace.statusMessage == nil)
    }

    @Test(arguments: [PhotoTool.brush, .eraser, .clone, .heal])
    func aDabChangesNoPixelOutsideTheCoverage(_ tool: PhotoTool) throws {
        let drag: (inout PhotoWorkspace) -> Void = { workspace in
            workspace.selectTool(tool)
            workspace.drag(from: point(4, 32), to: point(4, 32))
            workspace.drag(from: point(4, 32), to: point(60, 32))
            workspace.endDrag()
        }
        // Unweighted, the drag reaches pixels outside the rectangle,
        let free = try layerAfter(drag)
        #expect(try outside(inside, of: free.after) != outside(inside, of: free.before))
        // and with the coverage forced to 0 there it changes none of them.
        let weighted = try layerAfter(forcing: inside, drag)
        #expect(try outside(inside, of: weighted.after) == outside(inside, of: weighted.before))
        if tool != .heal { #expect(weighted.after != weighted.before) }
    }

    @Test func fillAndDeleteChangeNoPixelOutsideTheCoverage() throws {
        let edits: [(inout PhotoWorkspace) -> Void] = [{ $0.fillSelection() }, { $0.deleteSelection() }]
        for edit in edits {
            let result = try layerAfter(forcing: inside) { workspace in
                workspace.selectAll()
                edit(&workspace)
            }
            #expect(try outside(inside, of: result.after) == outside(inside, of: result.before))
            #expect(result.after != result.before)
        }
    }

    @Test func coverageIsOneInsideTheRectangleAndEverywhereWithout() throws {
        var workspace = try whiteImage()
        #expect(workspace.selectionCoverage(x: 63, y: 0) == 1)
        workspace.selectTool(.marquee)
        workspace.drag(from: point(8, 8), to: point(8, 8))
        workspace.drag(from: point(8, 8), to: point(24, 24))
        workspace.endDrag()
        #expect(workspace.selectionCoverage(x: 10, y: 10) == 1)
        #expect(workspace.selectionCoverage(x: 40, y: 10) == 0)
    }

    @Test func selectAllDeselectAndCropClearTheSelectionMask() throws {
        var workspace = try whiteImage()
        let mask = try Mask(width: 64, height: 64, fill: 0.5)
        workspace.selectionMask = mask
        workspace.selectAll()
        #expect(workspace.selectionMask == nil && workspace.selection == workspace.canvas?.rect)
        workspace.selectionMask = mask
        workspace.deselect()
        #expect(workspace.selectionMask == nil && workspace.selection == nil)
        workspace.selectionMask = mask
        stroke(&workspace, .crop, from: point(4, 4), to: point(40, 40))
        workspace.applyCrop()
        #expect(workspace.selectionMask == nil)
    }

    @Test func applyCropCallsTheGeometryHookOncePerLayer() throws {
        var workspace = try PhotoWorkspace.fixture(.layered)
        let count = workspace.geometryChangeCount
        stroke(&workspace, .crop, from: point(100, 100), to: point(500, 400))
        let crop = try #require(workspace.pendingCrop)
        workspace.applyCrop()
        #expect(workspace.geometryChangeCount == count + workspace.layers.count)
        #expect(workspace.lastGeometryChange?.change == .cropped(crop))
    }
}
