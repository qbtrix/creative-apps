// SuiteSidebarList.swift: the system sidebar List SuiteWindow's sections inits
// draw, one Section per SidebarSection (SidebarSectionHeader, SidebarNode rows).
// `onSelect` gets a selection; `onToggle`, `onMove` and `onRename` turn on a row
// toggle click, a drag reorder within a section's top-level rows and a
// double-click rename (nil turns that gesture off). A rename can be refused:
// the overload's closure returns a message the row shows inline (LL-6).
import SwiftUI

public struct SuiteSidebarList: View {
    private let sections: [SidebarSection]
    private let selection: SidebarItem.ID?
    private let onSelect: @MainActor (SidebarItem.ID) -> Void
    private let onToggle: (@MainActor (SidebarItem.ID, SidebarToggle.ID) -> Void)?
    private let onMove: (@MainActor (SidebarSection.ID, IndexSet, Int) -> Void)?
    private let onRename: (@MainActor (SidebarItem.ID, String) -> String?)?

    public init(
        sections: [SidebarSection], selection: SidebarItem.ID?,
        onSelect: @escaping @MainActor (SidebarItem.ID) -> Void,
        onToggle: (@MainActor (SidebarItem.ID, SidebarToggle.ID) -> Void)? = nil,
        onMove: (@MainActor (SidebarSection.ID, IndexSet, Int) -> Void)? = nil,
        onRename: (@MainActor (SidebarItem.ID, String) -> Void)? = nil
    ) {
        self.init(
            sections: sections, selection: selection, onSelect: onSelect, onToggle: onToggle, onMove: onMove,
            refusableRename: SidebarNode.refusable(onRename))
    }

    /// A rename the app can refuse: `onRename` returns nil to accept, or the
    /// message the row shows under the field it keeps open (LL-6).
    public init(
        sections: [SidebarSection], selection: SidebarItem.ID?,
        onSelect: @escaping @MainActor (SidebarItem.ID) -> Void,
        onToggle: (@MainActor (SidebarItem.ID, SidebarToggle.ID) -> Void)? = nil,
        onMove: (@MainActor (SidebarSection.ID, IndexSet, Int) -> Void)? = nil,
        onRename: @escaping @MainActor (SidebarItem.ID, String) -> String?
    ) {
        self.init(
            sections: sections, selection: selection, onSelect: onSelect, onToggle: onToggle, onMove: onMove,
            refusableRename: onRename)
    }

    init(
        sections: [SidebarSection], selection: SidebarItem.ID?, onSelect: @escaping @MainActor (SidebarItem.ID) -> Void,
        onToggle: (@MainActor (SidebarItem.ID, SidebarToggle.ID) -> Void)?,
        onMove: (@MainActor (SidebarSection.ID, IndexSet, Int) -> Void)?,
        refusableRename onRename: (@MainActor (SidebarItem.ID, String) -> String?)?
    ) {
        self.sections = sections
        self.selection = selection
        self.onSelect = onSelect
        self.onToggle = onToggle
        self.onMove = onMove
        self.onRename = onRename
    }

    public var body: some View {
        List(selection: Binding(get: { selection }, set: { id in if let id { onSelect(id) } })) {
            ForEach(sections) { section in
                Section {
                    ForEach(section.items) { SidebarNode(item: $0, onToggle: onToggle, onRename: onRename) }
                        .onMove(perform: moveAction(in: section.id))
                } header: {
                    SidebarSectionHeader(section: section)
                }
            }
        }
        .listStyle(.sidebar)
    }

    /// Drag reorder for one section's rows; nil (reorder off) without `onMove`.
    private func moveAction(in sectionID: SidebarSection.ID) -> ((IndexSet, Int) -> Void)? {
        guard let onMove else { return nil }
        return { from, to in onMove(sectionID, from, to) }
    }
}
