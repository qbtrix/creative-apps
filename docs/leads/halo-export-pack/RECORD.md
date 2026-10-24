# export-pack lead record

Issue: #3472 (runs before used #4509) · Packet: docs/blueprints/halo/features/export-pack.md
Run: act-1a16958d5fe-8dxu · Started: 2026-10-23T15:26:44Z (took over from act-1a16474bd28-v3ht)
Stage: 4 wave 4 (HX-a #4841, HX-u #4858, HX-m #4874 + #4917, HX-z #4942 open)
Base: 721168a8 (origin/dev; the brief says main, CLAUDE.md and the lane use dev)
Next: HX-8 (halo.md, built, feature-done) once placed-images:PH-z is built; Belt-Slice-Done per slice once a green ci.yml run holds it

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| HX-a | codec and alpha settings, ProRes refused; Render sheet Codec row and Transparent checkbox | HX-1, HX-2 | - | gradient-fill:HG-a, placed-images:PH-a | yes | 0 | done #4841 (a8e0e252) | [40029046141](https://github.com/qbtrix/creative-apps/actions/runs/40029046141) | wanted |
| HX-m | codec and alpha plan rules, alpha frames, RJ-H41; live renderer through services.media.movie | HX-3, HX-4 | - | HX-a | no | 0 | pr #4874, #4917 | - | - |
| HX-u | snapshots, budget, journey skipped | HX-5, HX-6 | - | HX-a | yes | 0 | pr #4858 | - | - |
| HX-z | journey live; halo.md, built, feature-done | HX-7, HX-8 | HaloExportPackJourneyTests | HX-m, HX-u; gradient-fill:HG-z | yes | 0 | pr #4942 (HX-7); HX-8 waits on PH-z | - | - |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| HX-1 | HX-a | 1 | codec and alpha settings, stub refusal | Sources/HaloModel/Contracts/HaloDocumentValues.swift, Tests/HaloModelTests/HaloProResTests.swift | existing render tests; ProRes refused | #4841 | merged |
| HX-2 | HX-a | 2 | Codec row, Transparent checkbox | Sources/HaloApp/HaloRenderSheet.swift | HaloRenderProResSnapshots.sheet | #4841 | merged |
| HX-3 | HX-m | 2 | plan rules, alpha frames (RJ-H41 moves to HX-4) | Sources/HaloModel/HaloRenderJob.swift, see packet | HaloProResTests, HaloRenderAlphaTests | #4874 | pr |
| HX-4 | HX-m | 2 | live renderer via media.movie; HaloMovieWriter kept for fractional fps | Sources/HaloModel/Live/LiveCompositionRendering.swift, Sources/HaloApp/HaloMovieWriter.swift | HaloMovieSinkTests | #4917 | pr |
| HX-5 | HX-u | 3 | snapshots, budget | Tests/AppSnapshotTests/HaloRenderProResSnapshots.swift, Tests/AppSnapshotTests/RenderBudgetHaloRenderSheetTests.swift | codecSwitchInTwoBodies | #4858 | pr |
| HX-6 | HX-u | 3 | journey skipped | UITests/HaloJourneyTests+ExportPack.swift | compiles, skipped | #4858 | pr |
| HX-7 | HX-z | 4 | journey live; RJ-H41 as a pending job (#4929) | UITests/HaloJourneyTests+ExportPack.swift, Tests/RealJobs/halo/prores-alpha/prores-alpha.jobs.pending.json | testRenderLowerThirdWithAlpha | #4942 | pr |
| HX-8 | HX-z | 5 | halo.md, built, feature-done | docs/blueprints/halo.md, docs/blueprints/halo/features/export-pack.wave.json | waves render --dry-run | - | blocked |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- Record lives on lead/halo-export-pack at docs/leads/halo-export-pack/: lead/export-pack already belongs to the suiteui export-pack lead (#3477).
- Base dev, not main: CLAUDE.md, the fast lane and every other lead target dev.
- HX-m ships as two PRs, both `Slice: HX-m`. HX-3 holds the plan rules, the alpha refusal, .mov naming and flattening movie frames without alpha over opaque black (a composition has no background fill, so PNG frames stay as they were). HX-4 holds the media service and writer. Together they are over the 400-line cap.
- ProRes 4444 stays refused in the Codec row until HX-4 ("ProRes 4444 lands with HX-4."): HX-3 has no writer that can make one.
- RJ-H41 moves to the HX-4 PR. The CLI refuses render.start on Linux, and its catalog step takes no codec or alpha yet, so a real ProRes job is checkable only once the writer and those params exist.
- RJ-H41 ships with HX-7 as `prores-alpha.jobs.pending.json`: the headless CLI writes png only, so gap #4929 asks for a movie render on macOS; the job is renamed when that lands.
- HX-4's shared MovieWriter takes whole-number fps only. #4857 (needs-ui, line:suiteui) asks for a rational rate; HaloMovieWriter stays for fractional rates until then.

## Open
- HX-a blocked (2026-10-21T00:13Z): gradient-fill:HG-a done (#3516); placed-images:PH-a waiting (stage 0, waits on HS-a #3676 and suiteui PL-a).
- 2026-10-21T13:42:11Z check-in: still blocked; placed-images is at Stage 0, PH-a waits on HS-a (#3676), HK-a (key-editing) and PL-a.
- 2026-10-22T16:37:55Z: New run act-1a16474bd28-v3ht for #4509. Cross-line waits are met on dev 7e9f260: ExportRules/keepsAlpha (SuiteKernel/Export/ExportOptions.swift), MovieCodec/MovieSettings/.prores4444 (SuiteModel/Values/Media.swift), media.movie (MediaEncoding.swift, FakeMedia.swift), SuiteShell/Media/MovieWriter.swift. gradient-fill is built. PH-a #4426 is open (fast-lane, clean, waits on its macOS build).
- 2026-10-22T16:37:55Z: Decision: HX-a builds stacked on lead/halo-placed-images-PH-a (both touch HaloDocumentValues.swift, PH-a is A/C first); its PR opens after PH-a merges, as branch lead/halo-export-pack-HX-a.
- 2026-10-23T15:26:44Z: run act-1a16958d5fe-8dxu for #3472. The placed-images waits (PH-a, PH-u) are on dev, so HX-a is rebuilt on origin/dev 721168a8 from lead/halo-*-HX-a, its test commit first.
- Wire: HX-a's `HaloRenderSettings.codec`/`alpha` and `choosing(...)` are what HX-3 (plan rules) and HX-4 (media.movie settings) read.
- 2026-10-23T16:05Z: HX-a #4841 opened (Head b8579d50, Mutate HaloModel.HaloDocumentValues 2/2). HX-5's snapshots shipped in HX-a (first in the slice), so HX-u is the budget test and the skipped journey.
- 2026-10-23T16:12Z: HX-u #4858 opened, stacked on HX-a. #4857 filed. HX-3 is building on lead/halo-export-pack-HX-m.
- 2026-10-23T17:10Z: HX-3 #4874 opened, stacked on HX-u (Head 9612572f, Mutate HaloRenderJob 8/8, HaloRenderFrame 3/3, HaloDocumentValues 2/2). HX-4 (writers, codec rows, RJ-H41) is next.
- 2026-10-23T17:24Z: HX-4 #4917 opened, stacked on HX-3 (Head 363a1d9f, Mutate HaloMovieSink 4/4, HaloDocumentValues 2/2, HaloRenderFrame 3/3). HEVC and ProRes 4444 pickable; fractional fps refused for them in words. RJ-H41 is not in HX-4: it moves to HX-z with the live journey.
- 2026-10-23T22:35Z: HX-a #4841 merged to dev (a8e0e252, batch-20261023204921). HX-u #4858 merged origin/dev, gate PASS, retargeted to dev (Head dfda2847). HX-3 #4874, HX-4 #4917, HX-z #4942 stay stacked on HX-u. Belt-Slice-Done for HX-a waits on a green ci.yml run on dev.
- 2026-10-23T23:05Z: Belt-Slice-Done HX-a posted (Linux check run 40029046141 on dev 491ec546) with Mac-Finish-Wanted. HX-u #4858 waits on the lane batch.
- 2026-10-23T23:20Z: #4858 (HX-u) waits on a lane batch; HX-3 #4874 retargets when it merges. Open line:halo findings #5004 #4693 #4222 #3926 touch no export-pack file: findings 0.
- 2026-10-23T23:40Z: dev unchanged since 654fb363; the lane's macOS gate for batch 20261023215139 (run 40029779505) has run since 21:51, so #4858 wait for the next batch. No lane comments, no supervisor reply, no new findings.
- 00:02Z heartbeat: dev unchanged at 654fb363. Batch lane/batch-20261023215139 macOS gate 40029779505 ended in failure at 23:45 (its PRs are bisected, not ours). Our PRs wait for the next batch; no lane comment, no supervisor reply, 0 findings.
- 00:25Z heartbeat: dev unchanged at 654fb363; full CI 40037716897 on it is green. No lane run since batch 20261023215139's macOS gate failed at 23:45 (no bisect probes yet). #4868, #4858, #4894 still wait for a batch; no lane comment, no supervisor reply, 0 findings.
- 00:47Z heartbeat: dev unchanged at 654fb363. The lane is bisecting batch 20261023215139: probe -6 Linux 40044876845 green, macOS gate 40044879600 running since 00:25. Our PRs wait for the next batch; no lane comment, no supervisor reply, 0 findings.
- 01:09Z heartbeat: dev unchanged at 654fb363. Lane bisect probe -6 macOS gate 40044879600 still running (since 00:25). Our PRs wait for the next batch; no lane comment, no supervisor reply, 0 findings.
- 01:30Z heartbeat: dev unchanged at 654fb363. Lane bisect: probe -6 green on both (macOS 40044879600); probe -9 (Linux 40050009822, macOS 40050012604) running since 01:29. Our PRs wait for the next batch; no lane comment, no supervisor reply, 0 findings.
