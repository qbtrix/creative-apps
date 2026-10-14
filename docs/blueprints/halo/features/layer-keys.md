# Feature packet: layer-keys

**Feature:** Key layers: inspector, drag and parent. The selected layer's
TRANSFORM rows with the stopwatch and the key diamond, the LAYER group
(Parent and Blend), and dragging a layer in the viewer to move or key its
position. All of it runs on the live types `LiveLayerPlacing`,
`LivePropertyKeying` and `LiveViewerDragging` over FlareCore
(`Timeline.value(of:at:)`, `Matrix`), with the not-animated rule in one
place.
**Line:** `line:halo` · **Wave:** W1 (`waves.md`) · **Lead branch:** `lead/layer-keys`

**Covers:** #38 (layer inspector with keys, parent and blend mode) and #207
(drag a layer in the viewer to key its position). #38 closes with LK-10 and
#207 with LK-11. The other tasks say "Part of #38" or "Part of #207", or
close through the feature issue's `feature-done` PR. #207 still carries
`needs-human`. Blueprint 8.1 and Q2 say the label can come off, but that is
the captain's call. This packet only notes it, and the lead does not remove
it. LK-11's PR says `Closes #207` either way.

**Depends on:** the foundation feature issue #777 and SuiteUI #333 (QH-4,
journey files). This feature's journeys live in
`UITests/HaloJourneyTests+Drag.swift`, `+Inspector.swift` and
`+Parent.swift`. `project.yml` compiles only `UITests/HaloJourneyTests.swift`
until #333 lands, so those files would not even compile before then. The
feature issue is filed only once #777 and #333 are both closed. Its one
`Depends on:` line names whichever of the two closed last. Model and view
tasks don't need #333; only LK-12 to LK-14 do. Because the issue waits for
#333 anyway, the lead can build every task. No creative-core issue is
needed: FlareCore on `main` already has `Keyframe`, `Timeline.value(of:at:)`
and `Matrix` (`inverted`, `apply`, `*`).

