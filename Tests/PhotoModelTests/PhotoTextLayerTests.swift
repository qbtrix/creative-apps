// PhotoTextLayerTests.swift (text-layers TX-1 written, TX-5 turned on): a text layer in Photo.
// `PhotoLayerKind.text` holds a `PhotoTextLayer`, the workspace is a kernel `TextStyleTarget`, and `text.add` /
// `text.set-words` list with their ids, schemas and availability. `text.add` makes one text layer above the
// selected one in one step, a size change re-rasterizes its bounds, undo restores the old pixels and style, and
// the layer blends, undoes and composites like a pixel layer. The style edits call `setTextStyle` directly until
// TS-6 builds the kernel's text command bodies. Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreRaster
@testable import PhotoModel
import SuiteKernel
import SuiteModel
import Testing

/// An 800 × 600 white image, its Background layer selected.
private func opened() throws -> PhotoWorkspace {
    var workspace = PhotoWorkspace()
    try workspace.newCanvas(width: 800, height: 600)
    return workspace
}

/// Photo's catalog, which holds the text commands.
private let catalog = PhotoWorkspace.catalog

/// FakeText's metrics and fonts, drawing every frame opaque red so the composite shows where text went.
private struct RedText: TextServices {
    let fake = FakeText()
    func measure(_ spans: [TextSpan]) throws(SuiteError) -> [SpanMetrics] { try fake.measure(spans) }
    func families() -> [FontFamily] { fake.families() }
    func draw(_ spans: [PlacedSpan], width: Int, height: Int) throws(SuiteError) -> MediaFrame {
        _ = try fake.draw(spans, width: width, height: height)
        let red: [UInt8] = [255, 0, 0, 255]
        return try MediaFrame(width: width, height: height, rgba: Array((0..<(width * height)).map { _ in red }.joined()))
    }
}

/// Runs `text.add` with "SALE" at (40, 60) on `workspace`; the new layer's id.
@discardableResult
private func addSale(_ workspace: inout PhotoWorkspace) throws -> PhotoLayer.ID {
    let params = JSONValue.object(["x": .number(40), "y": .number(60), "words": .string("SALE")])
    _ = try #require(catalog).run("text.add", params: params, on: &workspace)
    return try #require(workspace.selectedLayerID)
}

/// The `required` keys of an object schema; nil when `schema` isn't one.
private func required(_ schema: JSONValue) -> [String]? {
    guard case .object(let fields) = schema, case .array(let keys)? = fields["required"] else { return nil }
    return keys.compactMap { if case .string(let key) = $0 { key } else { nil } }
}

@Suite struct PhotoTextLayerTests {
    // The stub contract: what TX-5 keeps.

    @Test func aTextLayerIsAKindOfLayer() throws {
        let text = PhotoTextLayer(words: "SALE", style: .standard, origin: Mask.Point(x: 40, y: 60), boxWidth: nil)
        var layer = PhotoLayer(id: "layer-2", name: "SALE")
        layer.kind = .text(text)
        guard case .text(let kept) = layer.kind else { Issue.record("the kind isn't text: \(layer.kind)"); return }
        #expect(kept == text)
        let json = try JSONEncoder().encode(text)
        #expect(try JSONDecoder().decode(PhotoTextLayer.self, from: json) == text)
    }

