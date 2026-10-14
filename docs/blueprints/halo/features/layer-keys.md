# Feature packet: layer-keys

**Feature:** Key layers: inspector, drag and parent. The selected layer's
TRANSFORM rows with the stopwatch and the key diamond, the LAYER group
(Parent and Blend), and dragging a layer in the viewer to move or key its
position. All of it runs on the live types `LiveLayerPlacing`,
`LivePropertyKeying` and `LiveViewerDragging` over FlareCore
(`Timeline.value(of:at:)`, `Matrix`), with section 2's not-animated rule in
one internal helper.
**Line:** `line:halo` · **Wave:** W1 (`waves.md`) · **Lead branch:** `lead/layer-keys`

**Covers:** #38 (layer inspector with keys, parent and blend mode) closes
through LK-10. #207 (drag a layer in the viewer to key its position) closes
through LK-11. Other tasks say "Part of #38" or "Part of #207", or close
through the feature issue's `feature-done` PR. #207 still carries
`needs-human`. Blueprint 8.1 and Q2 say it can come off; that is the
captain's call, so this packet only notes it, and the lead does not remove
it. LK-11's PR says `Closes #207` either way.

**Depends on:** the foundation feature issue (#777) and SuiteUI QH-4 (#333).
The journeys live in `UITests/HaloJourneyTests+Drag.swift`,
`+Inspector.swift` and `+Parent.swift`. `project.yml` compiles only
`UITests/HaloJourneyTests.swift` until #333 lands, so those files would not
even compile before then. The feature issue is filed only once #777 and #333
are both closed, and its one `Depends on:` line names whichever closed last.
Only LK-12 to LK-14 need #333, but the issue waits for it anyway so the lead
can build every task. No creative-core issue is needed: FlareCore on `main`
has `Keyframe`, `Timeline.value(of:at:)` and `Matrix` (`*`, `inverted`,
`apply`).

Blueprint sections it builds on: 2 (`edit` and one undo step, where a
property's value lives, coordinates), 4 (H-J5, H-J6, H-J23 and their
states), 5 (`LayerPlacing`, `PropertyKeying`, `ViewerDragging`, their fakes,
the methods of `HaloKeying.swift` and `HaloViewerDrag.swift`), 6 (inspector
order, TRANSFORM and LAYER rows, the keys command area), 7.1 (HB-1, HB-3,
HB-4), 7.4 (HF-3, HF-5), 8.3 (owned files). The packet wins over the
blueprint and over #38's and #207's bodies where they differ; see "Review
notes folded in".

**Building blind.** LK-9 to LK-14 are in `Sources/HaloApp/`,
`Tests/AppSnapshotTests/` and `UITests/`, which the Linux gate never
compiles. Copy the shape of the W0 stubs they replace, keeping each type
name and initializer: slot views take `init(model: HaloProject, perform:
@escaping (HaloCommand) -> Void)` (FD-15), and `HaloWindow+Keys.swift`
keeps its `keysScene(_:)` hook (FD-14). Check `DragGesture`,
`onGeometryChange`, `accessibilityValue` and `onExitCommand` with the
`apple-docs` MCP before use and say so in the PR. Keep views dumb, and put
every decision in HaloModel tasks LK-1 to LK-8, including the
view-to-composition mapping, the shown value in percent, and the parent and
blend choices.

**Shared-file rule.** This feature owns only the Halo files in its task
rows. It never edits `Sources/SuiteUI/**`, `project.yml`,
`UITests/Journey*.swift`, `UITests/Journey+Input.swift`,
`Tests/AppSnapshotTests/AppSnapshotTests.swift` (it calls the shared
`snapshot(_:name:scheme:)` as it is), `docs/c4/model.json`,
`docs/design.md`, W0's `HaloProject.swift`, `HaloCommand.swift`,
`HaloViewerState.swift`, `HaloWindow.swift`, `HaloViewer.swift` or any menu
file, `HaloViewerCanvas.swift` (viewer-playback) or `HaloLayerList.swift`
(layer-panel).
- **Fakes.** It takes over W0's `FakeLayerPlacing`, `FakePropertyKeying` and
  `FakeViewerDragging` (free once foundation is done). For the duplicate
  gate, the rules they share with the live types live once in
  `Sources/HaloModel/Live/HaloKeyRules.swift`. It sits in `Live/` (the
  `halo-services` component), so the C4 lint passes.
- **The inspector.** It replaces `HaloLayerInspector.swift` whole, keeping
  W0's EASING and TEXT slots exactly as W0 wrote them
  (`HaloEasingInspector(model:perform:)`, then
  `HaloTextInspector(model:perform:)`). easing and text-layers (W2) own those
  views and never edit this file.

**Commands.** Views act only through `perform(_:)` (FD-11). The keys area
needs these payload cases: `.setProperty(HaloProperty, Double)`,
`.endPropertyScrub`, `.toggleAnimation(HaloProperty)`,
`.toggleKey(HaloProperty)`, `.setParent(String?)`, `.setBlendMode(BlendMode)`,
and for the viewer `.beginViewerDrag(x:y:)`, `.moveViewerDrag(x:y:)` (in
composition pixels, as Doubles), `.endViewerDrag` and `.cancelViewerDrag`.
FD-11 lists every v1 case, these and `.setPropertyText(HaloProperty,
String)` included, so features never add one. The lead never edits
`HaloCommand.swift`.

## Journey steps

All three journeys run on `-HaloFixture`. There `FakeProjectHistory`
records, so the Edit menu's Undo item already reads "Undo <step>". On
`-HaloSample` the history-files stub records nothing. The journeys assert
the Undo item's **title** ("open Edit; the item titled X exists") and never
press ⌘Z: Undo stays disabled ("Not built yet (#208).") until history-files
lands. The fakes call the same `HaloKeyRules` as the live types, so the
behavior is the one shipped. core-loop (W3) flips these journeys to
`-HaloSample`.

1. **H-J5** `testDragLayerToKeyPosition` (`+Drag`, `keyed`). Scrub to 12
   and read Ball's Position X and Y rows (X "560.0 px"). Drag from the
   artboard's normalized point (x / 1920, y / 1080), 100 / 1920 of its width
   to the right. Then `halo.inspector.row.x` reads 660.0 px within ±2 px,
   `Animate Position X` reads "Keyed at this frame", and Edit holds "Undo
   Move". Scrub to 0 and drag Floor 50 px down from its center: its
   Position Y reads the old value + 50 within ±2 px, and `Animate
   Position Y` reads "Not animated". A drag in the surround outside the
   artboard leaves Floor selected, with Edit still at "Undo Move". (LK-12)
2. **H-J6** `testInspectorKeysTransform` (`+Inspector`, `keyed`). Select
   Ball: its lane reads "3 keyframes". Scrub to 6 and click `Animate
   Rotation`: "Keyed at this frame". Scrub to 20: "Animated". Drag the
   Rotation bar right: "Keyed at this frame". Focus the bar, press → twice
   and Shift-→: the value steps +1, +1, +10 (QB-F4). Type `abc` and press
   Return: the value is kept. Ball's lane reads "6 keyframes" (0, 6, 12, 20,
   24, 47). Click "Add Key, Opacity": `Animate Opacity` reads "Keyed at this
   frame" and Edit holds "Undo Add Key". (LK-13)
