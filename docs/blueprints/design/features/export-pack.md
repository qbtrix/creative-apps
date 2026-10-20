# Feature packet: export-pack (Design)

**Feature:** Design's File > Export… adds JPEG to PNG, SVG and PDF, and a
Size row with Pixels and Long edge beside 1x, 2x and 3x, so "1080 × 1350"
writes exactly 1080 × 1350 whatever the frame's size in points. JPEG has no
alpha: it flattens onto the frame's fill, white when the frame has none.
**Line:** `line:design` · **Wave:** 3 (`waves.md`) · **Lead branch:** `lead/export-pack`
**Beta:** captain, 2026-10-20 (everyday gaps audit, rank 5). Labels `beta` and `p1` when filed.

**Covers:** feature map `design/export-pack` (adopter of S11); real job
RJ-D41 (new). RJ-D01 (the Instagram post) still waits on frame presets
(S10) for its first step and closes there.

**Depends on:** `suiteui/export-pack` **XP-a** (cross-line: `ExportOptions`,
`ExportSize`, the sheet's Size row); DX-3 needs **XP-6** (the rules), DX-5
**XP-4** (the rows). shell-media **SM-w** for the JPEG bytes (DX-4). Same
line: `design-export` (planned, #1970) owns every file this packet edits, so
each slice waits on it.

**Rule 20.** `DesignExportOptions` holds an `ExportSize` in place of its
`scale: Int`, and the plan's pixel sizes come from `ExportRules.pixels`; no
Design size rule is left. JPEG bytes come from `services.media.still`.

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| DX-a | The export options hold an `ExportSize` and list JPEG, the plan takes them on stubs, and the sheet shows the shared Size row and a JPEG chip. | DX-1, DX-2 | MJ-DX | XP-a (cross-line); design-export |
| DX-u | The sheet has snapshots and a render budget, and the journey is written. | DX-5, DX-6 | DJ-X1 | DX-a; XP-4 (DX-5, cross-line) |
| DX-m | The plan gives each file exact pixels, JPEG flattens onto the frame's fill, and the rasterizer draws at that size. | DX-3, DX-4 | MJ-DX, `DesignRasterizerSizeTests` (macOS) | DX-a; XP-6, SM-w (cross-line) |
| DX-z | Export writes real JPEG and PNG files at the exact size on live services, the journey passes, and the blueprint has it in. | DX-7, DX-8 | DJ-X1 | DX-u, DX-m; gradient-fill:DG-z (DX-8, design.md); placed-images:PD-z (DX-8, A/C first) |

DX-u waits only on DX-a (rule 18); DX-m never waits on DX-u. DX-m is marked `"ui": true` because DX-4 changes `DesignRasterizer` in DesignApp. MJ-DX is the Model walk in `DesignExportPackTests` (Linux).

## Journey steps

1. Open `Cards.design`, select the 540 × 675 pt "Post" frame, File > Export…
   (DX-2, `DesignExportPackJourneyTests.testExportPostAtExactSize`).
2. Pick JPEG; Size > Pixels, type 1080: height reads 1350, the readout
   "1080 × 1350 px".
3. Export into a folder: `Post.jpg` is 1080 × 1350.
4. Pick PNG, Long edge 512: `Post.png` is 410 × 512, with alpha.

## Jobs

| job | closes or adds | run | check | fixture |
|---|---|---|---|---|
| RJ-D41 | adds, closes with `design/export-pack` | Cm | `Tests/RealJobs/design/exact-jpeg/exact-jpeg.jobs.json`: export the "Post" frame as JPEG with `{"size":{"pixels":[1080,1350]}}` and as PNG with `{"size":{"longEdge":512}}` | `input/cards.design` (a 540 × 675 pt frame with a transparent corner) |

Trap: 2x applied on top (2160 × 2700), or the JPEG's transparent corner comes
out black. Assertion: the JPEG decodes at exactly 1080 × 1350 and its
transparent corner reads the frame's fill (white here) within 2/255; the PNG
is 410 × 512 with that corner's alpha 0. Mutations:
`DesignModel.DesignExport+Kernel.json`, the scale multiplied after the
pixel size → `.exactPixels`; JPEG not flattened → `.jpegFlattens`.

## Screens and states

`design-export-pixels` (JPEG, Pixels, light and dark), `design-export-long-edge` (PNG).

## Contract slice

```swift
// Sources/DesignModel/DesignExport+Kernel.swift (DX-1)
public enum DesignExportFormat { case png, jpeg, svg, pdf }          // jpeg: "JPEG lands with DX-3." until DX-3
public struct DesignExportOptions { public var format: DesignExportFormat; public var size: ExportSize; public var scope: DesignExportScope }
// `scale: Int` becomes `size: .scale(Double(scale))`; the old init stays as a convenience.
```

## Pseudocode

- **plan.** Each item's pixel size is `ExportRules.pixels(of: frame in pt at
  1x, options.size, evenSize: false)`; SVG and PDF keep points (Scale only).
- **JPEG.** The rasterizer draws at the planned size onto the frame's fill
  (white when none), then `services.media.still(frame, as: .jpeg, quality:)`.

## Tasks

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| DX-1 | – | `DesignExportOptions.size` and `.jpeg` (refused until DX-3); `DesignExportPackTests` written, disabled | `Sources/DesignModel/DesignExport+Kernel.swift`, `Tests/DesignModelTests/DesignExportPackTests.swift` | XP-a, design-export | ~120, 2 |
| DX-2 | – | The sheet: the shared Size row (Scale, Pixels, Long edge) and the JPEG chip; Metadata hidden (Design writes none) | `Sources/DesignApp/DesignExport+Kernel.swift` | DX-1 | ~80, 1 |
| DX-3 | – | The plan's exact pixel sizes and JPEG's refusals and flattening rule; RJ-D41's job folder; turns on `DesignExportPackTests` | `Sources/DesignModel/DesignExport+Kernel.swift`, `Tests/DesignModelTests/DesignExportPackTests.swift`, `Tests/mutations/DesignModel.DesignExport+Kernel.json`, `Tests/RealJobs/design/exact-jpeg/` | DX-1, XP-6 | ~220, 4 |
| DX-4 | – | `DesignRasterizer` draws at the planned pixel size onto the frame's fill for JPEG; JPEG through `services.media.still` | `Sources/DesignApp/DesignRasterizer.swift`, `Tests/AppSnapshotTests/DesignRasterizerSizeTests.swift` | DX-1, SM-w | ~160, 2 |
| DX-5 | – | Snapshots and the render budget test | `Tests/AppSnapshotTests/DesignExportPackSnapshots.swift`, `Tests/AppSnapshotTests/RenderBudgetDesignExportPackTests.swift` | DX-2, XP-4 | ~140, 2 |
| DX-6 | – | The journey written and skipped (`XCTSkip("waits on DX-7")`) | `UITests/DesignJourneyTests+ExportPack.swift` | DX-2 | ~100, 1 |
| DX-7 | – | Live: the journey turned on, on live services | `UITests/DesignJourneyTests+ExportPack.swift` | DX-6, DX-3, DX-4 | ~40, 1 |
| DX-8 | – | design.md: JPEG and exact pixel sizes in Export; `status: built`; `feature-done` | `docs/blueprints/design.md`, `docs/blueprints/design/features/export-pack.wave.json` | DX-7, DX-5, gradient-fill:DG-z | ~30, 2 |

## Build waves

- Wave 1: DX-1. Independent in this wave: DX-1 alone.
- Wave 2: DX-2, DX-3, DX-4. Independent in this wave: all three.
- Wave 3: DX-5, DX-6. Independent in this wave: both.
- Wave 4: DX-7. Independent in this wave: DX-7 alone.
- Wave 5: DX-8 (`feature-done`, final). Independent in this wave: DX-8 alone.

Longest chain: DX-1 → DX-2 → DX-6 → DX-7 → DX-8 (5). Chain of 5: the sheet needs the options, the journey drives the sheet, DX-7 turns it on live, DX-8 is the prose task.

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| DX-1 | compiles; existing export tests pass with `size: .scale`; JPEG is refused with its reason | an existing export changes | – (stub) |
| DX-2 | `DesignExportPackSnapshots.pixels` (DX-5's, first in the slice PR) | the row or chip is missing | – (UI) |
| DX-3 | `DesignExportPackTests`: 540 × 675 pt at `pixels(1080, 1350)` plans 1080 × 1350; `longEdge(512)` plans 410 × 512; SVG refuses Pixels with its reason; RJ-D41's plan half passes on Linux | a planned size is wrong | `DesignModel.DesignExport+Kernel`: scale applied after pixels → `.exactPixels`; JPEG keeps alpha → `.jpegFlattens` |
| DX-4 | `DesignRasterizerSizeTests` (macOS): the raster is exactly the planned size; the JPEG's transparent corner reads the fill | the raster is off by a pixel or the corner is black | – (macOS) |
| DX-5 | `DesignExportPackSnapshots`; `RenderBudgetDesignExportPackTests.typingWidthInTwoBodies` | budget over | – (UI) |
| DX-6 | compiles, skipped | – | – |
| DX-7 | `DesignExportPackJourneyTests.testExportPostAtExactSize` steps 1 to 4; RJ-D41 green on the macOS job | a step fails | – |
| DX-8 | `scripts/waves render --dry-run` | status not built | – |

## Quality tests

| quality row | budget | test |
|---|---|---|
| render: typing a width in the sheet | ≤ 2 window bodies per keystroke | `RenderBudgetDesignExportPackTests.typingWidthInTwoBodies` |
| Exact size | the JPEG decodes at the typed size | RJ-D41 |
| Audit | zero new over Design's baseline | `audit-design-*.json` |

## Done check

Per slice (rules 6, 15, 17, 21): DX-m merged-done; DX-u's feel gate and `Mac-Finish:`; DX-z's journey on live and RJ-D41 green on macOS. Then `Belt-Contact-Sheet:` with `design-export-*`.

## Not in this packet

Frame presets (S10), HEIC and WebP from Design, metadata (Design writes none), a JPEG background colour choice.
