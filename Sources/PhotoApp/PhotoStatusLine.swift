// PhotoStatusLine.swift: the Photo window's status line. The workspace's
// `statusMessage` (a refusal such as "Pick a pixel layer to paint on.") shows
// at the leading edge as an error (a refusal: nothing changed), stateError with
// the exclamation circle, left of the pills: zoom, image size, the window's
// note, the active tool, the render time and, on the fakes (`-PhotoFixture`),
// a "Preview data" warning pill (warning tint, color and triangle). The window
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
                Label(message, systemImage: "exclamationmark.circle")
                    .font(SuiteFont.pill)
                    .foregroundStyle(SuiteColor.stateError)
                    .lineLimit(1)
                    .padding(.leading, SuiteSpacing.s)
                    .accessibilityIdentifier("photo.status.message")
            }
            ViewerStatusBar(zoom: model.canvas == nil ? 0 : zoom, size: model.viewerSizeText) {
                if let note { Text(note) }
                if model.canvas != nil { Text(model.tool.title) }
                if let renderMilliseconds { Text("\(Int(renderMilliseconds.rounded())) ms render") }
                if model.isPreviewData {
                    Text("Preview data").accessibilityIdentifier("photo.status.preview").statusPill(.warning)
                }
            }
        }
        .background(SuiteColor.panel)
    }
}
