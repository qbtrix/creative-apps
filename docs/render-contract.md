# Render contract

How every canvas app (Photo, Design, Flare, Halo, Library) gets pixels on
screen. Read it before you touch a canvas, an overlay, a render route or
anything that runs per pointer or slider step. `scripts/check-render-contract`
in `scripts/ci` enforces the rules it can; the rest is on review.

Why it exists: each slow canvas we found came from a feature quietly taking
its own render route. Every one was locally reasonable and globally slow:

- A visible adjustment layer made `residentComposited` give up, so every
  redraw uploaded every tile, read the picture back and ran on the CPU
  (Levels at about 1 s per step). Fixed by #3144 with creative-core #624.
- Hue/Saturation had no GPU op, so each step read back, ran on the CPU and
  uploaded again. Same fix.
- A SwiftUI `ImagePaint` checkerboard the size of the artboard was rasterized
  on the CPU every frame (#3019). Another offscreen-rendered view had SwiftUI
  allocate a new IOSurface per frame: 76% of main-thread time.
- An unbounded MPS temporary crashed Metal at 8K (#3140).

## The rules

1. **One route to the screen.** With Metal on, everything visible on a canvas
   goes through the shared GPU compositor path: creative-core's CoreRender
   dispatcher on the Metal backend, written into SuiteUI's
   `CanvasTilePresenter` texture (`residentTexture`) and shown by
   `CanvasHostView`'s `CAMetalLayer`. The CPU path exists for export, undo
   snapshots and the Metal-off fallback (View > Rendering > CPU, or no
   device). It must match the GPU picture within CoreRender's parity
   tolerance: 2 display levels or 1e-3 linear for layers, 2 levels or 4e-3
   linear with the full adjustment chain (`PhotoRenderBackendTests`).

2. **No whole-canvas fallback.** No feature may make the GPU route return nil
   or fall back for the whole canvas. An op the GPU lacks gets a GPU
   implementation in creative-core, with parity tests, and a bump. Until then
   it is a known CPU op: one line in `Tests/render-cpu-ops.txt` (the one
   registry, each line naming the issue that removes it) and
   `// render-contract: cpu-op <id>` on the line that steps aside. The only
   fallback that needs no entry is Metal itself being off or not ready
   (`PhotoRenderRoute.residentTiles`).

3. **A step does no CPU pixel work.** A pointer drag or slider step does no
   CPU pixel work, no full-layer upload and no GPU-to-CPU readback. Upload
   only the tiles that changed (resident tiles). Readback is for export, the
   eyedropper and parity tests; mark an allowed one
   `// render-contract: allow <reason>`.

4. **No canvas-sized SwiftUI offscreen passes.** Over the canvas, never use
   `.drawingGroup()`, `.compositingGroup()`, `ImagePaint`, a `Canvas`, or a
   shadow, blur or mask on a view the size of the artboard or document. Each
   one makes SwiftUI rasterize or allocate a surface that size, often per
   frame. Overlays (selection, handles, guides, marks) are bounded to the
   viewport or drawn in the CALayer/Metal canvas (`CanvasHostView`'s overlay
   layer, SuiteUI `CanvasMarks`). A small control (a curve editor, a ruler, a
   scrub field) may use `Canvas`; it is not over the canvas.

5. **Respect the device texture limit.** Every GPU texture and MPS temporary
   is sized through one shared limit helper, never straight from the document
   size. TODO: the helper lands with #3140 (`CanvasTilePresenter`'s two
   `MTLTextureDescriptor.texture2DDescriptor` calls are the first users);
   once it merges, the lint gets a rule that every texture descriptor goes
   through it.

6. **Budgets.** A slider or drag step: p95 at or under 16 ms (target), 33 ms
   hard at 8K. Idle: under 10% CPU within 3 s of the last edit. The measured
   rows and their ratchet are in `Tests/render-budgets.md`; the real-app perf
   journeys that judge the bundled apps from outside (`scripts/ui-test perf`)
   come with #3122 once it merges.

## What the lint checks

`scripts/check-render-contract`, run by `scripts/ci` after its self-test
(`Tests/canonical/test_check_render_contract.sh`). Comments and strings never
count. A hit's key is `path::Scope.rule`, so moving lines doesn't move it.

| Rule | Fails on | Where | Escape (same line) |
|---|---|---|---|
| offscreen | `.drawingGroup(`, `.compositingGroup(`, `ImagePaint(`, `Canvas {` / `Canvas(` | canvas and overlay views: files under `Sources/{Photo,Design,Flare,Halo,Library}App` or `Sources/SuiteUI` named with Canvas, Stage, Viewer, Overlay, Viewport, Artboard, Artwork, Loupe, SelectionMarks, SelectionHandles or SnapGuide, plus any file with a `// render-contract: canvas-view` line | `// render-contract: allow <reason>` (the reason is required) |
| gpu-nil | `return nil` in a GPU-route func: one returning `RenderSurface?`, or with `// render-contract: gpu-route` on the line above it | all of `Sources/` | `// render-contract: cpu-op <id>`, `<id>` in `Tests/render-cpu-ops.txt` |
| readback | `<x>dispatcher.read(` | all of `Sources/` | `cpu-op <id>`, or `allow <reason>` for export and the eyedropper |

Hits that predate the lint are listed in
`Tests/render-contract-baseline.txt`. It only shrinks: a new hit fails, and so
does a listed one that is gone, until you rerun
`scripts/check-render-contract --update-baseline` in the same PR. Growing it
takes `--allow-increase` and a reviewer who agrees.

A new canvas view whose file name doesn't say so: add the
`// render-contract: canvas-view` line to its header. A new GPU-route func that
returns something other than `RenderSurface?` (a plan, a stack, a Bool): put
`// render-contract: gpu-route` on the line above it, so its bail-outs count.

Not mechanical, so on review: shadow, blur and mask on canvas-sized views
(the lint can't tell a handle from an artboard), full-layer uploads and CPU
pixel loops inside a step, and the budgets themselves (the perf suites and
journeys measure them).

## Today's baseline (the next fixes)

- Design `DesignArtwork` draws the page's nodes in a SwiftUI `Canvas`.
- Flare `FlareStageArt` draws the committed art in a `Canvas` under
  `.drawingGroup()` on the viewport.
- Halo `HaloDrawnLayers` draws the viewer in a `Canvas` under
  `.drawingGroup(colorMode: .linear)`; the linear group mixes opacity right
  (#1161), so the fix is moving the viewer onto the Metal canvas, not deleting
  the modifier.
- Photo `residentComposited` gives up on an adjustment layer, and
  `composited` / `applied` read the picture back for adjustment layers and
  Hue/Saturation. #3144 removes all three.
