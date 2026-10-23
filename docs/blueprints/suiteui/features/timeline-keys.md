# Feature packet: timeline-keys

**Feature:** the two timeline edits people expect in the first hour, built on
the one keys home. **Flare** gets a key button beside FILL colour, STROKE
colour and STROKE width, the same `KeyframeButton` the transform rows use: it
shows not animated, animated or keyed here, and a click adds or removes a key
at the playhead. With the recording ring on, a fill or stroke edit keys
instead of silently changing every frame. **Halo** adopts the SuiteUI
timeline's trim and gains slide: drag a layer bar's ends to trim its in and
out, drag its body to slide the layer and all its keys in time. SuiteKernel's
`Keys` gets the two rules both need (`ColorKeyRules` for colour tracks next to
`KeyRules` for number tracks, and `SpanRules.slide`), and SuiteUI's
`TimelineStrip` gets the slide gesture beside its trim. Every action is a
catalog command: Flare's existing `color-key.*` and key commands, Halo's new
`layer.slide` and `layer.trim`.
**Line:** `line:suiteui` · **Wave:** XK4 (`waves.md`, the beta gaps) · **Lead branch:** `lead/timeline-keys`
**Beta:** captain, 2026-10-21 (beta gaps cluster C13). Labels `beta` and `p1` when filed.

**Covers:** `2026-10-21-beta-gaps-combined.md` C13; Flare audit B3 and the
under-specified "the recording ring is a lie" note; Halo audit B3 and
under-specified 7 (trim was orphaned between key-editing and core-loop);
feature map E14 (Flare adopter) and the slide and trim part of S16; RJ-F13
(re-pointed) and RJ-H51 (new).

**Depends on:** adopt-kernel-easing **AE-flare** and **AE-halo** (planned):
they fold Flare's `KeyState`/`EasingEditing` and Halo's `HaloKeyRules` into
SuiteKernel's `Keys`. Read that packet first: this one adds rules next to
`KeyRules`, never a third copy beside Halo's or Flare's, and its app slices
wait on those two. The stage-matches-export fix (creative-core branch
`fix/flare-sampler`, creative-apps `fix/flare-stage-matches-export`, in
flight; Flare audit B2) makes the stage and the PNG sample colour tracks;
until it merges a keyed fill animates in the Lottie but not on the stage, so
TK-flare's journey and RJ-F13 wait on it (TK-7 carries no stage code). The
pinned FlareCore already stores `colorTracks` (`fill.<i>`, `stroke.<i>`) and
`strokeWidth.<i>` number tracks, and Flare's catalog already runs
`color-key.set`, `color-key.remove` and `color-key.move`.

**Hand-offs** (cross-line; the lead checks each before its slice starts):
- **TK-u, TK-flare:** `FlareInspectorFill.swift` is flare/gradient-fill FG-a's
  and stroke-style FK-a's; `Live/LiveProperties+Paint.swift` is Flare's paint
  owner's; start after their last task on them.
- **TK-u:** `HaloTimelineView.swift` is halo/key-editing KE-a's and
  core-loop CL-probe's.

**Rule 20.** Keys and easing have one home, SuiteKernel `Keys`. Colour keys
use FlareCore's `ColorKeyframe` through `ColorKeyRules`; span slide is
`SpanRules.slide` over `KeyRules.moveKeys`; trim stays SuiteUI's
`TimelineEditing.trimmed`. Each app keeps one adapter (`FlareColorKeys+Kernel.swift`,
`HaloSpan+Kernel.swift`); neither writes key or span maths of its own.

**C4:** edits the `suite-kernel/kernel-keys.json` part (TK-1 names the two
new rule files). No new component.

**Clean-room.** Gestures from the HIG and the apps' blueprints. No task reads
another product's code.

