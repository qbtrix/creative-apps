# Flare: easing curve editor (blueprint)

The first blueprint-first feature. This file is written before any feature
code. It fixes the scope, the screen, the journey, the contract and the tasks,
so a UI track and a logic track can build in parallel and meet at one
integrate PR. The contract and its Fake land with this file
(`Sources/FlareModel/EasingEditing.swift`,
`Sources/FlareModel/FakeEasingEditing.swift`) so both tracks start from code,
not prose.

## Scope

A person picks a layer, sees the keyframe segments of its animated properties
in the inspector, picks one, and shapes how that segment eases: by preset
chip, by dragging one of two curve handles, by scrubbing x1, y1, x2 or y2, or
by nudging a handle with the arrow keys. Every change is one undo step and
undoes exactly.

A segment is the stretch of one property track from a keyframe to the next
keyframe on the same track. Its curve is the start keyframe's FlareCore
`Easing` (`Keyframe.easing` is "applied from this keyframe to the next one").
Edits go through FlareCore's `SetKeyframeEasing` command, which already has
exact undo.

**How a person reaches it.** Flare cannot make keyframes yet (#204 keys a
drag on the stage). The smallest honest route is a **New Sample Animation**
command (File menu and toolbar) that opens a document with one layer, Ball,
keyed on `x` at frames 0, 24 and 48 and on `y` at frames 0 and 24, with Ball
selected. The inspector then lists Ball's three segments. Once #204 lands,
the same list shows keyframes a person made by hand, with no change here.

**Non-goals**

