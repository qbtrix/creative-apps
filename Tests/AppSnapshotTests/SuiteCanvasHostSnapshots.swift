// SuiteCanvasHostSnapshots.swift: the gallery's `canvas-host` page (CH-3) in
// suiteui-canvas-host-{light,dark,light-ic,dark-ic}.png. macOS only.
import SwiftUI
import Testing

@testable import SuiteUI

@MainActor
@Suite struct SuiteCanvasHostSnapshots {
    @Test func canvasHostPage() throws {
        let folder = try packageRoot().appending(path: ".build/snapshots")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let size = CGSize(width: 960, height: 600)
        for appearance in SnapshotAppearance.allCases {
            let image = try #require(SnapshotHost(appearance: appearance).render(CanvasHostPage(), size: size))
            let png = try #require(image.representation(using: .png, properties: [:]))
            try png.write(to: folder.appending(path: "suiteui-canvas-host-\(appearance.rawValue).png"))
        }
    }
}
