// HaloShapeTests.swift: shape-tools MJ-HS, the Model walk. A layer's shape
// spec saves under its own key and old projects open without one, and with no
// composition the Shape button says why (HS-1); drawing a star is one undo
// step at the playhead's span, the picked tool stays, a bad spec is refused,
// and the renderer draws a layer's spec, not its ellipse (HS-5).
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
