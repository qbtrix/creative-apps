# Feature packet: timeline-select-all

**Feature:** the shared timeline strip offers Select All Keys. While the strip
has focus, ⌘A asks the host to pick every key on every lane, and the host
does it with SuiteKernel's `Selection.selectAll`. The strip still owns no
pick (TL-a: values in, closures out); it only routes the request. Halo and
Flare both use it.
**Line:** `line:suiteui` · **Wave:** 4 (`waves.md`) · **Lead branch:** `lead/timeline-select-all`
**Beta:** captain, 2026-10-20 (the stress gate, PR #3499: neither timeline
has Select All Keys). Labels `beta` and `p1` when filed.

**Covers:** feature map `suiteui/timeline-select-all` (part of S16); the
"Select All Keys" gap the stress gate names for Halo and Flare. Adopters:
`halo/key-editing` and `flare/key-select-all`, each waiting on TSA-a.

**Depends on:** `suiteui/timeline` (built, #1480): the strip, its focus
(TL-12, TL-17) and the pick API (TL-a). Nothing else.

**Why a shared slice.** ⌘A is a menu key equivalent in both apps (Flare's own
`edit.select-all` item; Halo keeps the system pasteboard group so text fields
select all). A menu key equivalent fires before the focused view's
`onKeyPress`, so a key handler in the strip alone never sees ⌘A. The strip
therefore publishes the request two ways while it has focus, and each host
uses the one its menu needs: a focused value its own Select All route reads
first (Flare), and the responder chain's `selectAll:` (Halo's system item).
Both live once, here (rule 16), not in each app.

Blueprint sections: suiteui.md (timeline), suite.md 2 (the kernel's
`Selection`).

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| TSA-a | `TimelineStrip(onSelectAllKeys:)` exists; while the strip has focus ⌘A and the responder chain's Select All call it; the gallery page picks every key from ⌘A or its Select All Keys button, and the render budget holds. | TSA-1, TSA-2 | SJ19f | suiteui/timeline (built) |

One slice: the contract (TSA-1) carries the first UI change itself (the
gallery button, reachable with the mouse on the fakes), as design/gradient-fill's
DG-a does, and TSA-2 adds the journey, snapshot and budget on it (rule 18).
There is no logic slice: the pick itself is the host's
`Selection.selectAll`, already in SuiteKernel.

## Journey steps

1. Open the gallery's `timeline` page, click Ball's lane bed so the strip has
   focus (TSA-2, `SuiteJourneyTests.testTimelineSelectsAllKeys`).
2. Press ⌘A: the page log reads `select-all`, and every key on every lane
   draws picked.
3. Click the page's Select All Keys button (TSA-1): the same log line (mouse
   only, no shortcut needed).
4. Click an empty bed: the pick clears (TL-c, unchanged).

## Jobs

| job | closes or adds | run | check | fixture |
|---|---|---|---|---|
| RJ-H13 | contributes (closed by `halo/key-editing`) | C | Halo's `move-keys` job (HK-4) runs `timeline.select-all-keys`, the command this slice's route ends in | Halo's `input/bounce.halo` |

This packet adds no job of its own: Select All Keys has no outcome until a
host picks and moves the keys, which `halo/key-editing` (RJ-H13) and
`flare/key-select-all` (RJ-F43) check. Trap the strip owns: ⌘A selects the
stage's art instead of the keys while the timeline has focus. Assertion:
`TimelineSelectAllTests.focusedRouteWins` (below).

## Screens and states

`suiteui-timeline-all-picked` (light and dark): every key picked, the
strip's focus ring on.

## Contract slice

```swift
// Sources/SuiteUI/TimelineStrip.swift (TSA-1): one more closure, nil by default, so every caller compiles as today.
TimelineStrip(..., onSelectAllKeys: (@MainActor () -> Void)? = nil)

// Sources/SuiteUI/TimelineStrip+Keys.swift (TSA-1): while the strip has focus and onSelectAllKeys is non-nil:
//   .focusedValue(\.timelineSelectAll, TimelineSelectAll(run: onSelectAllKeys))
//   .onCommand(#selector(NSResponder.selectAll(_:))) { onSelectAllKeys() }   // Unverified API: onCommand on a focused SwiftUI view
public struct TimelineSelectAll { public let run: @MainActor () -> Void }
extension FocusedValues { public var timelineSelectAll: TimelineSelectAll? { get set } }
```

