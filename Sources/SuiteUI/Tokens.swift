// Tokens.swift: the suite's spacing, corner radius, size, type and color
// tokens. Every app view takes its numbers, fonts and colors from here so the
// five apps stay consistent; the design lint in scripts/ci fails on a raw
// color, font or size anywhere else in Sources/SuiteUI or an app. Colors are
// system semantic colors (they adapt to Light, Dark and Increase Contrast);
// never hard-code a hex value for a system role.
import AppKit
import SwiftUI

/// Spacing on a 4-point grid, smallest to largest.
public enum SuiteSpacing {
    public static let xxs: CGFloat = 2
    public static let xs: CGFloat = 4
    public static let s: CGFloat = 8
    public static let m: CGFloat = 12
    public static let l: CGFloat = 16
    public static let xl: CGFloat = 24
    public static let xxl: CGFloat = 32

    /// The whole scale in order, for tests and the gallery.
    public static let scale: [CGFloat] = [xxs, xs, s, m, l, xl, xxl]
}

/// Corner radii. Nested shapes step down one size so corners stay concentric.
public enum SuiteRadius {
    public static let small: CGFloat = 6
    public static let medium: CGFloat = 10
    public static let large: CGFloat = 16
}

/// Fixed sizes in points: the window shell's minimums and column widths, and
/// the tool palette's buttons.
public enum SuiteSize {
    /// One tool palette button; the HIG asks for hit targets of at least 28.
    public static let toolButton: CGFloat = 32
    /// The numeric field beside an inspector slider or stepper.
    public static let inspectorField: CGFloat = 56
    public static let sidebarWidth: (min: CGFloat, ideal: CGFloat, max: CGFloat) = (180, 220, 320)
    public static let inspectorWidth: (min: CGFloat, ideal: CGFloat, max: CGFloat) = (220, 260, 360)
    public static let contentMinimum = CGSize(width: 480, height: 360)
    public static let windowMinimum = CGSize(width: 900, height: 560)
    /// The timeline's fixed track-name column, ruler, one lane, a keyframe
    /// diamond, and the least room between two ruler labels.
    public static let timelineLabelColumn: CGFloat = 160
    public static let timelineRuler: CGFloat = 24
    public static let timelineLane: CGFloat = 28
    public static let timelineKeyframe: CGFloat = 10
    public static let timelineLabelSpacing: CGFloat = 48
}

/// Text styles. macOS has no Dynamic Type; these are the system text styles,
/// so they track the system's sizes (13 pt body).
public enum SuiteFont {
    public static let title = Font.title2.weight(.semibold)
    public static let headline = Font.headline
    public static let body = Font.body
    public static let caption = Font.caption
    public static let monospacedDigits = Font.body.monospacedDigit()
}

/// Semantic colors by role.
public enum SuiteColor {
    /// The window's own background, behind empty states and lists.
    public static var windowBackground: Color { Color(nsColor: .windowBackgroundColor) }
    /// The neutral surround around a canvas, so artwork color reads true.
    public static var canvasSurround: Color { Color(nsColor: .underPageBackgroundColor) }
    /// Flat fill for cards in the content layer (never glass).
    public static var surface: Color { Color(nsColor: .controlBackgroundColor) }
    public static var separator: Color { Color(nsColor: .separatorColor) }
    public static var secondaryText: Color { .secondary }
    /// The system accent: marks selection and the playhead.
    public static var accent: Color { .accentColor }
    /// A new document's artboard. Document content, not a system role.
    public static let artboard = Color.white
}
