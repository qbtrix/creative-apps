// PlaceLiveTests.swift (placed-images PL-8): the gallery's `place-image` page on live. Its board is a local
// PlacedImageTarget with a History: every intent runs through `PlaceCommands` in the board's catalog, a place is one
// `Place Image` step, and a focus drag (⌥-drag, Move Inside) is one step however many samples it sends. The Logo SVG
// draws its red and blue parts from `PlacedVector`, not the grey placeholder. macOS only (SuiteUI).
import CoreGraphics
import SuiteKernel
@testable import SuiteUI
import SwiftUI
import Testing

@MainActor @Suite struct PlaceLiveTests {
    static func sample(_ format: PlacedFormat) -> GalleryPlaceImage.Sample? { GalleryPlaceImage.samples.first { $0.format == format } }

    /// The board with `format`'s sample placed through `place.image`.
    static func placed(_ format: PlacedFormat) throws -> GalleryPlaceBoard {
        var board = GalleryPlaceBoard()
        let picked = try #require(Self.sample(format))
        let line = board.run(.place(name: picked.name, data: picked.data, at: nil))
        #expect(line.hasPrefix("place.image Place Image"), "the page stays on the local log: \(line)")
        return board
    }

    /// Wide PNG fits 800 × 267, centred, as one step; Logo SVG is a second image at 240 × 80, selected.
    @Test func samplesPlaceThroughPlaceImage() throws {
        var board = try Self.placed(.png)
        let wide = try #require(board.placedSelection)
        #expect(wide.asset.natural == Size(width: 1200, height: 400) && wide.asset.name == "wide.png")
        #expect(wide.image.box.width == 800 && abs(wide.image.box.minY + wide.image.box.maxY - 600) < 1e-9)
        let logo = try #require(Self.sample(.svg))
        _ = board.run(.place(name: logo.name, data: logo.data, at: nil))
        #expect(board.placedSelection?.asset.natural == Size(width: 240, height: 80))
        #expect(board.drawn.count == 2 && board.history.steps == ["Place Image", "Place Image"])
    }

    /// A box drag and a 30-sample focus drag are one step each; one undo puts the focus back at the centre.
    @Test func aFocusDragIsOneUndoStep() throws {
        var board = try Self.placed(.png)
        let start = try #require(board.placedSelection?.image)
        for n in 1...10 { _ = board.resize(start, right: start.box.maxX - Double(n) * 50, drag: "r1") }
        board.endDrag()
        #expect(board.placedSelection?.image.box.width == 300)
        let square = try #require(board.placedSelection?.image)
        for n in 1...30 {
            let line = board.moveFocus(square, by: Point(x: Double(n) * 10, y: 0), drag: "f1")
            #expect(line.hasPrefix("place.focus Move Inside"), "\(line)")
        }
        board.endDrag()
        #expect(board.history.steps == ["Place Image", "Resize", "Move Inside"])
        #expect(board.placedSelection?.image.focus == Point(x: 0, y: 0.5), "a 300-point drag right pans to the left edge")
        let undone = board.undo()
        #expect(undone && board.placedSelection?.image.focus == Point(x: 0.5, y: 0.5))
        #expect(board.placedSelection?.image.box.width == 300)
    }

    /// Reset Size at the natural aspect is refused with its reason and records nothing; after a resize it is one step.
    @Test func resetSizeRunsThroughTheCatalog() throws {
        var board = try Self.placed(.png)
        let refused = board.run(.resetSize)
        #expect(refused.hasPrefix("place.reset-size") && refused.contains("already has its own shape"), "\(refused)")
        #expect(board.history.steps == ["Place Image"])
        let start = try #require(board.placedSelection?.image)
        _ = board.resize(start, right: start.box.minX + 300, drag: "r1")
        board.endDrag()
        _ = board.run(.resetSize)
        #expect(board.history.steps == ["Place Image", "Resize", "Reset Size"])
        #expect(board.placedSelection?.image.box.height == 100)
    }

    /// The right edge grabs a resize, ⌥ inside the picture a focus drag, and anywhere else nothing.
    @Test func grabsTheEdgeOrTheInside() throws {
        let image = try #require(Self.placed(.png).placedSelection?.image)
        let middle = (image.box.minY + image.box.maxY) / 2
        #expect(GalleryPlaceBoard.grab(image, at: Point(x: image.box.maxX - 2, y: middle), option: false) == .edge)
        #expect(GalleryPlaceBoard.grab(image, at: Point(x: 400, y: middle), option: true) == .focus)
        #expect(GalleryPlaceBoard.grab(image, at: Point(x: 400, y: middle), option: false) == nil)
        #expect(GalleryPlaceBoard.grab(image, at: Point(x: 400, y: 10), option: true) == nil)
    }

    /// The Logo SVG draws its two colours: red on its left half, blue on its right, no grey.
    @Test func theSVGDrawsItsTwoColours() throws {
        let board = try Self.placed(.svg)
        let logo = try #require(board.placedSelection)
        let image = PlacedImage(assetID: logo.asset.id, box: Rect(minX: 0, minY: 0, maxX: 240, maxY: 80))
        let renderer = ImageRenderer(content: PlacedImageView(asset: logo.asset, image: image))
        renderer.scale = 1
        let cg = try #require(renderer.cgImage)
        let pixels = try #require(Self.rgba(cg))
        func at(_ x: Int, _ y: Int) -> [UInt8] { Array(pixels[((y * cg.width + x) * 4)..<((y * cg.width + x) * 4 + 3)]) }
        #expect(at(60, 40) == [255, 0, 0], "the left half drew \(at(60, 40))")
        #expect(at(180, 40) == [0, 0, 255], "the right half drew \(at(180, 40))")
    }

    /// `image`'s pixels as sRGB RGBA bytes, row by row.
    static func rgba(_ image: CGImage) -> [UInt8]? {
        var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
        guard let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4,
                space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            return true
        }
        return drawn ? bytes : nil
    }

    /// The resize cursor's strip on the canvas (view points) is exactly where a drag grabs the right edge.
    @Test func theEdgeStripIsWhereADragGrabs() throws {
        let board = try Self.placed(.png)
        let image = try #require(board.placedSelection?.image)
        let strip = GalleryPlaceImage.edgeStrip(image)
        let scale = GalleryPlaceImage.scale
        func grab(_ x: Double, _ y: Double) -> GalleryPlaceBoard.Grab? {
            GalleryPlaceBoard.grab(image, at: Point(x: x / scale, y: y / scale), option: false)
        }
        #expect(grab(strip.midX, strip.midY) == .edge)
        #expect(grab(strip.minX + 0.5, strip.minY + 0.5) == .edge && grab(strip.maxX - 0.5, strip.maxY - 0.5) == .edge)
        #expect(grab(strip.minX - 1, strip.midY) == nil && grab(strip.maxX + 1, strip.midY) == nil)
    }
}