    @Test func listsTheTextCommands() throws {
        let catalog = try #require(catalog)
        let text = catalog.ids.filter { $0.hasPrefix("text.") }
        #expect(text == ["text.add", "text.read", "text.set-alignment", "text.set-color", "text.set-font",
                         "text.set-italic", "text.set-line-height", "text.set-size", "text.set-tracking", "text.set-words"])
        let add = try #require(catalog.describe("text.add"))
        #expect(add.title == "Add Text")
        #expect(add.undoable)
        #expect(required(add.params) == ["words", "x", "y"])
        let words = try #require(catalog.describe("text.set-words"))
        #expect(words.title == "Edit Text")
        #expect(required(words.params) == ["words"])
    }

    @Test func noImageSaysWhy() throws {
        let catalog = try #require(catalog)
        let empty = PhotoWorkspace()
        #expect(catalog.availability("text.add", on: empty) == .unavailable("Open an image first."))
        #expect(catalog.availability("text.set-words", on: empty) == .unavailable("Open an image first."))
        #expect(empty.textStyle == nil)
    }

    @Test func editingWordsNeedsATextLayer() throws {
        let catalog = try #require(catalog)
        let workspace = try opened()
        #expect(catalog.availability("text.set-words", on: workspace) == .unavailable("Select a text layer first."))
        #expect(catalog.availability("text.set-size", on: workspace) == .unavailable("Select a text layer first."))
        #expect(workspace.textHelp == nil)
    }

    @Test func facesComeFromTheTextService() throws {
        let workspace = try opened()
        #expect(workspace.faces(of: "Serif").map(\.italic) == [false, true])
        #expect(workspace.faces(of: "No Such Family").isEmpty)
    }

    // MJ-TX: the text edits.

    @Test func addMakesOneLayerAboveTheSelected() throws {
        var workspace = try opened()
        let background = try #require(workspace.selectedLayerID)
        let id = try addSale(&workspace)
        #expect(workspace.layers.map(\.id) == [id, background])
        let layer = try #require(workspace.selectedLayer)
        guard case .text(let text) = layer.kind else { Issue.record("text.add made a \(layer.kind) layer"); return }
        #expect(text.words == "SALE")
        #expect(text.style == .standard)
        #expect(layer.name == "SALE")
        #expect(workspace.undoActionName == "Undo Add Text")
        workspace.undo()
        #expect(workspace.layers.map(\.id) == [background])
    }

    @Test func addDrawsTheWordsAtTheirOrigin() throws {
        var services = PhotoServices.fake
        services.text = RedText()
        var workspace = PhotoWorkspace(services: services)
        try workspace.newCanvas(width: 800, height: 600)
        let id = try addSale(&workspace)
        let layer = try #require(workspace.selectedLayer)
        let pixels = try #require(workspace.pixels[id])
        // FakeText: 4 graphemes of half an em at 24 pt is 48 wide; ascent + descent is one em, 24 high.
        #expect(pixels.width >= 48 && pixels.height >= 24)
        #expect(abs(layer.offsetX - 40) <= 2 && abs(layer.offsetY - 60) <= 2)
        let picture = try workspace.composite()
        #expect(try picture.pixel(x: 50, y: 70) != picture.pixel(x: 10, y: 10), "the text layer isn't composited")
    }

    @Test func addTakesAStyle() throws {
        var workspace = try opened()
        let style = JSONValue.object([
            "family": .string("System"), "weight": .number(900), "italic": .bool(false), "size": .number(120),
            "rgba": .array([.number(0), .number(0), .number(0), .number(255)]),
            "paragraph": .object(["alignment": .string("center"), "lineHeight": .number(1.2), "tracking": .number(0),
                                  "paragraphSpacing": .number(0)]),
        ])
        let params = JSONValue.object(["x": .number(40), "y": .number(60), "words": .string("SUMMER SALE"), "style": style])
        _ = try #require(catalog).run("text.add", params: params, on: &workspace)
        let kept = try #require(workspace.textStyle)
        #expect(kept.weight == 900 && kept.size == 120 && kept.paragraph.alignment == .center)
    }

    @Test func emptyWordsAreRefused() throws {
        var workspace = try opened()
        let params = JSONValue.object(["x": .number(40), "y": .number(60), "words": .string("")])
        #expect(throws: (any Error).self) { try #require(catalog).run("text.add", params: params, on: &workspace) }
        _ = try addSale(&workspace)
        #expect(throws: (any Error).self) {
            try #require(catalog).run("text.set-words", params: .object(["words": .string("")]), on: &workspace)
        }
        #expect(workspace.layers.count == 2)
        #expect(workspace.undoActionName == "Undo Add Text")
    }

    @Test func editingWordsRedrawsInOneStep() throws {
        var workspace = try opened()
        let id = try addSale(&workspace)
        let before = try #require(workspace.pixels[id])
        _ = try #require(catalog).run("text.set-words", params: .object(["words": .string("SALE NOW")]), on: &workspace)
        #expect(try #require(workspace.pixels[id]).width > before.width)
        guard case .text(let text) = workspace.selectedLayer?.kind else { Issue.record("not a text layer"); return }
        #expect(text.words == "SALE NOW")
        #expect(workspace.undoActionName == "Undo Edit Text")
        workspace.undo()
        guard case .text(let old) = workspace.selectedLayer?.kind else { Issue.record("undo lost the text"); return }
        #expect(old.words == "SALE")
        #expect(try #require(workspace.pixels[id]).width == before.width)
    }

    @Test func styleChangeRedraws() throws {
        var workspace = try opened()
        let id = try addSale(&workspace)
        let before = try #require(workspace.pixels[id])
        try workspace.setTextStyle(TextStyleRules.setting(.standard, .size, to: 96), name: "Text Size", drag: nil)
        let after = try #require(workspace.pixels[id])
        #expect(after.width > before.width && after.height > before.height, "a 4x size kept the old bounds")
        #expect(workspace.textStyle?.size == 96)
        #expect(workspace.undoActionName == "Undo Text Size")
    }

    @Test func oneDragIsOneStep() throws {
        var workspace = try opened()
        _ = try addSale(&workspace)
        for size in [30.0, 40, 50] {
            try workspace.setTextStyle(TextStyleRules.setting(.standard, .size, to: size), name: "Text Size", drag: "d1")
        }
        workspace.undo()
        #expect(workspace.textStyle == .standard)
        #expect(workspace.undoActionName == "Undo Add Text")
    }

    @Test func undoRestoresStyle() throws {
        var workspace = try opened()
        let id = try addSale(&workspace)
        let before = try #require(workspace.pixels[id]).rgba8()
        try workspace.setTextStyle(TextStyleRules.setting(.standard, .size, to: 96), name: "Text Size", drag: nil)
        workspace.undo()
        #expect(workspace.textStyle == .standard)
        #expect(try #require(workspace.pixels[id]).rgba8() == before)
    }

    @Test func aLayerUndoKeepsTheTextLayer() throws {
        var workspace = try opened()
        let id = try addSale(&workspace)
        workspace.renameLayer(id, to: "Title")
        workspace.undo()
        #expect(workspace.selectedLayer?.name == "SALE")
    }

    @Test func blendsAndMovesLikeAPixelLayer() throws {
        var workspace = try opened()
        let id = try addSale(&workspace)
        workspace.setBlendMode(id, .multiply)
        workspace.setOpacity(id, percent: 50)
        let layer = try #require(workspace.selectedLayer)
        #expect(layer.blendMode == .multiply)
        #expect(layer.opacity == 0.5)
        guard case .text = layer.kind else { Issue.record("blending turned the layer into \(layer.kind)"); return }
    }
}
