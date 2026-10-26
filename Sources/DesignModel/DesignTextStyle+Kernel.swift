// DesignTextStyle+Kernel.swift (text-style TS-7): Design's workspace is a kernel `TextStyleTarget`, so the seven
// text commands in `TextCommands` run on the selected text layers the way Halo's do. A layer's `DesignTextStyle`
// keeps its file keys here: italic, line height and tracking are written only away from their defaults, so a file
// written before them re-saves byte for byte. `setTextStyle` sets every selected unlocked text layer as one step
// (steps under one drag token fold into one) and refits each box (#3339): with a measurer (`services.text`) an
// auto-width box re-measures on a face, size, line height or tracking change and keeps its leading edge, centre or
// trailing edge by alignment, and a fixed-width one keeps its width and reflows its height; without one a size
// change scales the box, as the inspector's row does. Each layer takes only the fields the command changed, so a
// size change on a mixed selection keeps every layer's family. Linux-safe.
import SuiteKernel
import SuiteModel

extension DesignTextStyle {
    enum CodingKeys: String, CodingKey { case family, size, weight, alignment, fixedWidth, italic, lineHeight, tracking }
    /// The defaults a file leaves out: upright, line height 1.2, no tracking.
    static let defaultLineHeight = 1.2

    /// Decodes a style; a file without `fixedWidth` is auto width (nil), one without italic, line height or
    /// tracking takes their defaults.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            family: c.decode(String.self, forKey: .family), size: c.decode(Double.self, forKey: .size),
            weight: c.decode(Int.self, forKey: .weight), alignment: c.decode(DesignTextAlignment.self, forKey: .alignment),
            fixedWidth: c.decodeIfPresent(Bool.self, forKey: .fixedWidth))
        italic = try c.decodeIfPresent(Bool.self, forKey: .italic) ?? false
        lineHeight = try c.decodeIfPresent(Double.self, forKey: .lineHeight) ?? Self.defaultLineHeight
        tracking = try c.decodeIfPresent(Double.self, forKey: .tracking) ?? 0
    }

    /// Writes the style, leaving out a nil `fixedWidth` and italic, line height and tracking at their defaults.
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(family, forKey: .family)
        try c.encode(size, forKey: .size)
        try c.encode(weight, forKey: .weight)
        try c.encode(alignment, forKey: .alignment)
        try c.encodeIfPresent(fixedWidth, forKey: .fixedWidth)
        if italic { try c.encode(italic, forKey: .italic) }
        if lineHeight != Self.defaultLineHeight { try c.encode(lineHeight, forKey: .lineHeight) }
        if tracking != 0 { try c.encode(tracking, forKey: .tracking) }
    }

    /// The kernel's view of this style, drawn in `color`, wrapping at `boxWidth` when it has one.
    func kernel(_ color: DesignColor, boxWidth: Double?) -> TextStyle {
        TextStyle(family: family, weight: weight, italic: italic, size: size, rgba: [color.red, color.green, color.blue, 255],
                  paragraph: ParagraphStyle(alignment: alignment, lineHeight: lineHeight, tracking: tracking, boxWidth: boxWidth))
    }

    /// This style with each field of `s` that differs from `base` (every field when `base` is nil), so a
    /// multi-selection takes only the edited field; its width mode and the layer's colour stay. Size, line height
    /// and tracking keep the kernel's ranges (`TextStyleRules.range`).
    func taking(_ s: TextStyle, over base: TextStyle?) -> DesignTextStyle {
        var style = self
        let kept = TextStyleRules.setting(TextStyleRules.setting(TextStyleRules.setting(s, .size, to: s.size),
                                                                 .lineHeight, to: s.paragraph.lineHeight), .tracking, to: s.paragraph.tracking)
        if base?.family != s.family { style.family = s.family }
        if base?.weight != s.weight { style.weight = Swift.min(Swift.max(s.weight, 100), 900) }
        if base?.italic != s.italic { style.italic = s.italic }
        if base?.paragraph.alignment != s.paragraph.alignment { style.alignment = s.paragraph.alignment }
        if base?.size != s.size, s.size.isFinite { style.size = kept.size }
        if base?.paragraph.lineHeight != s.paragraph.lineHeight { style.lineHeight = kept.paragraph.lineHeight }
        if base?.paragraph.tracking != s.paragraph.tracking { style.tracking = kept.paragraph.tracking }
        return style
    }

    /// True when `other` measures differently: another face, size, line height or tracking.
    func measuresApart(from other: DesignTextStyle) -> Bool {
        family != other.family || weight != other.weight || italic != other.italic || size != other.size
            || lineHeight != other.lineHeight || tracking != other.tracking
    }
}

extension DesignWorkspace: TextStyleTarget {
    /// The primary selected text layer: the last selected node that is text.
    var selectedTextNode: DesignNode? {
        selectedNodeIDs.reversed().lazy.compactMap { self.findNode($0) }.first { $0.kind == .text }
    }

