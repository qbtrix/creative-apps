# status-and-layout lead record

Issue: #1528 · Packet: docs/blueprints/library/features/status-and-layout.md
Run: act-1a150baa34c-jzk9 · Session: claude/feature-lead-playbook-4h7pu1 · Started: 2026-10-18T20:38Z
Stage: 3 wave 1
Base: 507719b37a0f61d4242352f01481193829be3a87 (origin/dev; the brief's main f7e03506 is its ancestor)
Next: read the wave 1 builders' PRs (SL-1, SL-2, SL-3), then start wave 2 (SL-4, SL-5, SL-7)

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| SL-a | status row and inspector header values, grid columns and loupe fit per width | SL-1, SL-2 | MJ1 | spine (built) | no | 0 | building | - | - |
| SL-b | status row under grid and loupe, J12 at every width | SL-3, SL-4 | J12 | SL-a (SL-4); thumbnails, loupe-viewport (built); SuiteUI #1184 (SL-4, soft) | yes | 0 | building | - | - |
| SL-c | inspector header facts, Library control identifiers, wide-width snapshots | SL-5, SL-6, SL-7, SL-8 | J12 | SL-a (SL-5, SL-7); SL-b (SL-6, SL-8) | yes | 0 | planned | - | - |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| SL-1 | SL-a | 1 | LibraryLayout: content width, grid columns, loupe fit | Sources/LibraryModel/LibraryLayout.swift, Tests/LibraryModelTests/LibraryLayoutTests.swift, Tests/mutations/LibraryModel.LibraryLayout.json | LibraryLayoutTests | - | building |
| SL-2 | SL-a | 1 | status contract and statusRow; empty inspector header; MJ1; SL-5 tests disabled; model C4 part | Sources/LibraryModel/LibraryStatusText.swift, Tests/LibraryModelTests/LibraryStatusTextTests.swift, Tests/mutations/LibraryModel.LibraryStatusText.json, docs/c4/parts/creative-apps/library-model/library-model-sources.json | LibraryStatusTextTests | - | building |
| SL-3 | SL-b | 1 | J12 written whole, skipped "waits on SL-4" | UITests/LibraryJourneyTests+Layout.swift | J12 compiles and skips | - | building |
| SL-4 | SL-b | 2 | LibraryStatusBar under grid and loupe from statusRow | Sources/LibraryApp/LibraryStatusBar.swift, Tests/AppSnapshotTests/LibraryStatusSnapshots.swift, docs/c4/parts/creative-apps/library-app/library-app-sources.json | LibraryStatusSnapshots, J12 | - | planned |
| SL-5 | SL-c | 2 | inspector header facts and dateText | Sources/LibraryModel/LibraryStatusText.swift, Tests/LibraryModelTests/LibraryStatusTextTests.swift, Tests/mutations/LibraryModel.LibraryStatusText.json | LibraryStatusTextTests (SL-5 half) | - | planned |
| SL-7 | SL-c | 2 | layout snapshots at each width | Tests/AppSnapshotTests/LibraryLayoutSnapshots.swift | LibraryLayoutSnapshots | - | planned |
| SL-6 | SL-c | 3 | LibraryInspector header library.inspector.header | Sources/LibraryApp/LibraryInspector.swift, Tests/AppSnapshotTests/LibraryInspectorSnapshots.swift | LibraryInspectorSnapshots | - | planned |
| SL-8 | SL-c | 4 | identifier sweep for #291; feature-done | UITests/LibraryJourneyTests+Layout.swift, Sources/LibraryApp/LibraryStatusBar.swift, docs/c4/parts/creative-apps/library-app/library-app-sources.json | J12 enabled | - | planned |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- Resume of Belt's rebuilt record. The earlier run (act-1a147b7188d-pjro) was blocked on spine, thumbnails and loupe-viewport. All three are now built on dev, and no SL task had started.
- Base is origin/dev, not main: CLAUDE.md and the lane take dev only. main f7e03506 (the brief's step one, verified) is an ancestor of dev 507719b3.
- One combined wave plan with develop and export (contract rule 19). `scripts/waves check library` is OK. Wave 1 is SL-1, SL-2, SL-3, DV-1, DV-7. Their files don't overlap.
- Builders run as one build-wave.js Workflow per wave, as the brief's playbook asks.

## Open
- PR #2624 (open, SuiteUI line) deletes Sources/LibraryApp/LibraryStatusBar.swift and moves Library's status line into ViewerStatusBar (`message:`, `preview:`). SL-4 owns that file. If #2624 merges first, SL-4 builds on ViewerStatusBar and its LibraryWindow `statusBar(_:)`, with no Library copy (rule 20).
- Stage 1 issues (gap: status bar drawn only while isPreview; gap: MetadataInspector's InspectorHeader; needs-ui from #291's audit): being checked and filed.
