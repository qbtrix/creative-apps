# Feature packet: no-placeholders

**Feature:** a tester's first click never lands on a dead item. The launcher
shows Check for Updates… (disabled, "Not connected yet (updater).") and the
Assets page's Cut, Copy, Add from Clipboard and Select All (each disabled with
"Not connected yet (shared-assets)."). Flare shows beta.2 items that do nothing:
View > Onion Skin and Show Motion Path, Window > Interactions and Assist,
Object > Convert to Symbol and Edit Symbol, and an empty Library tab. This
packet hides them for the beta (their catalog ids stay, unavailable with a
plain reason, so the ledgers never lose an id) and adds `PlaceholderMenuTests`:
a scan of every app's and the launcher's menu sources for a constant
`.disabled(true)`, an empty action `{}` or a `notConnected(` reason, against a
shrink-only baseline. **Settings (⌘,) is left as it is**: whether the beta has
a minimal Settings pane or drops the item is the captain's call, and its line
stays in the baseline with that reason. Halo's empty Help item goes in
`editor-menus` (the suite Help group replaces it).
**Line:** `line:suite` · **Wave:** BG1 (`waves.md`, the beta gaps) · **Lead branch:** `lead/no-placeholders`
**Beta:** captain, 2026-10-21 (beta gaps, suite must-haves). Labels `beta` and `p1` when filed.

**Covers:** `2026-10-21-beta-gaps-combined.md` suite must-have "no placeholder
items" (Check for Updates and Assets; Settings left for the captain) and
Flare's "stub menu items"; suite audit row 4; Flare audit B7; RJ-X64 (new).

**Depends on:** onboarding (built; `AfterGlowApp.swift`). report-problem's
**RP-a** edits the launcher's `AfterGlowApp.swift` first (its Help group), so
NP-2 waits on it.

**Hand-offs:** `FlareCommands.swift` and `FlareWindow+View.swift` are flare
file-flow's, svg-place's and key-select-all's too, and
`FlareCommandCatalog.swift` is every Flare packet's; NP-flare starts after
their last task on them, or before with the owner told.

**Rule 20.** Menus already come from each app's catalog; hiding is one
`menuHidden` set beside each catalog's menu labels, not a second menu.

**C4:** none.

**Clean-room.** Nothing external is read.

Blueprint sections: suite.md 6 (menus), flare.md 3 (menus; beta.2 items).

**Hand-off (beta gaps C1 to C12, suiteui line, cross-line):** the XK4 kernel-gap adopts (clipboard-interop CB-flare, frame-rates FR-flare, anchor-parenting AN-flare, document-setup DS-flare, brush-keys BK-flare) also edit `FlareCommandCatalog.swift` and `FlareCommands.swift`. The slices here that edit those files start after those adopts' slices on the same app have merged, or before them with their lead told; the checker can't see this across lines.

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| NP-a | A ratchet test finds every placeholder menu item in the apps and the launcher against a shrink-only baseline, and the launcher hides Check for Updates and the Assets items. | NP-1, NP-2 | MJ-NP, XJ-NP | report-problem:RP-a (`AfterGlowApp.swift`) |
| NP-flare | Flare's beta.2 menu items and the empty Library tab are hidden with their commands kept and unavailable, only Settings is left in the baseline, RJ-X64 passes, and the feature is built. | NP-3, NP-4, NP-5, NP-6 | FJ-NP, XJ-NP, MJ-NP | NP-a, NP-a; command-state:CS-flare (Flare's catalog and `FlareCommands.swift`); flare menu hand-offs (cross-line) |

**Screen early.** NP-a changes the launcher's menus directly (there is nothing
to stub), so it is the `"ui": true` slice that waits only on report-problem's
RP-a; NP-flare follows it because both edit the baseline.

## Journey steps

`MJ-NP` (`PlaceholderMenuTests`, `FlareMenuVisibilityTests`) on Linux, then:
1. Launcher: open every menu; no Check for Updates, no disabled Assets items; Edit on Home keeps the system's Cut, Copy and Paste (NP-2; `XJ-NP`, `AfterGlowMenusJourneyTests.testNoPlaceholderItems`).
2. Flare: View, Window and Object hold no beta.2 items; the sidebar has no Library tab; every remaining item acts (NP-4; `FJ-NP`, `FlareMenusJourneyTests.testNoBetaTwoItems`).

## Jobs

| job | closes or adds | run | check | fixture |
|---|---|---|---|---|
| RJ-X64 | adds, closes with `suite/no-placeholders` | J | `Tests/RealJobs/suite/no-placeholders/`: open each menu in the launcher and in Flare, click every enabled item once on a sample document | `Bounce.flare` |

Trap: a menu item that looks real and does nothing, which a tester reports as a
bug on day one. Assertion: every enabled item changes the document, opens a
window or sheet, or changes a view state the readout shows; no visible item's
help says it isn't available yet; only Settings is in the baseline. NP-5
writes it.

## Screens and states

`launcher-menu-app` (no Check for Updates), `flare-menu-view` (no onion skin).

## Contract slice

```swift
// Sources/FlareModel/FlareCommandCatalog.swift (NP-3)
extension FlareWorkspace {
    /// Commands whose menu items the beta hides; each stays in the catalog, unavailable with `laterReason`.
    public static let menuHidden: Set<String>   // view.toggle-onion, view.toggle-motion-path, window.interactions,
                                                // window.assist, library.convert-to-symbol, library.exit-symbol
    public static func laterReason(_ id: String) -> String   // "Onion skin comes in a later beta."
}
```

`Tests/placeholder-menu-baseline.txt`: one `<file>: <line>` per allowed
placeholder, shrink-only, read by `PlaceholderMenuTests`.

## Pseudocode

