// HaloText+Layout.swift (text-style TS-10, slice TS-halo): a text layer off the standard face, or of more than one
// line, is set by the kernel's `TextStyleRules.layout`, so the rasterizer measures and draws one layout and the
// viewer and the render show the same lines. `laidOut` gives each line's text, lead x and baseline and the extent;
// Halo has no wrapping box, so lines break only at newlines. Linux-safe.
import SuiteKernel

/// One laid-out line of a Halo text layer: its text (no trailing space or newline), its lead x and its baseline y,
/// in pixels from the box's top left.
public struct HaloTextLine: Sendable, Equatable {
    public let text: String
    public let x: Double
    public let baseline: Double
}

/// A text layer laid out by the kernel: its lines and the width and height they fill.
public struct HaloTextSetting: Sendable, Equatable {
    public let lines: [HaloTextLine]
    public let width: Double
    public let height: Double
}

extension HaloTextContent {
    /// True when the layer draws through the kernel's layout: a face or paragraph off the standard, or two lines.
    public var drawsThroughLayout: Bool {
        style != TextStyle.standard || string.contains(where: \.isNewline)
    }

    /// Letter spacing in pixels: tracking is thousandths of an em.
    public var trackingPoints: Double { style.paragraph.tracking / 1000 * fontSize }

    /// The layer set in its style at `fontSize`, measured by `advances` (each grapheme's advance without tracking,
    /// the font's ascent and descent); nil when the layout refuses.
    public func laidOut(advances: ([String]) -> (advances: [Double], ascent: Double, descent: Double)) -> HaloTextSetting? {
        var kernel = style
        kernel.size = fontSize
        guard let layout = try? TextStyleRules.layout(string, style: kernel, advances: advances) else { return nil }
        let graphemes = Array(string)
        let lines = layout.lines.map { line in
            let start = min(max(line.graphemes.lowerBound, 0), graphemes.count)
            var text = String(graphemes[start..<max(start, min(line.graphemes.upperBound, graphemes.count))])
            while let last = text.last, last.isWhitespace { text.removeLast() }
            return HaloTextLine(text: text, x: line.x.first ?? 0, baseline: line.baseline)
        }
        return HaloTextSetting(lines: lines, width: layout.bounds.maxX, height: layout.bounds.maxY)
    }
}