Blueprint sections it builds on: 2 (`edit` and one undo step, where a
property's value lives, coordinates), 4 (H-J5, H-J6, H-J23 and their
states), 5 (`LayerPlacing`, `PropertyKeying`, `ViewerDragging`, the fakes,
the workspace methods of `HaloKeying.swift` and `HaloViewerDrag.swift`), 6
(inspector order, TRANSFORM and LAYER rows, the keys command area), 7.1
(HB-1, HB-3, HB-4), 7.4 (HF-3, HF-5), 8.3 (layer-keys' owned files). The
packet wins over the blueprint and over the issue bodies where they differ.
Each difference is listed under "Review notes folded in".

**Building blind.** LK-9 to LK-14 are in `Sources/HaloApp/`,
`Tests/AppSnapshotTests/` and `UITests/`. The Linux gate never compiles
these; the macOS job compiles them on `dev` after the lane merges. So:
- Copy the imports and shape of the W0 stubs they replace (`HaloLayerInspector`,
  `HaloViewerGestures`, `HaloWindow+Keys`), including each stub's type name
  and the initializer W0's callers use.
- Check `DragGesture`, `onGeometryChange`, `accessibilityValue` and
  `onExitCommand` with the `apple-docs` MCP before use, and say so in the PR.
- Keep views dumb.
- Put every decision in HaloModel tasks LK-1 to LK-8. That includes the
  view-to-composition point mapping, the shown values in percent, and the
  parent and blend choices.

**Shared-file rule.** This feature owns only the Halo files listed in its
task rows. It never edits `Sources/SuiteUI/**`, `project.yml`,
`UITests/Journey*.swift`, `UITests/Journey+Input.swift`,
`Tests/AppSnapshotTests/AppSnapshotTests.swift`, `docs/c4/model.json` or
`docs/design.md`. Nor does it edit any file of another W1 feature or a W0
file that no feature took over. In particular, `HaloViewer.swift`,
`HaloWindow.swift`, `HaloViewerState.swift`, `HaloProject.swift`,
`HaloCommand.swift`, the menus, `HaloViewerCanvas.swift` (viewer-playback)
and `HaloLayerList.swift` (layer-panel) are off limits. The new helper
`Sources/HaloModel/Live/HaloKeyRules.swift` sits in `Live/` (the
`halo-services` component), so the C4 lint passes without a description
change. The supervisor folds the helper into the description later. The
fake files `FakeLayerPlacing`, `FakePropertyKeying` and `FakeViewerDragging`
were foundation's in W0 and are free once it is done. This feature takes
them over because the duplicate-code gate in `scripts/ci` makes each one a
thin wrapper over the shared rules. Another rule is about `HaloLayerInspector.swift`.
This feature replaces it whole, but the replacement keeps W0's EASING and
TEXT slots exactly as W0 wrote them, hosting `HaloEasingInspector` and
`HaloTextInspector` with the same arguments. easing and text-layers (W2) own
those two views and change nothing in this file.

## Journey steps

All three journeys run on `-HaloFixture` (fake services). On fake services,
`FakeProjectHistory` records undo, so the Edit menu's Undo item already
reads "Undo <step>" while history-files is unbuilt. On `-HaloSample`,
`LiveProjectHistory` is still a stub and records nothing. The journeys
assert the Undo item's **title** and never press ⌘Z, because Undo stays
disabled ("Not built yet (#208).") until history-files lands. The fakes are
thin wrappers over the same `HaloKeyRules` the live types use, so the
behavior is identical. core-loop (W3) flips all three journeys to
`-HaloSample`.

1. **H-J5** `testDragLayerToKeyPosition` (`+Drag`, `keyed`): scrub to 12.
   The journey reads Ball's Position X and Y rows ("560.0 px" for X) and
   starts the drag at the artboard's normalized point (x / 1920, y / 1080).
   It drags 100 px right (100 / 1920 of the artboard's width). After the
   drag:
   - the Position X row (`halo.inspector.row.x`) reads 660.0 px within
     ±2 px;
   - `Animate Position X` reads "Keyed at this frame";
   - the Edit menu holds "Undo Move".

   Then scrub to 0 and drag Floor 50 px down from its center. Floor's
   Position Y row reads its old value + 50 within ±2 px, and
   `Animate Position Y` reads "Not animated". Last, drag in the gray
   surround outside the artboard. The selection stays Floor and the Edit
   menu still reads "Undo Move". (LK-12)
2. **H-J6** `testInspectorKeysTransform` (`+Inspector`, `keyed`). Select
   Ball and scrub to 6.
   - Click `Animate Rotation`: it reads "Keyed at this frame".
   - Scrub to 20: it reads "Animated". Drag the Rotation bar right: it reads
     "Keyed at this frame".
   - Focus the bar and press → twice, then Shift-→: the value steps +1, +1,
     +10 (QB-F4).
   - Type `abc` in the Rotation value and press Return: the row keeps its
     value.
   - Ball's lane reads "6 keyframes" (0, 6, 12, 20, 24, 47), up from
     "3 keyframes" before the stopwatch.
   - Click "Add Key, Opacity" at 20: `Animate Opacity` reads "Keyed at this
     frame" and the Edit menu holds "Undo Add Key".

   The "Rotation needs a number." caption is asserted in Model tests and a
   snapshot, not here (see "Review notes"). (LK-13)
3. **H-J23** `testParentAndBlend` (`+Parent`, `parented`, at frame 0).
   - Select Ball. Its Parent menu (`halo.inspector.parent`) lists None,
     Floor and Rig, and not Ball. Choose Rig. Ball's Position X still reads
     160.0 px, because Rig's world matrix is the identity at frame 0.
   - Select Rig. Its Parent menu has no Ball (Ball follows it). Type `1060`
     into Rig's Position X.
   - Select Ball. Its row still reads 160.0 px. Set Blend → Multiply: the
     Blend row reads Multiply.
   - Set Parent → None. Ball's Position X reads 260.0 px (kept on screen).
     The Edit menu holds "Undo Set Parent".

   (LK-14)

The Model half of every step runs on Linux first: `HaloKeyByDragTests`,
`HaloKeyingTests` and `HaloKeyToggleTests` replay H-J5, H-J6 and H-J23 on
`HaloProject` with `.fake`. They replay them again on `.live` keying with a
`FakeProjectHistory` swapped in, so steps are counted.

## Screens and states

| Screen | Empty | Error | Loading |
|---|---|---|---|
| Inspector, TRANSFORM | no layer selected: W0's "Select a layer to see its properties." stays; a null shows all eight rows (it has a transform) | a refused edit's `refusal.message` in `SuiteFont.caption` under the row whose id it names (`halo.inspector.row.rotation`: "Rotation needs a number."); on `.live` before LK-2 the rows are disabled with "Keys arrive with the layer inspector (#38)." | none |
| Keyframe button | per row: "Not animated" (no diamond), "Animated" (hollow diamond, "Add Key"), "Keyed at this frame" (filled, "Remove Key"), from `HaloKeyState` | – | – |
| Inspector, LAYER | Parent reads None; Blend reads Normal | a cycle (only reachable by a stale menu) shows "<name> can't follow a layer that follows it." under `halo.inspector.parent` | none |
| Viewer drag | a drag that starts over no layer, or in the surround, moves nothing, selects nothing and adds no step | a layer outside its span or a null is never hit | the preview while the pointer moves (`viewerDrag`, drawn by `viewerDrawList`); Escape cancels it with no step |

## Contract slice

The protocols, fakes and stubs are in `docs/blueprints/halo/contracts/` and
blueprint section 5. They are unchanged. What this feature adds:

```swift
// Live/HaloKeyRules.swift (LK-1 to LK-3): internal, the one home of section 2's rules
enum HaloKeyRules {
    static func value(_ p: HaloProperty, of layer: HaloLayer, in c: HaloComposition, at frame: Int) -> Double
    static func localMatrix(of layer: HaloLayer, in c: HaloComposition, at frame: Int) -> HaloMatrix
    static func worldMatrix(of id: String, in c: HaloComposition, at frame: Int) -> HaloMatrix?  // stops at a cycle
    static func follows(_ id: String, _ ancestorID: String, in c: HaloComposition) -> Bool
    static func keyState(_ track: [HaloKeyframe], at frame: Int) -> HaloKeyState
    static func rows(for id: String, in c: HaloComposition, at frame: Int) -> [HaloPropertyRow]
    static func setValue(_ v: Double, for p: HaloProperty, of id: String, at frame: Int, in c: inout HaloComposition) throws
    static func toggleAnimation(_ p: HaloProperty, of id: String, at frame: Int, in c: inout HaloComposition) throws
    static func toggleKey(_ p: HaloProperty, of id: String, at frame: Int, in c: inout HaloComposition) throws
    static func setParent(_ parentID: String?, of id: String, at frame: Int, in c: inout HaloComposition) throws
}
// LiveLayerPlacing, LivePropertyKeying: call HaloKeyRules; unavailableHelp nil.
// LiveViewerDragging: hit and commitMove over HaloKeyRules (never over FrameDrawing).
// FakeLayerPlacing, FakePropertyKeying: call HaloKeyRules. FakeViewerDragging wraps LiveViewerDragging.

// HaloKeying.swift (LK-5, LK-6)
extension HaloProject {
    public var propertyRows: [HaloPropertyRow] { get }                // selected layer at the playhead; [] for none
    public mutating func setProperty(_ p: HaloProperty, to value: Double)   // "Change <title>", coalesceKey "<layer id>.<p>"
    public mutating func setProperty(_ p: HaloProperty, text: String)       // HaloProperty.parse; nil → .notANumber
    public mutating func endPropertyScrub()                               // endCoalescing()
    public mutating func toggleAnimation(_ p: HaloProperty)               // "Animate <title>" / "Stop Animating <title>"
    public mutating func toggleKey(_ p: HaloProperty)                     // "Add Key" / "Remove Key"
    public mutating func setParent(_ parentID: String?)                   // "Set Parent"
    public var parentChoices: [(id: String, name: String)] { get }        // LayerPlacing.parentCandidates; None is the view's first item
    public var blendChoices: [(mode: BlendMode, title: String)] { get }   // every BlendMode.allCases, "Color Dodge"
}
extension HaloPropertyRow { public var shown: Double; public var shownRange: ClosedRange<Double>; public var shownStep: Double }
extension HaloProperty { public func stored(fromShown shown: Double) -> Double }   // ÷ displayFactor

// HaloViewerDrag.swift (LK-7)
extension HaloProject {
    /// A point in the artboard view (top-left origin) as composition pixels. Nil
    /// with no composition or a non-positive artboard side (no division by zero).
    public func compositionPoint(x: Double, y: Double, artboardWidth: Double, artboardHeight: Double) -> HaloPoint?
    public mutating func beginViewerDrag(at point: HaloPoint)    // hit at the playhead; selects the layer; no step
    public mutating func moveViewerDrag(to point: HaloPoint)     // viewerDrag.delta only; never records
    public mutating func endViewerDrag()                         // one "Move" step; zero delta adds none
    public mutating func cancelViewerDrag()                      // viewerDrag = nil, nothing recorded
}
```

Control ids:
- each TRANSFORM row is `halo.inspector.row.<raw value>` (for example
  `halo.inspector.row.rotation`), and its keyframe button is
  `halo.inspector.key.<raw value>`;
- the LAYER pickers are `halo.inspector.parent` and `halo.inspector.blend`;
- a drag refusal uses `halo.viewer.artboard`.

Each control applies `.haloControl(id:enabled:help:)`, so H-J13 picks it
up. Values read empty in XCUITest (#262), so each row also sets
`.accessibilityValue(row.text)` from `HaloPropertyRow.text`. Blend titles
are Halo's own switch over the 16 cases. Don't copy PhotoModel's
`BlendMode.title`: it belongs to another line, the jscpd gate would flag
it, and AppSnapshotTests imports both models, so a second `title` would be
ambiguous.

## Pseudocode

```
HaloKeyRules.value(p, layer, c, f):                       # LK-1; HF-3
  if let track = layer.tracks[p.rawValue], let v = Timeline.value(of: track, at: Double(f)) { return v }
  return layer.defaultValue(p, in: c)                     # opacity's static home is layer.opacity
worldMatrix(id, c, f): local(id); walk parentID outward, seen-set stops a cycle;  m = local(parent) * m
local = T(x, y) * R(rotation) * S(scaleX, scaleY) * T(-anchorX, -anchorY)

keyState(track, f) = track.count < 2 ? .notAnimated : track has f ? .keyedHere : .animated     # LK-2
setValue(v, p, id, f):  guard v.isFinite else throw .notANumber(p); v = clamp(v, p.range)
  track.count >= 2 ? key(track, f, v) : setStatic(v, p)    # setStatic: opacity → layer.opacity, tracks[p] = nil;
                                                           #            others → [Keyframe(0, v)]
toggleAnimation: animated ? setStatic(value at f) : keys at f and (f == last ? 0 : last), both = value at f
toggleKey: key at f ? remove it : add key(f, value at f); a track left under 2 keys → setStatic(its one value)
setParent(pid, id, f):                                     # LK-3; HF-5
  pid == id || follows(pid, id) → throw .parentCycle(layer.name); unknown → .unknownLayer
  onScreen = world(id).apply(anchor); child.parentID = pid
  local = (world(pid) ?? identity).inverted().apply(onScreen); setValue(local.x, .x); setValue(local.y, .y)

LiveViewerDragging.hit(c, f, point):                       # LK-4; HB-3
  for layer in c.layers (top first) where kind != .null && isVisible(at: f):
    if let inv = try? worldMatrix(layer.id).inverted(), layer.bounds(in: c).contains(inv.apply(point)) { return layer.id }
  return nil
commitMove(id, delta, f): guard delta != .zero; inverse of the parent's world;
  setValue(x + d'.x, .x), setValue(y + d'.y, .y) on a copy, then assign  # d' = delta in the parent's space

setProperty(p, to: v):                                     # LK-5
  guard let id = selectedLayerID else return
  edit("Change \(p.title)", control: "halo.inspector.row.\(p.rawValue)", coalesceKey: "\(id).\(p.rawValue)") {
    try services.keying.setValue(v, for: p, of: id, at: playhead, in: &$0.selected) }
setProperty(p, text:): guard let v = p.parse(text) else { edit(…) { throw .notANumber(p) }; return }
  setProperty(p, to: v); endPropertyScrub()                # a typed value is its own step
toggleAnimation(p): name = row(p).keyState == .notAnimated ? "Animate \(p.title)" : "Stop Animating \(p.title)"
toggleKey(p): name = row(p).keyState == .keyedHere ? "Remove Key" : "Add Key"        # LK-6
setParent(pid): edit("Set Parent", control: "halo.inspector.parent") { try keying.setParent(pid, …) }

beginViewerDrag(at: p):                                    # LK-7
  guard let comp, let id = services.dragging.hit(comp, at: playhead, point: p) else { return }   # surround: nothing
  selectLayer(id); viewerDrag = HaloViewerDragState(layerID: id, start: p, delta: .zero)
moveViewerDrag(to: p): viewerDrag?.delta = p - start       # viewerDrawList offsets it; history untouched
endViewerDrag(): defer { viewerDrag = nil }
  guard let d = viewerDrag, d.delta != .zero else { return }
  edit("Move", control: "halo.viewer.artboard") { try services.dragging.commitMove(d.layerID, by: d.delta, at: playhead, in: &$0.selected) }
  endCoalescing()
```

## Tasks

Every task is one PR to `dev` with at most 400 changed lines and 15 files.
Each carries the label `fast-lane` and the body lines `Belt-Lead:`,
`Feature: layer-keys`, `Fast-Check: pass` and `Head:`. LK-14 also carries
`feature-done`. Sizes are estimates. Split any task that comes out bigger.

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| LK-1 | #38 (part) | `HaloKeyRules` sampling, local and world matrices, `follows`; `LiveLayerPlacing` real; `FakeLayerPlacing` calls the rules; the suite runs on `[fake, live]` with HF-3 and HF-5's chain | `Sources/HaloModel/Live/HaloKeyRules.swift`, `Sources/HaloModel/Live/LiveLayerPlacing.swift`, `Sources/HaloModel/Fakes/FakeLayerPlacing.swift`, `Tests/HaloModelTests/LayerPlacingContractTests.swift` | – | ~300 |
| LK-2 | #38 (part) | The not-animated rule in `HaloKeyRules` (`keyState`, `rows`, `setValue`, `toggleAnimation`, `toggleKey`); `LivePropertyKeying` real except `setParent` (still `.notBuilt("Parenting")`); `FakePropertyKeying` calls the rules; the suite runs on `[fake, live]` | `Sources/HaloModel/Live/HaloKeyRules.swift`, `Sources/HaloModel/Live/LivePropertyKeying.swift`, `Sources/HaloModel/Fakes/FakePropertyKeying.swift`, `Tests/HaloModelTests/PropertyKeyingContractTests.swift` | LK-1 | ~360 |
| LK-3 | #38 (part) | `setParent` in the rules (cycle refused, child kept on screen); `LivePropertyKeying.setParent` live; parent cases on `[fake, live]`, HF-5's second half | `Sources/HaloModel/Live/HaloKeyRules.swift`, `Sources/HaloModel/Live/LivePropertyKeying.swift`, `Sources/HaloModel/Fakes/FakePropertyKeying.swift`, `Tests/HaloModelTests/PropertyKeyingContractTests.swift` | LK-2 | ~200 |
| LK-4 | #207 (part) | `LiveViewerDragging`: `hit` over the rules' world matrices (not `FrameDrawing`, viewer-playback's), `commitMove` through `HaloKeyRules.setValue` in the parent's space; `FakeViewerDragging` wraps it; the suite runs on `[fake, live]` | `Sources/HaloModel/Live/LiveViewerDragging.swift`, `Sources/HaloModel/Fakes/FakeViewerDragging.swift`, `Tests/HaloModelTests/ViewerDraggingContractTests.swift` | LK-2 | ~260 |
| LK-5 | #38 (part) | `propertyRows`, `setProperty(_:to:)` coalesced per row, `setProperty(_:text:)` with its refusal, `endPropertyScrub()`, the shown-value helpers | `Sources/HaloModel/HaloKeying.swift`, `Tests/HaloModelTests/HaloKeyingTests.swift` | LK-2 | ~280 |
| LK-6 | #38 (part) | `toggleAnimation`, `toggleKey`, `setParent`, `parentChoices`, `blendChoices`; the keys area file turns on stopwatch, diamond, Parent, Blend and viewer drag when the state and the services allow | `Sources/HaloModel/HaloKeying.swift`, `Sources/HaloModel/Availability/HaloAvailability+Keys.swift`, `Tests/HaloModelTests/HaloKeyToggleTests.swift`, `Tests/HaloModelTests/HaloKeysAvailabilityTests.swift` | LK-3, LK-4, LK-5 | ~330 |
| LK-7 | #207 (part) | `compositionPoint`, `beginViewerDrag`, `moveViewerDrag` (preview only), `endViewerDrag` (one "Move"), `cancelViewerDrag` | `Sources/HaloModel/HaloViewerDrag.swift`, `Tests/HaloModelTests/HaloKeyByDragTests.swift` | LK-4 | ~260 |
| LK-8 | – | Budgets HB-1, HB-3, HB-4 on `reference`, over `.fake` and `.live` | `Tests/HaloModelTests/HaloKeysBudgetTests.swift` | LK-5, LK-7 | ~150 |
| LK-9 | #38 (part) | App routing: `HaloWindow+Keys.swift` routes every keys command and builds the inspector's and viewer's key closures (rows, stopwatch, diamond, scrub end, typed value, parent, blend, drag begin/move/end/cancel); `HaloLayerInspector` TRANSFORM group: eight `InspectorSliderRow`s with shown value, range, step, unit, decimals and `keyed:`, each with a `KeyframeButton` (`HaloKeyState` → `KeyState`), `onEnd` → `endPropertyScrub`, `.accessibilityValue(row.text)`, the refusal caption; EASING and TEXT slots kept as W0 wrote them | `Sources/HaloApp/HaloWindow+Keys.swift`, `Sources/HaloApp/HaloLayerInspector.swift`, `Tests/AppSnapshotTests/HaloInspectorSnapshots.swift` | LK-6, LK-7 | ~360 |
| LK-10 | #38 (closes) | LAYER group: Parent (`InspectorPickerRow<String?>`, None then `parentChoices`) and Blend (`blendChoices`) calling `setParent` and W0's `setSelectedLayerBlendMode`; snapshots of the LAYER group and the inspector at its minimum width | `Sources/HaloApp/HaloLayerInspector.swift`, `Tests/AppSnapshotTests/HaloInspectorSnapshots.swift` | LK-9 | ~160 |
| LK-11 | #207 (closes) | `HaloViewerGestures`: a `DragGesture(minimumDistance: 0)` on the artboard-sized view W0 gives it, mapping through `compositionPoint`; begin, move and end through LK-9's closures; Escape (`onExitCommand`) cancels; snapshot of the drag preview | `Sources/HaloApp/HaloViewerGestures.swift`, `Tests/AppSnapshotTests/HaloKeyByDragSnapshots.swift` | LK-9 | ~180 |
| LK-12 | – | Journey H-J5 on `-HaloFixture keyed` | `UITests/HaloJourneyTests+Drag.swift` | LK-11, #333 | ~150 |
| LK-13 | – | Journey H-J6 on `-HaloFixture keyed` | `UITests/HaloJourneyTests+Inspector.swift` | LK-10, #333 | ~170 |
| LK-14 | – (`feature-done`) | Journey H-J23 on `-HaloFixture parented` | `UITests/HaloJourneyTests+Parent.swift` | LK-10, LK-12, LK-13, #333 | ~140 |

**Chains:**
- Model: LK-1 → LK-2 → (LK-3 ∥ LK-4 ∥ LK-5). Then LK-4 → LK-7. LK-6 waits
  on LK-3, LK-4 and LK-5, and LK-8 waits on LK-5 and LK-7.
- App: LK-9 → (LK-10 ∥ LK-11) → the journeys.

Several tasks share a file (`HaloKeyRules.swift` in LK-1 to LK-3,
`HaloKeying.swift` in LK-5 and LK-6, `HaloLayerInspector.swift` in LK-9 and
LK-10). Each pair is chained by its depends-on.

`HaloWindow+Keys.swift` is written once, in LK-9, with every route, so
LK-10 and LK-11 can run side by side.

**Coordination with viewer-playback.** `FakeFrameDrawing` calls
`FakeLayerPlacing`, so it picks up the rules with no edit. viewer-playback's
`LiveFrameDrawing` needs the same values and world matrices. It should call
`HaloKeyRules` (internal, same module) once LK-1 merges, and not restate the
math, which the jscpd gate would flag. LK-1 is small and goes first for
that reason.

**W0's command test.** `HaloCommandTests` (W0) checks an invariant: every
command is enabled, or disabled with help. It is not a snapshot of keys
reading "Not built yet". So LK-6 does not edit it. If it fails after
LK-6, the fault is in foundation's test. The lead files that as a `gap` on
`line:halo` and does not edit the file.

## Acceptance test per task

| id | test | fails when |
|---|---|---|
| LK-1 | `LayerPlacingContractTests` on `[fake, live]`. On `keyed`, Ball's x reads 160 at 0, 560 at 12, 360 at 6 and 960 at 30 (held past the last key), and its opacity reads 0.5 at 6. Floor's x equals `Floor.bounds(in:).midX`. HF-3: every property of every layer of `reference` at frames 0…299 equals `Timeline.value(of:at:)` on its track, or `defaultValue` with no track. HF-5: a three-deep chain whose layers have (translate 100, 0), (rotate 90 about the anchor) and (scale 2) gives the matrix multiplied by hand, within 1e-9. `parentCandidates` for Ball on `parented` leaves out Ball. An unknown id gives nil. A file-made cycle a→b→a returns a matrix, with no endless loop | live sampling differs from FlareCore, the matrix order is wrong, or a cycle hangs |
| LK-2 | `PropertyKeyingContractTests` on `[fake, live]`, on `keyed`. Rows: Ball at 12 reads Position X "560.0 px" `.keyedHere`, at 6 `.animated`, and Opacity at 6 reads "50%". Floor's Rotation is `.notAnimated`. Writes: `setValue(1000, .x)` on Ball at 6 gives keys [0, 6, 24]. Floor's x set at 30 keeps one key at frame 0 and stays `.notAnimated`. Floor's opacity set to 0.5 writes `layer.opacity` with no track. NaN throws `.notANumber(.x)` and leaves the composition equal; 200,000 clamps to 100,000. Stopwatch on Floor's rotation: at 6 it keys [6, 47]; at 47 it keys [0, 47]; off at 20 leaves one key at 0 with the value at 20. Diamond: on Ball's opacity at 20 it adds a key with value 1; again, it removes it. Removing Ball's x key at 0 leaves x not animated at 960 | a not-animated write adds a second key, opacity gets a track, the stopwatch leaves one diamond, or a NaN lands |
| LK-3 | Same suite, on `parented`. `setParent("Rig")` for Ball at 0 and at 30 keeps Ball's anchor on screen within 1e-6. Then Rig's x set to 1060 at 0 moves Ball's screen x to 260 while Ball's own x stays 160, and `setParent(nil)` at 0 sets Ball's x to 260. `setParent(Ball)` for Rig throws `.parentCycle("Rig")` ("Rig can't follow a layer that follows it."); for Ball itself it throws `.parentCycle("Ball")`; an unknown id throws `.unknownLayer`. Each refusal leaves the composition equal | a child jumps on parenting or unparenting, or a cycle is stored |
| LK-4 | `ViewerDraggingContractTests` on `[fake, live]`. On `three-layers`, the composition center hits Badge at 12 (Title starts at 24) and Title at 30; (10, 10) hits Background at 12; the Rig null is never returned; on `empty` the result is nil. `commitMove` on `keyed`: Ball at 12 by (100, 0) keys x [0, 12, 24] with 660 at 12. Floor at 0 by (0, 50) leaves y one key at 0 = old + 50. A zero delta leaves the composition equal. A child of a Rig with scale X 2 moved by (100, 0) changes its own x by 50 | the hit picks a null, a hidden layer or a lower layer, or a parented move lands in the wrong space |
| LK-5 | `HaloKeyingTests` on `.fake` and on `.live` keying with `FakeProjectHistory`, on `keyed` with Ball selected at 12. `propertyRows` gives 8 rows in `allCases` order, and `[]` with no layer. Three `setProperty(.rotation, to:)` calls give 1 step, "Undo Change Rotation"; after `endPropertyScrub()` a fourth makes 2. `setProperty(.rotation, text: "abc")` sets `refusal == HaloRefusal(control: "halo.inspector.row.rotation", message: "Rotation needs a number.")`, leaves the document equal and adds no step. "45°" stores 45, and " 50 %" on Opacity stores 0.5. A typed value is its own step, even right after a scrub of the same row. `shown` reads 50 for opacity 0.5, and `stored(fromShown: 50)` gives 0.5 | a scrub makes several steps, a refusal changes the document, or percent rows are off by 100 |
| LK-6 | `HaloKeyToggleTests` (same services and fixtures). The stopwatch on Rotation at 6 is "Undo Animate Rotation" with keys [6, 47]; again it is "Undo Stop Animating Rotation". The Opacity diamond at 20 is "Undo Add Key", then "Undo Remove Key". `setParent` is "Undo Set Parent". A cycle sets the refusal on `halo.inspector.parent`. On `parented`, `parentChoices` for Ball has Floor and Rig and no Ball; after Ball → Rig, Rig's choices have no Ball. `blendChoices` has 16 entries, including "Multiply" and "Color Dodge". `HaloKeysAvailabilityTests`: with no composition, help reads "Create a composition first."; with no layer, "Select a layer first."; on `.fake` and `.live` with a layer, every keys command's help is nil; with a stub keying service, its `unavailableHelp` comes through | a toggle names the wrong step, a picker offers a cycle, or a keys control turns on without its service |
| LK-7 | `HaloKeyByDragTests` (replaces #207's cases, see Review notes). `compositionPoint(480, 270, 960, 540)` on a 1920 × 1080 composition gives (960, 540); a 0 side gives nil. On `keyed` at 12, begin at Ball's center selects Ball. Two `moveViewerDrag` calls change `viewerDrawList`'s Ball item by the delta and leave `history.undo` unchanged. `endViewerDrag` adds one "Undo Move" with x 660 at 12, and x at 6 reads 410. Begin in empty space on `empty` leaves the selection and `viewerDrag` nil. `cancelViewerDrag` leaves the document equal with no step. A click (begin then end, no move) selects with no step | the preview records, a drag makes zero or two steps, or the mapping is off |
| LK-8 | `HaloKeysBudgetTests` (W0's `HaloBudget` helper): median and p95 of 200 runs on `reference` within the gates below | a step goes over budget |
| LK-9 | Snapshot `halo-inspector-light.png` and `halo-inspector-dark.png` (#38's names): `keyed`, Ball at 12, TRANSFORM with Position X keyed here and Opacity animated. `halo-inspector-refusal-light.png` and `-dark.png`: the caption under Rotation after `setProperty(.rotation, text: "abc")`. EASING and TEXT slots present | rows misalign, the key state is lost, the caption is missing, or a slot is dropped |
| LK-10 | Snapshot `halo-inspector-layer-light.png` and `-dark.png` (`parented`, Ball → Rig, Multiply). `halo-inspector-narrow-light.png` and `-dark.png` (inspector at `SuiteSize.inspectorWidth.min`, 200 pt, showing TRANSFORM): labels untruncated | a picker is missing or TRANSFORM clips at the minimum width |
| LK-11 | Snapshot `halo-key-by-drag-light.png` and `-dark.png` (#207's names): `HaloViewer` on `keyed` at 15 mid-drag by (100, 0). It shows the layers once viewer-playback's canvas has landed; until then, the artboard alone | the viewer stops compiling or the gesture covers the surround |
| LK-12 | H-J5 on the `dev` CI run | any step's assert |
| LK-13 | H-J6 on the `dev` CI run | any step's assert |
| LK-14 | H-J23 on the `dev` CI run; the last test in run order still launches a Journey | any step's assert |

## Quality tests

| quality row | budget | test |
|---|---|---|
| HB-1 viewer drag | `moveViewerDrag(to:)` + `viewerDrawList` on `reference` ≤ 3 ms device, ≤ 30 ms debug CI; on `.live` the draw list is real only once viewer-playback lands | `HaloKeysBudgetTests.viewerDragStep` (LK-8) |
| HB-3 viewer hit | `ViewerDragging.hit` on `reference` ≤ 1 ms, ≤ 10 ms debug | `HaloKeysBudgetTests.hit` (LK-8) |
| HB-4 inspector scrub | `setProperty(_:to:)` (with `edit`'s copy and coalesced record) + `propertyRows` on `reference` ≤ 1 ms, ≤ 10 ms debug | `HaloKeysBudgetTests.inspectorScrubStep` (LK-8) |
| HF-3 sampling equals FlareCore | exact | `LayerPlacingContractTests` (LK-1) |
| HF-5 parent chain and setParent | 1e-9 matrix; 1e-6 screen position | `LayerPlacingContractTests` (LK-1), `PropertyKeyingContractTests` (LK-3) |
| QB-F2 immediate feedback | the preview moves before mouse-up; a refusal shows under its row | `HaloKeyByDragTests` (LK-7), refusal snapshot (LK-9) |
| QB-F3 one gesture, one step | scrub, drag, stopwatch, diamond, parent: one named step each | `HaloKeyingTests`, `HaloKeyToggleTests`, `HaloKeyByDragTests` |
| QB-F4 keyboard parity | arrows +1, Shift ×10 on Rotation | H-J6 (LK-13) |
| QB-F1 no dead controls | keys controls enabled, or disabled with help | `HaloKeysAvailabilityTests` (LK-6); H-J13 picks up the new `halo.*` ids |
| Audit | no `halo` count up; `identifier` and `unnamed` unchanged by the new controls | `audit-halo-*.json` on the `feature-done` run |

Layout L4 (TRANSFORM bars aligned) is `HaloLayoutTests`, owned by
core-loop (W3), not by this feature. LK-10's narrow snapshot shows the group
at the inspector's minimum width so the contact sheet catches it early.

## Done check

- **Journeys green:** the macOS run on `dev` triggered by LK-14's
  `feature-done` PR is green, with H-J5, H-J6 and H-J23 passing. The W0
  journeys (H-J0, H-J1, H-J13, layout) and every other app's journeys must
  be unchanged.
- **Audit zero new:** no `halo` count is over `UITests/audit-baseline.json`.
  Each UI PR states the counts it expects.
- **Contact sheet:** the lead comments on the feature issue with
  `Belt-Contact-Sheet: <run link>`, one line per journey and the audit
  counts. Expected new shots:
  - the three journeys' steps;
  - the TRANSFORM and LAYER groups in the inspector in every shot with a
    layer selected;
  - the drag preview.

## Review notes folded in

Where they touch this feature, from the review of the blueprint PR (#767)
and this packet's own checks:

- **Undo title only.** H-J5, H-J6 and H-J23 assert "Undo Move", "Undo Add
  Key" and "Undo Set Parent" as the Edit menu's item title on
  `-HaloFixture`. They never press ⌘Z: undo is history-files'.
- **Typed `abc` can't reach the Model through the bar.**
  `InspectorSliderRow` (SuiteUI `ScrubField.commit`) parses typed text
  itself and keeps the old value without calling `onChange`, so the view
  never sees "abc". The blueprint has H-J6 assert the caption under the
  row, but that can't pass today. The lead files a `needs-ui` issue on
  `line:suiteui`: "InspectorSliderRow reports typed text that isn't a
  number", with a callback such as `onRejectedText: (String) -> Void` and a
  SuiteUI test. Meanwhile:
  - H-J6 asserts only that the value is kept;
  - `HaloKeyingTests` (LK-5) and the refusal snapshot (LK-9) prove the
    message;
  - once SuiteUI ships the hook, the view calls `setProperty(_:text:)` and
    core-loop adds the caption assert.
- **Drag precision.** XCUITest drags land on whole points, so a 100 px
  composition drag can be off by a pixel or two. The journeys allow ±2 px.
  The exact mapping is `compositionPoint`'s Model test.
- **#207's test is replaced.** #207's second drag on a not-animated solid
  "keys x at 30". Section 2's not-animated rule (and H-J5's Floor step)
  says it writes the one static value instead. `HaloKeyByDragTests` checks
  the halfway value on Ball, which is animated: 660 at 12, so 410 at 6. #207
  says `HaloApp.swift`. The gesture lives in `HaloViewerGestures.swift`.
- **#38's names.** Some names change from #38's body, and #38's
  `Depends on: #37, #5` is replaced by this packet's:

  | #38 says | Becomes |
  |---|---|
  | `HaloLayerEditing.swift` | `HaloKeying.swift` |
  | `HaloInspectorTests` | `HaloKeyingTests` and `HaloKeyToggleTests` |
  | steppers | bars (`InspectorSliderRow`; inspectors use no Stepper) |

  Its snapshot names (`halo-inspector-light/dark.png`) are kept.
- **No copies between fake and live.** All of section 2's rules live once,
  in `Live/HaloKeyRules.swift`. The three fakes call them or wrap the live
  type. The live types never create a fake. `LiveViewerDragging.hit` reads
  world matrices from the rules rather than `FrameDrawing`, so it works
  before viewer-playback's live drawing lands.
- **No shared docs.** The C4 description of `halo-services` (now also
  holding `HaloKeyRules`) and the inspector rows in `docs/design.md` are
  folded in by the supervisor.
- **Viewer summary.** The journeys don't read positions from the
  `halo.viewer.artboard` value. It lists names only (`<name>: <string>` for
  text), so positions are read from the TRANSFORM rows.
