// SidebarNestingTests.swift: the sidebar's two-level cap. A top-level item's
// descendants all draw at the second level, depth-first, with no children of
// their own. App-owned expansion (lists-and-layers LL-9, #589, #111): with the
// window's `expanded` and `onExpand`, a group's disclosure follows the app's
// set and a click calls onExpand instead of local state; without onExpand the
// group keeps its own state. A parent row's toggles stay their own
// accessibility elements (read from a hosted view's tree). macOS only.
import AppKit
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

/// Every accessibility identifier a hosted sidebar list draws with the app's
/// expansion `expanded`, in tree order. The top row has an eye and a lock; its
/// child and grandchild have an eye each.
@MainActor private func hostedSidebarIdentifiers(expanded: Set<SidebarItem.ID>) -> [String] {
    let app = NSApplication.shared
    for attribute in ["AXManualAccessibility", "AXEnhancedUserInterface"] {
        app.accessibilitySetValue(true, forAttribute: NSAccessibility.Attribute(rawValue: attribute))
    }
    let eye = SidebarToggle(id: "visible", title: "Visible", onSymbol: "eye", offSymbol: "eye.slash", isOn: true)
    let lock = SidebarToggle(id: "lock", title: "Lock", onSymbol: "lock", offSymbol: "lock.open", isOn: false)
    let leaf = SidebarItem(id: "c", title: "Leaf", systemImage: "square", toggles: [eye])
    let mid = SidebarItem(id: "b", title: "Mid", systemImage: "folder", toggles: [eye], children: [leaf])
    let top = SidebarItem(id: "a", title: "Top", systemImage: "folder", toggles: [eye, lock], children: [mid])
    let list = SuiteSidebarList(
        sections: [SidebarSection(id: "layers", title: "Layers", items: [top])], selection: nil,
        onSelect: { _ in }, onToggle: { _, _ in }
    )
    .environment(\.sidebarExpansion, SidebarExpansion(expanded: expanded, onExpand: { _, _ in }))
    .frame(width: 300, height: 300)
    let window = NSWindow(
        contentRect: CGRect(x: 0, y: 0, width: 300, height: 300), styleMask: [.titled], backing: .buffered, defer: false)
    window.contentView = NSHostingView(rootView: list)
    window.orderFrontRegardless()
    defer { window.orderOut(nil) }
    RunLoop.main.run(until: Date().addingTimeInterval(0.5))
    return sidebarIdentifiers(in: window)
}

@MainActor private func sidebarIdentifiers(in element: Any) -> [String] {
    let node = element as AnyObject
    var found = [String]()
    if let id = node.accessibilityIdentifier?() ?? nil, !id.isEmpty { found.append(id) }
    for child in (node.accessibilityChildren?() ?? nil) ?? [] { found += sidebarIdentifiers(in: child) }
    return found
}

/// The parent row's eye and lock read as two elements, each once with its own
/// id, not merged into the disclosure row; the app's set opens the group, and
/// the grandchild draws at the second level.
@MainActor @Test func aParentRowsTogglesAreTheirOwnElementsInAnAppOwnedGroup() {
    let open = hostedSidebarIdentifiers(expanded: ["a"])
    #expect(open.filter { $0 == "suite.sidebar.a.visible" }.count == 1)
    #expect(open.filter { $0 == "suite.sidebar.a.lock" }.count == 1)
    #expect(open.contains("suite.sidebar.b.visible") && open.contains("suite.sidebar.c.visible"))
    let closed = hostedSidebarIdentifiers(expanded: [])
    #expect(closed.filter { $0 == "suite.sidebar.a.lock" }.count == 1)
    #expect(!closed.contains("suite.sidebar.b.visible"))
}
