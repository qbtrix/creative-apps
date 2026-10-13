// PhotoCurvesSnapshots.swift: Photo's adjustments inspector with an S curve
// in Curves (three points between the ends) over the histogram of a sample
// photo-like image (a sky gradient and a sun), counted by
// PhotoWorkspace.curvesHistogram, at the inspector's ideal width, in Light and
// Dark. Writes photo-curves-light.png and photo-curves-dark.png. macOS only.
import CoreRaster
import PhotoModel
import SuiteUI
import SwiftUI
import Testing

@testable import PhotoApp

@MainActor
@Suite struct PhotoCurvesSnapshots {
    @Test func sCurveOverTheHistogram() throws {
        let (w, h) = (320, 240)
        var bytes = [UInt8](repeating: 255, count: w * h * 4)
        for y in 0..<h {
            for x in 0..<w {
                let i = (y * w + x) * 4, (dx, dy) = (x - 210, y - 100)
                let sun = dx * dx + dy * dy < 45 * 45
                bytes[i] = sun ? 250 : UInt8(40 + x * 180 / w)
                bytes[i + 1] = sun ? 190 : UInt8(80 + y * 120 / h)
                bytes[i + 2] = sun ? 60 : 200
            }
        }
        var model = PhotoWorkspace()
        try model.open(rgba8: bytes, width: w, height: h, name: "beach.png")
        model.adjust(.curvePoints([(0, 0), (0.25, 0.15), (0.5, 0.5), (0.75, 0.85), (1, 1)].map { CurvePoint(x: $0.0, y: $0.1) }))
        #expect(model.adjustments.curvePoints.count == 5)
        let histogram = model.curvesHistogram()
        #expect(histogram.max() == 1)
        for scheme in [ColorScheme.light, .dark] {
            let view = AdjustmentsInspector(settings: model.adjustments, histogram: histogram)
                .padding(SuiteSpacing.m)
                .frame(width: SuiteSize.inspectorWidth.ideal, alignment: .topLeading)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(SuiteSpacing.xxl)
            try snapshot(view, name: "photo-curves-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }
}
