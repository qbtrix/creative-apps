// SuiteSurfaceSnapshots.swift: CanvasSurface with a 1920 x 1080 artboard
// fitted and centered in its surround, and the empty variant (a 0 x 0
// document, drawn as a 1 x 1 pt artboard), in Light and Dark. Writes
// suiteui-surface-{light,dark}.png and suiteui-surface-empty-{light,dark}.png,
// and checks the surface against Golden/canvas/surface-<appearance>.png in
// the four appearances (CM-16 commits the baselines). macOS only.
import SuiteUI
import SwiftUI
import Testing

@MainActor
@Suite struct SuiteSurfaceSnapshots {
    @Test func surface() throws {
        for scheme in [ColorScheme.light, .dark] {
            let suffix = scheme == .dark ? "dark" : "light"
            try snapshot(CanvasSurface(artboard: CGSize(width: 1920, height: 1080)),
                         name: "suiteui-surface-\(suffix)", scheme: scheme)
            try snapshot(CanvasSurface(artboard: .zero), name: "suiteui-surface-empty-\(suffix)", scheme: scheme)
        }
    }

    /// The surface at 640 x 400 pt, as Golden/canvas/surface-<appearance>.png.
    @Test func surfaceGolden() {
        let size = CGSize(width: 640, height: 400)
        for appearance in SnapshotAppearance.allCases {
            assertGolden(CanvasSurface(artboard: CGSize(width: 1920, height: 1080)), size: size,
                         name: "surface", area: "canvas", appearance: appearance)
        }
    }
}
