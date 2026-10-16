// CanvasRulerUnitTests.swift: the unit CanvasViewport's ruler corner names.
// Pixels by default (Photo's documents are pixels); an app whose document is
// in points (Design) passes "pt", so the rulers agree with its status bar and
// inspector. No SwiftUI rendering. macOS only.
import SwiftUI
import Testing

@testable import SuiteUI

@MainActor
@Test func canvasRulerUnitIsPixelsUnlessTheAppNamesOne() {
    let size = CGSize(width: 100, height: 100)
    let pixels = CanvasViewport(documentSize: size, zoom: 1) { Color.clear } overlay: { EmptyView() }
    let points = CanvasViewport(documentSize: size, zoom: 1, unit: "pt") { Color.clear } overlay: { EmptyView() }
    #expect(pixels.unit == "px")
    #expect(points.unit == "pt")
}
