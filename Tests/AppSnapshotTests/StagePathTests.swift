// StagePathTests.swift: MP-4's StagePath (docs/blueprints/flare/features/mac-platform.md). Hand-built FlareCore
// paths reach CoreGraphics as one addCurve per cubic and one addLine per line, the matrix moves every point, colors
// land in sRGB with their channels, and a non-finite point is skipped instead of drawn. macOS only.
#if canImport(CoreGraphics)
import CoreGraphics
import FlareCore
import FlareModel
import Foundation
import Testing

@testable import FlareApp

@Suite struct StagePathTests {
    /// The number of each CGPath element type in `path`.
    private func counts(_ path: CGPath) -> [CGPathElementType: Int] {
        var counts: [CGPathElementType: Int] = [:]
        path.applyWithBlock { element in
            counts[element.pointee.type, default: 0] += 1
        }
        return counts
    }

    private func p(_ x: Double, _ y: Double) -> FlareCore.Point { FlareCore.Point(x: x, y: y) }

    /// A circle of radius 10 around the origin as four cubics (k is the usual quarter-circle handle length).
    private var ellipse: FlarePath {
        let r = 10.0
        let k = 0.5522847498 * r
        return FlarePath(elements: [
            .move(to: p(r, 0)),
            .cubic(control1: p(r, k), control2: p(k, r), to: p(0, r)),
            .cubic(control1: p(-k, r), control2: p(-r, k), to: p(-r, 0)),
            .cubic(control1: p(-r, -k), control2: p(-k, -r), to: p(0, -r)),
            .cubic(control1: p(k, -r), control2: p(r, -k), to: p(r, 0)),
            .close,
        ])
    }

    @Test func cubicsStayCurves() {
        let circle = counts(StagePath.cgPath(ellipse, transform: .identity))
        #expect(circle[.moveToPoint] == 1)
        #expect(circle[.addCurveToPoint] == 4)
        #expect(circle[.addLineToPoint] == nil)
        #expect(circle[.closeSubpath] == 1)

        let pen = FlarePath(elements: [
            .move(to: p(0, 0)),
            .cubic(control1: p(5, 10), control2: p(15, 10), to: p(20, 0)),
            .line(to: p(30, 0)),
            .cubic(control1: p(35, -10), control2: p(45, -10), to: p(50, 0)),
        ])
        let stroke = counts(StagePath.cgPath(pen, transform: .identity))
        #expect(stroke[.moveToPoint] == 1)
        #expect(stroke[.addCurveToPoint] == 2)
        #expect(stroke[.addLineToPoint] == 1)
        #expect(stroke[.closeSubpath] == nil)
    }

    @Test func translationMovesTheBounds() {
        let plain = StagePath.cgPath(ellipse, transform: .identity).boundingBoxOfPath
        let moved = StagePath.cgPath(ellipse, transform: .translation(x: 10, y: 20)).boundingBoxOfPath
        #expect(abs(moved.minX - plain.minX - 10) < 1e-9)
        #expect(abs(moved.minY - plain.minY - 20) < 1e-9)
        #expect(abs(moved.width - plain.width) < 1e-9)
        #expect(abs(moved.height - plain.height) < 1e-9)
    }

    @Test func emptyPathIsEmpty() {
        #expect(StagePath.cgPath(FlarePath(), transform: .identity).isEmpty)
    }

    @Test func colorIsSRGB() {
        let color = StagePath.cgColor(FlareColor(r: 1, g: 0.5, b: 0, a: 0.25))
        #expect((color.colorSpace?.name as String?) == (CGColorSpace.sRGB as String))
        let components = color.components ?? []
        #expect(components.count == 4)
        for (got, want) in zip(components, [1, 0.5, 0, 0.25] as [CGFloat]) {
            #expect(abs(got - want) < 1e-6)
        }
    }

    @Test func nonFinitePointIsSkipped() {
        let path = FlarePath(elements: [
            .move(to: p(0, 0)),
            .line(to: p(.nan, 5)),
            .cubic(control1: p(1, .infinity), control2: p(2, 2), to: p(3, 3)),
            .line(to: p(10, 10)),
        ])
        let drawn = StagePath.cgPath(path, transform: .identity)
        let found = counts(drawn)
        #expect(found[.moveToPoint] == 1)
        #expect(found[.addLineToPoint] == 1)
        #expect(found[.addCurveToPoint] == nil)
        let box = drawn.boundingBoxOfPath
        #expect(box.minX == 0 && box.minY == 0 && box.maxX == 10 && box.maxY == 10)
    }

    @Test func skippedMoveStartsAtTheNextPoint() {
        let path = FlarePath(elements: [.move(to: p(.nan, 0)), .line(to: p(4, 4)), .line(to: p(8, 0))])
        let found = counts(StagePath.cgPath(path, transform: .identity))
        #expect(found[.moveToPoint] == 1)
        #expect(found[.addLineToPoint] == 1)
    }
}
#endif
