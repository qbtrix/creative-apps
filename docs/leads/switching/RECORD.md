# switching lead record

Issue: #1507 · Packet: docs/blueprints/suite/features/switching.md
Run: act-1a152d6e775-atvh · Session: claude/switching-feature-lead-2qhod5 · Started: 2026-10-18 (earlier runs act-1a150baa312-n5va on claude/switching-feature-lead-kyvcdx, act-1a146f2912a-581f on claude/switching-feature-lead-jm0d5f)
Stage: 4 round 1, blocked on CI #3176 (scoped `suite` runs skip AfterGlowJourneyTests+Switch until it merges, #2971; SW-4a #2989 merged as 531550f)
Base: origin/dev d481419
Next: wait for #3176 (ci/scope-macos-per-app) to merge into dev, then for the next scoped `suite` run on dev that contains it; download ui-screens, snapshots and audit-suite json, run Anatomy round 1 (critic panel, clarity lens), then Belt-Contact-Sheet on #1507. SW-4b (#858) and SW-4c (#859) stay follow-ups

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
| SW-3c | feature | 3 | SuiteCommands Switch To from SwitchMenu, .suiteApp(_:host:) | Sources/SuiteShell/{SuiteCommands,SuiteAppModifier}.swift; SuiteAppDelegate.swift (registry); AppLauncher.swift (static run state) | SuiteCommandsTests (Linux), LauncherMenuStubTests | #1943 (merged 98e5d50f) | merged |
| SW-3d | feature | 4 | SwitcherEntries (model), SuiteSwitcherBridge (the switcher a window shows) | Sources/SuiteModel/Switching/SwitcherEntries.swift; Sources/SuiteShell/SuiteSwitcherBridge.swift; SuiteAppModifier.swift | SwitcherEntriesTests (Linux) | #1977 (merged) | merged |
| SW-4a | feature | 5 | Journeys SJ3, testOpenRecentBringsAppForward, testCrashIsolation (feature-done) | UITests/AfterGlowJourneyTests+Switch.swift | dev macOS run | #2989 | merged 531550f; adoption steps skip until #861, #862, #836, #837 |
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
- Home's HM-2b (#845) closed; it no longer gates SW-4a.
- SW-4a's adoption-dependent steps throw XCTSkip naming #861, #862, #837, #836 until those lines land; their journeys then run in full with no change here.
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

## Decisions (SW-3d)
- SW-3d's model half (SwitcherEntries) and tests are Linux. The bridge is macOS-only and was checked against the Linux gate's lints and C4 ownership only; the lane's build-only run is the compile check.
- The bridge sets `\.suiteSwitcher` through `Scene.environment(_:_:)`, which Apple's docs confirm. Its rows are read when the scene is built and are not refreshed while the window is open (the packet asked for a refresh on `<app>.windows`; that needs a view-level observable and is a known gap).
- The bridge's rows use the switcher's ids (`home` for the launcher), and a click switches through AppLauncher.
- C4: the bridge is added to the shell-apps component.
- Belt-Slice-Done lines don't apply: this packet is v2 (no slices table), so there's no slice to mark.

