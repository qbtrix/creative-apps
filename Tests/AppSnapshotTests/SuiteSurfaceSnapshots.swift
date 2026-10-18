// SuiteSurfaceSnapshots.swift: SuiteUI's CanvasSurface in Light and Dark:
// a 4:3 artboard fitted in its surround with a floating overlay pinned to
// the leading edge ("surface"), and the bare surface ("surface-empty").
// Writes suiteui-surface-{light,dark}.png and
// suiteui-surface-empty-{light,dark}.png, and checks both against
// Golden/canvas/surface-<appearance>.png and surface-empty-<appearance>.png
// in the four appearances (CM-16 commits the baselines). macOS only.
import SwiftUI
import Testing

@testable import SuiteUI

@MainActor
@Suite struct SuiteSurfaceSnapshots {
    static let artboard = CGSize(width: 800, height: 600)
    static let size = CGSize(width: 640, height: 400)

    static var surface: some View {
        CanvasSurface(artboard: artboard) {
            Label("Tools", systemImage: "pencil.tip")
                .padding(SuiteSpacing.s)
                .background(SuiteColor.panel, in: RoundedRectangle(cornerRadius: SuiteRadius.large))
        }
        .frame(width: size.width, height: size.height)
    }

    static var empty: some View {
        CanvasSurface(artboard: artboard).frame(width: size.width, height: size.height)
    }

    @Test func surfaceWithAndWithoutItsOverlay() throws {
        for scheme in [ColorScheme.light, .dark] {
            let suffix = scheme == .dark ? "dark" : "light"
            try snapshot(Self.surface, name: "suiteui-surface-\(suffix)", scheme: scheme)
            try snapshot(Self.empty, name: "suiteui-surface-empty-\(suffix)", scheme: scheme)
        }
    }

    @Test func surfaceGolden() {
        for appearance in SnapshotAppearance.allCases {
            assertGolden(Self.surface, size: Self.size, name: "surface", area: "canvas", appearance: appearance)
            assertGolden(Self.empty, size: Self.size, name: "surface-empty", area: "canvas", appearance: appearance)
        }
    }
}
