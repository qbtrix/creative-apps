// SidebarNestingTests.swift: the sidebar's two-level cap. A top-level item's
// descendants all draw at the second level, depth-first, with no children of
// their own. macOS only.
import SuiteUI
import Testing

@Test func threeLevelsDrawGrandchildrenFlatAtTheSecondLevel() {
    let leaf = SidebarItem(id: "c", title: "Level 3", systemImage: "square")
    let mid = SidebarItem(id: "b", title: "Level 2", systemImage: "folder", children: [leaf])
    let top = SidebarItem(id: "a", title: "Level 1", systemImage: "folder", children: [mid])
    #expect(top.secondLevelRows.map(\.id) == ["b", "c"])
    #expect(top.secondLevelRows.allSatisfy { $0.children.isEmpty })
}

@Test func deepAndWideTreesFlattenDepthFirstInOrder() {
    let d = SidebarItem(id: "d", title: "D", systemImage: "square")
    let c = SidebarItem(id: "c", title: "C", systemImage: "folder", children: [d])
    let b = SidebarItem(id: "b", title: "B", systemImage: "folder", children: [c])
    let e = SidebarItem(id: "e", title: "E", systemImage: "square")
    let top = SidebarItem(id: "a", title: "A", systemImage: "folder", children: [b, e])
    #expect(top.secondLevelRows.map(\.id) == ["b", "c", "d", "e"])
}

@Test func secondLevelRowsKeepEverythingButChildren() {
    let lock = SidebarToggle(id: "l", title: "Lock", onSymbol: "lock", offSymbol: "lock.open", isOn: true)
    let leaf = SidebarItem(id: "c", title: "Leaf", systemImage: "square")
    let mid = SidebarItem(id: "b", title: "Mid", systemImage: "folder", count: 4, toggles: [lock], children: [leaf])
    let top = SidebarItem(id: "a", title: "Top", systemImage: "folder", children: [mid])
    let first = top.secondLevelRows.first
    #expect(first?.title == "Mid")
    #expect(first?.systemImage == "folder")
    #expect(first?.count == 4)
    #expect(first?.toggles == [lock])
    #expect(first?.children.isEmpty == true)
}

@Test func itemsWithoutChildrenHaveNoSecondLevelRows() {
    #expect(SidebarItem(id: "a", title: "A", systemImage: "square").secondLevelRows.isEmpty)
}
