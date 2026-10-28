// RenderBudgetPlaceTests.swift (placed-images PL-4): the placed image's render budget (RenderBudgetHarness.swift),
// the packet's "120-sample focus drag on the gallery page" row. A focus model, standing in for the page's ⌥-drag
// (Move Inside, `.focus(_, drag:)` under one token), pans the gallery's Wide PNG across a 300 × 300 box 120 times,
// one per 120 Hz tick; only the picture's layer reads it, so the page body runs at most 3 times, and the raster is
// decoded once (`PlacedRaster`), never per frame. Nested in BodyCountSuites: it reads a global counter. macOS only.
#if canImport(AppKit)
import AppKit
import Observation
import SuiteKernel
import SwiftUI
import Testing

@testable import SuiteUI

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetPlaceTests {
        @Test(.timeLimit(.minutes(2))) func focusDragInThreeBodies() async throws {
            let wide = try #require(GalleryPlaceImage.samples.first { $0.format == .png })
            let (asset, fitted) = GalleryPlaceImage.placed(wide)
            #expect(PlacedRaster.image(asset) != nil, "the Wide PNG sample doesn't decode")
            let focus = PlaceFocus(PlacedImage(assetID: fitted.assetID, box: PlaceBudgetPage.box))
            let w = RenderBudgetWindow(PlaceBudgetPage(asset: asset, focus: focus))
            defer { w.close() }
            let bodies = { () -> Int? in PlaceBudgetPage.bodyRuns }
            try await w.settle(untilStable: bodies)
            let drag = "budget-focus"
            let track = try await w.measure("placed image focus drag, 120 samples", bodies: bodies) {
                try await w.ticks(120) { i in focus.move(to: Point(x: Double(i) / 120, y: 0.5), drag: drag) }
            }
            #expect(focus.moves == 120, "the focus moved \(focus.moves) of 120 times")
            #expect(focus.drags == [drag], "the drag carried tokens \(focus.drags), not one")
            let drawn = PlaceRules.drawnRect(focus.image, natural: asset.natural)
            #expect(drawn.width == 900 && drawn.height == 300, "the 3:1 picture drew \(drawn.width) × \(drawn.height)")
            #expect(drawn.maxX == PlaceBudgetPage.box.maxX, "focus 1 didn't right-align the crop: \(drawn)")
            // The focus is read only by the picture's layer: the page's body never runs. Budget 3, target 0.
            expectBodies(track, atMost: 3, target: 0)
        }
    }
}

/// What the page's ⌥-drag hands the picture: its image with the new focus, and the drag's token.
@MainActor @Observable private final class PlaceFocus {
    private(set) var image: PlacedImage
    @ObservationIgnored private(set) var moves = 0
    @ObservationIgnored private(set) var drags: Set<String> = []

    init(_ image: PlacedImage) { self.image = image }

    func move(to point: Point, drag: String) {
        image.focus = point
        moves += 1
        drags.insert(drag)
    }
}

/// The square box and the picture's layer; the page's body is the window body the budget counts.
private struct PlaceBudgetPage: View, BodyCounted {
    @Environment(\.bodyTally) private var bodyTally
    static let box = Rect(minX: 0, minY: 0, maxX: 300, maxY: 300)
    let asset: PlacedAsset
    let focus: PlaceFocus

    var body: some View {
        let _ = bodyTally.ran(Self.self)
        PlaceFocusLayer(asset: asset, focus: focus)
            .padding(SuiteSpacing.xxl)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// The only view that reads the focus: the picture drawn by `drawPlaced`, cropped by cover.
private struct PlaceFocusLayer: View {
    let asset: PlacedAsset
    let focus: PlaceFocus

    var body: some View {
        PlacedImageView(asset: asset, image: focus.image, cornerRadius: SuiteRadius.medium)
    }
}
#endif
