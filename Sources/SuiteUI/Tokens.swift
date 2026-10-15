// Tokens.swift: the suite's spacing, inset, corner radius, size, type, motion
// and color tokens, the "Visual language" section of docs/design.md. Every
// app view takes its numbers, fonts and colors from here so the five apps
// stay consistent; the design lint in scripts/ci fails on a raw color, font or
// size anywhere else in Sources/SuiteUI or an app.
//
// Colors: the graphite ladder (panels, rows, fills, lines), the text colors
// and the state colors are literal sRGB hex per appearance in SuitePalette
// (Dark, Light, Dark + Increase Contrast, Light + Increase Contrast), resolved
// at draw time through NSColor(name:dynamicProvider:), with the contrast
// column picked by a high-contrast appearance or SuiteHex.increasedContrast
// (AppKit hands out a high-contrast appearance only when the system setting
// is on, so a renderer drawing a chosen contrast binds it). The steps are written
// out, never mixed at run time, so TokensTests.contrast can check every pair
// the design table promises. Editors (EditorShell) force Dark, so they
// resolve the Dark columns in both system appearances. A few roles stay
// system colors (window background, the content-layer surface, separators),
// and the older names (`panelRaised`, `field`, `studioFill`,
// `selectedWell`, `keyframed`) now read the ladder until their callers move.
import AppKit
import SwiftUI

/// Spacing on a 4-point grid, smallest to largest, plus the named gaps of the
/// inspector and the status pills.
public enum SuiteSpacing {
    public static let xxs: CGFloat = 2
    public static let xs: CGFloat = 4
    public static let s: CGFloat = 8
    public static let m: CGFloat = 12
    public static let l: CGFloat = 16
    public static let xl: CGFloat = 24
    public static let xxl: CGFloat = 32
    /// The gap between two inspector rows.
    public static let row: CGFloat = 6
    /// The gap between two status pills.
    public static let pillGap: CGFloat = 4
    /// How far a bar slider's value marker stays off the row's top and bottom.
    public static let markerInset: CGFloat = 6
    /// The gap between two nodes of a node graph.
    public static let nodeGap: CGFloat = 32

    /// The whole scale in order, for tests and the gallery.
    public static let scale: [CGFloat] = [xxs, xs, s, m, l, xl, xxl]
}

/// Padding inside the filled controls: vertical by horizontal.
public enum SuiteInset {
    public static let barButton = EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8)
    public static let pill = EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8)
    public static let card = EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
}

/// Corner radii. Nested shapes step down one size so corners stay concentric.
public enum SuiteRadius {
    /// A field inside a row, a swatch inset.
    public static let field: CGFloat = 4
    /// Top-bar buttons.
    public static let small: CGFloat = 6
    /// Presets and chips.
    public static let control: CGFloat = 8
    /// Inspector rows, the info card, the action button.
    public static let medium: CGFloat = 10
    /// Timeline lane beds and clip blocks.
    public static let lane: CGFloat = 12
    /// The stage frame and sheets.
    public static let large: CGFloat = 16
    /// A Studio row or chip (StudioScrubRow, ChoiceChips).
    public static let row: CGFloat = 8
}

