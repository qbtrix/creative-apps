// HaloRenderedFrameView.swift: the frame Render Frame made (render-out RO-5,
// #451), shown over the artboard while the Model's `shownRenderedFrame` holds
// one: none, a frame from another composition, or playback running leaves
// the vector drawing as before. The image (HaloFrameImage) fills the
// artboard's fitted frame, laid out as HaloViewerCanvas lays out the drawn
// layers, so its pixels sit on theirs; it is `halo.viewer.rendered` with
// `renderedFrameSummary` ("Rendered frame 12 at 480 × 270") as its value.
// `renderedFrameNote` ("Rendered frame is out of date." when stale, else the
// frame's undrawn-text note) is captioned just under the artboard as
// `halo.viewer.renderedNote`, with the warning triangle. The image and its
// note are one Equatable view, so a body pass that changes neither skips
// making the image again. Reads its model and never acts.
import HaloModel
import SuiteUI
import SwiftUI

struct HaloRenderedFrameView: View {
    let model: HaloProject
    var perform: @MainActor (HaloCommand) -> Void = { _ in }

    var body: some View {
        if let frame = model.shownRenderedFrame, let comp = model.selectedComposition {
            HaloRenderedImage(
                frame: frame,
                artboard: CGSize(width: max(comp.width, 1), height: max(comp.height, 1)),
                summary: model.renderedFrameSummary ?? "",
                note: model.renderedFrameNote)
                .equatable()
        }
    }
}

/// The rendered frame over the artboard's fitted frame, and its note under it.
struct HaloRenderedImage: View, Equatable {
    let frame: HaloRenderedFrame
    let artboard: CGSize
    let summary: String
    let note: String?

    nonisolated static func == (a: Self, b: Self) -> Bool {
        a.frame == b.frame && a.artboard == b.artboard && a.summary == b.summary && a.note == b.note
    }

    var body: some View {
        if let image = HaloFrameImage.cgImage(frame) {
            Image(image, scale: 1, label: Text("Rendered frame"))
                .resizable()
                .accessibilityValue(summary)
                .accessibilityIdentifier("halo.viewer.rendered")
                .aspectRatio(artboard, contentMode: .fit)
                // Under the artboard, in the canvas inset: a zero-height
                // frame on the image's bottom edge that the note hangs from,
                // a small gap below it, without moving the image.
                .overlay(alignment: .bottom) {
                    if let note {
                        HaloRenderedNote(text: note)
                            .padding(.top, SuiteSpacing.xs)
                            .frame(height: 0, alignment: .top)
                    }
                }
                .frame(maxWidth: artboard.width, maxHeight: artboard.height)
                .padding(SuiteSize.canvasInset)
                .allowsHitTesting(false)
        }
    }
}

/// The rendered frame's note: a warning triangle and the text, one element.
private struct HaloRenderedNote: View {
    let text: String

    var body: some View {
        Label {
            Text(text).foregroundStyle(SuiteColor.textSecondary)
        } icon: {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(SuiteColor.stateWarning)
        }
        .font(SuiteFont.caption)
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
        .accessibilityIdentifier("halo.viewer.renderedNote")
    }
}
