// SidebarSection.swift: one titled group of sidebar rows in SuiteWindow, with
// an optional add button in its header, and SidebarNode, the row SuiteWindow
// draws for an item: a SidebarRow, nested in a disclosure group when the item
// has children. Nesting stops at two levels: deeper rows draw flat at the
// second. Its rename can be refused: the app's closure returns nil to accept
// or a message the row keeps its field open for (LL-6); `refusable` lifts the
// Void form. Selection stays one SidebarItem.ID across every section. A header's
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
        return SidebarRow(item, onToggle: toggle, refusableRename: rename).tag(id)
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
