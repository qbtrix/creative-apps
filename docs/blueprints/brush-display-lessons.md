# Brush display: lessons from making the Photo brush instant

What the Photo brush work (#701, #720, #728 and the tile canvas after them)
taught about this factory. Read it before you touch Photo's canvas path or
measure anything on it.

## What cost what, per brush event (4000 x 3000 canvas, one 256 px tile dirty)

| Cause | Where | Cost |
|---|---|---|
| Copy-on-write copy of the previous frame | `PhotoRenderer.render(after:)`: `var bytes = reusable.rgba8` while CanvasRenderer still held the old frame | 48 MB |
| Observation comparing frames | `@Observable` compares an `Equatable` value before it notifies, and `PhotoFrame` held the whole canvas | about 245 ms on the main actor in debug |
| Full-size picture | `Data(rgba8)` plus a new 48 MB CGImage that Core Animation re-uploads | 48 MB |
| Whole editor per pointer sample | every `model.drag` moved the revision; the Curves histogram recounted | a SwiftUI pass and a histogram per sample |

Before, from CI (debug, macOS 26 runner, run 38509968784): total p50 432 ms,
p95 517 ms; allocated p50 102 MB per event; 48 MB picture per event; 119 of
119 events over the byte budget. The captain's release build: p50 13.3 ms.

## Quirks

- **`@ObservationIgnored` for big Equatable values.** The Observation macro
  skips notifying when an `Equatable` value is unchanged, so it compares old
  and new on every set. Never keep a pixel buffer in an observed property.
- **Copy-on-write hides in "reuse the last frame".** Any array that two owners
  hold is copied whole on the first write. A renderer should hand out only
  what changed (the dirty tiles), not a canvas-sized value.
- **`cacheDisplay(in:to:)` draws through `draw(_:)`, not your sublayers.** The
  snapshots use it. A view that shows its picture in hand-made CALayers must
  also draw the same picture in `draw(_:)`, or the snapshot shows the
  checkerboard. `wantsUpdateLayer` true with an empty `updateLayer()` keeps
  the live path on the layers.
- **Seams between tile layers** come from edge antialiasing at fractional
  positions. `edgeAntialiasingMask = []` on each tile layer removes them
  (Core Animation's own documentation says so). PhotoTileCanvasTests checks
  an opaque image stays opaque at zooms that put tile edges between pixels.
- **Premultiplied bytes for Core Animation.** A straight-alpha CGImage is
  converted before display. CoreRaster's `rgba8()` is straight, so
  `PhotoRenderer.premultiplied(_:)` premultiplies the 8-bit bytes, and the
  reference is premultiplied the same way.
- **SwiftUI transforms and AppKit views.** The Straighten preview used
  `.rotationEffect` on an `Image`. On an `NSViewRepresentable` the tile view
  turns its own container layer instead.
- **Mouse input stays in CanvasViewport.** Taking clicks in the tile view would
  bypass SuiteUI's focus and Space-pan handling, and SuiteUI is another
  line's target. The view's `hitTest` returns nil. StrokePacer already
  applies input once per display frame.
- **Clone's Option press.** #713 added `sampling:` to `drag`. A batched drag
  (`drags`) must carry it per sample, or an Option-press in a batch is lost.

## Tooling in a cloud session

- No Swift toolchain is preinstalled. The swift.org tarball for
  6.3.3 / Ubuntu 24.04 unpacked under `/opt/swift` runs `scripts/ci` (about
  4 minutes cold).
- `gh` works for REST reads through the proxy even though `gh auth status`
  says the token is invalid. GraphQL (`gh pr view`) is refused; use
  `gh api repos/...`.
- `gh workflow run ci.yml` and the GitHub MCP dispatch both return
  `403 Resource not accessible by integration`. A worker can't start a
  macOS run. The sanctioned route is the `feature-done` label on the slice's
  last PR (the lane dispatches CI on dev once it merges), or a human
  dispatch.
- Run logs are readable: `gh api repos/qbtrix/creative-apps/actions/jobs/<id>/logs`.
  The BRUSH-LATENCY and BRUSH-DISPLAY lines are printed there too.
- The repro tests merged as one squash (#701). Rebase follow-ups onto dev and
  drop the original test commits.
- Stacked PRs don't fit the lane: its 400-line cap counts the diff from the
  merge base, so a stacked PR counts its parent's lines too. Open the next PR
  after the parent merges, from the same branch restarted on dev.
