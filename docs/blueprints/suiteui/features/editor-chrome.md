# Feature packet: editor-chrome

**Feature:** the editor window's chrome: `EditorShell`'s resizable,
collapsible timeline slot, the top bar's outlined items, one `.primary`
action and save status, the transport capsule, status pills with toggle and
warning styles, capsule tabs and the tool rail's colors, each with its rule
behind a contract, a gallery page and journeys.
**Line:** `line:suiteui` · **Wave:** 2 (`waves.md`) · **Lead branch:** `lead/editor-chrome`

**Covers:** #342 (S9 timeline slot, closes with EC-3), #339 (S6 top bar,
EC-4), #340 (S7 transport and pills, EC-6), #341 (S8 tabs and rail, EC-7).
EC-1, EC-2, EC-5, EC-8 to EC-13 have no issue of their own; their PRs say
"Part of the editor-chrome feature" (EC-2 and EC-5 also "Part of #342" and
"Part of #340").

**Depends on:** the suite-harness feature issue (#778). Every task needs
its golden compare and snapshot host (#331, #332), its gallery stub
(`Gallery/GalleryChrome.swift`), `.suiteControl(…role:)` and `.suiteProbes()`
(#775) and `ContractTypes.swift` (#773). No creative-core issue.

**This packet supersedes the "Touch only these files" lists** of #339,
#340, #341 and #342: each gains its contract, gallery and Fake-test files
(review of #765). The task table is the owned-file list.

**App features it unblocks:** Flare F1a #346 and F1b #347 (Flare's window
on `EditorShell` with the timeline slot), Flare F7b #376 (transport), and
Design's and Photo's primary Export and save status (their own `line:design`
and `line:photo` follow-ups once EC-4 lands; neither app changes here).

Blueprint sections: 4.2 (SJ1–SJ8), 4.4 (SP9, SP10), 5.2 (UC5, UC6, UC13,
UC14), 6.2 (timeline slot, save status, transport, tabs rows), 7.1 (QB-S8,
QB-S10), 7.3 (QB-S17, QB-S18), 8.3.

**Files it receives from the harness:** `ToolbarGroup.swift`,
`EditorTopBar.swift`, `EmptyStateView.swift` (identifiers already applied
and registered by SH-5) and the stub `Gallery/GalleryChrome.swift`.

**Building blind.** Only the contracts and the pure halves
(`ShellLayout`, the transport stepping, the pill text) can be reasoned about
without a Mac, and even they compile only in the macOS job (Q1). Check every
SwiftUI API with the `apple-docs` MCP (say so in the PR), copy a SuiteUI
file that builds, and run the contracts by hand on Linux as section 5.1
shows. Raw values only through tokens: the slot tokens
(`timelineSlotMinimum`, `timelineSlotToolbar`, `timelineGrab`) already exist
(SH-2); this feature edits no `Tokens.swift`.

## Journey steps

SJ1–SJ4 in `UITests/SuiteJourneyTests+Chrome.swift` (EC-10), SJ5–SJ8,
SP9 and SP10 in `UITests/SuiteJourneyTests+ChromePanels.swift` (EC-11), on
the `editor`, `editor-plain` and `empty` pages, as section 4.2 writes them:

1. **SJ1** `testEditorShellFitsAtEveryWidth`: widths 880, 1024, 1280, 1440;
   regions inside the window (1 pt slack), no overlap over 1 pt, content ≥
   `contentMinimum.width`, the right panel exactly `editorPanelWidth`;
   `offscreen` and `overlap` 0.
2. **SJ2** `testEditorShellTimelineSlot`: divider up 120 pt, then to the top
   (stops at the canvas's `contentMinimum.height`), double-click collapses
   to the 36 pt toolbar row, double-click restores the last height;
   `editor-plain` has no divider and its canvas fills the shell as today.
   The gallery has no View menu item of its own (Library's View menu holds
   thumbnail sizes), so SJ2 collapses by double-click only.
3. **SJ3** `testTopBarCommandsAndSaveStatus`: New logs `command new`; exactly
   one `suite.controls` entry has `role: "primary"`, it is Export, and its
   frame is the right-most in the bar; Undo is icon-only with label "Undo";
   Redo's entry carries its `unavailableHelp`; save status reads "Saved",
   "Unsaved changes", "Not saved".
4. **SJ4** `testToolRailSelectsAndExplains`: click tool b, then the first
   tool's key on the canvas: log `tool b`, `tool a`; `isSelected` follows;
   the disabled tool's entry has its reason and a click changes nothing.
5. **SJ5** `testTransportPlaysStepsAndLoops`: Play ↔ Pause label; two steps
   log `frame f+2`; at the end, step stays (loop off) or wraps to 0 (loop on);
   timecode `00:01 / 00:02` style; a `frameCount` 0 variant disables every
   button with "Nothing to play.".
6. **SJ6** `testStatusPills`: zoom pill equals `ViewerZoom.percentText`; size
   pill "1920 × 1080"; toggle pill `isSelected` on then off, log
   `toggle onion`; the warning pill shows its triangle and label.
7. **SJ7** `testEmptyStateOffersAction`: title, message, one primary button,
   log `action new`; the variant without an action has no button.
8. **SJ8** `testSegmentedTabsSwitch`: log `tab layers`, then ← gives
   `tab adjust`; the selected tab's `isSelected` is true.
9. **SP9** `testPressLatency`: 60 presses over tools, tabs and transport,
   series `press` (≥ 60 samples). **SP10** `testSlotDragLatency`: velocity
   drag of the divider 300 pt up and back, series `slot-drag`. Report-only.

## Screens and states

| Screen | Empty | Error | Loading |
|---|---|---|---|
| `editor` (shell, bar, rail, canvas, slot, tabs, pills) | `editor-plain`: a shell without a timeline draws exactly today's layout | save status "Not saved" with the warning triangle; the warning pill | none |
| Timeline slot | collapsed: only its 36 pt toolbar row | a drag past either limit clamps; nothing else changes | none |
| Transport capsule | `frameCount` 0: every button disabled with "Nothing to play." | none | none |
| Status pills | no trailing pills: zoom and size only | the warning pill | none |
| `empty` | the variant with no action has no button | none | none |

## Contract slice

EC-1 lands these four files verbatim from
`docs/blueprints/suiteui/contracts/Contracts.swift` (UC5, UC6, UC13, UC14):

```swift
// Contracts/ShellLayingOut.swift: ShellMetrics, ShellColumns, TimelineSlot
public protocol ShellLayingOut: Sendable {
    func columns(windowWidth: Double, metrics: ShellMetrics) -> ShellColumns
    func slot(_ slot: TimelineSlot, dragged dy: Double, available height: Double, metrics: ShellMetrics) -> TimelineSlot
    func toggled(_ slot: TimelineSlot, metrics: ShellMetrics) -> TimelineSlot
}
// Contracts/ToolPicking.swift: ToolFace
public protocol ToolPicking: Sendable {
    func tool(forKey key: Character, in tools: [ToolFace]) -> String?
    func help(for tool: ToolFace) -> String           // "Brush (B)" enabled, the reason disabled
    func violations(in tools: [ToolFace]) -> [String] // empty reason, or a shortcut used twice
}
// Contracts/TransportStepping.swift: TransportState (frame, frameCount, fps, isPlaying, loops), TransportFace
public protocol TransportStepping: Sendable {
    func stepped(_ state: TransportState, by frames: Int) -> TransportState
    func toStart(_ state: TransportState) -> TransportState
    func toEnd(_ state: TransportState) -> TransportState
    func face(_ state: TransportState) -> TransportFace
}
// Contracts/StatusPillComposing.swift: PillStyle (.plain, .toggle(isOn:), .warning), StatusPill
public protocol StatusPillComposing: Sendable {
    func pills(zoom: Double, documentSize: PlaneExtent, trailing: [StatusPill]) -> [StatusPill]
}
```

Public API this feature adds (additive; every existing call compiles):

```swift
EditorShell(..., timeline: (some View)? = nil)            // EC-3; nil = today's layout
EditorBarItem(..., prominence: .primary)                   // EC-4; registers role "primary"
EditorSaveStatus(.saved | .unsaved | .failed)              // EC-4
TransportCapsule(state: TransportState, onPlay:, onStep:, onStart:, onEnd:, onLoop:)  // EC-5
StatusPillStyle(_ style: PillStyle)   // EC-6: the contract's PillStyle maps onto the StatusPillStyle already on dev
// ViewerStatusBar keeps its init and trailing slot (toggle and warning pills already draw, #522);
// EC-6 routes its zoom and size text through SuiteStatusPills and registers toggle pills
```

**Views with no contract** (5.2): `EmptyStateView`, `SegmentedTabs`,
`SurfaceCard`, `GlassPanel`, `EditorTopBar`'s save status. SJ3, SJ7, SJ8 and
the goldens prove them.

**Slot shortcut.** Section 6.2 left the collapse shortcut to this packet.
Checked against the HIG's standard shortcuts (apple-docs,
`/design/human-interface-guidelines/keyboards`, 2026-10-14): ⌥⌘T is Show or
Hide Toolbar, and the HIG asks for custom shortcuts only on the most
frequent app commands and against Control and Option modifiers. So
`EditorShell` ships **no default shortcut**: it exposes the toggle, and a
host that wants one names it in its own View menu (Flare F1a decides).

## Pseudocode

```
SuiteShellLayout : ShellLayingOut                                 # EC-2
  columns(w, m): content = w - m.leading - m.trailing
                 fits = content >= m.contentMinimum.width
                 return (m.leading, max(content, m.contentMinimum.width), m.trailing, fits)
  slot(s, dy, available, m): guard !s.collapsed else s
                 maxH = max(available - m.contentMinimum.height, m.slotMinimum)
                 h = clamp(s.height - dy, m.slotMinimum ... maxH)  # dy up is negative
                 return (h, collapsed: false, lastOpenHeight: h)
  toggled(s, m): collapsed ? (s.lastOpenHeight, open) : (m.slotToolbar, collapsed, lastOpenHeight: s.height)

EditorShell(timeline:)                                            # EC-3
  VStack { canvas row; if timeline { divider(grab zone timelineGrab, row-resize cursor, double-click toggles);
           slot(height from @State TimelineSlot, toolbar row first) } }
  divider drag: probe "slot-drag" sample per change; one TimelineSlot update per change
  .suiteProbes() on the shell root

SuiteTransport : TransportStepping                                # EC-5
  last = max(frameCount - 1, 0)
  stepped(s, n): guard frameCount > 0 else s
                 f = s.frame + n; loops ? ((f mod frameCount) + frameCount) mod frameCount : clamp(f, 0...last)
  face(s): playTitle = isPlaying ? "Pause" : "Play"; help = frameCount > 0 ? nil : "Nothing to play."
           timecode = mm:ss(frame / fps) + " / " + mm:ss(frameCount / fps)     # fps <= 0 -> "--:--"

SuiteStatusPills : StatusPillComposing                            # EC-6
  zoom.isFinite && zoom > 0 ? ViewerZoom.percentText(zoom) : "–"; then "W × H" (Int, rounded); then trailing

SuiteToolPicking : ToolPicking                                    # EC-8
  tool(key): first enabled tool whose shortcut lowercased == key lowercased
  violations: ids with unavailableHelp == "" ∪ ids sharing a shortcut (case-insensitive), sorted
```

## Tasks

Every task is one PR to `dev`: at most 400 changed lines and 15 files,
label `fast-lane`, body lines `Belt-Lead:`, `Feature: editor-chrome`,
`Fast-Check: pass`, `Head:`. EC-13 carries `feature-done`. Every component
task's snapshot test also calls `assertGolden` through `SnapshotHost` in the four appearances (QB-V5; editor screens in Dark and Dark + Increase Contrast), so EC-12 and EC-13 have recorded actuals to commit. Every component
task registers its controls with `.suiteControl` (with a test that the
entry's reason equals its `.help`), emits its probe series, and moves its
fades to `suiteReduceMotion` with `fade-start`/`fade-end` marks. No task
edits `docs/c4/model.json`, `docs/design.md`, `Tokens.swift` or
`project.yml`, and none edits a blueprint or `waves.md`: this packet edits
no shared doc, so it has no docs task.

| id | issue | what | owned files | depends on |
|---|---|---|---|---|
| EC-1 | – | The four chrome contracts and their Fakes | `Sources/SuiteUI/Contracts/ShellLayingOut.swift`, `Sources/SuiteUI/Contracts/ToolPicking.swift`, `Sources/SuiteUI/Contracts/TransportStepping.swift`, `Sources/SuiteUI/Contracts/StatusPillComposing.swift`, `Tests/SuiteUITests/ChromeFakeTests.swift` | – |
| EC-2 | #342 (part) | `SuiteShellLayout`: columns and slot clamping (QB-S18) | `Sources/SuiteUI/ShellLayout.swift`, `Tests/SuiteUITests/ShellLayoutTests.swift` | EC-1 |
| EC-3 | #342 (closes) | `EditorShell(timeline:)`: divider, drag, collapse and restore, `slot-drag` series, `.suiteProbes()` | `Sources/SuiteUI/EditorShell.swift`, `Tests/SuiteUITests/EditorShellTests.swift`, `Tests/AppSnapshotTests/SuiteShellSnapshots.swift` | EC-2 |
| EC-4 | #339 | `EditorBarItem` outlined and `.primary` (role "primary"), `EditorSaveStatus`, `EmptyStateView`'s button in the primary style | `Sources/SuiteUI/EditorTopBar.swift`, `Sources/SuiteUI/EmptyStateView.swift`, `Tests/AppSnapshotTests/SuiteTopBarSnapshots.swift`, `Tests/AppSnapshotTests/SuiteEditorBarDimmingTests.swift` | – |
| EC-5 | #340 (part) | `TransportCapsule` and `SuiteTransport` | `Sources/SuiteUI/TransportCapsule.swift`, `Tests/SuiteUITests/TransportTests.swift`, `Tests/AppSnapshotTests/SuiteTransportSnapshots.swift` | EC-1 |
| EC-6 | #340 (closes) | `SuiteStatusPills` behind `ViewerStatusBar`'s zoom and size text; `PillStyle` maps onto the existing `StatusPillStyle`; toggle pills register and emit `press` | `Sources/SuiteUI/ViewerStatusBar.swift`, `Tests/SuiteUITests/StatusPillTests.swift`, `Tests/AppSnapshotTests/SuiteStatusSnapshots.swift` | EC-1 |
| EC-7 | #341 | `SegmentedTabs` as a capsule (still a `Picker`), rail colors, tab fades | `Sources/SuiteUI/SegmentedTabs.swift`, `Sources/SuiteUI/ToolbarGroup.swift`, `Tests/AppSnapshotTests/SuiteTabsSnapshots.swift` | – |
| EC-8 | – | `SuiteToolPicking` behind `ToolbarGroup`: key pick, help, violations; `press` series and tool fades | `Sources/SuiteUI/ToolbarGroup.swift`, `Tests/SuiteUITests/ToolPickingTests.swift` | EC-1, EC-7 |
| EC-9 | – | The `editor`, `editor-plain` and `empty` gallery pages, their log, page switches (save state, warning, `frameCount` 0, Reduce Motion) and the `-SuiteGalleryFakes` path | `Sources/SuiteUI/Gallery/GalleryChrome.swift` | EC-3, EC-4, EC-5, EC-6, EC-8 |
| EC-10 | – | SJ1, SJ2, SJ3, SJ4 | `UITests/SuiteJourneyTests+Chrome.swift` | EC-9 |
| EC-11 | – | SJ5, SJ6, SJ7, SJ8, SP9, SP10 | `UITests/SuiteJourneyTests+ChromePanels.swift` | EC-9 |
| EC-12 | – | Baselines from the CI artifact: shell, top bar and transport in the four appearances | `Tests/AppSnapshotTests/Golden/chrome/` (12 PNGs) | EC-3, EC-4, EC-5, EC-6, EC-7, EC-8 and their CI run |
| EC-13 | – | Baselines: status pills, tabs and rail in the four appearances; `feature-done` | `Tests/AppSnapshotTests/Golden/chrome/` (12 PNGs) | EC-6, EC-7, EC-8, EC-10, EC-11, EC-12 |

Sizes: EC-1 ~250 lines; EC-2 ~180; EC-3 ~300; EC-4 ~250; EC-5 ~300; EC-6
~200; EC-7 ~180; EC-8 ~200; EC-9 ~350; EC-10 ~300; EC-11 ~350; EC-12 and
EC-13 PNGs only. EC-12 and EC-13 split the goldens so neither passes 15
files; `Golden/chrome/` is this feature's folder, and the two PRs never
hold the same PNG.

Inside the feature: EC-7 and EC-8 share `ToolbarGroup.swift`, so EC-8
waits for EC-7 (it waits for EC-1 anyway, so the chain is no longer). EC-10
and EC-11 each own their journey file (`project.yml` compiles
`UITests/SuiteJourneyTests*.swift`), so they build side by side. EC-12
needs the shell, top bar and transport snapshot tests recording actuals on
a CI run, and also EC-6, EC-7 and EC-8: the shell sample fills its rail,
panel and status slots with `ToolbarGroup`, `SegmentedTabs` and
`ViewerStatusBar`, so its PNGs are final only once those three merge. EC-13
needs the rest of them, all of EC-12's PNGs (its check
reads every `chrome` golden) and both journey tasks, because the
`feature-done` run it triggers must show SJ1–SJ8 green.
`SurfaceCard.swift` and `GlassPanel.swift` are this feature's in wave 2 but
no task changes them.

## Build waves

- Wave 1: EC-1, EC-4, EC-7. Independent in this wave: all three.
- Wave 2: EC-2, EC-5, EC-6, EC-8. Independent in this wave: all four.
- Wave 3: EC-3. Independent in this wave: EC-3 alone.
- Wave 4: EC-9, EC-12. Independent in this wave: both.
- Wave 5: EC-10, EC-11. Independent in this wave: both.
- Wave 6: EC-13 (`feature-done`, final; no shared doc to edit).

Longest chain: EC-1 → EC-2 → EC-3 → EC-9 → EC-10 → EC-13 (6).
Chain of 6: `SuiteShellLayout` (EC-2) implements EC-1's `ShellLayingOut`,
`EditorShell` (EC-3) calls `SuiteShellLayout`, `GalleryChrome.swift` (EC-9)
builds `EditorShell(timeline:)`, SJ1–SJ4 (EC-10) drive EC-9's pages, and
EC-13's `feature-done` run must show those journeys green.

## Acceptance test per task

| id | test | fails when |
|---|---|---|
| EC-1 | `ChromeFakeTests`: each Fake gives `main.swift`'s literal result, including its deliberate gap (no slot clamp, no duplicate-shortcut check, no wrap and frame text, raw zoom text) | a Fake changes behaviour, so the live tests stop proving the gap is closed |
| EC-2 | `ShellLayoutTests.columnsEveryWidth` (QB-S18): every 40 pt from 600 to 2,560, content never under its minimum, `fits` false exactly under the three minimums, and while `fits` the three add up to the width; `slotClamps`: a drag past the top stops where the canvas keeps `contentMinimum.height`, below `timelineSlotMinimum` stops there; collapse then restore returns the last open height | a column sum is off by more than 0.001, or a clamp lets the canvas shrink |
| EC-3 | `EditorShellTests`: a shell built without `timeline:` has the same layout values as today (the existing assertions unchanged); with a slot, the window minimum still fits (QB-S23); `SuiteShellSnapshots` records the slot open, collapsed and dragged in Dark and Dark + Increase Contrast; `SuiteEditorShellSnapshots`' PNGs are byte-identical | a no-timeline shell changes, or the minimum no longer fits |
| EC-4 | `SuiteEditorBarDimmingTests`: the primary item's hover lightens and never greys, a disabled primary dims to 40 %; `SuiteTopBarSnapshots` records outlined, primary and the three save states; a unit test that the primary registers `role: "primary"` and an outlined item `role: nil`; the save status's accessibility labels are "Saved", "Unsaved changes", "Not saved" | hover greys, the role is wrong, or a label differs |
| EC-5 | `TransportTests`: from frame 47 of 48 a step stays at 47 with loop off and goes to 0 with loop on; step −1 from 0 wraps to 47 with loop on; `frameCount` 0 gives every face's help "Nothing to play." and a step changes nothing; timecode at 24 fps for frame 24 of 48 is `00:01 / 00:02`; `fps` 0 gives `--:--` with no division; each button's entry reason equals its `.help` | a wrap, a clamp or the timecode is wrong, or a zero divides |
| EC-6 | `StatusPillTests`: zoom 2 gives "200%" (`ViewerZoom.percentText` unchanged), NaN and 0 give "–", 1920 × 1080 gives "1920 × 1080", trailing pills keep their order; `ViewerStatusBar` takes its text from `SuiteStatusPills` (a bar built with zoom NaN shows "–", which today's code does not); `StatusPillStyle(PillStyle)` maps all three cases; a toggle pill's entry reason equals its `.help`; the existing `SuiteStatusSnapshots` PNGs (toggle and warning pills from #522) are byte-identical | the bar formats zoom itself, a style maps wrong, or an existing pill's look changes |
| EC-7 | `SuiteTabsSnapshots` records the capsule tabs and the rail's selected, hover and disabled colors; a unit test that `SegmentedTabs` still builds a `Picker` (its body type) | the tabs stop being a `Picker` underneath |
| EC-8 | `ToolPickingTests`: key `b` picks the enabled Brush, never a disabled tool; `help` is "Brush (B)" or the reason; two tools on `B` and one with an empty reason are violations; a `ToolbarGroup` tool's registered reason equals its `.help` | a disabled tool is picked by key, or a duplicate passes |
| EC-9 | The page builds both with live rules and with `-SuiteGalleryFakes`; SJ0 (harness) opens `editor`, `editor-plain` and `empty` with `violations()` empty | a control on the page is unregistered or disabled without a reason |
| EC-10 | SJ1–SJ4 pass on the CI run | any assert in 4.2's rows |
| EC-11 | SJ5–SJ8 pass; SP9 and SP10 each produce ≥ 60 samples (report-only) | an assert fails or a series is short |
| EC-12, EC-13 | The next CI run's `Golden*` checks pass against the committed baselines with no known issues left for `chrome` | a baseline is missing or differs |

## Quality tests

| quality row | budget | test |
|---|---|---|
| QB-S8 press to selected state drawn | p95 ≤ 1 frame late (placeholder 2) | SP9 `testPressLatency`, series `press` |
| QB-S10 slot divider drag | p95 ≤ 2 (placeholder 3) | SP10 `testSlotDragLatency`, series `slot-drag` |
| QB-S9 tab and tool fades | 0.14 s ± 1 refresh, 0 under Reduce Motion (report-only) | `fade-start`/`fade-end` marks from EC-7 and EC-8, read in SJ8 and SJ4 with the page switch off and on |
| QB-S17 shell regions | inside, no overlap, panel exactly `editorPanelWidth` | SJ1 |
| QB-S18 column rule | every 40 pt, 600–2,560 | `ShellLayoutTests.columnsEveryWidth` |
| QB-S23 window minimum fits | rail + content minimum + panel ≤ `windowMinimum.width` | `EditorShellTests`, `TokensTests` |
| QB-S24 goldens | 2/255, ≤ 0.5 % | EC-12, EC-13 |

## Done check

- **Journeys green:** the macOS run on `dev` triggered by EC-13 is green:
  SJ1–SJ8, SP9, SP10 (report-only), SJ0 and SJ25 on the chrome pages.
- **Audit zero new:** `suiteui` stays 0 for every check; Design's and Photo's
  counts do not rise (their `EditorShell` and `EditorTopBar` change with
  this feature, so read their `audit-*.json` on the same run, section 7.2).
- **Contact sheet:** `Belt-Contact-Sheet: <run link>` on the feature issue,
  listing `suiteui-editor-*`, `suiteui-editor-plain-*`, `suiteui-empty-*`
  and the Design and Photo editor shots, which change with the bar and pills.
