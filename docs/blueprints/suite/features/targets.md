# Feature packet: targets

**Feature:** the suite's targets exist and today's bundles are measured. The
new `SuiteModel`, `SuiteModelTests`, `SuiteShell` and `AfterGlowApp` targets
build on dev with placeholder files; the launcher already shows its home
window, Settings window, onboarding window and every menu item of blueprint
section 6.2, each disabled with "Not connected yet (<feature>)."; the size
of today's five bundles is in a CI artifact; a local spike measures the
packaging shape.
**Line:** `line:suite` · **Wave:** 0 (`waves.md`) · **Lead branch:** `lead/targets`
**Blueprint:** `docs/blueprints/suite.md` sections 2.2, 2.5 (changes 1, 4, 5), 5.1, 6.2, 8.2 (F0).

**Covers:** #807, #808, #809, #810, #811. Each closes through
the task PR named in its row (TG-0 through the supervisor's own commit).

**Depends on:** none. #763 (dev is red) is lane-wide, not a dependency: the
lane keeps merging while it is open.

**Supervisor merges.** BU-0 (`scripts/size-report`, `.github/workflows/ci.yml`)
and BU-1a (`Package.swift`) touch protected paths, so the fast lane refuses
them: the lead opens them as normal PRs (no `fast-lane` label) and the
supervisor merges. TG-0 is the supervisor's own edit of
`docs/c4/model.json` (no feature edits that file). Every other task takes
the lane.

**What changed from the blueprint (review of #792 and this packet's critic).**

- BU-1 is split in two (review: BU-1 was already at 15 files plus the C4
  JSON). BU-1a is the protected half: `Package.swift` and one file per new
  target so each builds. BU-1b is lane work: the launcher's scenes, its
  placeholder views and its menu stubs. The C4 entries move out of the
  feature into TG-0 and land first ("C4 entries can land before the Sources
  files"; the check only scans files that exist).
- BU-1b also creates `LauncherRouter.swift` as a stub app delegate, so
  `AfterGlowApp.swift` is complete after BU-1b and no later feature edits
  it. Services are wired later through `LauncherRouter+Services.swift`
  (home, HM-2a), which calls `UpdateService.checker()` in
  `UpdateService.swift`, a stub the home creates and the updater (UP-2,
  wave 4) fills. That answers the review's "the updater injection point has
  no owner".
- BU-S needs a Mac; a cloud lead can't run it. The supervisor (or the
  captain) runs it locally; it is not in the done check, and Q12 waits on
  its numbers.

## Journey steps

No journey yet (the home is wave 2). What a person can do after this
feature, on the dev CI build:

1. `AfterGlowApp` builds on the macOS job and launches to a window titled
   "AfterGlow" with a placeholder home ("The AfterGlow home arrives with the
   home feature.").
2. Every launcher menu of section 6.2 exists: File (New ▸ with its five
   items, Open…, Open Recent ▸; Close ⌘W is the system's), Edit (Undo and
   Redo are the system's; Cut, Copy, Paste as "Add from Clipboard", Delete
   as "Remove from Recents" or "Remove Asset" by page, Select All), View
   (Show Sidebar, Show Inspector, Larger and Smaller Thumbnails), Window
   (Switch To ▸, Assets), AfterGlow (Check for Updates…, Settings…). Each item the
   feature hasn't built yet is disabled with "Not connected yet (home)." (or
   switching, assets, updater, settings).
3. AfterGlow > Settings… (⌘,) opens the Settings window with one line:
   "Settings arrive with the settings feature."
4. The `size-report` artifact of the next dev run lists the five bundles.

## Screens and states

| Screen | Empty | Error | Loading |
|---|---|---|---|
| Home window (placeholder) | the placeholder sentence, centered, `SuiteFont.body`, `textSecondary` | none | none |
| Settings (placeholder) | one sentence | none | none |
| Onboarding window (placeholder) | declared but never opened (onboarding, wave 4, opens it) | none | none |
| Menus | every item present; unbuilt ones disabled with their reason (design.md: never hidden) | none | none |

## Contract slice

No protocol yet (suite-contracts, wave 1). BU-1a creates only:

```swift
// Sources/SuiteModel/Values/SuiteIdentity.swift (BU-1a; suite-contracts SC-1a fills the rest of Values/)
public enum SuiteIdentity {
    public static let prefix = "org.creativesuite"          // Q1 renames it; one constant
    public static let launcherBundleID = prefix + ".afterglow"
    public static func notConnected(_ feature: String) -> String { "Not connected yet (\(feature))." }
}

// Sources/SuiteShell/SuiteCommands.swift (BU-1a stub; switching SW-3c owns it from wave 2)
public struct SuiteCommands: Commands {            // Window > Switch To ▸, six items, each disabled
    public init(app: SuiteApp = .launcher) {}       // with SuiteIdentity.notConnected("switching"); the
                                                    // signature switching SW-3c keeps, so AfterGlowApp.swift
                                                    // (frozen after BU-1b) compiles before and after it
    public var body: some Commands { ... }
}

// Sources/AfterGlowApp/LauncherRouter.swift (BU-1b stub; switching SW-3b owns it from wave 2)
final class LauncherDelegate: NSObject, NSApplicationDelegate {}
```

`Package.swift` after BU-1a (blueprint 2.5 change 1, verbatim shape):
`SuiteModel` and `SuiteModelTests` on every platform; `model()` adds
`"SuiteModel"` to every `<X>Model`; under `#if os(macOS)`: `SuiteShell`
(SuiteUI, SuiteModel), the `AfterGlowApp` executable target and product
(SuiteUI, SuiteShell, SuiteModel), every `<X>App` adds `"SuiteShell"`, and
`AppSnapshotTests` adds `AfterGlowApp`, `SuiteShell` and `SuiteModel`.

## Pseudocode

```
BU-1b AfterGlowApp.swift (frozen after this task):
  @main struct AfterGlowApp: App
    @NSApplicationDelegateAdaptor(LauncherDelegate.self) var delegate
    body:
      Window("AfterGlow", id: "home") { HomeWindow() }
        launch and minimum size: the ones SuiteWindow already uses (#715: 1000 × 640, minimum 880)
        .commands { SuiteCommands(app: .launcher); LauncherCommandsHome(); LauncherCommandsAssets(); LauncherCommandsUpdate() }
      Settings { SettingsView() } .commands { LauncherCommandsSettings() }
      Window("Welcome to AfterGlow", id: "onboarding") { OnboardingWindow() }
  (UpdateSheet is presented by HomeWindow from wave 2; BU-1b only creates its file)

each LauncherCommands+<Area>:
  CommandGroup(replacing/after: <the 6.2 place>) {
    for item in the 6.2 items of <Area>:
      Button(item.title) {}.disabled(true).help(SuiteIdentity.notConnected(<feature>))
  }

BU-0 scripts/size-report (today's five bundles):
  for app in .build/apps/*App.app:
    bytes(executable), bytes(bundle), suiteUISymbols = nm -U | swift demangle | module SuiteUI,
      minus generic specializations and inlined copies (blueprint 7.5)
  bytes(app-builds.tar.gz)
  write .build/size-report.json in SizeReport's shape; exit 1 if an expected bundle is missing
```

## Tasks

Every task is one PR to `dev`: at most 400 changed lines and 15 files, body
lines `Belt-Lead:`, `Feature: targets`, `Fast-Check: pass`, `Head:`. Lane
PRs carry `fast-lane`; BU-1b also carries `feature-done`.

| id | issue | what | owned files | depends on | merges |
|---|---|---|---|---|---|
| TG-0 | #807 | C4: the planned `SuiteModel`, `SuiteShell`, `AfterGlowApp`, bundle, tests and journeys containers and components of `docs/blueprints/suite/c4-planned.json`, folded into the model | `docs/c4/model.json` | – | supervisor (its own commit) |
| BU-S | #808 | Local spike on a Mac: shape B's cold launch and activation (20 runs each, `ProcessInfo.systemUptime` stamps) and resident memory against shape A's second scene; `application(_:open:)` receives a file with no window open on macOS 26; a cross-app XCUITest drag works on the runner; whether Launch Services indexes a nested `Contents/Helpers/*.app` | `docs/blueprints/suite/spike.md` | – | lane (docs), run by the supervisor on a Mac |
| BU-0 | #809 | `scripts/size-report` for today's five bundles, its fixture test (run in the same `macos` step, since `nm` and `swift demangle` need Mach-O), and a `macos` step that runs it after `scripts/bundle-apps`, uploads `size-report` and adds the table to the job summary (report only). Its JSON keys are bundle's `SizeReport` exactly: `commit`, `entries` (`name`, `kind`, `bytes`) and `suiteUISymbols` (app name to count) | `scripts/size-report`, `Tests/size_report/test_size_report.sh`, `Tests/size_report/fixture/` (two tiny fake bundles), `.github/workflows/ci.yml` | – | supervisor |
| BU-1a | #810 | The four targets in `Package.swift` with one source file each, so Linux builds `SuiteModel` and the macOS job builds `SuiteShell` and `AfterGlowApp` | `Package.swift`, `Sources/SuiteModel/Values/SuiteIdentity.swift`, `Sources/SuiteShell/SuiteCommands.swift` (stub), `Sources/AfterGlowApp/AfterGlowApp.swift` (minimal `@main`), `Tests/SuiteModelTests/SuiteIdentityTests.swift` | TG-0 | supervisor |
| BU-1b | #811 | The launcher's scenes and placeholders: home `Window`, `Settings`, onboarding `Window`, the update sheet's file, the stub delegate, and one `Commands` stub per launcher feature holding its 6.2 items disabled with their reason | `Sources/AfterGlowApp/AfterGlowApp.swift`, `HomeWindow.swift`, `AssetsPage.swift`, `SettingsView.swift`, `OnboardingWindow.swift`, `UpdateSheet.swift`, `LauncherRouter.swift`, `LauncherCommands+Home.swift`, `LauncherCommands+Settings.swift`, `LauncherCommands+Assets.swift`, `LauncherCommands+Update.swift` (all under `Sources/AfterGlowApp/`), `Tests/SuiteModelTests/LauncherMenuStubTests.swift` | BU-1a | lane |

Order: TG-0 and BU-0 and BU-S at once; BU-1a after TG-0; BU-1b after BU-1a.
Sizes: BU-0 ~250 lines / 5 files, BU-1a ~150 / 5, BU-1b ~350 / 12.

**Ownership after this feature.** `AfterGlowApp.swift` and `Package.swift`
have no further owner in waves 1 and 2 (bundle's BU-3 owns `project.yml`,
not `Package.swift`). `SuiteIdentity.swift` goes to suite-contracts (SC-1a),
`SuiteCommands.swift` and `LauncherRouter.swift` to switching (SW-3c,
SW-3b), `HomeWindow.swift` and `LauncherCommands+Home.swift` to home, and
the other placeholders to settings, shared-assets, onboarding and updater in
their waves.

## Acceptance test per task

| id | test | fails when |
|---|---|---|
| TG-0 | `scripts/ci`'s C4 step on BU-1a's branch rebased on TG-0: `CI: PASS`; `jq . docs/c4/model.json` succeeds | a new Sources file has no owner or two owners |
| BU-S | `spike.md` holds, for shape B and shape A, 20 samples of cold launch and of activation with p50 and p95, resident memory of five apps vs one process, and a yes/no with the log line for each of the three confirmations | any number or confirmation is missing (the supervisor's review); a "no" on `application(_:open:)` reopens blueprint 2.6 before switching starts |
| BU-0 | `bash Tests/size_report/test_size_report.sh`, run by the `macos` step: on the fixture the JSON has one executable row per bundle with bytes > 0 and a `suiteUISymbols` count; with one bundle's executable removed the script exits 1 | a row is missing, a count is absent, or a missing bundle passes |
| BU-1a | `SuiteIdentityTests` (Linux): the prefix is `org.creativesuite`, the launcher id `org.creativesuite.afterglow`, and `notConnected("home")` reads "Not connected yet (home)."; `scripts/ci` PASS with `SuiteModel` in the Linux build | a target is missing on Linux, or the strings drift |
| BU-1b | `LauncherMenuStubTests` (Linux, reads the four `LauncherCommands+*.swift` files, `Sources/SuiteShell/SuiteCommands.swift` and `AfterGlowApp.swift` as text): every launcher item of blueprint 6.2 that is not the system's appears exactly once (Switch To ▸ in `SuiteCommands.swift`; Delete in the home stub; Cut, Copy, Paste and Select All in the assets stub) with `.disabled(true)` and `notConnected(<its feature>)`, and `AfterGlowApp.swift` declares the three scenes and the four command groups; the macOS job on dev builds `AfterGlowApp` | an item is missing, doubled or enabled with no reason, or a scene is missing |

## Quality tests

| quality row | budget | test |
|---|---|---|
| Size baseline (blueprint 7.5) | report only: bytes per executable, per bundle and the tarball; SuiteUI symbols per executable | BU-0's artifact on dev; the numbers go into the PR body and `spike.md` |
| No dead controls (CLAUDE.md) | every launcher menu item acts or is disabled with a reason | `LauncherMenuStubTests` |
| Packaging shape (Q12) | cold launch and activation recorded, no gate | BU-S |

## Done check

- **Journeys green:** the dev macOS run triggered by BU-1b (`feature-done`)
  is green: every existing app journey still passes and the five
  `<X>App.app` bundles still build with `SuiteShell` linked.
- **Audit zero new:** no app count over `UITests/audit-baseline.json` (the
  launcher has no journey yet, so no `afterglow` key; home adds it at 0).
- **Contact sheet:** `Belt-Contact-Sheet: <run link>` on the feature issue,
  with the `size-report` table pasted in and a note that the launcher has no
  journey shots until home.
