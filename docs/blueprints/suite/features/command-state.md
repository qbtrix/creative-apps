# Feature packet: command-state

**Feature:** the AI-accessible-first promise, kept for the beta. Two gaps
remain on dev. `suite.controls` (the control inventory journeys and agents
read) has no on or off state, so nobody can tell whether Show Original or any
selected toggle is on (#3652); and 89 controls are still bare buttons listed
in `Tests/command-path-baseline/<app>.txt` (Library 42, Halo 17, Photo 13,
Flare 11, Design 7 on `8c90de14b`), so the CLI and MCP can't reach them. This
packet gives `ControlEntry` an optional `selected` that every toggle-style
control reports, makes Library's Show Original a catalog command, and moves
every bare control onto a command, one app per slice. A ratchet keeps it there:
each baseline file carries a `# max: N` header that `CommandPathLimitTests`
holds, and each slice lowers it. Sheet Cancel and Close buttons are view state,
not document actions; the lint's new dismiss rule names them instead of a
baseline line.
**Line:** `line:suite` · **Wave:** BG1 (`waves.md`, the beta gaps) · **Lead branch:** `lead/command-state`
**Beta:** captain, 2026-10-21 (beta gaps, suite must-haves). Labels `beta` and `p0` when filed.

**Covers:** `2026-10-21-beta-gaps-combined.md` suite must-have "every action
is a command and toggles report state"; suite audit row 7 and under-specified
4 and 6; #3652 (closes); RJ-X61 (new).

**Depends on:** afterglow-cli (built, wave AI1) for the job's runner;
command-catalog and adopt-command-catalog (built, suiteui line):
`CommandSpec`, `MenuCommand(spec:)`, `CommandPathTests` and each app's catalog.

**Hand-offs** (each app slice switches files other lines also own; the lead
checks the owner's open slices before starting and goes after them):
- **CS-library-1, CS-library-2:** `LibraryCommands.swift`,
  `LibraryExportSheet.swift`, `LibraryBrowser.swift` (library spine, export,
  filters-collections, file-flow), `LibraryCommandCatalog.swift` and its ledger
  (suiteui shared-thumbnails ST-m, library tone-controls, file-flow).
- **CS-halo:** `HaloRenderSheet.swift`, `HaloWindow+File.swift`,
  `HaloWindow+Layers.swift`, `NewCompositionSheet.swift` (halo core-loop,
  file-flow, layer-panel); Halo's catalog after the suiteui XK4 Halo adopts.
- **CS-photo:** `ExportSheet.swift`, `ImageSizeSheet.swift`,
  `StraightenSheet.swift`, `PhotoCommands+File.swift`, `PhotoWindow.swift`
  (photo export-pack, transform, file-flow); Photo's catalog chain.
- **CS-flare:** `FlareRecovery.swift`, `FlareNewSheet.swift`,
  `FlareTimelineEdit.swift`; `Tests/command-path-baseline/flare.txt` after
  suiteui adopt-kernel-autosave AK-z.
- **CS-design:** `DesignCommands.swift` (design file-flow, export).

**Rule 20.** No new menu helper: every switch uses SuiteUI's existing
`MenuCommand(spec:)` and the app's own catalog. The `selected` state is one
field on SuiteUI's `ControlEntry`, set by the SuiteUI controls that are
toggles (`InspectorAction` with `isOn`, toolbar toggles, `SegmentedTabs`,
`KeyframeButton`), never by app code.

**C4:** no new component; `ControlInventorying.swift` is in
`suiteui/suiteui-sources`.

**Clean-room.** Nothing external is read.

Blueprint sections: suite.md 1.5 (commands), suiteui.md 2.2.

**Hand-off (beta gaps C1 to C12, suiteui line, cross-line):** the XK4 kernel-gap adopts (area-selection, clipboard-interop, frame-rates, document-setup, orientation-crop, anchor-parenting, brush-keys) also edit every app's catalog and `Tests/command-ids/<app>.txt`, Photo's, Library's and Flare's command-path baselines, and several menu and sheet files (`LibraryCommands.swift`, `HaloWindow+File.swift`, `NewCompositionSheet.swift`, `PhotoWindow.swift`, `FlareCommands.swift`, `FlareNewSheet.swift`, `FlareStageContextMenu.swift`, `DesignCommands.swift`, `DesignWindow.swift`). The slices here that edit those files start after those adopts' slices on the same app have merged, or before them with their lead told; the checker can't see this across lines.

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| CS-a | SuiteUI's control inventory reports selected for every toggle-style control, each baseline file has a max the ratchet test holds, and the lint names sheet dismiss buttons instead of baselining them. | CS-1, CS-2 | MJ-CS, XJ-CS | – |
| CS-library-1 | Library's 25 bare controls run catalog commands, its baseline file is empty of them and its limit drops to match, and its toggles report their state. | CS-3, CS-4 | LJ-CS1 | CS-a; the Library hand-offs |
| CS-library-2 | Library's 17 bare controls run catalog commands, its baseline file is empty of them and its limit drops to match, and its toggles report their state. | CS-5, CS-6 | LJ-CS2 | CS-a; CS-library-1 (the catalog and ledger) |
| CS-halo | Halo's 17 bare controls run catalog commands, its baseline file is empty of them and its limit drops to match, and its toggles report their state. | CS-7, CS-8 | HJ-CS | CS-a; the Halo hand-offs |
| CS-photo | Photo's 13 bare controls run catalog commands, its baseline file is empty of them and its limit drops to match, and its toggles report their state. | CS-9, CS-10 | PJ-CS | CS-a; the Photo hand-offs |
| CS-flare | Flare's 11 bare controls run catalog commands, its baseline file is empty of them and its limit drops to match, and its toggles report their state. | CS-11, CS-12 | FJ-CS | CS-a; the Flare hand-offs |
| CS-design | Design's 7 bare controls run catalog commands, its baseline file is empty of them and its limit drops to match, and its toggles report their state. | CS-13, CS-14 | DJ-CS | CS-a; the Design hand-offs |
| CS-z | Every baseline's max is 0 and the ratchet holds it, RJ-X61 runs Show Original by command, the control-state journey is on, and the feature is built. | CS-15, CS-16 | XJ-CS, MJ-CS | every app slice |

**Screen early.** The feature adds no screen: its UI work is the controls
the apps already show, moved onto commands, so CS-a (SuiteUI's state field)
is the `"ui": true` slice that waits on nothing, and each app slice is `"ui":
true` because it changes that app's views.

**Order.** The two Library slices share Library's catalog and ledger, so
CS-library-2 waits on CS-library-1 (the waits data). The other app slices run
side by side after CS-a.

## Journey steps

`MJ-CS` on Linux (`ControlStateTests` runs on macOS; `CommandPathTests`,
`CommandPathLimitTests` and each `<App>CommandPathTests` on Linux), then:
1. Library: press the Show Original toggle; `suite.controls` reports
   `library.develop.original` `selected: true`; press again, `false`
   (CS-1, CS-4; `XJ-CS`, `AfterGlowJourneyTests.testTogglesReportState`).
2. Each app's existing journeys stay green after its slice (`LJ-CS1`,
   `LJ-CS2`, `HJ-CS`, `PJ-CS`, `FJ-CS`, `DJ-CS`: the journeys that already
   drive those menus and sheets, unchanged).

## Jobs

| job | closes or adds | run | check | fixture |
|---|---|---|---|---|
| RJ-X61 | adds, closes with `suite/command-state` | C | `Tests/RealJobs/library/show-original/` and `show-original-off/`: `view.show-original` on, the `json` export with `contents: shown` reads `original: true`; toggled twice in one run, `original: false` | the library sample catalog |

Trap: a toggle an agent can't see or set, so it flips it blind or not at all.
Assertion: after the first run `view.read` reports `showOriginal: true`, after
the second `false`, and the photo's develop values are unchanged both times.
Mutation: `LibraryModel.LibraryCommandCatalog` (`.showOriginalToggles`, added
by CS-3). The check is written by CS-15 and stays disabled until CS-3 merges.

## Screens and states

None new. Every app's existing snapshots must not change.

## Contract slice

```swift
// Sources/SuiteUI/Contracts/ControlInventorying.swift (CS-1)
public struct ControlEntry: Hashable, Sendable, Codable {
    public var id: String
    public var enabled: Bool
    public var reason: String?
    public var role: String?
    public var selected: Bool?          // toggles only; nil (and no key) for every other control
    public init(id: String, enabled: Bool, reason: String? = nil, role: String? = nil, selected: Bool? = nil)
}
```

New command ids (each in its app's ledger): Library `view.show-original`
(and the ids for its 25 menu closures that lack one: import, rotate and the
rest the slice's test lists); Halo `render.start`, `composition.new`,
`layer.rename`; Photo `file.open-recent`; Flare `recovery.restore`,
`recovery.discard`, `frame.label`; Design `view.zoom-in`, `view.zoom-out`,
`view.fit`. A slice's test fixes the exact list from its baseline lines.

`# max: N` is the second line of each `Tests/command-path-baseline/<app>.txt`;
`CommandPathLimitTests` fails when the file holds more than N control lines.

## Pseudocode

- **Selected.** A SuiteUI control that draws an on state (InspectorAction
  `isOn`, a toolbar toggle, the picked `SegmentedTabs` item, a keyed
  `KeyframeButton`) registers `selected` with its id; nothing else does, so
  existing inventories decode and compare unchanged.
- **Switching a control.** A menu item becomes `MenuCommand(spec:)` over the
  app's catalog; a sheet's confirm builds the command's params from the sheet
  and runs it through the catalog (one undo step, as today); a sheet's Cancel
  stays a dismiss.
- **Ratchet.** Each slice deletes its lines from the baseline and sets
  `# max:` to the remaining count in the same commit; CS-z leaves every max
  at 0, so any new bare control fails CI on the PR that adds it.

## Tasks

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| CS-1 | – | **Test first.** `ControlStateTests` (an `InspectorAction` that is on publishes `selected: true`, off `false`, a plain button omits the key; old documents decode); `ControlEntry.selected: Bool?`, encoded only when set; `InspectorAction`, toolbar toggles, `SegmentedTabs` and `KeyframeButton` report it; `AfterGlowControlStateJourneyTests` written, skipped until CS-library-1 | `Sources/SuiteUI/Contracts/ControlInventorying.swift`, `Sources/SuiteUI/ControlInventory.swift`, `Sources/SuiteUI/InspectorAction.swift`, `Sources/SuiteUI/SegmentedTabs.swift`, `Sources/SuiteUI/KeyframeButton.swift`, `Tests/SuiteUITests/ControlStateTests.swift`, `UITests/AfterGlowJourneyTests+ControlState.swift` | – | ~200, 7 |
| CS-2 | – | `CommandPathLimitTests`: each baseline file's `# max: N` header (added to the five files at today's counts) holds its line count; `CommandPathTests` gains the dismiss rule (a `Button("Cancel")`, `"Close"` or `"Done"` that only dismisses its sheet is not a bare control) and scans `Sources/SuiteShell` and `Sources/AfterGlowApp` too, with their own baselines (`shell.txt`, `launcher.txt`) at today's counts | `Tests/SuiteKernelTests/CommandPathLimitTests.swift`, `Tests/SuiteKernelTests/CommandPathTests.swift`, `Tests/command-path-baseline/design.txt`, `Tests/command-path-baseline/flare.txt`, `Tests/command-path-baseline/halo.txt`, `Tests/command-path-baseline/library.txt`, `Tests/command-path-baseline/photo.txt`, `Tests/command-path-baseline/shell.txt`, `Tests/command-path-baseline/launcher.txt`, `Tests/mutations/SuiteKernelTests.CommandPathTests.json` | – | ~150, 8 |
| CS-3 | – | **Test first.** `LibraryCommandPathTests` lists the ids each control must run (the 25 `MenuCommand` closures in `LibraryCommands.swift`, plus `view.show-original` for #3652); the missing specs added to Library's catalog and ledger, each with its availability | `Tests/LibraryModelTests/LibraryCommandPathTests.swift`, `Sources/LibraryModel/LibraryCommandCatalog.swift`, `Tests/command-ids/library.txt`, `Tests/mutations/LibraryModel.LibraryCommandCatalog.json` | CS-2 | ~200, 4 |
| CS-4 | – | The controls run their commands (menus through `MenuCommand(spec:)`, sheet confirms through the sheet's command, Cancel and Close under the lint's dismiss rule); their lines leave `Tests/command-path-baseline/library.txt` and its `# max:` drops to the new count | `Sources/LibraryApp/LibraryCommands.swift`, `Tests/command-path-baseline/library.txt` | CS-3 | ~220, 2 |
| CS-5 | – | **Test first.** `LibraryCommandPathTests` lists the ids each control must run (the export sheet's 11 (its confirm runs `file.export` with the sheet's options), the browser's 4, Develop's reset and the loupe's one); the missing specs added to Library's catalog and ledger, each with its availability | `Tests/LibraryModelTests/LibraryCommandPathTests.swift`, `Sources/LibraryModel/LibraryCommandCatalog.swift`, `Tests/command-ids/library.txt`, `Tests/mutations/LibraryModel.LibraryCommandCatalog.json` | CS-2, CS-3 | ~160, 4 |
| CS-6 | – | The controls run their commands (menus through `MenuCommand(spec:)`, sheet confirms through the sheet's command, Cancel and Close under the lint's dismiss rule); their lines leave `Tests/command-path-baseline/library.txt` and its `# max:` drops to the new count | `Sources/LibraryApp/LibraryExportSheet.swift`, `Sources/LibraryApp/LibraryBrowser.swift`, `Sources/LibraryApp/DevelopInspector.swift`, `Sources/LibraryApp/LibraryLoupe.swift`, `Tests/command-path-baseline/library.txt` | CS-5 | ~220, 5 |
| CS-7 | – | **Test first.** `HaloCommandPathTests` lists the ids each control must run (render sheet, new composition, rename, the unsaved alert's actions, transport and timeline buttons); the missing specs added to Halo's catalog and ledger, each with its availability | `Tests/HaloModelTests/HaloCommandPathTests.swift`, `Sources/HaloModel/HaloCommandCatalog.swift`, `Tests/command-ids/halo.txt`, `Tests/mutations/HaloModel.HaloCommandCatalog.json` | CS-2 | ~180, 4 |
| CS-8 | – | The controls run their commands (menus through `MenuCommand(spec:)`, sheet confirms through the sheet's command, Cancel and Close under the lint's dismiss rule); their lines leave `Tests/command-path-baseline/halo.txt` and its `# max:` drops to the new count | `Sources/HaloApp/HaloRenderSheet.swift`, `Sources/HaloApp/HaloTimelineView.swift`, `Sources/HaloApp/HaloTransport.swift`, `Sources/HaloApp/HaloWindow+File.swift`, `Sources/HaloApp/HaloWindow+Layers.swift`, `Sources/HaloApp/HaloWindow+Render.swift`, `Sources/HaloApp/NewCompositionSheet.swift`, `Sources/HaloApp/RenameRefusalAlert.swift`, `Tests/command-path-baseline/halo.txt` | CS-7 | ~240, 9 |
| CS-9 | – | **Test first.** `PhotoCommandPathTests` lists the ids each control must run (export, image size, straighten (each sheet's confirm runs its command with the sheet's values) and Open Recent); the missing specs added to Photo's catalog and ledger, each with its availability | `Tests/PhotoModelTests/PhotoCommandPathTests.swift`, `Sources/PhotoModel/PhotoCommandCatalog.swift`, `Tests/command-ids/photo.txt`, `Tests/mutations/PhotoModel.PhotoCommandCatalog.json` | CS-2 | ~150, 4 |
| CS-10 | – | The controls run their commands (menus through `MenuCommand(spec:)`, sheet confirms through the sheet's command, Cancel and Close under the lint's dismiss rule); their lines leave `Tests/command-path-baseline/photo.txt` and its `# max:` drops to the new count | `Sources/PhotoApp/ExportSheet.swift`, `Sources/PhotoApp/ImageSizeSheet.swift`, `Sources/PhotoApp/PhotoCommands+File.swift`, `Sources/PhotoApp/PhotoWindow.swift`, `Sources/PhotoApp/StraightenSheet.swift`, `Tests/command-path-baseline/photo.txt` | CS-9 | ~180, 6 |
| CS-11 | – | **Test first.** `FlareCommandPathTests` lists the ids each control must run (recovery Restore and Discard, the new sheet, frame labels and the timeline edit buttons); the missing specs added to Flare's catalog and ledger, each with its availability | `Tests/FlareModelTests/FlareCommandPathTests.swift`, `Sources/FlareModel/FlareCommandCatalog.swift`, `Tests/command-ids/flare.txt`, `Tests/mutations/FlareModel.FlareCommandCatalog.json` | CS-2 | ~140, 4 |
| CS-12 | – | The controls run their commands (menus through `MenuCommand(spec:)`, sheet confirms through the sheet's command, Cancel and Close under the lint's dismiss rule); their lines leave `Tests/command-path-baseline/flare.txt` and its `# max:` drops to the new count | `Sources/FlareApp/FlareCommands.swift`, `Sources/FlareApp/FlareFilePanels.swift`, `Sources/FlareApp/FlareNewSheet.swift`, `Sources/FlareApp/FlareRecovery.swift`, `Sources/FlareApp/FlareStageContextMenu.swift`, `Sources/FlareApp/FlareTimelineEdit.swift`, `Tests/command-path-baseline/flare.txt` | CS-11 | ~170, 7 |
| CS-13 | – | **Test first.** `DesignCommandPathTests` lists the ids each control must run (Export, the zoom items and Fit); the missing specs added to Design's catalog and ledger, each with its availability | `Tests/DesignModelTests/DesignCommandPathTests.swift`, `Sources/DesignModel/DesignCommandCatalog.swift`, `Tests/command-ids/design.txt`, `Tests/mutations/DesignModel.DesignCommandCatalog.json` | CS-2 | ~110, 4 |
| CS-14 | – | The controls run their commands (menus through `MenuCommand(spec:)`, sheet confirms through the sheet's command, Cancel and Close under the lint's dismiss rule); their lines leave `Tests/command-path-baseline/design.txt` and its `# max:` drops to the new count | `Sources/DesignApp/DesignCommands.swift`, `Sources/DesignApp/DesignWindow.swift`, `Tests/command-path-baseline/design.txt` | CS-13 | ~90, 3 |
| CS-15 | – | RJ-X61's job (toggle Show Original with the CLI, read it back) and its check, enabled; `AfterGlowJourneyTests.testTogglesReportState` on | `Tests/RealJobs/library/show-original/show-original.jobs.json`, `UITests/AfterGlowJourneyTests+ControlState.swift` | CS-4, CS-6, CS-8, CS-10, CS-12, CS-14, CS-1 | ~90, 2 |
| CS-16 | – | `status: built`; `feature-done` | `docs/blueprints/suite/features/command-state.wave.json` | CS-15 | ~10, 1 |

## Build waves

- Wave 1: CS-1, CS-2. Independent in this wave: both.
- Wave 2: CS-3, CS-7, CS-9, CS-11, CS-13. Independent in this wave: all.
- Wave 3: CS-4, CS-5, CS-8, CS-10, CS-12, CS-14. Independent in this wave: all.
- Wave 4: CS-6. Independent in this wave: CS-6 alone.
- Wave 5: CS-15. Independent in this wave: CS-15 alone.
- Wave 6: CS-16. Independent in this wave: CS-16 alone.

Longest chain: CS-2 → CS-3 → CS-5 → CS-6 → CS-15 → CS-16 (6). Chain of 6: the lint first, then each app's commands before its controls switch, the Library pair in order on one catalog, and the job after every app.

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| CS-1 | `ControlStateTests` | a toggle publishes no state, or a plain button publishes one | – (SuiteUI; macOS-only files, the finisher runs the view half) |
| CS-2 | `CommandPathLimitTests`: a fixture with 3 lines under `# max: 2` fails; `CommandPathTests`: a sheet's Cancel passes, a Cancel that also edits fails | the baseline can grow, or the dismiss rule lets an edit through | `SuiteKernelTests.CommandPathTests`: dismiss rule matches any button title → `.dismissOnlyDismisses`; max read as a minimum → `.limitCaps` |
| CS-3 | `LibraryCommandPathTests`: every listed id is in the catalog with a schema and runs headless | a control's action has no command | `LibraryModel.LibraryCommandCatalog`: one new spec's availability always available → `.reasonWhenUnavailable`; a sheet command ignores a param → `.paramsReachRun` |
| CS-4 | `CommandPathTests` and `CommandPathLimitTests` with the shorter baseline; Library's journeys unchanged | a control still runs a closure, or the limit didn't drop | – (view wiring; the catalog's plan covers the logic) |
| CS-5 | `LibraryCommandPathTests`: every listed id is in the catalog with a schema and runs headless | a control's action has no command | `LibraryModel.LibraryCommandCatalog`: one new spec's availability always available → `.reasonWhenUnavailable`; a sheet command ignores a param → `.paramsReachRun` |
| CS-6 | `CommandPathTests` and `CommandPathLimitTests` with the shorter baseline; Library's journeys unchanged | a control still runs a closure, or the limit didn't drop | – (view wiring; the catalog's plan covers the logic) |
| CS-7 | `HaloCommandPathTests`: every listed id is in the catalog with a schema and runs headless | a control's action has no command | `HaloModel.HaloCommandCatalog`: one new spec's availability always available → `.reasonWhenUnavailable`; a sheet command ignores a param → `.paramsReachRun` |
| CS-8 | `CommandPathTests` and `CommandPathLimitTests` with the shorter baseline; Halo's journeys unchanged | a control still runs a closure, or the limit didn't drop | – (view wiring; the catalog's plan covers the logic) |
| CS-9 | `PhotoCommandPathTests`: every listed id is in the catalog with a schema and runs headless | a control's action has no command | `PhotoModel.PhotoCommandCatalog`: one new spec's availability always available → `.reasonWhenUnavailable`; a sheet command ignores a param → `.paramsReachRun` |
| CS-10 | `CommandPathTests` and `CommandPathLimitTests` with the shorter baseline; Photo's journeys unchanged | a control still runs a closure, or the limit didn't drop | – (view wiring; the catalog's plan covers the logic) |
| CS-11 | `FlareCommandPathTests`: every listed id is in the catalog with a schema and runs headless | a control's action has no command | `FlareModel.FlareCommandCatalog`: one new spec's availability always available → `.reasonWhenUnavailable`; a sheet command ignores a param → `.paramsReachRun` |
| CS-12 | `CommandPathTests` and `CommandPathLimitTests` with the shorter baseline; Flare's journeys unchanged | a control still runs a closure, or the limit didn't drop | – (view wiring; the catalog's plan covers the logic) |
| CS-13 | `DesignCommandPathTests`: every listed id is in the catalog with a schema and runs headless | a control's action has no command | `DesignModel.DesignCommandCatalog`: one new spec's availability always available → `.reasonWhenUnavailable`; a sheet command ignores a param → `.paramsReachRun` |
| CS-14 | `CommandPathTests` and `CommandPathLimitTests` with the shorter baseline; Design's journeys unchanged | a control still runs a closure, or the limit didn't drop | – (view wiring; the catalog's plan covers the logic) |
| CS-15 | RJ-X61 on Linux; `XJ-CS` | Show Original can't be reached by command, or its state isn't readable | – (job) |
| CS-16 | `scripts/waves render --dry-run` | status not built | – |

## Quality tests

| quality row | budget | test |
|---|---|---|
| render: Show Original toggle | ≤ 2 window bodies | `RenderBudgetLibraryDevelopTests` (existing, unchanged) |
| no dead controls | 0 lines in every baseline, capped | `CommandPathTests`, `CommandPathLimitTests` |
| one gesture, one step | each switched sheet confirm is one undo step, as before | each app's `<App>CommandPathTests` |
| behaviour preserved | every app's journeys and snapshots unchanged | the scoped run per slice |

## Done check

Per slice (rules 6, 15, 17, 21, 22): CS-a with `ControlStateTests` green on the
macOS gate and the ratchet green on Linux; each app slice merged-done when its
baseline lines are gone, its `# max:` dropped and its journeys green in a
scoped run, verified after the feel gate (`mouse`: every switched control
still works by mouse) and its `Mac-Finish:` line; RJ-X61 green on Linux at
CS-z. Then `Belt-Contact-Sheet:`.
