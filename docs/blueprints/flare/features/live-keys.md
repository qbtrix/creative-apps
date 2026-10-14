# Feature packet: live-keys

**Feature:** key, retime and ease on real documents. The inspector's
TRANSFORM rows with section 2's not-animated rule, the stopwatch and the
keyframe button, fill and stroke, and the timeline's rows, key moves,
deletes, frame inserts and removes and labels run on FlareCore for scene
layers and for a symbol's own layers while it is edited in place.
**Line:** `line:flare` · **Wave:** 2 (`waves.md`) · **Lead branch:** `lead/live-keys`

**Covers:** #13 (LM-4), #358 (LM-5). #13 closes with KY-4, #358 with KY-7.
KY-8 extends the shipped `LiveEasing` (#359, closed) to symbol layers; it has
no issue of its own and its PR says "Part of the live-keys feature".

**Depends on:** qbtrix/creative-core#171 (LC-5, keyframe commands take
`owner:`), qbtrix/creative-core#216 (LC-7, `SetShapeStroke`),
qbtrix/creative-core#219 (LC-10, `SetKeyframe` merge). None had landed on
creative-core `main` cfad97f (2026-10-14). KY-1 and KY-5 are reads and need
none of them, so the lead can start those at once; the rest wait on the
issue named in their row.

Where it starts from: `FakeProperties` and `FakeKeyframes` already run on the
real `CommandEngine` for scene layers. What the live types add is the symbol
owner (they throw `FakeProperties.symbolKeys` today), stroke through
`SetShapeStroke` instead of `FixtureEdit`, and one merged command per scrub.
The live files may call shared helpers, but must not contain `FixtureEdit`
(live-stage's ST-5 scan fails on it). `LiveEasing` (#359) already shipped for
scene layers; it throws `FakeProperties.symbolKeys` for a symbol owner
(`LiveEasing.swift:21`), so KY-8 gives it the owner path once LC-5 lands
rather than building a second easing type.

**How a chain compiles.** `LiveProperties` and `LiveKeyframes` are declared
as plain structs in KY-1 and KY-5; each later task adds its methods in its
own extension file, and the last task of each chain (KY-4, KY-7) adds
`extension LiveProperties: PropertyAnimating {}` or
`extension LiveKeyframes: KeyframeEditing {}` in its own file.

**Reading the fakes' tables.** `LiveProperties` reuses `FakeProperties.rows` and its key-state rule as pure static reads. That is allowed: IN-9's test checks that no member of `FlareServices.live` *is* a `Fake*` type, and a live type must never create a fake or run a fake's engine code. (live-stage's ST-7 moves the box math for exactly that reason: it creates a `FakeStage`.)

**Counting commands.** `CommandEngine`'s undo stack is internal to
FlareCore, so a test can't count the commands inside one entry. "One entry"
is tested as: after the gesture one `undo()` restores the document exactly
and `canUndo` is back to what it was. "One merged command" is tested on the
command itself once LC-10 lands: `var a = SetKeyframe(...)`,
`#expect(a.merge(b))`, and `a` holds the first old and the last new value. Blueprint sections: 2 (where a property's value
lives, one undo step), 6.2 (`PropertyAnimating`, `KeyframeEditing`), 7.5
(LM-4, LM-5).

## Journey steps

