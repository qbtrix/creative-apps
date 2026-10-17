// HaloTextEdits.swift (TX-1, #430): a text layer's words and size, edited
// from the inspector's TEXT section. Each committed change is one named step
// through `edit` ("Edit Text", "Change Text Size"); a size scrub coalesces on
// "<layer id>.fontSize" until `endTextSizeScrub()`. Both edits store the line
// box `services.text` measures (the 0.6 em estimate without one), so the
// viewer, hit testing and the rendered pixels share one box. An empty or
// all-blank string is refused with `.emptyText` and records nothing; a NaN
// size is ignored. Linux-safe: no UI imports.

extension HaloTextContent {
    /// The sizes a text layer takes, in composition pixels; writes clamp.
    public static let fontSizeRange: ClosedRange<Double> = 1...1000

    /// The size row's value: "96 px", "72.5 px"; "–" when not finite.
    public var sizeText: String {
        guard fontSize.isFinite else { return "–" }
        let tenths = (fontSize * 10).rounded() / 10
        let whole = tenths.rounded()
        return tenths == whole && abs(whole) < 1e15 ? "\(Int(whole)) px" : "\(tenths) px"
    }
}

extension HaloProject {
    /// The TEXT field's identifier, where an empty commit's refusal shows.
    static let textStringControl = "halo.inspector.text.string"

    /// The size row's identifier.
    static let textSizeControl = "halo.inspector.text.size"

    /// The selected text layer's words and size (the default "Text" at 72 when
    /// it has none); nil with no layer selected or a layer of another kind.
    public var selectedText: HaloTextContent? {
        guard let layer = selectedLayer, layer.kind == .text else { return nil }
        return layer.text ?? HaloTextContent()
    }

    /// Sets the selected text layer's words, each newline turned into a space
    /// (text is one line), and stores its measured box. An empty or all-blank
    /// string is refused with `.emptyText` under the TEXT field. One step,
    /// "Edit Text", unless the words are unchanged; nothing on another kind.
    public mutating func setText(_ string: String) {
        let rasterizer = services.text  // read before `edit`: its closure can't touch `self`
        edit("Edit Text", control: Self.textStringControl) { doc in
            guard let at = try doc.selectedTextLayerIndices() else { return }
            let (c, l) = at
            let line = String(string.map { $0.isNewline ? " " : $0 })
            guard !line.allSatisfy(\.isWhitespace) else { throw HaloEditError.emptyText }
            var content = doc.compositions[c].layers[l].text ?? HaloTextContent()
            content.string = line
            doc.compositions[c].layers[l].text = Self.measured(content, by: rasterizer)
        }
    }

    /// Sets the selected text layer's size, clamped to `fontSizeRange`, and
    /// stores its measured box. A scrub's writes are one step, "Change Text
    /// Size", until `endTextSizeScrub()`. A NaN or infinite size does nothing.
    public mutating func setFontSize(_ size: Double) {
        guard size.isFinite else { return }
        let rasterizer = services.text
        let key = selectedLayerID.map { "\($0).fontSize" }
        edit("Change Text Size", control: Self.textSizeControl, coalesceKey: key) { doc in
            guard let at = try doc.selectedTextLayerIndices() else { return }
            let (c, l) = at
            var content = doc.compositions[c].layers[l].text ?? HaloTextContent()
            let range = HaloTextContent.fontSizeRange
            content.fontSize = min(max(size, range.lowerBound), range.upperBound)
            doc.compositions[c].layers[l].text = Self.measured(content, by: rasterizer)
        }
    }

    /// Ends a size scrub, so the next size change is its own step.
    public mutating func endTextSizeScrub() {
        endCoalescing()
    }

    /// `content` with the box `rasterizer` measures; the estimate without one.
    private static func measured(_ content: HaloTextContent, by rasterizer: (any TextRasterizing)?) -> HaloTextContent {
        guard let rasterizer else { return HaloTextContent(string: content.string, fontSize: content.fontSize) }
        let box = rasterizer.measure(content)
        return HaloTextContent(string: content.string, fontSize: content.fontSize, width: box.width, height: box.height)
    }
}

extension HaloDocumentState {
    /// The selected composition's and layer's indexes when that layer is a
    /// text layer; nil for another kind. `.noComposition` or `.noLayerSelected`
    /// without them.
    fileprivate func selectedTextLayerIndices() throws -> (composition: Int, layer: Int)? {
        let at = try selectedLayerIndices()
        return compositions[at.composition].layers[at.layer].kind == .text ? at : nil
    }
}
