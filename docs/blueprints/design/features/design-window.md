# Feature packet: design-window

**Feature:** the window half of Design's wave-0 seam: every new intent and
menu item, the launch arguments the journeys use (`-DesignServices`,
`-DesignFixture`, `-DesignWindowSize`), the several-layer inspector shell,
the canvas marks and overlay slots, the pasteboard bridge, the control ids
registered with SuiteUI's inventory, and the every-control and layout
journeys. Each new control is wired to `design-contracts`' actions and shows
"<Feature> isn't built yet." until its wave-1 feature lands, so no control
is dead. (Blueprint wave 0, tasks D0-5a to D0-7.)
**Line:** `line:design` · **Wave:** 0b (`waves.md`) · **Lead branch:** `lead/design-window`

**Covers:** #288 (part: the window, top bar, canvas, panel and menu
controls get `design.<area>.<name>` ids; #288 closes when the `identifier`
count is 0, after wave 1). The lead files one `needs-ui` issue at stage 1,
"SuiteUI: a `mixed` state on `ScrubField`" (labels `needs-ui`,
`line:suiteui`), since no SuiteUI task builds it (inspector-controls.md's
states table lists an exact-field "Mixed" state but no IC task makes it; the
new issue links that table so it doesn't read as a duplicate); D0-5c uses a plain
"Mixed" text meanwhile.

**Depends on:** the design-contracts feature issue (the actions, services
and fixtures this window calls). Its first slice, DW-a, also waits on all of
Design shell-parity (`shell-parity.md`, SP2): DS-3 moves the window onto
`SuiteWindow` in the same files D0-5a, D0-5d and D0-6 edit
(`DesignIntent.swift`, `DesignWindow.swift`, `DesignEditor.swift`,
`UITests/DesignJourneyTests.swift`), so this packet builds on that window:
toolbar items from `DesignToolbarItem` (DS-1), the sidebar, the inspector
and the floating tool box. #778 suite-harness has merged: SH-7's journey
template, SH-5's `.suiteControl(id:enabled:reason:)`, `.suiteProbes()` and
`ToolbarAction.identifier` (the one publisher of `suite.controls`) and SH-4's
`suite.perf` are on `dev`. No creative-core issue.

**SuiteUI owner lane.** `CanvasViewport.swift`'s checker tile is a computed
`static var` that rebuilds on every body run of the canvas (line 309 on
`dev`). It is SuiteUI's file, so it is a SuiteUI issue, not a task here;
until it lands each canvas re-run still pays for the tile. DW-b's count is
of the editor body and doesn't depend on it.

Blueprint sections: 4 (Modes, J1, J15, the fixtures), 6 (the screens and
the menu bar), 7.2, 7.3 (the layout spec), 8.2 (wave 0, D0-5a to D0-7).

**What changed from the blueprint (review of #766 and the shared-file rule):**

- D0-5a (six App files, every new intent) is over the cap, so it splits:
  D0-5a (intents, `perform`, launch arguments, Zoom to Selection, status
  count), D0-5c (the several-layer inspector shell). D0-5b likewise splits
  into D0-5b (canvas marks and overlay slots) and D0-5d (the pasteboard
  bridge and the Layers rename state).
- No `DesignControls.swift`. SuiteUI's `ControlInventory` (SH-5) is the one
  publisher of `suite.controls`: D0-7a applies `.suiteProbes()` at the
  window root (an inner `EditorShell` call adds nothing later, by SH-5's
  rule) and registers Design's own controls with `.suiteControl`.
- D0-7 makes no `project.yml` edit (Q1 is answered: SuiteUI's SH-7 changes
  the template; `project.yml` is SuiteUI's under the shared-file rule).
- Launch-argument parsing, the status count text and the control ids are
  pure Model code in one new file, `DesignWindowOptions.swift`, so they are
  tested on Linux.
- **v3 re-cut (2026-10-16).** DW-a, the first slice, is the contract the
  wave-1 views plug into: the intents and launch arguments, every tier-1
  control id in `DesignControlID`, the canvas slots, the inspector shell,
  the pasteboard bridge, the Layers rename state, the menus, and two slot
  files for files-history (`DesignSaveStatus.swift`, the window subtitle;
  `DesignClosePrompt.swift`, the close prompt). Each slot file, and each view
  file a wave-1 feature fills (`DesignSelectionMarks`, `DesignAlignBar`,
  `DesignInspector`, `DesignCanvasMarks`, `DesignFrameLabels`,
  `DesignLayersPanel`, `DesignCommands`), passes to that feature when DW-a
  merges, and no later task here touches it again. So D0-5c and D0-5d
  register the ids of the controls they touch, and D0-7a only the window's
  own.
- **The canvas drag (DW-b, D0-8a and D0-8b) is new**, from an audit of the
  editors: a drag wrote the observed model on every pointer sample
  (`DesignCanvas.swift:47` → `DesignWindow.swift:74` →
  `DesignCanvasEditing.swift:128-151`), re-running the whole editor and the
  menus per sample, the cause of the Photo brush lag (see #1291). The press
  goes to the model, later samples to an App-side box only the canvas reads,
  and mouse-up replays the last sample into the model.
- No task edits `docs/c4/model.json` or `docs/design.md`; the supervisor
  folds blueprint section 6's Design rules into `docs/design.md` later, and
  until then section 6 of the blueprint is the look spec every task here
  follows.

**Building blind.** D0-5a to D0-7b are in `Sources/DesignApp/`,
`Tests/AppSnapshotTests/` and `UITests/`, which the Linux gate never
compiles. So: every SwiftUI and AppKit API checked with `apple-docs` (say
so in the PR: `FocusedValue`, `CommandGroup(after: .pasteboard)`,
`onCopyCommand`, `onCutCommand`, `onPasteCommand`, `NSPasteboard`), each
file copies the shape of a DesignApp file that builds, and every decision
that can be pure lives in `DesignWindowOptions.swift` or `design-contracts`'
actions.

## Slices

A slice is the unit of done: its tasks have merged and its journeys pass on
the Design-scoped macOS run.

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| DW-a | Every tier-1 command is in the menus, the several-layer inspector and the canvas, wired to the actions, and on the live services each says "<Feature> isn't built yet." (the slot and intent contract the wave-1 views plug into). | D0-5a, D0-5b, D0-5c, D0-5d, D0-6 | J1 | design-contracts (the feature); Design shell-parity (D0-5a, D0-5d, D0-6) |
| DW-b | A drag on the canvas redraws only the canvas: the editor body runs at most 3 times over a 120-sample drag, and the document ends the same as before. | D0-8a, D0-8b | J3 | DW-a |
| DW-c | Every enabled Design control acts and every disabled one says why, and the window keeps its layout at every width. | D0-7a, D0-7b | J15, `testLayoutAtWidths` | DW-b (D0-7a); DW-a (D0-7b) |

The wave-1 features' view tasks wait on DW-a; the ones that check a drag or
a scrub also wait on DW-b, whose box and `bodyRuns` counter they use.

## Journey steps

1. **J1** `testEveryMenuOpens` (exists, D0-6 extends it) on `-DesignFixture
   empty`: open File, Edit, Page, Object, View; each holds the items
   section 6 lists without a wave marker (Duplicate; Rename Page…; Group,
   Ungroup, Arrange ▸, Distribute Horizontally and Vertically; Zoom to
   Selection); each Design item is enabled or disabled with a tooltip; the
   system's Cut, Copy, Paste and Select All are only checked enabled or
   disabled; Page > Add Page reads "Undo Add Page".
2. **Fake mode** (D0-5a): `-DesignServices fake -DesignFixture cards`
   opens `cards` as an unsaved file on the fixture fakes; selecting A and B
   shows "2 Layers" in the inspector header and the status line.
3. **J15** `testEveryControlActsOrSaysWhy` (`+EveryControl`, class `DesignEveryControlJourneyTests`, D0-7b) on
   `cards`, live services: read `suite.controls`, click each enabled
   `design.*` control, Escape, ⌘Z; every enabled one changed the shot or a
   value; every disabled one has a reason (the "isn't built yet." ones
   included). A sweep, never cited by the matrix.
4. **J3** `testDrawShapesAddTextAndSave` (exists) keeps passing with its
   frame, rectangle and ellipse drags, moves and resizes going through the
   live drag box (DW-b); D0-8b checks the box's cost.
5. **Layout** `testLayoutAtWidths` (`+Layout`, class `DesignLayoutJourneyTests`, D0-7b) on `cards` with A
   selected at 880 × 560 and 1024 × 720 (CI), and 1280 × 800, 1440 × 900,
   1920 × 1080 locally (skipped on a smaller display): blueprint 7.3's six
   asserts, to 0.5 pt.

## Screens and states

| Screen | Empty | Error | Loading |
|---|---|---|---|
| Inspector, several layers | – | a disabled row or Align button shows its help as the tooltip ("Aligning several layers isn't built yet." on `.live`) | none |
| Inspector, rows that differ | – | – | – (they read "Mixed" in secondary text, no marker) |
| Canvas | no file: the existing `EmptyStateView` with New File | – | none |
| Canvas, marquee | the marquee mark shows only while `model.marquee` is non-nil | – | – |
| Canvas, mid-drag | the canvas draws the live box's copy; the inspector and the status line hold their values until mouse-up | – | – |
| Menus | nothing selected: Duplicate, Group, Ungroup, Arrange, Distribute, Zoom to Selection disabled with "Select a layer first." (or the slot's help) | each disabled Design item says why | – |
| Status line | no file: "No file open" (today) | – | – |
| Launch with `-DesignFixture <unknown>` | the window opens empty, as with no argument | the status line's message reads "No fixture named <name>." | – |

## Contract slice

Model (`Sources/DesignModel/DesignWindowOptions.swift`, D0-5a; Linux):

```swift
/// What the window reads from its launch arguments; parsed once.
public struct DesignWindowOptions: Sendable, Equatable {
    public var services: DesignServices          // `-DesignServices fake`, else .live
    public var fixture: String?                  // `-DesignFixture <name>`
    /// `-DesignWindowSize 880x560`; nil when absent or malformed. The app floors it at SuiteSize.windowMinimum.
    public var windowWidth: Double?
    public var windowHeight: Double?
    public init(arguments: [String])
}
extension DesignWorkspace {
    /// Opens a named fixture as an unsaved file (no URL, not undoable, like Open); false for an unknown name.
    public mutating func openFixture(_ name: String) -> Bool
    /// "2 Layers" with several selected, "1 Layer" with one, nil with none.
    public var selectionCountText: String? { get }
}
/// Every tier-1 `design.*` control id, declared up front by D0-5a so the
/// wave-1 views use it without editing this file; a missing id goes through
/// this feature's lane.
public enum DesignControlID { public static let all: [String]; public static let canvasSelection = "design.canvas.selection" /* … */ }
```

App slot files (D0-5a, D0-5d), each a pass-through until files-history
fills it: `DesignSaveStatus` (`subtitle(model) -> String?`, nil: the window subtitle
shell-parity leaves empty; and an empty `design.status.save` label in the
status line) and `DesignClosePrompt`, a view
modifier on the window root that lets every close through.

`DesignLiveDrag` (D0-8a, `Sources/DesignApp/DesignLiveDrag.swift`): an
App-side `@Observable final class` holding `workspace: DesignWorkspace?`
(a copy the canvas draws) and the last sample. `begin(from:)`,
`sample(from:to:modifiers:)`, `preview(_ change: DesignStyleChange)` (for an
inspector scrub) and `end(into:)`, which replays the last sample or change
into the model through its methods and clears the copy. Views read
`live.workspace ?? model`; only the canvas and the row being scrubbed read
it, so nothing else re-runs per sample.

App (macOS): new `DesignIntent` cases, one per `DesignCommand`, plus
`.copy`, `.cut`, `.paste`, `.selectAll`, `.zoomToSelection`,
`.moveLayer(id, parent, index)`, `.setStyle(DesignStyleChange)`,
`.renamePage(id, name)`; `DesignWindow.perform` calls the matching action
and shows a refusal's `help` in the status line's message.
`DesignCanvas(show: DesignRect?)` takes the rect Zoom to Selection asks for
and passes it on to `CanvasViewport` once SuiteUI adds that input (F1);
until then it is stored and unused.

## Pseudocode

```
launch (D0-5a):
  options = DesignWindowOptions(arguments: ProcessInfo.processInfo.arguments)
  model.useServices(options.services)
  if let f = options.fixture, !model.openFixture(f): note = "No fixture named \(f)."
  if let w = options.windowWidth, let h = options.windowHeight: content size = max((w, h), SuiteSize.windowMinimum)

perform(intent):                                     # one place, as today
  case .command(c):   do { try model.run(c) } catch { note = error.help }
  case .copy:         bridge.write(try model.copySelection(), type: model.pasteboardType)   # D0-5d
  case .cut:          bridge.write(try model.cutSelection(), type: …)                      # D0-5d
  case .paste:        if let data = bridge.read(type: …) { try model.paste(data) }         # D0-5d
  case .zoomToSelection:
      guard let rect = model.zoomToSelectionRect else return
      zoom = ViewerZoom stop that fits rect in the viewport; show = rect   # D0-5b's canvas takes `show`

menu item (D0-6): Button(title) { perform(i) }.disabled(help != nil).help(help ?? "")
  help comes from model.help(command) / zoomToSelectionHelp / copyHelp …   # never computed in the view

inspector with n > 1 (D0-5c):
  header "\(n) Layers"; Align row: six edges + Distribute H and V, each .help(model.help(.align(e)))
  each row: value = common value of the selection, or nil → "Mixed" text
  editing a row → perform(.setStyle(change)); one onEnd → one step (run key from the actions)

canvas (D0-5b):
  overlay (not clipped by the page): marquee rect (1 pt accent stroke, 10 % accent fill),
    DesignSelectionMarks (each outline, the dashed box; its 8 handles only when
      model.transformHelp == nil, so on `.live` no handle shows before select-several),
    DesignFrameLabels (empty slot; F3 fills it)
  DesignSelectionMarks' box carries .accessibilityIdentifier("design.canvas.selection")

registration: each task registers the controls it touches (D0-5c the
  inspector shell and Align row, D0-5d the Layers rename, D0-6 nothing: menus
  carry titles); D0-7a: window root .suiteProbes(), then the window's own
  controls: .accessibilityIdentifier(id).suiteControl(id: id, enabled: help == nil, reason: help)

canvas drag (D0-8a), no App write of `model = …` (scripts/ci's app-state rule):
  press:       model.drag(from: p, to: p, mods)     # selection shows at once
               live.begin(from: model)
  each sample: live.sample(from: start, to: q, mods) # the copy reruns drag from the
                                                      # gesture snapshot; the model is untouched
  mouse-up:    live.end(into: model)                 # model.drag(last), then model.endDrag()
  DesignCanvas draws live.workspace ?? model; nothing else reads `live`
```

## Tasks

Every task is one PR to `dev`: at most 400 changed lines and 15 files,
label `fast-lane`, body lines `Belt-Lead:`, `Feature: design-window`,
`Fast-Check: pass`, `Head:`, and the snapshot PNGs it changes. D0-7b also
carries `feature-done`. Paths drop `Sources/DesignApp/`; snapshots are in
`Tests/AppSnapshotTests/`.

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| D0-5a | #288 (part) | `DesignWindowOptions` and `openFixture`; `DesignControlID` with every tier-1 id; every new intent and `perform` for it; the three launch arguments; Zoom to Selection sets the zoom and keeps the rect in the window's state; the status line's selection count; the empty `DesignSaveStatus` slot | `Sources/DesignModel/DesignWindowOptions.swift`, `DesignIntent.swift`, `DesignWindow.swift`, `DesignEditor.swift`, `DesignSaveStatus.swift`; `Tests/DesignModelTests/DesignWindowOptionsTests.swift`; snapshot `DesignStatusSnapshots.swift` | Design shell-parity | ~390, 7 |
| D0-5b | #288 (part) | Canvas: the marquee mark; selection marks in their own file with `design.canvas.selection`; the empty `DesignFrameLabels` overlay slot; the `show` parameter | `DesignCanvas.swift`, `DesignCanvasMarks.swift`, `DesignSelectionMarks.swift`, `DesignFrameLabels.swift`; snapshot `DesignCanvasSeamSnapshots.swift` | – | ~300, 5 |
| D0-5c | #288 (part); files the `ScrubField` mixed `needs-ui` issue | The several-layer inspector shell: "<n> Layers", the Align row with Distribute, rows reading "Mixed", each control's help from the actions; ids on the inspector's and Align row's controls | `DesignInspector.swift`, `DesignAlignBar.swift`; snapshot `DesignSeveralInspectorSnapshots.swift` | D0-5a | ~300, 3 |
| D0-5d | #288 (part) | `DesignPasteboardBridge` (read and write under `pasteboardType`); copy, cut and paste hooks on the canvas and Layers; rename presentation state in Layers (row in rename, draft, refusal text) with its ids; the pass-through `DesignClosePrompt` on the window root | `DesignPasteboardBridge.swift`, `DesignWindow.swift` (the `.copy`, `.cut` and `.paste` cases of `perform`, the close-prompt modifier), `DesignCanvas.swift`, `DesignLayersPanel.swift`, `DesignClosePrompt.swift`; `Tests/AppSnapshotTests/DesignPasteboardBridgeTests.swift` | D0-5a, D0-5b | ~310, 6 |
| D0-6 | #288 (part) | Menus: Edit adds Duplicate after the stock pasteboard group (which stays); Page adds Rename Page…; Object adds Group, Ungroup, Arrange ▸, Distribute; View adds Zoom to Selection; every Design item disabled with its help; J1's item list | `DesignCommands.swift`, `DesignEditMenu.swift`, `DesignObjectMenu.swift`; snapshots `DesignEditMenuSnapshots.swift`, `DesignPageMenuSnapshots.swift`; `UITests/DesignJourneyTests.swift` | D0-5a | ~330, 6 |
| D0-8a | – | The live drag box: the press goes to the model, later samples to `DesignLiveDrag`, which only the canvas reads; mouse-up replays the last sample into the model, then `endDrag`; `preview` and `end` for an inspector scrub | `DesignLiveDrag.swift`, `DesignCanvas.swift`, `DesignWindow.swift`; `Tests/AppSnapshotTests/DesignLiveDragTests.swift` | D0-5d | ~260, 4 |
| D0-8b | – | The editor's `bodyRuns` counter (as #1291 adds to Photo's editor; see #1291) and the 120-sample drag check, with a `dragSamples` helper the wave-1 drag checks reuse | `DesignEditor.swift`; `Tests/AppSnapshotTests/DesignWindowDragTests.swift` | D0-8a | ~220, 2 |
| D0-7a | #288 (part) | `.suiteProbes()` at the window root; the window's own controls (toolbar items through `ToolbarAction.identifier`, the floating tool box, the canvas, the status line) get their `DesignControlID` id and `.suiteControl` registration | `DesignWindow.swift`, `DesignEditor.swift`, `DesignCanvas.swift`, `Sources/DesignModel/DesignWindowOptions.swift`; `Tests/DesignModelTests/DesignControlIDTests.swift` | D0-8b | ~200, 5 |
| D0-7b | – | The every-control sweep J15 and the layout journey | `UITests/DesignJourneyTests+EveryControl.swift`, `UITests/DesignJourneyTests+Layout.swift` | D0-6, D0-7a | ~300, 2; `feature-done` |

`DesignWindow.swift` passes D0-5a → D0-5d → D0-8a → D0-7a (D0-5a declares
the `.copy`, `.cut` and `.paste` intents and leaves their `perform` cases
empty with a note; D0-5d fills them with the bridge); `DesignEditor.swift`
D0-5a → D0-8b → D0-7a; `DesignCanvas.swift` D0-5b → D0-5d → D0-8a → D0-7a;
`DesignWindowOptions.swift` D0-5a → D0-7a. `DesignInspector.swift`,
`DesignAlignBar.swift` (D0-5c), `DesignLayersPanel.swift`,
`DesignClosePrompt.swift` (D0-5d), `DesignSaveStatus.swift` (D0-5a),
`DesignCommands.swift` (D0-6), `DesignSelectionMarks.swift`,
`DesignCanvasMarks.swift` and `DesignFrameLabels.swift` (D0-5b) are not
touched again here: each passes to its wave-1 feature when DW-a merges. D0-5b needs no task of
this packet: it reads `marquee`, `transformHelp` and the `cards` fixture
from design-contracts, and its `show` parameter has a nil default, so
`DesignEditor.swift`'s call still compiles. D0-5c and D0-6 need D0-5a's
intents (`.setStyle`; `.zoomToSelection`, `.renamePage` and the commands).
D0-7a needs no D0-6 code: it edits no menu file. D0-7b waits on D0-6 because
it carries `feature-done`, and that CI run must hold D0-6's extended J1.
D0-5a, D0-5d and D0-6 wait on Design shell-parity because DS-3 rewrites
their files; D0-5b and D0-5c don't touch them.

## Build waves

- Wave 1: D0-5a (once shell-parity has merged), D0-5b. Independent in this wave: both.
- Wave 2: D0-5c, D0-5d, D0-6 (DW-a done). Independent in this wave: all three.
- Wave 3: D0-8a. Independent in this wave: D0-8a alone.
- Wave 4: D0-8b (DW-b done). Independent in this wave: D0-8b alone.
- Wave 5: D0-7a. Independent in this wave: D0-7a alone.
- Wave 6: D0-7b (`feature-done`, final). Independent in this wave: D0-7b alone.

No task edits a shared doc (rule (a)), so no docs task is added.

Longest chain: D0-5a → D0-5d → D0-8a → D0-8b → D0-7a → D0-7b (6).
Chain of 6: the window's three files pass through each task in turn. D0-5d
fills the `.copy`, `.cut` and `.paste` cases D0-5a adds; D0-8a routes the
drags D0-5d's canvas hooks sit beside; D0-8b counts the body D0-8a slims;
D0-7a registers ids in the same three files; D0-7b's J15 reads the
`suite.controls` D0-7a publishes. The wave-1 views wait only on the first
two tasks of it (DW-a), and their drag checks on the first four (DW-b).

## Acceptance test per task

| id | test | fails when |
|---|---|---|
| D0-5a | `DesignWindowOptionsTests` (Linux): `["-DesignServices", "fake"]` gives `.fake`, nothing or `"live"` or `"x"` gives `.live`; `-DesignFixture cards` gives "cards"; `-DesignWindowSize 880x560` gives width 880 and height 560, `"880"`, `"0x0"`, `"axb"` and a missing value give nil; `openFixture("cards")` opens it with `documentURL == nil`, `canUndo == false`, and `openFixture("nope")` is false and changes nothing; `selectionCountText` is nil, "1 Layer", "2 Layers". `DesignStatusSnapshots`: `design-status-two-layers` with A and B selected on `cards` | a bad argument crashes or picks fake, a fixture opens as undoable or saved, or the count reads wrong |
| D0-5b | `DesignCanvasSeamSnapshots`: `design-canvas-marquee` (mid-marquee over A and B on `.fake`: the accent outline and fill drawn over the page edge, not clipped), `design-canvas-several-fake` (A and B on `.fake`: two outlines, the dashed box, 8 handles) and `design-canvas-several-live` (the same on `.live`: no handles, since resize is not built); today's `DesignCanvasSnapshots`, `DesignResizeSnapshots`, `DesignSelectionEdgeSnapshots` and `DesignMultiSelectSnapshots` PNGs unchanged | the marquee is clipped or missing, handles show on `.live` (a dead control) or are missing on `.fake`, or an existing PNG changes |
| D0-5c | `DesignSeveralInspectorSnapshots`: `design-inspector-several-fake` (A and B on `.fake`: "2 Layers", the Align row with Distribute, X, Y and W reading "Mixed", H reading 80) and `design-inspector-several-live` (the same on `.live`: every control dimmed with its tooltip text asserted on the hosted view's `help`) | the header miscounts, a common value reads "Mixed", or a `.live` control is enabled |
| D0-5d | `DesignPasteboardBridgeTests` (macOS, a private `NSPasteboard(name:)`): bytes written under `org.creativesuite.design.layers` read back equal; plain text on the pasteboard reads as nil for our type; reading never clears it | bytes change, another type is read as ours, or a read empties the pasteboard |
| D0-6 | `DesignEditMenuSnapshots` adds `design-edit-menu-duplicate` (Duplicate after Cut, Copy, Paste and Select All; disabled with nothing selected); `DesignPageMenuSnapshots` adds Rename Page…; J1 (`DesignJourneyTests.testEveryMenuOpens`) lists each new item and checks each Design item is enabled or has a tooltip | an item is missing, the stock pasteboard group is replaced, or a disabled Design item has no reason |
| D0-8a | `DesignLiveDragTests` (macOS, hosted window on `cards`, `.fake`): a 120-sample move of A leaves the model's A where it was until mouse-up while the live copy's A moves; after mouse-up the document equals the one 120 direct `model.drag` calls give, with one "Move" undo step and `live.workspace == nil`; a scrub preview of A's opacity changes the live copy only and commits one "Change Opacity" step at `end` | the model changes before mouse-up, the end state differs, or a gesture records more than one step |
| D0-8b | `DesignWindowDragTests` on `crowd`: a 120-sample move, resize, marquee and rectangle draw each run `DesignEditor`'s body 3 times or fewer; the same check with the box bypassed (samples written to the model) counts about 120, so the test can fail | the editor body runs per sample |
| D0-7a | `DesignControlIDTests` (Linux): every id in `DesignControlID.all` is unique, matches `design.<area>.<name>` (lowercase, dot-separated, three parts or more), and includes `design.canvas.selection`, `design.bar.undo` and each Align and Distribute button; the macOS run's `audit-design-*.json` `identifier` count falls | an id repeats, a view uses a literal id not in the list, or the count does not fall |
| D0-7b | J15 and `testLayoutAtWidths` pass on the macOS run; J15 fails on a deliberately enabled control with no effect (the test's own guard: it asserts the shot or a value changed, never just that the click happened); the layout test fails when the panel is not 280 pt or the canvas is under 440 pt | a dead control passes, or the layout asserts are skipped on CI sizes |

D0-5c's numbers: on `cards`, A is (100, 100, 100 × 80) and B is (300, 140,
200 × 80), so X, Y and W differ and H is shared.

## Quality tests

| quality row | budget | test |
|---|---|---|
| QB-F1 no dead controls | every enabled `design.*` control acts; every disabled one says why | J15 `testEveryControlActsOrSaysWhy` |
| 7.2 `identifier` | falls with DW-a and DW-c (0 is wave 1's, #288) | the macOS run's audit, `UITests/audit-baseline.json` |
| a drag doesn't run the editor per sample | `DesignEditor`'s body ≤ 3 runs over a 120-sample move, resize, marquee or draw | `DesignWindowDragTests` (D0-8b) |
| 7.2 `overlap`, `offscreen` | 0 at 880 × 560 and 1024 × 720 on CI | `testLayoutAtWidths` |
| 7.3 layout spec | panel 280 pt, canvas ≥ 440 pt, value column and toggle columns aligned to 0.5 pt | `testLayoutAtWidths` |
| 7.2 `unnamed` | 0: every icon-only Align and Distribute button keeps a title | the macOS run's audit |
| QB-F5 contrast of the marquee | judged by eye in `design-canvas-marquee` until #331 and #332 land; then a golden | `DesignCanvasSeamSnapshots` |

## Done check

Per slice: DW-a is done when J1 (extended) passes on the Design-scoped
macOS run after D0-6; DW-b when J3 still passes and `DesignWindowDragTests`
is green; DW-c when J15 and the layout journey pass. The feature is done
when all three are:

- **Journeys green:** the Design-scoped macOS run after the `feature-done` PR is
  green: J0 to J3 unchanged, J1 extended, J15 and the layout journey new.
- **Audit zero new:** that run's `design` counts are at or under the
  baseline, and `identifier` has fallen; nothing new in `overlap`,
  `offscreen`, `contrast`, `unnamed` or `disabled-dim`.
- **Contact sheet:** the lead comments `Belt-Contact-Sheet: <run link>` on
  the feature issue with one line per journey (J1, J15, layout) and the
  audit counts; the sheet shows the new menu items and the several-layer
  inspector disabled with "isn't built yet." on the live services.