J6 (move and key by drag), J7 (inspector keys), J8 (fill and stroke), J11
(retime, delete, insert and label) and J12 (easing) are the journeys; their
UI is F5 (#391), F6a (#186), F6b (#348), F8 (#377) and F9 (#378). This
feature proves their Model half on the live types, in
`Tests/FlareModelTests/LiveKeysJourneyTests.swift` (KY-9):

1. On `bounce` at frame 30, Ball X reads `.animated` (keys at 0, 12, 24,
   36, 47) and Shadow X `.notAnimated`; Ball and Shadow together read X as
   `nil` (Mixed) with no marker.
2. Shadow has no X track, so Shadow X set at frame 30 with auto-key off adds
   its one key at frame 0: it stays `.notAnimated` and reads the new value at
   0 and at 30.
3. The stopwatch on Shadow X at frame 0 keys 0 and 47: `.animated`.
4. 120 `setValue` calls on Ball rotation with one coalesce key are one undo
   entry: one `undo()` restores Ball.
5. Ball's fill set to `FF3B30`, then stroke width 4, cap and join Round; one
   undo restores only the join.
6. Ball's key at 24 moved to 28 is one "Undo Move Keyframe"; onto 36 it
   throws and changes nothing; the key at 12 deleted; two frames inserted at
   10 move 28 to 30; one removed moves it to 29; a label "hit" at 29.
7. Inside the "wave" symbol of `character`, the hand's rotation key moves
   and undoes exactly (the owner path), and `LiveEasing` sets Ease Out on its
   first segment through the extended `LiveEasing` (KY-8).

## Screens and states

| Screen | Empty | Error | Loading |
|---|---|---|---|
| Properties TRANSFORM rows | no layer selected: `properties` returns `[]` and the inspector shows SCENE | a write on a locked layer throws `CommandError.layerLocked(<id>)` (the workspace shows "Unlock <layer> to draw on it."); a non-finite value throws "<Title> needs a number." and changes nothing, as `FakeProperties` does | none |
| Keyframe button | `.notAnimated` (idle), `.animated`, `.keyedHere` per section 2 | – | – |
| FILL and STROKE | no shape on the selection: the fill write is a no-op that adds no undo entry | negative stroke width throws (LC-7's validation) | – |
| Timeline rows | a scene with no layers: `rows` is `[]` ("No layers yet." empty text, F7a) | a key move onto another key or past the last frame throws, nothing changes | – |

## Contract slice

No contract changes. The live types conform to `PropertyAnimating` and
`KeyframeEditing` in `Sources/FlareModel/Contracts/AnimateContracts.swift`:

```swift
public struct LiveProperties { public init() }   // : PropertyAnimating added in KY-4
//   properties(_:owner:layerIDs:frame:) -> [AnimatedProperty]
//   setValue(_:of:owner:layerIDs:frame:autoKey:coalesceKey:in:)      coalescible
//   toggleAnimated(_:owner:layerID:frame:lastFrame:in:)               grouped "Animate <Title>" / "Stop Animating <Title>"
//   toggleKey(_:owner:layerID:frame:in:)                              single
//   setFill(_:of:in:)  grouped "Set Fill" ; setStroke(_:of:in:)  grouped "Set Stroke"
public struct LiveKeyframes { public init() }    // : KeyframeEditing added in KY-7
//   rows(_:owner:), labels(_:sceneID:)
//   moveKeys(_:by:owner:coalesceKey:in:)  coalescible, throws on a collision
//   removeKeys(_:owner:in:)  grouped "Delete Keyframe"
//   insertFrames / removeFrames  single ; setLabel  single
```

FlareCore calls: `Layer.placement(at:)`, `Layer.standardDefaults`,
`SetKeyframe`, `RemoveKeyframe`, `MoveKeyframe` (with `owner:` after LC-5,
`SetKeyframe` merging after LC-10), `SetShapeFill`, `SetShapeStroke` (LC-7),
`ShiftKeyframes`, `SetSceneTiming`, `SetFrameLabel`, `RemoveFrameLabel`.

## Pseudocode

```
properties(doc, owner, layerIDs, frame):                         # KY-1
  layers = doc.layers(of: owner).filter(layerIDs)
  samples = layers.map { $0.sample(at: Double(frame)) }
  for row in FakeProperties.rows:                                # same rows, ranges, units
    values = samples.map { $0[row.name] ?? Layer.standardDefaults[row.name] ?? 0 }
    states = layers.map { keyState(row.name, $0, frame) }        # <2 keys: notAnimated; key at frame: keyedHere; else animated
    same   = values all equal AND states all equal               # the fake's rule
    value  = same ? values[0] : nil                              # nil = Mixed
    state  = same ? states[0] : .notAnimated                     # a Mixed row shows no marker
  return rows

setValue(v, prop, owner, ids, frame, autoKey, coalesceKey):      # KY-2
  guard v.isFinite else throw "<Title> needs a number."      # no clamp here: the bar slider keeps its range
  for id in ids:
    keys = track(id, prop)
    target = keys.count >= 2 || autoKey ? frame : (keys.first?.frame ?? 0)
    engine.perform(SetKeyframe(owner, id, prop, target, v), coalesceKey: coalesceKey)   # top level, merges (LC-10)

toggleAnimated(prop, owner, id, frame, lastFrame):               # KY-3
  if notAnimated: group("Animate <Title>") { key frame; if one key left and frame==it: key lastFrame same value }
  else:           group("Stop Animating <Title>") { remove all keys; key 0 with value at frame }
toggleKey: key at frame ? RemoveKeyframe : SetKeyframe(sampled value)

setFill / setStroke(items):                                      # KY-4
  shapes = the `.shape(i)` addresses the caller passes (the workspace sends one per shape of a selected layer)
  group("Set Fill" | "Set Stroke") { SetShapeFill | SetShapeStroke per shape }

rows(doc, owner):  per layer: union of track key frames, segments between them, easings by start frame   # KY-5
moveKeys(keys, delta):  try on a copy of the engine first; collision or past the end -> throw, no change   # KY-6
  then perform MoveKeyframe(owner, ...) per key with coalesceKey
insertFrames / removeFrames: ShiftKeyframes; grow the scene with SetSceneTiming in the same step when needed  # KY-7
setLabel: SetFrameLabel / RemoveFrameLabel
```

## Tasks

Every task is one PR to `dev`: at most 400 changed lines and 15 files, label
`fast-lane`, body lines `Belt-Lead:`, `Feature: live-keys`, `Fast-Check:
pass`, `Head:`. KY-9 also carries `feature-done`.

| id | issue | what | owned files | depends on |
|---|---|---|---|---|
| KY-1 | #13 (part) | `LiveProperties.properties`: values, key states, Mixed, owner-aware reads | `Sources/FlareModel/Live/LiveProperties.swift`, `Tests/FlareModelTests/LivePropertiesTests.swift` | – |
| KY-2 | #13 (part) | `setValue` by section 2's rule (no clamp; NaN refused), one merged command per scrub | `Sources/FlareModel/Live/LiveProperties.swift`, `Tests/FlareModelTests/LivePropertiesSetTests.swift` | KY-1, creative-core#171, creative-core#219 |
| KY-3 | #13 (part) | Stopwatch and keyframe button: `toggleAnimated`, `toggleKey` | `Sources/FlareModel/Live/LiveProperties+Keys.swift`, `Tests/FlareModelTests/LivePropertiesKeysTests.swift` | KY-2 |
| KY-4 | #13 (closes) | `setFill` and `setStroke`, and the `PropertyAnimating` conformance | `Sources/FlareModel/Live/LiveProperties+Paint.swift`, `Tests/FlareModelTests/LivePropertiesPaintTests.swift` | KY-3, creative-core#216 |
| KY-5 | #358 (part) | `LiveKeyframes.rows` and `labels` | `Sources/FlareModel/Live/LiveKeyframes.swift`, `Tests/FlareModelTests/LiveKeyframesTests.swift` | – |
| KY-6 | #358 (part) | `moveKeys` (collision and past-the-end refusals) and `removeKeys` | `Sources/FlareModel/Live/LiveKeyframes+Edit.swift`, `Tests/FlareModelTests/LiveKeyframesEditTests.swift` | KY-5, creative-core#171 |
| KY-7 | #358 (closes) | `insertFrames`, `removeFrames` (labels move with a whole-scene shift, the scene grows), `setLabel`, and the `KeyframeEditing` conformance | `Sources/FlareModel/Live/LiveKeyframes+Frames.swift`, `Tests/FlareModelTests/LiveKeyframesFramesTests.swift` | KY-6 |
| KY-8 | – | `LiveEasing` on a symbol's layers (the owner path, LC-5) | `Sources/FlareModel/Live/LiveEasing.swift`, `Tests/FlareModelTests/LiveEasingTests.swift` | creative-core#171 |
| KY-9 | – | The model journey (steps 1–7) and the QB-L7 budget | `Tests/FlareModelTests/LiveKeysJourneyTests.swift`, `Tests/FlareModelTests/LiveKeysBudgetTests.swift` | KY-4, KY-7, KY-8 |

KY-1 to KY-4, KY-5 to KY-7 and KY-8 can run side by side. The
issues list one source and one test file each; the packet splits them into
extension files so no PR passes 400 lines, and the PRs say so. No file here
is owned by another feature.

## Acceptance test per task

| id | test | fails when |
|---|---|---|
| KY-1 | `LivePropertiesTests`: equals `FakeProperties.properties` on `bounce` for Ball, Shadow and both, at frames 0, 12, 30 and 47 (at 0 Ball and Shadow give scale X `nil` and `.notAnimated`: equal values, different key states); inside "wave" the hand's rows equal the fake's too (reads work on any owner), with rotation 25 at 12 | a value, a key state or Mixed differs from the fake, or the symbol owner fails |
| KY-2 | `LivePropertiesSetTests`: keys at 0 and 24 (x 0 and 120) give `placement(at: 12).transform.x == 60`; Shadow X at 30 with auto-key off stays `.notAnimated` with its one key at 0; with auto-key on it becomes `.animated`; 120 calls with one key are one entry (one `undo()` restores Ball); two consecutive `SetKeyframe`s on one key merge (`a.merge(b)` is true); a symbol layer's key sets and undoes exactly; NaN throws and changes nothing | a not-animated edit adds a second key, a scrub leaves 2 entries, the commands don't merge, or a NaN lands |
| KY-3 | `LivePropertiesKeysTests`: the stopwatch on Shadow X at 0 gives keys at 0 and 47 named "Undo Animate X"; off again leaves one key at 0 with the value at the playhead; `toggleKey` adds then removes the key at 20 (one entry each) | the stopwatch leaves one diamond, or off loses the value |
| KY-4 | `LivePropertiesPaintTests`: fill `FF3B30` on Ball sets every shape in one "Undo Set Fill"; stroke width 4, cap and join Round each one entry and one undo restores only the join; a direct-selected item's fill changes only that shape; width -1 throws | a second entry, a shape left out, or a bad stroke passes |
| KY-5 | `LiveKeyframesTests`: equals `FakeKeyframes.rows` and `.labels` on `bounce` and `character`; inside "wave" the hand's row lists keys 0, 12, 23 | a row, key, segment or easing differs from the fake |
| KY-6 | `LiveKeyframesEditTests`: Ball's 24 → 28 is one "Undo Move Keyframe"; 24 onto 36 throws and the document, `canUndo` and `undoActionName` are unchanged; past frame 47 throws; 50 coalesced one-frame steps are one entry (one `undo()` restores the key); deleting 12 is one "Undo Delete Keyframe"; a symbol key moves and undoes exactly | a collision lands, a drag leaves several entries, or the owner path breaks |
| KY-7 | `LiveKeyframesFramesTests`: two frames inserted at 10 move 28 to 30; a key pushed past 47 grows the scene in the same entry; one removed moves it to 29; on every layer a label at 29 moves with it; `setLabel("hit", 29)` then `nil` removes it; each step is one entry | keys, labels or the scene length are wrong, or a step is two entries |
| KY-8 | `LiveEasingTests` (extended): Ease Out on the hand's first segment inside "wave" is one entry and undoes exactly; the existing scene-layer tests still pass; a symbol layer that doesn't exist throws `layerNotFound` | the symbol owner still throws, or scene easing changes |
| KY-9 | `LiveKeysJourneyTests.testMoveAndKey`, `.testInspectorKeysTransform`, `.testFillAndStroke`, `.testRetimeDeleteInsertAndLabel`, `.testEasingInsideASymbol` walk steps 1–7 with a real `CommandEngine` | any step's values or undo names differ from J6–J8, J11 and J12 |

## Quality tests

| quality row | budget (CI gate, debug) | test |
|---|---|---|
| QB-L7 one drag step through the engine | ≤ 10 ms per `setValue` scrub step (perform and validate) on `bounce` | `LiveKeysBudgetTests.scrubStepWithinBudget` (median of 120 steps) |
| QB-F3 one gesture, one step | a scrub, a key drag and each menu action are one named entry; scrubbing never adds a second | `LivePropertiesSetTests`, `LiveKeyframesEditTests` (one `undo()` restores) |
| QB-L3 hook | a key drag of 50 steps is one entry, and `MoveKeyframe` merges (`a.merge(b)`), so timeline scrubs stay cheap | `LiveKeyframesEditTests.coalescedDragIsOneEntry` |

## Done check

- **Journeys green:** the macOS run on `dev` triggered by the `feature-done`
  PR (KY-9) is green, `FlareJourneyTests` included.
- **Audit zero new:** no Flare count over `UITests/audit-baseline.json`.
- **Contact sheet:** `Belt-Contact-Sheet: <run link>` on the feature issue;
  no Flare screen changes (the live types are not wired until IN-1 and
  IN-2), and the comment says so.
