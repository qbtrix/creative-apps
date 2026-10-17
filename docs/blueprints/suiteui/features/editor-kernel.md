# Feature packet: editor-kernel

**Feature:** `SuiteKernel`, a Linux-safe library target every app Model
imports, with one module per editor concept the apps built five times:
history (named steps, coalescing runs, drag as one step, step ids, exact
dirty), selection (ordered with a primary, anchor, one `Pick`), marquee and
nudge rules, handle hit testing, the layer tree with nesting and a follow
link (parenting on day one, bones later), keys and easing rules over
FlareCore's `Keyframe`/`Easing`, the snap contract, box transform math, the
export run, the document session and the stroke model (samples, smoothing,
dab spacing, brush settings and presets, the live copy); plus the SuiteUI
halves that draw them: `LayerTreeList` (the one layers panel),
`SelectionHandles`, `SnapGuideMarks`, `ExportSheet`, the stroke pacer,
pressure capture and brush cursor, and `ToolKeys`.
**Line:** `line:suiteui` · **Wave:** XK1 (`waves.md`, the kernel track) · **Lead branch:** `lead/editor-kernel`

**Covers:** the editor-kernel design
(`paw-workspace/docs/design/drafts/2026-10-17-editor-kernel.md`, with its
inventory of every copy on origin/dev 1e42526b); the captain's call of
2026-10-17 on #1552 ("canonical first, starting now"); the needs-ui the
snapping packet asked for (smart-guide marks with a distance label).

**Depends on:** suite-harness (#778, built: the gallery and
`SuiteGallery.areas`) and editor-in-window (#1079, built: it owned
`SuiteGallery.swift`); both are closed, so nothing here waits. No
creative-core issue: the kernel imports FlareCore's `Point`, `Rect`,
`Matrix`, `Easing` and `Keyframe` as they are (design decision 2). The
seven `adopt-kernel-*` features (wave XK2) each wait on one slice here;
`snapping` (Design) fills the snap engine stubs EK-3 declares.

**Supervisor merges EK-1.** It edits `Package.swift`, `project.yml` and
`scripts/test-scope`, protected paths the fast lane refuses (CLAUDE.md,
Parallel agents), as the suite's targets packet did for BU-1a: the lead
opens the PR with `Fast-Check: pass`, the supervisor runs the macOS
build-only job and merges it. Every other task here takes the fast lane.

**Clean-room.** Every rule is stated from the apps' own code and tests
(the inventory) or from behaviour; no task reads another product's code.

