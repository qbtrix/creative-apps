// DesignTextFont.swift: the one mapping from a text layer's DesignTextStyle to the font
// and alignment it draws in (style-rows ST-5t). The canvas artwork (DesignTextArtwork)
// and the inline editor (DesignTextOverlay) both read it, so the text being typed and
// the text committed can't drift apart. Family is a name from the system's font list;
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
