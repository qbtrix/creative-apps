# raw lead record

Issue: #1530 · Packet: docs/blueprints/library/features/raw.md
Run: act-1a147b7188d-pjro · Session: claude/library-feature-lead-agcik2 · Started: 2026-10-17T02:36Z
Stage: 0 setup (re-checked at dev 82ac5055, 2026-10-17T03:08Z: still blocked)
Base: 37d996308670a9e50012b28d830fcd8736299b02 (origin/main; origin/dev is bc04c7d4)
Next: wait for develop:DV-a, crop:CR-a, export:EX-a, metadata-more:MD-a/MD-b/MD-e and thumbnails to merge; then re-run stage 0.4

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| RW-a | raw types, decoder requirements, fakes, raw-shoot fixture | RW-1, RW-2 | RJ0 | develop:DV-a, crop:CR-a, export:EX-a, metadata-more:MD-a, metadata-more:MD-e | no | 0 | blocked | - | - |
| RW-b | fast raw import, RAW+JPEG pairing, grid RAW mark | RW-3..RW-7 | RJ1 | RW-a (RW-3), metadata-more:MD-b (RW-6) | yes | 0 | blocked | - | - |
| RW-c | develop RAW section, undo, grid/loupe/export decode with it | RW-8..RW-10 | RJ2 | RW-b, develop, persist, export, status-and-layout, filters-collections:FC-e | yes | 0 | blocked | - | - |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| RW-1 | RW-a | - | raw types and decoder requirements | see raw.wave.json | RJ0 | - | blocked |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- Stage 0.4: no RW-a task can start. Its waits (develop:DV-a, crop:CR-a, export:EX-a, metadata-more:MD-a/MD-e) are all `planned` on dev, and the packet's own header says thumbnails is `planned`. No PR is open against dev for any Library feature.
- Commented on #1530 that the feature is blocked and what it waits on. No task started.
- Two features in this run also wait on the same upstream work (develop, status-and-layout), so the line lead can plan one wave once they unblock.

## Open
- Blocked on the upstream features listed under Next. Nothing is built, and no PR exists yet.
- needs-ui issue "ThumbnailBadges: a short text tag per cell" is not yet filed (packet says the lead files it at stage 1; defer until the packet is read in stage 1).
