# place-image lead record

Issue: #3455 · Packet: docs/blueprints/photo/features/place-image.md
Run: act-1a1624aaf38-uvd0 · Session: claude/feature-lead-playbook-gub3sk · Started: 2026-10-22T06:30Z (takes over from act-1a15eecbafe-u0f9 and the earlier runs below)
Stage: every slice merged-done; Belt-Slice-Done lines and contact sheet posted
Base: dev
Next: on the scoped photo run's journeys (journeys.yml after CI run 39722915670): critic panel for PP-u, confirm #4215 holds the render budget

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| PP-a | PlacedImageTarget conformance as stubs; checks and RJ-P37 job written, disabled | PP-1, PP-2 | MJ-PP | placed-images PL-1 (merged #3578) | no | 0 | done | 39514893774 | – |
| PP-u | File > Place… and drop run place.image on stubs; snapshots, budget, journey written | PP-3, PP-4 | PJ-P1 | PP-a; placed-images PL-2 (PP-3, merged #3931) | yes | 1 (#4215) | merged-done | 39722978870 | wanted |
| PP-m | placing PNG/JPEG adds a fitted pixel layer above the selection as one step; SVG refused; catalog | PP-5, PP-6 | MJ-PP | PP-a; PG-m (PP-6) | no | 0 | done (brief) | – | – |
| PP-z | live, journey on live, blueprint lists Place | PP-7, PP-8 | PJ-P1 | PP-u, PP-m; PG-z, PM-z (PP-8) | yes | 0 | done (brief) | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| PP-1 | PP-a | 1 | conformance as stubs; PhotoPlaceTests disabled | Sources/PhotoModel/PhotoPlace+Kernel.swift, Tests/PhotoModelTests/PhotoPlaceTests.swift | suite compiles, disabled | #3764 | merged 23:02Z |
| PP-2 | PP-a | 1 | RJ-P37 job folder, waits_on PP-6 | Tests/RealJobs/photo/place-logo/ | job listed, skipped | #3764 | merged 23:02Z |
| PP-3 | PP-u | 2 | File > Place… ⇧⌘P and the drop | Sources/PhotoApp/PhotoPlace.swift, PhotoCommands+File.swift, PhotoEditor.swift | PhotoPlaceMenuTests (6), Mutate 4/4 | #3976 | merged 10:20Z; CommandPath fixed by #4008 |
| PP-4 | PP-u | 3 | snapshots, budget, journey skipped | Tests/AppSnapshotTests/PhotoPlaceSnapshots.swift, RenderBudgetPhotoPlaceTests.swift, UITests/PhotoJourneyTests+Place.swift | snapshots (refused now; logo after PP-5), budget placeLargeInThreeBodies, journey skipped | #4003 | merged a47f41f75 |
| PP-5 | PP-m | 4 | conformance bodies; insertPixelLayer from paste; tests on (PP-6 folded in) | PhotoPlace+Kernel.swift, PhotoClipboard.swift, tests, mutations, catalog, ids | PhotoPlaceTests; .centredOnCanvas .largeFitsCanvas .aboveSelection | #4101 | merged |
| PP-7 | PP-z | 5 | journey on live | UITests/PhotoJourneyTests+Place.swift | journey | #4175 | merged 36164d2 |
| PP-8 | PP-z | 6 | photo.md, built, feature-done | docs/blueprints/photo.md, place-image.wave.json | scripts/ci | #4139 | merged |

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
- #4004 closed as superseded by #4008.
- PP-5 starts now: PG-m is met (gradient-fill is built, #4064). The waits on transform:PT-m, PH-m and PE-m only order edits to the shared PhotoCommandCatalog, and transform PT-5 already dropped the same kind of wait. A catalog conflict is resolved by the lane's merge or by a dev merge on needs-rebase.
- This run owns slices PP-m and PP-z only; PP-a and PP-u are counted as done per the brief.
- Run act-1a1624aaf38-uvd0 (2026-10-22T06:30Z) takes over and owns PP-u only (PP-a, PP-m, PP-z skipped per its brief). Base stays dev (main is 420 commits behind and holds none of the slice PRs); status stays on lead/place-image.
- PP-u merged-done per dev's lead.md rule 6: full CI run 39722978870 at 71987f724 contains #3976, #4003 and the fix #4215 (cb79b07), and its Linux job passed 04:50Z. No later merge carries `Feature: place-image`; no `finding` issue for the feature is open.

## Open
- PP-2's job is skipped by its `.jobs.pending.json` name (the real-jobs harness ignores `waits_on`); PP-6 renames it to `place-logo.jobs.json` to turn it on. `rasterSize` throws in the stub; PP-5 reads the header.
- The GitHub tools append an attribution footer on create; each PR body and comment is re-set without it right after creation (brief rule 3).
- PP-3 #3976 also touches PhotoIntent.swift and PhotoWindow.swift (one line each, intent routing). Until PP-6 adds place.image to Photo's catalog, PhotoPlace+Menu runs it through a PlaceCommands-only catalog. SwiftUI unbuilt on Linux; the lane's macOS gate is the first build.