Blueprint sections: flare.md (inspector, keys), halo.md (timeline), suiteui.md 2.

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| TK-a | SuiteKernel declares the colour key and span slide rules as stubs and Halo the slide and trim command specs, with every Model check written and disabled. | TK-1, TK-2 | MJ-TK | frame-rates:FR-a (shared app file) |
| TK-u | Flare's FILL and STROKE rows show key buttons and Halo's timeline bars trim and slide on the stubs, every control identified and within the render budget. | TK-3, TK-4 | FJ-TK, HJ-TK | TK-a; timeline and timeline-select-all (built: `TimelineStrip.swift`, `TimelineLaneInput.swift`) |
| TK-m | Colour keys toggle and sample on the kernel's rules, a slide moves a span and every key by the same clamped delta, and Halo's slide and trim are one undo step each through its catalog. | TK-5, TK-6 | MJ-TK, MJ-TK-halo | TK-a; adopt-kernel-easing:AE-halo; adjust-everywhere:AJ-halo (`HaloLayer.swift`); text-style:TS-halo (Halo's catalog and ledger); anchor-parenting:AN-halo (shared app file) |
| TK-flare | In Flare a key button keys fill colour, stroke colour and stroke width at the playhead, and with recording on a fill or stroke edit keys instead of changing every frame. | TK-7, TK-8 | FJ-TK, MJ-TK-flare | TK-m, TK-u; adopt-kernel-easing:AE-flare; the stage-matches-export fix (cross-line, for the journey) |
| TK-z | Halo's slide and trim run live end to end, RJ-H51 passes, the kernel part names its adopters, and the feature is built. | TK-9, TK-10 | HJ-TK, FJ-TK, MJ-TK | TK-m, TK-u, TK-flare; frame-rates:FR-a (shared app file) |

**Screen early.** TK-u puts Flare's key buttons and Halo's bar gestures on
screen on TK-a's stubs and waits on no slice of this feature but TK-a (and the
built timeline packets that own the strip's files), beside TK-m.

**Shared files.** `HaloLayer.swift` follows adjust-everywhere's AJ-halo and
Halo's catalog follows text-style's TS-halo on this line, so the three Halo
adopts land one after the other.

## Journey steps

Linux walks first (`MJ-TK`: `ColorKeyRulesTests`, `SpanRulesTests`;
`MJ-TK-halo`: `HaloSpanTests`; `MJ-TK-flare`: `FlareColorKeysTests`), then:
1. Flare: draw a rectangle, fill blue, click FILL's key button at frame 0, move to frame 30, pick orange: a second key; scrub to 15: the stage shows the mid colour; the button reads keyed at 0 and 30 (TK-3, TK-8; `FJ-TK`, `FlareFillKeyJourneyTests.testKeyFillColour`).
2. Halo: three text layers; drag the second bar's body 6 frames right and the third 12; drag the third's out end 12 frames left; each drag is one undo step; the keys moved with the bars (TK-4, TK-9; `HJ-TK`, `HaloSpanJourneyTests.testSlideAndTrimLayers`).

## Jobs

| job | closes or adds | run | check | fixture |
|---|---|---|---|---|
| RJ-F13 | closes (re-pointed to `suiteui/timeline-keys`; `needs` keep E14) | C | `Tests/RealJobs/flare/fill-colour-key/`: a rectangle, `color-key.set` fill blue at 0 and orange at 30 (fps 30), export Lottie and PNG frames 0, 15, 30 | a new scene |
| RJ-H51 | adds, closes with `suiteui/timeline-keys` | C | `Tests/RealJobs/halo/stagger-layers/`: `layer.slide` +6 on the second word and +12 on the third, `layer.trim` the third's out by −12, `render.frame` 18 | `input/three-words.halo` |

Traps and assertions. RJ-F13: the Lottie animates but the PNG frame 15 is
flat blue (the stage gap); frame 15's fill pixel is within 3 levels of the
blue-orange midpoint and the Lottie's `fl.c` has two keys. RJ-H51: a slide
moves the bar but leaves the keys, so the word pops in early; at frame 18 the
second word's opacity equals the original's at frame 12 within 1%, and the
third word's out point is 12 frames earlier. Mutations:
`SuiteKernel.SpanRules` (`.keysFollowClamp`), `HaloModel.HaloSpan+Kernel`
(`.keysSlideWithLayer`). RJ-F13 stays disabled with `waits_on: TK-7` and on
the stage fix; RJ-H51 is written by TK-9.

## Screens and states

`flare-inspector-fill-keyed` (FILL keyed here, STROKE animated, width static),
`halo-timeline-slide` (a bar mid-drag with its keys), `halo-timeline-trim`.

## Contract slice

```swift
// Sources/SuiteKernel/Keys/ColorKeyRules.swift (TK-1 stubs, TK-5 bodies). Foundation and FlareCore only.
public enum ColorKeyRules {
    public static func state(_ track: [ColorKeyframe], at frame: Int) -> KeyState
    /// Adds a key with `value` at `frame`, or removes the key there; `leaving` as KeyRules.toggleKey.
    public static func toggleKey(_ track: inout [ColorKeyframe], at frame: Int, value: Color, leaving: RemovePolicy) -> Bool
    public static func sample(_ track: [ColorKeyframe], at frame: Int) -> Color?
}
// Sources/SuiteKernel/Keys/SpanRules.swift (TK-1 stub, TK-5 body)
public enum SpanRules {
    /// The delta actually applied: `by`, clamped so `span` stays inside 0...lastFrame.
    public static func slide(_ span: inout ClosedRange<Int>, tracks: inout [String: [Keyframe]], by: Int,
                             lastFrame: Int) throws(KeyRefusal) -> Int
}
// Sources/SuiteUI/TimelineStrip.swift (TK-4): one new callback, default no-op
//   onSlide: @escaping @MainActor (ID, Int) -> Void = { _, _ in }      // frames moved since the last call
// Sources/HaloModel/HaloSpan+Kernel.swift (TK-2 specs, TK-6 bodies)
extension HaloProject {
    public struct SlideParams: Codable, Sendable { public var layer: String; public var by: Int; public var drag: String? }
    public struct TrimParams: Codable, Sendable { public var layer: String; public var edge: String; public var frame: Int; public var drag: String? }
    static var spanCommands: [CommandSpec<HaloProject>] { get }        // layer.slide, layer.trim
}
// Sources/FlareModel/FlareColorKeys+Kernel.swift (TK-7)
extension FlareWorkspace {
    public enum PaintKey: String, CaseIterable, Sendable { case fill, stroke, strokeWidth }
    public func keyState(_ k: PaintKey) -> KeyState                    // for the selected shape at the playhead
}
```

| id | title (undo step) | params | unavailable when |
|---|---|---|---|
| `layer.slide` (Halo) | Slide Layer | `{layer, by, drag?}` | no such layer; a locked layer |
| `layer.trim` (Halo) | Trim Layer | `{layer, edge: start or end, frame, drag?}` | no such layer; a locked layer |
| `color-key.set`, `color-key.remove`, `color-key.move` (Flare, existing) | Key Fill Colour / Remove Key / Move Keys | as today | as today, plus "Select one shape first." |

## Pseudocode

- **Colour key state.** Same frame rules as `KeyRules.state`: no keys is not
  animated, a key at the frame is keyed here, otherwise animated. Toggle at a
  keyed frame removes it (the last key leaves the property static with that
  colour, `.propertyGoesStatic`).
- **Recording.** Flare's recording ring on, or the property already
  animated: an edit writes a key at the playhead. Off and static: the edit sets
  the static value. This is the transform rows' rule, now for paint.
- **Slide.** `delta = clamp(by, -span.lowerBound, lastFrame - span.upperBound)`;
  move every key of the layer's tracks by `delta` with `KeyRules.moveKeys`
  (clamped to the comp), then shift the span. Children of a null layer keep
  their own spans; parenting is untouched.
- **Trim.** `TimelineEditing.trimmed` with the comp's last frame; keys stay
  where they are (a trimmed-away key still exists and comes back if the end is
  dragged out again).

## Tasks

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| TK-1 | – | **Checks first, then the stubs.** `ColorKeyRulesTests` and `SpanRulesTests` written, disabled by name; `ColorKeyRules` (state, toggle, sample over `[ColorKeyframe]`) and `SpanRules.slide` stubs; the keys part names them | `Sources/SuiteKernel/Keys/ColorKeyRules.swift`, `Sources/SuiteKernel/Keys/SpanRules.swift`, `Tests/SuiteKernelTests/ColorKeyRulesTests.swift`, `Tests/SuiteKernelTests/SpanRulesTests.swift`, `docs/c4/parts/creative-apps/suite-kernel/kernel-keys.json` | – | ~160, 5 |
| TK-2 | – | Halo's `layer.slide` and `layer.trim` specs in `HaloSpan+Kernel.swift` with real ids, schemas and availability, runs throwing `NotBuilt` (not yet in the catalog); `HaloSpanTests` written, disabled | `Sources/HaloModel/HaloSpan+Kernel.swift`, `Tests/HaloModelTests/HaloSpanTests.swift` | TK-1 | ~130, 2 |
| TK-3 | – | **Reachable first.** Flare's FILL colour, STROKE colour and STROKE width rows get `KeyframeButton`s (ids `flare.inspector.key.fill`, `.stroke`, `.stroke-width`) calling `color-key.set`/`color-key.remove` and the number key commands at the playhead; `FlareFillKeyJourneyTests` written, skipped until TK-7 | `Sources/FlareApp/FlareInspectorFill.swift`, `UITests/FlareJourneyTests+FillKeys.swift` | TK-1 | ~150, 2 |
| TK-4 | – | SuiteUI `TimelineStrip` gains `onSlide(ID, Int)` (drag a span's body; Shift snaps to the playhead) beside `onTrim`; Halo's timeline passes both to `layer.slide` and `layer.trim` (unavailable on the stubs with "Slide and trim arrive with TK-6."); render budget test; `HaloSpanJourneyTests` written, skipped until TK-8 | `Sources/SuiteUI/TimelineStrip.swift`, `Sources/SuiteUI/TimelineLaneInput.swift`, `Sources/HaloApp/HaloTimelineView.swift`, `UITests/HaloJourneyTests+Span.swift`, `Tests/AppSnapshotTests/RenderBudgetTimelineSpanTests.swift` | TK-2 | ~230, 5 |
| TK-5 | – | `ColorKeyRules` and `SpanRules` bodies: colour state and toggle by `KeyRules`' frame rules, sampling through FlareCore's colour easing; slide clamps the delta so the span stays in 0...lastFrame and moves every key with `KeyRules.moveKeys`; turns on both suites | `Sources/SuiteKernel/Keys/ColorKeyRules.swift`, `Sources/SuiteKernel/Keys/SpanRules.swift`, `Tests/SuiteKernelTests/ColorKeyRulesTests.swift`, `Tests/SuiteKernelTests/SpanRulesTests.swift`, `Tests/mutations/SuiteKernel.ColorKeyRules.json`, `Tests/mutations/SuiteKernel.SpanRules.json` | TK-1 | ~170, 6 |
| TK-6 | – | `HaloSpan+Kernel` bodies: `layer.slide` (span and keys by `SpanRules.slide`) and `layer.trim` (SuiteUI's `trimmed` rule, keys unchanged), one undo step each, a drag under one token one step; the catalog appends both; ids in the ledger; turns on `HaloSpanTests` | `Sources/HaloModel/HaloSpan+Kernel.swift`, `Sources/HaloModel/HaloLayer.swift`, `Sources/HaloModel/HaloCommandCatalog.swift`, `Tests/command-ids/halo.txt`, `Tests/HaloModelTests/HaloSpanTests.swift`, `Tests/mutations/HaloModel.HaloSpan+Kernel.json` | TK-2, TK-5 | ~200, 6 |
| TK-7 | – | **Test first.** `FlareColorKeysTests`; `FlareColorKeys+Kernel.swift` gives each row's key state from `ColorKeyRules` and `KeyRules`; a fill, stroke colour or stroke width edit with recording on calls the key command at the playhead, with recording off sets the static value only when the property isn't animated (else it keys, as transform rows do); RJ-F13 re-pointed, enabled once the stage fix merges | `Tests/FlareModelTests/FlareColorKeysTests.swift`, `Sources/FlareModel/FlareColorKeys+Kernel.swift`, `Sources/FlareModel/Live/LiveProperties+Paint.swift`, `Tests/mutations/FlareModel.FlareColorKeys+Kernel.json`, `Tests/RealJobs/flare/fill-colour-key/fill-colour-key.jobs.json` | TK-5 | ~240, 5 |
| TK-8 | – | The buttons on live; `FlareFillKeyJourneyTests` on (key blue at 0, orange at 30, scrub, the stage shows the mid colour) | `Sources/FlareApp/FlareWindow+Inspector.swift`, `UITests/FlareJourneyTests+FillKeys.swift` | TK-7, TK-3 | ~120, 2 |
| TK-9 | – | Halo's timeline on live: a bar drag runs `layer.slide` under one drag token, an end drag `layer.trim`; `HaloSpanJourneyTests` on; RJ-H51's job folder | `Sources/HaloApp/HaloWindow+Span.swift`, `UITests/HaloJourneyTests+Span.swift`, `Tests/RealJobs/halo/stagger-layers/stagger-layers.jobs.json`, `Tests/RealJobs/halo/stagger-layers/input/three-words.halo` | TK-6, TK-4 | ~160, 4 |
| TK-10 | – | The keys part names Flare and Halo; `status: built`; `feature-done` | `docs/c4/parts/creative-apps/suite-kernel/kernel-keys.json`, `docs/blueprints/suiteui/features/timeline-keys.wave.json` | TK-9, TK-8 | ~25, 2 |

## Build waves

- Wave 1: TK-1. Independent in this wave: TK-1 alone.
- Wave 2: TK-2, TK-3, TK-5. Independent in this wave: all.
- Wave 3: TK-4, TK-6, TK-7. Independent in this wave: all.
- Wave 4: TK-8, TK-9. Independent in this wave: both.
- Wave 5: TK-10. Independent in this wave: TK-10 alone.

Longest chain: TK-1 → TK-2 → TK-6 → TK-9 → TK-10 (5). Chain of 5: the stubs before the rules, the rules before an app's adapter, the adapter before its window, and the window before the done task.

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| TK-1 | the suites compile, disabled by name; `KernelShapeTests` (unchanged) | a signature an adopter calls is missing | – (stubs) |
| TK-2 | compiles, disabled by name | a spec the timeline calls is missing | – (stubs) |
| TK-3 | the three buttons exist with their ids and show the not-animated state on a static shape | a row has no button, or a button has no id | – (view; render budget row) |
| TK-4 | `RenderBudgetTimelineSpanTests.slideDragInThreeBodies`; a body drag reports one delta per frame crossed, an end drag still trims | a body drag trims, or an end drag slides | – (view; render budget row) |
| TK-5 | `ColorKeyRulesTests`: toggling at a keyed frame removes the key; two keys blue to orange sample to the mid colour at the middle frame with linear easing; `SpanRulesTests`: a slide of +6 moves the span and every key by 6; past the end it clamps and keys move by the clamped delta | a key survives a remove, a sample is off, or keys and span move apart | `SuiteKernel.ColorKeyRules`: toggle adds a duplicate at a keyed frame → `.toggleRemovesKey`. `SuiteKernel.SpanRules`: keys moved by the unclamped delta → `.keysFollowClamp`; lower bound clamp skipped → `.staysInComp` |
| TK-6 | `HaloSpanTests`: slide +6 moves in, out and every key by 6, one step; a 30-sample drag is one step; trim moves only the edge; a null layer's children keep their offsets | a slide leaves keys behind, or a trim moves keys | `HaloModel.HaloSpan+Kernel`: keys not moved on slide → `.keysSlideWithLayer`; drag token ignored → `.dragIsOneStep` |
| TK-7 | `FlareColorKeysTests`: recording on, a fill change at frame 30 adds a key there and keeps frame 0's; recording off on an animated fill keys instead of flattening; the button's state follows the playhead | an edit with recording on changes every frame, or a static edit flattens an animation | `FlareModel.FlareColorKeys+Kernel`: recording flag ignored → `.recordingKeys`; animated check skipped → `.animatedNeverFlattens` |
| TK-8 | `FJ-TK` | the stage shows a flat fill while the timeline shows keys | – (window wiring) |
| TK-9 | `HJ-TK`; RJ-H51 on Linux | a drag makes many undo steps, or keys stay behind | – (window wiring; TK-6's plan covers the logic) |
| TK-10 | `scripts/waves render --dry-run`; `scripts/c4-assemble --check` | status not built | – |

## Quality tests

| quality row | budget | test |
|---|---|---|
| render: Halo bar slide, 120-sample drag | ≤ 3 window bodies; one undo step | `RenderBudgetTimelineSpanTests.slideDragInThreeBodies` |
| render: Flare key button click | ≤ 2 window bodies | `RenderBudgetTimelineSpanTests.flareKeyClick` |
| one gesture, one step | a slide, a trim, a key click | `HaloSpanTests`, `FlareColorKeysTests` |
| no dead controls | key buttons and bar gestures are catalog commands | `CommandPathTests` |
| keyboard parity | Flare: ⌥K keys the focused row; Halo: ⌥← and ⌥→ slide the selected layer one frame | `FlareFillKeyJourneyTests`, `HaloSpanJourneyTests` |
| one keys home | no key or span maths outside SuiteKernel `Keys` | `scripts/check-dup-logic` (Keyframe, Easing stems) |

## Done check

Per slice (rules 6, 15, 17, 21, 22): TK-a and TK-m green on Linux with
`Mutate:` scores clean; TK-u, TK-flare and TK-z through the feel gate (`mouse`,
`taste`: key a fill colour, slide and trim three Halo layers) with their
`Mac-Finish:` lines; RJ-H51 green at TK-z's merged-done, RJ-F13 once the stage
fix has merged. Then `Belt-Contact-Sheet:`.
