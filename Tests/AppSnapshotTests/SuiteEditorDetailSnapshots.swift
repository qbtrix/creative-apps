// SuiteEditorDetailSnapshots.swift: EditorDetail filling the frame: a
// CanvasViewport with rulers and a 1600 x 1000 artboard fitted by
// EditorDetailLayout, the floating tool palette at its leading edge clear of
// the rulers and the artboard, and the status line under a hairline, in Light
// and Dark. Writes suiteui-editor-detail-light.png and
// suiteui-editor-detail-dark.png for review, and
// suiteui-editor-detail-wrapped-light/dark.png: Photo's 18 tools in a 1024 x 580
// column, too short for one column, so the palette wraps into two.
import SuiteUI
import SwiftUI
import Testing

@MainActor
@Test func suiteEditorDetail() throws {
    for scheme in [ColorScheme.light, .dark] {
        try snapshot(EditorDetailSample(), name: "suiteui-editor-detail-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
    }
}

/// A palette taller than its canvas wraps into columns, and the capsule hugs them (#6426).
@MainActor
@Test func suiteEditorDetailWrapped() throws {
    let tools = (0..<18).map { index in
        ToolbarAction("Tool \(index + 1)", systemImage: index == 0 ? "cursorarrow" : "circle", isSelected: index == 0)
    }
    let frame = CGSize(width: 1024, height: 580)
    for scheme in [ColorScheme.light, .dark] {
        try snapshot(
            EditorDetailSample(frame: frame, tools: tools).frame(width: frame.width, height: frame.height)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading),
            name: "suiteui-editor-detail-wrapped-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
    }
}

/// An editor detail column with sample tools and a fitted artboard; no state.
struct EditorDetailSample: View {
    let document = CGSize(width: 1600, height: 1000)
    var frame = CGSize(width: 1440, height: 900)
    var tools = [
        ToolbarAction("Select", systemImage: "cursorarrow", isSelected: true, shortcut: "v"),
        ToolbarAction("Rectangle", systemImage: "rectangle", shortcut: "r"),
        ToolbarAction("Ellipse", systemImage: "circle", shortcut: "e"),
        ToolbarAction("Pen", systemImage: "pencil.tip", shortcut: "p"),
        ToolbarAction("Text", systemImage: "textformat", unavailableHelp: "Text editing isn't wired yet.", shortcut: "t"),
    ]

    /// The fit for the sample's frame, less the rulers and a 28 pt status line.
    private var zoom: Double {
        let viewport = CGSize(width: frame.width - SuiteSize.ruler, height: frame.height - SuiteSize.ruler - 28)
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
