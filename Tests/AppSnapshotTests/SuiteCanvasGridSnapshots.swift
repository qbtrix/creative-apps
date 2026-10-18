// SuiteCanvasGridSnapshots.swift: CanvasGrid (CM-8, #530) over a light image
// and a dark image side by side, 3 cells each way, in
// suiteui-canvas-grid-{light,dark,light-ic,dark-ic}.png, and checked against
// Golden/canvas/ through SnapshotHost (QB-V5; CM-15 commits the baselines).
// The lines must read on both halves in every appearance. macOS only.
import Foundation
import SwiftUI
import Testing

@testable import SuiteUI

@MainActor
@Suite struct SuiteCanvasGridSnapshots {
    static let side: CGFloat = 240
    static let size = CGSize(width: side * 2, height: side)

    /// A white and a black document, each with its own 3 × 3 grid.
    struct Page: View {
        var body: some View {
            let side = SuiteCanvasGridSnapshots.side
            let light = CGRect(x: 0, y: 0, width: side, height: side)
            let dark = CGRect(x: side, y: 0, width: side, height: side)
            ZStack(alignment: .topLeading) {
                HStack(spacing: 0) {
                    SuiteColor.overlayPaper
                    SuiteColor.overlayInk
                }
                CanvasGrid(rect: light, cells: 3, zoom: 1)
                CanvasGrid(rect: dark, cells: 3, zoom: 1)
            }
        }
    }

    @Test func gridOverLightAndDarkImages() throws {
        let folder = try packageRoot().appending(path: ".build/snapshots")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for appearance in SnapshotAppearance.allCases {
            let image = try #require(SnapshotHost(appearance: appearance).render(Page(), size: Self.size))
            let png = try #require(image.representation(using: .png, properties: [:]))
            try png.write(to: folder.appending(path: "suiteui-canvas-grid-\(appearance.rawValue).png"))
            assertGolden(Page(), size: Self.size, name: "suiteui-canvas-grid", area: "canvas", appearance: appearance)
        }
    }
}
