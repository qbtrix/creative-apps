<!-- One-document (Option B) spike: evidence for the audit at docs/design/drafts/2026-10-29-one-document-audit.md (paw-workspace). Branch spike/one-document, never merged. -->
# One-document spike: time on DesignNode, measured

Branch `spike/one-document` off dev `af21f2093e`. It is never merged. It builds the minimum for the four measurements:

- `DesignNodeTime` (x, y and opacity tracks of the kernel's `Keyframe`) lives in `DesignNodeExtrasBox`, so the node stays small and `init(id:copying:)` copies it with the box. `init(from:)` reads it with `decodeIfPresent`, and `encode(to:)` writes it with `encodeIfPresent`, so files without time stay byte for byte as before.
- `DesignNode.sampled(at:)` and `DesignPage.sampled(at:)`. Frames are absolute page points, so sampling a node moves its whole subtree by the node's delta (`translate(by:)`), and each child then adds its own keys.
- The chokepoint: `DesignCanvas` paints `page.sampled(at:).painted` when `DesignSpikeClock.shared.frame` is set. `hitTest` goes through `nodes.hit` on the sampled tree when `DesignWorkspace.spikePlayhead` is set. Both are nil by default, so the product is unchanged.
- Fixtures: `DesignFixtures.animated(50 | 500)` is one UI frame whose rectangles are keyed on x, y and opacity over 2 s (frames 0 to 120 at 60 fps). The frame itself is keyed on x. `keyedCrowd` is the 2k crowd with every rectangle keyed.
- Playback: `PlaybackTiming.tick` drives it, with one tick per document frame in the tests. `DesignSpikeClock.play()` is a 120 Hz Timer standing in for a display link. There is no product UI.
- LiveFiling stays at version 1 in the spike. A real bump to version 2 needs `LiveFiling.decode` to accept 1 and 2, `encode` to write 2 only when some node has time (so still files stay version 1 and readable by older builds), a refusal test showing a version-1-only build refusing a version-2 file, and a DesignRecovery+Kernel check that recovery files carry the version too.

Measured on a release build (`-c release -Xswiftc -enable-testing -Xswiftc -DDEBUG`; `-DDEBUG` compiles in the window body counter at `-O`). Machine: the shared M2 Pro 16 GB, under the usual multi-agent load, so absolute numbers are noisy. Baselines and variants run in the same session.

## (a) Edit at a non-zero playhead

Measured: release build, `SpikeEditAtPlayheadTests`, the keyed 50-node fixture at frame 60 (1 s). node-2 shows x 47, y 40, opacity 0.65. Its rest x is 30.

| Edit at 1 s | Asked for | Shown after the edit |
|---|---|---|
| LiveTransforming.move | +100 x | **+0** (key wins) |
| LiveTransforming.nudge right, large | +10 x | **+0** |
| LiveTransforming.resize bottom-right | +20 w, +20 h | w 24 to 44, origin unchanged (works, because size is not keyed) |
| LiveAligning.align left (node-2, node-30) | both at x 47 | **47 and 209**, unchanged |
| LiveDuplicating | copy at +10, +10 | **copy exactly on top of the original (+0, +0)**. The copy keeps its time (true). |
| LiveStyling.setFrame x | 500 | **47** |
| LiveStyling.setOpacity | 0.9 | **0.65** |
| hitTest through the sampled tree | | node-2 at (52, 40); the sampled path works |
| LiveFiling round trip | | 1,159 bytes for 1 keyed node; reopen keeps time (true) |

## (b) Playback

Release build (`-O`, plus `-DDEBUG` for the body counter). The shared M2 Pro was loaded by about 8 other gate jobs. `playback()` runs 242 frames, each one PlaybackTiming tick per document frame, with layout and display forced per frame. There is no QB-L4 row in render-budgets.md, so a dropped frame here is a frame over budget.

| SwiftUI painter playback | p50 | p95 | max | over 8.3 ms (120 Hz) | over 16.7 ms (60 Hz) | window bodies |
|---|---|---|---|---|---|---|
| 50 nodes | 0.94 ms | 13.91 ms | 43.4 ms | 19 / 242 (7.9%) | 8 / 242 (3.3%) | **0** |
| 500 nodes | 1.49 ms | 13.07 ms | 70.5 ms | 22 / 242 (9.1%) | 8 / 242 (3.3%) | **0** |

- **Window bodies are 0 per frame.** Only the canvas observes the clock, so the audit's "0 bodies per frame" bar is met for free. That is better than Halo's 24 bodies/s precedent.
- p50 grows only 0.55 ms from 50 to 500 nodes, so per-node cost is not the issue. The p95 and max tail is the same at 50 and 500 nodes, which points at machine load (8 gate holders), not node count. It needs a quiet-machine rerun before it is read as a fidelity problem.
- 24 s of unthrottled playback of the 500-node fixture ran **241.8 fps** (about 4.1 ms per full frame, including the forced display).
- **No CanvasLiveLayer comparison was possible:** `SPIKE lift: no CanvasHostView in the Design window`. Design's canvas (CanvasViewport) is not hosted on SuiteUI's `CanvasHostView`, so Design has no live layer at all today. A lift needs Design moved onto CanvasHostView first (part of H6/H8). On top of that, CanvasHostView holds one lift (`lifted`), so per-node lifts would be new work.
- **Compositor deferral:** at 500 rect nodes, the painter meets 60 Hz at p50 with 0 window bodies, so the compositor can be deferred for a hero of this size.

## (c) Raster cost

`rasterCost()`, release, ImageRenderer of the sampled tree through DesignArtwork at 2x, 31 frames:

| Fixture | Sample the tree only | Sample plus raster p50 | p95 | p50 per node |
|---|---|---|---|---|
| 50 nodes | 0.004 ms | 0.10 ms | 0.34 ms | 1.9 us |
| 500 nodes | 0.042 ms | 0.48 ms | 2.22 ms | **1.0 us** |

Sampling costs about 0.08 us per node. Hundreds of plain vector nodes fit inside one 120 Hz frame (8.3 ms) with about 8,000 nodes of headroom at this rate. Caveat: the fixtures are solid rounded rectangles. Text, gradients, strokes and placed pictures cost more and were not measured. `sample <pid> 20 1` of the 24 s playback: **not captured.** Both tries attached to the wrong process: a log-line trigger lost to swift test's output buffering, and the `pgrep -f` pattern matched its own zsh. Next try: `sample $(pgrep -nx swiftpm-testing-helper) 20 1` about 10 s into `--filter playLongForSample`. The in-test timings above stand in for it: about 1 us per node, and 241.8 fps unthrottled on the 500-node fixture.

## (d) Big-document drag

`crowdDrag()`, release, the 120-sample RenderBudgetDesignTests drag on the 2k crowd, both runs in the same session:

| Run | step p50 | step p95 | window bodies | layout passes |
|---|---|---|---|---|
| plain crowd, no sampler | 35.5 ms | **80.0 ms** | 2 | 128 (857 ms) |
| keyed crowd, sampled at 1 s | 35.3 ms | **68.4 ms** | 2 | 127 (478 ms) |

- **The sampler adds nothing measurable.** The keyed run was even a little faster, which is within the noise of a loaded machine.
- Under today's load, both runs sit at about 11-13x the 6 ms budget. That matches the audit's "about 10x over" (57-63 ms). render-budgets.md's 4.1 ms p95 came from a quiet machine. H19's cost is the existing crowd-drag problem (the 2k-node painter and layout), not time.

## Verdict

- **Hero range: about 140-230 h**, down from 140-290. The audit's high case on two axes doesn't hold. (a) confirms 7 write-back editors but only 4 shared rules, so H4+H4b+H5 sits near the low case (about 22-30 h, not 43 h) as long as time stays top-level. (b) and (c) show that painter playback of 500 rect nodes costs 0 window bodies and about 1 us per node, so H6-H9 can stage at about 34 h, not 67 h. H19 does not grow because of time. The crowd drag is over budget with or without the sampler.
- **The staged, compositor-deferred hero is viable** for UI-scale documents (hundreds of plain vector nodes) on the SwiftUI painter. Two conditions: the 60 Hz tail (3.3% of frames over 16.7 ms, under load) needs a quiet-machine rerun, and text, gradient and stroke nodes still need costing. The compositor is not just deferred but further away than the audit assumed. Design isn't on CanvasHostView at all, so H6 starts with moving Design's canvas onto it.
- **Surprises:**
  1. Every rest-pose edit on a keyed axis does nothing on screen: move, nudge, set x, set opacity, align, and duplicate's offset (the copy lands exactly on the original). Auto-key at the playhead is hero-critical. It is not polish.
  2. The sampler is free: 0.04 ms for 500 nodes, and no change to the 2k drag p95. Time costs nothing on the read side. All the cost sits in edit semantics.
  3. Design has no CanvasHostView, so no live layer exists to defer to. Also, the crowd drag measures 68-80 ms p95 under load against the doc's 4.1 ms, so render-budgets.md's Design row reflects a quiet machine only.
