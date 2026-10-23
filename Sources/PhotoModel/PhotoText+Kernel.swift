// PhotoText+Kernel.swift (text-layers TX-2 stubs, TX-5 bodies): Photo's text layers on the kernel's text
// commands. The workspace is a `TextStyleTarget` (the selected text layer's style), and `text.add` and
// `text.set-words` join the kernel's seven `TextCommands.specs` in Photo's catalog. Every edit lays the words
// out with `TextStyleRules.layout` (advances from `services.text`), draws them through its `GlyphRasterizing`
// into the layer's tiles at the box's origin, and is one undo step of the whole stack. Linux-safe.
import CoreRaster
import SuiteKernel
import SuiteModel

extension PhotoWorkspace: TextStyleTarget {
    /// text.add's: where the box's top-left goes in canvas pixels, the words, and a style (the standard one when nil).
    public struct TextAddParams: Codable, Sendable { public var x, y: Int; public var words: String; public var style: TextStyle? }
    /// text.set-words': the selected text layer's new words.
    public struct TextWordsParams: Codable, Sendable { public var words: String }

    /// Clear pixels around the laid-out bounds, for glyphs that overhang their advance.
    static let textPadding = 2
    /// The widest or tallest text layer, in pixels.
    static let textLimit = 16_384

    public var textStyle: TextStyle? {
        guard case .text(let text) = selectedLayer?.kind else { return nil }
        return text.style
    }

    public var textHelp: String? { canvas == nil ? "Open an image first." : nil }

    public func faces(of family: String) -> [(weight: Int, italic: Bool)] {
        services.text.families().first { $0.name == family }?.faces.map { ($0.weight, $0.italic) } ?? []
    }

    /// Restyles the selected text layer and redraws it as one step named `name`; steps under one `drag` fold.
    public mutating func setTextStyle(_ s: TextStyle, name: String, drag: String?) throws {
        guard let id = selectedLayerID, case .text(var text) = selectedLayer?.kind else {
            throw CatalogError.unavailable(id: "text", why: "Select a text layer first.")
        }
        text.style = s
        try redraw(id, as: text, named: name, coalescing: drag.map { "text-style-\(id)-\($0)" })
    }

    /// Adds a text layer of `p`'s words above the selected layer, selected, in one step.
    mutating func addText(_ p: TextAddParams) throws {
        guard canvas != nil else { throw CatalogError.unavailable(id: "text.add", why: "Open an image first.") }
        guard !p.words.isEmpty else { throw CatalogError.failed(id: "text.add", message: "Type some words first.") }
        let text = PhotoTextLayer(words: p.words, style: p.style ?? .standard,
                                  origin: Mask.Point(x: Double(p.x), y: Double(p.y)), boxWidth: nil)
        let drawn = try rasterized(text)
        record(.stack(stackState), named: "Add Text")
        let above = selectedLayerID.flatMap(index(of:)) ?? 0
        let name = String(p.words.prefix { !$0.isNewline }.prefix(40))
        let id = insertLayer(named: name.isEmpty ? "Text" : name, pixels: drawn.pixels, kind: .text(text), at: above)
        if let at = index(of: id) { (layers[at].offsetX, layers[at].offsetY) = (drawn.x, drawn.y) }
        selectedLayerID = id
        touch(.all)
    }

    /// Replaces the selected text layer's words and redraws it in one step.
    mutating func setTextWords(_ words: String) throws {
        guard let id = selectedLayerID, case .text(var text) = selectedLayer?.kind else {
            throw CatalogError.unavailable(id: "text.set-words", why: "Select a text layer first.")
        }
        guard !words.isEmpty else { throw CatalogError.failed(id: "text.set-words", message: "Type some words first.") }
        text.words = words
        try redraw(id, as: text, named: "Edit Text", coalescing: nil)
    }

    /// Layer `id` becomes `text`, drawn afresh; nothing changes when drawing throws.
    private mutating func redraw(_ id: PhotoLayer.ID, as text: PhotoTextLayer, named name: String, coalescing: String?) throws {
        let drawn = try rasterized(text)
        guard let at = index(of: id) else { return }
        record(.stack(stackState), named: name, coalescing: coalescing)
        layers[at].kind = .text(text)
        (layers[at].offsetX, layers[at].offsetY) = (drawn.x, drawn.y)
        pixels[id] = drawn.pixels
        touch(.all)
    }

