# Feature packet: editor-chrome

**Feature:** the editor window's chrome parts that outlive `EditorShell`:
the transport capsule, the status pills, the floating tool palette's key
pick and help, the capsule tabs and the empty state's primary button, each
with its rule behind a contract, a gallery page and journeys.
**Line:** `line:suiteui` · **Wave:** 2 (`waves.md`) · **Lead branch:** `lead/editor-chrome`

**Rescoped 2026-10-18** on the captain's decision on #1344 (2026-10-17):
the one-shell decision of 2026-10-15 (`docs/blueprints/suiteui.md`
section 6) deletes `EditorShell`, `EditorTopBar` and `ToolbarGroup`'s
`.rail`, and editor-shell-removal (#1529) is out of the beta cut, so this
packet builds nothing on those files. Dropped: `ShellLayingOut` and EC-2,
EC-3 (the timeline slot), the `EditorTopBar` half of EC-4 (`.primary` bar
items and save status), EC-7's rail colors, the `editor-plain` page, SJ1 to
SJ3, SP10 and the shell and top-bar goldens. Where they went:

- **Timeline slot (#342):** moot with `EditorShell` gone (timeline packet,
  "Not in this packet"); an app that wants a resizable slot asks for it in a
  `needs-ui` issue against `SuiteWindow`/`EditorDetail`.
- **Save status:** editor-kernel EK-doc names it (`DocumentSession`) and
  adopt-kernel-session moves every app onto it; each app draws it in its own
  `SuiteWindow` toolbar (Design's `DesignSaveStatus` already does).
- **`.primary` Export:** editor-in-window, which owns the window toolbar.

**Covers:** #340 (S7 transport and pills, closes with EC-6b), #341 (S8 tabs;
its rail half is dropped, closes with EC-7), #339 (S6: only the empty state's
primary button is left here, EC-4; its bar half moves as above), #342 (S9,
moot; the lead closes it as not planned with a link to this packet).
The other tasks' PRs say "Part of the editor-chrome feature".

**Depends on:** the suite-harness feature (#778, merged): the golden compare
and snapshot host (#331, #332), the gallery stub
(`Gallery/GalleryChrome.swift`), `.suiteControl(…role:)` and `.suiteProbes()`
(#775) and `ContractTypes.swift` (#773). No creative-core issue.

**App features it unblocks:** Flare F7b #376 (`FlareTransport.swift` says
"TransportCapsule (#340) replaces the row") and Halo's transport, which take
the capsule in their own lines' follow-ups; neither app changes here.

**Canonical first (rule 20).** Searched SuiteModel, SuiteUI and every
`Sources/*Model/` on 2026-10-18. Frame stepping lives in
`FlarePlayback.stepFrame(by:)` (wraps with loop on, else clamps) and
`HaloPlayback`; neither is a kernel concept, and both stay the state owners
of their apps. `SuiteTransport` is the capsule's face rule only (what a
button does to a `TransportState`, what the capsule reads), with Flare's
semantics: it wraps the same way, and its timecode is Flare's
seconds:frames (`00:12 / 02:00`, #1844), not minutes:seconds, with the same
tooltip, so the capsule that replaces Flare's row reads the same. No task
writes undo, selection, export or any other kernel concept.

Blueprint sections: 4.2 (SJ4–SJ8), 4.4 (SP9), 5.2 (UC5, UC13, UC14),
6.2 (transport, tabs rows), 7.1 (QB-S8), 7.3 (QB-S9).

**Building blind.** The contracts and the three rules (`SuiteTransport`,
`SuiteStatusPills`, `SuiteToolPicking`) are Foundation-only Swift, but they
sit in SuiteUI, so they compile only in the macOS build (the lane's
build-only run). Check every SwiftUI API with the `apple-docs` MCP (say so
in the PR), copy a SuiteUI file that builds, and run each rule by hand on
Linux (paste it with its contract into a scratch `swift` script) before
pushing. Raw values only through tokens; this feature edits no
`Tokens.swift`.

## Slices

A slice is the unit of done: its tasks have merged and its journeys pass on
the `suiteui`-scoped macOS run.

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| EC-a | The three chrome contracts, their fakes and the three rules declared as stubs that every view below compiles against; the empty state's action is the primary button and the tabs draw as a capsule that is still a system `Picker`. | EC-1, EC-4, EC-7 | `ChromeFakeTests`, `SuiteEmptyStateSnapshots`, `SuiteTabsSnapshots` | – |
| EC-b | The gallery's `editor` page shows a clickable transport capsule, status pills with toggle and warning, capsule tabs and the floating palette, and `empty` offers its primary action, all on the stubs. | EC-5a, EC-6a, EC-9, EC-11 | SJ5, SJ6, SJ7, SJ8, SP9 | EC-a |
| EC-c | The live rules: the transport wraps or clamps and reads seconds:frames, the zoom pill reads "–" for a zoom that isn't a number, and a key picks only an enabled tool while a duplicate shortcut is a violation. | EC-5b, EC-6b, EC-8b | `TransportTests`, `StatusPillTests`, `ToolPickingTests` | EC-a |
| EC-d | The floating palette picks tools by key through the live rule and explains each disabled one, and the chrome's goldens are recorded. | EC-8, EC-10, EC-12, EC-13 | SJ4 | EC-b, EC-c |

EC-a is the contract slice. EC-4 and EC-7 ride in it because they restyle
existing views and need no contract, so EC-b's page and journeys find them
in place. EC-b is the UI slice (`"ui": true`) and runs beside EC-c, the
logic slice (rule 18). EC-b's first PR, EC-5a, makes the feature reachable: it puts the
capsule on the gallery's `editor` page (the gallery's page list is the
visible control). EC-d is the integrate step: EC-8 swaps `ToolbarGroup`'s
own key and help code for `SuiteToolPicking`, and EC-13 carries
`feature-done`.

**Stubs.** EC-1 declares `SuiteTransport`, `SuiteStatusPills` and
`SuiteToolPicking` with their final signatures. `SuiteTransport` and
`SuiteToolPicking` return their fakes' values until EC-5b and EC-8b fill
them. `SuiteStatusPills` is different: `ViewerStatusBar` is live in every
app, so its stub returns today's text (`ViewerZoom.percentText` and
`"W × H"`) and EC-6b adds the edge cases; no app's pill changes while the
slices run.

