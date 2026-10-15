# Feature packet: switching

**Feature:** move between the six suite processes with one keystroke and
never lose a thing. Window > Switch To ▸ (⌃⌘0 home, ⌃⌘1 to ⌃⌘5 the apps) in
the launcher and every app; a running app comes forward with its windows
as left; an app with no window opens one; a cold app launches with the
suite's arguments; a hand-off file carries "open this", "new from this
preset" and later verbs to the right app even when it has no window; a
crash in one app leaves the others running.
**Line:** `line:suite` · **Wave:** 2 (`waves.md`) · **Lead branch:** `lead/switching`
**Blueprint:** `docs/blueprints/suite.md` sections 2.3 (shell-apps,
shell-handoff, shell-store-watch, shell-adoption), 2.6 (processes,
hand-off transport, journey launch arguments), 4.2 (SJ1 steps 3–4, SJ2,
SJ3), 4.4 (SP1, SP2), 5.1 (UC-1, UC-5, UC-18), 5.8, 6.2 (Switch To), 7.1
(QB-S1, QB-S2, QB-SM4), 7.6, 8.2 (F4).

**Covers:** #852, #853, #854, #855, #856, #860, #857, and the app-line
adoption issues it files:
#861, #862, #863, #864, #865. Suite tasks close
through their PRs; the adoption issues through their lines' PRs.
**Follow-ups, outside the done check:** #858 (SW-4b, SJ2), which waits on
Photo's, Library's and Halo's adoptions, and #859 (SW-4c, perf), which
waits on #782. Both are filed now and merge when their waits clear.

**Depends on:** suite-contracts and bundle (wave 1; their feature issues
are named in `waves.md`) and #778 (SuiteUI suite-harness: #333 journey
template, #330 `FrameProbe`, #775 `suite.controls`). SW-4c also waits on
#782 (named marks `switch-cold`, `tile-progress`). SW-4a and SW-4b wait on
home's HM-2b #845 (the tiles and cards they click) and on the adoption
issues below.

**What changed from the blueprint (review of #792 and this packet's critic).**

- **SW-3 is split in three** (eleven AppKit files would not fit 400 lines):
  run states and the store watcher; the hand-off transport, the app
  delegate and the launcher's router; the menus and the scene modifier.
- **SW-4 waits on home's HM-2b** (review: SJ2, SJ3 and
  `testOpenRecentBringsAppForward` click tiles and cards HM-2 builds). Two
  leads run in wave 2, so this is a task-level `depends on`, not a feature
  dependency: the switching lead builds SW-1 to SW-3c first and starts
  SW-4a/b only once #845 is closed.
- **SW-4 is split in three** (switch journeys, the new-document journey,
  perf), and the rubric rows are their own task, SW-5, a docs-only PR that
  appends an "AfterGlow" subsection at the end of `docs/review-rubric.md`
  section 6. Flare's QH-7 (#396) edits the same file's Flare rows; whichever
  lands second rebases (no shared lines). SW-5 adds rows only, report only.
- **The adoption issues A-x-1 are filed here; the fixture issues A-x-0 and
  A-LI-0 are filed by home** (its journeys read them first).
- **Argument forwarding is Model code** (`LaunchArguments`, SW-1), so the
  rule "every `-<App>*` flag plus `-SuiteSupportDir`, `-SuitePerfProbe` and
  `-SuiteFixtureDocuments`" is tested on Linux.
- **Recents become cross-process here.** SW-3a attaches `StoreWatcher` to
  `StoreRecents.onWrite` and `externalChange()` in `Live/RecentsSlot.swift`
  (owned by switching in wave 2; recents-open-in owns it from wave 3), so
  the home's grid updates when an app writes recents.
