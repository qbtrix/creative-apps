// CommandShapeTests.swift (command-catalog CC-1, CJ0): every public type and method in Commands/
// exists and its type is documented, the object builder is closed, and JSONValue round trips.
import Foundation
import Testing
import SuiteKernel
/// A minimal headless document: one number and a history, enough to use every signature.
private struct ShapeDoc: HeadlessDocument {
    struct Bump: Codable, Sendable, CommandSchemaProviding { var by: Double; static let paramSchema = ParamSchema.object(["by": .number()], required: ["by"]) }
    var value = 0.0, history = History<Double>()
    static let app = "shape", openExtensions = ["shape"], exportFormats = ["json"]
    // The init's id checks arrive with CC-7; a test may trap where Sources/ may not.
    static let catalog = try! CommandCatalog<ShapeDoc>(app: app, [
        .typed("value.bump", title: "Bump Value", summary: "Adds to the value.", kind: .edit, params: Bump.self, example: .object(["by": .number(1)]),
               availability: { $0.value < 10 ? .available : .unavailable("The value is full.") }) { doc, p in doc.value += p.by; return doc.value },
    ], history: { $0.history })
    static func open(_ data: Data, name: String) throws -> ShapeDoc { ShapeDoc() }
    static func new(_ options: JSONValue) throws -> ShapeDoc { ShapeDoc() }
    func save() throws -> Data { try JSONValue.number(value).json() }
    func export(_ format: String, options: JSONValue) throws -> [ExportedFile] { [ExportedFile(suggestedName: "a.json", format: format, data: try save())] }
    func summary() -> JSONValue { .object(["value": .number(value)]) }
}
/// A document Copy As, Paste as Image and Copy Frame act on: a selection flag and the last pasted file's name.
private struct ClipDoc: CopyAsTarget, CopyFrameTarget {
    var selected = true, pasted: String?
    var copyAsHelp: String? { selected ? nil : "Select something to copy." }
    var pasteAsImageHelp: String? { nil }
    var copyFrameHelp: String? { nil }
    func copyAs(_ format: CopyAsFormat) throws -> CopiedBytes {
        CopiedBytes(type: format == .png ? "public.png" : format == .svg ? "public.svg-image" : "app.layers", data: Data([1, 2]))
    }
    mutating func pasteAsImage(name: String, data: Data) throws { pasted = name }
    func copyFrame() throws -> Data { Data([3]) }
}
@Suite struct CommandShapeTests {
    /// clipboard-interop CB-1: Copy As (`{format: png | svg | own}`), Paste as Image and Copy Frame are specs with
    /// closed schemas whose examples validate, the right kinds, and the target's help as their availability.
    @Test func copyAsSpecsHaveSchemasAndKinds() throws {
        let specs = CopyAsCommands.specs(ClipDoc.self), frame = CopyAsCommands.frameSpecs(ClipDoc.self)
        #expect(specs.map(\.id) == ["edit.copy-as", "edit.paste-as-image"] && frame.map(\.id) == ["edit.copy-frame"])
        #expect(specs.map(\.kind) == [.query, .edit] && frame.map(\.kind) == [.query])
        for spec in specs + frame { #expect(spec.params.validate(spec.example).isEmpty, "\(spec.id)'s example doesn't validate") }
        let copyAs = try #require(specs.first)
        #expect(!copyAs.params.validate(.object(["format": .string("gif")])).isEmpty)
        #expect(copyAs.availability(ClipDoc(selected: false)).why == "Select something to copy.")
        #expect(CopyAsFormat.allCases.map(\.rawValue) == ["png", "svg", "own"])
    }

    /// CJ0: every public type and method exists, and the stubs answer without trapping.
    @Test func everySignatureExists() throws {
        let catalog = ShapeDoc.catalog, spec = try #require(catalog.spec("value.bump")), described = try #require(catalog.describe("value.bump"))
        #expect(catalog.app == "shape" && catalog.ids == ["value.bump"] && spec.undoable && spec.params == ShapeDoc.Bump.paramSchema)
        #expect(catalog.availability("value.bump", on: ShapeDoc(value: 10)).why == "The value is full." && Availability.available.why == nil)
        #expect(try catalog.describeAll() == [described] && JSONValue(encoding: described).decode(CommandDescription.self) == described)
        var doc = ShapeDoc()
        let step = CommandEnvelope(id: "value.bump", params: spec.example)
        #expect(try catalog.run(step, on: &doc) == CommandOutcome(result: .number(1), undoStep: nil) && doc.value == 1)
        var full = ShapeDoc(value: 10)
        #expect(throws: CatalogError.unavailable(id: "value.bump", why: "The value is full.")) { try catalog.run("value.bump", params: spec.example, on: &full) }
        #expect(catalog.runBatch([step, step], on: &doc, atomic: true).stoppedAt == nil && doc.value == 3)
        #expect(catalog.runBatch([], on: &doc, atomic: false) == BatchReport(steps: [], stoppedAt: nil, rolledBack: false))
        _ = (CommandOutcome(result: .null, undoStep: nil), BatchReport.Step(id: "a", ok: true, undoStep: nil, error: nil), CommandKind.query)
        _ = [CatalogError.unknownCommand("x"), .malformedParams(id: "x", [SchemaIssue(path: "/x", message: "expected number")]),
             .unavailable(id: "x", why: "no"), .failed(id: "x", message: "no")]
        #expect(SchemaProbe.schema(of: ShapeDoc.Bump.self, maxDepth: 2) == ShapeDoc.Bump.paramSchema && ParamSchema.none.validate(.object([:])).isEmpty)
        #expect(CommandIDLedger.check(["value.bump"], ledger: "value.bump\n").isEmpty && CatalogConformance.check(ShapeDoc.self, fixture: doc).allSatisfy { $0.hasPrefix("value.bump: ") })
        #expect(try ShapeDoc.new(.null).export("json", options: .null).map(\.format) == ["json"] && ShapeDoc.open(Data(), name: "a").summary() != .null)
        #expect(ParamSchema.none.document() == .object(["type": .string("object"), "additionalProperties": .bool(false),
                                                        "$schema": .string("https://json-schema.org/draft/2020-12/schema")]))
    }

    /// `object` writes `additionalProperties: false` and its `required` list (mutation `.objectIsClosed`), and
    /// `.optional` keeps its key out of `required` (mutation `.optionalDropsRequired`).
    @Test func objectIsClosedAndOptionalDropsRequired() {
        let schema = ParamSchema.object(["x": .number(), "name": .optional(.string())], required: ["x", "name"], description: "A point.")
        #expect(schema.json == .object(["type": .string("object"), "description": .string("A point."), "additionalProperties": .bool(false),
                                        "required": .array([.string("x")]),
                                        "properties": .object(["x": .object(["type": .string("number")]), "name": .object(["type": .string("string")])])]))
    }

    /// Every case survives JSON text and back, sorted or not, and `init(encoding:)` / `decode` agree with Codable.
    @Test func jsonValueRoundTripsEveryCase() throws {
        let cases: [JSONValue] = [.null, .bool(true), .bool(false), .number(-2.5), .number(3), .string("a \"b\""), .array([.number(0), .array([])]), .object([:])]
        for value in cases + [.object(Dictionary(uniqueKeysWithValues: cases.enumerated().map { ("k\($0.offset)", $0.element) }))] {
            #expect(try JSONValue(json: value.json()) == value && JSONValue(json: value.json(sorted: false)) == value)
        }
        #expect(try String(decoding: JSONValue.object(["b": .null, "a": .null]).json(), as: UTF8.self) == #"{"a":null,"b":null}"#)
        #expect(try JSONValue(encoding: ShapeDoc.Bump(by: 2)) == .object(["by": .number(2)]) && JSONValue.number(2).decode(Double.self) == 2)
    }

    /// Every public type in Commands/ has a `///` line above it.
    @Test func publicTypesDocumented() throws {
        let root = KernelShapeTests.kernelSources, files = try KernelShapeTests.swiftFiles(under: root).filter { $0.hasPrefix("Commands/") }
        let typeLine = try Regex(#"^\s*public (struct|enum|protocol) "#)
        #expect(files.count == 9)
        for file in files {
            let lines = try String(contentsOf: root.appendingPathComponent(file), encoding: .utf8).split(separator: "\n", omittingEmptySubsequences: false)
            for (i, line) in lines.enumerated() where line.contains(typeLine) && !(i > 0 && lines[i - 1].contains("///")) {
                Issue.record("Sources/SuiteKernel/\(file):\(i + 1) has no doc line: \(line)")
            }
        }
    }
}

