// AnchorCommandsTests.swift (anchor-parenting AN-2, on since AN-4):
// transform.set-anchor, layer.set-parent and layer.new-null on a small fake
// document. Parenting and clearing keep every layer where it is on screen, a
// cycle is refused, `{at: center}` lands on the box centre, and each command
// is one write. AnchorSpecShapeTests (AN-1) runs now: the three specs exist
// with schemas their examples pass.
import Foundation
import Testing
import SuiteKernel

/// A layer of the fake: its placement and its box in layer space.
private struct FakeLayer: LayerPayload {
    var placement: Placement
    var box: Rect
    var holdsChildren: Bool { false }
}

/// The fake document: a flat layer tree whose placements the commands read and write.
private final class FakeAnchorDoc: AnchorTarget, ParentTarget {
    var layerTree: LayerTree<FakeLayer> { didSet { treeWrites += 1 } }
    var placementWrites = 0, treeWrites = 0, minted = 0

    init(_ layers: [(String, Placement, Rect)]) {
        layerTree = LayerTree(layers.map { LayerNode(id: $0.0, name: $0.0, payload: FakeLayer(placement: $0.1, box: $0.2)) })
    }

    func placement(of id: String) -> Placement? { layerTree.node(id)?.payload.placement }
    func bounds(of id: String) -> Rect? { layerTree.node(id)?.payload.box }
    func setPlacement(_ p: Placement, of id: String) throws {
        placementWrites += 1
        _ = layerTree.update(id) { $0.payload.placement = p }
    }
    func local(_ node: LayerNode<FakeLayer>) -> Matrix { node.payload.placement.matrix }
    /// `world` back into a placement with the anchor unchanged (no shear in these tests).
    func keepPlace(_ node: inout LayerNode<FakeLayer>, world: Matrix) {
        let o = world.apply(Point(x: 0, y: 0)), ex = world.apply(Point(x: 1, y: 0)), ey = world.apply(Point(x: 0, y: 1))
        let (ux, uy, vx, vy) = (ex.x - o.x, ex.y - o.y, ey.x - o.x, ey.y - o.y)
        let turn = atan2(uy, ux), sx = (ux * ux + uy * uy).squareRoot(), sy = -vx * sin(turn) + vy * cos(turn)
        var p = node.payload.placement
        let at = world.apply(Point(x: p.anchorX, y: p.anchorY))
        (p.x, p.y, p.scaleX, p.scaleY, p.rotation) = (at.x, at.y, sx, sy, turn * 180 / .pi)
        node.payload.placement = p
    }
    func newNull(named name: String) throws -> String {
        minted += 1
        let id = "null-\(minted)"
        layerTree.roots.append(LayerNode(id: id, name: name, payload: FakeLayer(placement: .identity,
                                                                               box: Rect(minX: 0, minY: 0, maxX: 100, maxY: 100))))
        return id
    }

    /// The layer's four box corners on the page, through its parents.
    func worldCorners(_ id: String) -> [Point] {
        let world = layerTree.worldPlacement(of: id) { local($0) }
        guard let b = bounds(of: id) else { return [] }
        return [Point(x: b.minX, y: b.minY), Point(x: b.maxX, y: b.minY), Point(x: b.maxX, y: b.maxY), Point(x: b.minX, y: b.maxY)]
            .map(world.apply)
    }
}

private func same(_ a: [Point], _ b: [Point]) -> Bool {
    a.count == b.count && zip(a, b).allSatisfy { abs($0.x - $1.x) < 1e-6 && abs($0.y - $1.y) < 1e-6 }
}

private let square = Rect(minX: 0, minY: 0, maxX: 50, maxY: 50)

/// A turned hand and a scaled, turned arm, neither following anything.
private func armAndHand() -> FakeAnchorDoc {
    FakeAnchorDoc([("arm", Placement(x: 100, y: 80, scaleX: 2, scaleY: 2, rotation: 15, anchorX: 25, anchorY: 25), square),
                   ("hand", Placement(x: 200, y: 100, rotation: 30, anchorX: 10, anchorY: 40), square)])
}

@Suite struct AnchorCommandsTests {
    /// Parenting a turned child to a scaled parent leaves its world corners unchanged; clearing it too.
    @Test func parentingAndClearingKeepPlace() throws {
        let doc = armAndHand(), before = doc.worldCorners("hand")
        try AnchorCommands.run("layer.set-parent", .object(["id": .string("hand"), "parent": .string("arm")]), anchor: doc, parent: doc)
        #expect(doc.layerTree.node("hand")?.followsID == "arm" && same(doc.worldCorners("hand"), before))
        try AnchorCommands.run("layer.set-parent", .object(["id": .string("hand"), "parent": .null]), anchor: doc, parent: doc)
        #expect(doc.layerTree.node("hand")?.followsID == nil && same(doc.worldCorners("hand"), before), "clear keeps place")
    }

