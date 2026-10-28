// PhotoStatusLine.swift: the Photo window's status line. The workspace's
// `statusMessage` (a refusal such as "Pick a pixel layer to paint on.") shows
// at the leading edge as an error (a refusal: nothing changed), stateError with
// the exclamation circle, in caption text (a sentence, not a pill), left of the pills: zoom, image size, the window's
// note, the active tool, the render time (with the backend that drew it,
// "CPU" or "GPU (Metal)", once a window renders through View > Rendering) and, on the fakes (`-PhotoFixture`),
// a "Preview data" warning pill (warning tint, color and triangle) whose
// tooltip and accessibility hint say it is built-in sample data. The window
// clears the message 4 s after it appears (PhotoWindow's `clearStatus` task);
// with no message only the pills show. In a window it reads the PhotoSession's
// `status` facet; without one (the snapshots) the workspace it was given.
import PhotoModel
import SuiteUI
import SwiftUI

struct PhotoStatusLine: View {
    private let given: PhotoWorkspace
    let zoom: Double
    var note: String?
    var renderMilliseconds: Double?
    /// The backend that drew the picture: CoreRender's CPU backend ("cpu") or the GPU's name; nil leaves it out.
    var renderBackend: String?
    @Environment(PhotoSession.self) private var session: PhotoSession?

    init(model: PhotoWorkspace, zoom: Double, note: String? = nil, renderMilliseconds: Double? = nil,
         renderBackend: String? = nil) {
        (given, self.zoom, self.note, self.renderMilliseconds, self.renderBackend) =
            (model, zoom, note, renderMilliseconds, renderBackend)
    }

    /// The window's workspace now, read through the `status` facet; the given one outside a window.
    private var model: PhotoWorkspace { session?.workspace(reading: .status) ?? given }

    /// The refusal sentence's type: caption text, not the pill type.
    static let messageFont = SuiteFont.caption
    /// What the "Preview data" pill means, as its tooltip and accessibility hint.
    static let previewHelp = "This window shows built-in sample data, not a file on disk."

    /// "12 ms render", or with a backend "GPU (Metal) · 12 ms render" (the View > Rendering menu's titles).
    nonisolated static func renderText(_ milliseconds: Double, backend: String?) -> String {
        let time = "\(Int(milliseconds.rounded())) ms render"
        guard let backend else { return time }
        // CoreRenderMetal names its backend "Metal (<device>)"; anything else is the CPU.
        let choice: RenderingChoice = backend.hasPrefix("Metal") ? .gpu : .cpu
        return "\(RenderingMenuItem.title(choice)) · \(time)"
    }

    var body: some View {
        let model = self.model
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
                if let renderMilliseconds {
                    Text(Self.renderText(renderMilliseconds, backend: renderBackend))
                        .accessibilityIdentifier("photo.status.render")
                }
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