Blueprint sections: suiteui.md 2.2 (components), 5 (contracts), 7.5
(feel); suite.md 2 (targets; `SuiteKernel` joins the Linux-safe tier).

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| EK-a | The `SuiteKernel` target exists and builds on Linux and macOS with every public type and signature declared as a documented stub, fakes and fixtures, so the UI slices, the logic slices, the adopt features and the snapping lead all build against it at once. | EK-1, EK-2, EK-3, EK-29 | KJ0 | – |
| EK-u | The gallery's `editor-kernel` page shows a 200-row layer tree you can drag into a parent, the selection handles and a smart guide with a distance label, on the kernel fakes, within the render budget. | EK-4, EK-5, EK-6 | `testEditorKernelGallery` | EK-a |
| EK-undo | `History<Payload>` records named steps, folds a run under one key, ends the run on undo, redo and `endRun`, keeps ids that never repeat, reads dirty as saved-vs-current and jumps to a step. | EK-7, EK-8 | KJ1 | EK-a |
| EK-sel | `Selection<ID>` picks with replace, toggle and extend (range from the anchor when an order is given), keeps a primary, refuses what `canAdd` refuses, prunes dead ids and moves by arrow in a grid; `Nudge` and `Marquee` give the one delta rule, run key and union rule. | EK-9, EK-10 | KJ2 | EK-a |
| EK-tree | `LayerTree<Payload>` nests, orders, cascades hide and lock, moves into a parent at an index, arranges, groups, ungroups and duplicates with refusals, and composes transforms along `followsID` without cycles, keeping a layer's place when its parent changes. | EK-11, EK-12, EK-13 | KJ3 | EK-a |
| EK-keys | `KeyRules` toggles, moves (clamped, all or nothing), removes and shifts keys on a sorted track and names the key state; `EasePreset` and `EaseCurve` give one preset set and one handle math. | EK-14, EK-15, EK-16 | KJ4 | EK-a |
| EK-snap | Given a tree and the moving ids, the snap module names the candidates (siblings, parent frames, the page; hidden skipped, locked kept) and orders the offsets lines, gaps, then whole points; the engines are the snapping lead's SN-2 and SN-3. | EK-17, EK-18 | KJ5 | EK-a; EK-tree (EK-18) |
| EK-box | `BoxMath` resizes by a handle with Shift and Option, never flips, scales several as one box, and `HandleHit` finds the handle under a point at a screen tolerance divided by zoom. | EK-19, EK-20 | KJ6 | EK-a |
| EK-run | `ExportRun<Options>` moves idle, editing, running(done, total), finished or failed, never reports progress going back, and returns to idle on cancel. | EK-21, EK-22 | KJ7 | EK-a |
| EK-doc | `DocumentSession` reads dirty from the saved and current tokens, names the save status, says when autosave is due and what recovery to offer, and `VersionedJSON` probes a file's version before decoding it. | EK-23, EK-24 | KJ8 | EK-a |
| EK-stroke | `StrokeSmoother` turns pressure samples into cubic segments with a pressure range (centripetal Catmull-Rom, one segment late, mirrored ends), `DabSpacer` spaces dabs, `BrushSettings` clamps size, hardness, opacity, flow and spacing and round-trips presets, and `LiveCopy<Model>` holds the copy a drag draws on until `take()`. | EK-27, EK-28 | KJ10 | EK-a |
| EK-chrome | `ExportSheet` (format, size, quality rows and a progress bar over `ExportRun` readouts), `StrokePacer`, `PointerPressure` and `BrushCursorMark` (#953), and `ToolKeys` (one tool-letter lookup and one `KeyModifiers(nsEvent:)`) exist in SuiteUI on the gallery page, on the fakes. | EK-30, EK-31 | `testEditorKernelGallery` | EK-a |
| EK-z | The full Linux walk runs every module together on the fakes, the blueprints and `docs/engineering.md` name the kernel tier, and the feature is built. | EK-25, EK-26 | KJ9 | every slice above |

EK-a is the contract (rule 12) and declares every signature the UI and the
logic slices call, as stubs (rule 18): a stub returns the fake's value or
`NotBuilt`. EK-u and EK-chrome are the UI slices (`"ui": true`): they wait
only on EK-a, run on the fakes, and EK-4 puts the page in the gallery index,
the visible control. The nine logic slices wait only on EK-a (EK-18 also on
EK-tree, whose tree it walks) and never on a UI slice. EK-z integrates.

## Journey steps

1. Open the gallery index, click `editor-kernel` (EK-4, SJ0 and
   `testEditorKernelGallery`): a 200-row tree from the kernel fixture,
   three groups deep, with eye and lock toggles and dimmed descendants of a
   hidden group.
2. Drag row "Card 7" onto group "Header" (EK-4): the row lands as its last
   child, the page's log shows one `move(into: "header", at: 3)`, the
   window body count stays at 1.
3. Click the first card, Shift-click the fourth (EK-5): four rows picked,
   the primary last; the handles mark shows eight handles and the rotate
   knob around the union box.
4. Hover the mark's top-left handle (EK-5): the status line names `.topLeft`.
5. The guide fixture (EK-5): a vertical line at x 300 between two boxes
   and a gap label "100"; its accessibility value reads the `summary`.
6. Click Export on the page (EK-30): `ExportSheet` shows the fake run's
   rows and a progress bar that reaches 10 of 10, then the finished state.
7. Press B then V on the page (EK-31): the status line names the tool
   `ToolKeys` picked; a 120-sample drag on the stroke pad draws through
   `StrokePacer` into `LiveCopy` with the window body count at 1.
8. KJ0 to KJ10 (Linux): each module's walk, in `Tests/SuiteKernelTests/`.

## Screens and states

`suiteui-editor-kernel-tree` (the tree, light and dark),
`suiteui-editor-kernel-tree-drag` (mid-drag, drop target lit),
`suiteui-editor-kernel-handles` (four picked, handles), `suiteui-editor-kernel-guides` (the guide and label),
`suiteui-editor-kernel-export` (the sheet, running and finished), `suiteui-editor-kernel-stroke` (the pad mid-stroke, cursor mark).

## Contract slice

Target (EK-1), `Package.swift`: `.target(name: "SuiteKernel", dependencies:
[.product(name: "FlareCore", package: core)])`,
`.testTarget(name: "SuiteKernelTests", dependencies: ["SuiteKernel"])`;
`model(_:_:)` adds `"SuiteKernel"` to every Model; `SuiteUI` adds it.
`scripts/test-scope` maps `Sources/SuiteKernel` to `SuiteKernelTests` plus
every Model's tests. C4: container `suite-kernel`, one part per concept.

```swift
// Sources/SuiteKernel/Geometry.swift (EK-1): the kernel's geometry is FlareCore's.
public typealias Point = FlareCore.Point; public typealias Rect = FlareCore.Rect; public typealias Matrix = FlareCore.Matrix
public enum EditorHandle: CaseIterable, Sendable { case topLeft, top, topRight, right, bottomRight, bottom, bottomLeft, left, inside, rotate
    public var isCorner: Bool { get } }
public enum Pick: Sendable { case replace, toggle, extend }
public enum Direction: Sendable { case up, down, left, right }
public struct EditModifiers: OptionSet, Sendable { shift, option, command }

// History/History.swift (EK-2 stub, EK-8 body)
public struct History<Payload: Sendable>: Sendable {
    public init(limit: Int = 100)
    public private(set) var currentStepID: Int; public var savedStepID: Int
    public var isDirty: Bool { get }; public var canUndo: Bool { get }; public var canRedo: Bool { get }
    public var undoName: String? { get }; public var redoName: String? { get }
    public var steps: [String] { get }; public var index: Int { get }
    public mutating func record(_ name: String, _ undo: Payload, key: String? = nil)
    public mutating func endRun()
    public mutating func undo(_ apply: (Payload) -> Payload) -> Bool
    public mutating func redo(_ apply: (Payload) -> Payload) -> Bool
    public mutating func jump(to index: Int, _ apply: (Payload) -> Payload)
}
public protocol HistoryReading: Sendable { var canUndo: Bool { get }; var canRedo: Bool { get }
    var undoName: String? { get }; var redoName: String? { get }; var isDirty: Bool { get } }

// Selection/Selection.swift (EK-2 stub, EK-10 body); Selection/Nudge.swift, Selection/Marquee.swift (EK-10)
public struct Selection<ID: Hashable & Sendable>: Sendable, Equatable {
    public init(_ ids: [ID] = [])
    public private(set) var ordered: [ID]; public var primary: ID? { get }; public var anchor: ID?
    public var set: Set<ID> { get }; public func contains(_ id: ID) -> Bool
    @discardableResult public mutating func pick(_ id: ID, _ pick: Pick, order: [ID]? = nil, canAdd: (ID) -> Bool = { _ in true }) -> Bool
    public mutating func replace(_ ids: [ID]); public mutating func clear()
    public mutating func selectAll(_ candidates: [ID], canAdd: (ID) -> Bool = { _ in true })
    public mutating func prune(alive: (ID) -> Bool)
    public mutating func move(_ direction: Direction, order: [ID], columns: Int)
}
public enum Nudge { public static func delta(_ d: Direction, large: Bool, step: Double = 1, largeStep: Double = 10) -> Point
    public static func runKey(_ base: String, _ ids: [some Hashable & CustomStringConvertible]) -> String }
public enum Marquee { public static func rect(enclosing a: Point, _ b: Point) -> Rect
    public static func union<ID: Hashable>(_ selection: [ID], _ found: [ID], extending: Bool) -> [ID] }

// Layers/LayerTree.swift (EK-2 stub, EK-12 body); Layers/LayerFollow.swift (EK-13)
public protocol LayerPayload: Hashable & Sendable { var holdsChildren: Bool { get } }
public struct LayerNode<Payload: LayerPayload>: Hashable, Sendable, Identifiable {
    public var id: String, name: String, isHidden: Bool, isLocked: Bool, children: [LayerNode], followsID: String?, payload: Payload }
public struct LayerRow: Hashable, Sendable { public var id: String, name: String, depth: Int, isHidden: Bool, isLocked: Bool,
    inheritsHidden: Bool, inheritsLocked: Bool, holdsChildren: Bool, isExpanded: Bool }
public enum ArrangeStep: Sendable { case bringToFront, bringForward, sendBackward, sendToBack }
public enum TreeRefusal: Error, Equatable { case unknown(String), intoItself(String), notAContainer(String), locked(String), cycle(String) }
public struct LayerTree<Payload: LayerPayload>: Hashable, Sendable {
    public init(_ roots: [LayerNode<Payload>] = []); public var roots: [LayerNode<Payload>]
    public func node(_ id: String) -> LayerNode<Payload>?; public func ancestors(of id: String) -> [String]?
    public func rows(expanded: Set<String>) -> [LayerRow]; public var frontToBack: [String] { get }
    public func isEffectivelyHidden(_ id: String) -> Bool; public func isEffectivelyLocked(_ id: String) -> Bool
    public mutating func update(_ id: String, _ body: (inout LayerNode<Payload>) -> Void) -> Bool
    public mutating func move(_ id: String, into parent: String?, at index: Int) throws(TreeRefusal)
    public mutating func arrange(_ step: ArrangeStep, _ ids: [String]) throws(TreeRefusal)
    public mutating func group(_ ids: [String], name: String, payload: Payload, mint: () -> String) throws(TreeRefusal) -> String
    public mutating func ungroup(_ id: String) throws(TreeRefusal)
    public mutating func duplicate(_ ids: [String], mint: () -> String) -> [String]
    public func follows(_ id: String, _ ancestor: String) -> Bool                     // LayerFollow
    public func worldPlacement(of id: String, local: (LayerNode<Payload>) -> Matrix) -> Matrix
    public mutating func setFollow(_ id: String, _ parent: String?, local: (LayerNode<Payload>) -> Matrix,
                                   keepingPlace: (inout LayerNode<Payload>, Matrix) -> Void) throws(TreeRefusal)
}

// Keys/Keys.swift (EK-3 stub, EK-15 body); Keys/KeyRules.swift (EK-16)
public enum Track<Property: Hashable & Codable & Sendable>: Hashable, Codable, Sendable { case property(Property), all }
public struct KeyRef<Property: Hashable & Codable & Sendable>: Hashable, Codable, Sendable { public var layerID: String, track: Track<Property>, frame: Int }
public enum KeyState: Sendable, Equatable { case notAnimated, animated, keyedHere }
public struct Segment<Property: Hashable & Codable & Sendable>: Hashable, Sendable { public var key: KeyRef<Property>, endFrame: Int, easing: Easing }
public enum EasePreset: String, CaseIterable, Sendable { case linear, ease, easeIn, easeOut, easeInOut, hold; public var easing: Easing { get }; public var title: String { get } }
public enum EaseCurve { public static func handles(of e: Easing) -> [Point]?; public static func moving(_ handle: Int, to p: Point, in e: Easing) -> Easing
    public static func samples(of e: Easing, count: Int) -> [Point] }                   // count 1 gives one point, capped at 4096
public enum RemovePolicy: Sendable { case singleStays, propertyGoesStatic }
public enum KeyRules {
    public static func state(_ track: [Keyframe], at frame: Int) -> KeyState
    public static func toggleKey(_ track: inout [Keyframe], at frame: Int, value: Double, leaving: RemovePolicy) -> Bool
    public static func toggleAnimated(_ track: inout [Keyframe], at frame: Int, lastFrame: Int, value: Double) -> Bool
    public static func moveKeys(_ tracks: inout [String: [Keyframe]], _ frames: Set<Int>, by delta: Int, clampedTo range: ClosedRange<Int>) throws(KeyRefusal)
    public static func removeKeys(_ track: inout [Keyframe], _ frames: Set<Int>, leaving: RemovePolicy)
    public static func insertFrames(_ track: inout [Keyframe], _ count: Int, at frame: Int)
    public static func removeFrames(_ track: inout [Keyframe], _ count: Int, at frame: Int)
}

// Snap/Snapping.swift (EK-29 stub, EK-18 body); Snap/SnapLines.swift, Snap/SnapGaps.swift (EK-29 stubs, snapping SN-2 and SN-3 bodies)
public struct SnapLine: Hashable, Sendable { public enum Axis: Hashable, Sendable { case x, y }; public var axis: Axis, at: Double, from: Double, to: Double }
public struct SnapGap: Hashable, Sendable { public var axis: SnapLine.Axis, from: Double, to: Double, across: Double, isSpacing: Bool; public var length: Int { get } }
public struct SnapGuides: Hashable, Sendable { public var lines: [SnapLine], gaps: [SnapGap]; public var summary: String { get }
    public init(lines: [SnapLine] = [], gaps: [SnapGap] = []); public static let empty: SnapGuides; public static let fake: SnapGuides }
public struct SnapCandidate: Hashable, Sendable { public var id: String?, frame: Rect }
public enum Snapping { public static func candidates<P: LayerPayload>(in tree: LayerTree<P>, moving: [String], drawingInto parent: String?,
    page: Rect, frame: (LayerNode<P>) -> Rect) -> [SnapCandidate]
    public static func offset(lines: Double?, gaps: Double?, wholePoints: Double) -> Double }
public struct SnapLines: Sendable { public init(_ c: [SnapCandidate]); public func offset(_ axis: SnapLine.Axis, for values: [Double], tolerance: Double) -> Double?
    public func lines(on box: Rect) -> [SnapLine] }
public struct SnapGaps: Sendable { public init(_ c: [SnapCandidate]); public func spacingOffset(_ axis: SnapLine.Axis, for box: Rect, tolerance: Double) -> Double?
    public func gaps(around box: Rect) -> [SnapGap] }

// Transform/BoxMath.swift, Transform/HandleHit.swift (EK-3 stubs, EK-20 bodies)
public struct LayerTransform: Hashable, Sendable { public var scaleX: Double = 1, scaleY: Double = 1, degrees: Double = 0, dx: Double = 0, dy: Double = 0 }
public enum BoxMath {
    public static func resized(_ rect: Rect, _ handle: EditorHandle, by delta: Point, modifiers: EditModifiers) -> Rect   // ⇧ aspect, ⌥ centre, min 1, never flips
    public static func scaled(_ rect: Rect, from old: Rect, to new: Rect) -> Rect
    public static func snappedDegrees(_ d: Double, modifiers: EditModifiers) -> Double                              // ⇧: 15°
    public static func handles(of rect: Rect, size: Double) -> [EditorHandle: Rect] }
public enum HandleHit { public static func handle(at p: Point, in rect: Rect, tolerance: Double) -> EditorHandle?    // Chebyshev; corners win ties
    public static func tolerance(screen: Double, zoom: Double) -> Double }

// Export/ExportRun.swift (EK-3 stub, EK-22 body)
public enum ExportRun<Options: Hashable & Sendable>: Hashable, Sendable { case idle, editing(Options), running(Options, done: Int, total: Int), finished(Options, [String]), failed(Options, String)
    public mutating func begin(_ o: Options) -> Bool; public mutating func start(total: Int) -> Bool
    public mutating func progressed(done: Int); public mutating func end(_ r: Result<[String], any Error>); public mutating func dismiss() }

// Session/DocumentSession.swift, Session/VersionedJSON.swift (EK-3 stubs, EK-24 bodies)
public enum SaveStatus: Hashable, Sendable { case unsaved, saved, saving, failed(String), readOnly }
public struct DocumentSession: Hashable, Sendable { public var savedToken: Int, currentToken: Int, lastEdit: Date?, lastAutosave: Date?, status: SaveStatus
    public var isDirty: Bool { get }; public func autosaveDue(now: Date, delay: TimeInterval) -> Bool
    public mutating func didSave(token: Int); public mutating func didEdit(token: Int, at: Date) }
public struct RecoveryOffer: Hashable, Sendable { public var name: String, savedAt: Date; public var prompt: String { get } }
public enum VersionedJSON { public static func probe(_ data: Data, key: String = "version") throws(VersionError) -> Int
    public static func words(for error: DecodingError) -> String }

// Stroke/Stroke.swift, Stroke/BrushSettings.swift, Stroke/LiveCopy.swift (EK-29 stubs, EK-28 bodies)
public struct StrokeSample: Hashable, Sendable { public var point: Point, pressure: Double, time: TimeInterval }   // pressure clamped 0...1, NaN → 1
public struct StrokeSegment: Hashable, Sendable { public var p0: Point, c1: Point, c2: Point, p1: Point, pressure: ClosedRange<Double> }
public struct StrokeSmoother: Sendable { public init(); public mutating func add(_ s: StrokeSample) -> StrokeSegment?   // one segment late; drops a repeated point
    public mutating func finish() -> StrokeSegment?; public static func flattened(_ seg: StrokeSegment, tolerance: Double) -> [Point] }  // n = ceil(sqrt(3·bend)), 1...64
public enum DabSpacer { public static func centers(_ a: Point, _ b: Point, spacing: Double, cap: Int = 10_000) -> [Point] }
public struct BrushSettings: Hashable, Codable, Sendable { public var size: Double, hardness: Double, opacity: Double, flow: Double, spacing: Double
    public static let ranges: (size: ClosedRange<Double>, percent: ClosedRange<Double>); public mutating func apply(_ edit: BrushEdit) -> Bool }  // clamps, ignores NaN
public struct BrushPreset: Hashable, Codable, Sendable, Identifiable { public var id: String, name: String, settings: BrushSettings }
public struct LiveCopy<Model: Sendable>: Sendable { public private(set) var shown: Model?; public mutating func begin(_ m: Model); public mutating func edit(_ body: (inout Model) -> Void) -> Bool
    public mutating func take() -> Model? }   // nil when nothing began; begin twice is ignored
```

The per-pixel capsule, falloff and max-coverage blend stay Photo's until
creative-core's stamp op lands (`needs-core`, filed by adopt-kernel-brush).

Fakes (`Sources/SuiteKernel/Fakes/KernelFixtures.swift`, EK-2): `tree200`
(200 rows, three groups deep, one hidden group, one locked), `cards` (the
snapping packet's A, B, C, Title, Pair, Locked, Hidden in Desktop 1440 ×
1024), `bounceTrack` (four keys), `ExportRunSteps`, `strokeSamples` (40 samples with pressure).

## Pseudocode

- `History.record`: `if key != nil && key == openKey { currentStepID = next(); return }`;
  else push `(name, payload, key)`, drop redo, trim to `limit` (the base
  absorbs), `openKey = key`, `currentStepID = next()`. `undo`: `openKey =
  nil`; pop; `redo.push(apply(payload))`; `currentStepID = step.idBefore`.
  Ids come from a counter that never rewinds, so `isDirty` is exact.
- `Selection.pick(id, .extend, order:)`: with `order` and an anchor, replace
  the anchor's contiguous run with `order[anchor...id]`; without `order`,
  append if `canAdd`. `.toggle` removes or appends; `.replace` sets `[id]`
  and the anchor. `primary` is always the last.
- `LayerTree.move(id, into:, at:)`: refuse `unknown`, `intoItself` (the
  parent is `id` or below it), `notAContainer`, `locked` (an effectively
  locked destination); remove, then insert at `min(index, count)`.
- `setFollow(id, parent)`: refuse `cycle` when `follows(parent, id)`; compute
  `world = worldPlacement(of: id)`, set `followsID`, then `keepingPlace(&node,
  inverse(worldPlacement(of: parent)) * world)`.
- `Snapping.candidates`: siblings of each moving id (or the children of the
  frame drawn into), their parent frames, the page; skip hidden and the
  moving subtree; keep locked. `offset`: `lines ?? gaps ?? wholePoints`.
- `BoxMath.resized`: the handle's edges move by `delta`; `.shift` keeps the
  aspect from the larger axis change; `.option` mirrors the move on the
  opposite edge; clamp width and height at 1 from the fixed edge.
- `ExportRun.progressed(done)`: ignored unless `.running`; `done = max(done,
  old)`, clamped to `total`.
- `StrokeSmoother.add`: keep the last 4 samples; with 4, emit the segment
  p1→p2 with centripetal knots (sqrt of chord length) converted to cubic
  handles; at the start mirror p0 across p1; `finish` mirrors the far end.

## Tasks

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| EK-1 | – | The targets task: `SuiteKernel` and `SuiteKernelTests` in `Package.swift` (every Model and SuiteUI depend on it), `project.yml`, `scripts/test-scope` mapping, `Geometry.swift` (typealiases, `EditorHandle`, `Pick`, `Direction`, `EditModifiers`), the kernel's header doc, the C4 container and geometry part; KJ0 written, disabled by name | `Package.swift`, `project.yml`, `scripts/test-scope`, `Sources/SuiteKernel/SuiteKernel.swift`, `Sources/SuiteKernel/Geometry.swift`, `Tests/SuiteKernelTests/KernelShapeTests.swift`, `docs/c4/parts/creative-apps/suite-kernel/container.json`, `docs/c4/parts/creative-apps/suite-kernel/kernel-geometry.json` | – | ~260, 8 |
| EK-2 | – | Stubs with doc comments: `History`, `HistoryReading`, `Selection`, `LayerTree`, `LayerNode`, `LayerRow`, `TreeRefusal`; `KernelFixtures` (`tree200`, `cards`); their C4 parts; KJ0 covers them | `Sources/SuiteKernel/History/History.swift`, `Sources/SuiteKernel/Selection/Selection.swift`, `Sources/SuiteKernel/Layers/LayerTree.swift`, `Sources/SuiteKernel/Fakes/KernelFixtures.swift`, `Tests/SuiteKernelTests/KernelShapeTests.swift`, `docs/c4/parts/creative-apps/suite-kernel/kernel-history.json`, `docs/c4/parts/creative-apps/suite-kernel/kernel-selection.json`, `docs/c4/parts/creative-apps/suite-kernel/kernel-layers.json` | EK-1 | ~380, 8 |
| EK-3 | – | Stubs with doc comments: `Keys`, `KeyRules`, `BoxMath`, `HandleHit`, `ExportRun`, `DocumentSession`, `VersionedJSON`; their C4 parts; KJ0 turned on | `Sources/SuiteKernel/Keys/Keys.swift`, `Sources/SuiteKernel/Keys/KeyRules.swift`, `Sources/SuiteKernel/Transform/BoxMath.swift`, `Sources/SuiteKernel/Transform/HandleHit.swift`, `Sources/SuiteKernel/Export/ExportRun.swift`, `Sources/SuiteKernel/Session/DocumentSession.swift`, `Sources/SuiteKernel/Session/VersionedJSON.swift`, `Tests/SuiteKernelTests/KernelShapeMoreTests.swift`, `docs/c4/parts/creative-apps/suite-kernel/kernel-keys.json`, `docs/c4/parts/creative-apps/suite-kernel/kernel-transform.json`, `docs/c4/parts/creative-apps/suite-kernel/kernel-export-session.json` | EK-1 | ~340, 11 |
| EK-4 | – | The `editor-kernel` gallery page (in `SuiteGallery.areas`) with `LayerTreeList` over `tree200`'s rows: disclosure, eye and lock, drag into a parent reporting `move`; the journey written first, `XCTSkip("waits on EK-6")` | `Sources/SuiteUI/SuiteGallery.swift`, `Sources/SuiteUI/Gallery/GalleryEditorKernel.swift`, `Sources/SuiteUI/LayerTreeList.swift`, `Tests/SuiteUITests/LayerTreeListTests.swift`, `UITests/SuiteJourneyTests+EditorKernel.swift` | EK-2 | ~360, 5 |
| EK-5 | – | `SelectionHandles` (eight handles and the rotate knob as marks, hover names the handle) and `SnapGuideMarks` (line between two boxes, distance label, accessibility value = `summary`) on the page; snapshots | `Sources/SuiteUI/SelectionHandles.swift`, `Sources/SuiteUI/SnapGuideMarks.swift`, `Sources/SuiteUI/Gallery/GalleryEditorKernel.swift`, `Tests/AppSnapshotTests/SuiteEditorKernelSnapshots.swift` | EK-4 | ~320, 4 |
| EK-6 | – | The render budget test (120-sample tree drag ≤ 3 window bodies) and the journey turned on | `Tests/AppSnapshotTests/RenderBudgetEditorKernelTests.swift`, `UITests/SuiteJourneyTests+EditorKernel.swift` | EK-5 | ~160, 2 |
| EK-7 | – | Checks first: `HistoryTests` (record, fold, run ends on undo/redo/endRun, ids never repeat, dirty exact, limit rolls into the base, jump) and KJ1, disabled | `Tests/SuiteKernelTests/HistoryTests.swift` | EK-2 | ~180, 1 |
| EK-8 | – | `History` body and its plan; turns on EK-7 | `Sources/SuiteKernel/History/History.swift`, `Tests/mutations/SuiteKernel.History.json`, `Tests/SuiteKernelTests/HistoryTests.swift` | EK-7 | ~200, 3 |
| EK-9 | – | Checks first: `SelectionTests` (replace/toggle/extend with and without an order, primary, canAdd, prune, grid move) and `NudgeMarqueeTests`; KJ2, disabled | `Tests/SuiteKernelTests/SelectionTests.swift`, `Tests/SuiteKernelTests/NudgeMarqueeTests.swift` | EK-2 | ~220, 2 |
| EK-10 | – | `Selection` body, `Nudge`, `Marquee`, their plans; turns on EK-9 | `Sources/SuiteKernel/Selection/Selection.swift`, `Sources/SuiteKernel/Selection/Nudge.swift`, `Sources/SuiteKernel/Selection/Marquee.swift`, `Tests/mutations/SuiteKernel.Selection.json`, `Tests/mutations/SuiteKernel.Nudge.json`, `Tests/SuiteKernelTests/SelectionTests.swift`, `Tests/SuiteKernelTests/NudgeMarqueeTests.swift` | EK-9 | ~300, 7 |
| EK-11 | – | Checks first: `LayerTreeTests` (rows, cascade, move refusals, arrange, group, ungroup, duplicate) and `LayerFollowTests` (follows, cycle refusal, keep place); KJ3, disabled | `Tests/SuiteKernelTests/LayerTreeTests.swift`, `Tests/SuiteKernelTests/LayerFollowTests.swift` | EK-2 | ~260, 2 |
| EK-12 | – | `LayerTree` body (nesting, rows, cascade, move, arrange, group, ungroup, duplicate) and its plan; turns on `LayerTreeTests` | `Sources/SuiteKernel/Layers/LayerTree.swift`, `Tests/mutations/SuiteKernel.LayerTree.json`, `Tests/SuiteKernelTests/LayerTreeTests.swift` | EK-11 | ~340, 3 |
| EK-13 | – | `LayerFollow` (`follows`, `worldPlacement`, `setFollow` keeping place) and its plan; turns on `LayerFollowTests` | `Sources/SuiteKernel/Layers/LayerFollow.swift`, `Tests/mutations/SuiteKernel.LayerFollow.json`, `Tests/SuiteKernelTests/LayerFollowTests.swift` | EK-11 | ~180, 3 |
| EK-14 | – | Checks first: `KeyRulesTests` (state, toggle, move clamped all or nothing, remove with both policies, insert and remove frames) and `EaseCurveTests` (presets, handles, moving, samples at count 1 and 5000); KJ4, disabled | `Tests/SuiteKernelTests/KeyRulesTests.swift`, `Tests/SuiteKernelTests/EaseCurveTests.swift` | EK-3 | ~240, 2 |
| EK-15 | – | `Keys` body (`KeyRef`, `Track`, `Segment`, `EasePreset`, `EaseCurve`) and its plan; turns on `EaseCurveTests` | `Sources/SuiteKernel/Keys/Keys.swift`, `Tests/mutations/SuiteKernel.Keys.json`, `Tests/SuiteKernelTests/EaseCurveTests.swift` | EK-14 | ~220, 3 |
| EK-16 | – | `KeyRules` body and its plan; turns on `KeyRulesTests` | `Sources/SuiteKernel/Keys/KeyRules.swift`, `Tests/mutations/SuiteKernel.KeyRules.json`, `Tests/SuiteKernelTests/KeyRulesTests.swift` | EK-14 | ~260, 3 |
| EK-17 | – | Checks first: `SnapCandidateTests` on `cards` and `tree200` (siblings, parent frames, page, hidden skipped, locked kept, moving subtree skipped, offset order); KJ5, disabled | `Tests/SuiteKernelTests/SnapCandidateTests.swift` | EK-29 | ~160, 1 |
| EK-18 | – | `Snapping` body (`candidates`, `offset`, `.fake`, `summary`) and its plan; turns on EK-17 (`SnapLines`/`SnapGaps` stay stubs for snapping SN-2, SN-3) | `Sources/SuiteKernel/Snap/Snapping.swift`, `Tests/mutations/SuiteKernel.Snapping.json`, `Tests/SuiteKernelTests/SnapCandidateTests.swift` | EK-17, EK-12 | ~200, 3 |
| EK-19 | – | Checks first: `BoxMathTests` (each handle, Shift aspect, Option centre, min 1, never flips, `scaled` for several, 15°) and `HandleHitTests` (Chebyshev, corners win, tolerance ÷ zoom); KJ6, disabled | `Tests/SuiteKernelTests/BoxMathTests.swift`, `Tests/SuiteKernelTests/HandleHitTests.swift` | EK-3 | ~220, 2 |
| EK-20 | – | `BoxMath` and `HandleHit` bodies and plans; turns on EK-19 | `Sources/SuiteKernel/Transform/BoxMath.swift`, `Sources/SuiteKernel/Transform/HandleHit.swift`, `Tests/mutations/SuiteKernel.BoxMath.json`, `Tests/mutations/SuiteKernel.HandleHit.json`, `Tests/SuiteKernelTests/BoxMathTests.swift`, `Tests/SuiteKernelTests/HandleHitTests.swift` | EK-19 | ~280, 6 |
| EK-21 | – | Checks first: `ExportRunTests` (every transition, progress never back, clamp to total, cancel to idle, dismiss); KJ7, disabled | `Tests/SuiteKernelTests/ExportRunTests.swift` | EK-3 | ~140, 1 |
| EK-22 | – | `ExportRun` body and its plan; turns on EK-21 | `Sources/SuiteKernel/Export/ExportRun.swift`, `Tests/mutations/SuiteKernel.ExportRun.json`, `Tests/SuiteKernelTests/ExportRunTests.swift` | EK-21 | ~160, 3 |
| EK-23 | – | Checks first: `DocumentSessionTests` (dirty exact after undo to saved, status, autosave due, recovery prompt) and `VersionedJSONTests` (probe, newer version, damaged, words); KJ8, disabled | `Tests/SuiteKernelTests/DocumentSessionTests.swift`, `Tests/SuiteKernelTests/VersionedJSONTests.swift` | EK-3 | ~200, 2 |
| EK-24 | – | `DocumentSession`, `RecoveryOffer`, `VersionedJSON` bodies and plans; turns on EK-23 | `Sources/SuiteKernel/Session/DocumentSession.swift`, `Sources/SuiteKernel/Session/VersionedJSON.swift`, `Tests/mutations/SuiteKernel.DocumentSession.json`, `Tests/mutations/SuiteKernel.VersionedJSON.json`, `Tests/SuiteKernelTests/DocumentSessionTests.swift`, `Tests/SuiteKernelTests/VersionedJSONTests.swift` | EK-23 | ~280, 6 |
| EK-25 | – | KJ9, the full walk: one document on the fixtures through selection, a tree move, a nudge run folded into one step, undo back to saved reading clean, a key toggle, a snap candidate set, an export run | `Tests/SuiteKernelTests/KernelWalkTests.swift` | EK-8, EK-10, EK-12, EK-13, EK-16, EK-18, EK-20, EK-22, EK-24, EK-28 | ~180, 1 |
| EK-27 | – | Checks first: `StrokeTests` (segment one late, repeated point dropped, pressure clamp and NaN, mirrored ends, flatten count 1...64, dab spacing and cap, settings clamp and NaN, preset round trip, `LiveCopy` take once) and KJ10, disabled | `Tests/SuiteKernelTests/StrokeTests.swift` | EK-29 | ~220, 1 |
| EK-28 | – | `StrokeSmoother`, `DabSpacer`, `BrushSettings`, `BrushPreset`, `LiveCopy` bodies and plans; turns on EK-27 | `Sources/SuiteKernel/Stroke/Stroke.swift`, `Sources/SuiteKernel/Stroke/BrushSettings.swift`, `Sources/SuiteKernel/Stroke/LiveCopy.swift`, `Tests/mutations/SuiteKernel.Stroke.json`, `Tests/mutations/SuiteKernel.BrushSettings.json`, `Tests/SuiteKernelTests/StrokeTests.swift` | EK-27 | ~340, 6 |
| EK-29 | – | Stubs with doc comments: `StrokeSample`, `StrokeSegment`, `StrokeSmoother`, `DabSpacer`, `BrushSettings`, `BrushPreset`, `LiveCopy`, `Snapping`, `SnapLines`, `SnapGaps`; `strokeSamples` fixture; the stroke and snap C4 parts | `Sources/SuiteKernel/Stroke/Stroke.swift`, `Sources/SuiteKernel/Stroke/BrushSettings.swift`, `Sources/SuiteKernel/Stroke/LiveCopy.swift`, `Sources/SuiteKernel/Snap/Snapping.swift`, `Sources/SuiteKernel/Snap/SnapLines.swift`, `Sources/SuiteKernel/Snap/SnapGaps.swift`, `Tests/SuiteKernelTests/KernelShapeStrokeTests.swift`, `docs/c4/parts/creative-apps/suite-kernel/kernel-stroke.json`, `docs/c4/parts/creative-apps/suite-kernel/kernel-snap.json` | EK-1 | ~300, 9 |
| EK-30 | #953 | `ExportSheet` (rows from a `FormatChoice` list, size and quality `StudioScrubRow`s, a progress bar and the finished or failed line, over `ExportRun` readouts), `StrokePacer` and `PointerPressure` moved from Photo's shape, `BrushCursorMark` in the CanvasMarks family; the page's Export button and stroke pad on the fakes; snapshots | `Sources/SuiteUI/ExportSheet.swift`, `Sources/SuiteUI/StrokePacer.swift`, `Sources/SuiteUI/PointerPressure.swift`, `Sources/SuiteUI/BrushCursorMark.swift`, `Sources/SuiteUI/Gallery/GalleryEditorKernelChrome.swift`, `Tests/SuiteUITests/ExportSheetTests.swift`, `Tests/SuiteUITests/StrokePacerTests.swift`, `Tests/AppSnapshotTests/SuiteEditorKernelChromeSnapshots.swift` | EK-4 | ~390, 8 |
| EK-31 | – | `ToolKeys`: `tool(forKey:in:)` over `PaletteTool` shortcuts and `KeyModifiers(nsEvent:)`, the one copy of each; the page's status line names the picked tool; render budget for the stroke pad (120 samples ≤ 1 body) | `Sources/SuiteUI/ToolKeys.swift`, `Tests/SuiteUITests/ToolKeysTests.swift`, `Sources/SuiteUI/Gallery/GalleryEditorKernelChrome.swift`, `Tests/AppSnapshotTests/RenderBudgetEditorKernelStrokeTests.swift` | EK-30 | ~200, 4 |
| EK-26 | – | Shared prose: suite.md (the `SuiteKernel` tier and the rule that no app copies a kernel concept), suiteui.md (the three halves), `docs/engineering.md` (layers), `status: built`; `feature-done` | `docs/blueprints/suite.md`, `docs/blueprints/suiteui.md`, `docs/engineering.md`, `docs/blueprints/suiteui/features/editor-kernel.wave.json` | EK-6, EK-25, EK-31 | ~120, 4; `feature-done` |

EK-2, EK-3 and EK-29 each add stub files EK-1 never touches, so they run together.
Each logic slice's test task owns only test files and its code task fills
the stub EK-2 or EK-3 added, so the eight code tasks share no file. EK-12
and EK-13 split the tree into two files for that reason. EK-18 walks the
tree, so it waits on EK-12. EK-4 edits `SuiteGallery.swift`, owned by two
built features (`depends`); nothing else here touches an existing file.
`docs/blueprints/suiteui.md` is owned by canvas-marks and canvas-host, so
EK-26 also waits on canvas-host's CH-d in `.wave.json`.

## Build waves

- Wave 1: EK-1. Independent in this wave: EK-1 alone.
- Wave 2: EK-2, EK-3, EK-29. Independent in this wave: all three.
- Wave 3: EK-4, EK-7, EK-9, EK-11, EK-14, EK-17, EK-19, EK-21, EK-23, EK-27. Independent in this wave: all ten.
- Wave 4: EK-5, EK-8, EK-10, EK-12, EK-13, EK-15, EK-16, EK-20, EK-22, EK-24, EK-28, EK-30. Independent in this wave: all twelve.
- Wave 5: EK-6, EK-18, EK-31. Independent in this wave: all three.
- Wave 6: EK-25. Independent in this wave: EK-25 alone.
- Wave 7: EK-26 (shared prose, `feature-done`, final). Independent in this wave: EK-26 alone.

Longest chain: EK-1 → EK-2 → EK-4 → EK-5 → EK-6 → EK-26 (6); EK-1 → EK-2 →
EK-4 → EK-30 → EK-31 → EK-26 is as long. Chain of 6: EK-2 adds the stubs
the page draws from; EK-5 (and EK-30) add to EK-4's page; EK-6 and EK-31
time them; EK-26 is the final prose task.

## Acceptance test per task

Checks first (rule 13): KJ0 merges in EK-1 disabled and turns on in EK-3;
each logic slice's tests merge in its first task disabled by name and turn
on with its code task; the journey merges in EK-4 skipped and turns on in
EK-6. Mutations (rule 14) go in the plan the task owns and run with
`scripts/mutate --plan SuiteKernel.<File>`.

| id | test | fails when | mutations |
|---|---|---|---|
| EK-1 | `KernelShapeTests.geometryAliasesAndHandles` | `EditorHandle.allCases.count != 10`, `.topLeft.isCorner` false, `swift build` on Linux fails to link SuiteKernel | – (declarations) |
| EK-2 | `KernelShapeTests.stubsReturnFakes` | a stub traps or `tree200.rows(expanded: []).count != 7` roots | – |
| EK-3 | `KernelShapeMoreTests.allModulesDeclared`, KJ0 | any type missing | – (declarations) |
| EK-4 | `LayerTreeListTests.rowsAndDropTargets`; `testEditorKernelGallery` steps 1, 2 | a row has no stable id; a drop onto a non-container is accepted; the page is not in the index | – (UI, rows in, closures out) |
| EK-5 | `SuiteEditorKernelSnapshots` (handles, guides); steps 3 to 5 | a handle missing; the label not "100"; accessibility value differs from `summary` | – |
| EK-6 | `RenderBudgetEditorKernelTests.testTreeDragBodies` | bodies > 3 over 120 samples | – |
| EK-7 | `HistoryTests` (disabled) | – | – |
| EK-8 | `HistoryTests`, KJ1 | see mutations | `openKey` not cleared in `undo` (two edits fold after an undo) → `HistoryTests.undoEndsRun`; `limit` trim uses `<=` (keeps one extra) → `.limitRollsIntoBase`; `currentStepID` reused after fold → `.idsNeverRepeat`; `isDirty` compares names → `.dirtyExactAfterUndoToSaved` |
| EK-9 | `SelectionTests`, `NudgeMarqueeTests` (disabled) | – | – |
| EK-10 | both, KJ2 | see mutations | `.extend` without an order replaces → `SelectionTests.extendAppendsOnAStage`; range uses `anchor..<id` → `.extendRangeIsClosed`; `canAdd` skipped on toggle → `.toggleRefusesLocked`; `Nudge.delta` large uses 5 → `NudgeMarqueeTests.largeIsTen`; `Marquee.union` keeps duplicates → `.unionDedupes` |
| EK-11 | `LayerTreeTests`, `LayerFollowTests` (disabled) | – | – |
| EK-12 | `LayerTreeTests`, KJ3 | see mutations | `intoItself` checks only the direct child → `LayerTreeTests.refusesIntoOwnDescendant`; cascade reads `isHidden` only → `.hiddenCascades`; `arrange(.bringForward)` on the top is not a no-op → `.bringForwardAtTopStays`; `ungroup` drops order → `.ungroupKeepsOrder` |
| EK-13 | `LayerFollowTests` | see mutations | cycle check compares ids by equality only → `LayerFollowTests.refusesCycleTwoDeep`; `worldPlacement` multiplies in the wrong order → `.worldComposesParentFirst`; `setFollow` skips `keepingPlace` → `.keepsScreenPlace` |
| EK-14 | `KeyRulesTests`, `EaseCurveTests` (disabled) | – | – |
| EK-15 | `EaseCurveTests`, `KernelShapeMoreTests.presetsSixCases` | see mutations | `samples(count: 1)` returns [] → `EaseCurveTests.oneSampleIsOnePoint`; cap uses 4095 → `.capAt4096`; `moving` swaps x1/y1 → `.movingHandleZero` |
| EK-16 | `KeyRulesTests`, KJ4 | see mutations | `moveKeys` clamps per key, not all or nothing → `KeyRulesTests.moveRefusesPastEnd`; `removeKeys(.propertyGoesStatic)` leaves one key → `.staticWhenOneLeft`; `insertFrames` shifts keys `>=` frame instead of `>` → `.insertKeepsKeyAtFrame`; `state` returns `.animated` for one key → `.oneKeyIsNotAnimated` |
| EK-17 | `SnapCandidateTests` (disabled) | – | – |
| EK-18 | `SnapCandidateTests`, KJ5 | see mutations | hidden layers kept → `SnapCandidateTests.skipsHidden`; locked skipped → `.keepsLocked`; a moving child's parent not listed → `.listsParentFrame`; `offset` prefers gaps → `.linesBeforeGaps` |
| EK-19 | `BoxMathTests`, `HandleHitTests` (disabled) | – | – |
| EK-20 | both, KJ6 | see mutations | min 0 → `BoxMathTests.minimumOnePoint`; `.shift` ignores the smaller axis → `.shiftKeepsAspect`; `.option` moves one edge → `.optionResizesFromCentre`; `HandleHit` uses Euclidean distance → `HandleHitTests.chebyshev`; edges win ties → `.cornersWinTies`; `tolerance` multiplies by zoom → `.toleranceDividesByZoom` |
| EK-21 | `ExportRunTests` (disabled) | – | – |
| EK-22 | `ExportRunTests`, KJ7 | see mutations | `progressed` allows a smaller `done` → `ExportRunTests.progressNeverBack`; `done > total` kept → `.clampsToTotal`; cancel goes to `.failed` → `.cancelReturnsToIdle`; `begin` while running accepted → `.beginRefusedWhileRunning` |
| EK-23 | `DocumentSessionTests`, `VersionedJSONTests` (disabled) | – | – |
| EK-24 | both, KJ8 | see mutations | `isDirty` is a flag set on edit → `DocumentSessionTests.cleanAfterUndoToSaved`; `autosaveDue` uses `lastAutosave` only → `.dueMeasuresFromLastEdit`; `probe` accepts a newer version → `VersionedJSONTests.refusesNewer`; `words` drops the path → `.wordsNameThePath` |
| EK-27 | `StrokeTests` (disabled) | – | – |
| EK-28 | `StrokeTests`, KJ10 | see mutations | segment emitted on the 3rd sample, not the 4th → `StrokeTests.oneSegmentLate`; repeated point kept → `.dropsRepeatedPoint`; flatten cap 65 → `.flattenCap64`; NaN pressure → 0 → `.nanPressureIsOne`; `DabSpacer` spacing floor 0 → `.spacingFloorOne`; `BrushSettings.apply` skips the clamp → `.clampsSize`; `LiveCopy.take` twice returns the copy twice → `.takeOnce` |
| EK-29 | `KernelShapeStrokeTests.strokeAndSnapStubsDeclared` | a type missing; `SnapGuides.fake.summary != "x 300, gap x 100, spacing x 100"`; the fixture is not 40 samples | – (declarations and fixtures; the fake's `summary` gets its mutation in EK-18) |
| EK-30 | `ExportSheetTests.rowsFollowTheRun`, `StrokePacerTests.spacingIsHalfAFrame`; `SuiteEditorKernelChromeSnapshots`; journey step 6 | the sheet shows a row the run has no choice for; the pacer sends two samples inside one spacing | – (UI) |
| EK-31 | `ToolKeysTests.letterPicksTool`, `.modifiersFromFlags`; `RenderBudgetEditorKernelStrokeTests.testStrokePadBodies`; journey step 7 | B picks nothing; `.shift` lost; bodies > 1 over 120 samples | – (UI) |
| EK-25 | `KernelWalkTests.walk` (KJ9) | any module disagrees with another on the walk's document | – (walk) |
| EK-26 | `scripts/waves render --dry-run`; the blueprint sections exist | status not `built`; a section missing | – |

## Quality tests

| quality row | budget | test |
|---|---|---|
| Linux build | `swift build` and `swift test --filter SuiteKernelTests` green on Ubuntu | CI `Linux` job |
| no app type in the kernel | `grep -rE "import (Design|Photo|Flare|Halo|Library)Model|import SuiteUI|import SuiteModel" Sources/SuiteKernel` finds nothing | `KernelShapeTests.importsOnlyFoundationAndFlareCore` |
| every public symbol documented | no `public` declaration without a `///` line above it | `KernelShapeMoreTests.publicSymbolsDocumented` (a source scan on Linux) |
| history fold | 120 `record` calls with one key are 1 step and 120 ids | `HistoryTests.foldKeepsOneStep` |
| tree rows | `rows(expanded:)` over 2,000 nodes under 2 ms | `Tests/perf-suites.txt` row `KernelBudgetTests` (reported) |
| render: `LayerTreeList` drag reorder (200 rows) | 120-sample drag ≤ 3 window bodies; drop p95 ≤ 8 ms | `RenderBudgetEditorKernelTests.testTreeDragBodies` |
| render: stroke pad through `StrokePacer` and `LiveCopy` | 120-sample drag ≤ 1 window body; input-to-ink p50 ≤ 6 ms | `RenderBudgetEditorKernelStrokeTests.testStrokePadBodies` |
| no dead controls | every control on the page registers in `suite.controls` | `SuiteJourneyTests.testEditorKernelGallery` |
| audit | zero new over the SuiteUI baseline | `audit-suiteui-*.json` |

## Done check

Per slice (rules 6, 15, 17): its tasks merged, its Linux walk green on the
newest dev run containing its last PR, every mutation in its plans caught,
no open `finding`; for EK-u and EK-chrome the feel gate (`mouse` and `taste`
lenses) and their `Mac-Finish:` lines. Then `Belt-Contact-Sheet:` once EK-z is done, and
the seven `adopt-kernel-*` features start their slices as each kernel slice
posts `Belt-Slice-Done:`.
