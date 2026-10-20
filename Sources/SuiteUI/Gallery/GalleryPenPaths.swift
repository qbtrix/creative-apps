// GalleryPenPaths.swift: the gallery's `pen-paths` page (pen-paths PN-2, PN-3).
// An artboard with a sample path on it under PathEditOverlay, a Pen and Direct
// Selection picker, and the `suite.gallery.log` line the journey reads: one
// line per intent the overlay sends, its command id then the intent. The Pen's
// draft goes through the kernel's PenRules; PN-8 runs the rest of the intents.
import SuiteKernel
import SwiftUI

enum GalleryPenPaths {
    static let name = "pen-paths"

    @MainActor static let pages: GalleryPages = [name: { AnyView(GalleryPenPathsPage()) }]

    /// The sample path on the artboard's right half: a closed contour of two
    /// corners and two smooth anchors, in document pixels.
    static let sample = PathInEdit(id: "sample", path: VectorPath(contours: [VectorContour(
        anchors: [
            VectorAnchor(point: Point(x: 260, y: 80)),
            VectorAnchor(point: Point(x: 400, y: 130), handleIn: Point(x: 370, y: 80), handleOut: Point(x: 430, y: 180), kind: .smooth),
            VectorAnchor(point: Point(x: 360, y: 290)),
            VectorAnchor(point: Point(x: 250, y: 220), handleIn: Point(x: 290, y: 280), handleOut: Point(x: 210, y: 160), kind: .smooth),
        ],
        closed: true)]), toDocument: .identity)

    /// The log line for one intent: its command id, then the intent itself.
    static func line(_ intent: PathIntent) -> String { "\(intent.command.id) \(intent)" }

    /// The Pen's draft after `intent`: a point added through PenRules, gone once closed, finished or cancelled.
    static func drafted(_ draft: PenDraft?, _ intent: PathIntent) -> PenDraft? {
        switch intent {
        case let .penAdd(point, handleOut): PenRules.add(point, handleOut: handleOut, to: draft, scale: 1)
        case .close, .finish, .cancel: nil
        default: draft
        }
    }
}

struct GalleryPenPathsPage: View {
    @State private var tool = PenTool.pen
    @State private var draft: PenDraft?
    @State private var log: [String] = []

    var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            Picker("Tool", selection: $tool) {
                ForEach(PenTool.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .fixedSize()
            .accessibilityIdentifier("suite.gallery.pen-tool")
            SuiteColor.artboard
                .frame(width: SuiteSize.contentMinimum.width, height: SuiteSize.contentMinimum.height)
                .overlay(alignment: .topLeading) {
                    PathEditOverlay(draft: draft, path: GalleryPenPaths.sample, selection: Selection(), tool: tool, zoom: 1) {
                        draft = GalleryPenPaths.drafted(draft, $0)
                        log.append(GalleryPenPaths.line($0))
                    }
                }
                .clipShape(.rect(cornerRadius: SuiteRadius.medium))
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Pen canvas")
                .accessibilityValue("One sample path")
                .accessibilityIdentifier("suite.gallery.pen-canvas")
            Text(log.last ?? "Nothing yet").font(SuiteFont.caption).foregroundStyle(SuiteColor.secondaryText).lineLimit(1)
                .accessibilityLabel(log.joined(separator: "\n"))
                .accessibilityValue(log.joined(separator: "\n"))
                .accessibilityIdentifier("suite.gallery.log")
        }
        .padding(SuiteSpacing.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
