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

The runnable check is `Tests/DesignModelTests/SpikeEditAtPlayheadTests.swift`. It prints what each edit shows at 1 s against what was asked for. Its run is in the same queued release job (see (b)). The table below comes from reading the code, and the test confirms the same behaviour.

Survey of all 11 `Sources/DesignModel/Live` editors, by reading. "Write-back" means the editor writes the rest pose (`frame`, `opacity`) on an axis a key overrides, so it needs a rule: write the key at the playhead (auto-key), or offset the whole track.

| Editor | What it does at playhead 1 s today | Needs |
|---|---|---|
| LiveTransforming (move, nudge, resize, delete) | `move` and `nudge` translate the rest frame, and the x and y keys win when sampled, so the node does not move on screen. `resize` builds its box from the rest frame, not the shown one, so it anchors to where the node was at rest. Width and height are not keyed, so they change. | write-back (x, y), plus reading the sampled box for resize |
| LiveAligning (align, distribute) | Reads the rest frames, computes the targets and translates the rest frames, so it aligns the rest poses and the shown nodes stay unaligned. | write-back, plus reading the sampled frames |
| LiveDuplicating | The copy goes through `layerTree.duplicate` and `init(id:copying:)` (see the time-kept line above). The offset translates the rest frame only. The absolute keys are copied unchanged, so the copy plays on top of the original. | write-back: offset the copied tracks |
| LiveClipboard (copy, paste) | Copy is Codable, so time survives. Paste offsets by +10,+10 through `translate` with the same flaw as duplicate. Pasting into another frame keeps absolute keys against a new parent delta. | write-back: offset the tracks, and rebase them on reparent |
| LiveGrouping (group, ungroup) | The new group's frame is the union of the rest boxes, so the group's bounds and handles are wrong at the playhead. The group has no time, which is correct. | sampled read for the box (and a rule for keying a group) |
| LiveStyling (frame fields, opacity, fill, radius, stroke, text) | `setFrame` x and y translate the rest frame, and the key wins. `setOpacity` writes rest opacity, and the key wins. Width, height, fill, radius, stroke and text are not keyed, so they work. | write-back (x, y, opacity) |
| LiveOrdering (reorder, reparent) | Reorder is fine. Reparenting into a frame whose x is keyed puts the node under a new parent delta, so it jumps by that delta. | write-back: rebase the tracks on reparent |
| LiveMarquee | Hits the rest frames, so it selects what was there at rest. | sampled read only |
| LiveFraming (zoom to selection) | Frames the rest boxes. | sampled read only |
| LiveFiling | Saves and reads `time` (see the file line above). Version 1, not bumped: an older build drops `time` on resave without a word. | format rule (version bump) |
| DesignSVG | Exports the rest pose unless it is fed `page.sampled(at:)`. | sampled read only |

Non-editor paths: snapping (`DesignSnapping+Kernel`) snaps to the rest frames of the other nodes. `handle(at:)` and the selection box use the rest frame, so handles and hit-testing disagree with the drawn node. The canvas live drag (`DesignLiveDrag`) writes `translate` on the live copy, so a drag of a keyed node does not move on screen.

**Count: 7 of 11 editors need a write-back rule** (Transforming, Aligning, Duplicating, Clipboard, Grouping, Styling, Ordering). 3 need only a sampled read (Marquee, Framing, SVG), and 1 needs a format rule (Filing). Snapping, handle hit-testing and the live drag add **3 more non-editor paths**. Rules shared by several editors: (1) auto-key x, y or opacity at the playhead when the axis is keyed, otherwise write the rest pose; (2) offset whole tracks on duplicate and paste; (3) rebase tracks on reparent; (4) read the sampled tree for boxes, snapping and handles.

## (b) Playback

**Not measured yet.** The release build sat in the counted gate pool for 64 min at LOW priority behind 8 holders (the bug-fix lanes, mac-finish lanes, kiln and supfix), and never started. A detached runner, `.build/spike/run.sh` in the worktree, keeps re-queuing it. Progress goes to `.build/spike/progress.log`, and the SPIKE lines go to `.build/spike/results.txt`. The tests that produce the numbers are committed: `Tests/AppSnapshotTests/SpikeOneDocumentTests.swift`.

Method: `playback()` runs 242 frames, each one PlaybackTiming tick per document frame, then layout and display forced (RenderBudgetWindow.timed's method). A dropped frame is a step over 8.3 ms at 120 Hz, and over 16.7 ms at 60 Hz. Body counts come from `DesignWindow.bodyRuns`. That runs for the painter, then for one pre-rastered lift of the whole frame on `CanvasHostView.showLiveLayer` / `moveLiveLayer`. There is no QB-L4 row in `Tests/render-budgets.md`, so this copies the Halo play-row method.

Already known from the code: `CanvasHostView` holds **one** lift (`lifted`). A per-node lift of 500 nodes is not possible on today's API. A compositor-deferred hero can only lift a whole pre-rastered frame, or a selection, as one layer. Per-node layers are H6 work.

## (c) Raster cost

Pending, with the same runner. `rasterCost()` times the sampled 50- and 500-node trees through DesignArtwork with ImageRenderer at 2x, and reports per-node microseconds plus the sampling cost on its own. `playLongForSample()` plays the 500-node fixture for 24 s while the runner takes `sample <pid> 20 1` into `.build/spike/sample.txt`.

## (d) Big-document drag

Pending, with the same runner. `crowdDrag()` runs RenderBudgetDesignTests' 120-sample drag on the plain crowd, then on `keyedCrowd` sampled at 1 s, in the same session. The baseline is today's 4.1 ms p95 / 6 ms budget, 3 bodies (render-budgets.md). The audit's 57-63 ms is not from this harness: #4479 is the design-seams packet issue and carries no number. Expect the sampled run to cost at least one full `page.sampled` tree copy of 2k nodes per sample. The sampler walks and copies the whole tree on every body.

## Verdict

Provisional. Only (a) has evidence; (b)-(d) wait on the queued run.

- **Hero range:** (a) supports the **low half of H4+H4b+H5 (about 22-30 h)** as long as time stays top-level with no full interleave. That is 7 editors plus 3 paths, but only 4 shared rules (auto-key at the playhead, track offset on copy, track rebase on reparent, sampled reads), so the cost doesn't grow per editor. Keep the hero at **140-290 h** until (b)-(d) land. Nothing yet moves H6-H9.
- **Staged (compositor-deferred) hero:** not decided. One known limit: CanvasLiveLayer lifts one layer, so staging means painter playback, or one whole-frame lift, which only fits playback that never edits.
- **Surprises:** (1) Dragging a keyed node at a non-zero playhead does nothing on screen. The key overrides the rest pose that the live drag writes, so auto-key is hero-critical, not polish. (2) Absolute frames force subtree translation at sample time, and they make reparenting jump a node by the new parent's delta, so the track-rebase rule is needed even for the hero. (3) The read side is cheap only for draw and export. Hit-testing is a Model function with no playhead, and handles, snapping, marquee and framing all read rest frames, so the "page.painted de-risks reads" claim misses interaction.