## Journey steps

SJ5–SJ8 and SP9 in `UITests/SuiteJourneyTests+ChromePanels.swift` (EC-11),
SJ4 in `UITests/SuiteJourneyTests+Chrome.swift` (EC-10), on the `editor`
and `empty` pages:

1. **SJ4** `testToolPaletteSelectsAndExplains`: click tool b, then press the
   first tool's key on the page: log `tool b`, `tool a`; `isSelected`
   follows; the disabled tool's entry has its reason, a click and its key
   change nothing.
2. **SJ5** `testTransportPlaysStepsAndLoops`: Play ↔ Pause label; two steps
   log `frame f+2`; at the end, step stays (loop off) or wraps to 0 (loop on);
   the timecode reads `00:12 / 02:00` style (seconds:frames) and its tooltip
   says so; the `frameCount` 0 switch disables every button with
   "Nothing to play.".
3. **SJ6** `testStatusPills`: zoom pill equals `ViewerZoom.percentText`; size
   pill "1920 × 1080"; toggle pill `isSelected` on then off, log
   `toggle onion`; the warning pill shows its triangle and label.
4. **SJ7** `testEmptyStateOffersAction`: title, message, one primary button,
   log `action new`; the variant without an action has no button.
5. **SJ8** `testSegmentedTabsSwitch`: log `tab layers`, then ← gives
   `tab adjust`; the selected tab's `isSelected` is true.
6. **SP9** `testPressLatency`: 60 presses over tools, tabs and transport,
   series `press` (≥ 60 samples). Report-only.

## Screens and states

| Screen | Empty | Error | Loading |
|---|---|---|---|
| `editor` (transport, pills, tabs, floating palette) | the `frameCount` 0 switch | the warning pill | none |
| Transport capsule | `frameCount` 0: every button disabled with "Nothing to play." | none | none |
| Status pills | no trailing pills: zoom and size only | the warning pill | none |
| Floating palette | none | a disabled tool shows its reason | none |
| `empty` | the variant with no action has no button | none | none |

## Contract slice

EC-1 lands these three files from
`docs/blueprints/suiteui/contracts/Contracts.swift` (UC5, UC13, UC14),
verbatim except one widening: `TransportFace` gains
`timecodeHelp: String?` (nil when nothing can play), because a new user
can't tell `00:12` is seconds:frames without it (Flare's #1844).

