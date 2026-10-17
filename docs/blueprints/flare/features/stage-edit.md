# Feature packet: stage-edit

**Feature:** select, transform and edit art on the stage of a real
document. Click, Shift-click and marquee select; the box with its eight
scale handles and the rotate zone; zoom, pan, rulers and guides; Cut, Copy,
Paste, Duplicate, Delete, Select All and Deselect through the menus, the
stage's context menu and the pasteboard; the full draw journey with Pen.
**Line:** `line:flare` · **Wave:** 4 (`waves.md`) · **Lead branch:** `lead/stage-edit`

**Covers:** F3b #204 (closes with SE-1; its drag-to-key half landed in
`draw-key-save` DK-14), F3c #375, F18 #384, and the stage half of IN-1 #397
(J3, J5 and J15 green live). #397 closes with whichever of this feature's
SE-5 and `inspector-timeline`'s IT-10 lands second (J6 to J8 are there).

**Depends on:** the `draw-key-save` feature issue (its window, router,
stage, `.built` services and menu bar). Of the four running features it
needs live-stage #798, through `draw-key-save`'s DK-3. At task level only:
SE-1 waits on S12 #273 (`SelectionHandles`), SE-2 on #273 (guide marks) and
on #995 (ruler toggle and drag-out guides). SE-3 and SE-4 need neither, so
the lead starts them at once.

Blueprint sections: 2 (selection and transforms, one undo step), 3.1 (stage),
3.4 (Edit, View and Object menus, the stage context menu), 4 (J3, J5, J14,
J15), 7.3 (F3b, F3c, F4a, F18), 7.6 (IN-1).

**Where it starts from.** The Model already marquees on empty stage and
moves an item with a Select drag (`FlareDrag.swift`, `FlareSelection.swift`).
It does not yet scale or rotate: no code hit-tests the eight handles or the
rotate zone, previews a scale or rotate, or commits `.scale`/`.rotate`, though
the use case can (`ShapeBuilding.boxResult` and `commitBox`, live in
`LiveShapes+Box`). SE-0 adds that to the workspace.
the Edit actions and their refusals are in `FlareEdit.swift` (`copy`, `cut`,
`paste`, `duplicate`, `delete`, `selectAll`, `deselect`, `editHelp`); guides
in `FlareGuides.swift`. `draw-key-save` leaves stubs this feature fills:
`FlareStageSelection.swift`, `FlareStageGuides.swift`, `FlareStageContextMenu.swift`
(each given read-only `model`, `zoom` and `perform`),
`FlareWindow+View.swift` and `FlareWindow+Edit.swift`, and the window's
`zoom`, `showsRulers` and `showsGuides` state.

**Not here.** Direct Select's anchor and handle marks (F4b #390) are `p2`
and come after this feature; the Direct Select tool already acts through
`drag` in the Model. Snapping is v1.1. The inspector's "Mixed" reading (J5's
inspector step) is `inspector-timeline`'s; J5 here reads the selection from
the stage.

## Journey steps

All launch with `-FlareSample <fixture>`: the fixture document on `.built`
(live) services, so each journey is also its IN-1 check.

| # | step | task | journey test |
|---|---|---|---|
| 1 | V; click Ball; Shift-click Shadow; click empty stage; marquee Ball and Shadow; click Ball; drag the bottom-right handle out by half the box; drag the rotate zone a quarter turn | SE-0, SE-1 | J5 `FlareSelectJourneys.testSelectMarqueeScaleRotate` |
| 2 | ⌘+ twice; Space-drag 100 pt; ⌘0; drag from the top ruler to y 300; drag that guide to 320; drag it back onto the ruler; ⌘R | SE-2 | J14 `FlareViewJourneys.testZoomPanAndGuides` |
| 3 | select Ball; ⌘C; ⌘V; ⌘D; select Shadow; ⌘X; ⌘V; select "Ball copy 2"; ⌫; the stage context menu on Ball | SE-3 | J15 `FlareEditJourneys.testCopyPasteDuplicateDelete` |
| 4 | Select All, Deselect, Bring Forward, Send Backward; Escape cancels a marquee | SE-4, SE-5 | `FlareEditOrderJourneys.testSelectAllOrderAndEscape` |
| 5 | J3 in full on `empty`: the timeline's empty text; R; E with Shift; P closed triangle; P with a drag at the second point and Return; ⌘Z | SE-5 | J3 `FlareDrawJourneys.testDrawShapesWithEachTool`, extended |

