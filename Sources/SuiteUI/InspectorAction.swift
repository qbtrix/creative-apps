// InspectorAction.swift: the full-width action at the end of an inspector
// section: 32 pt, the Studio rows' radius and fill with a 1 pt outline, a
// leading symbol and a semibold title, centered. Hover takes the field fill; an action
// that can't run is disabled at 40% and its tooltip says why, from the
// ToolbarAction it is built from. An icon-only action shows just the symbol,
// so several share a row (Align's icon rows); its title stays the accessibility
// label and leads the tooltip while it can't run. Owns presentation state only: hover.
import SwiftUI

public struct InspectorAction: View {
    private let action: ToolbarAction
    private let iconOnly: Bool

    public init(_ action: ToolbarAction, iconOnly: Bool = false) {
        self.action = action
        self.iconOnly = iconOnly
    }

    public var body: some View {
        Button(action: action.perform) {
            let label = Label(action.title, systemImage: action.systemImage)
            if iconOnly { label.labelStyle(.iconOnly) } else { label.imageScale(.small) }
        }
        .buttonStyle(ActionStyle())
        .disabled(!action.isEnabled)
        .help(Self.help(action, iconOnly: iconOnly))
        .suiteControl(action)
    }

    /// The tooltip: the action's own help, except that an icon-only action that can't run names
    /// itself before the reason, since no title is on screen.
    public nonisolated static func help(_ action: ToolbarAction, iconOnly: Bool) -> String {
        guard iconOnly, let reason = action.unavailableHelp else { return action.help }
        return "\(action.title): \(reason)"
    }

    private struct ActionStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            ActionBody(configuration: configuration)
        }
    }

    private struct ActionBody: View {
        let configuration: ButtonStyleConfiguration
        @State private var hovering = false
        @Environment(\.isEnabled) private var isEnabled
        @Environment(\.suiteReduceMotion) private var reduceMotion

        var body: some View {
            let shape = RoundedRectangle(cornerRadius: SuiteRadius.row)
            let lit = isEnabled && (hovering || configuration.isPressed)
            configuration.label
                .font(SuiteFont.inspectorValue)
                .foregroundStyle(Color.primary)
                .frame(maxWidth: .infinity)
                .frame(height: SuiteSize.actionButton)
                .background(lit ? SuiteColor.field : SuiteColor.panelRaised, in: shape)
                .overlay(shape.strokeBorder(SuiteColor.outline, lineWidth: 1))
                .contentShape(shape)
                .opacity(isEnabled ? 1 : SuiteColor.disabledOpacity)
                .onHover { hovering = $0 }
                .animation(SuiteMotion.state(reduceMotion: reduceMotion), value: hovering)
        }
    }
}
