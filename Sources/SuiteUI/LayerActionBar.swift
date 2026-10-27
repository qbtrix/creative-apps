// LayerActionBar.swift: the Layers panel's own surface onto an app's command
// catalog: the icon bar at the bottom of the panel (new layer, new group,
// duplicate, delete, add mask, fx, lock, visibility, as far as the app's
// catalog has them) and, through LayerTreeList's `contextActions`, each row's
// context menu. Neither holds a command of its own. An app builds each item
// from the same catalog spec and target as its Layer menu,
// `ToolbarAction(spec, on: target)` (MenuCommand+Catalog.swift), so its title,
// enablement and reason match the menu item's and the menu bar, the panel and
// the CLI and MCP run one command path. The bar draws with
// SidebarActionRow; a List-based panel that isn't LayerTreeList (Design's)
// uses this bar and `layerContextMenu(forSelection:)`, which builds the menu
// only when it opens, for the rows it opened on. fx is `styles(on:...)`, built
// from `style.panel`'s spec; `effects(identifier:)` stays, disabled with
// `effectsPending`, until no app calls it (layer-styles LS-13).
import SuiteImaging
import SwiftUI

/// The row of layer commands at the bottom of a Layers panel.
public struct LayerActionBar: View {
    let actions: [ToolbarAction]

    public init(_ actions: [ToolbarAction]) {
        self.actions = actions
    }

    /// Why fx can't run yet.
    public static let effectsPending = "Layer Effects: layer styles aren't built yet."

    /// The fx button until shared layer styles land: disabled, saying why.
    nonisolated public static func effects(identifier: String?) -> ToolbarAction {
        ToolbarAction("Layer Effects", systemImage: "fx", unavailableHelp: effectsPending, identifier: identifier)
    }

    /// The fx button: `style.panel`'s spec on `target`, so its title and reason are the menu item's; `perform` opens it.
    nonisolated public static func styles<T: LayerStyleTarget>(
        on target: T, identifier: String?, perform: @escaping @MainActor () -> Void
    ) -> ToolbarAction {
        guard let spec = StyleCommands.specs(T.self).first(where: { $0.id == "style.panel" }) else { return effects(identifier: identifier) }
        return ToolbarAction(spec, on: target, systemImage: "fx", identifier: identifier, perform: perform)
    }

    public var body: some View {
        SidebarActionRow(actions)
            .padding(.horizontal, SuiteSpacing.xs)
    }
}

extension View {
    /// A List-based Layers panel's context menu (Design's), built only when it opens, for the rows it
    /// opened on: the selection when a selected row is right-clicked, else that row. No actions, no menu.
    public func layerContextMenu(forSelection actions: @escaping @MainActor (Set<String>) -> [ToolbarAction]) -> some View {
        contextMenu(forSelectionType: String.self) { ids in
            SidebarContextMenu.buttons(SidebarContextMenu.items(for: actions(ids)) ?? [])
        }
    }
}
