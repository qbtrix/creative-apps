// ColorWell.swift: the one color row (InspectorColorRow): the system color
// well as a swatch capsule beside its hex code, which the user can also type.
// HexColor is the value both sides speak: 8-bit sRGB, read from "#RRGGBB",
// "RRGGBB" or "#RGB" in either case, written as "#RRGGBB". It is plain and
// tested on its own; its bridge to SwiftUI's Color goes through
// Color.Resolved in sRGB. Text that isn't a hex color keeps the old color.
// InspectorColorWellRow is its HexColor wrapper. The row owns presentation
// state only: the hex text being typed.
import SwiftUI

public struct HexColor: Hashable, Sendable {
    public let red: UInt8
    public let green: UInt8
    public let blue: UInt8

    public init(_ red: UInt8, _ green: UInt8, _ blue: UInt8) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    public static let black = HexColor(0, 0, 0)

    /// The color `text` names, or nil when it isn't a hex color. Surrounding
    /// spaces and one leading "#" are ignored; three digits double up ("#F80"
    /// is "#FF8800").
    public init?(_ text: String) {
        var digits = text.trimmingCharacters(in: .whitespaces)
        if digits.hasPrefix("#") { digits.removeFirst() }
        if digits.count == 3 { digits = String(digits.flatMap { [$0, $0] }) }
        guard digits.count == 6, digits.allSatisfy(\.isHexDigit), let value = UInt32(digits, radix: 16) else {
            return nil
        }
        self.init(UInt8(value >> 16 & 0xFF), UInt8(value >> 8 & 0xFF), UInt8(value & 0xFF))
    }

    /// "#RRGGBB", upper case.
    public var text: String {
        "#" + [red, green, blue].map { byte in
            let hex = String(byte, radix: 16, uppercase: true)
            return hex.count == 1 ? "0" + hex : hex
        }.joined()
    }

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
public struct InspectorColorRow: View {
    private let label: String
    private let color: Color
    private let supportsOpacity: Bool
    private let onPick: @MainActor (Color.Resolved) -> Void
    @State private var draft: String?
    @FocusState private var isTyping: Bool
    @Environment(\.self) private var environment

    public init(
        _ label: String, color: Color, supportsOpacity: Bool = true, onChange: @escaping @MainActor (Color) -> Void
    ) {
        self.label = label
        self.color = color
        self.supportsOpacity = supportsOpacity
        self.onPick = { onChange(Color($0)) }
    }

    /// An 8-bit sRGB color; `onChange` hears only a different one.
    public init(_ label: String, hex: HexColor, onChange: @escaping @MainActor (HexColor) -> Void) {
        self.label = label
        self.color = hex.color
        self.supportsOpacity = false
        self.onPick = { picked in
            let next = HexColor(picked)
            if next != hex { onChange(next) }
        }
    }

    public var body: some View {
        InspectorRow(label) {
            HStack(spacing: SuiteSpacing.s) {
                ColorPicker(
                    label, selection: Binding(get: { color }, set: { onPick($0.resolve(in: environment)) }),
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
    }

    private func commit() {
        guard let text = draft else { return }
        draft = nil
        if let hex = HexColor(text) { onPick(hex.resolved) }
    }
}

/// The color row for a HexColor: InspectorColorRow's hex init.
public struct InspectorColorWellRow: View {
    private let row: InspectorColorRow

    public init(_ label: String, color: HexColor, onChange: @escaping @MainActor (HexColor) -> Void) {
        row = InspectorColorRow(label, hex: color, onChange: onChange)
    }

    public var body: some View { row }
}
