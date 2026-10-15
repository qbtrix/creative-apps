# Feature packet: home

**Feature:** the AfterGlow home window. A person launches AfterGlow and sees
yesterday's work from every app in one grid, newest first, with a
thumbnail; searches and filters it by app; starts something new from five
tiles; sees which apps are running; and gets a plain sentence, never an
alert, when a file has moved.
**Line:** `line:suite` · **Wave:** 2 (`waves.md`) · **Lead branch:** `lead/home`
**Blueprint:** `docs/blueprints/suite.md` sections 4.1, 4.2 (SJ0, SJ1),
4.3 (SJ19), 4.4 (SP3, SP4), 5.1 (UC-3, UC-16), 5.7 (`HomeModel`), 6.1
(Home), 6.2 (launcher File, Edit, View), 7.1 (QB-S3, QB-S4, QB-SM2), 7.3,
7.4 (QB-SV7), 8.2 (F3).

**Covers:** #841, #842, #843, #844, #845, #846,
#870, #847, #848, and the app-line fixture issues it files:
#837, #836, #838, #839, #840. The suite
tasks close through their PRs; the five app-line issues close through their
own lines' PRs (CLAUDE.md: a line never edits another line's targets).
**Follow-up, outside the done check:** #849 (HM-3c, the perf journeys), which
waits on #782; it is filed now and merges whenever #782 lands, like
bundle's BU-6.

**Depends on:** suite-contracts and bundle (wave 1; their feature issues are
named in `waves.md`), and #778 (SuiteUI suite-harness: #331–#333 goldens,
snapshot host and journey template; #330 `FrameProbe`; #775 `suite.controls`
through `.suiteControl` and `.suiteProbes`). HM-3c also waits on #782
(named probe marks: `recents-ready`). HM-3a waits on Design's fixture
issue, A-DE-0.

**SuiteUI it uses before it exists** (placeholders until they merge,
CLAUDE.md): #803 `AppTile`, #804 `ThumbnailBadges` app symbol and Missing
(after #779 S-L2, same file), #805 `SidebarRow` trailing accessory (after
the lists-and-layers `SidebarRow` chain), #780 `InlineNotice`. None blocks
the feature: each placeholder is a plain SwiftUI view in a `Home*.swift`
file, and the swap is a one-file follow-up the SuiteUI PR's author or the
next home round makes.

