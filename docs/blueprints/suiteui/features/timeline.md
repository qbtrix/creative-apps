# Feature packet: timeline

**Feature:** a timeline strip that looks and works like a current motion
editor: lane beds, clip blocks and keys you can tell apart in every state, the
easing drawn between keys, a playhead with a time pill you can grab anywhere,
a ruler that stays put while the lanes scroll; keys picked by click, keyboard
and VoiceOver, dragged with snapping, several at once, and clip ends trimmed by
drag; then zoom, horizontal scroll, a frames/timecode switch and a work area.
**Line:** `line:suiteui` · **Wave:** 2 (`waves.md`) · **Lead branch:** `lead/timeline`

**Covers:** #62 (S10 restyle, key contrast on a selected span), #63 (S11 key
drag, keyboard and VoiceOver keys), #1257 (playhead time pill, clip blocks on
a lane bed), #1423 (diamonds all accent with no key picked). The same PRs also
close #771 (key shape by easing and a picked-keys set, TL-3 and TL-11), #772
(the lane's spoken value names its span and keys, TL-12) and #219 (blank
long-timeline snapshots, TL-7), so the lead puts those numbers in their PR
bodies. From the Halo timeline review of 2026-10-16 (the captain: the Halo
timeline "feels like it's 1990") it takes the strip's share of B3 (the
strip half: spans drawn tick to tick), B4, B5, B6, B7, B8, B9, B11, B12 and
B13; the Halo halves stay on Halo's line.

