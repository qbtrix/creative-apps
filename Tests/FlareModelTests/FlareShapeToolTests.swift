// FlareShapeToolTests.swift (shape-tools FS-1): the Shape tool on FlareWorkspace's ShapeTarget stubs. The tool
// and its picked options work now; drawing (`addShape`) waits on FS-6, so those tests are disabled until it lands.
import FlareCore
import SuiteKernel
import Testing
@testable import FlareModel

struct FlareShapeToolTests {
    static let box = Rect(minX: 0, minY: 0, maxX: 100, maxY: 100)

    static func open() -> FlareWorkspace {
        var ws = FlareWorkspace(services: .fake())
        ws.newDocument()
        return ws
    }

    /// A path's anchor points: each element's end, the closing point dropped.
    static func points(_ path: FlarePath) -> [FlareCore.Point] {
        path.elements.compactMap { e -> FlareCore.Point? in
            switch e { case .move(let p), .line(let p), .quad(_, let p), .cubic(_, _, let p): p; case .close: nil }
        }
    }

    @Test func shapeIsAToolWithKeyUAndAReasonUntilItDraws() {
        #expect(FlareTool.allCases.contains(.shape))
        #expect(FlareTool.shape.unavailableHelp == FlareTool.shapeHelp)
        #expect(!FlareTool.shape.isEnabled)
        #expect(FlareWorkspace(services: .fake()).toolHelp(.shape) == FlareTool.shapeHelp)
        #expect(Self.open().toolHelp(.shape) == FlareTool.shapeHelp)
    }

    @Test func toolStartsOnAFivePointStar() {
        let ws = FlareWorkspace(services: .fake())
        #expect(ws.shapeTool == .defaults(.star))
        #expect(ws.shapeTool.kind == .star && ws.shapeTool.points == 5)
    }

    @Test func pickShapeToolRecordsTheSpecAsViewState() {
        var ws = Self.open()
        let arrow = ShapeIntent.kind(.arrow).applied(to: ws.shapeTool)
        ws.pickShapeTool(arrow)
        #expect(ws.shapeTool == arrow)
        ws.pickShapeTool(ShapeIntent.points(7).applied(to: .defaults(.star)))
        #expect(ws.shapeTool.kind == .star && ws.shapeTool.points == 7)
        #expect(!ws.canUndo, "picking options is view state, not an undo step")
    }

    @Test func addShapeRefusesUntilTheKernelLands() {
        var ws = Self.open()
        let layers = ws.layers.count
        #expect(throws: ShapeRefusal.self) { try ws.addShape(.defaults(.star), in: Self.box, name: "Star") }
        #expect(ws.layers.count == layers && !ws.canUndo)
    }

    @Test(.disabled("waits on FS-6")) func addShapeAddsOneLayerAsOneStep() throws {
        var ws = Self.open()
        let layers = ws.layers.count
        let id = try ws.addShape(.defaults(.star), in: Self.box, name: "Star")
        #expect(ws.layers.count == layers + 1 && ws.selectedLayerID == id)
        let path = try ShapeRules.path(.defaults(.star), in: Self.box)
        let shape = ws.layers.first { $0.id == id }?.shapes.first
        #expect(shape?.points == Self.points(path))
        #expect(ws.undoActionName == "Undo Star")
    }

    @Test(.disabled("waits on FS-6")) func drawIsOneStep() throws {
        var ws = Self.open()
        let before = ws.layers.count
        _ = try ws.addShape(.defaults(.arrow), in: Self.box, name: "Arrow")
        ws.undo()
        #expect(ws.layers.count == before && !ws.canUndo)
    }

    @Test(.disabled("waits on FS-6")) func starHasTenPointsFirstAtTheTop() throws {
        var ws = Self.open()
        let id = try ws.addShape(.defaults(.star), in: Self.box, name: "Star")
        let points = ws.layers.first { $0.id == id }?.shapes.first?.points ?? []
        #expect(points.count == 10)
        #expect(points.first == FlareCore.Point(x: 50, y: 0))
    }
}
