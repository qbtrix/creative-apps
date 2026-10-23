# Feature packet: adopt-command-catalog

**Feature:** each app registers the actions it already has as commands in
SuiteKernel's catalog, fills its `<X>Headless` document (open, save,
export, summary with no window, Linux included), adds its first real jobs,
and points its menus and toolbar at the catalog, so a menu item, the CLI,
the MCP server and a crew's test all take one path. Behaviour-preserving:
no new action, no new reason text, no new undo step; each app keeps its
public Model API, control ids and journeys.
**Line:** `line:suiteui` · **Wave:** XK2 (`waves.md`, the kernel track;
beta-80 **W2** adopt slices, `p0`) · **Lead branch:**
`lead/adopt-command-catalog`

**Covers:** the captain's AI-accessible-first call, per app; beta-80 plan
"W0: command layer", adopt rows; the plan's real-jobs acceptance suites
(each slice adds its app's first jobs).

**Depends on:** command-catalog (#2996): every slice waits on its
**CC-run** (the real catalog, ledger and conformance suite); the menu task
of each slice also on **CC-u** (`MenuCommand(spec:on:)`) and on **CC-lint**
(the app's command-path baseline it empties). Cross-line, as hand-offs:
- `suite/afterglow-cli` (#2998) **CL-jobs** for the real-jobs harness the jobs run
  in (the jobs are data; they merge before it and run once it lands).
- creative-core `image-codecs` (qbtrix/creative-core#562) **IC-png** and the `scripts/bump-core` that
  brings it, for Photo's and Library's Linux headless I/O (AC-p2, AC-l2).
  JPEG jobs wait on its **IC-jpeg**; until then they declare `"platforms":
  ["macos"]` with that reason and run on the Mac lane through ImageIO.
- Undo stays where adopt-kernel-undo puts it: each catalog reads its
  target's `HistoryReading` (Flare's is `CommandEngine` behind AU-f1's
  adapter). A slice never adds a history.

**Hand-offs** (files other packets own; the lead checks each before the
slice starts):
- **AC-photo:** `PhotoCommands+*.swift` are owned by photo-edit and
  photo-documents (built and in flight); the menu task starts after their
  `Belt-Slice-Done:` lines on those files.
- **AC-design:** `DesignEditMenu.swift` and `DesignObjectMenu.swift` by
  copy-group and select-several; `DesignActions.swift` stays as is (the
  catalog calls `help(_:)` and `run`).
- **AC-flare:** `FlareCommands.swift` by mac-platform and layers-files.
- **AC-halo:** `HaloCommands.swift` and the menu files by history-files and
  core-loop; `HaloCommand.swift` stays (the catalog maps its cases).
- **AC-library:** `LibraryMenus.swift` and `LibraryCommands.swift` by
  spine, cull and import. Library keeps several menu actions as closures in
  `LibraryApp`; AC-l1 moves each into a `LibraryCatalog` Model method first
  (a view-to-Model move the app-state rule wants anyway), so this slice is
  the largest (sized at 4 tasks, not 3).

**Clean-room.** Behaviour only; every rule comes from the apps' own tests.

Blueprint sections: each app's blueprint, the section that lists its menus
(unchanged behaviour); suite.md 1.5.

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| AC-photo | Photo's menu, toolbar and palette actions are catalog commands whose availability is the app's existing help, `PhotoHeadless` opens, saves and exports on Linux, the batch-resize and watermark jobs pass, and every menu item is built from its spec. | AC-p1, AC-p2, AC-p3 | MJ-AC-photo | command-catalog:CC-run; CC-u and CC-lint (AC-p3) |
| AC-design | Design's `DesignCommand`s, tools and file actions are catalog commands over `help(_:)` and `run`, `DesignHeadless` works on Linux, the export-frames and align jobs pass, and its menus are built from specs. | AC-d1, AC-d2, AC-d3 | MJ-AC-design | command-catalog:CC-run; CC-u and CC-lint (AC-d3) |
| AC-flare | FlareCore's 63 document commands (through `CommandRegistry.builtIn` and `CommandEngine`) and Flare's own actions are catalog commands, `FlareHeadless` works on Linux, the SVG-frames and key-and-save jobs pass, and its menus are built from specs. | AC-f1, AC-f2, AC-f3, AC-f4 | MJ-AC-flare | command-catalog:CC-run; CC-u and CC-lint (AC-f4) |
| AC-halo | Every `HaloCommand` case is a catalog command whose availability is `unavailableHelp(for:)`, `HaloHeadless` works on Linux, the retitle and render-frame jobs pass, and its menus are built from specs. | AC-h1, AC-h2, AC-h3 | MJ-AC-halo | command-catalog:CC-run; CC-u and CC-lint (AC-h3) |
| AC-library | Library's menu actions move into Model methods and become catalog commands, `LibraryHeadless` imports, culls and exports on Linux, the import-rate-export and cull jobs pass, and its menus are built from specs. | AC-l1, AC-l2, AC-l3, AC-l4 | MJ-AC-library | command-catalog:CC-run; CC-u and CC-lint (AC-l4) |
| AC-z | `afterglow list-apps` and every app's `list-commands` match their goldens, every catalog passes the conformance suite in one walk, every real job is green, and the feature is built. | AC-z1, AC-z2 | MJ-AC-all | every slice above; command-catalog:CC-z (AC-z2) |

Each app slice is `"ui": true` because its last task changes
`Sources/<X>App/`; its render budget row is the app's existing menu and
toolbar budget, unchanged. The acceptance tests are the app's existing
Model tests and journeys (merged long before, so rule 13 holds by
construction), plus the conformance suite and the id ledger on the new
catalog, plus the real jobs (rule 14 plans on each new file). There is no
new screen (`"ui_slice": "none"`): behaviour-preserving, proven by the
existing journeys.

## Journey steps

Per slice, a Linux walk, then the app's existing journeys on the scoped
run after its last PR:
- `MJ-AC-photo`: `PhotoCommandCatalogTests` (conformance on the fixture, ledger,
  availability equals the old help for every toolbar item and menu
  action), `PhotoHeadlessTests` (open, save, reopen equal; export PNG), and
  `RealJobsTests` for `Tests/RealJobs/photo/`; then
  `PhotoEditJourneyTests.testCopyPasteAsNewLayer` unchanged.
- `MJ-AC-design`: the same three for Design; then
  `DesignArrangeJourneyTests.testGroupAndUngroup`.
- `MJ-AC-flare`: the same three for Flare, the conformance run covering
  all 63 FlareCore ids; then `FlareMenuJourneys.testEveryMenuOpens`.
- `MJ-AC-halo`: the same three for Halo; then
  `HaloJourneyTests.testEveryMenuOpens` and
  `HaloHistoryJourneyTests.testUndoRedoEveryEdit`.
- `MJ-AC-library`: the same three for Library; then
  `LibraryJourneyTests.testEveryMenuOpens` and `.testRateASelectedPhoto`.
- `MJ-AC-all` (AC-z1): `AllAppsCatalogTests`.

## The real jobs each slice adds

`Tests/RealJobs/<app>/<job>/job.jobs.json` with `input/` and `expected/`,
in the format `afterglow-cli.md` defines. Fixtures are made by our own
tests or drawn by us, never downloaded. A job that needs a command the app
doesn't have yet is not faked: the slice files a `gap` issue on the app's
line and the job carries `"pending": "#<gap>"`, which the harness reports
as skipped with that issue, never as passed.

| app | job | what it proves | expectation |
|---|---|---|---|
| photo | `batch-resize` | three PNGs to a 1080 long side (`image.resize`), PNG out | pixels, tolerance 2 |
| photo | `watermark` | place `logo.png` bottom-right with a 24 px inset, opacity 0.6, flatten, PNG out | pixels, tolerance 2 |
| design | `export-frames-svg` | open a two-frame `.design`, export every frame as SVG | sha256 |
| design | `align-and-save` | select all, align left, distribute vertically, save | json equal |
| flare | `export-svg-frames` | open a 12-frame `.flare`, export frames 0, 6, 11 as SVG | sha256 |
| flare | `key-and-save` | `layer.add`, `keyframe.set` at 0 and 12, save | json equal |
| halo | `retitle-and-save` | set a text layer's text, save | json equal |
| halo | `render-frame` | render frame 12 of a shapes-only composition to PNG | pixels, tolerance 2 |
| library | `import-rate-export` | import four PNGs, rate two 5 stars and pick them, export picks at a 1024 long side | pixels, tolerance 2 |
| library | `cull-and-save` | rate, flag and label, save the catalog | json equal |

## Screens and states

None new. Each app's existing menu snapshots must be unchanged (title,
enabled state, help text), which `<X>CommandCatalogTests.menusUnchanged` checks
against a golden of today's menu table taken by the slice's first task.

## Contract slice

Nothing new: command-catalog's `CommandSpec`, `CommandCatalog`,
`HeadlessDocument`, `CatalogConformance`, `CommandIDLedger` and
`MenuCommand(spec:on:)`. Each slice adds, in its own Model:

```swift
// Sources/<X>Model/<X>CommandCatalog.swift: the app's commands, one spec per existing action
extension <X>Workspace {   // Photo, Design, Flare: <X>Workspace; Halo: HaloProject; Library: LibraryCatalog
    public static let commands: [CommandSpec<<X>Workspace>]   // availability = the existing help; run = the existing method
}
// Sources/<X>Model/<X>Headless.swift (CC-2's stub, filled): the workspace with headless live services
public struct <X>Headless: HeadlessDocument { public var workspace: <X>Workspace /* ... */ }
// Sources/PhotoModel/CoreRasterImageCodec.swift (AC-p2): PhotoImageCodec over creative-core's PNG/JPEG codecs
```

Ids follow the menu: `<menu>.<action>` in lowercase (`image.resize`,
`layer.duplicate`, `edit.undo`, `view.zoom-in`, `file.export`). Flare's
FlareCore commands keep their own ids (`layer.add`, `keyframe.move`).
`Tests/command-ids/<app>.txt` records every id at the slice's first task.

## Pseudocode

```
spec for an existing action A with help h(A) and method m:
  CommandSpec.typed(id, title: the menu title, summary: the menu help's first sentence,
                    kind: edit if m records a history step, view if it moves view state,
                    query if it reads, file if it touches files,
                    params: P (the method's arguments as a Codable struct),
                    availability: { w in h(A)(w).map(.unavailable) ?? .available },
                    run: { w, p in try w.m(p...) })
Flare's FlareCore commands (AC-f1):
  for type in CommandRegistry.builtIn families: spec(id: type.id, title: label, schema: SchemaProbe(type)
    or its CommandSchemaProviding override, kind: .edit,
    availability: dry-run perform on a copy of the engine → .unavailable(error message) on throw,
    run: workspace.perform(decoded command))       // through CommandEngine; undo stays there
menus (each slice's last task): every MenuCommand/Button site in Sources/<X>App/ becomes
  MenuCommand(<X>Workspace.commands[id], on: model, perform: { model.run(id, …) }); the app's
  Tests/command-path-baseline/<app>.txt goes to empty; titles, shortcuts and help stay identical.
```

## Tasks

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| AC-p1 | – | **Photo catalog.** One spec per Photo menu, toolbar and palette action over `PhotoWorkspace` (availability from `PhotoToolbarItem`'s `unavailableHelp` and the menu reasons); the id ledger; `PhotoCommandCatalogTests` (conformance, ledger, availability equals the old help, the menu golden) | `Sources/PhotoModel/PhotoCommandCatalog.swift`, `Tests/PhotoModelTests/PhotoCommandCatalogTests.swift`, `Tests/command-ids/photo.txt`, `Tests/mutations/PhotoModel.PhotoCommandCatalog.json` | – | ~380, 4 |
| AC-p2 | – | **Photo headless.** `PhotoHeadless` (open PNG and JPEG and Photo's own file, save, export PNG and JPEG, summary) with `CoreRasterImageCodec`; the two real jobs | `Sources/PhotoModel/PhotoHeadless.swift`, `Sources/PhotoModel/CoreRasterImageCodec.swift`, `Tests/PhotoModelTests/PhotoHeadlessTests.swift`, `Tests/RealJobs/photo/`, `Tests/mutations/PhotoModel.PhotoHeadless.json` | AC-p1 | ~340, 5 |
| AC-p3 | – | **Photo menus.** Every `Sources/PhotoApp/PhotoCommands*.swift` item and toolbar button built from its spec; the baseline emptied; the menu golden and the existing journeys unchanged | `Sources/PhotoApp/PhotoCommands.swift`, `Sources/PhotoApp/PhotoCommands+File.swift`, `Sources/PhotoApp/PhotoCommands+Edit.swift`, `Sources/PhotoApp/PhotoCommands+Image.swift`, `Sources/PhotoApp/PhotoCommands+Layer.swift`, `Sources/PhotoApp/PhotoCommands+Select.swift`, `Sources/PhotoApp/PhotoCommands+View.swift`, `Tests/command-path-baseline/photo.txt` | AC-p1 | ~360, 8 |
| AC-d1 | – | **Design catalog.** Specs over `DesignWorkspace` for every `DesignCommand` (through `help(_:)` and `run`), tool, page and file action; ledger; `DesignCommandCatalogTests` | `Sources/DesignModel/DesignCommandCatalog.swift`, `Tests/DesignModelTests/DesignCommandCatalogTests.swift`, `Tests/command-ids/design.txt`, `Tests/mutations/DesignModel.DesignCommandCatalog.json` | – | ~340, 4 |
| AC-d2 | – | **Design headless.** `DesignHeadless` (open, save, export SVG; PNG through the raster path once a Linux PNG writer is in), the two real jobs | `Sources/DesignModel/DesignHeadless.swift`, `Tests/DesignModelTests/DesignHeadlessTests.swift`, `Tests/RealJobs/design/`, `Tests/mutations/DesignModel.DesignHeadless.json` | AC-d1 | ~260, 4 |
| AC-d3 | – | **Design menus.** `DesignCommands.swift`, `DesignEditMenu.swift`, `DesignObjectMenu.swift` built from specs; baseline emptied | `Sources/DesignApp/DesignCommands.swift`, `Sources/DesignApp/DesignEditMenu.swift`, `Sources/DesignApp/DesignObjectMenu.swift`, `Tests/command-path-baseline/design.txt` | AC-d1 | ~240, 4 |
| AC-f1 | – | **FlareCore commands.** One spec per `CommandRegistry.builtIn` id (63) over `FlareWorkspace`, schema from `SchemaProbe` with `CommandSchemaProviding` overrides for the enum-heavy params, availability by dry run on a copy, run through `CommandEngine`; `FlareCoreCommandCatalogTests` (all 63 conform) | `Sources/FlareModel/FlareDocumentCommands+Catalog.swift`, `Tests/FlareModelTests/FlareCoreCommandCatalogTests.swift`, `Tests/mutations/FlareModel.FlareDocumentCommands+Catalog.json` | – | ~360, 3 |
| AC-f2 | – | **Flare app actions.** Specs for `FlareEditAction` (through `editHelp`), tools, playback, scenes and file; the ledger for all Flare ids; `FlareCommandCatalogTests` | `Sources/FlareModel/FlareCommandCatalog.swift`, `Tests/FlareModelTests/FlareCommandCatalogTests.swift`, `Tests/command-ids/flare.txt`, `Tests/mutations/FlareModel.FlareCommandCatalog.json` | AC-f1 | ~320, 4 |
| AC-f3 | – | **Flare headless.** `FlareHeadless` (open, save, export SVG and Lottie on Linux; PNG frames macOS-only until a Linux rasterizer), the two real jobs | `Sources/FlareModel/FlareHeadless.swift`, `Tests/FlareModelTests/FlareHeadlessTests.swift`, `Tests/RealJobs/flare/`, `Tests/mutations/FlareModel.FlareHeadless.json` | AC-f2 | ~240, 4 |
| AC-f4 | – | **Flare menus.** `FlareCommands.swift` and `FlareStageContextMenu.swift` built from specs; baseline emptied | `Sources/FlareApp/FlareCommands.swift`, `Sources/FlareApp/FlareStageContextMenu.swift`, `Tests/command-path-baseline/flare.txt` | AC-f2 | ~300, 3 |
| AC-h1 | – | **Halo catalog.** One spec per `HaloCommand` case over `HaloProject`, availability = `unavailableHelp(for:)`, payload cases as typed params; ledger; `HaloCommandCatalogTests` | `Sources/HaloModel/HaloCommandCatalog.swift`, `Tests/HaloModelTests/HaloCommandCatalogTests.swift`, `Tests/command-ids/halo.txt`, `Tests/mutations/HaloModel.HaloCommandCatalog.json` | – | ~360, 4 |
| AC-h2 | – | **Halo headless.** `HaloHeadless` (open, save, render a frame to PNG; movies stay macOS through shell-media), the two real jobs | `Sources/HaloModel/HaloHeadless.swift`, `Tests/HaloModelTests/HaloHeadlessTests.swift`, `Tests/RealJobs/halo/`, `Tests/mutations/HaloModel.HaloHeadless.json` | AC-h1 | ~240, 4 |
| AC-h3 | – | **Halo menus.** `HaloCommands.swift`, `HaloCompositionCommands.swift`, `HaloEditMenu.swift`, `HaloFileMenu.swift`, `HaloAnimationMenu.swift` built from specs; baseline emptied | `Sources/HaloApp/HaloCommands.swift`, `Sources/HaloApp/HaloCompositionCommands.swift`, `Sources/HaloApp/HaloEditMenu.swift`, `Sources/HaloApp/HaloFileMenu.swift`, `Sources/HaloApp/HaloAnimationMenu.swift`, `Tests/command-path-baseline/halo.txt` | AC-h1 | ~320, 6 |
| AC-l1 | – | **Library actions into the Model.** Each `LibraryMenu` closure that changes state becomes a `LibraryCatalog` method with its reason (the view keeps calling, now the method); `LibraryActionTests` | `Sources/LibraryModel/LibraryActions.swift`, `Tests/LibraryModelTests/LibraryActionTests.swift`, `Tests/mutations/LibraryModel.LibraryActions.json` | – | ~340, 3 |
| AC-l2 | – | **Library catalog.** Specs over `LibraryCatalog` for import, rate, flag, label, select, develop copy and paste, crop, export; ledger; `LibraryCommandCatalogTests` | `Sources/LibraryModel/LibraryCommandCatalog.swift`, `Tests/LibraryModelTests/LibraryCommandCatalogTests.swift`, `Tests/command-ids/library.txt`, `Tests/mutations/LibraryModel.LibraryCommandCatalog.json` | AC-l1 | ~320, 4 |
| AC-l3 | – | **Library headless.** `LibraryHeadless` (a catalog file plus a folder of images; import, save, export picks through the CoreRaster codec), the two real jobs | `Sources/LibraryModel/LibraryHeadless.swift`, `Tests/LibraryModelTests/LibraryHeadlessTests.swift`, `Tests/RealJobs/library/`, `Tests/mutations/LibraryModel.LibraryHeadless.json` | AC-l2 | ~300, 4 |
| AC-l4 | – | **Library menus.** `LibraryMenus.swift` and `LibraryCommands.swift` built from specs; baseline emptied | `Sources/LibraryApp/LibraryMenus.swift`, `Sources/LibraryApp/LibraryCommands.swift`, `Tests/command-path-baseline/library.txt` | AC-l2 | ~320, 3 |
| AC-z1 | – | `AllAppsCatalogTests`: `list-apps` and each app's `list-commands` against goldens, every catalog through `CatalogConformance` on its fixture, every `Tests/RealJobs/<app>/` green or pending with a gap | `Tests/AfterGlowCLITests/AllAppsCatalogTests.swift`, `Tests/AfterGlowCLITests/Golden/apps/` | AC-p2, AC-d2, AC-f3, AC-h2, AC-l3 | ~200, 2 |
| AC-z2 | – | Shared prose: suiteui.md (each app's menus come from its catalog), `status: built`; `feature-done` | `docs/blueprints/suiteui.md`, `docs/blueprints/suiteui/features/adopt-command-catalog.wave.json` | AC-z1, AC-p3, AC-d3, AC-f4, AC-h3, AC-l4 | ~80, 2; `feature-done` |

Inside an app, the headless and menu tasks both need the catalog, so they
wait on it and run side by side (they own different files). No two apps
share a file. Flare splits its catalog in two (FlareCore's 63 commands and
the app's own) because one file would pass 400 lines.

## Build waves

- Wave 1: AC-p1, AC-d1, AC-f1, AC-h1, AC-l1. Independent in this wave: all five.
- Wave 2: AC-p2, AC-p3, AC-d2, AC-d3, AC-f2, AC-h2, AC-h3, AC-l2. Independent in this wave: all eight.
- Wave 3: AC-f3, AC-f4, AC-l3, AC-l4. Independent in this wave: all four.
- Wave 4: AC-z1. Independent in this wave: AC-z1 alone.
- Wave 5: AC-z2 (shared prose, `feature-done`, final). Independent in this wave: AC-z2 alone.

Longest chain: AC-f1 → AC-f2 → AC-f3 → AC-z1 → AC-z2 (5); AC-l1 → AC-l2 →
AC-l3 → AC-z1 → AC-z2 is as long. Chain of 5: each step adds what the next
registers, serves or walks, and AC-z2 is the final prose task.

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| AC-p1 | `PhotoCommandCatalogTests`: conformance on the Photo fixture; ledger; for every action, `availability` equals the old help on six fixture states (no document, empty, one layer, locked layer, selection, mid-drag); the menu golden | a reason changes, an edit records no step, or an id is missing | availability from the wrong help (a toolbar item's for a menu action) → `.availabilityMatchesHelp`; `kind` `.view` for an edit → `.editsRecordOneStep` |
| AC-p2 | `PhotoHeadlessTests`: open, save, reopen equal; export PNG decodes to the same pixels; the two jobs green (pixels tolerance 2) | a round trip loses a layer, or a job differs | the codec drops alpha premultiplication → `.pngRoundTripExact`; export ignores the size option → `RealJobsTests` photo/batch-resize |
| AC-p3 | the menu golden and `PhotoEditJourneyTests.testCopyPasteAsNewLayer` unchanged; `CommandPathTests` with an empty Photo baseline | a menu item changes title, shortcut, enabled state or help | – (view wiring; the golden is the oracle) |
| AC-d1 | `DesignCommandCatalogTests` as AC-p1, for Design's states | as AC-p1 | `help(_:)` bypassed for a one-layer command → `.oneLayerHelpKept`; nudge's large flag dropped from params → `.nudgeLarge` |
| AC-d2 | `DesignHeadlessTests`; the two jobs green | as AC-p2 | SVG export of the selected page only → `export-frames-svg` job |
| AC-d3 | menu golden; `DesignArrangeJourneyTests.testGroupAndUngroup` unchanged; empty baseline | as AC-p3 | – |
| AC-f1 | `FlareCoreCommandCatalogTests`: every one of the 63 ids has a spec whose example decodes through `CommandRegistry.builtIn` and runs; undo through `CommandEngine` restores the saved bytes; a locked layer's command is unavailable with the engine's message | an id is missing or its schema rejects its own example | dry run skipped (availability always available) → `.lockedLayerUnavailable`; the probe's schema used where an override exists → `.overrideWins` |
| AC-f2 | `FlareCommandCatalogTests` as AC-p1 | as AC-p1 | `editHelp` read without the pasteboard for paste → `.pasteHelpReadsPasteboard` |
| AC-f3 | `FlareHeadlessTests`; the two jobs green | as AC-p2 | frames exported off by one → `export-svg-frames` job |
| AC-f4 | menu golden; `FlareMenuJourneys.testEveryMenuOpens` unchanged; empty baseline | as AC-p3 | – |
| AC-h1 | `HaloCommandCatalogTests`: one spec per `HaloCommand.allCases` entry; availability equals `unavailableHelp(for:)` on the `keyed` fixture states; conformance | a case is missing or its availability differs | one area's help mapped to another's → `.areaHelpMatches`; scrub run recorded as an edit → `.scrubIsView` |
| AC-h2 | `HaloHeadlessTests`; the two jobs green | as AC-p2 | render ignores the frame number → `render-frame` job |
| AC-h3 | menu golden; `HaloJourneyTests.testEveryMenuOpens` and `HaloHistoryJourneyTests.testUndoRedoEveryEdit` unchanged; empty baseline | as AC-p3 | – |
| AC-l1 | `LibraryActionTests`: each moved action does what its closure did on the sample catalog, and refuses with the same reason | a moved action changes behaviour | rating clamps 0...4 instead of 0...5 → `.ratingRange`; refusal on sample data skips the import hint → `.sampleRefusalHint` |
| AC-l2 | `LibraryCommandCatalogTests` as AC-p1 | as AC-p1 | flag toggles instead of sets → `.flagSets` |
| AC-l3 | `LibraryHeadlessTests`; the two jobs green | as AC-p2 | export of every photo, not picks → `import-rate-export` job |
| AC-l4 | menu golden; `LibraryJourneyTests.testEveryMenuOpens` and `.testRateASelectedPhoto` unchanged; empty baseline | as AC-p3 | – |
| AC-z1 | `AllAppsCatalogTests` (MJ-AC-all) | any app's catalog, golden or job breaks | – (integration) |
| AC-z2 | `scripts/waves check` | the data don't check | – (prose) |

## Quality tests

| quality row | budget | test |
|---|---|---|
| render: each app's menus | unchanged: the app's existing `RenderBudget<X>Tests` rows hold (a menu command run adds no window body beyond the change it makes) | `RenderBudgetPhotoTests`, `RenderBudgetDesignTests`, `RenderBudgetFlareTests`, `RenderBudgetHaloTests`, `RenderBudgetLibraryTests` (existing) |
| availability cost | each app's `availability` for every command on its fixture ≤ 2 ms total (menus read it on every open) | `<X>CommandCatalogTests.availabilityWithinBudget` (reported) |
| no dead controls | every menu item enabled or with a why-not, as before | the menu goldens |
| one path | `CommandPathTests` baselines empty for all five apps | `CommandPathTests` |
| Linux headless | every real job tagged `linux` runs in the Linux job | `RealJobsTests` |

## Done check

Per slice: its tasks merged, the newest dev CI run containing its last PR
green on `Linux` (the Model tests, the conformance suite and the real
jobs), then the app's existing journeys green on its scoped run, the feel
gate (menus unchanged) and the `Mac-Finish:` line. Then the contact sheet:
the five `list-commands` outputs and the real-jobs table.
