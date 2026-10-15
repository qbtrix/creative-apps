# Photo blueprint (v2)

Photo is the suite's raster editor: open a photo, crop and straighten it,
fix its tone, paint and retouch it in layers, save it and export it. v1 has
shipped (`docs/photo-v1.md`). This blueprint plans **v2** from there. It is
the gate before any v2 feature code: scope, architecture, the usage ranking,
every tier-1 journey, the use-case contracts, the look, the quality bar, and
the features in dependency waves. Feature packets
(`docs/blueprints/photo/features/`) come after the captain approves it.

Sources read on 2026-10-14: creative-apps `origin/dev` 956d946 (Sources,
Tests, UITests, docs, the open `line:photo` issues and the merged Photo PRs),
creative-core `dev` 4cac701 (CoreRaster; `main`, which `Package.swift`
tracks, is cfad97f, with no CoreRaster difference), `docs/design.md`,
`docs/priorities.md`, `docs/review-rubric.md` section 6 (every `QB-` id),
`docs/blueprints/app-audit.md`, `docs/blueprints/brush-display-lessons.md`,
and `docs/blueprints/flare.md` as the worked example of the shape.

Contents: 0 Status on dev · 1 Brief · 2 Pseudo-C4 · 3 Usage map · 4 Journeys ·
5 Contracts · 6 Look · 7 Quality bar · 8 Coverage and waves · 9 Open
questions for the captain · 10 Critic rounds

Ids used below: **PV-n** is a v2 feature (section 8), **PJ-n** a v2 journey
(section 4), **PB-n** a Photo budget (section 7). `QB-` ids are the rubric's.

---

## 0. Status on dev (2026-10-14)

### 0.1 What v1 covers, exactly

`docs/photo-v1.md` is the v1 sign-off: run 38474121045 on dev 27b304a, all
twelve Photo journeys green. The twelve, in `UITests/PhotoJourneyTests.swift`:

| # | Journey (test) | What it proves |
|---|---|---|
| V1 | `testLaunchShowsWindowShell` | The EditorShell window launches: top bar, rail, empty canvas, panel |
| V2 | `testNewImageAndEveryTool` | File > New Image, then every rail tool clicked (none disabled) |
| V3 | `testCurvesDragAndNudge` | Curves: drag a point, nudge it with the arrows, one undo step each |
| V4 | `testEveryMenuOpens` | File, Edit, Select, Image, Layer, View all open |
| V5 | `testOpenImagePaintAndSave` | Open a PNG, paint with the brush, undo and redo, Save writes the file |
| V6 | `testSaveAsAndActualSize` | Save As (Shift-Command-S) renames the window; Actual Size (Command-1) |
| V7 | `testEveryToolEditsTheImage` | Clone (Option-click, drag), Heal, Eraser options, Marquee + Fill, Move, Crop + Apply, each a named undo step |
| V8 | `testStraighten` | Image > Straighten… by an angle with the grid and Crop to Fit |
| V9 | `testTier1CropResize` | Crop tool, Image Size with kept proportions, Rotate |
| V10 | `testTier1Layers` | New, delete, rename, hide, opacity, blend mode, Bring Forward / Send Backward, Select Layer Above / Below |
| V11 | `testTier1Tone` | Exposure, Levels, Curves, Hue/Saturation: enable, edit, Reset |
| V12 | `testTier1UndoRedoZoomPan` | Named undo and redo, zoom in and out, Fit, Space-drag and arrow-key pan |

