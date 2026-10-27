// PhotoRenderRouteImagingTests.swift: the dispatcher route's adjustments are
// ImagingProgram's steps (suite-imaging IM-8s). Each section on its own, run
// through `applied(to:on:)`, lands within one 8-bit level of
// ImagingProgram.adjustments run step by step on the CPU (runImaging), and
// levels then the curve, the shared order, is what the route runs. Runs on
// Linux and macOS.
import CoreRaster
import CoreRender
import SuiteImaging
import Testing

@testable import PhotoModel

@Suite struct PhotoRenderRouteImagingTests {
    /// A 16 by 16 ramp: red across, green down, blue mixed, opaque.
    static func ramp() throws -> PixelBuffer {
        var buffer = try PixelBuffer(width: 16, height: 16)
        for y in 0..<16 {
            for x in 0..<16 {
                let r = Float(x) / 15, g = Float(y) / 15
                try buffer.setPixel(x: x, y: y, RGBA(r: r, g: g, b: (r + g) / 2, a: 1))
            }
        }
        return buffer
    }

    /// `settings` applied to the ramp through a CPU route's dispatcher.
    static func dispatched(_ settings: AdjustmentSettings) throws -> PixelBuffer {
        let dispatcher = PhotoRenderRoute(preferred: nil).dispatcher()
        let result = try settings.applied(to: dispatcher.surface(ramp()), on: dispatcher)
        defer { dispatcher.release(result) }
        return try dispatcher.read(result)
    }

    /// `steps` run on the ramp in order on the CPU, as `runImaging` runs them:
    /// tone steps on CoreRender's CPU backend, hue/saturation through Photo's
    /// matrix (the route and the export move to core's together in IM-8).
    static func reference(_ steps: [ToneAdjustment], _ settings: AdjustmentSettings) throws -> PixelBuffer {
        var buffer = try ramp()
        for step in steps { buffer = try settings.runImaging([step], on: buffer) }
        return buffer
    }

    /// The largest channel difference between `a` and `b`, in 8-bit levels.
    static func levels(_ a: PixelBuffer, _ b: PixelBuffer) throws -> Float {
        var worst: Float = 0
        for y in 0..<a.height {
            for x in 0..<a.width {
                let p = try a.pixel(x: x, y: y), q = try b.pixel(x: x, y: y)
                for d in [p.r - q.r, p.g - q.g, p.b - q.b, p.a - q.a] { worst = max(worst, abs(d) * 255) }
            }
        }
        return worst
    }

    static let curve = [CurvePoint(x: 0, y: 0), CurvePoint(x: 0.3, y: 0.6), CurvePoint(x: 1, y: 1)]

    /// Each section alone, away from its identity, the others switched off.
    static let sections: [(AdjustmentKind, [AdjustmentEdit])] = [
        (.exposure, [.exposure(0.7)]),
        (.levels, [.blackPoint(0.1), .whitePoint(0.85), .gamma(1.6)]),
        (.curves, [.curvePoints(curve)]),
        (.hueSaturation, [.hue(40), .saturation(-30), .lightness(10)]),
    ]

    static func only(_ kind: AdjustmentKind, _ edits: [AdjustmentEdit]) -> AdjustmentSettings {
        var settings = AdjustmentSettings()
        for edit in edits { settings.apply(edit) }
        for other in AdjustmentKind.allCases where other != kind { settings.apply(.setEnabled(other, false)) }
        return settings
    }

    @Test(arguments: sections.indices)
    func everyStepMapped(_ index: Int) throws {
        let (kind, edits) = Self.sections[index]
        let settings = Self.only(kind, edits)
        let steps = ImagingProgram.adjustments(settings.imaging)
        #expect(steps.count == 1, "\(kind) gives one step")
        let ramp = try Self.ramp()
        let dispatched = try Self.dispatched(settings)
        #expect(try Self.levels(dispatched, ramp) > 2, "\(kind) left the ramp as it was")
        #expect(try Self.levels(dispatched, Self.reference(steps, settings)) <= 1, "\(kind) is off ImagingProgram's step")
    }

    @Test func sharedOrder() throws {
        var settings = AdjustmentSettings()
        for edit: AdjustmentEdit in [.blackPoint(0.1), .whitePoint(0.85), .gamma(1.6), .curvePoints(Self.curve)] {
            settings.apply(edit)
        }
        let steps = ImagingProgram.adjustments(settings.imaging)
        #expect(steps.count == 2)
        let dispatched = try Self.dispatched(settings)
        #expect(try Self.levels(dispatched, Self.reference(steps, settings)) <= 1, "the route runs levels, then the curve")
        #expect(try Self.levels(dispatched, Self.reference(steps.reversed(), settings)) > 1, "the order shows in the picture")
    }
}
