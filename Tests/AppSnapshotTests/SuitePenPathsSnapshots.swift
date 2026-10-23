// SuitePenPathsSnapshots.swift (pen-paths PN-4): PathEditOverlay on the
// gallery's `pen-paths` page, in Light and Dark. The empty page (the Pen
// chosen, the sample path), a Pen draft of three corners with the rubber band
// to the pointer, a draft with a smooth fourth anchor and its handles, the
// close ring with the pointer on the first anchor, the sample in Direct
// Selection with a corner and a smooth anchor selected (handles shown), and
// 5,000 anchors with half selected. The drafts and pointers are seeded, so
// the screens don't wait on PenRules (PN-5) or the page's selection (PN-8).
// Writes suiteui-pen-paths{,-drawing,-smooth,-close-hover,-selected,-stress}-{light,dark}.png.
import Foundation
import SuiteKernel
@testable import SuiteUI
import SwiftUI
import Testing

@MainActor
@Suite struct SuitePenPathsSnapshots {
    @Test func penPathsStates() throws {
        let corners = [Point(x: 44, y: 72), Point(x: 132, y: 72), Point(x: 132, y: 180)].map { VectorAnchor(point: $0) }
        let smooth = VectorAnchor(point: Point(x: 66, y: 216), handleIn: Point(x: 44, y: 180), handleOut: Point(x: 88, y: 252), kind: .smooth)
        let three = PenDraft(contour: VectorContour(anchors: corners, closed: false), scale: 1)
        let four = PenDraft(contour: VectorContour(anchors: corners + [smooth], closed: false), scale: 1)
        let picked = Selection([AnchorRef(contour: 0, index: 0), AnchorRef(contour: 0, index: 1)])
        let stars = PenPathsFixture.stars()
        let states: [(String, PenPathsSample)] = [
            ("-drawing", PenPathsSample(draft: three, pointer: CGPoint(x: 198, y: 216))),
            ("-smooth", PenPathsSample(draft: four, pointer: CGPoint(x: 176, y: 300))),
            ("-close-hover", PenPathsSample(draft: four, pointer: CGPoint(x: 44, y: 72))),
            ("-selected", PenPathsSample(selection: picked, tool: .directSelect)),
            ("-stress", PenPathsSample(path: stars, artboard: PenPathsFixture.artboard, selection: PenPathsFixture.half(stars),
                                       tool: .directSelect)),
        ]
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(GalleryPenPathsPage(), name: "suiteui-pen-paths-\(scheme.name)", scheme: scheme)
            for (suffix, sample) in states {
                try snapshot(sample, name: "suiteui-pen-paths\(suffix)-\(scheme.name)", scheme: scheme)
            }
        }
        #expect(PenPathsFixture.stars().path.contours.reduce(0) { $0 + $1.anchors.count } == 5_000)
    }
}

/// The 5,000-anchor stress path: 500 ten-point stars on a 25 x 20 grid, 36 pt cells, inside a 920 x 740 artboard.
enum PenPathsFixture {
    static let artboard = CGSize(width: 920, height: 740)
    static let cell = 36.0, margin = 10.0

    static func stars() -> PathInEdit {
        var contours: [VectorContour] = []
        for row in 0..<20 {
            for column in 0..<25 {
                let cx = margin + cell * (Double(column) + 0.5), cy = margin + cell * (Double(row) + 0.5)
                let anchors = (0..<10).map { k in
                    let angle = Double(k) * .pi / 5, r = cell * (k % 2 == 0 ? 0.4 : 0.18)
                    return VectorAnchor(point: Point(x: cx + r * sin(angle), y: cy - r * cos(angle)))
                }
                contours.append(VectorContour(anchors: anchors, closed: true))
            }
        }
        return PathInEdit(id: "stars", path: VectorPath(contours: contours), toDocument: .identity)
    }

    /// Every other anchor of `path`: half of them.
    static func half(_ path: PathInEdit) -> Selection<AnchorRef> {
        Selection(path.path.contours.indices.flatMap { c in
            path.path.contours[c].anchors.indices.filter { $0 % 2 == 0 }.map { AnchorRef(contour: c, index: $0) }
        })
    }
}

/// The page's layout with the overlay's state seeded: the tool picker, the artboard and the overlay on it.
private struct PenPathsSample: View {
    var path = GalleryPenPaths.sample
    var artboard = SuiteSize.contentMinimum
    var draft: PenDraft?
    var selection = Selection<AnchorRef>()
    var tool = PenTool.pen
    var pointer: CGPoint?

    var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            Picker("Tool", selection: .constant(tool)) {
                ForEach(PenTool.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .fixedSize()
            SuiteColor.artboard
                .frame(width: artboard.width, height: artboard.height)
                .overlay(alignment: .topLeading) {
                    PathEditOverlay(draft: draft, path: path, selection: selection, tool: tool, zoom: 1, pointer: pointer) { _ in }
                }
                .clipShape(.rect(cornerRadius: SuiteRadius.medium))
        }
        .padding(SuiteSpacing.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
