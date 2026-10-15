// PhotoStatusLine.swift: the Photo window's status line. The workspace's
// `statusMessage` (a refusal such as "Pick a pixel layer to paint on.") shows
// at the leading edge as an error (a refusal: nothing changed), stateError with
// the exclamation circle, in caption text (a sentence, not a pill), left of the pills: zoom, image size, the window's
// note, the active tool, the render time and, on the fakes (`-PhotoFixture`),
// a "Preview data" warning pill (warning tint, color and triangle) whose
// tooltip and accessibility hint say it is built-in sample data. The window
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

    /// The refusal sentence's type: caption text, not the pill type.
    static let messageFont = SuiteFont.caption
    /// What the "Preview data" pill means, as its tooltip and accessibility hint.
    static let previewHelp = "This window shows built-in sample data, not a file on disk."

    var body: some View {
        HStack(spacing: 0) {
            if let message = model.statusMessage {
                Label(message, systemImage: "exclamationmark.circle")
                    .font(Self.messageFont)
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
                        .help(Self.previewHelp)
                        .accessibilityHint(Self.previewHelp)
                }
            }
        }
        .background(SuiteColor.panel)
    }
}