## Screens and states

| screen | state | snapshot PNG |
|---|---|---|
| Stage | one selection: box, 8 handles, rotate zone | `flare-select-one@2x.png` (SE-1) |
| Stage | two selected after a marquee: one box around both | `flare-select-two@2x.png` (SE-1) |
| Stage | during a scale drag: the preview box and art, no commit | `flare-select-scaling.png` (SE-1) |
| Stage | a locked layer: no box, clicks pass through | `flare-select-locked.png` (SE-1) |
| Stage | zoom 200%, rulers on; two guides, one being dragged | `flare-view-guides@2x.png` (SE-2) |
| Stage | rulers hidden | `flare-view-norulers.png` (SE-2) |
| Edit | "Nothing to paste." on Paste with an empty pasteboard: the item disabled with that reason | journey shot `edit-paste-disabled` (SE-3) |
| Stage | the context menu on Ball | journey shot `stage-context-menu` (SE-3) |

## Contract slice

Model (Linux, tested):

```swift
// Sources/FlareModel/FlareBoxDrag.swift (SE-0), plus the gesture's handle in FlareDrag.swift's StageGesture
public struct StageHandle: Sendable, Equatable {
    public enum Kind: Sendable, Equatable { case corner(Int), edge(Int), rotate }   // 0...3 clockwise from top-left
    public var kind: Kind, point: Point                                            // scene points
}
extension FlareWorkspace {
    public func handles(of box: Rect, rotation: Double) -> [StageHandle]   // 4 corners, 4 edges, the rotate zone
    func handle(at point: Point, stageScale: Double) -> StageHandle?        // hit within FlareWorkspace.hitSlop
}
// dragChanged with .select starting on a handle: dragPreview = boxResult(scale or rotate) ; endDrag: commitBox

// Sources/FlareModel/FlareSelectionRead.swift (SE-1)
public struct SelectionReadout: Sendable, Equatable {
    public var count: Int                      // "2 selected"
    public var box: Rect?                      // scene points, rotation applied
    public var rotation: Double?               // degrees, nil when mixed
    public var scaleX: Double?, scaleY: Double?  // nil when mixed
    public var handles: [StageHandle]          // SE-0's handles(of:rotation:) for the box
}
extension FlareWorkspace { public var selectionReadout: SelectionReadout }

// Sources/FlareModel/FlareViewMath.swift (SE-2)
public enum FlareZoom {
    public static func zoomIn(_ zoom: Double) -> Double     // the next ZoomMath-like step, 10%...3200%
    public static func zoomOut(_ zoom: Double) -> Double
    public static func readout(_ zoom: Double?) -> String   // "Fit", "200%"
}
extension FlareWorkspace {
    public func guideReadout(at index: Int) -> String?      // "y 300"
}

// Sources/FlareModel/FlareEditOrder.swift (SE-4)
extension FlareWorkspace {
    public mutating func bringForward()        // one "Undo Bring Forward"; refused at the top with a reason
    public mutating func sendBackward()
    public func orderHelp(forward: Bool) -> String?
}
```