**What changed from the blueprint (review of #792 and this packet's critic).**

- **No `UITests/Journey+Suite.swift`.** It matches SuiteUI's
  `UITests/Journey*.swift` template glob, so it would compile into all five
  app journey bundles, which can't see `SuiteApp`. The harness is
  `UITests/AfterGlowJourneyTests+Harness.swift`, compiled only into
  `AfterGlowJourneyTests` (bundle's BU-3 glob). The budget file is
  `UITests/AfterGlowJourneyTests+BudgetsHome.swift` for the same reason.
- **SJ1 steps 3 and 4 are switching's** (`testOpenRecentBringsAppForward`).
  Until switching's SW-3b swaps the hand-off slot, opening a card is refused
  with "Not connected yet (switching).", so no hand-off file exists for a
  home journey to assert. The home ships steps 1, 2, 5 and 6 and asserts
  nothing about step 3.
- **`HomeModel` reads `SuitePreferences.homeOrder`** (review: SJ18 needs
  it and `HomeModel` had no reader). Until settings swaps the preferences
  slot, `load()` throws not-connected and the home keeps the default order
  without a message.
- **Hand-off ids come from `makeID`** (default `HandOff.newID()`), not
  `"open-<fileID>"` or a one-second clock (review).
- **No `docs/design.md` edit.** The blueprint's HM-4 wrote the "AfterGlow"
  section; the supervisor folds blueprint 6.4 in instead. HM-4's `needs-ui`
  issues are filed (#803, #804, #805).
- **The launcher's controls register through SuiteUI's `.suiteControl` and
  the window applies `.suiteProbes()` once** (#775: one publisher only), so
  SJ0 and SJ19 read `suite.controls`. The wait is #775/#778, not #782.
- **The services wiring has an owner.** `LauncherRouter+Services.swift`
  builds `SuiteServices.live(support:)`, seeds a `-SuiteFixture` with
  `FixtureSeeder` before the first frame, and supplies the updater through
  `with(updates: UpdateService.checker())`; `UpdateService.swift` is a stub
  returning nil that the updater (UP-2, wave 4) fills.
- The app fixture issues (A-x-0, A-LI-0) are filed here, not by switching:
  the home's journeys are the first to read the fixture documents.

## Journey steps

SJ0 `testLaunchShowsHomeAndEveryMenu` (`AfterGlowJourneyTests.swift`) on
`weekOfWork`:

1. Launch. The home is frontmost: sidebar (Home, Assets, APPS with five
   rows), the New row (five tiles), RECENT with 8 cards newest first, the
   running-apps strip empty ("No apps running"). `Logo.design` and
   `Cards.design` are not marked Missing.
2. `openEachMenu()`: AfterGlow, File, Edit, View, Window, Help each hold the
   section 6.2 items (system items such as Services not counted).
3. Read `suite.controls`; click each enabled `afterglow.*` control, then
   Escape: each changed the shot or a value; each disabled one has a reason.

SJ1 `testHomeFindsAndOpensRecentWork` (`+Home`) on `weekOfWork`, `missing`,
`empty`:

1. Type "logo" in search → 2 cards (`Logo.design`, `Logo animated.flare`).
2. Click the Design chip → 1 card.
3. (switching ships it)
4. (switching ships it)
5. Relaunch on `missing`: `Cards.design` shows "Missing"; Return on it → in
   place "Cards.design was moved or deleted." with Locate… and Remove from
   Recents; Remove → 7 cards; Edit > Undo → 8.
6. Relaunch on `empty`: "No recent work yet. Start something new above, or
   open a file." with Open… as the one prominent button.

`testHomeAtEveryWidth` (`+Layout`): the home at 880 and 1000 pt; the
audit's `offscreen` and `overlap` stay 0. SJ19 `testEveryControlActsOrSaysWhy`
(`+EveryControl`): the `suite.controls` sweep over the home, the Assets
placeholder and the Settings placeholder. SP3, SP4 (`+PerfHome`).

## Screens and states

| Screen | Empty | Error | Loading |
|---|---|---|---|
| Recents grid | `FakeHome`'s sentence with Open… prominent (`EmptyStateView`); "Nothing matches “<query>”." when a search or filter hides everything | a missing file: the card's Missing badge and, on open, the sentence in place (`InlineNotice` #780, placeholder until then) with Locate… and Remove from Recents; a store read failure: `SuiteError.message` in the same place | a card whose thumbnail hasn't loaded shows its app's symbol on the `panel` fill (`afterglow-home-loading`) |
| New row | – | a missing app's tile disabled with "<App> is missing from AfterGlow. Reinstall AfterGlow to get it back." (`-SuiteHideApp`); until switching lands every tile is disabled with "Not connected yet (switching)." (`HomeModel` reads `services.pending["sending"]`; `SuiteCreating` itself has no reason) | a tile shows a progress ring 100 ms after its click (`AppTile` #803; switching's SW-4a times it) |
| Running strip | "No apps running" in `textSecondary` | – | while `launching` is set for more than 100 ms, a `ProgressRow` (#781; a plain `ProgressView` placeholder until it merges) reads "Opening <App>…" (probe mark `switch-cold`, timed by switching's SW-4c) |
| Inspector | no selection: "Select a recent item to see its details." | – | – |

Snapshots (`AfterGlowHomeSnapshots`, Light, Dark and both with Increase
Contrast): `afterglow-home-week`, `afterglow-home-empty`,
`afterglow-home-missing`, `afterglow-home-loading`, `afterglow-home-search`;
`AfterGlowHomeLayoutTests`: `afterglow-home-880`, `-1000`, `-1280`, `-1728`.

## Contract slice

From suite-contracts: `HomeBuilding`, `DocumentCreating`, `RecentWork`,
`AppSwitching`, `HandOffSending`, `PreferencesStoring`, `HomeState`,
`NewTile`, `RecentCard`, `HomeLayout`, `SuiteServices`. This feature adds:

```swift
public struct HomeBuilder: HomeBuilding {                 // HM-1a, the live one: FakeHome's rule,
    public init(creating: any DocumentCreating, locale: Locale, calendar: Calendar)   // ages by the locale
}
public struct SuiteCreating: DocumentCreating { public init() }   // HM-1b: FakeCreating's tiles and presets, moved
@MainActor @Observable public final class HomeModel {             // HM-1b: blueprint 5.7, plus:
    public init(services: SuiteServices, fileExists: @escaping @Sendable (String) -> Bool,
                makeID: @escaping @Sendable () -> String = HandOff.newID)
    public private(set) var thumbnailStep: Int                    // 0...3, View > Larger/Smaller
    public private(set) var launching: SuiteApp?                  // set while a switch, open or new waits on its app;
                                                                  // cleared by the receipt or an error (QB-L9)
    public func undoRemove(now: Date) async                       // Edit > Undo after Remove from Recents
    public func larger(); public func smaller()
    // reload also reads preferences.homeOrder; a not-connected preferences slot keeps SuiteApp.apps silently
}
public struct HomeMenu: Equatable, Sendable {                     // HM-2c: what the launcher's File, Edit and View menus show
    public static func make(recents: RecentsList, selection: String?, thumbnailStep: Int,
                            page: HomePage, hasWindow: Bool) -> HomeMenu   // items, enabled, reasons; Open Recent = 20 newest
}
public enum HomePage: Sendable { case home, assets }              // HM-2c: Delete routes by page
// HomeBuilder.swift imports Foundation (with FoundationInternationalization on Linux) for locale weekday
// names, not only FoundationEssentials: `#if canImport(FoundationInternationalization)`.
```

## Pseudocode

```
HomeBuilder.home(recents, running, query, filter, order, missingApps, missingFiles, now):   # HM-1a
  as FakeHome, except age(date): same day "Today"; previous day "Yesterday";
    within 6 days: weekday name (locale); else the date, medium style (locale)

HomeModel.reload(now):                                                                     # HM-1b
  recents = try services.recents.list()                (error -> message)
  order   = (try? services.preferences.load().homeOrder) ?? SuiteApp.apps
  running, missingApps from services.switching.runState(of:) for each app
  missingFiles = recents whose path fileExists is false
  rebuild
removeSelection: remember (item) as lastRemoved; recents.remove; rebuild
undoRemove: if lastRemoved: services.recents.note(lastRemoved.ref, .opened, lastRemoved.lastUsed, its thumbnail)
openSelection: missing -> message .fileMissing ; else send HandOff(id: makeID(), .launcher -> item.app, .open, [item.ref])
newDocument(preset): send services.creating.handOff(for: preset, id: makeID(), at: now)

LauncherServices.shared (LauncherRouter+Services.swift):                                   # HM-2a
  support = SuiteLocations.supportFolder(arguments, home)
  if -SuiteFixture name: FixtureSeeder.seed(name, FileStore(support), -SuiteFixtureDocuments, support/Documents, now)
  return SuiteServices.live(support: support).with(updates: UpdateService.checker())

HomeWindow:  reads LauncherServices.shared via a HomeModel in @State; .task { reload; observe }
  sidebar: Home | Assets | APPS rows (click: model.filter(app); double-click: model.switchTo(app))
  toolbar: Open… ; .searchable -> model.search ; inspector toggle ; "Preview data" pill when services.isPreview
  content: New row (HomeLayout.tileWidth, tileShowsChips) ; RECENT header + ChipRow + ThumbnailGrid
  every control: .suiteControl(id: "afterglow.home.<name>", enabled:, reason:) ; the window: .suiteProbes() once
```

## Tasks

Every task is one PR to `dev`: at most 400 changed lines and 15 files, label
`fast-lane`, body lines `Belt-Lead:`, `Feature: home`, `Fast-Check: pass`,
`Head:`. HM-3b, the last PR of the feature, carries `feature-done`; HM-3c is
a follow-up outside the done check. UI PRs list their snapshot PNGs.

| id | issue | what | owned files | depends on |
|---|---|---|---|---|
| HM-1a | #842 | `HomeBuilder` (locale ages) and the live home slot; QB-SM2 | `Sources/SuiteModel/Home/HomeBuilder.swift`, `Sources/SuiteShell/Live/HomeSlot.swift`, `Tests/SuiteModelTests/HomeBuilderTests.swift`, `Tests/SuiteModelTests/Budget+Home.swift` | SC-3a #826, SC-4b #830, SC-5b #833 |
| HM-1b | #843 | `HomeModel` (5.7 plus `makeID`, `homeOrder`, undo of Remove, thumbnail steps, `launching`) and `SuiteCreating` with the live creating slot | `Sources/SuiteModel/Home/HomeModel.swift`, `Sources/SuiteModel/Home/SuiteCreating.swift`, `Sources/SuiteShell/Live/CreatingSlot.swift`, `Tests/SuiteModelTests/HomeModelTests.swift` | SC-3a #826, SC-4b #830, SC-5b #833 |
| HM-0 | #841 | The AfterGlow journey harness: `Journey(bundlePath:bundleID:auditKey:)`, `attach(_:)` by bundle id with per-process audit keys, the suite launch flags, `tearDown` ends every suite process; a smoke test; the `afterglow` audit key at 0 | `UITests/AfterGlowJourneyTests+Harness.swift`, `UITests/AfterGlowJourneyTests+Smoke.swift`, `UITests/audit-baseline.json` | BU-3 #814, BU-4 #818, #333 |
| HM-2a | #844 | The home window: sidebar, toolbar, search, chips, recents grid, empty and missing states, running strip; services wiring and fixture seeding; the updater stub; probes and control registration; the window publishes its `HomeModel` with `.focusedSceneValue(\.homeModel, model)` (the key is declared in `HomeWindow.swift`) so the launcher's menus reach it; home snapshots | `Sources/AfterGlowApp/HomeWindow.swift`, `HomeSidebar.swift`, `HomeGrid.swift`, `HomeRunningStrip.swift`, `LauncherRouter+Services.swift`, `UpdateService.swift` (all under `Sources/AfterGlowApp/`), `Tests/AppSnapshotTests/AfterGlowHomeSnapshots.swift` | HM-1b, SC-4c #831, #775 |
| HM-2b | #845 | The New row (tiles, presets as chips or a menu by `tileShowsChips`, disabled reasons, progress hook), the inspector (Open, Open In ▸ disabled until recents-open-in, Show in Finder, Remove from Recents), the file drop target; the layout snapshot test | `Sources/AfterGlowApp/HomeNewRow.swift`, `HomeInspector.swift`, `HomeDropTarget.swift`, `Tests/AppSnapshotTests/AfterGlowHomeLayoutTests.swift` | HM-2a |
| HM-2c | #846 | The launcher's File (New ▸, Open…, Open Recent ▸ with Clear Menu), Edit (Undo, Delete routing by page: Remove from Recents) and View (Show Sidebar, Show Inspector ⌥⌘I, Larger ⌘+, Smaller ⌘−) menus over `HomeMenu`; `LauncherCommandsHome` reads the model through `@FocusedValue(\.homeModel)` (no window: every item disabled "Open the AfterGlow window first." except New and Open…, which open it) | `Sources/AfterGlowApp/LauncherCommands+Home.swift`, `Sources/SuiteModel/Home/HomeMenu.swift`, `Tests/SuiteModelTests/HomeMenuTests.swift`, `Tests/SuiteModelTests/LauncherMenuStubTests.swift` | HM-1b, HM-2a, BU-1b #811 |
| HM-4 | #870 | The home's golden baselines, reviewed from the dev run that contains HM-2a and HM-2b | `Tests/AppSnapshotTests/Golden/afterglow/` (SH-9's `Golden/<area>/` folder) | HM-2a, HM-2b and their dev CI run |
| HM-3a | #847 | Journeys SJ0 and SJ1 (steps 1, 2, 5, 6) | `UITests/AfterGlowJourneyTests.swift`, `UITests/AfterGlowJourneyTests+Home.swift` | HM-0, HM-2b, HM-2c, A-DE-0 #836 |
| HM-3b | #848 | `testHomeAtEveryWidth` and SJ19 | `UITests/AfterGlowJourneyTests+Layout.swift`, `UITests/AfterGlowJourneyTests+EveryControl.swift` | HM-3a, HM-4 |
| HM-3c | #849 | SP3, SP4 and the home's budget constants (report only); the `recents-ready` mark in the grid | `UITests/AfterGlowJourneyTests+PerfHome.swift`, `UITests/AfterGlowJourneyTests+BudgetsHome.swift`, `Sources/AfterGlowApp/HomeGrid.swift` | HM-0, HM-2a, #782 |

App-line issues this feature files (`needs-suite`, built by their lines;
each names its files):

| id | issue | line | what | owned files | depends on |
|---|---|---|---|---|---|
| A-FL-0 | #837 | flare | Fixture export test: writes `Bounce.flare`, `Title.flare` and `Logo animated.flare` into `UITests/Fixtures/suite/` (and a 512 px thumbnail of each where the Model can already render one, into `UITests/Fixtures/suite/thumbnails/`), and fails when they drift | `Tests/FlareModelTests/SuiteFixtureExportTests.swift`, `UITests/Fixtures/suite/{Bounce,Title,Logo animated}.flare`, `UITests/Fixtures/suite/thumbnails/<those names>.png` | – |
| A-DE-0 | #836 | design | Same for `Logo.design` (Design `cards`, one page renamed) and `Cards.design` | `Tests/DesignModelTests/SuiteFixtureExportTests.swift`, `UITests/Fixtures/suite/{Logo,Cards}.design`, their thumbnails | – |
| A-PH-0 | #838 | photo | Same for `beach.ora` (two layers) and `Sunset.png` (1600 × 1067). `large.png` (6000 × 4000, SP5) is clipboard-drag's, wave 3 | `Tests/PhotoModelTests/SuiteFixtureExportTests.swift`, `UITests/Fixtures/suite/{beach.ora,Sunset.png}`, their thumbnails | Photo PV-1 (`.ora` save) for `beach.ora`; `Sunset.png` at once |
| A-HA-0 | #839 | halo | Same for `Intro.halo` (a two-layer composition) | `Tests/HaloModelTests/SuiteFixtureExportTests.swift`, `UITests/Fixtures/suite/Intro.halo`, its thumbnail | #209 (Halo save and open) |
| A-LI-0 | #840 | library | `-LibrarySample <seed>` loads Library's 60 seeded sample photos (`LibrarySample.items(seed:)`) into the catalog at `-LibraryCatalogDir` (the `weekOfWork` and `roundTrip` catalogs; the blueprint's "3 photos" is corrected to Library's real sample) | `Sources/LibraryModel/LibraryLaunchOptions.swift`, `Tests/LibraryModelTests/LibraryLaunchOptionsTests.swift`, `Sources/LibraryApp/LibraryApp.swift` (one line: the catalog is built from the options) | – (A-LI-1 #864, which also edits `LibraryApp.swift`, comes after it) |

A thumbnail missing from `UITests/Fixtures/suite/thumbnails/` is not an
error: the card shows the loading state (its app's symbol). Each app's
real thumbnails arrive with recents-open-in's A-x-2 (QB-SV1).

The home's own journeys need only Design's documents (SJ1 step 5 tells a
present `Cards.design` from a missing one), so HM-3a waits on A-DE-0 alone.
The rest are filed here because the fixture documents are one set; their
first readers are switching's SW-4a (SJ3 opens `Bounce.flare`) and wave 3.

Order: HM-1a, HM-1b and HM-0 at once. HM-1b does not wait for HM-1a:
`HomeModel` reads the home through `HomeBuilding`, and its tests run on
`.fake`'s `FakeHome`; `HomeBuilder` takes any `DocumentCreating`, so HM-1a
does not wait for `SuiteCreating`. HM-2a after HM-1b (`HomeWindow` holds a
`HomeModel`); HM-2b after HM-2a (its views and layout test sit in
`HomeWindow`); HM-2c after HM-1b and HM-2a (the `\.homeModel` key);
HM-4 after the dev run that holds HM-2a and HM-2b; HM-3a after HM-0, the
views (SJ0 counts HM-2b's tiles), the menus (HM-2c: Edit > Undo) and
A-DE-0; HM-3c after HM-0 and HM-2a, whose `HomeGrid.swift` it edits.
HM-3b's own tests need only the harness and the views, but it carries
`feature-done`, so it waits on HM-3a and HM-4: its dev run must hold SJ0,
SJ1 and the goldens. Sizes: HM-1a ~250, HM-1b ~360, HM-0
~250, HM-2a ~380 (7 files), HM-2b ~350, HM-2c ~300, HM-3a ~300, HM-3b ~220,
HM-3c ~200.

**Files shared with other features, and why it's safe.**
`LauncherMenuStubTests.swift` (BU-1b's, wave 0) is edited by HM-2c only in
wave 2. `UITests/audit-baseline.json` gains one key at 0 in HM-0; CI's
Audit-lower job commits that file straight to `dev`, so HM-0 rebases right
before its last `scripts/ci`. `UpdateService.swift` and
`LauncherRouter+Services.swift` are created here; the updater owns
`UpdateService.swift` from wave 4. `HomeSlot.swift` and `CreatingSlot.swift`
come from suite-contracts (wave 1). Switching (wave 2) owns none of these.

## Build waves

No task edits a shared doc (`docs/c4/model.json`, `docs/design.md`, the
blueprint or `waves.md`); every new file sits in a folder its C4 component
already covers, so rule (a) adds no task. The app-line rows (A-x-0) are
built by their own lines and are not in these waves.

- Wave 1: HM-1a, HM-1b, HM-0. Independent in this wave: all three.
- Wave 2: HM-2a. Independent in this wave: HM-2a alone.
- Wave 3: HM-2b, HM-2c, HM-3c (follow-up, once #782 lands). Independent in this wave: all three.
- Wave 4: HM-4 (after the dev run that holds HM-2a and HM-2b), HM-3a. Independent in this wave: both.
- Wave 5: HM-3b (`feature-done`, final; it merges after every other task of the done check, HM-1a included). Independent in this wave: HM-3b alone.

Longest chain: HM-1b → HM-2a → HM-2b → HM-3a → HM-3b (5); HM-1b → HM-2a →
HM-2b → HM-4 → HM-3b is as long.
Chain of 5: `HomeWindow.swift` holds HM-1b's `HomeModel`; HM-2b's
`HomeNewRow` and `AfterGlowHomeLayoutTests` sit in HM-2a's `HomeWindow`;
SJ0 counts HM-2b's tiles and HM-4's goldens are shot from HM-2b's screens;
HM-3b carries `feature-done`, so its dev run must hold HM-3a's journeys and
HM-4's goldens.

## Acceptance test per task

| id | test | fails when |
|---|---|---|
| HM-1a | `HomeBuilderTests`: on `weekOfWork` the cards' items, order and `isMissing` equal `FakeHome`'s (ages differ on purpose); ages with `en_US` and a fixed calendar: now → "Today", −1 day → "Yesterday", −3 days → the weekday name, −10 days → the medium date; `de_DE` gives German weekday names; tiles keep `order` | an age ignores the locale, or order or filtering differs from the fake |
| HM-1b | `HomeModelTests` (on `.fake`): reload shows 8 cards; search "logo" 2; Design filter 1; a `homeOrder` of Library, Photo first orders the tiles so; a preferences slot that throws not-connected keeps the default order and sets no message; `openSelection` on a missing card sets the 5.4 sentence and sends nothing; on a present card sends one `.open` hand-off whose id comes from `makeID`; two opens of one card send two different ids; remove then `undoRemove` restores 8 with the same thumbnail; `locate` re-points the card; `larger()` stops at 3; `launching` is the target app while a send waits and nil after its receipt or error | any count, order, id rule or message differs |
| HM-0 | `AfterGlowSmokeJourneys.testLauncherLaunchesOnEmpty`: `.build/apps/AfterGlow.app` launches with the suite flags, the home window exists, `attach(.launcher)` shoots and audits under `afterglow`; `tearDown` leaves no suite process; the `afterglow` key is at 0 for all six checks | the harness can't launch, an app process survives, or a check is missing from the key |
| HM-2a | `AfterGlowHomeSnapshots` (macOS): the five home snapshots render in four appearances (with no baseline yet each fails with share 1 and writes its actual to `.build/snapshots/`, SH-9's rule, which is how HM-4 gets them); on `.fake` the "Preview data" pill shows, on a live store with no fixture it doesn't; tiles are disabled with "Not connected yet (switching)." while `pending` holds `sending` | the pill shows on live, or a tile is enabled while sending is pending |
| HM-4 | the next dev run compares `AfterGlowHomeSnapshots` and `AfterGlowHomeLayoutTests` against the committed baselines and passes; one changed pixel row in a baseline makes it fail | a golden differs from the reviewed screen |
| HM-2b | `AfterGlowHomeLayoutTests` (macOS, anchor preferences) at 880, 1000, 1280, 1728 on `weekOfWork`: tiles, the RECENT header and the grid share one left edge (±0.5 pt); no card or tile crosses the content's right edge; no two cards overlap; card origins on the 4 pt grid; sidebar 200 pt; tiles show chips only at 1280 and 1728 | any geometric rule breaks at any width |
| HM-2c | `HomeMenuTests` (Linux): with no selection Remove from Recents is disabled with "Select a recent item first."; Open Recent lists the 20 newest of `crowd` and Clear Menu empties it; Larger is disabled at step 3 with "Thumbnails are at their largest."; `LauncherMenuStubTests` now expects the home's items enabled through `HomeMenu` and every other feature's still disabled with its reason | an item acts with nothing to act on, or a stub loses its reason |
| HM-3a | SJ0 and SJ1 on the dev macOS run: the counts and sentences of the journey steps above; the audit at 0 under `afterglow` | a count, sentence or menu item differs, or the audit counts anything |
| HM-3b | `testHomeAtEveryWidth`: `offscreen` and `overlap` 0 at 880 and 1000; SJ19: every enabled `afterglow.*` control changes the shot or a value, every disabled one has a reason | a control is dead or a width overflows |
| HM-3c | SP3 and SP4 record at least 20 samples each into the run's perf JSON with p50 and p95; fewer samples fail the test as invalid | the probe marks are missing or too few |
| A-x-0 | each line's `SuiteFixtureExportTests`: the files exist, decode with the app's own reader, and equal what the test writes (rerun with `SUITE_FIXTURE_WRITE=1` to refresh); any thumbnail present is 512 px on its long side | a fixture drifts from the app's format, or a committed file no longer decodes |
| A-LI-0 | `LibraryLaunchOptionsTests`: `-LibrarySample 2026 -LibraryCatalogDir <tmp>` gives a catalog of the 60 seeded photos in `<tmp>`, the same 60 for the same seed, and never touches the default catalog | the runner's real catalog changes |

## Quality tests

| quality row | budget | test |
|---|---|---|
| QB-SM2 `HomeBuilding.home` over 200 recents with a query | ≤ 2 ms (debug ≤ 20 ms) | `Budget+Home.homeOver200` |
| QB-S3 cold launch → home first frame; first frame → `recents-ready` (200 recents) | ≤ 500 ms; ≤ 100 ms; report only | SP3 `testHomeFirstFrameAndRecents` |
| QB-S4 search keystroke → filtered grid drawn | p95 ≤ 2 frames late; placeholder gate 3 | SP4 `testRecentsSearchKeystrokes` |
| 7.3 layout | the table and the four geometric rules | `ValuesHomeLayoutTests` (Linux), `AfterGlowHomeLayoutTests`, `testHomeAtEveryWidth` |
| QB-SV7 goldens | home in four appearances | `AfterGlowHomeSnapshots` |
| 7.2 audit | `afterglow` at 0 for all six checks | every shot of SJ0, SJ1, SJ19 |

## Done check

- **Journeys green:** the dev macOS run triggered by HM-3b (`feature-done`)
  is green with SJ0, SJ1, `testHomeAtEveryWidth`, SJ19 and the home goldens
  passing. HM-3c (#849) follows as a normal lane PR once #782 lands; the
  contact sheet says the perf rows are pending.
- **Audit zero new:** the `afterglow` key stays at 0 for every check; no app
  key rises.
- **Contact sheet:** `Belt-Contact-Sheet: <run link>` on the feature issue,
  one line per journey, the home shots at 880 and 1000, and the snapshot
  PNG names above.
