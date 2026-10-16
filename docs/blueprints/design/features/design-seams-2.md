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

**Depends on:** the design-contracts feature issue, plus only the slices
whose files it reopens (it calls no wave-1 code):

| what it waits on | why | tasks |
|---|---|---|
| style-rows SR-m | `DesignInspectorContent.swift` (ST-2) | D2-1a |
| style-rows SR-b | `DesignCanvasMarks.swift` (ST-5) | D2-1a, D2-4a |
| files-history FH-a | `DesignFile.swift`, `DesignHistory.swift`, `Live/LiveFiling.swift`, `DesignFilingTests.swift` (FH-1, FH-2) | D2-1b |
| layers-panel LP-b | `DesignWorkspace.swift` (L-3) | D2-1b, D2-3a |
| design-seams | `DesignCanvasEditing.swift` (D0-3c) | D2-3b |
| select-several SS-b | `DesignCanvasEditing.swift` (S-5) | D2-3b |
| all of design-window | `DesignCanvas.swift`, `DesignIntent.swift`, `DesignWindow.swift`, `DesignEditor.swift`, `DesignObjectMenu.swift`, `DesignWindowOptions.swift`, `UITests/DesignJourneyTests.swift`, the live drag box | D2-4a, D2-4b |
| files-history FH-b | `DesignCommands.swift` (FH-3) | D2-4b |
| canvas-basics | `DesignCanvasEditing.swift` (CB-2, CB-3), `DesignCanvas.swift`, `DesignIntent.swift`, `DesignWindow.swift` (CB-6, CB-9) | D2-3b, D2-4a, D2-4b |
| snapping SN-b | `DesignCanvasEditing.swift` (SN-4, SN-5) | D2-3b |
| snapping SN-c | `DesignIntent.swift`, `DesignCommands.swift` (SN-8) | D2-4b |

