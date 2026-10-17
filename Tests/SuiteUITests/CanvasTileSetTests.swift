// CanvasTileSetTests.swift: the canvas host's tile path (CH-8). An update of
// 3 dirty tiles replaces 3 layers and leaves the clean ones as they were; a
// new document size restarts the set, so no stale tile survives;
// `handedBytes` is the byte count of the images handed to layers, clean tiles
// left out; every image a layer shows is premultiplied sRGB. macOS only.
import CoreGraphics
import SuiteUI
import Testing

@MainActor
@Suite struct CanvasTileSetTests {
    private static let document = CGSize(width: 4096, height: 2160)

    /// A 4 x 4 image filled with `gray` in `space`, with `alpha` as its alpha layout.
    private static func image(
        _ gray: CGFloat, space: CFString = CGColorSpace.sRGB, alpha: CGImageAlphaInfo = .premultipliedLast
    ) -> CGImage? {
        guard let colorSpace = CGColorSpace(name: space),
            let context = CGContext(
                data: nil, width: 4, height: 4, bitsPerComponent: 8, bytesPerRow: 16, space: colorSpace,
                bitmapInfo: alpha.rawValue)
        else { return nil }
        context.setFillColor(red: gray, green: gray, blue: gray, alpha: 0.5)
        context.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        return context.makeImage()
    }

    /// The fake content's twenty rects, each with its own image.
    private static func fullTiles() -> [CanvasTile] {
        FakeCanvasContent().tiles(dirtyOnly: false).enumerated().map { index, tile in
            CanvasTile(rect: tile.rect, image: image(CGFloat(index) / 20))
        }
    }

    private static func bytes(_ images: [CGImage?]) -> Int {
        images.compactMap { $0 }.reduce(0) { $0 + $1.bytesPerRow * $1.height }
    }

    @Test func threeDirtyTilesReplaceThreeLayers() {
        let set = CanvasTileSet()
        let full = Self.fullTiles()
        let first = set.apply(full, documentSize: Self.document)
        #expect(first.replaced == 20)
        #expect(set.layerCount == 20)

        let dirty: Set<Int> = [2, 7, 15]
        let next = full.enumerated().map { index, tile in
            dirty.contains(index) ? CanvasTile(rect: tile.rect, image: Self.image(0.9)) : tile
        }
        let update = set.apply(next, documentSize: Self.document)

        #expect(update.replaced == 3)
        #expect(!update.restarted)
        #expect(set.layerCount == 20)
        for (index, tile) in next.enumerated() {
            #expect(set.image(at: tile.rect) === tile.image, "tile \(index)")
        }
    }

    @Test func aSizeChangeRestarts() {
        let set = CanvasTileSet()
        let full = Self.fullTiles()
        #expect(set.apply(full, documentSize: Self.document).restarted)
        #expect(!set.apply(full, documentSize: Self.document).restarted)

        let small = CGSize(width: 2048, height: 432)
        let kept = Array(full.prefix(2))
        let update = set.apply(kept, documentSize: small)

        #expect(update.restarted)
        #expect(update.replaced == 2)
        #expect(set.documentSize == small)
        #expect(set.layerCount == 2)
        for stale in full.dropFirst(2) {
            #expect(set.image(at: stale.rect) == nil)
        }
        #expect(set.container.bounds.size == small)
    }

    @Test func handedBytesEqualsTheHandedTilesBytes() {
        let set = CanvasTileSet()
        let full = Self.fullTiles()
        set.apply(full, documentSize: Self.document)
        #expect(set.handedBytes == Self.bytes(full.map(\.image)))
        #expect(set.handedBytes > 0)

        let fresh = [Self.image(0.3), Self.image(0.6), Self.image(0.8)]
        var next = full
        for (offset, index) in [0, 9, 19].enumerated() {
            next[index] = CanvasTile(rect: full[index].rect, image: fresh[offset])
        }
        set.apply(next, documentSize: Self.document)
        #expect(set.handedBytes == Self.bytes(fresh))

        set.apply(next, documentSize: Self.document)
        #expect(set.handedBytes == 0)
    }

    @Test func imagesArePremultipliedSRGB() throws {
        let set = CanvasTileSet()
        let rects = FakeCanvasContent().tiles(dirtyOnly: false).map(\.rect)
        let sRGB = try #require(Self.image(0.5))
        let p3 = try #require(Self.image(0.5, space: CGColorSpace.displayP3))
        let opaque = try #require(Self.image(0.5, alpha: .noneSkipLast))
        set.apply(
            [CanvasTile(rect: rects[0], image: sRGB), CanvasTile(rect: rects[1], image: p3),
             CanvasTile(rect: rects[2], image: opaque)],
            documentSize: Self.document)

        #expect(set.image(at: rects[0]) === sRGB)
        #expect(!CanvasTileSet.isPremultipliedSRGB(p3))
        for rect in rects.prefix(3) {
            let shown = try #require(set.image(at: rect))
            #expect(CanvasTileSet.isPremultipliedSRGB(shown))
            #expect([.premultipliedLast, .premultipliedFirst].contains(shown.alphaInfo))
            #expect(shown.colorSpace?.name.map { $0 as String } == (CGColorSpace.sRGB as String))
        }
    }
}
