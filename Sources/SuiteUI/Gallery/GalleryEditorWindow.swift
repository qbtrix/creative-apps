// GalleryEditorWindow.swift: the gallery's `editor-window` page (editor-in-window, EW-5), driven by
// SuiteJourneyTests+EditorWindow.swift. A SuiteWindow from the `sidebar:` init (it skips the -SuiteGallery check,
// so the page never recurses): the save state as subtitle, Pages with a SidebarActionRow and Layers in the sidebar,
// New and Open beside the title, Save, Undo, Redo and the zooms trailing, an EditorDetail with a 1600 x 1000 artboard
// fitted by EditorDetailLayout, and a 304 pt inspector. Add and Delete Page are the edits Undo and Redo step through;
// a tool's key picks it. Opened from the index, the page sizes its window to the editor's launch size (the
// index's window is narrower than the page's minimum). Every control acts or says why, with a `suite.gallery.*` id, so the `suiteui` audit stays 0.
import SwiftUI

enum GalleryEditorWindow {
    static let name = "editor-window"

    @MainActor static let pages: GalleryPages = [name: { AnyView(GalleryEditorWindowPage()) }]
}

private struct GalleryEditorWindowPage: View {
    private static let document = CGSize(width: 1600, height: 1000)
    private static let tools: [(title: String, systemImage: String, key: Character)] = [
        ("Select", "cursorarrow", "v"), ("Rectangle", "rectangle", "r"), ("Ellipse", "circle", "e"),
        ("Pen", "pencil.tip", "p"), ("Text", "textformat", "t"),
    ]
    private static let layers = [
        SidebarItem(id: "layer.title", title: "Title Text", systemImage: "textformat"),
        SidebarItem(id: "layer.shape", title: "Shape", systemImage: "circle"),
        SidebarItem(id: "layer.background", title: "Background", systemImage: "rectangle"),
    ]

    @State private var title = "Poster"
    @State private var edited = true
    @State private var pageCount = 1
    @State private var undoCounts: [Int] = []
    @State private var redoCounts: [Int] = []
    @State private var selection: String? = "page.1"
    @State private var tool = "Select"
    @State private var chosenZoom: Double?  // the zoom the user picked; nil follows the fit
    @State private var viewport = CGSize.zero  // the area inside the rulers, as CanvasViewport reports it

    private var fitZoom: Double {
        EditorDetailLayout(viewport: viewport, toolCount: Self.tools.count).fitScale(artboard: Self.document)
    }

    private var zoom: Double { chosenZoom ?? fitZoom }

    /// The size the page asks of its window when it opens from the index: the editor window's launch size (the
    /// sidebar ideal, the content ideal and the 304 pt inspector, at the launch height) plus the gallery's back row
    /// above it. The index opens the window at its own, smaller launch size, and a window doesn't grow when a page's
    /// minimum does: at that size the window clipped the sidebar, the status line and a toolbar action.
    /// SuiteWindowSizer fits it to the screen's visible frame. Under -SuiteWindowSize the window already has its size.
    private static let windowSize = CGSize(
        width: SuiteSize.sidebarWidth.ideal + SuiteSize.contentIdealWidth + inspectorWidth,
        height: SuiteSize.windowLaunch.height + SuiteSize.toolButton + 2 * SuiteSpacing.s)
    private static let inspectorWidth = SuiteSize.editorPanelWidth + 2 * SuiteSpacing.m
    private static let sizesWindow = SuiteWindowSize.parse(ProcessInfo.processInfo.arguments) == nil

    var body: some View {
        window
            .background {
                if Self.sizesWindow { SuiteWindowSizer(size: Self.windowSize) }
            }
    }

