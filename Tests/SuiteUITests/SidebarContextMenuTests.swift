// SidebarContextMenuTests.swift: a sidebar row's context menu, built from the
// app's ToolbarActions (lists-and-layers LL-8a, part of #73). A row with no
// actions, or a window with no `contextActions`, builds no menu; a disabled
// action stays in the menu, disabled, with its unavailableHelp as its help;
// an enabled one has no help and runs its action. Every existing SuiteWindow
// initializer still compiles without the new parameter. macOS only.
import SwiftUI
import Testing
@testable import SuiteUI

@MainActor
@Suite struct SidebarContextMenuTests {
    private static let locked = "Unlock the layer to delete it."

    private static func actions(for id: SidebarItem.ID) -> [ToolbarAction] {
        guard id == "ball" else { return [] }
        return [
            ToolbarAction("Duplicate", systemImage: "plus.square.on.square"),
            ToolbarAction("Delete", systemImage: "trash", unavailableHelp: locked),
        ]
    }

    @Test func anItemWithNoActionsBuildsNoMenu() {
        #expect(SidebarContextMenu.items(for: []) == nil)
        #expect(SidebarNode.menu(for: "sky", from: SidebarContextActions(Self.actions)) == nil)
    }

    @Test func aWindowWithoutContextActionsBuildsNoMenu() {
        #expect(SidebarNode.menu(for: "ball", from: nil) == nil)
    }

    @Test func aDisabledActionIsDisabledWithItsReasonAsHelp() throws {
        let menu = try #require(SidebarNode.menu(for: "ball", from: SidebarContextActions(Self.actions)))
        #expect(menu.map(\.title) == ["Duplicate", "Delete"])
        let delete = try #require(menu.last)
        #expect(delete.isDisabled)
        #expect(delete.help == Self.locked)
        let duplicate = try #require(menu.first)
        #expect(!duplicate.isDisabled)
        #expect(duplicate.help == nil)
    }

    /// Records the actions a menu item runs.
    @MainActor private final class Log {
        var ran: [String] = []
    }

    @Test func anEnabledItemRunsItsAction() throws {
        let log = Log()
        let actions = [ToolbarAction("Duplicate", systemImage: "plus.square.on.square") { log.ran.append("Duplicate") }]
        let item = try #require(SidebarContextMenu.items(for: actions)?.first)
        item.perform()
        #expect(log.ran == ["Duplicate"])
    }

    /// The old forms build without `contextActions`, and the new parameter
    /// fits both rename forms.
    @Test func existingWindowInitializersCompileUnchanged() {
        let item = SidebarItem(id: "ball", title: "Ball", systemImage: "circle")
        let sections = [SidebarSection(id: "layers", title: "Layers", items: [item])]
        _ = SuiteWindow(
            title: "Doc", sections: sections, selection: nil, onSelect: { _ in },
            content: { Text(verbatim: "Content") }, inspector: { Text(verbatim: "Inspector") })
        _ = SuiteWindow(
            title: "Doc", sections: sections, selection: nil, onSelect: { _ in },
            onRename: { (_: String, _: String) in }, content: { Text(verbatim: "Content") },
            inspector: { Text(verbatim: "Inspector") })
        _ = SuiteWindow(
            title: "Doc", sidebarTitle: "Layers", items: [item], selection: nil, onSelect: { _ in },
            content: { Text(verbatim: "Content") }, inspector: { Text(verbatim: "Inspector") })
        _ = SuiteWindow(
            title: "Doc", sections: sections, selection: nil, onSelect: { _ in },
            contextActions: Self.actions, content: { Text(verbatim: "Content") },
            inspector: { Text(verbatim: "Inspector") })
        _ = SuiteWindow(
            title: "Doc", sections: sections, selection: nil, onSelect: { _ in },
            onRename: { (_: String, _: String) -> String? in nil }, contextActions: Self.actions,
            content: { Text(verbatim: "Content") }, inspector: { Text(verbatim: "Inspector") })
    }
}
