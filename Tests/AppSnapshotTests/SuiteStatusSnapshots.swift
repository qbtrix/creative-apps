// SuiteStatusSnapshots.swift: ViewerStatusBar's pills under a viewer: zoom and
// size alone; with plain trailing pills and a View menu; with a toggle pill
// on and off and a warning pill; and with no document (the "–" zoom), on the
// editor panel, in Light and Dark. Writes suiteui-status-light.png and
// suiteui-status-dark.png.
import SuiteUI
import SwiftUI
import Testing

@MainActor
@Suite struct SuiteStatusSnapshots {
    @Test func statusPills() throws {
        try snapshot(StatusSheet(), name: "suiteui-status-light", scheme: .light)
        try snapshot(StatusSheet(), name: "suiteui-status-dark", scheme: .dark)
    }
}

private struct StatusSheet: View {
    var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.l) {
            ViewerStatusBar(zoom: 0.51, size: "1920 × 1080 px")
            ViewerStatusBar(zoom: 1, size: "800 × 600 px") {
                Text("Brush")
                Text("12 ms render")
                Menu("View") { Button("Fit") {} }.menuStyle(.button).buttonStyle(.plain)
            }
            ViewerStatusBar(zoom: 2, size: "1080 × 1080 px") {
                Text("Onion").statusPill(.toggle(isOn: true))
                Text("Loop").statusPill(.toggle(isOn: false))
                Text("Preview data").statusPill(.warning)
            }
            ViewerStatusBar(zoom: 0, size: "No file open")
        }
        .frame(width: 720)
        .padding(SuiteSpacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(SuiteColor.canvasSurround)
    }
}