3. **H-J23** `testParentAndBlend` (`+Parent`, `parented`, frame 0). Select
   Ball: its Parent menu (`halo.inspector.parent`) lists None, Floor and
   Rig, not Ball. Choose Rig: Ball's Position X still reads 160.0 px (Rig's
   world matrix is the identity at 0). Select Rig: its Parent menu has no
   Ball. Type `1060` into Rig's Position X. Select Ball: still 160.0 px.
   Blend → Multiply: the Blend row reads Multiply. Parent → None: Ball's
   Position X reads 260.0 px (kept on screen), and Edit holds "Undo Set
   Parent". (LK-14)

The Model half of every step runs on Linux first: `HaloKeyByDragTests`,
`HaloKeyingTests` and `HaloKeyToggleTests` replay the steps on `HaloProject`
with `.fake`, and again with `.live` and `FakeProjectHistory` swapped in.

## Screens and states

| Screen | Empty | Error | Loading |
|---|---|---|---|
| Inspector, TRANSFORM | no layer: W0's "Select a layer to see its properties." stays; a null shows all eight rows | a refused edit's `refusal.message` in `SuiteFont.caption` under the row its id names ("Rotation needs a number." under `halo.inspector.row.rotation`); on `.live` before LK-2b every row is disabled with "Keys arrive with the layer inspector (#38)." | none |
| Keyframe button | "Not animated" (no diamond), "Animated" (hollow diamond, Add Key), "Keyed at this frame" (filled, Remove Key) from `HaloKeyState` | – | – |
| Inspector, LAYER | Parent None; Blend Normal | a cycle (a stale menu only) shows "<name> can't follow a layer that follows it." under `halo.inspector.parent` | none |
| Viewer drag | a drag that starts over no layer or in the surround moves nothing, selects nothing and adds no step | a null, or a layer outside its span, is never hit | the preview while the pointer moves (`viewerDrag` through `viewerDrawList`); Escape cancels it, with no step |

## Contract slice

The protocols, fakes and stubs are unchanged (`docs/blueprints/halo/contracts/`,
section 5). What this feature adds:

