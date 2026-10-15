# Feature packet: text-layers

**Feature:** Text layers. A text layer's words, size and color are edited in
the inspector's TEXT section, each committed change one named undo step; the
CoreText rasterizer replaces W0's stub so Render Frame and Render… draw text,
and the stored line box is the box the pixels fill.
**Line:** `line:halo` · **Wave:** W2 (`waves.md`) · **Lead branch:** `lead/text-layers`

**Covers:** #430. It closes through TX-7, the `feature-done` PR. The other
tasks say "Part of #430" in their PR bodies.

**Depends on:** the layer-keys feature issue (the inspector that hosts the
TEXT slot), the viewer-playback feature issue (the canvas and the renderer
that draw text), the history-files feature issue (undo, files, the Undo
name) and #333 (QH-4: `project.yml` compiles only
`UITests/HaloJourneyTests.swift` today, so `UITests/HaloJourneyTests+Text.swift`
is not even compiled until it lands). The feature issue is filed once all
four are closed, and its one `Depends on:` line names whichever closed last.
Only TX-7 (the journey) needs #333; the issue waits for it anyway so the lead
can build every task. No creative-core issue is needed: scaled and rotated
text is drawn with CoreRaster's `resized` and `rotated(degrees:)`, then
`composite` at an offset, inside viewer-playback's renderer.

**What this feature does not touch.** Text drawing belongs to
viewer-playback (W1). It draws text items as vectors in
`HaloViewerCanvas.swift` and as pixels in `LiveFrameRendering` through
`TextRasterizing` (tested there with `FakeTextRasterizer`). This feature does
NOT edit the renderer or the canvas. It adds the CoreText rasterizer
(`Sources/HaloApp/HaloTextRasterizer.swift`, replacing W0's stub, which
`HaloLaunch` already installs as `services.text`), the text edits and the
TEXT inspector. If a test here shows the canvas or the renderer drawing text
wrong, the lead files a `line:halo` bug naming that file and does not fix it
in this feature.

