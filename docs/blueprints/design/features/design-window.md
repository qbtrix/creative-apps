# Feature packet: design-window

**Feature:** the window half of Design's wave-0 seam: every new intent and
menu item, the launch arguments the journeys use (`-DesignServices`,
`-DesignFixture`, `-DesignWindowSize`), the several-layer inspector shell,
the canvas marks and overlay slots, the pasteboard bridge, the control ids
registered with SuiteUI's inventory, and the every-control and layout
journeys. Each new control is wired to `design-seams`' actions and shows
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

**Depends on:** the design-seams feature issue (the actions, services and
fixtures this window calls) and #778 suite-harness, for three of its tasks:
SH-7 (#333: the Journey template compiles `UITests/<target>*.swift`, so
D0-7b's new journey files build; `Journey+Input.swift`'s keys with
modifiers), SH-5 (#775: `.suiteControl(id:enabled:reason:)`, `.suiteProbes()`
and `ToolbarAction.identifier`, the one publisher of `suite.controls`,
captain call Q9 of the SuiteUI packets) and SH-4 (#330: `suite.perf`). No
creative-core issue.

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
that can be pure lives in `DesignWindowOptions.swift` or `design-seams`'
actions.

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
3. **J15** `testEveryControlActsOrSaysWhy` (`+EveryControl`, D0-7b) on
   `cards`, live services: read `suite.controls`, click each enabled
   `design.*` control, Escape, ⌘Z; every enabled one changed the shot or a
   value; every disabled one has a reason (the "isn't built yet." ones
   included). A sweep, never cited by the matrix.
4. **Layout** `testLayoutAtWidths` (`+Layout`, D0-7b) on `cards` with A
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
/// Every `design.*` control id, in one place so the views and J15 agree.
public enum DesignControlID { public static let all: [String]; public static let canvasSelection = "design.canvas.selection" /* … */ }
```

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

registration (D0-7a): window root .suiteProbes();
  every Design-owned control: .accessibilityIdentifier(id).suiteControl(id: id, enabled: help == nil, reason: help)
```

## Tasks

Every task is one PR to `dev`: at most 400 changed lines and 15 files,
label `fast-lane`, body lines `Belt-Lead:`, `Feature: design-window`,
`Fast-Check: pass`, `Head:`, and the snapshot PNGs it changes. D0-7b also
carries `feature-done`. Paths drop `Sources/DesignApp/`; snapshots are in
`Tests/AppSnapshotTests/`.

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| D0-5a | #288 (part) | `DesignWindowOptions` and `openFixture`; every new intent and `perform` for it; the three launch arguments; Zoom to Selection sets the zoom and keeps the rect in the window's state; the status line's selection count | `Sources/DesignModel/DesignWindowOptions.swift`, `DesignIntent.swift`, `DesignWindow.swift`, `DesignEditor.swift`; `Tests/DesignModelTests/DesignWindowOptionsTests.swift`; snapshot `DesignStatusSnapshots.swift` | – | ~360, 6 |
| D0-5b | #288 (part) | Canvas: the marquee mark; selection marks in their own file with `design.canvas.selection`; the empty `DesignFrameLabels` overlay slot; the `show` parameter | `DesignCanvas.swift`, `DesignCanvasMarks.swift`, `DesignSelectionMarks.swift`, `DesignFrameLabels.swift`; snapshot `DesignCanvasSeamSnapshots.swift` | D0-5a | ~300, 5 |
| D0-5c | #288 (part); files the `ScrubField` mixed `needs-ui` issue | The several-layer inspector shell: "<n> Layers", the Align row with Distribute, rows reading "Mixed", each control's help from the actions | `DesignInspector.swift`, `DesignAlignBar.swift`; snapshot `DesignSeveralInspectorSnapshots.swift` | D0-5a | ~280, 3 |
| D0-5d | #288 (part) | `DesignPasteboardBridge` (read and write under `pasteboardType`); copy, cut and paste hooks on the canvas and Layers; rename presentation state in Layers (row in rename, draft, refusal text) | `DesignPasteboardBridge.swift`, `DesignWindow.swift` (the `.copy`, `.cut` and `.paste` cases of `perform`), `DesignCanvas.swift`, `DesignLayersPanel.swift`; `Tests/AppSnapshotTests/DesignPasteboardBridgeTests.swift` | D0-5a, D0-5b | ~280, 5 |
| D0-6 | #288 (part) | Menus: Edit adds Duplicate after the stock pasteboard group (which stays); Page adds Rename Page…; Object adds Group, Ungroup, Arrange ▸, Distribute; View adds Zoom to Selection; every Design item disabled with its help; J1's item list | `DesignCommands.swift`, `DesignEditMenu.swift`, `DesignObjectMenu.swift`; snapshots `DesignEditMenuSnapshots.swift`, `DesignPageMenuSnapshots.swift`; `UITests/DesignJourneyTests.swift` | D0-5a | ~330, 6 |
| D0-7a | #288 (part) | `.suiteProbes()` at the window root; every Design-owned control gets its `DesignControlID` id and `.suiteControl` registration (rail and top bar through `ToolbarAction.identifier`) | `DesignWindow.swift`, `DesignEditor.swift`, `DesignPanel.swift`, `DesignInspector.swift`, `DesignAlignBar.swift`, `DesignLayersPanel.swift`, `DesignCanvas.swift`, `Sources/DesignModel/DesignWindowOptions.swift`; `Tests/DesignModelTests/DesignControlIDTests.swift` | D0-5c, D0-5d, D0-6; #778 (SH-5) | ~250, 9 |
| D0-7b | – | The every-control sweep J15 and the layout journey | `UITests/DesignJourneyTests+EveryControl.swift`, `UITests/DesignJourneyTests+Layout.swift` | D0-7a; #778 (SH-7) | ~300, 2; `feature-done` |

`DesignWindow.swift` passes D0-5a → D0-5d → D0-7a (D0-5a declares the
`.copy`, `.cut` and `.paste` intents and leaves their `perform` cases empty
with a note; D0-5d fills them with the bridge); `DesignEditor.swift` D0-5a →
D0-7a;
`DesignCanvas.swift` D0-5b → D0-5d → D0-7a; `DesignInspector.swift` and
`DesignAlignBar.swift` D0-5c → D0-7a; `DesignLayersPanel.swift` D0-5d →
D0-7a; `DesignWindowOptions.swift` D0-5a → D0-7a. D0-5b, D0-5c and D0-6
touch disjoint files and may run side by side after D0-5a.

## Acceptance test per task

| id | test | fails when |
|---|---|---|
| D0-5a | `DesignWindowOptionsTests` (Linux): `["-DesignServices", "fake"]` gives `.fake`, nothing or `"live"` or `"x"` gives `.live`; `-DesignFixture cards` gives "cards"; `-DesignWindowSize 880x560` gives width 880 and height 560, `"880"`, `"0x0"`, `"axb"` and a missing value give nil; `openFixture("cards")` opens it with `documentURL == nil`, `canUndo == false`, and `openFixture("nope")` is false and changes nothing; `selectionCountText` is nil, "1 Layer", "2 Layers". `DesignStatusSnapshots`: `design-status-two-layers` with A and B selected on `cards` | a bad argument crashes or picks fake, a fixture opens as undoable or saved, or the count reads wrong |
| D0-5b | `DesignCanvasSeamSnapshots`: `design-canvas-marquee` (mid-marquee over A and B on `.fake`: the accent outline and fill drawn over the page edge, not clipped), `design-canvas-several-fake` (A and B on `.fake`: two outlines, the dashed box, 8 handles) and `design-canvas-several-live` (the same on `.live`: no handles, since resize is not built); today's `DesignCanvasSnapshots`, `DesignResizeSnapshots`, `DesignSelectionEdgeSnapshots` and `DesignMultiSelectSnapshots` PNGs unchanged | the marquee is clipped or missing, handles show on `.live` (a dead control) or are missing on `.fake`, or an existing PNG changes |
| D0-5c | `DesignSeveralInspectorSnapshots`: `design-inspector-several-fake` (A and B on `.fake`: "2 Layers", the Align row with Distribute, X, Y and W reading "Mixed", H reading 80) and `design-inspector-several-live` (the same on `.live`: every control dimmed with its tooltip text asserted on the hosted view's `help`) | the header miscounts, a common value reads "Mixed", or a `.live` control is enabled |
| D0-5d | `DesignPasteboardBridgeTests` (macOS, a private `NSPasteboard(name:)`): bytes written under `org.creativesuite.design.layers` read back equal; plain text on the pasteboard reads as nil for our type; reading never clears it | bytes change, another type is read as ours, or a read empties the pasteboard |
| D0-6 | `DesignEditMenuSnapshots` adds `design-edit-menu-duplicate` (Duplicate after Cut, Copy, Paste and Select All; disabled with nothing selected); `DesignPageMenuSnapshots` adds Rename Page…; J1 (`DesignJourneyTests.testEveryMenuOpens`) lists each new item and checks each Design item is enabled or has a tooltip | an item is missing, the stock pasteboard group is replaced, or a disabled Design item has no reason |
| D0-7a | `DesignControlIDTests` (Linux): every id in `DesignControlID.all` is unique, matches `design.<area>.<name>` (lowercase, dot-separated, three parts or more), and includes `design.canvas.selection`, `design.bar.undo` and each Align and Distribute button; the macOS run's `audit-design-*.json` `identifier` count falls below 20 | an id repeats, a view uses a literal id not in the list, or the count does not fall |
| D0-7b | J15 and `testLayoutAtWidths` pass on the macOS run; J15 fails on a deliberately enabled control with no effect (the test's own guard: it asserts the shot or a value changed, never just that the click happened); the layout test fails when the panel is not 280 pt or the canvas is under 440 pt | a dead control passes, or the layout asserts are skipped on CI sizes |

D0-5c's numbers: on `cards`, A is (100, 100, 100 × 80) and B is (300, 140,
200 × 80), so X, Y and W differ and H is shared.

## Quality tests

| quality row | budget | test |
|---|---|---|
| QB-F1 no dead controls | every enabled `design.*` control acts; every disabled one says why | J15 `testEveryControlActsOrSaysWhy` |
| 7.2 `identifier` | under 20 after D0-7a (0 is wave 1's, #288) | the macOS run's audit, `UITests/audit-baseline.json` |
| 7.2 `overlap`, `offscreen` | 0 at 880 × 560 and 1024 × 720 on CI | `testLayoutAtWidths` |
| 7.3 layout spec | panel 280 pt, canvas ≥ 440 pt, value column and toggle columns aligned to 0.5 pt | `testLayoutAtWidths` |
| 7.2 `unnamed` | 0: every icon-only Align and Distribute button keeps a title | the macOS run's audit |
| QB-F5 contrast of the marquee | judged by eye in `design-canvas-marquee` until #331 and #332 land; then a golden | `DesignCanvasSeamSnapshots` |

## Done check

- **Journeys green:** the macOS run on `dev` after the `feature-done` PR is
  green: J0 to J3 unchanged, J1 extended, J15 and the layout journey new.
- **Audit zero new:** that run's `design` counts are at or under the
  baseline, and `identifier` has fallen; nothing new in `overlap`,
  `offscreen`, `contrast`, `unnamed` or `disabled-dim`.
- **Contact sheet:** the lead comments `Belt-Contact-Sheet: <run link>` on
  the feature issue with one line per journey (J1, J15, layout) and the
  audit counts; the sheet shows the new menu items and the several-layer
  inspector disabled with "isn't built yet." on the live services.
