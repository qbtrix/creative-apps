// PhotoGradientToolTests.swift: MJ-PG, the Gradient tool's Model walk
// (gradient-fill PG-1 writes it, PG-3 turns it on). A drag draws the tool's
// `Fill` (default black to white, linear) into the selected layer from the
// press to the release, inside the selection when there is one, dithered so
// an 8-bit export doesn't band, as one "Gradient" undo step. The agent's
// `image.gradient` runs the same, and RJ-P19 (Tests/RealJobs/photo/sky-gradient)
// passes. Runs on Linux and macOS.
import CoreRaster
import FlareCore
import Foundation
@testable import PhotoModel
import SuiteKernel
import Testing

@Suite struct PhotoGradientToolTests {
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
        try rgba(workspace, x, y).first
    }

    /// The exported 8-bit sRGB (r, g, b, a) at (x, y); empty outside the image.
    static func rgba(_ workspace: PhotoWorkspace, _ x: Int, _ y: Int) throws -> [UInt8] {
        let image = try workspace.exportPixels(as: .png)
        let at = (y * image.width + x) * 4
        return image.rgba8.indices.contains(at + 3) ? Array(image.rgba8[at..<(at + 4)]) : []
    }

    /// RJ-P19's sky: deep blue at the top to pale blue, as sRGB components.
    static let deepBlue = Color(r: 0.0625, g: 0.1875, b: 0.5625), paleBlue = Color(r: 0.75, g: 0.875, b: 1)
    static let sky = Fill.linear(stops: [GradientStop(offset: 0, color: deepBlue), GradientStop(offset: 1, color: paleBlue)],
                                 start: Point(x: 0, y: 0), end: Point(x: 1, y: 0))

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
        // Black to white over 2048 rows is about 8 rows per 8-bit level: undithered, each level repeats 8 rows.
        // Rows of pure black or white are the stops themselves (OKLab stays under half a level for ~100 rows
        // next to black), not a band, so they don't count.
        var workspace = try Self.gray(8, 2048)
        stroke(&workspace, .gradient, from: point(4, 0), to: point(4, 2047))
        let image = try workspace.exportPixels(as: .png)
        let rows = stride(from: 0, to: image.rgba8.count, by: image.width * 4).map {
            Array(image.rgba8[$0..<min($0 + image.width * 4, image.rgba8.count)])
        }
        let flat = Set([0, 255].map { v in Array([[UInt8]](repeating: [UInt8(v), UInt8(v), UInt8(v), 255], count: 8).joined()) })
        var run = 1, longest = 1
        for (above, row) in zip(rows, rows.dropFirst()) where !flat.contains(row) {
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
        #expect(workspace.statusMessage == nil, "a click is not an error")
    }

    @Test func drawGradientWritesTheSelectedLayer() throws {
        var workspace = try Self.gray()
        try workspace.drawGradient(from: point(0, 0), to: point(0, 63))
        #expect(try Self.red(workspace, 30, 0) ?? 255 <= 2)
        #expect(workspace.undoActionName == "Undo Gradient")
    }

    /// The stops are sRGB, as the editor shows them: the first row is the first stop's bytes, not those of the
    /// same numbers read as linear light.
    @Test func firstRowIsDeepBlue() throws {
        var workspace = try Self.gray()
        try workspace.drawGradient(Self.sky, from: point(0, 0), to: point(0, 64))
        let want = [Self.deepBlue.r, Self.deepBlue.g, Self.deepBlue.b].map { Int(($0 * 255).rounded()) }
        for x in [0, 13, 63] {
            let got = try Self.rgba(workspace, x, 0).prefix(3).map(Int.init)
            #expect(got.count == 3 && zip(got, want).allSatisfy { abs($0 - $1) <= 2 }, "\(got) is not \(want)")
        }
    }

    @Test func radialRunsFromTheCentreOut() throws {
        var workspace = try Self.gray()
        let radial = Fill.radial(stops: ToolOptions.defaultGradient.stops, center: Point(x: 0.5, y: 0.5), radius: 0.5)
        try workspace.drawGradient(radial, from: point(32, 32), to: point(32, 0))
        #expect(try Self.red(workspace, 32, 32) ?? 255 <= 2, "the centre is the first stop")
        #expect(try Self.red(workspace, 0, 0) ?? 0 >= 250, "a corner is past the edge")
        #expect(try Self.red(workspace, 63, 32) == Self.red(workspace, 32, 63), "it is round")
    }

    // MARK: image.gradient

    static func params(_ stops: [(Double, Double, Double, Double)], type: String = "linear") -> JSONValue {
        .object([
            "type": .string(type),
            "stops": .array(stops.map { s in
                .object(["offset": .number(s.0), "r": .number(s.1), "g": .number(s.2), "b": .number(s.3), "a": .number(1)])
            }),
            "from": .object(["x": .number(0), "y": .number(0)]), "to": .object(["x": .number(0), "y": .number(63)]),
        ])
    }

    @Test func imageGradientDrawsOneStepAndLeavesTheToolsFill() throws {
        var workspace = try Self.gray()
        _ = try PhotoWorkspace.catalog.run("image.gradient", params: Self.params([(0, 0, 0, 0), (1, 1, 1, 1)]), on: &workspace)
        #expect(try Self.red(workspace, 30, 0) ?? 255 <= 2)
        #expect(try Self.red(workspace, 30, 63) ?? 0 >= 250)
        #expect(workspace.undoActionName == "Undo Gradient")
        #expect(workspace.toolOptions.gradient == ToolOptions.defaultGradient)
    }

    @Test func imageGradientRefusesOneStopAndNoImage() throws {
        var workspace = try Self.gray()
        #expect {
            try PhotoWorkspace.catalog.run("image.gradient", params: Self.params([(0, 0, 0, 0)]), on: &workspace)
        } throws: { error in
            if case .malformedParams? = error as? CatalogError { true } else { false }
        }
        #expect(!workspace.canUndo)
        var empty = PhotoWorkspace()
        #expect(PhotoWorkspace.catalog.availability("image.gradient", on: empty) == .unavailable(PhotoWorkspace.noImage))
        #expect(throws: CatalogError.self) {
            try PhotoWorkspace.catalog.run("image.gradient", params: Self.params([(0, 0, 0, 0), (1, 1, 1, 1)]), on: &empty)
        }
    }

    @Test func selectRectSelectsThePixelsInsideTheImage() throws {
        var workspace = try Self.gray()
        let rect: JSONValue = .object(["minX": .number(-5), "minY": .number(0), "maxX": .number(25), "maxY": .number(32)])
        _ = try PhotoWorkspace.catalog.run("select.rect", params: rect, on: &workspace)
        #expect(workspace.selection == PixelRect(x: 0, y: 0, width: 25, height: 32))
        let outside: JSONValue = .object(["minX": .number(100), "minY": .number(0), "maxX": .number(104), "maxY": .number(4)])
        _ = try PhotoWorkspace.catalog.run("select.rect", params: outside, on: &workspace)
        #expect(workspace.selection == nil) // a rectangle off the image selects nothing
    }

    // MARK: RJ-P19

    /// The sky job's script, run as the real-jobs harness runs it, and its one PNG.
    static func skyJob() throws -> PixelBuffer {
        let folder = PhotoJob.root.appendingPathComponent("sky-gradient")
        let script = try JSONDecoder().decode(PhotoJob.Script.self, from: Data(contentsOf: folder.appendingPathComponent("sky-gradient.jobs.json")))
        var doc = try PhotoHeadless.open(Data(contentsOf: folder.appendingPathComponent("input/grey-256.png")), name: "grey-256.png")
        let report = PhotoHeadless.catalog.runBatch(script.steps, on: &doc, atomic: script.atomic)
        #expect(report.stoppedAt == nil, "\(report.steps.compactMap(\.error))")
        let data = try #require(try doc.export(script.output.format, options: script.output.options).first?.data)
        return try PNG.read(data)
    }

    @Test func skyGradientJobPasses() throws {
        #expect(try PhotoJob.check("sky-gradient") == [])
        let image = try Self.skyJob()
        let bytes = try image.rgba8(), width = image.width
        #expect(image.width == 256 && image.height == 256)
        let rows = (0..<image.height).map { y in Array(bytes[(y * width * 4)..<((y + 1) * width * 4)]) }
        // The top half: the first row within 2/255 of deep blue, never darker going down, no run of more than 4 equal rows.
        let want = [Self.deepBlue.r, Self.deepBlue.g, Self.deepBlue.b].map { Int(($0 * 255).rounded()) }
        let first = rows.first ?? []
        #expect(stride(from: 0, to: first.count, by: 4).allSatisfy { x in (0..<3).allSatisfy { abs(Int(first[x + $0]) - want[$0]) <= 2 } })
        let mean = rows.prefix(128).map { row in row.enumerated().filter { $0.offset % 4 == 2 }.reduce(0) { $0 + Int($1.element) } }
        #expect(zip(mean, mean.dropFirst()).allSatisfy { $0 <= $1 }, "a row is darker than the one above it")
        var run = 1, longest = 1
        for (above, row) in zip(rows.prefix(128), rows.prefix(128).dropFirst()) {
            run = row == above ? run + 1 : 1
            longest = max(longest, run)
        }
        #expect(longest <= 4, "\(longest) equal rows: the sky bands")
        // The bottom half is the original grey.
        #expect(rows.dropFirst(128).allSatisfy { $0 == Array([[UInt8]](repeating: [128, 128, 128, 255], count: width).joined()) })
    }
}
