// ColorWell.swift: the one color row (InspectorColorRow): the system color
// well as a swatch capsule beside its hex code, which the user can also type.
// HexColor is the value both sides speak: 8-bit sRGB, read from "#RRGGBB",
// "RRGGBB" or "#RGB" in either case, written as "#RRGGBB". It is plain and
// tested on its own; its bridge to SwiftUI's Color goes through
// Color.Resolved in sRGB. Text that isn't a hex color keeps the old color.
// The text rules are HexColorText, the suite's HexColorEditing (UC2), over
// RGB8; it and HexColor parse, format and round through SuiteKernel's
// HexText, the suite's one hex codec, and HexColor's bridge to the kernel's
// FillColor is `init(_:)` / `fill`. InspectorColorWellRow is its HexColor wrapper.
// Both rows report `onEnd` once per gesture through an EditRun (HexEnds): a
// hex commit is a change and an end in one, even when it keeps the color; the
// color panel's picks stream through `onChange` and end once when the panel
// closes (SwiftUI's ColorPicker reports no end of interaction) or the row goes
// away. The row owns presentation state only: the hex text being typed and
// the gesture's run. A `sampleable` row (the default) shows an
// EyedropperButton after the hex code; its pick is one change and one end,
// after ending an open run of panel picks, and Escape changes nothing. A host
// that disables the row passes its reason as `sampleHelp`, so the button lists
// itself in `suite.controls` as disabled with that reason, not as enabled.
import AppKit
import SuiteKernel
import SwiftUI

/// The hex field's text rules (UC2): "#RRGGBB", "RRGGBB" or "#RGB" in either
/// case, with surrounding spaces and one leading "#" ignored; three digits
/// double up ("#F80" is "#FF8800"). An alpha form ("#RRGGBBAA") reads only
/// when opaque: the row has no alpha. Written as "#RRGGBB", upper case.
/// Both are HexText's, so the field reads like every other hex in the suite.
public struct HexColorText: HexColorEditing {
    public init() {}

    public func parse(_ text: String) -> RGB8? {
        guard let color = HexText.parse(text), HexText.byte(color.a) == 255 else { return nil }
        return HexColor(color).rgb
    }

    public func committed(_ text: String, old: RGB8) -> RGB8 { parse(text) ?? old }

    public func format(_ color: RGB8) -> String { HexText.format(HexColor(color).fill) }
}

/// One gesture, one end, for a color row, over the suite's EditRun: a hex
/// commit is a change and an end in one call; the color panel's picks open
/// one run that its close ends. HexColorTests drive it.
struct HexEnds: Equatable, Sendable {
    private(set) var run = EditRun()

    var isOpen: Bool { run.isOpen }
    var ends: Int { run.ends }

    /// The hex field closed with typed text: the color to send (nil when it
    /// keeps `old`), and whether this commit ended the run (true, once).
    mutating func committed(_ text: String, old: RGB8) -> (color: RGB8?, ended: Bool) {
        let next = HexColorText().committed(text, old: old)
        _ = run.change()
        return (next == old ? nil : next, run.end())
    }

    /// A color panel pick; true when it opened the run.
    mutating func picked() -> Bool { run.change() }

    /// The panel closed or the row went away: true once per run of picks.
    mutating func closed() -> Bool { run.end() }
}

public struct HexColor: Hashable, Sendable {
    public let red: UInt8
    public let green: UInt8
    public let blue: UInt8

    public init(_ red: UInt8, _ green: UInt8, _ blue: UInt8) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    public init(_ rgb: RGB8) { self.init(rgb.red, rgb.green, rgb.blue) }

    public static let black = HexColor(0, 0, 0)

    /// The color `text` names, or nil when it isn't a hex color (HexColorText).
    public init?(_ text: String) {
        guard let rgb = HexColorText().parse(text) else { return nil }
        self.init(rgb)
    }

    public var rgb: RGB8 { RGB8(red, green, blue) }

    /// "#RRGGBB", upper case.
    public var text: String { HexColorText().format(rgb) }

    /// The nearest 8-bit color to the kernel's `fill` (both sRGB), its alpha
    /// dropped; HexText's rounding, so out-of-range clamps and NaN reads 0.
    public init(_ fill: FillColor) {
        self.init(HexText.byte(fill.r), HexText.byte(fill.g), HexText.byte(fill.b))
    }

