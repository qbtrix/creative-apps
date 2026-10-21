# Feature packet: editor-menus

**Feature:** the editors finally use the suite shell they were built for.
Home, switching, AI access and the live command channel are built, but only
the launcher adds `SuiteCommands` and `AIAccessCommands`, and no editor sets a
`SuiteAppDelegate` or passes `live:` to `.suiteApp`. So inside an editor there
is no Window > Switch To (⌃⌘0 for Home, ⌃⌘1 to 5 for the apps), no Window > AI
Access…, no live MCP channel to the open document, and the home's New Photo
reaches no delegate (#3648). This packet adds one scene modifier,
`.suiteEditor(_:host:live:)`, that applies `.suiteApp` and the three command
groups (Switch To, AI Access, and report-problem's Help group in place of the
system's empty app help, which closes Halo's #1018), and teaches
`SuiteAppDelegate` to open a fresh window when the Dock icon is clicked with
none open (#1081, for every editor). Each editor then adopts it in a few
lines.
**Line:** `line:suite` · **Wave:** BG1 (`waves.md`, the beta gaps) · **Lead branch:** `lead/editor-menus`
**Beta:** captain, 2026-10-21 (beta gaps, suite must-haves). Labels `beta` and `p0` when filed.

**Covers:** `2026-10-21-beta-gaps-combined.md` suite must-have "Switch To / AI
Access menus and the live channel in every editor (#3648)" and Halo's "reopen
window after closing the last one, help items"; suite audit row 5 and
under-specified 1; #3648, #1081, #1018 (close); RJ-X63 (new).

**Depends on:** switching (built: `SuiteCommands`, `AppLauncher`),
afterglow-mcp (built: `LiveCommandChannel`, `AIAccessCommands`).
report-problem **RP-a** gives `SuiteHelpCommands`' signature (EM-1).

**Hand-offs** (cross-line; the lead checks each before its slice starts):
each editor's `<App>App.swift` belongs to that app's file-flow adopt, which
adds `.suiteApp(.x, host:)` (photo/file-flow PF, design/file-flow DF,
flare/file-flow FL, halo/file-flow HF, library/file-flow LF; Photo's is also
suiteui adopt-kernel-unsaved-prompt's, Library's library/spine's). An app
slice starts after that app's file-flow slice on the file has merged and
replaces its `.suiteApp(...)` line with `.suiteEditor(...)`. If a file-flow
adopt hasn't started, its lead is told the line is this packet's.

**Rule 20.** One modifier and one delegate for every process; no app writes
its own Switch To, AI Access, Help or reopen code. The live channel reuses
each app's catalog document (`HeadlessDocument`), no new adapter.

**C4:** the shell's `shell-adoption` part names `.suiteEditor` (EM-1).

**Clean-room.** Menu names and keys from the suite blueprint and the HIG.

Blueprint sections: suite.md 2.6 (adoption), 6 (menus).

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| EM-a | SuiteShell declares `.suiteEditor` and the delegate's reopen rule, and the launcher-side journeys for an editor are written and skipped. | EM-1, EM-2 | XJ-EM | report-problem:RP-a |
| EM-photo-design | Photo and Design show Switch To, AI Access and the Help group, answer live commands, reopen a window from the Dock, and the home's New Photo opens a photo (#3648). | EM-3, EM-4 | PJ-EM, DJ-EM | EM-a; photo and design file-flow (cross-line) |
| EM-flare-halo | Flare and Halo show Switch To, AI Access and the Help group, answer live commands, and reopen a window from the Dock; Halo's empty Help item is gone (#1018, #1081). | EM-5, EM-6 | FJ-EM, HJ-EM | EM-a; flare and halo file-flow (cross-line) |
| EM-library | Library shows Switch To, AI Access and the Help group, answers live commands on its catalog and reopens its window from the Dock, RJ-X63 passes in all five editors, and the feature is built. | EM-7, EM-8, EM-9, EM-10 | LJ-EM, PJ-EM, DJ-EM, FJ-EM, HJ-EM | EM-a; library file-flow and spine (cross-line), every app slice |

**Screen early.** EM-a is the `"ui": true` contract slice (the modifier is the
screen piece); each app slice adopts it on the real menus. The app slices
wait only on EM-a and on their app's file-flow adopt (cross-line), so they run
side by side.

**#3648.** The home's New Photo hands a create request to Photo; with no
`SuiteAppDelegate` nobody accepts it. EM-3 closes it and its journey step
covers it.

## Journey steps

`MJ-EM` (`SuiteEditorReopenTests`) on Linux, then per app on the scoped run:
1. In the editor press ⌃⌘0: Home comes forward; ⌃⌘3 (Photo) from Design opens Photo (EM-3 to EM-7).
2. Window > AI Access… opens the access list; a granted client's `afterglow run --live <app> <id>` changes the open document (EM-3 to EM-7).
3. Help shows Report a Problem… and Beta Notes, and no empty app help item (EM-6 for Halo's #1018).
4. Close the last window, click the Dock icon: a new window opens (EM-2; #1081).
5. Photo: from Home, New Photo opens a new document in Photo (EM-3; #3648).
Journeys: `PJ-EM` to `LJ-EM`, `<App>SuiteMenusJourneyTests.testSuiteMenus`.

## Jobs

| job | closes or adds | run | check | fixture |
|---|---|---|---|---|
| RJ-X63 | adds, closes with `suite/editor-menus` | J | `Tests/RealJobs/suite/editor-menus/`: in each editor, ⌃⌘0, Window > AI Access…, one live command, close the last window and click the Dock icon | each app's sample document |

Trap: an editor that looks finished but strands the tester (no way back to
Home, no AI access, a closed window that never comes back). Assertion: in all
five, Home is frontmost after ⌃⌘0, the AI Access window opens, the live
command's change shows in the document, and a window exists after the Dock
click. Mutation: `SuiteModel.ReopenRule` (`.reopensOnlyWhenNone`). EM-8
writes it; EM-9 enables it.

## Screens and states

`<app>-menu-window-switch-to` and `<app>-menu-help` for each editor.

## Contract slice

```swift
// Sources/SuiteShell/SuiteEditorScene.swift (EM-1)
extension Scene {
    /// `.suiteApp(app, host:, live:)` plus Switch To, AI Access and the Help group (replacing `.help`).
    @MainActor public func suiteEditor(_ app: SuiteApp, host: any SuiteDocumentHost, live: LiveCommandChannel?) -> some Scene
}
// Sources/SuiteModel/Switching/ReopenRule.swift (EM-1 stub, EM-2 body). Linux-safe.
public enum ReopenRule { public static func shouldOpenWindow(visibleWindows: Int, launchedHidden: Bool) -> Bool }
// Sources/SuiteShell/SuiteAppDelegate.swift (EM-2)
//   open func applicationShouldHandleReopen(_:hasVisibleWindows:) -> Bool   // asks ReopenRule, then openWindow()
//   public var openWindow: (@MainActor () -> Void)?                          // set by .suiteEditor from the scene
```

## Pseudocode

- **Reopen.** On a Dock click with no visible window and the app not launched
  hidden for a hand-off, call the scene's `openWindow` (the window group's
  default id, or Library's `Window` id); otherwise let the system do nothing.
- **Help.** `.commands { CommandGroup(replacing: .help) { SuiteHelpCommands(app:) } }`.
- **Live.** `LiveCommandChannel(app:, document: { the frontmost window's
  catalog document }, apply: { its window applies the result })`; started by
  `.suiteApp`, so AI Access lists the app once it's running.

## Tasks

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| EM-1 | – | **Checks first.** `SuiteEditorReopenTests` (the reopen decision: no visible window and not launching hidden opens one; a hidden launch for a hand-off doesn't) written, disabled; `.suiteEditor(_:host:live:)` applies `.suiteApp` and adds `SuiteCommands(app:)`, `AIAccessCommands(app:)` and `SuiteHelpCommands(app:)` (replacing `.help`); the adoption part names it | `Sources/SuiteShell/SuiteEditorScene.swift`, `Sources/SuiteModel/Switching/ReopenRule.swift`, `Tests/SuiteModelTests/SuiteEditorReopenTests.swift`, `docs/c4/parts/creative-apps/suite-shell/shell-adoption.json` | – | ~170, 4 |
| EM-2 | – | `SuiteAppDelegate` gains `applicationShouldHandleReopen` and an `openWindow` action the scene registers; `ReopenRule` body; turns on `SuiteEditorReopenTests` | `Sources/SuiteShell/SuiteAppDelegate.swift`, `Sources/SuiteModel/Switching/ReopenRule.swift`, `Tests/SuiteModelTests/SuiteEditorReopenTests.swift`, `Tests/mutations/SuiteModel.ReopenRule.json` | EM-1 | ~120, 4 |
| EM-3 | – | Photo: `@NSApplicationDelegateAdaptor(SuiteAppDelegate.self)` and `.suiteEditor(.photo, host:, live:)` with a `LiveCommandChannel` over its catalog's document; the home's New Photo now reaches the delegate and opens a 1920 × 1080 document (#3648); `PhotoSuiteMenusJourneyTests` (⌃⌘0 brings Home forward, Window > AI Access… opens, a live `afterglow` call reaches the open document, closing the last window then the Dock icon opens a new one) | `Sources/PhotoApp/PhotoApp.swift`, `UITests/PhotoJourneyTests+SuiteMenus.swift` | EM-2 | ~140, 2 |
| EM-4 | – | Design: `@NSApplicationDelegateAdaptor(SuiteAppDelegate.self)` and `.suiteEditor(.design, host:, live:)` with a `LiveCommandChannel` over its catalog's document; Design's own Window menu items stay; `DesignSuiteMenusJourneyTests` (⌃⌘0 brings Home forward, Window > AI Access… opens, a live `afterglow` call reaches the open document, closing the last window then the Dock icon opens a new one) | `Sources/DesignApp/DesignApp.swift`, `UITests/DesignJourneyTests+SuiteMenus.swift` | EM-2 | ~110, 2 |
| EM-5 | – | Flare: `@NSApplicationDelegateAdaptor(SuiteAppDelegate.self)` and `.suiteEditor(.flare, host:, live:)` with a `LiveCommandChannel` over its catalog's document; Flare's pasteboard bridge keeps working; `FlareSuiteMenusJourneyTests` (⌃⌘0 brings Home forward, Window > AI Access… opens, a live `afterglow` call reaches the open document, closing the last window then the Dock icon opens a new one) | `Sources/FlareApp/FlareApp.swift`, `UITests/FlareJourneyTests+SuiteMenus.swift` | EM-2 | ~110, 2 |
| EM-6 | – | Halo: `@NSApplicationDelegateAdaptor(SuiteAppDelegate.self)` and `.suiteEditor(.halo, host:, live:)` with a `LiveCommandChannel` over its catalog's document; File > New Window stays in the File menu (#1081) and the system's Halo Help item is replaced by the suite's Help group (#1018); `HaloSuiteMenusJourneyTests` (⌃⌘0 brings Home forward, Window > AI Access… opens, a live `afterglow` call reaches the open document, closing the last window then the Dock icon opens a new one) | `Sources/HaloApp/HaloApp.swift`, `UITests/HaloJourneyTests+SuiteMenus.swift`, `Sources/HaloApp/HaloFileMenu.swift` | EM-2 | ~150, 3 |
| EM-7 | – | Library: `@NSApplicationDelegateAdaptor(SuiteAppDelegate.self)` and `.suiteEditor(.library, host:, live:)` with a `LiveCommandChannel` over its catalog's document; its single `Window` scene reopens by id; `LibrarySuiteMenusJourneyTests` (⌃⌘0 brings Home forward, Window > AI Access… opens, a live `afterglow` call reaches the open document, closing the last window then the Dock icon opens a new one) | `Sources/LibraryApp/LibraryApp.swift`, `UITests/LibraryJourneyTests+SuiteMenus.swift` | EM-2 | ~120, 2 |
| EM-8 | – | RJ-X63's job folder (the five editors' suite menus, by the live channel and the journeys' readouts) | `Tests/RealJobs/suite/editor-menus/editor-menus.jobs.json` | – | ~40, 1 |
| EM-9 | – | RJ-X63's check enabled; the AfterGlow every-control journey lists the editors' new menu ids | `Tests/RealJobs/suite/editor-menus/editor-menus.jobs.json`, `UITests/AfterGlowJourneyTests+EveryControl.swift` | EM-3, EM-4, EM-5, EM-6, EM-7, EM-8 | ~60, 2 |
| EM-10 | – | `status: built`; `feature-done` | `docs/blueprints/suite/features/editor-menus.wave.json` | EM-9 | ~10, 1 |

## Build waves

- Wave 1: EM-1, EM-8. Independent in this wave: both.
- Wave 2: EM-2. Independent in this wave: EM-2 alone.
- Wave 3: EM-3, EM-4, EM-5, EM-6, EM-7. Independent in this wave: all.
- Wave 4: EM-9. Independent in this wave: EM-9 alone.
- Wave 5: EM-10. Independent in this wave: EM-10 alone.

Longest chain: EM-1 → EM-2 → EM-3 → EM-9 → EM-10 (5). Chain of 5: the modifier first, the delegate's rule, then each app's adoption before the job.

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| EM-1 | compiles; the launcher's menus unchanged | a group the editors need is missing | – (stubs) |
| EM-2 | `SuiteEditorReopenTests` | a Dock click with no window does nothing, or a hidden hand-off launch shows a window | `SuiteModel.ReopenRule`: hidden-launch check dropped → `.handOffStaysHidden`; visible-window check inverted → `.reopensOnlyWhenNone` |
| EM-3 | `PJ-EM` | a menu is missing, the live channel can't reach the document, or no window comes back | – (adoption; EM-3's plan covers the reopen rule) |
| EM-4 | `DJ-EM` | a menu is missing, the live channel can't reach the document, or no window comes back | – (adoption; EM-3's plan covers the reopen rule) |
| EM-5 | `FJ-EM` | a menu is missing, the live channel can't reach the document, or no window comes back | – (adoption; EM-3's plan covers the reopen rule) |
| EM-6 | `HJ-EM` | a menu is missing, the live channel can't reach the document, or no window comes back | – (adoption; EM-3's plan covers the reopen rule) |
| EM-7 | `LJ-EM` | a menu is missing, the live channel can't reach the document, or no window comes back | – (adoption; EM-3's plan covers the reopen rule) |
| EM-8 | `scripts/jobs check` | the job names a menu the editors lack | – (job) |
| EM-9 | RJ-X63 in the scoped run | an editor lacks a menu | – (job) |
| EM-10 | `scripts/waves render --dry-run` | status not built | – |

## Quality tests

| quality row | budget | test |
|---|---|---|
| render: opening Window and Help menus | no window body re-render | each app's `RenderBudget*` suite (unchanged counts) |
| no dead controls | every new menu item acts | `AfterGlowJourneyTests+EveryControl` |
| keyboard parity | ⌃⌘0 to ⌃⌘5 in every editor | `<App>SuiteMenusJourneyTests` |
| one copy | no app file declares Switch To, AI Access or Help items | `scripts/check-dup-views` (existing) |

## Done check

Per slice (rules 6, 15, 17, 21, 22): EM-a green with `Mutate:` clean; each app
slice merged-done with its journey green in a scoped run, verified after the
feel gate (`mouse`: reach Home, AI Access and Help by mouse; reopen from the
Dock) and its `Mac-Finish:` line; RJ-X63 green at EM-library. Then
`Belt-Contact-Sheet:`.
