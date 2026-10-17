# Feature packet: inspector-timeline

**Feature:** key, ease and retime on real documents from the inspector and
the timeline. The Properties tab's title, info card and TRANSFORM rows with
keyframe buttons and "Mixed"; FILL and STROKE; the SCENE section; the
TIMING row and the easing popover; retiming, deleting and labelling keys,
inserting and removing frames; and the transport with the actual-fps pill.
**Line:** `line:flare` · **Wave:** 4 (`waves.md`) · **Lead branch:** `lead/inspector-timeline`

**Status:** built (2026-10-17), feature issue #1515. IT-1 to IT-10 are on
`dev`; J9 and J6 now run on `-FlareSample bounce`, so no fixture flag is
left in this feature's journeys. IT-9's `TransportCapsule` half is deferred
to gap issue #2185, because SuiteUI #340 is still open; its status pills
and J10 on live merged.

**Covers:** F6a #186, F6b #348, F6c #349 (its SCENE half; the INSTANCE half
moves to the later library feature, with J18), F7b #376, F8 #377, F9 #378,
and IN-2 #385 (J9 to J12 green live). It also makes J6 to J8 green live, the
inspector half of IN-1 #397, which closes with whichever of this feature's
IT-10 and `stage-edit`'s SE-5 lands second.

