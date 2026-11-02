// PlacedVectorPixelsTests.swift: SuiteImaging's shared drawing of a placed SVG. A vector scales into the box it is
// drawn at, each item's contours fill even-odd in its colour and opacity, and a nil fill paints nothing.
import CoreRaster
import SuiteImaging
import SuiteKernel
import Testing

@Suite struct PlacedVectorPixelsTests {
    static let square = [Point(x: 0, y: 0), Point(x: 10, y: 0), Point(x: 10, y: 10), Point(x: 0, y: 10)]
    static let hole = [Point(x: 3, y: 3), Point(x: 7, y: 3), Point(x: 7, y: 7), Point(x: 3, y: 7)]

    @Test func aVectorScalesIntoItsBoxAndFillsEvenOdd() throws {
        let item = PlacedVector.Item(contours: [Self.square, Self.hole], fill: .solid(FillColor(r: 0, g: 0, b: 1)))
        let out = try PlacedVectorPixels.pixels(PlacedVector(size: Size(width: 10, height: 10), items: [item]), width: 20, height: 20)
        #expect(out.width == 20 && out.height == 20)
        #expect(try out.pixel(x: 2, y: 2) == RGBA(r: 0, g: 0, b: 1, a: 1))
        #expect(try out.pixel(x: 10, y: 10).a == 0, "the hole stays clear")
        #expect(try out.pixel(x: 18, y: 18).b == 1, "the square fills the whole doubled box")
    }

    @Test func opacityScalesAndANilFillPaintsNothing() throws {
        let half = PlacedVector.Item(contours: [Self.square], fill: .solid(FillColor(r: 1, g: 0, b: 0)), opacity: 0.5)
        let none = PlacedVector.Item(contours: [Self.square], fill: nil)
        let out = try PlacedVectorPixels.pixels(PlacedVector(size: Size(width: 10, height: 10), items: [half]), width: 10, height: 10)
        #expect(abs(try out.pixel(x: 5, y: 1).a - 0.5) < 0.01)
        let empty = try PlacedVectorPixels.pixels(PlacedVector(size: Size(width: 10, height: 10), items: [none]), width: 10, height: 10)
        #expect(try empty.pixel(x: 5, y: 5).a == 0)
    }
}
