# tone-controls lead record

Issue: #3468 · Packet: docs/blueprints/photo/features/tone-controls.md
Run: act-1a15eecbafe-u0f9 · Session: claude/photo-feature-lead-batch-gdxv4u · Started: 2026-10-21T14:20Z (takes over from the earlier runs below)
Stage: 3 W1 blocked (run act-1a15eecbafe-u0f9)
Base: b70dcb71e33b073d8e17f60683fea8c36db02f65
Next: blocked: suiteui tone-controls TC-a (#3476) has no Belt-Slice-Done and dev has no ToneTarget/ToneRows; PT-1 starts when it lands; checked 16:35Z

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| PT-a | AdjustmentSettings.tone and the ToneTarget adapter as stubs; Adjust panel shows ToneRows | PT-1, PT-2 | MJ-PT | suiteui tone-controls TC-a | yes | 0 | blocked | – | – |
| PT-u | snapshots, render budget, journey written | PT-5, PT-6 | PJ-T1 | PT-a; TC-3 (PT-5) | yes | 0 | waiting | – | – |
| PT-m | live route and export path; adapter bodies; catalog; RJ-P12–14 | PT-3, PT-4 | MJ-PT | PT-a; IM-photo, TC-5, TC-6; catalog chain | no | 0 | waiting | – | – |
| PT-z | journey on live, feature-done | PT-7, PT-8 | PJ-T1 | PT-u, PT-m; PG-z (PT-8) | yes | 0 | waiting | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| PT-1 | PT-a | 2 | tone in AdjustmentSettings; adapter stubs; PhotoToneTests disabled | Sources/PhotoModel/AdjustmentSettings.swift, PhotoTone+Kernel.swift, Tests/PhotoModelTests/PhotoToneTests.swift | compiles; old doc opens neutral | – | blocked (TC-a) |
| PT-2 | PT-a | 3 | Adjust panel ToneRows | Sources/PhotoApp/AdjustmentsInspector.swift | PhotoToneSnapshots.panel | – | waiting |
| PT-3 | PT-m | 4 | live route and export | PhotoAdjust+Imaging.swift, PhotoRender.swift | PhotoToneTests | – | waiting |
| PT-4 | PT-m | 4 | adapter bodies, catalog, jobs | PhotoTone+Kernel.swift, PhotoCommandCatalog.swift, RealJobs | PhotoToneCommandTests | – | waiting |
| PT-5 | PT-u | 4 | snapshots, budget | Tests/AppSnapshotTests/PhotoToneSnapshots.swift, RenderBudgetPhotoToneTests.swift | snapshots | – | waiting |
| PT-6 | PT-u | 4 | journey skipped | UITests/PhotoJourneyTests+Tone.swift | compiles | – | waiting |
| PT-7 | PT-z | 5 | journey on live | UITests/PhotoJourneyTests+Tone.swift | journey | – | waiting |
| PT-8 | PT-z | 6 | photo.md, built, feature-done | docs/blueprints/photo.md, tone-controls.wave.json | scripts/ci | – | waiting |

## Waves (combined plan, all three features)
- W1: PM-1 (SuiteUI LayerTreeList multi-select, no waits) and PP-a (PP-1 and PP-2 in one PR; waits met by PL-1 #3578 and PL-m on dev). The files do not overlap.
- W2: PM-2 once photo-gradient-fill PG-a is slice-done; PP-3 once placed-images PL-2 has merged; PT-1 once suiteui tone-controls TC-a is slice-done.
- W3: PM-3 (after PM-2), PP-4 (after PP-3), PT-2 (after PT-1), PM-4 (after PM-2).
- W4: PP-5 with PP-6 folded in, then PM-5 and PM-6, stacked in that order on the catalog. All three wait on PG-m. PT-3 and PT-4 wait on TC-5 and TC-6, IM-photo and the catalog chain. PM-7, PM-8, PT-5 and PT-6 also run here.
- W5: PP-7, PM-9, PT-7 (live journeys). W6: PP-8, PM-10, PT-8 (feature-done; each waits on PG-z).

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|
| – | – | – | – | – | – |

## Decisions
- v3 loop: each packet has a `## Slices` table.
- Base `dev`, not `main`. The brief step one checked main at b3011ab, but the packets exist only on dev (6c2c7b0), and CLAUDE.md and the lead contract say to branch from and target dev.
- Line lead (rule 19) for #3455 place-image, #3468 tone-controls (Photo) and #3535 multi-layer-select. There is one combined wave plan, and all three records show the same waves.
- Photo tone-controls records on `lead/photo-tone-controls`, because `lead/tone-controls` belongs to the live SuiteUI tone-controls lead (#3476). PRs keep `Feature: tone-controls`.
- PP-1 starts on PL-1 (#3578, merged) rather than all of PL-a. PP-1 is Model-only and uses only the kernel `PlacedImageTarget` and Place types, which are on dev; PL-m (rule bodies) is done too. PL-2 is SuiteUI views, and only PP-3 needs it.
- PP-6 (under 50 lines) is folded into PP-5's PR, as the packet says.
- One PR per slice (rule 22), split per task when a slice is over the 400-line cap: PM-a (~600, so PM-1, PM-2 and PM-3 each get a PR).
- Run act-1a15eecbafe-u0f9 (2026-10-21T14:20Z) takes over this record. The brief asked for base main and status on lead/transform and lead/tone-controls. It uses base dev and these photo-prefixed status branches instead: the fast lane merges only into dev, and lead/transform and lead/tone-controls belong to the live Halo #3443 and SuiteUI #3476 leads. Force-pushing them would rewrite another lead's history.
- Red Linux runs on #3969, #4005 and #4003 came from dev at the time, not from the PRs: the PhotoPlace CommandPath failure (fixed by #4008), stale Design mutation anchors (DY-a), and LargeCatalogBudget timing (moved to perf-suites in #4050/#4069). A fixer merges origin/dev into each branch so the lane re-runs Linux on a fresh head.
- All four slices (PT-a, PT-u, PT-m, PT-z) remain for this run.

## Open
