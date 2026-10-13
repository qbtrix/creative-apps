// SuiteEditorShellSnapshots.swift: the editor shell parts in one window-sized
// frame (EditorShell with its top bar, docked tool rail, canvas viewport with
// rulers, a selection and a pending crop, the right panel's tabs, sections and
// color well, and the status line). Writes suiteui-editor-shell-light.png and
// suiteui-editor-shell-dark.png; the shell is dark in both on purpose.
import SuiteUI
import SwiftUI
import Testing

@MainActor
@Test func suiteEditorShell() throws {
    for scheme in [ColorScheme.light, .dark] {
        try snapshot(EditorShellSample(), name: "suiteui-editor-shell-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
    }
}

/// Every editor shell part with sample values; no state.
struct EditorShellSample: View {
    var body: some View {
        EditorShell {
            EditorTopBar(app: "Photo", document: "beach.jpg") {
                Button("Open…") {}
            } content: {
                EditorBarItem(ToolbarAction("Open", systemImage: "folder"))
                EditorBarItem(ToolbarAction("Save", systemImage: "square.and.arrow.down"))
                EditorBarItem(ToolbarAction("Export", systemImage: "square.and.arrow.up"))
                EditorBarMenu("Image", systemImage: "photo") { Button("Rotate 90° Clockwise") {} }
                EditorBarDivider()
                EditorBarItem(ToolbarAction("Undo", systemImage: "arrow.uturn.backward"), showsTitle: false)
                EditorBarItem(
                    ToolbarAction("Redo", systemImage: "arrow.uturn.forward", unavailableHelp: "Nothing to redo."),
                    showsTitle: false)
                Spacer()
                EditorBarItem(ToolbarAction("Zoom Out", systemImage: "minus.magnifyingglass"), showsTitle: false)
                EditorBarItem(ToolbarAction("Fit", systemImage: "arrow.up.left.and.arrow.down.right"), showsTitle: false)
                EditorBarItem(ToolbarAction("Zoom In", systemImage: "plus.magnifyingglass"), showsTitle: false)
            }
        } rail: {
            ToolbarGroup(
                [
                    ToolbarAction("Move", systemImage: "arrow.up.and.down.and.arrow.left.and.right", shortcut: "v"),
                    ToolbarAction("Marquee", systemImage: "rectangle.dashed", shortcut: "m"),
                    ToolbarAction("Brush", systemImage: "paintbrush.pointed", isSelected: true, shortcut: "b"),
                    ToolbarAction("Eraser", systemImage: "eraser", shortcut: "e"),
                    ToolbarAction("Crop", systemImage: "crop", shortcut: "c"),
                ], style: .rail)
        } canvas: {
            CanvasViewport(documentSize: CGSize(width: 800, height: 600), zoom: 0.75) {
                LinearGradient(colors: [.orange, .pink, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .opacity(0.85)
            } overlay: {
                SelectionOutline(rect: CGRect(x: 80, y: 60, width: 240, height: 180), zoom: 0.75)
                CropShade(rect: CGRect(x: 400, y: 200, width: 320, height: 300), documentSize: CGSize(width: 800, height: 600), zoom: 0.75)
            }
        } panel: {
            VStack(alignment: .leading, spacing: 0) {
                SegmentedTabs("Panel", tabs: [InspectorOption(id: 0, title: "Adjust"), InspectorOption(id: 1, title: "Layers")], selection: 0) { _ in }
                InspectorSection("Tool Options") {
                    InspectorSliderRow("Size", value: 30, in: 1...500, unit: "px", decimals: 0) { _ in }
                    InspectorColorWellRow("Color", color: HexColor(0x18, 0x77, 0xF2)) { _ in }
                    InspectorSliderRow("Opacity", value: 100, in: 1...100, unit: "%", decimals: 0) { _ in }
                }
                InspectorSection("Exposure", onReset: {}) {
                    InspectorSliderRow("Exposure", value: 0.3, in: -5...5, unit: "EV", decimals: 1) { _ in }
                }
                InspectorSection("Blur") {
                    InspectorSliderRow("Radius", value: 0, in: 0...20, unit: "px", decimals: 1) { _ in }
                }
            }
        } status: {
            ViewerStatusBar(zoom: 0.75, size: "800 × 600 px") { Text("12 ms render") }
        }
    }
}
