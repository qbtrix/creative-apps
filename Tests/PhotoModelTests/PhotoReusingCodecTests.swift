// PhotoReusingCodecTests.swift: a CLI edit re-encodes only the images it changed (quality gate #5833). Opening a
// saved .ora, adding a layer and saving keeps the photo layer's PNG byte for byte, as read; resizing the image
// writes a new one. Runs on Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
@testable import PhotoModel
import SuiteKernel
import Testing

@Suite struct PhotoReusingCodecTests {
    /// A 6 x 4 photo of distinct pixels, as a saved .ora.
    func savedDocument() throws -> Data {
        var rgba = [UInt8]()
        for i in 0..<24 { rgba += [UInt8(i * 10), UInt8(255 - i * 9), UInt8(i * 3), 255] }
        let png = try PhotoHeadless.codec.encode(DecodedImage(rgba8: rgba, width: 6, height: 4), as: .png, quality: 1)
        return try PhotoHeadless.open(png, name: "photo.png").save()
    }

    func layerPNG(_ ora: Data) throws -> Data? {
        try PhotoServices.live.archive.package(fromContainer: ora).files["data/layer-1.png"]
    }

    @Test func anEditThatLeavesALayerAloneKeepsItsPNG() throws {
        let saved = try savedDocument()
        var document = try PhotoHeadless.open(saved, name: "photo.ora")
        #expect(document.files.remembered >= 1, "the opened layer's PNG wasn't remembered")
        _ = try PhotoHeadless.catalog.run("layer.new", params: .object([:]), on: &document)
        let out = try document.save()
        let before = try #require(try layerPNG(saved))
        #expect(try layerPNG(out) == before)
        #expect(document.files.reused >= 1, "the untouched photo layer was encoded again")
        #expect(try PhotoHeadless.open(out, name: "photo.ora").workspace.layers.count == 2)
    }

    @Test func anEditThatChangesALayerWritesANewPNG() throws {
        let saved = try savedDocument()
        var document = try PhotoHeadless.open(saved, name: "photo.ora")
        _ = try PhotoHeadless.catalog.run("image.resize", params: .object(["width": .number(3), "height": .number(2)]), on: &document)
        let out = try document.save()
        let image = try PhotoHeadless.codec.decode(try #require(try layerPNG(out)), longestSide: nil)
        #expect(image.width == 3 && image.height == 2, "the resized layer kept its old PNG")
    }
}