- The cold-launch progress in the home's running strip is home's (HM-1b's
  `launching`, HM-2a's strip with `ProgressRow` #781); SW-4c only times it.

## Journey steps

SJ3 `testSwitchKeepsEachAppAsLeft` (`+Switch`) on `weekOfWork`:

1. Open `Bounce.flare` from the home; in Flare go to frame 12, select Ball,
   zoom to 200%.
2. ⌃⌘2 → Design comes forward (no document: its empty state). The home strip
   shows "Opening Design…" while it launches cold.
3. ⌃⌘1 → Flare comes forward: frame 12, Ball selected, 200%, same window.
4. Window > Switch To > Home (⌃⌘0); in the running strip click Flare → the
   same state again. The strip lists Flare and Design.
5. In Flare ⌘W (the last window), then Window > Switch To > Show Flare
   Window (⌃⌘1, enabled because Flare has no window) → Flare, still the same
   process, opens a window (its empty state, as a reopen).

`testOpenRecentBringsAppForward` (`+Switch`, blueprint SJ1 steps 3–4): on
`weekOfWork` search "logo", Design chip, Return on `Logo.design` → Design is
`runningForeground` with window title "Logo.design" and the launcher still
runs; ⌃⌘0 → the home is frontmost.

`testCrashIsolation` (`+Switch`, 7.6): with Design holding a dirty document
and Flare running, `SIGKILL` Flare (its pid from its probe); Design's
window, document and dirty dot are unchanged; the home drops Flare from the
strip within 1 s; ⌃⌘1 launches it cold. If the runner may not signal
another process, this test is skipped with that sentence and runs locally.

SJ2 `testNewDocumentByType` (`+New`) on `empty`:

1. New Animation's preset menu (at 1000 pt) → "Vertical 9:16" → Flare
   comes forward with a new untitled animation (1080 × 1920 once Flare's
   #351 lands; until then the title "Untitled" only).
2. ⌃⌘0; New Design → Design's new untitled file.
3. ⌃⌘0; New Image → Photo's New Image sheet.
4. ⌃⌘0; New Composition → Halo's New Composition sheet.
5. ⌃⌘0; Import Photos… → Library comes forward with its Import Folder panel.
6. Relaunch with `-SuiteHideApp halo`: the Halo tile is disabled with "Halo
   is missing from AfterGlow. Reinstall AfterGlow to get it back."

SP1, SP2 (`+PerfSwitch`).

## Screens and states

| Surface | Empty | Error | Loading |
|---|---|---|---|
| Window > Switch To ▸ (every process) | the current app's item reads "Show <App> Window": enabled with no window, else disabled "You're in <App>." | a missing app's item disabled with `appMissing`'s sentence | – |
| Switching to a crashed app | – | the strip drops it within 1 s; the next ⌃⌘<n> launches it cold | the home's "Opening <App>…" after 100 ms |
| A hand-off the target can't take | – | the target's `refusal` sentence shown by the sender in place (the home's message line); an expired one: "This request expired."; a newer format: "This was sent by a newer AfterGlow. Update AfterGlow to open it." | – |
| An app that hasn't adopted the suite yet | its Switch To item still launches or activates it; hand-offs to it are refused "<App> can't do that yet." | – | – |

## Contract slice

From suite-contracts: `AppSwitching`, `HandOffSending`, `HandOffReceiving`,
`SuiteDocumentHost`, `HandOff`, `HandOffCodec`, `SwitchReceipt`,
`AppRunState`, `StoreRecents`. This feature adds:

```swift
// Sources/SuiteModel/Switching/ (SW-1)
public enum SwitchAction: Equatable, Sendable { case activate, open, refuse(SuiteError) }
public enum SwitchPlanner {
    public static func action(for state: AppRunState) -> SwitchAction   // running with windows: activate;
}                                                                         // no window or not running: open; missing: refuse
public struct SwitchMenuItem: Equatable, Sendable { app, title, digit, enabled, reason }
public enum SwitchMenu { public static func items(current: SuiteApp, states: [SuiteApp: AppRunState]) -> [SwitchMenuItem] }
public enum LaunchArguments { public static func forward(_ args: [String], to app: SuiteApp) -> [String] }

// Sources/SuiteModel/HandOff/ (SW-2)
public actor StoreHandOffs: HandOffSending, HandOffReceiving {
    public init(store: FileStore, from: SuiteApp, deliver: @escaping @Sendable (String, SuiteApp) async throws(SuiteError) -> SwitchReceipt)
    public func sweep(now: Date) throws(SuiteError) -> Int     // expires pending files older than 7 days, deletes settled ones
}

// Sources/SuiteShell/ (SW-3a–c; macOS)
public actor AppLauncher: AppSwitching { public init(bundle: String, arguments: [String]) }   // -SuiteHideApp honoured
public final class StoreWatcher { public static func post(_ file: String); public func observe(_ file: String, _ action: @escaping @Sendable () -> Void) }
public enum HandOffTransport { public static func deliver(_ path: String, to app: SuiteApp) async throws(SuiteError) -> SwitchReceipt }
open class SuiteAppDelegate: NSObject, NSApplicationDelegate {      // apps adopt with @NSApplicationDelegateAdaptor; Photo subclasses it
    public var host: (any SuiteDocumentHost)?
    open func application(_ app: NSApplication, open urls: [URL])
}
extension Scene { public func suiteApp(_ app: SuiteApp, host: any SuiteDocumentHost) -> some Scene }
public struct SuiteCommands: Commands { public init(app: SuiteApp = .launcher) }   // the signature BU-1a's stub already has, so the
                                                                                   // frozen AfterGlowApp.swift keeps compiling
```

## Pseudocode

```
SwitchMenu.items(current, states):                                  # SW-1
  for app in [.launcher] + SuiteApp.apps:
    title = app == current ? "Show \(app.displayName) Window" : app == .launcher ? "Home" : app.displayName
    if states[app] == .missing: disabled(appMissing(app).message)
    elif app == current and states[app] has windows: disabled("You're in \(app.displayName).")
    else enabled ; key ⌃⌘ app.switchDigit

LaunchArguments.forward(args, to app):                              # SW-1, blueprint 2.6
  keep "-<AppName>*" pairs, -SuiteSupportDir, -SuitePerfProbe, -SuiteFixtureDocuments, -LibrarySample, -LibraryCatalogDir (Library only)

AppLauncher.switchTo(app, reason):                                   # SW-3a
  switch SwitchPlanner.action(runState(app)):
    .activate: NSRunningApplication(bundleID).activate()
    .open: NSWorkspace.openApplication(at: helper(app), configuration: args = LaunchArguments.forward(own args, app))
    .refuse(e): throw e
  receipt(requestedAt: ProcessInfo.systemUptime)
runState: running apps by bundle id; window count from the app's own probe value is not visible, so
  "has windows" comes from the run state the app posts on StoreWatcher ("<app>.windows" notification)

StoreHandOffs.send(h):                                               # SW-2
  store.writeData("handoffs/\(h.id).aghandoff", HandOffCodec.encode(h))   # raw bytes, no revision envelope (SC-4a)
  return try await deliver(path, h.to)
StoreHandOffs.receive(data, now): decode; expired -> settle(.expired), throw ; else .accepted
SuiteAppDelegate.application(_:open:):                                # SW-3b
  for url where ext == "aghandoff": h = receive(data); state = try await host.accept(h); settle(h.id, state)
  other urls: host.accept(HandOff(id: newID(), from: .launcher, to: app, verb: .open, documents: [ref(url)]))
LauncherDelegate (LauncherRouter.swift): a document URL -> FakeRouting rule -> deliver to that app; no window opens;
  an .aghandoff addressed to the launcher -> LauncherRouter+<verb area>.swift (none in wave 2: settings adds +Settings)
```

## Tasks

Every task is one PR to `dev`: at most 400 changed lines and 15 files, label
`fast-lane`, body lines `Belt-Lead:`, `Feature: switching`, `Fast-Check:
pass`, `Head:`. SW-4a, the last PR of the feature, carries `feature-done`; SW-5
lands before it; SW-4b and SW-4c are follow-ups outside the done check.

| id | issue | what | owned files | depends on |
|---|---|---|---|---|
| SW-1 | #852 | `SwitchPlanner`, `SwitchMenu`, `LaunchArguments` | `Sources/SuiteModel/Switching/SwitchPlanner.swift`, `SwitchMenu.swift`, `LaunchArguments.swift`, `Tests/SuiteModelTests/SwitchRunStateTests.swift`, `Tests/SuiteModelTests/SwitchMenuTests.swift`, `Tests/SuiteModelTests/SwitchLaunchArgumentsTests.swift` | SC-1b #821 |
| SW-2 | #853 | `StoreHandOffs`: write, deliver, receive, settle, expire, sweep; QB-SM4 | `Sources/SuiteModel/HandOff/StoreHandOffs.swift`, `Tests/SuiteModelTests/HandOffStoreTests.swift`, `Tests/SuiteModelTests/Budget+HandOff.swift` | SC-4a #829, SC-2a #824 |
| SW-3a | #854 | `AppLauncher` (live `AppSwitching`, `-SuiteHideApp`), `StoreWatcher`, the live switching slot, the watcher on the recents slot | `Sources/SuiteShell/AppLauncher.swift`, `StoreWatcher.swift`, `Live/SwitchingSlot.swift`, `Live/RecentsSlot.swift`, `Tests/AppSnapshotTests/SuiteShellSwitchingTests.swift` | SW-1, SC-5b #833 |
| SW-3b | #855 | `HandOffTransport`, `SuiteAppDelegate`, the live hand-off slot, the launcher's `LauncherRouter` (file routing, no window; verb dispatch to `LauncherRouter+<Area>.swift`) | `Sources/SuiteShell/HandOffTransport.swift`, `SuiteAppDelegate.swift`, `Live/HandOffSlot.swift`, `Sources/AfterGlowApp/LauncherRouter.swift`, `Tests/AppSnapshotTests/SuiteShellHandOffTests.swift` | SW-1, SW-2 |
| SW-3c | #856 | `SuiteCommands` (Switch To ▸ from `SwitchMenu`; Open In ▸ and Settings… through stubs), `.suiteApp(_:host:)`, the `SettingsRoute` and `OpenInMenu` stubs; the shortcut clash test | `Sources/SuiteShell/SuiteCommands.swift`, `SuiteAppModifier.swift`, `SettingsRoute.swift` (stub), `OpenInMenu.swift` (stub), `Tests/SuiteModelTests/SuiteCommandsTests.swift` | SW-3a, SW-3b |
| SW-4a | #857 | Journeys SJ3, `testOpenRecentBringsAppForward`, `testCrashIsolation` | `UITests/AfterGlowJourneyTests+Switch.swift` | SW-3c, HM-0 #841, HM-2b #845, A-FL-1 #861, A-DE-1 #862, A-FL-0 #837, A-DE-0 #836 |
| SW-4b | #858 | Journey SJ2 (every tile, the missing-app error) | `UITests/AfterGlowJourneyTests+New.swift` | SW-3c, HM-0 #841, HM-2b #845, A-FL-1 #861, A-DE-1 #862, A-FL-0 #837, A-DE-0 #836, A-PH-1 #863, A-LI-1 #864, A-HA-1 #865 |
| SW-4c | #859 | SP1, SP2; the switching budget constants (report only) | `UITests/AfterGlowJourneyTests+PerfSwitch.swift`, `UITests/AfterGlowJourneyTests+BudgetsSwitch.swift` | SW-3c, HM-0 #841, HM-2b #845, A-FL-1 #861, A-DE-1 #862, A-FL-0 #837, A-DE-0 #836, #782 |
| SW-5 | #860 | Every QB-S and QB-SM row of blueprint 7.1 into `docs/review-rubric.md` section 6 as an appended "AfterGlow" subsection, report only, each naming its test and its feature's budget file | `docs/review-rubric.md` | – |

Adoption issues this feature files (`needs-suite`, each built by its line):

| id | issue | line | what | owned files | depends on |
|---|---|---|---|---|---|
| A-FL-1 | #861 | flare | `FlareModel` conforms to `SuiteDocumentHost` (`.open` a `.flare`, `.new` from a preset's width, height and fps); `FlareApp` adds `.suiteApp(.flare, host:)`, `@NSApplicationDelegateAdaptor(SuiteAppDelegate.self)` and `SuiteCommands(app: .flare)`; Flare's menu journey counts updated | `Sources/FlareModel/FlareDocumentHost.swift`, `Tests/FlareModelTests/FlareDocumentHostTests.swift`, `Sources/FlareApp/FlareApp.swift`, `UITests/FlareJourneyTests.swift` | SW-3c #856, #346 (the window on `EditorShell`) |
| A-DE-1 | #862 | design | Same for Design (`.open` a `.design`, `.new` blank) | `Sources/DesignModel/DesignDocumentHost.swift`, `Tests/DesignModelTests/DesignDocumentHostTests.swift`, `Sources/DesignApp/DesignApp.swift`, `UITests/DesignJourneyTests.swift` | SW-3c |
| A-PH-1 | #863 | photo | Same for Photo (`.open` an image or `.ora`; `.new` shows the New Image sheet); Photo's PV-1 delegate subclasses `SuiteAppDelegate` when it lands | `Sources/PhotoModel/PhotoDocumentHost.swift`, `Tests/PhotoModelTests/PhotoDocumentHostTests.swift`, `Sources/PhotoApp/PhotoApp.swift`, `UITests/PhotoJourneyTests.swift` | SW-3c |
| A-LI-1 | #864 | library | Same for Library (`.new` with `library.import` opens Import Folder; `.open` of images is recents-open-in's A-LI-2) | `Sources/LibraryModel/LibraryDocumentHost.swift`, `Tests/LibraryModelTests/LibraryDocumentHostTests.swift`, `Sources/LibraryApp/LibraryApp.swift`, `UITests/LibraryJourneyTests.swift` | SW-3c, A-LI-0 #840 (same `LibraryApp.swift`) |
| A-HA-1 | #865 | halo | Same for Halo (`.open` a `.halo`; `.new` shows New Composition) | `Sources/HaloModel/HaloDocumentHost.swift`, `Tests/HaloModelTests/HaloDocumentHostTests.swift`, `Sources/HaloApp/HaloApp.swift`, `UITests/HaloJourneyTests.swift` | SW-3c, #209 for `.open` |

Order: the Build waves below. SW-3b doesn't need SW-3a: `HandOffTransport`
opens the hand-off file with the target app through Launch Services and
calls nothing in `AppLauncher` or `StoreWatcher`. It needs SW-1: that open
cold-launches an app that isn't running, so it passes
`LaunchArguments.forward` too. SW-5 only names tests, so
it needs no code. SW-4b and SW-4c don't need SW-4a's journey file; they
carry its outside waits instead (home's #845, the adoptions, the fixtures)
and stay follow-ups outside the done check. The adoption issues land on
their lines after SW-3c. Sizes:
SW-1 ~300, SW-2 ~280, SW-3a ~350, SW-3b ~380, SW-3c ~330, SW-4a ~330,
SW-4b ~220, SW-4c ~220, SW-5 ~60.

**Files shared with other features, and why it's safe.** `SuiteCommands.swift`
(BU-1a's stub, wave 0) and `LauncherRouter.swift` (BU-1b's stub) are owned
here from wave 2. `Live/SwitchingSlot.swift`, `Live/HandOffSlot.swift` and
`Live/RecentsSlot.swift` come from suite-contracts (wave 1); recents-open-in
owns `RecentsSlot.swift` from wave 3. `SettingsRoute.swift` and
`OpenInMenu.swift` are created here as disabled stubs and owned by settings
and recents-open-in from wave 3. Home (the other wave-2 feature) owns no
file in this list, and nothing home owns appears here. Each app's `<X>App.swift`
and journey file is edited only by its own line's adoption issue.

**Shared docs.** No task edits `docs/c4/model.json`, `docs/design.md`,
`docs/blueprints/suite.md` or `waves.md`: the new files sit in the
`SuiteModel`, `SuiteShell`, `AfterGlowApp` and journeys components that
targets' TG-0 (see #807) adds, so the feature needs no docs task. `docs/review-rubric.md`
(SW-5) is not a shared doc under rule (a).

## Build waves

- Wave 1: SW-1, SW-2, SW-5. Independent in this wave: all three.
- Wave 2: SW-3a, SW-3b. Independent in this wave: both.
- Wave 3: SW-3c. Independent in this wave: SW-3c alone.
- Wave 4: SW-4a (`feature-done`), SW-4b, SW-4c (follow-ups, each once its
  outside waits clear). Independent in this wave: all three.

Longest chain: SW-1 → SW-3a → SW-3c → SW-4a (4), and SW-2 → SW-3b → SW-3c →
SW-4a (4).
Chain of 4: `AppLauncher` (SW-3a) calls `SwitchPlanner` and
`LaunchArguments` (SW-1), `HandOffTransport` (SW-3b) uses
`LaunchArguments` (SW-1) and `SuiteAppDelegate` (SW-3b) calls
`StoreHandOffs` (SW-2); `SuiteCommands` and `SuiteAppModifier` (SW-3c) use
`StoreWatcher` and set `SuiteAppDelegate.host`; the journeys (SW-4a) drive
the Switch To menu SW-3c adds.

## Acceptance test per task

| id | test | fails when |
|---|---|---|
| SW-1 | `SwitchRunStateTests`: running with windows → activate; running with none → open; not running → open; missing → refuse `appMissing`; after `terminate` the state is not running and the next switch opens. `SwitchMenuTests`: six items in order Home, Flare … Halo with digits 0–5; in Flare with a window its item is disabled "You're in Flare."; with no window it reads "Show Flare Window" and is enabled. `SwitchLaunchArgumentsTests`: Design gets `-DesignSaveTo x` and `-SuiteSupportDir`, never `-FlareSaveTo` | a crashed app is activated instead of launched, an item is mislabeled, or a flag leaks to the wrong app |
| SW-2 | `HandOffStoreTests`: `send` writes exactly `handoffs/<uuid>.aghandoff` and calls `deliver` with that path; `receive` of a 7-day-old pending file settles it `expired` and throws "This request expired."; `settle(.returned)` then `sweep` deletes it; a format-2 file is refused; `Budget+HandOff` QB-SM4 encode + decode ≤ 2 ms debug | a path nests, an expired request acts, or a settled file lingers |
| SW-3a | `SuiteShellSwitchingTests` (macOS): `AppLauncher` on a bundle without Halo (or with `-SuiteHideApp halo`) reports Halo `missing`; `StoreWatcher.post("recents.json")` reaches an observer within 1 s; a `StoreRecents` behind the recents slot sees another instance's write after the post | a missing app reads as not running, or a cross-process write is never seen |
| SW-3b | `SuiteShellHandOffTests` (macOS): `SuiteAppDelegate` given a hand-off URL calls `host.accept` with the decoded hand-off and settles it with the host's state; given an expired one never calls the host; `LauncherDelegate` given `Cards.design` opens no launcher window and delivers to Design | a hand-off acts twice, or the launcher opens a window for a routed file |
| SW-3c | `SuiteCommandsTests` (Linux): `SwitchMenu.items` gives digits 0–5 once each (the shortcuts are built from them in a loop, so the digits are checked on the model, not as text); a text scan of `Sources/*App/*.swift` and `Sources/SuiteShell/*.swift` other than `SuiteCommands.swift` finds no `.keyboardShortcut` whose modifiers hold both `.control` and `.command`; the `SettingsRoute` and `OpenInMenu` stubs carry "Not connected yet (settings)." and "… (recents-open-in)."; `SuiteCommands.swift` declares `init(app: SuiteApp = .launcher)` | a shortcut clashes or doubles, or a stub is enabled with no reason |
| SW-4a | SJ3, `testOpenRecentBringsAppForward`, `testCrashIsolation` on the dev macOS run, asserting the states above; the audit under each app's key and `afterglow` unchanged | state is lost across switches, Show <App> Window is disabled with no window, or a crash takes another app's document |
| SW-4b | SJ2: each app frontmost with its named window or sheet; the hidden-Halo tile disabled with its sentence | a tile opens the wrong app or nothing |
| SW-4c | SP1 (30 switches, at least 30 samples) and SP2 (each app 20 cold opens) write p50 and p95 to the run's perf JSON; too few samples fail as invalid | marks are missing or too few |
| SW-5 | review: every QB-S1…S9, QB-L9 and QB-SM1…SM6 row of blueprint 7.1 appears once in the rubric with its test name and "report only" | a row is missing or a gate is set before ten runs |
| A-x-1 | each line's `<X>DocumentHostTests` (Linux): the verbs it takes are accepted and others refused "<App> can't do that yet."; `.new` from the app's preset sets the document size it names; the app's journey `testSwitchToMenu` finds Window > Switch To with six items and its own "Show <App> Window"; its menu-count assertions updated in the same PR, its audit counts not raised | a verb is silently ignored, or the app's menus lose an item |

## Quality tests

| quality row | budget | test |
|---|---|---|
| QB-S1 switch to a running app: key event → first frame of the target's key window | p95 ≤ 6 refreshes; report only | SP1 `testSwitchToRunningAppLatency` |
| QB-S2 first open per session: click → first frame | ≤ 700 ms median, ≤ 1 s p95; report only | SP2 `testColdOpenEachApp` |
| QB-SM4 `HandOffCodec` encode + decode | ≤ 0.2 ms (debug ≤ 2 ms) | `Budget+HandOff` |
| QB-L9 a cold launch shows progress | "Opening <App>…" ≤ 100 ms after the command, by the `switch-cold` mark | SW-4c |
| 7.6 no work lost when switching; crash isolation | SJ3's state equal after two switches; Design unchanged after Flare's `SIGKILL` | SJ3, `testCrashIsolation` |
| 6.2 shortcuts | ⌃⌘0–5 bound once, free in every app | `SuiteCommandsTests` |

## Done check

- **Journeys green:** the dev macOS run triggered by SW-4a (`feature-done`)
  is green, with SJ3, `testOpenRecentBringsAppForward` and
  `testCrashIsolation` passing and every app journey still green with the
  adopted menus. SW-4b (#858) and SW-4c (#859) are follow-ups; the contact
  sheet says which waits are still open.
- **Audit zero new:** `afterglow` stays at 0; no app key rises from its
  Switch To menu.
- **Contact sheet:** `Belt-Contact-Sheet: <run link>` on the feature issue,
  one line per journey, Flare's window before and after the two switches
  side by side.
