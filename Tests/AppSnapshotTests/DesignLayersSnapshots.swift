// DesignLayersSnapshots.swift: Design's sidebar (DesignLayersPanel) at the editor's
// panel width: a Desktop frame holding a group of two shapes (one hidden, one
// locked and selected), each row with its eye and lock toggles (#45), the group
// collapsed, the group itself hidden and locked (its shapes' rows dim and show
// the group's state), an expanded and a collapsed group
// side by side (the chevrons look alike), and a shape selected whose parent is
// then collapsed, which selects the parent (#121). Each has two pages with
// Page 1 current, so Page 1 keeps its checkmark even while a layer is highlighted,
// with Add Page and Delete Page in a SidebarActionRow under the pages; a
// one-page file shows Delete Page disabled, saying why, and with no file open
// both are disabled. Writes design-layers-, -group-hidden-, -collapsed-,
// -chevrons-, -collapsed-selection-, -one-page- and -no-file-{light,dark}.png.
// macOS only.
import DesignModel
import SuiteUI
import SwiftUI
import Testing

@testable import DesignApp

@MainActor
@Suite struct DesignLayersSnapshots {
    private func shoot(_ state: String, _ model: DesignWorkspace) throws {
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                PanelSample(model: model), name: "design-layers\(state)-\(scheme == .dark ? "dark" : "light")",
                scheme: scheme)
        }
    }

    /// Page 1 holds the Desktop frame (node-1); page 2 holds its own (node-2). Returns the model.
    private func twoPages() -> DesignWorkspace {
        var model = DesignWorkspace()
        model.newFile()
        model.addPage()
        model.selectPage("page-1")
        return model
    }

    private let box = DesignRect(x: 40, y: 40, width: 200, height: 120)

    @Test func expandedAndCollapsed() throws {
        var model = twoPages()
        let group = try model.addNode(.group, frame: box, in: "node-1")
        let rectangle = try model.addNode(.rectangle, frame: box, in: group)
        let ellipse = try model.addNode(.ellipse, frame: box, in: group)
        try model.setNodeHidden(rectangle, true)
        try model.setNodeLocked(ellipse, true)
        try shoot("", model)
        // Hiding and locking the group shows on its shapes' rows.
        var grouped = model
        try grouped.toggleNodeFlag(group, .hidden)
        try grouped.toggleNodeFlag(group, .locked)
        #expect(grouped.isHiddenInTree(rectangle) && grouped.isLockedInTree(ellipse))
        try shoot("-group-hidden", grouped)
        // Collapsing the group hides its two shapes; its chevron turns to point right.
        model.deselect()
        try model.setExpanded(group, false)
        try shoot("-collapsed", model)
    }

    @Test func chevronsLookAlike() throws {
        var model = twoPages()
        let open = try model.addNode(.group, frame: box, in: "node-1")
        try model.addNode(.rectangle, frame: box, in: open)
        let closed = try model.addNode(.group, frame: box, in: "node-1")
        try model.addNode(.ellipse, frame: box, in: closed)
        model.deselect()
        try model.setExpanded(closed, false)
        #expect(model.isExpanded(open) && !model.isExpanded(closed))
        try shoot("-chevrons", model)
    }

    @Test func collapsingTheParentOfTheSelectionHighlightsTheParent() throws {
        var model = twoPages()
        let group = try model.addNode(.group, frame: box, in: "node-1")
        let rectangle = try model.addNode(.rectangle, frame: box, in: group)
        model.selectItem(rectangle)
        try model.setExpanded(group, false)
        #expect(model.selectedNodeID == group)
        try shoot("-collapsed-selection", model)
    }

    @Test func aOnePageFileCantDeleteItsPage() throws {
        var model = DesignWorkspace()
        model.newFile()
        let entries = DesignLayersPanel.pageCommands(model, { _ in }).map { $0.controlEntry() }
        #expect(entries == [
            ControlEntry(id: "design.page.add", enabled: true),
            ControlEntry(id: "design.page.delete", enabled: false, reason: "A file keeps at least one page."),
        ])
        let titles = DesignLayersPanel.pageCommands(model, { _ in }).map { $0.title }
        #expect(titles == ["Add Page", "Delete Page"])
        try shoot("-one-page", model)
        let allEnabled = DesignLayersPanel.pageCommands(twoPages(), { _ in }).allSatisfy { $0.isEnabled }
        #expect(allEnabled)
    }

    /// With no file open, Add Page can't add one, so both page commands are off and say why.
    @Test func noFileDisablesBothPageCommands() throws {
        let model = DesignWorkspace()
        let entries = DesignLayersPanel.pageCommands(model, { _ in }).map { $0.controlEntry() }
        #expect(entries == [
            ControlEntry(id: "design.page.add", enabled: false, reason: "Create or open a file first."),
            ControlEntry(id: "design.page.delete", enabled: false, reason: "Create or open a file first."),
        ])
        try shoot("-no-file", model)
    }
}

private struct PanelSample: View {
    let model: DesignWorkspace
    var body: some View {
        DesignLayersPanel(model: model, perform: { _ in })
            .frame(width: SuiteSize.editorPanelWidth)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(SuiteSpacing.xxl)
    }
}
