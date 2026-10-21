// PhotoGradientToolTests.swift: MJ-PG, the Gradient tool's Model walk
// (gradient-fill PG-1 writes it, PG-3 turns it on). A drag draws the tool's
// `Fill` (default black to white, linear) into the selected layer from the
// press to the release, inside the selection when there is one, dithered so
// an 8-bit export doesn't band, as one "Gradient" undo step. Runs on Linux
// and macOS.
import CoreRaster
import PhotoModel
import Testing

@Suite(.disabled("waits on PG-3")) struct PhotoGradientToolTests {
    /// A `width` x `height` image of one opaque sRGB gray.
    static func gray(_ width: Int = 64, _ height: Int = 64, level: UInt8 = 128) throws -> PhotoWorkspace {
        var workspace = PhotoWorkspace()
        let pixel: [UInt8] = [level, level, level, 255]
        try workspace.open(rgba8: Array([[UInt8]](repeating: pixel, count: width * height).joined()),
                           width: width, height: height, name: "gray.png")
        return workspace
    }

    /// The exported 8-bit sRGB red at (x, y).
    static func red(_ workspace: PhotoWorkspace, _ x: Int, _ y: Int) throws -> UInt8? {
        let image = try workspace.exportPixels(as: .png)
        let at = (y * image.width + x) * 4
        return image.rgba8.indices.contains(at) ? image.rgba8[at] : nil
    }

    @Test func theToolsFillIsBlackToWhiteLinear() {
        let gradient = PhotoWorkspace().toolOptions.gradient
        #expect(gradient.stops.map(\.color) == [.black, .white])
        #expect(gradient.stops.map(\.offset) == [0, 1])
        if case .linear = gradient {} else { Issue.record("the default gradient is not linear") }
    }

    @Test func staysInSelection() throws {
        var workspace = try Self.gray()
        stroke(&workspace, .marquee, from: point(0, 0), to: point(64, 32))
        stroke(&workspace, .gradient, from: point(32, 0), to: point(32, 31))
        #expect(try Self.red(workspace, 32, 0) ?? 255 <= 2, "the first row is the first stop")
        #expect(try Self.red(workspace, 32, 31) ?? 0 >= 250, "the last row is the last stop")
        for y in 32..<64 {
            #expect(try Self.red(workspace, 10, y) == 128, "row \(y) is outside the selection")
        }
    }

    @Test func noSelectionFillsTheLayer() throws {
        var workspace = try Self.gray()
        stroke(&workspace, .gradient, from: point(0, 32), to: point(63, 32))
        #expect(try Self.red(workspace, 0, 5) ?? 255 <= 2)
        #expect(try Self.red(workspace, 63, 60) ?? 0 >= 250)
        #expect(try Self.red(workspace, 32, 32) != 128)
    }

    @Test func noBanding() throws {
        // Black to white over 2048 rows is 8 rows per 8-bit level: undithered, each level repeats 8 rows.
        var workspace = try Self.gray(8, 2048)
        stroke(&workspace, .gradient, from: point(4, 0), to: point(4, 2047))
        let image = try workspace.exportPixels(as: .png)
        let rows = stride(from: 0, to: image.rgba8.count, by: image.width * 4).map {
            Array(image.rgba8[$0..<min($0 + image.width * 4, image.rgba8.count)])
        }
        var run = 1, longest = 1
        for (above, row) in zip(rows, rows.dropFirst()) {
            run = row == above ? run + 1 : 1
            longest = max(longest, run)
        }
        #expect(longest <= 4, "\(longest) equal rows in a row")
    }

    @Test func aDragIsOneGradientStep() throws {
        var workspace = try Self.gray()
        let id = try #require(workspace.selectedLayerID)
        let before = try #require(workspace.pixels[id])
        let steps = workspace.historySteps.count
        workspace.selectTool(.gradient)
        workspace.drag(from: point(0, 0), to: point(10, 10))
        workspace.drag(from: point(0, 0), to: point(40, 40))
        workspace.drag(from: point(0, 0), to: point(63, 63))
        workspace.endDrag()
        #expect(workspace.historySteps.count == steps + 1)
        #expect(workspace.undoActionName == "Undo Gradient")
        workspace.undo()
        #expect(workspace.pixels[id] == before)
    }

    @Test func aClickDrawsNothing() throws {
        var workspace = try Self.gray()
        let before = workspace.pixels
        stroke(&workspace, .gradient, from: point(20, 20), to: point(20, 20))
        #expect(workspace.pixels == before && !workspace.canUndo)
    }

    @Test func drawGradientWritesTheSelectedLayer() throws {
        var workspace = try Self.gray()
        try workspace.drawGradient(from: point(0, 0), to: point(0, 63))
        #expect(try Self.red(workspace, 30, 0) ?? 255 <= 2)
        #expect(workspace.undoActionName == "Undo Gradient")
    }
}