- **Scan.** For each Swift file under `Sources/*App/` and `Sources/AfterGlowApp/`:
  a `Button(` inside a `Commands` body or `CommandMenu` whose trailing closure
  is empty, or whose modifiers include `.disabled(true)` or `notConnected(`,
  is a placeholder; compare against the baseline by file and trimmed line.
- **Hide.** A menu built from the catalog skips ids in `menuHidden`; the
  command still runs headless and answers with its reason, so an agent learns
  why.

## Tasks

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| NP-1 | – | **Check first.** `PlaceholderMenuTests` (SuiteKernelTests, the `CommandPathTests` fixture pattern): a menu `Button` with a constant `.disabled(true)`, an empty `{}` action or a `notConnected(` help fails unless `Tests/placeholder-menu-baseline.txt` lists it; the baseline holds today's lines (Settings with the reason "captain decision") | `Tests/SuiteKernelTests/PlaceholderMenuTests.swift`, `Tests/SuiteKernelTests/Fixtures/Placeholder/Menus.swift.txt`, `Tests/placeholder-menu-baseline.txt`, `Tests/mutations/SuiteKernelTests.PlaceholderMenuTests.json` | – | ~160, 4 |
| NP-2 | – | The launcher drops `LauncherCommandsUpdate` and `LauncherCommandsAssets` from its scene for the beta (the files stay for the updater and assets features); their baseline lines go; `AfterGlowMenusJourneyTests.testNoPlaceholderItems` walks the launcher's menus | `Sources/AfterGlowApp/AfterGlowApp.swift`, `Tests/placeholder-menu-baseline.txt`, `UITests/AfterGlowJourneyTests+Menus.swift` | NP-1 | ~80, 3 |
| NP-3 | – | **Test first.** `FlareMenuVisibilityTests`: the hidden set lists onion skin, motion path, interactions, assist, convert to symbol and edit symbol; each command reports "<Name> comes in a later beta." and stays in `Tests/command-ids/flare.txt`; `FlareCommandCatalog` gains `menuHidden` | `Tests/FlareModelTests/FlareMenuVisibilityTests.swift`, `Sources/FlareModel/FlareCommandCatalog.swift`, `Tests/mutations/FlareModel.FlareCommandCatalog.json` | NP-1 | ~120, 3 |
| NP-4 | – | `FlareCommands` and `FlareWindow+View` skip hidden ids; the Library tab is hidden in the sidebar; their placeholder lines leave the baseline; `FlareMenusJourneyTests.testNoBetaTwoItems` | `Sources/FlareApp/FlareCommands.swift`, `Sources/FlareApp/FlareWindow+View.swift`, `Sources/FlareApp/FlareLibraryPanel.swift`, `Tests/placeholder-menu-baseline.txt`, `UITests/FlareJourneyTests+Menus.swift` | NP-3, NP-2 | ~120, 5 |
| NP-5 | – | RJ-X64's job and check (every enabled item in the launcher's and Flare's menus does something; no disabled item says it isn't available yet) | `Tests/RealJobs/suite/no-placeholders/no-placeholders.jobs.json` | NP-4 | ~50, 1 |
| NP-6 | – | `status: built`; `feature-done` | `docs/blueprints/suite/features/no-placeholders.wave.json` | NP-5 | ~10, 1 |

## Build waves

- Wave 1: NP-1. Independent in this wave: NP-1 alone.
- Wave 2: NP-2, NP-3. Independent in this wave: both.
- Wave 3: NP-4. Independent in this wave: NP-4 alone.
- Wave 4: NP-5. Independent in this wave: NP-5 alone.
- Wave 5: NP-6. Independent in this wave: NP-6 alone.

Longest chain: NP-1 → NP-3 → NP-4 → NP-5 → NP-6 (5). Chain of 5: the ratchet, the launcher, Flare's catalog and menus, then the job and the done task.

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| NP-1 | `PlaceholderMenuTests`: the fixture's three kinds fail; a disabled item with a live reason passes; the real tree passes with the baseline | a new dead item passes | `SuiteKernelTests.PlaceholderMenuTests`: empty-action check dropped → `.emptyActionFails`; baseline read as allow-all → `.baselineOnlyListed` |
| NP-2 | `XJ-NP`; `PlaceholderMenuTests` with the shorter baseline | an item still shows, or the system Edit menu loses Cut, Copy and Paste on Home | – (view) |
| NP-3 | `FlareMenuVisibilityTests` | an id is dropped from the ledger, or a hidden command claims to be available | `FlareModel.FlareCommandCatalog`: hidden command left available → `.hiddenIsUnavailable`; one id missing from the hidden set → `.allBetaTwoHidden` |
| NP-4 | `FJ-NP`; Flare's existing menu journeys with the hidden items removed from their lists | a hidden item still shows or a kept one vanished | – (view) |
| NP-5 | RJ-X64 in the scoped run | a dead item survives | – (job) |
| NP-6 | `scripts/waves render --dry-run` | status not built | – |

## Quality tests

| quality row | budget | test |
|---|---|---|
| no dead controls | no placeholder item outside the baseline; the baseline only shrinks | `PlaceholderMenuTests` |
| ids kept | no id leaves a ledger | `CommandIDLedger` checks (existing) |
| keyboard parity | ⌥⌘O, ⇧⌘M, ⌥⌘A and ⌥⌘K no longer bound in Flare | `FlareMenusJourneyTests` |

## Done check

Per slice (rules 6, 15, 17, 21, 22): NP-a and NP-flare merged-done with their
journeys green in a scoped run and verified after the feel gate (`mouse`: walk
the menus) with their `Mac-Finish:` lines; RJ-X64 green at NP-flare. Settings
stays in the baseline until the captain decides.
