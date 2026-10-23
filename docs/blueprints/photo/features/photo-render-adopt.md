# Feature packet: photo-render-adopt

**Feature:** Photo's canvas draws through creative-core's CoreRender
dispatcher, on the CPU backend or the Metal backend, and View > Rendering
(Automatic, GPU (Metal), CPU) picks which, live in every open window. The
choice is the suite's one `suite.rendering` key, so it survives a relaunch.
The status line names the backend that drew the picture and how long it
took. The canvas is SuiteUI's CanvasHostView: tile layers on the CPU path,
its CAMetalLayer on the GPU path. Photo's document, tools and undo don't
change; only how the picture is drawn does.
**Line:** `line:photo` · **Row:** R1 of the beta-80 plan
(`docs/design/drafts/2026-10-18-beta-80-plan.md` in the workspace), Photo
adopter · **Blueprint:** the dual-renderer note (2026-10-17) and
`docs/blueprints/suiteui/features/canvas-host.md`.

**Covers:** the Photo slice of R1, pulled forward so the captain can open a
big photo and switch between the GPU and the CPU live. Halo, Flare and
Design adopt R1 later with their own packets.

**Depends on:** the creative-core pin at 3094ab1 or later (CoreRender and
CoreRenderMetal, metal-backend MB-1 to MB-17), and SuiteUI's canvas-host
feature (RenderingPreference, RenderingCommands, CanvasHostView and its
CAMetalLayer path).

**Render contract:** the rules this route keeps (no whole-canvas fallback, no
readback per step, the parity tolerance) are `docs/render-contract.md`.

## Journey steps

1. Open a large photo. View > Rendering shows Automatic checked and "Drawing
   on GPU" under the three choices.
2. The status line's render pill reads "GPU (Metal) · N ms render".
3. Pick CPU. The picture redraws at once and the pill reads "CPU · N ms
   render". Paint a stroke; the pill keeps naming the CPU.
4. Pick GPU (Metal). The picture redraws on the GPU. Quit and relaunch: the
   menu still checks GPU (Metal).

The menu can't be driven by an XCUITest journey without taking the mouse,
so these steps are checked by hand on the Mac (the done check) and by
`PhotoRenderBackendTests` in code.

## Screens and states

| Screen | Empty | Error | Loading |
|---|---|---|---|
| Status line render pill | no pill with no image | a failed render keeps the last picture and shows the window's render note (unchanged) | while the Metal pipelines compile in the background, the dispatcher draws those op families on the CPU and the pill says CPU until the next redraw |
| View > Rendering | – | Metal stopped: Automatic falls back to the CPU (the route checks the backend's health) | – |

## Contract slice

```swift
// PhotoModel (Linux-safe)
public struct PhotoRenderRoute: Sendable {
    public let preferred: (any RenderBackend)?   // nil: the CPU
    public static let cpu: PhotoRenderRoute
    public func dispatcher() -> RenderDispatcher  // its own CPUBackend per render
}
extension PhotoWorkspace {
    public func renderedSurface(_ rect: PixelRect, on: RenderDispatcher) throws -> RenderSurface
}
extension PhotoRenderer {
    public static func update(_: PhotoWorkspace, since: Int?, route: PhotoRenderRoute = .cpu) async throws -> PhotoTileUpdate
}
// PhotoTileUpdate gains `backend: String`, the backend whose display encode made its bytes.

// PhotoApp (macOS)
@MainActor final class PhotoRendering {      // the live preference and the Metal backend, one per process
    var route: PhotoRenderRoute
    nonisolated static func route(_: RenderingChoice, gpu: (any RenderBackend)?) -> PhotoRenderRoute
}
// CanvasRenderer.follow(_:redraw:) redraws the whole picture on each choice change; `backend` names who drew it.
```

## How the picture is drawn

A region of the canvas is the visible layers bottom-up, then the
adjustments, then display bytes. A pixel layer's tiles go to `composite`
with its blend mode and opacity (only each tile's painted part is uploaded,
and an opaque normal tile that covers the region replaces it). Exposure,
levels and curves are `adjusted`, blur is `gaussianBlur`, and the bytes come
from `display`. An adjustment layer and Hue/Saturation have no `RenderOp`
yet, so those two read the picture back, run on CoreRaster and upload it
again. A section at its identity is skipped (CoreRaster returns the buffer
itself there, so the bits are the same). The CPU route renders each damaged
256 px tile on its own task, each with its own CPU backend, since one CPU
backend runs its composites one at a time. The GPU route renders each row of
damaged tiles as one region, the rows on their own tasks: one region for a
whole 8K picture took 2.6 s, tiles in parallel 0.27 s, rows 0.33 s, while a
two-tile brush frame took 4.9, 9.4 and 4.6 ms. Export stays on
CoreRaster directly, which is also the reference the parity tests use.

## Tasks

| id | what | PR |
|---|---|---|
| RA-1 | Bump creative-core to 3094ab1 (CoreRender and CoreRenderMetal reach the apps) | #2820 |
| RA-2 | The dispatcher route, View > Rendering in Photo, the status line readout, the parity, switching and 8K tests, this packet | #2840 |
| RA-3 | SuiteUI's CanvasHostView hosts Photo's canvas (`EmbeddedCanvasHost` in the CanvasViewport): tile layers on the CPU path, the CAMetalLayer with `CanvasTilePresenter` on the GPU path; Automatic draws on Metal; Photo's own `TileCanvasView` is deleted | the next PR |

## Acceptance

| test | fails when |
|---|---|
| `PhotoRenderRouteTests` (Linux) | the CPU route, or the one-region GPU path run on a second CPU backend, differs from CoreRaster's render by any byte, for a full picture or a stroke's damaged tiles |
| `PhotoRenderBackendTests` parity (this Mac's GPU) | Metal against the reference: layers alone outside CoreRender's standard tolerance (2 display levels, 1e-3 linear); with every adjustment on, outside 2 levels or 4e-3 linear (a nine-step half-float chain) |
| `PhotoRenderBackendTests` switching | changing the choice doesn't redraw the whole picture on the backend it names |
| `PhotoTileCanvasTests` (this Mac's GPU) | the embedded host's tile layers or the Metal presenter's texture differ from the reference picture |
| `CanvasHostMetalTests` | Automatic or GPU with a device keeps the tile layers, the presenter misses the tiles shown, or the drawable has more pixels than the document |
| `PhotoRenderBudgetTests` (perf list, report only) | never; it records the 8K numbers in `Tests/render-budgets.md`, and G1 sets the budgets |

## Done check

On the Mac, open a 7680 x 4320 photo, switch View > Rendering between GPU
(Metal) and CPU, and watch the status line's render pill name the backend
and its time. The choice survives a relaunch.
