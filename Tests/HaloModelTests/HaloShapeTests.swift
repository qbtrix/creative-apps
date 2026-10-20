// HaloShapeTests.swift: shape-tools MJ-HS, the Model walk. A layer's shape
// spec saves under its own key and old projects open without one, and with no
// composition the Shape button says why (HS-1); drawing a star is one undo
// step at the playhead's span, the picked tool stays, a bad spec is refused,
// and the renderer draws a layer's spec, not its ellipse (HS-5).
// HaloShapeCommandIDTests (HS-6): Halo's catalog lists the kernel's
// `shape.draw` and `tool.shape`, the headless catalog runs them, and RJ-H35
// (`Tests/RealJobs/halo/star-layer/`) draws a six-point star by command whose
// frame 0 shows the layer colour at the top point and the background on the
// rim between two outer points, where an ellipse would still cover.
// Linux and macOS.
import Foundation
@testable import HaloModel
import SuiteKernel
import Testing

@Suite struct HaloShapeTests {
    static let star = ShapeSpec(kind: .star, points: 6, innerRatio: 0.5)
    static let box = Rect(minX: 760, minY: 340, maxX: 1160, maxY: 740)

    /// `three-layers`, its composition selected.
    static func project() throws -> HaloProject {
        var project = HaloProject(services: .fake)
        project.restore(try #require(HaloFixtures.project("three-layers")))
        return project
    }

    @Test func oldProjectsOpenWithoutAShape() throws {
        let state = try #require(HaloFixtures.project("three-layers"))
        let data = try JSONEncoder().encode(state)
        #expect(String(decoding: data, as: UTF8.self).contains("\"shape\":") == false)  // the key, not a kind's value
        let decoded = try JSONDecoder().decode(HaloDocumentState.self, from: data)
        #expect(decoded == state)
        #expect(decoded.compositions.flatMap(\.layers).allSatisfy { $0.shape == nil })
    }

    @Test func aShapeSavesUnderItsKeyAndComesBack() throws {
        var layer = HaloLayer(
            id: "s", name: "Star", kind: .shape, inFrame: 0, outFrame: 10, color: HaloLayerKind.shape.defaultColor)
        layer.shape = Self.star
        let data = try JSONEncoder().encode(layer)
        #expect(String(decoding: data, as: UTF8.self).contains("\"shape\":"))
        let decoded = try JSONDecoder().decode(HaloLayer.self, from: data)
        #expect(decoded.shape == Self.star)
        #expect(decoded.withID("t").shape == Self.star)
    }

    @Test func noCompositionSaysWhy() throws {
        var project = HaloProject(services: .fake)
        #expect(project.selectedComposition == nil)
        #expect(project.shapeHelp == "Make a composition first.")
        #expect(throws: (any Error).self) { try project.addShape(Self.star, in: Self.box, name: "Star") }
        #expect(project.history.undo.isEmpty)
    }

    @Test func aCompositionTakesShapes() throws {
        let project = try Self.project()
        #expect(project.shapeHelp == nil)
    }

    @Test func pickingKeepsTheTool() throws {
        var project = try Self.project()
        project.pickShapeTool(Self.star)
        #expect(project.shapeTool == Self.star)
        project.runShape(.points(8))
        #expect(project.shapeTool.points == 8)
    }

    @Test func drawingAddsOneSelectedShapeLayerAsOneStep() throws {
        var project = try Self.project()
        let before = try #require(project.selectedComposition)
        let id = try project.addShape(Self.star, in: Self.box, name: "Star")
        let comp = try #require(project.selectedComposition)
        #expect(comp.layers.count == before.layers.count + 1)
        let layer = try #require(project.selectedLayer)
        #expect(layer.id == id && layer.name == "Star" && layer.kind == .shape)
        #expect(layer.shape == Self.star)
        #expect(layer.inFrame == comp.playheadFrame)
        #expect(project.history.undo.count == 1)
    }

    @Test func aBadSpecIsRefusedAndAddsNothing() throws {
        var project = try Self.project()
        let before = project.document
        #expect(throws: ShapeRefusal.self) {
            try project.addShape(ShapeSpec(kind: .polygon, sides: 2), in: Self.box, name: "Polygon")
        }
        #expect(project.document == before)
        #expect(project.history.undo.isEmpty)
    }

    @Test func drawIsOneStep() throws {
        var project = try Self.project()
        let before = project.document
        let params: JSONValue = .object([
            "kind": .string("star"), "points": .number(6), "innerRatio": .number(0.5),
            "x": .number(760), "y": .number(340), "w": .number(400), "h": .number(400),
        ])
        let id = try HaloProject.catalog.run("shape.draw", params: params, on: &project).result
        let layer = try #require(project.selectedLayer)
        #expect(id == .object(["id": .string(layer.id)]))
        #expect(layer.name == "Draw Star" && layer.shape == Self.star)
        #expect(layer.rect == HaloLayerRect(x: 760, y: 340, width: 400, height: 400))
        #expect(project.history.undo.count == 1)
        project.undo()
        #expect(project.document == before)
    }

    @Test func specDrawsPath() throws {
        let bounds = HaloLayerRect(x: 760, y: 340, width: 400, height: 400)
        func item(_ shape: ShapeSpec?, _ matrix: HaloMatrix = .identity) -> HaloDrawItem {
            HaloDrawItem(
                layerID: "s", kind: .shape, bounds: bounds, matrix: matrix, opacity: 1,
                color: HaloLayerKind.shape.defaultColor, blendMode: .normal, shape: shape)
        }
        #expect(HaloOutlines.outline(of: item(nil)) == .ellipse(bounds))
        guard case .polygon(let points)? = HaloOutlines.outline(of: item(Self.star, .translation(x: 10, y: 0))) else {
            Issue.record("a star is a polygon")
            return
        }
        #expect(points.count == 12)
        func has(_ x: Double, _ y: Double) -> Bool { points.contains { abs($0.x - x) < 1e-6 && abs($0.y - y) < 1e-6 } }
        #expect(has(970, 340), "the top point, moved by the matrix")
        #expect(has(1020, 540 - 100 * 3.0.squareRoot() / 2), "the first inner point, at half the radius")
    }
}

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
