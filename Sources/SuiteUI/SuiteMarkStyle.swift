// SuiteMarkStyle.swift: the plain icon button for a small mark, such as a
// rating star or a color dot. It draws no chrome at rest; hover and press
// light a `rowHover` fill behind the mark, so every mark shows the state it
// is in (docs/design.md: round icon buttons take `rowHover` on hover). Disabled
// marks never light. The label carries its own hit frame, so the fill covers
// the whole hit. Owns presentation state only: hover.
import SwiftUI

public struct SuiteMarkStyle: ButtonStyle {
    public init() {}

    /// Whether a mark's fill is lit: hovered or pressed, and enabled.
    public static func highlight(hovering: Bool, pressed: Bool, enabled: Bool) -> Bool {
        enabled && (hovering || pressed)
    }

    public func makeBody(configuration: Configuration) -> some View {
        MarkBody(configuration: configuration)
    }

    private struct MarkBody: View {
        let configuration: Configuration
        @State private var hovering = false
        @Environment(\.isEnabled) private var isEnabled
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        var body: some View {
            let lit = SuiteMarkStyle.highlight(
                hovering: hovering, pressed: configuration.isPressed, enabled: isEnabled)
            configuration.label
                .background(lit ? SuiteColor.rowHover : .clear, in: .rect(cornerRadius: SuiteRadius.row))
                .contentShape(.rect)
                .onHover { hovering = $0 }
                .animation(SuiteMotion.state(reduceMotion: reduceMotion), value: lit)
        }
    }
}
