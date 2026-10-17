// SuiteCanvasHostSnapshots.swift: the gallery's `canvas-host` page (CH-3; on
// the tile set's swatch tiles and the live preference since CH-9) in
// suiteui-canvas-host-{light,dark,light-ic,dark-ic}.png. The preference reads a
// scratch defaults domain, so the status line is the same on every runner.
// macOS only.
import Foundation
import SwiftUI
import Testing

@testable import SuiteUI

@MainActor
@Suite struct SuiteCanvasHostSnapshots {
    @Test func canvasHostPage() throws {
        let folder = try packageRoot().appending(path: ".build/snapshots")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let domain = "org.creativesuite.tests.snapshots.\(UUID().uuidString)"
        defer { UserDefaults.standard.removePersistentDomain(forName: domain) }
        let size = CGSize(width: 960, height: 600)
        for appearance in SnapshotAppearance.allCases {
            let page = CanvasHostPage(suiteName: domain)
            let image = try #require(SnapshotHost(appearance: appearance).render(page, size: size))
            let png = try #require(image.representation(using: .png, properties: [:]))
            try png.write(to: folder.appending(path: "suiteui-canvas-host-\(appearance.rawValue).png"))
        }
    }
}
