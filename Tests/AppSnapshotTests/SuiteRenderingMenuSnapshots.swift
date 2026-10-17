// SuiteRenderingMenuSnapshots.swift: the `settings-rendering` page's
// Rendering menu (canvas-host CH-4) in the four appearances. AppKit can't draw
// an open NSMenu offscreen, so each image shows the page's pull-down with the
// menu's contents laid out under it: the three choices with the current one
// selected, then the status line. Writes suiteui-rendering-menu-<appearance>.png
// (GPU (Metal) checked) and suiteui-rendering-menu-fallback-<appearance>.png
// (Automatic after Metal stopped, the note in the status line) to
// .build/snapshots. macOS only.
import AppKit
import SuiteUI
import SwiftUI
import Testing

@MainActor
@Suite struct SuiteRenderingMenuSnapshots {
    private static let size = CGSize(width: 320, height: 220)

    private static func page(_ model: RenderingMenuModel) -> some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.m) {
            RenderingPullDown(model: model)
            VStack(alignment: .leading, spacing: SuiteSpacing.s) {
                RenderingMenu(model: model)
            }
        }
        .padding(SuiteSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @Test func openMenuInFourAppearances() throws {
        let gpu = RenderingMenuModel(preference: FakeRenderingPreference(choice: .gpu))
        #expect(gpu.items.filter(\.isChecked).map(\.title) == ["GPU (Metal)"])
        let lost = FakeRenderingPreference(choice: .gpu)
        lost.loseDevice()
        let fallback = RenderingMenuModel(preference: lost)
        fallback.pick(.automatic)
        #expect(fallback.statusLine == "Drawing on CPU: Metal stopped")

        let folder = try packageRoot().appending(path: ".build/snapshots")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for (name, model) in [("suiteui-rendering-menu", gpu), ("suiteui-rendering-menu-fallback", fallback)] {
            for appearance in SnapshotAppearance.allCases {
                let image = try #require(SnapshotHost(appearance: appearance).render(Self.page(model), size: Self.size))
                let png = try #require(image.representation(using: .png, properties: [:]))
                try png.write(to: folder.appending(path: "\(name)-\(appearance.rawValue).png"))
            }
        }
    }
}