    /// `text` laid out and drawn: its pixels and where their top-left sits on the canvas.
    func rasterized(_ text: PhotoTextLayer) throws -> (pixels: TiledPixels, x: Int, y: Int) {
        let service = services.text, style = text.style
        var shaped = style
        shaped.paragraph.boxWidth = text.boxWidth
        // Tracking is the layout's, so the measured advances carry none.
        let span = TextSpan("", fontFamily: style.family, fontSize: style.size, weight: style.weight,
                            italic: style.italic, rgba: style.rgba)
        var failure: (any Error)?
        let layout = try TextStyleRules.layout(text.words, style: shaped) { (graphemes: [String]) in
            var run = span
            run.string = graphemes.joined()
            do {
                if let metrics = try service.measure([run]).first { return (metrics.advances, metrics.ascent, metrics.descent) }
            } catch { failure = error }
            return ([], 0, 0)
        }
        if let failure { throw failure }
        let pad = Double(Self.textPadding), bounds = layout.bounds
        let width = bounds.maxX - bounds.minX + 2 * pad, height = bounds.maxY - bounds.minY + 2 * pad
        let left: Double = text.origin.x + bounds.minX - pad, top: Double = text.origin.y + bounds.minY - pad
        let limit = Double(Self.textLimit)
        guard width <= limit, height <= limit, abs(left) <= limit * 4, abs(top) <= limit * 4 else {
            throw CatalogError.failed(id: "text", message: "The text is too big to draw.")
        }
        let x = Int(left.rounded(FloatingPointRoundingRule.down)), y = Int(top.rounded(FloatingPointRoundingRule.down))
        // The fraction rounding left and up dropped moves every glyph by the same amount.
        let dx = left - Double(x) - bounds.minX + pad, dy = top - Double(y) - bounds.minY + pad
        let graphemes = Array(text.words)
        let placed: [PlacedSpan] = layout.lines.compactMap { line in
            let kept: [(index: Int, x: Double)] = zip(line.graphemes, line.x).filter { (index: Int, _: Double) in
                graphemes.indices.contains(index) && !graphemes[index].isNewline
            }
            guard !kept.isEmpty else { return nil }
            var run = span
            run.string = String(kept.map { graphemes[$0.index] })
            return PlacedSpan(span: run, origins: kept.map { SuitePoint(x: $0.x + dx, y: line.baseline + dy) },
                              degrees: kept.map { _ in 0 })
        }
        let frame = try service.draw(placed, width: Int(width.rounded(FloatingPointRoundingRule.up)) + 1,
                                     height: Int(height.rounded(FloatingPointRoundingRule.up)) + 1)
        return (TiledPixels(try PixelBuffer(rgba8: frame.rgba, width: frame.width, height: frame.height)), x, y)
    }

    /// text.add, text.set-words and the kernel's seven text commands.
    static var textCommands: [CommandSpec<PhotoWorkspace>] {
        [
            .typed("text.add", title: "Add Text", summary: "Adds a text layer above the selected one, its box's top-left at x, y.",
                   kind: .edit, params: TextAddParams.self,
                   schema: .object(["x": .integer("Canvas pixels from the left."), "y": .integer("Canvas pixels from the top."),
                                    "words": .string("The words; a newline starts a paragraph.")], required: ["words", "x", "y"]),
                   example: .object(["x": .number(40), "y": .number(60), "words": .string("SALE")]),
                   availability: { $0.canvas == nil ? .unavailable("Open an image first.") : .available }
            ) { w, p -> JSONValue in try w.addText(p); return .object([:]) },
            .typed("text.set-words", title: "Edit Text", summary: "Replaces the selected text layer's words and redraws it.",
                   kind: .edit, params: TextWordsParams.self,
                   schema: .object(["words": .string("The new words.")], required: ["words"]),
                   example: .object(["words": .string("SALE NOW")]), availability: { wordsAvailability($0) }
            ) { w, p -> JSONValue in try w.setTextWords(p.words); return .object([:]) },
        ] + TextCommands.specs(PhotoWorkspace.self)
    }

    /// text.set-words needs an open image and a selected text layer.
    private static func wordsAvailability(_ workspace: PhotoWorkspace) -> Availability {
        if workspace.canvas == nil { return .unavailable("Open an image first.") }
        return workspace.textStyle == nil ? .unavailable("Select a text layer first.") : .available
    }
}
