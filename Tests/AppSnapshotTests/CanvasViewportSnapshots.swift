// CanvasViewportSnapshots.swift: CanvasViewport drawing sample artboard
// content, half of it see-through, on the plain artboard and on the
// checkerboard, fitted to the window and at 200%, in Light and Dark. Writes
// suiteui-canvas-content-{light,dark}.png and
// suiteui-canvas-checkerboard-{light,dark}.png (fitted), and
// suiteui-canvas-content-200-{light,dark}.png and
// suiteui-canvas-checkerboard-200-{light,dark}.png. The ruler corner in
// points (CM-9) writes suiteui-canvas-pt-{light,dark}.png, and the viewport's
// goldens canvas/viewport-{px,pt} in the four appearances, which CM-14 commits.
import SuiteUI
import SwiftUI
import Testing

@MainActor
@Test func suiteCanvasViewportRulerUnit() throws {
    let document = CGSize(width: 800, height: 600)
    let window = CGSize(width: 1440 - SuiteSize.ruler, height: 900 - SuiteSize.ruler)
    let fitted = ZoomMath.fit(document: document, in: window)
    for scheme in [ColorScheme.light, .dark] {
        try snapshot(
            CanvasViewportSample(document: document, zoom: fitted, checkerboard: false, unit: "pt"),
            name: "suiteui-canvas-pt-\(scheme.name)", scheme: scheme)
    }
    let size = CGSize(width: 640, height: 400)
    let zoom = ZoomMath.fit(document: document, in: CGSize(width: size.width - SuiteSize.ruler, height: size.height - SuiteSize.ruler))
    for appearance in SnapshotAppearance.allCases {
        for unit in ["px", "pt"] {
            let sample = CanvasViewportSample(document: document, zoom: zoom, checkerboard: false, unit: unit)
            assertGolden(sample, size: size, name: "viewport-\(unit)", area: "canvas", appearance: appearance)
        }
    }
}

@MainActor
@Test func suiteCanvasViewport() throws {
    let document = CGSize(width: 800, height: 600)
    let window = CGSize(width: 1440 - SuiteSize.ruler, height: 900 - SuiteSize.ruler)
    let zooms: [(String, Double)] = [("", ZoomMath.fit(document: document, in: window)), ("-200", 2)]
    for scheme in [ColorScheme.light, .dark] {
        for (suffix, zoom) in zooms {
            for checkerboard in [false, true] {
                let name = "suiteui-canvas-\(checkerboard ? "checkerboard" : "content")\(suffix)-\(scheme.name)"
                try snapshot(CanvasViewportSample(document: document, zoom: zoom, checkerboard: checkerboard), name: name, scheme: scheme)
            }
        }
    }
}

/// A CanvasViewport with sample shapes drawn in document points; no state.
struct CanvasViewportSample: View {
    let document: CGSize
    let zoom: Double
    let checkerboard: Bool
    var unit = "px"

    var body: some View {
        CanvasViewport(documentSize: document, zoom: zoom, checkerboard: checkerboard, unit: unit) {
            Canvas { context, _ in
                context.scaleBy(x: zoom, y: zoom)
                context.fill(Path(CGRect(x: 60, y: 60, width: 420, height: 280)), with: .color(.indigo))
                context.fill(Path(ellipseIn: CGRect(x: 360, y: 180, width: 360, height: 360)), with: .color(.orange.opacity(0.6)))
                context.fill(
                    Path(roundedRect: CGRect(x: 120, y: 400, width: 260, height: 140), cornerRadius: 24),
                    with: .color(.pink.opacity(0.4)))
            }
        } overlay: {
            EmptyView()
        }
    }
}