A host with its own Select All item reads `@FocusedValue(\.timelineSelectAll)`
and calls `run()` when it is non-nil, else its usual Select All. A host on the
system item gets `selectAll:` through the responder chain. The host's closure
picks every key with `Selection.selectAll(candidates)` in its Model.

## Pseudocode

```
TimelineStripKeys body (TSA-1):
  if isFocused, let all = onSelectAllKeys:
      content.focusedValue(\.timelineSelectAll, TimelineSelectAll(run: all))
             .onCommand(#selector(NSResponder.selectAll(_:)), perform: all)
  else content unchanged          # no focused value: the host's own Select All runs
gallery timeline page (TSA-1 button, TSA-2 ⌘A):
  onSelectAllKeys: log("select-all"); picked = every key of every track
  Select All Keys button (gallery.timeline.selectAll) calls the same closure
```

## Tasks

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| TSA-1 | – | `onSelectAllKeys`, the focused value and the responder route; the gallery page's Select All Keys button and log; `TimelineSelectAllTests` first | `Sources/SuiteUI/TimelineStrip.swift`, `Sources/SuiteUI/TimelineStrip+Keys.swift`, `Sources/SuiteUI/Gallery/GalleryTimeline.swift`, `Tests/SuiteUITests/TimelineSelectAllTests.swift`, `Tests/mutations/SuiteUI.TimelineStrip+Keys.json` | – | ~180, 5 |
| TSA-2 | – | The journey (⌘A on the page), the snapshot and the render budget row; `status: built`, `feature-done` | `UITests/SuiteJourneyTests+TimelineSelectAll.swift`, `Tests/AppSnapshotTests/SuiteTimelineSelectAllSnapshots.swift`, `Tests/AppSnapshotTests/RenderBudgetSuiteTimelineSelectAllTests.swift`, `docs/blueprints/suiteui/features/timeline-select-all.wave.json` | TSA-1 | ~200, 4 |

## Build waves

- Wave 1: TSA-1. Independent in this wave: TSA-1 alone.
- Wave 2: TSA-2 (`feature-done`, final). Independent in this wave: TSA-2 alone.

Longest chain: TSA-1 → TSA-2 (2).

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| TSA-1 | `TimelineSelectAllTests`: with `onSelectAllKeys` set and focus, the strip's route reports a `TimelineSelectAll` and calling it runs the closure once (`focusedRouteWins`); without focus, or with a nil closure, it reports none (`noRouteWithoutFocus`); a strip built without the argument draws the same as before (TL snapshots unchanged) | ⌘A goes to the stage while the timeline has focus, or the route stays published after focus leaves | `SuiteUI.TimelineStrip+Keys`: the focus check dropped → `.noRouteWithoutFocus`; the closure called twice per request → `.focusedRouteWins` |
| TSA-2 | `SuiteJourneyTests.testTimelineSelectsAllKeys` steps 1 to 4; `SuiteTimelineSelectAllSnapshots`; `RenderBudgetSuiteTimelineSelectAllTests.selectAllInOneBody` | a step fails, or the pick redraws every lane more than once | – (UI) |

## Quality tests

| quality row | budget | test |
|---|---|---|
| render: ⌘A on the 200-lane `timeline-long` page | ≤ 1 window body; p95 ≤ 8 ms | `RenderBudgetSuiteTimelineSelectAllTests.selectAllInOneBody` |
| No dead controls; mouse parity | the Select All Keys button does what ⌘A does | `testTimelineSelectsAllKeys` step 3 |
| Keyboard parity | ⌘A works with the strip focused by a click or by Tab | `testTimelineSelectsAllKeys` |
| Audit | zero new over SuiteUI's baseline | `audit-suite-*.json` |

## Done check

Per slice (rules 6, 15, 17): TSA-a merged-done on the Linux job, then its
journey, feel gate and `Mac-Finish:` (the `onCommand` route is checked on the
Mac, its `Unverified API:` line). Then `Belt-Contact-Sheet:` with
`suiteui-timeline-all-picked`.

## Not in this packet

Deselect All Keys (a bed click and Escape already clear the pick), Select All
Keys on one lane only, and picking by marquee on the lanes (S16).
