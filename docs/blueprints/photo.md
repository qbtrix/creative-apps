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
creative-core `main` 4cac701 (CoreRaster, the revision `Package.swift`
resolves today, since it tracks `main`), `docs/design.md`,
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
- **Tests.** 49 files in `Tests/PhotoModelTests` (Linux), 16 Photo files in
  `Tests/AppSnapshotTests` (including `PhotoBrushLatencyTests` and
  `PhotoTileCanvasTests`), one journey file.
- **App audit** (`UITests/audit-baseline.json`): `photo` is at
  `identifier: 23`, every other check 0.
- **Shared harness not built yet** (SuiteUI line, all open): `FrameProbe`
  #330 (p3), golden compare #331 (p1), the scale-2 four-appearance host #332
  (p1), the journey file split and input helpers #333 (p1), status pills #340.
  Until #333 lands every Photo journey lives in one file.
- **creative-core** (`main` 4cac701) CoreRaster has: `PixelBuffer` (Float32,
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
| #79 | bug, p3 | Adjustments inspector rows don't line up (ragged slider and field columns) |
| #252 | bug, p3 | Inspector no-image message splits "File > New Image" across two lines |
| #253 | bug, p3 | Status bar says "No image" while canvas and inspector say "No Image Open" |
| #255 | bug, p1 | Levels typing draft opens at two decimals (value change fixed by #525; what's left is cosmetic, and the fix is in SuiteUI's `ScrubField`) |
| #289 | p2, needs-ui | Controls with no accessibility identifier (the audit counts 23 now) |
| #421 | p2 | Ellipse and lasso selections, layer masks |
| #544 | p2 | Type the crop size and lock its aspect ratio |
| #580 | p2, needs-spec | Adjustment layers in the layer stack |
| #586 | bug, p3, needs-human | A tone section's Reset icon is a 9 pt hit target (fix in SuiteUI's `InspectorSectionHeader`) |
| #588 | p2 | Draw the brush cursor circle on the canvas |
| #644 | p2 | History list (view half of #25) |

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
| Transform | Edit > Free Transform (Command-T): scale with the 8 handles, rotate outside them, Shift keeps ratio, typed W%, H%, angle; Flip Layer Horizontal and Vertical; Image > Flip Canvas Horizontal and Vertical | Skew, distort, perspective, warp |
| History | The History tab: every named step, click to jump, later steps dimmed | Snapshots, history brush |
| Paint | The brush cursor circle at the brush size; Eyedropper (I) picks a color from the image into the brush color, point or 3 × 3 or 5 × 5 average | Gradient, paint bucket, brush presets and textures |
| Export | PNG, JPEG, TIFF and HEIC; a size as a percent or a longest side; quality for JPEG and HEIC | Export several sizes at once, web presets, metadata editing |
| Fixes | #79, #252, #253, #289 (Photo's views), and #255, #586 tracked to SuiteUI | – |

Tier 3 stays out of v2: text, paths and a pen, layer styles, print setup,
specialist controls, gradients and fills.
