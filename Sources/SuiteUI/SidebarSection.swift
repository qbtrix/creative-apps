// SidebarSection.swift: one titled group of sidebar rows in SuiteWindow, with
// an optional add button in its header, and SidebarNode, the row SuiteWindow
// draws for an item: a SidebarRow, nested in a disclosure group when the item
// has children. Selection stays one SidebarItem.ID across every section.
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
            Text(section.title)
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

/// One item and, through a system disclosure group, its children.
struct SidebarNode: View {
    let item: SidebarItem
    let onToggle: (@MainActor (SidebarItem.ID, SidebarToggle.ID) -> Void)?
    let onRename: (@MainActor (SidebarItem.ID, String) -> Void)?

    var body: some View {
        if item.children.isEmpty {
            row
        } else {
            DisclosureGroup {
                ForEach(item.children) { SidebarNode(item: $0, onToggle: onToggle, onRename: onRename) }
            } label: {
                row
            }
        }
    }

    private var row: some View {
        let id = item.id
        var toggle: (@MainActor (SidebarToggle.ID) -> Void)?
        if let onToggle { toggle = { onToggle(id, $0) } }
        var rename: (@MainActor (String) -> Void)?
        if let onRename { rename = { onRename(id, $0) } }
        return SidebarRow(item, onToggle: toggle, onRename: rename).tag(id)
    }
}
