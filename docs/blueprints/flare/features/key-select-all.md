# Feature packet: key-select-all (Flare)

**Feature:** Flare's timeline gets Select All Keys. ⌘A while the timeline has
focus, or Select All Keys in the timeline's context menu, picks every key on
every layer of the edited scene through SuiteKernel's `Selection.selectAll`;
with the stage focused, ⌘A still selects the art. The picked keys then move,
ease and delete with the timeline's existing drag (TL-d, IT-7) and Delete.
**Line:** `line:flare` · **Wave:** 6 (`waves.md`) · **Lead branch:** `lead/key-select-all`
**Beta:** captain, 2026-10-20 (the stress gate, PR #3499: "neither timeline
has Select All Keys"). Labels `beta` and `p1` when filed.

**Covers:** feature map `flare/key-select-all` (adopter of
`suiteui/timeline-select-all`); real job RJ-F43 (new).

**Depends on:** `suiteui/timeline-select-all` **TSA-a** (cross-line, KS-2:
`onSelectAllKeys` and the `timelineSelectAll` focused value). Built:
inspector-timeline (the key pick, drag and delete), draw-key-save, flare-export (the intent files).

**Hand-offs** (cross-line files; the lead checks each before the task):
`FlareCommandCatalog.swift` and `Tests/command-ids/flare.txt` pass through one
chain of Flare packets; KS-a now heads it (gradient-fill's FG-m waits on
KS-a). `FlareCommands.swift` passes svg-place's PF-u then file-flow's FL-a;
KS-a heads that chain too (PF-u waits on KS-a). Both catalog files are also
adopt-command-catalog's (#2999, AC-flare; AC-f1 to AC-f3 merged): KS-1 starts
after AC-flare's `Belt-Slice-Done:`. `UITests/FlareJourneyTests+StressPerf.swift`
comes from PR #3499: KS-4 waits on its merge.

**Rule 20.** The pick is SuiteKernel's `Selection`: `selectAllKeys()` builds
`Selection(selectedKeys)`, calls `selectAll(every summary key of the scene)`
and writes `ordered` back. `FlareKeySelection+Kernel.swift` is the adapter and
the only new Model file; Flare's `selectedKeys` stays the store the timeline
already reads, so no other key path changes. The ⌘A route is the shared
strip's focused value, not a Flare focus tracker.

Blueprint sections: flare.md (timeline), suiteui `timeline-select-all.md`.

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| KS-a | `timeline.select-all-keys` picks every key of the scene on the kernel `Selection`, and ⌘A with the timeline focused, or the timeline's context menu, sends it while ⌘A on the stage still selects art. | KS-1, KS-2 | MJ-KS | AC-flare (KS-1, hand-off); suiteui/timeline-select-all TSA-a (KS-2, cross-line) |
| KS-z | The journey, snapshot and render budget pass, and the stress gate's Flare key move starts from ⌘A instead of Shift-clicking every lane. | KS-3, KS-4 | FJ-KS1 | KS-a; PR #3499 (KS-4) |

KS-a carries the UI task (KS-2), so the feature is reachable from the
timeline's context menu as soon as it merges. The logic is one call into the
kernel, so the Model task builds it for real, not as a stub.

## Journey steps

On the `bounce` sample: Background, Shadow and Ball
(`FlareKeySelectAllJourneys.testSelectAllKeys`, KS-3):

1. Hide Shadow with its eye, click the timeline's Ball lane, press ⌘A (KS-2):
   every key on every lane draws picked, the hidden Shadow's too.
2. Right-click a key, choose Select All Keys: the same (mouse only).
3. Drag a picked key 5 frames right: every key moves 5 frames as one "Move
   Keyframe" step (IT-7, unchanged); ⌘Z puts them back.
4. Click the stage, press ⌘A: the stage's art is selected and the key pick is
   unchanged (the focused route only answers while the timeline has focus).
5. Click the timeline, ⌘A, Delete: no key is left; ⌘Z brings all back.

## Jobs

| job | closes or adds | run | check | fixture |
|---|---|---|---|---|
| RJ-F43 | adds (`flare/key-select-all`) | C | `Tests/RealJobs/flare/select-all-keys/select-all-keys.jobs.json`: `timeline.select-all-keys`, `edit.delete` | `input/three-layers.flare` (three layers, one hidden, keys on each) |

Trap: Select All picks the stage's art, or only the selected layer's keys, so
keys stay behind. Assertion: the saved file's three layers all have empty
`tracks`, the hidden one included. Mutation: `FlareModel.FlareKeySelection+Kernel`,
hidden layers skipped → `FlareTimelineEditTests.selectAllTakesHiddenLayers`.

## Screens and states

`flare-timeline-all-picked`, `flare-timeline-menu-select-all` (light and dark).

## Contract slice

```swift
// Sources/FlareModel/FlareIntent.swift (KS-1): one case in the timeline area.
case selectAllKeys                                        // FlareIntent.Timeline; title "Select All Keys"
// Sources/FlareModel/FlareKeySelection+Kernel.swift (KS-1)
extension FlareWorkspace {
    public mutating func selectAllKeys()                  // every summary key (property nil) of the edited owner's layers
    public var selectAllKeysHelp: String? { get }         // "There are no keys to select." / no document
}
// Catalog: act("timeline.select-all-keys", "Select All Keys", ...) in FlareCommandCatalog.swift; id in flare.txt.
// Sources/FlareApp/FlareCommands.swift (KS-2): the ⌘A item calls
//   @FocusedValue(\.timelineSelectAll)?.run() when present, else .edit(.selectAll) as today.
```

## Pseudocode

```
selectAllKeys():                                           # KS-1
  guard selectAllKeysHelp == nil else refuse(help)
  keys = for each layer of the edited owner (hidden and locked too), for each key frame of its summary row:
         KeyRef(layerID, property: nil, frame)
  var s = Selection(selectedKeys); s.selectAll(keys); selectedKeys = s.ordered
  timelineError = nil                                      # a pick is never an edit: no undo step
FlareTimelineEdit (KS-2): TimelineStrip(..., onSelectAllKeys: { perform(.timeline(.selectAllKeys)) })
  context menu: "Select All Keys" first, disabled with selectAllKeysHelp
```

## Tasks

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| KS-1 | – | `selectAllKeys` on the kernel `Selection`, its intent, title, route, catalog spec and id; tests first; RJ-F43's job folder | `Sources/FlareModel/FlareKeySelection+Kernel.swift`, `Sources/FlareModel/FlareIntent.swift`, `Sources/FlareModel/FlareIntent+Titles.swift`, `Sources/FlareApp/FlareWindow+Timeline.swift`, `Sources/FlareModel/FlareCommandCatalog.swift`, `Tests/command-ids/flare.txt`, `Tests/FlareModelTests/FlareTimelineEditTests.swift`, `Tests/mutations/FlareModel.FlareKeySelection+Kernel.json`, `Tests/RealJobs/flare/select-all-keys/select-all-keys.jobs.json`, `Tests/RealJobs/flare/select-all-keys/input/three-layers.flare` | AC-flare (hand-off) | ~260, 10 |
| KS-2 | – | ⌘A through the strip's focused route, the context menu item; reachable from the timeline's context menu | `Sources/FlareApp/FlareTimelineEdit.swift`, `Sources/FlareApp/FlareCommands.swift` | KS-1, TSA-a | ~80, 2 |
| KS-3 | – | The journey, the snapshots and the render budget row | `UITests/FlareJourneyTests+KeySelectAll.swift`, `Tests/AppSnapshotTests/FlareKeySelectAllSnapshots.swift`, `Tests/AppSnapshotTests/RenderBudgetFlareKeySelectAllTests.swift` | KS-2 | ~220, 3 |
| KS-4 | – | The stress journey picks with ⌘A before its key move; `status: built`, `feature-done` | `UITests/FlareJourneyTests+StressPerf.swift`, `docs/blueprints/flare/features/key-select-all.wave.json` | KS-3, #3499 | ~60, 2 |

## Build waves

- Wave 1: KS-1. Independent in this wave: KS-1 alone.
- Wave 2: KS-2. Independent in this wave: KS-2 alone (waits on TSA-a too).
- Wave 3: KS-3. Independent in this wave: KS-3 alone.
- Wave 4: KS-4 (`feature-done`, final). Independent in this wave: KS-4 alone.

Longest chain: KS-1 → KS-2 → KS-3 → KS-4 (4). Chain of 4: the menu sends the
intent KS-1 adds, the journey drives that menu, and KS-4's stress run starts
from the journey's ⌘A.

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| KS-1 | `FlareTimelineEditTests`: on `bounce` with Shadow hidden, `selectAllKeys` picks every key of every layer (`selectAllTakesHiddenLayers`), records no undo step, keeps order; with no keys it refuses with its help; `FlareIntentTests` walks the new case; RJ-F43 passes on Linux | a layer's keys are left out, the pick records a step, or the job leaves a key | `FlareModel.FlareKeySelection+Kernel`: hidden layers skipped → `.selectAllTakesHiddenLayers`; the scene's owner ignored (a symbol's keys picked from the scene) → `.selectAllInEditedOwner` |
| KS-2 | `FlareTimelineEditSnapshots` menu state; `FlareKeySelectAllJourneys` (KS-3) | ⌘A on the stage picks keys, or the menu item is missing | – (UI) |
| KS-3 | `FlareKeySelectAllJourneys.testSelectAllKeys` steps 1 to 5; `FlareKeySelectAllSnapshots`; `RenderBudgetFlareKeySelectAllTests.selectAllInOneBody` | a step fails, over budget | – (UI) |
| KS-4 | `FlareStressPerfJourneyTests.testStress` (perf run) with ⌘A before `move-keys`; `scripts/waves render --dry-run` | the move starts from a partial pick, or status not built | – |

## Quality tests

| quality row | budget | test |
|---|---|---|
| render: ⌘A in the timeline on `stress` (200 lanes, 600 keys) | ≤ 1 window body; p95 ≤ 16 ms | `RenderBudgetFlareKeySelectAllTests.selectAllInOneBody` |
| Stress gate: ⌘A in the timeline, then the key at 300 dragged 10 frames, ⌘Z (`move-keys`, series `key-drag`) | step p95 ≤ 33 ms; main-thread surface allocation ≤ 20 %; a11y answer ≤ 2 s; idle CPU < 10 % 3 s after | `FlareStressPerfJourneyTests.testStress` (perf run, `Tests/render-budgets.md`) |
| One gesture, one step | ⌘A records no step; the drag after it one | `FlareTimelineEditTests` |
| No dead controls; mouse and keyboard parity | the context menu item does what ⌘A does | `testSelectAllKeys` |
| Audit | zero new over Flare's baseline | `audit-flare-*.json` |

## Done check

Per slice (rules 6, 15, 17, 21): KS-a merged-done with RJ-F43 green in the
Linux job; KS-a's and KS-z's feel gate and `Mac-Finish:`; the journey green.
Then `Belt-Contact-Sheet:` with `flare-timeline-*`.

## Not in this packet

Moving keys by command (`timeline.move-keys`; the drag is IT-7's), a key
marquee, Deselect All Keys (a bed click clears), and moving `selectedKeys`
itself onto a stored kernel `Selection` (adopt-kernel-selection's Flare slice
covers the stage selection only; a follow-up when Flare's key pick needs an
anchor).
