// PhotoDocumentRoundTripTests.swift: LiveArchive, the OpenRaster document
// (PV-1, D-2), through RawCodec, a lossless in-memory codec. PF-1: every
// layer's 8-bit bytes, masks, kinds, blend, opacity, offsets, visibility, the
// whole-image adjustments and the selected layer survive exactly; bad
// packages fail with the ArchiveError the alert names. Runs on Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreRaster
@testable import PhotoModel
import Testing

@Suite struct PhotoDocumentRoundTripTests {
    private let archive = LiveArchive()

    /// Distinct bytes per pixel, so a swapped or shifted byte shows.
    private func image(_ width: Int, _ height: Int, seed: Int) -> DecodedImage {
        DecodedImage(rgba8: (0..<width * height * 4).map { UInt8(($0 * 7 + seed) % 256) }, width: width, height: height)
    }

    /// Top first: an adjustment layer with a mask, a hidden multiply layer
    /// at an offset with a disabled mask, and the Background.
    private func snapshot() -> PhotoDocumentSnapshot {
        var settings = AdjustmentSettings()
        settings.apply(.exposure(0.75))
        settings.apply(.hue(30))
        var curves = PhotoLayer(id: "layer-7", name: "Curves & <1>")
        curves.kind = .adjustment(settings)
        curves.hasMask = true
        var paint = PhotoLayer(id: "layer-3", name: "Layer \"1\"", isVisible: false, opacity: 0.37, blendMode: .multiply)
        paint.offsetX = -2; paint.offsetY = 3
        paint.hasMask = true; paint.isMaskEnabled = false
        let background = PhotoLayer(id: "layer-1", name: "Background")
        var global = AdjustmentSettings()
        global.apply(.saturation(-40))
        global.apply(.blurSigma(1.5))
        return PhotoDocumentSnapshot(
            canvas: CanvasSize(width: 6, height: 4), layers: [curves, paint, background],
            pixels: ["layer-3": image(3, 2, seed: 5), "layer-1": image(6, 4, seed: 0)],
            masks: ["layer-7": image(6, 4, seed: 9), "layer-3": image(3, 2, seed: 11)],
            adjustments: global, selectedLayerID: "layer-3")
    }

