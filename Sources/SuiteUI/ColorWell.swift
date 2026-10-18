// ColorWell.swift: the one color row (InspectorColorRow): the system color
// well as a swatch capsule beside its hex code, which the user can also type.
// HexColor is the value both sides speak: 8-bit sRGB, read from "#RRGGBB",
// "RRGGBB" or "#RGB" in either case, written as "#RRGGBB". It is plain and
// tested on its own; its bridge to SwiftUI's Color goes through
// Color.Resolved in sRGB. Text that isn't a hex color keeps the old color.
// The text rules are HexColorText, the suite's HexColorEditing (UC2):
// Foundation only, over RGB8. InspectorColorWellRow is its HexColor wrapper.
// Both rows report `onEnd` once per gesture through an EditRun (HexEnds): a
// hex commit is a change and an end in one, even when it keeps the color; the
// color panel's picks stream through `onChange` and end once when the panel
// closes (SwiftUI's ColorPicker reports no end of interaction) or the row goes
// away. The row owns presentation state only: the hex text being typed and
// the gesture's run.
import AppKit
import SwiftUI

/// The hex field's text rules (UC2): "#RRGGBB", "RRGGBB" or "#RGB" in either
/// case, with surrounding spaces and one leading "#" ignored; three digits
/// double up ("#F80" is "#FF8800"). Written as "#RRGGBB", upper case.
/// Foundation only.
public struct HexColorText: HexColorEditing {
    public init() {}

    public func parse(_ text: String) -> RGB8? {
        var digits = text.trimmingCharacters(in: .whitespaces)
        if digits.hasPrefix("#") { digits.removeFirst() }
        if digits.count == 3 { digits = String(digits.flatMap { [$0, $0] }) }
        guard digits.count == 6, digits.allSatisfy(\.isHexDigit), let value = UInt32(digits, radix: 16) else {
            return nil
        }
        return RGB8(UInt8(value >> 16 & 0xFF), UInt8(value >> 8 & 0xFF), UInt8(value & 0xFF))
    }

    public func committed(_ text: String, old: RGB8) -> RGB8 { parse(text) ?? old }

    public func format(_ color: RGB8) -> String {
        "#" + [color.red, color.green, color.blue].map { byte in
            let hex = String(byte, radix: 16, uppercase: true)
            return hex.count == 1 ? "0" + hex : hex
        }.joined()
    }
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

    /// The nearest 8-bit sRGB color to `resolved`; components outside 0...1
    /// are clamped.
    public init(_ resolved: Color.Resolved) {
        func byte(_ value: Float) -> UInt8 {
            guard value.isFinite else { return 0 }
            return UInt8((min(max(value, 0), 1) * 255).rounded())
        }
        self.init(byte(resolved.red), byte(resolved.green), byte(resolved.blue))
    }

    public var resolved: Color.Resolved {
        Color.Resolved(red: Float(red) / 255, green: Float(green) / 255, blue: Float(blue) / 255)
    }

    public var color: Color { Color(resolved) }
}

/// The one color row: a filled InspectorRow with the label on the left, then
/// on the right a swatch capsule (the system color well, which opens the
/// system color panel) with a 1 pt outline and the color's hex code, which the
/// user can also type. Takes a Color, or a HexColor through the second init.
/// `onEnd` runs once per gesture: each hex commit, and each run of panel
/// picks once the panel closes, so a host makes each one undo step.
public struct InspectorColorRow: View {
    private let label: String
    private let color: Color
    private let supportsOpacity: Bool
    private let onPick: @MainActor (Color.Resolved) -> Void
    private let onEnd: @MainActor () -> Void
    @State private var draft: String?
    @State private var ends = HexEnds()
    @FocusState private var isTyping: Bool
    @Environment(\.self) private var environment

    public init(
        _ label: String, color: Color, supportsOpacity: Bool = true, onChange: @escaping @MainActor (Color) -> Void,
        onEnd: @escaping @MainActor () -> Void = {}
    ) {
        self.label = label
        self.color = color
        self.supportsOpacity = supportsOpacity
        self.onPick = { onChange(Color($0)) }
        self.onEnd = onEnd
    }

    /// An 8-bit sRGB color; `onChange` hears only a different one.
    public init(
        _ label: String, hex: HexColor, onChange: @escaping @MainActor (HexColor) -> Void,
        onEnd: @escaping @MainActor () -> Void = {}
    ) {
        self.label = label
        self.color = hex.color
        self.supportsOpacity = false
        self.onPick = { picked in
            let next = HexColor(picked)
            if next != hex { onChange(next) }
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
        if let next = result.color { onPick(HexColor(next).resolved) }
        if result.ended { onEnd() }
    }
}

/// The color row for a HexColor: InspectorColorRow's hex init.
public struct InspectorColorWellRow: View {
    private let row: InspectorColorRow

    /// `onEnd` runs once per gesture, as on InspectorColorRow.
    public init(
        _ label: String, color: HexColor, onChange: @escaping @MainActor (HexColor) -> Void,
        onEnd: @escaping @MainActor () -> Void = {}
    ) {
        row = InspectorColorRow(label, hex: color, onChange: onChange, onEnd: onEnd)
    }

    public var body: some View { row }
}
