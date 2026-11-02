// HaloText+Kernel.swift (text-style TS-9, slice TS-halo): Halo's project is a kernel `TextStyleTarget`, so the
// kernel's text commands (`TextCommands`) run on the selected text layer. A layer keeps its face and paragraph in
// `HaloTextContent.style`; its size stays `fontSize` and its colour the layer's, so `textStyle` reads both from
// there and `setTextStyle` writes the size back to `fontSize` (Halo's 1...1000). The style key is written only away
// from the standard face and paragraph, so a project saved before it re-saves byte for byte. Without a rasterizer
// the box is the estimate: 0.6 em a character plus tracking, one em for the first line and line height x one em
// for each line after it. Linux-safe.
import SuiteKernel

extension HaloTextContent: Codable {
    enum CodingKeys: String, CodingKey { case string, fontSize, width, height, style }

    /// Decodes a text layer's content; one without a style takes the standard face and paragraph.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(string: c.decode(String.self, forKey: .string), fontSize: c.decode(Double.self, forKey: .fontSize),
                      width: c.decode(Double.self, forKey: .width), height: c.decode(Double.self, forKey: .height),
                      style: c.decodeIfPresent(TextStyle.self, forKey: .style) ?? .standard)
    }

    /// Writes the content, leaving the style out at the standard face and paragraph.
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(string, forKey: .string)
        try c.encode(fontSize, forKey: .fontSize)
        try c.encode(width, forKey: .width)
        try c.encode(height, forKey: .height)
        let face = Self.face(style)
        if face != TextStyle.standard { try c.encode(face, forKey: .style) }
    }

    /// `s`'s face and paragraph only: size, colour and box width at the standard's (Halo keeps size in `fontSize`,
    /// colour on the layer, and has no wrapping box), the weight in 100...900.
    static func face(_ s: TextStyle) -> TextStyle {
        var face = s
        (face.size, face.rgba, face.paragraph.boxWidth) = (TextStyle.standard.size, TextStyle.standard.rgba, nil)
        face.weight = min(max(s.weight, 100), 900)
        return face
    }

    /// The estimated box of `string` at `fontSize` in `style`: the longest line at 0.6 em a character plus
    /// tracking (at least one character), one em for the first line and `lineHeight` em for each line after it.
    static func estimate(_ string: String, fontSize: Double, style: TextStyle) -> (width: Double, height: Double) {
        let lines = string.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
        let longest = lines.map(\.count).max() ?? 0
        let em = 0.6 + style.paragraph.tracking / 1000
        let width = fontSize * em * Double(max(longest, 1))
        let height = fontSize * (1 + style.paragraph.lineHeight * Double(max(lines.count - 1, 0)))
        return (width, height)
    }
}

extension HaloProject: TextStyleTarget {
    /// Where a refused style change shows.
    static let textStyleControl = "halo.inspector.text.style"

    /// The selected text layer's style: its face and paragraph, `fontSize` as the size and the layer's colour.
    public var textStyle: TextStyle? {
        guard let text = selectedText, let layer = selectedLayer else { return nil }
        var style = text.style
        style.size = text.fontSize
        style.rgba = [layer.color.red, layer.color.green, layer.color.blue].map(Self.byte) + [255]
        return style
    }

    /// Why the text commands can't run: no composition; nil otherwise (with no text layer the kernel asks for one).
    public var textHelp: String? {
        selectedComposition == nil ? HaloEditError.noComposition.message : nil
    }

    /// Every weight, upright and italic: Halo has no font list of its own yet. Empty for an empty name.
    public func faces(of family: String) -> [(weight: Int, italic: Bool)] {
        family.isEmpty ? [] : stride(from: 100, through: 900, by: 100).flatMap { [($0, false), ($0, true)] }
    }

    /// Sets the selected text layer's face, paragraph and size (clamped to `fontSizeRange`) and remeasures its box,
    /// as one step named `name`; steps under one `drag` fold into one. Throws without a text layer, changing nothing.
    public mutating func setTextStyle(_ s: TextStyle, name: String, drag: String?) throws {
        if let textHelp { throw CatalogError.failed(id: "text", message: textHelp) }
        guard textStyle != nil else { throw CatalogError.failed(id: "text", message: Self.noTextLayerHelp) }
        let rasterizer = services.text  // read before `edit`: its closure can't touch `self`
        let key = drag.flatMap { drag in selectedLayerID.map { "\($0).text-\(drag)" } }
        let set = edit(name, control: Self.textStyleControl, coalesceKey: key) { doc in
            let (c, l) = try doc.selectedLayerIndices()
            var content = doc.compositions[c].layers[l].text ?? HaloTextContent()
            content.style = HaloTextContent.face(s)
            let range = HaloTextContent.fontSizeRange
            if s.size.isFinite { content.fontSize = min(max(s.size, range.lowerBound), range.upperBound) }
            doc.compositions[c].layers[l].text = Self.measured(content, by: rasterizer)
        }
        if !set { throw CatalogError.failed(id: "text", message: refusal?.message ?? Self.noTextLayerHelp) }
    }

    /// A 0...1 colour channel as an 8-bit level; NaN is 0.
    static func byte(_ channel: Double) -> UInt8 {
        channel.isNaN ? 0 : UInt8((min(max(channel, 0), 1) * 255).rounded())
    }
}
