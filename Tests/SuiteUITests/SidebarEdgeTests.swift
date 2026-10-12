// SidebarEdgeTests.swift: edge cases for the sidebar values and the two
// SuiteWindow initializers apps call. macOS only.
import SuiteUI
import SwiftUI
import Testing

private func visible(_ isOn: Bool) -> SidebarToggle {
    SidebarToggle(id: "v", title: "Visible", onSymbol: "eye", offSymbol: "eye.slash", isOn: isOn)
}

@Test func itemsThatDifferOnlyInAToggleStateAreNotEqual() {
    let shown = SidebarItem(id: "a", title: "Layer", systemImage: "square", toggles: [visible(true)])
    let hidden = SidebarItem(id: "a", title: "Layer", systemImage: "square", toggles: [visible(false)])
    #expect(shown != hidden)
    #expect(shown.id == hidden.id)
}

@Test func itemsThatDifferOnlyInTheirChildrenAreNotEqual() {
    let child = SidebarItem(id: "c", title: "Child", systemImage: "square")
    let empty = SidebarItem(id: "p", title: "Group", systemImage: "folder")
    let full = SidebarItem(id: "p", title: "Group", systemImage: "folder", children: [child])
    #expect(empty != full)
}

@Test func toggleWithOneSymbolForBothStatesShowsIt() {
    let pin = SidebarToggle(id: "p", title: "Pinned", onSymbol: "pin", offSymbol: "pin", isOn: false)
    #expect(pin.systemImage == "pin")
}

@Test func toggleWithAnEmptyTitleStillPicksItsSymbol() {
    let toggle = SidebarToggle(id: "x", title: "", onSymbol: "lock", offSymbol: "lock.open", isOn: true)
    #expect(toggle.systemImage == "lock")
}

@Test func sectionKeepsItsItemsInOrder() {
    let items = ["c", "a", "b"].map { SidebarItem(id: $0, title: $0, systemImage: "square") }
    let section = SidebarSection(id: "s", title: "Layers", items: items)
    #expect(section.items.map(\.id) == ["c", "a", "b"])
}

@MainActor
@Test func bothWindowInitializersStillCompile() {
    let items = [SidebarItem(id: "a", title: "All", systemImage: "photo", count: 2)]
    _ = SuiteWindow(title: "Doc", sidebarTitle: "Library", items: items, selection: "a", onSelect: { _ in }) {
        EmptyView()
    } inspector: {
        EmptyView()
    }
    _ = SuiteWindow(
        title: "Doc", sections: [SidebarSection(id: "s", title: "Library", items: items)], selection: nil,
        onSelect: { _ in }
    ) {
        EmptyView()
    } inspector: {
        EmptyView()
    }
}
