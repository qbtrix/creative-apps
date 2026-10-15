// HaloOutlinesTests.swift: VP-4a's outline helper. A translate + positive
// scale matrix picks the axis-aligned mask of the world box; a rotation or a
// mirror picks the flattened polygon; the four-cubic circle stays on its
// radius; a non-finite matrix gives no outline. Runs on Linux and macOS.
import CoreRaster
import FlareCore
@testable import HaloModel
import Testing

private let box = HaloLayerRect(x: 10, y: 20, width: 40, height: 30)

@Test func translateAndPositiveScalePicksTheAxisAlignedMaskOfTheWorldBox() throws {
    let m = HaloMatrix.translation(x: 5, y: 7) * HaloMatrix.scale(x: 2, y: 3)
    let world = HaloLayerRect(x: 25, y: 67, width: 80, height: 90)
    #expect(HaloOutlines.isAxisAligned(m))
    #expect(HaloOutlines.outline(.rectangle, bounds: box, matrix: m) == .rectangle(world))
    #expect(HaloOutlines.outline(.ellipse, bounds: box, matrix: m) == .ellipse(world))

    let mask = try #require(HaloOutlines.outline(.rectangle, bounds: box, matrix: m))
        .mask(width: 200, height: 200, scaleX: 1, scaleY: 1)
    #expect(mask == (try Mask.rectangle(width: 200, height: 200, x: 25, y: 67, w: 80, h: 90)))
    let oval = try #require(HaloOutlines.outline(.ellipse, bounds: box, matrix: m))
        .mask(width: 100, height: 100, scaleX: 0.5, scaleY: 0.5)
    let expected = try Mask.ellipse(
        width: 100, height: 100, centerX: 32.5, centerY: 56, radiusX: 20, radiusY: 22.5)
    #expect(oval == expected)
}

@Test func aRotatedOrMirroredMatrixPicksThePolygon() throws {
    let rotated = HaloMatrix.translation(x: 50, y: 50) * HaloMatrix.rotation(degrees: 30)
    let mirrored = HaloMatrix.scale(x: -1, y: 1)
    for m in [rotated, mirrored, HaloMatrix.scale(x: 1, y: -2)] {
        #expect(!HaloOutlines.isAxisAligned(m))
        for shape in [HaloOutlineShape.rectangle, .ellipse] {
            guard case .polygon(let points) = HaloOutlines.outline(shape, bounds: box, matrix: m) else {
                Issue.record("expected a polygon for \(shape) at \(m)")
                continue
            }
            #expect(points.count >= 4)
        }
    }
    // The rotated rectangle's corners are the box's corners through the matrix.
    let corners = [(10.0, 20.0), (50.0, 20.0), (50.0, 50.0), (10.0, 50.0)].map {
        rotated.apply(HaloPoint(x: $0.0, y: $0.1))
    }
    let outline = HaloOutlines.outline(.rectangle, bounds: box, matrix: rotated)
    guard case .polygon(let points) = outline else { Issue.record("no polygon"); return }
    for corner in corners {
        #expect(points.contains { abs($0.x - corner.x) < 1e-9 && abs($0.y - corner.y) < 1e-9 })
    }
    let mask = try #require(outline).mask(width: 120, height: 120, scaleX: 1, scaleY: 1)
    #expect(mask.area > 0)
}

@Test func theFourCubicCircleStaysOnItsRadius() throws {
    let circle = HaloLayerRect(x: -100, y: -100, width: 200, height: 200)
    let polylines = try HaloOutlines.path(.ellipse, bounds: circle, matrix: .identity).flattened(tolerance: 0.25)
    let points = polylines.flatMap { $0 }
    #expect(points.count > 8)
    for p in points {
        #expect(abs((p.x * p.x + p.y * p.y).squareRoot() - 100) <= 0.3)
    }
}

@Test func aNonFiniteMatrixGivesNoOutline() {
    let bad = [
        HaloMatrix(a: .nan, b: 0, c: 0, d: 1, tx: 0, ty: 0),
        HaloMatrix(a: 1, b: 0, c: 0, d: 1, tx: .infinity, ty: 0),
        HaloMatrix(a: 1, b: .nan, c: 0, d: 1, tx: 0, ty: 0),
    ]
    for m in bad {
        #expect(!HaloOutlines.isAxisAligned(m))
        #expect(HaloOutlines.outline(.rectangle, bounds: box, matrix: m) == nil)
        #expect(HaloOutlines.outline(.ellipse, bounds: box, matrix: m) == nil)
    }
}

@Test func onlySolidsAndShapesHaveAnOutline() {
    func item(_ kind: HaloLayerKind) -> HaloDrawItem {
        HaloDrawItem(
            layerID: "a", kind: kind, bounds: box, matrix: .identity, opacity: 1,
            color: HaloLayerColor(red: 1, green: 0, blue: 0), blendMode: .normal)
    }
    #expect(HaloOutlines.outline(of: item(.solid)) == .rectangle(box))
    #expect(HaloOutlines.outline(of: item(.shape)) == .ellipse(box))
    #expect(HaloOutlines.outline(of: item(.text)) == nil)
    #expect(HaloOutlines.outline(of: item(.null)) == nil)
}
