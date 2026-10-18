// GalleryChrome.swift: the gallery's editor-chrome pages (the editor shell,
// its top bar and rail, the empty state and the save status). `editor` hosts a
// TransportCapsule over its own TransportState (48 frames at 24 fps, frame
// 12): the page applies each callback through TransportStepping (the live
// SuiteTransport, or FakeTransportStepping under -SuiteGalleryFakes) and
// writes one line per callback to the `suite.gallery.log` element the
// journeys read (`play on`, `play off`, `frame 13`, `loop on`). EC-9 adds the
// pills, tabs, floating palette and the page switches. `editor-plain` and
// `empty` are still stubs naming the feature that fills them; editor-chrome
// replaces them in this file only. `save-status` draws EditorSaveStatus in its
// three states.
import SwiftUI

enum GalleryChrome {
    @MainActor static let pages: GalleryPages = SuiteGallery.stubs(["editor-plain", "empty"], feature: "editor-chrome")
        .merging([
            "editor": { AnyView(GalleryChromeEditor()) },
            "save-status": { AnyView(GallerySaveStatusPage()) },
        ]) { _, page in page }
}

/// The `editor` page: the transport capsule and the log.
private struct GalleryChromeEditor: View {
    @Environment(\.galleryRequest) private var request
    @State private var transport = TransportState(frame: 12, frameCount: 48, fps: 24)
    @State private var lines: [String] = []

    /// The live transport rule, or the contract's Fake under -SuiteGalleryFakes.
    private var stepping: any TransportStepping {
        request?.fakes == true ? FakeTransportStepping() : SuiteTransport()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.m) {
            TransportCapsule(
                state: transport, stepping: stepping,
                onPlay: {
                    transport.isPlaying.toggle()
                    note(transport.isPlaying ? "play on" : "play off")
                },
                onStep: { apply(stepping.stepped(transport, by: $0)) },
                onStart: { apply(stepping.toStart(transport)) },
                onEnd: { apply(stepping.toEnd(transport)) },
                onLoop: { loops in
                    transport.loops = loops
                    note(loops ? "loop on" : "loop off")
                })
            Spacer(minLength: 0)
            Text(lines.last ?? "Nothing yet")
                .lineLimit(1)
                .font(SuiteFont.caption)
                .foregroundStyle(SuiteColor.secondaryText)
                .accessibilityIdentifier("suite.gallery.log")
                .accessibilityLabel(lines.joined(separator: "\n"))
                .accessibilityValue(lines.joined(separator: "\n"))
        }
        .padding(SuiteSpacing.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func apply(_ next: TransportState) {
        transport = next
        note("frame \(next.frame)")
    }

    /// Appends one log line, keeping the last 40.
    private func note(_ line: String) {
        lines = Array((lines + [line]).suffix(40))
    }
}

private struct GallerySaveStatusPage: View {
    var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            EditorSaveStatus(.saved, title: "Saved", help: "Every change is saved.", identifier: "suite.gallery.save.saved")
            EditorSaveStatus(.edited, title: "Edited", help: "Save to keep your changes.", identifier: "suite.gallery.save.edited")
            EditorSaveStatus(.notSaved, title: "Not saved", help: "The disk is full.", identifier: "suite.gallery.save.failed")
            Spacer()
        }
        .padding(SuiteSpacing.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