/// A photo for the crop and orientation commands (orientation-crop OC-1): its orientation, its crop
/// frame in its bounds (the unit square), why each can't act, and one undo history for both.
struct CropShapeTarget: OrientationTarget, CropTarget {
    struct State: Hashable, Sendable { var orientation = Orientation.up, frame: CropFrame? }
    var state = State(), orientationHelp: String?, cropHelp: String?, applied = 0, history = History<State>()
    var orientation: Orientation { state.orientation }
    var cropFrame: CropFrame? { state.frame }
    var cropBounds: Rect { Rect(minX: 0, minY: 0, maxX: 1, maxY: 1) }
    mutating func setOrientation(_ o: Orientation, name: String) throws { history.record(name, state); state.orientation = o }
    mutating func setCropFrame(_ f: CropFrame?, name: String) throws { history.record(name, state); state.frame = f }
    mutating func applyCrop() throws { history.record("Crop", state); applied += 1 }
    static func catalog() throws -> CommandCatalog<CropShapeTarget> {
        try CommandCatalog(app: "test", CropCommands.specs(CropShapeTarget.self)) { $0.history }
    }
}

extension CommandShapeTests {
    /// OC-1: the nine ids in one catalog, every one an undoable edit whose example passes its schema,
    /// each blocked by its side's help, and a param outside its schema refused.
    @Test func cropCommandsShape() throws {
        let catalog = try CropShapeTarget.catalog()
        #expect(catalog.ids == ["crop.apply", "crop.reset", "crop.set-aspect", "crop.set-frame", "crop.swap",
                                "image.flip", "image.rotate-180", "image.rotate-ccw", "image.rotate-cw"])
        for id in catalog.ids {
            let spec = try #require(catalog.spec(id))
            #expect(spec.undoable && !spec.title.isEmpty && !spec.summary.isEmpty && spec.params.validate(spec.example).isEmpty, "\(id)")
        }
        var blocked = CropShapeTarget(orientationHelp: "Open a photo first.", cropHelp: "Pick a photo to crop.")
        #expect(catalog.availability("image.rotate-cw", on: blocked).why == "Open a photo first.")
        #expect(catalog.availability("crop.swap", on: blocked).why == "Pick a photo to crop.")
        #expect(throws: CatalogError.unavailable(id: "image.flip", why: "Open a photo first.")) {
            try catalog.run("image.flip", params: .object(["axis": .string("vertical")]), on: &blocked)
        }
        let flip = try #require(catalog.spec("image.flip"))
        #expect(!flip.params.validate(.object(["axis": .string("diagonal")])).isEmpty)
    }
}
