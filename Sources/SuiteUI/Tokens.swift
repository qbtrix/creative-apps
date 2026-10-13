// Tokens.swift: the suite's spacing, corner radius, size, type and color
// tokens. Every app view takes its numbers, fonts and colors from here so the
// five apps stay consistent; the design lint in scripts/ci fails on a raw
// color, font or size anywhere else in Sources/SuiteUI or an app. Colors are
// system semantic colors (they adapt to Light, Dark and Increase Contrast);
// never hard-code a hex value for a system role. The one brand value is the
// accent blue. The inspector tokens are the "Pro density" rules in
// docs/design.md: small controls, the 11 pt scale, 22 pt rows. The editor
// shell tokens (top bar, rail, rulers, right panel, checkerboard) are the
// "Editor shell" rules in docs/design.md, sized after the Ripple editor. The
// Studio tokens (caps headers, 28 pt filled rows, chips, the curve editor)
// are the "Studio rows and chips" rules in docs/design.md.
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
    /// A field well inside a dense inspector row.
    public static let field: CGFloat = 4
    public static let small: CGFloat = 6
    public static let medium: CGFloat = 10
    public static let large: CGFloat = 16
    /// A Studio row or chip (StudioScrubRow, ChoiceChips).
    public static let row: CGFloat = 8
}

/// Fixed sizes in points: the window shell's minimums and column widths, and
/// the tool palette's buttons.
public enum SuiteSize {
    /// One tool palette button; the HIG asks for hit targets of at least 28.
    public static let toolButton: CGFloat = 32
    /// The numeric field beside an inspector slider or stepper.
    public static let inspectorField: CGFloat = 56
    /// One inspector row, and the viewer status line.
    public static let inspectorRow: CGFloat = 22
    /// The shared label column of InspectorRow; labels sit right-aligned in it.
    public static let inspectorLabelColumn: CGFloat = 88
    /// Control size inside inspectors and viewer chrome.
    public static let compactControl: ControlSize = .small
    /// Room CanvasSurface leaves around the artboard on every side.
    public static let canvasInset: CGFloat = 64
    public static let sidebarWidth: (min: CGFloat, ideal: CGFloat, max: CGFloat) = (180, 220, 320)
    public static let inspectorWidth: (min: CGFloat, ideal: CGFloat, max: CGFloat) = (220, 260, 360)
    public static let contentMinimum = CGSize(width: 480, height: 360)
    public static let windowMinimum = CGSize(width: 900, height: 560)
    /// The timeline's fixed track-name column, ruler, one lane, a keyframe
    /// diamond, the least room between two ruler labels and between two ruler
    /// ticks, the room one caption digit of a ruler label takes, and how much
    /// ruler is drawn before the scroll view says which stretch is visible.
    public static let timelineLabelColumn: CGFloat = 160
    public static let timelineRuler: CGFloat = 24
    public static let timelineLane: CGFloat = 28
    public static let timelineKeyframe: CGFloat = 10
    public static let timelineLabelSpacing: CGFloat = 48
    public static let timelineTickSpacing: CGFloat = 6
    public static let timelineLabelDigit: CGFloat = 7
    public static let timelineRulerSpan: CGFloat = 4096
    /// The editor shell (EditorShell): the top bar's height, the room the
    /// window's close, minimize and zoom buttons take at its leading edge, a
    /// divider between top bar groups, and the right panel's width.
    public static let editorTopBar: CGFloat = 40
    public static let windowControlsInset: CGFloat = 76
    public static let editorBarDivider: CGFloat = 20
    public static let editorPanelWidth: CGFloat = 280
    /// The canvas rulers' thickness, a minor tick's length, and the least room
    /// between two labelled ticks.
    public static let ruler: CGFloat = 20
    public static let rulerMinorTick: CGFloat = 4
    public static let rulerLabelSpacing: CGFloat = 64
    /// One square of the checkerboard behind transparent pixels.
    public static let checkerSquare: CGFloat = 8
    /// The hex text field beside a color well.
    public static let hexField: CGFloat = 76
    /// Studio controls: the letter spacing of a caps header, a filled scrub
    /// row, a preset chip, and its tick dots and value marker.
    public static let capsTracking: CGFloat = 0.7
    public static let studioRow: CGFloat = 28
    public static let chip: CGFloat = 24
    public static let studioTick: CGFloat = 2
    /// The curve editor (CurveEditor): its height, a handle, the handle's hit
    /// target and the preview dot.
    public static let curveEditor: CGFloat = 180
    public static let curveHandle: CGFloat = 10
    public static let curveHandleHit: CGFloat = 28
    public static let curvePreviewDot: CGFloat = 6
}