    /// This color as the kernel's FillColor, opaque.
    public var fill: FillColor { FillColor(r: Double(red) / 255, g: Double(green) / 255, b: Double(blue) / 255) }

    /// The nearest 8-bit sRGB color to `resolved` (Color.Resolved is sRGB);
    /// its opacity is dropped, components outside 0...1 are clamped.
    public init(_ resolved: Color.Resolved) {
        self.init(FillColor(r: Double(resolved.red), g: Double(resolved.green), b: Double(resolved.blue)))
    }

    public var resolved: Color.Resolved {
        Color.Resolved(red: Float(red) / 255, green: Float(green) / 255, blue: Float(blue) / 255)
    }

    public var color: Color { Color(resolved) }
}

/// The one color row: a filled InspectorRow with the label on the left, then
/// on the right a swatch capsule (the system color well, which opens the
/// system color panel) with a 1 pt outline and the color's hex code, which the
/// user can also type. Takes a Color, a HexColor through the second init, or a
/// HexColor with its opacity through the third (the panel shows its opacity
/// slider; a typed hex or an eyedropper pick keeps the opacity).
/// `onEnd` runs once per gesture: each hex commit, and each run of panel
/// picks once the panel closes, so a host makes each one undo step.
public struct InspectorColorRow: View {
    private let label: String
    private let color: Color
    private let supportsOpacity: Bool
    private let sampleable: Bool
    private let sampleHelp: String?
    /// What a pick tells the host; internal so ColorAlphaTests can pick.
    let onPick: @MainActor (Color.Resolved) -> Void
    /// The opacity a typed hex or an eyedropper pick keeps (the opacity init); nil resolves them opaque.
    private var keptOpacity: Float?
    private let onEnd: @MainActor () -> Void
    /// The hex field's accessibility identifier, when a host names it (InspectorColorWellRow.hexIdentifier).
    var hexID: String?
    @State private var draft: String?
    @State private var ends = HexEnds()
    @FocusState private var isTyping: Bool
    @Environment(\.self) private var environment

    public init(
        _ label: String, color: Color, supportsOpacity: Bool = true, sampleable: Bool = true,
        sampleHelp: String? = nil, onChange: @escaping @MainActor (Color) -> Void,
        onEnd: @escaping @MainActor () -> Void = {}
    ) {
        self.label = label
        self.color = color
        self.supportsOpacity = supportsOpacity
        self.sampleable = sampleable
        self.sampleHelp = sampleHelp
        self.onPick = { onChange(Color($0)) }
        self.onEnd = onEnd
    }

    /// An 8-bit sRGB color; `onChange` hears only a different one.
    public init(
        _ label: String, hex: HexColor, sampleable: Bool = true, sampleHelp: String? = nil,
        onChange: @escaping @MainActor (HexColor) -> Void, onEnd: @escaping @MainActor () -> Void = {}
    ) {
        self.label = label
        self.color = hex.color
        self.supportsOpacity = false
        self.sampleable = sampleable
        self.sampleHelp = sampleHelp
        self.onPick = { picked in
            let next = HexColor(picked)
            if next != hex { onChange(next) }
        }
        self.onEnd = onEnd
    }

    /// An 8-bit sRGB color with its opacity, 0...1: the panel shows its opacity slider and `onChange` hears the color
    /// and opacity whenever either differs. A typed hex or an eyedropper pick keeps `opacity`.
    public init(
        _ label: String, hex: HexColor, opacity: Double, sampleable: Bool = true, sampleHelp: String? = nil,
        onChange: @escaping @MainActor (HexColor, Double) -> Void, onEnd: @escaping @MainActor () -> Void = {}
    ) {
        let alpha = Float(opacity.isFinite ? min(max(opacity, 0), 1) : 1)
        var resolved = hex.resolved
        resolved.opacity = alpha
        self.label = label
        self.color = Color(resolved)
        self.supportsOpacity = true
        self.sampleable = sampleable
        self.keptOpacity = alpha
        self.sampleHelp = sampleHelp
        self.onPick = { picked in
            let next = HexColor(picked)
            if next != hex || abs(picked.opacity - alpha) > 0.5 / 255 { onChange(next, Double(picked.opacity)) }
        }
        self.onEnd = onEnd
    }

