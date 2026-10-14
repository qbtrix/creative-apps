# Feature packet: design-seams-2

**Feature:** the tier-2 seam, the same move as wave 0 once wave 1 has let
go of the shared files: the path, component and variable schema with file
version 2, the tier-2 fakes and live stubs, the actions and pen routes, and
the canvas, menus, top bar and sheet slots for Export, the Pen tool,
Components and Variables, every control disabled with "<Feature> isn't
built yet." until its wave-3 feature fills it. (Blueprint wave 2, D2-1 to
D2-4.)
**Line:** `line:design` · **Wave:** 2 (`waves.md`) · **Lead branch:** `lead/design-seams-2`

**Covers:** no issue closes here; #418, #19 and #20 close in wave 3
(export, components, variables) and the Pen tool's gap issue with F7. #288
(part: the new controls' ids).

**Depends on:** all five wave-1 feature issues closed (select-several,
copy-group, style-rows, layers-panel, files-history): this feature edits
files each of them owns (`DesignCanvasMarks.swift`, `DesignCanvas.swift`,
`DesignInspectorContent.swift`, `DesignCorners.swift`, `DesignFile.swift`,
`DesignHistory.swift`, `DesignWorkspace.swift`, `DesignCommands.swift`,
`DesignWindow.swift`, `DesignEditor.swift`, `DesignActions.swift`,
`DesignCanvasEditing.swift`). Its `Depends on:` line names files-history,
the last of them to touch the window, and its body lists the other four.
The Export item's primary style in the top bar is editor-chrome EC-4
(#339): until it merges, Export… is a plain `EditorBarItem`. No
creative-core issue (F7's path geometry is wave 3's).

Blueprint sections: 5.1 (D2-1's schema), 5.4 tier 2, 5.6, 5.7's
`DesignTierTwoFakes.swift`, 6 (menu bar, wave-3 rows), 8.2 (wave 2).

**What changed from the blueprint (shared-file rule, the 400-line cap):**

- D2-4 had nine App files plus J1's file and `docs/c4/model.json`. It
  splits into D2-4a (the canvas) and D2-4b (menus, top bar, window, sheet
  placeholders, J1), and edits no `docs/c4/model.json`: the supervisor
  folds in the wave-3 file names from `c4-planned.json`.
- D2-1 splits into D2-1a (the `path` kind with every switch over the kind)
  and D2-1b (file version 2 with components and variables, and history
  snapshots that carry them).
- D2-3's tier-2 actions go in a new `DesignActions+TierTwo.swift`, so
  `DesignActions.swift` is not reopened; the pen routes stay in
  `DesignCanvasEditing.swift` (D2-3b).

## Journey steps

1. **J1** `testEveryMenuOpens` (exists; D2-4b extends it): File holds
   Export… ⇧⌘E; Object holds Create Component ⌥⌘K; View holds Light / Dark
   preview and Variables…; each is disabled with its "isn't built yet."
   reason on the live services ("Export isn't built yet.", "Components
   isn't built yet.", "Variables isn't built yet.").
2. **J2** `testNewFileAndEveryTool` (exists, unchanged): Pen stays disabled
   with its existing reason, "Drawing paths isn't built yet."
   (`DesignTool.pen.unavailableHelp`); F7 clears it.
3. **Model walk** `DesignSeams2JourneyTests` (D2-3b, Linux) on `.fake`:
   press, drag and finish a three-anchor pen path ("Add Path"); create a
   component from Desktop and insert it at the canvas center ("Create
   Component", "Insert Desktop"); add a color variable, bind A's fill,
   switch to dark: `displayFill(of: A)` reads the dark value; plan a PNG
   export of every top-level frame at 2x.
4. **J15** (design-window) still passes: the new controls are disabled with
   reasons.

## Screens and states

| Screen | Empty | Error | Loading |
|---|---|---|---|
| Export sheet slot | an empty placeholder view F6 fills; never shown on `.live` because Export… is disabled | – | – |
| Variables sheet slot | an empty placeholder view F9 fills | – | – |
| Canvas, path node | drawn as its path; a path with fewer than two anchors draws nothing | – | – |
| Canvas, instance | draws `resolvedChildren(of:)`; a missing component draws a dashed outline with its name | – | – |
| Pen draft | the overlay slot is empty with no draft | – | – |
| Menus, top bar | every tier-2 item disabled with its help | – | – |

## Contract slice

Schema (5.1): `case path` on `DesignNodeKind` (symbol `scribble`); on
`DesignNode`: `path: DesignPath?`, `componentID: String?`,
`fillVariableID: String?`, each `decodeIfPresent` and kept by
`init(id:copying:)`; on the file: `components` and `variables`; file
version 2, version 1 still opens, and an older build refuses version 2 with
its existing "made by a newer version" reason. `DesignSnapshot` carries
`components` and `variables` so undo restores them.

Services: `.fake` names `FakeExport`, `FakePen`, `FakeComponents`,
`FakeVariables` (5.7, `Fakes/DesignTierTwoFakes.swift`); `.live` names
`LiveExport`, `LivePen`, `LiveComponents`, `LiveVariables`, each forwarding
to `NotBuilt` with 5.6's names ("Export", "The Pen tool", "Components",
"Variables").

Actions (`DesignActions+TierTwo.swift`):

```swift
extension DesignWorkspace {
    public func exportHelp() -> String?
    public func exportPlan(format: DesignExportFormat, scale: Int, existing: Set<String>) throws(DesignRefusal) -> [DesignExportItem]
    public func svg(for id: String) throws(DesignRefusal) -> String
    public var penDraft: DesignPath? { get }                 // stored: public internal(set)
    public mutating func penPress(at point: DesignPoint)     // D2-3b, the routes
    public mutating func penDrag(to point: DesignPoint)
    public mutating func finishPen() throws(DesignRefusal)   // Return; Escape calls cancelPen()
    public mutating func cancelPen()
    public func createComponentHelp() -> String?
    public mutating func createComponent() throws(DesignRefusal)
    public mutating func insertComponent(_ id: String, centeredOn center: DesignPoint) throws(DesignRefusal)
    public mutating func addVariable(named: String, value: DesignVariableValue) throws(DesignRefusal)
    public mutating func renameVariable(_ id: String, to: String) throws(DesignRefusal)
    public mutating func removeVariable(_ id: String) throws(DesignRefusal)
    public mutating func setVariable(_ id: String, _ mode: DesignMode, to: DesignVariableValue) throws(DesignRefusal)
    public mutating func bindFill(_ variableID: String?) throws(DesignRefusal)
    public internal(set) var previewMode: DesignMode       // view state, not undoable
    public mutating func setPreviewMode(_ mode: DesignMode)
    public func displayFill(of node: DesignNode) -> DesignColor?   // the bound variable in previewMode, else fill
    public func resolvedChildren(of instance: DesignNode) -> [DesignNode]?
}
```

The `tool == .pen` routes stay behind `DesignTool.pen.unavailableHelp`
("Drawing paths isn't built yet.") until F7 clears it; on `.fake` a test
can pick the tool through an internal hook.

## Pseudocode

```
D2-1a: add `case path`; compile every `switch` over DesignNodeKind:
  systemImage "scribble"; inspector fill label "Fill"; DesignCorners help "A path has no corners to round.";
  DesignArtwork: `case .path: EmptyView()` (placeholder, D2-4a draws it)
D2-1b: file version = 2; decode: version 1 → components [], variables []; version > 2 → .unsupportedVersion
  snapshot(): + components, variables; restore(): sets both

library edits (components, variables) are file-level, not page-level:
  apply(edit, library:) records one step whose snapshot holds pages + components + variables

penPress(p): penDraft = services.pen.press(at: p, draft: penDraft, tolerance: handleTolerance / zoom)
  if penDraft.isClosed: finishPen()
finishPen(): var m = mint(); edit = try services.pen.commit(penDraft, into: frame under first anchor, page, &m)
  apply(edit, mint: m); penDraft = nil
displayFill(n): n.fillVariableID.flatMap { services.variables.resolve($0, in: previewMode, variables) }.color ?? n.fill
```

## Tasks

Every task is one PR to `dev`: at most 400 changed lines and 15 files,
label `fast-lane`, body lines `Belt-Lead:`, `Feature: design-seams-2`,
`Fast-Check: pass`, `Head:`, and the snapshot PNGs it changes. D2-4b also
carries `feature-done`. Paths drop `Sources/DesignModel/` and
`Sources/DesignApp/`; Model tests are `Tests/DesignModelTests/`.

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| D2-1a | – | `case path` with every switch over the kind (a placeholder in the artwork); `path` on the node | `DesignNode.swift`, `DesignInspectorContent.swift`, `DesignCorners.swift`, `DesignCanvasMarks.swift`; tests `DesignPathKindTests.swift` | – | ~150, 5 |
| D2-1b | – | `componentID`, `fillVariableID`; file `components` and `variables`; version 2 with version 1 still opening; snapshots carry the library | `DesignNode.swift`, `DesignFile.swift`, `Live/LiveFiling.swift`, `DesignHistory.swift`, `DesignWorkspace.swift`; tests `DesignTierTwoSchemaTests.swift`, and the existing version-1 byte checks it moves to version 2: `DesignFilingTests.swift`, `DesignFileTests.swift`, `DesignFixturesTests.swift` | D2-1a | ~360, 9 |
| D2-2 | – | Tier-2 fakes and live stubs; `.fake` and `.live` name them; the law over them | `Fakes/DesignTierTwoFakes.swift`, `Live/LiveExport.swift`, `Live/LivePen.swift`, `Live/LiveComponents.swift`, `Live/LiveVariables.swift`, `DesignServices.swift`; tests `DesignContractLawTierTwoTests.swift` | D2-1b | ~380, 7 |
| D2-3a | – | Export, component and variable actions, `previewMode`, `displayFill`, `resolvedChildren` | `DesignActions+TierTwo.swift`; tests `DesignActionsTierTwoTests.swift` | D2-2 | ~360, 2 |
| D2-3b | – | Pen press, drag, finish and cancel routes; the Linux model walk | `DesignCanvasEditing.swift`, `DesignActions+TierTwo.swift`; tests `DesignPenRouteTests.swift`, `DesignSeams2JourneyTests.swift` | D2-3a | ~300, 4 |
| D2-4a | – | The canvas draws paths, resolved instances and bound fills; the pen draft overlay slot | `DesignCanvasMarks.swift`, `DesignCanvas.swift`; snapshots `DesignTierTwoCanvasSnapshots.swift` | D2-3b | ~250, 3 |
| D2-4b | #288 (part) | Export…, Create Component, Variables… and Light / Dark in the menus and top bar; the window presents the two placeholder sheets and keeps the visible canvas center for Insert; J1's tier-2 items | `DesignIntent.swift`, `DesignWindow.swift`, `DesignCommands.swift`, `DesignObjectMenu.swift`, `DesignEditor.swift`, `DesignExportSheet.swift`, `DesignVariablesSheet.swift`; snapshots `DesignTierTwoMenuSnapshots.swift`; `UITests/DesignJourneyTests.swift` | D2-3b, D2-4a | ~330, 9; `feature-done` |

The tasks run in order. D2-4b waits for D2-4a so the `feature-done` PR is
the last to merge. `DesignNode.swift` passes D2-1a →
D2-1b, `DesignCanvasMarks.swift` D2-1a → D2-4a, `DesignActions+TierTwo.swift`
D2-3a → D2-3b.

## Acceptance test per task

| id | test | fails when |
|---|---|---|
| D2-1a | `DesignPathKindTests`: `.path`'s symbol is "scribble"; its corner help is "A path has no corners to round."; a path node with a `DesignPath` of three anchors round-trips through the codec and `init(id:copying:)` keeps the path; every existing kind's symbol and help unchanged | a switch misses the case, or a copy drops the path |
| D2-1b | `DesignTierTwoSchemaTests`: a version-1 string decodes with empty components and variables; a version-2 file with one component, one variable and a bound fill round-trips byte for byte; version 3 is refused "It was made by a newer version of Design (file version 3)."; an undo after a library edit restores the components and variables | an old file fails, a new field is dropped, or undo misses the library |
| D2-2 | `DesignContractLawTierTwoTests`: on `.fake` and `.live`, every tier-2 help and write under the law on `cards`; `.live`'s tier-2 helps read "Export isn't built yet.", "The Pen tool isn't built yet.", "Components isn't built yet.", "Variables isn't built yet."; FakePen closes within tolerance; FakeComponents refuses a non-frame with "<name> isn't a frame." | a slot is unnamed, a stub acts, or a fake breaks the law |
| D2-3a | `DesignActionsTierTwoTests` on `.fake`: create a component from Desktop is one step "Create Component" and undo restores Desktop's children; insert is "Insert Desktop" centered on the given point; add, rename, remove, set and bind variables are one step each and a refusal records none; `setPreviewMode` records nothing; `displayFill(of: A)` follows the bound variable in each mode and A's own fill when unbound; `resolvedChildren` of an instance of a missing component is nil | a library edit is not undoable, preview mode records a step, or a bound fill ignores the mode |
| D2-3b | `DesignPenRouteTests` on `.fake`: three presses and Return add one "Add Path" step; a press within tolerance of the first anchor closes and commits; Escape leaves no node and no step; the draft never survives a tool change; `DesignSeams2JourneyTests` walks step 3 | a draft records steps, Escape leaves a node, or a close is missed |
| D2-4a | `DesignTierTwoCanvasSnapshots`: `design-canvas-path` (a three-anchor fake path), `design-canvas-instance` (an instance of Desktop drawn from the component), `design-canvas-bound-fill-dark` (A bound to a variable in dark preview); today's canvas PNGs unchanged | an existing PNG changes, or an instance draws nothing |
| D2-4b | `DesignTierTwoMenuSnapshots`: File with Export…, Object with Create Component, View with Light / Dark and Variables…, each disabled on `.live`; J1 lists the tier-2 items with their reasons | a tier-2 item is missing or enabled with no action |

## Quality tests

| quality row | budget | test |
|---|---|---|
| QD-V1 save is stable, older files open | byte equality; versions 1 and 2 | `DesignTierTwoSchemaTests` |
| QD-S9 any document edit | ≤ 1 ms / ≤ 10 ms, now with the library in the snapshot | `DesignBudgetTests.applyStep` (design-seams) |
| QB-F1 no dead controls | every tier-2 control disabled with a reason | J1, J15 |
| help law | every tier-2 conformance | `DesignContractLawTierTwoTests` |

## Done check

- **Journeys green:** the macOS run on `dev` after the `feature-done` PR is
  green: J1 extended; J0 to J16 from waves 0 and 1 still pass.
- **Audit zero new:** that run's `design` counts are at or under the
  baseline; the new menu and top bar items carry ids.
- **Contact sheet:** the lead comments `Belt-Contact-Sheet: <run link>` on
  the feature issue with one line per journey and the audit counts, and
  notes which shots changed (menus and top bar only).
