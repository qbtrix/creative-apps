# tone-controls lead record

Issue: #3468 · Packet: docs/blueprints/photo/features/tone-controls.md
Run: act-1a16cd04539-4jc0 · Session: claude/feature-lead-playbook-9tb3qe · Started: 2026-10-24T07:30Z (takes over from act-1a16958d691-2ax3)
Stage: build W4 (PT-3, PT-4 building on the TC-5/TC-6 stubs; PT-2 #5007, PT-6 #5008 in the lane)
Base: 830af22de (dev now 1bbaba6c1)
Next: PT-3 and PT-4 PRs from build-wave (branches lead/photo-tone-PT-3, lead/photo-tone-PT-4); PT-5 once TC-3 #5006 merges; turn on the Wire-disabled tests when TC-5 #4880 / TC-6 #4953 merge

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| PT-a | AdjustmentSettings.tone and the ToneTarget adapter as stubs; Adjust panel shows ToneRows | PT-1, PT-2 | MJ-PT | suiteui tone-controls TC-a (TC-1 #4555 merged; TC-2 building) | yes | 0 | building | – | – |
| PT-u | snapshots, render budget, journey written | PT-5, PT-6 | PJ-T1 | PT-a; TC-3 (PT-5) | yes | 0 | waiting | – | – |
| PT-m | live route and export path; adapter bodies; catalog; RJ-P12–14 | PT-3, PT-4 | MJ-PT | PT-a; IM-photo (on dev), TC-5, TC-6 (stubs, rule 12); catalog chain (all built) | no | 0 | building | – | – |
| PT-z | journey on live, feature-done | PT-7, PT-8 | PJ-T1 | PT-u, PT-m; PG-z (PT-8) | yes | 0 | waiting | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| PT-1 | PT-a | 2 | tone in AdjustmentSettings; adapter stubs; PhotoToneTests disabled | Sources/PhotoModel/AdjustmentSettings.swift, PhotoTone+Kernel.swift, Tests/PhotoModelTests/PhotoToneTests.swift | PhotoToneTests | #4845 | merged |
| PT-2 | PT-a | 3 | Adjust panel ToneRows | Sources/PhotoApp/AdjustmentsInspector.swift | PhotoToneSnapshots.panel | #5007 | in lane |
| PT-3 | PT-m | 4 | live route and export | PhotoAdjust+Imaging.swift, PhotoRender.swift | PhotoToneTests | – | building |
| PT-4 | PT-m | 4 | adapter bodies, catalog, jobs | PhotoTone+Kernel.swift, PhotoCommandCatalog.swift, RealJobs | PhotoToneCommandTests | – | building |
| PT-5 | PT-u | 4 | snapshots, budget | Tests/AppSnapshotTests/PhotoToneSnapshots.swift, RenderBudgetPhotoToneTests.swift | snapshots | – | waiting |
| PT-6 | PT-u | 4 | journey skipped | UITests/PhotoJourneyTests+Tone.swift | compiles | #5008 | in lane (stacked on #5007) |
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
- Run act-1a16958d691-2ax3 (2026-10-23) takes over; same base-dev and status-branch choices as above (brief named main; the lane merges only into dev).
- Rule 12 on dev: TC-1 (#4555, ToneTarget, ToneSettings, ToneCommands) is the contract and has merged, so PT-1 builds on it now. PT-2 needs TC-2's ToneRows view, which is not on dev; PT-a ships as two PRs (PT-1 now, PT-2 when TC-2 lands), split per task.
- Tone gets no AdjustmentKind case: one would change the panel sections, the adjustment-layer kinds, the catalog oneOf and the stored `enabled` set. Instead `AdjustmentEdit.kind` is optional with `title`/`section` helpers, which touches PhotoWorkspace.swift and PhotoAdjustmentLayer.swift beyond PT-1's listed files (a few lines each).
- PT-2 runs a ToneIntent through a new `PhotoIntent.tone` case and `PhotoWindow+Tone.swift` (the per-area pattern), so the PR touches 6 files, not the packet's 1. It is still well inside the caps.
- No dead controls: until PT-4, `toneHelp` is non-nil with an image open, so the rows and tone.* commands stay off and say why.

- Run act-1a16cd04539-4jc0 (2026-10-24) takes over; same base-dev and status-branch choices. Brief step one checked main at 654fb3632.
- PT-3 and PT-4 start now (rule 12): TC-1, the tone contract, has merged; IM-photo (LiveToneSurface, the PhotoAdjust+Imaging adapter) is on dev; gradient-fill, transform, history-panel, eyedropper and place-image are all `built`. Tests that need the TC-5 / TC-6 bodies are written and disabled by name, with `Wire:` lines in the PR body.
- PT-3 and PT-4 branch from dev, not stacked on #5008: they are Model-only, share no files with PT-2/PT-6, and stacking would push their diffs over 400 lines while #5007/#5008 wait in the lane.
- PT-5 waits on TC-3 (#5006): snapshots and a render budget of the TC-2 placeholder rows would only be redone when TC-3 lands.

## Open
- [x] Wire: tone-controls:TC-2 (#4862 merged, dev 491ec5461): PT-2 #5007 builds on ToneRows(settings:help:hidden:onIntent:).
- [ ] Wire: tone-controls:TC-5 (#4880 open) turns on PT-3's disabled cases; TC-6 (#4953 open) PT-4's; TC-3 (#5006 open) starts PT-5.
- [x] Supervisor (FYI, not a stall): Fast Lane has merged nothing since dev 654fb3632 (~22:55Z) because it is bisecting batch lane/batch-20261023215139: probe -9 macOS gate failed 01:29Z, probe -7 macOS gate passed (started 02:43Z); probe -8 Linux passed; at 05:02Z the lane started a new batch, lane/batch-20261024050226, with 12 older PRs (#4839-#4875). Its macOS gate went red; since 05:45Z it bisects (probe -6). #5007, #5008 and the TC waits are not in it and are queued for a later batch. #5007, #5008 and the TC waits (#5006, #4880, #4953) sit clean with fast-lane for the next batch. Resolved 2026-10-24T06:42Z: dev moved to e5dcf9394 (#4840 landed from batch-20261024050226, whose bisection continues at probes -1/-3); #5007, #5008 and the TC waits are still open and queued.
