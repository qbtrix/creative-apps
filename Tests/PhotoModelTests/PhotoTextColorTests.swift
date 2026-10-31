// PhotoTextColorTests.swift (#5951): `text.set-color` sets the selected text layer's colour, `text.read` reports
// it, the words redraw in it, one drag is one undo step, and it refuses with no text layer or a bad colour.
// Linux and macOS.
import CoreRaster
@testable import PhotoModel
import SuiteKernel
import SuiteModel
import Testing

/// FakeText's metrics and fonts, drawing every frame in its first span's colour so the layer shows what was asked.
private struct SpanColorText: TextServices {
    let fake = FakeText()
    func measure(_ spans: [TextSpan]) throws(SuiteError) -> [SpanMetrics] { try fake.measure(spans) }
    func families() -> [FontFamily] { fake.families() }
    func draw(_ spans: [PlacedSpan], width: Int, height: Int) throws(SuiteError) -> MediaFrame {
        _ = try fake.draw(spans, width: width, height: height)
        let rgba = spans.first?.span.rgba ?? [0, 0, 0, 0]
        return try MediaFrame(width: width, height: height, rgba: Array((0..<(width * height)).map { _ in rgba }.joined()))
    }
}

/// An 800 × 600 image with "SALE" added at (40, 60), drawn in its span's colour; the text layer's id.
private func withSale() throws -> (PhotoWorkspace, PhotoLayer.ID) {
    var services = PhotoServices.fake
    services.text = SpanColorText()
    var workspace = PhotoWorkspace(services: services)
    try workspace.newCanvas(width: 800, height: 600)
    let params = JSONValue.object(["x": .number(40), "y": .number(60), "words": .string("SALE")])
    _ = try PhotoWorkspace.catalog.run("text.add", params: params, on: &workspace)
    return (workspace, try #require(workspace.selectedLayerID))
}

/// `text.set-color` with `rgba`, under `drag` when given.
private func setColor(_ workspace: inout PhotoWorkspace, _ rgba: [Double], drag: String? = nil) throws {
    var fields: [String: JSONValue] = ["rgba": .array(rgba.map(JSONValue.number))]
    if let drag { fields["drag"] = .string(drag) }
    _ = try PhotoWorkspace.catalog.run("text.set-color", params: .object(fields), on: &workspace)
}

@Suite struct PhotoTextColorTests {
    @Test func setColorRedrawsAndReads() throws {
        var (workspace, id) = try withSale()
        try setColor(&workspace, [200, 30, 30, 255])
        #expect(workspace.textStyle?.rgba == [200, 30, 30, 255])
        #expect(workspace.undoActionName == "Undo Text Color")
        let read = try PhotoWorkspace.catalog.run("text.read", params: .object([:]), on: &workspace)
        #expect("\(read)".contains("200") && "\(read)".contains("30"), "text.read doesn't report the colour: \(read)")
        let pixels = try #require(workspace.pixels[id]).rgba8()
        #expect(Array(pixels.prefix(4)) == [200, 30, 30, 255], "the words weren't redrawn in the new colour")
    }

    @Test func oneDragIsOneStep() throws {
        var (workspace, _) = try withSale()
        for red in [50.0, 120, 250] { try setColor(&workspace, [red, 0, 0, 255], drag: "d1") }
        #expect(workspace.textStyle?.rgba == [250, 0, 0, 255])
        workspace.undo()
        #expect(workspace.textStyle?.rgba == TextStyle.standard.rgba)
        #expect(workspace.undoActionName == "Undo Add Text")
    }

    /// The inspector's colour row: a run of picks under one drag is one step; with no text layer the status line says why.
    @Test func theColourRowRunsTheCommand() throws {
        var (workspace, _) = try withSale()
        for red: UInt8 in [40, 90, 210] { workspace.runTextColor([red, 10, 10, 128], drag: "row") }
        #expect(workspace.textStyle?.rgba == [210, 10, 10, 128])
        #expect(workspace.undoActionName == "Undo Text Color")
        workspace.undo()
        #expect(workspace.undoActionName == "Undo Add Text")
        var empty = PhotoWorkspace()
        try empty.newCanvas(width: 80, height: 60)
        empty.runTextColor([1, 2, 3, 255], drag: nil)
        #expect(empty.statusMessage == "Select a text layer first.")
    }

    @Test func needsATextLayer() throws {
        var workspace = PhotoWorkspace()
        #expect(PhotoWorkspace.catalog.availability("text.set-color", on: workspace) == .unavailable("Open an image first."))
        try workspace.newCanvas(width: 800, height: 600)
        #expect(PhotoWorkspace.catalog.availability("text.set-color", on: workspace) == .unavailable("Select a text layer first."))
        #expect(throws: (any Error).self) { try workspace.setTextColor([1, 2, 3, 255]) }
    }

    @Test func refusesABadColour() throws {
        var (workspace, _) = try withSale()
        #expect(throws: (any Error).self) { try setColor(&workspace, [300, 0, 0, 255]) }
        #expect(throws: (any Error).self) { try setColor(&workspace, [0, 0, 0]) }
        #expect(workspace.textStyle?.rgba == TextStyle.standard.rgba)
        #expect(workspace.undoActionName == "Undo Add Text")
    }
}
