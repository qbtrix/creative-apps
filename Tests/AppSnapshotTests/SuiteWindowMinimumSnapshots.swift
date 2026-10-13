// SuiteWindowMinimumSnapshots.swift: a SuiteWindow at the window minimum
// (900 x 560 pt), its sidebar, content and inspector all shown, so the shot
// shows the split view fitting the window with nothing clipped (#215). The
// window sits at the top leading corner of the 1440x900 frame. Writes
// suiteui-window-minimum-light.png and suiteui-window-minimum-dark.png.
import SuiteUI
import SwiftUI
import Testing

@MainActor
@Test func suiteWindowMinimum() throws {
    for scheme in [ColorScheme.light, .dark] {
        try snapshot(
            WindowMinimumSample(), name: "suiteui-window-minimum-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
    }
}

/// A SuiteWindow with sample rows and an inspector section; no state.
private struct WindowMinimumSample: View {
    var body: some View {
        SuiteWindow(
            title: "Untitled", sidebarTitle: "Layers",
            items: [
                SidebarItem(id: "title", title: "Title Text", systemImage: "textformat"),
                SidebarItem(id: "background", title: "Background", systemImage: "rectangle"),
            ],
            selection: "title", onSelect: { _ in },
            actions: [ToolbarAction("New Image", systemImage: "doc.badge.plus")]
        ) {
            Text("Canvas").font(SuiteFont.headline).frame(maxWidth: .infinity, maxHeight: .infinity)
        } inspector: {
            InspectorSection("Background") {
                InspectorSliderRow("Opacity", value: 100, in: 0...100, unit: "%", decimals: 0) { _ in }
            }
        }
        .frame(width: SuiteSize.windowMinimum.width, height: SuiteSize.windowMinimum.height)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
