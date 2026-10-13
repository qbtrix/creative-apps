// ColorWell.swift: a color as an editor's tool options show it: the system
// color well (ColorPicker) beside its hex code, which the user can also type.
// HexColor is the value both sides speak: 8-bit sRGB, read from "#RRGGBB",
// "RRGGBB" or "#RGB" in either case, written as "#RRGGBB". It is plain and
// tested on its own; its bridge to SwiftUI's Color goes through
// Color.Resolved in sRGB. Text that isn't a hex color keeps the old color.
// The row owns presentation state only: the hex text being typed.
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

    public var color: Color {
        Color(Color.Resolved(red: Float(red) / 255, green: Float(green) / 255, blue: Float(blue) / 255))
    }
}

/// An inspector row with a color well and the color's hex code.
public struct InspectorColorWellRow: View {
    private let label: String
    private let color: HexColor
    private let onChange: @MainActor (HexColor) -> Void
    @State private var draft: String?
    @FocusState private var isTyping: Bool
    @Environment(\.self) private var environment

    public init(_ label: String, color: HexColor, onChange: @escaping @MainActor (HexColor) -> Void) {
        self.label = label
        self.color = color
        self.onChange = onChange
    }

    public var body: some View {
        InspectorRow(label) {
            HStack(spacing: SuiteSpacing.s) {
                ColorPicker(
                    label,
                    selection: Binding(
                        get: { color.color },
                        set: { picked in
                            let hex = HexColor(picked.resolve(in: environment))
                            if hex != color { onChange(hex) }
                        }),
                    supportsOpacity: false
                )
                .labelsHidden()
                TextField("\(label) Hex", text: Binding(get: { draft ?? color.text }, set: { draft = $0 }))
                    .textFieldStyle(.plain)
                    .labelsHidden()
                    .font(SuiteFont.inspectorValue)
                    .focused($isTyping)
                    .onSubmit(commit)
                    .onChange(of: isTyping) { _, typing in if !typing { commit() } }
                    .padding(.horizontal, SuiteSpacing.xs)
                    .padding(.vertical, SuiteSpacing.xxs)
                    .frame(width: SuiteSize.hexField)
                    .background(
                        isTyping ? SuiteColor.fieldActive : SuiteColor.field,
                        in: RoundedRectangle(cornerRadius: SuiteRadius.field))
                    .help("\(label) as a hex code, like #1877F2")
            }
        }
    }

    private func commit() {
        guard let text = draft else { return }
        draft = nil
        if let hex = HexColor(text), hex != color { onChange(hex) }
    }
}