/// Fixed sizes in points: the window shell's minimums and column widths, and
/// the controls' visual and hit sizes (hits at least 28 where the layout
/// allows, never under 20).
public enum SuiteSize {
    /// One tool palette button; the HIG asks for hit targets of at least 28.
    public static let toolButton: CGFloat = 32
    /// Every inspector row, bar slider, dropdown and toggle row.
    public static let inspectorBar: CGFloat = 34
    /// The keyframe button (a circle) and the key-here diamond slot beside it.
    public static let keyframeButton: CGFloat = 28
    /// Chips and timeline toggle chips.
    public static let chip: CGFloat = 28
    /// Preset buttons: 24 drawn, 28 to hit.
    public static let preset: CGFloat = 24
    public static let presetHit: CGFloat = 28
    /// The full-width outlined action.
    public static let actionButton: CGFloat = 32
    /// Status pills: 20 drawn, 24 to hit.
    public static let pill: CGFloat = 20
    public static let pillHit: CGFloat = 24
    /// The transport capsule's buttons and its larger play button.
    public static let transportButton: CGFloat = 32
    public static let playButton: CGFloat = 36
    /// The swatch inside a color row.
    public static let swatch = CGSize(width: 24, height: 16)
    /// Stage selection handles and pen anchors: drawn, then hit.
    public static let selectionHandle: CGFloat = 8
    public static let selectionHandleHit: CGFloat = 12
    public static let anchor: CGFloat = 6
    public static let anchorHit: CGFloat = 12
    /// The unsaved and recording dots.
    public static let statusDot: CGFloat = 6
    /// The keyboard focus ring: its width and its gap outside the shape.
    public static let focusRing: CGFloat = 2
    public static let focusRingGap: CGFloat = 1
    /// The numeric field beside an inspector slider or stepper.
    public static let inspectorField: CGFloat = 56
    /// Control size inside inspectors and viewer chrome.
    public static let compactControl: ControlSize = .small
    /// Room CanvasSurface leaves around the artboard on every side.
    public static let canvasInset: CGFloat = 64
    /// The SuiteWindow columns. The window's sizes come from them: its minimum
    /// width is the side columns' ideals around the content minimum, and its
    /// launch width the side columns' ideals around the content ideal, so the
    /// sidebar and inspector are never clipped at launch (#215, #579).
    public static let sidebarWidth: (min: CGFloat, ideal: CGFloat, max: CGFloat) = (160, 200, 320)
    public static let inspectorWidth: (min: CGFloat, ideal: CGFloat, max: CGFloat) = (200, 240, 360)
    public static let contentMinimum = CGSize(width: 440, height: 360)
    public static let contentIdealWidth: CGFloat = 560
    /// What the split view's detail column adds around SuiteWindow's content
    /// frame. The inspector sits in that column, and the column measured the
    /// content frame's minimum plus the inspector's minimum plus an 8 pt
    /// divider: 648 pt for a 440 pt minimum, in every window from 900 to
    /// 1000 pt wide (#933; 708 for #579's 480 and 220). SuiteWindow sizes its
    /// content frame this much under the content sizes, so the column comes
    /// out at contentMinimum and the three columns fit windowMinimum.
    public static let detailInspectorAllowance: CGFloat = inspectorWidth.min + 8
    public static let windowMinimum = CGSize(
        width: sidebarWidth.ideal + contentMinimum.width + inspectorWidth.ideal, height: 560)
    public static let windowLaunch = CGSize(
        width: sidebarWidth.ideal + contentIdealWidth + inspectorWidth.ideal, height: 640)
    /// The timeline's fixed track-name column, ruler, one lane, a keyframe
    /// diamond and its hit, the least room between two ruler labels and
    /// between two ruler ticks, the room one caption digit of a ruler label
    /// takes, and how much ruler is drawn before the scroll view says which
    /// stretch is visible.
    public static let timelineLabelColumn: CGFloat = 160
    public static let timelineRuler: CGFloat = 24
    public static let timelineLane: CGFloat = 32
    public static let timelineKeyframe: CGFloat = 10
    public static let timelineKeyframeHit: CGFloat = 16
    public static let timelineLabelSpacing: CGFloat = 48
    public static let timelineTickSpacing: CGFloat = 6
    public static let timelineLabelDigit: CGFloat = 7
    public static let timelineRulerSpan: CGFloat = 4096
    /// The editor shell (EditorShell): the top bar's height, the room the
    /// window's close, minimize and zoom buttons take at its leading edge, a
    /// divider between top bar groups, and the right panel's width.
    public static let editorTopBar: CGFloat = 48
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
    /// row, and the 2 pt tick dots and value marker of a bar slider.
    public static let capsTracking: CGFloat = 0.7
    public static let studioRow: CGFloat = 28
    public static let studioTick: CGFloat = 2
    /// The curve editor (CurveEditor): its height, a handle, the handle's hit
    /// target and the preview dot.
    public static let curveEditor: CGFloat = 180
    public static let curveHandle: CGFloat = 10
    public static let curveHandleHit: CGFloat = 28
    public static let curvePreviewDot: CGFloat = 6
    /// The least hit of an icon-only button (an inspector section's Reset):
    /// docs/design.md's 20 pt floor.
    public static let iconButtonHit: CGFloat = 20
    /// The editor's timeline slot: its least open height, its collapsed height
    /// (the chip row, 28, with 4 above and below), and the grab zone above its
    /// 1 pt hairline divider.
    public static let timelineSlotMinimum: CGFloat = 120
    public static let timelineSlotToolbar: CGFloat = 36
    public static let timelineGrab: CGFloat = 8
    /// The quarter-ring outside each selection corner that rotates.
    public static let rotateZone: CGFloat = 16
    /// The point mark: its ring and cross, the ink's line width and the paper
    /// halo's width under it.
    public static let pointMarkRing: CGFloat = 12
    public static let pointMarkCross: CGFloat = 6
    public static let pointMarkInk: CGFloat = 1.5
    public static let pointMarkPaper: CGFloat = 3
    /// The node graph: one node, an arrow's head and its line width.
    public static let nodeSize = CGSize(width: 120, height: 56)
    public static let arrowHead: CGFloat = 6
    public static let arrowStroke: CGFloat = 1.5
    /// The accent line that shows where a dragged row will land.
    public static let insertionLine: CGFloat = 2
}