    /// A parent that already follows the layer is refused with a sentence, and nothing changes.
    @Test func refusesCycle() throws {
        let doc = armAndHand()
        try AnchorCommands.run("layer.set-parent", .object(["id": .string("hand"), "parent": .string("arm")]), anchor: doc, parent: doc)
        let tree = doc.layerTree
        let error = #expect(throws: CatalogError.self) {
            try AnchorCommands.run("layer.set-parent", .object(["id": .string("arm"), "parent": .string("hand")]), anchor: doc, parent: doc)
        }
        if case .failed(_, let message)? = error { #expect(message.hasSuffix(".")) } else { Issue.record("not a sentence: \(String(describing: error))") }
        #expect(doc.layerTree == tree)
    }

    /// `{at: center}` puts the anchor on the box centre and the layer stays put; `keepPlace: false` moves it.
    @Test func setAnchorAtCentreKeepsPlace() throws {
        let doc = armAndHand(), before = doc.worldCorners("hand")
        try AnchorCommands.run("transform.set-anchor", .object(["id": .string("hand"), "at": .string("center")]), anchor: doc, parent: doc)
        let p = try #require(doc.placement(of: "hand"))
        #expect(p.anchorX == 25 && p.anchorY == 25 && same(doc.worldCorners("hand"), before))
        try AnchorCommands.run("transform.set-anchor", .object(["id": .string("hand"), "x": .number(0), "y": .number(0),
                                                                "keepPlace": .bool(false)]), anchor: doc, parent: doc)
        let loose = try #require(doc.placement(of: "hand"))
        #expect(loose.anchorX == 0 && loose.anchorY == 0 && loose.x == p.x && loose.y == p.y)
    }

    /// An anchor change and a parent change are one write (one undo step) each.
    @Test func oneStep() throws {
        let doc = armAndHand()
        try AnchorCommands.run("transform.set-anchor", .object(["id": .string("arm"), "at": .string("topLeft")]), anchor: doc, parent: doc)
        #expect(doc.placementWrites == 1)
        let writes = doc.treeWrites
        try AnchorCommands.run("layer.set-parent", .object(["id": .string("hand"), "parent": .string("arm")]), anchor: doc, parent: doc)
        #expect(doc.treeWrites == writes + 1)
    }

    /// An unknown layer or parent, and an anchor with no point, are refused with a sentence and write nothing.
    @Test func refusesWhatItCannotDo() throws {
        let doc = armAndHand(), tree = doc.layerTree
        let asks: [(String, JSONValue)] = [
            ("layer.set-parent", .object(["id": .string("leg"), "parent": .string("arm")])),
            ("layer.set-parent", .object(["id": .string("hand"), "parent": .string("leg")])),
            ("layer.set-parent", .object(["id": .string("hand"), "parent": .string("hand")])),
            ("transform.set-anchor", .object(["id": .string("leg"), "at": .string("center")])),
            ("transform.set-anchor", .object(["id": .string("hand"), "x": .number(3)])),
        ]
        for (id, params) in asks {
            let error = #expect(throws: CatalogError.self) { try AnchorCommands.run(id, params, anchor: doc, parent: doc) }
            if case .failed(let failing, let message)? = error {
                #expect(failing == id && message.hasSuffix(".") && !message.contains("("), "\(message)")
            } else { Issue.record("\(id) \(params): not a sentence: \(String(describing: error))") }
        }
        #expect(doc.layerTree == tree && doc.placementWrites == 0)
    }

    /// With no app target the commands are unavailable, said in a sentence.
    @Test func needsATarget() {
        #expect(throws: CatalogError.self) { try AnchorCommands.run("layer.new-null", .object([:]), anchor: nil, parent: nil) }
        #expect(throws: CatalogError.self) {
            try AnchorCommands.run("transform.set-anchor", .object(["id": .string("a"), "at": .string("center")]), anchor: nil, parent: nil)
        }
    }

    /// New Null adds one empty layer that can be parented to.
    @Test func newNullAddsALayer() throws {
        let doc = armAndHand()
        try AnchorCommands.run("layer.new-null", .object(["name": .string("Null 1")]), anchor: doc, parent: doc)
        let null = try #require(doc.layerTree.roots.last)
        #expect(doc.layerTree.roots.count == 3 && null.name == "Null 1")
        try AnchorCommands.run("layer.set-parent", .object(["id": .string("hand"), "parent": .string(null.id)]), anchor: doc, parent: doc)
        #expect(doc.layerTree.node("hand")?.followsID == null.id)
    }
}

@Suite struct AnchorSpecShapeTests {
    /// AN-1: the three specs exist in order, each an edit with a schema its example passes.
    @Test func threeSpecsWithSchemas() {
        let specs = AnchorCommands.specs
        #expect(specs.map(\.id) == ["transform.set-anchor", "layer.set-parent", "layer.new-null"])
        for spec in specs {
            #expect(spec.kind == .edit && spec.params != .none && spec.params.validate(spec.example).isEmpty, "\(spec.id)")
            #expect(!spec.title.isEmpty && !spec.summary.isEmpty)
        }
        #expect(throws: CatalogError.self) { try AnchorCommands.run("layer.nope", .object([:]), anchor: nil, parent: nil) }
    }
}
