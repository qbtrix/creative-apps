// PathCommandsTests.swift (pen-paths PN-1 written, PN-7 turns on; the spec shape check runs now): the twelve commands.
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
    @Test func specsAreTheTwelveWithTheirTitles() throws {
        let catalog = try #require(Self.catalog)
        #expect(catalog.ids == Self.titles.keys.sorted())
        for (id, (kind, title)) in Self.titles {
            let spec = try #require(catalog.spec(id))
            #expect(spec.kind == kind && spec.params.validate(spec.example).isEmpty && (title == nil || spec.title == title), "\(id)")
        }
    }
    @Test(.disabled("waits on PN-7")) func oneStepPerRun() throws {
        var doc = PathDoc.editing
        #expect(try Self.run(.move(dx: 5, dy: 0, drag: nil), &doc)?.undoStep == "Move Points" && doc.history.undoSteps.count == 1)
        #expect(try Self.run(.remove, &doc)?.undoStep == "Delete Points" && doc.history.undoSteps.count == 2)
    }
    @Test(.disabled("waits on PN-7")) func dragIsOneStep() throws {
        var doc = PathDoc.editing
        for i in 0..<120 { _ = try Self.run(.handle(AnchorEditTests.mid, .handleOut, to: Point(x: 120, y: Double(i)), breaking: false, drag: "d1"), &doc) }
        #expect(doc.history.undoSteps.map(\.name) == ["Move Handle"])
    }
    @Test(.disabled("waits on PN-7")) func closeNeedsThree() throws {
        var doc = PathDoc(penDraft: PenRulesTests.draft([(0, 0), (50, 0)]))
        #expect(Self.catalog?.availability("path.close", on: doc) != .available)
        doc.penDraft = PenRulesTests.draft([(0, 0), (50, 0), (50, 50)])
        #expect(Self.catalog?.availability("path.close", on: doc) == .available)
    }
    @Test(.disabled("waits on PN-7")) func insertUnavailableOffThePath() throws {
        var doc = PathDoc.editing
        #expect(throws: CatalogError.self) { try Self.run(.insert(Point(x: 100, y: 90)), &doc) }
        #expect(doc.history.undoSteps.isEmpty)
    }
    @Test(.disabled("waits on PN-7")) func drawRoundTripsRead() throws {
        var (source, doc) = (PathDoc.editing, PathDoc())
        guard case .object(let fields)? = try Self.catalog?.run("path.read", params: .object([:]), on: &source).result, let contours = fields["contours"]
        else { Issue.record("no contours"); return }
        _ = try Self.catalog?.run("path.draw", params: .object(["contours": contours]), on: &doc)
        #expect(doc.pathInEdit?.path == AnchorEditTests.path())
    }
    @Test(.disabled("waits on PN-7")) func intentCommandRoundTrips() throws {
        let intents: [PathIntent] = [.penAdd(Point(x: 1, y: 2), handleOut: nil), .close, .finish, .cancel, .selectAll, .move(dx: 1, dy: 2, drag: "d"),
                                     .select(anchors: [AnchorEditTests.mid], rect: Rect(minX: 0, minY: 0, maxX: 5, maxY: 5), extend: true),
                                     .handle(AnchorEditTests.mid, .handleIn, to: Point(x: 0, y: 0), breaking: true, drag: nil),
                                     .insert(Point(x: 150, y: 0)), .remove, .convert(.corner)]
        for intent in intents { #expect(Self.catalog?.spec(intent.command.id)?.params.validate(intent.command.params).isEmpty == true, "\(intent)") }
    }
}
