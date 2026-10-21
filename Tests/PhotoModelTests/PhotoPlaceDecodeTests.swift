// PhotoPlaceDecodeTests.swift (place-image PP-m, finding #4248): a placed file is read through the workspace's
// image codec (the window's is ImageIO) at the size it is placed at, not decoded whole and then resampled, so a
// 4000 x 3000 JPEG placed on an 800 x 600 canvas asks the codec for 800 px on its longest side. A codec that
// rounds a pixel off still leaves the layer exactly the fitted box. Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
@testable import PhotoModel
import SuiteKernel
import Testing

/// A codec for a `width` x `height` grey picture that notes each longest side it is asked for and answers at it,
/// `short` pixels narrower than asked.
private final class SizingCodec: PhotoImageCodec, @unchecked Sendable {
    let width: Int, height: Int, short: Int
    private(set) var sides: [Int?] = []

    init(_ width: Int, _ height: Int, short: Int = 0) { (self.width, self.height, self.short) = (width, height, short) }

    func decode(_ data: Data, longestSide: Int?) throws -> DecodedImage {
        sides.append(longestSide)
        var (w, h) = (width, height)
        if let side = longestSide, side < max(w, h) {
            let scale = Double(side) / Double(max(w, h))
            (w, h) = (Int((Double(w) * scale).rounded()), Int((Double(h) * scale).rounded()))
        }
        w = max(w - short, 1)
        return DecodedImage(rgba8: [UInt8](repeating: 128, count: w * h * 4), width: w, height: h)
    }

    func encode(_ image: DecodedImage, as format: ImageFormat, quality: Double) throws -> Data { Data() }
}

@Suite struct PhotoPlaceDecodeTests {
    /// An 800 x 600 image reading placed files through `codec`.
    private func opened(_ codec: SizingCodec) throws -> PhotoWorkspace {
        var workspace = PhotoWorkspace()
        try workspace.newCanvas(width: 800, height: 600)
        workspace.fileFlow.codec = codec
        return workspace
    }

    /// Places a `width` x `height` file (its bytes are only the codec's business) the way `place.image` does.
    private func place(_ width: Int, _ height: Int, on workspace: inout PhotoWorkspace) throws -> String {
        let data = Data([1, 2, 3])
        let asset = PlacedAsset(id: PlaceRules.assetID(of: data), name: "photo.jpg", format: .jpeg,
                                natural: Size(width: Double(width), height: Double(height)), data: data)
        let box = PlaceRules.fitted(natural: asset.natural, in: workspace.placeCanvas, at: nil)
        return try workspace.insertPlaced(asset, PlacedImage(assetID: asset.id, box: box), name: "Place Image")
    }

    @Test func largeIsReadAtTheFittedSize() throws {
        let codec = SizingCodec(4000, 3000)
        var workspace = try opened(codec)
        let id = try place(4000, 3000, on: &workspace)
        #expect(codec.sides == [800], "the file was read at \(codec.sides), not straight at the box's 800 px")
        let tiles = try #require(workspace.pixels[id])
        #expect((tiles.width, tiles.height) == (800, 600))
        #expect(workspace.statusMessage == "Placed at 20%.")
        #expect(workspace.canUndo)
    }

    @Test func smallIsReadWhole() throws {
        let codec = SizingCodec(200, 100)
        var workspace = try opened(codec)
        let id = try place(200, 100, on: &workspace)
        #expect(codec.sides == [nil])
        let tiles = try #require(workspace.pixels[id])
        #expect((tiles.width, tiles.height) == (200, 100))
        #expect(workspace.statusMessage == nil)
    }

    @Test func aCodecAPixelShortStillFillsTheBox() throws {
        let codec = SizingCodec(4000, 3000, short: 1)
        var workspace = try opened(codec)
        let id = try place(4000, 3000, on: &workspace)
        let tiles = try #require(workspace.pixels[id])
        #expect((tiles.width, tiles.height) == (800, 600))
    }
}
