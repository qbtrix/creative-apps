// HaloStrokeJobTests.swift: stroke-style HK-6, RJ-H30
// (`Tests/RealJobs/halo/star-stroke/`). A six-point star drawn by command,
// filled with a linear gradient and given an 8 pt stroke, renders frame 0 to
// the reference, and the reference shows the stroke's black on the star's
// edge and the gradient's colour at its centre. Linux and macOS.
import Foundation
@testable import HaloModel
import SuiteKernel
import Testing

@Suite struct HaloStrokeJobTests {
    /// The render matches the reference (one 1080p render), and the reference
    /// shows the stroke on the edge and the gradient inside.
    @Test func theStarStrokeJobPassesAndShowsTheStrokeOverTheGradient() throws {
        #expect(try HaloJob.check("star-stroke") == [])
        let png = try HaloJob.decodePNG(
            Data(contentsOf: HaloJob.root.appendingPathComponent("star-stroke/expected/empty-1080p-0.png")))
        func pixel(_ x: Int, _ y: Int) -> [UInt8] {
            let at = (y * png.width + x) * 4
            return at >= 0 && at + 4 <= png.rgba.count ? Array(png.rgba[at..<(at + 4)]) : []
        }
        func near(_ a: [UInt8], _ b: [UInt8]) -> Bool { a.count == 4 && zip(a, b).allSatisfy { abs(Int($0) - Int($1)) <= 2 } }
        // The top point's tip sits on y = 340; 4 px below it is inside the 8 pt band.
        let edge = pixel(960, 344)
        #expect(near(edge, [0, 0, 0, 255]), "the star's top edge is the stroke's black: \(edge)")
        let centre = pixel(960, 540), want = try Self.gradientCentre()
        #expect(near(centre, want), "the centre is the gradient's colour \(want): \(centre)")
    }

    /// The colour the gradient alone paints at the star's centre: the same
    /// steps without the stroke, rendered.
    static func gradientCentre() throws -> [UInt8] {
        var doc = try HaloHeadless.open(try HaloHeadlessTests.input("star-stroke", "empty-1080p.halo"), name: "empty-1080p.halo")
        let steps: [CommandEnvelope] = [
            CommandEnvelope(id: "shape.draw", params: .object([
                "kind": .string("star"), "points": .number(6), "innerRatio": .number(0.5),
                "x": .number(760), "y": .number(340), "w": .number(400), "h": .number(400),
            ])),
            CommandEnvelope(id: "fill.type", params: .object(["type": .string("linear")])),
        ]
        let report = HaloHeadless.catalog.runBatch(steps, on: &doc, atomic: true)
        #expect(report.stoppedAt == nil)
        let frame = try HaloJob.produced(doc, .object(["frame": .number(0)]))
        let at = (540 * frame.width + 960) * 4
        return at >= 0 && at + 4 <= frame.rgba.count ? Array(frame.rgba[at..<(at + 4)]) : []
    }
}
