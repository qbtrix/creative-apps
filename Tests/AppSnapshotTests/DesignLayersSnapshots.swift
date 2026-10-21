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
// both are disabled. On `cards` (layers-panel L-4): the A row in rename, opened
// through its "Rename" action in a hosted window, the way a double-click opens
// it (nested in BodyCountSuites, see there); Title moved into Pair with both
// expanded, whose eye and lock columns sit at one x at A's depth and Title's,
// also with Pair hidden and locked; a drag in flight, its line on C's top edge and its tint on
// Pair; and a page with no layers, whose hint lines each fit the panel. Writes
// design-layers-, -group-hidden-, -collapsed-, -chevrons-, -collapsed-selection-,
// -one-page-, -no-file-, -renaming-, -nested-, -drop-above-, -drop-into- and -empty-{light,dark}.png.
// macOS only.
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

// Its hosted windows open a rename field, and every window's field shares the one field editor, so
// it nests in BodyCountSuites and never runs beside another hosted test that edits text.
extension BodyCountSuites {
    @MainActor
    @Suite struct DesignLayersRowSnapshots {
        let desktop = "node-1", a = "node-2", title = "node-5", pair = "node-6"

        /// `cards` with Desktop open: A, B, C, Title, Pair, Locked and Hidden under it.
        private func cards() throws -> DesignWorkspace {
            var model = DesignFixtures.cards
            try model.setExpanded(desktop, true)
            return model
        }

        @Test func aRowInRename() async throws {
            for scheme in [ColorScheme.light, .dark] {
                let w = RenderBudgetWindow(PanelSample(model: try cards()).hosted(scheme), size: Self.size)
                defer { w.close() }
                w.window.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
                try await w.settle(300)
                let name = try #require(w.element(.staticText, in: "design.layer.\(a)"), "no title on A")
                #expect(w.perform(SidebarRow.renameActionName, on: "design.layer.\(a)"), "A has no Rename action")
                try await w.settle(300)
                let field = await w.element("suite.sidebar.\(a).rename")
                #expect(field != nil, "A's rename field didn't open")
                // The field takes the title text's place (its own inset aside): the name doesn't jump left.
                if let field { #expect(field.minX >= name.minX && field.minX - name.minX <= SuiteSpacing.s, "the field at \(field.minX), the title at \(name.minX)") }
                try Self.write(w, name: "design-layers-renaming-\(scheme == .dark ? "dark" : "light")")
            }
        }

        @Test func aLayerNestedInAGroup() async throws {
            var model = try cards()
            try model.moveLayer(title, into: pair, at: 0)
            try model.setExpanded(pair, true)
            model.deselect()
            #expect(model.layerRows.contains { $0.id == title })
            for scheme in [ColorScheme.light, .dark] {
                try snapshot(PanelSample(model: model), name: "design-layers-nested-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
            }
            // The eye and lock columns share one x at every depth (blueprint 7.3, item 4), and stay there
            // when Title's toggles show its group hidden and locked.
            var shut = model
            try shut.toggleNodeFlag(pair, .hidden)
            try shut.toggleNodeFlag(pair, .locked)
            for sample in [model, shut] {
                let w = RenderBudgetWindow(PanelSample(model: sample).hosted(.light), size: Self.size)
                defer { w.close() }
                try await w.settle(300)
                for flag in DesignLayerFlag.allCases {
                    let outer = try #require(await w.element("suite.sidebar.\(a).\(flag.rawValue)"), "no \(flag) on A")
                    let inner = try #require(await w.element("suite.sidebar.\(title).\(flag.rawValue)"), "no \(flag) on Title")
                    #expect(abs(outer.midX - inner.midX) < 0.5, "\(flag): A at \(outer.midX), Title at \(inner.midX)")
                }
            }
        }

        /// A drag in flight on `cards`: the accent line on C's top edge (B dropped above C), and the
        /// tint on Pair's row (Title dropped into Pair), the two drops J12 makes (#3556).
        @Test func aDragShowsItsDropLine() throws {
            let model = try cards()
            let c = "node-4"
            for (state, line) in [("above", DesignLayerDropLine(rowID: c, position: .above)),
                                  ("into", DesignLayerDropLine(rowID: pair, position: .into))] {
                for scheme in [ColorScheme.light, .dark] {
                    try snapshot(
                        PanelSample(model: model, dropLine: line),
                        name: "design-layers-drop-\(state)-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
                }
            }
        }

        @Test func aPageWithNoLayers() throws {
            var model = DesignWorkspace()
            model.newFile()
            model.selectItem(desktop)
            model.deleteSelection()
            #expect(model.selectedPage?.nodes.isEmpty == true)
            // A list row doesn't grow for a wrapped note, so each line of the hint fits the panel's text
            // column on one line: the panel less a note's inset and the list's row inset on each side.
            let column = SuiteSize.editorPanelWidth - 2 * (SuiteSpacing.m + SuiteSpacing.l)
            for open in [true, false] {
                for line in DesignLayersPanel.emptyNotes(isOpen: open) {
                    let width = NSHostingView(rootView: Text(line).font(SuiteFont.inspectorMeta)).fittingSize.width
                    #expect(width <= column, "\"\(line)\" is \(width) pt, the column \(column)")
                }
            }
            for scheme in [ColorScheme.light, .dark] {
                try snapshot(PanelSample(model: model), name: "design-layers-empty-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
            }
        }

        static let size = CGSize(width: 1440, height: 900)

        /// The hosted window's view as a 1440 × 900 PNG in .build/snapshots, as `snapshot` writes one.
        static func write<V: View>(_ w: RenderBudgetWindow<V>, name: String) throws {
            let host = w.host
            guard let image = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { throw SnapshotError.render(name) }
            host.cacheDisplay(in: host.bounds, to: image)
            guard let png = image.representation(using: .png, properties: [:]) else { throw SnapshotError.encode(name) }
            let folder = try packageRoot().appending(path: ".build/snapshots")
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try png.write(to: folder.appending(path: "\(name).png"))
        }
    }
}

extension View {
    /// The snapshot look for a view hosted in a live window: window background, scheme, flat glass.
    fileprivate func hosted(_ scheme: ColorScheme) -> some View {
        let size = BodyCountSuites.DesignLayersRowSnapshots.size
        return frame(width: size.width, height: size.height)
            .background(SuiteColor.windowBackground)
            .environment(\.colorScheme, scheme)
            .environment(\.suiteSnapshotRendering, true)
    }
}

private struct PanelSample: View {
    let model: DesignWorkspace
    var dropLine: DesignLayerDropLine?
    var body: some View {
        DesignLayersPanel(model: model, perform: { _ in }, seededLine: dropLine)
            .frame(width: SuiteSize.editorPanelWidth)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(SuiteSpacing.xxl)
    }
}
