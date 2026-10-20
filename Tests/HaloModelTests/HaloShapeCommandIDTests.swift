// HaloShapeCommandIDTests.swift: shape-tools HS-6. Halo's catalog lists the
// kernel's `shape.draw` and `tool.shape`, the headless catalog runs them, and
// RJ-H35 (`Tests/RealJobs/halo/star-layer/`) draws a six-point star by command
// whose frame 0 shows the layer colour at the top point and the background on
// the rim between two outer points, where an ellipse would still cover.
// Linux and macOS.
import Foundation
@testable import HaloModel
import SuiteKernel
import Testing

@Suite struct HaloShapeCommandIDTests {
    @Test func theShapeCommandsAreListed() throws {
        for id in ["shape.draw", "tool.shape"] {
            #expect(HaloProject.catalog.ids.contains(id), "\(id)")
            #expect(HaloHeadless.catalog.ids.contains(id), "\(id)")
        }
        #expect(HaloProject.catalog.ids.count == HaloCommand.allCases.count + 2)
    }

    @Test func toolShapeKeepsThePickedTool() throws {
        var project = try HaloShapeTests.project()
        let command = ShapeIntent.points(8).command
        _ = try HaloProject.catalog.run(command.id, params: command.params, on: &project)
        #expect(project.shapeTool.kind == .star && project.shapeTool.points == 8)
        #expect(project.history.undo.isEmpty)
    }

    /// The render matches the reference (one 1080p render, slow in debug), and the reference shows a star.
    @Test func theStarJobPassesAndShowsTheStarNotAnEllipse() throws {
        #expect(try HaloJob.check("star-layer") == [])
        let png = try HaloJob.decodePNG(
            Data(contentsOf: HaloJob.root.appendingPathComponent("star-layer/expected/empty-1080p-0.png")))
        func pixel(_ x: Int, _ y: Int) -> [UInt8] {
            let at = (y * png.width + x) * 4
            return at >= 0 && at + 4 <= png.rgba.count ? Array(png.rgba[at..<(at + 4)]) : []
        }
        let color = HaloLayerKind.shape.defaultColor
        let want = [color.red, color.green, color.blue].map { UInt8(($0 * 255).rounded()) } + [255]
        let top = pixel(960, 345), rim = pixel(1055, 376)
        #expect(top.count == 4 && zip(top, want).allSatisfy { abs(Int($0) - Int($1)) <= 2 }, "the top point: \(top)")
        #expect(rim == [0, 0, 0, 0], "the rim between two points, inside the box's ellipse: \(rim)")
    }
}
