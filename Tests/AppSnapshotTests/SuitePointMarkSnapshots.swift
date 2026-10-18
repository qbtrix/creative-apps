// SuitePointMarkSnapshots.swift: SuiteUI's CanvasPointMark (a clone source's
// ring and cross) over light and over dark pixels, at zoom 1 and 4, on one
// sheet, in Light and Dark. The ring is the same size in every cell; only the
// document point under it moves. Writes suiteui-point-mark-light.png and
// suiteui-point-mark-dark.png.
import SwiftUI
import Testing

@testable import SuiteUI

@MainActor
@Suite struct SuitePointMarkSnapshots {
    @Test func pointMarkOverLightAndDarkAtZoomOneAndFour() throws {
        try snapshot(PointMarkSheet(), name: "suiteui-point-mark-light", scheme: .light)
        try snapshot(PointMarkSheet(), name: "suiteui-point-mark-dark", scheme: .dark)
    }
}

private struct PointMarkSheet: View {
    /// One 200 x 200 pt cell; the mark sits at its centre at either zoom.
    private static let cell: CGFloat = 200

    var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.xxl) {
            ForEach([false, true], id: \.self) { dark in
                HStack(spacing: SuiteSpacing.xxl) {
                    ForEach([1.0, 4.0], id: \.self) { zoom in
                        cell(dark: dark, zoom: zoom)
                    }
                }
            }
        }
        .padding(SuiteSpacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// A light or dark gradient, the mark at the centre at `zoom`.
    private func cell(dark: Bool, zoom: Double) -> some View {
        let tones: [Color] = dark ? [SuiteColor.overlayInk, .indigo] : [SuiteColor.overlayPaper, .yellow]
        let center = Self.cell / 2 / zoom
        return ZStack {
            LinearGradient(colors: tones, startPoint: .topLeading, endPoint: .bottomTrailing)
            CanvasPointMark(point: CGPoint(x: center, y: center), zoom: zoom)
        }
        .frame(width: Self.cell, height: Self.cell)
    }
}
