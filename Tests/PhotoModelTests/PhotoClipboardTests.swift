// PhotoClipboardTests.swift: the workspace's Cut, Copy and Paste (E-3) on
// `.live`: PF-3 (copy then paste in place gives the source back within 1/255,
// exactly for an untouched 8-bit image), one named step each, paste with no
// image, the oversized paste note, QB-F1 and QB-F2. Runs on Linux and macOS.
import CoreRaster
@testable import PhotoModel
import Testing

@Suite struct PhotoClipboardTests {
    /// An opened opaque `width` x `height` image whose bytes vary by pixel.
    private func patterned(_ width: Int = 80, _ height: Int = 60) throws -> PhotoWorkspace {
        var bytes: [UInt8] = []
        for y in 0..<height {
            for x in 0..<width { bytes += [UInt8((x * 7) % 256), UInt8((y * 11) % 256), UInt8((x + y) % 256), 255] }
        }
        var workspace = PhotoWorkspace()
        try workspace.open(rgba8: bytes, width: width, height: height, name: "pattern.png")
        return workspace
    }

    /// Layer `id`'s 8-bit straight bytes at canvas pixel (x, y); clear outside it.
    private func bytes(_ workspace: PhotoWorkspace, _ id: PhotoLayer.ID, _ x: Int, _ y: Int) throws -> [UInt8] {
        let layer = try #require(workspace.layers.first { $0.id == id })
        let tiled = try #require(workspace.pixels[id])
        let lx = x - layer.offsetX, ly = y - layer.offsetY
        guard (0..<tiled.width).contains(lx), (0..<tiled.height).contains(ly) else { return [0, 0, 0, 0] }
        let one = try PixelBuffer(width: 1, height: 1, fill: try tiled.pixel(x: lx, y: ly))
        return try one.rgba8()
    }

