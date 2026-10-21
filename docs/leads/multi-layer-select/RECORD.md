# multi-layer-select lead record

Issue: #3535 · Packet: docs/blueprints/photo/features/multi-layer-select.md
Run: act-1a15e9d8b78-eu21 (resumed; earlier act-1a15b1de115-nxto) · Session: claude/multi-layer-select-lead-g8o0jx · Started: 2026-10-20T20:40Z
Stage: 3 wave 3
Base: ac7f95c9f6b0516253108a270145e4280f243b69
Next: PM-3 and PM-4 builders stacked on PM-2 (#4087, lead/multi-layer-select-PM-2); then PM-5, PM-6

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| PM-a | LayerTreeList picks several rows; Photo keeps a kernel Selection of layers; list, Select > All Layers and intents on stubs | PM-1, PM-2, PM-3 | MJ-PM | photo-gradient-fill:PG-a (PM-2); shell-parity (built) | yes | 0 | building | – | – |
| PM-u | snapshots of four states, render budget, journey written | PM-7, PM-8 | PJ-M1 | PM-a | yes | 0 | waiting | – | – |
| PM-m | selection bodies; hide, opacity, delete, move on every selected layer as one step; catalog; RJ-P43 | PM-4, PM-5, PM-6 | MJ-PM | PM-a; PG-m (PM-5, PM-6) | no | 0 | waiting | – | – |
| PM-z | journey on live, stress journey, photo.md, feature-done | PM-9, PM-10 | PJ-M1 | PM-u, PM-m; PG-z (PM-10); #3499 (PM-9) | yes | 0 | waiting | – | – |
| PM-g | group layers | PM-11, PM-12, PM-13 | – | PM-m | yes | 0 | out of beta (captain 2026-10-20, v1) | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| PM-1 | PM-a | 1 | LayerTreeList multi-select init and pick(shift:command:) | Sources/SuiteUI/LayerTreeList.swift, Sources/SuiteUI/LayerTreeList+Rows.swift, Tests/SuiteUITests/LayerTreeListTests.swift, Tests/mutations/SuiteUI.LayerTreeList.json | LayerTreeListTests; .pickModes .severalSelected | #3761 | merged 00:24Z |
| PM-2 | PM-a | 2 | layerSelection behind selectedLayerID; API stubs; suites disabled | Sources/PhotoModel/PhotoWorkspace.swift, PhotoLayerSelection+Kernel.swift, PhotoSeveralLayers+Kernel.swift, two test suites | PhotoWorkspaceTests | #4087 | pr open |
| PM-3 | PM-a | 3 | Layers list on multi-select, Select > All Layers ⌥⌘A, intents | Sources/PhotoApp/PhotoLayerList.swift, PhotoIntent.swift, PhotoWindow.swift, PhotoCommands+Select.swift | PhotoLayerListSnapshots, PhotoEditMenuTests | – | building |
| PM-4 | PM-m | 3 | selection bodies | PhotoLayerSelection+Kernel.swift + tests + mutations | PhotoLayerSelectionTests | – | building |
| PM-5 | PM-m | 4 | several-layer hide/opacity/delete; catalog | PhotoSeveralLayers+Kernel.swift, PhotoCommandCatalog.swift, command-ids | PhotoSeveralLayersTests | – | waiting |
| PM-6 | PM-m | 4 | Move moves every selected layer; RJ-P43 | PhotoStroke.swift, PhotoSeveralLayers+Kernel.swift, RealJobs/photo/fade-layers | moveMovesEvery | – | waiting |
| PM-7 | PM-u | 4 | snapshots and render budget | Tests/AppSnapshotTests/PhotoMultiLayerSnapshots.swift, RenderBudgetPhotoMultiLayerTests.swift | snapshots | – | waiting |
| PM-8 | PM-u | 4 | journey written, skipped | UITests/PhotoJourneyTests+MultiSelect.swift | compiles | – | waiting |
| PM-9 | PM-z | 5 | journey on live | UITests/PhotoJourneyTests+MultiSelect.swift, +StressPerf.swift | journey | – | waiting |
| PM-10 | PM-z | 6 | photo.md, built, feature-done | docs/blueprints/photo.md, multi-layer-select.wave.json | scripts/ci | – | waiting |

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
- This run holds only #3535 (brief act-1a15e9d8b78-eu21); place-image and photo tone-controls are no longer this lead's.
- PM-g is out of the beta (supervisor comment on #3535, 2026-10-20): not planned; PM-10 stays feature-done.
- PG-a and PG-m are slice-done (lead/photo-gradient-fill record, run 39582236683); AC-photo has Belt-Slice-Done on #2999: PM-2, PM-4, PM-5, PM-6 waits are met. PM-9 waits on #3499 (open); PM-10 on PG-z (#4064 open).
- One PR per slice (rule 22), split per task when a slice is over the 400-line cap: PM-a (~600, so PM-1, PM-2 and PM-3 each get a PR).

## Open
- Belt watches lead/photo-multi-layer-select (docs/leads/photo-multi-layer-select/): the record is mirrored there from 14:55Z; lead/multi-layer-select keeps the same files.
- The PR tooling re-appends a footer line to PR bodies after an edit removes it; the fast lane strips it from the squash commit.
