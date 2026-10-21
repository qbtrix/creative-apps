// PhotoTextORATests.swift (text-layers TX-1 written, TX-6 turns on): a text layer in the `.ora`. It saves
// as its rasterized PNG in the stack plus an `afterglow:text` attribute holding the words and style, so it
// reopens editable in Photo and as pixels in another editor; a damaged attribute reads as pixels too, never
// an error. Through LiveArchive and RawCodec, a lossless in-memory codec. Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreRaster
@testable import PhotoModel
import SuiteKernel
import Testing

@Suite struct PhotoTextORATests {
    private let archive = LiveArchive()

    /// "SALE" in red, 48 pt, centred in a 200 px box.
    private let sale: PhotoTextLayer = {
        var style = TextStyle.standard
        style.size = 48
        style.rgba = [220, 20, 20, 255]
        style.paragraph.alignment = .center
        return PhotoTextLayer(words: "SALE", style: style, origin: Mask.Point(x: 12, y: 8), boxWidth: 200)
    }()

    /// Distinct bytes per pixel, so a swapped or shifted byte shows.
    private func image(_ width: Int, _ height: Int, seed: Int) -> DecodedImage {
        DecodedImage(rgba8: (0..<width * height * 4).map { UInt8(($0 * 7 + seed) % 256) }, width: width, height: height)
    }

    /// Top first: the "SALE" text layer at an offset over the Background; the text's pixels stand in for
    /// its rasterized words.
    private func snapshot() -> PhotoDocumentSnapshot {
        var title = PhotoLayer(id: "layer-2", name: "SALE")
        title.kind = .text(sale)
        title.offsetX = 12; title.offsetY = 8
        let background = PhotoLayer(id: "layer-1", name: "Background")
        return PhotoDocumentSnapshot(
            canvas: CanvasSize(width: 6, height: 4), layers: [title, background],
            pixels: ["layer-2": image(4, 2, seed: 3), "layer-1": image(6, 4, seed: 0)], selectedLayerID: "layer-2")
    }

    /// `package` with `edit` applied to every text file in it that `old` occurs in.
    private func editing(_ package: PhotoPackage, _ old: String, _ edit: (String) -> String) throws -> PhotoPackage {
        var package = package, found = false
        for (path, data) in package.files where path.hasSuffix(".xml") || path.hasSuffix(".json") {
            let text = String(decoding: data, as: UTF8.self)
            guard text.contains(old) else { continue }
            package.files[path] = Data(edit(text).utf8)
            found = true
        }
        #expect(found, "no file in the package holds \(old)")
        return package
    }

    // The workspace's save and open.

    @Test func theWorkspaceSavesAndReopensATextLayer() throws {
        var workspace = PhotoWorkspace(services: .fake)
        try workspace.newCanvas(width: 6, height: 4)
        var title = PhotoLayer(id: "layer-9", name: "SALE")
        title.kind = .text(sale)
        workspace.layers.insert(title, at: 0)
        let words = image(4, 2, seed: 3)
        workspace.pixels["layer-9"] = try TiledPixels(rgba8: words.rgba8, width: words.width, height: words.height)
        let package = try workspace.documentPackage(archive: archive, codec: RawCodec())
        var reopened = PhotoWorkspace(services: .fake)
        try reopened.openDocument(package, name: "Sale.ora", archive: archive, codec: RawCodec())
        #expect(reopened.layers.first?.kind == .text(sale))
        #expect(try reopened.snapshot().pixels["layer-9"] == words)
    }

    @Test func aDocumentWithoutTextSavesAsBefore() throws {
        var workspace = PhotoWorkspace(services: .fake)
        try workspace.newCanvas(width: 6, height: 4)
        let package = try workspace.documentPackage(archive: archive, codec: RawCodec())
        let xml = String(decoding: try #require(package.files["stack.xml"]), as: UTF8.self)
        #expect(!xml.contains("afterglow:text"))
    }

    // MJ-TX: the text layer in the file.

    @Test
    func reopensEditable() throws {
        let original = snapshot()
        let package = try archive.encode(original, codec: RawCodec())
        let xml = String(decoding: try #require(package.files["stack.xml"]), as: UTF8.self)
        #expect(xml.contains("afterglow:text="))
        let reopened = try archive.decode(package, codec: RawCodec())
        #expect(reopened == original)
        guard case .text(let text) = reopened.layers.first?.kind else { Issue.record("the title reopened as pixels"); return }
        #expect(text == sale)
    }

    @Test
    func theStackPNGIsTheRasterizedPixels() throws {
        let original = snapshot()
        let package = try archive.encode(original, codec: RawCodec())
        let xml = String(decoding: try #require(package.files["stack.xml"]), as: UTF8.self)
        #expect(xml.contains(#"name="SALE" src="data/layer-2.png" x="12" y="8""#))
        let png = try RawCodec().decode(try #require(package.files["data/layer-2.png"]), longestSide: nil)
        #expect(png == original.pixels["layer-2"])
    }

    @Test
    func unknownKeyTolerated() throws {
        let package = try editing(try archive.encode(snapshot(), codec: RawCodec()), "afterglow:text") {
            $0.replacingOccurrences(of: "&quot;family&quot;", with: "&quot;glow&quot;:3,&quot;family&quot;")
        }
        let reopened = try archive.decode(package, codec: RawCodec())
        guard case .text(let text) = reopened.layers.first?.kind else { Issue.record("an unknown key lost the text"); return }
        #expect(text == sale)
    }

    @Test
    func withoutTheAttributeReadsAsPixels() throws {
        let original = snapshot()
        let package = try editing(try archive.encode(original, codec: RawCodec()), "afterglow:text") {
            $0.replacing(#/ afterglow:text="[^"]*"/#, with: "")
        }
        let reopened = try archive.decode(package, codec: RawCodec())
        let title = try #require(reopened.layers.first)
        #expect(title.kind == .pixels)
        #expect(title.name == "SALE")
        #expect(reopened.pixels["layer-2"] == original.pixels["layer-2"])
    }
}

extension PhotoTextORATests {
    @Test func aDamagedAttributeReadsAsPixels() throws {
        let package = try editing(try archive.encode(snapshot(), codec: RawCodec()), "afterglow:text") {
            $0.replacingOccurrences(of: "&quot;words&quot;", with: "&quot;wor")
        }
        let reopened = try archive.decode(package, codec: RawCodec())
        #expect(reopened.layers.first?.kind == .pixels)
        #expect(reopened.layers.first?.name == "SALE")
    }

    @Test func aTitleWithMarkupSurvives() throws {
        var original = snapshot()
        var title = try #require(original.layers.first)
        var tricky = sale
        tricky.words = #"<b>"Fish & Chips"</b> it's 'on'"#
        title.kind = .text(tricky)
        original.layers[0] = title
        let reopened = try archive.decode(try archive.encode(original, codec: RawCodec()), codec: RawCodec())
        #expect(reopened.layers.first?.kind == .text(tricky))
    }
}
