# Lead record: Halo gradient-fill

- Issue: #3417
- Packet: docs/blueprints/halo/features/gradient-fill.md (v3, slices)
- Run: act-1a157712a33-ye70
- Session: claude/gradient-fill-lead-0aoxhi
- Started: 2026-10-20
- Stage: 3 polling (wave 1 blocked)
- Base: dev 533daec
- Next: wait for suiteui GF-1 (#3421) to merge (Sources/SuiteKernel/Fill/ on dev); then start wave 1 (HG-a: HG-1 + HG-5)

## Slices

| Slice | Tasks | UI | Waits | State | PRs |
|---|---|---|---|---|---|
| HG-a | HG-1, HG-5 | no | suiteui GF-1 | blocked | – |
| HG-u | HG-2, HG-3, HG-4 | yes | HG-a; halo core-loop CL-probe (HG-2); suiteui GF-2, GF-3 | blocked | – |
| HG-m | HG-6, HG-7 | no | HG-a; suiteui GF-6 and adopt-command-catalog AC-halo (HG-7) | blocked | – |
| HG-z | HG-8, HG-9 | yes | HG-u, HG-m; halo core-loop CL-z (HG-9) | blocked | – |

## Tasks

| Task | Wave | State | PR | Note |
|---|---|---|---|---|
| HG-1 | W1 | built locally | – | HaloLayer.gradient, HaloDrawItem.gradient, conformance stubs, HaloGradientTests (2 on, 3 waiting on HG-7); PR opens once GF-1 is on dev |
| HG-5 | W2 | built locally | – | HaloGradientRenderTests, 4 waiting on HG-6; in the HG-a PR (rule 22) |
| HG-2 | W2 | blocked | – | CL-probe: core-loop is planned, no lead running |
| HG-7 | W2 | blocked | – | GF-6 (suiteui W3); AC-halo: adopt-command-catalog is planned, no lead running |
| HG-3 | W3 | blocked | – | GF-3 |
| HG-4 | W3 | blocked | – | after HG-2 |
| HG-6 | W3 | built locally | – | stacked on HG-a; Mutate 3/3 HaloModel.LiveFrameRendering; PR waits on GF-6 and AC-halo (packet Depends on); gate CI: PASS at 1af5780 |
| HG-8 | W4 | blocked | – | after HG-4, HG-6, HG-7 |
| HG-9 | W5 | blocked | – | CL-z |

## Reviews

| Slice | Round | Run | Findings | Verdict |
|---|---|---|---|---|

## Decisions

- Base is dev (CLAUDE.md; the lane retargets main to dev).
- Record lives at docs/leads/halo-gradient-fill/ on lead/halo-gradient-fill: lead/gradient-fill is the Flare lead's.
- HG-1 waits on GF-1 merging only, not the whole GF-a slice: HG-1 uses only the Fill types and GradientFillTarget; GF-2's editor matters only to HG-2.
- HG-6 render tests sample a 65 px box (33 px when moved): an odd size puts a pixel centre on the gradient's centre; at 64 px the centre pixel sat at t≈0.016, which perceptual interpolation reads as r 0.905.
- RJ-H32 (gradient-frame real job) lands with HG-7: its script runs `fill.gradient`, which needs GF-6 and AC-halo.
- Model targets already depend on SuiteKernel (Package.swift line 60), so no package change is needed.

## Open

- GF-1 #3421: open, mergeable clean; its lane macOS build (run 39364860084) still queued at 04:16Z, no runner.
- halo core-loop (CL-probe, CL-z) and suiteui adopt-command-catalog (AC-halo) are status planned with no lead branch: HG-2, HG-7 and HG-9 cannot start until those run.
- Resolved: pinned core has `PixelBuffer.gradient(width:height:shape:from:to:stops:space:dither:)` (CoreRaster/Fill/RasterGradient.swift); no needs-core issue.
- HALO-GRADIENT-FRAME costs about 1.5–1.7 s on a Linux debug build at 1080p (report only).
- The contract's `extension HaloDrawItem { var gradient }` is a stored field with an init default (extensions can't store).
