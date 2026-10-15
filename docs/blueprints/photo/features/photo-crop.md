# Feature packet: photo-crop

**Feature:** PV-3, crop precision (#544). Type the pending crop's X, Y, W and
H; lock its aspect to Free, Original, 1:1, 3:2, 4:3 or 16:9 with a portrait
swap; the crop drag keeps the lock. Also the two perf journeys blueprint 7.1
gives PV-0 (PJ-P1, PJ-P2), since they need a second journey file and the
crop drag is one of their series.
**Line:** `line:photo` · **Wave:** 1 (`waves.md`) · **Tier:** p1 (#544 moves
from p2 to p1 with the blueprint, section 9 question 2) · **Lead branch:**
`lead/photo-crop`

**Covers:** #544 (closes with CP-5).

**Depends on:** photo-seams (`CropContracts.swift`, `LiveCrop.swift` stub,
`PhotoCropSize.swift` with today's crop drag moved in, `cropAspect` state,
`PhotoWindow+Crop.swift`, `CropOptions.swift` with today's Apply and Cancel
buttons moved in, `CropOverlay.swift`). Only the journey tasks CP-5 and CP-7
also wait on photo-journey-kit; if it is still open when they come up, the
lead records the wait, keeps its heartbeat, and builds them once it closes.
No creative-core issue.

**Return in a field commits the field.** Today Apply Crop carries
`.keyboardShortcut(.defaultAction)` (`PhotoPanel.swift:97`), so Return typed
in the W field would apply the crop. CP-4 removes that shortcut; Return on
the canvas still applies through photo-seams' `.confirm`.

Blueprint sections: 4.2 PJ-8, 5.1 (`CropSizing`, `CropAspect`, `CropField`),
5.3 (PV-3 methods), 6.1 rules 2 and 5, 6.2 (crop options), 7.1 PB-8 and the
perf journeys, 7.3 PF-5, 7.4 rule 5, 7.5 QB-F4.

## Review notes folded in (review of #768)

- **QB-F2 gets a number and a test** for this feature's part: every crop
  drag event updates `pendingCrop` (the overlay draws from it), so the
  rectangle follows the pointer before mouse-up; `PhotoCropSizeTests.dragUpdatesEveryEvent`
  checks 60 events give 60 different rects, and PB-8 bounds the step at
  ≤ 0.05 ms release, ≤ 0.5 ms debug (gated).
- **PJ-P1 and PJ-P2 have an owner and a file** (`+Perf`, CP-7). The
  ellipse-marquee and transform-handle series of PJ-P1 are added by PV-5 and
  PV-7 in their own perf files (`+PerfSelect`, `+PerfTransform`) when they
  land; this feature records the brush, crop and Space-pan series.

## Journey steps

1. **PJ-8 `testTypedCropSizeAndAspect`** (`+Crop`), as blueprint 4.2 writes
   it: on `beach.png` (800 × 600), Crop (C) shows X, Y, W, H with the
   placeholder "Drag on the image, or type a size" and the six aspect chips;
   1:1 gives a centered 600 × 600 pending crop; W 400, Return gives H 400 and the crop stays pending (the canvas is
   still 800 × 600)
   with X and Y kept; 3:2 then swap (`photo.crop.swap`) reads 2:3 with
   H > W; Free and a drag from (10, 10) to (210, 110) give W 200, H 100
   (±1 at Fit); X 700, Return reads X 600 (clamped); Return applies: canvas
   200 × 100, "Undo Crop". Each step asserts the crop element
   `photo.canvas.crop` exists (photo-seams' identified mark).
2. **PJ-P1 `testCanvasDragLatency`** (`+Perf`): `-PhotoFixture large`;
   velocity-controlled drags across 600 pt at 300 pt/s for the brush, the
   crop and Space-pan, with SuiteUI's velocity-drag helper (#333, in
   suite-harness SH-7); at least 60 samples per series; frames late p95
   reported (QB-L1, report-only until FrameProbe #330 lands in
   suite-harness).
3. **PJ-P2 `testSliderScrubLatency`** (`+Perf`): Exposure bar drag on
   `large`, at least 60 samples, QB-L2 reported. photo-adjustment-layers adds
   the adjustment-layer series in its own file.

## Screens and states

| Screen | Empty | Error | Loading |
|---|---|---|---|
| Crop options (Adjust tab, Crop tool) | no pending crop and Free: the four fields show placeholders and are disabled ("Drag on the image, or type a size") | a typed 0, a negative or a non-number keeps the old value and beeps; a value past the canvas clamps | none |
| Canvas, crop pending | – | – | – |
| Crop overlay with a lock | the shade, thirds, and the aspect in a pill on the crop's top edge ("3:2") | – | – |
| No image | Crop options show the empty state; Crop tool disabled as today | – | – |

## Contract slice

From blueprint 5.1 (`CropSizing`, `CropAspect`, `CropField`) and 5.3's PV-3
methods. Added here:

```swift
// M/PhotoCropSize.swift
extension PhotoWorkspace {
    /// Sets one field; false (and nothing changes) for a value under 1 or not finite.
    @discardableResult
    public mutating func setCropField(_ field: CropField, to value: Int) -> Bool
    /// The value a field shows: the pending crop's, or nil (placeholder) with none.
    public func cropFieldValue(_ field: CropField) -> Int?
    /// The text in the crop's aspect pill, nil when Free.
    public var cropAspectBadge: String?
}

// M/Live/LiveCrop.swift (stub from photo-seams, filled here)
enum LiveCrop { static func make() -> any CropSizing }   // LiveCropSizing
```

## Pseudocode

```
ratio(aspect, canvas): free -> nil; original -> canvas.w : canvas.h; ratio(w, h) -> w : h

setting(field, value, crop, aspect, canvas):             # CP-1, LiveCropSizing
  r = crop
  x, y: r.x = clamp(value, 0, canvas.w - r.w) (and y alike); size unchanged
  width:  r.w = clamp(value, 1, canvas.w - r.x); if ratio: r.h = round(r.w * h / w);
          if r.y + r.h > canvas.h: r.h = canvas.h - r.y; r.w = round(r.h * w / h)
  height: the same with sides swapped
dragged(anchor, point, aspect, canvas):
  r = rect(anchor, point) clamped; if ratio: the larger side wins, the other follows,
  then shrink both together until inside the canvas; at least 1 x 1
applying(aspect, crop, canvas):
  base = crop ?? canvas.rect; largest rect of the ratio centered on base's center inside base and canvas
swapped(ratio(w, h)) = ratio(h, w); free, original unchanged

setCropAspect(a): cropAspect = a; if a != .free: pendingCrop = services.crop.applying(a, pendingCrop, canvas)  # CP-2
setCropField(f, v): guard v >= 1 else false; pendingCrop = services.crop.setting(...)
swapCropAspect(): cropAspect = services.crop.swapped(...); re-apply
cropDrag (moved by photo-seams): pendingCrop = services.crop.dragged(anchor, point, cropAspect, canvas)
cropFieldsEnabled = canvas != nil && (pendingCrop != nil || cropAspect != .free)
```

Pending-crop changes stay outside history, as today; only Apply records
"Crop".

## Tasks

Every task is one PR to `dev`: at most 400 changed lines and 15 files, label
`fast-lane`, body lines `Belt-Lead:`, `Feature: photo-crop`, `Fast-Check:
pass`, `Head:`. The last one to merge carries `feature-done`.

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| CP-1 | #544 (part) | `LiveCropSizing`: typed fields, locked drag, applying and swapping an aspect | `M/Live/LiveCrop.swift`, `MT/LiveCropSizingTests.swift` | – | ~300, 2 |
| CP-2 | #544 (part) | Workspace: `setCropField`, `setCropAspect`, `swapCropAspect`, `cropFieldsEnabled`, `cropFieldValue`, `cropAspectBadge`; the crop drag keeps the lock | `M/PhotoCropSize.swift`, `MT/PhotoCropSizeTests.swift` | CP-1 | ~300, 2 |
| CP-3 | – | Budget PB-8 (crop drag and a typed field) on `large` | `MT/PhotoCropBudgetTests.swift` | CP-2 | ~100, 1 |
| CP-4 | #544 (part) | Crop options: four `ScrubField`s two per row in a `Grid`, the six aspect `ChoiceChips`, Swap, Apply Crop (its `.defaultAction` shortcut removed), Cancel; the window's crop intents | `A/CropOptions.swift`, `A/PhotoWindow+Crop.swift`, `ST/PhotoCropOptionsSnapshots.swift` | CP-2 | ~300, 3 |
| CP-5 | #544 (closes) | The aspect pill on the crop overlay; journey PJ-8 | `A/CropOverlay.swift`, `UT/PhotoJourneyTests+Crop.swift` | CP-4, photo-journey-kit | ~240, 2 |
| CP-7 | – | Perf journeys PJ-P1 (brush, crop, Space-pan series) and PJ-P2 (Exposure scrub) | `UT/PhotoJourneyTests+Perf.swift` | photo-journey-kit | ~200, 1 |

CP-7 needs nothing this packet adds: its brush, crop-drag, Space-pan and
Exposure series drive controls that exist before photo-crop, so it builds in
the first wave. CP-5 closes the chain and carries `feature-done`; if CP-7 is
still open when CP-5 is ready (both wait on photo-journey-kit), CP-7 merges
first or carries the label itself, so the `feature-done` run has PJ-P1 and
PJ-P2. No task edits a shared doc (`docs/c4/model.json`, `docs/design.md`,
the blueprint, `waves.md`): every new file sits in a target folder its C4
component already covers, so there is no docs task. If CP-4 passes 400
lines, split it into CP-4a (`CropOptions.swift` and its snapshots) and CP-4b
(`PhotoWindow+Crop.swift`), in that order; CP-5 then depends on CP-4b.

## Build waves

- Wave 1: CP-1, CP-7. Independent in this wave: both.
- Wave 2: CP-2. Independent in this wave: CP-2 alone.
- Wave 3: CP-3, CP-4. Independent in this wave: both.
- Wave 4: CP-5 (`feature-done`, final). Independent in this wave: CP-5 alone.

Longest chain: CP-1 → CP-2 → CP-4 → CP-5 (4).
Chain of 4: CP-2's test needs CP-1's `LiveCropSizing` for the locked drag
(`FakeCrop` ignores the aspect); CP-4's `CropOptions.swift` calls CP-2's
`setCropField`, `setCropAspect`, `swapCropAspect` and `cropFieldValue`;
CP-5's PJ-8 types into CP-4's `photo.crop.*` fields and its pill reads
CP-2's `cropAspectBadge`.

## Acceptance test per task

| id | test | fails when |
|---|---|---|
| CP-1 | `LiveCropSizingTests` on 800 × 600: `applying(1:1, nil)` is (100, 0, 600, 600); width 400 under 1:1 from (100, 0, 600, 600) gives (100, 0, 400, 400); X 700 with width 200 gives X 600; `dragged` (10, 10)→(210, 110) Free gives (10, 10, 200, 100), under 1:1 gives (10, 10, 200, 200); `swapped(3:2)` is 2:3; Original on 800 × 600 is 4:3; every result of 1,000 seeded random inputs lies inside the canvas, is at least 1 × 1 and keeps the ratio within 1 px | a result leaves the canvas, drops below 1 px, or breaks the ratio by more than 1 px |
| CP-2 | `PhotoCropSizeTests`: `setCropField(.width, 0)` returns false and changes nothing; fields are disabled with no crop and Free and enabled after choosing 1:1; the crop drag under 3:2 keeps 3:2; `dragUpdatesEveryEvent` (QB-F2): 60 drag events give 60 different `pendingCrop` values; PF-5: a typed crop then Apply equals CoreRaster `cropped` of each layer at that rect; nothing but Apply records a history step | a bad value is taken, the drag ignores the lock, the overlay would lag, or a field edit is an undo step |
| CP-3 | `PhotoCropBudgetTests`: PB-8 ≤ 0.05 ms release and ≤ 0.5 ms debug (gated in CI), 60 events on `large` | the debug gate fails in CI |
| CP-4 | `PhotoCropOptionsSnapshots`: `photo-crop-options-light.png`, `-dark.png` (empty state) and `photo-crop-ratio-light.png`, `-dark.png` (1:1 locked, 600 × 600); identifiers `photo.crop.x`, `.y`, `.width`, `.height`, `.aspect.<title>`, `.swap`, `.apply`, `.cancel`; the four fields line up as a 2 × 2 grid (7.4 rule 5, equal widths in the snapshot host's frames) | a control has no identifier, or the grid is ragged |
| CP-5 | PJ-8 passes on the macOS run with every step `shot`, including Return in the W field leaving the crop pending; the overlay's pill reads "1:1" under the lock and is absent under Free | any step fails, or Return in a field applies the crop |
| CP-7 | PJ-P1 records at least 60 samples per series (brush, crop, pan) and PJ-P2 at least 60, as report-only lines on the contact sheet | a series has fewer than 60 samples |

## Quality tests

| quality row | budget | test |
|---|---|---|
| PB-8 crop drag, typed field | ≤ 0.05 ms release, ≤ 0.5 ms debug (gated); ≤ 4 ms event to picture (overlay only, report via PJ-P1) | `PhotoCropBudgetTests.cropDragAndField`, PJ-P1 |
| PF-5 | typed crop equals CoreRaster `cropped` | `PhotoCropSizeTests.typedCropMatchesCropped` |
| QB-F2 | the crop rect follows every drag event | `PhotoCropSizeTests.dragUpdatesEveryEvent` |
| QB-F4 | the four fields type; Return applies; Escape cancels | PJ-8 |
| 7.4 rule 5 | the 2 × 2 grid lines up within 1 pt | `PhotoCropOptionsSnapshots.gridAligned` (PV-10's PJ-17 measures it again) |
| PJ-P1, PJ-P2 | report-only until #330 | `testCanvasDragLatency`, `testSliderScrubLatency` |

## Done check

- **Journeys green:** the macOS run on `dev` triggered by the
  `feature-done` PR is green: PJ-8, V7, V9 (crop and Apply still work),
  V1–V12; PJ-P1 and PJ-P2 report.
- **Audit zero new:** no Photo count over `UITests/audit-baseline.json`.
- **Contact sheet:** `Belt-Contact-Sheet: <run link>` on the feature issue,
  one line per journey, the PB-8 number and the audit counts.
