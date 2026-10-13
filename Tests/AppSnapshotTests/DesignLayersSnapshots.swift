// DesignLayersSnapshots.swift: Design's panel on the Layers tab at the editor's
// panel width: a Desktop frame holding a group of two shapes (one hidden, one
// locked and selected), the group collapsed, an expanded and a collapsed group
// side by side (the chevrons look alike), and a shape selected whose parent is
// then collapsed, which selects the parent (#121). Each has two pages with
// Page 1 current, so Page 1 keeps its checkmark even while a layer is highlighted,
// with Add Page and Delete Page in a row under the pages. Writes design-layers-,
// -collapsed-, -chevrons- and -collapsed-selection-{light,dark}.png. macOS only.
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
}

private struct PanelSample: View {
    let model: DesignWorkspace
    var body: some View {
        DesignPanel(model: model, tab: .layers)
            .frame(width: SuiteSize.editorPanelWidth)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(SuiteSpacing.xxl)
    }
}
