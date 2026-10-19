// DesignTextFont.swift: the one mapping from a text layer's DesignTextStyle to the font
// and alignment it draws in (style-rows ST-5t), and the size text takes in it
// (`measure`, canvas-basics CB-6). The canvas artwork (DesignTextArtwork), the inline
// editor (DesignTextOverlay) and the window's fitted commit all read it, so the text
// being typed, the box it commits into and the text drawn can't drift apart. Family is a name from the system's font list;
// the Model's default family ("System") is the system font. Weight is CSS's 100...900,
// rounded to the nearest hundred. A family the Mac doesn't have falls back to the
// system font at the same size and weight. These are document fonts, the user's
// content, not chrome: the shell's type stays SuiteFont.
import AppKit
import DesignModel
import SwiftUI

@MainActor
enum DesignTextFont {
    /// The platform font for `style` at `scale` × its size (scale 1 for page points).
    static func nsFont(_ style: DesignTextStyle, scale: Double = 1) -> NSFont {
        let size = pointSize(style, scale: scale)
        let rank = weightRank(style.weight)
        if style.family != DesignTextStyle.default.family,
           let font = NSFontManager.shared.font(
               withFamily: style.family, traits: [], weight: managerWeights[rank], size: size) {
            return font
        }
        return NSFont.systemFont(ofSize: size, weight: systemWeights[rank])
    }

    /// The SwiftUI font for `style` at `scale` × its size.
    static func font(_ style: DesignTextStyle, scale: Double = 1) -> Font {
        Font(nsFont(style, scale: scale) as CTFont)
    }

    /// The point size `style` draws at, `scale` × its size; a scale that isn't a positive finite number counts as 1.
    static func pointSize(_ style: DesignTextStyle, scale: Double = 1) -> Double {
        style.size * (scale.isFinite && scale > 0 ? scale : 1)
    }

    /// The size `text` takes in `style` (page points), each side rounded up to a whole point: one
    /// line per paragraph with no `wrapWidth`, wrapped at `wrapWidth` with one. The window commits
    /// an edit with it (canvas-basics CB-6) and the inline editor sizes its field by it.
    static func measure(_ text: String, _ style: DesignTextStyle, wrapWidth: Double?) -> DesignTextExtent {
        let wrap = wrapWidth.flatMap { $0.isFinite && $0 > 0 ? $0 : nil } ?? .greatestFiniteMagnitude
        let string = NSAttributedString(string: text, attributes: [.font: nsFont(style)])
        let bounds = string.boundingRect(
            with: CGSize(width: wrap, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin], context: nil)
        return DesignTextExtent(width: ceil(bounds.width), height: ceil(bounds.height))
    }

    /// The size `draft` takes in `node`'s box: one line per paragraph for an auto-width box,
    /// wrapped at the frame's width for a fixed-width one.
    static func measure(_ draft: String, in node: DesignNode) -> DesignTextExtent {
        measure(draft, node.textStyle, wrapWidth: node.textStyle.fixedWidth == true ? node.frame.width : nil)
    }

    /// How the lines of `style` align inside their box.
    static func textAlignment(_ style: DesignTextStyle) -> TextAlignment {
        switch style.alignment {
        case .leading: .leading
        case .center: .center
        case .trailing: .trailing
        }
    }

    /// Where a box puts text of `style`: always at its top, across as aligned.
    static func frameAlignment(_ style: DesignTextStyle) -> Alignment {
        switch style.alignment {
        case .leading: .topLeading
        case .center: .top
        case .trailing: .topTrailing
        }
    }

    /// How far across its box the text sits: 0 leading, 0.5 centered, 1 trailing.
    static func across(_ style: DesignTextStyle) -> Double {
        switch style.alignment {
        case .leading: 0
        case .center: 0.5
        case .trailing: 1
        }
    }

    /// 100...900 as an index 0...8 into the weight tables, nearest hundred, clamped.
    private static func weightRank(_ weight: Int) -> Int {
        min(max(Int((Double(weight) / 100).rounded()) - 1, 0), 8)
    }

    /// The system font's weights for 100...900: Thin to Black.
    private static let systemWeights: [NSFont.Weight] = [
        .ultraLight, .thin, .light, .regular, .medium, .semibold, .bold, .heavy, .black,
    ]

    /// NSFontManager's 0...15 weight hints for 100...900 (5 is regular, 9 bold).
    private static let managerWeights = [2, 3, 4, 5, 6, 8, 9, 10, 11]
}