**Depends on:** the `draw-key-save` feature issue (its window, router,
timeline, transport, `.built` services). Of the four running features it
needs live-keys #799 (and live-scenes #800 for the SCENE section), through
`draw-key-save`'s DK-3. At task level only: IT-7 waits on S11 #63
(`TimelineStrip` key drag) and IT-9 on S7 #340 (`TransportCapsule` and the
pills). The inspector rows (S1 #334, S2 #335, S3 #336, S4 #337, S5 #338) are
closed. IT-8 uses the `CurveEditor` already on `dev`; S13 #343 adds only its
goldens and the Reduce Motion mark, so IT-8 doesn't wait on it.

Blueprint sections: 2 (where a property's value lives, the not-animated
rule, one undo step), 3.1 (Properties tab, timeline), 3.3 (easing popover),
3.4 (Animate menu), 4 (J6 to J12), 7.3 (F6a, F6b, F6c, F7b, F8, F9), 7.6
(IN-2).

**Where it starts from.** The use cases are live (`LiveProperties`,
`LiveKeyframes`, `LiveEasing`) and the workspace already scrubs, keys and
eases (`FlareAnimate.swift`: `setProperty`, `endPropertyScrub`,
`toggleAnimated`, `toggleKey`, `toggleAutoKey`; `FlareEasing.swift`). What
the workspace lacks is fill and stroke, and the timeline's edits (key
selection, move, delete, frames, labels), which today only the services
have; IT-2 and IT-3 add them. `draw-key-save` leaves `FlareInspector.swift`
(the tabs, with today's scene card and easing editor), `FlareTimeline.swift`,
`FlareTransport.swift` and the `+Inspector` and `+Timeline` area files.

## Journey steps

All launch with `-FlareSample bounce` (live), so each is also its IN-1 or
IN-2 check.

| # | step | task | journey test |
|---|---|---|---|
| 1 | select Ball; the Rotation keyframe button; frame 20; drag the Rotation bar; focus it and → twice, then Shift-→; select Ball and Shadow: X reads Mixed | IT-4 | J7 `FlareInspectorJourneys.testInspectorKeysTransform` |
| 2 | select Ball; FILL hex `FF3B30`; STROKE width 4; cap Round; join Round; ⌘Z | IT-5 | J8 `FlareFillStrokeJourneys.testFillAndStroke` |
| 3 | nothing selected: SCENE shows 1920 × 1080, 24 fps, 48 frames; set 30 fps; the SCENE row reads 30 and the timecode's total changes | IT-6 | `FlareSceneInspectorJourneys.testSceneSection` |
| 4 | drag Ball's key at 24 to 28; select the key at 12 and ⌫; frame 10, ⌥= twice; ⌥− once; frame 29, Add Label "hit"; the key's context menu | IT-7 | J11 `FlareTimelineEditJourneys.testRetimeDeleteInsertAndLabel` |
| 5 | TIMING row on Ball's first segment: Ease Out; open the popover; drag the first handle; focus it and ↑ | IT-8 | J12 `FlareEasingJourneys.testEasingPresetAndCurve` |
| 6 | frame 30; Space; wait 1 s; Space; → twice; loop off and End then Space stops at the end | IT-9 | J10 `FlarePlaybackJourneys.testPlayLoopAndStep` |
| 7 | J9 scrub and J6 move-and-key, flipped from fixtures to `-FlareSample` | IT-10 | J9, J6 |

## Screens and states

| screen | state | snapshot PNG |
|---|---|---|
| Properties | Ball: title "Ball", info card (Kind Shape, Frame 12, Size, Keys 5), TRANSFORM rows with buttons in each key state | `flare-inspector-ball-light.png`, `flare-inspector-ball-dark.png` (IT-4) |
| Properties | Ball and Shadow: "2 layers", X reads Mixed with no marker | `flare-inspector-mixed.png` (IT-4) |
| Properties | a refused edit (NaN typed): the row's reason in the error color | `flare-inspector-refused.png` (IT-4) |
| FILL, STROKE | solid fill; a gradient as a read-only swatch; stroke width, cap, join | `flare-fill-solid.png`, `flare-fill-gradient.png`, `flare-stroke.png` (IT-5) |
| SCENE | nothing selected: size, background, fps, duration, presets grid | `flare-scene-section.png` (IT-6) |
| Timeline | a selected key, a key being dragged, a label on the ruler | `flare-timeline-edit.png`, `flare-timeline-label.png` (IT-7) |
| Timeline | a refused move (onto another key): the key snaps back, the reason in the status line | `flare-timeline-refused.png` (IT-7) |
| TIMING, popover | the row reading Ease Out; the popover with presets, curve and four numbers | `flare-timing-row.png`, `flare-easing-popover.png` (IT-8) |
| Transport | `TransportCapsule` paused and playing; pills 16:9, 1080p, 24 fps, actual fps, zoom; the actual-fps pill in the warning color when frames drop | `flare-transport-capsule-paused.png`, `flare-transport-capsule-playing.png`, `flare-status-dropping.png` (IT-9) |

## Contract slice

Model (Linux, tested):

```swift
// Sources/FlareModel/FlareInspectorRead.swift (IT-1)
public struct InspectorSummary: Sendable, Equatable {
    public var title: String                  // the selection's name, "2 layers", or the scene's name
    public var kind: String, frame: Int, size: String, keys: Int?   // the info card
    public var showsScene: Bool               // nothing selected
}
extension FlareWorkspace { public var inspectorSummary: InspectorSummary }

// Sources/FlareModel/FlarePaint.swift (IT-2)
public struct PaintReadout: Sendable, Equatable {
    public var fillHex: String?, fillIsGradient: Bool   // nil hex = Mixed
    public var strokeHex: String?, strokeWidth: Double?, cap: Stroke.Cap?, join: Stroke.Join?   // FlareCore's
}
extension FlareWorkspace {
    public var paint: PaintReadout?
    public mutating func setFill(hex: String)          // refuses a bad hex with a reason
    public mutating func setStrokeWidth(_ width: Double)   // called once, on the bar's release
    public mutating func setStrokeCap(_ cap: Stroke.Cap)
    public mutating func setStrokeJoin(_ join: Stroke.Join)
    public mutating func setStrokeColor(hex: String)
}
// Stored state goes in FlareWorkspace.swift (Swift has no stored properties in extensions), all in IT-2:
//   paintError: String?, selectedKeys: [KeyRef], timelineError: String?, keyDragSerial: Int,
//   each cleared in load(_:). IT-3 uses the timeline ones.
// The width bar shows the dragged value while scrubbing and calls setStrokeWidth once from onEnd, so a
// width drag is one entry: PropertyAnimating.setStroke takes no coalesce key, and Live/ is not ours.

// Sources/FlareModel/FlareTimelineEdit.swift (IT-3)
extension FlareWorkspace {
    // selectedKeys, timelineError and keyDragSerial are stored in FlareWorkspace.swift (IT-2)
    public mutating func selectKey(_ key: KeyRef, extending: Bool)
    public mutating func moveSelectedKeys(by frames: Int, dragStart: Int)   // one entry per drag
    public mutating func endKeyDrag()
    public mutating func removeSelectedKeys()
    public mutating func insertFrames(_ count: Int)        // at the playhead
    public mutating func removeFrames(_ count: Int)
    public mutating func setLabel(_ name: String?)         // at the playhead
    public var timelineLabels: [Int: String]
}

// Sources/FlareModel/FlareStatusRead.swift (IT-9)
public struct StatusPills: Sendable, Equatable {
    public var aspect: String, size: String, fps: String    // "16:9", "1080p", "24 fps"
    public var actualFPS: String?, isDropping: Bool         // while playing
    public var textWarning: String?                         // "Text not shown (1)"
}
extension FlareWorkspace { public func statusPills(measuredFPS: Double?) -> StatusPills }
```

App: `FlareInspector` lays out sections from stubs (`FlareInspectorFill`,
`FlareInspectorScene`, `FlareInspectorTiming`) so each task owns its own
file; every row carries `flare.inspector.<property>` and its keyframe
button `flare.inspector.<property>.key` with the `KeyState` value.

## Pseudocode

```
inspectorSummary:                                          # IT-1
  selection empty -> scene: title = scene name, showsScene
  one layer -> its name, kind (Shape | Instance | Group), frame, size of selectionBounds, keys on its row
  several -> "<n> layers", keys nil

FlareInspector (Properties):                               # IT-4
  InspectorHeader(summary) ; if showsScene: FlareInspectorScene(...) else
  InspectorSection("TRANSFORM") { for p in model.animatedProperties:
     InspectorSliderRow(p.title, value: p.value ?? Mixed, range, unit, decimals,
        onChange: { perform(.inspector(.scrub(p.name, $0, start))) }, onEnd: { perform(.inspector(.endScrub)) })
     KeyframeButton(p.keyState, onToggle: .toggleAnimated(p.name), onKey: .toggleKey(p.name)) }
  FlareInspectorFill(...) ; FlareInspectorTiming(...)      # stubs; Timing shows today's FlareEasingInspector
performInspector: scrub -> setProperty ; endScrub -> endPropertyScrub ; toggleAnimated ; toggleKey ;
  setFill/stroke* -> IT-2's ; sceneCanvas/sceneTiming -> setSceneCanvas/setSceneTiming ;
  easingPreset/handle/endHandle -> FlareEasing's

setFill(hex):                                              # IT-2
  guard color = FlareColor(hex) else paintError = "Use 6 hex digits, like FF3B30."
  services.properties.setFill(color, layers/items, in: &engine)   # one "Undo Set Fill"

moveSelectedKeys(by, dragStart):                           # IT-3
  try services.keyframes.moveKeys(selectedKeys, by: delta from last step, owner, coalesceKey: "keys-\(serial)")
  catch -> timelineError = message ; document unchanged
endKeyDrag: serial += 1

FlareTimelineEdit:                                         # IT-7
  TimelineStrip(onSelectKeyframe: selectKey, onMoveKeyframes: moveSelectedKeys (S11), onEnd: endKeyDrag)
  key context menu: Easing ▸ presets (setEasingPreset), Delete Keyframe
  ⌫ removes selected keys ; ⌥= ⌥− insert/remove ; Add Label… asks the name in a popover

FlareInspectorTiming:                                      # IT-8
  the key under the playhead: InspectorPickerRow("Easing", preset or "Custom") ; a button opens
  FlareEasingPopover(PresetGrid, CurveEditor, four numbers) ; FlareEasingInspector.swift deleted

FlareTransport:                                            # IT-9
  TransportCapsule(isPlaying, loops, onStart, onBack, onPlay, onForward, onEnd, onLoop)   # S7 #340
  ViewerStatusBar(zoom, size) { pills from statusPills(measuredFPS: driver.measuredFPS) }
  # zoom comes through the FlareTransport(model:, zoom:, perform:, tick:) stub signature (DK-10)
PlaybackDriver.measuredFPS (IT-9): frames shown over the last second, from the tick targets
```

## Tasks

Every task is one PR to `dev`: at most 400 changed lines and 15 files, label
`fast-lane`, body lines `Belt-Lead:`, `Feature: inspector-timeline`,
`Fast-Check: pass`, `Head:`. IT-10 also carries `feature-done`.

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| IT-1 | #186 (part) | `inspectorSummary` (title and info card) | `Sources/FlareModel/FlareInspectorRead.swift`, `Tests/FlareModelTests/FlareInspectorReadTests.swift` | – | ~140, 2 files |
| IT-2 | #348 (part) | Fill and stroke on the workspace, with refusals; the stored state of IT-2 and IT-3 in `FlareWorkspace`, cleared on load | `Sources/FlareModel/FlarePaint.swift`, `Sources/FlareModel/FlareWorkspace.swift`, `Tests/FlareModelTests/FlarePaintTests.swift` | – | ~280, 3 files |
| IT-3 | #377 (part) | Key selection, move, delete, frames and labels on the workspace | `Sources/FlareModel/FlareTimelineEdit.swift`, `Tests/FlareModelTests/FlareTimelineEditTests.swift` | IT-2 | ~300, 2 files |
| IT-4 | #186 (closes) | The Properties tab: header, TRANSFORM rows and keyframe buttons, Mixed; section stubs; every `.inspector` intent routed; J7 | `Sources/FlareApp/FlareInspector.swift`, `Sources/FlareApp/FlareInspectorTransform.swift`, `Sources/FlareApp/FlareInspectorFill.swift`, `Sources/FlareApp/FlareInspectorScene.swift`, `Sources/FlareApp/FlareInspectorTiming.swift`, `Sources/FlareApp/FlareWindow+Inspector.swift`, `Tests/AppSnapshotTests/FlareInspectorSnapshots.swift`, `UITests/FlareJourneyTests+Inspector.swift` | IT-1, IT-2 | ~390, 8 files |
| IT-5 | #348 (closes) | FILL (solid, gradient read-only) and STROKE sections; J8 | `Sources/FlareApp/FlareInspectorFill.swift`, `Tests/AppSnapshotTests/FlareFillSnapshots.swift`, `UITests/FlareJourneyTests+FillStroke.swift` | IT-4 | ~260, 3 files |
| IT-6 | see #349 | The SCENE section: size, background, fps, duration, presets | `Sources/FlareApp/FlareInspectorScene.swift`, `Tests/AppSnapshotTests/FlareSceneSnapshots.swift`, `UITests/FlareJourneyTests+SceneInspector.swift` | IT-4 | ~240, 3 files |
| IT-7 | #377 (closes) | Timeline editing: key select and drag, ⌫, insert and remove frames, labels, the key context menu; J11 | `Sources/FlareApp/FlareTimelineEdit.swift`, `Sources/FlareApp/FlareTimeline.swift`, `Sources/FlareApp/FlareWindow+Timeline.swift`, `Tests/AppSnapshotTests/FlareTimelineEditSnapshots.swift`, `UITests/FlareJourneyTests+TimelineEdit.swift` | IT-3, #63 | ~360, 5 files |
| IT-8 | #378 (closes) | The TIMING row and the easing popover; `FlareEasingInspector` retired; the old easing journey moved into J12 | `Sources/FlareApp/FlareInspectorTiming.swift`, `Sources/FlareApp/FlareEasingPopover.swift`, `Sources/FlareApp/FlareEasingInspector.swift` (deleted), `Tests/AppSnapshotTests/FlareEasingSnapshots.swift`, `UITests/FlareJourneyTests.swift`, `UITests/FlareJourneyTests+Easing.swift` | IT-4 | ~380, 6 files |
| IT-9 | #376 (closes) | `TransportCapsule` and the status pills with the actual fps (`PlaybackDriver.measuredFPS`); J10 in full on live | `Sources/FlareModel/FlareStatusRead.swift`, `Tests/FlareModelTests/FlareStatusReadTests.swift`, `Sources/FlareApp/FlareTransport.swift`, `Sources/FlareApp/PlaybackDriver.swift`, `Tests/AppSnapshotTests/PlaybackDriverTests.swift`, `Tests/AppSnapshotTests/FlareTransportSnapshots.swift`, `UITests/FlareJourneyTests+Playback.swift` | #340 | ~380, 7 files |
| IT-10 | #385 (closes) | J9 and J6 flipped to `-FlareSample`; this packet's status line | `UITests/FlareJourneyTests+Timeline.swift`, `UITests/FlareJourneyTests+Animate.swift`, `docs/blueprints/flare/features/inspector-timeline.md` | IT-5, IT-6, IT-7, IT-8, IT-9 | ~80, 3 files |

`FlareTimeline.swift`, `FlareWindow+Timeline.swift`, `FlareTransport.swift`,
`FlareInspector.swift`, `FlareWindow+Inspector.swift` and
`UITests/FlareJourneyTests.swift` are `draw-key-save`'s, and
`FlareWorkspace.swift` and `PlaybackDriver.swift` are older; each is edited by
one task here and by no other wave-4 feature. IT-4 keeps today's
`FlareEasingInspector` inside the TIMING stub, so the easing journey stays
green until IT-8 replaces both.

**Shared docs.** A wave-4 feature beside `stage-edit` and `layers-files`:
its final task edits no shared doc. New files sit under the `flare-app` and
`flare-model` paths, which the C4 descriptions already cover. The status
goes in this packet and `inspector-timeline.wave.json`.

## Build waves

- Wave 1: IT-1, IT-2, IT-9. Independent in this wave: all three (IT-9
  starts when #340 closes).
- Wave 2: IT-3, IT-4. Independent in this wave: both.
- Wave 3: IT-5, IT-6, IT-7, IT-8. Independent in this wave: all four (IT-7
  starts when #63 closes).
- Wave 4: IT-10 (final).

Longest chain: IT-2 → IT-4 → IT-5 → IT-10, IT-1 → IT-4 → IT-5 → IT-10 and
IT-2 → IT-3 → IT-7 → IT-10 (4). Chain of 4: the Properties tab needs the
summary it shows and the paint methods it routes; the FILL section fills the
stub IT-4 places; the timeline edits need the key state IT-2 stores in
`FlareWorkspace`; and the final task flips journeys only once every section
is in.

## Acceptance test per task

| id | test | fails when |
|---|---|---|
| IT-1 | `FlareInspectorReadTests` on `.fake()`: nothing selected gives Scene 1 and `showsScene`; Ball at 12 gives "Ball", Shape, frame 12, Keys 5; Ball and Shadow give "2 layers" and keys nil; inside "wave" the hand reads its own keys | a title, kind or count is wrong |
| IT-2 | `FlarePaintTests` on `.built`: `FF3B30` on Ball is one "Undo Set Fill" and every shape takes it; "FF3B3" refuses with the reason and changes nothing; a width set is one entry and one undo restores it; cap then join are two entries and one undo restores only the join; a gradient fill reads `fillIsGradient` and refuses a hex set with "Gradients can't be edited yet." | a set leaves several entries, a bad hex lands, a gradient is overwritten, or `load` keeps a stale `paintError` or key selection |
| IT-3 | `FlareTimelineEditTests` on `.built`: Ball's 24 → 28 in 4 one-frame steps is one "Undo Move Keyframe"; onto 36 refuses with the reason, nothing moves; delete 12 is one entry; two frames inserted at 10 move 28 to 30; one removed moves it to 29; `setLabel("hit")` at 29 then nil removes it | a drag is several entries, a collision lands, or a label doesn't move with frames |
| IT-4 | `FlareInspectorSnapshots` (four PNGs); J7 on `-FlareSample bounce`: the Rotation button reads "Animated", then "Keyed at this frame" at 20; a diamond on Ball's lane at 20; → → Shift-→ step +1, +1, +10; Ball and Shadow read X "Mixed"; the existing easing journey still passes | a row doesn't key, a step is wrong, Mixed shows a value, or the easing journey breaks |
| IT-5 | `FlareFillSnapshots` (three PNGs); J8: fill reads FF3B30 and the stage shot differs; width reads 4.0 pt; cap and join read Round; ⌘Z restores only the join | a field doesn't land, or an undo restores more than its step |
| IT-6 | `FlareSceneSnapshots` (one PNG); `testSceneSection`: 1920 × 1080, 24 fps, 48 frames; set 30 fps: the SCENE fps row reads 30 and the timecode's total changes from 02:00; ⌘Z restores 24 (the fps pill is IT-9's) | a scene value doesn't land or undo misses it |
| IT-7 | `FlareTimelineEditSnapshots` (three PNGs); J11: key at 28 and "Undo Move Keyframe"; key 12 gone; 28 → 30 → 29; "hit" on the ruler at 29; each step one ⌘Z; a drag onto another key snaps back and shows the reason | a retime, delete, frame edit or label fails, or a step is two ⌘Z |
| IT-8 | `FlareEasingSnapshots` (two PNGs, replacing the inspector easing ones); J12: TIMING reads "Ease Out", then "Custom"; the four numbers change; each edit one ⌘Z; the old `testEditEasingOfAKeyframeSegment` steps pass from the popover; `FlareEasingInspector` is gone (one easing editor) | a preset doesn't land, the popover's curve doesn't follow, or two editors remain |
| IT-9 | `PlaybackDriverTests`: ticks 1/24 s apart for a second give `measuredFPS` 24, every other tick dropped gives 12. `FlareStatusReadTests`: `bounce` gives 16:9, 1080p, 24 fps; measured 18 at 24 gives "18 fps" and `isDropping`; `showcase` gives "Text not shown (1)". `FlareTransportSnapshots` (three PNGs). J10 on `-FlareSample bounce`: "Playing" while playing; the actual-fps pill exists while playing; after pause f ≠ 30; → twice gives f + 2 (mod 48 with loop on); with loop off, play from 46 stops at 47 | a pill is wrong, playback doesn't move or stop, or the fps pill never shows |
| IT-10 | J9 and J6 green on `-FlareSample bounce` (no fixture flag left in this feature's journeys) | a timeline or key journey fails on live services |

## Quality tests

| quality row | budget | test |
|---|---|---|
| QB-L2 slider scrub | a scrub step redraws the stage; one entry per scrub | J7 (IT-4), `PropertyScrubUndoTests` stay green; P2 (QH-5 #394) reports it |
| QB-L3 timeline scrub | a key drag is one merged command | `FlareTimelineEditTests` (IT-3), `LiveKeysBudgetTests.moveKeyStepWithinBudget` |
| QB-L4 playback | dropped frames show in the pill; report-only until QH-7 | `FlareStatusReadTests` (IT-9), J10 |
| QB-F3 one gesture, one step | a scrub, a width drag, a key drag, each frame edit and each easing edit are one ⌘Z | J7, J8, J11, J12 |
| QB-F4 Mixed | a value that differs across the selection reads Mixed with no key marker | J7 (IT-4), `flare-inspector-mixed.png` |
| Keyboard parity | → ← Shift-arrows on rows and handles, ⌫ on keys, ⌥= ⌥− K ⇧K ⌥K Space | J7, J11, J12, J10 |
| App audit | no Flare count over `UITests/audit-baseline.json` | the macOS run's `audit-flare-*.json` |

## Done check

- **Journeys green:** the macOS run on `dev` triggered by IT-10
  (`feature-done`) is green: J6 to J12 and the scene journey on
  `-FlareSample`, with `testDrawKeyAndSave` still green.
- **Audit zero new:** no Flare count over `UITests/audit-baseline.json`.
- **Contact sheet:** `Belt-Contact-Sheet: <run link>` on the feature issue,
  one line per journey and the audit counts.
