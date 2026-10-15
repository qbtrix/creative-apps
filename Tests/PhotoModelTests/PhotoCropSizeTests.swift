// PhotoCropSizeTests.swift: the crop's typed fields and aspect lock on the
// workspace (PV-3, photo-crop CP-2), on the live crop sizing (the fake
// ignores the aspect). Runs on Linux and macOS.
import CoreRaster
import PhotoModel
import Testing

@Suite struct PhotoCropSizeTests {
    /// An open 800 x 600 image whose Background differs from pixel to pixel,
    /// with the crop tool picked.
    private func image() throws -> PhotoWorkspace {
        var bytes: [UInt8] = []
        bytes.reserveCapacity(800 * 600 * 4)
        for y in 0..<600 { for x in 0..<800 { bytes += [UInt8(x % 256), UInt8(y % 256), UInt8((x + y) % 256), 255] } }
        var workspace = PhotoWorkspace(services: .live)
        try workspace.open(rgba8: bytes, width: 800, height: 600, name: "g.png")
        workspace.selectTool(.crop)
        return workspace
    }

    /// `setCropField(field, to: value)`'s answer (a mutating call can't sit in `#expect`).
    private func typed(_ workspace: inout PhotoWorkspace, _ field: CropField, _ value: Int) -> Bool {
        workspace.setCropField(field, to: value)
    }

    /// Whether `crop` is `w`:`h` within a pixel.
    private func keeps(_ crop: PixelRect?, _ w: Int, _ h: Int) -> Bool {
        guard let crop else { return false }
        return abs(Double(crop.height) - Double(crop.width) * Double(h) / Double(w)) <= 1
    }

    @Test func aValueUnderOneChangesNothing() throws {
        var workspace = try image()
        workspace.setCropAspect(.ratio(1, 1))
        let before = workspace
        #expect(!typed(&workspace, .width, 0))
        #expect(!typed(&workspace, .height, -5))
        #expect(!typed(&workspace, .x, Int.min))
        #expect(workspace == before)
    }

    @Test func noCanvasTakesNothing() {
        var workspace = PhotoWorkspace(services: .live)
        workspace.setCropAspect(.ratio(1, 1))
        #expect(!workspace.cropFieldsEnabled)
        #expect(!typed(&workspace, .width, 100))
        #expect(workspace.pendingCrop == nil)
    }

    @Test func fieldsWaitForACropOrALock() throws {
        var workspace = try image()
        #expect(!workspace.cropFieldsEnabled)
        #expect(!typed(&workspace, .width, 100))
        #expect(workspace.pendingCrop == nil && workspace.cropFieldValue(.width) == nil)
        #expect(workspace.cropAspectBadge == nil)
        workspace.setCropAspect(.ratio(1, 1))
        #expect(workspace.cropFieldsEnabled)
        #expect(workspace.pendingCrop == PixelRect(x: 100, y: 0, width: 600, height: 600))
        #expect(workspace.cropFieldValue(.x) == 100 && workspace.cropFieldValue(.y) == 0)
        #expect(workspace.cropFieldValue(.width) == 600 && workspace.cropFieldValue(.height) == 600)
        #expect(workspace.cropAspectBadge == "1:1")
        workspace.setCropAspect(.original)
        #expect(workspace.cropAspectBadge == "Original")
        workspace.setCropAspect(.free)
        #expect(workspace.cropAspectBadge == nil)
        #expect(workspace.cropFieldsEnabled)
    }

    @Test func aLockedAspectStartsACropFromATypedField() throws {
        var workspace = try image()
        workspace.setCropAspect(.ratio(1, 1))
        workspace.cancelCrop()
        #expect(workspace.cropFieldsEnabled && workspace.cropAspectBadge == nil)
        #expect(typed(&workspace, .width, 300))
        #expect(workspace.pendingCrop == PixelRect(x: 100, y: 0, width: 300, height: 300))
    }

