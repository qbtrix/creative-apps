# Feature packet: onboarding

**Feature:** the first launch of `AfterGlow.app` opens one welcome window
over the home, once. Three pages: a short welcome that names the five apps
and explains the Rendering choice in one line; what you make most (the
focus that orders the home); a starter row with one tile per app, each
with its New presets and an "Open sample" that opens a sample document in
that app. Continue, Back and Skip are buttons in the window; closing the
window is Skip. Finishing or skipping records the version in the suite
preferences, so the window never comes back on its own; Help > Welcome to
AfterGlow reopens it any time. A journey or a person who wants no tour
passes `-SuiteSkipOnboarding YES`.
**Line:** `line:suite` · **Wave:** 4 (`waves.md`) · **Lead branch:** `lead/onboarding`
**Beta:** in the captain's beta cut (`paw-workspace/docs/design/drafts/2026-10-17-afterglow-beta-cut.md`,
Suite row: "onboarding (three pages, once)"; the Suite tier-1 chain starts
"onboarding once → home → open → switch"). Labels `beta` and `p0` when filed.
**Blueprint:** `docs/blueprints/suite.md` row 159 (Onboarding), 2.3
(suite-onboarding, suite-preferences, launcher-scene, onboarding), 4.1
(`firstLaunch`, `-SuiteSkipOnboarding`, `Bundle/Samples/`, identifiers
`afterglow.onboarding.<name>`), 4.2 SJ18, 5.2 UC-11 `PreferencesStoring` and
UC-13 `OnboardingFlowing`, 6.1 (Onboarding row), 6.2 (Help), 7.3 item 2
(OB-1 margins), 7.4 QB-SV7, 8.2 F10. Rendering wording:
`2026-10-17-dual-renderer.md` section 2, the beta cut ("CPU as Automatic")
and canvas-host's follow-up "View > Rendering in every suite process".

**Covers:** F10 (OB-1, OB-2 of blueprint 8.2), UC-13, SJ18, and the live
half of UC-11 (the preferences store) now that settings is out of the beta;
the `firstLaunch` fixture's reason to exist; the one place the Rendering
choice is said to a first-time user.

**Depends on:** targets (wave 0: `AfterGlowApp.swift`, `OnboardingWindow.swift`),
suite-contracts (built: `OnboardingFlowing`, `PreferencesStoring`,
`FakeOnboarding`, `FakePreferences`, `OnboardingPage`,
`SuitePreferences.onboardingDoneVersion`, the slots), bundle (BU-4 #1445's
`bundle-apps` copies `Bundle/Samples/` into `Contents/Resources/Samples`),
home (the harness HM-0 and `AfterGlowJourneyTests.swift` HM-3a, `HomeModel`
reading `homeOrder`, the `afterglow` audit key), switching (hand-off
transport to a cold app, Window > Switch To). Cross-line, in the Hand-offs
list: the fixture exports #836 (Design), #837 (Flare), #838 (Photo), #839
(Halo), which are the sample files; SuiteUI `needs-ui` for
`SuiteSize.onboardingWindow` (blueprint 6.3) and #803 `AppTile`. **No
settings wait:** settings is out of the beta (captain, 2026-10-17), so this
packet makes the preferences slot live itself (OB-9, see What changed).

**Rule 20 (canonical first), export:** onboarding exports nothing and
owns no export, undo, selection, layer, transform, easing or crop logic.
"Open sample" and "New" are hand-offs (`HandOff` with `.open` and `.new`,
sent through `HandOffSending`, the same path the home's cards and tiles
take); a sample that an app should export comes from that app's own export
on SuiteKernel's `ExportRun` and SuiteUI's `ExportSheet`
(`docs/blueprints/suiteui/features/editor-kernel.md` EK-run, EK-chrome;
`adopt-kernel-export.md`), never from here. No editor-kernel wait: this
packet calls no kernel module. The live preferences store is no new store
either: `StorePreferences` is `StoreRecents`' shape over `FileStore`
(revisioned JSON under the store's lock), the one suite store.

**Hand-offs** (files other packets own; checked by the lead before the
slice starts):
- **OB-11 samples:** `Bundle/Samples/` holds copies of the A-x-0 fixture
  exports #836–#839 (`Cards.design`, `Bounce.flare`, `beach.ora`,
  `Intro.halo`; Library's sample is Photo's `Sunset.png`, imported). A file
  whose export hasn't landed is left out, its test row skips with the issue
  number, and its tile's "Open sample" reads "The Flare sample isn't in this
  build." BU-4 (#1445) copies `Bundle/Samples/` into the bundle; if the
  merged `scripts/bundle-apps` doesn't, the lead files a `line:suite` bundle
  issue (supervisor-merged file) and OJ3 waits on it.
- **OB-6, OB-13 journeys:** home's harness (HM-0) passes
  `-SuiteSkipOnboarding YES` to every launch but this packet's; until it
  does, the other suite journeys never see the window anyway (every fixture
  but `firstLaunch` has `onboardingDoneVersion: 1`). The relaunch step
  reuses `-SuiteSupportDir`, which `Journey(bundlePath:bundleID:auditKey:)`
  takes as arguments.
- **`Tests/perf-suites.txt`** gains
  `suite AppSnapshotTests.BodyCountSuites/RenderBudgetAfterGlowOnboardingTests/timing`:
  supervisor-only, asked for in OB-5's PR body.