    @Test func pasteInPlace() throws {
        // An untouched opened 8-bit image comes back exactly.
        var workspace = try patterned()
        let background = try #require(workspace.selectedLayerID)
        workspace.setSelection(PixelRect(x: 10, y: 5, width: 30, height: 20))
        let imageTaken = workspace.copySelection()
        let image = try #require(imageTaken)
        workspace.paste(image, viewCenter: point(40, 30))
        let pasted = try #require(workspace.selectedLayerID)
        #expect(workspace.selectedLayer?.offsetX == 10 && workspace.selectedLayer?.offsetY == 5)
        for y in 5..<25 {
            for x in 10..<40 {
                #expect(try bytes(workspace, pasted, x, y) == bytes(workspace, background, x, y))
            }
        }

        // Painted Float pixels come back within 1/255.
        var painted = try whiteImage(48, 48)
        painted.addLayer()
        painted.setToolOption(.color(red: 30, green: 140, blue: 220))
        painted.setToolOption(.size(20))
        stroke(&painted, .brush, from: point(6, 24), to: point(42, 20))
        let source = try #require(painted.selectedLayerID)
        painted.setSelection(PixelRect(x: 4, y: 8, width: 36, height: 30))
        let copiedTaken = painted.copySelection()
        let copied = try #require(copiedTaken)
        painted.paste(copied, viewCenter: point(24, 24))
        let layer = try #require(painted.selectedLayerID)
        #expect(layer != source)
        for y in 8..<38 {
            for x in 4..<40 {
                let want = try bytes(painted, source, x, y), got = try bytes(painted, layer, x, y)
                let channels = want[3] == 0 ? [3] : [0, 1, 2, 3]
                for c in channels { #expect(abs(Int(want[c]) - Int(got[c])) <= 1, "(\(x), \(y)) channel \(c)") }
            }
        }
    }

    @Test func pasteAddsOneSelectedLayerAboveTheSelected() throws {
        var workspace = try patterned()
        workspace.addLayer()
        let top = try #require(workspace.selectedLayerID)
        let background = try #require(workspace.layers.last?.id)
        workspace.selectLayer(background)
        let undoCount = workspace.historySteps.count
        workspace.setSelection(PixelRect(x: 0, y: 0, width: 8, height: 8))
        let imageTaken = workspace.copySelection()
        let image = try #require(imageTaken)
        workspace.paste(image, viewCenter: point(40, 30))
        #expect(workspace.layers.map(\.name) == ["Layer 1", "Pasted Layer", "Background"])
        #expect(workspace.layers.first?.id == top)
        #expect(workspace.selectedLayer?.name == "Pasted Layer")
        #expect(workspace.historySteps.count == undoCount + 1)
        #expect(workspace.undoActionName == "Undo Paste")
        workspace.undo()
        #expect(workspace.layers.map(\.name) == ["Layer 1", "Background"])
        #expect(workspace.selectedLayerID == background)
    }

    @Test func cutClearsTheAreaInOneStep() throws {
        var workspace = try patterned()
        let id = try #require(workspace.selectedLayerID)
        let before = workspace.pixels[id]
        workspace.setSelection(PixelRect(x: 10, y: 10, width: 20, height: 10))
        let imageTaken = workspace.cutSelection()
        let image = try #require(imageTaken)
        #expect(image.source == PixelRect(x: 10, y: 10, width: 20, height: 10))
        #expect(workspace.undoActionName == "Undo Cut")
        #expect(workspace.historySteps == ["Open", "Cut"])
        #expect(try layerPixel(workspace, 15, 15)?.a == 0)
        #expect(try layerPixel(workspace, 5, 5)?.a == 1)
        workspace.undo()
        #expect(workspace.pixels[id] == before)

        // No selection cuts the whole layer.
        workspace.deselect()
        let wholeTaken = workspace.cutSelection()
        let whole = try #require(wholeTaken.map(\.image))
        #expect(whole.width == 80 && whole.height == 60)
        #expect(try layerPixel(workspace, 79, 59)?.a == 0)
        #expect(workspace.historySteps == ["Open", "Cut"])
        workspace.undo()
        #expect(workspace.pixels[id] == before)
    }

    @Test func cutIsWeightedByCoverage() throws {
        var workspace = try patterned()
        // A half-coverage mask: Copy takes half alpha, Cut leaves the other half.
        let half = try Mask(width: 80, height: 60, fill: 0.5)
        workspace.setSelection(PixelRect(x: 0, y: 0, width: 80, height: 60), mask: half)
        let imageTaken = workspace.cutSelection()
        let image = try #require(imageTaken)
        #expect(image.image.rgba8[3] == 128)
        let alpha = try #require(try layerPixel(workspace, 20, 20)?.a)
        #expect(abs(alpha - 0.5) < 0.001)
        #expect(workspace.historySteps == ["Open", "Cut"])
    }

    @Test func pasteWithNoImageOpensAClean() throws {
        var workspace = PhotoWorkspace()
        #expect(workspace.pasteHelp(true) == nil)
        let bytes = [UInt8](repeating: 200, count: 200 * 100 * 4)
        workspace.paste(
            ClipboardImage(image: DecodedImage(rgba8: bytes, width: 200, height: 100), source: nil),
            viewCenter: point(0, 0))
        #expect(workspace.canvas == CanvasSize(width: 200, height: 100))
        #expect(workspace.layers.map(\.name) == ["Background"])
        #expect(workspace.documentName == nil)
        #expect(!workspace.isDirty)
        #expect(!workspace.canUndo)
        #expect(workspace.statusMessage == nil)
        let one = try PixelBuffer(width: 1, height: 1, fill: try #require(try layerPixel(workspace, 50, 50)))
        #expect(try one.rgba8() == [200, 200, 200, 200])
    }

    @Test func oversizedPasteIsScaledToFit() throws {
        // 6000 x 4000 (24 MP) against the 16,777,216 open limit.
        let size = try #require(PhotoWorkspace.pasteSize(width: 6000, height: 4000))
        #expect(size.width == 5016 && size.height == 3344 && size.percent == 84)
        #expect(size.width * size.height <= PhotoWorkspace.maxOpenPixels)
        #expect(PhotoWorkspace.pasteSize(width: 4096, height: 4096) == nil)

        // The same ratio through the workspace and a real lanczos3 resize, at a
        // hundredth of the limit, so the debug build stays fast.
        var workspace = try whiteImage(64, 64)
        let bytes = [UInt8](repeating: 255, count: 600 * 400 * 4)
        PhotoWorkspace.$pasteLimit.withValue(PhotoWorkspace.maxOpenPixels / 100) {
            workspace.paste(
                ClipboardImage(image: DecodedImage(rgba8: bytes, width: 600, height: 400), source: nil),
                viewCenter: point(32, 32))
        }
        let id = try #require(workspace.selectedLayerID)
        let tiled = try #require(workspace.pixels[id])
        #expect(tiled.width == 501 && tiled.height == 334)
        #expect(workspace.selectedLayer?.name == "Pasted Layer")
        #expect(workspace.statusMessage == "Pasted at 84%.")
        #expect(workspace.undoActionName == "Undo Paste")
        let center = try tiled.pixel(x: 250, y: 167)
        #expect(abs(center.a - 1) < 0.001 && abs(center.r - 1) < 0.001)

        // With no image open, the scaled paste opens at the scaled size.
        var empty = PhotoWorkspace()
        PhotoWorkspace.$pasteLimit.withValue(PhotoWorkspace.maxOpenPixels / 100) {
            empty.paste(
                ClipboardImage(image: DecodedImage(rgba8: bytes, width: 600, height: 400), source: nil),
                viewCenter: point(0, 0))
        }
        #expect(empty.canvas == CanvasSize(width: 501, height: 334))
        #expect(empty.statusMessage == "Pasted at 84%.")
        #expect(!empty.isDirty)
    }

    @Test func nothingToCopyIsImmediate() throws {
        var workspace = try whiteImage(32, 32)
        workspace.addLayer()
        workspace.setSelection(PixelRect(x: 4, y: 4, width: 10, height: 10))
        let copied = workspace.copySelection()
        #expect(copied == nil)
        #expect(workspace.statusMessage == "Nothing to copy.")
        workspace.clearStatus()
        let cut = workspace.cutSelection()
        #expect(cut == nil)
        #expect(workspace.statusMessage == "Nothing to copy.")
        #expect(workspace.undoActionName == "Undo New Layer")
    }

    @Test func pasteTakesALayerIDNeverUsedBefore() throws {
        var workspace = try patterned()
        let imageTaken = workspace.copySelection()
        let image = try #require(imageTaken)
        var seen = Set(workspace.layers.map(\.id))
        for _ in 0..<3 {
            workspace.paste(image, viewCenter: point(40, 30))
            let id = try #require(workspace.selectedLayerID)
            #expect(!seen.contains(id))
            seen.insert(id)
            workspace.undo()
        }
    }

    @Test func everyItemActsOrSaysWhy() throws {
        var empty = PhotoWorkspace()
        #expect(empty.copyHelp == "Open an image first.")
        #expect(empty.cutHelp == "Open an image first.")
        #expect(empty.pasteHelp(false) == "Nothing to paste.")
        let emptyCopy = empty.copySelection(), emptyCut = empty.cutSelection()
        #expect(emptyCopy == nil && emptyCut == nil)
        #expect(empty.canvas == nil)

        var workspace = try patterned()
        #expect(workspace.copyHelp == nil && workspace.cutHelp == nil && workspace.pasteHelp(true) == nil)
        let imageTaken = workspace.copySelection()
        let image = try #require(imageTaken)
        let beforeCut = workspace
        let cut = workspace.cutSelection()
        #expect(cut != nil)
        #expect(workspace != beforeCut)
        let beforePaste = workspace
        workspace.paste(image, viewCenter: point(40, 30))
        #expect(workspace != beforePaste)
    }
}