/// Text styles. macOS has no Dynamic Type; these are the system text styles,
/// so they track the system's sizes (13 pt body, 12 callout, 11 subheadline,
/// 10 caption: the same scale as the Ripple tokens).
public enum SuiteFont {
    public static let title = Font.title2.weight(.semibold)
    public static let headline = Font.headline
    public static let body = Font.body
    public static let caption = Font.caption
    public static let monospacedDigits = Font.body.monospacedDigit()
    /// Inspector and viewer chrome: 11 pt labels, values and section titles.
    public static let inspectorLabel = Font.subheadline
    public static let inspectorValue = Font.subheadline.monospacedDigit()
    public static let inspectorSection = Font.subheadline.weight(.semibold)
    /// InspectorHeader: 12 pt semibold name over 10 pt metadata lines.
    public static let inspectorTitle = Font.callout.weight(.semibold)
    public static let inspectorMeta = Font.caption.monospacedDigit()
    /// A Studio group header (KEYFRAMES, EASING): 10 pt semibold, set in caps
    /// with SuiteSize.capsTracking.
    public static let sectionCaps = Font.caption.weight(.semibold)
    /// The editor shell: top bar items and the document title, and ruler labels.
    public static let editorBar = Font.callout
    public static let editorTitle = Font.callout.weight(.semibold)
    public static let rulerLabel = Font.caption2.monospacedDigit()
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
    /// The grey ramp for flush panels: the window background with 0, 6, 10
    /// and 14 percent of the label color mixed in (the Ripple surface ladder),
    /// so each step adapts to Light, Dark and Increase Contrast.
    /// A flat panel: inspector bands, the viewer status line.
    public static var panel: Color { windowBackground }
    /// A raised band on a panel: InspectorHeader.
    public static var panelRaised: Color { windowBackground.mix(with: .primary, by: 0.06) }
    /// A field well at rest (ScrubField).
    public static var field: Color { windowBackground.mix(with: .primary, by: 0.10) }
    /// A field well while it is dragged or edited.
    public static var fieldActive: Color { windowBackground.mix(with: .primary, by: 0.14) }
    /// The suite's one accent, brand blue #1877F2: selection, the playhead,
    /// the active tool, control fills. SuiteWindow applies it as the tint.
    public static let accent = Color(red: 0x18 / 255, green: 0x77 / 255, blue: 0xF2 / 255)
    /// Accent for text: a darker shade in Light (#1260C9) and a lighter tint
    /// in Dark (#5A9DF6), so small text clears 4.5:1 on the panel greys.
    public static var accentText: Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(srgbRed: 0x5A / 255, green: 0x9D / 255, blue: 0xF6 / 255, alpha: 1)
                : NSColor(srgbRed: 0x12 / 255, green: 0x60 / 255, blue: 0xC9 / 255, alpha: 1)
        })
    }
    /// A new document's artboard. Document content, not a system role.
    public static let artboard = Color.white
    /// The two squares of the checkerboard behind transparent pixels: the
    /// canvas surround with a little more and a little less of the label color.
    public static var checkerLight: Color { canvasSurround.mix(with: .primary, by: 0.14) }
    public static var checkerDark: Color { canvasSurround.mix(with: .primary, by: 0.05) }
    /// Ruler ticks: the label color at 40%.
    public static var rulerTick: Color { Color.primary.opacity(0.4) }
    /// The selected tool's well in a docked tool rail.
    public static var selectedWell: Color { accent.opacity(0.18) }
    /// "This is a keyframe": the system orange, used for nothing else.
    public static var keyframed: Color { .orange }
    /// A Studio row's fill up to its value: the ramp's next step past
    /// `.fieldActive` (18%), so it reads on the raised track in Dark too.
    public static var studioFill: Color { windowBackground.mix(with: .primary, by: 0.18) }
    /// A Studio row's fill while it is dragged: the accent at 26%.
    public static var studioFillActive: Color { accent.opacity(0.26) }
    /// Marks drawn over document content (a selection's marching ants, a
    /// crop frame): black and white so they read on any pixels, and the dim
    /// outside a pending crop.
    public static let overlayInk = Color.black
    public static let overlayPaper = Color.white
    public static let cropShade = Color.black.opacity(0.55)
}