    /// `package` with `old` replaced by `new` in its document.json.
    private func editingJSON(_ package: PhotoPackage, _ old: String, _ new: String) throws -> PhotoPackage {
        var package = package
        let text = String(decoding: try #require(package.files["photo/document.json"]), as: UTF8.self)
        #expect(text.contains(old))
        package.files["photo/document.json"] = Data(text.replacingOccurrences(of: old, with: new).utf8)
        return package
    }

    @Test func everyFieldSurvives() throws {
        let original = snapshot()
        let package = try archive.encode(original, codec: RawCodec())
        #expect(try archive.decode(package, codec: RawCodec()) == original)
        #expect(package.files["mimetype"] == Data("image/openraster".utf8))
        for path in ["data/layer-1.png", "data/layer-2.png", "photo/masks/layer-2.png", "photo/masks/layer-3.png",
                     "mergedimage.png", "Thumbnails/thumbnail.png", "stack.xml"] {
            #expect(package.files[path] != nil, "\(path) missing")
        }
        #expect(package.files["data/layer-3.png"] == nil)
        let text = String(decoding: try #require(package.files["photo/document.json"]), as: UTF8.self)
        #expect(text.hasPrefix(#"{"adjustments":"#) && text.contains(#""format":1"#))
    }

    @Test func stackListsPixelLayersTopFirst() throws {
        let package = try archive.encode(snapshot(), codec: RawCodec())
        let xml = String(decoding: try #require(package.files["stack.xml"]), as: UTF8.self)
        #expect(xml.contains(#"<image version="0.0.6" w="6" h="4">"#))
        #expect(xml.contains(#"name="Layer &quot;1&quot;" src="data/layer-2.png" x="-2" y="3" opacity="0.37""#))
        #expect(xml.contains(#"visibility="hidden" composite-op="svg:multiply""#))
        #expect(xml.contains(#"composite-op="svg:src-over""#))
        #expect(!xml.contains("Curves"))
        let paint = try #require(xml.range(of: "layer-2.png")), back = try #require(xml.range(of: "layer-1.png"))
        #expect(paint.lowerBound < back.lowerBound)
    }

    @Test func mergedImageAndThumbnail() throws {
        let big = PhotoDocumentSnapshot(
            canvas: CanvasSize(width: 512, height: 300), layers: [PhotoLayer(id: "layer-1", name: "Background")],
            pixels: ["layer-1": image(512, 300, seed: 1)])
        let package = try archive.encode(big, codec: RawCodec())
        let merged = try RawCodec().decode(try #require(package.files["mergedimage.png"]), longestSide: nil)
        #expect(merged.width == 512 && merged.height == 300)
        let thumb = try RawCodec().decode(try #require(package.files["Thumbnails/thumbnail.png"]), longestSide: nil)
        #expect(thumb.width == 256 && thumb.height == 150)
    }

    @Test func workspaceRoundTripsThroughTheFile() throws {
        let white = DecodedImage(rgba8: [UInt8](repeating: 255, count: 8 * 6 * 4), width: 8, height: 6)
        var workspace = PhotoWorkspace(services: .fake)
        try workspace.openImage(try RawCodec().encode(white, as: .png, quality: 1), name: "beach.png", codec: RawCodec())
        workspace.addLayer()
        stroke(&workspace, .brush, from: point(1, 1), to: point(6, 4))
        let top = try #require(workspace.layers.first?.id)
        workspace.setOpacity(top, percent: 50)
        workspace.setBlendMode(top, .multiply)
        workspace.adjust(.exposure(1))
        let before = try workspace.snapshot()
        let file = try archive.container(try archive.encode(before, codec: RawCodec()))
        #expect(file.prefix(30 + 8).suffix(8) == Data("mimetype".utf8))
        var opened = PhotoWorkspace(services: .fake)
        try opened.openDocument(try archive.package(fromContainer: file), name: "beach.ora", archive: archive,
                                codec: RawCodec())
        #expect(try opened.snapshot() == before)
        #expect(opened.layers.count == 2)
        #expect(!opened.isDirty)
    }

    @Test func newerFormatRefuses() throws {
        let package = try editingJSON(try archive.encode(snapshot(), codec: RawCodec()), #""format":1"#, #""format":2"#)
        #expect(throws: ArchiveError.newerVersion(2)) { try archive.decode(package, codec: RawCodec()) }
    }

    @Test func missingLayerImageIsDamaged() throws {
        var package = try archive.encode(snapshot(), codec: RawCodec())
        package.files["data/layer-2.png"] = nil
        #expect(throws: ArchiveError.damaged("data/layer-2.png is missing")) {
            try archive.decode(package, codec: RawCodec())
        }
    }

    @Test func missingDocumentJSONIsDamaged() throws {
        var package = try archive.encode(snapshot(), codec: RawCodec())
        package.files["photo/document.json"] = nil
        #expect(throws: ArchiveError.damaged("photo/document.json is missing")) {
            try archive.decode(package, codec: RawCodec())
        }
    }

    @Test func unreadableJSONIsDamaged() throws {
        var package = try archive.encode(snapshot(), codec: RawCodec())
        package.files["photo/document.json"] = Data("{".utf8)
        #expect(throws: ArchiveError.damaged("photo/document.json is unreadable")) {
            try archive.decode(package, codec: RawCodec())
        }
    }

    @Test func twentyMegapixelLayerIsTooLarge() throws {
        var package = try archive.encode(snapshot(), codec: RawCodec())
        package.files["data/layer-1.png"] = try RawCodec().encode(
            DecodedImage(rgba8: [UInt8](repeating: 0, count: 5000 * 4000 * 4), width: 5000, height: 4000),
            as: .png, quality: 1)
        #expect(throws: ArchiveError.tooLarge) { try archive.decode(package, codec: RawCodec()) }
    }

    @Test func oversizedCanvasIsTooLarge() throws {
        let package = try editingJSON(
            try archive.encode(snapshot(), codec: RawCodec()), #""canvas":{"height":4,"width":6}"#,
            #""canvas":{"height":4000,"width":5000}"#)
        #expect(throws: ArchiveError.tooLarge) { try archive.decode(package, codec: RawCodec()) }
    }

    @Test func liveServicesHoldTheArchive() {
        #expect(PhotoServices.live.archive is LiveArchive)
        #expect(PhotoServices.live.archive.unavailableHelp == nil)
        #expect(archive.formatVersion == 1)
    }
}
