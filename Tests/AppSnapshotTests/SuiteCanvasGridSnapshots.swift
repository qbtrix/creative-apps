// SuiteCanvasGridSnapshots.swift: CanvasGrid (CM-8, #530), a 9-cell
// straighten grid over a light and a dark image, in Light and Dark, in
// suiteui-canvas-grid-{light,dark}-on-{light,dark}.png. The grid's white
// lines over their black shadow should read on both images. macOS only.
import Foundation
import SwiftUI
import Testing

@testable import SuiteUI

@MainActor
@Suite struct SuiteCanvasGridSnapshots {
    @Test func gridOverLightAndDarkImages() throws {
        let folder = try packageRoot().appending(path: ".build/snapshots")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let size = CGSize(width: 480, height: 320)
        let images: [(name: String, pixels: Color)] = [
            ("light", SuiteColor.overlayPaper), ("dark", SuiteColor.overlayInk),
        ]
        for appearance in [SnapshotAppearance.light, .dark] {
            for image in images {
                // The image covers document pixels 20...220 × 20...140 at zoom 2, the grid's rect.
                let page = ZStack(alignment: .topLeading) {
                    image.pixels.frame(width: 400, height: 240).offset(x: 40, y: 40)
                    CanvasGrid(rect: CGRect(x: 20, y: 20, width: 200, height: 120), cells: 9, zoom: 2)
                }
                .frame(width: size.width, height: size.height, alignment: .topLeading)
                let bitmap = try #require(SnapshotHost(appearance: appearance).render(page, size: size))
                let png = try #require(bitmap.representation(using: .png, properties: [:]))
                let name = "suiteui-canvas-grid-\(appearance.rawValue)-on-\(image.name).png"
                try png.write(to: folder.appending(path: name))
            }
        }
    }
}
