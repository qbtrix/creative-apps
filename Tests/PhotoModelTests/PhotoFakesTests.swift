// PhotoFakesTests.swift: the v2 fakes (blueprint 5.2) are all available,
// keep no state across instances, and each changes something a journey can
// see. Runs on Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreRaster
import PhotoModel
import Testing

@Suite struct PhotoFakesTests {
    private func snapshot() -> PhotoDocumentSnapshot {
        let layer = PhotoLayer(id: "layer-1", name: "Background")
        let image = DecodedImage(rgba8: [UInt8](repeating: 200, count: 2 * 2 * 4), width: 2, height: 2)
        return PhotoDocumentSnapshot(canvas: CanvasSize(width: 2, height: 2), layers: [layer],
                                     pixels: [layer.id: image], selectedLayerID: layer.id)
    }

    /// An all-white layer's pixels, through the only public way to make them.
    private func tiles(_ width: Int, _ height: Int) throws -> TiledPixels {
        try FakeMasking().mask(from: nil, layerBounds: PixelRect(x: 0, y: 0, width: width, height: height))
    }

    @Test func everyFakeIsAvailable() {
        let fakes: [any PhotoUseCase] = [
            FakeArchive(), FakeRecovery(), FakeClipboard(), FakeMerging(), FakeCrop(), FakeSelection(),
            FakeMasking(), FakeAdjustmentLayers(), FakeTransform(), FakeExportSizing(), FakeSampling(),
        ]
        #expect(fakes.count == 11)
        for fake in fakes { #expect(fake.unavailableHelp == nil, "\(type(of: fake))") }
    }

    @Test func fakeArchiveRoundTripsThroughItsContainer() throws {
        let archive = FakeArchive(), original = snapshot()
        let package = try archive.encode(original, codec: RawCodec())
        let data = try archive.container(package)
        let read = try archive.package(fromContainer: data)
        #expect(try archive.decode(read, codec: RawCodec()) == original)
    }

    @Test func aSecondFakeArchiveDoesNotSeeTheFirstsSnapshot() throws {
        let first = FakeArchive(), second = FakeArchive()
        let package = try first.encode(snapshot(), codec: RawCodec())
        #expect(throws: ArchiveError.notADocument) { try second.decode(package, codec: RawCodec()) }
    }

    @Test func fakeArchiveRefusesAnotherFile() {
        #expect(throws: ArchiveError.notADocument) { try FakeArchive().package(fromContainer: Data("PK".utf8)) }
    }

    @Test func fakeRecoveryKeepsItsOwnEntriesNewestFirst() throws {
        let recovery = FakeRecovery(), package = PhotoPackage(files: [:])
        try recovery.write(RecoveryEntry(documentName: "A", savedAt: 1, package: package), window: "w1")
        try recovery.write(RecoveryEntry(documentName: "B", savedAt: 2, package: package), window: "w2")
        #expect(try recovery.leftBehind().map(\.documentName) == ["B", "A"])
        #expect(try FakeRecovery().leftBehind().isEmpty)
        try recovery.discard(window: "w2")
        #expect(try recovery.leftBehind().map(\.documentName) == ["A"])
        try recovery.discardAll()
        #expect(try recovery.leftBehind().isEmpty)
    }

    @Test func fakeSamplingGivesSunYellow() throws {
        let picture = try PixelBuffer(width: 1, height: 1)
        #expect(FakeSampling().sample(picture, center: (x: 0, y: 0), size: .point)
            == SampledColor(red: 255, green: 204, blue: 0))
    }

    @Test func fakeAdjustmentLayersChangeAGrayPixel() throws {
        let gray = try PixelBuffer(width: 1, height: 1, fill: RGBA(r: 0.2, g: 0.2, b: 0.2, a: 1))
        let out = try FakeAdjustmentLayers().applying(AdjustmentSettings(), to: gray, opacity: 1,
                                                      blendMode: .normal, mask: nil)
        #expect(try out.pixel(x: 0, y: 0) != gray.pixel(x: 0, y: 0))
    }

    @Test func fakeClipboardCopiesASquareAndPastesItCentered() throws {
        let content = PlacedPixels(pixels: try tiles(8, 8), x: 0, y: 0)
        let copied = try #require(try FakeClipboard().copy(content, selection: nil, mask: nil))
        #expect(copied.image.width == 64 && copied.image.height == 64)
        let rect = FakeClipboard().placement(of: copied, canvas: CanvasSize(width: 200, height: 100),
                                             center: Mask.Point(x: 0, y: 0))
        #expect(rect == PixelRect(x: 68, y: 18, width: 64, height: 64))
    }

    @Test func fakeMergingRefusesAnAdjustmentLayerBelow() throws {
        let upper = LayerContent(layer: PhotoLayer(id: "a", name: "A"), pixels: try tiles(2, 2))
        let lower = LayerContent(layer: PhotoLayer(id: "b", name: "B"), pixels: nil)
        #expect(throws: PhotoRefusal("Merge Down needs a pixel layer below.")) {
            try FakeMerging().mergeDown(upper, onto: lower)
        }
    }

    @Test func fakeSelectionSelectsTheShapesRectangle() throws {
        let mask = try FakeSelection().mask(for: .ellipse(PixelRect(x: 1, y: 1, width: 2, height: 2)),
                                            canvas: CanvasSize(width: 4, height: 4))
        #expect(mask.area > 0)
        #expect(throws: PhotoRefusal.self) { try FakeSelection().mask(for: .lasso([]), canvas: CanvasSize(width: 4, height: 4)) }
    }

    @Test func fakeTransformMovesThePixels() throws {
        let content = PlacedPixels(pixels: try tiles(2, 2), x: 3, y: 4)
        let draft = TransformDraft(layerID: "a", box: PixelRect(x: 3, y: 4, width: 2, height: 2))
        let moved = FakeTransform().dragged(draft, handle: .inside, from: Mask.Point(x: 0, y: 0),
                                            to: Mask.Point(x: 5, y: -2), modifiers: [])
        let applied = try FakeTransform().applied(moved, to: content)
        #expect(applied.x == 8 && applied.y == 2)
        #expect(FakeTransform().corners(of: moved).count == 4)
    }

    @Test func fakeExportSizingScalesByPercent() throws {
        let size = try FakeExportSizing().outputSize(for: CanvasSize(width: 800, height: 600), .percent(50))
        #expect(size == CanvasSize(width: 400, height: 300))
        let image = DecodedImage(rgba8: [UInt8](repeating: 0, count: 4), width: 1, height: 1)
        #expect(try FakeExportSizing().resized(image, to: size).width == 400)
    }

    @Test func fakeCropClampsToTheCanvas() {
        let canvas = CanvasSize(width: 10, height: 10)
        let crop = FakeCrop().setting(.width, to: 50, in: PixelRect(x: 2, y: 2, width: 4, height: 4),
                                      aspect: .free, canvas: canvas)
        #expect(crop == PixelRect(x: 2, y: 2, width: 8, height: 4))
    }
}