**This packet supersedes S10's and S11's "Touch only these files" lists**
(#62, #63): the task table is the owned-file list. It also answers two open
captain calls in `waves.in.md`:

- **Q4, the wait on #342.** #62's `Depends on: #342` asked for the
  `EditorShell(timeline:)` slot. The 2026-10-15 one-shell decision deletes
  `EditorShell` (`editor-shell-removal.md`), so nothing will ever host the
  strip in that slot. Halo and Flare host it in their own views, and the
  gallery page hosts it in a plain panel. This feature waits on no
  editor-chrome task and moves from wave 3 to wave 2.
- **Q5, `needs-human` on #63.** The captain's brief of 2026-10-16 puts #63 in
  this feature. The feature issue asks for the label to be lifted; the label
  came from a run blocked on #62, not from a design question.

**Depends on:** the suite-harness feature issue (#778, closed): goldens,
`SnapshotHost`, `.suiteControl(…)`, `FrameProbe`, the gallery stub
`Gallery/GalleryTimeline.swift`, `Journey.perf()`. No creative-core issue.
Every token it reads is on `dev`: `laneBed`, `accentFill`, `stateKeyed`,
`rowHover`, `selectedTint`, `SuiteRadius.lane`, `timelineKeyframeHit` (16),
`SuiteFont.pill`. No task edits `Tokens.swift` (editor-in-window owns it),
`KeyframeButton.swift`, `ChipRow.swift`, `ScrubValue.swift` or
`StudioScrubRow.swift` (inspector-controls owns them); this feature only calls
them.

**Clean-room.** Every rule below describes behaviour on screen. No task reads
or copies another product's code or assets.

Blueprint sections: 2 (Timeline component), 4.2 (SJ19), 4.4 (SP3, SP8), 5.2
(UC11 `TimelineMapping`, UC12 `KeyEditing`), 6.2 (Timeline keys and
playhead), 7.1 (QB-S5), 7.2 (QB-S11), 7.3 (QB-S20, QB-S21, QB-S29), 8.3
(timeline's files).

## Slices

A slice is the unit of done: its tasks have merged and its journeys pass on a
scoped macOS run that contains its last PR. Slices run most-used first.

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| TL-a | Hosts can code against the timeline's new API and contracts (key shapes, picked keys, clips, the pick, move, trim, unit and work-area callbacks), and the gallery shows the strip on its two pages, drawn as today. | TL-1, TL-2, TL-3, TL-4 | SJ0 | suite-harness (feature `depends`) |
| TL-b | The strip draws lane beds, clip blocks and keys in every state with the easing between them, a playhead with a time pill grabbed anywhere, a ruler pinned above lazily drawn lanes, hover feedback and key hits on the 16 pt token, and a scrub redraws only the playhead. | TL-5, TL-6, TL-7, TL-8, TL-9 | SJ19a, SP3 | TL-a (TL-5, TL-7) |
| TL-c | Keys are picked by click, Shift-click, Command-click and right-click, cleared by a click on the bed, stepped with ← and →, and read and picked by VoiceOver. | TL-10, TL-11, TL-12 | SJ19b | TL-a (TL-10); TL-b (TL-11) |
| TL-d | Picked keys drag as one group with snapping to frames and the playhead, and a clip's ends trim by drag, each drag one step for the host. | TL-13, TL-14, TL-15 | SJ19c, SP8 | TL-a (TL-13); TL-c (TL-13, TL-14) |
| TL-e | The strip zooms (⌘+, ⌘−, ⌘0, pinch, a zoom bar), scrolls sideways, switches frames and timecode, and shows a draggable work area on the ruler. | TL-16, TL-17, TL-18, TL-19 | SJ19d | TL-a (TL-16); TL-b (TL-17, TL-18, TL-19); TL-c, TL-d (TL-19) |

TL-c to TL-e wait on TL-b because their lanes, ruler and strip edits land in
files TL-b restyles (`TimelineLaneInput.swift`, `TimelineRuler.swift`,
`TimelineStrip.swift`): a wait, not a shared file. TL-2 cuts today's
`TimelineStrip.swift` into seam files first (`TimelineLaneAccess.swift`,
`TimelineStrip+Keys.swift`), so TL-c's keyboard and VoiceOver work owns files
no other slice touches.

### Who uses each part

H: Halo (`HaloTimelineView`, today's only caller). F: Flare (`FlareTimeline`,
built by draw-key-save DK-10; retime and key menus by inspector-timeline IT-7,
whose wait on #63 this feature meets). "Both" means both.

| part | slice | used by | what the host does with it (its own line's follow-up) |
|---|---|---|---|
| lane bed, hover | TL-b | both | nothing: drawn by the strip |
| clip blocks with contrast (Halo's in and out points) | TL-b | H | nothing: `spans` keep their meaning |
| key states: idle, picked, at the playhead | TL-b | both | passes `pickedFrames` per track (H: its picked keys; F: `selectedKeys`) |
| key shape by easing, the curve between keys | TL-b | both | passes `TimelineKey(frame:shape:)` from its easing |
| playhead pill, grab anywhere | TL-b | both | nothing |
| ruler pinned while lanes scroll (B4) | TL-b | both, H first | H drops its outer vertical `ScrollView` and offers the capped height |
| key hits on the 16 pt token (B11) | TL-b | both | nothing |
| pick by click, Shift, ⌘, right-click; bed clears (B5, B6) | TL-c | both | `onPickKeyframe` into its Model's selection; H's ⌫ acts on it |
| ← → and VoiceOver keys (#63) | TL-c | both | nothing beyond `onPickKeyframe` |
| drag picked keys with snapping | TL-d | both (F: IT-7 retime; H: retime, promoted from tier 2) | `onMoveKeyframes` per frame step, `onEndKeyDrag` closes one undo step |
| trim a clip's ends | TL-d | H | `onTrim` sets in or out, `onEndTrim` closes one undo step |
| zoom, horizontal scroll | TL-e | both | passes `toolbar: true` (zoom keys and pinch work without it) |
| frames/timecode | TL-e | both | owns the unit, passes `unit` and `fps`, and uses `TimelineTime.label` for its own readout so the ruler, pill and readout agree |
| work area | TL-e | both, H first (Loop and Render honour it) | owns the range, passes `workArea`, takes `onWorkArea` |

## Journey steps

All on the gallery (`-SuiteGallery timeline` or `timeline-long`, live rules),
reading the log `suite.gallery.log` and `suite.controls`. Every step that
changes mode or selection clicks or drags something visible with the mouse
(factory lesson 152); keyboard shortcuts get a step of their own after the
mouse step that shows the same thing. Each file declares
`extension SuiteJourneyTests`.

1. **SJ0** `testGalleryOpensEveryPage` (exists; TL-4): opens `timeline` and
   `timeline-long`; every `suite.gallery.timeline.*` control is listed, none
   dead.
2. **SJ19a** `testTimelineLooksAndScrubs` (`+Timeline`, TL-5 writes it
   skipped, TL-8 enables it), on `timeline`: hover Ball's key at 12 (the
   shot shows the hover ring); click Shadow's name (log `track shadow`; its
   bed takes the selected tint; a bed click is SJ19b's, TL-c); press on the playhead line
   inside Badge's lane, not on the ruler, and drag 120 pt left (log
   `scrub 18`; the pill's label reads `18`); drag on the ruler to frame 30
   (log `scrub 30`). Then on `timeline-long`: scroll the lanes down 2,000 pt
   with the mouse wheel over the lanes (`suite.gallery.timeline.ruler`'s
   frame y unchanged, a lane past the 60th hittable); drag on the ruler
   again (log `scrub …`). Shots: `timeline-idle`, `timeline-hover`,
   `timeline-long-scrolled`.
3. **SP3** `testTimelineScrubLatency` (`+Timeline`, TL-8): velocity drag of
   the playhead pill across 600 pt on `timeline-long`, series
   `timeline-scrub`. Report-only.
4. **SJ19b** `testTimelinePicksKeys` (`+TimelineKeys`, TL-10 skipped, TL-12
   enables), on `timeline`: click Ball's key at 12 (log
   `pick ball 12 replace`; the key's element `isSelected`); Shift-click its
   key at 24 (`pick ball 24 extend`); ⌘-click 12 (`pick ball 12 toggle`);
   right-click Shadow's key at 36 (`pick shadow 36 replace`, and the page's
   context menu shows "Ease In"); click Ball's empty bed (`pick ball none`).
   Keyboard step: click Ball's key at 0, press → twice (`pick ball 24
   replace`), ← at the first key changes nothing. VoiceOver step: the key
   element labelled "Key at frame 36, eased" exists on Shadow's lane and its
   `click()` (the accessibility default action) logs `pick shadow 36
   replace`; Badge's lane value reads "Frames 20–50, 3 keyframes at 20, 30,
   50".
5. **SJ19c** `testTimelineDragsKeysAndTrimsClips` (`+TimelineDrag`, TL-13
   skipped, TL-15 enables), on `timeline` at 10 pt per frame: drag Ball's key
   at 12 by 52 pt (log `move +5`, then `move end`); pick Ball's 24 and
   36 and drag 24 by 30 pt (`move +3` with both keys moved, `move end`);
   drag Ball's last key 400 pt right (the group stops when that key reaches
   frame 59; the log sums to the clamped delta); drag Shadow's key at 12 to
   6 pt short of the playhead at 30 (it lands on 30); drag Badge's clip's
   right end 100 pt left (`trim badge end 40`, `trim end`), then its left end 50 pt right (`trim badge start 25`);
   the pointer over a clip end is the resize cursor (the shot shows the
   time pill while dragging).
6. **SP8** `testKeyDragLatency` (`+TimelineDrag`, TL-15): velocity drag of a
   picked key across 600 pt on `timeline-long`, series `key-drag`.
   Report-only.
7. **SJ19d** `testTimelineZoomsScrollsAndSetsTheWorkArea` (`+TimelineNav`,
   TL-16 skipped, TL-19 enables), on `timeline-long` with the toolbar: drag
   the "Zoom" bar right (the ruler's label step falls; the zoom bar's value
   grows); click Fit (back to the whole range); click a lane, then ⌘+ twice
   and ⌘− once (a separate step; the zoom value follows); scroll sideways
   with the wheel (ruler labels change, the names column stays); click the
   "Timecode" chip (log `unit timecode`; ruler labels and the pill read
   `00:01:06` style); click "Frames" back; click the "Work Area" chip (log
   `work 0…9999`); drag the work area's left handle 120 pt right and its
   right handle 200 pt left (one log line per drag end, `work <in>…9999`
   then `work <in>…<out>`, with in above 0 and out below 9999); press
   Escape mid-drag on the second handle (nothing logged).

## Screens and states

| Screen | Empty | Error | Loading |
|---|---|---|---|
| `timeline` (60 frames at 24 fps, 10 pt per frame, playhead 30; Ball keys 0 linear, 12 eased, 24 hold, 36 linear; Shadow keys 12 and 36 eased; Badge a clip 20…50 with keys 20, 30, 50) | the page switch "No tracks": the strip's names column and ruler, the host's empty text under them, no lanes | a key drag past the end clamps as a group; a trim past the other edge stops one frame short | none |
| `timeline-long` (300 lanes, 10,000 frames, toolbar on) | – | – | none: lanes are lazy, so the page opens at once |
| Keys | no keys on a lane: a bare bed | – | – |
| Picked keys | nothing picked: every key idle (#1423) | – | – |
| Toolbar | `toolbar: false` (today's hosts): no row, zoom keys and pinch still work | – | – |
| Work area | off: no bar on the ruler | – | – |

Snapshot PNGs (`SuiteTimelineSnapshots`, `assertGolden` in Light, Dark,
Light + Increase Contrast and Dark + Increase Contrast): `suiteui-timeline`
(keys in the three shapes, one picked, one at the playhead),
`suiteui-timeline-clips` (Badge's clip with keys on it, the selected track),
`suiteui-timeline-long` (#219: names, ruler labels 0 to about 600, keys,
playhead), `suiteui-timeline-hover`, `suiteui-timeline-toolbar` (timecode,
work area on).

## Contract slice

TL-1 lands two contracts verbatim from
`docs/blueprints/suiteui/contracts/Contracts.swift` and one new one:

```swift
// Contracts/TimelineMapping.swift (UC11, verbatim): TimelineScale, RulerMarkSet
public protocol TimelineMapping: Sendable {
    func x(forFrame frame: Int, scale: TimelineScale) -> Double
    func frame(atX x: Double, scale: TimelineScale) -> Int
    func keyframe(nearX x: Double, in keyframes: [Int], tolerance: Double, scale: TimelineScale) -> Int?
    func rulerMarks(visible: ClosedRange<Double>, minimumSpacing: Double, scale: TimelineScale) -> RulerMarkSet
}
// Contracts/KeyEditing.swift (UC12, verbatim): LaneKey
public protocol KeyEditing: Sendable {
    func nextKey(after key: LaneKey, direction: Int, tracks: [String: [Int]]) -> LaneKey?
    func frameDelta(points: Double, scale: TimelineScale) -> Int
    func moved(_ keys: Set<LaneKey>, by delta: Int, lastFrame: Int) -> [LaneKey: Int]
}
// Contracts/TimelineEditing.swift (new): the values the strip's API passes, and snap and trim
public enum TimeUnit: String, Hashable, Sendable, CaseIterable { case frames, timecode }
public enum SpanEdge: String, Hashable, Sendable { case start, end }
public enum PickMode: String, Hashable, Sendable { case replace, extend, toggle }
public protocol TimelineEditing: Sendable {
    /// `frame`, or `playhead` when their ticks are within `radius` points (a tie goes to the playhead).
    func snapped(_ frame: Int, playhead: Int, radius: Double, scale: TimelineScale) -> Int
    /// `span` with `edge` at `frame`: inside 0...lastFrame, never shorter than one frame, the other edge fixed.
    /// The work area moves its handles by the same rule.
    func trimmed(_ span: ClosedRange<Int>, edge: SpanEdge, to frame: Int, lastFrame: Int) -> ClosedRange<Int>
}
/// Never snaps; trims with no one-frame floor (an edge past the other gives frame...frame).
public struct FakeTimelineEditing: TimelineEditing
```

Public API TL-3 adds (additive: `HaloTimelineView`'s call and every existing
`TimelineTrack(keyframes:spans:)` compile and draw as before):

```swift
public enum TimelineKeyShape: String, Hashable, Sendable { case linear, eased, hold }
public struct TimelineKey: Hashable, Sendable { public var frame: Int; public var shape: TimelineKeyShape }
TimelineTrack(id:, name:, keys: [TimelineKey], spans: [ClosedRange<Int>] = [],
              pickedFrames: Set<Int> = [], isSelected: Bool = false)
// the old init maps `keyframes` to .linear keys; `keyframes` stays as a computed [Int]
TimelineStrip(tracks:, duration:, frameWidth:, playhead:,                 // as today
              unit: TimeUnit = .frames, fps: Int = 0, workArea: ClosedRange<Int>? = nil, toolbar: Bool = false,
              onScrub:, onSelectKeyframe:, onSelectTrack:,               // as today; a plain key click still calls onSelectKeyframe
              onPickKeyframe: (ID, Int?, PickMode) -> Void = …,           // nil frame: the bed was clicked, clear the pick
              onMoveKeyframes: (Int) -> Void = …, onEndKeyDrag: () -> Void = …,   // frames since the last call
              onTrim: (ID, SpanEdge, Int) -> Void = …, onEndTrim: () -> Void = …,
              onUnit: (TimeUnit) -> Void = …, onWorkArea: (ClosedRange<Int>?) -> Void = …)
public enum TimelineTime { static func label(frame: Int, fps: Int, unit: TimeUnit) -> String }   // TL-16
```

`onMoveKeyframes` and `onEndKeyDrag` are the names inspector-timeline's
pseudocode already calls (`moveSelectedKeys`, `endKeyDrag`). The host owns the
picked keys, the unit and the work area (values in, closures out); the strip
owns only presentation state: hover, zoom, scroll, a drag in progress.

## Pseudocode

```
Files after TL-2 (all Sources/SuiteUI/): TimelineStrip (layout), TimelineTrack (data),
TimelineLane (one lane's Canvas, Equatable), TimelineLaneInput (the lane's pointer),
TimelineLaneAccess (the lane's accessibility), TimelineRuler, TimelinePlayhead,
TimelineStrip+Keys (focus-scoped keys). Debug-only `static var bodyRuns` on
TimelineStrip, TimelineLane, TimelineRuler and TimelinePlayhead.

TimelineLook (TL-5, no SwiftUI: returns SuiteHex palette entries and rects)
  keyFill(key, picked, atPlayhead): atPlayhead ? stateKeyed : picked ? accent : textSecondary   # #1423: never track.isSelected
  keyEdge(picked): picked ? 1 pt white : 1 pt panel        # the edge carries contrast on a clip (#62)
  keyPath(shape): linear diamond, eased circle, hold square; draw 10 pt, hit 16 pt
  clipFill: accent 24 % into panel, written out per appearance:
            Dark 0x233A5B, Light 0xC1D8F6, Dark+IC 0x2A3D57, Light+IC 0xC4D9F4
  segment(a, b): a.shape == .hold ? step : line; eased adds a curve glyph at the middle when b.x - a.x >= 24 pt
  pillRect(playheadX, labelWidth, visible): centred on the line, clamped inside visible (inset first)

Lane (TL-6): bed laneBed radius lane, 2 pt gap above and below; selected track: selectedTint
  clip block: from tick(span.lower) to tick(span.upper), at least 10 pt wide, height bed - 4, radius min(lane, h/2), clipFill
  tween: 2 pt textTertiary between consecutive keys; keys over everything with their edge
  hover (presentation state): bed rowHover; key under pointer a 2 pt accent ring 1 pt outside;
  changes animate with SuiteMotion.state(reduceMotion:)
  key hit: FrameMapping.keyframe(nearX:, tolerance: timelineKeyframeHit / 2)            # B11

Hit priority on a press inside a lane (TimelineLaneInput):
  key within 8 pt > clip end within 6 pt (TL-15) > playhead band 8 pt each side > bed (select track, clear pick)
  on the ruler: work-area handle (TL-18) > pill and ruler (scrub)

Strip layout (TL-7):
  VStack { toolbar row if toolbar (TL-17) ;
           HStack { corner ; ruler (outside both scroll views, draws marks at x - visibleX.lower) } ;
           ScrollView(.vertical) { HStack { LazyVStack(names) ; ScrollView(.horizontal) { LazyVStack(lanes) } } } }
  ideal height = toolbar + ruler + lanes * count; offered less, the lanes scroll under the pinned ruler
  (a host still inside its own vertical ScrollView is offered unlimited height and sees today's layout)
  snapshot branch: lanes offered the strip's width, leading, clipped (#219)
  each lane is Equatable over (track, mapping, hover); the lane id is the track id

Playhead (TL-8): one Equatable layer over ruler and lanes
  2 pt accent line; pill accentFill, white SuiteFont.pill text, label TimelineTime.label(...)
  drawn over the ruler with a 2 pt ground knock-out, so the ruler never depends on the playhead (#1257)
  keys at the playhead on the visible rows drawn here in stateKeyed, so no lane depends on the playhead
  grab: the pill and a 16 pt band down the line; drag -> frame(atX:)
  one scrub sender here, used by the ruler's drag too: onScrub only when frame != last sent (#1297, strip half)
  probe series timeline-scrub

Pick rule (TL-10, pure in TimelineKeys):
  press on key k with modifiers m: m.shift -> (k, .extend) ; m.command -> (k, .toggle) ; else (k, .replace)
  right press on k: k picked ? nothing : (k, .replace)       # B6: the menu acts on the key under the pointer
  press on bed: onSelectTrack(id) ; onPickKeyframe(id, nil, .replace)
  SuiteKeyEditing.nextKey: same track, sorted, nil past either end
  frameDelta: (points / frameWidth).rounded() ; moved: clamp the group's delta so min >= 0 and max <= lastFrame

Keyboard and VoiceOver (TL-12):
  the strip is focusable; focus draws the 2 pt accent ring 1 pt outside (as ScrubField)
  ← / → with a pick: nextKey from the last picked key -> onPickKeyframe(.replace); no pick: the first key of the selected track
  each key an accessibility child "Key at frame 24, eased", default action picks it (.replace), isSelected when picked
  lane value: "Frames 20–50, 3 keyframes at 20, 30, 50" (spans first, then keys; "No keyframes")
  children are built in the lane body, which a scrub never runs (lesson 153: no per-frame scaffolding)

Key drag (TL-13 rules, TL-14 view):
  press on an unpicked key picks it first (.replace); then the drag moves every picked key
  total = snapped(grabbed + frameDelta(dx)) - grabbed, then moved(...) clamps the group
  send onMoveKeyframes(total - lastSent) only when it changes; onEndKeyDrag once on release
  Escape while dragging: onMoveKeyframes(-lastSent), onEndKeyDrag
  a time pill above the grabbed key shows its new frame while dragging; probe series key-drag
Trim (TL-15): press within 6 pt of a clip end (resize cursor on hover)
  frame = snapped(frame(atX:)); span' = trimmed(span, edge, frame, lastFrame)
  onTrim(id, edge, span'.edge) when it changes; onEndTrim once

Zoom and scroll (TL-16 rules, TL-17 view): zoom is a factor over the host's frameWidth, 1 = fit
  zoomIn/zoomOut: ViewerZoom.zoomedIn/zoomedOut(factor), clamped 1...max(1, 64 / frameWidth)
  anchor: the frame under the pointer (for ⌘+ and ⌘−, the playhead) keeps its screen x
  ⌘+ ⌘− ⌘0 while the strip has focus (TimelineStrip+Keys does not take them: TL-17 adds its own handler)
  pinch: MagnifyGesture on the lanes, continuous, same clamp; zoom bar: StudioScrubRow "Zoom", Fit button
  sideways scroll by wheel and trackpad; during playback the view jumps a page when the playhead leaves it

Units and work area (TL-16 rules, TL-18 view):
  TimelineTime.label: frames "30"; timecode "MM:SS:FF" ("00:01:06" at 24 fps), "H:MM:SS:FF" from an hour; fps <= 0 -> frames
  ruler labels in timecode sit on whole seconds once the frame step reaches fps / 2; label spacing from the widest label
  toolbar: "Frames" / "Timecode" chips (ChipRow) -> onUnit; "Work Area" chip -> onWorkArea(on ? 0...duration : nil)
  work area: a bar on the ruler's lower 6 pt, two 16 pt handles; drag -> trimmed(...) -> onWorkArea on release
  lanes outside the work area dim to 60 % in the playhead layer
```

## Tasks

Every task is one PR to `dev`: at most 400 changed lines and 15 files, label
`fast-lane`, body lines `Belt-Lead:`, `Feature: timeline`, `Slice: <slice>`,
`Fast-Check: pass`, `Head:`, and for a task with mutations its `Mutate:` line
(see "Mutations on macOS" below). TL-19 carries `feature-done`. Every
component task's snapshot test calls `assertGolden` through `SnapshotHost` in
the four appearances, registers its controls with `.suiteControl` (a test
that each entry's reason equals its `.help`), emits its probe series, and
moves its state fades to `suiteReduceMotion`. No task edits
`docs/c4/model.json` (the new files sit in `suiteui-sources`, path
`Sources/SuiteUI/`), `docs/design.md`, `docs/blueprints/suiteui.md`,
`Tokens.swift` or `project.yml`: section 6.2's timeline rows go into
`docs/design.md` with suite-record (wave 4), as for every SuiteUI feature, so
this packet has no docs task. Paths drop `Sources/SuiteUI/`.

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| TL-1 | – | The three timeline contracts and their Fakes | `Contracts/TimelineMapping.swift`, `Contracts/KeyEditing.swift`, `Contracts/TimelineEditing.swift`, `Tests/SuiteUITests/TimelineFakeTests.swift` | – | ~230, 4 |
| TL-2 | – | Cut `TimelineStrip.swift` into seven of the pseudocode's files (all but `TimelineTrack.swift`, which TL-3 adds), no behaviour change; debug `bodyRuns` counters; the safe-area guard reads every `Timeline*.swift` | `TimelineStrip.swift`, `TimelineLane.swift`, `TimelineLaneInput.swift`, `TimelineLaneAccess.swift`, `TimelineRuler.swift`, `TimelinePlayhead.swift`, `TimelineStrip+Keys.swift`, `Tests/SuiteUITests/TimelineStripSafeAreaTests.swift` | – | ~330, 8 |
| TL-3 | #771 (part) | The additive API: `TimelineKey`, `TimelineKeyShape`, `pickedFrames`, the new `TimelineStrip` inputs and closures with defaults | `TimelineTrack.swift`, `TimelineStrip.swift`, `Tests/SuiteUITests/TimelineTrackTests.swift`, `Tests/mutations/SuiteUI.TimelineTrack.json` | TL-1, TL-2 | ~220, 4 |
| TL-4 | – | The `timeline` and `timeline-long` pages over the new API, their log, the page switches (no tracks, nothing picked, toolbar), an easing context menu on the strip as hosts add one, the `-SuiteGalleryFakes` path | `Gallery/GalleryTimeline.swift` | TL-3 | ~300, 1 |
| TL-5 | #62, #1423 (part) | Checks first, then the look rules: `TimelineLook`; SJ19a and SP3 skipped; the real-window scrub budget disabled | `TimelineLook.swift`, `Tests/SuiteUITests/TimelineLookTests.swift`, `Tests/mutations/SuiteUI.TimelineLook.json`, `UITests/SuiteJourneyTests+Timeline.swift`, `Tests/AppSnapshotTests/SuiteTimelineScrubWindowTests.swift` | TL-3 | ~380, 5 |
| TL-6 | #62 (closes with TL-8), #1423 (strip half), #771 (shapes), #1257 (clips) | Lanes: bed, clip blocks, keys in their states and shapes, the tween and the eased glyph, hover; key hits on the 16 pt token (B11); Equatable lanes | `TimelineLane.swift`, `TimelineLaneInput.swift`, `Tests/SuiteUITests/TimelineLaneTests.swift`, `Tests/AppSnapshotTests/SuiteTimelineSnapshots.swift`, `Tests/mutations/SuiteUI.TimelineLane.json`, `Tests/mutations/SuiteUI.TimelineLaneInput.json` | TL-5 | ~360, 6 |
| TL-7 | #219 (closes) | Layout: the ruler pinned above vertically scrolling lazy lanes (B4, B13 strip half), the ideal height, #219's snapshot width; `QB-S11` ruler budget | `TimelineStrip.swift`, `Tests/SuiteUITests/TimelineStripLayoutTests.swift`, `Tests/SuiteUITests/TimelineBudgetTests.swift`, `Tests/mutations/SuiteUI.TimelineStrip.json` | TL-3 | ~300, 4 |
| TL-8 | #1257 (closes), #62 (closes) | The playhead: 2 pt line, the time pill, grab from the pill or the band anywhere down the lanes, in its own layer with the at-playhead keys; scrub sends only changed frames; `timeline-scrub` series in QB-S5; enables SJ19a, SP3 and the scrub budget | `TimelinePlayhead.swift`, `TimelineRuler.swift`, `Tests/SuiteUITests/TimelinePlayheadTests.swift`, `Tests/mutations/SuiteUI.TimelinePlayhead.json`, `UITests/SuiteJourneyTests+Timeline.swift`, `Tests/AppSnapshotTests/SuiteTimelineScrubWindowTests.swift`, `UITests/SuiteJourneyTests+Budgets.swift` | TL-5, TL-6, TL-7 | ~340, 7 |
| TL-9 | – | Baselines from the CI artifact: `suiteui-timeline`, `-clips`, `-long`, `-hover` in the four appearances | `Tests/AppSnapshotTests/Golden/timeline/` (16 PNGs) | TL-6, TL-8 and their CI run | PNGs |
| TL-10 | #63 (part), #771 (part) | Checks first, then the key rules: `SuiteKeyEditing` (nextKey, frameDelta, the group-clamped move) and the pick rule; SJ19b skipped | `TimelineKeys.swift`, `Tests/SuiteUITests/TimelineKeysTests.swift`, `Tests/mutations/SuiteUI.TimelineKeys.json`, `UITests/SuiteJourneyTests+TimelineKeys.swift` | TL-1 | ~320, 4 |
| TL-11 | #771 (closes), #1423 (closes), B5, B6 | Pointer picking on lanes: click, Shift, ⌘, right-click, the bed clears and selects the track | `TimelineLaneInput.swift`, `Tests/SuiteUITests/TimelineLanePickTests.swift`, `Tests/mutations/SuiteUI.TimelineLaneInput.json` | TL-10, TL-6 | ~220, 3 |
| TL-12 | #63 (keyboard and VoiceOver half), #772 (closes) | Focus ring, ← and →, each key an accessibility child with its default action, the lane's spoken value; enables SJ19b | `TimelineLaneAccess.swift`, `TimelineStrip+Keys.swift`, `Tests/SuiteUITests/TimelineAccessTests.swift`, `Tests/mutations/SuiteUI.TimelineLaneAccess.json`, `Tests/mutations/SuiteUI.TimelineStrip+Keys.json`, `UITests/SuiteJourneyTests+TimelineKeys.swift` | TL-10, TL-11 | ~300, 6 |
| TL-13 | #63 (drag rules) | Checks first, then `SuiteTimelineEditing` (snap, trim) and the key-drag step rule; SJ19c and SP8 skipped; the real-window key-drag budget disabled | `TimelineEdits.swift`, `Tests/SuiteUITests/TimelineEditsTests.swift`, `Tests/mutations/SuiteUI.TimelineEdits.json`, `UITests/SuiteJourneyTests+TimelineDrag.swift`, `Tests/AppSnapshotTests/SuiteTimelineKeyDragWindowTests.swift` | TL-1, TL-10 | ~380, 5 |
| TL-14 | #63 (closes) | Key drag: press picks, the group moves with snapping, the drag pill, Escape cancels, `key-drag` series; enables the key-drag budget | `TimelineLaneInput.swift`, `Tests/SuiteUITests/TimelineKeyDragTests.swift`, `Tests/mutations/SuiteUI.TimelineLaneInput.json`, `Tests/AppSnapshotTests/SuiteTimelineKeyDragWindowTests.swift` | TL-13, TL-11 | ~300, 4 |
| TL-15 | – | Trim: the clip ends' grab zones and resize cursor, `onTrim` and `onEndTrim`; enables SJ19c and SP8 | `TimelineLaneInput.swift`, `Tests/SuiteUITests/TimelineTrimTests.swift`, `Tests/mutations/SuiteUI.TimelineLaneInput.json`, `UITests/SuiteJourneyTests+TimelineDrag.swift` | TL-14 | ~260, 4 |
| TL-16 | – | Checks first, then the navigation rules: `TimelineZoom` (steps, clamp, anchor, follow) and `TimelineTime` (labels, timecode label frames); SJ19d skipped | `TimelineZoom.swift`, `TimelineTime.swift`, `Tests/SuiteUITests/TimelineNavTests.swift`, `Tests/mutations/SuiteUI.TimelineZoom.json`, `Tests/mutations/SuiteUI.TimelineTime.json`, `UITests/SuiteJourneyTests+TimelineNav.swift` | TL-1 | ~360, 6 |
| TL-17 | – | Zoom and sideways scroll: ⌘+ ⌘− ⌘0, pinch, the toolbar row with the zoom bar and Fit, follow during playback | `TimelineStrip.swift`, `TimelineToolbar.swift`, `Tests/SuiteUITests/TimelineToolbarTests.swift`, `Tests/mutations/SuiteUI.TimelineStrip.json`, `Tests/mutations/SuiteUI.TimelineToolbar.json` | TL-16, TL-7 | ~340, 5 |
| TL-18 | – | Units and work area: the Frames/Timecode chips, ruler and pill text in the unit, the Work Area chip, the bar and its handles | `TimelineToolbar.swift`, `TimelineRuler.swift`, `Tests/SuiteUITests/TimelineRulerUnitTests.swift`, `Tests/mutations/SuiteUI.TimelineToolbar.json`, `Tests/mutations/SuiteUI.TimelineRuler.json` | TL-17, TL-8 | ~320, 5 |
| TL-19 | – | Enables SJ19d; baselines `suiteui-timeline-toolbar` in the four appearances; the feature's `.wave.json` status; `feature-done` | `UITests/SuiteJourneyTests+TimelineNav.swift`, `Tests/AppSnapshotTests/Golden/timeline/` (4 PNGs) | TL-18, TL-15, TL-12, TL-9 | ~60, 6 |

Inside the feature: `TimelineStrip.swift` passes TL-2 → TL-3 → TL-7 →
TL-17, `TimelineLaneInput.swift` TL-2 → TL-6 → TL-11 → TL-14 → TL-15,
`TimelineRuler.swift` TL-2 → TL-8 → TL-18, `TimelineToolbar.swift` TL-17 →
TL-18, and each slice's journey file goes from its checks-first task to the
task that enables it. A mutation plan follows its source file, so a plan is
owned by each task in that file's chain and never by two tasks that can run
at once. TL-9 and TL-19 never hold the same PNG.

## Build waves

- Wave 1: TL-1, TL-2. Independent in this wave: both.
- Wave 2: TL-3, TL-10, TL-16. Independent in this wave: all three.
- Wave 3: TL-4, TL-5, TL-7, TL-13. Independent in this wave: all four.
- Wave 4: TL-6, TL-17. Independent in this wave: both.
- Wave 5: TL-8, TL-11. Independent in this wave: both.
- Wave 6: TL-9, TL-12, TL-14, TL-18. Independent in this wave: all four.
- Wave 7: TL-15. Independent in this wave: TL-15 alone.
- Wave 8: TL-19 (`feature-done`, final). Independent in this wave: TL-19 alone.

Longest chain: TL-1 → TL-3 → TL-5 → TL-6 → TL-11 → TL-14 → TL-15 → TL-19 (8).
Chain of 8: TL-3 adds the key types TL-5's look rules read; TL-6 draws with
TL-5's rules; then one pointer handler per lane (`TimelineLaneInput.swift`)
takes, in turn, the 16 pt hit (TL-6), picking (TL-11), key drag (TL-14) and
trim (TL-15), because a press is classified once (key, clip end, playhead
band, bed) and each step adds one branch to the same gesture; TL-19 carries
`feature-done`, whose run must show every journey green. Splitting that
gesture across files would let two handlers claim one press.

## Acceptance test per task

Each slice's checks land in its first code task (TL-5, TL-10, TL-13, TL-16)
or with the code (TL-1 to TL-3). A test that lands before its code is
`@Test(.disabled("waits on TL-n"))`, a journey `throw XCTSkip("waits on TL-n")`,
and that task enables it. Mutation filters are `swift test --filter` regexes.

| id | test | fails when | mutations (plan: label → filter) |
|---|---|---|---|
| TL-1 | `TimelineFakeTests`: each Fake gives `main.swift`'s literal result with its gap (a label every 10 frames and no ticks; each key clamped on its own; no snap; a trim may invert to `frame...frame`) | a Fake changes, so the live tests stop proving the gap closed | none: fakes only |
| TL-2 | The existing `FrameMapping*`, `Ruler*` and `SuiteTimelineSnapshots` tests pass unchanged; `TimelineStripSafeAreaTests` reads every `Sources/SuiteUI/Timeline*.swift` and fails on a color `.background(` without `ignoresSafeAreaEdges:` | a split file draws a background past the safe area (#1034) | none: no behaviour change |
| TL-3 | `TimelineTrackTests`: `TimelineTrack(keyframes: [0, 12])` gives keys `[0 .linear, 12 .linear]` and `keyframes == [0, 12]`; `pickedFrames` round-trips; `HaloTimelineView.swift` compiles untouched (the macOS build) | the old init changes what it draws, or a picked frame is lost | `SuiteUI.TimelineTrack`: old init maps keys to `.eased` → `TimelineTrackTests`; `keyframes` reads `pickedFrames` → `TimelineTrackTests` |
| TL-4 | SJ0 opens both pages with `violations()` empty; the page builds with live rules and with `-SuiteGalleryFakes` | a control on the page is unregistered or dead | none: gallery fixture |
| TL-5 | `TimelineLookTests`: idle `textSecondary` on a selected track with nothing picked (#1423); picked `accent`; at the playhead `stateKeyed`; the three paths; `clipFill` equals the 24 % mix of `accent` into `panel` within 1/255 in each appearance; idle key fill and the picked key's edge against `clipFill` are ≥ 3:1 in all four (#62); the pill stays inside the visible stretch at frame 0 and at the last frame | a picked state follows the track, a key at the playhead isn't keyed, a key on a clip is under 3:1, or the pill leaves the lanes | `SuiteUI.TimelineLook`: picked reads `isSelected` (#1423) → `TimelineLookTests`; at-playhead check dropped → `TimelineLookTests`; pill clamp's upper bound dropped → `TimelineLookTests` |
| TL-6 | `TimelineLaneTests`: a span 20…50 at 10 pt per frame gives a block from x 200 to 500 (tick to tick, plus the inset); a span of one frame is 10 pt wide; keys 12 pt apart pick the nearer; a press 7 pt from a key hits it and 9 pt doesn't (16 pt token, B11); `SuiteTimelineSnapshots` records `suiteui-timeline`, `-clips`, `-hover` | a block covers a cell past its last frame, the hit is the 10 pt draw size, or the far key wins | `SuiteUI.TimelineLaneInput`: tolerance `timelineKeyframe` for `timelineKeyframeHit / 2` → `TimelineLaneTests`; `SuiteUI.TimelineLane`: the block ends at `upper + 1` → `TimelineLaneTests`; the minimum width dropped → `TimelineLaneTests` |
| TL-7 | `TimelineStripLayoutTests`: ideal height is ruler + lanes (toolbar off) and ruler + 36 + lanes (on); offered 200 pt with 300 lanes, the ruler's frame is y 0…24 after a 2,000 pt scroll and the rows built stay under 20; the snapshot branch offers the lanes the strip's width (#219: a 20,000-frame snapshot has names and labels); `TimelineBudgetTests` QB-S11 | the ruler scrolls away, lanes are built eagerly, or #219's PNG is blank | `SuiteUI.TimelineStrip`: ideal height drops the ruler → `TimelineStripLayoutTests`; the lanes' stack made eager → `TimelineStripLayoutTests` |
| TL-8 | `TimelinePlayheadTests`: a press 7 pt beside the line in a lane grabs it, 9 pt doesn't; dragging over the same frame sends one `onScrub`; the pill reads `30` at 30. `SuiteTimelineScrubWindowTests` (real window, below); SJ19a, SP3 | a scrub repeats a frame, the band is the 2 pt line, or a lane redraws during a scrub | `SuiteUI.TimelinePlayhead`: the changed-frame guard dropped → `TimelinePlayheadTests\|SuiteTimelineScrubWindowTests`; band width 2 for 16 → `TimelinePlayheadTests` |
| TL-9 | The next CI run's golden checks pass against the committed `timeline` baselines | a baseline is missing or differs | none: PNGs |
| TL-10 | `TimelineKeysTests`: `nextKey` stays on its track and is nil past either end; `frameDelta` rounds (14 pt at 10 pt per frame is 1, 15 is 2); `moved` of keys 40 and 46 by +5 with last frame 47 moves both by +1 (the group clamp; the Fake moves only 46); the pick rule's four cases and the right-press rule | a key crosses tracks, a group loses its spacing at an edge, or a modifier picks the wrong mode | `SuiteUI.TimelineKeys`: per-key clamp (the Fake's) → `TimelineKeysTests`; Shift gives `.replace` → `TimelineKeysTests`; right press on an unpicked key keeps the old pick (B6) → `TimelineKeysTests` |
| TL-11 | `TimelineLanePickTests`: a press on a key with each modifier calls `onPickKeyframe` with its mode and a plain press also `onSelectKeyframe`; a press on the bed calls `onSelectTrack` and `onPickKeyframe(id, nil, .replace)` (B5) | the bed does nothing, or a plain click extends | `SuiteUI.TimelineLaneInput`: bed press skips the clear → `TimelineLanePickTests`; plain press sends `.extend` → `TimelineLanePickTests` |
| TL-12 | `TimelineAccessTests`: Badge's value "Frames 20–50, 3 keyframes at 20, 30, 50" (#772); a key child's label "Key at frame 24, eased", its action picks it, `isSelected` follows `pickedFrames`; → from 12 picks 24, ← at 0 does nothing; SJ19b | a key can't be reached without a pointer (#63), or the value drops the span | `SuiteUI.TimelineLaneAccess`: the value drops the span → `TimelineAccessTests`; the child label reads the index, not the frame → `TimelineAccessTests`; `SuiteUI.TimelineStrip+Keys`: → and ← swapped → `TimelineAccessTests` |
| TL-13 | `TimelineEditsTests`: a key 7 pt from the playhead snaps to it, 9 pt doesn't, a tie goes to the playhead; `trimmed` keeps one frame and the other edge, and clamps to 0…last; the drag step rule sends +1, +1, −2 for totals 1, 2, 0 and nothing for a repeat | a snap misses its radius, a trim inverts a span, or a step repeats | `SuiteUI.TimelineEdits`: `<` for `<=` on the radius → `TimelineEditsTests`; the one-frame floor dropped → `TimelineEditsTests`; steps sent per sample → `TimelineEditsTests` |
| TL-14 | `TimelineKeyDragTests`: pressing an unpicked key picks it before it moves; two picked keys move together; Escape sends the negative of what was sent; one `onEndKeyDrag` per drag; `SuiteTimelineKeyDragWindowTests` (below) | a drag moves the old pick, a cancel leaves keys moved, or one drag ends twice | `SuiteUI.TimelineLaneInput`: the pick-on-press dropped → `TimelineKeyDragTests`; Escape skips the reverse step → `TimelineKeyDragTests` |
| TL-15 | `TimelineTrimTests`: a press 5 pt inside a clip's right end trims the end, 7 pt is a bed press; the trimmed end snaps to the playhead; one `onEndTrim` per drag; SJ19c, SP8 | the wrong end trims, a trim ignores snapping, or a drag is two steps | `SuiteUI.TimelineLaneInput`: start and end zones swapped → `TimelineTrimTests`; the snap skipped → `TimelineTrimTests` |
| TL-16 | `TimelineNavTests`: zoom steps follow `ViewerZoom` stops and stop at 1 and at 64 pt per frame; the anchor frame keeps its x within 0.5 pt; `label` gives `30`, `00:01:06` at 24 fps, `1:00:00:00` at an hour, frames when fps is 0 (no division); timecode label frames are whole seconds once the step reaches fps / 2 | the strip zooms below fit, the anchor drifts, or a label is wrong | `SuiteUI.TimelineZoom`: the lower clamp dropped → `TimelineNavTests`; anchor ignores the pointer → `TimelineNavTests`; `SuiteUI.TimelineTime`: frames field `frame % 60` → `TimelineNavTests`; the fps guard dropped → `TimelineNavTests` |
| TL-17 | `TimelineToolbarTests`: the zoom bar's range is 1…the clamp's max and Fit sets 1; ⌘+ from fit goes to the next stop; the toolbar's controls register with reasons equal to their help, each ≥ 20 pt (chips 28) | the bar can't zoom, Fit misses, or a control is dead | `SuiteUI.TimelineToolbar`: the bar's upper bound 1 → `TimelineToolbarTests`; `SuiteUI.TimelineStrip`: ⌘0 keeps the zoom → `TimelineToolbarTests` |
| TL-18 | `TimelineRulerUnitTests`: in timecode the ruler labels read `00:01:00` style at whole seconds and never overlap at widths 320, 640, 1,280 (QB-S21); the Work Area chip sends `0...duration` then `nil`; a handle drag sends one `onWorkArea` on release, clamped by `trimmed` | a label ignores the unit, labels overlap, or the work area inverts | `SuiteUI.TimelineRuler`: labels ignore the unit → `TimelineRulerUnitTests`; `SuiteUI.TimelineToolbar`: the chip sends the range when turning off → `TimelineRulerUnitTests` |
| TL-19 | SJ19d passes; the golden checks pass with no known issue left for `timeline` | an assert in SJ19d fails or a baseline differs | none |

**The real-window budgets** (factory lesson 153), each hosting the strip
itself, not a model, in a 1280 × 400 borderless window ordered in far off
every screen, as `PhotoWindowStrokeTests` hosts Photo's window, reusing its
`CountingHostingView`; a small host view keeps `playhead` and the picked keys
in `@State` and applies each callback as Halo and Flare do. Sample: 300 lanes,
10,000 frames, keys every 12 frames, at 4 pt per frame. Body counts come from
the debug `bodyRuns` counters TL-2 adds; NSHostingView layout passes are
reported, not judged. Both are macOS only.

- `SuiteTimelineScrubWindowTests.aScrubRedrawsOnlyThePlayhead` (TL-5 writes,
  TL-8 enables): mouse-down on the ruler, 120 dragged events at 120 Hz over
  600 pt, mouse-up. Spec: `TimelineLane` bodies 0, `TimelineRuler` bodies 0,
  `TimelinePlayhead` bodies ≤ frames crossed + 2, `TimelineStrip` bodies ≤
  frames crossed + 2, `onScrub` calls = frames crossed and never the same
  frame twice in a row.
- `SuiteTimelineKeyDragWindowTests.aKeyDragRedrawsOnlyItsLanes` (TL-13
  writes, TL-14 enables): two keys picked on lanes 5 and 6, the same 120
  events dragging the one on lane 5. Spec: lanes other than 5 and 6 run 0
  bodies, lanes 5 and 6 each ≤ frame steps + 2, `onMoveKeyframes` calls =
  frame steps, the sum of their deltas = the final delta, `onEndKeyDrag` once.

**Mutations on macOS.** SuiteUI has no Linux target (Package.swift is
protected and Q1 is open), so `scripts/mutate --plan SuiteUI.<File>` builds
and runs only on a Mac; on a Linux builder the filter matches no tests and
every entry would read ESCAPED. Until the captain answers (`waves.in.md`,
Q10): the builder writes each plan and its tests as above, `scripts/ci`
still checks every anchor on Linux (`scripts/mutate --validate`), and the PR
body ends `Mutate: macOS pending SuiteUI.<File>, …`. Before it posts a
slice's `Belt-Slice-Done:` line, the lead asks the supervisor to run those
plans on the Mac and record the score line on the PR; an escape is a missing
test, as in contract rule 14, and the slice isn't done while one escapes.

## Quality tests

| quality row | budget | test |
|---|---|---|
| QB-S5 ruler scrub and key drag | p95 ≤ 2 frames late (placeholder 3) | SP3 `timeline-scrub`, SP8 `key-drag` (TL-8 adds `timeline-scrub` to QB-S5's series) |
| Real-window render budget, scrub | 0 lane and ruler bodies over 120 samples | `SuiteTimelineScrubWindowTests` |
| Real-window render budget, key drag | 0 bodies on lanes without a picked key | `SuiteTimelineKeyDragWindowTests` |
| QB-S11 ruler marks | 4,096 pt of a 100,000-frame timeline ≤ 0.2 ms (gate 2 ms) | `TimelineBudgetTests` |
| QB-S20 hit sizes | keys 16 pt; toolbar controls ≥ 20 pt, chips 28 | `TimelineLaneTests`, `TimelineToolbarTests`, SJ25 |
| QB-S21 labels inside and never overlapping | lane widths 320, 640, 1,280; frames and timecode | `FrameMapping` label tests (exist), `TimelineRulerUnitTests` |
| QB-S29 frame mapping equals a reference | frame ↔ x for 0…lastFrame at 5 widths | `TimelineFakeTests` against the live mapping |
| Key contrast on a clip (#62) | ≥ 3:1 in four appearances | `TimelineLookTests` |
| One gesture, one step | a key drag, a trim or a work-area drag ends once | `TimelineKeyDragTests`, `TimelineTrimTests`, `TimelineRulerUnitTests` |
| Keyboard and VoiceOver parity | every key pickable without a pointer; zoom by keys; chips focusable | SJ19b, SJ19d, `TimelineAccessTests` |
| No dead controls | every toolbar control registered with its reason | SJ0, `TimelineToolbarTests` |
| Reduce Motion | hover and pick fades 0 s | `fade-start`/`fade-end` marks from TL-6 read in SJ19a with the page switch |

## Done check

Per slice (contract rule 6): its journeys green on a scoped macOS run that
contains its last merged PR, every app built, no open `finding` issue for the
slice, and every plan of its PRs scored with no escape (on the Mac, as above).
TL-a: SJ0. TL-b: SJ19a and SP3 plus the scrub budget. TL-c: SJ19b. TL-d:
SJ19c and SP8 plus the key-drag budget. TL-e: SJ19d. Then:

- **Audit zero new:** `suiteui` stays 0 for every check; Halo's counts don't
  rise (`HaloTimelineView` keeps calling the strip as today, so read Halo's
  `audit-*.json` on the same run).
- **Halo still green:** H-J3 and the `halo-timeline*` shots on the same run;
  the Halo PNGs change with the restyle, and the contact sheet lists them.
- **Contact sheet:** `Belt-Contact-Sheet: <run link>` on the feature issue,
  listing `suiteui-timeline-*`, the SJ19 shots and `halo-timeline-*`, with
  the SP3 and SP8 p95 and both window budgets' counts.
- **Follow-ups filed** (stage 4, one issue each, not tasks here): `line:halo`
  "Adopt the timeline API" (drop the outer vertical `ScrollView`, pass picked
  frames, key shapes and `toolbar: true` with fps, `onTrim` to in and out,
  `onWorkArea` to Loop and Render, `onMoveKeyframes` to retime, and drop the
  hidden per-row readouts now that #772 is in); `line:flare` needs none
  (DK-10 and IT-7 already plan these calls).

## Not in this packet

Name chips with eye, lock and solo; per-property sub-lanes; the recording
ring (#391); a resizable or collapsible timeline slot (#342 is moot with
`EditorShell` gone); marquee key selection; Shift-arrow by ten and
jump-to-next-key keys; snapping to other keys. Each can be its own `needs-ui`
issue when an app asks.

## Open

- **Q10 Mutations on macOS** (above): run SuiteUI plans on the supervisor's
  Mac, or approve Q1's Linux target for SuiteUI's pure rules. Default: the
  Mac.
- **⌘+ and ⌘− against the host's View menu.** Inside the gallery nothing
  else claims them. In Halo and Flare the canvas's Zoom In may take the
  shortcut first; each host's adoption follow-up checks it in its own
  journey and routes the menu item to the timeline while it has focus.
