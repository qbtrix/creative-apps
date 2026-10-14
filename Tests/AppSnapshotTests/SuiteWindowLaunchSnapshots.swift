// SuiteWindowLaunchSnapshots.swift: a SuiteWindow at its launch size
// (SuiteSize.windowLaunch), sidebar, content and inspector all shown, so the shot
// shows both side columns whole at launch, the content column between them no
// wider than the window minus both (#579). The window sits at the top leading
// corner of the 1440x900 frame. Writes suiteui-window-launch-light.png and
// suiteui-window-launch-dark.png.
import SuiteUI
import SwiftUI
import Testing

@MainActor
@Test func suiteWindowLaunch() throws {
    for scheme in [ColorScheme.light, .dark] {
        try snapshot(
            WindowLaunchSample(), name: "suiteui-window-launch-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
    }
}

/// A SuiteWindow with sample rows, a content view that asks for more than the
/// content column's ideal width, and an inspector section; no state.
private struct WindowLaunchSample: View {
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
            Text("Canvas").font(SuiteFont.headline)
                .frame(idealWidth: SuiteSize.windowLaunch.width, maxWidth: .infinity, maxHeight: .infinity)
        } inspector: {
            InspectorSection("Background") {
                InspectorSliderRow("Opacity", value: 100, in: 0...100, unit: "%", decimals: 0) { _ in }
            }
        }
        .frame(width: SuiteSize.windowLaunch.width, height: SuiteSize.windowLaunch.height)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