/// Text styles. macOS has no Dynamic Type; these are the system text styles,
/// so they track the system's sizes (13 pt body, 12 callout, 11 subheadline,
/// 10 caption and caption2 on macOS). Nothing goes below 10 pt.
public enum SuiteFont {
    public static let title = Font.title2.weight(.semibold)
    public static let headline = Font.headline
    public static let body = Font.body
    public static let caption = Font.caption
    public static let monospacedDigits = Font.body.monospacedDigit()
    /// Inspector rows: 11 pt labels, 11 pt semibold tabular values (units in
    /// the same string), 10 pt semibold section headers set in caps.
    public static let inspectorLabel = Font.subheadline
    public static let inspectorValue = Font.subheadline.weight(.semibold).monospacedDigit()
    public static let inspectorSection = Font.caption2.weight(.semibold)
    /// InspectorHeader: the 12 pt semibold name, and its older metadata lines.
    public static let inspectorTitle = Font.callout.weight(.semibold)
    public static let inspectorMeta = Font.caption.monospacedDigit()
    /// Status pills, chips and preset labels.
    public static let pill = Font.caption2.weight(.semibold).monospacedDigit()
    /// Timecode and frame readouts.
    public static let timecode = Font.caption.monospaced()
    /// A Studio group header (KEYFRAMES, EASING): 10 pt semibold, set in caps
    /// with SuiteSize.capsTracking.
    public static let sectionCaps = Font.caption.weight(.semibold)
    /// The editor shell: top bar items and the document title, and ruler labels.
    public static let editorBar = Font.callout
    public static let editorTitle = Font.callout.weight(.semibold)
    public static let rulerLabel = Font.caption2.monospacedDigit()
}

/// Hover and state changes fade background, color and border over 0.14 s;
/// under Reduce Motion they change at once. Nothing else in the chrome moves.
public enum SuiteMotion {
    public static let state = Animation.easeInOut(duration: 0.14)

    /// `state`, or nil (no animation) under Reduce Motion.
    public static func state(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : state
    }
}

/// One color as literal sRGB hex (0xRRGGBB) in each appearance, in the order
/// of docs/design.md's tables: Dark, Light, Dark + Increase Contrast, Light +
/// Increase Contrast.
public struct SuiteHex: Hashable, Sendable {
    public let dark: UInt32
    public let light: UInt32
    public let darkContrast: UInt32
    public let lightContrast: UInt32

    public init(_ dark: UInt32, _ light: UInt32, _ darkContrast: UInt32, _ lightContrast: UInt32) {
        self.dark = dark
        self.light = light
        self.darkContrast = darkContrast
        self.lightContrast = lightContrast
    }

    /// The four values in table order.
    public var values: [UInt32] { [dark, light, darkContrast, lightContrast] }