    public var body: some View {
        InspectorRow(label) {
            HStack(spacing: SuiteSpacing.s) {
                ColorPicker(
                    label, selection: Binding(get: { color }, set: { pick($0.resolve(in: environment)) }),
                    supportsOpacity: supportsOpacity
                )
                .labelsHidden()
                .accessibilityIdentifier("suite.colorwell." + label.lowercased().replacingOccurrences(of: " ", with: "-"))
                .frame(width: SuiteSize.swatch.width, height: SuiteSize.swatch.height)
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(SuiteColor.outline, lineWidth: 1))
                TextField(
                    "\(label) Hex",
                    text: Binding(get: { draft ?? HexColor(color.resolve(in: environment)).text }, set: { draft = $0 })
                )
                .textFieldStyle(.plain)
                .labelsHidden()
                .font(SuiteFont.inspectorValue)
                .multilineTextAlignment(.trailing)
                .focused($isTyping)
                .onSubmit(commit)
                .onChange(of: isTyping) { _, typing in if !typing { commit() } }
                .frame(width: SuiteSize.hexField)
                .background {
                    if isTyping { RoundedRectangle(cornerRadius: SuiteRadius.field).fill(SuiteColor.fieldActive).padding(-SuiteSpacing.xs) }
                }
                .help("\(label) as a hex code, like #1877F2")
                .accessibilityIdentifier(hexID ?? "", isEnabled: hexID != nil)
                if sampleable { EyedropperButton(help: sampleHelp) { sample($0, ends: &ends) } }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { note in
            if note.object is NSColorPanel { closePicks() }
        }
        .onDisappear(perform: closePicks)
    }

    /// A panel pick. The run is written only when it opens, never per sample.
    private func pick(_ resolved: Color.Resolved) {
        if !ends.isOpen { _ = ends.picked() }
        onPick(resolved)
    }

    /// An eyedropper pick: one change and one end, a gesture of its own, after ending an open run of panel picks.
    /// Nil (Escape) calls neither. EyedropperTests drive it.
    func sample(_ hex: HexColor?, ends: inout HexEnds) {
        guard let hex else { return }
        if ends.isOpen, ends.closed() { onEnd() }
        onPick(kept(hex.resolved))
        onEnd()
    }

    /// `resolved` at the row's kept opacity (the opacity init), else as it is.
    func kept(_ resolved: Color.Resolved) -> Color.Resolved {
        var out = resolved
        if let keptOpacity { out.opacity = keptOpacity }
        return out
    }

    /// Ends an open run of panel picks, once.
    private func closePicks() {
        guard ends.isOpen else { return }
        if ends.closed() { onEnd() }
    }

    private func commit() {
        guard let text = draft else { return }
        draft = nil
        closePicks()
        let result = ends.committed(text, old: HexColor(color.resolve(in: environment)).rgb)
        if let next = result.color { onPick(kept(HexColor(next).resolved)) }
        if result.ended { onEnd() }
    }
}

/// The color row for a HexColor: InspectorColorRow's hex init.
public struct InspectorColorWellRow: View {
    private var row: InspectorColorRow

    /// This row with its hex field identified as `id`, for a page's UI tests.
    func hexIdentifier(_ id: String) -> InspectorColorWellRow {
        var named = self
        named.row.hexID = id
        return named
    }

    /// `onEnd` runs once per gesture, as on InspectorColorRow.
    public init(
        _ label: String, color: HexColor, sampleable: Bool = true, sampleHelp: String? = nil,
        onChange: @escaping @MainActor (HexColor) -> Void, onEnd: @escaping @MainActor () -> Void = {}
    ) {
        row = InspectorColorRow(
            label, hex: color, sampleable: sampleable, sampleHelp: sampleHelp, onChange: onChange, onEnd: onEnd)
    }

    /// The opacity row: the panel's opacity slider shows and `onChange` hears the color and opacity, 0...1.
    public init(
        _ label: String, color: HexColor, opacity: Double, sampleable: Bool = true, sampleHelp: String? = nil,
        onChange: @escaping @MainActor (HexColor, Double) -> Void, onEnd: @escaping @MainActor () -> Void = {}
    ) {
        row = InspectorColorRow(
            label, hex: color, opacity: opacity, sampleable: sampleable, sampleHelp: sampleHelp, onChange: onChange, onEnd: onEnd)
    }

    public var body: some View { row }
}
