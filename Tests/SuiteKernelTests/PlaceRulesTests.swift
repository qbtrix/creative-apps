// PlaceRulesTests.swift (placed-images PL-1 written, PL-5 turns on): the sniff, the content id, the contain fit
// that never upscales, the cover crop that never stretches, and the reset. The assets' one-copy rule runs now.
import Foundation
import Testing
import SuiteKernel

@Suite struct PlaceRulesTests {
    static let png = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 13])
    static let wide = Size(width: 1200, height: 400), small = Size(width: 240, height: 80)
    static let canvas = Rect(minX: 0, minY: 0, maxX: 800, maxY: 600), square = Rect(minX: 0, minY: 0, maxX: 300, maxY: 300)
    static func image(_ focus: Point = Point(x: 0.5, y: 0.5)) -> PlacedImage { PlacedImage(assetID: "a", box: square, focus: focus) }

    @Test func assetsKeepOneCopyPerID() {
        let asset = { (id: String) in PlacedAsset(id: id, name: "\(id).png", format: .png, natural: Self.wide, data: Data(id.utf8)) }
        let two = PlacedAssets().adding(asset("a")).adding(asset("b"))
        var renamed = asset("a"); renamed.name = "other.png"
        #expect(two.adding(renamed).byID["a"]?.name == "a.png")
        #expect(two.pruned(keeping: ["b"]).byID.keys.sorted() == ["b"])
    }
    @Test func sniffsEachFormat() {
        #expect(PlaceRules.format(of: Self.png) == .png && PlaceRules.format(of: Data([0xFF, 0xD8, 0xFF, 0xE0])) == .jpeg)
        #expect(PlaceRules.format(of: Data("<?xml version=\"1.0\"?>\n<svg/>".utf8)) == .svg)
        #expect(PlaceRules.format(of: Data([0xEF, 0xBB, 0xBF]) + Data("  <svg/>".utf8)) == .svg)
        #expect(PlaceRules.format(of: Data("plain text".utf8)) == nil && PlaceRules.format(of: Data()) == nil)
    }
    @Test func equalBytesEqualIDs() {
        var changed = Self.png; changed[11] = 14
        #expect(PlaceRules.assetID(of: Self.png) == PlaceRules.assetID(of: Data(Self.png)) && !PlaceRules.assetID(of: Self.png).isEmpty)
        #expect(PlaceRules.assetID(of: Self.png) != PlaceRules.assetID(of: changed))
    }
    @Test func fitsCentredNeverUpscaledInside() {
        let fit = PlaceRules.fitted(natural: Self.wide, in: Self.canvas, at: nil)
        #expect(fit.width == 800 && abs(fit.height - 266.67) < 0.01 && abs((fit.minY + fit.maxY) / 2 - 300) < 1e-9)
        #expect(PlaceRules.fitted(natural: Self.small, in: Self.canvas, at: nil) == Rect(minX: 280, minY: 260, maxX: 520, maxY: 340))
        #expect(PlaceRules.fitted(natural: Self.small, in: Self.canvas, at: Point(x: 790, y: 5)) == Rect(minX: 560, minY: 0, maxX: 800, maxY: 80))
    }
    @Test func coverKeepsAspectEdgesAndReset() {
        #expect(PlaceRules.drawnRect(Self.image(), natural: Self.wide) == Rect(minX: -300, minY: 0, maxX: 600, maxY: 300))
        #expect(PlaceRules.drawnRect(Self.image(Point(x: 0, y: 0.5)), natural: Self.wide) == Rect(minX: 0, minY: 0, maxX: 900, maxY: 300))
        let past = PlaceRules.drawnRect(Self.image(Point(x: -1, y: 0.5)), natural: Self.wide)
        #expect(past.minX <= 0 && past.maxX >= 300)
        #expect(PlaceRules.resetBox(Self.image(), natural: Self.wide) == Rect(minX: 0, minY: 100, maxX: 300, maxY: 200))
    }
    // The mutation plan's named checks (Tests/mutations/SuiteKernel.PlaceRules.json).
    @Test func neverUpscales() {
        let fit = PlaceRules.fitted(natural: Self.small, in: Self.canvas, at: nil)
        #expect(fit.width == 240 && fit.height == 80)
        #expect(PlaceRules.fitted(natural: Self.wide, in: Self.canvas, at: nil).minX == 0)
    }
    @Test func coverKeepsAspect() {
        let tall = PlacedImage(assetID: "a", box: Rect(minX: 10, minY: 20, maxX: 110, maxY: 420))
        let drawn = PlaceRules.drawnRect(tall, natural: Self.wide)
        #expect(drawn == Rect(minX: -540, minY: 20, maxX: 660, maxY: 420) && drawn.width / drawn.height == 3)
    }
    @Test func focusEdgeCovers() {
        for focus in [Point(x: -1, y: 0.5), Point(x: 2, y: 0.5), Point(x: 0.5, y: 9)] {
            let drawn = PlaceRules.drawnRect(Self.image(focus), natural: Self.wide)
            #expect(drawn.minX <= 0 && drawn.maxX >= 300 && drawn.minY <= 0 && drawn.maxY >= 300)
        }
    }
    @Test func svgWithBOM() {
        #expect(PlaceRules.format(of: Data([0xEF, 0xBB, 0xBF]) + Data("\n<?xml version=\"1.0\"?><svg/>".utf8)) == .svg)
        #expect(PlaceRules.format(of: Data([0xEF, 0xBB, 0xBF]) + Data("hello".utf8)) == nil)
    }
}
