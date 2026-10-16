// DesignLayersSnapshots.swift: Design's sidebar (DesignLayersPanel) at the editor's
// panel width: a Desktop frame holding a group of two shapes (one hidden, one
// locked and selected), each row with its eye and lock toggles (#45), the group
// collapsed, the group itself hidden and locked (its shapes' rows dim and show
// the group's state), an expanded and a collapsed group
// side by side (the chevrons look alike), and a shape selected whose parent is
// then collapsed, which selects the parent (#121). Each has two pages with
// Page 1 current, so Page 1 keeps its checkmark even while a layer is highlighted,
// with Add Page and Delete Page in a SidebarActionRow under the pages; a
// one-page file shows Delete Page disabled, saying why. Writes design-layers-,
// -group-hidden-, -collapsed-, -chevrons-, -collapsed-selection- and
// -one-page-{light,dark}.png. The + glyph of the action row sits on the page
// rows' symbol column, measured on the rendered pixels (#1386). macOS only.
import AppKit
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

    /// With a layer selected no page row is highlighted, so the inked bands from the top read: the Pages
    /// header, Page 1, Page 2, then the action row. Its first glyph starts on Page 2's symbol column.
    @Test func thePageActionRowLinesUpWithThePageRows() throws {
        var model = twoPages()
        model.selectItem("node-1")
        #expect(model.selectedNodeIDs == ["node-1"])
        for scheme in [ColorScheme.light, .dark] {
            let image = try #require(render(PanelSample(model: model), scheme: scheme))
            let bands = inkBands(image)
            try #require(bands.count >= 4, "only \(bands.count) inked bands in \(scheme)")
            let page = bands[2]
            let actions = bands[3]
            #expect(abs(actions - page) <= 1, "+ glyph at x \(actions), page symbol at x \(page) in \(scheme)")
        }
    }
}

/// The leading x of the first `count` horizontal bands of ink in the panel, top to bottom. A pixel is
/// ink when it differs from the pixel just inside the panel's leading edge on its own line, so a sidebar
/// material behind the list doesn't count; lines with ink are grouped while consecutive.
@MainActor
private func inkBands(_ image: NSBitmapImageRep, count: Int = 4) -> [Int] {
    let left = Int(SuiteSpacing.xxl) + 1
    let right = min(image.pixelsWide, Int(SuiteSpacing.xxl + SuiteSize.editorPanelWidth))
    guard left < right else { return [] }
    func sRGB(_ x: Int, _ y: Int) -> NSColor? { image.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) }
    var bands: [Int] = []
    var current: Int?
    for y in 0..<image.pixelsHigh where bands.count < count {
        guard let background = sRGB(left, y) else { continue }
        let leading = ((left + 1)..<right).first { x in
            guard let color = sRGB(x, y) else { return false }
            let distance = abs(color.redComponent - background.redComponent)
                + abs(color.greenComponent - background.greenComponent)
                + abs(color.blueComponent - background.blueComponent)
            return distance > 0.25
        }
        if let leading {
            current = min(current ?? leading, leading)
        } else if let band = current {
            bands.append(band)
            current = nil
        }
    }
    return bands
}
