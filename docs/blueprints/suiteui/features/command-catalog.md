# Feature packet: command-catalog

**Feature:** one typed command catalog in `SuiteKernel` that every app
registers its model actions in, so menus, buttons, the `afterglow` CLI, the
MCP server and the crews' tests all drive the same path. A command has a
stable name, typed parameters with a JSON schema, a typed result, a kind
(query, view, edit, file) whose `edit` runs record exactly one undo step in
the document's history, a description written for people and for models,
and an availability rule that says why not when it can't run. Linux-safe.
**Line:** `line:suiteui` · **Wave:** XK1 (`waves.md`, the kernel track;
beta-80 **W0**, `p0`) · **Lead branch:** `lead/command-catalog`

**Covers:** the captain's AI-accessible-first call ("Every action is a
command. The UI, CLI and MCP all drive the same command channel, which is
also how crews test the app"), missed in the beta-80 plan and added as its
W0 (`paw-workspace/docs/design/drafts/2026-10-18-beta-80-plan.md`, "W0:
command layer"); suite blueprint section 1.5 (the principle); beta-80 row
S14 (the command palette lists catalog entries, so it is built on this).

**Depends on:** editor-kernel (#1933): only its contract slice EK-a (the
`SuiteKernel` target, on dev) and EK-undo (`HistoryReading`, on dev), so
nothing here waits on open work except CC-9 (EK-u, which edits
`SuiteGallery.swift` first; font-picker's FP-a now edits it after CC-u,
lead decision 2026-10-20) and CC-14 (EK-z, for the
shared prose files). No
creative-core issue: FlareCore stays as it is (see "FlareCore's engine").

**Downstream:** `suite/afterglow-cli` (#2998) and `suite/afterglow-mcp` (#3000) build on
CC-a's fakes and the five `<X>Headless` stubs; `adopt-command-catalog`
(#2999, XK2) fills one app per slice.

**Clean-room.** Behaviour only. The envelope is FlareCore's own; JSON
Schema is the public 2020-12 vocabulary; no other product's code is read.

Blueprint sections: suite.md 1.5 (principle), 2.2 (containers); suiteui.md
2.2 (MenuCommand), 5 (contracts); docs/engineering.md (layers).

### FlareCore's engine: reused where it generalizes, not generalized

`CommandEngine` (FlareCore `Command.swift`) is bound to FlareCore's
`Document`: it validates every result with `FlareFormat.validate`, and its
`LayerCommand` scoping is about scenes and symbols. It does not generalize
to a Photo pixel document or a Library catalog, and moving it would break a
built, fuzzed engine (`CommandFuzzTests`, `UndoPropertyTests`). What
generalizes, the catalog takes as is:

- the envelope `{"id": "<name>", "params": {...}}` that
  `CommandRegistry.encode`/`decode` write and read (journals, scripting,
  replay), so a FlareCore journal line is a catalog step unchanged;
- the id rule: stable dotted lowercase names, a retired id never reused;
- the error contract: untrusted input never crashes; an unknown id and a
  malformed envelope are distinct, named errors;
- run on a copy, commit on success: a command that throws leaves the
  target untouched.

Flare adopts by wrapping `CommandRegistry.builtIn` (its 63 ids map one to
one; `label` is the title; the schema comes from `SchemaProbe` over each
`Command` type's `Decodable` init; undo stays on `CommandEngine`, read
through `HistoryReading` as adopt-kernel-undo's AU-f1 makes it). There is
no third undo path: the catalog never owns a history, it reads the
target's.

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| CC-a | `SuiteKernel/Commands` exists with every public type and signature as a documented stub, a fake headless document with six commands, and one `<X>Headless` stub in each app Model, so the CLI, the MCP server, the UI page and the adopt slices build against it at once. | CC-1, CC-2 | CJ0 | – |
| CC-schema | `ParamSchema` writes JSON Schema 2020-12 for the subset the suite uses and validates a JSON value with a path per issue, and `SchemaProbe` derives a schema from any `Decodable` type by running its init on a recording decoder. | CC-3, CC-4, CC-5 | CJ1 | CC-a |
| CC-run | `CommandCatalog` runs a command by id or envelope: unknown, malformed, unavailable and failed runs each name their cause and change nothing, an `edit` run records exactly one undo step, a batch runs atomic or stops at the first refusal, and the id ledger and the conformance suite check any app's catalog. | CC-6, CC-7, CC-8 | CJ2 | CC-a |
| CC-u | The gallery's `command-catalog` page lists the fake catalog as menu items built from specs: enabled ones run on the fake document, disabled ones show their why-not as help, within the render budget. | CC-9, CC-10 | `SuiteJourneyTests.testCommandCatalogGallery` | CC-a; editor-kernel:EK-u (CC-9, for `SuiteGallery.swift`) |
| CC-lint | A Linux test fails when an app's menu item or toolbar button is built without a command spec and isn't in that app's shrinking baseline, so the one path is enforced, not remembered. | CC-11, CC-12 | CJ3 | CC-a |
| CC-z | The full Linux walk runs the fake document through list, describe, every example, a batch, undo and save, the blueprints name the command layer, and the feature is built. | CC-13, CC-14 | CJ4 | every slice above; editor-kernel:EK-z (CC-14) |

CC-a is the contract (rule 12) and declares every signature the UI, the
logic slices, the CLI and the adopt slices call, as stubs (rule 18): a stub
returns the fake's value or throws `CatalogError.notBuilt`. CC-u is the UI
slice (`"ui": true`); it waits only on CC-a (and on EK-u for the gallery file)
and its first task puts the page in the gallery index, the visible control.
CC-schema, CC-run and CC-lint never wait on CC-u. CC-z integrates.

## Journey steps

1. CJ0 (Linux, CC-1, CC-2): every type in `Commands/` exists with its doc
   comment; `FakeCanvasDocument.catalog.ids` lists its six commands; each
   `<X>Headless.open` throws `notBuilt` naming its adopt slice.
2. CJ1 (Linux, CC-3 to CC-5): the probe of `AddRectParams` (two numbers,
   an optional string, a nested `Size`) equals the hand-written schema;
   validating `{"x": "1"}` names `/x` and "expected number".
3. CJ2 (Linux, CC-6 to CC-8): `rect.add` with the example adds one rect
   and the history's `undoName` reads "Add Rectangle"; `rect.move` on a
   locked rect throws `unavailable` with "Unlock Rect 1 first." and the
   document is unchanged; a three-step batch whose second step is refused
   leaves the document as it was when atomic.
4. Open the gallery index, click `command-catalog` (CC-9,
   `testCommandCatalogGallery`): six rows, "Remove Rectangle" disabled with
   help "Select a rectangle first."; click "Add Rectangle": the page's
   document shows one rect and the Edit row reads "Undo Add Rectangle".
5. CJ3 (Linux, CC-11): a fixture app source with a bare `MenuCommand("X",
   help: "", perform: {})` fails the check, naming file and line; the same
   line listed in the fixture baseline passes.
6. CJ4 (Linux, CC-13): the walk in step 3, plus `describe` for every id
   round trips through JSON, every example runs, and save then open gives
   an equal document.

## Screens and states

`suiteui-command-catalog` (the page, light and dark, one row disabled with
its help shown), `suiteui-command-catalog-ran` (after Add Rectangle, the
Undo row named).

## Contract slice

New module folder `Sources/SuiteKernel/Commands/` (C4: ✚ component
`kernel-commands` in container `suite-kernel`,
`docs/c4/parts/creative-apps/suite-kernel/kernel-commands.json`, `paths:
["Sources/SuiteKernel/Commands/"]`, `order` 110, added by CC-1). Foundation
(FoundationEssentials) only, like the rest of the kernel.

```swift
// Commands/JSONValue.swift (CC-1, real: it is a value type with Codable)
public enum JSONValue: Hashable, Sendable, Codable {
    case null, bool(Bool), number(Double), string(String), array([JSONValue]), object([String: JSONValue])
    public init(json: Data) throws; public func json(sorted: Bool = true) throws -> Data
    public init<T: Encodable>(encoding value: T) throws; public func decode<T: Decodable>(_ type: T.Type) throws -> T }

// Commands/ParamSchema.swift (CC-1: builders real, validate and export stubs; CC-4 bodies)
public struct ParamSchema: Hashable, Sendable {
    public var json: JSONValue                                 // the JSON Schema object
    public static func object(_ properties: [String: ParamSchema], required: [String], description: String? = nil) -> ParamSchema   // additionalProperties: false
    public static func string(_ description: String? = nil, oneOf cases: [String]? = nil, maxLength: Int? = nil) -> ParamSchema
    public static func number(_ description: String? = nil, minimum: Double? = nil, maximum: Double? = nil) -> ParamSchema
    public static func integer(_ description: String? = nil, minimum: Int? = nil, maximum: Int? = nil) -> ParamSchema
    public static let boolean: ParamSchema
    public static func array(of item: ParamSchema, minItems: Int? = nil, maxItems: Int? = nil) -> ParamSchema
    public static func optional(_ s: ParamSchema) -> ParamSchema       // drops it from `required` of its parent
    public static let none: ParamSchema                                 // {"type":"object","additionalProperties":false}
    public func validate(_ value: JSONValue) -> [SchemaIssue]           // empty = valid
    public func document() -> JSONValue                                  // with "$schema": 2020-12
}
public struct SchemaIssue: Hashable, Sendable, Codable { public var path: String; public var message: String }   // "/size/w", "expected number"

// Commands/SchemaProbe.swift (CC-1 stub, CC-5 body)
public enum SchemaProbe {
    /// The schema `T`'s `init(from:)` asks for, read by running it on a recording decoder.
    public static func schema<T: Decodable>(of type: T.Type, maxDepth: Int = 8) -> ParamSchema
}
/// Overrides the probe where it can't see enough (an enum's cases, a range).
public protocol CommandSchemaProviding { static var paramSchema: ParamSchema { get } }

// Commands/CommandSpec.swift (CC-1 stub, CC-7 body)
public enum CommandKind: String, Hashable, Sendable, Codable {
    case query   // reads; changes nothing
    case view    // changes view state (zoom, selection, playhead); not undoable
    case edit    // changes the document; exactly one undo step
    case file    // reads or writes files outside the document (import, export)
}
public enum Availability: Hashable, Sendable { case available; case unavailable(String)   // the why-not, in the app's words
    public var why: String? { get } }
public struct CommandSpec<Target>: Sendable {
    public let id: String          // "layer.add": lowercase, dots and hyphens, ≤ 64, stable; never reuse a retired id
    public let title: String       // "Add Layer": the menu title and the undo step's name
    public let summary: String     // one or two sentences for a person and a model
    public let kind: CommandKind
    public var undoable: Bool { get }          // kind == .edit
    public let params: ParamSchema
    public let result: ParamSchema
    public let example: JSONValue  // params that run on the app's fixture document
    public let availability: @Sendable (Target) -> Availability
    public static func typed<P: Decodable & Sendable, R: Encodable>(
        _ id: String, title: String, summary: String, kind: CommandKind,
        params: P.Type, schema: ParamSchema? = nil, result: ParamSchema = .none, example: JSONValue,
        availability: @escaping @Sendable (Target) -> Availability = { _ in .available },
        run: @escaping @Sendable (inout Target, P) throws -> R) -> CommandSpec
}
public struct CommandDescription: Codable, Hashable, Sendable {   // what `describe`, `list-commands` and MCP publish
    public var app, id, title, summary: String; public var kind: CommandKind; public var undoable: Bool
    public var params, result, example: JSONValue }

// Commands/CommandCatalog.swift (CC-1 stub, CC-7 body)
public struct CommandEnvelope: Codable, Hashable, Sendable { public var id: String; public var params: JSONValue }   // FlareCore's envelope shape
public enum CatalogError: Error, Hashable, Sendable {
    case unknownCommand(String); case malformedParams(id: String, [SchemaIssue])
    case unavailable(id: String, why: String); case failed(id: String, message: String)
    case notBuilt(id: String, feature: String) }
public struct CommandOutcome: Hashable, Sendable { public var result: JSONValue; public var undoStep: String? }
public struct BatchReport: Codable, Hashable, Sendable {
    public struct Step: Codable, Hashable, Sendable { public var id: String; public var ok: Bool; public var undoStep: String?; public var error: String? }
    public var steps: [Step]; public var stoppedAt: Int?; public var rolledBack: Bool }
public struct CommandCatalog<Target>: Sendable {
    public init(app: String, _ specs: [CommandSpec<Target>], history: @escaping @Sendable (Target) -> any HistoryReading) throws   // bad or duplicate id throws
    public let app: String; public var ids: [String] { get }                   // sorted
    public func spec(_ id: String) -> CommandSpec<Target>?
    public func availability(_ id: String, on target: Target) -> Availability
    public func describe(_ id: String) -> CommandDescription?
    public func describeAll() -> [CommandDescription]
    public func run(_ id: String, params: JSONValue, on target: inout Target) throws(CatalogError) -> CommandOutcome
    public func run(_ step: CommandEnvelope, on target: inout Target) throws(CatalogError) -> CommandOutcome
    public func runBatch(_ steps: [CommandEnvelope], on target: inout Target, atomic: Bool) -> BatchReport
}

// Commands/HeadlessDocument.swift (CC-1, protocol only)
public struct ExportedFile: Hashable, Sendable { public var suggestedName: String; public var format: String; public var data: Data }
/// A document an app opens, edits, saves and exports with no window: what the CLI, MCP and the real-jobs suites drive.
public protocol HeadlessDocument: Sendable {
    static var app: String { get }                    // "photo"
    static var openExtensions: [String] { get }       // native first, then imports
    static var exportFormats: [String] { get }
    static var catalog: CommandCatalog<Self> { get }
    static func open(_ data: Data, name: String) throws -> Self
    static func new(_ options: JSONValue) throws -> Self
    func save() throws -> Data                         // native format
    func export(_ format: String, options: JSONValue) throws -> [ExportedFile]
    func summary() -> JSONValue                        // what `afterglow <app> open` prints
}

// Commands/CommandIDLedger.swift, Commands/CatalogConformance.swift (CC-1 stubs, CC-8 bodies)
public enum CommandIDLedger {   // Tests/command-ids/<app>.txt: one id per line, "retired <id>" for a removed one
    public static func check(_ ids: [String], ledger: String) -> [String] }   // problems: removed without retiring, a retired id back
public enum CatalogConformance {
    /// Every spec of D's catalog on `fixture`: the example validates and runs, an edit records one step named
    /// its title and "edit.undo" restores save() bytes, query and view leave save() bytes equal, a refusal changes
    /// nothing, describe round trips through JSON. Returns the problems, empty when it conforms.
    public static func check<D: HeadlessDocument>(_ type: D.Type, fixture: D) -> [String] }

// Fakes/FakeCanvasDocument.swift (CC-2): a Linux headless document of named rects.
// Commands: rect.add (edit), rect.move (edit, coalesces a drag under one key), rect.remove (edit),
// rect.select (view), rect.list (query), doc.export-json (file); plus edit.undo / edit.redo (view kind:
// they move the history, they are not themselves steps). A locked rect refuses move and remove.

// Sources/<X>Model/<X>Headless.swift (CC-2), five stubs, one per app:
public struct PhotoHeadless: HeadlessDocument { /* app "photo"; an empty catalog; open/new/save/export throw
    CatalogError.notBuilt(id: "open", feature: "adopt-command-catalog AC-photo") */ }   // likewise Design, Flare, Halo, Library
```

```swift
// Sources/SuiteUI/MenuCommand+Catalog.swift (CC-9): the one way a menu item or toolbar button is built.
extension MenuCommand {
    public init<T>(_ spec: CommandSpec<T>, on target: T, systemImage: String? = nil, shortcut: KeyboardShortcut? = nil,
                   perform: @escaping @MainActor () -> Void)   // title = spec.title; isEnabled from availability; help = summary or "<title>: <why>"
}
```

## Pseudocode

```
run(id, params, target):
  spec = specs[id]            else throw unknownCommand(id)
  issues = spec.params.validate(params)
  if issues: throw malformedParams(id, issues)              // nothing ran
  if case .unavailable(why) = spec.availability(target): throw unavailable(id, why)
  var copy = target
  do   result = try spec.run(&copy, params)                 // typed: decode P, call, encode R
  catch let e as CatalogError: throw e
  catch: throw failed(id, String(describing: e))           // target untouched
  target = copy
  return Outcome(result, undoStep: spec.undoable ? history(target).undoName : nil)

runBatch(steps, target, atomic):
  start = target; report = []
  for (i, step) in steps: do { outcome = try run(step, &target); report += ok }
                          catch { report += error; if atomic { target = start; rolledBack = true }; stoppedAt = i; break }

SchemaProbe.schema(T):
  run T.init(from: RecordingDecoder) once. The decoder answers every request with a
  placeholder (0, "", false, empty container) and records: keyed container keys with the
  type asked for; decodeIfPresent ⇒ not required; nested Decodable ⇒ recurse (depth
  ≤ maxDepth, then {} with a note); unkeyed ⇒ array of the element's schema. An init
  that throws on a placeholder (a RawRepresentable enum refusing "") keeps what was
  recorded so far and marks that key {"type":"string"} with no cases: the known limit,
  which `CommandSchemaProviding` overrides.
```

## Tasks

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| CC-1 | – | The contract: `Commands/` types as documented stubs (`JSONValue` and the `ParamSchema` builders real), the C4 part, CJ0's shape checks | `Sources/SuiteKernel/Commands/JSONValue.swift`, `Sources/SuiteKernel/Commands/ParamSchema.swift`, `Sources/SuiteKernel/Commands/SchemaProbe.swift`, `Sources/SuiteKernel/Commands/CommandSpec.swift`, `Sources/SuiteKernel/Commands/CommandCatalog.swift`, `Sources/SuiteKernel/Commands/HeadlessDocument.swift`, `Sources/SuiteKernel/Commands/CommandIDLedger.swift`, `Sources/SuiteKernel/Commands/CatalogConformance.swift`, `Tests/SuiteKernelTests/CommandShapeTests.swift`, `docs/c4/parts/creative-apps/suite-kernel/kernel-commands.json` | – | ~380, 10 |
| CC-2 | – | `FakeCanvasDocument` and its catalog (the commands above, on stubs that answer like the fake); the five `<X>Headless` stubs; CJ0 covers them | `Sources/SuiteKernel/Fakes/FakeCanvasDocument.swift`, `Sources/PhotoModel/PhotoHeadless.swift`, `Sources/DesignModel/DesignHeadless.swift`, `Sources/FlareModel/FlareHeadless.swift`, `Sources/HaloModel/HaloHeadless.swift`, `Sources/LibraryModel/LibraryHeadless.swift`, `Tests/SuiteKernelTests/CommandFakeTests.swift` | CC-1 | ~340, 7 |
| CC-3 | – | Checks first: `ParamSchemaTests` (each builder's JSON, validate with paths for type, required, enum, bounds, additionalProperties, items, nesting) and `SchemaProbeTests` (structs, optionals, arrays, nested types, depth cap, a throwing enum init kept partial, the override); CJ1, disabled | `Tests/SuiteKernelTests/ParamSchemaTests.swift`, `Tests/SuiteKernelTests/SchemaProbeTests.swift` | CC-1 | ~260, 2 |
| CC-4 | – | `ParamSchema.validate` and `document()` bodies and the plan; turns on `ParamSchemaTests` | `Sources/SuiteKernel/Commands/ParamSchema.swift`, `Tests/mutations/SuiteKernel.ParamSchema.json`, `Tests/SuiteKernelTests/ParamSchemaTests.swift` | CC-3 | ~280, 3 |
| CC-5 | – | `SchemaProbe` body (the recording decoder) and the plan; turns on `SchemaProbeTests` | `Sources/SuiteKernel/Commands/SchemaProbe.swift`, `Tests/mutations/SuiteKernel.SchemaProbe.json`, `Tests/SuiteKernelTests/SchemaProbeTests.swift` | CC-3 | ~320, 3 |
| CC-6 | – | Checks first: `CommandCatalogTests` (ids, unknown, malformed, unavailable, failed rolls back, edit records one step, describe), `CommandBatchTests` (atomic, stop, report), `CommandIDLedgerTests`, `CatalogConformanceTests` (the fake conforms; a broken fake fails each law); CJ2, disabled | `Tests/SuiteKernelTests/CommandCatalogTests.swift`, `Tests/SuiteKernelTests/CommandBatchTests.swift`, `Tests/SuiteKernelTests/CommandIDLedgerTests.swift`, `Tests/SuiteKernelTests/CatalogConformanceTests.swift` | CC-2 | ~360, 4 |
| CC-7 | – | `CommandCatalog`, `CommandSpec.typed`, envelope and batch bodies, the plans; turns on `CommandCatalogTests` and `CommandBatchTests` | `Sources/SuiteKernel/Commands/CommandCatalog.swift`, `Sources/SuiteKernel/Commands/CommandSpec.swift`, `Tests/mutations/SuiteKernel.CommandCatalog.json`, `Tests/SuiteKernelTests/CommandCatalogTests.swift`, `Tests/SuiteKernelTests/CommandBatchTests.swift` | CC-6, CC-4 | ~340, 5 |
| CC-8 | – | `CommandIDLedger` and `CatalogConformance` bodies and plans; turns on their tests | `Sources/SuiteKernel/Commands/CommandIDLedger.swift`, `Sources/SuiteKernel/Commands/CatalogConformance.swift`, `Tests/mutations/SuiteKernel.CatalogConformance.json`, `Tests/SuiteKernelTests/CommandIDLedgerTests.swift`, `Tests/SuiteKernelTests/CatalogConformanceTests.swift` | CC-6 | ~300, 5 |
| CC-9 | – | `MenuCommand(spec:on:)`, the `command-catalog` gallery page over the fake (in `SuiteGallery.areas`), snapshots; the journey written first, `XCTSkip("waits on CC-10")` | `Sources/SuiteUI/MenuCommand+Catalog.swift`, `Sources/SuiteUI/Gallery/GalleryCommandCatalog.swift`, `Sources/SuiteUI/SuiteGallery.swift`, `Tests/SuiteUITests/MenuCommandCatalogTests.swift`, `Tests/AppSnapshotTests/SuiteCommandCatalogSnapshots.swift`, `UITests/SuiteJourneyTests+CommandCatalog.swift` | CC-2 | ~320, 6 |
| CC-10 | – | The render budget (clicking every row ≤ 2 window bodies each) and the journey turned on | `Tests/AppSnapshotTests/RenderBudgetCommandCatalogTests.swift`, `UITests/SuiteJourneyTests+CommandCatalog.swift` | CC-9 | ~140, 2 |
| CC-11 | – | `CommandPathTests` (Linux): scans `Sources/*App/` for `MenuCommand(` and toolbar `Button(` built without a spec, against `Tests/command-path-baseline/<app>.txt` (today's sites, generated once here); a fixture tree proves both directions; CJ3 | `Tests/SuiteKernelTests/CommandPathTests.swift`, `Tests/SuiteKernelTests/Fixtures/CommandPath/`, `Tests/command-path-baseline/photo.txt`, `Tests/command-path-baseline/design.txt`, `Tests/command-path-baseline/flare.txt`, `Tests/command-path-baseline/halo.txt`, `Tests/command-path-baseline/library.txt` | CC-1 | ~260, 8 |
| CC-12 | – | The ratchet: a baseline line whose site is gone fails ("remove it from the baseline"), so baselines only shrink; `docs/factory/lead.md` rule 20 gains one sentence naming the check (a fragment of the rule, not shared prose) | `Tests/SuiteKernelTests/CommandPathTests.swift`, `docs/factory/lead.md` | CC-11 | ~80, 2 |
| CC-13 | – | CJ4, the full walk: list, describe every id through JSON, every example on the fixture, a coalesced drag as one step, undo to saved reading clean, an atomic batch rolled back, save then open equal | `Tests/SuiteKernelTests/CommandWalkTests.swift` | CC-5, CC-7, CC-8 | ~200, 1 |
| CC-14 | – | Shared prose: suiteui.md (MenuCommand from a spec; the gallery page), `docs/engineering.md` (the command layer under every app), the kernel header lists `Commands/`, `status: built`; `feature-done` | `docs/blueprints/suiteui.md`, `docs/engineering.md`, `Sources/SuiteKernel/SuiteKernel.swift`, `docs/blueprints/suiteui/features/command-catalog.wave.json` | CC-10, CC-12, CC-13 | ~120, 4; `feature-done` |

CC-4 and CC-5 fill different stubs, so they run together; so do CC-7 and
CC-8. CC-7 also waits on CC-4 because a run validates its params. CC-11
reads source text only, so it needs nothing but the contract. CC-12 owns
one sentence of `lead.md` rule 20 (the rule names its enforcers; this adds
one), which no other open packet edits.

## Build waves

- Wave 1: CC-1. Independent in this wave: CC-1 alone.
- Wave 2: CC-2, CC-3, CC-11. Independent in this wave: all three.
- Wave 3: CC-4, CC-5, CC-6, CC-9, CC-12. Independent in this wave: all five.
- Wave 4: CC-7, CC-8, CC-10. Independent in this wave: all three.
- Wave 5: CC-13. Independent in this wave: CC-13 alone.
- Wave 6: CC-14 (shared prose, `feature-done`, final). Independent in this wave: CC-14 alone.

Longest chain: CC-1 → CC-3 → CC-4 → CC-7 → CC-13 → CC-14 (6). Chain of 6:
CC-3 writes the checks CC-4 turns on, CC-7's runs validate through CC-4's
body, CC-13 walks CC-7's runs, and CC-14 is the final prose task.

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| CC-1 | `CommandShapeTests` (CJ0): every public type and method exists; `ParamSchema.object` writes `additionalProperties: false` and the `required` list; `JSONValue` round trips every case; `.optional` drops the key from `required` | a signature is missing or a builder writes the wrong keyword | – (stubs; builders: `required` kept for an optional → `.optionalDropsRequired`; `additionalProperties` omitted → `.objectIsClosed`) |
| CC-2 | `CommandFakeTests`: the fake's six ids, its fixture, each stub `<X>Headless.open` throws `notBuilt` naming its slice | an id is missing or a stub answers | – (fake) |
| CC-3 | `ParamSchemaTests`, `SchemaProbeTests` exist and are disabled by name | – | – (tests) |
| CC-4 | `ParamSchemaTests`: a string where a number goes reports `/x` "expected number"; a missing required key, an extra key, a value outside `minimum`/`maximum`, a case outside `oneOf`, an array over `maxItems` each give one issue at the right path; nested paths read `/size/w`; `document()` carries `$schema` 2020-12 | an issue is missed or names the wrong path | `minimum` checked with `<` for `<=` → `.minimumInclusive`; nested path drops the parent → `.nestedPath`; extra keys accepted → `.closedObject` |
| CC-5 | `SchemaProbeTests`: the probe of `AddRectParams` equals the hand-written schema; `Int?` is optional; `[Point]` is an array of the point object; depth 9 stops at 8; an enum that throws on "" keeps the keys before it; `CommandSchemaProviding` wins | the probe misses a key, marks an optional required, or loops | `decodeIfPresent` recorded as required → `.optionalNotRequired`; nested type recorded as string → `.nestedObject`; depth cap off by one → `.depthCap` |
| CC-6 | the four test files exist, disabled by name | – | – (tests) |
| CC-7 | `CommandCatalogTests`, `CommandBatchTests` (CJ2): unknown id; malformed params name the path and run nothing; unavailable carries the why and changes nothing; a throwing run leaves the target equal; an edit's outcome names the step; a coalesced drag is one step; atomic batch rolls back, non-atomic stops and reports | any refusal changes the target, or an edit records 0 or 2 steps | availability checked after the run → `.unavailableChangesNothing`; target assigned before the run returns → `.failedRollsBack`; atomic rollback skipped → `.atomicBatch` |
| CC-8 | `CommandIDLedgerTests`: a removed id not marked retired fails; a retired id back fails; a new id passes. `CatalogConformanceTests`: the fake conforms; a fake whose edit records no step, whose query changes bytes, or whose example fails validation each fail with a named problem | a broken catalog passes | retired id allowed back → `.retiredNeverReused`; undo law compares history only, not bytes → `.undoRestoresBytes` |
| CC-9 | `MenuCommandCatalogTests`: title, enabled and help from the spec (help "Remove Rectangle: Select a rectangle first."); `testCommandCatalogGallery` written, skipped | a disabled item hides, or its help drops the why | – (UI; budget in CC-10) |
| CC-10 | `RenderBudgetCommandCatalogTests`: each row click ≤ 2 window bodies; the journey passes | over budget | – |
| CC-11 | `CommandPathTests` (CJ3): the fixture's bare `MenuCommand(` fails naming file and line; listed in the fixture baseline it passes; a spec-built one passes; today's apps pass against their generated baselines | a bare site passes, or a spec site fails | the scan skips `Sources/*App/` subfolders → `.scansSubfolders`; baseline match by file only, not line text → `.baselineMatchesLine` |
| CC-12 | `CommandPathTests.staleBaselineFails`: a baseline line whose site is gone fails | the baseline can grow stale | stale lines ignored → `.staleBaselineFails` |
| CC-13 | `CommandWalkTests` (CJ4) | any law breaks on the fixture walk | – (integration) |
| CC-14 | `scripts/waves check`, `scripts/c4-assemble --check` | the wave data or the C4 parts don't assemble | – (prose) |

## Quality tests

| quality row | budget | test |
|---|---|---|
| run overhead | a no-op command through `run` (validate, availability, copy, commit) ≤ 50 µs p95 on Linux CI for a 1 KB params object | `CommandCatalogTests.runOverheadWithinBudget` (reported) |
| schema size | the fake's `describeAll()` JSON ≤ 8 KB; the probe never loops (depth cap) | `SchemaProbeTests.depthCap` |
| untrusted input | 1,000 seeded mutations of each example (types swapped, keys dropped and added, huge strings) throw `malformedParams` or run; never crash | `CommandCatalogTests.fuzzedParamsNeverCrash` |
| no dead controls | every catalog-built menu item is enabled or carries a why-not | `MenuCommandCatalogTests.disabledHasWhy` |
| render: gallery row click | each click ≤ 2 window bodies; p95 ≤ 8 ms | `RenderBudgetCommandCatalogTests.rowClick` |
| Linux-safe | `Commands/` imports Foundation only | `KernelShapeTests.importsOnlyFoundationAndFlareCore` (existing scan) |

## Done check

Per slice: its tasks merged and the newest dev CI run containing its last
PR has a green `Linux` job; CC-u also the feel gate and its `Mac-Finish:`
line. Then the contact sheet once every slice is done. No open `finding`
for the feature.
