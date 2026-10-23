// SuiteGalleryTransformSnapshots.swift: the gallery's `transform-handles` page
// (transform-tools TT-z, #4625) with its box turned 30°, in Light and Dark
// (suiteui-gallery-transform-turned-light, -dark). The turned box draws one
// outline, the editor's, and its probe covers the turned box's bounds. macOS only.
import Foundation
import SuiteKernel
import SwiftUI
import Testing

@testable import SuiteUI

@MainActor
@Suite struct SuiteGalleryTransformSnapshots {
    private static let size = CGSize(width: 820, height: 440)
    private static let box = Rect(minX: 100, minY: 80, maxX: 300, maxY: 200)
    private static let paperSize = CGSize(width: 400, height: 300)

    /// The board turned `degrees` through the catalog, as a knob or the rows would.
    private static func board(turned degrees: Double) -> GalleryTransformBoard {
        var board = GalleryTransformBoard()
        _ = board.send(.rotate(by: degrees, drag: nil))
        return board
    }

    /// The box's marks alone on paper, 400 × 300 with no viewport, so a document point is a view point.
    private static func marks(_ item: TransformBox) -> some View {
        ZStack(alignment: .topLeading) {
            SuiteColor.overlayPaper
            GalleryTransformMarks(item: item, onResize: { _ in }, onRotate: { _ in }, onEnd: {})
        }
        .frame(width: paperSize.width, height: paperSize.height, alignment: .topLeading)
    }

    @Test func turned() throws {
        let board = Self.board(turned: 30)
        #expect(board.item.degrees == 30)
        let folder = try packageRoot().appending(path: ".build/snapshots")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for appearance in [SnapshotAppearance.light, .dark] {
            let host = SnapshotHost(appearance: appearance)
            let bitmap = try #require(host.render(GalleryTransformPage(board: board), size: Self.size))
            let png = try #require(bitmap.representation(using: .png, properties: [:]))
            try png.write(to: folder.appending(path: "suiteui-gallery-transform-turned-\(appearance.rawValue).png"))
        }
    }

    /// Unturned, the probe is the box; turned 30°, it is the bounds of the turned corners about the same centre.
    @Test func theProbeCoversTheTurnedBox() {
        let flat = GalleryTransformMarks.probeRect(TransformBox(box: Self.box))
        #expect(flat == CGRect(x: 100, y: 80, width: 200, height: 120))
        let probe = GalleryTransformMarks.probeRect(TransformBox(box: Self.box, degrees: 30))
        let (c, s) = (cos(Double.pi / 6), sin(Double.pi / 6))
        let (w, h) = (200 * c + 120 * s, 200 * s + 120 * c)
        #expect(abs(probe.width - w) < 0.001 && abs(probe.height - h) < 0.001)
        #expect(abs(probe.midX - 200) < 0.001 && abs(probe.midY - 140) < 0.001)
    }

    /// The unturned top edge crosses (150, 80), device pixel (300, 160) at scale 2; turned 30° about the
    /// centre, no outline, handle or knob is left there, so the paper shows: one outline, not two.
    @Test func theTurnedBoxDrawsOneOutline() throws {
        let host = SnapshotHost(appearance: .light)
        let flat = try #require(host.image(Self.marks(TransformBox(box: Self.box)), size: Self.paperSize))
        let turned = try #require(host.image(Self.marks(TransformBox(box: Self.box, degrees: 30)), size: Self.paperSize))
        let paper = SnapshotHostTests.pixel(flat, 8, 8)
        #expect(SnapshotHostTests.differs(SnapshotHostTests.pixel(flat, 300, 160), paper))
        #expect(!SnapshotHostTests.differs(SnapshotHostTests.pixel(turned, 300, 160), paper, limit: 8))
        #expect(!SnapshotHostTests.differs(SnapshotHostTests.pixel(turned, 300, 159), paper, limit: 8))
    }
}
