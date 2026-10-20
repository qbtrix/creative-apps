# photo file-flow lead record

Issue: #3471 · Packet: docs/blueprints/photo/features/file-flow.md
Run: act-1a15a9f4eba-h30y · Session: claude/feature-lead-playbook-djd69t · Started: 2026-10-20T18:40Z
Stage: 3 wave 1
Base: e382f9d7fba02ffdefc8ba2f23c9461b4774fad6
Next: PF-1 builder (PhotoFileFlow+Kernel stubs) then PF-4 stacked on it; PF-2 waits place-image:PP-u; PF-3 waits Photo tone-controls PT-m, transform PT-m, history-panel PH-m, eyedropper PE-m, place-image PP-m

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| PF-a | Photo conforms to SuiteDocumentHost and FileFlowTarget on stubs; .suiteApp scene; suite Open Recent, Open In, drop on fakes | PF-1, PF-2 | MPF | SF-a (merged #3488, #3489); photo-seams, photo-documents, photo-render-adopt, shell-parity (built); place-image:PP-u (PF-2) | yes | 0 | building | – | – |
| PF-u | menu and drop mark snapshots, render budget, journey written | PF-5, PF-6 | PFJ1 | PF-a | yes | 0 | waiting | – | – |
| PF-m | open/new/place hand-offs, old recents imported once, suite recents, opens and saves noted | PF-3, PF-4 | MPF | PF-a; SF-5, SF-6, SF-7 (merged); tone-controls:PT-m, transform:PT-m, history-panel:PH-m, eyedropper:PE-m, place-image:PP-m (PF-3) | yes | 0 | building (PF-4 stacked on PF-1) | – | – |
| PF-z | live drop, Open Recent, Open In; journey; built | PF-7, PF-8 | PFJ1 | PF-u, PF-m; SF-8 (PF-7); export-pack:PX-z, place-image:PP-z (PF-8) | yes | 0 | waiting | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| PF-1 | PF-a | 1 | adapter stubs (SuiteDocumentHost, FileFlowTarget); PhotoFileFlowTests disabled | Sources/PhotoModel/PhotoFileFlow+Kernel.swift, Tests/PhotoModelTests/PhotoFileFlowTests.swift | compiles, suite disabled | – | building |
| PF-2 | PF-a | – | .suiteApp scene, SuiteFileCommands with Open In, .suiteFileDrop | Sources/PhotoApp/PhotoApp.swift, Sources/PhotoApp/PhotoCommands+File.swift, Sources/PhotoApp/PhotoEditor.swift | snapshots (PF-5's) | – | waits place-image:PP-u |
| PF-3 | PF-m | – | adapter bodies, FileFlowCommands specs, recents import, RJ-P42 | Sources/PhotoModel/PhotoFileFlow+Kernel.swift, Sources/PhotoModel/PhotoCommandCatalog.swift, Tests/command-ids/photo.txt, Tests/PhotoModelTests/PhotoFileFlowTests.swift, Tests/mutations/PhotoModel.PhotoFileFlow+Kernel.json, Tests/RealJobs/photo/drop-layer/, Sources/PhotoModel/PhotoRecentMenu.swift | PhotoFileFlowTests | – | waits PT-m, PH-m, PE-m, PP-m |
| PF-4 | PF-m | 1 (stacked on PF-1) | window notes opens and saves through the bridge | Sources/PhotoApp/PhotoWindow+File.swift, Tests/AppSnapshotTests/PhotoFileFlowLiveTests.swift | PhotoFileFlowLiveTests (macOS) | – | building |
| PF-5 | PF-u | – | snapshots, render budget | Tests/AppSnapshotTests/PhotoFileFlowSnapshots.swift, Tests/AppSnapshotTests/RenderBudgetPhotoFileDropTests.swift | RenderBudgetPhotoFileDropTests | – | waits PF-2 |
| PF-6 | PF-u | – | journey written, skipped | UITests/PhotoJourneyTests+FileFlow.swift | compiles, skipped | – | waits PF-2 |
| PF-7 | PF-z | – | journey on live | UITests/PhotoJourneyTests+FileFlow.swift | journey | – | waits PF-6, PF-3, PF-4, SF-8 (#3529 open) |
| PF-8 | PF-z | – | photo.md, status built, feature-done | docs/blueprints/photo.md, docs/blueprints/photo/features/file-flow.wave.json | scripts/waves render --dry-run | – | waits PF-7, PF-5, PX-z, PP-z |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- Lead branch is lead/photo-<feature> and the record lives in docs/leads/photo-<feature>/: the packet names lead/<feature>, but lead/gradient-fill, lead/export-pack and lead/file-flow already belong to the Flare, SuiteUI and Suite features of the same names, and are active. Earlier Photo leads use the photo- prefix (lead/photo-seams, lead/photo-documents).
- Base and PR target are origin/dev, not main: the brief names main (b3011ab9, verified), but the packets exist only on dev, CLAUDE.md sends crew PRs to dev and the lane retargets main PRs to dev.
- One PR per task, stacked: PRs stay under the 400-line cap, and each slice PR opens with its failing or disabled test as the first commit.
- PF-4 stacks on PF-1 in wave 1: it needs PF-1 and SF-7 (merged #3507, f58d52ca) only.

## Open
- PF-2 waits Photo place-image PP-u and PF-3 waits Photo tone-controls PT-m, transform PT-m, history-panel PH-m, eyedropper PE-m and place-image PP-m (file ownership, A/C first): none of those Photo features has a lead branch yet.