    /// Increase Contrast for the tokens resolved inside
    /// `SuiteHex.$increasedContrast.withValue(_:operation:)`; nil (the
    /// default) follows the appearance. AppKit only hands out a high-contrast
    /// appearance when the system setting is on: `NSAppearance(named:)` with
    /// a high-contrast name returns plain Aqua or Dark Aqua (CI run
    /// 38667087530), so a renderer that draws a chosen contrast, like the
    /// snapshot host, says so here.
    @TaskLocal public static var increasedContrast: Bool?

    /// The value for `appearance`: the closest of the four, so a vibrant dark
    /// appearance reads Dark, a high-contrast one (or any appearance while
    /// `increasedContrast` is true) reads its Increase Contrast column, and
    /// anything unknown reads Light.
    public func value(for appearance: NSAppearance) -> UInt32 {
        switch Self.column(appearance) {
        case .darkAqua: dark
        case .accessibilityHighContrastDarkAqua: darkContrast
        case .accessibilityHighContrastAqua: lightContrast
        default: light
        }
    }

    /// The table column for `appearance`: its light or dark side from the
    /// appearance, its contrast from `increasedContrast` when that is bound,
    /// otherwise from the appearance.
    private static func column(_ appearance: NSAppearance) -> NSAppearance.Name {
        let found = match(appearance)
        let isDark = found == .darkAqua || found == .accessibilityHighContrastDarkAqua
        let contrast = increasedContrast
            ?? (found == .accessibilityHighContrastAqua || found == .accessibilityHighContrastDarkAqua)
        switch (isDark, contrast) {
        case (true, true): return .accessibilityHighContrastDarkAqua
        case (true, false): return .darkAqua
        case (false, true): return .accessibilityHighContrastAqua
        case (false, false): return .aqua
        }
    }

    /// The appearance as one of the four table columns. A system name maps
    /// directly (vibrant to its non-vibrant column); any other appearance
    /// tries the high-contrast names first, then splits light from dark.
    private static func match(_ appearance: NSAppearance) -> NSAppearance.Name? {
        if let column = columns[appearance.name] { return column }
        let contrast: [NSAppearance.Name] = [.accessibilityHighContrastAqua, .accessibilityHighContrastDarkAqua]
        if let found = appearance.bestMatch(from: contrast + [.aqua, .darkAqua]), contrast.contains(found) {
            return found
        }
        return appearance.bestMatch(from: [.aqua, .darkAqua])
    }

    private static let columns: [NSAppearance.Name: NSAppearance.Name] = [
        .aqua: .aqua, .vibrantLight: .aqua,
        .darkAqua: .darkAqua, .vibrantDark: .darkAqua,
        .accessibilityHighContrastAqua: .accessibilityHighContrastAqua,
        .accessibilityHighContrastVibrantLight: .accessibilityHighContrastAqua,
        .accessibilityHighContrastDarkAqua: .accessibilityHighContrastDarkAqua,
        .accessibilityHighContrastVibrantDark: .accessibilityHighContrastDarkAqua,
    ]

    /// This color at `alpha`, or at `darkAlpha` in the dark appearances.
    func color(alpha: CGFloat = 1, darkAlpha: CGFloat? = nil) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let hex = value(for: appearance)
            let column = Self.column(appearance)
            let isDark = column == .darkAqua || column == .accessibilityHighContrastDarkAqua
            return NSColor(
                srgbRed: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255, alpha: isDark ? darkAlpha ?? alpha : alpha)
        })
    }
}

