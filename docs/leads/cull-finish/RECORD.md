# cull-finish lead record

Issue: #3458 · Packet: docs/blueprints/library/features/cull-finish.md
Run: act-1a15995d319-aamb · started 2026-10-20
Stage: build, wave 1 (DR-1 PR #3623 open; DR-2 + DR-5 PR #3625 open, stacked on #3623)
Base: 4f365bf8 (origin/dev)
Next: once #3623 merges, retarget #3625 to dev, merge dev into it, regate, move Head, add fast-lane. DR-3, DR-6, DR-7 wait on other features (below)

## Slices
| slice | behavior | tasks | waits on | ui | rounds | state | run |
|---|---|---|---|---|---|---|---|
| DR-a | contract: Trash service, label keys 6-9, Delete Rejects stubs, tests written disabled | DR-1, DR-2 | FC-a (on dev), MD-a (on dev) | no | 0 | building | - |
| DR-u | confirm dialog, ⌘⌫, Set Label 6-9; snapshots; journey skipped | DR-3, DR-4 | DR-a, FC-a, MD-d/e | yes | 0 | waiting | - |
| DR-m | label cull, deleteRejects body + undo, excludedPaths coding, LiveTrash | DR-5..DR-8 | DR-a; MD-c (DR-7); AC-library (command id) | no | 0 | waiting | - |
| DR-z | journey on, docs, C4, feature-done | DR-9, DR-10 | DR-u, DR-m | no | 0 | waiting | - |

## Tasks
| id | slice | wave | behavior | PR | state |
|---|---|---|---|---|---|
| DR-1 | DR-a | 1 | PhotoTrashing, FakeTrash, LiveTrash stub, services.trash, LibraryKey.label 6-9, deleteRejects stubs (Mutate 4/4) | #3623 | open, fast-lane |
| DR-2 | DR-a | 1 | disabled tests for DR-5/DR-6, never-deletes scan, delete-rejects real job (pending DR-8) | #3625 | open, stacked on #3623; CI: PASS on e0752118 |
| DR-5 | DR-m | 1 | keys 6-9 set Red/Yellow/Green/Blue as one step, never advance (40 lines, folded into DR-2's PR) | #3625 | open, folded into DR-2; Mutate 2/2 LibraryModel.LibraryCulling |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|
| - | - | - | - | - | - |

## Decisions
- Dependencies FC-a (LibraryUndoAdapter) and MD-a (LibraryServices) are on dev, so DR-1 starts now.
- DR-2's real job is marked `"pending": "DR-8"` with `"platforms": []`, the repo's existing mechanism for a job that waits; the packet's `waits_on: DR-8` means the same.
- The re-import check uses `beginImport()`'s skip set, so DR-6 adds trashed paths there.
- DR-a ships as two PRs (DR-1, DR-2): the packet sizes it near 320 lines plus fixtures.
- Waits outside this feature: DR-3 and DR-7 on AC-library's Belt-Slice-Done on #2999 (AC-l4 still waits on CC-u); DR-3 on metadata-more MD-d and MD-e, DR-6 on MD-e, DR-7 on MD-c (MD PRs #3545, #3569-#3582 open). DR-4 waits on DR-3; DR-8 on DR-7. Until those land, DR-5 is the only buildable DR task after DR-a.

- 2026-10-20T16:44Z: macOS build-only runs for this feature have been queued since ~14:25Z (runner backlog); lead keeps waiting, no action needed from the supervisor unless the queue is stuck.