    private var window: some View {
        SuiteWindow(
            title: title, subtitle: edited ? "Edited" : "", documentActions: documentActions, actions: actions,
            inspectorWidth: Self.inspectorWidth
        ) {
            sidebar
        } content: {
            EditorDetail {
                CanvasViewport(
                    documentSize: Self.document, zoom: zoom, checkerboard: false,
                    onSize: { viewport = $0 }, onZoom: { chosenZoom = $0 }, onKey: { pick($0) }
                ) {
                    EmptyView()
                } overlay: {
                    EmptyView()
                }
            } palette: {
                ToolbarGroup(palette, axis: .vertical)
            } status: {
                ViewerStatusBar(
                    zoom: zoom, size: "1600 × 1000 px",
                    preview: ("This page draws built-in sample data.", "suite.gallery.status.preview")) { Text(tool) }
            }
        } inspector: {
            InspectorHeader(
                "Page \(selectedPage ?? 1)",
                facts: [InspectorFact("Size", "1600 × 1000 px"), InspectorFact("Layers", "\(Self.layers.count)")]
            )
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// The selected page's number; nil while a layer is selected.
    private var selectedPage: Int? {
        guard let selection, selection.hasPrefix("page.") else { return nil }
        return Int(selection.dropFirst(5))
    }

    private var sidebar: some View {
        List(selection: $selection) {
            Section {
                ForEach(1...max(pageCount, 1), id: \.self) { page in
                    SidebarRow(SidebarItem(id: "page.\(page)", title: "Page \(page)", systemImage: "doc"))
                        .tag("page.\(page)")
                }
                SidebarActionRow(pageActions)
            } header: {
                SidebarSectionHeader(section: SidebarSection(id: "pages", title: "Pages", items: []))
            }
            Section {
                ForEach(Self.layers) { SidebarRow($0).tag($0.id) }
            } header: {
                SidebarSectionHeader(section: SidebarSection(id: "layers", title: "Layers", items: []))
            }
        }
        .listStyle(.sidebar)
    }

    private var pageActions: [ToolbarAction] {
        [
            ToolbarAction("Add Page", systemImage: "plus", identifier: "suite.gallery.page.add") {
                edit(to: pageCount + 1)
            },
            ToolbarAction(
                "Delete Page", systemImage: "trash",
                unavailableHelp: pageCount > 1 ? nil : "A document keeps at least one page.",
                identifier: "suite.gallery.page.delete"
            ) { edit(to: pageCount - 1) },
        ]
    }

    private var documentActions: [ToolbarAction] {
        [
            ToolbarAction("New", systemImage: "doc.badge.plus", identifier: "suite.gallery.bar.new") { open("Untitled") },
            ToolbarAction("Open", systemImage: "folder", identifier: "suite.gallery.bar.open") { open("Poster") },
        ]
    }

    private var actions: [ToolbarAction] {
        [
            ToolbarAction(
                "Save", systemImage: "square.and.arrow.down", unavailableHelp: edited ? nil : "No changes to save.",
                identifier: "suite.gallery.bar.save"
            ) { edited = false },
            ToolbarAction(
                "Undo", systemImage: "arrow.uturn.backward",
                unavailableHelp: undoCounts.isEmpty ? "Nothing to undo." : nil, identifier: "suite.gallery.bar.undo"
            ) { step(back: true) },
            ToolbarAction(
                "Redo", systemImage: "arrow.uturn.forward",
                unavailableHelp: redoCounts.isEmpty ? "Nothing to redo." : nil, identifier: "suite.gallery.bar.redo"
            ) { step(back: false) },
            ToolbarAction(
                "Zoom Out", systemImage: "minus.magnifyingglass",
                unavailableHelp: zoom > ZoomMath.range.lowerBound ? nil : "Already at the smallest zoom.",
                identifier: "suite.gallery.bar.zoom-out"
            ) { chosenZoom = ZoomMath.zoomedOut(from: zoom) },
            ToolbarAction(
                "Fit", systemImage: "arrow.up.left.and.arrow.down.right", identifier: "suite.gallery.bar.fit"
            ) { chosenZoom = nil },
            ToolbarAction(
                "Zoom In", systemImage: "plus.magnifyingglass",
                unavailableHelp: zoom < ZoomMath.range.upperBound ? nil : "Already at the largest zoom.",
                identifier: "suite.gallery.bar.zoom-in"
            ) { chosenZoom = ZoomMath.zoomedIn(from: zoom) },
        ]
    }

    private var palette: [ToolbarAction] {
        Self.tools.map { item in
            ToolbarAction(
                item.title, systemImage: item.systemImage, isSelected: item.title == tool, shortcut: item.key,
                identifier: "suite.gallery.tool.\(item.title.lowercased())"
            ) { tool = item.title }
        }
    }

    /// The tool whose key was pressed, with no Command, Option or Control held.
    private func pick(_ press: KeyPress) -> KeyPress.Result {
        guard press.modifiers.isDisjoint(with: [.command, .option, .control]),
            let item = Self.tools.first(where: { String($0.key) == press.characters.lowercased() })
        else { return .ignored }
        tool = item.title
        return .handled
    }

    /// One page edit: the page count before it goes on the undo stack.
    private func edit(to count: Int) {
        guard count >= 1 else { return }
        undoCounts.append(pageCount)
        redoCounts.removeAll()
        setPages(count)
    }

    /// `count` pages, edited; a selected page past the last selects the last.
    private func setPages(_ count: Int) {
        pageCount = count
        edited = true
        if let page = selectedPage, page > count { selection = "page.\(count)" }
    }

    /// Undo (`back`) or Redo: the page count the last undo or redo entry holds.
    private func step(back: Bool) {
        guard let count = back ? undoCounts.popLast() : redoCounts.popLast() else { return }
        if back { redoCounts.append(pageCount) } else { undoCounts.append(pageCount) }
        setPages(count)
    }

    /// A fresh document named `name`: one page, saved, fitted, no history.
    private func open(_ name: String) {
        title = name
        pageCount = 1
        undoCounts.removeAll()
        redoCounts.removeAll()
        selection = "page.1"
        chosenZoom = nil
        edited = false
    }
}
