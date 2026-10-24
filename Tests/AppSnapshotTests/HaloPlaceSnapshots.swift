// HaloPlaceSnapshots.swift (placed-images PH-u): a placed picture in Halo's viewer and inspector, from values (the
// draw list fills a solid's picture, so each fixture is built by hand rather than placed through the commands).
// halo-place-logo: a 480 x 160 logo.svg on a solid centred in a 1920 x 1080 composition (an SVG draws SuiteUI's
// grey placeholder with its name until PL-8). halo-place-fill: a 1200 x 800 JPEG, red left and blue right, filling
// a full-frame solid. halo-place-inspector: the layer inspector on `three-layers` with Background holding
// logo.svg: IMAGE reads "logo.svg · SVG · 480 × 160" with live Replace… and Reset Size over the Place row's
// "Into the selected solid" checkbox, no note (the place commands run since PH-6), and FILL is off with the note
// that the picture covers the solid's colour. Also the pure mappings: the ⌥-drag's focus pan and the drop point.
// Light and Dark. macOS only.
import CoreGraphics
import HaloModel
import ImageIO
import SuiteKernel
import SuiteUI
import SwiftUI
import Testing
import UniformTypeIdentifiers

@testable import HaloApp

@MainActor
@Suite struct HaloPlaceSnapshots {
    @Test func logo() throws {
        let box = Rect(minX: 720, minY: 460, maxX: 1200, maxY: 620)
        try Self.both(Self.viewer(Self.item(Self.logoAsset, box: box)), name: "halo-place-logo")
    }

    @Test func fill() throws {
        let asset = PlacedAsset(
            id: "photo", name: "photo-1200x800.jpg", format: .jpeg, natural: Size(width: 1200, height: 800),
            data: try Self.jpeg(width: 1200, height: 800))
        try Self.both(Self.viewer(Self.item(asset, box: Rect(minX: 0, minY: 0, maxX: 1920, maxY: 1080))), name: "halo-place-fill")
    }

    @Test func inspector() throws {
        var document = try #require(HaloFixtures.project("three-layers"))
        let l = try #require(document.compositions.first?.layers.firstIndex { $0.name == "Background" })
        document.compositions[0].layers[l].placedAsset = Self.logoAsset
        var project = HaloProject(services: .fake, document: document)
        project.selectLayer(document.compositions[0].layers[l].id)
        #expect(HaloPlaceInspector.shows(project.selectedLayer?.kind), "a solid shows IMAGE")
        let section = HaloPlaceInspector(model: project)
        #expect(section.asset == Self.logoAsset && section.modelHelp == nil, "IMAGE reads the picture, controls live")
        let fill = HaloFillInspector(model: project, perform: { _ in }, runFill: { _ in })
        #expect(fill.help != nil && fill.colorHelp == fill.help, "FILL and its colour row say the picture covers them")
        #expect(HaloPlaceInspector.fillTitle == "Into the selected solid", "the checkbox names when it applies")
        try Self.both(
            HaloLayerInspector(model: project)
                .environment(\.haloPlace, { _, _ in })
                .frame(width: SuiteSize.inspectorWidth.ideal, height: 1100, alignment: .topLeading)
                .background(SuiteColor.panel),
            name: "halo-place-inspector")
    }

    /// Panning right by the whole excess takes the focus from the middle to the left edge; an axis with no
    /// excess keeps its focus.
    @Test func focusPan() {
        let image = PlacedImage(assetID: "photo", box: Rect(minX: 0, minY: 0, maxX: 1920, maxY: 1080))
        let natural = Size(width: 1200, height: 800)  // cover: 1920 x 1280, 200 px of vertical excess only
        #expect(HaloPlace.focus(image, natural: natural, panned: CGSize(width: 300, height: 100)) == Point(x: 0.5, y: 0))
        #expect(HaloPlace.focus(image, natural: natural, panned: CGSize(width: 0, height: -50)) == Point(x: 0.5, y: 0.75))
    }

    /// A 1920 x 1080 composition in a 1088 x 668 viewer fits at 50% inside the 64 pt inset.
    @Test func dropPoint() {
        let (viewer, comp) = (CGSize(width: 1088, height: 668), CGSize(width: 1920, height: 1080))
        #expect(HaloPlace.pixelsPerPoint(viewer: viewer, composition: comp) == 2)
        #expect(HaloPlace.compositionPoint(CGPoint(x: 544, y: 334), viewer: viewer, composition: comp) == Point(x: 960, y: 540))
        #expect(HaloPlace.compositionPoint(CGPoint(x: 10, y: 10), viewer: viewer, composition: comp) == nil)
    }

    /// A 480 x 160 SVG: a dark rounded bar with a light circle.
    static let logoSVG = ##"<svg xmlns="http://www.w3.org/2000/svg" width="480" height="160"><rect width="480" height="160" rx="24" fill="#202840"/><circle cx="80" cy="80" r="48" fill="#F0C040"/></svg>"##
    static let logoAsset = PlacedAsset(
        id: "logo", name: "logo.svg", format: .svg, natural: Size(width: 480, height: 160), data: Data(logoSVG.utf8))

    /// A solid over `box` showing `asset`, on a grey full-frame solid.
    private static func item(_ asset: PlacedAsset, box: Rect) -> [HaloDrawItem] {
        let frame = HaloLayerRect(x: 0, y: 0, width: 1920, height: 1080)
        let rect = HaloLayerRect(x: box.minX, y: box.minY, width: box.width, height: box.height)
        return [
            HaloDrawItem(
                layerID: "bg", kind: .solid, bounds: frame, matrix: .identity, opacity: 1,
                color: HaloLayerColor(red: 0.3, green: 0.3, blue: 0.3), blendMode: .normal),
            HaloDrawItem(
                layerID: "placed", kind: .solid, bounds: rect, matrix: .identity, opacity: 1,
                color: HaloLayerColor(red: 0, green: 1, blue: 0), blendMode: .normal,
                placedAsset: asset, placedImage: PlacedImage(assetID: asset.id, box: box)),
        ]
    }

    private static func viewer(_ items: [HaloDrawItem]) -> some View {
        HaloDrawnLayers(list: HaloDrawList(width: 1920, height: 1080, frame: 0, items: items), selectedLayerID: "placed")
            .frame(width: 640, height: 360)
            .padding(SuiteSpacing.l)
            .background(SuiteColor.panel)
    }

    /// A `width` x `height` JPEG, red on the left half and blue on the right.
    static func jpeg(width: Int, height: Int) throws -> Data {
        let data = NSMutableData()
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
            let context = CGContext(
                data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { throw CocoaError(.fileWriteUnknown) }
        context.setFillColor(CGColor(srgbRed: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width / 2, height: height))
        context.setFillColor(CGColor(srgbRed: 0, green: 0, blue: 1, alpha: 1))
        context.fill(CGRect(x: width / 2, y: 0, width: width - width / 2, height: height))
        guard let image = context.makeImage(),
            let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil)
        else { throw CocoaError(.fileWriteUnknown) }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
        return data as Data
    }

    /// Writes `<name>-light` and `<name>-dark`.
    private static func both(_ view: some View, name: String) throws {
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(view, name: "\(name)-\(scheme.name)", scheme: scheme)
        }
    }
}