```swift
// Live/HaloKeyRules.swift (LK-1 to LK-3): internal, the one home of section 2's rules
enum HaloKeyRules {
    static func value(_ p: HaloProperty, of layer: HaloLayer, in c: HaloComposition, at f: Int) -> Double
    static func worldMatrix(of id: String, in c: HaloComposition, at f: Int) -> HaloMatrix?   // a cycle stops the walk
    static func follows(_ id: String, _ ancestorID: String, in c: HaloComposition) -> Bool
    static func rows(for id: String, in c: HaloComposition, at f: Int) -> [HaloPropertyRow]
    static func setValue(_ v: Double, for p: HaloProperty, of id: String, at f: Int, in c: inout HaloComposition) throws
    static func toggleAnimation(_ p: HaloProperty, of id: String, at f: Int, in c: inout HaloComposition) throws
    static func toggleKey(_ p: HaloProperty, of id: String, at f: Int, in c: inout HaloComposition) throws
    static func setParent(_ pid: String?, of id: String, at f: Int, in c: inout HaloComposition) throws
}
// Live types call it, unavailableHelp nil. FakeLayerPlacing and FakePropertyKeying call it;
// FakeViewerDragging wraps LiveViewerDragging. A live type never creates a fake.

// HaloKeying.swift (LK-5, LK-6)
extension HaloProject {
    public var propertyRows: [HaloPropertyRow] { get }                     // selected layer at the playhead; [] for none
    public mutating func setProperty(_ p: HaloProperty, to value: Double)  // "Change <title>", coalesceKey "<layer id>.<raw>"
    public mutating func setProperty(_ p: HaloProperty, text: String)      // HaloProperty.parse; nil → .notANumber(p)
    public mutating func endPropertyScrub()                                // endCoalescing()
    public mutating func toggleAnimation(_ p: HaloProperty)                // "Animate <title>" / "Stop Animating <title>"
    public mutating func toggleKey(_ p: HaloProperty)                      // "Add Key" / "Remove Key"
    public mutating func setParent(_ parentID: String?)                    // "Set Parent"
    public var parentChoices: [(id: String, name: String)] { get }         // parentCandidates, timeline order; the view puts None first
    public var blendChoices: [(mode: BlendMode, title: String)] { get }    // BlendMode.allCases: "Multiply", "Color Dodge"
}
extension HaloPropertyRow { public var shown: Double; public var shownRange: ClosedRange<Double>; public var shownStep: Double }
extension HaloProperty { public func stored(fromShown shown: Double) -> Double }   // shown ÷ displayFactor

// HaloViewerDrag.swift (LK-7)
extension HaloProject {
    /// A point in the artboard view (top-left origin) in composition pixels; nil with
    /// no composition or a side ≤ 0 (no division by zero).
    public func compositionPoint(x: Double, y: Double, artboardWidth: Double, artboardHeight: Double) -> HaloPoint?
    public mutating func beginViewerDrag(at point: HaloPoint)   // hit at the playhead; selects it; no step
    public mutating func moveViewerDrag(to point: HaloPoint)    // viewerDrag.delta only; never records
    public mutating func endViewerDrag()                        // one "Move"; a zero delta adds none
    public mutating func cancelViewerDrag()                     // viewerDrag = nil; nothing recorded
}
```

