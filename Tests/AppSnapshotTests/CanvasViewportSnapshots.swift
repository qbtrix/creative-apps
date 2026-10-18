// CanvasViewportSnapshots.swift: CanvasViewport drawing sample artboard
// content, half of it see-through, on the plain artboard and on the
// checkerboard, fitted to the window and at 200%, in Light and Dark. Writes
// suiteui-canvas-content-{light,dark}.png and
// suiteui-canvas-checkerboard-{light,dark}.png (fitted), and
// suiteui-canvas-content-200-{light,dark}.png and
// suiteui-canvas-checkerboard-200-{light,dark}.png, plus the plain artboard
// with its ruler corner in points, suiteui-canvas-pt-{light,dark}.png (#264).
// The px and pt viewports side by side are checked against
// Golden/canvas/canvas-rulers-<appearance>.png in the four appearances
// (CM-14 commits the baselines).
import SuiteUI
import SwiftUI
import Testing

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
        let points = CanvasViewportSample(document: document, zoom: zooms[0].1, checkerboard: false, rulerUnit: "pt")
        try snapshot(points, name: "suiteui-canvas-pt-\(scheme.name)", scheme: scheme)
    }
}

/// The px and pt corners side by side, at a size where the rulers' labels read.
@MainActor
@Test func suiteCanvasRulersGolden() {
    let document = CGSize(width: 400, height: 300)
    let pair = HStack(spacing: 0) {
        ForEach(["px", "pt"], id: \.self) { unit in
            CanvasViewportSample(document: document, zoom: 0.5, checkerboard: false, rulerUnit: unit)
        }
    }
    for appearance in SnapshotAppearance.allCases {
        assertGolden(pair, size: CGSize(width: 640, height: 240), name: "canvas-rulers", area: "canvas", appearance: appearance)
    }
}

/// A CanvasViewport with sample shapes drawn in document points; no state.
struct CanvasViewportSample: View {
    let document: CGSize
    let zoom: Double
    let checkerboard: Bool
    /// The unit the ruler corner names.
    var rulerUnit = "px"

    var body: some View {
        CanvasViewport(documentSize: document, zoom: zoom, checkerboard: checkerboard, rulerUnit: rulerUnit) {
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
