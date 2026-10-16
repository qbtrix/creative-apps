// SidebarActionRow.swift: a row of icon-only commands under a sidebar list
// section (Add Page, Delete Page; New Layer, Delete Layer). Each command is a
// ToolbarAction drawn as a native accessory-bar button with its symbol only,
// the shape of an icon-only EditorBarItem. An action that can't run is
// disabled, its symbol dimmed, and its tooltip says why; its accessibility
// label is its title, so the journeys click it by name, and an action with
// an `identifier` carries it and lists itself in `suite.controls`.
import SwiftUI

public struct SidebarActionRow: View {
    private let actions: [ToolbarAction]

    public init(_ actions: [ToolbarAction]) {
        self.actions = actions
    }

    public var body: some View {
        HStack(spacing: 0) {
            ForEach(actions) { action in
                let command = Self.command(for: action)
                Button(action: action.perform) {
                    Label {
                        Text(verbatim: command.label)
                    } icon: {
                        SidebarActionSymbol(systemImage: action.systemImage)
                    }
                    .labelStyle(.iconOnly)
                }
                .buttonStyle(.accessoryBar)
                .disabled(!command.isEnabled)
                // After .disabled, so the tooltip still shows on a disabled command.
                .help(command.help)
                .accessibilityLabel(command.label)
                .suiteControl(action)
            }
            Spacer(minLength: 0)
        }
    }
}

extension SidebarActionRow {
    /// What one command's button shows and says: its accessibility label,
    /// its identifier, its tooltip and whether it can run.
    struct Command: Equatable {
        let label: String
        let identifier: String?
        let help: String
        let isEnabled: Bool
    }

    /// The commands this row draws, in order.
    var commands: [Command] { actions.map(Self.command(for:)) }

    static func command(for action: ToolbarAction) -> Command {
        Command(label: action.title, identifier: action.identifier, help: action.help, isEnabled: action.isEnabled)
    }
}

/// A command's symbol in the secondary color, or tertiary while disabled.
/// Setting the color overrides the system's disabled dimming, so the
/// disabled color is set here too.
private struct SidebarActionSymbol: View {
    let systemImage: String
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Image(systemName: systemImage).foregroundStyle(
            isEnabled ? AnyShapeStyle(SuiteColor.secondaryText) : AnyShapeStyle(HierarchicalShapeStyle.tertiary))
    }
}