```swift
// Contracts/ToolPicking.swift: ToolFace
public protocol ToolPicking: Sendable {
    func tool(forKey key: Character, in tools: [ToolFace]) -> String?
    func help(for tool: ToolFace) -> String           // "Brush (B)" enabled, the reason disabled
    func violations(in tools: [ToolFace]) -> [String] // empty reason, or a shortcut used twice
}
// Contracts/TransportStepping.swift: TransportState (frame, frameCount, fps, isPlaying, loops),
// TransportFace (playTitle, unavailableHelp, timecode, timecodeHelp)
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
SuiteTransport(), SuiteStatusPills(), SuiteToolPicking()   // EC-1 stubs, EC-5b/6b/8b fill
TransportCapsule(state: TransportState, stepping: some TransportStepping = SuiteTransport(),
                 onPlay:, onStep:, onStart:, onEnd:, onLoop:)                       // EC-5a
StatusPillStyle(_ style: PillStyle)   // EC-6a: maps onto the StatusPillStyle already on dev
// ViewerStatusBar keeps its init and trailing slot; EC-6a routes its zoom and size text
// through SuiteStatusPills and registers toggle pills
```

**Views with no contract** (5.2): `EmptyStateView`, `SegmentedTabs`. SJ7,
SJ8 and the goldens prove them.

## Pseudocode

```
SuiteTransport : TransportStepping                                # EC-5b
  last = max(frameCount - 1, 0)
  stepped(s, n): guard frameCount > 0 else s
                 f = s.frame + n (overflow clamps); loops ? ((f mod frameCount) + frameCount) mod frameCount : clamp(f, 0...last)
  face(s): playTitle = isPlaying ? "Pause" : "Play"; help = frameCount > 0 ? nil : "Nothing to play."
           timecode = ss:ff(frame) + " / " + ss:ff(frameCount)   # fps <= 0 or frameCount 0 -> "--:-- / --:--"
           timecodeHelp = "Seconds:frames at 24 fps: 1 second and 23 frames of 2 seconds and 0 frames."

SuiteStatusPills : StatusPillComposing                            # EC-6b
  zoom.isFinite && zoom > 0 ? ViewerZoom.percentText(zoom) : "–"; then "W × H" (Int, rounded); then trailing

SuiteToolPicking : ToolPicking                                    # EC-8b
  tool(key): first enabled tool whose shortcut lowercased == key lowercased
  help: enabled ? "Title (K)" (title alone with no shortcut) : the reason
  violations: ids with unavailableHelp == "" ∪ ids sharing a shortcut (case-insensitive), sorted
```

## Tasks

