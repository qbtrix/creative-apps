# Feature packet: key-editing (Halo)

**Feature:** Halo's timeline edits keys the way Flare's does. Halo adopts the
shared strip's key picking (TL-c) and group drag with snapping (TL-d): click,
Shift-click and ⌘-click pick keys on any lane, Select All Keys (⌘A in the
timeline, or Animation > Select All Keys) picks every key of the composition,
and a drag moves every picked key by the same number of frames, snapped to
frames and the playhead, as one undo step through the kernel `History`. Every
action is a catalog command, so the CLI and an agent pick, select all and move
keys the way the timeline does.
**Line:** `line:halo` · **Wave:** W4 (`waves.md`) · **Lead branch:** `lead/key-editing`
**Beta:** captain, 2026-10-20 (the stress gate, PR #3499: "Halo can't move
keys"). Labels `beta` and `p1` when filed.

**Covers:** feature map `halo/key-editing` (adopter of `suiteui/timeline`
TL-c and TL-d, and of `suiteui/timeline-select-all`); real job RJ-H13 (select
several keys across layers, hidden layers included, and drag them later);
#2763 (stale keys after a Shift-pick; KE-3 adds the test it asks for). The
strip half of these gestures shipped in `suiteui/timeline` (#1480); this is
the Halo half its "Who uses each part" table leaves on Halo's line.

**Depends on:** `suiteui/timeline-select-all` **TSA-a** (cross-line, KE-2
only: `onSelectAllKeys` and the focused route). Built: `suiteui/timeline`,
editor-kernel (`Selection`, `KeyRules.moveKeys`, `History`), halo/easing,
halo/history-files, adopt-kernel-selection's AS-h1 and AS-h2 (merged, #2762
and #2792: `keySelection` is already a kernel `Selection<HaloKeyRef>`).

**Hand-offs** (cross-line files; the lead checks each before the task):
`HaloCommandCatalog.swift` and `Tests/command-ids/halo.txt` are
adopt-command-catalog's (#2999, AC-halo; AC-h1 merged as #3191), and seven
planned Halo packets each add a few lines to them: KE-1 starts after
AC-halo's `Belt-Slice-Done:`. Among Halo's packets the catalog passes in one
chain, and KE-a now heads it (gradient-fill's HG-m waits on KE-a), so a beta
fix isn't queued behind six feature packets. `docs/blueprints/halo.md` passes
core-loop's CL-z → KE-z → gradient-fill's HG-z.
`HaloKeySelection.swift` is shared with adopt-kernel-easing's AE-halo: KE-3
rebases onto it, and owns the file's plan (`Tests/mutations/HaloModel.HaloKeySelection.json`),
repointing any `find` its edit moves. `HaloTimelineView.swift` is also
core-loop's (W3, planned): its CL-probe slice waits on KE-a, because CL-8
is itself held by SuiteUI's probe recorder (#3401) and KE-2 is the task that
puts key editing on screen.
`UITests/HaloJourneyTests+StressPerf.swift` comes from PR #3499 (stacked on
#3122): KE-7 waits on #3499's merge.

**Rule 20.** No Halo key-move or selection logic: picks are the kernel
`Selection<HaloKeyRef>` (`pick`, `selectAll`, `prune`), the move is
`KeyRules.moveKeys` (all or nothing, refusing a collision), the group clamp
and snapping are the strip's `SuiteKeyEditing.moved` and
`TimelineEditing.snapped`, and the step is the kernel `History` through
`HaloProject.edit(coalesceKey:)`. The new Model files are adapters
(`HaloKeyPick+Kernel.swift`, `HaloKeyMove+Kernel.swift`).

**What changes in Halo's pick.** Today every pick is narrowed to the selected
layer (`liveKeySelection`, `narrowToPickedKeys`). RJ-H13 and the stress
gesture pick across layers, so a pick now keeps every key that still exists
in the selected composition; a plain click on another layer's key still
selects that layer and starts the pick over. The EASING list and easing edits
keep reading the selected layer's segments (`pickedKeys`, `pickedSegment`),
so adopt-kernel-easing's tests are unchanged.

Blueprint sections: halo.md (timeline, keys, easing), suiteui
`timeline.md` (Who uses each part: pick, drag picked keys).

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| KE-a | The four commands exist with their catalog ids and stubbed Model calls, and the timeline sends them: picks by click, Shift and ⌘, Select All Keys from ⌘A, the Animation menu and the context menu, and key drags, on the stubs. | KE-1, KE-2 | MJ-KE | AC-halo (KE-1, hand-off); suiteui/timeline-select-all TSA-a (KE-2, cross-line) |
| KE-u | The picked keys across lanes, the menus and a key drag look right and stay inside their render budget. | KE-5, KE-6 | HJ-K1 | KE-a |
| KE-m | Picks span layers, Select All Keys picks every key of the composition (hidden layers too), and a move shifts every picked key as one undo step or refuses whole. | KE-3, KE-4 | MJ-KE | KE-a |
| KE-z | The journey and the stress gate's Halo move-keys gesture pass on live, and the blueprint says Halo moves keys. | KE-7, KE-8 | HJ-K1 | KE-u, KE-m; core-loop:CL-z (KE-8); PR #3499 (KE-7) |

KE-a carries the first UI task (KE-2), so the feature is reachable from the
Animation menu once the contract merges; KE-u waits only on KE-a (rule 18) and
KE-m never waits on KE-u. MJ-KE is the Model walk in `HaloKeyEditingTests`
(Linux). HJ-K1 is `HaloKeyEditingJourneyTests.testSelectAllAndMoveKeys`.

## Journey steps

On the `parented` fixture: Ball keyed at 0, 12 and 24, the Rig null at 0
and 47 (`HaloKeyEditingJourneyTests.testSelectAllAndMoveKeys`, KE-5 writes it
skipped, KE-7 turns it on):

1. Click Ball's key at frame 0 (KE-2): it draws picked; Ball is selected.
2. Shift-click Rig's key at 0: keys on two lanes draw picked (KE-3).
3. Drag Ball's key 6 frames right: both land at 6, the time pill shows the
   new frame while dragging; Edit's Undo reads "Undo Move Keyframes" (KE-4).
4. ⌘Z: both keys are back at 0, in one step.
5. Hide Rig with its eye, click the timeline, press ⌘A: every key on every
   lane draws picked, the hidden Rig's too (KE-3). Animation > Select All Keys
   does the same (KE-2, mouse only).
6. Click Ball's key at 0 alone and drag it onto 12: nothing moves and the
   status line says "A key is already at frame 12 on Ball." (KE-4).
7. ⌘A, then ⌫: every key goes in one "Delete Keyframes" step (unchanged
   path, now across layers); ⌘Z brings them back.

## Jobs

| job | closes or adds | run | check | fixture |
|---|---|---|---|---|
| RJ-H13 | closes (now `halo/key-editing`; run J → C) | C | `Tests/RealJobs/halo/move-keys/move-keys.jobs.json`: `timeline.select-all-keys`, `timeline.move-keys` 6, `timeline.end-key-drag`, save | `input/bounce.halo` (three layers, one hidden, each keyed at 0, 12 and 24) |

Trap: the hidden layer's keys stay behind (and the next trap a reviewer hits:
only the selected layer's keys move). Assertion: the saved project's tracks on
all three layers, the hidden one included, read 6, 18 and 30. Mutations:
`HaloModel.HaloKeyPick+Kernel`, hidden layers skipped in `selectAllKeys` →
`HaloKeySelectionTests.selectAllTakesHiddenLayers`; `HaloModel.HaloKeyMove+Kernel`,
only the selected layer's tracks moved → `.moveSpansLayers`.

## Screens and states

`halo-timeline-keys-picked-across` (two lanes picked), `halo-timeline-all-picked`
(⌘A), `halo-timeline-key-drag` (time pill over the grabbed key),
`halo-animation-menu-select-all` (light and dark).

## Contract slice

```swift
// Sources/HaloModel/HaloCommand.swift (KE-1): four cases in the easing area, each with a sample payload.
case pickLaneKeys(layerID: String, frame: Int?, mode: Pick)  // nil frame: the bed was clicked, clear the pick
case selectAllKeys
case moveKeys(by: Int, dragStart: Int)                       // frames since the last call; dragStart folds one drag
case endKeyDrag
// Catalog ids (HaloCommandCatalog.swift, Tests/command-ids/halo.txt):
// timeline.pick-keys {layerID, frame?, mode}, timeline.select-all-keys, timeline.move-keys {by, dragStart},
// timeline.end-key-drag. easing.select-lane-keys keeps its params.

// Sources/HaloModel/HaloKeyPick+Kernel.swift (KE-1 stubs, KE-3 bodies)
extension HaloProject {
    public mutating func pickLaneKeys(layerID: String, frame: Int?, mode: Pick)
    public mutating func selectAllKeys()
    public func pickedFrames(of layerID: String) -> Set<Int>     // what the lane draws picked
    public var selectAllKeysHelp: String? { get }                // "There are no keys to select." / nil
}
// Sources/HaloModel/HaloKeyMove+Kernel.swift (KE-1 stubs, KE-4 bodies)
extension HaloProject {
    public mutating func moveKeys(by frames: Int, dragStart: Int)
    public mutating func endKeyDrag()
    public var moveKeysHelp: String? { get }                     // "Select keyframes to move." / nil
}
```

Stubs: the two helps return "Not built yet (KE-3)." and "Not built yet
(KE-4).", so the menu item and drags are disabled with that reason on the
stubs; `pickLaneKeys` forwards to today's `selectLaneKeys` (replace and
extend) so the UI task picks on the stubs.

## Pseudocode

```
pickLaneKeys(layer, frame, mode):                                    # KE-3
  frame == nil: keySelection.clear(); return                         # the bed
  layer != selectedLayerID and mode == .replace: selectLayer(layer)
  keys = every key of layer's tracks at frame (all properties)
  .replace: keySelection.replace(keys)
  .extend:  for k in keys: keySelection.pick(k, .extend)
  .toggle:  all keys picked ? remove them : add them
  keySelection.prune(alive: composition keys)                        # stale keys drop (#2763), other layers stay
selectAllKeys(): keySelection.selectAll(every key of every layer of the selected composition, hidden and locked included)
pickedFrames(of layer): frames of keySelection's keys on layer
moveKeys(by d, dragStart):                                           # KE-4
  d == 0 or nothing picked: return
  edit("Move Keyframes", control: "halo.timeline", coalesceKey: "keys-\(dragStart)-\(keyDragSerial)") { doc in
      for layer in picked layers: for property in its picked properties:
          try KeyRules.moveKeys(&tracks[property], picked frames, by: d, clampedTo: 0...lastFrame)
  }                                                                  # a throw (.collides) refuses the whole step
  on success: keySelection.replace(picked keys shifted by d, order kept)
  on refusal: refusal = "A key is already at frame N on <layer>."
endKeyDrag(): endCoalescing(); keyDragSerial &+= 1
Timeline view (KE-2), after FlareTimelineEdit:
  tracks: TimelineTrack(id:, name:, keys: frames as .linear, spans: [bar], pickedFrames: pickedFrames(of:), isSelected:)
  onPickKeyframe(id, frame, mode) -> .pickLaneKeys; onMoveKeyframes(d) -> .moveKeys(d, dragStart) (dragStart held per drag)
  onEndKeyDrag -> .endKeyDrag; onSelectAllKeys -> .selectAllKeys
  drop the SpatialTapGesture: TL-c's bed press already calls onSelectTrack
  context menu and Animation menu: "Select All Keys" (help names ⌘A), disabled with selectAllKeysHelp
```

## Tasks

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| KE-1 | – | The four `HaloCommand` cases, their availability, catalog specs and ids; the adapter stubs; `HaloKeyEditingTests` written, disabled | `Sources/HaloModel/HaloCommand.swift`, `Sources/HaloModel/Availability/HaloAvailability+Easing.swift`, `Sources/HaloModel/HaloCommandCatalog.swift`, `Tests/command-ids/halo.txt`, `Sources/HaloModel/HaloKeyPick+Kernel.swift`, `Sources/HaloModel/HaloKeyMove+Kernel.swift`, `Tests/HaloModelTests/HaloKeyEditingTests.swift` | AC-halo (hand-off) | ~260, 7 |
| KE-2 | – | The timeline on the strip's pick and drag API, Select All Keys in the Animation and context menus, the routes; reachable from Animation > Select All Keys | `Sources/HaloApp/HaloTimelineView.swift`, `Sources/HaloApp/HaloAnimationMenu.swift`, `Sources/HaloApp/HaloWindow+Easing.swift` | KE-1, TSA-a | ~220, 3 |
| KE-3 | #2763 | Pick bodies: cross-layer picks, toggle, the bed clear, Select All Keys, `pickedFrames`; the stale-key test; `HaloKeySelectionTests` cases that asserted other-layer keys drop rewritten to the new rule | `Sources/HaloModel/HaloKeyPick+Kernel.swift`, `Sources/HaloModel/HaloKeySelection.swift`, `Tests/HaloModelTests/HaloKeySelectionTests.swift`, `Tests/mutations/HaloModel.HaloKeySelection.json`, `Tests/mutations/HaloModel.HaloKeyPick+Kernel.json` | KE-1 | ~280, 5 |
| KE-4 | – | Move bodies over `KeyRules.moveKeys`, one step per drag, the refusal; turns on `HaloKeyEditingTests`; the 5,000-key budget; RJ-H13's job folder | `Sources/HaloModel/HaloKeyMove+Kernel.swift`, `Tests/HaloModelTests/HaloKeyEditingTests.swift`, `Tests/mutations/HaloModel.HaloKeyMove+Kernel.json`, `Tests/HaloModelTests/HaloKeysBudgetTests.swift`, `Tests/RealJobs/halo/move-keys/move-keys.jobs.json`, `Tests/RealJobs/halo/move-keys/input/bounce.halo` | KE-1 | ~320, 6 |
| KE-5 | – | Snapshots of the four states; the journey written, skipped until KE-7 | `Tests/AppSnapshotTests/HaloKeyEditingSnapshots.swift`, `UITests/HaloJourneyTests+KeyEditing.swift` | KE-2 | ~220, 2 |
| KE-6 | – | The render budget test: a 120-sample drag of two picked keys and ⌘A on `crowd` | `Tests/AppSnapshotTests/RenderBudgetHaloKeyEditingTests.swift` | KE-2 | ~160, 1 |
| KE-7 | – | Live: the journey turned on; the stress journey gains ⌘A on the timeline and the move-keys drag with ⌘Z | `UITests/HaloJourneyTests+KeyEditing.swift`, `UITests/HaloJourneyTests+StressPerf.swift` | KE-3, KE-4, KE-5, KE-6, #3499 | ~120, 2 |
| KE-8 | – | `halo.md` timeline rows (move keys, Select All Keys, cross-layer picks); `status: built`; `feature-done` | `docs/blueprints/halo.md`, `docs/blueprints/halo/features/key-editing.wave.json` | KE-7, core-loop CL-z | ~40, 2 |

## Build waves

- Wave 1: KE-1. Independent in this wave: KE-1 alone.
- Wave 2: KE-2, KE-3, KE-4. Independent in this wave: all three (KE-2 waits on TSA-a too).
- Wave 3: KE-5, KE-6. Independent in this wave: both.
- Wave 4: KE-7. Independent in this wave: KE-7 alone.
- Wave 5: KE-8 (shared prose, `feature-done`, final). Independent in this wave: KE-8 alone.

Longest chain: KE-1 → KE-2 → KE-5 → KE-7 → KE-8 (5). Chain of 5: the view
sends the commands KE-1 declares, the snapshots and journey draw that view,
the journey runs on it live, and KE-8 is the prose task.

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| KE-1 | `HaloCommandTests` walks the four new cases; `HaloCommandCatalogTests` finds the four ids and `easing.select-lane-keys` unchanged; `HaloKeyEditingTests` compiles, disabled | an id is missing or an old one changed its params | – (stub) |
| KE-2 | `HaloTimelineClickTests`: a key press sends `.pickLaneKeys` with the press's mode, a bed press clears, ⌘A while focused sends `.selectAllKeys` | a press sends the old `.selectLaneKeys`, or ⌘A selects nothing | – (UI) |
| KE-3 | `HaloKeySelectionTests`: Shift-click on another layer keeps the first layer's keys; a plain click there replaces the pick and selects that layer; ⌘-click toggles; a stale key drops after a Shift-pick (#2763); `HaloKeySelectionTests.selectAllTakesHiddenLayers`: ⌘A on `parented` with Rig hidden picks every key, Rig's included; easing still reads the selected layer only | a pick narrows to one layer, a hidden layer is skipped, or easing acts on another layer | `HaloModel.HaloKeyPick+Kernel`: hidden layers skipped → `.selectAllTakesHiddenLayers`; `.toggle` treated as `.extend` → `HaloKeySelectionTests.toggleRemoves`; prune by the selected layer instead of the composition → `.shiftKeepsOtherLayer`. `HaloModel.HaloKeySelection`: its plan's entries repointed |
| KE-4 | `HaloKeyEditingTests`: keys at 0 on Ball and 0 on Rig moved by +6 both land at 6 (`moveSpansLayers`); three moves in one drag are one "Move Keyframes" step and one undo puts all back (`oneStepPerDrag`); a move onto an unpicked key refuses and moves nothing (`collisionRefusesWhole`); the pick follows the keys; RJ-H13 passes on Linux; `HaloKeysBudgetTests.moveFiveThousandKeys`: one step on `crowd` with every key picked ≤ 8 ms | a key stays behind, a drag is several steps, a refusal moves part of the pick, or the step is over budget | `HaloModel.HaloKeyMove+Kernel`: only the selected layer moved → `.moveSpansLayers`; the coalesce key dropped → `.oneStepPerDrag`; tracks moved one by one, not all or nothing → `.collisionRefusesWhole` |
| KE-5 | `HaloKeyEditingSnapshots` (four states); the journey compiles, skipped "waits on KE-7" | a state is missing | – (UI) |
| KE-6 | `RenderBudgetHaloKeyEditingTests.keyDragInThreeBodies`, `.selectAllInOneBody` | over budget | – (UI) |
| KE-7 | `HaloKeyEditingJourneyTests.testSelectAllAndMoveKeys` steps 1 to 7 on live; `HaloStressPerfJourneyTests.testStress` with the two new gestures (perf run) | a step fails, or a gesture misses the gate | – |
| KE-8 | `scripts/waves render --dry-run` | status not built | – |

## Quality tests

| quality row | budget | test |
|---|---|---|
| render: 120-sample drag of two picked keys on `parented` | ≤ 3 window bodies; p95 ≤ 8 ms | `RenderBudgetHaloKeyEditingTests.keyDragInThreeBodies` |
| render: ⌘A on `crowd` (300 lanes, 5,000 keys) | ≤ 1 window body; p95 ≤ 16 ms | `RenderBudgetHaloKeyEditingTests.selectAllInOneBody` |
| Model: one move step, 5,000 keys picked (`crowd`) | ≤ 8 ms on Linux | `HaloKeysBudgetTests.moveFiveThousandKeys` |
| Stress gate: ⌘A in the timeline on `crowd` (`select-all-keys`) | a11y answer ≤ 2 s; main-thread surface allocation ≤ 20 %; idle CPU < 10 % 3 s after | `HaloStressPerfJourneyTests.testStress` (perf run, `Tests/render-budgets.md`) |
| Stress gate: every key picked, the key at frame 150 on Solid 300 dragged 10 frames right, then ⌘Z (`move-keys`, series `key-drag`) | step p95 ≤ 33 ms; main-thread surface allocation ≤ 20 %; a11y answer ≤ 2 s; idle CPU < 10 % 3 s after | `HaloStressPerfJourneyTests.testStress` |
| One gesture, one step | a key drag, ⌘A (no step: a pick is never an edit) | `HaloKeyEditingTests.oneStepPerDrag` |
| No dead controls; mouse and keyboard parity | Select All Keys in two menus and ⌘A; every command disabled with its help | `testSelectAllAndMoveKeys` |
| Audit | zero new over Halo's baseline | `audit-halo-*.json` |

## Done check

Per slice (rules 6, 15, 17, 21): KE-m merged-done with RJ-H13 green in the
Linux job; KE-u's feel gate and `Mac-Finish:`; KE-z's journey on live and the
stress gate's two gestures inside the gate (a miss is a `finding`, the budget
doesn't move). Then `Belt-Contact-Sheet:` with `halo-timeline-*`.

## Not in this packet

Trimming a layer's in and out points by drag (TL-d's `onTrim`, Halo's
`core-loop`), a marquee over keys, copy and paste of keys (S16), Deselect
All Keys (a bed click clears).