copy-group and select-several's SS-a are not waited on. The feature issue
is filed once S2-a's waits are done; its body lists the table above.
The Export item's primary style in the top bar is editor-chrome EC-4
(#339): until it merges, Export… is a plain `EditorBarItem`. No
creative-core issue (F7's path geometry is wave 3's).

## Slices

A slice is the unit of done: its tasks have merged and its journeys pass
(MJ6 on the Linux gate; J1 and MJ7 on the Design-scoped macOS run and the
Linux gate).

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| S2-a | A file with a path, a component and a bound variable saves as version 2 and reopens, version 1 still opens, a newer version is refused, and undo restores the library. | D2-1a, D2-1b, D2-2 | MJ6 | design-contracts (the feature); style-rows SR-m, SR-b (D2-1a); files-history FH-a, layers-panel LP-b (D2-1b) |
| S2-b | Export, Create Component, Variables and Light or Dark preview sit in the menus, each saying it isn't built yet, while the Model drafts pen paths, components and variables on the fakes. | D2-3a, D2-3b, D2-4a, D2-4b | J1, MJ7 | S2-a (D2-3a, D2-4a); layers-panel LP-b (D2-3a); design-seams, select-several SS-b (D2-3b); design-window (D2-4a, D2-4b); style-rows SR-b (D2-4a); files-history FH-b (D2-4b); canvas-basics (D2-3b, D2-4a, D2-4b); snapping SN-b (D2-3b), SN-c (D2-4b) |

A pen drag's samples go to design-window's live drag box, and the draft
overlay reads it, so the editor body doesn't run per sample; D2-4a checks
it on the fakes (the Pen tool stays off until F7).

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
3. **MJ7** `DesignSeams2JourneyTests` (D2-3b, Linux) on `.fake`:
   press, drag and finish a three-anchor pen path ("Add Path"); create a
   component from Desktop and insert it at the canvas center ("Create
   Component", "Insert Desktop"); add a color variable, bind A's fill,
   switch to dark: `displayFill(of: A)` reads the dark value; plan a PNG
   export of every top-level frame at 2x.
4. **J15** (design-window) still passes: the new controls are disabled with
   reasons.

MJ6 is `DesignTierTwoSchemaTests.testLibraryWalk` (D2-1b, Linux): a
version-2 file with a three-anchor path, a component and a fill bound to a
variable saves, reopens and undoes a library edit.

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
| D2-1a | – | `case path` with every switch over the kind (a placeholder in the artwork); `path` on the node | `DesignNode.swift`, `DesignInspectorContent.swift`, `DesignCorners.swift`, `DesignCanvasMarks.swift`; tests `DesignPathKindTests.swift` | style-rows SR-m, SR-b | ~150, 5 |
| D2-1b | – | `componentID`, `fillVariableID`; file `components` and `variables`; version 2 with version 1 still opening; snapshots carry the library; walk MJ6 | `DesignNode.swift`, `DesignFile.swift`, `Live/LiveFiling.swift`, `DesignHistory.swift`, `DesignWorkspace.swift`; tests `DesignTierTwoSchemaTests.swift`, and the existing version-1 byte checks it moves to version 2: `DesignFilingTests.swift`, `DesignFileTests.swift`, `DesignFixturesTests.swift` | D2-1a; files-history FH-a; layers-panel LP-b | ~380, 9 |
| D2-2 | – | Tier-2 fakes and live stubs; `.fake` and `.live` name them; the law over them | `Fakes/DesignTierTwoFakes.swift`, `Live/LiveExport.swift`, `Live/LivePen.swift`, `Live/LiveComponents.swift`, `Live/LiveVariables.swift`, `DesignServices.swift`; tests `DesignContractLawTierTwoTests.swift` | D2-1b | ~380, 7 |
| D2-3a | – | Export, component and variable actions, `previewMode`, `displayFill`, `resolvedChildren` | `DesignActions+TierTwo.swift`, `DesignWorkspace.swift` (the stored `previewMode`); tests `DesignActionsTierTwoTests.swift` | D2-2; layers-panel LP-b | ~360, 3 |
| D2-3b | – | Pen press, drag, finish and cancel routes; walk MJ7 | `DesignCanvasEditing.swift`, `DesignActions+TierTwo.swift`, `DesignWorkspace.swift` (the stored `penDraft`); tests `DesignPenRouteTests.swift`, `DesignSeams2JourneyTests.swift` | D2-3a; design-seams; select-several SS-b; canvas-basics; snapping SN-b | ~300, 5 |
| D2-4a | – | The canvas draws paths, resolved instances and bound fills; the pen draft overlay slot, reading the live drag box; the pen drag check | `DesignCanvasMarks.swift`, `DesignCanvas.swift`; snapshots `DesignTierTwoCanvasSnapshots.swift`; `Tests/AppSnapshotTests/DesignPenDragTests.swift` | D2-3b; design-window; style-rows SR-b; canvas-basics | ~320, 4 |
| D2-4b | #288 (part) | Export…, Create Component, Variables… and Light / Dark in the menus and toolbar, with their ids in `DesignControlID`; the window presents the two placeholder sheets and keeps the visible canvas center for Insert; J1's tier-2 items | `DesignIntent.swift`, `DesignWindow.swift`, `DesignCommands.swift`, `DesignObjectMenu.swift`, `DesignEditor.swift`, `DesignExportSheet.swift`, `DesignVariablesSheet.swift`, `Sources/DesignModel/DesignWindowOptions.swift`; snapshots `DesignTierTwoMenuSnapshots.swift`; `UITests/DesignJourneyTests.swift` | D2-3a; design-window; files-history FH-b; canvas-basics; snapping SN-c | ~350, 10; `feature-done` |

Each link is merged code the task needs. `DesignNode.swift` passes D2-1a →
D2-1b (both add stored fields and coding keys to `DesignNode`, which an
extension file can't hold). D2-2's fakes build `.path` nodes and set
`componentID` and `fillVariableID`. D2-3a calls the tier-2 service slots
D2-2 adds. Every stored property of `DesignWorkspace` sits in the struct
body in `DesignWorkspace.swift`, so D2-3a adds `previewMode` there and
D2-3b adds `penDraft`; that file passes D2-1b → D2-3a → D2-3b, the same
order the code links give. `DesignActions+TierTwo.swift` passes D2-3a → D2-3b, whose
journey walk also uses D2-3a's actions. D2-4a reads `displayFill`,
`resolvedChildren` (D2-3a) and the pen draft overlay draws the `penDraft`
path that D2-3b's `penPress` builds, and it reopens
`DesignCanvasMarks.swift` after D2-1a. D2-4b calls only D2-3a's helps and
actions: Return and Escape for the pen are F7's, so it needs nothing from
D2-3b or D2-4a and shares no file with them. D2-4b carries
`feature-done`, so it is held to the last wave next to D2-4a; that is
the only reason, not a code link. No task edits a shared
doc (`docs/c4/model.json`, `docs/design.md`, the blueprint, `waves.md`):
the supervisor folds the wave-3 file names into `docs/c4/model.json`, and
every new file sits in a folder its C4 component already covers.

## Build waves

- Wave 1: D2-1a. Independent in this wave: one task.
- Wave 2: D2-1b. Independent in this wave: one task.
- Wave 3: D2-2. Independent in this wave: one task.
- Wave 4: D2-3a. Independent in this wave: one task.
- Wave 5: D2-3b. Independent in this wave: one task.
- Wave 6: D2-4a, D2-4b (`feature-done`, final). Independent in this wave: both.
  D2-4b needs only D2-3a; it waits for wave 6 because it carries
  `feature-done`, whose merge starts the CI run the Done check reads.

Longest chain: D2-1a → D2-1b → D2-2 → D2-3a → D2-3b → D2-4a (6).
Chain of 6: `DesignNode`'s stored fields (D2-1a → D2-1b), the fakes need
`path`, `componentID` and `fillVariableID` (→ D2-2), the actions call
D2-2's `DesignServices` slots (→ D2-3a), the pen routes extend
`DesignActions+TierTwo.swift` (→ D2-3b), and the canvas overlay reads
`penDraft` (→ D2-4a).

## Acceptance test per task

| id | test | fails when |
|---|---|---|
| D2-1a | `DesignPathKindTests`: `.path`'s symbol is "scribble"; its corner help is "A path has no corners to round."; a path node with a `DesignPath` of three anchors round-trips through the codec and `init(id:copying:)` keeps the path; every existing kind's symbol and help unchanged | a switch misses the case, or a copy drops the path |
| D2-1b | `DesignTierTwoSchemaTests`: a version-1 string decodes with empty components and variables; a version-2 file with one component, one variable and a bound fill round-trips byte for byte; version 3 is refused "It was made by a newer version of Design (file version 3)."; an undo after a library edit restores the components and variables | an old file fails, a new field is dropped, or undo misses the library |
| D2-2 | `DesignContractLawTierTwoTests`: on `.fake` and `.live`, every tier-2 help and write under the law on `cards`; `.live`'s tier-2 helps read "Export isn't built yet.", "The Pen tool isn't built yet.", "Components isn't built yet.", "Variables isn't built yet."; FakePen closes within tolerance; FakeComponents refuses a non-frame with "<name> isn't a frame." | a slot is unnamed, a stub acts, or a fake breaks the law |
| D2-3a | `DesignActionsTierTwoTests` on `.fake`: create a component from Desktop is one step "Create Component" and undo restores Desktop's children; insert is "Insert Desktop" centered on the given point; add, rename, remove, set and bind variables are one step each and a refusal records none; `setPreviewMode` records nothing; `displayFill(of: A)` follows the bound variable in each mode and A's own fill when unbound; `resolvedChildren` of an instance of a missing component is nil | a library edit is not undoable, preview mode records a step, or a bound fill ignores the mode |
| D2-3b | `DesignPenRouteTests` on `.fake`: three presses and Return add one "Add Path" step; a press within tolerance of the first anchor closes and commits; Escape leaves no node and no step; the draft never survives a tool change; `DesignSeams2JourneyTests` walks step 3 | a draft records steps, Escape leaves a node, or a close is missed |
| D2-4a | `DesignTierTwoCanvasSnapshots`: `design-canvas-path` (a three-anchor fake path), `design-canvas-instance` (an instance of Desktop drawn from the component), `design-canvas-bound-fill-dark` (A bound to a variable in dark preview); today's canvas PNGs unchanged. `DesignPenDragTests` (design-window D0-8b's `dragSamples`, `.fake`, the pen picked through the internal hook): a 120-sample pen drag runs `DesignEditor`'s body 3 times or fewer | an existing PNG changes, an instance draws nothing, or the editor body runs per pen sample |
| D2-4b | `DesignTierTwoMenuSnapshots`: File with Export…, Object with Create Component, View with Light / Dark and Variables…, each disabled on `.live`; J1 lists the tier-2 items with their reasons | a tier-2 item is missing or enabled with no action |

## Quality tests

| quality row | budget | test |
|---|---|---|
| QD-V1 save is stable, older files open | byte equality; versions 1 and 2 | `DesignTierTwoSchemaTests` |
| QD-S9 any document edit | ≤ 1 ms / ≤ 10 ms, now with the library in the snapshot | `DesignBudgetTests.applyStep` (design-seams) |
| QB-F1 no dead controls | every tier-2 control disabled with a reason | J1, J15 |
| help law | every tier-2 conformance | `DesignContractLawTierTwoTests` |
| the editor body doesn't run per sample | ≤ 3 `DesignEditor` body runs over a 120-sample pen drag | `DesignPenDragTests` (D2-4a) |

## Done check

Per slice: S2-a is done when MJ6 passes on the Linux gate; S2-b when J1
(extended) passes on the Design-scoped run after D2-4b and MJ7 on the
Linux gate. The feature is done when both are:

- **Journeys green:** the macOS run on `dev` after the `feature-done` PR is
  green: J1 extended; J0 to J16 from waves 0 and 1 still pass.
- **Audit zero new:** that run's `design` counts are at or under the
  baseline; the new menu and top bar items carry ids.
- **Contact sheet:** the lead comments `Belt-Contact-Sheet: <run link>` on
  the feature issue with one line per journey and the audit counts, and
  notes which shots changed (menus and top bar only).
