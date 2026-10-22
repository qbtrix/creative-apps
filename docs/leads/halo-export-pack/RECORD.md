# export-pack lead record

Issue: #4509 (was #3472) · Packet: docs/blueprints/halo/features/export-pack.md
Run: act-1a16474bd28-v3ht · Session: claude/halo-feature-lead-3yp4w1 · Started: 2026-10-22T16:00Z (took over from earlier runs)
Stage: 3 wave 1 (HX-a building, stacked on PH-a)
Base: 2cc149f57 (origin/dev; the brief says main, CLAUDE.md and the lane use dev)
Next: HX-a PR opens when PH-a #4426 merges; then HX-m and HX-u stacked on HX-a

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| HX-a | codec and alpha settings, ProRes refused; Render sheet Codec row and Transparent checkbox | HX-1, HX-2 | - | gradient-fill:HG-a, placed-images:PH-a | yes | 0 | blocked | - | - |
| HX-m | codec and alpha plan rules, alpha frames, RJ-H41; live renderer through services.media.movie | HX-3, HX-4 | - | HX-a | no | 0 | blocked | - | - |
| HX-u | snapshots, budget, journey skipped | HX-5, HX-6 | - | HX-a | yes | 0 | blocked | - | - |
| HX-z | journey live; halo.md, built, feature-done | HX-7, HX-8 | HaloExportPackJourneyTests | HX-m, HX-u; gradient-fill:HG-z | yes | 0 | blocked | - | - |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| HX-1 | HX-a | 1 | codec and alpha settings, stub refusal | Sources/HaloModel/Contracts/HaloDocumentValues.swift, Tests/HaloModelTests/HaloProResTests.swift | existing render tests; ProRes refused | - | blocked |
| HX-2 | HX-a | 2 | Codec row, Transparent checkbox | Sources/HaloApp/HaloRenderSheet.swift | HaloRenderProResSnapshots.sheet | - | blocked |
| HX-3 | HX-m | 2 | plan rules, alpha frames, RJ-H41 | Sources/HaloModel/HaloRenderJob.swift, see packet | HaloProResTests | - | blocked |
| HX-4 | HX-m | 2 | live renderer via media.movie; HaloMovieWriter deleted | Sources/HaloModel/Live/LiveCompositionRendering.swift, Sources/HaloApp/HaloMovieWriter.swift | HaloMovieSinkTests | - | blocked |
| HX-5 | HX-u | 3 | snapshots, budget | Tests/AppSnapshotTests/HaloRenderProResSnapshots.swift, Tests/AppSnapshotTests/RenderBudgetHaloRenderSheetTests.swift | codecSwitchInTwoBodies | - | blocked |
| HX-6 | HX-u | 3 | journey skipped | UITests/HaloJourneyTests+ExportPack.swift | compiles, skipped | - | blocked |
| HX-7 | HX-z | 4 | journey live | UITests/HaloJourneyTests+ExportPack.swift | testRenderLowerThirdWithAlpha | - | blocked |
| HX-8 | HX-z | 5 | halo.md, built, feature-done | docs/blueprints/halo.md, docs/blueprints/halo/features/export-pack.wave.json | waves render --dry-run | - | blocked |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- Record lives on lead/halo-export-pack at docs/leads/halo-export-pack/: lead/export-pack already belongs to the suiteui export-pack lead (#3477).
- Base dev, not main: CLAUDE.md, the fast lane and every other lead target dev.

## Open
- HX-a blocked (2026-10-21T00:13Z): gradient-fill:HG-a done (#3516); placed-images:PH-a waiting (stage 0, waits on HS-a #3676 and suiteui PL-a).
- 2026-10-21T13:42:11Z check-in: still blocked; placed-images is at Stage 0, PH-a waits on HS-a (#3676), HK-a (key-editing) and PL-a.
- 2026-10-22T16:37:55Z: New run act-1a16474bd28-v3ht for #4509. Cross-line waits are met on dev 7e9f260: ExportRules/keepsAlpha (SuiteKernel/Export/ExportOptions.swift), MovieCodec/MovieSettings/.prores4444 (SuiteModel/Values/Media.swift), media.movie (MediaEncoding.swift, FakeMedia.swift), SuiteShell/Media/MovieWriter.swift. gradient-fill is built. PH-a #4426 is open (fast-lane, clean, waits on its macOS build).
- 2026-10-22T16:37:55Z: Decision: HX-a builds stacked on lead/halo-placed-images-PH-a (both touch HaloDocumentValues.swift, PH-a is A/C first); its PR opens after PH-a merges, as branch lead/halo-export-pack-HX-a.
