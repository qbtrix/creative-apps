// GalleryPlaceImage.swift: the gallery's `place-image` page (placed-images PL-2; PL-4 turns its journey on). An
// 800 × 600 canvas, drawn at half size, with Place… (disabled until PL-3 builds the panel) and two samples whose bytes
// are made here: `Wide PNG`, a 1200 × 400 picture, and `Logo SVG`, 240 × 80 with a red and a blue part. A sample
// places through `PlaceRules.fitted`, and each intent writes one line, `<command id> <intent>`, to `suite.gallery.log`.
// The canvas reads "Image, <name>, W by H pixels" to VoiceOver. The page is its own area in `SuiteGallery.areas`.
import CoreGraphics
import Foundation
import ImageIO
import SuiteKernel
import SwiftUI
import UniformTypeIdentifiers

enum GalleryPlaceImage {
    static let name = "place-image"

    static let pages: GalleryPages = [name: { AnyView(GalleryPlaceImagePage()) }]

    /// The canvas the page places into, and the scale it's drawn at.
    static let canvas = Rect(minX: 0, minY: 0, maxX: 800, maxY: 600)
    static let scale = 0.5

    /// A sample the page can place: its file name, bytes and natural size.
    struct Sample {
        let label: String, name: String, format: PlacedFormat, natural: Size, data: Data
    }

    static let samples = [
        Sample(label: "Wide PNG", name: "wide.png", format: .png, natural: Size(width: 1200, height: 400), data: widePNG()),
        Sample(label: "Logo SVG", name: "logo.svg", format: .svg, natural: Size(width: 240, height: 80), data: Data(logoSVG.utf8)),
    ]

    /// 240 × 80: a red part on the left, a blue one on the right.
    static let logoSVG = """
        <svg xmlns="http://www.w3.org/2000/svg" width="240" height="80" viewBox="0 0 240 80">\
        <rect x="0" y="0" width="120" height="80" fill="#ff0000"/><rect x="120" y="0" width="120" height="80" fill="#0000ff"/></svg>
        """

    /// The asset and its fitted, centred image for `sample`.
    static func placed(_ sample: Sample) -> (PlacedAsset, PlacedImage) {
        let id = PlaceRules.assetID(of: sample.data)
        let asset = PlacedAsset(
            id: id, name: sample.name, format: PlaceRules.format(of: sample.data) ?? sample.format, natural: sample.natural,
            data: sample.data)
        return (asset, PlacedImage(assetID: id, box: PlaceRules.fitted(natural: sample.natural, in: canvas, at: nil)))
    }

    /// 1200 × 400 PNG bytes: three bands, orange, green and purple; empty if ImageIO can't encode them.
    static func widePNG() -> Data {
        let (width, height) = (1200, 400)
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
            let context = CGContext(
                data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return Data() }
        let bands = [(1.0, 0.6, 0.0), (0.2, 0.7, 0.3), (0.5, 0.3, 0.8)]
        for (index, band) in bands.enumerated() {
            context.setFillColor(CGColor(srgbRed: band.0, green: band.1, blue: band.2, alpha: 1))
            context.fill(CGRect(x: index * width / bands.count, y: 0, width: width / bands.count, height: height))
        }
        let bytes = CFDataCreateMutable(nil, 0)
        guard let image = context.makeImage(), let bytes,
            let destination = CGImageDestinationCreateWithData(bytes, UTType.png.identifier as CFString, 1, nil)
        else { return Data() }
        CGImageDestinationAddImage(destination, image, nil)
        return CGImageDestinationFinalize(destination) ? bytes as Data : Data()
    }
}

/// The `place-image` page: the canvas, Place… and the samples, the file row once placed, and the log.
struct GalleryPlaceImagePage: View {
    @State private var placed: (asset: PlacedAsset, image: PlacedImage)?
    @State private var log: [String] = []

    var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            HStack(spacing: SuiteSpacing.s) {
                Button("Place…") {}
                    .disabled(PlacePanel.unbuiltHelp != nil)
                    .help(PlacePanel.unbuiltHelp ?? "Choose an image to place.")
                    .accessibilityIdentifier("suite.place.choose")
                ForEach(GalleryPlaceImage.samples, id: \.name) { sample in
                    Button(sample.label) { place(sample) }
                        .accessibilityIdentifier("suite.place.sample.\(sample.format.rawValue)")
                }
            }
            GalleryPlaceCanvas(placed: placed)
            if let placed {
                PlacedImageRows(asset: placed.asset, formats: Set(PlacedFormat.allCases), onIntent: send)
                    .frame(width: SuiteSize.inspectorWidth.ideal)
            }
            Text(log.last ?? "Nothing yet").font(SuiteFont.caption).foregroundStyle(SuiteColor.secondaryText).lineLimit(1)
                .accessibilityLabel(log.joined(separator: "\n"))
                .accessibilityValue(log.joined(separator: "\n"))
                .accessibilityIdentifier("suite.gallery.log")
        }
        .padding(SuiteSpacing.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func place(_ sample: GalleryPlaceImage.Sample) {
        placed = GalleryPlaceImage.placed(sample)
        send(.place(name: sample.name, data: sample.data, at: nil))
    }

    private func send(_ intent: PlaceIntent) {
        log.append("\(intent.command.id) \(intent)")
        if log.count > 40 { log.removeFirst(log.count - 40) }
    }
}

/// The canvas at half size: empty with its prompt, or the placed image through `drawPlaced`.
private struct GalleryPlaceCanvas: View {
    let placed: (asset: PlacedAsset, image: PlacedImage)?

    var body: some View {
        let canvas = GalleryPlaceImage.canvas, scale = GalleryPlaceImage.scale
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(SuiteColor.panel))
            if let placed { context.drawPlaced(placed.asset, placed.image, scale: scale) }
        }
        .frame(width: canvas.width * scale, height: canvas.height * scale)
        .overlay {
            if placed == nil {
                Text("Drop an image here, or choose Place…").font(SuiteFont.caption).foregroundStyle(SuiteColor.secondaryText)
            }
        }
        .clipShape(.rect(cornerRadius: SuiteRadius.medium))
        .accessibilityElement()
        .accessibilityLabel(placed == nil ? "Empty canvas" : "Image")
        .accessibilityValue(placed.map { PlacedImageText.spoken($0.asset) } ?? "")
        .accessibilityIdentifier("suite.place.canvas")
    }
}
