// SidebarNestingTests.swift: the sidebar's two-level cap. A top-level item's
// descendants all draw at the second level, depth-first, with no children of
// their own. App-owned expansion (lists-and-layers LL-9, #589, #111): with the
// window's `expanded` and `onExpand`, a group's disclosure follows the app's
// set and a click calls onExpand instead of local state; without onExpand the
// group keeps its own state. That a parent row's toggles stay their own
// accessibility elements is SJ17's step 5 (UITests/SuiteJourneyTests+Lists),
// since an in-process host exposes no List rows to accessibility. macOS only.
import SwiftUI
import Testing
@testable import SuiteUI

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

/// Records what a disclosure reports, and the group's own state.
@MainActor private final class ExpansionLog {
    var calls: [String] = []
    var local = false
    var localBinding: Binding<Bool> { Binding(get: { self.local }, set: { self.local = $0 }) }
    func expansion(_ expanded: Set<SidebarItem.ID>) -> SidebarExpansion {
        SidebarExpansion(expanded: expanded, onExpand: { id, open in self.calls.append("\(id):\(open)") })
    }
}

@MainActor @Test func anAppOwnedDisclosureFollowsTheAppsSet() {
    let log = ExpansionLog()
    let expansion = log.expansion(["a"])
    #expect(SidebarNode.expansion(for: "a", in: expansion, local: log.localBinding).wrappedValue)
    #expect(!SidebarNode.expansion(for: "b", in: expansion, local: log.localBinding).wrappedValue)
    log.local = true
    #expect(!SidebarNode.expansion(for: "b", in: expansion, local: log.localBinding).wrappedValue)
}

@MainActor @Test func aClickCallsOnExpandInsteadOfLocalState() {
    let log = ExpansionLog()
    SidebarNode.expansion(for: "a", in: log.expansion([]), local: log.localBinding).wrappedValue = true
    #expect(log.calls == ["a:true"])
    #expect(!log.local)
    SidebarNode.expansion(for: "a", in: log.expansion(["a"]), local: log.localBinding).wrappedValue = false
    #expect(log.calls == ["a:true", "a:false"])
}

@MainActor @Test func withoutOnExpandTheGroupKeepsItsOwnState() {
    let log = ExpansionLog()
    for expansion in [nil, SidebarExpansion(expanded: ["a"], onExpand: nil)] {
        log.local = false
        let open = SidebarNode.expansion(for: "a", in: expansion, local: log.localBinding)
        #expect(!open.wrappedValue)
        open.wrappedValue = true
        #expect(log.local && open.wrappedValue)
    }
    #expect(log.calls.isEmpty)
}

/// The window's sections inits take the new parameters after `contextActions`.
@MainActor @Test func windowInitializersTakeTheExpansion() {
    let item = SidebarItem(id: "a", title: "A", systemImage: "folder")
    let sections = [SidebarSection(id: "layers", title: "Layers", items: [item])]
    _ = SuiteWindow(
        title: "Doc", sections: sections, selection: nil, onSelect: { _ in }, expanded: ["a"],
        onExpand: { _, _ in }, content: { Text(verbatim: "Content") }, inspector: { Text(verbatim: "Inspector") })
    _ = SuiteWindow(
        title: "Doc", sections: sections, selection: nil, onSelect: { _ in },
        onRename: { (_: String, _: String) -> String? in nil }, contextActions: { _ in [] }, expanded: [],
        onExpand: { _, _ in }, content: { Text(verbatim: "Content") }, inspector: { Text(verbatim: "Inspector") })
}
