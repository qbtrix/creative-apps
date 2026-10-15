// PhotoStatusLine.swift: the Photo window's status line. The workspace's
// `statusMessage` (a refusal such as "Pick a pixel layer to paint on.") shows
// at the leading edge with a warning triangle in the warning color, left of
// the pills: zoom, image size, the window's note, the active tool, the
// render time and, on the fakes (`-PhotoFixture`), "Preview data". The window
// clears the message 4 s after it appears (PhotoWindow's `clearStatus` task);
// with no message only the pills show.
import PhotoModel
import SuiteUI
import SwiftUI

struct PhotoStatusLine: View {
    let model: PhotoWorkspace
    let zoom: Double
    var note: String?
    var renderMilliseconds: Double?

    var body: some View {
        HStack(spacing: 0) {
            if let message = model.statusMessage {
                Label(message, systemImage: "exclamationmark.triangle")
                    .font(SuiteFont.pill)
                    .foregroundStyle(SuiteColor.stateWarning)
                    .lineLimit(1)
                    .padding(.leading, SuiteSpacing.s)
                    .accessibilityIdentifier("photo.status.message")
            }
            ViewerStatusBar(zoom: model.canvas == nil ? 0 : zoom, size: model.viewerSizeText) {
                if let note { Text(note) }
                if model.canvas != nil { Text(model.tool.title) }
                if let renderMilliseconds { Text("\(Int(renderMilliseconds.rounded())) ms render") }
                if model.isPreviewData { Text("Preview data").accessibilityIdentifier("photo.status.preview") }
            }
        }
        .background(SuiteColor.panel)
    }
}