## Decisions (stage 4, run act-1a152d6e775-atvh)
- Supervisor (#1507, 06:25Z): a green scoped `suite` run on dev that contains 531550f is valid evidence for Anatomy round 1 and the contact sheet. Run 39209833935 (d481419) is that run.
- Supervisor correction (#1507, 06:43Z): scoped `suite` runs skip AfterGlowJourneyTests+Switch (#2971), so 39209833935 carries no switching journeys. Evidence is the first scoped `suite` run on dev after #3176 merges.
- Belt's 07:1xZ stall ping named `lead/switching`; this session may push only `claude/switching-feature-lead-2qhod5`, so RECORD.md and timeline.tsv stay there, as every earlier run of this lead did. Told the supervisor on #1507.
- Status channel is this run's designated branch `claude/switching-feature-lead-2qhod5`, reset to origin/dev d481419 (a fast-forward from main b7e17ed) with this record copied from `claude/switching-feature-lead-kyvcdx`. Brief's base check: HEAD b7e17ed matched `origin/main`; work stays on dev.

## Decisions (wave 5, run act-1a150baa312-n5va)
- The brief's base check (HEAD f7e0350) matched `origin/main`; the work is based on `origin/dev` 507719b, as the earlier run decided.
- SW-4a ships now as the feature-done PR. The launcher-side steps run today: the home's Switch To items and its disabled own item, ⌃⌘1/⌃⌘2 launching Flare and Design as separate processes while the home keeps running, SIGKILL of Flare leaving Design and the home running, and ⌃⌘1 relaunching Flare cold. Steps that need Flare or Design to host suite documents (state kept across switches, the shared switcher, window titles, dirty dot, the strip listing apps) skip naming the adoption and fixture issues, following the home journeys' XCTSkip pattern. The macOS journeys never hold a lane PR (supervisor note), so the dev run is their proof.
- Checked with the apple-docs MCP: `XCUIElement.hover()`, `NSRunningApplication.forceTerminate()`.
- SW-4a is #2989. Its first macOS build (run 39164953207) failed on a dev break that isn't this PR's: #2942's zoom-sweep test still used `TileCanvasView`, which #2907 had removed. #2990 fixed it on dev at 21:35Z. The fix wasn't ported, because CLAUDE.md says not to fix another line's dev break in a PR. dev was merged into the branch once #2990 landed.
- The GitHub proxy re-appends a "Generated by" footer to every PR body this session writes, even on a REST PATCH, so it can't be removed from here. The lane strips attribution from the squash commit.
- SW-4a's macOS build of 8fe3116 passed (run 39170015887), and the lane squash-merged #2989 as 531550f at 22:43Z. The branch restarts from dev after the squash, so this record and the timeline continue on top of the merged history.
- The first full CI run on dev that contains 531550f is 39173775025 (head 46f6ce21, created 22:47Z). At 23:14Z it was still pending with no job started, behind queued dev runs from 22:16Z on. The Anatomy round (lead.md stage 4) reads that run's `ui-screens`, `snapshots` and audit, so it starts when the run finishes. Nothing in switching's files waits on anything else.

## Decisions (stage 4, run act-1a1552a8478-ned8)
- Brief's base check: HEAD b3011ab9 matched `origin/main`. Work stays on dev. This run's status channel is `claude/switching-feature-lead-a254h6`, reset to origin/dev 8f405311, with this record copied from `claude/switching-feature-lead-2qhod5`.
- #3176 merged at 17:16Z, so dev's `suite` scope now runs AfterGlowJourneyTests, the switching journeys among them. #2971 is closed.
- Evidence for Anatomy round 1 and the contact sheet: scoped `suite` run 39292755765 on dev 8f405311, which contains #3176. It was queued at 17:16Z.
- Next: when 39292755765 completes, read its ui-screens, snapshots and audit, run critic round 1 with the first-use clarity lens, then fix or post the contact sheet.
- Run 39292755765 (dev 8f405311) finished at 21:09Z: `macOS (suite)` green, `macOS journeys (suite)` red (report-only). Switching's journeys: SJ3 `testSwitchKeepsEachAppAsLeft` ran its launcher steps (switch-sj3-menu, switch-sj3-home) and skipped the adoption steps; `testOpenRecentBringsAppForward` skipped at its fixture guard; `testCrashIsolation` failed at Switch.swift:98: `XCUIApplication(bundleIdentifier:)` raised "The app representing org.creativesuite.flare could not be found" right after ⌃⌘1, though Flare had started (teardown terminated it). Launch Services hadn't registered the id of an app the launcher had just started by path. The run has no `snapshots` artifact, only ui-screens, xcresult, app-builds and size-report. Audit (afterglow): contrast 0, disabled-dim 0, identifier 10, offscreen 0, overlap 0, unnamed 0. The 10 identifier hits are on the home's filter chips and search field (home's feature, not switching's).
- Fix: the switch journeys wait for the started process and attach by its running bundle's URL (`switched(to:)`), the same `XCUIApplication(url:)` init the harness uses for the launcher. It ships as a fix PR from this branch. Critic round 1 runs on the next scoped `suite` run that contains it.
- Critic round 1 (workflow wf_0001f667-4c1) started at 21:18Z on run 39292755765's screens, lenses clarity, journey, design, layout and controls.
- Round 1 verdict: not clean. 11 confirmed findings, 2 refuted, filed as #3352 to #3358.
- Round 1 fix PR, from this branch:
  - #3352: the home sets its switcher through a new `.suiteSwitcher(current:)` view modifier in SuiteShell, applied in HomeWindow. AfterGlowApp.swift is frozen.
  - #3354: SJ3 sends ⌃⌘0 to Design, and skips on adoption while Design has no Switch To menu.
  - #3355: testCrashIsolation checks Design's window and the strip drop between the SIGKILL and the relaunch.
  - The attach-by-URL fix for line 98.
- #3353 is declined. Packet switching.md line 130 specifies the current app's item as "Show <App> Window", the launcher included, so the finding conflicts with the packet.
- #3356 and #3357 change SuiteWindow and AppSwitcher (SuiteUI, MAC_GATED). #3358 is the home's New row, not switching. They are next, in fix round 2.
- Round 1 fix PR #3359 merged at 22:10Z, after the lane's macOS build 39327605843 passed.
- Fix round 2, from this branch, restarted on dev:
  - #3356: `AppSwitcher.toolbarTrailing` reserves the inspector's column (`inspectorWidth`), so the row ends left of it. SuiteWindow passes the inspector's ideal width when it shows.
  - #3357: an open search field (`isSearching`) reserves `searchFieldRoom` past the buttons, so the row narrows to fit instead of pushing the sidebar toggle into the overflow menu.
  - Tests: AppSwitcherTests `theRowStaysOutOfTheInspectorsColumn` and `anOpenSearchFieldNarrowsTheRow`. The journeys check the row's maxX against the inspector at 880 and 1000 pt, and check that the sidebar toggle stays hittable with search open.
- Next: critic round 2 on the next scoped `suite` run that contains round 2.
