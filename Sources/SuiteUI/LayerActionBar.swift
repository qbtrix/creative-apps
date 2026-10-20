// LayerActionBar.swift: the Layers panel's own surface onto an app's command
// catalog: the icon bar at the bottom of the panel (new layer, new group,
// duplicate, delete, add mask, fx, lock, visibility, as far as the app's
// catalog has them) and, through LayerTreeList's `contextActions`, each row's
// context menu. Neither holds a command of its own. An app builds each item
// the way its Layer menu does, `MenuCommand(spec, on: target)` (CommandPath
// rule), and hands it over as `ToolbarAction(item)`, which keeps the item's
// title, symbol, enablement, reason and action, so the menu bar, the panel and
// the CLI and MCP run one command path and can't disagree. The bar draws with
// SidebarActionRow; a list that isn't LayerTreeList (Design's) uses this bar
// and `layerContextMenu(_:)` the same way. fx is shown disabled with
// `effectsPending` until shared layer styles land; that feature replaces
// `effects(identifier:)` with its own spec's item.
import SwiftUI

extension ToolbarAction {
    /// The panel's button or context item for a menu item an app built from its catalog spec:
    /// the same title, symbol, enablement, reason and action. A disabled item's reason is its help.
    public init(_ item: MenuCommand, identifier: String? = nil) {
        self.init(item.title, systemImage: item.systemImage ?? "circle.dashed",
                  unavailableHelp: item.isEnabled ? nil : item.help, identifier: identifier, perform: item.perform)
    }
}

/// The row of layer commands at the bottom of a Layers panel.
public struct LayerActionBar: View {
    let actions: [ToolbarAction]

    public init(_ actions: [ToolbarAction]) {
        self.actions = actions
    }

    /// Why fx can't run yet.
    public static let effectsPending = "Layer Effects: layer styles aren't built yet."

    /// The fx button until shared layer styles land: disabled, saying why.
    public static func effects(identifier: String?) -> ToolbarAction {
        ToolbarAction("Layer Effects", systemImage: "fx", unavailableHelp: effectsPending, identifier: identifier)
    }

    public var body: some View {
        SidebarActionRow(actions)
            .padding(.horizontal, SuiteSpacing.xs)
    }
}

extension View {
    /// A Layers row's context menu from the app's spec-built actions; none for an empty list.
    public func layerContextMenu(_ actions: [ToolbarAction]) -> some View {
        modifier(SidebarContextMenu(items: SidebarContextMenu.items(for: actions)))
    }
}