Every task is one PR to `dev`: at most 400 changed lines and 15 files,
label `fast-lane`, body lines `Belt-Lead:`, `Feature: editor-chrome`,
`Slice:`, `Fast-Check: pass`, `Head:`. EC-13 carries `feature-done`. Every
view task's snapshot test also calls `assertGolden` through `SnapshotHost`
in the four appearances (QB-V5), so EC-12 and EC-13 have recorded actuals
to commit. Every view task registers its controls with `.suiteControl`
(with a test that the entry's reason equals its `.help`), emits its probe
series, and moves its fades to `suiteReduceMotion` with
`fade-start`/`fade-end` marks. No task edits `docs/c4/model.json`,
`docs/design.md`, `Tokens.swift` or `project.yml`.

| id | slice | issue | what | owned files | depends on |
|---|---|---|---|---|---|
| EC-1 | EC-a | – | The three contracts, their Fakes, and the three rules as stubs | `Sources/SuiteUI/Contracts/ToolPicking.swift`, `Sources/SuiteUI/Contracts/TransportStepping.swift`, `Sources/SuiteUI/Contracts/StatusPillComposing.swift`, `Sources/SuiteUI/SuiteTransport.swift`, `Sources/SuiteUI/SuiteStatusPills.swift`, `Sources/SuiteUI/SuiteToolPicking.swift`, `Tests/SuiteUITests/ChromeFakeTests.swift` | – |
| EC-5a | EC-b | #340 (part) | `TransportCapsule` over `TransportStepping`, on the gallery's `editor` page | `Sources/SuiteUI/TransportCapsule.swift`, `Tests/AppSnapshotTests/SuiteTransportSnapshots.swift`, `Sources/SuiteUI/Gallery/GalleryChrome.swift` | EC-1 |
| EC-6a | EC-b | #340 (part) | `ViewerStatusBar` takes its zoom and size text from `StatusPillComposing`; `StatusPillStyle(PillStyle)`; toggle pills register and emit `press` | `Sources/SuiteUI/ViewerStatusBar.swift`, `Tests/AppSnapshotTests/SuiteStatusSnapshots.swift` | EC-1 |
| EC-4 | EC-a | #339 (part) | `EmptyStateView`'s button in the primary style, registered with role `"primary"` | `Sources/SuiteUI/EmptyStateView.swift`, `Tests/AppSnapshotTests/SuiteEmptyStateSnapshots.swift` | – |
| EC-7 | EC-a | #341 (closes) | `SegmentedTabs` as a capsule (still a `Picker`), tab fades | `Sources/SuiteUI/SegmentedTabs.swift`, `Tests/AppSnapshotTests/SuiteTabsSnapshots.swift` | – |
| EC-9 | EC-b | – | The `editor` page complete (pills, tabs, floating palette with a disabled tool, the `frameCount` 0 and Reduce Motion switches, its log) and the `empty` page; the `-SuiteGalleryFakes` path; `editor-plain` removed | `Sources/SuiteUI/Gallery/GalleryChrome.swift`, `Tests/SuiteUITests/SuiteGalleryTests.swift` | EC-5a, EC-6a, EC-4, EC-7 |
| EC-11 | EC-b | – | SJ5, SJ6, SJ7, SJ8, SP9 | `UITests/SuiteJourneyTests+ChromePanels.swift` | EC-9 |
| EC-5b | EC-c | #340 (part) | `SuiteTransport`'s live body | `Sources/SuiteUI/SuiteTransport.swift`, `Tests/SuiteUITests/TransportTests.swift` | EC-1 |
| EC-6b | EC-c | #340 (closes) | `SuiteStatusPills`' live body | `Sources/SuiteUI/SuiteStatusPills.swift`, `Tests/SuiteUITests/StatusPillTests.swift` | EC-1 |
| EC-8b | EC-c | – | `SuiteToolPicking`'s live body | `Sources/SuiteUI/SuiteToolPicking.swift`, `Tests/SuiteUITests/ToolPickingTests.swift` | EC-1 |
| EC-8 | EC-d | – | `ToolbarGroup`'s `.floating` palette picks by key and builds its help through `SuiteToolPicking`; `press` series and tool fades. `.rail` is untouched (editor-shell-removal deletes it) | `Sources/SuiteUI/ToolbarGroup.swift`, `Tests/SuiteUITests/ToolbarPickingTests.swift` | EC-8b, EC-9 |
| EC-10 | EC-d | – | SJ4 | `UITests/SuiteJourneyTests+Chrome.swift` | EC-8 |
| EC-12 | EC-d | – | Baselines from the CI artifact: transport, status pills and empty state in the four appearances | `Tests/AppSnapshotTests/Golden/chrome/` (12 PNGs) | EC-5a, EC-6a, EC-4 and their CI run |
| EC-13 | EC-d | – | Baselines: tabs and floating palette in the four appearances; `feature-done` | `Tests/AppSnapshotTests/Golden/chrome/` (8 PNGs) | EC-7, EC-8, EC-10, EC-11, EC-12 |

Sizes: EC-1 ~250 lines; EC-5a ~280; EC-6a ~150; EC-4 ~80; EC-7 ~120;
EC-9 ~300; EC-11 ~300; EC-5b ~150; EC-6b ~100; EC-8b ~120; EC-8 ~150;
EC-10 ~120; EC-12 and EC-13 PNGs only.

Inside the feature: EC-5a and EC-9 share `GalleryChrome.swift`, so EC-9
waits for EC-5a. Each logic task owns its rule's file, which EC-1 created,
so the three run side by side. `ToolbarGroup.swift` and `ViewerStatusBar`
are shared shell files: EC-8 changes `ToolbarGroup.swift`, which is
`MAC_GATED`, so its PR waits for the lane's macOS run.

Across features: this feature `depends` on suite-harness (built), which
also owns `EmptyStateView.swift` and `ToolbarGroup.swift`. editor-shell-removal
(parked) now `depends` on editor-chrome, because both own
`ToolbarGroup.swift` and EC-8 must land before `.rail` is deleted.

## Build waves

- Wave 1: EC-1, EC-4, EC-7. Independent: all three.
- Wave 2: EC-5a, EC-6a, EC-5b, EC-6b, EC-8b. Independent: all five.
- Wave 3: EC-9, EC-12. Independent: both.
- Wave 4: EC-11, EC-8. Independent: both.
- Wave 5: EC-10.
- Wave 6: EC-13 (`feature-done`, final).

EC-5a goes first in wave 2: Flare F7b #376 waits on the capsule.

## Acceptance test per task

| id | test | fails when |
|---|---|---|
| EC-1 | `ChromeFakeTests`: each Fake gives its literal result, including its deliberate gap (no wrap and frame text, no duplicate-shortcut check, raw zoom text); each stub's signature compiles against its contract, `SuiteStatusPills()` gives today's "200%" and "1920 × 1080" | a Fake or a stub changes behaviour |
| EC-5a | `SuiteTransportSnapshots` records the capsule playing, paused, looped and with `frameCount` 0; each button's entry reason equals its `.help`; the timecode's tooltip is `face.timecodeHelp` | a button is unregistered, or a reason differs from its help |
| EC-6a | `ViewerStatusBar` built with a `StatusPillComposing` that returns "x" shows "x"; `StatusPillStyle(PillStyle)` maps all three cases; a toggle pill's entry reason equals its `.help`; the existing `SuiteStatusSnapshots` PNGs are byte-identical | the bar formats zoom itself, a style maps wrong, or an existing pill's look changes |
| EC-4 | `SuiteEmptyStateSnapshots` records the primary button; it registers `role: "primary"`, and the variant with no action has none | the role is wrong or a button appears with no action |
| EC-7 | `SuiteTabsSnapshots` records the capsule tabs selected, hovered and disabled; a unit test that `SegmentedTabs` still builds a `Picker` | the tabs stop being a `Picker` underneath |
| EC-9 | `SuiteGalleryTests` lists `editor` and `empty`, not `editor-plain`; the page builds with live rules and with `-SuiteGalleryFakes`; SJ0 opens both with `violations()` empty | a control on the page is unregistered or disabled without a reason |
| EC-11 | SJ5–SJ8 pass; SP9 produces ≥ 60 samples (report-only) | an assert fails or a series is short |
| EC-5b | `TransportTests`: from frame 47 of 48 a step stays at 47 with loop off and goes to 0 with loop on; step −1 from 0 wraps to 47 with loop on; `Int.max` steps clamp without overflow; `frameCount` 0 gives "Nothing to play." and a step changes nothing; at 24 fps frame 36 of 48 reads `01:12 / 02:00` with the tooltip "Seconds:frames at 24 fps: 1 second and 12 frames of 2 seconds and 0 frames."; `fps` 0 gives `--:-- / --:--` with no division | a wrap, a clamp or the timecode is wrong, or a zero divides |
| EC-6b | `StatusPillTests`: zoom 2 gives "200%" (`ViewerZoom.percentText` unchanged), NaN, infinity and 0 give "–", 1920 × 1080 gives "1920 × 1080", 1919.6 rounds to 1920, trailing pills keep their order | a zoom that isn't a number prints, or the order changes |
| EC-8b | `ToolPickingTests`: key `b` and `B` pick the enabled Brush, never a disabled tool; `help` is "Brush (B)", the title alone with no shortcut, or the reason; two tools on `B` and one with an empty reason are violations, sorted | a disabled tool is picked by key, or a duplicate passes |
| EC-8 | `ToolbarPickingTests`: a `.floating` group's tool help and key pick come from `SuiteToolPicking`, and a registered tool's reason equals its `.help`; `.rail` output unchanged | the palette keeps its own key code, or `.rail` changes |
| EC-10 | SJ4 passes | any assert in its row |
| EC-12, EC-13 | The next CI run's `Golden*` checks pass against the committed baselines with no known issues left for `chrome` | a baseline is missing or differs |

## Quality tests

| quality row | budget | test |
|---|---|---|
| QB-S8 press to selected state drawn | p95 ≤ 1 frame late (placeholder 2) | SP9 `testPressLatency`, series `press` |
| QB-S9 tab and tool fades | 0.14 s ± 1 refresh, 0 under Reduce Motion (report-only) | `fade-start`/`fade-end` marks from EC-7 and EC-8, read in SJ8 and SJ4 with the page switch off and on |
| QB-S24 goldens | 2/255, ≤ 0.5 % | EC-12, EC-13 |

## Done check

- **Journeys green:** the macOS run on `dev` triggered by EC-13 is green:
  SJ4–SJ8, SP9 (report-only), SJ0 and SJ25 on the chrome pages.
- **Audit zero new:** `suiteui` stays 0 for every check; every app's counts
  stay put (`ViewerStatusBar` is in all of them; read their `audit-*.json`
  on the same run).
- **Contact sheet:** `Belt-Contact-Sheet: <run link>` on the feature issue,
  listing `suiteui-editor-*`, `suiteui-empty-*` and one editor shot per app,
  whose status pills draw through `SuiteStatusPills`.