App: `FlareStageSelection(model:, zoom:, perform:)` reads `model.selectionReadout` and draws `SelectionHandles` (S12)
and carries `flare.stage.selection` with the readout as its value
("2 selected, scale 1.50 × 1.50, rotation 90°"); `FlareStageGuides` draws
the guide marks and gives each guide `flare.stage.guide.<i>` with its
readout; `FlarePasteboard` reads and writes `com.qbtrix.flare.items`
(Flare's private type) on `NSPasteboard.general`.

## Pseudocode

```
FlareStageSelection:                                      # SE-1
  guard let box = readout.box: nothing
  SelectionHandles(box, rotation, handles, zoom)         # S12 #273; hits only the gesture's, never its own
  accessibilityValue(readout text)
# The gesture is draw-key-save's: a drag starting on a handle reaches dragChanged; SE-0's Model picks the handle.
dragChanged(.select) (SE-0): if gesture is new and handle(at: start) = h: gesture.handle = h
  h.corner/edge -> dragPreview = list with boxResult(.scale(h), selection, end) applied
  h.rotate      -> dragPreview = list with boxResult(.rotate, selection, end) applied
endDrag (SE-0): gesture.handle != nil -> commitBox (one "Scale" or "Rotate" entry) ; else today's move or marquee

performView:                                              # SE-2
  .zoomIn  -> zoom = FlareZoom.zoomIn(zoom ?? fitted) ; .zoomOut likewise ; .fit -> zoom = nil ; .actualSize -> 1
  .toggleRulers -> showsRulers.toggle() ; .toggleGuides -> showsGuides.toggle() ; .clearGuides -> model.clearGuides()
FlareStageGuides:
  onRulerDrag(drag):  .changed first -> model.addGuide(axis, at: pos) ; later -> model.moveGuide(i, to: pos, dragStart:)
                      .ended -> model.endGuideDrag() ; isOverRuler -> model.removeGuide(i)
  a guide line drag   -> moveGuide ... endGuideDrag (one "Undo Move Guide")

performEdit:                                              # SE-3
  .copy  -> FlarePasteboard.write(model.copy())
  .cut   -> FlarePasteboard.write(model.cut())
  .paste -> model.paste(FlarePasteboard.read())
  .duplicate / .delete / .selectAll / .deselect -> the Model's
editHelp(intent) = model.editHelp(action, pasteboard: FlarePasteboard.read())   # "Nothing to paste."
FlareStageContextMenu (the modifier DK-8 applies): .contextMenu on a hit item: Cut, Copy, Duplicate, Delete, Bring Forward, Send Backward
            (Convert to Symbol shows disabled with the library's reason until library lands)

bringForward:                                             # SE-4
  guard one owner, every selected layer below the top else refuse "Already at the front."
  through the same command as moveLayer, one "Bring Forward" entry
```

## Tasks

Every task is one PR to `dev`: at most 400 changed lines and 15 files, label
`fast-lane`, body lines `Belt-Lead:`, `Feature: stage-edit`, `Fast-Check:
pass`, `Head:`. SE-5 also carries `feature-done`.

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| SE-0 | #204 (part) | Scale and rotate by the box in the workspace: handle hit-testing, the preview through `boxResult`, the commit through `commitBox` | `Sources/FlareModel/FlareBoxDrag.swift`, `Sources/FlareModel/FlareDrag.swift`, `Sources/FlareModel/FlareSelection.swift`, `Tests/FlareModelTests/FlareBoxDragTests.swift` | – | ~320, 4 files |
| SE-1 | #204 (closes) | Selection readout in the Model; the box, handles and rotate zone on the stage; J5 | `Sources/FlareModel/FlareSelectionRead.swift`, `Tests/FlareModelTests/FlareSelectionReadTests.swift`, `Sources/FlareApp/FlareStageSelection.swift`, `Tests/AppSnapshotTests/FlareSelectSnapshots.swift`, `UITests/FlareJourneyTests+Select.swift` | SE-0, #273 | ~340, 5 files |
| SE-2 | #375 (closes) | Zoom steps, fit, 100%, Space-pan, rulers on and off, guides out of the rulers, moved and removed; J14 | `Sources/FlareModel/FlareViewMath.swift`, `Tests/FlareModelTests/FlareViewMathTests.swift`, `Sources/FlareApp/FlareStageGuides.swift`, `Sources/FlareApp/FlareStage.swift`, `Sources/FlareApp/FlareWindow+View.swift`, `Tests/AppSnapshotTests/FlareViewSnapshots.swift`, `UITests/FlareJourneyTests+View.swift` | #273, #995 | ~380, 7 files |
| SE-3 | #384 (closes) | Edit actions through the pasteboard, their reasons, the stage context menu; J15 | `Sources/FlareApp/FlareWindow+Edit.swift`, `Sources/FlareApp/FlarePasteboard.swift`, `Sources/FlareApp/FlareStageContextMenu.swift`, `UITests/FlareJourneyTests+Edit.swift` | SE-4 | ~260, 4 files |
| SE-4 | see #384 | Bring Forward and Send Backward in the Model with their refusals | `Sources/FlareModel/FlareEditOrder.swift`, `Tests/FlareModelTests/FlareEditOrderTests.swift` | – | ~160, 2 files |
| SE-5 | see #397 | J3 in full on live; the order journey; this packet's status line | `UITests/FlareJourneyTests+Draw.swift`, `UITests/FlareJourneyTests+EditOrder.swift`, `docs/blueprints/flare/features/stage-edit.md` | SE-1, SE-2, SE-3, SE-4 | ~200, 3 files |

`FlareStage.swift` is `draw-key-save`'s file; in this feature only SE-2
edits it (the ruler arguments of #995 on its `CanvasViewport`), and no other
wave-4 feature does. The context menu is its own modifier file, which DK-8
applies as a stub. `FlareDrag.swift` and `FlareSelection.swift` are edited
only by SE-0, in any wave-4 feature. Bring Forward and Send Backward are
Object-menu intents in the `.edit` area, so SE-3 routes them to SE-4's
methods and stacks on SE-4. Undo and Redo in `+Edit.swift` are already
routed (draw-key-save DK-7); SE-3 adds the rest.

**Shared docs.** This is a wave-4 feature running beside
`inspector-timeline` and `layers-files`, so its final task edits no shared
doc (`docs/c4/model.json`, `docs/design.md`, `flare.md`, `waves.md`): its new
files sit under the `flare-app` and `flare-model` paths and the components'
descriptions already cover them ("views in Sources/FlareApp", "FlareWorkspace
… selection, tool"). The status goes in this packet and `stage-edit.wave.json`; the next packet
writer refreshes `flare.md` section 0.

## Build waves

- Wave 1: SE-0, SE-2, SE-4. Independent in this wave: all three. SE-0 and
  SE-4 start at once; SE-2 starts when #273 and #995 close.
- Wave 2: SE-1, SE-3. Independent in this wave: both (SE-1 starts when #273
  closes).
- Wave 3: SE-5 (final).

Longest chain: SE-0 → SE-1 → SE-5 and SE-4 → SE-3 → SE-5 (3).

## Acceptance test per task

| id | test | fails when |
|---|---|---|
| SE-0 | `FlareBoxDragTests` on `.fake()` and `.built`: a Select drag from Ball's bottom-right handle out by half the box previews scale 1.5 with the top-left corner fixed (1e-9) and performs nothing before `endDrag`; `endDrag` is one "Undo Scale"; a drag on the rotate zone a quarter turn is one "Undo Rotate" about the box centre; a drag starting 10 pt off every handle moves or marquees as before; `handles(of:rotation:)` gives 9 handles at the corners, edge midpoints and above the top edge | a handle isn't hit, a preview commits, a gesture is two entries, or a move turns into a scale |
| SE-1 | `FlareSelectionReadTests` on `.fake()` and `.built`: Ball alone gives count 1 and its box; Ball and Shadow give 2 and their union; a scale preview gives scale 1.5 before `endDrag`; rotation 90 after a quarter-turn commit; 8 handles plus the rotate zone at the box's corners and edge midpoints. `FlareSelectSnapshots` (four PNGs). J5 on `-FlareSample bounce`: 1, then 2 selected; 0 after the empty click; 2 after the marquee; scale reads 1.50 (±0.02); rotation 90° (±1°); the Edit menu reads "Undo Rotate" | the box is off the art, a handle is missing, a gesture commits early, or J5's readings are off |
| SE-2 | `FlareViewMathTests`: zoomIn from 1 is 2 (the 1, 2, 3, 4, 6, 8 … steps), clamped to 0.1…32; readout "Fit" for nil and "200%" for 2; `guideReadout` "y 300". `FlareViewSnapshots` (two PNGs). J14 on `-FlareSample bounce`: zoom pill 200%, then "Fit"; the ruler origin label changed after the pan; the guide reads "y 300", then "y 320", one "Undo Move Guide"; dragged onto the ruler it is gone; ⌘R hides the rulers | a zoom step is skipped, a guide drag is two undo steps, or a dropped guide stays |
| SE-3 | J15 on `-FlareSample bounce`: "Ball copy" above Ball, 10 pt right; "Ball copy 2"; Shadow gone, then back; "Ball copy 2" gone; the Edit menu names "Undo Paste", "Undo Duplicate", "Undo Cut", "Undo Delete" in turn; with the pasteboard cleared, Paste is disabled with "Nothing to paste."; the context menu on Ball lists Cut, Copy, Duplicate, Delete, Bring Forward, Send Backward | an action skips the pasteboard, an undo name is wrong, or Paste is enabled with nothing to paste |
| SE-4 | `FlareEditOrderTests`: Ball forward over Shadow is one "Undo Bring Forward" and one undo restores the order; the top layer refuses with "Already at the front."; backward under the locked Background refuses with "Background is locked."; the selection survives the move | the order is wrong, a refusal changes the document, or a step is two entries |
| SE-5 | J3 extended on `-FlareSample empty`: the empty text first; Rectangle 1, Ellipse 1 (equal sides), Path 1, Path 2 whose second anchor is "smooth"; after ⌘Z "Redo Add Path" and Path 2 gone; the probe's drag-preview mark before each mouse-up. `testSelectAllOrderAndEscape`: ⌘A selects 2 (Background is locked); ⇧⌘A 0; ⌘] then ⌘[ restore the order; Escape mid-marquee leaves no selection | a tool fails live, a pen anchor is a corner, or Escape commits |

## Quality tests

| quality row | budget | test |
|---|---|---|
| QB-F3 one gesture, one step | a move, a scale, a rotate, a guide drag and each Edit action are one ⌘Z | J5, J14, J15 (SE-1 to SE-3) |
| QB-F1 no dead controls | every Edit, View and Object item acts or says why | J29 (draw-key-save) stays green; SE-3's disabled Paste |
| QB-L1 drag latency | the scale preview redraws on each move, nothing commits until mouse-up | `FlareSelectionReadTests` (preview before `endDrag`); P1 (QH-5 #394) reports it |
| QB-L5 hit per pointer move | ≤ 10 ms on `bounce` | `LiveStageBudgetTests.hitWithinBudget` (live-stage) stays green on `.built` |
| Keyboard parity | ⌘C ⌘X ⌘V ⌘D ⌫ ⌘A ⇧⌘A ⌘] ⌘[ ⌘+ ⌘− ⌘0 ⌘1 ⌘R Space-drag Escape | J5, J14, J15, SE-5 |
| App audit | no Flare count over `UITests/audit-baseline.json` | the macOS run's `audit-flare-*.json` |

## Done check

- **Journeys green:** the macOS run on `dev` triggered by SE-5
  (`feature-done`) is green: J3, J5, J14, J15 and the order journey, on
  `-FlareSample`, with `testDrawKeyAndSave` still green.
- **Audit zero new:** no Flare count over `UITests/audit-baseline.json`.
- **Contact sheet:** `Belt-Contact-Sheet: <run link>` on the feature issue,
  one line per journey and the audit counts.
