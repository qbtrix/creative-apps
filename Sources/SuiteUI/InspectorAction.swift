// InspectorAction.swift: the full-width action at the end of an inspector
// section: 32 pt, the Studio rows' radius and fill with a 1 pt outline, a
// leading symbol and a semibold title, centered. Hover takes the field fill; an action
// that can't run is disabled at 40% and its tooltip says why, from the
// ToolbarAction it is built from. Owns presentation state only: hover.
import SwiftUI

public struct InspectorAction: View {
    private let action: ToolbarAction

    public init(_ action: ToolbarAction) {
        self.action = action
    }

    public var body: some View {
        Button(action: action.perform) {
            Label(action.title, systemImage: action.systemImage).imageScale(.small)
        }
        .buttonStyle(ActionStyle())
        .disabled(!action.isEnabled)
        .help(action.help)
        .suiteControl(action)
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