- Making, moving or deleting keyframes (#204 and later issues).
- A timeline or graph editor across many segments; this edits one segment.
- Playback of the document (#11). The preview dot plays the curve only.
- Easing kinds FlareCore lacks (springs, steps with a count, per-axis
  easing). Those would be `needs-core` issues first.
- Copying or pasting easing, saving custom presets.
- Multi-select: editing many segments at once.
- Redo in the editor. Redo stays the Edit menu's job.

## Screen anatomy

The editor lives in Flare's inspector (ideal width 260 pt, so 236 pt of
content inside a 12 pt gutter) below the scene card, while a layer is
selected. Two groups, each under a small caps header: KEYFRAMES, then EASING.

Style: the Studio editor's look in native SwiftUI. Graphite panels from the
grey ramp, small uppercase letter-spaced headers, full-width rounded filled
rows, chips for presets, the blue accent only for selected or active, amber
only for "this is a keyframe". SF fonts through `SuiteFont`, system focus
rings, Light and Dark both from semantic colors.

New tokens are marked **new**; they land in `Tokens.swift` with UI1. Every
other token exists today.

| Element | Size | Tokens and colors |
|---|---|---|
| Group header (KEYFRAMES, EASING) | 10 pt text, 12 pt above, 4 pt below | **new** `SuiteFont.sectionCaps` (caption, semibold), `.textCase(.uppercase)`, **new** `SuiteSize.capsTracking` 0.7; `SuiteColor.secondaryText` |
| Keyframe segment row | full width × 24 pt, radius 6 | `SuiteRadius.small`; rest: clear; hover: `SuiteColor.panelRaised`; selected: `SuiteColor.selectedWell` fill and `SuiteColor.accentText` property name |
| Row contents | 7 pt diamond, 8 pt gap, then text | SF Symbol `diamond.fill` in **new** `SuiteColor.keyframed` (system orange, amber = keyframed); property name 11 pt `SuiteFont.inspectorLabel`; frames "0 → 24" `SuiteFont.inspectorValue` secondary; preset title trailing, `SuiteFont.inspectorMeta` secondary |
| Curve canvas | full width (236) × 180 pt, radius 10 | **new** `SuiteSize.curveEditor` 180; `SuiteRadius.medium`; fill `SuiteColor.field`; plot inset `SuiteSpacing.m` (12) |
| Plot range | x 0...1; y -0.25...1.25, widened to include both handles | computed by `CurveEditor.plotRange(including:)` in SuiteUI, unit-tested |
| Grid | quarter lines, 0.5 pt | `SuiteColor.separator` |
| Linear reference | 1 pt, dash 3 on 3, (0,0) to (1,1) | `SuiteColor.secondaryText` at 50% |
| Curve | 2 pt, round caps and joins, a vector `Path` through the samples | `.primary` |
| Handle arms | 1 pt, (0,0) to handle 1, (1,1) to handle 2 | `SuiteColor.secondaryText` |
| Handles | 10 pt circle, 1.5 pt ring, 28 pt hit target | **new** `SuiteSize.curveHandle` 10, **new** `SuiteSize.curveHandleHit` 28; rest: `SuiteColor.panel` fill, `.primary` ring; focused or dragged: `SuiteColor.accent` fill and a 2 pt accent focus ring 2 pt out. Hold segments draw the handles at 40% opacity (moving one turns the segment into a curve) |
| Preview dot | 6 pt circle riding the curve, 1.2 s run then 0.4 s rest, looping | **new** `SuiteSize.curvePreviewDot` 6; `.primary`; hidden under Reduce Motion; driven by `TimelineView(.animation)` (presentation state, no model writes) |
| Preset chips | 3 columns × 2 rows, 4 pt gaps, each 24 pt tall, radius 8 | **new** `SuiteSize.chip` 24, **new** `SuiteRadius.row` 8; 10 pt `SuiteFont.caption` semibold; rest: `SuiteColor.panelRaised` fill, secondary text; hover: `SuiteColor.field`, primary text; active: `SuiteColor.selectedWell` fill, 1 pt `SuiteColor.accent` border, primary text. Order: Linear, Ease, Ease In, Ease Out, Ease In-Out, Hold |
| Scrub rows x1, y1, x2, y2 | full width × 28 pt, 4 pt apart, radius 8, 12 pt side padding | **new** `SuiteSize.studioRow` 28; `SuiteRadius.row`; track `SuiteColor.panelRaised`; fill to the value `SuiteColor.field`; fill while dragged **new** `SuiteColor.studioFillActive` (accent at 26%); 5 tick dots 2 pt, `.primary` at 22%; value marker 2 pt wide, row height minus 12, `.primary` at 55% (accent while dragged) |
| Row text | label left inside the row, value right | label "X1" 11 pt `SuiteFont.inspectorLabel` secondary; value "0.25" 11 pt semibold `SuiteFont.inspectorValue`, tabular figures, two decimals |
| Row ranges | x 0...1, y -1...2, step 0.01 | drag sideways through `ScrubValue.dragged` (one step per point, Shift ×10, Option ×0.1); click the value to type; Up and Down nudge one step |
| Empty states | inside the EASING group | no segments: "Key a property to shape its easing."; segments but none picked: "Pick a keyframe above." `SuiteFont.inspectorMeta`, secondary |

**Keyboard.** The canvas is focusable and shows the system focus ring. Tab
and Shift-Tab move focus between handle 1 and handle 2. Arrow keys nudge the
focused handle by 0.01, Shift-arrow by 0.1. Each nudge is one move followed by
`endEasingHandleDrag()`, so each is one undo step. Chips and rows are reached
with Tab in reading order and act with Space.

**Accessibility identifiers** (the journey finds controls by these):
`flare.easing.curve`, `flare.easing.handle1`, `flare.easing.handle2`,
`flare.easing.row.x1` ... `flare.easing.row.y2`. Chips and segment rows are
found by their titles ("Ease In", "x 0 → 24"). Handles carry the labels
"Handle 1" and "Handle 2" and their value as "x 0.42, y 0.00".

**Content and control.** All of it is control inside the inspector, so all of
it is flat: no glass, no shadows. The Studio rows and chips are rounded on
purpose; UI1 records that exception in `docs/design.md`.

## Journey

XCUITest: `FlareJourneyTests.testEditEasingOfAKeyframeSegment` (lands with
I1). Each step shoots the whole window as `flare-<step>.png`.

| # | A person does | The window shows | Step name |
|---|---|---|---|
| 1 | Launches Flare and clicks **New Sample Animation** | Ball selected; KEYFRAMES lists x 0 → 24, x 24 → 48, y 0 → 24 | `easing-sample` |
| 2 | Clicks **x 0 → 24** | Row selected; the curve is linear, the Linear chip is active | `easing-segment` |
| 3 | Clicks **Ease In** | Curve bends; Ease In active; X1 reads 0.42 | `easing-preset` |
| 4 | Drags `flare.easing.handle1` up and left | Handle follows; no chip is active; X1 and Y1 rows track it | `easing-drag` |
| 5 | Presses Right five times on the focused handle | X1 grows by 0.05 | `easing-nudge` |
| 6 | Chooses Edit > Undo six times (five nudges, one drag) | The curve is Ease In again; X1 reads 0.42 | `easing-undo` |

The test asserts the X1 row's accessibility value after steps 3 and 6.

## Contract

`Sources/FlareModel/EasingEditing.swift`, landed with this blueprint:

```swift
public struct EasingSegment: Hashable, Sendable, Identifiable {
    public let property: String
    public let startFrame: Int
    public let endFrame: Int
}
public enum EasingHandle: Int, CaseIterable, Sendable { case first = 1, second = 2 }
public enum EasingPreset: String, CaseIterable, Sendable {
    case linear, ease, easeIn, easeOut, easeInOut, hold
    public var title: String { get }
    public var easing: Easing { get }
}

public protocol EasingEditing: Sendable {
    var easingSegments: [EasingSegment] { get }          // sorted by property, then start frame
    var selectedEasingSegment: EasingSegment? { get }
    var currentEasing: Easing? { get }                   // read the current segment's easing
    var canUndo: Bool { get }
    mutating func selectEasingSegment(_ segment: EasingSegment)
    mutating func setEasingPreset(_ preset: EasingPreset)
    mutating func moveEasingHandle(_ handle: EasingHandle, to point: Point)   // x clamped to 0...1
    mutating func endEasingHandleDrag()
    func easingCurveSamples(count: Int) -> [Point]
    mutating func undo()
}

extension EasingEditing {
    public var currentEasingPreset: EasingPreset? { get }
    public var currentEasingHandles: (first: Point, second: Point)? { get }
}

public enum EasingCurve {   // the shared pure math
    public static func handles(of easing: Easing) -> (first: Point, second: Point)
    public static func moving(_ easing: Easing, _ handle: EasingHandle, to point: Point) -> Easing?
    public static func samples(of easing: Easing, count: Int) -> [Point]
}
```

Rules every conformer keeps:

- Handle x is clamped to 0...1. Handle y is not clamped (overshoot). A point
  with a non-finite coordinate changes nothing.
- Linear and hold have their handles at (0,0) and (1,1); moving one turns the
  segment into a cubic Bezier from there.
- Consecutive moves of the same handle are one undo step until
  `endEasingHandleDrag()`. A preset, a selection change or an undo also ends
  the drag. Everything else is one step per call.
- Samples come from FlareCore's `Easing.value(at:)` through
  `EasingCurve.samples`; nobody re-implements the curve.
- `undo()` is FlareWorkspace's existing `undo()`, which is why it fits.

`FlareWorkspace.load(_:)` (internal) also lands here: `newDocument()` now
calls it, and L2's sample uses it, so L1 and L2 never edit the same file.

## Fake

`Sources/FlareModel/FakeEasingEditing.swift`: a value type with four fixed
segments, opacity 12 → 36 (Ease In-Out), x 0 → 24 (Ease, selected),
x 24 → 48 (Linear), y 0 → 24 (Hold), and its own undo stack. It keeps every
rule above and shares `EasingCurve` with the real model, so the two can't
drift. `Tests/FlareModelTests/EasingEditingContractTests.swift` proves it on
Linux. The UI track builds and snapshots against it; it is never wired into a
window.

## Tasks

Every task is one PR to `dev`, branched from `origin/dev`, under 400 changed
lines and 15 files. Owned files are disjoint across tracks. UI tasks use only
the contract and the Fake. Logic tasks touch no SwiftUI.

```
        this PR (contract + Fake)
        ├── UI1 ── UI2 ──┐
        ├── L1 ──────────┼── I1  (after the captain approves UI2's snapshots)
        └── L2 ──────────┘
```

### UI1: Studio curve editor, chips and scrub rows in SuiteUI

Line `suiteui`. Model-free components, so Halo can reuse them for its own
keyframes later.

- **Owned:** `Sources/SuiteUI/CurveEditor.swift` (new),
  `Sources/SuiteUI/StudioScrubRow.swift` (new),
  `Sources/SuiteUI/ChoiceChips.swift` (new), `Sources/SuiteUI/Tokens.swift`
  (edit: the **new** tokens above), `Tests/SuiteUITests/CurveEditorTests.swift`
  (new), `Tests/SuiteUITests/StudioScrubRowTests.swift` (new),
  `Tests/AppSnapshotTests/SuiteCurveEditorSnapshots.swift` (new),
  `docs/design.md` (edit: a short "Studio rows and chips" section),
  `docs/c4/model.json` (edit only if the SuiteUI description needs it).
- **API:** `CurveEditor(samples: [CGPoint], handles: (CGPoint, CGPoint)?,
  dimmedHandles: Bool, onMove: (EasingHandleIndex, CGPoint) -> Void, onEnd:
  () -> Void)` in unit coordinates, with the static `plotRange(including:)`
  and `previewPoint(samples:phase:)`; `StudioScrubRow(label:value:range:
  step:onChange:onEnd:)`; `ChoiceChips(options:selected:onSelect:)`.
  (`EasingHandleIndex` is SuiteUI's own 1 or 2, since SuiteUI knows no Model.)
- **Acceptance tests:** `CurveEditorTests.curveIsOneVectorPath` (the curve
  shape's `path(in:)` for 129 samples is 1 move plus 128 lines),
  `CurveEditorTests.plotRangeWidensForOvershoot`,
  `CurveEditorTests.previewPointStaysInsideTheSamples` (phase below 0, above
  1 and an empty array all give a safe point), `CurveEditorTests.nudgeSteps`
  (0.01, Shift 0.1), `StudioScrubRowTests.fillFractionClampsToRange`, and the
  gallery snapshots `suite-curve-editor-light.png` and
  `suite-curve-editor-dark.png`.
- **Quality checks:** design lint (every size and color from `Tokens.swift`);
  every handle has a tooltip and accessibility label; focus rings visible in
  both snapshots; `TokensTests` still pass; macOS CI job green.

### UI2: Flare easing inspector on the Fake

Line `flare`. Base: UI1's branch until UI1 merges, then `dev`.

- **Owned:** `Sources/FlareApp/FlareEasingInspector.swift` (new: the
  KEYFRAMES list and the EASING group),
  `Tests/AppSnapshotTests/FlareEasingSnapshots.swift` (new).
- **Shape:** `FlareEasingInspector<Editor: EasingEditing>(editor:onSelect:
  onPreset:onMoveHandle:onEndDrag:)`. It reads the editor and calls the
  closures; it never mutates the editor. The snapshot test holds a
  `FakeEasingEditing` and renders the view at inspector width.
- **Acceptance tests:** snapshots `flare-easing-editor-light.png`,
  `flare-easing-editor-dark.png` (Fake as it starts: x 0 → 24, Ease) and
  `flare-easing-editor-2x-dark.png` (rendered at scale 2 to judge sharpness),
  plus `flare-easing-editor-hold-dark.png` (y 0 → 24 selected, dimmed handles,
  step curve).
- **Quality checks:** app-state rule (no assignment or binding to the
  editor); design lint; no dead controls (every chip, row and handle acts on
  the Fake); the snapshot PNG names in the PR body; macOS CI job green. The
  captain reviews these snapshots before I1 starts.

### L1: FlareWorkspace conforms to EasingEditing

Line `flare`. Parallel with UI1, UI2 and L2.

- **Owned:** `Sources/FlareModel/FlareEasing.swift` (new: the conformance),
  `Sources/FlareModel/FlareWorkspace.swift` (edit: stored selected segment,
  a drag serial, a `coalesceKey` passed through `apply` to
  `CommandEngine.perform(_:coalesceKey:)`, clearing the segment in `load` and
  when the layer selection changes), `Tests/FlareModelTests/FlareEasingTests.swift`
  (new), `Tests/FlareModelTests/FlareEasingDragCostTests.swift` (new).
- **Behavior:** segments come from the selected layer's `tracks`: each
  keyframe that has a next keyframe on its track. Presets and handle moves
  run `SetKeyframeEasing` through `apply`; a handle drag coalesces with the
  key `easing/<layer>/<property>/<frame>/<handle>/<serial>`, and
  `endEasingHandleDrag()` bumps the serial. A locked layer's refusal lands in
  `layerError`, as every other layer edit does.
- **Acceptance tests (Linux):** `FlareEasingTests.segmentsListEveryKeyframeWithANext`,
  `.selectingAnotherLayerClearsTheSegment`, `.presetIsOneUndoStepNamedSetKeyframeEasing`,
  `.handleXIsClampedAndYMayOvershoot`, `.oneDragIsOneUndoStep`,
  `.undoRestoresTheDocumentExactly` (document equal to the one before the
  first edit), `.samplesMatchFlareCoreWithinOneBillionth`,
  `.lockedLayerIsRefused`, and `FlareEasingDragCostTests.handleDragP95UnderBudget`.
  Tests seed keyframes with `@testable import FlareModel` and `apply(SetKeyframe(...))`,
  so L1 does not wait for L2.
- **Quality checks:** no-crash lint; Models stay Linux-safe; the PR body
  reports the measured p95 in debug and in release
  (`swift test -c release --filter FlareEasingDragCostTests`).

### L2: New Sample Animation in the model

Line `flare`. Parallel with everything.

- **Owned:** `Sources/FlareModel/FlareSampleAnimation.swift` (new:
  `FlareWorkspace.newSampleAnimation()` builds the Ball document described
  in Scope, opens it with `load(_:)` and selects Ball),
  `Tests/FlareModelTests/FlareSampleAnimationTests.swift` (new).
- **Acceptance tests (Linux):** `FlareSampleAnimationTests.sampleSelectsBallWithFiveKeyframes`
  (x keys at 0, 24, 48 and y keys at 0, 24, all linear),
  `.sampleHasNoUndoHistory`, `.samplePassesFlareFormatValidation`.
- **Quality checks:** no-crash lint; the sample is built from FlareCore types
  only, with no engine code copied.

### I1: wire the editor to FlareWorkspace and walk the journey

Line `flare`. Starts only after the captain approves UI2's snapshots and L1,
L2 and UI2 have merged to `dev`.

- **Owned:** `Sources/FlareApp/FlareApp.swift` (edit: the inspector shows
  `FlareEasingInspector(editor: model, ...)` with closures calling the model;
  a "New Sample Animation" toolbar action), `Sources/FlareApp/FlareCommands.swift`
  (new: File > New Sample Animation; Edit > Undo and Redo on the model, named
  from the engine's action name), `UITests/FlareJourneyTests.swift` (edit:
  `testEditEasingOfAKeyframeSegment`).
- **Acceptance tests:** the journey above passes in the macOS job and
  uploads `flare-easing-sample.png` through `flare-easing-undo.png`;
  `FlareJourneyTests.testEveryMenuOpens` still passes with the new items.
- **Quality checks:** app-state rule; every new command is in the menu bar;
  the ui-screens PNG names in the PR body.

## Quality bar

| Bar | Number | Enforced by |
|---|---|---|
| Handle drag cost in the model, per event | p95 ≤ 1 ms in release; p95 ≤ 5 ms in debug (CI runs debug). 1000 moves on a document of 200 layers × 4 tracks × 25 keys. If debug measures under 1 ms, L1 tightens the debug budget to 2 ms | `FlareEasingDragCostTests.handleDragP95UnderBudget` (L1), budget chosen with `#if DEBUG`; release run reported in L1's PR |
| Curve samples equal FlareCore | max \|y − `Easing.value(at: x)`\| ≤ 1e-9 over 1001 samples, every preset | `EasingEditingContractTests.samplesMatchFlareCoreWithinOneBillionth` (this PR), `FlareEasingTests.samplesMatchFlareCoreWithinOneBillionth` (L1) |
| Handle x clamped, y free | x in 0...1 after any move; y keeps 1.4 and -0.3 | `EasingEditingContractTests.handleXIsClampedAndYMayOvershoot`, `FlareEasingTests.handleXIsClampedAndYMayOvershoot` |
| Undo exact | one drag = one step; one preset = one step; undoing all edits gives a document equal to the original | `EasingEditingContractTests.oneDragIsOneUndoStep`, `FlareEasingTests.undoRestoresTheDocumentExactly` |
| Snapshots in Light and Dark | 2 suite PNGs, 4 Flare PNGs, each opened and listed in its PR | `SuiteCurveEditorSnapshots` (UI1), `FlareEasingSnapshots` (UI2), macOS CI artifact |
| The journey passes | 6 steps, 6 PNGs, two value assertions | `FlareJourneyTests.testEditEasingOfAKeyframeSegment` (I1), macOS CI job |
| Curve is a vector Path | 1 move + 128 lines for 129 samples, sharp in the scale-2 snapshot | `CurveEditorTests.curveIsOneVectorPath` (UI1), `flare-easing-editor-2x-dark.png` (UI2) |
| Every PR's gate | `scripts/ci` prints `CI: PASS`; both CI jobs green | the fast check, then GitHub CI |

## How every PR ships (pilot rules)

- Branch from `origin/dev`; open the PR against `dev`, not `main`.
- Run the fast check on your own machine first: `scripts/ci` must print
  `CI: PASS` (on a Mac without Xcode, through the Linux-safe harness; UI
  tasks also run `gh workflow run CI --ref <branch>` for the macOS job).
- The PR body carries `Fast-Check: pass` and `Head: <full head sha>`, and the
  PR gets the `fast-lane` label.
- Each task records its start and end time (from `date`), the PR's changed
  lines and files, and how many fix-and-push loops CI took. Those numbers are
  what this pilot measures.
