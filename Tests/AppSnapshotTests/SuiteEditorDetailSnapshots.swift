// SuiteEditorDetailSnapshots.swift: EditorDetail filling the frame: a
// CanvasViewport with rulers and a 1600 x 1000 artboard fitted by
// EditorDetailLayout, the floating tool palette at its leading edge clear of
// the rulers and the artboard, and the status line under a hairline, in Light
// and Dark. Writes suiteui-editor-detail-light.png and
// suiteui-editor-detail-dark.png for review, and suiteui-editor-detail-wrapped-*
// for an 18-tool palette (Photo's) in a canvas too short for one column: two
// columns of nine, the artboard clear of both.
import SuiteUI
import SwiftUI
import Testing

@MainActor
@Test func suiteEditorDetail() throws {
    for scheme in [ColorScheme.light, .dark] {
        try snapshot(EditorDetailSample(), name: "suiteui-editor-detail-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        try snapshot(WrappedPaletteSample(), name: "suiteui-editor-detail-wrapped-\(scheme.name)", scheme: scheme)
    }
}

/// An editor detail column with sample tools and a fitted artboard; no state.
struct EditorDetailSample: View {
    private let document = CGSize(width: 1600, height: 1000)
    private let tools = [
        ToolbarAction("Select", systemImage: "cursorarrow", isSelected: true, shortcut: "v"),
        ToolbarAction("Rectangle", systemImage: "rectangle", shortcut: "r"),
        ToolbarAction("Ellipse", systemImage: "circle", shortcut: "e"),
        ToolbarAction("Pen", systemImage: "pencil.tip", shortcut: "p"),
        ToolbarAction("Text", systemImage: "textformat", unavailableHelp: "Text editing isn't wired yet.", shortcut: "t"),
    ]

    /// The fit for the snapshot's 1440 x 900 frame, less the rulers and a 28 pt status line.
    private var zoom: Double {
        let viewport = CGSize(width: 1440 - SuiteSize.ruler, height: 900 - SuiteSize.ruler - 28)
        return EditorDetailLayout(viewport: viewport, toolCount: tools.count).fitScale(artboard: document)
    }

    var body: some View {
        EditorDetail {
            CanvasViewport(documentSize: document, zoom: zoom, checkerboard: false) {
                LinearGradient(colors: [.orange, .pink, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .opacity(0.85)
            } overlay: {
                EmptyView()
            }
        } palette: {
            ToolbarGroup(tools, axis: .vertical)
        } status: {
            ViewerStatusBar(zoom: zoom, size: "1600 × 1000 px")
        }
    }
}

/// Photo's 18 tools at the runner's window height: the palette wraps into two columns of nine.
struct WrappedPaletteSample: View {
    private let document = CGSize(width: 4000, height: 3000)
    private let frame = CGSize(width: 1024, height: 580)
    private let tools = [
        "cursorarrow", "arrow.up.and.down.and.arrow.left.and.right", "lasso", "wand.and.stars", "crop", "eyedropper",
        "paintbrush", "pencil", "eraser", "paintbrush.pointed", "bandage", "drop", "circle.lefthalf.filled",
        "paintpalette", "textformat", "rectangle", "hand.raised", "magnifyingglass",
    ].enumerated().map { ToolbarAction("Tool \($0.offset + 1)", systemImage: $0.element, isSelected: $0.offset == 6) }

    private var zoom: Double {
        let viewport = CGSize(width: frame.width - SuiteSize.ruler, height: frame.height - SuiteSize.ruler - 28)
        return EditorDetailLayout(viewport: viewport, toolCount: tools.count).fitScale(artboard: document)
    }

    var body: some View {
        EditorDetail {
            CanvasViewport(documentSize: document, zoom: zoom, checkerboard: false) {
                LinearGradient(colors: [.teal, .blue, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing)
            } overlay: {
                EmptyView()
            }
        } palette: {
            ToolbarGroup(tools, axis: .vertical)
        } status: {
            ViewerStatusBar(zoom: zoom, size: "4000 × 3000 px")
        }
        .frame(width: frame.width, height: frame.height)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
