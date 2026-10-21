// GalleryPenPaths.swift: the gallery's `pen-paths` page (pen-paths PN-2). An
// empty artboard with the Pen chosen and a sample path on it, drawn by the
// placeholder PathEditOverlay (the path only), and the `suite.gallery.log`
// line the journey reads. PN-3 fills the overlay and logs its intents; PN-8
// runs them through the kernel. The sample is SuiteUI's `PathContourStandIn`
// until PN-1's kernel path types land.
import SwiftUI

enum GalleryPenPaths {
    static let name = "pen-paths"

    @MainActor static let pages: GalleryPages = [name: { AnyView(GalleryPenPathsPage()) }]

    /// The sample path on the artboard's right half: a closed contour of two
    /// corners and two smooth anchors, in document pixels.
    static let sample = PathContourStandIn(
        anchors: [
            PathAnchor(point: CGPoint(x: 260, y: 80), kind: .corner),
            PathAnchor(point: CGPoint(x: 400, y: 130), kind: .smooth,
                       handleIn: CGPoint(x: 370, y: 80), handleOut: CGPoint(x: 430, y: 180)),
            PathAnchor(point: CGPoint(x: 360, y: 290), kind: .corner),
            PathAnchor(point: CGPoint(x: 250, y: 220), kind: .smooth,
                       handleIn: CGPoint(x: 290, y: 280), handleOut: CGPoint(x: 210, y: 160)),
        ],
        closed: true)
}

struct GalleryPenPathsPage: View {
    private let tool = PenTool.pen

    var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            Text(tool.title).font(SuiteFont.sectionCaps).foregroundStyle(SuiteColor.secondaryText).accessibilityAddTraits(.isHeader)
            SuiteColor.artboard
                .frame(width: SuiteSize.contentMinimum.width, height: SuiteSize.contentMinimum.height)
                .overlay(alignment: .topLeading) {
                    PathEditOverlay(draft: nil, path: [GalleryPenPaths.sample], tool: tool, zoom: 1)
                }
                .clipShape(.rect(cornerRadius: SuiteRadius.medium))
                .accessibilityElement()
                .accessibilityLabel("Pen canvas")
                .accessibilityValue("One sample path")
                .accessibilityIdentifier("suite.gallery.pen-canvas")
            Text("Nothing yet").font(SuiteFont.caption).foregroundStyle(SuiteColor.secondaryText).lineLimit(1)
                .accessibilityIdentifier("suite.gallery.log")
        }
        .padding(SuiteSpacing.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