**Control ids**, each set through `.haloControl(id:enabled:help:)` so H-J13
finds it: `halo.inspector.row.<raw>` (a TRANSFORM row),
`halo.inspector.key.<raw>` (its keyframe button), `halo.inspector.parent`,
`halo.inspector.blend`, and `halo.viewer.artboard` for a drag's refusal.
Values read empty in XCUITest (#262), so each row also sets
`.accessibilityValue(row.text)`. The Blend titles are Halo's own `switch`
over the 16 cases: PhotoModel's `BlendMode.title` is another line's, a copy
would trip jscpd, and AppSnapshotTests imports both models.

## Pseudocode

```
HaloKeyRules.value(p, layer, c, f):                                     # LK-1; HF-3
  track sampled with Timeline.value(of:at:) ?? layer.defaultValue(p, in: c)    # opacity's static home: layer.opacity
worldMatrix(id): m = local(id); walk parentID outward with a seen-set; m = local(parent) * m
local = T(x, y) * R(rotation) * S(scaleX, scaleY) * T(-anchorX, -anchorY)

keyState(track, f) = track.count < 2 ? .notAnimated : track has f ? .keyedHere : .animated  # LK-2a
setValue(v, p, id, f):                                                  # LK-2b
  guard v.isFinite else throw .notANumber(p); v = clamp(v, p.range)
  track.count >= 2 ? key(track, f, v) : setStatic(v, p)     # opacity → layer.opacity, no track; else [Key(0, v)]
toggleAnimation: animated ? setStatic(value at f) : keys at f and (f == last ? 0 : last) with value at f
toggleKey: key at f ? remove : add key(f, value at f); a track left with < 2 keys → setStatic(its value)
setParent(pid, id, f):                                                  # LK-3; HF-5
  pid == id || follows(pid, id) → throw .parentCycle(name); unknown → .unknownLayer
  screen = world(id).apply(anchor); parentID = pid
  local = (world(pid) ?? .identity).inverted().apply(screen); setValue(local.x, .x); setValue(local.y, .y)

LiveViewerDragging.hit(c, f, pt):                                       # LK-4; HB-3
  first layer, top first, kind != .null && isVisible(at: f) && bounds.contains(world⁻¹.apply(pt))
commitMove(id, d, f): d == .zero → return; d' = d in the parent's space; setValue(x + d'.x), setValue(y + d'.y) on a copy

setProperty(p, to: v):                                                  # LK-5; HB-4
  guard let id = selectedLayerID else return
  edit("Change \(p.title)", control: "halo.inspector.row.\(p.rawValue)", coalesceKey: "\(id).\(p.rawValue)") {
    try keying.setValue(v, for: p, of: id, at: playhead, in: &selected($0)) }
setProperty(p, text: t): guard let v = p.parse(t) else { edit(…) { throw .notANumber(p) }; return }
  endCoalescing(); setProperty(p, to: v); endCoalescing()                # a typed value is its own step
toggleAnimation(p): name from the row's state before (.notAnimated → "Animate …")      # LK-6
toggleKey(p): .keyedHere → "Remove Key", else "Add Key"
keysHelp(cmd): no composition → "Create a composition first."; no layer → "Select a layer first.";
  else the needed service's unavailableHelp (keying, placing or dragging), else nil

beginViewerDrag(at: pt):                                                # LK-7; HB-1
  guard let comp, let id = dragging.hit(comp, at: playhead, point: pt) else return   # surround or empty: nothing
  selectLayer(id); viewerDrag = HaloViewerDragState(layerID: id, start: pt, delta: .zero)
moveViewerDrag(to: pt): viewerDrag?.delta = pt - start                  # viewerDrawList offsets the preview
endViewerDrag(): defer { viewerDrag = nil }; guard delta != .zero else return
  edit("Move", control: "halo.viewer.artboard") { try dragging.commitMove(id, by: delta, at: playhead, in: &…) }
  endCoalescing()
```

## Tasks

Every task is one PR to `dev` with at most 400 changed lines and 15 files.
Each carries the label `fast-lane` and the body lines `Belt-Lead:`,
`Feature: layer-keys`, `Fast-Check: pass` and `Head:`. LK-14 also carries
`feature-done`. Sizes are estimates. Split any task that comes out bigger.

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| LK-1 | #38 (part) | `HaloKeyRules`: sampling, local and world matrices, `follows`; `LiveLayerPlacing` real; `FakeLayerPlacing` calls the rules; suite on `[fake, live]` with HF-3 and HF-5's chain | `Sources/HaloModel/Live/HaloKeyRules.swift`, `Sources/HaloModel/Live/LiveLayerPlacing.swift`, `Sources/HaloModel/Fakes/FakeLayerPlacing.swift`, `Tests/HaloModelTests/LayerPlacingContractTests.swift` | – | ~300 |
| LK-2a | #38 (part) | The read half of the not-animated rule in `HaloKeyRules` (`keyState`, `rows`); `LivePropertyKeying`'s rows real (its writes still throw `.notBuilt`, its help unchanged); `FakePropertyKeying`'s rows and key states move onto the rules; the rows half of the suite on `[fake, live]` | `Sources/HaloModel/Live/HaloKeyRules.swift`, `Sources/HaloModel/Live/LivePropertyKeying.swift`, `Sources/HaloModel/Fakes/FakePropertyKeying.swift`, `Tests/HaloModelTests/PropertyKeyingContractTests.swift` | LK-1 | ~200 |
| LK-2b | #38 (part) | The write half in `HaloKeyRules` (`setValue`, `toggleAnimation`, `toggleKey`); `LivePropertyKeying` real except `setParent` (still `.notBuilt("Parenting")`), help nil; `FakePropertyKeying`'s writes move onto the rules; the writes half of the suite on `[fake, live]` | `Sources/HaloModel/Live/HaloKeyRules.swift`, `Sources/HaloModel/Live/LivePropertyKeying.swift`, `Sources/HaloModel/Fakes/FakePropertyKeying.swift`, `Tests/HaloModelTests/PropertyKeyingContractTests.swift` | LK-2a | ~240 |
| LK-3 | #38 (part) | `setParent` in the rules (cycle refused, the child kept on screen); `LivePropertyKeying.setParent` real; HF-5's second half on `[fake, live]` | `Sources/HaloModel/Live/HaloKeyRules.swift`, `Sources/HaloModel/Live/LivePropertyKeying.swift`, `Sources/HaloModel/Fakes/FakePropertyKeying.swift`, `Tests/HaloModelTests/PropertyKeyingContractTests.swift` | LK-2b | ~200 |
| LK-4 | #207 (part) | `LiveViewerDragging`: `hit` over the rules' world matrices (not `FrameDrawing`, which is viewer-playback's), `commitMove` through `HaloKeyRules.setValue` in the parent's space; `FakeViewerDragging` wraps it; suite on `[fake, live]` | `Sources/HaloModel/Live/LiveViewerDragging.swift`, `Sources/HaloModel/Fakes/FakeViewerDragging.swift`, `Tests/HaloModelTests/ViewerDraggingContractTests.swift` | LK-2b | ~260 |
| LK-5 | #38 (part) | `propertyRows`, `setProperty(_:to:)` coalesced per row, `setProperty(_:text:)` and its refusal, `endPropertyScrub()`, the shown-value helpers | `Sources/HaloModel/HaloKeying.swift`, `Tests/HaloModelTests/HaloKeyingTests.swift` | LK-2b | ~280 |
| LK-6 | #38 (part) | `toggleAnimation`, `toggleKey`, `setParent`, `parentChoices`, `blendChoices`; the keys area file turns on the stopwatch, diamond, Parent, Blend and viewer drag when the state and services allow | `Sources/HaloModel/HaloKeying.swift`, `Sources/HaloModel/Availability/HaloAvailability+Keys.swift`, `Tests/HaloModelTests/HaloKeyToggleTests.swift`, `Tests/HaloModelTests/HaloKeysAvailabilityTests.swift` | LK-3, LK-4, LK-5 | ~330 |
| LK-7 | #207 (part) | `compositionPoint`, `beginViewerDrag`, `moveViewerDrag` (preview only), `endViewerDrag` (one "Move"), `cancelViewerDrag` | `Sources/HaloModel/HaloViewerDrag.swift`, `Tests/HaloModelTests/HaloKeyByDragTests.swift` | LK-4 | ~260 |
| LK-8 | – | Budgets HB-1, HB-3, HB-4 on `reference`, over `.fake` and `.live` | `Tests/HaloModelTests/HaloKeysBudgetTests.swift` | LK-5, LK-7 | ~150 |
| LK-9 | #38 (part) | `HaloWindow+Keys.swift` routes every keys command to its Model method (`keysScene(_:)` kept). `HaloLayerInspector`'s TRANSFORM group has eight `InspectorSliderRow`s (shown value, range, step, unit, decimals, `keyed:`); `onChange` sends `.setProperty(p, p.stored(fromShown:))` and `onEnd` sends `.endPropertyScrub`. Each row has a `KeyframeButton` (`HaloKeyState` mapped to `KeyState`), `.accessibilityValue(row.text)` and the refusal caption. The EASING and TEXT slots stay as W0 wrote them | `Sources/HaloApp/HaloWindow+Keys.swift`, `Sources/HaloApp/HaloLayerInspector.swift`, `Tests/AppSnapshotTests/HaloInspectorSnapshots.swift` | LK-6, LK-7 | ~360 |
| LK-10 | #38 (closes) | The LAYER group: Parent (`InspectorPickerRow<String?>`, None then `parentChoices`) and Blend (`blendChoices`) send `.setParent` and `.setBlendMode` (W0's "Change Blend Mode" mutator); snapshots of the group and of the inspector at its minimum width | `Sources/HaloApp/HaloLayerInspector.swift`, `Tests/AppSnapshotTests/HaloInspectorSnapshots.swift` | LK-9 | ~160 |
| LK-11 | #207 (closes) | `HaloViewerGestures(model:perform:)`: a `DragGesture(minimumDistance: 0)` on the artboard-sized view W0 gives it, mapped through `compositionPoint`, sends begin, move and end; Escape (`onExitCommand`) sends cancel; snapshot of the preview | `Sources/HaloApp/HaloViewerGestures.swift`, `Tests/AppSnapshotTests/HaloKeyByDragSnapshots.swift` | LK-9 | ~180 |
| LK-12 | – | H-J5 on `-HaloFixture keyed` | `UITests/HaloJourneyTests+Drag.swift` | LK-11, #333 | ~150 |
| LK-13 | – | H-J6 on `-HaloFixture keyed` | `UITests/HaloJourneyTests+Inspector.swift` | LK-10, #333 | ~170 |
| LK-14 | – (`feature-done`) | H-J23 on `-HaloFixture parented` | `UITests/HaloJourneyTests+Parent.swift` | LK-10, LK-12, LK-13, #333 | ~140 |

The Model chain is LK-1 → LK-2a → LK-2b → (LK-3 ∥ LK-4 ∥ LK-5), LK-4 → LK-7, LK-6
after LK-3, LK-4 and LK-5, and LK-8 after LK-5 and LK-7. The app chain is
LK-9 → (LK-10 ∥ LK-11) → the journeys. Tasks that share a file chain
through depends-on. LK-9 writes `HaloWindow+Keys.swift` once with every
route, so LK-10 and LK-11 can run side by side. The 8.3 list's
`HaloKeyingTests` keeps the rows, scrub and typed value; the toggle and
availability tests get new files so no task passes 400 lines. LK-2 is split
in two because moving `FakePropertyKeying`'s ~110 lines of rules into
`HaloKeyRules` counts as both a delete and an add.

**Coordination.** `FakeFrameDrawing` calls `FakeLayerPlacing`, so it picks
up the rules with no edit. viewer-playback's `LiveFrameDrawing` needs the
same values and world matrices, and gets them through the `LayerPlacing`
protocol (it takes a placing, defaulting to `LiveLayerPlacing()`), so the
math lives once, in `HaloKeyRules`, and neither feature waits on the other. layer-panel's LP-1 keeps a deleted parent's
children on screen through `services.keying.setParent`, which is real after
LK-3. W0's `HaloCommandTests` checks an invariant (every command enabled,
or disabled with help), so LK-6 doesn't edit it.