A thirteenth test, `testBrushStrokeHitchesOnALargePhoto` (#701), came after
the sign-off. It is a perf probe on a 4000 × 3000 photo under XCTest's hitch
metric, an expected failure where the runner can't collect hitches. It is
not a journey.

In plain words, v1 does:

- **Files.** Open PNG, JPEG, HEIC (menu, drop, `-PhotoOpenFile`), a photo over
  16 MP decoded smaller. Save writes back to the open file in its own format
  (PNG or JPEG); Save As picks a new file; Export writes PNG or JPEG with a
  quality slider. **Layers are flattened on every save**: there is no layered
  file format, so a saved and reopened image has one layer.
- **Geometry.** Crop tool (C) with Apply on Return; Image Size; Rotate by
  quarter turns; Straighten by −45° to 45° with Crop to Fit.
- **Tone.** Exposure, Levels, Curves (over a histogram), Hue/Saturation and
  Blur, each with an enable switch and Reset. They apply to the **whole
  composited image** from the Adjust tab, never as layers.
- **Edit.** Named undo and redo of every edit; slider and curve gestures are
  one step each (`endAdjust`).
- **View.** Zoom in and out, Actual Size, Fit, pinch, Space-drag, scroll and
  arrow-key pan.
- **Layers.** New, delete, rename, show and hide, opacity, blend mode (the 16
  W3C modes), reorder by drag and by Command-] / Command-[, select by
  Option-Command-] / [.
- **Tools on the rail:** Move V, Marquee M (rectangles only), Brush B, Eraser E
  (each with its own size, hardness, opacity), Clone S, Heal J, Crop C.

### 0.2 What landed after v1

From `git log origin/dev -- Sources/PhotoModel Sources/PhotoApp`:

| PR | What |
|---|---|
| #701 | A brush event's cost measured end to end (`PhotoBrushLatencyTests`, the hitch journey) |
| #707 | Clone tool on the rail: Option-click samples, drag clones |
| #709 | Select > All stays off while a sheet is up, so Command-A selects the field's text (closes #575) |
| #720 | One brush update per display frame, no frame compare, no histogram recount mid-stroke |
| #723 | The focused layer row's highlight reads 5.05:1 (closes #545) |
| #728 | Only the damaged tiles render, premultiplied, for the live canvas |
| #729 | The canvas is one Core Animation layer per tile (`TileCanvas.swift`) |
| #734 | The dev-red journey failures cleared |
| #738 | Heal paints the source's texture in the tone where it lands |

Model also already holds, with no view yet: the history list
(`historySteps`, `historyIndex`, `jumpToHistoryStep`, #25 closed; the view is
#644) and the brush cursor diameter (`brushCursorDiameter`, #26 closed; the
circle is #588).

### 0.3 The code today

- **PhotoModel** (19 files, 2,467 lines): one value-type `PhotoWorkspace`
  with extensions per area (`PhotoStroke`, `PhotoSelection`, `PhotoHistory`,
  `PhotoImageFile`, `PhotoImageOps`, `PhotoStraighten`, `PhotoRetouch`,
  `PhotoRender`, `PhotoTileUpdate`, `PhotoLayerMenu`, `PhotoInspectorContent`),
  `TiledPixels` (copy-on-write 256 px tiles), its own `PhotoHistory` (not
  FlareCore's `CommandEngine`), and one protocol, `PhotoImageCodec`. There are
  no use-case contracts and no fakes: everything calls CoreRaster directly.
  The selection is a whole-pixel `PixelRect`. `PhotoLayer` has no mask and no
  kind.
- **PhotoApp** (16 files, 1,831 lines): `PhotoWindow` routes every
  `PhotoIntent` (one flat enum) to the workspace; `PhotoEditor` lays out the
  `EditorShell`; `PhotoPanel` holds the Adjust | Layers tabs;
  `PhotoCommands` is the whole menu bar in one file; `TileCanvas` and
  `StrokePacer` are the fast canvas path; `ImageIOCodec` is the codec.
- **Tests.** 50 files in `Tests/PhotoModelTests` (one is shared support) (Linux), 16 Photo files in
  `Tests/AppSnapshotTests` (including `PhotoBrushLatencyTests` and
  `PhotoTileCanvasTests`), one journey file.
- **App audit** (`UITests/audit-baseline.json`): `photo` is at
  `identifier: 23`, every other check 0.
- **Shared harness not built yet** (SuiteUI line, all open): `FrameProbe`
  #330 (p3), golden compare #331 (p1), the scale-2 four-appearance host #332
  (p1), the journey file split and input helpers #333 (p1), status pills #340.
  Until #333 lands every Photo journey lives in one file.
- **creative-core** (`dev` 4cac701) CoreRaster has: `PixelBuffer` (Float32,
  linear, premultiplied), `composite` with the 16 blend modes and an integer
  offset (no mask parameter), `Mask` (rectangle, ellipse, polygon; add,
  subtract, intersect, invert; no feather), exposure, levels, curves, the
  develop sliders, Gaussian blur and unsharp mask, histograms, `resized`
  (bilinear, lanczos3), `rotated(degrees:filter:)` and `straightenCrop`,
  quarter turns and `cropped`, `cloned(offset:through:)`, `TileDiff`, display
  bytes. It has **no** affine transform, no flip, no masked composite, no
  mask feather, no `healed` (creative-core#232 closed with clone only; Photo
  heals in `PhotoRetouch.swift` with a per-dab mean shift), no hue/saturation
  (Photo does it in `HueSaturation.swift`), and no layered file format. No
  open creative-core issue serves Photo.

### 0.4 Open `line:photo` issues (11)

| Issue | Labels | What it covers |
|---|---|---|
| #79 | bug, gap, p3 | Adjustments inspector rows don't line up (ragged slider and field columns) |
| #252 | bug, gap, p3 | Inspector no-image message splits "File > New Image" across two lines |
| #253 | bug, gap, p3 | Status bar says "No image" while canvas and inspector say "No Image Open" |
| #255 | bug, gap, p1 | Levels typing draft opens at two decimals (value change fixed by #525; what's left is cosmetic, and the fix is in SuiteUI's `ScrubField`) |
| #289 | p2, needs-ui | Controls with no accessibility identifier (the audit counts 23 now) |
| #421 | gap, p2 | Ellipse and lasso selections, layer masks |
| #544 | gap, p2 | Type the crop size and lock its aspect ratio |
| #580 | gap, p2, needs-spec | Adjustment layers in the layer stack |
| #586 | bug, gap, p3, needs-human | A tone section's Reset icon is a 9 pt hit target (fix in SuiteUI's `InspectorSectionHeader`) |
| #588 | gap, p2 | Draw the brush cursor circle on the canvas |
| #644 | gap, p2 | History list (view half of #25) |

### 0.5 What is missing

Against `docs/priorities.md` and the usage map (section 3):

1. **Layers don't survive a save** (tier 1: "save" and "layers"). Worst gap:
   it loses work the app let you build.
2. **No crash recovery, no Open Recent, no unsaved marker** (tier 1, inferred:
   losing work outranks any feature).
3. **No Cut, Copy, Paste, Duplicate Layer, Merge Down or Flatten** (tier 1,
   inferred: standard on every Mac editor, and the way an image gets into a
   layer).
4. **Adjustment layers** (#580; tier 1's layers line).
5. **Typed crop size and aspect lock** (#544; tier 1's crop line).
6. **Selections beyond rectangles and layer masks** (#421; tier 2).
7. **Transform: scale, rotate and flip a layer; flip the canvas** (tier 2).
8. **History list and brush cursor** (#644, #588; tier 2).
9. **Export at a size, and TIFF and HEIC export** (tier 2).
10. **Eyedropper** (tier 2, inferred: the brush has a color but nothing picks
    one from the image).
11. **Polish bugs** (#79, #252, #253, #255, #289, #586).

---

## 1. Brief

### The problem

Photo v1 does the everyday photo fix on a flat image: open, crop, tone,
retouch, export. But a person who builds anything in layers loses it on
Save, a crash loses everything since the last save, an image can't be
pasted in, and tone fixes can't be kept apart or limited to part of the
picture. v2 makes Photo a place you can do layered work in and come back to.

### Who uses it

- **The everyday fixer** (most sessions): opens a phone or camera photo,
  crops, straightens, fixes tone, exports a JPEG for sharing. v1 serves them;
  v2 adds the typed crop size for a post and export at a size.
- **The layered editor** (weekly): combines images, keeps tone fixes as
  adjustment layers, masks them to part of the picture, retouches on its own
  layer, saves the layered file and reopens it next day.
- **The keyboard user and the VoiceOver user**: every pointer change has a
  keyboard path (QB-F4), every control a name and identifier (app audit).

### Non-goals (all versions)

Vector drawing and page layout (Design), animation (Flare, Halo), a photo
catalog and batch develop (Library), camera raw decoding (Library #427),
plugins or scripting, cloud sync or collaboration, an iPad build, and reading
or writing any closed layered format.

### The v2 line

| Area | In v2 | Out (later or never) |
|---|---|---|
| Files | A layered document format (section 9, question 1) that keeps layers, masks, adjustment layers, blend, opacity, offsets and the global adjustments; Open Recent; an unsaved dot and the close prompt; autosave to a recovery file and a restore offer after a crash | Reading and writing other apps' layered formats; version browser |
| Edit | Cut, Copy, Paste (as a new layer, at its place or centered), Paste from another app's image on the pasteboard, Duplicate Layer, Merge Down, Flatten Image | Paste Into a selection, Copy Merged |
| Crop | Typed X, Y, W, H for the pending crop; aspect Free, Original, 1:1, 3:2, 4:3, 16:9 with a portrait swap | Crop presets with resolution, perspective crop |
| Layers | Adjustment layers (Exposure, Levels, Curves, Hue/Saturation) in the stack, each with visibility, opacity, blend mode, reorder and a mask | Blur as an adjustment layer (it's a filter), layer groups, clipping masks, layer styles |
| Select | Rectangle, Ellipse and Lasso (freehand, closed on release); Shift adds, Option subtracts; Select > Invert; Feather; brush, eraser, clone, heal, Fill and Delete act inside it | Magic wand, quick selection, refine edge, saved selections |
| Masks | Add Mask from Selection, Delete Mask, Apply Mask, disable a mask; paint on the mask with brush and eraser | Vector masks, mask density and feather sliders on the layer |
| Transform | Edit > Free Transform (Command-T): scale with the 8 handles, rotate outside them, Shift keeps ratio, typed W%, H%, angle; Edit > Transform > Flip Horizontal and Flip Vertical (the selected layer); Image > Flip Canvas Horizontal and Vertical | Skew, distort, perspective, warp |
| History | The History tab: every named step, click to jump, later steps dimmed | Snapshots, history brush |
| Paint | The brush cursor circle at the brush size; Eyedropper (I) picks a color from the image into the brush color, point or 3 × 3 or 5 × 5 average | Gradient, paint bucket, brush presets and textures |
| Export | PNG, JPEG, TIFF and HEIC; a size as a percent or a longest side; quality for JPEG and HEIC | Export several sizes at once, web presets, metadata editing |
| Fixes | #79, #252, #253, #289 (Photo's views), and #255, #586 tracked to SuiteUI | – |

Tier 3 stays out of v2: text, paths and a pen, layer styles, print setup,
specialist controls, gradients and fills.

---

## 2. Pseudo-C4 (drawn before code)

Three layers, as `docs/engineering.md` says. SuiteUI sits beside the app and
knows no Model. Nothing new at L1 or L2: v2 adds L3 components (groups of
files) inside the two Photo containers. The same model is
`docs/blueprints/photo/c4-planned.json`, in the shape of `docs/c4/model.json`,
with `"status"` and `"authored": true` on every element.

```
creative-core (Linux)       creative-apps
CoreRaster, CoreColor ───▶  PhotoModel ──────────────────────▶ PhotoApp ◀── SuiteUI
                            workspace + history + render        window, intents, menus,
                            contracts ─▶ fakes | live           canvas + overlays, panel,
                            (Linux, tested)                     sheets, platform (ImageIO,
                                                                packages, pasteboard, autosave)
```

### 2.1 L2 containers

| Container | Status | Responsibility | Paths | Relationships |
|---|---|---|---|---|
| PhotoModel | existing | Every bit of Photo's state and logic, Linux-safe and tested: the workspace, history, renderer, the v2 contracts with their fakes and live conformances | `Sources/PhotoModel/` | uses CoreRaster and CoreColor (creative-core) |
| PhotoApp | existing | The SwiftUI window on SuiteUI's `EditorShell`, its menus and sheets, and the platform code (ImageIO, file packages, pasteboard, autosave timer) | `Sources/PhotoApp/` | builds from SuiteUI; reads PhotoModel and calls its methods |
| SuiteUI | existing (other line) | Shared components; v2 asks for six (section 6.3) | `Sources/SuiteUI/` | – |
| CoreRaster, CoreColor | existing (creative-core) | Pixels, compositing, masks, tone, resampling; v2 asks for five engine additions (section 8.4) | creative-core | – |

### 2.2 L3 components in PhotoModel

The existing component `photo-model-sources` (`Sources/PhotoModel/`) is split
here by responsibility so features can own parts of it. The C4 gate in
`scripts/ci` only reads `docs/c4/model.json`, where the one component keeps
owning the whole folder; PV-0 rewrites that component's description once to
name everything below, so no later feature edits `docs/c4/model.json`.

| Component | Status | Responsibility | Owned paths | Relationships |
|---|---|---|---|---|
| workspace | existing (v2 adds state in PV-0) | `PhotoWorkspace`: the open image, layers (top first) with kind and mask flags, pixels and masks as tiles, selection (rect plus optional coverage mask), tool and tool options, pending crop and aspect, transform draft, sample size, services, the saved marker | `PhotoWorkspace.swift`, `PhotoLayer.swift`, `PixelRect.swift`, `TiledPixels.swift`, `ToolOptions.swift`, `PhotoInspectorContent.swift`, `PhotoLayerMenu.swift` | calls contracts through `services`; records every edit in history |
| history | existing (PV-0 adds step ids, the selection and mask-tiles steps, and masks in the stack) | Named undo and redo by tiles, layer lists or whole stacks; the history list and jump; each History tab row (PV-4) | `PhotoHistory.swift`, `PhotoHistoryRows.swift` (PV-4) | read by the History tab (PV-4) |
| render | existing (PV-0 extracts the per-layer step) | Composite visible layers bottom-up, then the global adjustments; damaged tiles only for the live canvas; the curve's samples and histogram | `PhotoRender.swift`, `PhotoTileUpdate.swift`, `PhotoLayerComposite.swift` (new in PV-0: one layer's contribution, the hook PV-6 and PV-5 fill), `AdjustmentSettings.swift`, `GammaTrack.swift`, `HueSaturation.swift` | uses CoreRaster `composite`; calls `adjustmentLayers` and `masking` |
| tools | existing (PV-0 routes drags) | Each tool's drag: brush, eraser, clone, heal, move; routes marquee, crop, eyedropper and transform drags to their components; weights paint by the selection's coverage | `PhotoStroke.swift`, `PhotoRetouch.swift`, `PhotoSelection.swift` | calls select-mask, crop, transform, eyedropper |
| image-ops | existing | Open and export through `PhotoImageCodec`; Image Size, Rotate, Straighten | `PhotoImageFile.swift`, `PhotoImageOps.swift`, `PhotoStraighten.swift` | uses CoreRaster resample and rotate |
| contracts | planned (PV-0) | One protocol per v2 use case and the values they share (section 5); `PhotoServices` with `.fake` and `.live` | `Contracts/`, `PhotoServices.swift` | implemented by fakes and live |
| fakes | planned (PV-0) | Deterministic fakes and the fixture images for views, snapshots and `-PhotoFixture` journeys | `Fakes/`, `PhotoFixtures.swift` | implement contracts |
| live | planned (PV-0 stubs; each feature fills its file) | The real conformances over CoreRaster; `NotBuilt` stand-ins until each feature lands | `Live/` | use CoreRaster; implement contracts |
| documents | planned (PV-1) | Snapshot to and from the workspace, Save routing (document or flat image), the dirty marker, autosave due time | `PhotoDocumentFile.swift`, `PhotoRecovery.swift` | calls `archive`, `recovery` |
| edit | planned (PV-2) | Cut, Copy, Paste as a new layer, Duplicate Layer, Merge Down, Flatten Image, with their availability | `PhotoClipboard.swift`, `PhotoLayerOps.swift` | calls `clipboard`, `merging` |
| crop | planned (PV-3) | Typed crop numbers and the aspect lock; the crop drag | `PhotoCropSize.swift` | calls `crop` |
| select-mask | planned (PV-5) | Selection shapes, add and subtract, invert, feather; selection coverage for paint; layer masks: add, delete, apply, enable, paint on the mask | `PhotoSelectionMask.swift`, `PhotoMask.swift` | calls `selection`, `masking` |
| adjustment-layers | planned (PV-6) | New adjustment layer, edit its settings, render it in the stack | `PhotoAdjustmentLayer.swift` | calls `adjustmentLayers` |
| transform | planned (PV-7) | Free Transform mode: begin, drag handles, typed values, commit, cancel; flip layer and canvas | `PhotoTransform.swift` | calls `transform` |
| export | planned (PV-8) | Export options and output size; TIFF and HEIC | `PhotoExportOptions.swift` (and the `ImageFormat` cases in `PhotoImageFile.swift`) | calls `exportSizing` |
| eyedropper | planned (PV-9) | The Eyedropper tool's drag: sample the composited image into the brush color | `PhotoEyedropper.swift` | calls `sampling` |

All paths are under `Sources/PhotoModel/`.

### 2.3 L3 components in PhotoApp

| Component | Status | Responsibility | Owned paths | Relationships |
|---|---|---|---|---|
| window | existing (PV-0 splits the router) | `PhotoApp`, `PhotoWindow` (the one `@State` model and presentation state), `PhotoIntent` with one sub-enum per v2 area, and one `PhotoWindow+<Area>.swift` per area | `PhotoApp.swift`, `PhotoWindow.swift`, `PhotoIntent.swift`, `PhotoWindow+File.swift` (PV-1), `+Edit.swift` (PV-2), `+Crop.swift` (PV-3), `+History.swift` (PV-4), `+Select.swift` (PV-5), `+AdjustmentLayer.swift` (PV-6), `+Transform.swift` (PV-7), `+Export.swift` (PV-8), `+Sample.swift` (PV-9) | calls PhotoModel |
| commands | existing (PV-0 splits per menu) | The menu bar: `PhotoMenu` carries the workspace value, so each menu reads what it needs | `PhotoCommands.swift`, `PhotoCommands+File.swift`, `+Edit.swift`, `+Select.swift`, `+Image.swift`, `+Layer.swift`, `+View.swift` | sends `PhotoIntent` |
| canvas | existing (PV-0 adds the overlay and splits the bars) | The EditorShell layout, the tile canvas and its renderer, the stroke pacer, pointer pressure; the overlay of marks; the top bar and the status line | `PhotoEditor.swift`, `PhotoTopBar.swift`, `PhotoStatusLine.swift`, `TileCanvas.swift`, `CanvasRenderer.swift`, `StrokePacer.swift`, `PointerPressure.swift`, `PhotoCanvasOverlay.swift`, `CropOverlay.swift`, `SelectionOverlay.swift`, `TransformOverlay.swift`, `BrushCursorOverlay.swift` | SuiteUI `EditorShell`, `CanvasViewport`, `CanvasMarks` |
| panel | existing (PV-0 splits per tab) | The right panel: Adjust, Layers and History tabs; tool options per tool | `PhotoPanel.swift`, `PhotoAdjustTab.swift`, `PhotoLayersTab.swift`, `PhotoHistoryTab.swift`, `PhotoToolOptions.swift`, `CropOptions.swift`, `SelectOptions.swift`, `TransformOptions.swift`, `SampleOptions.swift`, `AdjustmentsInspector.swift`, `CurvesSection.swift` | SuiteUI inspector rows, chips, tabs |
| sheets | existing | Export, Image Size, Straighten | `ExportSheet.swift`, `ImageSizeSheet.swift`, `StraightenSheet.swift` | – |
| platform | existing (ImageIO) and planned | The ImageIO codec; reading and writing document packages; the autosave timer; the pasteboard | `ImageIOCodec.swift`, `PhotoPackageIO.swift` (PV-1), `PhotoAutosave.swift` (PV-1), `PhotoPasteboard.swift` (PV-2) | ImageIO, AppKit |

All paths are under `Sources/PhotoApp/`.

### 2.4 Why the seams first (PV-0)

Photo today has five files every feature would touch: `PhotoWorkspace.swift`
(its `==` lists every stored property), `PhotoIntent.swift` (one flat enum),
`PhotoWindow.swift` (one `perform` switch and `private` state),
`PhotoCommands.swift` (the whole menu bar) and `PhotoPanel.swift`. PV-0
splits each so that every later feature owns its own files, exactly as
Flare's LM-0a3 and F1 did:

- **One PR adds every v2 stored property** to `PhotoWorkspace` (and its `==`),
  `PhotoLayer` (`kind`, `hasMask`, `isMaskEnabled`) and `PhotoHistory`
  (`.selection` step; masks in `PhotoStack`). No later feature edits those
  three files.
- **Drags carry what the tools need.** Today's `drag(from:to:pressure:sampling:)`
  and `drags(_:)` carry only Option (as `sampling`). PV-0 adds
  `drag(from:to:pressure:modifiers:zoom:)` and its batch form, keeps the old
  two as wrappers so the existing tests compile unchanged, and
  `PhotoWindow`, `StrokePacer` and the canvas gesture call the new ones, so Shift-drag (add, keep
  ratio, snap), Option-drag (subtract, from center) and zoom-aware handle
  tolerances reach PV-5 and PV-7 without touching those files again.
- **Drags route by component.** `PhotoStroke.drag` sends marquee drags to
  `selectionDrag` (`PhotoSelectionMask.swift`), crop to `cropDrag`
  (`PhotoCropSize.swift`), eyedropper to `sampleDrag`
  (`PhotoEyedropper.swift`), and any drag while `transformDraft != nil` to
  `transformDrag` (`PhotoTransform.swift`). PV-0 moves today's marquee and
  crop code into those files unchanged and creates the other two as
  stubs; each feature then owns its file. The eyedropper's stub is already
  real: it calls `services.sampling` and sets the brush color, so the tool
  works on `.fake` (as `PhotoToolsTests` requires) and stays disabled on
  `.live` until PV-9 replaces `LiveSampling`.
- **Paint goes through one target and the selection's coverage.** Brush,
  eraser, clone and heal write into `paintTarget()` (PV-0, in
  `PhotoStroke.swift`): `.pixels(id)`, `.mask(id)` while `editsMask` and the
  layer has a mask, or nil with "Select an image layer in the Layers tab to paint on." on an
  adjustment layer. A mask's coverage is its gray with alpha 1, so the brush
  paints black to hide and white to reveal, the eraser paints white, and
  `PhotoHistory` gets a `.maskTiles` step beside `.tiles`. Every dab, and
  Delete and Fill, is weighted by `selectionCoverage(x:y:)`, a stub in
  `PhotoSelectionMask.swift` that returns 1 inside today's rectangle; Select
  All, Deselect and Apply Crop also set or clear `selectionMask` there. PV-5
  fills these in its own file and only sets `editsMask`.
- **Rendering routes by layer.** `PhotoLayerComposite.swift` holds one
  layer's contribution (today: composite its pixels). PV-6 adds adjustment
  layers to it in wave 2, PV-5 adds masks in wave 4.
- **Intents and menus route by area.** `PhotoIntent` gains one case per
  area holding that area's own enum, declared in the area's
  `PhotoWindow+<Area>.swift` (empty enum plus an empty `switch`). PV-0
  makes `PhotoWindow`'s stored state `internal` so the area files can reach
  it, and declares every v2 presentation flag (recovery offer, paste
  refusal text, transform mode, export options draft).
- **Return and Escape route by mode.** The canvas key handler in
  `PhotoEditor.swift` sends `.confirm` and `.dismiss` instead of
  `.applyCrop` and `.cancelCrop`. `PhotoWindow.perform` asks
  `confirmTransform()` and `dismissTransform()` (in
  `PhotoWindow+Transform.swift`, stubs returning false) first, then falls
  back to today's crop and deselect behavior, so PV-7 never edits
  `PhotoEditor.swift`.
- **Availability comes from services.** A control that needs a use case
  reads `model.services.<use case>.unavailableHelp`. `.live` starts as
  `NotBuilt` for every v2 use case ("Not built yet (PV-n)."), so a v2 menu
  item or tool is disabled with that tooltip until its feature lands; under
  `-PhotoFixture` every fake answers nil. A feature never edits
  `PhotoServices.swift`: `.live` reads `Live<X>.make()` from the feature's own
  `Live/` file.
- **The tool enum grows once.** PV-0 adds `.eyedropper` (I) to `PhotoTool`.
  A tool's availability moves to `PhotoWorkspace.toolHelp(_:) -> String?`,
  which reads the tool's service (the eyedropper's is `services.sampling`);
  `PhotoTool.unavailableHelp` stays as the fallback text. `PhotoToolsTests`
  changes in the same PR to read `toolHelp` and to run each tool on
  `.fake`, where every tool works.

---

## 3. Usage map

Ranked the way `docs/priorities.md` ranks: what people do in nearly every
session (tier 1), weekly (tier 2), occasionally or as specialists (tier 3).
Clean-room: public sources only, no other app opened or run, no product
named. No public study counts per-feature use in raster editors, so as in
`docs/priorities.md` the tiers come from what every beginner course teaches
first and what every shortcut list repeats; rows marked *inferred* have no
direct source and move first if usage data turns up.

**Sources.** From `docs/priorities.md`: the photo editing habits survey of
18–25 year olds (https://petapixel.com/2024/06/21/one-third-of-18-to-25-year-olds-edit-their-photos-for-social-media)
and the photo editing software survey
(https://shotkit.com/photo-editing-software-survey/). Added here:

- The OpenRaster file layout and layer stack specifications
  (https://www.openraster.org/baseline/file-layout-spec.html,
  https://www.openraster.org/baseline/layer-stack-spec.html): a published,
  open spec whose stated goal is saving layered work "without destructive
  pixel operations"; it is the evidence that keeping layers on save is a
  baseline expectation of a raster editor.
- Public beginner raster-editing course outlines (university short courses,
  library tech training, online certificates; named here only by kind,
  because their titles name a product). Read together, their order is
  constant: the interface and opening a file; selections; layers and layer
  masks; adjustment layers for tone and color; retouching (clone, heal);
  then export. Masks and adjustment layers appear in the first or second
  class of every outline read.
- W3C Compositing and Blending Level 1 (https://www.w3.org/TR/compositing-1/),
  already the spec behind CoreRaster's blend modes, for what a layer's blend
  and opacity mean when layers merge or flatten.

### Tier 1: nearly every session

| # | Job | v1 | v2 adds | Source |
|---|---|---|---|---|
| 1 | Open, save, export with format and quality | open, save flat, Save As, export PNG and JPEG | **save and reopen with layers kept**; Open Recent; the unsaved dot and close prompt | priorities.md; OpenRaster spec (layers survive save) |
| 2 | Never lose work | – | **autosave and restore after a crash** | *inferred*: losing work outranks any feature (the same call as Flare's decision 4) |
| 3 | Crop, straighten, resize | crop drag, straighten, Image Size, rotate | **typed crop size and aspect lock** (#544) | priorities.md; the course outlines (cropping to a size for a post or print) |
| 4 | Tone and color | exposure, levels, curves, hue/saturation (whole image) | – (see 6) | priorities.md |
| 5 | Undo, redo, zoom, pan | all | – | priorities.md (*inferred*) |
| 6 | Layers: stack, opacity, adjustment layers | stack, opacity, blend, order | **adjustment layers** (#580) | priorities.md; course outlines (adjustment layers in class one or two) |
| 7 | Get pixels into and between layers | – | **Cut, Copy, Paste as a new layer, paste from another app, Duplicate Layer, Merge Down, Flatten** | *inferred*: the standard Edit commands every Mac editor has (`docs/design.md`, Commands), and the only way to combine two photos |

### Tier 2: weekly

| # | Job | v1 | v2 | Source |
|---|---|---|---|---|
| 8 | Heal and clone | both tools | – (core op tracked, section 8.4) | priorities.md |
| 9 | Selections and masks | rectangle marquee | **ellipse, lasso, add, subtract, invert, feather; layer masks** (#421) | priorities.md; course outlines |
| 10 | Brush and eraser | both, with options | **the brush cursor circle** (#588); **eyedropper** (*inferred*: a brush color needs a way to pick it from the image) | priorities.md (#26) |
| 11 | History beyond one step | model only | **the History tab** (#644) | priorities.md (#25) |
| 12 | Transform | quarter turns, straighten | **free transform of a layer, flip layer and canvas** | priorities.md |
| 13 | Export at a size and in more formats | PNG, JPEG at full size | **a percent or longest side; TIFF and HEIC** | *inferred* from the photo editing survey (photos edited to share go out at a size a service takes) |

### Tier 3: specialist or occasional (not v2)

Blend modes beyond today's 16 and layer styles; text; paths and a pen;
print setup; specialist controls; gradients and fills; magic wand and refine
edge; skew, distort, perspective and warp; layer groups and clipping masks;
camera raw (Library); 16-bit layers (section 9, question 3).

### Priority labels for v2 work

Following `docs/priorities.md`'s rules: PV-1, PV-2, PV-3 and PV-6 are `p1`;
PV-0 is `p1` by dependency; PV-4, PV-5, PV-7, PV-8 and PV-9 are `p2`; PV-10
takes each bug's own label (#255 `p1`, the rest `p3`, #289 `p2`). #580 and
#544 move from `p2` to `p1` with this blueprint (section 9, question 2).

---

## 4. Journeys

### 4.1 Rules for every v2 journey

- **Files.** Each feature owns `UITests/PhotoJourneyTests+<Area>.swift`, one
  `XCTestCase` class, once SuiteUI's QH-4 (#333) makes the journey template
  compile `UITests/<target>*.swift`. Until #333 merges, two features of one
  wave can't both add journeys, so section 8 makes every wave-1 feature wait
  on #333 for its journey task only (its model and view tasks don't).
- **Launch.** Live journeys write their input with the existing
  `writeTestPhoto(to:)` helper, which PV-0 moves out of `PhotoJourneyTests`
  (where it is `private static`) into `UITests/PhotoJourneyTests+Fixtures.swift`
  as an internal function every Photo journey class can call (PV-0 owns
  both files; the move waits on #333, since today `project.yml` compiles only
  `UITests/PhotoJourneyTests.swift`), and open it with `-PhotoOpenFile`; saves go to
  `-PhotoSaveTo <folder>`, exports to `-PhotoExportTo <folder>`. Two new
  arguments (PV-0): `-PhotoFixture <name>` runs `.fake` services on a fixture
  (section 5.4) and shows a "Preview data" pill; `-PhotoRecoveryDir <folder>`
  points autosave at the test's folder (PV-1).
- **Finding things.** Every v2 control carries `photo.<area>.<name>`
  (`photo.file.recent`, `photo.crop.width`, `photo.layer.mask-badge`).
  Journeys find controls by identifier, menus by title.
- **Waiting.** State is awaited with `waitForExistence` or a value predicate
  (5 s, 30 s for open and save of the large photo). No journey times anything
  through an XCUI query; timings come from the model budgets (section 7.1).
- **Every step takes a `shot`** and so runs the app audit.
- **The v1 journeys stay** (section 0.1, V1–V12) and must stay green; a v2
  feature that changes a v1 step updates that step in the same PR.

### 4.2 Tier-1 journeys

Each step names what the person does and what the test asserts. States
lists every empty, error and loading state the journey passes through.

**PJ-1 `testSaveLayeredDocumentAndReopen`** (`+Documents`, PV-1)

1. Launch with `-PhotoOpenFile beach.png -PhotoSaveTo <tmp>`. Assert the
   title is `beach.png` and there is no unsaved dot (`photo.bar.saved`
   value "Saved").
2. Layer > New Layer; brush a stroke; Layer opacity to 50; blend Multiply.
   Assert `photo.bar.saved` value "Edited" (the dot) and the window's
   document-edited state is set.
3. File > Save. Assert a "Keep layers?" choice appears, because the open
   file is a PNG: **Save as Photo Document** (default) or **Flatten into
   PNG**. Choose Save as Photo Document. Assert the title reads
   `beach.ora`, "Saved", and the file exists in `<tmp>`, starts with the
   zip signature and its first entry is `mimetype` reading `image/openraster`.
4. Close the window (Command-W): no prompt. File > Open Recent >
   `beach.ora`. Assert 2 layers, the top named "Layer 1" with opacity
   reads 50 and blend "Multiply", and the shot matches step 3's canvas.
5. Command-Z. Assert the Edit menu reads "Redo" only (a reopened document
   has an empty history, "Open" as its first step).

States: loading, "Opening…" note when the decode takes over 100 ms (the
30 MB fixture variant in PJ-P3); error none here (see PJ-4).

**PJ-2 `testUnsavedPromptAndOpenRecent`** (`+Documents`, PV-1)

1. Launch on `beach.png`. Brush a stroke. Command-W.
2. Assert the unsaved-changes alert with Save, Don't Save, Cancel (an
   `NSAlert` the window shows, worded like the system's document alert,
   since Photo uses `WindowGroup`, section 9 question 5).
   Cancel: the window stays, still "Edited".
3. Command-W, Don't Save: the window closes. File > Open Recent lists
   `beach.png` first. Open it: the stroke is gone.
4. File > Open Recent > Clear Menu: the submenu shows its empty state
   (only Clear Menu, disabled).

States: empty (Open Recent with nothing), none loading, error none.

**PJ-3 `testRestoreAfterCrash`** (`+Recovery`, PV-1)

1. Launch on `beach.png` with `-PhotoRecoveryDir <tmp>`. New Layer, brush a
   stroke. Wait until `photo.bar.saved` value reads "Edited, autosaved"
   (autosave runs 5 s after the last edit under `-PhotoRecoveryDir`, 30 s
   otherwise).
2. Terminate the app (`app.terminate()`, no quit path), relaunch with the
   same `-PhotoRecoveryDir` and no file.
3. Assert the restore offer: "Restore beach.png from <time>?" with Restore
   and Discard (`photo.recovery.restore`, `photo.recovery.discard`).
4. Restore. Assert 2 layers and "Edited" (a restored document is unsaved).
5. Command-Q, Don't Save; relaunch: no offer (a clean close discards the
   recovery file).

States: empty (no recovery file: no offer, the empty canvas), loading (the
offer appears only after the recovery directory is read, off the main
thread), error ("The unsaved image couldn't be restored: <reason>." in the
offer's place, with Discard only, when the package is damaged).

**PJ-4 `testOpenBadDocuments`** (`+Documents`, PV-1)

For each file written by the test: a `.ora` that is not a zip (bytes
`not a zip`); one whose `photo/document.json` says `"format": 2`; one
missing `data/layer-2.png`; one with a 20 MP layer, over the limit. Open each with `-PhotoOpenFile`.

Assert the alert text is `ArchiveError.message` for the case ("This file
isn't a Photo document.", "…made by a newer Photo (format 2)…", "This
document is damaged: data/layer-2.png is missing.", "This document is
larger than Photo can open."), and the empty state stays (or the document
that was open stays open).

States: error (four), empty (after each alert).

**PJ-5 `testCopyPasteAsNewLayer`** (`+Edit`, PV-2)

1. Launch on `beach.png`. With no selection, assert Edit > Cut and Copy are
   enabled (they take the whole layer), Paste is disabled with
   "Nothing to paste." when the pasteboard holds no image (the test clears
   it first).
2. Marquee (M) a rectangle over the sun. Command-C. Assert Paste enabled.
3. Command-V. Assert a new layer "Pasted Layer" above Background, selected,
   and its bounds (layer info line) equal the selection's rect; the Edit
   menu reads "Undo Paste".
4. Select Background, Command-X. Assert the sun area of Background is
   transparent where cut (the canvas shot differs) and "Undo Cut".
5. Command-Z twice: Background whole, the pasted layer gone.

States: empty (nothing selected: whole layer; nothing on the pasteboard:
Paste disabled with its reason), error ("Nothing to copy." in the status
line when the selected area is fully transparent).

**PJ-6 `testPasteFromAnotherApp`** (`+Edit`, PV-2)

1. The test writes a 200 × 100 PNG to `NSPasteboard.general` from the test
   runner. Launch on `beach.png` (800 × 600).
2. Edit > Paste. Assert a new layer of 200 × 100 centered on the view's
   center (offset 300, 250 at Fit), "Undo Paste".
3. With no image open (a fresh launch, empty canvas), Edit > Paste. Assert
   a new image opens from the pasteboard, 200 × 100, titled "Untitled".

States: empty (the no-image case above), error (a pasteboard image over
16 MP pastes scaled to fit, with a status note "Pasted at 50%.").

**PJ-7 `testDuplicateMergeAndFlatten`** (`+LayerOps`, PV-2)

1. Launch on `beach.png`. Layer > Duplicate Layer (Command-J). Assert
   "Background copy" above Background, selected, "Undo Duplicate Layer".
2. Set its blend to Screen, opacity 60. Layer > Merge Down (Command-E).
   Assert one layer named "Background" and the canvas shot equals step 2's
   canvas shot (merge keeps the look), "Undo Merge Down".
3. New Layer, brush; Layer > Flatten Image. Assert one layer, "Undo
   Flatten Image".
4. With one layer, assert Merge Down is disabled with "There's no layer
   below to merge into." and Flatten Image is disabled with "The image
   already has one layer."

States: empty (the disabled reasons), error (Merge Down onto an adjustment
layer: disabled with "Merge Down needs a pixel layer below.").

**PJ-8 `testTypedCropSizeAndAspect`** (`+Crop`, PV-3)

1. Launch on `beach.png` (800 × 600). Crop tool (C). Assert the crop options
   show X, Y, W, H (empty: "Drag on the image, or type a size") and the
   aspect chips Free, Original, 1:1, 3:2, 4:3, 16:9.
2. Choose 1:1. Assert a centered 600 × 600 pending crop (W and H read 600).
3. Type W 400, Return. Assert H reads 400 (locked), X and Y keep the
   top-left.
4. Choose 3:2, click the swap button (`photo.crop.swap`). Assert the chip
   reads 2:3 and H > W.
5. Choose Free; drag on the canvas from 10,10 to 210,110. Assert W 200 and
   H 100 (±1 at Fit).
6. Type X 700, Return. Assert X reads 600 (clamped so the crop stays on the
   canvas). Return applies: canvas 200 × 100, "Undo Crop".

States: empty (no pending crop: the fields show placeholders and are
disabled until a crop exists or an aspect is chosen), error (a typed 0 or a
non-number keeps the old value and beeps; covered by the model tests).

**PJ-9 `testAdjustmentLayer`** (`+AdjustmentLayers`, PV-6)

1. Launch on `beach.png`. Layers tab. Layer > New Adjustment Layer > Curves.
   Assert a row "Curves 1" with the adjustment symbol above Background,
   selected; the Adjust tab shows only the Curves section, titled
   "Curves 1"; "Undo New Adjustment Layer".
2. Drag the curve's midpoint up. Assert the canvas shot differs from step 1
   and the Edit menu reads "Undo Curves".
3. Hide the row's eye: the canvas equals step 1's shot. Show it again.
4. New Layer above it, brush: the brush stroke is not affected (above the
   adjustment). Select the adjustment and Send Backward once: it is now
   the bottom row, Send Backward is disabled, and the canvas shows the
   stroke on the unadjusted photo (nothing below the adjustment).
5. Opacity 0 on the adjustment: canvas equals step 1. Command-Z restores
   the opacity.
6. Select Background: the Adjust tab shows the whole-image sections again,
   headed "Image".

States: empty (an adjustment layer at the bottom changes nothing; its
row's info line says "Nothing below to adjust."), error (Brush on an
adjustment layer: the canvas refuses with "Select an image layer in the Layers tab to paint on."
in the status line, the stroke does nothing).

### 4.3 Tier-2 journeys

Written in full in each feature's packet; named here so the coverage matrix
can point at them.

| # | Test (file, feature) | Steps | Asserts | States |
|---|---|---|---|---|
| PJ-10 | `testHistoryTabJump` (`+History`, PV-4) | four edits; History tab; click step 2; New Layer | rows "Open", then each edit; rows after 2 dimmed; clicking 2 undoes two steps; a new edit removes the dimmed rows | empty: a new image lists only "New Image" |
| PJ-11 | `testBrushCursorFollowsSize` (`+History`, PV-4) | Brush; hover the canvas; size 40, then 120; Move tool | `photo.canvas.brush-cursor` exists, its frame width is 40 × zoom, then 120 × zoom (±1 pt); gone with Move | none |
| PJ-12 | `testEllipseLassoAddSubtract` (`+Select`, PV-5) | Marquee shape Ellipse; drag; Shift-drag a rectangle; Option-drag a lasso; Select > Invert; Feather 10; brush | the marching-ants element exists after each; the info line reads the selection's bounds; brush paints only inside (a pixel outside unchanged); each change is one "Undo Select" step | empty: Invert with nothing selected selects all |
| PJ-13 | `testLayerMaskFromSelection` (`+Mask`, PV-5) | ellipse select; Layer > Add Mask from Selection; paint black on the mask; Shift-click the badge; Layer > Apply Mask | `photo.layer.mask-badge` on the row; the pixels outside are hidden, not deleted (disable shows them); Apply makes them transparent; one step each | error: Add Mask on an adjustment layer with nothing selected reveals all |
| PJ-14 | `testFreeTransformAndFlip` (`+Transform`, PV-7) | Command-T; drag the bottom-right handle out by half; drag outside a corner a quarter turn with Shift; Return; Edit > Transform > Flip Horizontal; Image > Flip Canvas Vertical | the transform box element; W% reads 150, angle 90; Return gives "Undo Free Transform"; Escape in a second round leaves the layer as it was; flips are exact (`testFlip…` model goldens) | loading: a transform over 12 MP shows "Transforming…" |
| PJ-15 | `testExportAtSizeAsTIFFAndHEIC` (`+Export`, PV-8) | Export; TIFF; size 50%; Export; HEIC quality 70; longest side 400; Export | files exist with TIFF and HEIC headers; TIFF is 400 × 300; HEIC's longer side 400 | error: a longest side over 16384 disables Export with the reason; loading: "Exporting…" |
| PJ-16 | `testEyedropperPicksColor` (`+Sample`, PV-9) | Eyedropper (I); click the sun; 5 × 5; click the sky; B | the brush color well's hex reads the sun's color, then the sky's mean; picking is not an undo step | empty: a click on a transparent pixel keeps the color and says "Nothing to sample here." |
| PJ-17 | `testLayoutAtWidths` (`+Layout`, PV-10) | relaunch at 880, 960 and 1024 pt (section 7.4) | the layout rules of section 7.4 at each width | none |

### 4.4 Fixtures

Built in code in `Sources/PhotoModel/PhotoFixtures.swift` (PV-0), never read
from disk, so the UI test target never builds a document file:

| Fixture | Contents | Used by |
|---|---|---|
| `empty` | no image | the empty states |
| `sample` | the `writeTestPhoto` picture: 800 × 600, a sky gradient from blue at the top to orange at the bottom, a yellow sun disc centered at (560, 220) with radius 90; one Background layer | most journeys |
| `layered` | `sample` plus "Paint" (a red stroke, Multiply, 60%), "Curves 1" (an adjustment layer), and a mask on Paint | PV-5, PV-6 views and snapshots |
| `large` | 4000 × 3000 noise and gradients, three layers | PJ-P1–P3, model budgets |
| `limit` (tests only) | 16 MP, eight layers each with a mask | `PhotoBudgetTests` |

---

## 5. Contracts

One Swift protocol per v2 use case, with a fake for each, so a feature's
views and its logic can be built in parallel (the view on the fake, the
logic as the live conformance) and meet in `PhotoServices`.

**Checked on Linux.** Every block below was compiled on 2026-10-14, as
written, inside PhotoModel on dev 956d946 with creative-core `dev` 4cac701,
Swift 6.3.3 on Ubuntu 24.04 (`swift build --build-tests`), and the 309
existing Photo model tests passed with it in place. PV-0's first task lands
exactly these files and repeats that build.

**How a contract is used.** A contract is a pure service over value types.
The workspace method a view calls (section 5.3) checks availability, calls
the contract inside one recorded history step, and writes the result to its
own state; a throw leaves everything unchanged. So the undo name, the
coalescing and the "one gesture, one step" rule (QB-F3) live in the
workspace, never in a conformance, and fakes and live conformances are
interchangeable. Every protocol refines `PhotoUseCase`, whose
`unavailableHelp` is the tooltip of the controls that need it.

**Engine-direct (no protocol)**, because there would be one conformer and
the code already exists: the history list and jump (`PhotoHistory`, PV-4),
the brush cursor diameter (PV-4), Duplicate Layer (copies a layer and its
tiles), and opening flat files (`PhotoImageCodec`, existing).

### 5.1 The protocols and shared values (`Sources/PhotoModel/Contracts/`)

**Shared values** (`Contracts/PhotoContractTypes.swift`)

```swift
// Contracts/PhotoContractTypes.swift: what every Photo v2 use-case contract
// shares. A contract is a pure service over value types: it takes pixels,
// layers and geometry and returns new ones. PhotoWorkspace owns state and
// history; it calls a contract inside one recorded step, so a contract never
// records undo itself and a throw leaves the workspace unchanged.
// Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreRaster

/// Every contract says whether it can run yet. Its text is the tooltip of
/// every control that needs it ("Not built yet (PV-5)."); nil once it works.
public protocol PhotoUseCase: Sendable {
    var unavailableHelp: String? { get }
}

/// A use case refused for a reason the person can fix, in the words the
/// window shows ("Nothing to paste.", "Merge Down needs a pixel layer below.").
public struct PhotoRefusal: Error, Equatable, Sendable {
    public var message: String
    public init(_ message: String) { self.message = message }
}

/// Modifier keys held during a canvas drag.
public struct DragModifiers: OptionSet, Hashable, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    /// Keep the ratio, add to a selection, snap an angle to 15 degrees.
    public static let shift = DragModifiers(rawValue: 1)
    /// From the center, subtract from a selection.
    public static let option = DragModifiers(rawValue: 2)
}

/// Pixels placed on the canvas: a buffer and where its top-left pixel sits.
public struct PlacedPixels: Sendable, Equatable {
    public var pixels: TiledPixels
    public var x: Int
    public var y: Int
    public init(pixels: TiledPixels, x: Int, y: Int) {
        self.pixels = pixels; self.x = x; self.y = y
    }
}

/// One layer with what it draws: pixels for a pixel layer (nil for an
/// adjustment layer) and its mask, a buffer the layer's size whose gray is
/// the coverage, alpha 1 (nil for none).
public struct LayerContent: Sendable, Equatable {
    public var layer: PhotoLayer
    public var pixels: TiledPixels?
    public var mask: TiledPixels?
    public init(layer: PhotoLayer, pixels: TiledPixels?, mask: TiledPixels? = nil) {
        self.layer = layer; self.pixels = pixels; self.mask = mask
    }
}
```

**PV-1 documents and recovery** (`Contracts/DocumentContracts.swift`)

```swift
// Contracts/DocumentContracts.swift: the layered document (PV-1). A document
// is one OpenRaster file (a zip, https://www.openraster.org/baseline/): the
// `mimetype` entry, `stack.xml` with the layers, one 8-bit sRGB PNG per pixel
// layer, `mergedimage.png` and `Thumbnails/thumbnail.png`, plus Photo's own
// `photo/document.json` for what OpenRaster has no word for (adjustment
// layers, masks, the whole-image adjustments). PNGs go through the
// PhotoImageCodec the app already has, so the format code runs and is tested
// on Linux. Recovery keeps the latest autosaved file. Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreRaster

/// A document's entries by path: "mimetype", "stack.xml",
/// "data/layer-3.png", "photo/masks/layer-3.png", "photo/document.json",
/// "mergedimage.png", "Thumbnails/thumbnail.png".
public struct PhotoPackage: Sendable, Equatable {
    public var files: [String: Data]
    public init(files: [String: Data]) { self.files = files }
}

/// Everything a document keeps, in 8-bit straight-alpha sRGB like an opened
/// file. A mask is stored as a gray image whose gray is the coverage.
public struct PhotoDocumentSnapshot: Sendable, Equatable {
    public var canvas: CanvasSize
    /// Top first, with kind, mask flags, blend, opacity and offset.
    public var layers: [PhotoLayer]
    /// One image per pixel layer, its own size.
    public var pixels: [PhotoLayer.ID: DecodedImage]
    /// One image per layer that has a mask, the layer's size.
    public var masks: [PhotoLayer.ID: DecodedImage]
    /// The Adjust tab's whole-image adjustments.
    public var adjustments: AdjustmentSettings
    public var selectedLayerID: PhotoLayer.ID?
    public init(canvas: CanvasSize, layers: [PhotoLayer], pixels: [PhotoLayer.ID: DecodedImage],
                masks: [PhotoLayer.ID: DecodedImage] = [:], adjustments: AdjustmentSettings = AdjustmentSettings(),
                selectedLayerID: PhotoLayer.ID? = nil) {
        self.canvas = canvas; self.layers = layers; self.pixels = pixels; self.masks = masks
        self.adjustments = adjustments; self.selectedLayerID = selectedLayerID
    }
}

/// Why a package didn't open; `message` is the alert's text.
public enum ArchiveError: Error, Equatable, Sendable {
    case notADocument
    case newerVersion(Int)
    case damaged(String)
    case tooLarge

    public var message: String {
        switch self {
        case .notADocument: "This file isn't a Photo document."
        case .newerVersion(let v): "This document was made by a newer Photo (format \(v)). Update Photo to open it."
        case .damaged(let detail): "This document is damaged: \(detail)."
        case .tooLarge: "This document is larger than Photo can open."
        }
    }
}

/// PV-1: write and read the layered document.
public protocol DocumentArchiving: PhotoUseCase {
    /// The format version this conformance writes; a newer one fails to open.
    var formatVersion: Int { get }
    /// The package for `snapshot`, every image through `codec` as PNG.
    func encode(_ snapshot: PhotoDocumentSnapshot, codec: any PhotoImageCodec) throws -> PhotoPackage
    /// The snapshot in `package`. Throws `ArchiveError` and nothing else.
    func decode(_ package: PhotoPackage, codec: any PhotoImageCodec) throws -> PhotoDocumentSnapshot
    /// The file's bytes: a zip whose first entry is `mimetype`, every entry
    /// stored (PNGs are compressed already). Pure Swift, so Linux tests it.
    func container(_ package: PhotoPackage) throws -> Data
    /// The entries of a file `container` wrote. Throws `ArchiveError`
    /// (`.notADocument` for a non-zip or another mimetype, `.damaged` for a
    /// compressed entry, which v2 doesn't read).
    func package(fromContainer data: Data) throws -> PhotoPackage
}

/// One autosaved document.
public struct RecoveryEntry: Sendable, Equatable {
    /// The document's name when it had one, for "Restore <name> from <time>?".
    public var documentName: String?
    /// Seconds since 1970 when it was written.
    public var savedAt: Double
    public var package: PhotoPackage
    public init(documentName: String?, savedAt: Double, package: PhotoPackage) {
        self.documentName = documentName; self.savedAt = savedAt; self.package = package
    }
}

/// PV-1: keep the latest autosave of the open document until it is saved or
/// closed cleanly. One entry per window; a newer write replaces it.
public protocol RecoveryStoring: PhotoUseCase {
    func write(_ entry: RecoveryEntry, window: String) throws
    /// The entries a crash left behind, newest first.
    func leftBehind() throws -> [RecoveryEntry]
    func discard(window: String) throws
    func discardAll() throws
}

/// What the open file is, so Save knows what to write.
public enum PhotoFileKind: Hashable, Sendable {
    /// A layered Photo document.
    case document
    /// A flat image file in a format Photo writes (PNG, JPEG).
    case image(ImageFormat)
    /// A flat file Photo reads but doesn't write (HEIC before PV-8): Save is Save As.
    case readOnly
}

/// What File > Save does now.
public enum SaveAction: Hashable, Sendable {
    /// Write the document over its file.
    case writeDocument
    /// Write the flat image over its file (one pixel layer, no masks or adjustment layers).
    case writeImage(ImageFormat)
    /// The open file is flat but the image has layers: ask "Keep layers?"
    /// (Save as Photo Document, or Flatten into the file's format).
    case askKeepLayers(ImageFormat)
    /// A new or read-only image: Save As.
    case saveAs
}
```

**PV-2 clipboard and merging** (`Contracts/EditContracts.swift`)

```swift
// Contracts/EditContracts.swift: Cut, Copy and Paste of pixels, and the layer
// commands that make or combine layers: Merge Down and Flatten (PV-2).
// Duplicate Layer needs no contract (it copies a layer and its tiles).
// Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreRaster

/// Pixels on their way to or from the pasteboard.
public struct ClipboardImage: Sendable, Equatable {
    public var image: DecodedImage
    /// Where on the canvas they were copied from; nil from another app.
    public var source: PixelRect?
    public init(image: DecodedImage, source: PixelRect?) {
        self.image = image; self.source = source
    }
}

/// PV-2: what Copy takes and where Paste puts it.
public protocol PixelClipboard: PhotoUseCase {
    /// The layer's pixels inside the selection, each weighted by `mask` when
    /// given (a feathered or lasso selection), cut to the bounds of what is
    /// not transparent. The whole layer when `selection` is nil. Nil when
    /// every pixel there is transparent ("Nothing to copy.").
    func copy(_ content: PlacedPixels, selection: PixelRect?, mask: Mask?) throws -> ClipboardImage?
    /// Where a pasted image lands: on its source rect when that still
    /// overlaps the canvas, else centered on `center` (the view's center in
    /// canvas pixels). Never off the canvas entirely.
    func placement(of image: ClipboardImage, canvas: CanvasSize, center: Mask.Point) -> PixelRect
}

/// PV-2: combine layers into one pixel layer.
public protocol LayerMerging: PhotoUseCase {
    /// `upper` composited onto `lower` with upper's blend mode, opacity and
    /// mask (an adjustment layer applies its adjustment), as one pixel layer
    /// that keeps lower's id, name, blend and opacity and covers both
    /// layers' bounds. Throws `PhotoRefusal("Merge Down needs a pixel layer
    /// below.")` when `lower` is an adjustment layer.
    func mergeDown(_ upper: LayerContent, onto lower: LayerContent) throws -> PlacedPixels
    /// Every visible layer, bottom-up, then `adjustments`, as one canvas-size
    /// layer: the same pixels Export writes before its format's background.
    /// Each layer sits at its own `offsetX`, `offsetY`. The workspace resets
    /// the whole-image adjustments to their defaults in the same step, since
    /// they are now in the pixels.
    func flatten(_ layers: [LayerContent], canvas: CanvasSize, adjustments: AdjustmentSettings) throws -> TiledPixels
}
```

**PV-3 crop** (`Contracts/CropContracts.swift`)

```swift
// Contracts/CropContracts.swift: a crop rectangle from typed numbers and an
// aspect lock (PV-3, #544). Every result lies inside the canvas, at least
// 1 x 1, and keeps the aspect when one is set. Linux-safe.
import CoreRaster

/// The crop's shape lock.
public enum CropAspect: Hashable, Sendable {
    case free
    /// The canvas's own width : height.
    case original
    /// Width : height, both at least 1. `portrait` swaps them.
    case ratio(Int, Int)

    public static let presets: [CropAspect] = [.free, .original, .ratio(1, 1), .ratio(3, 2), .ratio(4, 3), .ratio(16, 9)]

    public var title: String {
        switch self {
        case .free: "Free"
        case .original: "Original"
        case .ratio(let w, let h): "\(w):\(h)"
        }
    }
}

/// One of the four numbers the crop options show.
public enum CropField: Hashable, Sendable, CaseIterable {
    case x, y, width, height
}

/// PV-3: crop geometry.
public protocol CropSizing: PhotoUseCase {
    /// `crop` with `field` set to `value`, clamped to the canvas. With an
    /// aspect, setting width moves height (and the reverse) about the
    /// top-left corner; X and Y move without resizing.
    func setting(_ field: CropField, to value: Int, in crop: PixelRect, aspect: CropAspect,
                 canvas: CanvasSize) -> PixelRect
    /// The rect a crop drag from `anchor` to `point` makes, keeping `aspect`
    /// (the larger of the two sides wins) and clamped to the canvas.
    func dragged(from anchor: Mask.Point, to point: Mask.Point, aspect: CropAspect, canvas: CanvasSize) -> PixelRect
    /// `crop` reshaped to `aspect` about its center, as large as fits inside
    /// both it and the canvas; the largest centered rect when `crop` is nil.
    func applying(_ aspect: CropAspect, to crop: PixelRect?, canvas: CanvasSize) -> PixelRect
    /// `aspect` with its sides swapped (3:2 becomes 2:3); free and original stay.
    func swapped(_ aspect: CropAspect, canvas: CanvasSize) -> CropAspect
}
```

**PV-5 selections and masks** (`Contracts/SelectionContracts.swift`)

```swift
// Contracts/SelectionContracts.swift: selections as coverage masks and layer
// masks (PV-5, #421). A selection is a canvas-size CoreRaster Mask; a
// rectangle selection stays pixel-exact (coverage 0 or 1). A layer mask is a
// buffer the layer's size whose gray (red channel) is the coverage, alpha
// always 1, so the brush paints black to hide and white to reveal and tile
// undo keeps its tiles (PhotoHistory's mask-tiles step). Linux-safe.
import CoreRaster

/// What a selection drag draws, in canvas pixels.
public enum SelectionShape: Sendable, Equatable {
    case rectangle(PixelRect)
    case ellipse(PixelRect)
    /// A freehand outline, closed from the last point to the first.
    case lasso([Mask.Point])
}

/// How a new shape meets the selection there is: Shift adds, Option subtracts.
public enum SelectionCombine: Hashable, Sendable {
    case replace, add, subtract

    public init(_ modifiers: DragModifiers) {
        self = modifiers.contains(.shift) ? .add : modifiers.contains(.option) ? .subtract : .replace
    }
}

/// PV-5: build and change the selection.
public protocol SelectionShaping: PhotoUseCase {
    /// The coverage of `shape` on a `canvas`-size mask, antialiased except
    /// for a rectangle. Throws `PhotoRefusal` for a lasso under 3 points.
    func mask(for shape: SelectionShape, canvas: CanvasSize) throws -> Mask
    /// `new` combined into `current`. Nil when nothing is left selected.
    func combine(_ current: Mask?, with new: Mask, _ mode: SelectionCombine) throws -> Mask?
    /// Everything not selected; the whole canvas when `mask` is nil.
    func inverted(_ mask: Mask?, canvas: CanvasSize) throws -> Mask?
    /// The edge softened over `radius` pixels (0...250); 0 returns `mask`.
    func feathered(_ mask: Mask, radius: Double) throws -> Mask
    /// The smallest whole-pixel rect holding every covered pixel; nil when empty.
    func bounds(of mask: Mask) -> PixelRect?
    /// The marching-ants outline: closed polylines along coverage 0.5, in
    /// canvas pixels, for the overlay.
    func outline(of mask: Mask) -> [[Mask.Point]]
}

/// PV-5: layer masks.
public protocol LayerMasking: PhotoUseCase {
    /// A mask for a layer at `layerBounds` (canvas pixels): the selection's
    /// coverage as gray where it overlaps, black elsewhere; all white (reveal all) when
    /// `selection` is nil.
    func mask(from selection: Mask?, layerBounds: PixelRect) throws -> TiledPixels
    /// `pixels` with every alpha multiplied by the mask's gray: Apply Mask.
    func applying(_ mask: TiledPixels, to pixels: TiledPixels) throws -> TiledPixels
    /// `region`, a part of the layer at `origin` in layer pixels, multiplied
    /// by the mask there: what the renderer composites. Equals `region` for
    /// an all-1 mask, bit for bit.
    func masked(_ region: PixelBuffer, at origin: (x: Int, y: Int), by mask: TiledPixels) throws -> PixelBuffer
}

/// The Marquee tool's options.
public enum SelectionShapeKind: String, Hashable, Sendable, CaseIterable {
    case rectangle, ellipse, lasso
}

public struct SelectionOptions: Hashable, Sendable {
    public var shape: SelectionShapeKind
    /// Pixels, 0...250, applied to each new shape.
    public var feather: Double
    public init(shape: SelectionShapeKind = .rectangle, feather: Double = 0) {
        self.shape = shape; self.feather = feather
    }
}
```

**PV-6 adjustment layers, PV-7 transform** (`Contracts/LayerContracts.swift`)

```swift
// Contracts/LayerContracts.swift: adjustment layers (PV-6, #580) and the
// free transform and flips (PV-7). Linux-safe.
import CoreRaster

/// PV-6: an adjustment in the stack changes the layers under it.
public protocol AdjustmentLayering: PhotoUseCase {
    /// The sections an adjustment layer can hold: exposure, levels, curves
    /// and hue/saturation (blur reads neighbours, so it stays whole-image).
    var kinds: [AdjustmentKind] { get }
    /// `below` (the stack composited so far, a region of the canvas) with
    /// `settings`' enabled sections applied, mixed back by `opacity`,
    /// `blendMode` and `mask` (the same region of the layer mask, coverage as gray; nil for
    /// none). With opacity 1, normal blend and no mask, equals
    /// `settings` applied to `below` bit for bit.
    func applying(_ settings: AdjustmentSettings, to below: PixelBuffer, opacity: Double,
                  blendMode: BlendMode, mask: PixelBuffer?) throws -> PixelBuffer
}

/// A handle of the transform box.
public enum TransformHandle: Hashable, Sendable, CaseIterable {
    case topLeft, top, topRight, right, bottomRight, bottom, bottomLeft, left
    /// Inside the box: move.
    case inside
    /// Just outside a corner: rotate.
    case rotate
}

/// A layer's pending transform: scale about the box's top-left, then turn
/// clockwise about the box's center, then move.
public struct LayerTransform: Hashable, Sendable {
    public var scaleX: Double
    public var scaleY: Double
    public var degrees: Double
    public var dx: Double
    public var dy: Double
    public init(scaleX: Double = 1, scaleY: Double = 1, degrees: Double = 0, dx: Double = 0, dy: Double = 0) {
        self.scaleX = scaleX; self.scaleY = scaleY; self.degrees = degrees; self.dx = dx; self.dy = dy
    }
    public static let identity = LayerTransform()
}

/// Edit > Free Transform in progress on one layer.
public struct TransformDraft: Hashable, Sendable {
    public var layerID: PhotoLayer.ID
    /// The layer's bounds (or the selection's, when one is set) before the transform.
    public var box: PixelRect
    public var transform: LayerTransform
    public init(layerID: PhotoLayer.ID, box: PixelRect, transform: LayerTransform = .identity) {
        self.layerID = layerID; self.box = box; self.transform = transform
    }
}

public enum FlipAxis: Hashable, Sendable {
    case horizontal, vertical
}

/// PV-7: free transform and flips.
public protocol LayerTransforming: PhotoUseCase {
    /// The handle under `point` (canvas pixels) within `tolerance` canvas
    /// pixels (the app passes 6 pt divided by zoom); nil outside the box.
    func handle(at point: Mask.Point, in draft: TransformDraft, tolerance: Double) -> TransformHandle?
    /// `draft` after dragging `handle` from `start` to `point`: a side or
    /// corner scales with the opposite side fixed (Shift keeps the ratio,
    /// Option scales about the center), inside moves, rotate turns (Shift
    /// snaps to 15 degrees). Scale never reaches 0 or flips sign by a drag.
    func dragged(_ draft: TransformDraft, handle: TransformHandle, from start: Mask.Point,
                 to point: Mask.Point, modifiers: DragModifiers) -> TransformDraft
    /// The four box corners after the transform, clockwise from top-left,
    /// for the overlay.
    func corners(of draft: TransformDraft) -> [Mask.Point]
    /// The layer's pixels with the transform applied (lanczos3), placed at
    /// their new bounds. The identity gives back `content` bit for bit.
    func applied(_ draft: TransformDraft, to content: PlacedPixels) throws -> PlacedPixels
    /// `content` mirrored across its own center line, exactly (no filtering);
    /// twice gives back the input bit for bit.
    func flipped(_ content: PlacedPixels, _ axis: FlipAxis) throws -> PlacedPixels
}
```

**PV-8 export size, PV-9 eyedropper** (`Contracts/OutputContracts.swift`)

```swift
// Contracts/OutputContracts.swift: export at a size (PV-8) and the
// eyedropper's sample (PV-9). Linux-safe.
import CoreRaster

/// How big Export writes the image.
public enum ExportSize: Hashable, Sendable {
    /// 1...400 percent of the canvas.
    case percent(Double)
    /// The longer side in pixels, 1...16384, the other side in proportion.
    case longestSide(Int)
}

/// The Export sheet's choices.
public struct ExportOptions: Hashable, Sendable {
    public var format: ImageFormat
    /// 0...1, for the formats that take one (JPEG, HEIC).
    public var quality: Double
    public var size: ExportSize
    public init(format: ImageFormat = .png, quality: Double = 0.9, size: ExportSize = .percent(100)) {
        self.format = format; self.quality = quality; self.size = size
    }
}

/// PV-8: the size Export writes.
public protocol ExportSizing: PhotoUseCase {
    /// The output size for `canvas` at `size`, each side rounded and at
    /// least 1. Throws `PhotoRefusal("Export is limited to 16384 pixels a
    /// side.")` past `PhotoWorkspace.maxSide`.
    func outputSize(for canvas: CanvasSize, _ size: ExportSize) throws -> CanvasSize
    /// `image` resampled to `size` (lanczos3 down, bilinear up); `image`
    /// itself when the size is unchanged.
    func resized(_ image: DecodedImage, to size: CanvasSize) throws -> DecodedImage
}

/// How many pixels the eyedropper averages.
public enum SampleSize: Int, Hashable, Sendable, CaseIterable {
    case point = 1, threeByThree = 3, fiveByFive = 5

    public var title: String {
        switch self {
        case .point: "Point"
        case .threeByThree: "3 × 3"
        case .fiveByFive: "5 × 5"
        }
    }
}

/// A sampled color, 8-bit sRGB like ToolOptions' color.
public struct SampledColor: Hashable, Sendable {
    public var red: UInt8
    public var green: UInt8
    public var blue: UInt8
    public init(red: UInt8, green: UInt8, blue: UInt8) {
        self.red = red; self.green = green; self.blue = blue
    }
}

/// PV-9: the eyedropper.
public protocol ColorSampling: PhotoUseCase {
    /// The mean color of the `size` x `size` square centered on (x, y) in
    /// `picture` (the composited image around the point, with the point at
    /// `center` in it), over the pixels that are inside it and not fully
    /// transparent, straight alpha, encoded to sRGB. Nil when there are none.
    func sample(_ picture: PixelBuffer, center: (x: Int, y: Int), size: SampleSize) -> SampledColor?
}
```

### 5.2 Services and fakes

`Sources/PhotoModel/PhotoServices.swift` (PV-0). `.live` is the workspace's
default, so a test or a window that forgets to choose still runs the real
code. It reads each member from its feature's file in `Live/`, which returns
a `NotBuilt` stand-in (`unavailableHelp` = "Not built yet (PV-n).") until the
feature replaces it. `.fake` makes new fake instances on every read, so no
two workspaces (or two parallel tests) share a fake's state.
`LiveServicesTests` (PV-0) fails when a member of `.live` is a `Fake` type,
and lists which are still `NotBuilt`.

```swift
// PhotoServices.swift: one value per v2 use case, the seam between the
// window and the logic. `.fake` runs every contract on its fake, so views and
// journeys are built before the logic (`-PhotoFixture`). `.live` takes each
// member from its Live file, where a feature that isn't built yet returns
// its NotBuilt stand-in, whose `unavailableHelp` disables the controls that
// need it. Linux-safe.
public struct PhotoServices: Sendable {
    public var archive: any DocumentArchiving
    public var recovery: any RecoveryStoring
    public var clipboard: any PixelClipboard
    public var merging: any LayerMerging
    public var crop: any CropSizing
    public var selection: any SelectionShaping
    public var masking: any LayerMasking
    public var adjustmentLayers: any AdjustmentLayering
    public var transform: any LayerTransforming
    public var exportSizing: any ExportSizing
    public var sampling: any ColorSampling

    public init(archive: any DocumentArchiving, recovery: any RecoveryStoring, clipboard: any PixelClipboard,
                merging: any LayerMerging, crop: any CropSizing, selection: any SelectionShaping,
                masking: any LayerMasking, adjustmentLayers: any AdjustmentLayering,
                transform: any LayerTransforming, exportSizing: any ExportSizing, sampling: any ColorSampling) {
        self.archive = archive; self.recovery = recovery; self.clipboard = clipboard; self.merging = merging
        self.crop = crop; self.selection = selection; self.masking = masking
        self.adjustmentLayers = adjustmentLayers; self.transform = transform
        self.exportSizing = exportSizing; self.sampling = sampling
    }

    /// Every use case on its fake: deterministic, instant, no file system.
    /// New instances on every read, so no two workspaces share a fake's state.
    public static var fake: PhotoServices {
        PhotoServices(
            archive: FakeArchive(), recovery: FakeRecovery(), clipboard: FakeClipboard(), merging: FakeMerging(),
            crop: FakeCrop(), selection: FakeSelection(), masking: FakeMasking(),
            adjustmentLayers: FakeAdjustmentLayers(), transform: FakeTransform(), exportSizing: FakeExportSizing(),
            sampling: FakeSampling())
    }

    /// Every use case on its live conformance, each from its feature's file
    /// in `Live/` (a NotBuilt stand-in until the feature lands). The
    /// workspace's default.
    public static var live: PhotoServices {
        PhotoServices(
            archive: LiveDocuments.archive(), recovery: LiveDocuments.recovery(), clipboard: LiveEdit.clipboard(),
            merging: LiveEdit.merging(), crop: LiveCrop.make(), selection: LiveSelection.selection(),
            masking: LiveSelection.masking(), adjustmentLayers: LiveAdjustmentLayers.make(),
            transform: LiveTransform.make(), exportSizing: LiveExportSizing.make(), sampling: LiveSampling.make())
    }
}
```

The fakes, `Sources/PhotoModel/Fakes/PhotoFakes.swift` (PV-0; the first PR
may split it per contract to stay under 400 lines). Each does the least
that still changes something a journey can see:

```swift
// Fakes/PhotoFakes.swift: a fake per v2 contract, for building views and
// journeys before the logic. Each is deterministic and does the least that
// still changes something a journey can see, so no control looks dead on
// fakes. None reads the file system, and none shares state with another
// instance: `PhotoServices.fake` makes new ones on every read, so parallel
// tests never see each other's documents. The real behavior is the Live
// types'; a test fails if `.live` holds any Fake (LiveServicesTests).
// Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreRaster
import Synchronization

/// Writes a one-line manifest and each image as raw bytes, no codec, and
/// gives back the last snapshot this instance wrote.
public final class FakeArchive: DocumentArchiving {
    private let last = Mutex<PhotoDocumentSnapshot?>(nil)
    public var unavailableHelp: String? { nil }
    public var formatVersion: Int { 1 }
    public init() {}

    public func encode(_ snapshot: PhotoDocumentSnapshot, codec: any PhotoImageCodec) throws -> PhotoPackage {
        var files: [String: Data] = ["document.txt": Data("fake \(snapshot.canvas.width)x\(snapshot.canvas.height)".utf8)]
        for (id, image) in snapshot.pixels { files["layers/\(id).raw"] = Data(image.rgba8) }
        last.withLock { $0 = snapshot }
        return PhotoPackage(files: files)
    }

    public func decode(_ package: PhotoPackage, codec: any PhotoImageCodec) throws -> PhotoDocumentSnapshot {
        guard package.files["document.txt"] != nil, let snapshot = last.withLock({ $0 }) else {
            throw ArchiveError.notADocument
        }
        return snapshot
    }

    public func container(_ package: PhotoPackage) throws -> Data {
        package.files["document.txt"] ?? Data()
    }

    public func package(fromContainer data: Data) throws -> PhotoPackage {
        guard String(decoding: data, as: UTF8.self).hasPrefix("fake ") else { throw ArchiveError.notADocument }
        return PhotoPackage(files: ["document.txt": data])
    }
}

/// Keeps entries in memory per window.
public final class FakeRecovery: RecoveryStoring {
    private let entries = Mutex<[String: RecoveryEntry]>([:])
    public var unavailableHelp: String? { nil }
    public init() {}
    public func write(_ entry: RecoveryEntry, window: String) throws { entries.withLock { $0[window] = entry } }
    public func leftBehind() throws -> [RecoveryEntry] {
        entries.withLock { $0.values.sorted { $0.savedAt > $1.savedAt } }
    }
    public func discard(window: String) throws { _ = entries.withLock { $0.removeValue(forKey: window) } }
    public func discardAll() throws { entries.withLock { $0 = [:] } }
}

/// Copies a 64 x 64 red square; pastes at the center.
public struct FakeClipboard: PixelClipboard {
    public var unavailableHelp: String? { nil }
    public init() {}
    public func copy(_ content: PlacedPixels, selection: PixelRect?, mask: Mask?) throws -> ClipboardImage? {
        let red: [UInt8] = [255, 59, 48, 255]
        let bytes = Array((0..<(64 * 64)).map { _ in red }.joined())
        return ClipboardImage(image: DecodedImage(rgba8: bytes, width: 64, height: 64), source: selection)
    }
    public func placement(of image: ClipboardImage, canvas: CanvasSize, center: Mask.Point) -> PixelRect {
        PixelRect(x: (canvas.width - image.image.width) / 2, y: (canvas.height - image.image.height) / 2,
                  width: image.image.width, height: image.image.height)
    }
}

/// Merge Down keeps the lower layer's pixels; Flatten keeps the bottom layer's.
public struct FakeMerging: LayerMerging {
    public var unavailableHelp: String? { nil }
    public init() {}
    public func mergeDown(_ upper: LayerContent, onto lower: LayerContent) throws -> PlacedPixels {
        guard let pixels = lower.pixels else { throw PhotoRefusal("Merge Down needs a pixel layer below.") }
        return PlacedPixels(pixels: pixels, x: lower.layer.offsetX, y: lower.layer.offsetY)
    }
    public func flatten(_ layers: [LayerContent], canvas: CanvasSize, adjustments: AdjustmentSettings) throws
        -> TiledPixels
    {
        if let bottom = layers.last?.pixels { return bottom }
        return try TiledPixels(width: canvas.width, height: canvas.height)
    }
}

/// Free aspect only; numbers clamp to the canvas.
public struct FakeCrop: CropSizing {
    public var unavailableHelp: String? { nil }
    public init() {}
    public func setting(_ field: CropField, to value: Int, in crop: PixelRect, aspect: CropAspect,
                        canvas: CanvasSize) -> PixelRect {
        var r = crop
        switch field {
        case .x: r.x = value
        case .y: r.y = value
        case .width: r.width = value
        case .height: r.height = value
        }
        return r.intersection(canvas.rect) ?? crop
    }
    public func dragged(from anchor: Mask.Point, to point: Mask.Point, aspect: CropAspect, canvas: CanvasSize)
        -> PixelRect
    {
        PixelRect(from: anchor, to: point).intersection(canvas.rect) ?? canvas.rect
    }
    public func applying(_ aspect: CropAspect, to crop: PixelRect?, canvas: CanvasSize) -> PixelRect {
        crop ?? canvas.rect
    }
    public func swapped(_ aspect: CropAspect, canvas: CanvasSize) -> CropAspect { aspect }
}

/// Every shape selects its bounding rectangle.
public struct FakeSelection: SelectionShaping {
    public var unavailableHelp: String? { nil }
    public init() {}
    public func mask(for shape: SelectionShape, canvas: CanvasSize) throws -> Mask {
        let rect: PixelRect
        switch shape {
        case .rectangle(let r), .ellipse(let r): rect = r
        case .lasso(let points):
            guard let first = points.first else { throw PhotoRefusal("Draw around the area to select.") }
            rect = points.reduce(PixelRect(from: first, to: first)) { $0.union(PixelRect(from: $1, to: $1)) }
        }
        return try Mask.rectangle(width: canvas.width, height: canvas.height, x: Double(rect.x), y: Double(rect.y),
                                  w: Double(rect.width), h: Double(rect.height))
    }
    public func combine(_ current: Mask?, with new: Mask, _ mode: SelectionCombine) throws -> Mask? {
        guard var current, mode != .replace else { return mode == .subtract ? current : new }
        if mode == .add { try current.add(new) } else { try current.subtract(new) }
        return current
    }
    public func inverted(_ mask: Mask?, canvas: CanvasSize) throws -> Mask? {
        guard var mask else { return try Mask(width: canvas.width, height: canvas.height, fill: 1) }
        mask.invert()
        return mask
    }
    public func feathered(_ mask: Mask, radius: Double) throws -> Mask { mask }
    public func bounds(of mask: Mask) -> PixelRect? {
        mask.area > 0 ? PixelRect(x: 0, y: 0, width: mask.width, height: mask.height) : nil
    }
    public func outline(of mask: Mask) -> [[Mask.Point]] {
        guard let b = bounds(of: mask) else { return [] }
        let (x0, y0, x1, y1) = (Double(b.x), Double(b.y), Double(b.maxX), Double(b.maxY))
        return [[.init(x: x0, y: y0), .init(x: x1, y: y0), .init(x: x1, y: y1), .init(x: x0, y: y1)]]
    }
}

/// Masks reveal everything; nothing is hidden.
public struct FakeMasking: LayerMasking {
    public var unavailableHelp: String? { nil }
    public init() {}
    public func mask(from selection: Mask?, layerBounds: PixelRect) throws -> TiledPixels {
        try TiledPixels(width: layerBounds.width, height: layerBounds.height, fill: RGBA(r: 1, g: 1, b: 1, a: 1))
    }
    public func applying(_ mask: TiledPixels, to pixels: TiledPixels) throws -> TiledPixels { pixels }
    public func masked(_ region: PixelBuffer, at origin: (x: Int, y: Int), by mask: TiledPixels) throws
        -> PixelBuffer
    { region }
}

/// An adjustment layer brightens by one stop, whatever its settings.
public struct FakeAdjustmentLayers: AdjustmentLayering {
    public var unavailableHelp: String? { nil }
    public var kinds: [AdjustmentKind] { [.exposure, .levels, .curves, .hueSaturation] }
    public init() {}
    public func applying(_ settings: AdjustmentSettings, to below: PixelBuffer, opacity: Double,
                         blendMode: BlendMode, mask: PixelBuffer?) throws -> PixelBuffer {
        try below.exposure(stops: 1)
    }
}

/// Only moves: any handle drag translates the box; applying moves the pixels.
public struct FakeTransform: LayerTransforming {
    public var unavailableHelp: String? { nil }
    public init() {}
    public func handle(at point: Mask.Point, in draft: TransformDraft, tolerance: Double) -> TransformHandle? {
        .inside
    }
    public func dragged(_ draft: TransformDraft, handle: TransformHandle, from start: Mask.Point,
                        to point: Mask.Point, modifiers: DragModifiers) -> TransformDraft {
        var next = draft
        next.transform.dx += point.x - start.x
        next.transform.dy += point.y - start.y
        return next
    }
    public func corners(of draft: TransformDraft) -> [Mask.Point] {
        let b = draft.box, t = draft.transform
        let (x0, y0) = (Double(b.x) + t.dx, Double(b.y) + t.dy)
        let (x1, y1) = (x0 + Double(b.width), y0 + Double(b.height))
        return [.init(x: x0, y: y0), .init(x: x1, y: y0), .init(x: x1, y: y1), .init(x: x0, y: y1)]
    }
    public func applied(_ draft: TransformDraft, to content: PlacedPixels) throws -> PlacedPixels {
        let t = draft.transform
        guard t.dx.isFinite, t.dy.isFinite, abs(t.dx) < 1e6, abs(t.dy) < 1e6 else { return content }
        return PlacedPixels(pixels: content.pixels, x: content.x + Int(t.dx.rounded()),
                            y: content.y + Int(t.dy.rounded()))
    }
    public func flipped(_ content: PlacedPixels, _ axis: FlipAxis) throws -> PlacedPixels { content }
}

/// Percent sizes only; a resize returns a gray image of the asked size.
public struct FakeExportSizing: ExportSizing {
    public var unavailableHelp: String? { nil }
    public init() {}
    public func outputSize(for canvas: CanvasSize, _ size: ExportSize) throws -> CanvasSize {
        guard case .percent(let p) = size, p.isFinite, p > 0, p <= 400 else { return canvas }
        return CanvasSize(width: max(Int((Double(canvas.width) * p / 100).rounded()), 1),
                          height: max(Int((Double(canvas.height) * p / 100).rounded()), 1))
    }
    public func resized(_ image: DecodedImage, to size: CanvasSize) throws -> DecodedImage {
        DecodedImage(rgba8: [UInt8](repeating: 128, count: size.width * size.height * 4),
                     width: size.width, height: size.height)
    }
}

/// Always samples the fixtures' sun yellow.
public struct FakeSampling: ColorSampling {
    public var unavailableHelp: String? { nil }
    public init() {}
    public func sample(_ picture: PixelBuffer, center: (x: Int, y: Int), size: SampleSize) -> SampledColor? {
        SampledColor(red: 255, green: 204, blue: 0)
    }
}
```

The stand-ins, `Sources/PhotoModel/Live/NotBuilt.swift` (PV-0), and the
shape of each feature's `Live/` file as PV-0 creates it (one enum per file:
`LiveDocuments.swift`, `LiveEdit.swift`, `LiveCrop.swift`,
`LiveSelection.swift`, `LiveAdjustmentLayers.swift`, `LiveTransform.swift`,
`LiveExportSizing.swift`, `LiveSampling.swift`; shown here together):

```swift
// Live/NotBuilt.swift: the stand-ins `.live` holds for a use case whose
// feature hasn't landed. Every call refuses with the same text its
// `unavailableHelp` gives, so a control that reaches one anyway shows why.
// Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreRaster

struct NotBuilt: Sendable {
    let feature: String
    var help: String { "Not built yet (\(feature))." }
    func refuse() -> PhotoRefusal { PhotoRefusal(help) }
}

struct NotBuiltArchive: DocumentArchiving {
    let not = NotBuilt(feature: "PV-1")
    var unavailableHelp: String? { not.help }
    var formatVersion: Int { 0 }
    func encode(_ snapshot: PhotoDocumentSnapshot, codec: any PhotoImageCodec) throws -> PhotoPackage { throw not.refuse() }
    func decode(_ package: PhotoPackage, codec: any PhotoImageCodec) throws -> PhotoDocumentSnapshot { throw not.refuse() }
    func container(_ package: PhotoPackage) throws -> Data { throw not.refuse() }
    func package(fromContainer data: Data) throws -> PhotoPackage { throw not.refuse() }
}

struct NotBuiltRecovery: RecoveryStoring {
    let not = NotBuilt(feature: "PV-1")
    var unavailableHelp: String? { not.help }
    func write(_ entry: RecoveryEntry, window: String) throws { throw not.refuse() }
    func leftBehind() throws -> [RecoveryEntry] { [] }
    func discard(window: String) throws {}
    func discardAll() throws {}
}

struct NotBuiltClipboard: PixelClipboard {
    let not = NotBuilt(feature: "PV-2")
    var unavailableHelp: String? { not.help }
    func copy(_ content: PlacedPixels, selection: PixelRect?, mask: Mask?) throws -> ClipboardImage? { throw not.refuse() }
    func placement(of image: ClipboardImage, canvas: CanvasSize, center: Mask.Point) -> PixelRect {
        PixelRect(x: 0, y: 0, width: image.image.width, height: image.image.height)
    }
}

struct NotBuiltMerging: LayerMerging {
    let not = NotBuilt(feature: "PV-2")
    var unavailableHelp: String? { not.help }
    func mergeDown(_ upper: LayerContent, onto lower: LayerContent) throws -> PlacedPixels { throw not.refuse() }
    func flatten(_ layers: [LayerContent], canvas: CanvasSize, adjustments: AdjustmentSettings) throws -> TiledPixels {
        throw not.refuse()
    }
}

struct NotBuiltCrop: CropSizing {
    let not = NotBuilt(feature: "PV-3")
    var unavailableHelp: String? { not.help }
    func setting(_ field: CropField, to value: Int, in crop: PixelRect, aspect: CropAspect, canvas: CanvasSize) -> PixelRect { crop }
    func dragged(from anchor: Mask.Point, to point: Mask.Point, aspect: CropAspect, canvas: CanvasSize) -> PixelRect {
        PixelRect(from: anchor, to: point).intersection(canvas.rect) ?? canvas.rect
    }
    func applying(_ aspect: CropAspect, to crop: PixelRect?, canvas: CanvasSize) -> PixelRect { crop ?? canvas.rect }
    func swapped(_ aspect: CropAspect, canvas: CanvasSize) -> CropAspect { aspect }
}

struct NotBuiltSelection: SelectionShaping {
    let not = NotBuilt(feature: "PV-5")
    var unavailableHelp: String? { not.help }
    func mask(for shape: SelectionShape, canvas: CanvasSize) throws -> Mask { throw not.refuse() }
    func combine(_ current: Mask?, with new: Mask, _ mode: SelectionCombine) throws -> Mask? { throw not.refuse() }
    func inverted(_ mask: Mask?, canvas: CanvasSize) throws -> Mask? { throw not.refuse() }
    func feathered(_ mask: Mask, radius: Double) throws -> Mask { throw not.refuse() }
    func bounds(of mask: Mask) -> PixelRect? { nil }
    func outline(of mask: Mask) -> [[Mask.Point]] { [] }
}

struct NotBuiltMasking: LayerMasking {
    let not = NotBuilt(feature: "PV-5")
    var unavailableHelp: String? { not.help }
    func mask(from selection: Mask?, layerBounds: PixelRect) throws -> TiledPixels { throw not.refuse() }
    func applying(_ mask: TiledPixels, to pixels: TiledPixels) throws -> TiledPixels { throw not.refuse() }
    func masked(_ region: PixelBuffer, at origin: (x: Int, y: Int), by mask: TiledPixels) throws -> PixelBuffer { region }
}

struct NotBuiltAdjustmentLayers: AdjustmentLayering {
    let not = NotBuilt(feature: "PV-6")
    var unavailableHelp: String? { not.help }
    var kinds: [AdjustmentKind] { [] }
    func applying(_ settings: AdjustmentSettings, to below: PixelBuffer, opacity: Double, blendMode: BlendMode,
                  mask: PixelBuffer?) throws -> PixelBuffer { below }
}

struct NotBuiltTransform: LayerTransforming {
    let not = NotBuilt(feature: "PV-7")
    var unavailableHelp: String? { not.help }
    func handle(at point: Mask.Point, in draft: TransformDraft, tolerance: Double) -> TransformHandle? { nil }
    func dragged(_ draft: TransformDraft, handle: TransformHandle, from start: Mask.Point, to point: Mask.Point,
                 modifiers: DragModifiers) -> TransformDraft { draft }
    func corners(of draft: TransformDraft) -> [Mask.Point] { [] }
    func applied(_ draft: TransformDraft, to content: PlacedPixels) throws -> PlacedPixels { throw not.refuse() }
    func flipped(_ content: PlacedPixels, _ axis: FlipAxis) throws -> PlacedPixels { throw not.refuse() }
}

struct NotBuiltExportSizing: ExportSizing {
    let not = NotBuilt(feature: "PV-8")
    var unavailableHelp: String? { not.help }
    func outputSize(for canvas: CanvasSize, _ size: ExportSize) throws -> CanvasSize { canvas }
    func resized(_ image: DecodedImage, to size: CanvasSize) throws -> DecodedImage { image }
}

struct NotBuiltSampling: ColorSampling {
    let not = NotBuilt(feature: "PV-9")
    var unavailableHelp: String? { not.help }
    func sample(_ picture: PixelBuffer, center: (x: Int, y: Int), size: SampleSize) -> SampledColor? { nil }
}
```

```swift
// Scratch stand-in for PV-0's eight Live/<X>.swift stubs, one enum per file in
// the real tree (LiveDocuments.swift, LiveEdit.swift, ...), each owned by its
// feature, which replaces the NotBuilt it returns.
enum LiveDocuments {
    static func archive() -> any DocumentArchiving { NotBuiltArchive() }
    static func recovery() -> any RecoveryStoring { NotBuiltRecovery() }
}
enum LiveEdit {
    static func clipboard() -> any PixelClipboard { NotBuiltClipboard() }
    static func merging() -> any LayerMerging { NotBuiltMerging() }
}
enum LiveCrop { static func make() -> any CropSizing { NotBuiltCrop() } }
enum LiveSelection {
    static func selection() -> any SelectionShaping { NotBuiltSelection() }
    static func masking() -> any LayerMasking { NotBuiltMasking() }
}
enum LiveAdjustmentLayers { static func make() -> any AdjustmentLayering { NotBuiltAdjustmentLayers() } }
enum LiveTransform { static func make() -> any LayerTransforming { NotBuiltTransform() } }
enum LiveExportSizing { static func make() -> any ExportSizing { NotBuiltExportSizing() } }
enum LiveSampling { static func make() -> any ColorSampling { NotBuiltSampling() } }
```

### 5.3 What each feature adds to the workspace

PV-0 adds the stored state (the only edit to `PhotoWorkspace.swift` and
`PhotoLayer.swift` in v2); each feature adds its methods in its own
extension file, named in the comment. These are the calls views make. The
bodies below are the stubs used to compile the signatures; each feature
writes the real ones.

Stored state added to `PhotoWorkspace` (and to its `==`, except `services`,
which isn't `Equatable`):

```swift
    // v2 state (PV-0). Each belongs to the extension file named; besides it,
    // start() resets them all, PhotoHistory restores masks and the selection on
    // undo, and PhotoStroke paints into a mask through paintTarget().
    /// The use cases (PhotoServices); `.live` in the app, `.fake` under -PhotoFixture.
    public internal(set) var services: PhotoServices = .live
    /// The selection's coverage when it isn't an exact rectangle (PhotoSelectionMask.swift).
    public internal(set) var selectionMask: Mask?
    /// The Marquee tool's shape and feather (PhotoSelectionMask.swift).
    public internal(set) var selectionOptions = SelectionOptions()
    /// Each masked layer's mask, its own size, coverage as gray, alpha 1 (PhotoMask.swift).
    public internal(set) var masks: [PhotoLayer.ID: TiledPixels] = [:]
    /// Brush and eraser paint on the selected layer's mask (PhotoMask.swift).
    public internal(set) var editsMask = false
    /// The crop's aspect lock (PhotoCropSize.swift).
    public internal(set) var cropAspect = CropAspect.free
    /// Free Transform in progress (PhotoTransform.swift).
    public internal(set) var transformDraft: TransformDraft?
    /// The eyedropper's sample size (PhotoEyedropper.swift).
    public internal(set) var sampleSize = SampleSize.point
    /// The Export sheet's last choices (PhotoExportOptions.swift).
    public internal(set) var exportOptions = ExportOptions()
    /// What the open file is, for Save (PhotoDocumentFile.swift).
    public internal(set) var fileKind: PhotoFileKind?
    /// The history step last saved, opened or created (`currentStepID`), so a
    /// new blank image and a just-opened file are clean; nil with no image.
    public internal(set) var savedStepID: Int?
    /// A one-line refusal or note for the status line ("Nothing to paste.");
    /// `clearStatus()` drops it (the window calls it 4 s later).
    public internal(set) var statusMessage: String?
```

Added to `PhotoLayer` (with `PhotoLayerKind` beside it) and to
`AdjustmentSettings` (`Equatable` becomes `Hashable`, so a layer can hold
settings):

```swift
    /// Pixels, or an adjustment applied to the layers below (PV-6).
    public internal(set) var kind = PhotoLayerKind.pixels
    /// Whether the layer has a mask in `PhotoWorkspace.masks` (PV-5).
    public internal(set) var hasMask = false
    /// A disabled mask is kept but not applied (Shift-click its badge).
    public internal(set) var isMaskEnabled = true

/// What a layer holds.
public enum PhotoLayerKind: Hashable, Sendable {
    case pixels
    case adjustment(AdjustmentSettings)
}
```

Changed in `PhotoHistory` (PV-0):

- a `.selection(PixelRect?, Mask?)` edit, so a selection change is one
  "Select" step (#421);
- `PhotoStack` keeps `masks` beside `pixels`, so every whole-stack step
  restores masks too;
- every recorded step gets an id from a counter that never repeats;
  `currentStepID` is the newest undo entry's id, or `baseStepID` with
  nothing to undo, and `baseStepID` (0 at the start) takes the id of each
  step the 50-step limit trims, as `baseName` does. The dirty marker
  compares `currentStepID` with `savedStepID`, so it stays right after an
  undo followed by a new edit, and after undoing everything past a trim
  (an index would not);
- a `.maskTiles(layer:, [Int: PixelBuffer])` step for mask paint;
- `apply(.layers)`'s guard (today `Set(list.map(\.id)) == Set(pixels.keys)`,
  `PhotoHistory.swift:139`) and the invariant at the top of
  `PhotoWorkspace.swift` change to "`pixels` holds one buffer per **pixel**
  layer", or the first adjustment layer would make every layer-list undo a
  no-op.

Also PV-0, so later features stay inside their files:

- `start()` resets every v2 field (selection mask, masks, `editsMask`,
  transform draft, status message, file kind) and sets `savedStepID` to the
  current step, so a just-opened file or a new blank image is clean (no
  prompt when it is closed untouched).
- Crop, Image Size, Rotate, Straighten and Delete Layer call
  `layerGeometryChanged(_:_:)` for each layer they change; PV-2 (Duplicate,
  Merge Down) and PV-7 (transform, flips) call it from their own files. It is
  a no-op until PV-5 fills it in `PhotoMask.swift` to keep each mask the size
  and place of its layer.
- `paintTarget()` refuses an adjustment layer with "Select an image layer in the Layers tab
  to paint on." (PJ-9) from the start, since PV-0 adds layer kinds.

The methods, by feature:

```swift
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreRaster

/// Where a paint stroke writes. A mask's coverage is its gray (red
/// channel), alpha always 1, so the brush paints black to hide and white to
/// reveal, the eraser paints white, and tile undo works as on pixels.
public enum PaintTarget: Hashable, Sendable {
    case pixels(PhotoLayer.ID)
    case mask(PhotoLayer.ID)
}

/// Where the Adjust tab's edits go (PV-6).
public enum AdjustTarget: Hashable, Sendable {
    case image
    case layer(PhotoLayer.ID, AdjustmentSettings)
}

// PV-0 (PhotoWorkspace.swift)
extension PhotoWorkspace {
    public func toolHelp(_ tool: PhotoTool) -> String? { nil }
    public init(services: PhotoServices) { self.init(); self.services = services }
    public mutating func clearStatus() { statusMessage = nil }
    /// Where brush, eraser, clone and heal write (PV-0, in PhotoStroke.swift):
    /// the selected layer's mask while `editsMask` and it has one, else its
    /// pixels; nil, with `statusMessage` "Select an image layer in the Layers tab to paint on.",
    /// on an adjustment layer without a mask target.
    public func paintTarget() -> PaintTarget? { selectedLayerID.map(PaintTarget.pixels) }
    /// One pointer event with its modifier keys and the canvas zoom (points
    /// per canvas pixel, for hit tolerances). Today's
    /// `drag(from:to:pressure:sampling:)` and `drags(_:)` stay as thin
    /// wrappers (`sampling` is `[.option]`, zoom 1), so the ~60 existing test
    /// calls compile unchanged; the window and StrokePacer call these.
    public mutating func drag(from start: Mask.Point, to point: Mask.Point, pressure: Double = 1,
                              modifiers: DragModifiers, zoom: Double = 1) {}
    /// A display frame's events at once, each with its modifiers.
    public mutating func drags(_ events: [(from: Mask.Point, to: Mask.Point, pressure: Double, modifiers: DragModifiers)],
                               zoom: Double = 1) {}
    /// Delete and Fill weight each pixel by the selection's coverage; Select
    /// All, Deselect and Apply Crop set or clear `selectionMask` too (PV-0
    /// routes them through PhotoSelectionMask.swift).
    func selectionCoverage(x: Int, y: Int) -> Float { 1 }
}

/// A geometry change every layer's extras (its mask) must follow (PV-0 calls
/// `layerGeometryChanged` from crop, Image Size, rotate, straighten, delete,
/// and PV-2 and PV-7 from their files; PV-5 fills it in PhotoMask.swift).
public enum LayerGeometryChange: Sendable {
    case cropped(PixelRect)
    case resized(scaleX: Double, scaleY: Double)
    case rotated(QuarterTurn)
    case straightened(degrees: Double, crop: PixelRect)
    case flippedCanvas(FlipAxis)
    case transformed(LayerTransform)
    case flipped(FlipAxis)
    case duplicated(from: PhotoLayer.ID)
    case removed
}

extension PhotoWorkspace {
    mutating func layerGeometryChanged(_ id: PhotoLayer.ID, _ change: LayerGeometryChange) {}
}

// PV-0 (PhotoHistory.swift): every recorded step gets a new id from a counter
// that never goes back or repeats; trimming the oldest steps keeps the ids.
extension PhotoWorkspace {
    /// The id of the step the image is at: the newest undo entry's, or
    /// `baseStepID` with nothing to undo. `baseStepID` is 0 at "New Image" or
    /// "Open" and takes the id of each step the 50-step limit trims, the way
    /// `baseName` does, so undoing everything after a trim still reads dirty.
    public var currentStepID: Int { 0 }
}

// PV-1 (PhotoDocumentFile.swift, PhotoRecovery.swift)
extension PhotoWorkspace {
    public var isDirty: Bool { canvas != nil && savedStepID != currentStepID }
    public var saveAction: SaveAction { .saveAs }
    public func snapshot() throws -> PhotoDocumentSnapshot { throw PhotoRefusal("") }
    public func documentPackage(codec: any PhotoImageCodec) throws -> PhotoPackage { PhotoPackage(files: [:]) }
    public mutating func openDocument(_ package: PhotoPackage, name: String, codec: any PhotoImageCodec) throws {}
    public mutating func didSave(as name: String, kind: PhotoFileKind) {}
    public static let autosaveDelay: Double = 30
    public func autosaveDue(lastEdit: Double, lastAutosave: Double?, now: Double) -> Bool { false }
    public func recoveryEntry(now: Double, codec: any PhotoImageCodec) throws -> RecoveryEntry? { nil }
    public mutating func restore(_ entry: RecoveryEntry, codec: any PhotoImageCodec) throws {}
}

// PV-2 (PhotoClipboard.swift, PhotoLayerOps.swift)
extension PhotoWorkspace {
    public var copyHelp: String? { nil }
    public func copySelection() throws -> ClipboardImage? { nil }
    public mutating func cutSelection() throws -> ClipboardImage? { nil }
    public mutating func paste(_ image: ClipboardImage, viewCenter: Mask.Point) throws {}
    public var duplicateHelp: String? { nil }
    public mutating func duplicateSelectedLayer() {}
    public var mergeDownHelp: String? { nil }
    public mutating func mergeDown() throws {}
    public var flattenHelp: String? { nil }
    public mutating func flattenImage() throws {}
}

// PV-3 (PhotoCropSize.swift)
extension PhotoWorkspace {
    public var cropFieldsEnabled: Bool { false }
    public mutating func setCropField(_ field: CropField, to value: Int) {}
    public mutating func setCropAspect(_ aspect: CropAspect) {}
    public mutating func swapCropAspect() {}
}

// PV-5 (PhotoSelectionMask.swift, PhotoMask.swift)
extension PhotoWorkspace {
    public mutating func setSelectionShape(_ shape: SelectionShapeKind) {}
    public mutating func setFeather(_ radius: Double) {}
    public mutating func invertSelection() {}
    public var selectionOutline: [[Mask.Point]] { [] }
    public var maskHelp: String? { nil }
    public mutating func addMaskFromSelection() throws {}
    public mutating func deleteMask() {}
    public mutating func applyMask() throws {}
    public mutating func toggleMaskEnabled() {}
    public mutating func setEditsMask(_ on: Bool) {}
}

// PV-6 (PhotoAdjustmentLayer.swift)
extension PhotoWorkspace {
    public var adjustTarget: AdjustTarget { .image }
    public mutating func addAdjustmentLayer(_ kind: AdjustmentKind) {}
    public mutating func adjustLayer(_ id: PhotoLayer.ID, _ edit: AdjustmentEdit) {}
}

// PV-7 (PhotoTransform.swift)
/// A free transform worked out by `transformed()`, waiting for `commitTransform`.
public struct TransformResult: Sendable {
    public let layerID: PhotoLayer.ID
    public let placed: PlacedPixels
    /// The workspace revision it was worked out from.
    public let revision: Int
}

extension PhotoWorkspace {
    public var transformHelp: String? { nil }
    public mutating func beginTransform() throws {}
    public mutating func setTransform(_ transform: LayerTransform) {}
    public var transformCorners: [Mask.Point] { [] }
    /// Works the transform out without changing anything, off the main actor
    /// (like `straightened`); nil with no transform in progress.
    public func transformed() throws -> TransformResult? { nil }
    /// Applies `result` as one "Free Transform" step unless the image changed
    /// meanwhile; returns whether it did.
    public mutating func commitTransform(_ result: TransformResult) -> Bool { false }
    public mutating func cancelTransform() {}
    public mutating func flipLayer(_ axis: FlipAxis) throws {}
    public mutating func flipCanvas(_ axis: FlipAxis) throws {}
}

// PV-8 (PhotoExportOptions.swift)
extension PhotoWorkspace {
    public mutating func setExportOptions(_ options: ExportOptions) {}
    public func exportSize(_ options: ExportOptions) throws -> CanvasSize { CanvasSize(width: 1, height: 1) }
    public func export(_ options: ExportOptions, codec: any PhotoImageCodec) async throws -> Data { Data() }
}

// PV-9 (PhotoEyedropper.swift)
extension PhotoWorkspace {
    public mutating func setSampleSize(_ size: SampleSize) {}
    @discardableResult
    public mutating func sample(at point: Mask.Point) -> Bool { false }
}
```

### 5.4 Which contract each journey is built from

| Journey | Contracts | Workspace calls |
|---|---|---|
| PJ-1 save and reopen | `DocumentArchiving` (`encode`, `container`, `package(fromContainer:)`, `decode`) | `saveAction`, `documentPackage(codec:)`, `didSave(as:kind:)`, `openDocument(_:name:codec:)`, `isDirty` (`savedStepID != currentStepID`) |
| PJ-2 unsaved prompt, Open Recent | – (AppKit's recent list) | `isDirty` |
| PJ-3 restore after a crash | `RecoveryStoring`, `DocumentArchiving` | `autosaveDue(lastEdit:lastAutosave:now:)`, `recoveryEntry(now:codec:)`, `restore(_:codec:)` |
| PJ-4 bad documents | `DocumentArchiving` (`ArchiveError.message`) | `openDocument` |
| PJ-5 copy, cut, paste | `PixelClipboard` | `copyHelp`, `copySelection()`, `cutSelection()`, `paste(_:viewCenter:)` |
| PJ-6 paste from another app | `PixelClipboard.placement` | `paste(_:viewCenter:)` (opens a new image with none open) |
| PJ-7 duplicate, merge, flatten | `LayerMerging` | `duplicateSelectedLayer()`, `mergeDownHelp`, `mergeDown()`, `flattenHelp`, `flattenImage()` |
| PJ-8 typed crop | `CropSizing` | `cropFieldsEnabled`, `setCropField(_:to:)`, `setCropAspect(_:)`, `swapCropAspect()`, `drag` (crop) |
| PJ-9 adjustment layer | `AdjustmentLayering` | `addAdjustmentLayer(_:)`, `adjustTarget`, `adjustLayer(_:_:)`, the existing layer methods |
| PJ-10 history | – (engine-direct) | `historySteps`, `historyIndex`, `jumpToHistoryStep(_:)` |
| PJ-11 brush cursor | – (engine-direct) | `brushCursorDiameter` |
| PJ-12 selections | `SelectionShaping` | `setSelectionShape(_:)`, `setFeather(_:)`, `invertSelection()`, `selectionOutline`, `drag` (marquee) |
| PJ-13 layer masks | `LayerMasking`, `SelectionShaping` | `maskHelp`, `addMaskFromSelection()`, `deleteMask()`, `applyMask()`, `toggleMaskEnabled()`, `setEditsMask(_:)` |
| PJ-14 transform and flip | `LayerTransforming` | `transformHelp`, `beginTransform()`, `drag` (transform mode), `setTransform(_:)`, `transformCorners`, `transformed()`, `commitTransform(_:)`, `cancelTransform()`, `flipLayer(_:)`, `flipCanvas(_:)` |
| PJ-15 export size and formats | `ExportSizing` | `setExportOptions(_:)`, `exportSize(_:)`, `export(_:codec:)` |
| PJ-16 eyedropper | `ColorSampling` | `setSampleSize(_:)`, `sample(at:)`, `drag` (eyedropper) |
| PJ-17 layout | – | – (views only) |

---

## 6. Look

Photo already follows `docs/design.md`'s Editor shell: dark in both
appearances, hidden title bar, the 48 pt top bar, the docked rail, the
canvas with rulers and a checkerboard, the 280 pt right panel with
`SegmentedTabs`, and status pills. v2 keeps all of it. The house reference
for every new control is Flare's easing editor (the Studio rows and chips in
`docs/design.md`): `StudioScrubRow` / `InspectorSliderRow` bars for numbers
in a range, `ScrubField` for exact coordinates, `ChoiceChips` / `PresetGrid`
for one-of-a-few presets, `ChipRow` toggle chips for modes, `InspectorAction`
for a full-width command, `InspectorSection` with uppercase caps headers.

### 6.1 What Photo adds to `docs/design.md`

These are rules for Photo's screens; SuiteUI's components carry the look.
None needs a new token.

1. **The panel has three tabs:** Adjust, Layers, History, in that order.
   The tab bar never scrolls away.
2. **Tool options lead the Adjust tab** and change with the tool: brush and
   eraser (size, hardness, opacity, color), Marquee (shape chips, feather),
   Crop (X, Y, W, H, aspect chips, swap), Eyedropper (sample size chips),
   Free Transform (W %, H %, angle, Apply, Cancel). Exact coordinates (crop
   X, Y, W, H) are `ScrubField`s two per row in a `Grid`, one decimal never
   (whole pixels); ranges (feather, W %, H %, angle) are bar sliders with
   their unit.
3. **The Adjust tab edits what is selected.** With an adjustment layer
   selected it shows only that layer's sections, under a header naming the
   layer; otherwise the whole-image sections under the header "Image". The
   header's info line says which ("Adjusts the layers below" / "Adjusts the
   whole image"). People must never wonder which one a slider changes.
4. **Layer rows** carry, left to right: the eye, a kind symbol
   (`photo` for pixels, `slider.horizontal.3` for an adjustment), the name,
   and a mask badge (`rectangle.dashed.badge.record`, filled while the mask
   is the paint target, struck through while disabled). Each has a tooltip
   and an identifier (`photo.layer.<id>.eye`, `.kind`, `.mask-badge`).
5. **Overlay marks** are black-under-white like `SelectionOutline`, 1 device
   pixel, never take a click (the canvas gesture does): marching ants for any
   selection outline, the transform box with 8 square handles and a rotate
   cursor zone, the brush cursor ring, the crop shade with its thirds and,
   with an aspect lock, the aspect shown in a pill on the crop's top edge.
6. **Unsaved state** is the top bar's save status (S6, #339): "Saved", the
   unsaved dot with "Edited", "Edited, autosaved", "Not saved" in the error
   color after a failed save. The window's close button shows the system's
   edited dot too.
7. **Refusals go to the status line**, left of the pills, in the warning
   color with `exclamationmark.triangle`, for 4 s or until the next action
   ("Nothing to paste.", "Select an image layer in the Layers tab to paint on."). Alerts only
   for open and save failures and for the "Keep layers?" choice.
8. **Long work shows a note** in the canvas's top-left after 100 ms
   (the existing Straightening note's style): "Opening…", "Saving…",
   "Transforming…", "Exporting…", "Merging…".
9. **Fake data says so.** Under `-PhotoFixture` the status pills include a
   warning pill "Preview data", as Flare does.

### 6.2 Screens and their components

Components are SuiteUI unless named `Photo*` or a system control. **Bold**
means it doesn't exist yet (section 6.3).

| Screen | State | Uses | Feature |
|---|---|---|---|
| Main window | every | `EditorShell`, `EditorTopBar` (+ save status, **S6 #339**), `ToolbarGroup(style: .rail)`, `CanvasViewport`, `ViewerStatusBar` (pills **S7 #340**) | PV-0, PV-1 |
| Canvas overlay | crop pending | `CropShade` | existing, PV-3 |
| Canvas overlay | rectangle selection | `SelectionOutline` | existing |
| Canvas overlay | ellipse, lasso, feathered selection | **`SelectionPathOutline`** | PV-5 |
| Canvas overlay | Free Transform | **`SelectionHandles` with rotation** (on top of #273) | PV-7 |
| Canvas overlay | brush, eraser, clone, heal | **`BrushCursorMark`** | PV-4 |
| Adjust tab: tool options | brush, eraser | `InspectorSection`, `InspectorSliderRow`, `InspectorColorWellRow` | existing |
| Adjust tab: tool options | marquee | `ChoiceChips` (Rectangle, Ellipse, Lasso), `InspectorSliderRow` (Feather, px) | PV-5 |
| Adjust tab: tool options | crop | `ScrubField` × 4 in a `Grid`, `ChoiceChips` (6 aspects), `InspectorAction` (Swap; Apply Crop; Cancel) | PV-3 |
| Adjust tab: tool options | eyedropper | `ChoiceChips` (Point, 3 × 3, 5 × 5), `InspectorColorWellRow` (the picked color, read-only) | PV-9 |
| Adjust tab: tool options | transform | `InspectorSliderRow` (W %, H %, Angle °), `InspectorAction` (Apply, Cancel) | PV-7 |
| Adjust tab: sections | image or adjustment layer | `InspectorHeader`, `InspectorSection`, `Toggle` (checkbox), `InspectorSliderRow`, `ToneCurveEditor` | existing, PV-6 |
| Layers tab | any image | `List` rows (until **`LayerList`**, Flare's S15, unfiled), `InspectorPickerRow` (blend), `InspectorSliderRow` (opacity), `InspectorAction` | existing, PV-5, PV-6 |
| Layers tab | adjustment and mask marks | SF Symbols in the row, **row accessory slot** in `LayerList` | PV-5, PV-6 |
| History tab | steps | `List` of rows (`SidebarRow`), later steps in the secondary text color with a `clock.arrow.circlepath` symbol on the current one | PV-4 |
| History tab | no image open | `EmptyStateView` ("No image open. Its edits will be listed here.") | PV-4 |
| History tab | image with no edits | one row, "New Image" or "Open", current | PV-4 |
| Export sheet | – | `Picker` (segmented: PNG, JPEG, TIFF, HEIC), `InspectorSliderRow` (Quality %, Size %), `ScrubField` (Longest side px), a `Picker` for the size kind, the output size line | PV-8 |
| Keep layers? | Save of a flat file with layers | system `.confirmationDialog`: Save as Photo Document (default), Flatten into PNG, Cancel | PV-1 |
| Restore offer | launch after a crash | system alert: Restore, Discard | PV-1 |
| Unsaved changes | close or quit | an `NSAlert` with Save, Don't Save, Cancel, worded like the system's document alert | PV-1 |
| Open failure | bad package | system alert with `ArchiveError.message` | PV-1 |

### 6.3 SuiteUI components v2 needs (`needs-ui`, `line:suiteui`)

Filed by PV-0 once the captain approves this blueprint; each feature uses a
plain SwiftUI placeholder until its component lands (CLAUDE.md).

| Component | Need | Who asks | Existing issue |
|---|---|---|---|
| `SelectionPathOutline` | marching ants along closed polylines in document pixels at a zoom, black under white dashes, no hit testing | PV-5 | needs a new issue |
| `SelectionHandles` with rotation | a transform box from four corners at any rotation, 8 square handles on the pixel grid and a rotate zone; marks only | PV-7 | needs a new issue: #273 moves Design's axis-aligned resize handles into SuiteUI for Flare and Halo and has no rotation; the new issue builds on it |
| `BrushCursorMark` | a ring of a diameter in document pixels at a zoom, black under white, following the pointer | PV-4 | needs a new issue (#588 asks Photo to draw it; the mark belongs in `CanvasMarks`) |
| `LayerList` with an accessory slot | Flare's S15 plus a trailing accessory per row (Photo's mask badge) and a leading symbol | PV-5, PV-6 | not filed; Flare's S15 |
| Save status in `EditorTopBar` | Saved, Edited, Edited autosaved, Not saved | PV-1 | #339 (S6) |
| Status pills, warning pill | "Preview data", refusal messages | PV-0 | #340 (S7) |

Two v1 bugs whose fix is in SuiteUI are tracked to that line, not built in
Photo: #255 (`ScrubField.beginTyping` ignores `decimals:`) and #586
(`InspectorSectionHeader` Reset hit target). PV-10 relabels them
`line:suiteui` with a comment.

### 6.4 Snapshots each feature adds

`Tests/AppSnapshotTests/Photo<Feature>Snapshots.swift`, Light and Dark
(the shell is dark in both, so they guard regressions in the snapshot host),
named `photo-<state>-<scheme>.png`: `photo-unsaved`, `photo-keep-layers`
(PV-1); `photo-pasted-layer` (PV-2); `photo-crop-options`,
`photo-crop-ratio` (PV-3); `photo-history` (the name #644 gives),
`photo-brush-cursor` (PV-4); `photo-selection-mask` (the name #421 gives),
`photo-selection-lasso`, `photo-layer-mask` (PV-5); `photo-adjustment-layer`, `photo-adjust-target` (PV-6);
`photo-transform-box` (PV-7); `photo-export-options` (PV-8);
`photo-eyedropper-options` (PV-9); `photo-adjustments-aligned` (PV-10).

---

## 7. Quality bar

Every row says what is measured, by which test, where it runs, and the
number it must meet. Nothing here is a judgment call at review time. The
`QB-` rows are `docs/review-rubric.md` section 6; `PB-` rows are Photo's.

### 7.1 Input-to-screen budgets for each interactive tool

Photo measures latency at three depths, because the frame probe (QB-L1,
SuiteUI's #330) isn't built yet:

- **Model step** (Linux and macOS, `swift test`): wall time of the
  workspace call one pointer event or key makes, on the `large` fixture
  (4000 × 3000, three layers), median and p95 of 60 events. One `@Test`
  per row, in the owning feature's `Photo<Feature>BudgetTests.swift` (the
  table after this one). The device target is checked locally in a release
  build (`swift test -c release --filter Budget`). CI runs debug, where
  CoreRaster's per-pixel loops run about 20 times slower
  (`PhotoBrushLatencyTests.swift`'s measurement), so CI gates a row on its
  debug number only when the row is geometry (no per-pixel loop): PB-5,
  PB-6, PB-8, PB-10, PB-14, PB-17, at the device target × 10. The rows that
  touch pixels (marked "report" in the debug column) are reported on the
  contact sheet in CI and gated only in release.
- **Event to picture** (macOS, `Tests/AppSnapshotTests`): the model step
  plus `PhotoRenderer.update` of the damaged tiles plus `CanvasTiles.apply`,
  done the way the window does it, exactly as `PhotoBrushLatencyTests`
  measures the brush today. The 8 ms p50 gate (half a 60 Hz frame, the other
  half left for SwiftUI and Core Animation, the brush test's rule) holds in a
  release build, which CI doesn't run: CI's debug run only reports the
  number (on the contact sheet as `<TOOL>-LATENCY`), and the gate is checked
  locally on a Mac with `swift test -c release --filter Latency`, as the
  brush budget was set. Each feature's rows go in its own
  `Photo<Feature>LatencyTests.swift`.
- **Progress marks** ("within 100 ms", QB-L9) need the frame probe's marks,
  so every such cell is report-only until #330 lands; until then the model
  half is gated (the work runs off the main actor, and the call that starts
  it returns within one frame).
- **Frames late** (macOS journeys, QB-L1, QB-L2): report-only through the
  hitch metric (`XCTHitchMetric`, as `testBrushStrokeHitchesOnALargePhoto`
  does) until #330 lands; then the perf journeys PJ-P1 and PJ-P2 read
  `suite.perf` and the gate is set from CI (the rubric's "How gates are
  set": ten green runs, p95 × 1.5, never tighter than 2 frames).

| id | Interaction | Model step (device / debug gate) | Event to picture (release p50) | Frames late | Feature |
|---|---|---|---|---|---|
| PB-1 | Brush, eraser drag event | ≤ 3 ms in both builds (exists: `dragBudget` in `ST/PhotoBrushLatencyTests.swift`, macOS) | ≤ 8 ms (exists) | QB-L1, PJ-P1 | existing |
| PB-2 | Clone, heal drag event (64 px dab) | ≤ 1 ms / report | ≤ 8 ms | QB-L1, PJ-P1 | existing (new rows) |
| PB-3 | Brush drag inside an ellipse selection (coverage weighting) | ≤ 0.5 ms / report | ≤ 8 ms | QB-L1 | PV-5 |
| PB-4 | Paint on a layer mask | ≤ 0.3 ms / report | ≤ 8 ms | QB-L1 | PV-5 |
| PB-5 | Marquee rectangle and ellipse drag (outline only; the mask is built on mouse-up) | ≤ 0.1 ms / ≤ 1 ms | ≤ 4 ms (overlay only, no tiles) | QB-L1, PJ-P1 | PV-5 |
| PB-6 | Lasso drag event (append a point) | ≤ 0.05 ms / ≤ 0.5 ms | ≤ 4 ms | QB-L1 | PV-5 |
| PB-7 | Selection mouse-up: build the mask (ellipse, or a 1,000-point lasso) on 12 MP | ≤ 60 ms / report | – | QB-F2 (outline drawn before mouse-up) | PV-5 |
| PB-8 | Crop drag and a typed crop field | ≤ 0.05 ms / ≤ 0.5 ms | ≤ 4 ms | QB-L1 | PV-3 |
| PB-9 | Move tool drag | ≤ 0.1 ms / report | ≤ 8 ms | QB-L1 | existing (new row) |
| PB-10 | Free Transform handle drag (box only; pixels are transformed on Return) | ≤ 0.05 ms / ≤ 0.5 ms | ≤ 8 ms (preview: the layer's picture scaled and turned on the GPU, like Straighten's) | QB-L1, PJ-P1 | PV-7 |
| PB-11 | Free Transform commit on a 12 MP layer, off the main actor | ≤ 1.5 s / report | "Transforming…" within 100 ms | QB-L9 | PV-7 |
| PB-12 | Flip layer or canvas, 12 MP | ≤ 60 ms / report | – | – | PV-7 |
| PB-13 | Adjustment slider drag event with an adjustment layer in a 3-layer stack (one 256 px tile) | ≤ 4 ms / report | ≤ 8 ms per damaged tile batch | QB-L2, PJ-P2 | PV-6 |
| PB-14 | Eyedropper click (5 × 5 sample) | ≤ 1 ms / ≤ 10 ms | ≤ 4 ms (color well only) | – | PV-9 |
| PB-15 | Copy of a 12 MP layer; Paste as a new layer | ≤ 120 ms / report | the new layer drawn in ≤ 1 frame after the model step | – | PV-2 |
| PB-16 | Merge Down of two 12 MP layers; Flatten of three | ≤ 400 ms / report | "Merging…" within 100 ms | QB-L9 | PV-2 |
| PB-17 | History jump of 10 steps | ≤ 50 ms / ≤ 500 ms | ≤ 1 frame for the damaged tiles | – | PV-4 |
| PB-18 | Save a 3-layer 12 MP document (encode through a codec stub on Linux; ImageIO on macOS) | ≤ 2 s / report | "Saving…" within 100 ms; the window stays responsive | QB-L9, QB-L12 | PV-1 |
| PB-19 | Open the same document | ≤ 2 s / report | "Opening…" within 100 ms | QB-L9, QB-L12, PJ-P3 | PV-1 |
| PB-20 | Autosave of the same document, off the main actor | ≤ 2 s / report; the snapshot copy taken on the main actor ≤ 1.6 ms / ≤ 16 ms | – | QB-L12 | PV-1 |
| PB-21 | Export 12 MP at 50 % as JPEG | ≤ 1.5 s / report | "Exporting…" within 100 ms | QB-L8, QB-L9 | PV-8 |
| PB-22 | Pan and zoom (Space-drag, pinch) | – (view only) | ≤ 4 ms (no tiles re-rendered) | QB-L1, PJ-P1 | existing (new row) |

Where each row is tested (model step / event to picture), so every cell has
a file and an owner:

| Rows | Model step file | Event-to-picture file | Owner |
|---|---|---|---|
| PB-1 | `ST/PhotoBrushLatencyTests.swift` (exists, macOS) | the same file (exists) | existing |
| PB-2, PB-9 | `MT/PhotoBudgetTests.swift` | `ST/PhotoBrushLatencyTests.swift` (adds series) | PV-0 |
| PB-22 | – | report-only through the hitch journey and PJ-P1 | PV-0 |
| PB-15, PB-16 | `MT/PhotoEditBudgetTests.swift` | – (the new layer's tiles are PB-1's path) | PV-2 |
| PB-8 | `MT/PhotoCropBudgetTests.swift` | overlay only: report-only through PJ-P1 | PV-3 |
| PB-17 | `MT/PhotoHistoryBudgetTests.swift` | – | PV-4 |
| PB-3, PB-4, PB-5, PB-6, PB-7 | `MT/PhotoSelectionBudgetTests.swift` | `ST/PhotoSelectionLatencyTests.swift` | PV-5 |
| PB-13 | `MT/PhotoAdjustmentLayerBudgetTests.swift` | `ST/PhotoAdjustmentLayerLatencyTests.swift` | PV-6 |
| PB-10, PB-11, PB-12 | `MT/PhotoTransformBudgetTests.swift` | `ST/PhotoTransformLatencyTests.swift` | PV-7 |
| PB-21 | `MT/PhotoExportBudgetTests.swift` | – | PV-8 |
| PB-14 | `MT/PhotoEyedropperTests.swift` (a budget `@Test`) | – | PV-9 |
| PB-18, PB-19, PB-20 | `MT/PhotoDocumentsBudgetTests.swift`; PB-20's main-actor part is the snapshot copy, gated ≤ 16 ms debug | – | PV-1 |

Perf journeys (report-only until #330; owner in brackets):

| # | Test | Steps | Measures |
|---|---|---|---|
| PJ-P1 | `testCanvasDragLatency` (`+Perf`, PV-0) | on `large`: velocity-controlled drags across 600 pt at 300 pt/s for brush, ellipse marquee, crop, transform handle, Space-pan | at least 60 samples per series; frames late p95 (QB-L1) |
| PJ-P2 | `testSliderScrubLatency` (`+Perf`, PV-0) | Exposure bar drag on `large`, then the same on an adjustment layer once PV-6 lands | at least 60 samples; QB-L2 |
| PJ-P3 | `testOpenLargeDocument` (`+PerfDocuments`, PV-1) | save `large` as a document, reopen it | the "Opening…" mark within QB-L9; no main-thread stall over QB-L12 |

### 7.2 App-audit checks that apply

All six checks in `docs/blueprints/app-audit.md` run on every Photo shot:
`disabled-dim`, `overlap`, `contrast`, `identifier`, `offscreen`, `unnamed`.
Photo's baseline today is `identifier: 23`, everything else 0. The v2 rule,
checked on the contact sheet of every feature's CI run (`docs/factory/lead.md`
stage 4, "Audit"):

- No v2 feature raises any Photo count. Every new control carries a
  `photo.<area>.<name>` identifier, a label, and a disabled look from the
  system or SuiteUI, so `identifier`, `unnamed` and `disabled-dim` stay where
  they are; the new overlay marks are `accessibilityHidden` and never
  controls.
- PV-10 lowers `identifier` from 23 to the count left in SuiteUI's own
  components (Photo's views all get identifiers); CI's `Audit lower` job
  writes the new number.
- The new sheets and dialogs (Keep layers?, Restore, export options) are
  audited as their own layers: `offscreen` at the 1024 × 768 runner proves
  they fit.

### 7.3 Fidelity tests (output equals a reference)

Linux unless marked macOS. "Bit for bit" compares `PixelBuffer` storage.

| id | Check | Test | Feature |
|---|---|---|---|
| PF-1 | Save then open gives back every layer's 8-bit bytes, masks, kinds, blend, opacity, offsets, visibility and the global adjustments exactly | `PhotoDocumentRoundTripTests` (with an in-memory lossless codec on Linux; ImageIO on macOS in `PhotoPackageIOTests`) | PV-1 |
| PF-2 | A document's composite after reopening equals the composite before saving within 1/255 per channel (the 8-bit storage) | `PhotoDocumentRoundTripTests.compositeSurvives` | PV-1 |
| PF-3 | Copy then Paste in place: the new layer's pixels equal the source's inside the selection bit for bit | `PhotoClipboardTests` | PV-2 |
| PF-4 | Merge Down and Flatten equal `composite()` of the same layers bit for bit (they are the same pixels Export writes) | `PhotoLayerOpsTests` | PV-2 |
| PF-5 | A typed crop then Apply equals CoreRaster `cropped` of each layer at that rect | `PhotoCropSizeTests` | PV-3 |
| PF-6 | A rectangle selection's mask is exactly 0 or 1 and equals today's `PixelRect` behavior for Delete and Fill | `PhotoSelectionMaskTests` | PV-5 |
| PF-7 | An all-1 mask composites bit for bit like no mask; Delete Mask restores the exact pixels; Apply Mask equals pixels × coverage | `PhotoMaskTests` | PV-5 |
| PF-8 | An adjustment layer at opacity 1, normal, no mask, over the whole stack equals the same settings as whole-image adjustments, bit for bit; at opacity 0 it equals no layer | `PhotoAdjustmentLayerTests` | PV-6 |
| PF-9 | Free Transform at identity changes no pixel; flip twice is the input bit for bit; flip horizontal equals a reference mirror built pixel by pixel; scale 2 then 0.5 is within 2/255 of the input away from edges | `PhotoTransformTests` | PV-7 |
| PF-10 | Export at 50 % equals CoreRaster `resized(lanczos3)` of the composite, encoded; at 100 % equals today's export bytes | `PhotoExportOptionsTests` | PV-8 |
| PF-11 | The eyedropper's 3 × 3 sample equals the mean of those nine composited pixels, encoded | `PhotoEyedropperTests` | PV-9 |
| PF-12 | The live canvas's damaged tiles equal the full-frame reference with adjustment layers and masks in the stack (as today's `PhotoTileUpdateTests` do without them) | `PhotoAdjustmentLayerTileTests` (PV-6), `PhotoMaskTileTests` (PV-5) | PV-5, PV-6 |
| PF-13 | Goldens of each new overlay and panel state in Dark and Dark + Increase Contrast, tolerance 2/255 and 0.5 % (QB-V2, QB-V5) | macOS, `GoldenImage` once #331 and #332 land; PNGs for eyes until then | every UI feature |

### 7.4 Layout spec (alignment at several window widths)

Measured by PJ-17 `testLayoutAtWidths` (PV-10) from the accessibility frames
of identified elements, at window widths 880 (`SuiteSize.windowMinimum`,
200 + 440 + 240), 960 and 1024 points (the macOS runner's display is
1024 × 768, so wider windows would fail the audit's `offscreen` check
there), each launched with a new `-PhotoWindowWidth <pt>` argument (PV-0)
on `layered` with the Adjust tab open. Tolerance 1 pt. The same test runs at
1280, 1440 and 1920 locally on a larger display, run as
`TEST_RUNNER_PHOTO_LAYOUT_WIDE=1 scripts/ui-test` (xcodebuild hands a
variable to the UI test runner only with the `TEST_RUNNER_` prefix, which it
strips; PV-10 checks this against Apple's documentation first); CI skips
those widths with a message.

1. The panel is exactly `SuiteSize.editorPanelWidth` (280) wide and its
   right edge is the window's; the rail's width is constant across widths.
2. The canvas fills the rest: rail width + canvas width + panel width =
   window width.
3. Every bar slider in the Adjust tab (`photo.adjust.*`, `photo.tool.*`)
   has the same minX and the same width (#79), and every value field the
   same maxX.
4. Section headers share one minX; labels inside bars share one minX.
5. The crop options' four `ScrubField`s line up as a 2 × 2 grid: equal
   widths, X over W and Y over H share minX.
6. No identified element lies outside the window (the audit's `offscreen`)
   and no two controls overlap (`overlap`), at every width.
7. The top bar's items keep one baseline (equal midY) and none is clipped:
   at 880 the lowest-priority labels collapse to icons, never off-screen.

Model half (Linux): `PhotoLayoutTests` (PV-10) asserts the inspector's text
constants fit: the no-image message keeps "File > New Image" on one line
(#252), the three empty-state names agree (#253).

### 7.5 Feel (rubric rows that every feature meets)

- **QB-F1** No dead controls: `PhotoToolsTests` (reading `toolHelp`, PV-0)
  and a model test per feature that each new menu item either changes the
  workspace or returns a reason.
- **QB-F2** Live feedback: selection outline, crop rect, transform box and
  brush cursor draw while dragging; refusals show in the status line.
- **QB-F3** One gesture, one named step; every journey asserts the Edit
  menu's title after each edit (the names are in section 4).
- **QB-F4** Keyboard parity: crop fields type; transform W %, H % and angle
  type and arrow-step; Feather arrow-steps; every new tool has a one-key
  shortcut (I); every new menu command has its shortcut (Command-J, -E,
  Command-T, Shift-Command-I for Invert; Flatten Image has none, since
  Shift-Command-E is Export).

---

## 8. Coverage and waves

### 8.1 Every open `line:photo` issue

| Issue | Feature | How it closes |
|---|---|---|
| #79 adjustments rows don't line up | PV-10 | layout rule 3 of section 7.4, PJ-17 |
| #252 no-image message splits the menu path | PV-10 | `PhotoLayoutTests` |
| #253 status bar says "No image" | PV-10 | `PhotoLayoutTests`, one constant for the three panes |
| #255 Levels typing draft at two decimals | not Photo: SuiteUI (`ScrubField.beginTyping`) | PV-10 relabels it `line:suiteui` with a comment; cosmetic since #525 |
| #289 controls with no identifier | PV-10 (Photo's own views); the rest is SuiteUI's | the audit's `identifier` count falls to SuiteUI's share |
| #421 ellipse and lasso, layer masks | PV-5 | PJ-12, PJ-13, `PhotoSelectionMaskTests` |
| #544 typed crop size and aspect lock | PV-3 | PJ-8 |
| #580 adjustment layers (needs-spec) | PV-6 | PJ-9; section 1 and 6.1 rule 3 answer its open questions (the Adjust tab keeps a whole-image set; Exposure, Levels, Curves and Hue/Saturation can be layers, Blur can't; masks come with PV-5) |
| #586 Reset hit target 9 pt | not Photo: SuiteUI (`InspectorSectionHeader`) | PV-10 relabels it `line:suiteui` |
| #588 brush cursor circle | PV-4 | PJ-11 |
| #644 History list | PV-4 | PJ-10 (a panel tab, since Photo's window has no sidebar) |

Every v2 feature, the other way round: PV-0 (no issue; the seams), PV-1
(no issue: layered save, Open Recent, recovery), PV-2 (no issue: edit and
layer commands), PV-7 (no issue: transform), PV-8 (no issue: export size and
formats), PV-9 (no issue: eyedropper). Each gets a `gap` issue when its
packet is written.

Open issues on other lines that v2 touches:

| Issue | Line | Effect on Photo v2 |
|---|---|---|
| #333 QH-4 journey files | suiteui | every feature's journey task waits on it (one journey file per feature) |
| #331, #332 goldens | suiteui | PF-13 goldens wait on them; PNGs for eyes until then |
| #330 FrameProbe | suiteui | PJ-P1, PJ-P2 report hitches only until it lands |
| #339 S6 save status | suiteui | PV-1 shows the unsaved state with a plain label until it lands |
| #340 S7 status pills | suiteui | "Preview data" and refusal pills use the current `statusPill(.warning)` until it lands |
| #273 selection handles into SuiteUI | suiteui | the base PV-7's rotating transform box builds on (a new `needs-ui` issue adds rotation) |
| #274 share open and save panel plumbing | suiteui | touches the code PV-0 moves into `PhotoWindow+File.swift`; it must not run during waves 0–1, or PV-1 absorbs it (section 9, question 6) |
| #591 a `ScrubTrack` owns its step | suiteui | none for v2 |

### 8.2 Waves

A wave starts when everything in its "waits on" cell has merged. No two
features in one wave own the same file. Across waves a file can change
hands; the later wave starts from the merged result.

| Wave | Feature | Tier | Waits on (this repo) | Waits on (creative-core) |
|---|---|---|---|---|
| 0 | PV-0 seams: contracts, fakes, services, stored state, routing, splits | p1 by dependency | nothing (its journey task: #333) | nothing |
| 1 | PV-1 documents: layered save and open, Open Recent, unsaved state, recovery | p1 | PV-0; journeys #333 | nothing |
| 1 | PV-2 edit and layer commands: Cut, Copy, Paste, Duplicate, Merge Down, Flatten | p1 | PV-0; journeys #333 | nothing |
| 1 | PV-3 crop precision (#544) | p1 | PV-0; journeys #333 | nothing |
| 2 | PV-6 adjustment layers (#580) | p1 | PV-2 (hands over `PhotoCommands+Layer.swift`); it needn't wait for PV-1 or PV-3 | nothing; optional CR-5 |
| 3 | PV-4 history tab and brush cursor (#644, #588) | p2 | every p1 (waves 1 and 2) | nothing |
| 3 | PV-7 transform and flip | p2 | every p1 (PV-2 hands over `PhotoCommands+Edit.swift`) | CR-1, CR-2 |
| 3 | PV-8 export size, TIFF, HEIC | p2 | every p1 | nothing |
| 3 | PV-9 eyedropper | p2 | every p1 | nothing |
| 3 | PV-10 polish (#79, #252, #253, #289; moves #255, #586) | p2, p3 bugs | every p1 (PV-6 hands over `AdjustmentsInspector.swift`, `CurvesSection.swift`) | nothing |
| 4 | PV-5 selections and masks (#421) | p2 | PV-6 (hands over `PhotoLayerComposite.swift`, `PhotoLayersTab.swift`, `PhotoCommands+Layer.swift`) and wave 3 | CR-3, CR-4; optional CR-6 |

Why this order:

- **PV-0 alone first.** It edits the five shared files once
  (section 2.4), so every later feature owns its own. It changes no
  behavior a person sees except the eyedropper tool on the rail (disabled,
  "Not built yet (PV-9).") and nothing when run on `.live`; the existing
  309 model tests and twelve journeys are its regression gate.
- **Every p1 next, in waves 1 and 2** (`docs/priorities.md`: nothing `p2`
  starts on a line while a `p1` is open and unblocked). PV-1, PV-2 and PV-3
  are independent. PV-6 is p1 but shares `PhotoCommands+Layer.swift` with
  PV-2, so it starts as soon as PV-2 merges, without waiting for PV-1 or
  PV-3.
- **Then the p2 features and the polish bugs together (wave 3)**: they share
  no file. PV-10's bugs are p3 apart from #289 (p2); running them beside the
  p2 work is the one place this plan doesn't follow the pick order exactly
  (section 9, question 9).
- **PV-5 last**: it needs PV-6's layer kinds in the render hook to put
  masks on adjustment layers (#580's third question), and it waits on the
  most engine work.

### 8.3 Owned files per feature

Paths are relative to the repo root; `M/` is `Sources/PhotoModel/`, `A/` is
`Sources/PhotoApp/`, `MT/` is `Tests/PhotoModelTests/`, `ST/` is
`Tests/AppSnapshotTests/`, `UT/` is `UITests/`. "(stub from PV-0)" means
PV-0 creates the file with today's behavior or a no-op, and the feature then
owns it.

**PV-0 seams** (wave 0)

- Model: `M/Contracts/PhotoContractTypes.swift`, `M/Contracts/DocumentContracts.swift`,
  `M/Contracts/EditContracts.swift`, `M/Contracts/CropContracts.swift`,
  `M/Contracts/SelectionContracts.swift`, `M/Contracts/LayerContracts.swift`,
  `M/Contracts/OutputContracts.swift`, `M/PhotoServices.swift`,
  `M/Fakes/PhotoFakes.swift` (may split per contract), `M/PhotoFixtures.swift`,
  `M/Live/NotBuilt.swift`, and the stubs `M/Live/LiveDocuments.swift`,
  `M/Live/LiveEdit.swift`, `M/Live/LiveCrop.swift`, `M/Live/LiveSelection.swift`,
  `M/Live/LiveAdjustmentLayers.swift`, `M/Live/LiveTransform.swift`,
  `M/Live/LiveExportSizing.swift`, `M/Live/LiveSampling.swift`;
  edits `M/PhotoWorkspace.swift`, `M/PhotoLayer.swift`, `M/AdjustmentSettings.swift`,
  `M/PhotoHistory.swift`, `M/PhotoStroke.swift`, `M/PhotoSelection.swift`,
  `M/PhotoImageOps.swift`, `M/PhotoStraighten.swift` (the geometry hook),
  `M/PhotoRender.swift`; new `M/PhotoLayerComposite.swift`,
  `M/PhotoSelectionMask.swift` (today's marquee drag moved in),
  `M/PhotoCropSize.swift` (today's crop drag moved in), and the stubs
  `M/PhotoMask.swift`, `M/PhotoTransform.swift`, `M/PhotoEyedropper.swift`.
- App: edits `A/PhotoApp.swift`, `A/PhotoIntent.swift`, `A/PhotoWindow.swift`,
  `A/StrokePacer.swift` (modifiers per event),
  `A/PhotoCommands.swift`, `A/PhotoEditor.swift`, `A/PhotoPanel.swift`; new
  `A/PhotoWindow+File.swift` (today's open and save moved in),
  `A/PhotoWindow+Export.swift` (today's export moved in), the stubs
  `A/PhotoWindow+Edit.swift`, `+Crop.swift`, `+History.swift`, `+Select.swift`,
  `+AdjustmentLayer.swift`, `+Transform.swift`, `+Sample.swift`;
  `A/PhotoCommands+File.swift`, `+Edit.swift`, `+Select.swift`, `+Image.swift`,
  `+Layer.swift`, `+View.swift` (today's items moved in); `A/PhotoTopBar.swift`,
  `A/PhotoStatusLine.swift`, `A/PhotoCanvasOverlay.swift`, `A/CropOverlay.swift`,
  `A/SelectionOverlay.swift` (today's marks moved in), stubs
  `A/TransformOverlay.swift`, `A/BrushCursorOverlay.swift`;
  `A/PhotoAdjustTab.swift`, `A/PhotoLayersTab.swift`, `A/PhotoToolOptions.swift`
  (today's panel moved in), stubs `A/PhotoHistoryTab.swift` (not shown until
  PV-4 adds the tab), `A/CropOptions.swift`,
  `A/SelectOptions.swift`, `A/TransformOptions.swift`, `A/SampleOptions.swift`.
- Tests: `MT/PhotoContractsTests.swift`, `MT/PhotoFakesTests.swift`,
  `MT/LiveServicesTests.swift`, `MT/PhotoBudgetTests.swift` (PB-1, PB-2, PB-9),
  edits `MT/PhotoToolsTests.swift`; `ST/PhotoSeamsSnapshots.swift`
  (Preview data pill), edits the Photo snapshot files whose views moved;
  `UT/PhotoJourneyTests+Perf.swift` (PJ-P1, PJ-P2; after #333),
  `UT/PhotoJourneyTests+Fixtures.swift` (shared helpers), edits
  `UT/PhotoJourneyTests.swift` (uses them).
- Docs: `docs/c4/model.json` (the `photo-model-sources` and
  `photo-app-sources` descriptions name everything in section 2, once).
- Also: files the six `needs-ui` issues of section 6.3.
- Tasks (each one PR, under 400 lines): contracts (two PRs), fakes and
  fixtures, services and Live stubs, workspace state and history, model
  routing (no behavior change), intents and window split, commands split,
  editor and overlay split, panel split, launch arguments and the preview
  pill, C4 description, perf journeys.

**PV-1 documents** (wave 1)

- `M/PhotoDocumentFile.swift`, `M/PhotoRecovery.swift`, `M/Live/LiveDocuments.swift`
- `A/PhotoWindow+File.swift`, `A/PhotoCommands+File.swift`, `A/PhotoTopBar.swift`,
  `A/PhotoPackageIO.swift` (new), `A/PhotoAutosave.swift` (new),
  `A/PhotoApp.swift` (an app delegate adaptor: open a file from Open Recent or
  Finder with no window, `applicationShouldTerminate` for the unsaved prompt
  on Quit, the menu's no-window fallback for File items)
- `MT/PhotoDocumentRoundTripTests.swift`, `MT/PhotoDocumentFileTests.swift`,
  `MT/PhotoContainerTests.swift`, `MT/PhotoRecoveryTests.swift`,
  `MT/PhotoDocumentsBudgetTests.swift`
- `ST/PhotoDocumentsSnapshots.swift`, `ST/PhotoPackageIOTests.swift`
- `UT/PhotoJourneyTests+Documents.swift`, `UT/PhotoJourneyTests+Recovery.swift`,
  `UT/PhotoJourneyTests+PerfDocuments.swift`

**PV-2 edit and layer commands** (wave 1)

- `M/PhotoClipboard.swift`, `M/PhotoLayerOps.swift`, `M/Live/LiveEdit.swift`
- `A/PhotoWindow+Edit.swift`, `A/PhotoCommands+Edit.swift`,
  `A/PhotoCommands+Layer.swift`, `A/PhotoPasteboard.swift` (new)
- `MT/PhotoClipboardTests.swift`, `MT/PhotoLayerOpsTests.swift`, `MT/PhotoEditBudgetTests.swift`
- `ST/PhotoEditSnapshots.swift`, `ST/PhotoPasteboardTests.swift`
- `UT/PhotoJourneyTests+Edit.swift`, `UT/PhotoJourneyTests+LayerOps.swift`

**PV-3 crop precision** (wave 1)

- `M/PhotoCropSize.swift`, `M/Live/LiveCrop.swift`
- `A/PhotoWindow+Crop.swift`, `A/CropOptions.swift`, `A/CropOverlay.swift`
- `MT/PhotoCropSizeTests.swift`, `MT/PhotoCropBudgetTests.swift`
- `ST/PhotoCropOptionsSnapshots.swift`
- `UT/PhotoJourneyTests+Crop.swift`

**PV-10 polish** (wave 3)

- `M/PhotoInspectorContent.swift`
- `A/PhotoStatusLine.swift`, `A/PhotoEditor.swift`, `A/AdjustmentsInspector.swift`,
  `A/CurvesSection.swift`, `A/ImageSizeSheet.swift`, `A/StraightenSheet.swift`
- `MT/PhotoLayoutTests.swift`, edits `MT/PhotoInspectorContentTests.swift`
- `ST/PhotoPolishSnapshots.swift`
- `UT/PhotoJourneyTests+Layout.swift`
- Also: relabels #255 and #586 to `line:suiteui`; the `-PhotoWindowWidth`
  argument is PV-0's.

**PV-6 adjustment layers** (wave 2)

- `M/PhotoAdjustmentLayer.swift`, `M/PhotoLayerComposite.swift`,
  `M/Live/LiveAdjustmentLayers.swift`
- `A/PhotoWindow+AdjustmentLayer.swift`, `A/PhotoAdjustTab.swift`,
  `A/PhotoLayersTab.swift`, `A/PhotoCommands+Layer.swift`,
  `A/AdjustmentsInspector.swift` (only the layer's sections; no Blur on a
  layer), `A/CurvesSection.swift` (reads and writes the target's curve)
- `MT/PhotoAdjustmentLayerTests.swift`, `MT/PhotoAdjustmentLayerTileTests.swift`,
  `MT/PhotoAdjustmentLayerBudgetTests.swift`
- `ST/PhotoAdjustmentLayerSnapshots.swift`, `ST/PhotoAdjustmentLayerLatencyTests.swift`
- `UT/PhotoJourneyTests+AdjustmentLayers.swift`, `UT/PhotoJourneyTests+PerfAdjustmentLayers.swift`
  (PJ-P2's adjustment-layer series)

**PV-4 history tab and brush cursor** (wave 3)

- `M/PhotoHistoryRows.swift` (new: each row's name and whether it is current
  or undone, from `historySteps` and `historyIndex`)
- `A/PhotoWindow+History.swift`, `A/PhotoHistoryTab.swift`, `A/BrushCursorOverlay.swift`,
  `A/PhotoPanel.swift` (adds the History tab to `PhotoPanelTab`)
- `MT/PhotoHistoryRowsTests.swift`, `MT/PhotoHistoryBudgetTests.swift`
- `ST/PhotoHistorySnapshots.swift` (the name #644 gives), `ST/PhotoBrushCursorSnapshots.swift`
- #644 names `PhotoHistoryItems.swift` and a sidebar; Photo's window has no
  sidebar, so PV-4's packet edits #644's file list to the History tab files
  above before its PR says "Closes #644".
- `UT/PhotoJourneyTests+History.swift`

**PV-7 transform and flip** (wave 3)

- `M/PhotoTransform.swift`, `M/Live/LiveTransform.swift`
- `A/PhotoWindow+Transform.swift`, `A/TransformOptions.swift`, `A/TransformOverlay.swift`,
  `A/PhotoCommands+Edit.swift`, `A/PhotoCommands+Image.swift`
- `MT/PhotoTransformTests.swift`, `MT/PhotoTransformBudgetTests.swift`
- `ST/PhotoTransformSnapshots.swift`, `ST/PhotoTransformLatencyTests.swift`
- `UT/PhotoJourneyTests+Transform.swift`

**PV-8 export size and formats** (wave 3)

- `M/PhotoExportOptions.swift`, `M/PhotoImageFile.swift`, `M/Live/LiveExportSizing.swift`
- `A/PhotoWindow+Export.swift`, `A/ExportSheet.swift`, `A/ImageIOCodec.swift`
- `MT/PhotoExportOptionsTests.swift`, `MT/PhotoExportBudgetTests.swift`
- `ST/PhotoExportOptionsSnapshots.swift`
- `UT/PhotoJourneyTests+Export.swift`

**PV-9 eyedropper** (wave 3)

- `M/PhotoEyedropper.swift`, `M/Live/LiveSampling.swift`
- `A/PhotoWindow+Sample.swift`, `A/SampleOptions.swift`
- `MT/PhotoEyedropperTests.swift`
- `ST/PhotoEyedropperSnapshots.swift`
- `UT/PhotoJourneyTests+Sample.swift`

**PV-5 selections and masks** (wave 4)

- `M/PhotoSelectionMask.swift`, `M/PhotoMask.swift`, `M/PhotoLayerComposite.swift`,
  `M/Live/LiveSelection.swift`
- `A/PhotoWindow+Select.swift`, `A/SelectOptions.swift`, `A/SelectionOverlay.swift`,
  `A/PhotoLayersTab.swift`, `A/PhotoCommands+Select.swift`, `A/PhotoCommands+Layer.swift`
- `MT/PhotoSelectionMaskTests.swift` (the name #421 gives), `MT/PhotoMaskTests.swift`,
  `MT/PhotoMaskTileTests.swift`,
  `MT/PhotoSelectionBudgetTests.swift`
- `ST/PhotoSelectionMaskSnapshots.swift` (the name #421 gives), `ST/PhotoSelectionLatencyTests.swift`
- `UT/PhotoJourneyTests+Select.swift`, `UT/PhotoJourneyTests+Mask.swift`

Checked: within each wave the lists above share no path (a script over this
section: every path listed once per wave).

### 8.4 Engine work (creative-core)

No open creative-core issue serves Photo. v2 needs these new ones; none is
filed here (the captain files them with the packets).

| id | Needs a new core issue | One-line spec | Waited on by |
|---|---|---|---|
| CR-1 | yes | `PixelBuffer.transformed(_ m: AffineMatrix, width:height:filter:) throws -> PixelBuffer`: resample through an affine map (scale, rotate, translate) with transparent outside and the `ResampleFilter` kernels, identity bit for bit | PV-7 |
| CR-2 | yes | `PixelBuffer.flipped(_ axis: FlipAxis) -> PixelBuffer`: exact mirror (copied pixels, no filter), twice is the input | PV-7 |
| CR-3 | yes | `Mask.feathered(radius: Double) throws -> Mask`: Gaussian blur of coverage with sigma = radius / 3, values kept in 0...1, radius 0 returns self | PV-5 |
| CR-4 | yes | `Mask.contours(level: Float = 0.5) -> [[Mask.Point]]` and `Mask.coveredBounds -> (x, y, width, height)?`: marching-squares outlines for marching ants and the bounds Crop and Copy use | PV-5 |
| CR-5 | optional | `PixelBuffer.hueSaturation(hue:saturation:lightness:) throws -> PixelBuffer`: move Photo's `HueSaturation.swift` (its `ponytail:`) into CoreRaster so an adjustment layer's tile render meets PB-13 | PV-6 (perf only) |
| CR-6 | optional | `composite(_:onto:x:y:blendMode:opacity:mask:)`: the composite weighted by a coverage buffer, so a masked layer doesn't need a premultiply pass in Photo | PV-5 (perf only) |
| CR-7 | yes, not v2 | `PixelBuffer.healed(offset:through:)` as creative-core#232 specified; #232 closed with `cloned` only, and Photo heals with a per-dab mean shift (`PhotoRetouch.swift`'s `ponytail:`) | none in v2; Heal's quality follow-up |

PV-1 needs no engine work: the zip container is a small pure-Swift writer
and reader of stored entries in PhotoModel (CRC-32 included), and PNGs go
through the app's ImageIO codec as today. If the captain would rather have
the container in creative-core (Library or Design may want it), that is
section 9, question 1.

---

## 9. Open questions for the captain

Each has a recommendation; the blueprint is written as if it is accepted.

1. **The document format.** Recommended: OpenRaster (`.ora`, a published
   open spec) as a zip of stored entries, with Photo's extra data in
   `photo/document.json`, written by a small pure-Swift zip writer in
   PhotoModel. Other readers of OpenRaster then see the pixel layers (not
   adjustment layers or masks). Alternatives: a private package directory
   (needs document-type entries in the app's Info.plist, which
   `scripts/bundle-apps` writes, a protected path), or the container in
   creative-core for other apps to share. Either way, opening `.ora` files
   from other apps that compress their entries is not v2.
2. **Ranks.** Move #580 (adjustment layers) and #544 (typed crop) from `p2`
   to `p1`, and file PV-1 and PV-2 as `p1` (section 3).
3. **Bit depth.** v2 keeps 8-bit sRGB per layer on disk (what opening a file
   gives today), so the round trip is exact only in 8 bits (PF-2: within
   1/255 of the in-memory Float picture after tone edits). 16-bit layers
   are tier 3.
4. **Save of a flat file with layers.** Recommended: ask "Keep layers?"
   (Save as Photo Document, the default, or Flatten into the file's
   format), never flatten silently. The alternative, always Save As a
   document, surprises someone who only cropped a JPEG.
5. **Window model.** Keep `WindowGroup` with one model per window, as
   Flare's decision 4 did, with the unsaved alert done by the window; not
   `DocumentGroup`.
6. **#274** (share the open and save panel plumbing with Design) touches the
   code PV-0 moves. Hold it until PV-1 merges, or let PV-1 absorb Photo's
   side of it.
7. **Exported document type.** Double-clicking an `.ora` in Finder to open
   Photo needs an exported type in Info.plist (`scripts/bundle-apps`,
   protected). Open from the File menu, Open Recent and drop work without
   it. File a separate issue to add it, or leave it?
8. **Engine issues.** File CR-1 to CR-4 on creative-core when the PV-5 and
   PV-7 packets are written; CR-5 and CR-6 only if PB-13 or PB-3 fail.
9. **Polish beside p2.** PV-10's p3 bugs run in wave 3 beside the p2
   features, since they share no file. Strict pick order would put them
   after PV-5; say if you want that.

---

## 10. Critic rounds

A critic agent read this blueprint against the repo's rules, the Photo code,
CoreRaster and the open issues, and tried to refute it. Each finding was
verified with evidence (file and line, or a command) before it counted.

### Round 1 (2026-10-14): 5 blocking, 8 major, 5 minor; all fixed

Confirmed correct by the critic: the counts in section 0, the CoreRaster
claims, no shortcut collision, no shared file within a wave, no product
name in either file.

| # | Severity | Finding | Fix |
|---|---|---|---|
| C1 | blocking | `isDirty` compared history indexes, which stop at the 50-step limit and repeat after undo plus a new edit, so an edit could read as saved | Steps get ids from a counter that never repeats; `isDirty` is `savedStepID != currentStepID` (5.3) |
| C2 | blocking | `PhotoHistory.apply(.layers)` requires one pixel buffer per layer, so any adjustment layer would make layer-list undo a silent no-op (PJ-9 step 5) | PV-0 changes that guard and the workspace invariant to pixel layers (5.3) |
| C3 | blocking | Masks must follow crop, resize, rotate, straighten, delete, duplicate, merge and flips, all in files PV-5 doesn't own | PV-0 adds `layerGeometryChanged(_:_:)`, called from every such place, filled by PV-5 in its own file (5.3) |
| C4 | blocking | PV-6 needed `AdjustmentsInspector.swift`, `CurvesSection.swift` and the paint refusal, none owned | Both files go to PV-6 (wave 2); PV-0 writes the adjustment-layer paint refusal (5.3, 8.3) |
| C5 | blocking | The layout journey's 1280–1920 pt windows can't fit the 1024 × 768 runner, and 1024 isn't the window minimum (880) | CI measures at 880, 960, 1024; wider widths run locally (7.4) |
| C6 | major | The History tab case, Return and Escape for transform, and PJ-P2's adjustment-layer series sat in files their features don't own | PV-4 owns `PhotoPanel.swift`; Return and Escape route by mode through `PhotoWindow+Transform.swift`; PV-6 gets its own perf journey file (2.4, 8.3) |
| C7 | major | Open Recent with no window and Quit's unsaved prompt need `PhotoApp.swift` | PV-1 owns `PhotoApp.swift` in wave 1 (8.3) |
| C8 | major | `.fake` as the workspace default could write fake bytes to a user's file; the fakes shared global state across parallel tests | `.live` is the default; `.fake` makes new instances per read; `FakeArchive` keeps its own state (5.2, recompiled) |
| C9 | major | v2 state had no reset on open or new, the saved marker no initial value, the status message no way to clear | `start()` resets every v2 field and marks an opened file saved; `clearStatus()` (5.3) |
| C10 | major | Release-only gates that CI never runs, cells with no test or owner, 100 ms marks that need the frame probe | Every row has a file and owner; release gates are local, CI gates the debug number; marks are report-only until #330 (7.1) |
| C11 | major | `writeTestPhoto` is private to one class, and the fixture description didn't match its picture | PV-0 moves it to `UITests/PhotoJourneyTests+Fixtures.swift`; the `sample` fixture is that picture (4.1, 4.4) |
| C12 | major | #273 has no rotation, which the transform box needs | A new `needs-ui` issue on top of #273 (6.3) |
| C13 | major | `PhotoHistoryRows.swift` was in no C4 component | Added to `photo-model-history` in `c4-planned.json` |
| C14 | minor | PJ-4's expected message named the wrong path | `data/layer-2.png` |
| C15 | minor | PJ-9 sent the adjustment backward twice when once reaches the bottom | One Send Backward, and the button is then disabled |
| C16 | minor | Issue labels left out `gap`; #644 and #421 name other file and PNG names | Labels fixed; PNG names follow the issues; PV-4's packet edits #644's file list |
| C17 | minor | No section 10 yet; PJ-P3's file differed between 7.1 and 8.3 | This section; `+PerfDocuments` in both |
| C18 | minor | Flatten bakes in the whole-image adjustments but didn't reset them | The workspace resets them in the same step (5.1) |

After the fixes the contracts, fakes, `NotBuilt` stand-ins and workspace
stubs were compiled again (`swift build --build-tests`), and the 309 Photo
model tests passed with `.live` as the default.

### Round 2 (2026-10-14): 4 blocking, 6 major, 4 minor; all fixed

The critic first checked every round-1 fix: C2–C8, C10, C12 and C14–C18
held; C1, C11 and C13 were wrong or half done, C9 partial (all four are
covered below).

| # | Severity | Finding | Fix |
|---|---|---|---|
| D1 | blocking | `UITests/PhotoJourney+Fixtures.swift` matches neither today's journey template nor #333's `PhotoJourneyTests*.swift` pattern, so it would never compile | Renamed `UITests/PhotoJourneyTests+Fixtures.swift`; the move waits on #333 (4.1, 8.3) |
| D2 | blocking | Drags carry only Option (`sampling`) and no zoom, so Shift and Option selection modes, ratio and angle snaps and zoom-aware handles couldn't be built from PV-5's and PV-7's files | PV-0 widens `drag` and `drags` to `modifiers:` and `zoom:` and owns `StrokePacer.swift` for it (2.4, 5.3) |
| D3 | blocking | Mask paint had no target type, no undo step, and source-over paint can't lower an alpha coverage | `PaintTarget` (`.pixels` or `.mask`) in PV-0's `PhotoStroke.swift`; masks keep coverage as gray with alpha 1 (black hides, white reveals); a `.maskTiles` history step (2.4, 5.1, 5.3) |
| D4 | blocking | C1's step id fell back to 0 when everything was undone after a trim, reading clean with an edit applied | `baseStepID` takes each trimmed step's id, like `baseName` (5.3) |
| D5 | major | Delete, Fill, Select All, Deselect and Apply Crop ignored the selection mask, in a file PV-5 doesn't own | PV-0 routes them through `PhotoSelectionMask.swift` (2.4) |
| D6 | major | PV-0's no-op eyedropper would fail its own `PhotoToolsTests` on `.fake` | PV-0's eyedropper drag calls `services.sampling` and sets the color (2.4) |
| D7 | major | Wave 2 ran p2 features beside a p1, against `docs/priorities.md` | Wave 2 is PV-6 alone; the p2 features and PV-10 are wave 3; PV-5 is wave 4; the polish exception is question 9 (8.2) |
| D8 | major | Debug gates at × 10 when CoreRaster's loops run about × 20 in debug; PB-1's source was wrong | CI gates only the geometry rows in debug; pixel rows report in CI and gate in release locally; PB-1 cites `dragBudget` in the macOS test (7.1) |
| D9 | major | `PHOTO_LAYOUT_WIDE=1` wouldn't reach the UI test runner | `TEST_RUNNER_PHOTO_LAYOUT_WIDE=1`, checked against Apple's documentation in PV-10 (7.4) |
| D10 | major | A new image read as dirty while the text said clean | `start()` sets `savedStepID` for new images too (5.3) |
| D11 | minor | PF-12 named a test file no feature owns | `PhotoAdjustmentLayerTileTests` (PV-6), `PhotoMaskTileTests` (PV-5) |
| D12 | minor | `start()` didn't reset `editsMask` | Added (5.3) |
| D13 | minor | 2.2's history row left out `PhotoHistoryRows.swift` | Added |
| D14 | minor | "System alert" for unsaved changes against question 5's `WindowGroup`; two different History empty states | An `NSAlert` worded like the system's; the empty states split into no image and no edits (4.2, 6.2) |

Confirmed by round 2: no shortcut collision (Command-J, Command-E,
Command-T, Shift-Command-I and I are free; Shift-Command-E stays Export),
the 11 open `line:photo` issues and their labels match 0.4 and 8.1, every
file in 8.3 sits in exactly one `c4-planned.json` component, and neither file
names another company's product. After the fixes the code was compiled
again and the 309 Photo model tests passed.

### Round 3 (2026-10-14): verification of round 2; 3 major, all fixed

A third pass checked D1–D14 only. Thirteen held. D3 had left `masks`
described as "coverage in alpha" in 5.3, and three new problems came from
the round-2 fixes:

| # | Severity | Finding | Fix |
|---|---|---|---|
| E1 | major | `isDirty` read true with no image open (nil against step 0), so closing an empty window would prompt | `isDirty` is false without a canvas (5.3) |
| E2 | major | Making `modifiers:` and `zoom:` required on `drag` would break about 60 existing calls in 15 test files PV-0 doesn't list | New overloads; the old signatures stay as wrappers (2.4, 5.3) |
| E3 | major | "Each is written only by the extension file named" was false once paint, undo and `start()` write masks and the selection | The comment names every writer (5.3); `masks` reads "coverage as gray" |

The `photo-model-history` description in `c4-planned.json` now names step ids
and the mask-tiles step. The code was compiled again after the fixes. Round
3 found no blocking item, so the critic loop stops here.
