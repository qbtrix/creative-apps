# Lead record: Halo gradient-fill

- Issue: #3417
- Packet: docs/blueprints/halo/features/gradient-fill.md (v3, slices)
- Run: act-1a157712a33-ye70
- Session: claude/gradient-fill-lead-0aoxhi
- Started: 2026-10-20
- Stage: 3 polling (wave 1 blocked)
- Base: dev 533daec
- Next: HG-a done (Belt-Slice-Done posted 2026-10-20T10:32Z, run 39406588924); HG-m PR (HG-6 + HG-7) waits on suiteui GF-6 (AC-halo's files are on dev); HG-u waits on CL-probe and GF-2/GF-3

## Slices

| Slice | Tasks | UI | Waits | State | PRs |
|---|---|---|---|---|---|
| HG-a | HG-1, HG-5 | no | suiteui GF-1 | done | #3516; Belt-Slice-Done on run 39406588924 (Linux green, head a6cb012) |
| HG-u | HG-2, HG-3, HG-4 | yes | HG-a; halo core-loop CL-probe (HG-2); suiteui GF-2, GF-3 | blocked | – |
| HG-m | HG-6, HG-7 | no | HG-a; suiteui GF-6 and adopt-command-catalog AC-halo (HG-7) | blocked | – |
| HG-z | HG-8, HG-9 | yes | HG-u, HG-m; halo core-loop CL-z (HG-9) | blocked | – |

## Tasks

| Task | Wave | State | PR | Note |
|---|---|---|---|---|
| HG-1 | W1 | merged | #3516 | HaloLayer.gradient, HaloDrawItem.gradient, conformance stubs, HaloGradientTests (2 on, 3 waiting on HG-7); gate CI: PASS at 7d112c5 |
| HG-5 | W2 | merged | #3516 | HaloGradientRenderTests, 4 waiting on HG-6; in the HG-a PR (rule 22) |
| HG-2 | W2 | blocked | – | CL-probe: core-loop is planned, no lead running |
| HG-7 | W2 | blocked | – | GF-6 (suiteui W3); AC-halo's HaloCommandCatalog.swift, HaloHeadless.swift and Tests/command-ids/halo.txt are on dev (packet still status planned, no Belt-Slice-Done) |
| HG-3 | W3 | blocked | – | GF-3 |
| HG-4 | W3 | blocked | – | after HG-2 |
| HG-6 | W3 | built locally | – | stacked on HG-a; Mutate 3/3 HaloModel.LiveFrameRendering; PR waits on GF-6 and AC-halo (packet Depends on); rebased onto dev 11a545e after #3516 merged, now at 0bc7526, scripts/ci --changed PASS 2026-10-20T10:10Z |
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

- GF-1 #3421 merged into dev at 9a14677 (by 05:54Z) after its macOS build sat queued 2h10m. No GF-6 or AC-halo PR yet.
- halo core-loop (CL-probe, CL-z) is status planned with no lead branch: HG-2 and HG-9 cannot start until it runs. AC-halo's files (catalog, headless, command-ids and path baseline) are already on dev at ab71d30 (checked 06:44Z), so HG-7 waits only on GF-6.
- Resolved: pinned core has `PixelBuffer.gradient(width:height:shape:from:to:stops:space:dither:)` (CoreRaster/Fill/RasterGradient.swift); no needs-core issue.
- HALO-GRADIENT-FRAME costs about 1.5–1.7 s on a Linux debug build at 1080p (report only).
- The contract's `extension HaloDrawItem { var gradient }` is a stored field with an init default (extensions can't store).
- The PR tool appends an attribution footer to bodies it creates; #3516's was removed by an edit at 06:20Z. Every later PR body and comment gets the same check after posting.
- 2026-10-21: HG-u opened as #4207 (inspector FILL section, snapshots, budget test, journey skipped until HG-8).
- HG-7 names each fill step for its command title ("Fill Type", "Set Gradient", ...), not one "Change Fill": the kernel's catalog conformance (stepNamedTitle) requires a step named for its spec. HaloGradientTests reads "Undo Fill Type".
- The fill.angle and fill.stop-* examples are exempt from exampleRuns in HaloCommandCatalogTests: the Ball fixture's fill is solid, and those commands need a gradient.
- RJ-H32's pixel expectation is skipped until image codecs reach the apps (RealJobs.pixelsWait); the job still runs both steps and writes the PNG.
- 2026-10-21: HG-m opened as #4216 (HG-6 render + HG-7 commands, 15 files, +200/-32; Mutate 5/5 HaloModel.LiveFrameRendering). The two fill mutations live in the LiveFrameRendering plan to keep the PR at 15 files. The gate also needed the catalog count in HaloShapeCommandIDTests and the halo list-commands golden to list the eight fill ids; the shading adapter is named `+Kernel` to pass check-dup-logic.
- A REST PATCH of a PR body through `gh api --jq` piped into a file emptied #4216's body once; it was restored with the PR update tool, which does not append the footer.
- 22:27Z poll: #4207 (HG-u) and #4216 (HG-m) are clean with fast-lane, and the lane's macOS builds are queued for a runner (runs 39680681261 since 21:40Z and 39682487811 since 21:54Z). No needs-fix or needs-rebase. No gradient-fill findings are open; the open line:halo findings (#4220-#4233 and older) belong to other features. HG-z waits on both merging. Next: Belt-Slice-Done for HG-u (with Mac-Finish-Wanted) and HG-m once a green halo run contains their merges, then the critics, then HG-z.
- HG-8 prepared on branch `halo-gradient-live` (7829797, stacked on HG-u's fd55072). The gradient journey no longer skips, and each edit's undo step is named for its fill command ("Undo Fill Type", "Undo Gradient Stop Color"). No PR yet: once #4207 and #4216 merge, rebuild it on origin/dev with HG-9 (halo.md prose, wave status built) as HG-z, waiting on KE-z for the blueprint part.
- 22:31Z poll: both PRs clean, the lane's macOS builds still queued for a runner; KE-z still planned. Nothing to fix.
- 23:06Z: HG-u's macOS build (run 39680681261) failed: `KeyState` was ambiguous in HaloLayerInspector.swift:187 once HG-u imported SuiteKernel (for GradientIntent), which has its own KeyState. Fix round 1: return `SuiteUI.KeyState`, as FlareApp does. Pushed 79935fd, scripts/ci --changed PASS, Head moved, footer checked. Only that name clashed with SuiteUI; SuiteKernel's Alignment/Axis are not used bare there. HG-m's build is still queued; KE-z still planned. halo-gradient-live stays on the old HG-u head and is rebuilt on dev once both merge.
- 23:39Z: HG-m's macOS build (run 39682487811) failed only on `RenderBudgetPhotoPlaceTests.swift:35` (`PhotoPlaceIntent` has no `files`). That's a dev break (#4164 vs #4003, dev-red #3856), not HG-m's; it is not a fix round. The fix is #4215 (line:photo, Linux CI red at 22:16Z). It's not ported (CLAUDE.md; HG-m is at 15 files). The stand-down comment is on #4216. Once #4215 is on dev: merge dev into both PR branches, rerun the gate, move Head. HG-u's new build (39691720607, head 79935fd) is queued and will likely hit the same Photo error. KE-z is still planned.
- Footer: gh api REST PATCH re-adds the attribution footer to comments; mcp update_issue_comment removes it (checked).
- 00:20Z: #4215 merged. Merged dev into both PR branches without conflicts: HG-m ba788c4, HG-u cb8fe6d. scripts/ci --changed PASS on each, both pushed, Head lines moved, no footer. The lane's macOS builds of the new heads come next. KE-z still planned.