Blueprint sections it builds on: 2 (one undo step, rendering and feel,
commands and availability, launch arguments, fixtures), 4 (H-J22), 5
(`HaloTextContent`, `TextRasterizing`, `HaloServices.text`, the
`HaloTextEdits.swift` row of the workspace methods), 6 (Inspector, TEXT; the
Text command area), 7.2 (audit), 7.4 (HF-10), 8.3 (text-layers' owned files).
The packet wins over the blueprint and over #430's body where they differ;
the differences are listed under "Review notes folded in".

**Building blind.** TX-4 to TX-7 are in `Sources/HaloApp/`,
`Tests/AppSnapshotTests/` and `UITests/`, which the Linux gate never
compiles. Copy the imports and shape of a HaloApp view that builds
(`HaloEasingInspector.swift` for an inspector section, `HaloWindow+Keys.swift`
for a router file), check every SwiftUI, CoreText and CoreGraphics API with
the `apple-docs` MCP before use and say so in the PR, keep views dumb (the
field's draft is view-local `@State`; nothing assigns Model state), and keep
every decision (emptiness, clamping, measuring, help text, the size row's
value text) in HaloModel tasks TX-1 to TX-3.

**Shared-file rule.** This feature owns only the Halo files in its task
rows. It never edits `Sources/SuiteUI/**`, `project.yml`,
`UITests/Journey*.swift`, `UITests/Journey+Input.swift`,
`Tests/AppSnapshotTests/AppSnapshotTests.swift` (it calls the shared
`snapshot(_:name:scheme:)` helper as it is), `docs/c4/model.json` or
`docs/design.md`. Its only shared-doc edits are TX-7's two lines in the
Halo plan (`docs/blueprints/halo/c4-planned.json`,
`docs/blueprints/halo/waves.py`). It does not own `HaloLayerInspector.swift` (layer-keys made
the TEXT slot and keeps it), `HaloViewerCanvas.swift`,
`Live/LiveFrameRendering.swift`, `HaloProject.swift`, `HaloLayer.swift`,
`HaloLaunch.swift` or any menu file. Its W2 siblings are easing and
render-out; it shares no file with them, and its tests go in new files
rather than in W0's `HaloCommandTests.swift`.

## Journey steps

1. **H-J22** `testTextLayer` (new, `UITests/HaloJourneyTests+Text.swift`,
   class `HaloTextJourneyTests`) on `-HaloSample empty` (every service it
   reads is live by W2, and `services.text` is `HaloTextRasterizer` in both
   modes, so it starts live): Layer > New > Text; the TEXT section shows
   with "Text" in the field and the size row's value "72 px"; type "Hello"
   in the TEXT field and press Return; open Edit: "Undo Edit Text"; type
   `96` into the size row and Return: its value "96 px", Edit reads
   "Undo Change Text Size"; select all in the field, delete, Return: the
   caption "Enter some text." shows under the field, the field reads
   "Hello" again and Edit still reads "Undo Change Text Size" (a refusal is
   not a step); `halo.viewer.artboard`'s value reads "Frame 0: Text 1: Hello"
   throughout after the first commit. (TX-7)

The blueprint's H-J22 asserts "Undo Edit Text" after all four steps; after
size 96 the top step is "Change Text Size", so the journey reads the Edit
menu after each commit instead. The Model half runs on Linux first:
`HaloTextLayerTests` (the same steps on `HaloProject(services: .fake)` with
`empty`) and `HaloTextAvailabilityTests`.

## Screens and states

| Screen | Empty | Error | Loading |
|---|---|---|---|
| Inspector, TEXT | no text layer selected: no TEXT section (the view draws nothing when `selectedText` is nil); the text commands are disabled with "Select a text layer first." (no composition: "Create a composition first.") | an empty or all-blank commit keeps the old string, sets the refusal "Enter some text." on `halo.inspector.text.string`, shown in `SuiteFont.caption` under the field, and the field shows the stored string again | none (measuring is synchronous and cheap) |
| Viewer | a new text layer reads "Text" at 72 in the box W0 measured at creation (FD-10; the estimate only when `services.text` is nil; see Review notes) | none (drawing never fails) | none |
| Rendered frame | `services.text` nil (Linux tests only): text layers skipped and counted, as viewer-playback's renderer already does | a rasterizer throw is the renderer's failure path (viewer-playback, render-out) | none |

## Contract slice

`HaloTextContent`, `TextRasterizing`, `HaloServices.text` and
`HaloEditError.emptyText` exist from W0 (blueprint 5.1, 5.2, 5.4). This
feature adds:

```swift
// HaloTextEdits.swift (TX-1); the color members in HaloTextEdits+Color.swift (TX-2)
extension HaloTextContent {
    public static let fontSizeRange: ClosedRange<Double> = 1...1000   // composition px; writes clamp
    public var sizeText: String { get }                                // "96 px": the size row's value
}
extension HaloLayerColor {
    public init(bytes red: UInt8, _ green: UInt8, _ blue: UInt8)     // the color row's 8-bit sRGB
    public var bytes: (red: UInt8, green: UInt8, blue: UInt8) { get } // rounded, clamped
}
extension HaloProject {
    public var selectedText: HaloTextContent? { get }       // the selected text layer's (default if nil); nil otherwise
    public var selectedLayerColor: HaloLayerColor? { get }  // nil for no layer or a null
    public mutating func setText(_ string: String)          // "Edit Text", control halo.inspector.text.string
    public mutating func setFontSize(_ size: Double)        // "Change Text Size", coalesced on "<layer id>.fontSize"
    public mutating func endTextSizeScrub()                 // endCoalescing()
    public mutating func setLayerColor(_ color: HaloLayerColor)  // "Change Color", coalesced on "<layer id>.color"
}

// HaloAvailability+Text.swift (TX-3): the text area's commands (W0's
// HaloCommand cases for the TEXT field, size and color) answer state only.

// HaloApp (TX-4): replaces W0's stub, same spelling HaloLaunch uses.
struct HaloTextRasterizer: TextRasterizing { init() }
```

## Pseudocode

```
measured(c, by r: (any TextRasterizing)?):      # TX-1, private
  guard let r else { return HaloTextContent(string: c.string, fontSize: c.fontSize) }  # the estimate
  let box = r.measure(c)
  return HaloTextContent(string: c.string, fontSize: c.fontSize, width: box.width, height: box.height)

setText(s):
  let r = services.text                          # read before edit: no overlapping access to self
  edit("Edit Text", control: "halo.inspector.text.string") { doc in
    guard let (ci, li) = doc.selectedLayerIndices else throw doc.hasComposition ? .noLayerSelected : .noComposition
    guard doc.compositions[ci].layers[li].kind == .text else return          # no change, no step
    let line = s.replacing newlines with " "                                  # one-line text
    guard !line.allSatisfy(\.isWhitespace) else throw .emptyText
    var c = doc.compositions[ci].layers[li].text ?? HaloTextContent()
    c.string = line
    doc.compositions[ci].layers[li].text = measured(c, by: r)
  }                                               # same string: copy == document, no step

setFontSize(size):
  guard size.isFinite else return                 # nothing to do, no refusal
  edit("Change Text Size", control: "halo.inspector.text.size", coalesceKey: "\(layerID).fontSize") {
    same guards; c.fontSize = size.clamped(to: fontSizeRange); text = measured(c, by: r) }

setLayerColor(color):                             # TX-2; text, solid and shape
  guard every component isFinite else return
  edit("Change Color", control: "halo.inspector.text.color", coalesceKey: "\(layerID).color") {
    same guards; null → return; layer.color = components clamped to 0...1 }

textHelp(c):                                      # TX-3
  no composition → "Create a composition first."
  selected layer missing or not .text → "Select a text layer first."
  else nil

HaloTextRasterizer.measure(t):                    # TX-4, CoreText
  line = CTLine of t.string in the system UI font at t.fontSize
  (width, ascent, descent) = CTLineGetTypographicBounds(line)
  return HaloLayerRect(x: 0, y: 0, width: ceil(width), height: ceil(ascent + descent))
HaloTextRasterizer.rasterize(t, color):
  box = measure(t); a CGContext of box's size, linear sRGB, float, premultiplied
  draw the line with its baseline at descent from the bottom (height − descent from the top:
  viewer-playback's pinned baseline rule), in the color converted to linear
  copy rows top first into a PixelBuffer (linear light, premultiplied, (0,0) = box top left)
```

## Tasks

Every task is one PR to `dev`: at most 400 changed lines and 15 files, label
`fast-lane`, body lines `Belt-Lead:`, `Feature: text-layers`, `Fast-Check:
pass`, `Head:`. TX-7 also carries `feature-done` and `Closes #430`.

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| TX-1 | #430 (part) | `setText`, `setFontSize`, `endTextSizeScrub`, `selectedText`, `fontSizeRange`, `sizeText`; both edits store the measured box from `services.text.measure` (the estimate when nil); one named step per commit, scrubs coalesced | `Sources/HaloModel/HaloTextEdits.swift`, `Tests/HaloModelTests/HaloTextLayerTests.swift` | – | ~260 |
| TX-2 | #430 (part) | `setLayerColor` ("Change Color") for text, solid and shape; `selectedLayerColor`; `HaloLayerColor(bytes:)` and `bytes` | `Sources/HaloModel/HaloTextEdits+Color.swift`, `Tests/HaloModelTests/HaloTextColorTests.swift` | – | ~140 |
| TX-3 | #430 (part) | `HaloAvailability+Text.swift` replaced whole: the text area's commands answer state only ("Create a composition first.", "Select a text layer first.") | `Sources/HaloModel/Availability/HaloAvailability+Text.swift`, `Tests/HaloModelTests/HaloTextAvailabilityTests.swift` | – | ~110 |
| TX-4 | #430 (part) | `HaloTextRasterizer` on CoreText replaces W0's stub: `measure` (typographic line box) and `rasterize` (linear light, premultiplied, box-sized) | `Sources/HaloApp/HaloTextRasterizer.swift`, `Tests/AppSnapshotTests/HaloTextRasterizerTests.swift` | – | ~260 |
| TX-5 | #430 (part) | HF-10 macOS half with CoreText: the ink lies inside the stored box, and the viewer's drawing of a text layer matches `render` of it as HF-1 compares solids (the baseline rule itself is pinned and tested by viewer-playback's VP-9) | `Tests/AppSnapshotTests/HaloTextFidelityTests.swift` | TX-1, TX-4 | ~200 |
| TX-6 | #430 (part) | App: `HaloTextInspector` (TEXT header; system `TextField` with a view-local draft committed on Return and focus loss; `InspectorSliderRow` for size with `sizeText` as its accessibility value; `InspectorColorRow(_:hex:onChange:)`; the refusal caption), W0's slot `init(model:perform:)` replaced whole, acting only through `perform` with FD-11's `.setText(String)`, `.setFontSize(Double)`, `.endTextSizeScrub` and `.setLayerColor(HaloLayerColor)`; `HaloWindow+Text` routes those cases to the Model methods; snapshots | `Sources/HaloApp/HaloTextInspector.swift`, `Sources/HaloApp/HaloWindow+Text.swift`, `Tests/AppSnapshotTests/HaloTextLayerSnapshots.swift` | TX-1, TX-2, TX-3, TX-4 | ~300 |
| TX-7 | #430 (closes, `feature-done`) | Journey H-J22 on `-HaloSample empty`; the feature's shared-doc edits: `Sources/HaloModel/HaloTextEdits+Color.swift` added to `halo-text`'s paths in the planned C4 model, with "and the layer color" in its description, and `M+"HaloTextEdits+Color.swift"` added to text-layers' owns in `waves.py` | `UITests/HaloJourneyTests+Text.swift`, `docs/blueprints/halo/c4-planned.json`, `docs/blueprints/halo/waves.py` | TX-5, TX-6, #333 | ~155 |

TX-1 to TX-4 share no file and start together. TX-2 keeps its color edit in
its own `HaloTextEdits+Color.swift`, so it no longer waits on TX-1's
`HaloTextEdits.swift`: it reuses only W0's `edit` and Layer > New > Text.
TX-3 reads only the composition and the selected layer's kind, which W0
has. TX-5 calls TX-1's `setText` and `setFontSize` with TX-4's rasterizer.
TX-6 calls TX-1's and TX-2's methods (`sizeText`, `selectedText`,
`selectedLayerColor`, `bytes`), needs TX-3's help to enable its controls and
TX-4's `measure` for the box its snapshot shows. TX-7 is the `feature-done`
task, so it goes last, after TX-5 and TX-6, and it carries the feature's
only shared-doc edits. TX-3 and TX-6 each replace a W0
stub whole (`HaloAvailability+Text.swift`; `HaloTextInspector.swift` and
`HaloWindow+Text.swift`), keeping the function and init spellings W0's
router and layer-keys' TEXT slot call.

## Build waves

- Wave 1: TX-1, TX-2, TX-3, TX-4. Independent in this wave: all four.
- Wave 2: TX-5, TX-6. Independent in this wave: both.
- Wave 3: TX-7 (final, `feature-done`, shared docs; also waits on #333).

Longest chain: TX-1 → TX-6 → TX-7 (3); TX-2, TX-3 or TX-4 → TX-6 → TX-7 is
the same length. TX-7, the final task, owns the shared-doc edits (the
planned C4 path and description, and the `waves.py` owns line; see Review
notes), so no build task chains through a shared file.

## Acceptance test per task

| id | test | fails when |
|---|---|---|
| TX-1 | `HaloTextLayerTests` on `empty`, `.fake` services (`FakeTextRasterizer`): Layer > New > Text gives "Text 1", `selectedText` "Text" at 72; `setText("Hello")` stores width 216 and height 72 (the fake's `measure`), one step "Edit Text", `viewerSummary` "Frame 0: Text 1: Hello"; `setFontSize(96)` stores 288 × 96 and `bounds(in:)` is (816, 492, 288, 96); `setText("")`, `"   "` and `"\n"` each set refusal `.emptyText` on `halo.inspector.text.string` and leave "Hello" with no new step; `setText("Hello")` again records nothing; "A\nB" is stored "A B"; three `setFontSize` calls then `endTextSizeScrub` are one step and the fourth a new one; `setFontSize(0)` stores 1, `5000` stores 1000, `.nan` changes nothing; on a fresh layer, `setText("Hello")`, `setFontSize(96)`, then two `undo()` bring back "Text" at 72 and one `redo()` "Hello" at 72. With a test-only `WideMeasure` rasterizer in the test file (width 50 per character, height 1.25 × size) "Hello" at 72 stores 250 × 90 (HF-10 Linux half: the stored box equals `measure`); with `services.text = nil` it stores the estimate 216 × 72. After `fileData()`, `services.files.decode` and `finishOpen(.success)`, the layer reads "Hello", 96, 288 × 96. `LiveFrameRendering().render` of frame 0 at 1920 × 1080 with `FakeTextRasterizer` has the layer color at (960, 540) and nothing at (810, 540) | the box is the estimate while a rasterizer is set, a commit records zero or two steps, a refusal changes the text, each call of one scrub records its own step, or text, size or box is lost in a file |
| TX-2 | `HaloTextColorTests`: on the text layer `setLayerColor(0.2, 0.4, 0.6)` records one "Change Color" and `selectedLayerColor` reads it; two calls in a row are one step; on `keyed`'s Ball (solid) and on a shape it works; on `three-layers`' Rig (null) nothing changes and nothing records; `(1.5, -1, 0.5)` stores (1, 0, 0.5); a NaN component changes nothing; `HaloLayerColor(bytes: 51, 102, 153)` equals (0.2, 0.4, 0.6) and `.bytes` of (0.2, 0.4, 0.6) is (51, 102, 153) | a color edit isn't one named step, a null gets a color, or an out-of-range or NaN component is stored |
| TX-3 | `HaloTextAvailabilityTests` on `.fake` and `.live`: `HaloProject()` with no composition: each text command reads "Create a composition first."; `empty` with no layer, then with Solid 1 selected: "Select a text layer first."; with Text 1 selected: nil for all three; `three-layers` with Title selected: nil; and no text command reads "Not built yet" | a text control is enabled with nothing to edit, or stays disabled on a text layer |
| TX-4 | `HaloTextRasterizerTests` (macOS): `measure` of "Hello" at 96 has x 0, y 0, whole-number width and height, height ≥ 96 and < 160; width grows from "Hello" to "Hello Halo"; `rasterize` returns a buffer exactly the box's size; "Hello" in white has ink (alpha > 0.5) in both its left and right quarters; a covered pixel of sRGB (1, 0.5, 0) reads linear (1, 0.214, 0, 1) within 1/255, and a half-covered edge pixel's color channels are no greater than its alpha (premultiplied); "Wj", "Ågy" and "—" at 12, 96 and 400: `CTLineGetImageBounds` lies inside `measure`'s box within 1 px | the box is fractional or off-origin, the buffer is mis-sized, the text is clipped or offset, or pixels come out gamma-encoded or unpremultiplied |
| TX-5 | `HaloTextFidelityTests` (macOS) on `empty` plus a black solid, a white text layer "Hello" at 96 via `setText` and `setFontSize` with `HaloTextRasterizer`: the rendered frame's ink bounding box lies inside the stored box at full size within 1 px (QB-V4); the viewer's canvas (the shared snapshot host, linear light) against `services.rendering.render(_:width:height:text:)` at 1920 × 1080: channel ≤ 2/255 on all but ≤ 0.5% of pixels, upright and with Rotation keyed to 30. Both sides follow viewer-playback's pinned baseline rule (line box top-left at `bounds.origin`, first baseline at `bounds.y + ascent`, the rasterizer's baseline at `height − descent`), so a correct CoreText rasterizer passes; if the viewer-vs-render half fails, the lead files a `line:halo` bug on viewer-playback's `HaloViewerCanvas.swift` and does not fix it here | ink lands outside the box the viewer and hit test use, or the viewer and the render disagree |
| TX-6 | Snapshots in `HaloTextLayerSnapshots`: `halo-text-layer-light/dark.png` (the viewer showing "Hello" at 96 and the TEXT section: field, "96 px" bar, color row); `halo-text-refused-light/dark.png` (the caption "Enter some text." under the field holding "Hello"). The macOS build on `dev` compiles both files | the TEXT section is missing, shows for a non-text layer, or has no refusal caption |
| TX-7 | H-J22 above on the `dev` CI run; `python3 docs/blueprints/halo/waves.py check docs/blueprints/halo/c4-planned.json` passes with `HaloTextEdits+Color.swift` owned once | any step's assert, or the color file has no planned C4 owner |

## Quality tests

| quality row | budget | test |
|---|---|---|
| HF-10 text box (QB-V4) | stored box equals `measure`; ink inside the box ≤ 1 px at full size; viewer vs render as HF-1 (channel ≤ 2/255, ≤ 0.5% of pixels) | `HaloTextLayerTests.storedBoxEqualsMeasure` (TX-1, Linux); `HaloTextFidelityTests` (TX-5, macOS) |
| QB-F3 one committed edit, one step | "Edit Text", "Change Text Size" (coalesced per scrub), "Change Color"; typing and refusals record nothing | `HaloTextLayerTests.eachCommitIsOneNamedStep` (TX-1), `HaloTextColorTests` (TX-2), H-J22 (TX-7) |
| QB-F1 no dead controls | each text command enabled or disabled with help | `HaloTextAvailabilityTests` (TX-3); W0's `HaloCommandTests` stays green |
| QB-F2 immediate feedback | the refusal shows under the field in the same update | H-J22 (TX-7), `halo-text-refused-*` (TX-6) |
| Audit, every check | no `halo` count over `UITests/audit-baseline.json` | `audit-halo-*.json` on the `feature-done` run: the field is labelled "Text", every control carries `halo.inspector.text.*` through `.haloControl` |

No HB row is new: a text edit is `edit` plus one `measure`, inside HB-9.
The baselines are lowered by CI's `Audit lower` job, never by hand; TX-6's
and TX-7's PR bodies state the counts they expect (unchanged).

## Done check

- **Journeys green:** the macOS run on `dev` triggered by TX-7's
  `feature-done` PR is green, with H-J22 passing and every other Halo and
  app journey unchanged (H-J13 runs on `keyed`, which has no text layer).
- **Audit zero new:** no `halo` count over `UITests/audit-baseline.json`.
- **Contact sheet:** the lead comments on the feature issue with
  `Belt-Contact-Sheet: <run link>`, one line per H-J22 step and the audit
  counts. Expected new shots: `halo-text-*` from the journey, and the
  snapshots `halo-text-layer-*` and `halo-text-refused-*`; nothing else
  changes.

## Review notes folded in

From the review of the blueprint PR (#767) and the brief, where they change
this feature:

- **Text drawing has one owner, and it isn't this feature.** viewer-playback
  (W1) draws text items as vectors in `HaloViewerCanvas.swift` and as pixels
  in `LiveFrameRendering` through `TextRasterizing` (scaled or rotated text
  via CoreRaster `resized`, `rotated(degrees:)`, then `composite` at an
  offset). This feature adds only the CoreText rasterizer, the edits and the
  inspector. #430's body owns `FrameRenderer.swift` and asks for "a rendered
  frame with a fake rasterizer has the text's bounds filled"; that file is
  not ours, so TX-1 only asserts the existing renderer's output.
- **#430's body vs this packet.** Its `HaloTextLayer.swift` is
  `HaloTextEdits.swift`; `HaloLayer.swift`'s text fields came in W0; the
  journey goes in `UITests/HaloJourneyTests+Text.swift`, not
  `HaloJourneyTests.swift`; `open(_:)` is history-files' `finishOpen(_:)`;
  its `Depends on: #38, #40, #209` becomes the feature line above. The
  snapshot names `halo-text-layer-light/dark.png` are kept.
- **Undo name in H-J22.** The Edit menu is read after each commit (see
  Journey steps), since the blueprint's single "Undo Edit Text" assert can't
  hold after the size change.
- **Size and color rules the blueprint left open.** Size clamps to
  1...1000 px (as `HaloProperty.range` clamps, never refuses); a NaN size or
  color component is ignored, not refused (no `HaloEditError` case fits and
  the controls never send one). A null takes no color. Consecutive color
  picks coalesce on `<layer id>.color` because the system color panel sends
  a stream with no end event.
- **Fresh layers are measured by W0.** The blueprint left `newLayer(.text)`
  storing the 0.6 em estimate, so an unedited text layer's ink could overrun
  its box. Foundation's FD-10 (it owns `HaloProject.swift`) stores the box
  from `services.text?.measure` when Layer > New > Text runs (the estimate
  only when `services.text` is nil), so every text layer the app makes
  starts measured. Fixtures still carry the estimate; HF-10's tests use
  layers made or edited through the Model.
- **The baseline rule is viewer-playback's, and pinned.** TX-5 used to
  rely on a baseline rule no file of its own set. viewer-playback now pins
  it (VP-5, VP-8) and tests it with a test rasterizer box (VP-9): a text
  item's line box top-left is `bounds.origin`, the canvas draws resolved
  `Text` with its first baseline at `bounds.y + ascent` of the font measured
  by the same rule the rasterizer uses (`measure` height = ascent + descent;
  baseline at `height − descent`). TX-4's rasterizer follows it, and TX-5
  only checks CoreText ink inside the box and viewer against render with
  CoreText. A failure there is a bug the lead files on viewer-playback's
  canvas, not a fix in this feature.
- **The TEXT slot acts through `perform`.** `HaloTextInspector` has W0's
  one initializer `init(model:perform:)`; it sends FD-11's text cases and
  takes no closures.
- **C4.** TX-2's new `HaloTextEdits+Color.swift` is covered today by
  `docs/c4/model.json`'s `Sources/HaloModel/` folder path, so the C4 lint
  passes as is. The Halo plan lists HaloModel files one by one, and its
  `halo-text` component names only `HaloTextEdits.swift` ("string and
  size"). TX-7 adds the color file to `halo-text`'s paths in
  `c4-planned.json`, folds "and the layer color" into its description, and
  adds the file to text-layers' owns in `waves.py`, so `waves.py check`
  finds one owner.
