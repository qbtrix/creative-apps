# switching lead record

Issue: #1507 · Packet: docs/blueprints/suite/features/switching.md
Run: act-1a146f2912a-581f · Session: claude/switching-feature-lead-jm0d5f · Started: 2026-10-16T23:00Z
Stage: 3 wave 2 (SW-3c in review)
Base: origin/dev 88c4584b (after #1883 merged as 7d068e10)
Next: SW-3c PR in review; then SW-3d (SwitcherEntries, the switcher bridge), once SW-3c merges and editor-in-window's AppSwitcherState is on dev

Brief deviations (decided here, see Decisions): base is `dev`, not `main`; the status channel is this branch, not `lead/switching`.

## Slices
This packet has no `## Slices` table: the v2 loop applies. The feature is one unit.

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| SW-1 | feature | 1 | SwitchPlanner, SwitchMenu (six Switch To items), LaunchArguments | Sources/SuiteModel/Switching/{SwitchPlanner,SwitchMenu,LaunchArguments}.swift; Tests/SuiteModelTests/Switch{RunState,Menu,LaunchArguments}Tests.swift | SwitchRunStateTests, SwitchMenuTests, SwitchLaunchArgumentsTests | #1747 (merged b267d006) | merged |
| SW-2 | feature | 1 | StoreHandOffs: send, receive, settle, expire, sweep | Sources/SuiteModel/HandOff/StoreHandOffs.swift; Tests/SuiteModelTests/HandOffStoreTests.swift; Budget+HandOff.swift | HandOffStoreTests, Budget+HandOff | #1791 (merged c512a7e8) | merged |
| SW-5 | feature | 1 | QB-S and QB-SM rows of blueprint 7.1 into docs/review-rubric.md section 6 | docs/review-rubric.md | review (rows present once, "report only") | #1816 (merged 7dd54a00) | merged |
| SW-3a | feature | 2 | AppLauncher, StoreWatcher, live switching slot, recents watcher | Sources/SuiteShell/{AppLauncher,StoreWatcher}.swift; Live/{SwitchingSlot,RecentsSlot}.swift | SuiteShellSwitchingTests (macOS) | #1833 (merged 7d022431) | merged |
| SW-3b | feature | 2 | HandOffTransport, SuiteAppDelegate, live hand-off slot, the launcher router | Sources/SuiteShell/{HandOffTransport,SuiteAppDelegate}.swift; Live/HandOffSlot.swift; Sources/AfterGlowApp/LauncherRouter.swift | SuiteShellHandOffTests (macOS) | #1883 (merged 7d068e10) | merged |
| SW-3c | feature | 3 | SuiteCommands Switch To from SwitchMenu, .suiteApp(_:host:) | Sources/SuiteShell/{SuiteCommands,SuiteAppModifier}.swift; SuiteAppDelegate.swift (registry); AppLauncher.swift (static run state) | SuiteCommandsTests (Linux), LauncherMenuStubTests | this PR | in review |
| SW-3d | feature | 4 | SwitcherEntries and the switcher bridge | Sources/SuiteModel/Switching/SwitcherEntries.swift; Tests/SuiteModelTests/SwitcherEntriesTests.swift; Sources/SuiteShell/SuiteSwitcherBridge.swift | SwitcherEntriesTests | – | waits on SW-3c, editor-in-window |
| SW-4a | feature | 5 | Journeys SJ3, testOpenRecentBringsAppForward, testCrashIsolation (feature-done) | UITests/AfterGlowJourneyTests+Switch.swift | dev macOS run | – | waits on SW-3c, SW-3d, home HM-2b #845 and the adoptions |
| SW-4b | feature | 5 | Journey SJ2 (follow-up #858) | UITests/AfterGlowJourneyTests+New.swift | dev macOS run | – | follow-up, outside the done check |
| SW-4c | feature | 5 | SP1, SP2 and budget constants (follow-up #859) | UITests/AfterGlowJourneyTests+PerfSwitch.swift, +BudgetsSwitch.swift | perf JSON | – | follow-up, waits on #782 |
| A-FL-1 | #861 | line:flare | FlareModel SuiteDocumentHost, FlareApp adoption | Sources/FlareModel/FlareDocumentHost.swift and FlareApp | FlareDocumentHostTests | – | owned by flare line |
| A-DE-1 | #862 | line:design | DesignModel SuiteDocumentHost, DesignApp adoption | Sources/DesignModel/DesignDocumentHost.swift and DesignApp | DesignDocumentHostTests | – | owned by design line |
| A-PH-1 | #863 | line:photo | PhotoModel SuiteDocumentHost, PhotoApp adoption | Sources/PhotoModel/PhotoDocumentHost.swift and PhotoApp | PhotoDocumentHostTests | – | owned by photo line |
| A-LI-1 | #864 | line:library | LibraryModel SuiteDocumentHost, LibraryApp adoption | Sources/LibraryModel/LibraryDocumentHost.swift and LibraryApp | LibraryDocumentHostTests | – | owned by library line |
| A-HA-1 | #865 | line:halo | HaloModel SuiteDocumentHost, HaloApp adoption | Sources/HaloModel/HaloDocumentHost.swift and HaloApp | HaloDocumentHostTests | – | owned by halo line |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|
| – | – | – | – | – | – |

No review has run: no PR has merged and no scoped run exists for this feature yet.

## Decisions
- v2 loop: the packet has no `## Slices` table, so rules 6, 13, 14, 15 and 17 (slice done, build-the-check, mutations, feel gate, Mac finish) do not apply.
- Base `dev`, not `main`: the lead contract says base dev, CLAUDE.md says never target main, and the fast lane only merges PRs based on dev. The brief's "Integration branch: main" is not followed. Its base SHA check (HEAD = 6baabdb) matched `origin/main`; dev is at caa3c66.
- Status channel: RECORD.md and timeline.tsv go to this run's designated branch, `claude/switching-feature-lead-jm0d5f`, not `lead/switching`. The system instructions forbid pushing to other branches without permission, so Belt has to read that branch.
- One branch, one PR at a time: the designated branch is the only one this session may push. The next task's PR waits until the previous PR is merged or the branch can be reset.
- SW-1 deviation from the packet's sketch: `SwitchPlanner.action` takes the app as well as the state, because `.refuse(.appMissing(app))` needs it.
- SW-1's Model is Linux-testable; no SwiftUI or AppKit. The macOS build runs on the lane's build-only run.
- `bundle` (wave 1) is still planned. Its BU-1a (`SuiteCommands`) and BU-1b (`LauncherRouter`) stubs are not on dev, so SW-3b and SW-3c stay blocked until bundle merges.
- The swift toolchain was not on this machine; it is installed with `scripts/cloud-setup.sh` (pinned 6.3.3) so `scripts/ci --changed` can run here.

## Open
- The fast lane needs `Fast-Check: pass` on the head: produced by `scripts/ci --changed` here after the toolchain installs.
- Bundle (wave 1) not built: SW-3b and SW-3c wait on it.
- Editor-in-window's AppSwitcherState is needed for SW-3d.
- Home's HM-2b (#845) gates SW-4a.
- The adoption issues A-FL-1 through A-HA-1 belong to their app lines, not to this lead.

## Decisions (wave 2)
- SW-3a is macOS-only Swift that this machine cannot compile. The Linux gate proves the lints and C4 ownership only; the lane's build-only macOS run is the compile check, and a failure comes back to this branch.
- `AppLauncher.runState` reports `.running(windows: 1)` for a running app. The probe that counts real windows is not wired, so "Show <App> Window" can't yet see an app with no window. Known gap for a later task.
- `StoreWatcher` is an enum with static `post` and `observe`, not the instance `observe` the packet sketched: an observer lives as long as its process, so there is nothing for an instance to own.
- `switchingIsLive` flips to true. `SuiteLiveServicesTests` now expects 11 pending members, not 12, and no longer expects a switch to throw "not connected".
- Bundle's stubs (`LauncherRouter.swift`, `SuiteCommands.swift`) are on `dev` already, though bundle's wave file still says "planned". SW-3b and SW-3c are unblocked on that basis. Asked of the supervisor in the PR-side note, not assumed silently.

## Decisions (wave 2, SW-3b)
- SW-3b is macOS-only Swift, unverified on this machine; the lane's build-only run is the compile check.
- The router uses `LauncherServices.shared.routing` (FakeRouting, as the packet says) for the file-to-app rule. The routing slot stays fake until recents-open-in owns it.
- `SuiteAppDelegate` takes its `host`, `receiver` and `app` as public vars; the `.suiteApp(_:host:)` modifier that sets them is SW-3c.
- `SuiteAppDelegate.handle(_:)` is public so the macOS tests can run it without Launch Services.
- The launcher sends a document URL to its app as an open hand-off and opens no window; a hand-off addressed to the launcher has no verb yet and is left alone.
- `SuiteLiveServicesTests` now expects 9 pending members: switching, sending and receiving are live.

## Decisions (wave 2, SW-3c)
- SW-3c is macOS-only Swift for SuiteShell, unverified on this machine; the Linux gate covers the menu wiring as text and the shortcut-clash scan.
- The Switch To items come from `SwitchMenu.items` with a synchronous run-state read (`AppLauncher.state(of:bundle:hidden:)`), since the menu builds without awaiting the actor. Menus rebuild when SwiftUI rebuilds them, so a app that launches while a menu is open shows its new state on the next build.
- `.suiteApp(_:host:)` reaches the delegate through `SuiteAppRegistry.delegate`, which `SuiteAppDelegate.init` sets; the receiver is a `StoreHandOffs` over the support folder.
- Not done here: the `SettingsRoute` and `OpenInMenu` stubs. Settings and Open In aren't in this menu yet, and the settings and recents-open-in features own those stubs from wave 3, so creating them now would add unused code.
- `LauncherMenuStubTests` no longer requires Switch To buttons to be disabled stubs; `SuiteCommandsTests` checks the live wiring instead.

## Decisions (SW-3c fix)
- The lane's macOS build failed on #1943: `AppLauncher.open` called the static `path(of:bundle:)` without `Self.`, after the static run-state refactor. The Linux gate can't compile SuiteShell, so only the macOS build caught it. Fixed on the same branch; the fix is a fast-forward, not a force-push.
- Lesson for the rest of wave 3: before a macOS-only edit, check every call site of a helper that changed from instance to static, by grep, since the Linux gate won't.
