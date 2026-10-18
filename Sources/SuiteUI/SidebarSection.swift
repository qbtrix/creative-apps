// SidebarSection.swift: one titled group of sidebar rows in SuiteWindow, with
// an optional add button in its header, and SidebarNode, the row SuiteWindow
// draws for an item: a SidebarRow, nested in a disclosure group when the item
// has children. Nesting stops at two levels: deeper rows draw flat at the
// second. Its rename can be refused: the app's closure returns nil to accept
// or a message the row keeps its field open for (LL-6); `refusable` lifts the
// Void form. A row's context menu is built from the ToolbarActions the window's
// `contextActions` gives its id, reached through the environment
// (`sidebarContextActions`): a disabled action shows greyed with its
// unavailableHelp as help, and a row with no actions gets no menu (LL-8a).
// Selection stays one SidebarItem.ID across every section. A header's
// title is SuiteColor.textSecondary: the sidebar style's own header gray is
// about 2.2:1 on the sidebar, under the 4.5:1 the app audit asks for.
import SwiftUI

public struct SidebarSection: Identifiable {
    public let id: String
    public let title: String
    public let items: [SidebarItem]
    /// Shown as an icon button in the section header (for example "New Layer").
    public let addAction: ToolbarAction?

    public init(id: String, title: String, items: [SidebarItem], addAction: ToolbarAction? = nil) {
        self.id = id
        self.title = title
        self.items = items
        self.addAction = addAction
    }
}

/// The header SuiteWindow draws for a section: its title and add button.
struct SidebarSectionHeader: View {
    let section: SidebarSection

    var body: some View {
        HStack {
            Text(section.title).foregroundStyle(SuiteColor.textSecondary)
            Spacer(minLength: SuiteSpacing.s)
            if let add = section.addAction {
                Button(action: add.perform) {
                    Label(add.title, systemImage: add.systemImage)
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
                .help(add.title)
                .accessibilityLabel(add.title)
            }
        }
    }
}

/// One top-level item and, through a system disclosure group, its
/// `secondLevelRows`: the two-level cap from docs/design.md.
struct SidebarNode: View {
    let item: SidebarItem
    let onToggle: (@MainActor (SidebarItem.ID, SidebarToggle.ID) -> Void)?
    /// Nil to accept a rename, or the message the row shows when the app refuses it (LL-6).
    let onRename: (@MainActor (SidebarItem.ID, String) -> String?)?
    /// The window's `contextActions`; nil gives no row a menu (LL-8a).
    @Environment(\.sidebarContextActions) private var contextActions

    var body: some View {
        if item.children.isEmpty {
            row
        } else {
            DisclosureGroup {
                ForEach(item.secondLevelRows) { SidebarNode(item: $0, onToggle: onToggle, onRename: onRename) }
            } label: {
                row
            }
        }
    }

    private var row: some View {
        let id = item.id
        var toggle: (@MainActor (SidebarToggle.ID) -> Void)?
        if let onToggle { toggle = { onToggle(id, $0) } }
        var rename: (@MainActor (String) -> String?)?
        if let onRename { rename = { onRename(id, $0) } }
        return SidebarRow(item, onToggle: toggle, refusableRename: rename)
            .modifier(SidebarContextMenu(items: Self.menu(for: id, from: contextActions)))
            .tag(id)
    }

    /// The menu for the row `id`: nil when the window gives no actions for it.
    /// Main actor on purpose: it calls the app's main-actor closure.
    @MainActor static func menu(for id: SidebarItem.ID, from actions: SidebarContextActions?) -> [SidebarMenuItem]? {
        guard let actions else { return nil }
        return SidebarContextMenu.items(for: actions.actions(id))
    }

    /// The Void rename form as one that never refuses.
    nonisolated static func refusable(
        _ onRename: (@MainActor (SidebarItem.ID, String) -> Void)?
    ) -> (@MainActor (SidebarItem.ID, String) -> String?)? {
        guard let onRename else { return nil }
        return { id, name in
            onRename(id, name)
            return nil
        }
    }
}

/// One context menu item: disabled, with its reason as help, while its action can't run.
struct SidebarMenuItem: Identifiable {
    let id: String
    let title: String
    let systemImage: String
    let isDisabled: Bool
    /// The action's unavailableHelp; nil while it can run.
    let help: String?
    let perform: @MainActor () -> Void

    init(_ action: ToolbarAction) {
        id = action.id
        title = action.title
        systemImage = action.systemImage
        isDisabled = !action.isEnabled
        help = action.unavailableHelp
        perform = action.perform
    }
}

/// A row's context menu: system menu buttons, one per item; nil items add no menu.
struct SidebarContextMenu: ViewModifier {
    let items: [SidebarMenuItem]?

    /// The menu `actions` build; nil when there are none.
    static func items(for actions: [ToolbarAction]) -> [SidebarMenuItem]? {
        actions.isEmpty ? nil : actions.map(SidebarMenuItem.init)
    }

    @ViewBuilder func body(content: Content) -> some View {
        if let items {
            content.contextMenu {
                ForEach(items) { item in
                    Button(item.title, systemImage: item.systemImage, action: item.perform)
                        .disabled(item.isDisabled)
                        .help(item.help ?? item.title)
                }
            }
        } else {
            content
        }
    }
}

/// The window's `contextActions`, boxed for the environment: a MainActor
/// object, so the key's nil default stays concurrency-safe.
@MainActor final class SidebarContextActions {
    let actions: @MainActor (SidebarItem.ID) -> [ToolbarAction]

    init(_ actions: @escaping @MainActor (SidebarItem.ID) -> [ToolbarAction]) {
        self.actions = actions
    }
}

extension EnvironmentValues {
    /// The actions each sidebar row's context menu shows; nil gives no row a menu.
    var sidebarContextActions: SidebarContextActions? {
        get { self[SidebarContextActionsKey.self] }
        set { self[SidebarContextActionsKey.self] = newValue }
    }
}

private struct SidebarContextActionsKey: EnvironmentKey {
    static let defaultValue: SidebarContextActions? = nil
}