/// The literal hex behind SuiteColor, exactly docs/design.md's Visual language
/// tables. TokensTests checks the contrast between them.
public enum SuitePalette {
    // The graphite ladder.
    public static let canvasSurround = SuiteHex(0x18191B, 0xE4E5E8, 0x121314, 0xDCDDE0)
    public static let ground = SuiteHex(0x1E1F22, 0xEDEEF0, 0x18191B, 0xF2F2F3)
    public static let panel = SuiteHex(0x26272B, 0xF6F6F7, 0x202124, 0xFFFFFF)
    public static let card = SuiteHex(0x2F3033, 0xECECED, 0x323336, 0xEBEBEB)
    public static let row = SuiteHex(0x313236, 0xEAEAEB, 0x36373A, 0xE6E6E6)
    public static let rowHover = SuiteHex(0x3C3D40, 0xDDDDDE, 0x444547, 0xD6D6D6)
    public static let valueFill = SuiteHex(0x3F4044, 0xDADADB, 0x4E4F52, 0xCACACA)
    public static let dragFill = SuiteHex(0x2D3E58, 0xCDDAEC, 0x3A485C, 0xC7D3E3)
    public static let fieldActive = SuiteHex(0x1B1B1E, 0xFFFFFF, 0x161719, 0xFFFFFF)
    public static let hairline = SuiteHex(0x333438, 0xE7E7E8, 0x3B3C3E, 0xE0E0E0)
    public static let outline = SuiteHex(0x404144, 0xD8D8D9, 0x636466, 0xB2B2B2)
    public static let tick = SuiteHex(0x56575A, 0xC0C0C1, 0x6A6A6C, 0xABABAB)
    public static let marker = SuiteHex(0x9D9EA0, 0x6F6F6F, 0xC7C8C8, 0x404040)
    /// The bar slider's marker while dragging: white in Dark, accentText in Light.
    public static let markerDragging = SuiteHex(0xFFFFFF, 0x0A4FA6, 0xFFFFFF, 0x08408A)
    public static let laneBed = SuiteHex(0x2D2D31, 0xEFEFF0, 0x2D2E31, 0xF0F0F0)
    public static let accent = SuiteHex(0x1877F2, 0x1877F2, 0x4A94F7, 0x0A5FD0)
    /// The one primary button and the playhead pill, under white text (5.05:1).
    public static let accentFill = SuiteHex(0x156BDB, 0x156BDB, 0x156BDB, 0x156BDB)
    // Text.
    public static let textPrimary = SuiteHex(0xEDEEF0, 0x1D1D1F, 0xFFFFFF, 0x000000)
    public static let textSecondary = SuiteHex(0xB4B8BF, 0x50545C, 0xD2D5DA, 0x3A3D43)
    public static let textTertiary = SuiteHex(0x80848C, 0x7C8088, 0x9A9EA6, 0x5E626A)
    public static let accentText = SuiteHex(0x8DBDFF, 0x0A4FA6, 0xA8CCFF, 0x08408A)
    // States.
    public static let stateKeyed = SuiteHex(0xF4C542, 0x664900, 0xFFD666, 0x4F3800)
    public static let stateSelected = SuiteHex(0x8DBDFF, 0x0A4FA6, 0xA8CCFF, 0x08408A)
    public static let stateRecording = SuiteHex(0xFF8A82, 0xA3110B, 0xFFA39C, 0x870E09)
    public static let stateSuggested = SuiteHex(0xC4A8FF, 0x5C31B3, 0xD2BCFF, 0x4A2694)
    public static let stateWarning = SuiteHex(0xFFA552, 0x7F3E00, 0xFFB673, 0x663100)
    public static let stateError = SuiteHex(0xFF8F8F, 0x9E1F1F, 0xFFA3A3, 0x821818)
    public static let stateSuccess = SuiteHex(0x3DD68C, 0x105C35, 0x5CE0A0, 0x0B4A2A)
    public static let onionBefore = SuiteHex(0xF7A0AD, 0x9A2A40, 0xFAB3BE, 0x7E2134)
    public static let onionAfter = SuiteHex(0x4CC9A0, 0x0F5E47, 0x6BD6B2, 0x0B4C39)

    /// A state's tint is its strong color at 16% over the panel in Dark and 12% in Light.
    public static let tintDark: CGFloat = 0.16
    public static let tintLight: CGFloat = 0.12
}

/// Colors by role.
public enum SuiteColor {
    /// The window's own background, behind empty states and lists.
    public static var windowBackground: Color { Color(nsColor: .windowBackgroundColor) }
    /// Flat fill for cards in the content layer (never glass).
    public static var surface: Color { Color(nsColor: .controlBackgroundColor) }
    public static var separator: Color { Color(nsColor: .separatorColor) }
    /// Secondary text in SuiteWindow apps' lists, cards and sheets: the
    /// palette's textSecondary, so it clears 4.5:1 on card, panel and surface
    /// in every appearance (#283; the system `.secondary` measured about 4:1
    /// on light cards).
    public static let secondaryText = textSecondary

