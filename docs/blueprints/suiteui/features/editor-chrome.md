# Feature packet: editor-chrome

**Feature:** the editor's transport capsule (play, step, start, end, loop and
a timecode, wrapping or clamping at the ends), status pills whose zoom and
size text comes from one rule (with toggle and warning styles), and the
floating tool palette's key pick, tooltips and rule check, each behind a
contract, on the gallery's chrome pages, with journeys.
**Line:** `line:suiteui` · **Wave:** 2 (`waves.md`) · **Lead branch:** `lead/editor-chrome`

**Rescoped 2026-10-18** (supervisor decision on #1344, 2026-10-17): the
captain's one-shell decision of 2026-10-15 deletes `EditorShell`,
`EditorTopBar` and `ToolbarGroup`'s `.rail` style, and editor-shell-removal
(#1529) is out of the beta cut. So this packet keeps only what lives on in
the one-shell window:

- **Kept:** the `ToolPicking`, `TransportStepping` and `StatusPillComposing`
  contracts (old EC-1), the transport (old EC-5), the status pills (old EC-6)
  and the tool pick for the `.floating` palette (old EC-8). The transport goes
  first: Flare F7b #376 waits on it.
- **Dropped:** `ShellLayingOut` and `SuiteShellLayout` (old EC-1 half, EC-2),
  `EditorShell(timeline:)` (old EC-3), `EditorBarItem.primary` and
  `EditorSaveStatus` (old EC-4), `SegmentedTabs`' capsule and the rail colours
  (old EC-7), the `editor` and `editor-plain` gallery pages (old EC-9), SJ1,
  SJ2, SJ3, SJ8, SP10, and the shell, top-bar and tabs goldens (old EC-12,
  EC-13).
- **Left to other features:** the timeline slot and the save status in
  `SuiteWindow`/`EditorDetail` are not small there (the window's detail
  layout and the session's dirty state), so they go to editor-in-window's
  follow-ups and adopt-kernel-session (`DocumentSession`'s save status);
  #342 and #339 stay open for them. The capsule tabs (#341) wait for a
  `gap` issue of their own.
- **Task ids are new** (EC-1 to EC-13 below); no earlier task id was ever
  reported done, so nothing is renumbered under a run.

**Covers:** #340 (S7 transport and pills: closes with EC-12). Part of #341
(the palette's tool pick; its tabs half stays open). The other tasks say
"Part of the editor-chrome feature".

**Depends on:** the suite-harness feature issue (#778, closed): goldens,
`SnapshotHost`, `.suiteControl(…role:)`, `.suiteProbes()`, `FrameProbe`,
`ContractTypes.swift`, the gallery stub `Gallery/GalleryChrome.swift`. And
editor-kernel's EK-1 (built): the `SuiteKernel` target every Model and
SuiteUI link. No creative-core issue.

**Canonical first (rule 20).** The frame-stepping rule already exists twice:
`FlarePlayback.stepFrame(by:)` and Halo's playback steps. A third copy in
SuiteUI would be one more, and an app Model can't import SuiteUI. So the
transport's contract and its rule live in the kernel, in a new module
`Sources/SuiteKernel/Transport/`, which every Model already links and which
builds and tests on Linux (`SuiteKernelTests`). `TransportCapsule` (SuiteUI)
draws it. Flare's and Halo's playback adopting it is their lines' follow-up
(each lead files the `gap` once EC-9 merges). The tool-key lookup: editor-
kernel's EK-31 plans `ToolKeys` as "the one tool-letter lookup"; EC-11 lands
first, so `SuiteToolPicking.tool(forKey:in:)` is that one copy and EK-31's
`ToolKeys` calls it over `PaletteTool` instead of writing a second (the lead
comments this on the editor-kernel issue when EC-11 merges). The pill text
is SuiteUI's alone (`ViewerZoom.percentText` already is).

**App features it unblocks:** Flare F7b #376 (transport), and every app's
status bar and floating palette (no app changes here).

Blueprint sections: 4.2 (SJ4 to SJ7), 4.4 (SP9), 5.2 (UC6, UC13, UC14), 6.2
(transport row), 7.1 (QB-S8), 7.3 (QB-S9), 8.3.

**Building blind.** The transport's rule (EC-1, EC-8, EC-9) is Linux code with
Linux tests: build it and run `SuiteKernelTests` in the cloud. The pills and
the tool pick are pure Swift in SuiteUI, which compiles only in the macOS job:
keep them Foundation-only inside the file so a reviewer can run them by hand,
check every SwiftUI API with the `apple-docs` MCP (say so in the PR), and copy
a SuiteUI file that builds. Raw values only through tokens; this feature
edits no `Tokens.swift`.

## Slices

A slice is the unit of done: its tasks have merged and its journeys pass on a
scoped macOS run (`app=suiteui`) that contains its last PR.

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| EC-a | Hosts and tests can code against `TransportStepping` (in the kernel), `ToolPicking` and `StatusPillComposing`, with fakes, stubbed live types, and the gallery's `transport`, `status`, `palette` and `empty` pages declared as placeholders. | EC-1, EC-2, EC-3 | SJ0 | – |
| EC-b | The gallery's `transport` page plays, pauses, steps, jumps to start and end and toggles loop on a capsule with a timecode; the `status` page shows zoom, size, toggle and warning pills; the `palette` page picks tools by click and key with each tooltip; all on the fakes, every control registered with its reason. | EC-4, EC-5, EC-6, EC-7 | SJ4, SJ5, SJ6, SJ7, SP9 | EC-a (EC-4, EC-5, EC-6, EC-7) |
| EC-c | The transport wraps with loop on and clamps with it off without overflow, reads `mm:ss / mm:ss` and never divides by zero; the pills print "200%", "–" and "1920 × 1080"; the palette refuses a duplicate shortcut or an empty reason: each as the contract promised and the fakes left out. | EC-8, EC-9, EC-10, EC-11 | SJ4, SJ5, SJ6 | EC-a (EC-8, EC-9, EC-10, EC-11) |
| EC-d | The pages run on the live rules (fakes only behind `-SuiteGalleryFakes`), the journeys assert the live behaviour, and the chrome goldens are committed. | EC-12, EC-13 | SJ4, SJ5, SJ6, SJ7, SP9 | EC-b (EC-12); EC-c (EC-12); EC-d's EC-12 (EC-13) |

EC-b is the UI slice (rule 18): it waits only on EC-a and runs beside EC-c,
which never waits on it. EC-b's first task (EC-4) makes the transport
reachable on the gallery's `transport` page, so the screen shows early and
Flare F7b can read its look.

## Journey steps

SJ4 to SJ7 and SP9 in `UITests/SuiteJourneyTests+ChromePanels.swift` (EC-7,
asserted on live by EC-12), on the `transport`, `status`, `palette` and
`empty` pages:

1. **SJ0** (harness, EC-3): the gallery opens all four chrome pages with
   `violations()` empty.
2. **SJ4** `testToolRailSelectsAndExplains`: on `palette`, click tool b, then
   press the first tool's key on the canvas: the log reads `tool b`, `tool a`;
   `isSelected` follows; the disabled tool's entry has its reason and a click
   changes nothing. On live (EC-12): the page's duplicate-shortcut variant
   lists both ids in its status line.
3. **SJ5** `testTransportPlaysStepsAndLoops`: Play ↔ Pause label; two steps
   log `frame f+2`; at the end a step stays (loop off) or wraps to 0 (loop on,
   live only); timecode `00:01 / 00:02` style (live; the fake prints frames);
   the `frameCount` 0 variant disables every button with "Nothing to play.".
4. **SJ6** `testStatusPills`: the zoom pill equals `ViewerZoom.percentText`
   (live; the fake prints "2.0×"); size pill "1920 × 1080"; the toggle pill's
   `isSelected` goes on then off and logs `toggle onion`; the warning pill
   shows its triangle and label; the zoom-NaN variant shows "–" (live).
5. **SJ7** `testEmptyStateOffersAction`: today's `EmptyStateView` (no
   restyle): title, message, one button, log `action new`; the variant
   without an action has no button.
6. **SP9** `testPressLatency`: 60 presses over the palette's tools and the
   transport's buttons, series `press` (≥ 60 samples). Report-only.

## Screens and states

| Screen | Empty | Error | Loading |
|---|---|---|---|
| `transport` (capsule: start, step back, play, step forward, end, loop, timecode) | `frameCount` 0: every button disabled with "Nothing to play.", timecode `--:--` | none | none |
| `status` (viewer status bar: zoom, size, onion toggle, a warning) | no trailing pills: zoom and size only | the warning pill; zoom NaN shows "–" | none |
| `palette` (the `.floating` tool group over a plain canvas) | none | a disabled tool shows its reason; the duplicate variant's status line names the clashing ids | none |
| `empty` | the variant with no action has no button | none | none |

Snapshots: `suiteui-transport-*`, `suiteui-status-*`, `suiteui-palette-*` in
the four appearances (light, dark, and each with Increase Contrast), from
`SuiteTransportSnapshots`, `SuiteStatusSnapshots` and `SuitePaletteSnapshots`.

## Contract slice

EC-1 lands the transport in the kernel (UC13) and EC-2 the other two in
SuiteUI (UC6, UC14), verbatim from
`docs/blueprints/suiteui/contracts/Contracts.swift` except where noted:

```swift
// Sources/SuiteKernel/Transport/TransportStepping.swift (EC-1): TransportState
// (frame, frameCount, fps, isPlaying, loops), TransportFace (playTitle,
// unavailableHelp, timecode), and the protocol:
public protocol TransportStepping: Sendable {
    func stepped(_ state: TransportState, by frames: Int) -> TransportState
    func toStart(_ state: TransportState) -> TransportState
    func toEnd(_ state: TransportState) -> TransportState
    func face(_ state: TransportState) -> TransportFace
}
// Sources/SuiteKernel/Transport/FakeTransportStepping.swift (EC-1): never wraps,
// prints frames ("12 / 48"); its clamp uses addingReportingOverflow (the
// blueprint's `s.frame + frames` traps at Int.max).
// Sources/SuiteKernel/Transport/SuiteTransport.swift (EC-1): the live type,
// its bodies forwarding to the fake until EC-9.

// Sources/SuiteUI/Contracts/ToolPicking.swift (EC-2): ToolFace and
public protocol ToolPicking: Sendable {
    func tool(forKey key: Character, in tools: [ToolFace]) -> String?
    func help(for tool: ToolFace) -> String           // "Brush (B)" enabled, the reason disabled
    func violations(in tools: [ToolFace]) -> [String] // empty reason, or a shortcut used twice
}
// Sources/SuiteUI/Contracts/StatusPillComposing.swift (EC-2): PillStyle
// (.plain, .toggle(isOn:), .warning), StatusPill and
public protocol StatusPillComposing: Sendable {
    func pills(zoom: Double, documentSize: PlaneExtent, trailing: [StatusPill]) -> [StatusPill]
}
// Their fakes beside them; FakeStatusPillComposing prints the raw zoom and
// guards a size that isn't finite ("–"), since Int(Double.nan) traps.
// Sources/SuiteUI/ToolPicking.swift, Sources/SuiteUI/StatusPills.swift (EC-2):
// SuiteToolPicking and SuiteStatusPills, forwarding to the fakes until EC-10, EC-11.
```

Public API this feature adds (additive; every existing call compiles):

```swift
TransportCapsule(state: TransportState, rules: some TransportStepping = SuiteTransport(),
                 onPlay:, onStep: (Int) -> Void, onStart:, onEnd:, onLoop:)   // EC-4
StatusPillStyle(_ style: PillStyle)   // EC-5: the contract's PillStyle onto the StatusPillStyle on dev
ViewerStatusBar(..., pills: some StatusPillComposing = SuiteStatusPills())   // EC-5; the old init keeps working
ToolbarGroup(.floating, ..., picking: some ToolPicking = SuiteToolPicking()) // EC-6; .floating only
```

The capsule is values in, closures out: the host owns the frame and calls
the rules (Flare's playback, later through the kernel). Control ids:
`suite.transport.start|back|play|forward|end|loop`, `suite.transport.timecode`,
`suite.status.pill.<n>`, the palette's existing tool ids.

**Views with no contract** (5.2): `EmptyStateView` (unchanged). SJ7 proves it.

## Pseudocode

```
SuiteTransport : TransportStepping                                # EC-9 (kernel, Linux)
  last = max(frameCount - 1, 0)
  stepped(s, n): guard frameCount > 0 else s
                 loops: f = ((s.frame mod frameCount) + (n mod frameCount)) mod frameCount, then + frameCount mod frameCount
                 else:  clamp(s.frame + n, 0...last), the sum by addingReportingOverflow (overflow -> the end n points at)
  toStart: frame 0; toEnd: frame last
  face(s): playTitle = isPlaying ? "Pause" : "Play"; help = frameCount > 0 ? nil : "Nothing to play."
           timecode = mm:ss(frame / fps) + " / " + mm:ss(frameCount / fps)   # fps <= 0 or frameCount 0 -> "--:--"
           mm:ss: whole seconds, floor; minutes past 99 keep counting (no wrap)

SuiteStatusPills : StatusPillComposing                            # EC-10
  zoom.isFinite && zoom > 0 ? ViewerZoom.percentText(zoom) : "–"
  size: both sides finite and >= 0 ? "\(Int(w.rounded())) × \(Int(h.rounded()))" : "–"; then trailing in order

SuiteToolPicking : ToolPicking                                    # EC-11
  tool(key): first enabled tool whose shortcut lowercased == key lowercased
  help: the reason while disabled, else "Title (K)" with the shortcut uppercased, else the title
  violations: ids with unavailableHelp == "" ∪ ids sharing a shortcut (case-insensitive), sorted, no repeats

TransportCapsule                                                  # EC-4
  HStack of SuiteUI buttons (system Button in the suite's glass style, never a look-alike);
  each .help(face.unavailableHelp ?? its title) and .suiteControl(id, reason: the same text);
  disabled while face.unavailableHelp != nil; the loop button is a toggle (isSelected);
  a press emits a `press` sample; the timecode is monospaced digits (SuiteFont token)
```

## Tasks

Every task is one PR to `dev`: at most 400 changed lines and 15 files, label
`fast-lane`, body lines `Belt-Lead:`, `Feature: editor-chrome`, `Slice:`,
`Fast-Check: pass`, `Head:`. EC-13 carries `feature-done`. Every view task's
snapshot test also calls `assertGolden` through `SnapshotHost` in the four
appearances (QB-V5), so EC-13 has recorded actuals to commit; registers its
controls with `.suiteControl` (with a test that each entry's reason equals its
`.help`); emits its probe series; and moves its fades to `suiteReduceMotion`
with `fade-start`/`fade-end` marks. No task edits `docs/c4/model.json`,
`docs/design.md`, `Tokens.swift` or `project.yml`.

| id | slice | what | owned files | depends on | size |
|---|---|---|---|---|---|
| EC-1 | EC-a | The kernel's transport: `TransportState`, `TransportFace`, `TransportStepping`, `FakeTransportStepping`, the stubbed `SuiteTransport`; `TransportFakeTests` (the fake's literal results, its gap included); the C4 part | `Sources/SuiteKernel/Transport/TransportStepping.swift`, `Sources/SuiteKernel/Transport/FakeTransportStepping.swift`, `Sources/SuiteKernel/Transport/SuiteTransport.swift`, `Tests/SuiteKernelTests/TransportFakeTests.swift`, `docs/c4/parts/creative-apps/suite-kernel/kernel-transport.json` | – | ~200, 5 |
| EC-2 | EC-a | `ToolPicking` and `StatusPillComposing` with their fakes; stubbed `SuiteToolPicking`, `SuiteStatusPills`; `ChromeFakeTests` | `Sources/SuiteUI/Contracts/ToolPicking.swift`, `Sources/SuiteUI/Contracts/StatusPillComposing.swift`, `Sources/SuiteUI/ToolPicking.swift`, `Sources/SuiteUI/StatusPills.swift`, `Tests/SuiteUITests/ChromeFakeTests.swift` | – | ~220, 5 |
| EC-3 | EC-a | The four chrome pages as placeholders, each in its own file, `GalleryChrome.pages` listing them (the `editor` and `editor-plain` stubs go); SJ0 sees them | `Sources/SuiteUI/Gallery/GalleryChrome.swift`, `Sources/SuiteUI/Gallery/GalleryTransport.swift`, `Sources/SuiteUI/Gallery/GalleryStatus.swift`, `Sources/SuiteUI/Gallery/GalleryPalette.swift` | – | ~120, 4 |
| EC-4 | EC-b | `TransportCapsule` over `TransportStepping`; the `transport` page on the fake with its log and `frameCount` 0 switch; snapshots; the render budget | `Sources/SuiteUI/TransportCapsule.swift`, `Sources/SuiteUI/Gallery/GalleryTransport.swift`, `Tests/AppSnapshotTests/SuiteTransportSnapshots.swift`, `Tests/AppSnapshotTests/RenderBudgetChromeTests.swift` | EC-1, EC-3 | ~300, 4 |
| EC-5 | EC-b | `ViewerStatusBar` takes its zoom and size text from a `StatusPillComposing`; `StatusPillStyle(PillStyle)`; toggle pills register and emit `press`; the `status` page on the fake | `Sources/SuiteUI/ViewerStatusBar.swift`, `Sources/SuiteUI/Gallery/GalleryStatus.swift`, `Tests/AppSnapshotTests/SuiteStatusSnapshots.swift` | EC-2, EC-3 | ~200, 3 |
| EC-6 | EC-b | `ToolbarGroup`'s `.floating` style takes a `ToolPicking`: key pick, help from the picker, `press` series, tool fades; the `palette` page on the fake with its duplicate variant (MAC_GATED: the lane runs the macOS job) | `Sources/SuiteUI/ToolbarGroup.swift`, `Sources/SuiteUI/Gallery/GalleryPalette.swift`, `Tests/AppSnapshotTests/SuitePaletteSnapshots.swift` | EC-2, EC-3 | ~220, 3 |
| EC-7 | EC-b | SJ4, SJ5, SJ6, SJ7, SP9 on the fakes | `UITests/SuiteJourneyTests+ChromePanels.swift` | EC-4, EC-5, EC-6 | ~300, 1 |
| EC-8 | EC-c | Checks first: `TransportTests` (kernel, Linux) and `StatusPillTests`, `ToolPickingTests`, each disabled by name until its body lands | `Tests/SuiteKernelTests/TransportTests.swift`, `Tests/SuiteUITests/StatusPillTests.swift`, `Tests/SuiteUITests/ToolPickingTests.swift` | EC-1, EC-2 | ~240, 3 |
| EC-9 | EC-c | `SuiteTransport`'s bodies and its mutation plan; turns on `TransportTests` | `Sources/SuiteKernel/Transport/SuiteTransport.swift`, `Tests/mutations/SuiteKernel.SuiteTransport.json`, `Tests/SuiteKernelTests/TransportTests.swift` | EC-8 | ~150, 3 |
| EC-10 | EC-c | `SuiteStatusPills`' body and its plan; turns on `StatusPillTests` | `Sources/SuiteUI/StatusPills.swift`, `Tests/mutations/SuiteUI.StatusPills.json`, `Tests/SuiteUITests/StatusPillTests.swift` | EC-8 | ~100, 3 |
| EC-11 | EC-c | `SuiteToolPicking`'s body and its plan; turns on `ToolPickingTests` | `Sources/SuiteUI/ToolPicking.swift`, `Tests/mutations/SuiteUI.ToolPicking.json`, `Tests/SuiteUITests/ToolPickingTests.swift` | EC-8 | ~120, 3 |
| EC-12 | EC-d | The pages default to the live rules (fakes behind `-SuiteGalleryFakes`); the journeys assert the live wrap, timecode, "200%"/"–" and the duplicate refusal; closes #340 | `Sources/SuiteUI/Gallery/GalleryTransport.swift`, `Sources/SuiteUI/Gallery/GalleryStatus.swift`, `Sources/SuiteUI/Gallery/GalleryPalette.swift`, `UITests/SuiteJourneyTests+ChromePanels.swift` | EC-7, EC-9, EC-10, EC-11 | ~200, 4 |
| EC-13 | EC-d | Baselines from the CI artifact: transport, status and palette in the four appearances; the wave's `status`; `feature-done` | `Tests/AppSnapshotTests/Golden/chrome/` (12 PNGs), `docs/blueprints/suiteui/features/editor-chrome.wave.json` | EC-12 and its CI run | PNGs, 13 |

EC-9, EC-10 and EC-11 each own the test file EC-8 wrote for them (EC-8 first,
then the three side by side). EC-4 to EC-6 each own one page file EC-3 made,
so they build side by side; EC-12 takes all three after them.

## Build waves

- Wave 1: EC-1, EC-2, EC-3 (the contract slice). Independent: all three.
- Wave 2: EC-4, EC-5, EC-6, EC-8. Independent: all four (EC-4 first in the PR order: Flare F7b waits on it).
- Wave 3: EC-7, EC-9, EC-10, EC-11. Independent: all four.
- Wave 4: EC-12.
- Wave 5: EC-13 (`feature-done`, after EC-12's scoped run records the actuals).

Longest chain: EC-1 → EC-8 → EC-9 → EC-12 → EC-13 (5); EC-3 → EC-4 → EC-7 →
EC-12 → EC-13 runs beside it.

## Acceptance test per task

| id | test | fails when | mutations (rule 14) |
|---|---|---|---|
| EC-1 | `TransportFakeTests`: the fake clamps 47 + 1 to 47 of 48 even with loop on (its gap), prints "12 / 48", gives "Nothing to play." at `frameCount` 0, and survives `Int.max` | the fake changes, so the live tests stop proving the gap is closed | – (fakes) |
| EC-2 | `ChromeFakeTests`: each fake's literal result, including its gap (no duplicate-shortcut check, raw zoom text) | a fake changes behaviour | – (fakes) |
| EC-3 | SJ0 opens `transport`, `status`, `palette` and `empty` with `violations()` empty; `SuiteGalleryTests` lists the four ids and no `editor` | a page is missing or a stub control is unregistered | – (UI) |
| EC-4 | `SuiteTransportSnapshots` records playing, paused, loop on and `frameCount` 0; each button's entry reason equals its `.help`; `RenderBudgetChromeTests.testTransportPressBodies`: 60 presses, ≤ 1 window body each | a reason differs from its tooltip, or a press redraws more than the capsule | – (UI) |
| EC-5 | `SuiteStatusSnapshots`: the existing PNGs (toggle and warning pills, #522) are byte-identical with the fake's zoom text replaced by the bar's old text; `StatusPillStyle(PillStyle)` maps all three cases; a toggle pill's entry reason equals its `.help` | a style maps wrong, or an existing pill's look changes | – (UI) |
| EC-6 | `SuitePaletteSnapshots`: selected, disabled and the duplicate variant; a key press on the page picks the fake's answer; a tool's registered reason equals its `.help` | the palette reads its key or help anywhere but the picker | – (UI) |
| EC-7 | SJ4 to SJ7 pass on the fakes; SP9 records ≥ 60 samples | an assert in the journey steps fails | – (UI) |
| EC-8 | The three test files compile and every test is disabled by name with "until EC-9/10/11" | – | – |
| EC-9 | `TransportTests`: 47 of 48 steps to 47 with loop off and 0 with loop on; −1 from 0 wraps to 47; `Int.max` and `Int.min` steps neither trap nor leave 0...47; `frameCount` 0 changes nothing and every face's help is "Nothing to play."; 24 fps at frame 24 of 48 is `00:01 / 00:02`; fps 0 is `--:--`; toEnd is 47 | a wrap, a clamp or the timecode is wrong, or a step traps | wrap dropped (`loops` read as false); clamp to `frameCount` instead of `last`; fps 0 divides |
| EC-10 | `StatusPillTests`: zoom 2 is "200%", NaN, 0 and −1 are "–", 1920 × 1080 is "1920 × 1080", a NaN size is "–", trailing pills keep their order | the zoom or size text is wrong, or a NaN traps | the `zoom > 0` guard dropped; trailing reversed |
| EC-11 | `ToolPickingTests`: key `b` picks the enabled Brush, never a disabled one, `B` too; help is "Brush (B)" or the reason; two tools on `B` and one with an empty reason are violations, sorted, once each | a disabled tool is picked, or a duplicate passes | the enabled check dropped; the duplicate check dropped; case folding dropped |
| EC-12 | SJ4 to SJ7 pass on live on the scoped run; a page built with `-SuiteGalleryFakes` still shows the fake's text | a page still runs a fake by default | – (UI) |
| EC-13 | The next CI run's `Golden*` checks pass against the committed `chrome` baselines | a baseline is missing or differs | – |

## Quality tests

| quality row | budget | test |
|---|---|---|
| QB-S8 press to selected state drawn | p95 ≤ 1 frame late (placeholder 2) | SP9 `testPressLatency`, series `press` |
| render: transport press (EC-b) | 60 presses, ≤ 1 window body each | `RenderBudgetChromeTests.testTransportPressBodies` |
| QB-S9 tool fades | 0.14 s ± 1 refresh, 0 under Reduce Motion (report-only) | `fade-start`/`fade-end` marks from EC-6, read in SJ4 with the page switch off and on |
| QB-S24 goldens | 2/255, ≤ 0.5 % | EC-13 |

## Done check

- **Journeys green:** the scoped `app=suiteui` run on `dev` after EC-13 shows
  SJ4 to SJ7, SP9 (report-only) and SJ0 on the chrome pages.
- **Kernel green:** `SuiteKernelTests` (with `TransportTests` on) and every
  Model's tests pass on the Linux job.
- **Audit zero new:** `suiteui` stays 0 for every check; no app's counts rise
  (every app's status bar and floating palette change with EC-5 and EC-6, so
  read their `audit-*.json` on the same run, section 7.2).
- **Contact sheet:** `Belt-Contact-Sheet: <run link>` on the feature issue,
  listing `suiteui-transport-*`, `suiteui-status-*`, `suiteui-palette-*`,
  `suiteui-empty-*` and one app's status bar and palette shot.