    /// The primary selected text layer's style; nil when no text layer is selected.
    public var textStyle: TextStyle? {
        guard let node = selectedTextNode else { return nil }
        return node.textStyle.kernel(node.fill, boxWidth: node.textStyle.fixedWidth == true ? node.frame.width : nil)
    }

    /// Why the text commands can't run: a text edit open, or the primary text layer locked; nil when they can
    /// (and with no text layer, where `TextCommands` says to select one).
    public var textHelp: String? {
        guard let node = selectedTextNode else { return nil }
        if editingTextID != nil { return styleHelp(.textStyle) }
        return lockHelp(node.id)
    }

    /// The faces `family` has in the measurer's font list; with no list, or a family it doesn't list, every
    /// weight upright and italic, as the inspector offers today. Empty for an empty name.
    public func faces(of family: String) -> [(weight: Int, italic: Bool)] {
        if let listed = services.text?.families().first(where: { $0.name == family }) {
            return listed.faces.map { ($0.weight, $0.italic) }
        }
        return family.isEmpty ? [] : stride(from: 100, through: 900, by: 100).flatMap { [($0, false), ($0, true)] }
    }

    /// Sets the fields `s` changes from the primary text layer's style on every selected unlocked text layer as
    /// one step named `name`, refitting each box; steps under one `drag` fold into one. A style that changes
    /// nothing refuses with `.unchanged`.
    public mutating func setTextStyle(_ s: TextStyle, name: String, drag: String?) throws {
        if let why = textHelp { throw CatalogError.failed(id: "text", message: why) }
        guard gesture == nil else { throw CatalogError.failed(id: "text", message: "Finish the drag first.") }
        let ids = selectedNodeIDs.filter { findNode($0)?.kind == .text && !isLockedInTree($0) }
        let (before, base) = (snapshot, textStyle)
        let measurer = services.text
        for id in ids {
            _ = pages.update(id) { node in
                let old = node.textStyle
                node.textStyle = old.taking(s, over: base)
                node.frame = Self.refitted(node, from: old, measurer)
            }
        }
        guard snapshot != before else { throw DesignRefusal.unchanged }
        record(name, before: before, coalescing: drag.map { "text-" + $0 })
    }

    /// `node`'s frame after its style changed from `old` (see the file header). Unchanged when nothing it measures
    /// by changed, for empty text, or when measuring fails.
    static func refitted(_ node: DesignNode, from old: DesignTextStyle, _ measurer: (any TextMeasuring)?) -> DesignRect {
        let style = node.textStyle
        guard style.measuresApart(from: old) else { return node.frame }
        let fixed = style.fixedWidth == true
        var frame = node.frame
        guard let measurer else {
            guard old.size.isFinite, old.size > 0, style.size != old.size else { return frame }
            let ratio = style.size / old.size
            if !fixed { frame.width = Swift.max(1, (frame.width * ratio).rounded(.up)) }
            frame.height = Swift.max(1, (frame.height * ratio).rounded(.up))
            return frame
        }
        guard !node.text.isEmpty, let extent = measure(node.text, style, wrap: fixed ? frame.width : nil, measurer) else { return frame }
        let width = fixed ? frame.width : Swift.max(1, extent.width.rounded(.up))
        let across: Double = switch style.alignment {
        case .center: 0.5
        case .trailing: 1.0
        case .leading, .justified: 0
        }
        frame.x += (frame.width - width) * across
        (frame.width, frame.height) = (width, Swift.max(1, extent.height.rounded(.up)))
        return frame
    }

    /// `text` laid out in `style` by the kernel's layout over `measurer`'s advances, wrapped at `wrap` when given;
    /// nil when the measurer or the layout refuses.
    static func measure(_ text: String, _ style: DesignTextStyle, wrap: Double?, _ measurer: any TextMeasuring) -> DesignTextExtent? {
        let weight = Swift.min(Swift.max(Int((Double(style.weight) / 100).rounded()) * 100, 100), 900)
        var failed = false
        let layout = try? TextStyleRules.layout(text, style: style.kernel(.black, boxWidth: wrap)) { graphemes in
            let span = TextSpan(graphemes.joined(), fontFamily: style.family, fontSize: style.size, weight: weight, italic: style.italic)
            guard let metrics = try? measurer.measure([span]).first, metrics.advances.count == graphemes.count else {
                failed = true
                return (Array(repeating: 0, count: graphemes.count), 0, 0)
            }
            return (metrics.advances, metrics.ascent, metrics.descent)
        }
        guard let bounds = layout?.bounds, !failed else { return nil }
        let extent = DesignTextExtent(width: bounds.maxX - bounds.minX, height: bounds.maxY - bounds.minY)
        return extent.width.isFinite && extent.height.isFinite ? extent : nil
    }
}