    // The graphite ladder: around the canvas, bars, panels, the info card,
    // rows, their hover, a bar slider's fill at rest and while dragged, a
    // field being typed in, lines between bars, outlines, decoration.
    public static let canvasSurround = SuitePalette.canvasSurround.color()
    public static let ground = SuitePalette.ground.color()
    public static let panel = SuitePalette.panel.color()
    public static let card = SuitePalette.card.color()
    public static let row = SuitePalette.row.color()
    public static let rowHover = SuitePalette.rowHover.color()
    public static let valueFill = SuitePalette.valueFill.color()
    public static let dragFill = SuitePalette.dragFill.color()
    public static let fieldActive = SuitePalette.fieldActive.color()
    /// Between bars and panels only, never inside a panel.
    public static let hairline = SuitePalette.hairline.color()
    /// The 1 pt edge of outlined buttons and presets.
    public static let outline = SuitePalette.outline.color()
    public static let tick = SuitePalette.tick.color()
    public static let marker = SuitePalette.marker.color()
    public static let markerDragging = SuitePalette.markerDragging.color()
    public static let laneBed = SuitePalette.laneBed.color()

    /// The suite's one accent, brand blue #1877F2: selection, focus, the
    /// playhead, the active tool. SuiteWindow applies it as the tint.
    public static let accent = SuitePalette.accent.color()
    public static let accentFill = SuitePalette.accentFill.color()
    public static let textPrimary = SuitePalette.textPrimary.color()
    public static let textSecondary = SuitePalette.textSecondary.color()
    /// Placeholders and disabled text only; never information a person needs.
    public static let textTertiary = SuitePalette.textTertiary.color()
    public static let accentText = SuitePalette.accentText.color()

    // State colors: each pairs with a shape cue (docs/design.md, State colors).
    public static let stateKeyed = SuitePalette.stateKeyed.color()
    public static let stateSelected = SuitePalette.stateSelected.color()
    public static let stateRecording = SuitePalette.stateRecording.color()
    public static let stateSuggested = SuitePalette.stateSuggested.color()
    public static let stateWarning = SuitePalette.stateWarning.color()
    public static let stateError = SuitePalette.stateError.color()
    public static let stateSuccess = SuitePalette.stateSuccess.color()
    public static let onionBefore = SuitePalette.onionBefore.color()
    public static let onionAfter = SuitePalette.onionAfter.color()
    /// The tints behind a selected chip or preset, a key at the playhead and a
    /// warning pill.
    public static let selectedTint = tint(SuitePalette.stateSelected)
    public static let keyedTint = tint(SuitePalette.stateKeyed)
    public static let warningTint = tint(SuitePalette.stateWarning)
    /// A disabled control draws at this opacity, and its tooltip says why.
    public static let disabledOpacity: Double = 0.4

    // Older names, now on the ladder, until their callers move.
    /// A raised band on a panel: the info card.
    public static let panelRaised = card
    /// A field well at rest.
    public static let field = row
    /// The selected tool's well in a docked tool rail.
    public static let selectedWell = selectedTint
    /// "This is a keyframe".
    public static let keyframed = stateKeyed
    /// A Studio row's fill up to its value, and while it is dragged.
    public static let studioFill = valueFill
    public static let studioFillActive = dragFill

    /// A new document's artboard. Document content, not a system role.
    public static let artboard = Color.white
    /// The two squares of the checkerboard behind transparent pixels: the
    /// canvas surround with a little more and a little less of the label color.
    public static var checkerLight: Color { canvasSurround.mix(with: .primary, by: 0.14) }
    public static var checkerDark: Color { canvasSurround.mix(with: .primary, by: 0.05) }
    /// Ruler ticks: the label color at 40%.
    public static var rulerTick: Color { Color.primary.opacity(0.4) }
    /// Marks drawn over document content (a selection's marching ants, a
    /// crop frame): black and white so they read on any pixels, and the dim
    /// outside a pending crop.
    public static let overlayInk = Color.black
    public static let overlayPaper = Color.white
    public static let cropShade = Color.black.opacity(0.55)

    private static func tint(_ state: SuiteHex) -> Color {
        state.color(alpha: SuitePalette.tintLight, darkAlpha: SuitePalette.tintDark)
    }
}
