// DesignTextStyle+Layout.swift (text-style TS-8): how the canvas sets a text layer whose style uses the new fields.
// A style at the defaults (upright, line height 1.2, no tracking, not justified) draws as it always has; any other
// goes through the kernel's `TextStyleRules.layout`, and `laidOut` hands the app its words, each at its pen x and
// baseline (justify gaps, alignment lead and tracking included), plus the extent they fill, so measuring and drawing
// read the one layout. `runText` runs a shared text style row's intent through Design's catalog. Linux-safe.
import SuiteKernel

/// One word of a laid-out text layer: its text, its pen x and its baseline y, in points from the box's top left.
public struct DesignTextWord: Sendable, Equatable {
    public let text: String
    public let x: Double
    public let baseline: Double
}

/// A text layer laid out by the kernel: its words and the width and height its lines fill.
public struct DesignTextSetting: Sendable, Equatable {
    public let words: [DesignTextWord]
    public let width: Double
    public let height: Double
}

extension DesignTextStyle {
    /// True when the style draws through the kernel's layout: italic, line height or tracking off its default, or justified.
    public var drawsThroughLayout: Bool {
        italic || lineHeight != Self.defaultLineHeight || tracking != 0 || alignment == .justified
    }

    /// Letter spacing in points: tracking is thousandths of an em.
    public var trackingPoints: Double { tracking / 1000 * size }

    /// `text` set in this style, wrapped and justified at `wrap` (ignored unless finite and > 0), measured by
    /// `advances` (each grapheme's advance without tracking, the font's ascent and descent); nil when the layout refuses.
    public func laidOut(_ text: String, wrap: Double?,
                        advances: ([String]) -> (advances: [Double], ascent: Double, descent: Double)) -> DesignTextSetting? {
        let box = wrap.flatMap { $0.isFinite && $0 > 0 ? $0 : nil }
        guard let layout = try? TextStyleRules.layout(text, style: kernel(.black, boxWidth: box), advances: advances) else { return nil }
        let graphemes = Array(text)
        var words = [DesignTextWord]()
        for line in layout.lines {
            var word = "", x = 0.0
            for (offset, index) in line.graphemes.enumerated() where index < graphemes.count && offset < line.x.count {
                let grapheme = graphemes[index]
                if grapheme.isWhitespace {
                    if !word.isEmpty { words.append(DesignTextWord(text: word, x: x, baseline: line.baseline)) }
                    word = ""
                } else {
                    if word.isEmpty { x = line.x[offset] }
                    word.append(grapheme)
                }
            }
            if !word.isEmpty { words.append(DesignTextWord(text: word, x: x, baseline: line.baseline)) }
        }
        return DesignTextSetting(words: words, width: layout.bounds.maxX, height: layout.bounds.maxY)
    }
}

extension DesignWorkspace {
    /// Runs a shared text style row's intent (font, size, alignment, line height, tracking) as its text command.
    public mutating func runText(_ intent: TextIntent) {
        let (id, params) = intent.command
        _ = try? Self.catalog.run(id, params: params, on: &self)
    }
}
