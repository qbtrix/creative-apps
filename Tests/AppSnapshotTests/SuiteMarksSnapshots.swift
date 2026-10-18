// SuiteMarksSnapshots.swift: SelectionHandlesEditor (canvas-marks CM-4) at
// 25, 100 and 400 %, in Light and Dark, in
// suiteui-marks-handles-{25,100,400}-{light,dark}.png, plus the hairline
// check: at scale 2 the box's 1 pt outline is exactly two device pixels per
// edge and each handle's edge is crisp on the pixel grid. macOS only.
import Foundation
import SwiftUI
import Testing

@testable import SuiteUI

@MainActor
@Suite struct SuiteMarksSnapshots {
    /// The box in view points at every zoom: its document rect is this over the zoom.
    private static let view = CGRect(x: 40, y: 60, width: 240, height: 160)

    private static func page(zoom: Double) -> some View {
        let rect = CGRect(x: view.minX / zoom, y: view.minY / zoom, width: view.width / zoom, height: view.height / zoom)
        return ZStack(alignment: .topLeading) {
            SuiteColor.overlayPaper
            SelectionHandlesEditor(rect: rect, zoom: zoom, onResize: { _ in }, onRotate: { _ in }, onEnd: {})
        }
        .frame(width: 360, height: 280, alignment: .topLeading)
    }

    @Test(arguments: [0.25, 1.0, 4.0])
    func handlesAtEachZoom(zoom: Double) throws {
        let folder = try packageRoot().appending(path: ".build/snapshots")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let size = CGSize(width: 360, height: 280)
        for appearance in [SnapshotAppearance.light, .dark] {
            let host = SnapshotHost(appearance: appearance)
            let bitmap = try #require(host.render(Self.page(zoom: zoom), size: size))
            let png = try #require(bitmap.representation(using: .png, properties: [:]))
            try png.write(to: folder.appending(path: "suiteui-marks-handles-\(Int(zoom * 100))-\(appearance.rawValue).png"))

            let image = try #require(host.image(Self.page(zoom: zoom), size: size))
            let paper = SnapshotHostTests.pixel(image, 2, 2)
            // Row 85 pt (device 170) crosses only the left and right edges, at 40 and 280 pt.
            let marked = (0..<image.width).filter { SnapshotHostTests.differs(SnapshotHostTests.pixel(image, $0, 170), paper) }
            #expect(marked == [79, 80, 559, 560], "\(zoom) \(appearance.rawValue)")
            // The top-left handle spans 36...44 pt; its left edge's stroke is device 71 and 72, full colour.
            let edge = (SnapshotHostTests.pixel(image, 70, 116), SnapshotHostTests.pixel(image, 71, 116),
                        SnapshotHostTests.pixel(image, 72, 116))
            #expect(!SnapshotHostTests.differs(edge.0, paper), "\(zoom) \(appearance.rawValue)")
            #expect(SnapshotHostTests.differs(edge.1, paper) && !SnapshotHostTests.differs(edge.1, edge.2),
                    "\(zoom) \(appearance.rawValue)")
        }
    }
}
