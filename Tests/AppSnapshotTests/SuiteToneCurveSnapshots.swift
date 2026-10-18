// SuiteToneCurveSnapshots.swift: SuiteUI's ToneCurveEditor at the inspector's
// content width: an S curve (three points between the ends) over a histogram,
// the same with its middle point focused (`focusedPoint`; the offscreen window
// never holds focus), and the identity with no histogram. The curve is
// CoreRaster's `curves` run over a ramp, so it is the engine's. Increase
// Contrast is partial: NSAppearance(named:) gives plain Aqua or Dark Aqua for
// the high-contrast names unless the system setting is on, so the tokens'
// IC columns can't render in-process (the four-appearance host is #332). The
// -contrast files set the environment's contrast (the underscored setter),
// which shows the component's own IC change, the well outline. Writes
// suite-tone-curve-light, -dark, -light-contrast and -dark-contrast .png,
// and checks the gallery against Golden/inspector/tone-curve-<appearance>.png
// in SnapshotHost's four appearances (a missing baseline is a known issue).
import CoreRaster
import SuiteUI
import SwiftUI
import Testing

@MainActor
@Suite struct SuiteToneCurveSnapshots {
    @Test func toneCurve() throws {
        let points = [(0, 0), (0.25, 0.15), (0.5, 0.5), (0.75, 0.85), (1, 1)].map { CGPoint(x: $0.0, y: $0.1) }
        let histogram = (0..<64).map { i -> Double in
            let x = (Double(i) + 0.5) / 64
            return exp(-pow((x - 0.32) / 0.13, 2)) + 0.55 * exp(-pow((x - 0.74) / 0.09, 2)) + 0.05
        }
        let gallery = ToneCurveGallery(points: points, samples: try engineSamples(points), histogram: histogram)
        for scheme in [ColorScheme.light, .dark] {
            let look = scheme == .dark ? "dark" : "light"
            try snapshot(gallery, name: "suite-tone-curve-\(look)", scheme: scheme)
            try snapshot(
                gallery.environment(\._colorSchemeContrast, .increased), name: "suite-tone-curve-\(look)-contrast",
                scheme: scheme)
        }
        // Three 240 pt inspector columns, 32 pt apart and around.
        for appearance in SnapshotAppearance.allCases {
            assertGolden(
                gallery, size: CGSize(width: 848, height: 300), name: "tone-curve", area: "inspector",
                appearance: appearance)
        }
    }

    /// The curve through `points` as CoreRaster applies it: 129 samples of
    /// `curves` over a 0...1 ramp in the red channel.
    private func engineSamples(_ points: [CGPoint]) throws -> [CGPoint] {
        var ramp = try PixelBuffer(width: 129, height: 1)
        for x in 0...128 { try ramp.setPixel(x: x, y: 0, RGBA(r: Float(x) / 128, g: 0, b: 0, a: 1)) }
        let curved = try ramp.curves(points: points.map { CurvePoint(x: Float($0.x), y: Float($0.y)) })
        return try (0...128).map { CGPoint(x: Double($0) / 128, y: Double(try curved.pixel(x: $0, y: 0).r)) }
    }
}

private struct ToneCurveGallery: View {
    let points: [CGPoint]
    let samples: [CGPoint]
    let histogram: [Double]

    var body: some View {
        let identity = [CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 1)]
        HStack(alignment: .top, spacing: SuiteSpacing.xxl) {
            column(points, samples, histogram, focus: nil)
            column(points, samples, histogram, focus: 2)
            column(identity, identity, [], focus: 0)
        }
        .padding(SuiteSpacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func column(_ points: [CGPoint], _ samples: [CGPoint], _ histogram: [Double], focus: Int?) -> some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.xs) {
            Text("Curves")
                .font(SuiteFont.sectionCaps)
                .textCase(.uppercase)
                .tracking(SuiteSize.capsTracking)
                .foregroundStyle(SuiteColor.secondaryText)
            ToneCurveEditor(
                points: points, samples: samples, histogram: histogram, focusedPoint: focus, onChange: { _ in },
                onEnd: {})
        }
        .frame(width: SuiteSize.inspectorWidth.ideal - 2 * SuiteSpacing.m)
        .padding(SuiteSpacing.m)
        .background(SuiteColor.panel)
    }
}