## Acceptance test per task

| id | test | fails when |
|---|---|---|
| LK-1 | `LayerPlacingContractTests` on `[fake, live]`. On `keyed`: Ball's x is 160 at 0, 360 at 6, 560 at 12 and 960 at 30 (held past the last key); its opacity is 0.5 at 6; Floor's x is `Floor.bounds(in:).midX`. HF-3: every property of every layer of `reference` at frames 0…299 equals `Timeline.value(of:at:)` on its track, or `defaultValue` with no track. HF-5: a three-deep chain (translate (100, 0); rotate 90° about the anchor; scale 2) equals the matrix multiplied by hand within 1e-9. `parentCandidates` for Ball on `parented` leaves out Ball. An unknown id gives nil. A file-made cycle a→b→a returns a matrix | live sampling differs from FlareCore, the matrix order is wrong, or a cycle hangs |
| LK-2a | `PropertyKeyingContractTests` (rows) on `[fake, live]`, on `keyed` (`keyed` keys Ball's x at 0 and 24 and its opacity at 12; each test looks Ball's and Floor's ids up by name with `try #require`). Rows: Ball's Position X at 12 is "560.0 px" `.animated`, and its Opacity at 12 is `.keyedHere`; at 6 Position X is `.animated` and Opacity reads "50%"; Floor's Rotation is `.notAnimated`; an unknown id gives `[]` | a key state is wrong, a percent row is off by 100, or live rows differ from the fake's |
| LK-2b | `PropertyKeyingContractTests` (writes) on `[fake, live]`, on `keyed`. `setValue(1000, .x)` on Ball at 6 gives keys [0, 6, 24]. Floor's x set at 30 stays one key at frame 0, `.notAnimated`. Floor's opacity 0.5 writes `layer.opacity` with no track. NaN throws `.notANumber(.x)` and leaves the composition equal; 200,000 clamps to 100,000. The stopwatch on Floor's rotation at 6 keys [6, 47], at 47 keys [0, 47], and off at 20 leaves one key at 0 holding the value at 20. The diamond on Ball's opacity at 20 adds a key with value 1, and again removes it. Removing Ball's x key at 0 leaves x not animated at 960 | a not-animated write adds a key, opacity gets a track, the stopwatch leaves one diamond, or NaN lands |
| LK-3 | Same suite on `parented`. Parenting Ball to Rig at 0, and separately at 30, keeps Ball's anchor on screen within 1e-6. After parenting at 0, setting Rig's x to 1060 at 0 puts Ball's anchor at screen x 260 while Ball's own x stays 160; `setParent(nil)` at 0 then stores Ball's x as 260. Rig → Ball throws `.parentCycle("Rig")` ("Rig can't follow a layer that follows it."); Ball → Ball throws `.parentCycle("Ball")`; an unknown id throws `.unknownLayer`. Each refusal leaves the composition equal | a child jumps on parenting or unparenting, or a cycle is stored |
| LK-4 | `ViewerDraggingContractTests` on `[fake, live]`. On `three-layers`, Title's box center hits Title at 30. At 12 (before Title's span) the same point hits Badge or Background, whichever is topmost under it, never Title or Rig. On `empty`, every point gives nil. `commitMove` on `keyed`: Ball at 12 by (100, 0) gives x keys [0, 12, 24] with 660 at 12; Floor at 0 by (0, 50) leaves y one key at 0 = old + 50; a zero delta leaves the composition equal. A child of a Rig with scale X 2 moved by (100, 0) changes its own x by 50 | the hit picks a null, a hidden or a lower layer, or a parented move lands in the wrong space |
| LK-5 | `HaloKeyingTests` on `.fake`, and on `.live` with `FakeProjectHistory`, on `keyed` with Ball selected at 12. `propertyRows` has 8 rows in `allCases` order, and `[]` with no layer. Three `setProperty(.rotation, to:)` calls make 1 step, "Undo Change Rotation"; after `endPropertyScrub()` a fourth makes 2. `setProperty(.rotation, text: "abc")` sets `refusal` to `HaloRefusal(control: "halo.inspector.row.rotation", message: "Rotation needs a number.")`, leaves the document equal and adds no step. "45°" stores 45 as its own step, even right after a scrub; " 50 %" on Opacity stores 0.5. `shown` is 50 for opacity 0.5, and `stored(fromShown: 50)` is 0.5 | a scrub makes several steps, a refusal changes the document, or percent rows are off by 100 |
| LK-6 | `HaloKeyToggleTests` (same setup). The stopwatch on Rotation at 6 is "Undo Animate Rotation" with keys [6, 47], and again "Undo Stop Animating Rotation". The Opacity diamond at 20 is "Undo Add Key", then "Undo Remove Key". `setParent` is "Undo Set Parent". A cycle sets the refusal on `halo.inspector.parent`. On `parented`, Ball's `parentChoices` are Floor and Rig, with no Ball; after Ball → Rig, Rig's choices have no Ball. `blendChoices` has 16 entries, including "Multiply" and "Color Dodge". `HaloKeysAvailabilityTests`: no composition gives "Create a composition first."; no layer gives "Select a layer first."; on `.fake` and `.live` with a layer every keys command is nil; a stub keying service's `unavailableHelp` comes through | a toggle names the wrong step, a picker offers a cycle, or a keys control turns on without its service |
| LK-7 | `HaloKeyByDragTests` (replaces #207's cases). `compositionPoint(480, 270, 960, 540)` on 1920 × 1080 is (960, 540); a side of 0 gives nil. On `keyed` at 12, a begin at Ball's center selects Ball. Two moves shift `viewerDrawList`'s Ball item by the delta and leave `history.undo` unchanged. The end adds one "Undo Move" with x 660 at 12, so x at 6 is 410. A begin on empty space leaves the selection and `viewerDrag` unchanged. A cancel leaves the document equal with no step. A click (begin, end) selects with no step | the preview records, a drag makes zero or two steps, or the mapping is off |
| LK-8 | `HaloKeysBudgetTests` with W0's `HaloBudget`: median and p95 of 200 runs on `reference` within the gates below | a step goes over budget |
| LK-9 | Snapshot `halo-inspector-light.png` and `halo-inspector-dark.png` (#38's names): `keyed`, Ball at 12, Position X animated (hollow diamond), Opacity keyed here (filled), EASING and TEXT slots present. `halo-inspector-refusal-light.png` and `-dark.png`: the caption under Rotation after `setProperty(.rotation, text: "abc")` | rows misalign, a key state is lost, the caption is missing, or a slot is dropped |
| LK-10 | Snapshot `halo-inspector-layer-light.png` and `-dark.png` (`parented`, Ball → Rig, Multiply). `halo-inspector-narrow-light.png` and `-dark.png`: the inspector at `SuiteSize.inspectorWidth.min` (200 pt) with TRANSFORM and no truncated label | a picker is missing, or TRANSFORM clips at the minimum width |
| LK-11 | Snapshot `halo-key-by-drag-light.png` and `-dark.png` (#207's names): `HaloViewer` on `keyed` at 15, mid-drag by (100, 0). It shows layers once viewer-playback's canvas has landed; before that, only the artboard | the viewer stops compiling or the gesture covers the surround |
| LK-12 to LK-14 | H-J5, H-J6 and H-J23 on the `dev` CI run; the last test in run order still launches a Journey | any step's assert |

## Quality tests

| quality row | budget | test |
|---|---|---|
| HB-1 viewer drag | `moveViewerDrag(to:)` + `viewerDrawList` on `reference` ≤ 3 ms device, ≤ 30 ms debug CI (on `.live` the draw list is real only after viewer-playback) | `HaloKeysBudgetTests.viewerDragStep` (LK-8) |
| HB-3 viewer hit | `ViewerDragging.hit` on `reference` ≤ 1 ms, ≤ 10 ms debug | `HaloKeysBudgetTests.hit` (LK-8) |
| HB-4 inspector scrub | `setProperty(_:to:)` (with `edit`'s copy and coalesced record) + `propertyRows` on `reference` ≤ 1 ms, ≤ 10 ms debug | `HaloKeysBudgetTests.inspectorScrubStep` (LK-8) |
| HF-3 sampling equals FlareCore | exact | `LayerPlacingContractTests` (LK-1) |
| HF-5 parent chain and `setParent` | 1e-9 matrix; 1e-6 screen position | `LayerPlacingContractTests` (LK-1), `PropertyKeyingContractTests` (LK-3) |
| QB-F2 immediate feedback | the preview moves before mouse-up; a refusal shows under its row | `HaloKeyByDragTests` (LK-7); refusal snapshot (LK-9) |
| QB-F3 one gesture, one step | scrub, typed value, drag, stopwatch, diamond, parent | `HaloKeyingTests`, `HaloKeyToggleTests`, `HaloKeyByDragTests` |
| QB-F4 keyboard parity | arrows +1, Shift ×10 on Rotation | H-J6 (LK-13) |
| QB-F1 no dead controls | keys controls enabled, or disabled with help | `HaloKeysAvailabilityTests` (LK-6); H-J13 picks up the new ids |
| Audit | no `halo` count goes up; every new control has a `halo.*` id and a label | `audit-halo-*.json` on the `feature-done` run |

Layout L4 (TRANSFORM bars aligned) is in `HaloLayoutTests`, owned by
core-loop (W3), not by this feature. LK-10's narrow snapshot shows the group
at the inspector's minimum width, so the contact sheet catches a clip
early.

## Done check

- **Journeys green:** the macOS run on `dev` triggered by LK-14's
  `feature-done` PR is green, with H-J5, H-J6 and H-J23 passing. W0's
  journeys and every other app's journeys stay unchanged.
- **Audit zero new:** no `halo` count is over `UITests/audit-baseline.json`.
  Each UI PR states the counts it expects.
- **Contact sheet:** `Belt-Contact-Sheet: <run link>` on the feature issue,
  with one line per journey and the audit counts. Expected new shots: the
  three journeys' steps; TRANSFORM and LAYER in every shot with a layer
  selected; the drag preview.

## Review notes folded in

Where they touch this feature, from the review of #767 and this packet's
own checks:

- **Undo title only.** H-J5, H-J6 and H-J23 assert "Undo Move", "Undo Add
  Key" and "Undo Set Parent" as the Edit menu item's title on
  `-HaloFixture` and never press ⌘Z: undo is history-files'.
- **Typed `abc` can't reach the Model through the bar.** `InspectorSliderRow`
  (`ScrubField.commit`) parses typed text itself and keeps the old value
  without calling `onChange`, so the view never sees "abc" and the caption
  the blueprint has H-J6 assert can't appear. Filed as #783 (`needs-ui`,
  `line:suiteui`), "InspectorSliderRow reports typed text that isn't a
  number" (a callback such as `onRejectedText: (String) -> Void`,
  with a SuiteUI test). Meanwhile H-J6 asserts only that the value is kept,
  and LK-5's test and LK-9's refusal snapshot prove the message. Once the
  hook ships, the row sends the text to `setProperty(_:text:)` (a
  `.setPropertyText` case) and core-loop adds the caption assert.
- **Drag precision.** XCUITest drags land on whole points, so a 100 px drag
  can be off by a pixel or two: the journeys allow ±2 px, and
  `compositionPoint`'s Model test is exact.
- **#207's test is replaced.** #207's second drag on a not-animated solid
  "keys x at 30"; section 2's rule (and H-J5's Floor step) writes the one
  static value instead. `HaloKeyByDragTests` checks the halfway value on
  animated Ball (660 at 12, so 410 at 6). #207 names `HaloApp.swift`; the
  gesture lives in `HaloViewerGestures.swift`.
- **#38's names.** `HaloLayerEditing.swift` is `HaloKeying.swift`;
  `HaloInspectorTests` is `HaloKeyingTests` and `HaloKeyToggleTests`;
  steppers are bars (`InspectorSliderRow`; inspectors use no Stepper). Its
  `Depends on: #37, #5` is replaced by this packet's. Its snapshot names
  (`halo-inspector-light/dark.png`) are kept.
- **No copies between fake and live.** The rules live once, in
  `Live/HaloKeyRules.swift`. `LiveViewerDragging.hit` reads world matrices
  from the rules, not `FrameDrawing`, so it works before viewer-playback's
  live drawing lands.
- **No shared docs.** The supervisor folds in the `halo-services`
  description (now also `HaloKeyRules`) and the inspector rows in
  `docs/design.md`.
- **Layer ids in tests.** Ids look like "comp-1-layer-1", not names: every
  Model test looks a fixture layer's id up by name (`try #require(keyed.layers.first { $0.name == "Ball" }).id`) and passes that. Errors that
  carry a name (`.parentCycle("Rig")`) take the layer's name, as the
  message does.
- **`keyed` at 12.** Ball's x keys are at 0 and 24 and its opacity is keyed
  at 12, so at 12 Position X is animated (560.0 px) and Opacity is keyed
  here; LK-2a and LK-9 assert exactly that.
- **Viewer summary.** The `halo.viewer.artboard` value lists names only
  (`<name>: <string>` for text), so the journeys read positions from the
  TRANSFORM rows.
