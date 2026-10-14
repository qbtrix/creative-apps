# Feature packet: live-stage

**Feature:** draw and select on real documents. The stage picture, hit
testing, marquee, selection bounds and the shape tools (Rectangle, Ellipse,
Pen, box move, scale and rotate, path edit, delete, duplicate, copy and paste)
run on FlareCore instead of the fakes.
**Line:** `line:flare` · **Wave:** 2 (`waves.md`) · **Lead branch:** `lead/live-stage`

**Covers:** #357 (LM-2), #740 (LM-3b). #357 closes with ST-5, #740 with ST-9.

**Depends on:** qbtrix/creative-core#213 (LC-1 render list),
qbtrix/creative-core#214 (LC-2 topmost hit and marquee),
qbtrix/creative-core#215 (LC-3 world bounds), qbtrix/creative-core#182 (LC-4
path builders), qbtrix/creative-core#173 (LC-6 instance commands),
qbtrix/creative-core#216 (LC-7 `SetShapeStroke`, `SetShapePath`,
`DuplicateLayer`; it follows LC-6). None had landed on creative-core `main`
cfad97f (2026-10-14). The lead's first stage checks each one; a task whose
engine issue is still open waits, and the others go ahead (ST-3 needs only
#214, ST-6 only #182).

Blueprint sections: 2 (selection and transforms, one undo step, rendering),
6.2 (`StageRendering`, `StageHitTesting`, `ShapeBuilding`), 7.5 (LM-2, LM-3).
Nothing here is wired into `FlareServices.live`; IN-1 (#397) does that after
gate G2.

**How a chain compiles.** A protocol conformance must have every
requirement in the PR that declares it. So `LiveHits` and `LiveShapes` are
declared as plain structs in the first task of their chain, each later task
adds its methods in its own extension file, and the last task of the chain
adds the one line `extension LiveX: Protocol {}` in its own file. No task
edits a file another task in the chain owns, except where the table chains
them. `LiveStage` has one requirement and conforms in ST-1.

## Journey steps

J3 (draw with each tool) and J5 (select, marquee, scale, rotate) are the
journeys; their UI is F4a (#203) and F3b (#204). This feature proves their
Model half on the live types, in
`Tests/FlareModelTests/LiveStageJourneyTests.swift` (ST-10):

1. On `empty`, a Rectangle draft from (100, 100) to (300, 200) and its commit
   add "Rectangle 1" in one entry, "Undo Add Rectangle".
2. An Ellipse with Shift has equal width and height; a Pen path of three
   corners closed on the first point, and a Pen drag at the second point,
   give "Path 1" and "Path 2" whose second anchor is smooth.
3. The live draw list of the result has those items in paint order, curves
   as cubics.
4. On `bounce`, a hit at Ball's center returns Ball; the Background is locked
   and never hit; a marquee around Ball and Shadow returns both in paint
   order.
5. A box scale from the bottom-right handle keeps the top-left corner within
   1e-9; a rotate turns about the box center; each is one named entry.
6. Copy Ball, paste: "Ball copy" above Ball, 10 pt right, one "Undo Paste".

## Screens and states

| Screen | Empty | Error | Loading |
|---|---|---|---|
| Stage | no scene with that id: a 0 × 0 list with no items (as `FakeStage`); an empty scene: the background only | a missing or cyclic symbol: that instance is skipped, nothing throws; a text item is listed with an empty path and counted in `hiddenTextCount` | none (the list is built per frame, inside QB-L6) |
| Selection | a click on empty stage or on a locked or hidden layer: `hit` returns nil | – | – |
| Tool rail | `unavailableHelp(for:)` is nil for every tool (the workspace's `toolHelp` covers "no document") | a draw above a locked layer throws `CommandError.layerLocked(<id>)`, which the workspace turns into "Unlock <layer> to draw on it."; a garbage paste throws "Nothing to paste."; moving a text item throws "Text can't be moved yet." (no FlareCore command moves text) | – |

## Contract slice

No contract changes. The live types conform to the protocols in
`Sources/FlareModel/Contracts/StageContracts.swift` and `ShapeContracts.swift`:

```swift
public struct LiveStage: StageRendering { public init() }        // drawList(_:sceneID:frame:editing:)
public struct LiveHits { public init() }                         // : StageHitTesting added in ST-4
public struct LiveShapes { public init() }                       // : ShapeBuilding added in ST-9
```

The FlareCore calls they wrap: `Scene.renderList(at:symbols:)` (LC-1), the
topmost-hit and marquee queries with a tolerance (LC-2), world bounds with
stroke (LC-3), the rectangle-with-radius and ellipse builders (LC-4),
`AddLayer`, `AddShape`, `SetKeyframe`, `TranslateShape`, `RemoveShape`,
`RemoveTextShape`, `RemoveLayer`, `SetInstanceTransform` and `RemoveInstance`
(LC-6), `SetShapePath` and `DuplicateLayer` (LC-7), and `CommandRegistry`
envelopes for copy and paste. Undo cases are section 2's: a commit, a box
gesture, Paste and Delete of several items are each one `engine.group(name)`;
nothing performs while the pointer moves.

`boxResult` (the box math: the scaled or rotated box for a handle drag) is
already written in `FakeShapes` (`boxResult`, `obliqueScale`, `fit`, `ratio`,
`lineTolerance`, `handle`, `corners`), and its oblique-scale path creates a
`FakeStage` to read item boxes. ST-7 moves that math into
`Sources/FlareModel/Live/BoxGestureMath.swift` and makes it take the draw
list as a parameter instead of creating a `FakeStage`; `FakeShapes` passes
`FakeStage`'s list and keeps a forwarding `FakeShapes.handle` (nine existing
test files call it), and `LiveShapes` passes `LiveStage`'s list. So the two
can't drift and no live type ever creates a fake (IN-9's check). The helper
sits under `Live/`, where the `flare-model-sources` description ("their live
conformances over FlareCore") already covers it, so ST-7 needs no
`docs/c4/model.json` edit, which export-preview owns in this wave.

## Pseudocode

```
LiveStage.drawList(doc, sceneID, frame, editing):          # ST-1, ST-2
  guard scene = doc.scene(sceneID) else empty 0x0 list
  owner = editing.map(.symbol) ?? .scene(sceneID)
  items = scene.renderList(at: Double(frame), symbols: doc.symbols, owner)   # LC-1, nested instances included
  map each render item -> StageItem(address, path (cubics kept), fill, stroke, matrix, opacity)
  hiddenTextCount = items.count(where: isText)
  return StageDrawList(width, height, background, items)

LiveHits.hit(doc, scene, frame, editing, point, tolerance):  # ST-3
  core topmost hit (LC-2) at point with tolerance, skipping hidden, locked and text -> StageAddress?
LiveHits.marquee(...rect):  core marquee query, paint order                  # ST-4
LiveHits.bounds(...items):  union of core world bounds with stroke (LC-3), nil when empty

LiveShapes.draft(tool, start, end, modifiers):              # ST-6
  rectangle: PathBuilders rect(box, radius) ; shift -> square box
  ellipse:   PathBuilders ellipse(box)       ; shift -> circle
  pen:       anchors so far; a drag at an anchor -> smooth (handles mirrored, G1)
LiveShapes.commit(draft, owner, above):  guard above not locked else throw layerLocked
  engine.group("Add <Kind>") { AddLayer; AddShape }
BoxGestureMath.result(gesture, list: StageDrawList, ...)    # ST-7: moved, FakeStage() replaced by the list parameter
LiveShapes.boxResult = BoxGestureMath.result(..., list: LiveStage().drawList(...))   # ST-8
LiveShapes.commitBox(gesture, layers, box):  engine.group("Move"|"Scale"|"Rotate") {
  per layer: SetKeyframe x, y, scaleX, scaleY, rotation by section 2's not-animated rule }

LiveShapes edit (ST-9): setPath -> SetShapePath ;
  translate: shape -> TranslateShape ; instance -> SetInstanceTransform ; text -> throw "Text can't be moved yet."
  delete -> group("Delete") { RemoveShape | RemoveTextShape | RemoveInstance } ;
  duplicate -> group("Duplicate") { DuplicateLayer } ;
  copy -> CommandRegistry envelopes ; paste -> decode or throw "Nothing to paste.", group("Paste"), offset 10 pt
```

## Tasks

Every task is one PR to `dev`: at most 400 changed lines and 15 files, label
`fast-lane`, body lines `Belt-Lead:`, `Feature: live-stage`, `Fast-Check:
pass`, `Head:`. ST-10 also carries `feature-done`.

| id | issue | what | owned files | depends on |
|---|---|---|---|---|
| ST-1 | #357 (part) | `LiveStage` on the render list: scene layers, paint order, opacity, cubics kept | `Sources/FlareModel/Live/LiveStage.swift`, `Tests/FlareModelTests/LiveStageTests.swift` | creative-core#213 |
| ST-2 | #357 (part) | `LiveStage`: instances nested two deep, editing a symbol in place, text counted | `Sources/FlareModel/Live/LiveStage.swift`, `Tests/FlareModelTests/LiveStageNestingTests.swift` | ST-1 |
| ST-3 | #357 (part) | `LiveHits` struct and `hit`: topmost with address, tolerance, hidden, locked and text skipped, editing in place | `Sources/FlareModel/Live/LiveHits.swift`, `Tests/FlareModelTests/LiveHitsTests.swift` | creative-core#214 |
| ST-4 | #357 (part) | `marquee`, `bounds` (with stroke), and the `StageHitTesting` conformance | `Sources/FlareModel/Live/LiveHits+Marquee.swift`, `Tests/FlareModelTests/LiveHitsBoundsTests.swift` | ST-3, creative-core#215 |
| ST-5 | #357 (closes) | `LiveConformanceTests`: `noFixtureEditInLive` and live-equals-fake for the stage on `bounce` and `character` | `Tests/FlareModelTests/LiveConformanceTests.swift` | ST-2, ST-4 |
| ST-6 | #740 (part) | `LiveShapes` struct, `unavailableHelp`, drafts and commits for Rectangle, Ellipse and Pen | `Sources/FlareModel/Live/LiveShapes.swift`, `Tests/FlareModelTests/LiveShapesTests.swift` | creative-core#182 |
| ST-7 | #740 (part) | The pure move: box math out of `FakeShapes` into `BoxGestureMath`, the draw list as a parameter, a forwarding `FakeShapes.handle`; no behavior change | `Sources/FlareModel/Live/BoxGestureMath.swift`, `Sources/FlareModel/Fakes/FakeShapes.swift`, `Tests/FlareModelTests/BoxGestureMathTests.swift` | – |
| ST-8 | #740 (part) | `boxResult` and `commitBox` on `LiveShapes` over `BoxGestureMath` and `LiveStage` | `Sources/FlareModel/Live/LiveShapes+Box.swift`, `Tests/FlareModelTests/LiveShapesBoxTests.swift` | ST-6, ST-7, ST-1 |
| ST-9 | #740 (closes) | Edits: `setPath`, `translate`, `delete`, `duplicate`, `copy`, `paste`, and the `ShapeBuilding` conformance | `Sources/FlareModel/Live/LiveShapes+Edit.swift`, `Tests/FlareModelTests/LiveShapesEditTests.swift` | ST-8, creative-core#173, creative-core#216 |
| ST-10 | – | The model journey (steps 1–6) and the stage budgets on the live types | `Tests/FlareModelTests/LiveStageJourneyTests.swift`, `Tests/FlareModelTests/LiveStageBudgetTests.swift` | ST-5, ST-9 |

ST-1 to ST-5, ST-6 and ST-7 can start side by side (ST-7 needs no engine
change, so it can go first); ST-8 joins them. ST-1 and ST-2 share
`LiveStage.swift`, stacked. ST-7 touches `FakeShapes.swift` only to move the
box math out: the existing `ShapeFakes*Tests` and `ShapeScale*Tests` must
pass unchanged, which proves the move. ST-7 is about 150 lines moved (300 in
the diff count, deleted plus added) and a short test; if it nears 400, the
lead moves the oblique-scale part in its own PR first. No file here is owned
by another feature; `FakeShapes.swift` is in no other packet.

## Acceptance test per task

| id | test | fails when |
|---|---|---|
| ST-1 | `LiveStageTests`: `bounce` at frames 0, 12 and 47 equals `FakeStage` item for item (address, path, fill, stroke, matrix within 1e-9, opacity); a hidden layer is absent; each `cubic` in a shape's outline is a `cubic` in the item | live and fake disagree, a hidden layer draws, or a curve is flattened |
| ST-2 | `LiveStageNestingTests`: a test-built scene with an instance of a symbol that holds an instance of a second symbol draws every leaf shape with the multiplied opacity (the fake stops one level deep, so this compares against values the test computes); editing "wave" in `character` lists only the symbol's layers; a text item gives `hiddenTextCount` 1 and an empty path | a nested leaf is missing, opacity isn't multiplied, or the scene shows while editing a symbol |
| ST-3 | `LiveHitsTests`: Ball's center hits Ball; a point inside Ball's bounding box but outside its circle misses (the core is geometric; `FakeHits` uses boxes, so this is not compared with the fake); 4 pt off a 0-width stroke hits at tolerance 4; the locked Background and a hidden layer never hit; inside a symbol only its items hit; at the center of every shape and at 10 points at least 50 pt outside every box, live equals `FakeHits` | a locked or hidden layer is hit, the tolerance is ignored, or live and fake disagree where both are exact |
| ST-4 | `LiveHitsBoundsTests`: a marquee around Ball and Shadow gives both in paint order; a marquee over only Background gives `[]`; bounds of a test-built 10-wide stroked square grow by 5 on each side; bounds of `[]` are nil; a rotated layer's bounds within 1e-9 of the core's; `LiveHits()` used as `any StageHitTesting` compiles | the order changes, a locked layer is picked, or the stroke is left out |
| ST-5 | `LiveConformanceTests.noFixtureEditInLive` reads every `.swift` under `Sources/FlareModel/Live/` (found from `#filePath`), fails on the string `FixtureEdit`, and fails if it found fewer than 3 files (so a wrong path can't pass); `liveStageEqualsFake` over `bounce` and `character` (scene level, where the fake is exact) | a live file uses `FixtureEdit`, the scan reads nothing, or live and fake drift |
| ST-6 | `LiveShapesTests`: a Rectangle draft is the LC-4 rectangle path for its box and Shift makes it square; an Ellipse is four cubics (the fake draws 32 lines, so geometry is checked against the builders, not the fake); a pen drag makes a smooth anchor with G1 continuity (handles collinear within 1e-9); a rectangle commit is one entry "Undo Add Rectangle" and the new layer's id and name ("Rectangle 1") equal the fake's; a commit above a locked layer throws `CommandError.layerLocked` with its id | a curve is flattened, an extra undo entry, a broken G1 handle, or a name differs from the fake |
| ST-7 | `BoxGestureMathTests`: for each handle and a rotate on `bounce`, `BoxGestureMath.result` with `FakeStage`'s list equals what `FakeShapes.boxResult` returned before the move (values recorded in the test from the pre-move code); every existing `ShapeFakes*Tests` and `ShapeScale*Tests` passes unchanged; no line under `Sources/FlareModel/Live/` names `FakeStage` | the math changed in the move, or the helper still creates a fake |
| ST-8 | `LiveShapesBoxTests`: a scale keeps the opposite corner within 1e-9; a rotate keeps the box center; each `commitBox` is one entry named "Move", "Scale" or "Rotate"; the box and the layer transforms after each gesture equal `FakeShapes` on `bounce` | a corner drifts, a gesture is two entries, or live and fake differ |
| ST-9 | `LiveShapesEditTests`: `setPath` then undo restores the path exactly; `translate` of a direct-selected shape leaves the layer transform unchanged; translating a text item throws "Text can't be moved yet." and changes nothing; `duplicate` gives "Ball copy" with a fresh id in "Undo Duplicate"; copy then paste gives "Ball copy" 10 pt right in one "Undo Paste"; `paste(Data("x".utf8))` throws "Nothing to paste."; delete of a shape and an instance is one "Undo Delete"; `LiveShapes()` used as `any ShapeBuilding` compiles | a second undo entry, a reused id, garbage pastes, or a text move lands |
| ST-10 | `LiveStageJourneyTests.testDrawShapesWithEachTool` and `.testSelectMarqueeScaleRotate` walk steps 1–6 on `LiveStage`, `LiveHits` and `LiveShapes` with a real `CommandEngine` | any step's names, counts or values differ from J3 and J5 |

## Quality tests

| quality row | budget (CI gate, debug) | test |
|---|---|---|
| QB-L5 hit per pointer move | ≤ 10 ms on `bounce` (on `reference` once #326 lands; #328 asserts it there) | `LiveStageBudgetTests.hitWithinBudget` (median of 50 runs) |
| QB-L6 draw list per frame | ≤ 20 ms on `bounce` | `LiveStageBudgetTests.drawListWithinBudget` |
| QB-L11 model half | one frame's list with nested instances ≤ 40 ms | `LiveStageBudgetTests.nestedDrawListWithinBudget` (the ST-2 scene) |
| QB-V1 curves stay curves | each `cubic` stays a `cubic` in the draw list | `LiveStageTests.cubicsKept`, `LiveShapesTests.ellipseIsFourCubics` |
| QB-F3 one gesture, one step | every commit and box gesture is one named entry: after it, one `undo()` restores the document and leaves `canUndo` as it was before | `LiveShapesTests`, `LiveShapesBoxTests`, `LiveShapesEditTests` |

The budget files are new (`LiveStageBudgetTests.swift`); `StageBudgetTests`
belongs to QH-3 (#328), which is `p3` and later.

## Done check

- **Journeys green:** the macOS run on `dev` triggered by the `feature-done`
  PR (ST-10) is green, `FlareJourneyTests` included.
- **Audit zero new:** no Flare count over `UITests/audit-baseline.json`.
- **Contact sheet:** `Belt-Contact-Sheet: <run link>` on the feature issue;
  the window does not change (the live types are not wired until IN-1), and
  the comment says so.