- **`needs-ui`:** `SuiteSize.onboardingWindow` (720 × 520, blueprint 6.3);
  until it merges the window's size and margins come from `OnboardingLayout`
  in SuiteModel (as `HomeLayout` holds the home's numbers), so the design
  lint sees no literal in app code. `AppTile` #803: the starter tile and the
  home's tile both move onto it when it lands.
- **Settings, after the beta:** its General pane's "Show Welcome Again" is
  `openWindow(id: "onboarding")`, the call Help > Welcome to AfterGlow makes;
  its panes read and write the `StorePreferences` OB-9 makes live. Nothing
  here is thrown away.

**What changed from the blueprint.**
- **Settings is out of the beta** (captain, 2026-10-17), so onboarding
  carries the one preference it needs itself, under rule 18 (contract
  widening): `onboardingDoneVersion` and `homeOrder` are read and saved
  through the existing `PreferencesStoring` contract, and OB-9 makes that
  contract live with `StorePreferences` over `FileStore`
  (`Sources/SuiteModel/Preferences/`, the C4 part `suite-preferences`
  already names the folder), flipping `preferencesIsLive`. The home's
  `HomeModel.reload` already reads `homeOrder` from `services.preferences`,
  so the focus orders the home the moment the slot is live.
- **The Rendering line.** The beta ships rendering as View > Rendering in
  every suite process (canvas-host's `RenderingCommands` follow-up), not a
  Settings pane, so page 1 says, in one line: "Rendering is Automatic, which
  draws on the CPU in this beta. View > Rendering in any app changes it."
- **The window opens itself.** `AfterGlowApp.swift` is frozen by BU-1a and
  pinned by `LauncherMenuStubTests.appDeclaresTheScenesAndCommandGroups`
  (scene strings and command groups each once). An AppKit delegate
  extension (`LauncherRouter+Onboarding.swift`, the C4 part's extension
  point) can't reach SwiftUI's `openWindow`, so first-launch presentation
  is the scene's own: OB-3 adds two modifiers to the onboarding `Window`
  (`.defaultLaunchBehavior(OnboardingWindow.launchBehavior)`,
  `.restorationBehavior(.disabled)`, macOS 15+ on a macOS 26 target) and one
  `.commands { LauncherCommandsOnboarding() }`. The pinned strings stay
  exactly once; `noItemEnabledWithoutAReason` reads only its `commandFiles`
  list, which the new file is not in (the Help item is live, not a disabled
  stub). The one reason: no other place can present a `Window` scene at
  launch without a home-window edit, which home still owns.
- **`launchBehavior` is decided before the first frame** by
  `OnboardingLaunch.presents(arguments:stored:flow:)`, pure and Linux-tested:
  false with `-SuiteSkipOnboarding YES` (blueprint 4.1; nothing read the
  flag before), else `flow.shouldShow(stored ?? SuitePreferences(), version:
  SuiteOnboarding.version)` over a synchronous
  `FileStore.read("preferences.json")` of `LauncherServices.support`.
- **Page 3 is the starter row,** not three sample buttons: one tile per app
  in focus order, its presets as `ChoiceChips` (a chip creates the document
  at once, as the home's tiles do) and "Open sample". "Start from an empty
  home" finishes with nothing opened. Page 1 carries the Rendering line.
  Most-used first: Flare, Design and Photo samples land first (OB-11 copies
  what has been exported; Halo's and Library's rows skip until theirs have).
- **The focus orders the starters too,** so the fakes track proves the
  ordering inside the window (OJ2) before the home's order is live (OJ3).
- **`OnboardingFlowing` is not widened.** `ContractShapeMoreTests`,
  `FakesSettingsTests`, `ValuesSettingsTests` and `SuiteLiveServicesTests`
  pin three pages and `choices == [[], allCases, []]`. The starters, the
  samples, the launch rule and the rendering line live in `OnboardingModel`
  and the `Onboarding/` types; `SuiteOnboarding` (live) keeps the fake's
  pages and focus → order rule by calling `FakeOnboarding`'s, and differs in
  `shouldShow` (`(done ?? 0) < version`, so a bumped version shows again).
- **Closing the window is Skip.** The HIG asks that onboarding be optional
  and never a trap: `OnboardingWindow.onDisappear` with no finish calls
  `model.skip()`, which records the version with no focus.

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| OB-a | `Sources/SuiteModel/Onboarding/` exists with every type and signature the window calls declared as stubs returning the fake's values, its Linux tests written and disabled. | OB-1, OB-2 | MJ-OB0 | – |
| OB-u (`ui`) | Help > Welcome to AfterGlow and the first launch open the window on the fakes: three pages, Continue, Back, Skip, focus chips, the starter row, every control identified and the render budget met. | OB-3, OB-4, OB-5, OB-6 | OJ1, OJ2 | OB-a (OB-3); home (OB-6: the harness and `AfterGlowJourneyTests`) |
| OB-m | `SuiteOnboarding`, `OnboardingLaunch` and `OnboardingModel` do the work (show once per version, honour the skip flag, step pages, order starters by focus, finish into saved preferences with one stale retry, send the New and Open hand-offs), and `StorePreferences` over `FileStore` makes the preferences slot live. | OB-7, OB-8, OB-9 | MJ-OB1, MJ-OB2, MJ-OB4 | OB-a (OB-7, OB-8, OB-9) |
| OB-s | `SampleCatalog` names one sample per app, finds it under the bundle's Resources, copies it into Documents without overwriting, and `Bundle/Samples/` holds the files. | OB-10, OB-11 | MJ-OB3 | OB-a (OB-10, OB-11); bundle (OB-11) |
| OB-z | The slot is live, the window reads the bundle's samples, and the journeys run on live: shown once across a relaunch, a sample opens its app, a preset opens a new document, the home follows the focus. | OB-12, OB-13 | OJ3, OJ4 | OB-u, OB-m, OB-s (OB-12); switching (OB-13) |

OB-u waits on no slice of this feature but OB-a (rule 18); OB-m and OB-s
never wait on OB-u. OB-6's `home` wait names the whole feature because a v2
packet exposes no slice ids; only HM-0 (the harness) and HM-3a (the class)
are needed, so the lead starts OB-6 once those two have merged. OB-z swaps
the fakes for live and runs OJ3 and OJ4.

## Journey steps

All clicks are mouse clicks on titled buttons or menu items (`Journey.click`,
menu bar items by title); keys appear only where a step checks parity.
Every shot is audited under `afterglow` (a sample's app under its own key).

OJ1 `testFirstLaunchShowsAndSkips` (`+Onboarding`, OB-6) on `firstLaunch`,
no skip flag:

1. Launch. The window "Welcome to AfterGlow" is frontmost over the home;
   `afterglow.onboarding.page` reads `apps`; the five app names and the
   Rendering line are on screen. Shot `onboarding-welcome`. (OB-3)
2. Click Skip. The window closes; the home is frontmost; `suite.controls`
   of the home unchanged. Shot `onboarding-skipped`. (OB-3)
3. Menu bar: Help > Welcome to AfterGlow. The window is back on page 1.
   Shot `onboarding-reopened`. (OB-3)
4. Click the window's close button. It closes; the home stays. (OB-3)

OJ2 `testFocusOrdersStarters` (`+Onboarding`, OB-6) on `firstLaunch`:

1. Launch; click Continue. Page `focus` shows five chips, none selected;
   Continue is enabled (focus is optional). Shot `onboarding-focus`. (OB-4)
2. Click "Photos". The chip is selected. Click Continue. (OB-4)
3. Page `start` shows five starter tiles, Library then Photo first, then
   Flare, Design, Halo; each with its preset chips; "Open sample" on every
   tile (on the fakes: enabled, the fake catalog says present). Shot
   `onboarding-start`. (OB-4)
4. Click Back. Page `focus`, "Photos" still selected. Click Continue. (OB-4)
5. Click "Start from an empty home". The window closes; the home is
   frontmost. Shot `onboarding-empty-home`. (OB-4)
6. Press Escape on a reopened window (Help > Welcome to AfterGlow): it
   closes (keyboard parity with Skip). Press Return on a reopened window:
   page 2 (parity with Continue). (OB-3)

OJ3 `testOpenSampleOpensFlareAndOrdersHome` (`+OnboardingStart`, OB-12
skipped, OB-13 live) on `firstLaunch`:

1. Launch; Continue; click "Photos"; Continue. (OB-12)
2. Click Flare's "Open sample". The window closes; Flare comes forward with
   a window titled "Bounce" (its copy at `<support>/Documents/Samples/Bounce.flare`).
   Shot `onboarding-sample-flare` under Flare's audit key. (OB-12)
3. Menu bar: Window > Switch To > Home. The home's New row reads Import
   Photos…, New Image, New Animation, New Design, New Composition in that
   order; RECENT shows `Bounce.flare`. Shot `onboarding-home-ordered`. (OB-9, OB-12)
4. Quit and relaunch with the same `-SuiteSupportDir`. No welcome window;
   the home is frontmost, still in that order. (OB-9, OB-12)

OJ4 `testNewDesignFromOnboarding` (`+OnboardingStart`, OB-12 skipped, OB-13
live) on `firstLaunch`:

1. Launch; Continue; Continue (no focus). (OB-12)
2. Click "Blank" under Design. The window closes; Design comes forward
   with an untitled design. Shot `onboarding-new-design` under Design's key.
   Relaunch: no welcome. (OB-12)

Model walks (Linux, `SuiteModelTests`): MJ-OB0 `OnboardingStubTests` (the
stubs return the fake's values and the signatures compile), MJ-OB1
`OnboardingLaunchTests` + `SuiteOnboardingTests`, MJ-OB2
`OnboardingModelTests` (the four-page walk on `.fake` services: show →
focus → starter → finished, preferences saved, one hand-off recorded), MJ-OB3
`SampleCatalogTests` + `SampleFilesTests`, MJ-OB4 `StorePreferencesTests`
(load, save, stale, changes, round trip through a second instance).

## Screens and states

| screen state | what shows | snapshot (`Golden/afterglow-onboarding/`) |
|---|---|---|
| Page 1, welcome | title "Five apps, one AfterGlow", the five symbols (`HomeSidebarRows.symbol`) with names in a row, the body, the Rendering line in `SuiteFont.caption` / `textSecondary`, Continue (prominent, default), Skip | `afterglow-onboarding-welcome-{light,dark,light-ic,dark-ic}` |
| Page 2, focus | "What do you make most?", `ChoiceChips` Animation, Design, Photos, Motion, Everything, none selected; Back, Continue, Skip | `-focus-*`, `-focus-selected-*` (Photos) |
| Page 3, start | "Start with a sample or a new document", five tiles in focus order, preset chips, "Open sample"; "Start from an empty home"; Back, Skip | `-start-*` (Photos order), `-start-default-*` (no focus) |
| Page 3, a sample missing | that tile's "Open sample" disabled, help "The Halo sample isn't in this build." | `-start-missing-*` |
| Finishing | after a chip or Open sample: the tile's progress ring (`launching`), controls disabled while the hand-off sends | `-start-launching-*` |
| Error in place | a hand-off refused: the sentence under the tile (`SuiteError.message`), nothing modal | `-start-error-*` |

Layout check (blueprint 7.3 item 2): Continue, Back and Skip sit inside the
window with 24 pt margins (`OnboardingLayout.margin`, equal to
`SuiteSpacing.xl`) at the default size; no tile crosses the content's right
edge at 720 pt and at `SuiteSize.windowLaunch` width.

## Contract slice

Declared by OB-1 as documented stubs (a stub returns the fake's value or a
constant; nothing throws `NotBuilt`: every call here has a fake value). The
logic slices fill the bodies and never change a signature.

```swift
// Sources/SuiteModel/Onboarding/OnboardingStarter.swift (OB-1)
/// One sample document the tour can open, shipped in Contents/Resources/Samples.
public struct SampleFile: Hashable, Sendable {
    public var app: SuiteApp
    public var fileName: String          // "Bounce.flare"
    public var type: SuiteTypeID
    public var title: String             // "Bounce", what the tile says
}
/// One tile of the start page: the app's New tile plus its sample.
public struct OnboardingStarter: Equatable, Sendable {
    public var tile: NewTile             // SuiteCreating's title and presets
    public var sample: SampleFile?
    public var sampleReason: String?     // nil when the sample can be opened
}
/// The window's numbers until SuiteSize.onboardingWindow lands (needs-ui): 720 × 520, 24 pt margins.
public enum OnboardingLayout { public static let width = 720.0, height = 520.0, margin = 24.0 }
/// Identifiers (blueprint 4.1): afterglow.onboarding.<name>.
public enum OnboardingControls {
    public static let page = "afterglow.onboarding.page"          // value: the page id
    public static let `continue` = "afterglow.onboarding.continue"
    public static let back = "afterglow.onboarding.back"
    public static let skip = "afterglow.onboarding.skip"
    public static func focus(_ f: OnboardingFocus) -> String      // afterglow.onboarding.focus.<raw>
    public static func preset(_ p: NewDocumentPreset) -> String   // afterglow.onboarding.new.<preset id>
    public static func sample(_ app: SuiteApp) -> String          // afterglow.onboarding.sample.<app>
    public static let startEmpty = "afterglow.onboarding.start-empty"
    public static let help = "afterglow.onboarding.help"          // the Help menu item
}

// Sources/SuiteModel/Onboarding/SuiteOnboarding.swift (OB-1 stub, OB-7 body)
/// The live OnboardingFlowing (blueprint 5.2 row 13: "same type in Onboarding/").
public struct SuiteOnboarding: OnboardingFlowing {
    public static let version = 1
    /// The one line about rendering on page 1.
    public static let renderingNote = "Rendering is Automatic, which draws on the CPU in this beta. View > Rendering in any app changes it."
    public var pages: [OnboardingPage]                                   // FakeOnboarding().pages
    public func shouldShow(_ p: SuitePreferences, version: Int) -> Bool  // (p.onboardingDoneVersion ?? 0) < version
    public func finishing(_ p: SuitePreferences, focus: OnboardingFocus?, version: Int) -> SuitePreferences
    /// The apps a focus puts first, the order the start page and the home share.
    public static func order(for focus: OnboardingFocus?) -> [SuiteApp]  // finishing(...).homeOrder
}

// Sources/SuiteModel/Onboarding/OnboardingLaunch.swift (OB-1 stub, OB-7 body)
public enum OnboardingLaunch {
    public static let skipFlag = "-SuiteSkipOnboarding"
    /// False with "-SuiteSkipOnboarding YES"; else flow.shouldShow(stored ?? defaults, version:).
    public static func presents(arguments: [String], stored: SuitePreferences?, flow: any OnboardingFlowing,
                                version: Int = SuiteOnboarding.version) -> Bool
    /// The stored preferences read synchronously before the first frame; nil when none or unreadable.
    public static func stored(in store: FileStore) -> SuitePreferences?
}

// Sources/SuiteModel/Onboarding/SampleCatalog.swift (OB-1 stub, OB-10 body)
public struct SampleCatalog: Sendable {
    /// One per app: Bounce.flare, Cards.design, beach.ora (Photo), Sunset.png (Library, imported), Intro.halo.
    public static let samples: [SampleFile]
    public static func sample(for app: SuiteApp) -> SampleFile?
    /// The folder the bundle copies Bundle/Samples/ to: <resources>/Samples.
    public static func folder(resources: String) -> String
    /// "The <App> sample isn't in this build." when `present` says the file isn't there; nil otherwise.
    public static func reason(for s: SampleFile, folder: String, present: (String) -> Bool) -> String?
    /// Where the copy lands: <documents>/Samples/<fileName>, or "<stem> 2.<ext>", "<stem> 3.<ext>" while taken.
    public static func destination(for s: SampleFile, documents: String, exists: (String) -> Bool) -> String
    /// The document ref of a copy at `path`.
    public static func ref(for s: SampleFile, path: String) -> SuiteDocumentRef
}

// Sources/SuiteModel/Preferences/StorePreferences.swift (OB-1 stub, OB-9 body)
/// The live PreferencesStoring (UC-11) over FileStore's preferences.json, StoreRecents' shape.
public actor StorePreferences: PreferencesStoring {
    static let file = "preferences.json"
    public init(store: FileStore, onWrite: @escaping @Sendable (String) -> Void = { _ in })
    public func load() throws(SuiteError) -> SuitePreferences          // stored value with the store's revision; defaults when none
    public func save(_ p: SuitePreferences) throws(SuiteError) -> SuitePreferences  // .staleRevision unless p.revision == stored; writes revision + 1, yields it, onWrite(file)
    public func changes() -> AsyncStream<Int>
    public func externalChange()                                        // re-read and yield an unseen revision (a StoreWatcher calls it)
}

// Sources/SuiteModel/Onboarding/OnboardingModel.swift (OB-1 stubs, OB-8 body)
/// The window's view-model (blueprint 5.7, HomeModel's shape). Linux-safe.
@MainActor @Observable public final class OnboardingModel {
    public private(set) var pages: [OnboardingPage]      // services.onboarding.pages
    public private(set) var pageIndex = 0
    public private(set) var focus: OnboardingFocus?
    public private(set) var starters: [OnboardingStarter]  // tiles in SuiteOnboarding.order(for: focus)
    public private(set) var launching: SuiteApp?          // a hand-off in flight
    public private(set) var message: SuiteError?          // shown under the tile, never an alert
    public private(set) var isFinished = false            // the window closes when true
    public var page: OnboardingPage { pages[pageIndex] }
    public var canGoBack: Bool { pageIndex > 0 }
    public var isLastPage: Bool { pageIndex == pages.count - 1 }
    public var renderingNote: String { SuiteOnboarding.renderingNote }
    /// `present` is FileManager.default.fileExists in the app; `samplesFolder` the bundle's Resources/Samples;
    /// `documents` the support folder's Documents; `copy` moves bytes (tests pass a recorder).
    public init(services: SuiteServices, samplesFolder: String, documents: String,
                present: @escaping @Sendable (String) -> Bool,
                copy: @escaping @Sendable (String, String) throws(SuiteError) -> Void,
                makeID: @escaping @Sendable () -> String = HandOff.newID)
    public func load() async                 // preferences (focus from homeOrder when already set), starters
    public func `continue`()                 // last page: finish(); else pageIndex += 1
    public func back()                       // clamped at 0
    public func choose(_ focus: OnboardingFocus?)   // toggles; reorders starters
    public func skip() async                 // finishing(focus: nil), save, isFinished
    public func finish() async               // finishing(focus:), save (stale: reload, retry once), isFinished
    public func startNew(_ preset: NewDocumentPreset, now: Date) async   // creating.handOff + send, then finish
    public func openSample(_ app: SuiteApp, now: Date) async  // copy to destination, .open hand-off, then finish
}
```

Launcher side (OB-3, `Sources/AfterGlowApp/`): `OnboardingWindow.launchBehavior:
SceneLaunchBehavior` (`.presented` when `OnboardingLaunch.presents(arguments:
ProcessInfo.processInfo.arguments, stored: OnboardingLaunch.stored(in:
FileStore(folder: LauncherServices.support)), flow: LauncherServices.shared.onboarding)`,
else `.suppressed`); `LauncherCommandsOnboarding: Commands` with
`CommandGroup(after: .help) { Button("Welcome to AfterGlow") { openWindow(id: "onboarding") } }`;
`OnboardingWindow.bodyRuns` (debug counter, as the apps' windows). Slot side
(OB-9): `preferencesIsLive = true`, `preferencesSlot` returns
`StorePreferences(store: c.store)`; (OB-12): `onboardingIsLive = true`,
`onboardingSlot` returns `SuiteOnboarding()`.

## Pseudocode

```
presents(arguments, stored, flow):
    if arguments has skipFlag followed by "YES" → false
    return flow.shouldShow(stored ?? SuitePreferences(), version)

SuiteOnboarding.shouldShow(p, version): (p.onboardingDoneVersion ?? 0) < version
SuiteOnboarding.finishing: FakeOnboarding().finishing(p, focus, version)   // one focus → order rule
order(for: focus): finishing(SuitePreferences(), focus, version).homeOrder

StorePreferences.load: (value, revision) = store.read(file); var p = value ?? SuitePreferences(); p.revision = revision; seen = revision
StorePreferences.save(p):
    (_, current) = store.read(file); guard p.revision == current else throw .staleRevision
    var next = p; next.revision = current + 1
    store.write(file, next, expecting: current)            // under the store's lock
    seen = next.revision; feed.send(seen); onWrite(file); return next
externalChange(): (_, r) = store.read(file); if r > seen { seen = r; feed.send(r) }

OnboardingModel.load:
    prefs = try? await services.preferences.load()          // live from OB-9; focus stays nil when none
    starters = order(for: focus).map { app in
        tile = services.creating.tiles(missing: []).first { $0.app == app }
        sample = SampleCatalog.sample(for: app)
        reason = sample.map { SampleCatalog.reason(for: $0, folder: samplesFolder, present: present) }
        OnboardingStarter(tile, sample, reason) }

choose(f): focus = (focus == f) ? nil : f; starters reordered (same tiles, order(for: focus))

finish():
    var p = (try? await services.preferences.load()) ?? SuitePreferences()
    p = services.onboarding.finishing(p, focus: focus, version: SuiteOnboarding.version)
    do { try await services.preferences.save(p) }
    catch .staleRevision { reload, finishing again, save once more }     // a second stale → message
    catch { message = error }                                            // still finished: the window closes
    isFinished = true

skip(): focus = nil; await finish()

startNew(preset):
    launching = preset.app
    send(services.creating.handOff(for: preset, id: makeID(), at: now))  // as HomeModel.newDocument
    on success: await finish()                                          // on error: message, stay

openSample(app):
    guard let s = starter(app).sample, starter(app).sampleReason == nil else { message = .fileMissing; return }
    dest = SampleCatalog.destination(for: s, documents: documents, exists: present)   // never overwrites
    try copy(folder/fileName, dest)                                    // ioFailed → message
    send(HandOff(id, from: .launcher, to: app, verb: .open, documents: [SampleCatalog.ref(for: s, path: dest)], createdAt: now))
    on success: await finish()

OnboardingWindow:
    .task { await model.load() }
    .onChange(of: model.isFinished) { if $0 { dismissWindow(id: "onboarding") } }
    .onDisappear { if !model.isFinished { Task { await model.skip() } } }   // closing = Skip
    Continue: .keyboardShortcut(.defaultAction); Skip: .keyboardShortcut(.cancelAction)
```

## Tasks

One PR per task, base `dev`, label `fast-lane`, body lines `Belt-Lead:`,
`Feature: onboarding`, `Slice: <id>`, `Fast-Check: pass`, `Head:`, and for
a task that changes planned source its `Mutate:` line. OB-13 carries
`feature-done`. Every UI task's builder reads `docs/engineering/swiftui-rules.md`.

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| OB-1 | – | The `Onboarding/` types and stubs: `SampleFile`, `OnboardingStarter`, `OnboardingLayout`, `OnboardingControls`; `SuiteOnboarding`, `OnboardingLaunch`, `SampleCatalog`, `StorePreferences` and `OnboardingModel` with every signature above, bodies returning the fake's values (`pages` from `FakeOnboarding`, `presents` true unless the flag, starters from `SuiteCreating`, `StorePreferences` reading and writing like `FakePreferences`, `finish` sets `isFinished`); `OnboardingStubTests` pins the signatures and the fake values (MJ-OB0) | `Sources/SuiteModel/Onboarding/OnboardingStarter.swift`, `Sources/SuiteModel/Onboarding/SuiteOnboarding.swift`, `Sources/SuiteModel/Onboarding/OnboardingLaunch.swift`, `Sources/SuiteModel/Onboarding/SampleCatalog.swift`, `Sources/SuiteModel/Onboarding/OnboardingModel.swift`, `Sources/SuiteModel/Preferences/StorePreferences.swift`, `Tests/SuiteModelTests/OnboardingStubTests.swift` | – | ~360, 7 |
| OB-2 | – | The checks first, each `@Test(.disabled("waits on OB-n"))`: `SuiteOnboardingTests`, `OnboardingLaunchTests` (OB-7), `OnboardingModelTests` (OB-8), `StorePreferencesTests` (OB-9), `SampleCatalogTests` (OB-10), from the Acceptance rows | `Tests/SuiteModelTests/SuiteOnboardingTests.swift`, `Tests/SuiteModelTests/OnboardingLaunchTests.swift`, `Tests/SuiteModelTests/OnboardingModelTests.swift`, `Tests/SuiteModelTests/StorePreferencesTests.swift`, `Tests/SuiteModelTests/SampleCatalogTests.swift` | OB-1 | ~390, 5 |
| OB-3 | – | Reachable and open: Help > Welcome to AfterGlow (`LauncherCommandsOnboarding`, live, `openWindow(id: "onboarding")`), the scene's `.defaultLaunchBehavior(OnboardingWindow.launchBehavior)`, `.restorationBehavior(.disabled)` and `.commands` (three lines in the frozen file, see What changed); `OnboardingWindow` over an `OnboardingModel` on `LauncherServices.shared`: page 1 with symbols, names, body and the Rendering line, Continue (default) and Skip (cancel), the page/continue/skip control ids, `bodyRuns`, close = skip; `OnboardingLauncherTests` (Linux text scan: the three lines once, the Button titled "Welcome to AfterGlow" calls `openWindow`, the stub test's pinned strings unchanged); the slice's Mac checks as disabled shells (`@Test(.disabled("waits on OB-4"))`): the snapshot and render budget suites OB-5 fills. PR body: `Unverified API: defaultLaunchBehavior, restorationBehavior (macOS 15+ scene modifiers)` for the Mac finisher | `Sources/AfterGlowApp/AfterGlowApp.swift`, `Sources/AfterGlowApp/LauncherCommands+Onboarding.swift`, `Sources/AfterGlowApp/OnboardingWindow.swift`, `Sources/AfterGlowApp/OnboardingPages.swift`, `Tests/SuiteModelTests/OnboardingLauncherTests.swift`, `Tests/AppSnapshotTests/AfterGlowOnboardingSnapshots.swift`, `Tests/AppSnapshotTests/RenderBudgetAfterGlowOnboardingTests.swift` | OB-1 | ~340, 7 |
| OB-4 | – | Pages 2 and 3 on the fakes: `ChoiceChips` of the five focuses (toggle), Back; the starter row (`OnboardingStartPage`: tile symbol and title, preset `ChoiceChips`, "Open sample" with its reason as help, the launching ring, the in-place message), "Start from an empty home"; every control's id; `OnboardingLauncherTests` gains the ids-present scan | `Sources/AfterGlowApp/OnboardingPages.swift`, `Sources/AfterGlowApp/OnboardingStartPage.swift`, `Tests/SuiteModelTests/OnboardingLauncherTests.swift` | OB-3 | ~330, 3 |
| OB-5 | – | Fills OB-3's shells: goldens for the six states in four appearances, the margin and right-edge layout check, and `RenderBudgetAfterGlowOnboardingTests` (`bodies` gates: a Continue click ≤ 2 window bodies, a focus chip click ≤ 1, a 120-sample pointer move over the starter row 0; `timing` reports) nested in `BodyCountSuites`; asks the supervisor for the `perf-suites.txt` line | `Tests/AppSnapshotTests/AfterGlowOnboardingSnapshots.swift`, `Tests/AppSnapshotTests/RenderBudgetAfterGlowOnboardingTests.swift`, `Tests/AppSnapshotTests/Golden/afterglow-onboarding/` | OB-4 | ~360, 3 + PNGs |
| OB-6 | – | Journeys OJ1 and OJ2 as an `extension AfterGlowJourneyTests` (fixture `firstLaunch`, no skip flag; mouse clicks; the Escape and Return parity step) | `UITests/AfterGlowJourneyTests+Onboarding.swift` | OB-4, home HM-0 and HM-3a (the harness and the class) | ~200, 1 |
| OB-7 | – | `SuiteOnboarding` and `OnboardingLaunch` bodies and plans; turns on their tests | `Sources/SuiteModel/Onboarding/SuiteOnboarding.swift`, `Sources/SuiteModel/Onboarding/OnboardingLaunch.swift`, `Tests/mutations/SuiteModel.SuiteOnboarding.json`, `Tests/mutations/SuiteModel.OnboardingLaunch.json`, `Tests/SuiteModelTests/SuiteOnboardingTests.swift`, `Tests/SuiteModelTests/OnboardingLaunchTests.swift` | OB-2 | ~200, 6 |
| OB-8 | – | `OnboardingModel` body (load, page flow, choose, skip, finish with one stale retry, startNew, openSample) and its plan; turns on `OnboardingModelTests` | `Sources/SuiteModel/Onboarding/OnboardingModel.swift`, `Tests/mutations/SuiteModel.OnboardingModel.json`, `Tests/SuiteModelTests/OnboardingModelTests.swift` | OB-2 | ~300, 3 |
| OB-9 | – | `StorePreferences` body (`StoreRecents`' shape: load with the store's revision, save under the lock with `staleRevision`, `changes()`, `externalChange()`, `onWrite`) and its plan; the preferences slot live (`preferencesIsLive = true`, `StorePreferences(store: c.store)`); `SuiteLiveServicesTests` rows for `preferences` (no longer pending, count 8, `load()` returns defaults on an empty folder); turns on `StorePreferencesTests` | `Sources/SuiteModel/Preferences/StorePreferences.swift`, `Tests/mutations/SuiteModel.StorePreferences.json`, `Sources/SuiteShell/Live/PreferencesSlot.swift`, `Tests/AppSnapshotTests/SuiteLiveServicesTests.swift`, `Tests/SuiteModelTests/StorePreferencesTests.swift` | OB-2 | ~220, 5 |
| OB-10 | – | `SampleCatalog` body (the five samples, folder, reason, destination with "2", "3" suffixes, ref) and its plan; turns on `SampleCatalogTests` | `Sources/SuiteModel/Onboarding/SampleCatalog.swift`, `Tests/mutations/SuiteModel.SampleCatalog.json`, `Tests/SuiteModelTests/SampleCatalogTests.swift` | OB-2 | ~180, 3 |
| OB-11 | – | `Bundle/Samples/`: the present A-x-0 exports copied in (`Cards.design`, `Bounce.flare`, `beach.ora`, `Sunset.png`, `Intro.halo`) and `SampleFilesTests` (every `SampleCatalog.samples` file exists under `Bundle/Samples/`, is non-empty and its extension matches its type; a row whose export issue is open skips naming it) | `Bundle/Samples/`, `Tests/SuiteModelTests/SampleFilesTests.swift` | OB-1; #836, #837, #838, #839 (cross-line, skip rows until each lands) | ~120, 1 + files |
| OB-12 | – | Live: `onboardingIsLive = true` and `SuiteOnboarding()` in the slot; `SuiteLiveServicesTests` rows for `onboarding` (no longer pending, count 7, `is SuiteOnboarding`); `LauncherRouter+Onboarding.swift` gives the window `LauncherServices.samplesFolder` (`Bundle.main.resourcePath` + `/Samples`), `documents` and a `FileManager` copy; the window passes them; OJ3 and OJ4 written as `throw XCTSkip("waits on OB-13")` | `Sources/SuiteShell/Live/OnboardingSlot.swift`, `Tests/AppSnapshotTests/SuiteLiveServicesTests.swift`, `Sources/AfterGlowApp/LauncherRouter+Onboarding.swift`, `Sources/AfterGlowApp/OnboardingWindow.swift`, `UITests/AfterGlowJourneyTests+OnboardingStart.swift` | OB-4, OB-7, OB-8, OB-9, OB-10 | ~200, 5 |
| OB-13 | – | Enables OJ3 and OJ4 on live; blueprint prose (row 159, 2.3, 6.1, 8.2 F10 to what was built; `-SuiteSkipOnboarding` in 4.1 named as implemented; UC-11's live store named under onboarding); `status: built`; `feature-done` | `UITests/AfterGlowJourneyTests+OnboardingStart.swift`, `docs/blueprints/suite.md`, `docs/blueprints/suite/features/onboarding.wave.json` | OB-5, OB-6, OB-11, OB-12; switching (transport, Window > Switch To) | ~220, 3 |

The frozen `AfterGlowApp.swift` and `OnboardingWindow.swift` are targets'
files (wave 0, built); `OnboardingSlot.swift`, `PreferencesSlot.swift` and
`SuiteLiveServicesTests.swift` are suite-contracts' (wave 1, built);
`AfterGlowJourneyTests.swift`'s class is home's. The `.wave.json` names
those features in `depends`, which is what lets a later slice own a built
feature's file. `SuiteLiveServicesTests.swift` is edited by OB-9 (OB-m) and
OB-12 (OB-z); OB-z waits on OB-m, so they never run at once.

## Build waves

- Wave 1: OB-1. Independent in this wave: OB-1.
- Wave 2: OB-2, OB-3, OB-11. Independent in this wave: all three.
- Wave 3: OB-4, OB-7, OB-8, OB-9, OB-10. Independent in this wave: all five.
- Wave 4: OB-5, OB-6, OB-12. Independent in this wave: all three (OB-6
  also needs home's HM-0 and HM-3a merged).
- Wave 5: OB-13 (prose and `feature-done`, final).

Longest chain: OB-1 → OB-3 → OB-4 → OB-5 → OB-13 (5). Chain of 5: OB-3
declares the window OB-4's pages sit in, OB-5 shoots OB-4's pages, and
OB-13's done run must hold the goldens. The other chain of 5, OB-1 → OB-2 →
OB-8 → OB-12 → OB-13: OB-2's checks merge before OB-8's code (rule 13),
OB-12 makes OB-8's model live, OB-13 proves it on live.

## Acceptance test per task

Checks land in OB-2 (the Model slices' tests, disabled until their task),
OB-3 (the launcher scans and the disabled snapshot and budget shells OB-5
fills), OB-4 (more scans), OB-12 (OJ3 and OJ4 skipped until OB-13). The one
exception to check-first: OJ1 and OJ2 (OB-6) can't precede OB-3, since they
extend home's `AfterGlowJourneyTests` class (HM-3a) and `UITests/` compiles
in the lane's build-only run; they land with the slice's last task instead.
Mutations target Model code and run with `scripts/mutate --plan <plan>`; a
task's PR ends with its `Mutate:` line.

| id | test | fails when | mutations (plan: label → filter) |
|---|---|---|---|
| OB-1 | `OnboardingStubTests` (Linux): `SuiteOnboarding().pages == FakeOnboarding().pages`; `SuiteOnboarding.renderingNote` names View > Rendering and the CPU; `OnboardingLaunch.presents([], nil, flow)` is true; `OnboardingModel(...)` on `.fake` has five starters in `SuiteApp.apps` order with `SuiteCreating.titles`; `OnboardingControls.focus(.photos) == "afterglow.onboarding.focus.photos"`; `StorePreferences(store:)` on an empty folder loads defaults; the init signature pins | a stub returns a non-fake value early, or a signature drifts | none: stubs |
| OB-2 | the five test files compile and are disabled with their task id | a check is enabled before its code | none: checks |
| OB-3 | the two Mac suites compile, disabled "waits on OB-4"; `OnboardingLauncherTests` (Linux text): `AfterGlowApp.swift` holds `.defaultLaunchBehavior(OnboardingWindow.launchBehavior)`, `.restorationBehavior(.disabled)` and `LauncherCommandsOnboarding()` once each and the stub test's pinned strings once each; `LauncherCommands+Onboarding.swift` has `Button("Welcome to AfterGlow")` with `openWindow(id: "onboarding")` and no `.disabled(`; `OnboardingWindow.swift` declares `static var bodyRuns`, `.keyboardShortcut(.defaultAction)`, `.keyboardShortcut(.cancelAction)` and `onDisappear`; the Mac build on dev compiles. OJ1 steps 1–4 | the scene no longer presents at launch, the Help item is dead, or closing isn't Skip | none: view code (the launch rule is OB-7's) |
| OB-4 | `OnboardingLauncherTests` gains: `OnboardingPages.swift` and `OnboardingStartPage.swift` use `ChoiceChips`, every `OnboardingControls` id appears in a `.suiteControl(` call, "Start from an empty home" and "Open sample" are titles, no literal size (every number is `OnboardingLayout`'s or a token); OJ2 steps 1–5 | a control is unidentified, a page is hand-rolled chips, or a page is missing | none: view code |
| OB-5 | `AfterGlowOnboardingSnapshots`: the six states × four appearances match their goldens; Continue, Back and Skip frames sit ≥ 24 pt inside the window; no tile crosses the right edge at 720 and at `windowLaunch` width. `RenderBudgetAfterGlowOnboardingTests.bodies`: Continue click ≤ 2, focus chip click ≤ 1, 120-sample pointer move 0 | a page drifts, a button touches the edge, or a hover runs the window body | none: snapshots |
| OB-6 | OJ1, OJ2 green on the scoped run (`app=suite`); the `afterglow` audit unchanged; `suite.controls` of the welcome window lists every control enabled or with a reason | the window doesn't open, Skip or Back is dead, or the order is wrong | none: journeys |
| OB-7 | `SuiteOnboardingTests`: `shouldShow` false at `onboardingDoneVersion == version`, true at `nil` and at `version − 1`; `finishing(focus: .photos)` puts `[.library, .photo]` first and sets the version; `order(for: nil) == SuiteApp.apps`. `OnboardingLaunchTests`: `["-SuiteSkipOnboarding", "YES"]` → false whatever is stored; `["-SuiteSkipOnboarding", "NO"]` → the flow's answer; a flag with no value → the flow's answer; `stored(in:)` reads what `FileStore.write` wrote and nil from an empty folder | the tour shows twice, the flag is ignored, or a focus order drops an app | `SuiteModel.SuiteOnboarding`: `<` → `<=` (shows again after done) → `SuiteOnboardingTests`; `finishing` returns `p` unchanged (version never written) → `SuiteOnboardingTests`. `SuiteModel.OnboardingLaunch`: the `skipFlag` guard removed → `OnboardingLaunchTests`; `"YES"` check inverted → `OnboardingLaunchTests` |
| OB-8 | `OnboardingModelTests` on `.fake`: `continue()` walks 0 → 1 → 2 and the third call finishes; `back()` at 0 stays 0; `choose(.photos)` twice clears the focus; starters follow `order(for:)` after every choose; `skip()` saves `onboardingDoneVersion == 1` with `homeOrder == SuiteApp.apps`; `finish()` after `.photos` saves Library, Photo first; a `FakePreferences` seeded one revision ahead: finish reloads and saves once more, `isFinished`; `startNew(flare.hd)` records one `.new` hand-off to `.flare` with that preset and finishes; `openSample(.flare)` copies `<folder>/Bounce.flare` to `<documents>/Samples/Bounce.flare`, records one `.open` hand-off whose document is that path, and finishes; `openSample` on a starter with a reason records nothing and sets `message`; a `FakeHandOffs` that refuses leaves `isFinished` false with `message` | a page is skipped, a stale save is lost, a sample overwrites, or a refused hand-off still closes the window | `SuiteModel.OnboardingModel`: last-page `continue()` increments past the end → `OnboardingModelTests`; `back()` clamp dropped → `OnboardingModelTests`; `skip()` keeps the chosen focus → `OnboardingModelTests`; the stale retry removed → `OnboardingModelTests`; `openSample` ignores `sampleReason` → `OnboardingModelTests`; `startNew` finishes before the send succeeds → `OnboardingModelTests` |
| OB-9 | `StorePreferencesTests` (Linux, a temp folder): `load()` on an empty folder is `SuitePreferences()` at revision 0; `save` writes revision 1 and `load()` returns it; `save` with a stale revision throws `.staleRevision` and changes nothing; `changes()` yields each new revision once; a second `StorePreferences` on the same folder reads the first's write, and `externalChange()` yields the unseen revision once and then nothing; `onWrite` is called with `"preferences.json"` on every save. `SuiteLiveServicesTests`: `pending["preferences"] == nil`, `s.preferences.load()` on a fresh support folder returns defaults | a stale save wins, a revision is lost, or another process's write is never seen | `SuiteModel.StorePreferences`: the `p.revision == current` guard dropped → `StorePreferencesTests`; `next.revision = current` (no bump) → `StorePreferencesTests`; `externalChange` yields when `r >= seen` (repeats) → `StorePreferencesTests` |
| OB-10 | `SampleCatalogTests`: five samples, one per `SuiteApp.apps`, types `.flareAnimation`, `.designDocument`, `.photoOpenRaster`, `.png`, `.haloProject`; `folder("/R") == "/R/Samples"`; `reason` nil when present, "The Halo sample isn't in this build." when not; `destination` is `<documents>/Samples/Bounce.flare`, then `Bounce 2.flare`, `Bounce 3.flare` while taken; `ref` has the app, type, `displayName` of the copy and `fileID(forPath:)` | an app has no sample, a copy overwrites, or the ref names the bundle's file | `SuiteModel.SampleCatalog`: `exists` check dropped (overwrites) → `SampleCatalogTests`; suffix starts at 1 (`Bounce 1.flare`) → `SampleCatalogTests`; `reason` returns nil when missing → `SampleCatalogTests` |
| OB-11 | `SampleFilesTests` (Linux, reads the repo): each `SampleCatalog.samples` file is under `Bundle/Samples/`, non-empty, extension matching its type; a row whose fixture issue is still open is `XCTSkip`ped by its number | a sample is missing from the build or is an empty file | none: files |
| OB-12 | `+OnboardingStart.swift` compiles and skips "waits on OB-13"; `SuiteLiveServicesTests`: `pending["onboarding"] == nil`, pending count 7, `s.onboarding is SuiteOnboarding`, `shouldShow(SuitePreferences(), version: 1)` true; `OnboardingLauncherTests`: `LauncherRouter+Onboarding.swift` builds `samplesFolder` from `Bundle.main.resourcePath` and `SampleCatalog.folder` | the slot still hands out the fake, or the window reads samples from the wrong folder | none: wiring (the bodies are OB-7..10's) |
| OB-13 | OJ3, OJ4 green on the dev macOS run; the home's and the apps' journeys unchanged; the audit under `afterglow`, `flare`, `design` not raised | the sample doesn't open, the home order doesn't follow, or the tour shows again after a relaunch | none: journeys |

## Quality tests

| quality row | budget | test |
|---|---|---|
| render: page turn (Continue, Back) | one click ≤ 2 window bodies (the page and the buttons' enablement); p95 ≤ 16 ms, reported | `RenderBudgetAfterGlowOnboardingTests.bodies`, `.timing` |
| render: focus chip | one click ≤ 1 window body; starters reorder in the same body | `RenderBudgetAfterGlowOnboardingTests.bodies` |
| render: pointer over the starter row | 120-sample move ≤ 0 window bodies (hover is the chips' own state) | `RenderBudgetAfterGlowOnboardingTests.bodies` |
| QB-L9 progress | a tile's ring within 100 ms of a chip or Open sample click (`launching`) | `AfterGlowOnboardingSnapshots` (`-start-launching`), OJ3 step 2 shot |
| store cost | `StorePreferences.save` ≤ 2 ms debug on a 1 KB file (as `Budget+Store`), reported | `StorePreferencesTests.saveWithinBudget` (listed by the supervisor in `perf-suites.txt` if it flakes) |
| No dead controls | every button acts or is disabled with a reason ("The Halo sample isn't in this build.", the pending `sending` sentence); nothing hidden | `suite.controls` read in OJ2, `OnboardingLauncherTests` |
| One gesture, one step | a preset chip creates the document at once; Open sample opens at once; no confirm sheet | OJ3, OJ4, `OnboardingModelTests` |
| Keyboard and VoiceOver parity | Return = Continue, Escape = Skip; chips and tiles reachable by Tab; the page element's value is the page id | OJ2 step 6, `OnboardingLauncherTests` |
| Mouse-only first-time user | every page entered and left with the mouse; the close button leaves | OJ1 steps 2–4, the critic panel's `mouse` lens |
| QB-SV7 goldens | six states × four appearances | `AfterGlowOnboardingSnapshots` |
| 7.3 layout | buttons ≥ 24 pt inside the window; nothing crosses the right edge | `AfterGlowOnboardingSnapshots` layout checks |
| The audit | `afterglow` not raised by the window; the apps' keys unchanged after a sample opens | OJ1–OJ4 |

## Done check

Per slice (contract rule 6): its journeys green on a scoped run (`app=suite`)
that contains its last merged PR, every app built, no open `finding`,
mutations scored in its PR bodies. OB-a: `OnboardingStubTests`. OB-u: OJ1
and OJ2 on the fakes-backed live slot, `RenderBudgetAfterGlowOnboardingTests.bodies`,
the goldens, then the feel gate and its `Mac-Finish: OB-u` line (rules 15
and 17). OB-m: `SuiteOnboardingTests`, `OnboardingLaunchTests`,
`OnboardingModelTests`, `StorePreferencesTests` with `Mutate: 4/4
SuiteModel.SuiteOnboarding+OnboardingLaunch`, `Mutate: 6/6
SuiteModel.OnboardingModel` and `Mutate: 3/3 SuiteModel.StorePreferences`.
OB-s: `SampleCatalogTests` (`Mutate: 3/3`) and `SampleFilesTests` with no
skipped row once #836–#839 are closed. OB-z: OJ3 and OJ4 on live on the dev
run OB-13 triggers, with the home's and the apps' journeys green on the same
run; the audit zero new. Then `Belt-Contact-Sheet: <run link>` on the
feature issue, one line per journey, the three pages in light and dark side
by side, and the home after OJ3 step 3.

## Not in this packet

The Settings window and its panes (after the beta; General's "Show Welcome
Again" is `openWindow(id: "onboarding")` and its panes use OB-9's
`StorePreferences`). Copying `Bundle/Samples/` into the bundle (bundle
BU-4). The sample files' contents (each app's A-x-0 export). A
`StoreWatcher` for `preferences.json` across processes (switching's
`StoreWatcher` attaches `externalChange()` when a second process needs
it; the launcher is the only writer in the beta). `SuiteSize.onboardingWindow`
and `AppTile` (SuiteUI, `needs-ui`). In-app tutorials, a "what's new" page
on update, and a per-app first-run (blueprint row 159's Later column).

## Open

- If the merged BU-4 `bundle-apps` doesn't copy `Bundle/Samples/`, OB-11's
  files sit in the repo unshipped until the bundle issue lands; OJ3 waits
  on it and the lead says so in RECORD's `Open`.
- `SuiteLiveServicesTests` pins the pending count (9 today); OB-9 and OB-12
  each lower it by one. A sibling feature that flips another slot in the
  same window rebases that one number.