    @Test func typedSidesFollowTheLockAndClamp() throws {
        var workspace = try image()
        workspace.setCropAspect(.ratio(1, 1))
        #expect(typed(&workspace, .width, 400))
        #expect(workspace.pendingCrop == PixelRect(x: 100, y: 0, width: 400, height: 400))
        #expect(typed(&workspace, .width, 200))
        #expect(typed(&workspace, .x, 700))
        #expect(workspace.pendingCrop == PixelRect(x: 600, y: 0, width: 200, height: 200))
    }

    @Test func swapTurnsTheLockOnItsSide() throws {
        var workspace = try image()
        workspace.setCropAspect(.ratio(3, 2))
        #expect(keeps(workspace.pendingCrop, 3, 2))
        workspace.swapCropAspect()
        #expect(workspace.cropAspect == .ratio(2, 3))
        let crop = try #require(workspace.pendingCrop)
        #expect(crop.height > crop.width)
        #expect(keeps(crop, 2, 3))
        #expect(workspace.cropAspectBadge == "2:3")
    }

    @Test func theDragKeepsTheLock() throws {
        var workspace = try image()
        workspace.setCropAspect(.ratio(3, 2))
        workspace.cancelCrop()
        stroke(&workspace, .crop, from: point(10, 10), to: point(310, 300))
        #expect(keeps(workspace.pendingCrop, 3, 2))
        stroke(&workspace, .crop, from: point(700, 500), to: point(100, 450))
        #expect(keeps(workspace.pendingCrop, 3, 2))
    }

    @Test func aClickStillDropsTheCrop() throws {
        var workspace = try image()
        workspace.setCropAspect(.ratio(3, 2))
        stroke(&workspace, .crop, from: point(50, 50), to: point(50.4, 50.4))
        #expect(workspace.pendingCrop == nil)
    }

    /// QB-F2: the overlay follows every pointer event.
    @Test func dragUpdatesEveryEvent() throws {
        var workspace = try image()
        workspace.setCropAspect(.ratio(3, 2))
        workspace.cancelCrop()
        let start = point(20, 20)
        workspace.drag(from: start, to: start)
        var seen: [PixelRect?] = []
        for i in 1...60 {
            workspace.drag(from: start, to: point(20 + Double(i) * 9, 20 + Double(i) * 6))
            seen.append(workspace.pendingCrop)
        }
        workspace.endDrag()
        #expect(seen.allSatisfy { $0 != nil })
        #expect(Set(seen).count == 60)
    }

    /// PF-5: a typed crop cuts each layer exactly as CoreRaster's `cropped`.
    @Test func typedCropMatchesCropped() throws {
        var workspace = try image()
        addFilledLayer(&workspace, red: 200, green: 40, blue: 90)
        workspace.setCropAspect(.ratio(3, 2))
        #expect(typed(&workspace, .width, 300))
        #expect(typed(&workspace, .x, 123))
        #expect(typed(&workspace, .y, 77))
        let rect = try #require(workspace.pendingCrop)
        #expect(rect == PixelRect(x: 123, y: 77, width: 300, height: 200))
        var expected: [PhotoLayer.ID: PixelBuffer] = [:]
        for layer in workspace.layers {
            let tiled = try #require(workspace.pixels[layer.id])
            expected[layer.id] = try tiled.flattened().cropped(
                x: rect.x - layer.offsetX, y: rect.y - layer.offsetY, width: rect.width, height: rect.height)
        }
        workspace.applyCrop()
        #expect(workspace.canvas == CanvasSize(width: 300, height: 200))
        for layer in workspace.layers {
            #expect(try workspace.pixels[layer.id]?.flattened() == expected[layer.id])
        }
    }

    @Test func onlyApplyIsAnUndoStep() throws {
        var workspace = try image()
        let steps = workspace.historyIndex
        workspace.setCropAspect(.ratio(4, 3))
        workspace.swapCropAspect()
        #expect(typed(&workspace, .height, 300))
        #expect(typed(&workspace, .y, 10))
        workspace.setCropAspect(.free)
        #expect(typed(&workspace, .width, 100))
        stroke(&workspace, .crop, from: point(10, 10), to: point(200, 150))
        #expect(workspace.historyIndex == steps)
        workspace.applyCrop()
        #expect(workspace.historyIndex == steps + 1)
        #expect(workspace.undoActionName == "Undo Crop")
    }
}
