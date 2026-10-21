// GroupPickTests.swift (area-selection AR-2 written, AR-4 turns on): the group-aware click on a three-level tree,
// written from the packet before its bodies. `groupSpecsHaveSchemas` is AR-1's and runs now.
import Testing
import SuiteKernel

/// A payload for the fixture: a container flag and nothing else.
private struct PickItem: LayerPayload { var holdsChildren: Bool }

private func pickLeaf(_ id: String) -> LayerNode<PickItem> { LayerNode(id: id, name: id, payload: PickItem(holdsChildren: false)) }
private func pickGroup(_ id: String, locked: Bool = false, _ children: [LayerNode<PickItem>]) -> LayerNode<PickItem> {
    LayerNode(id: id, name: id, isLocked: locked, children: children, payload: PickItem(holdsChildren: true))
}

/// Three levels: `card` holds `face` (which holds `title` and `photo`) and `back`; `bg` and `empty` sit at the
/// root beside it; `vault` is a locked group holding `gold`.
private let tree = LayerTree([
    pickLeaf("bg"),
    pickGroup("card", [pickGroup("face", [pickLeaf("title"), pickLeaf("photo")]), pickLeaf("back")]),
    pickGroup("empty", []),
    pickGroup("vault", locked: true, [pickLeaf("gold")]),
])

/// The fixture tree as a pick target: every click hits `title`.
private struct PickDoc: GroupPickTarget {
    var pickTree: LayerTree<PickItem> { tree }
    var groupScope = GroupScope.root, pickedLayer: String?
    func layerHit(at point: Point) -> String? { "title" }
    mutating func setGroupPick(_ id: String?, scope: GroupScope) throws { (pickedLayer, groupScope) = (id, scope) }
}

@Suite struct GroupPickTests {
    static let card = GroupScope(path: ["card"]), face = GroupScope(path: ["card", "face"])

    /// AR-1: the three specs build a catalog, each a view change with an object schema.
    @Test func groupSpecsHaveSchemas() throws {
        let specs = GroupPick.specs(PickDoc.self)
        #expect(try CommandCatalog(app: "test", specs, history: { _ in History<Int>() }).ids.count == 3)
        expectSelectionSpecs(specs, ["select.pick", "select.enter-group", "select.exit-group"], .view)
        #expect(GroupScope.root.path.isEmpty && GroupScope(path: ["card"]) == Self.card)
    }

    @Test(.disabled("waits on AR-4")) func clickPicksTheOutermostGroupInScope() {
        let picks = [("title", GroupScope.root, "card"), ("bg", .root, "bg"), ("title", Self.card, "face"), ("back", Self.card, "back"),
                     ("title", Self.face, "title")]
        for (hit, scope, picked) in picks { #expect(GroupPick.target(hit: hit, scope: scope, deep: false, in: tree) == picked, "\(hit)") }
        // Outside the entered group, or off the tree, the click picks nothing.
        #expect(GroupPick.target(hit: "bg", scope: Self.card, deep: false, in: tree) == nil && GroupPick.target(hit: "nowhere", scope: .root, deep: false, in: tree) == nil)
    }

    @Test(.disabled("waits on AR-4")) func commandPicksTheDeepestAndLockedPicksNothing() {
        #expect(GroupPick.target(hit: "title", scope: .root, deep: true, in: tree) == "title" && GroupPick.target(hit: "photo", scope: Self.card, deep: true, in: tree) == "photo")
        #expect(GroupPick.target(hit: "gold", scope: .root, deep: false, in: tree) == nil && GroupPick.target(hit: "gold", scope: .root, deep: true, in: tree) == nil)
    }

    @Test(.disabled("waits on AR-4")) func enterAndExitOneLevel() {
        #expect(GroupPick.entering("card", scope: .root, in: tree) == Self.card)
        #expect(GroupPick.entering("face", scope: Self.card, in: tree) == Self.face)
        #expect(GroupPick.entering("bg", scope: .root, in: tree) == nil && GroupPick.entering("empty", scope: .root, in: tree) == nil)
        #expect(GroupPick.exiting(Self.face) == Self.card && GroupPick.exiting(Self.card) == .root && GroupPick.exiting(.root) == .root)
    }

    @Test(.disabled("waits on AR-4")) func commandsPickEnterAndExit() throws {
        let catalog = try CommandCatalog(app: "test", GroupPick.specs(PickDoc.self), history: { _ in History<Int>() })
        var doc = PickDoc()
        let at: JSONValue = .object(["x": .number(5), "y": .number(5)]), none: JSONValue = .object([:])
        #expect(try catalog.run("select.pick", params: at, on: &doc).result == .object(["id": .string("card")]))
        _ = try catalog.run("select.enter-group", params: none, on: &doc)
        #expect(doc.groupScope == Self.card && doc.pickedLayer == nil)
        for (id, params) in [("select.pick", at), ("select.enter-group", none), ("select.exit-group", none)] { _ = try catalog.run(id, params: params, on: &doc) }
        #expect(doc.groupScope == Self.card && doc.pickedLayer == "face")
        #expect(catalog.availability("select.exit-group", on: PickDoc()).why != nil)
    }
}
