// SuitePlaceSnapshots.swift (placed-images PL-4): the placed-image screens in Light and Dark, from the packet's Screens
// and states. Writes suiteui-place-empty-{light,dark}.png (the gallery page's drop prompt, Place… and the samples),
// suiteui-place-wide-{light,dark}.png (Wide PNG fitted 800 × 267 with its rows), suiteui-place-cover-{light,dark}.png
// (the wide picture in a square box, cropped by cover at the left, centre and right focus, never squashed),
// suiteui-place-svg-{light,dark}.png (Logo SVG at its natural 240 × 80), suiteui-place-drop-target-{light,dark}.png
// (the canvas with the drop's accent ring) and suiteui-place-refused-{light,dark}.png (the format note). macOS only.
import SuiteKernel
import SwiftUI
import Testing

@testable import SuiteUI

@MainActor
@Suite struct SuitePlaceSnapshots {
    @Test func screens() throws {
        let wide = try #require(GalleryPlaceImage.samples.first { $0.format == .png })
        let logo = try #require(GalleryPlaceImage.samples.first { $0.format == .svg })
        #expect(!wide.data.isEmpty, "the Wide PNG sample has no bytes")
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(GalleryPlaceImagePage(), name: "suiteui-place-empty-\(scheme.name)", scheme: scheme)
            try snapshot(PlaceSample(sample: wide), name: "suiteui-place-wide-\(scheme.name)", scheme: scheme)
            try snapshot(PlaceCoverSample(sample: wide), name: "suiteui-place-cover-\(scheme.name)", scheme: scheme)
            try snapshot(PlaceSample(sample: logo), name: "suiteui-place-svg-\(scheme.name)", scheme: scheme)
            try snapshot(PlaceSample(sample: nil, ringed: true), name: "suiteui-place-drop-target-\(scheme.name)", scheme: scheme)
            try snapshot(PlaceSample(sample: nil, note: PlaceRules.formatHelp), name: "suiteui-place-refused-\(scheme.name)", scheme: scheme)
        }
    }

    /// The fitted box the wide sample gets, which the wide screen shows: 800 × 267, centred.
    @Test func wideFitsTheCanvas() throws {
        let wide = try #require(GalleryPlaceImage.samples.first { $0.format == .png })
        let box = GalleryPlaceImage.placed(wide).1.box
        #expect(box.width == 800 && abs(box.height - 800.0 / 3) < 0.5, "Wide PNG fits as \(box.width) × \(box.height)")
        #expect(abs((box.minY + box.maxY) / 2 - 300) < 0.5, "Wide PNG isn't centred: \(box)")
    }
}

/// The page's canvas at half size, as `GalleryPlaceCanvas` draws it: a sample placed and its rows, or the empty
/// prompt with the drop ring or a refusal note under it.
private struct PlaceSample: View {
    let sample: GalleryPlaceImage.Sample?
    var ringed = false
    var note: String?

    var body: some View {
        let canvas = GalleryPlaceImage.canvas, scale = GalleryPlaceImage.scale
        let placed = sample.map(GalleryPlaceImage.placed)
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            Canvas { context, size in
                context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(SuiteColor.panel))
                if let placed { context.drawPlaced(placed.0, placed.1, scale: scale) }
            }
            .frame(width: canvas.width * scale, height: canvas.height * scale)
            .overlay {
                if placed == nil {
                    Text("Drop an image here, or choose Place…").font(SuiteFont.caption).foregroundStyle(SuiteColor.secondaryText)
                }
            }
            .clipShape(.rect(cornerRadius: SuiteRadius.medium))
            .overlay {
                if ringed { RoundedRectangle(cornerRadius: SuiteRadius.medium).stroke(SuiteColor.accent, lineWidth: SuiteSize.focusRing) }
            }
            if let placed {
                PlacedImageRows(asset: placed.0, formats: Set(PlacedFormat.allCases)) { _ in }
                    .frame(width: SuiteSize.inspectorWidth.ideal)
            }
            if let note { Text(note).font(SuiteFont.caption).foregroundStyle(SuiteColor.secondaryText) }
        }
        .padding(SuiteSpacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// The 1200 × 400 picture in a 300 × 300 box at focus 0, 0.5 and 1: three different crops, each 3:1.
private struct PlaceCoverSample: View {
    let sample: GalleryPlaceImage.Sample

    var body: some View {
        let placed = GalleryPlaceImage.placed(sample)
        HStack(spacing: SuiteSpacing.xxl) {
            ForEach([0.0, 0.5, 1.0], id: \.self) { x in
                let image = PlacedImage(
                    assetID: placed.1.assetID, box: Rect(minX: 0, minY: 0, maxX: 300, maxY: 300), focus: Point(x: x, y: 0.5))
                PlacedImageView(asset: placed.0, image: image, cornerRadius: SuiteRadius.medium)
            }
        }
        .padding(SuiteSpacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
