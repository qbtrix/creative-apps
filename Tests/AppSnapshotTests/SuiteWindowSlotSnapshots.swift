// SuiteWindowSlotSnapshots.swift: a SuiteWindow built with the `sidebar:` init
// (EW-1): an app's own two-section list (Pages and Layers) in the sidebar
// slot, the subtitle "Edited", New and Open as document actions, and an
// editor's 304 pt inspector (editorPanelWidth plus SuiteSpacing.m on each
// side). The window is the launch size with that inspector in the ideal's
// place, at the top leading corner of the 1440x900 frame. Writes
// suiteui-window-slot-light.png and suiteui-window-slot-dark.png for review.
import SuiteUI
import SwiftUI
import Testing

@MainActor
@Test func suiteWindowSlot() throws {
    for scheme in [ColorScheme.light, .dark] {
        try snapshot(WindowSlotSample(), name: "suiteui-window-slot-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
    }
}

/// A SuiteWindow with its own sidebar list, a subtitle and a wide inspector; no state.
private struct WindowSlotSample: View {
    static let inspectorWidth = SuiteSize.editorPanelWidth + 2 * SuiteSpacing.m

    var body: some View {
        SuiteWindow(
            title: "Untitled", subtitle: "Edited",
            documentActions: [
                ToolbarAction("New", systemImage: "doc.badge.plus", identifier: "sample.new"),
                ToolbarAction("Open", systemImage: "folder", identifier: "sample.open"),
            ],
            actions: [ToolbarAction("Undo", systemImage: "arrow.uturn.backward", unavailableHelp: "Nothing to undo.")],
            inspectorWidth: Self.inspectorWidth
        ) {
            List {
                Section("Pages") {
                    Label("Page 1", systemImage: "doc")
                    Label("Page 2", systemImage: "doc")
                }
                Section("Layers") {
                    Label("Title Text", systemImage: "textformat")
                    Label("Background", systemImage: "rectangle")
                }
            }
            .listStyle(.sidebar)
            .accessibilityIdentifier("sample.layers")
        } content: {
            Text("Canvas").font(SuiteFont.headline).frame(maxWidth: .infinity, maxHeight: .infinity)
        } inspector: {
            InspectorSection("Background") {
                InspectorSliderRow("Opacity", value: 100, in: 0...100, unit: "%", decimals: 0) { _ in }
            }
        }
        .frame(
            width: SuiteSize.sidebarWidth.ideal + SuiteSize.contentIdealWidth + Self.inspectorWidth,
            height: SuiteSize.windowLaunch.height)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
