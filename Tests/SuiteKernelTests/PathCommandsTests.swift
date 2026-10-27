// PathCommandsTests.swift (pen-paths PN-1 written, PN-7 turns on): the twelve commands on a test target with a kernel
// `History`. Each edit run records one step named its title, a drag is one step, every why-not reads, `path.draw`
// round-trips `path.read`, and on a scaled, turned and moved layer every param and `path.read` are document space.
// Mutations: Tests/mutations/SuiteKernel.PathCommands.json.
import Testing
import SuiteKernel
/// One path in edit, its history folding steps by drag token (`FillDoc`'s pattern).
struct PathDoc: PathEditTarget {
    var penDraft: PenDraft?, pathInEdit: PathInEdit?, anchorSelection = Selection<AnchorRef>(), pathHelp: String?, history = History<PathInEdit?>()
    mutating func addPath(_ path: VectorPath, name: String) throws -> String {
        history.record(name, pathInEdit); pathInEdit = PathInEdit(id: "path-1", path: path, toDocument: .identity); return "path-1"
    }
    mutating func setPath(_ path: VectorPath, name: String, drag: String?) throws { history.record(name, pathInEdit, key: drag.map { "\(name):\($0)" }); pathInEdit?.path = path }
    static let editing = PathDoc(pathInEdit: PathInEdit(id: "path-1", path: AnchorEditTests.path(), toDocument: .identity), anchorSelection: Selection([AnchorEditTests.mid]))
}
@Suite struct PathCommandsTests {
    static let catalog = (try? CommandCatalog(app: "test", PathCommands.specs(PathDoc.self), history: { $0.history }))
    static let titles: [String: (CommandKind, String?)] = [
        "path.read": (.query, nil), "path.draw": (.edit, "Add Path"), "path.pen-add": (.view, nil), "path.close": (.edit, "Add Path"),
        "path.finish": (.edit, "Add Path"), "path.cancel": (.view, nil), "path.anchor-select": (.view, nil), "path.anchor-move": (.edit, "Move Points"),
        "path.handle-move": (.edit, "Move Handle"), "path.anchor-insert": (.edit, "Add Point"), "path.anchor-remove": (.edit, "Delete Points"),
        "path.anchor-convert": (.edit, "Convert Points")]
    static func run(_ intent: PathIntent, _ doc: inout PathDoc) throws -> CommandOutcome? { try catalog?.run(intent.command.id, params: intent.command.params, on: &doc) }
    static func why(_ id: String, _ doc: PathDoc) -> String? { catalog?.availability(id, on: doc).why }
    static func pen(_ points: [(Double, Double)], _ doc: inout PathDoc) throws {
        for p in points { _ = try run(.penAdd(Point(x: p.0, y: p.1), handleOut: nil), &doc) }
    }
    @Test func specsAreTheTwelveWithTheirTitles() throws {
        let catalog = try #require(Self.catalog)
        #expect(catalog.ids == Self.titles.keys.sorted())
        for (id, (kind, title)) in Self.titles {
            let spec = try #require(catalog.spec(id))
            #expect(spec.kind == kind && spec.params.validate(spec.example).isEmpty && (title == nil || spec.title == title), "\(id)")
        }
    }
    @Test func oneStepPerRun() throws {
        var doc = PathDoc.editing
        let edits: [(PathIntent, String)] = [(.move(dx: 5, dy: 0, drag: nil), "Move Points"),
                                             (.handle(AnchorEditTests.mid, .handleOut, to: Point(x: 130, y: 0), breaking: false, drag: nil), "Move Handle"),
                                             (.convert(.corner), "Convert Points"), (.insert(Point(x: 150, y: 0)), "Add Point"), (.remove, "Delete Points")]
        _ = try Self.run(.selectAll, &doc)
        #expect(doc.anchorSelection.set.count == 3 && doc.history.undoSteps.isEmpty)
        for (count, (intent, title)) in edits.enumerated() {
            #expect(try Self.run(intent, &doc)?.undoStep == title && doc.history.undoSteps.count == count + 1, "\(intent)")
        }
        try Self.pen([(0, 0), (50, 0), (50, 50)], &doc)
        #expect(doc.history.undoSteps.count == 5 && doc.penDraft?.contour.anchors.count == 3)
        #expect(try Self.run(.close, &doc)?.undoStep == "Add Path" && doc.history.undoSteps.count == 6 && doc.penDraft == nil)
        try Self.pen([(0, 0), (50, 0)], &doc)
        #expect(try Self.run(.finish, &doc)?.undoStep == "Add Path" && doc.history.undoSteps.count == 7 && doc.penDraft == nil)
        try Self.pen([(0, 0)], &doc)
        _ = try Self.run(.cancel, &doc)
        #expect(doc.penDraft == nil && doc.history.undoSteps.count == 7)
    }
    @Test func dragIsOneStep() throws {
        var doc = PathDoc.editing
        for i in 0..<120 { _ = try Self.run(.handle(AnchorEditTests.mid, .handleOut, to: Point(x: 120, y: Double(i)), breaking: false, drag: "d1"), &doc) }
        #expect(doc.history.undoSteps.map(\.name) == ["Move Handle"])
        #expect(doc.history.undoSteps.first?.payload == PathDoc.editing.pathInEdit)
        _ = try Self.run(.selectAll, &doc)
        for _ in 0..<10 { _ = try Self.run(.move(dx: 1, dy: 0, drag: "d2"), &doc) }
        #expect(doc.history.undoSteps.map(\.name) == ["Move Handle", "Move Points"])
        #expect(doc.pathInEdit?.path.contours.first?.anchors.first?.point == Point(x: 10, y: 0))
    }
    @Test func closeNeedsThree() throws {
        var doc = PathDoc(penDraft: PenRulesTests.draft([(0, 0), (50, 0)]))
        #expect(Self.why("path.close", doc) == "Click a third point to close the path.")
        doc.penDraft = PenRulesTests.draft([(0, 0), (50, 0), (0, 0)])
        #expect(Self.why("path.close", doc) == "Click a third point to close the path.")
        doc.penDraft = PenRulesTests.draft([(0, 0), (50, 0), (50, 50)])
        #expect(Self.catalog?.availability("path.close", on: doc) == .available)
        _ = try Self.run(.close, &doc)
        let contour = doc.pathInEdit?.path.contours.first
        #expect(contour?.closed == true && contour?.anchors.count == 3 && doc.penDraft == nil)
    }
    @Test func insertUnavailableOffThePath() throws {
        var doc = PathDoc.editing
        #expect(throws: CatalogError.self) { try Self.run(.insert(Point(x: 100, y: 90)), &doc) }
        #expect(doc.history.undoSteps.isEmpty)
        _ = try Self.run(.insert(Point(x: 150, y: 2)), &doc)
        #expect(doc.pathInEdit?.path.contours.first?.anchors.count == 4 && doc.anchorSelection.ordered == [AnchorRef(contour: 0, index: 2)])
    }
    @Test func everyWhyNot() throws {
        let empty = PathDoc()
        #expect(Self.why("path.read", empty) == "Select a path or start one with the Pen.")
        #expect(Self.why("path.anchor-select", empty) == "Select a path to edit its points." && Self.why("path.anchor-move", empty) == "Select a path to edit its points.")
        #expect(Self.why("path.close", empty) == "Click with the Pen to start a path." && Self.why("path.cancel", empty) == "Click with the Pen to start a path.")
        #expect(Self.why("path.finish", PathDoc(penDraft: PenRulesTests.draft([(0, 0)]))) == "Click a second point to finish the path.")
        #expect(Self.why("path.draw", PathDoc(pathHelp: "The layer is locked.")) == "The layer is locked.")
        var none = PathDoc.editing
        none.anchorSelection = Selection()
        for id in ["path.anchor-move", "path.anchor-remove", "path.anchor-convert"] { #expect(Self.why(id, none) == "Select a point first.", "\(id)") }
        var doc = PathDoc.editing
        #expect(throws: CatalogError.self) { try Self.run(.handle(AnchorRef(contour: 0, index: 0), .handleOut, to: Point(x: 9, y: 9), breaking: false, drag: nil), &doc) }
        #expect(throws: CatalogError.self) { try Self.run(.handle(AnchorRef(contour: 0, index: 7), .handleOut, to: Point(x: 9, y: 9), breaking: true, drag: nil), &doc) }
        #expect(doc.history.undoSteps.isEmpty)
        _ = try Self.run(.handle(AnchorRef(contour: 0, index: 0), .handleOut, to: Point(x: 9, y: 9), breaking: true, drag: nil), &doc)
        #expect(doc.history.undoSteps.count == 1)
    }
    @Test func drawRefusesFewerThanTwo() throws {
        var doc = PathDoc()
        let one: JSONValue = .object(["contours": .array([.object(["closed": .bool(false), "anchors": .array([.object(["x": .number(0), "y": .number(0), "kind": .string("corner")])])])])])
        #expect(throws: CatalogError.self) { try Self.catalog?.run("path.draw", params: one, on: &doc) }
        #expect(doc.pathInEdit == nil && doc.history.undoSteps.isEmpty)
    }
    @Test func selectByRefRectAndAll() throws {
        var doc = PathDoc.editing
        _ = try Self.run(.select(anchors: nil, rect: Rect(minX: 150, minY: -10, maxX: 250, maxY: 10), extend: false), &doc)
        #expect(doc.anchorSelection.ordered == [AnchorRef(contour: 0, index: 2)])
        _ = try Self.run(.select(anchors: [AnchorRef(contour: 0, index: 0), AnchorRef(contour: 3, index: 0)], rect: nil, extend: true), &doc)
        #expect(doc.anchorSelection.set == [AnchorRef(contour: 0, index: 2), AnchorRef(contour: 0, index: 0)])
        _ = try Self.run(.selectAll, &doc)
        #expect(doc.anchorSelection.set.count == 3 && doc.history.undoSteps.isEmpty)
    }
    @Test func drawRoundTripsRead() throws {
        var (source, doc) = (PathDoc.editing, PathDoc())
        guard case .object(let fields)? = try Self.catalog?.run("path.read", params: .object([:]), on: &source).result, let contours = fields["contours"]
        else { Issue.record("no contours"); return }
        #expect(fields["selected"] == .array([.array([.number(0), .number(1)])]))
        _ = try Self.catalog?.run("path.draw", params: .object(["contours": contours]), on: &doc)
        #expect(doc.pathInEdit?.path == AnchorEditTests.path() && doc.history.undoSteps.map(\.name) == ["Add Path"])
    }
    /// A layer scaled 2 by 0.5, turned 30 degrees and moved (30, -20), so a transpose, a skipped translation or a
    /// skipped scale each land somewhere else.
    static let turned = Matrix(a: 2 * cos30, b: 2 * 0.5, c: -0.5 * 0.5, d: 0.5 * cos30, tx: 30, ty: -20)
    static let cos30 = 3.0.squareRoot() / 2
    static func onTurned() -> PathDoc { var doc = PathDoc.editing; doc.pathInEdit?.toDocument = turned; return doc }
    static func middle(_ doc: PathDoc) -> VectorAnchor? { doc.pathInEdit?.path.contours.first?.anchors.dropFirst().first }
    static func near(_ a: Point?, _ b: Point, within e: Double = 1e-9) -> Bool { a.map { abs($0.x - b.x) <= e && abs($0.y - b.y) <= e } ?? false }
    @Test func moveIsADocumentDeltaOnATransformedLayer() throws {
        var doc = Self.onTurned()
        let before = try #require(Self.middle(doc)).point
        _ = try Self.run(.move(dx: 10, dy: 5, drag: nil), &doc)
        let start = Self.turned.apply(before)
        #expect(Self.near(Self.middle(doc).map { Self.turned.apply($0.point) }, Point(x: start.x + 10, y: start.y + 5)), "\(String(describing: Self.middle(doc)))")
    }
    @Test func handleIsADocumentPointOnATransformedLayer() throws {
        var doc = Self.onTurned()
        let to = Point(x: 260, y: 40)
        _ = try Self.run(.handle(AnchorEditTests.mid, .handleOut, to: to, breaking: true, drag: nil), &doc)
        #expect(Self.near(Self.middle(doc)?.handleOut.map(Self.turned.apply), to), "\(String(describing: Self.middle(doc)))")
    }
    @Test func insertIsADocumentPointOnATransformedLayer() throws {
        var doc = Self.onTurned()
        // (150, 0) is on the path in its own space, nearly 50 points off it in the document. A point lands within
        // the nearest-point search's tolerance, `insertReach / 8`.
        #expect(throws: CatalogError.self) { try Self.run(.insert(Point(x: 150, y: 0)), &doc) }
        let on = Self.turned.apply(Point(x: 150, y: 0))
        _ = try Self.run(.insert(on), &doc)
        let added = doc.pathInEdit?.path.contours.first?.anchors.dropFirst(2).first
        #expect(doc.anchorSelection.ordered == [AnchorRef(contour: 0, index: 2)] && Self.near(added.map { Self.turned.apply($0.point) }, on, within: 0.75))
    }
    @Test func readIsDocumentSpaceOnATransformedLayer() throws {
        var doc = Self.onTurned()
        guard case .object(let fields)? = try Self.catalog?.run("path.read", params: .object([:]), on: &doc).result,
              case .array(let contours)? = fields["contours"], case .object(let contour)? = contours.first,
              case .array(let anchors)? = contour["anchors"], case .object(let first)? = anchors.first,
              case .number(let x)? = first["x"], case .number(let y)? = first["y"] else { Issue.record("no anchors"); return }
        #expect(Self.near(Point(x: x, y: y), Self.turned.apply(Point(x: 0, y: 0))))
    }
    @Test func aLayerScaledToNothingRefusesPointEdits() throws {
        var doc = PathDoc.editing
        doc.pathInEdit?.toDocument = Matrix.scale(x: 0, y: 1)
        #expect(throws: CatalogError.self) { try Self.run(.move(dx: 1, dy: 0, drag: nil), &doc) }
        #expect(throws: CatalogError.self) { try Self.run(.handle(AnchorEditTests.mid, .handleOut, to: Point(x: 1, y: 1), breaking: true, drag: nil), &doc) }
        #expect(doc.history.undoSteps.isEmpty && doc.pathInEdit?.path == AnchorEditTests.path())
    }
    @Test func intentCommandRoundTrips() throws {
        let intents: [PathIntent] = [.penAdd(Point(x: 1, y: 2), handleOut: nil), .close, .finish, .cancel, .selectAll, .move(dx: 1, dy: 2, drag: "d"),
                                     .select(anchors: [AnchorEditTests.mid], rect: Rect(minX: 0, minY: 0, maxX: 5, maxY: 5), extend: true),
                                     .handle(AnchorEditTests.mid, .handleIn, to: Point(x: 0, y: 0), breaking: true, drag: nil),
                                     .insert(Point(x: 150, y: 0)), .remove, .convert(.corner)]
        for intent in intents { #expect(Self.catalog?.spec(intent.command.id)?.params.validate(intent.command.params).isEmpty == true, "\(intent)") }
    }
}
