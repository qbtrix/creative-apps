// PhotoTextLayerTests.swift (text-layers TX-1 written, TX-5 turns on): a text layer in Photo. The stub
// contract runs now: `PhotoLayerKind.text` holds a `PhotoTextLayer`, the workspace is a kernel
// `TextStyleTarget`, and `text.add` / `text.set-words` list with their ids, schemas and availability while
// every run refuses with NotBuilt. The edits (`text.add` makes one text layer above the selected one in one
// step, a size change re-rasterizes its bounds, undo restores the old pixels and style, the layer blends and
// moves like a pixel layer) are disabled by name until TX-5 builds PhotoText+Kernel's bodies. Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreRaster
@testable import PhotoModel
import SuiteKernel
import Testing

/// An 800 × 600 white image, its Background layer selected.
private func opened() throws -> PhotoWorkspace {
    var workspace = PhotoWorkspace()
    try workspace.newCanvas(width: 800, height: 600)
    return workspace
}

/// Photo's text commands in a catalog of their own, as TX-5 appends them to Photo's.
private let catalog = try? CommandCatalog<PhotoWorkspace>(app: "photo", PhotoWorkspace.textCommands,
                                                          history: { $0.history.kernel })

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
        #expect(catalog.ids == ["text.add", "text.read", "text.set-alignment", "text.set-font", "text.set-italic",
                                "text.set-line-height", "text.set-size", "text.set-tracking", "text.set-words"])
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
        #expect(catalog.availability("text.set-size", on: workspace) == .unavailable("Text arrives with TX-5."))
    }

    @Test func theStubsRefuseAndChangeNothing() throws {
        var workspace = try opened()
        let params = JSONValue.object(["x": .number(40), "y": .number(60), "words": .string("SALE")])
        #expect(throws: CatalogError.self) { try #require(catalog).run("text.add", params: params, on: &workspace) }
        #expect(throws: (any Error).self) { try workspace.setTextStyle(.standard, name: "Text Size", drag: nil) }
        #expect(workspace.layers.count == 1)
    }

    // MJ-TX: the text edits.

    @Test(.disabled("waits on TX-5: builds PhotoText+Kernel's bodies"))
    func addMakesOneLayerAboveTheSelected() throws {
        var workspace = try opened()
        let background = try #require(workspace.selectedLayerID)
        let id = try addSale(&workspace)
        #expect(workspace.layers.map(\.id) == [id, background])
        let layer = try #require(workspace.selectedLayer)
        guard case .text(let text) = layer.kind else { Issue.record("text.add made a \(layer.kind) layer"); return }
        #expect(text.words == "SALE")
        #expect(text.style == .standard)
        #expect(workspace.undoActionName == "Undo Add Text")
        workspace.undo()
        #expect(workspace.layers.map(\.id) == [background])
    }

    @Test(.disabled("waits on TX-5: builds PhotoText+Kernel's bodies"))
    func styleChangeRedraws() throws {
        var workspace = try opened()
        let id = try addSale(&workspace)
        let before = try #require(workspace.pixels[id])
        let (sizeID, params) = TextIntent.size(96, drag: nil).command
        _ = try #require(catalog).run(sizeID, params: params, on: &workspace)
        let after = try #require(workspace.pixels[id])
        #expect(after.width > before.width && after.height > before.height, "a 4x size kept the old bounds")
        #expect(workspace.textStyle?.size == 96)
    }

    @Test(.disabled("waits on TX-5: builds PhotoText+Kernel's bodies"))
    func undoRestoresStyle() throws {
        var workspace = try opened()
        let id = try addSale(&workspace)
        let before = try #require(workspace.pixels[id]).rgba8()
        let (sizeID, params) = TextIntent.size(96, drag: nil).command
        _ = try #require(catalog).run(sizeID, params: params, on: &workspace)
        workspace.undo()
        #expect(workspace.textStyle == .standard)
        #expect(try #require(workspace.pixels[id]).rgba8() == before)
    }

    @Test(.disabled("waits on TX-5: builds PhotoText+Kernel's bodies"))
    func blendsAndMovesLikeAPixelLayer() throws {
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
