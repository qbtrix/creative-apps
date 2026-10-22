# status-and-layout lead record

Issue: #1528 · Packet: docs/blueprints/library/features/status-and-layout.md
Run: act-1a147b7188d-pjro · Session: claude/library-feature-lead-agcik2 · Started: 2026-10-17T02:36Z
Stage: 0 setup (re-checked at dev fe0f5f17, 2026-10-17T06:21Z: still blocked; needs-human comment posted on the issue)
Base: 37d996308670a9e50012b28d830fcd8736299b02 (origin/main; origin/dev is bc04c7d4)
Next: wait for spine (#1044, status building) to merge SL-1/SL-2, and for thumbnails and loupe-viewport; then re-run stage 0.4

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| SL-a | status row and inspector header values, grid columns and loupe fit per width | SL-1, SL-2 | MJ1 | spine | no | 0 | blocked | - | - |
| SL-b | status row under grid and loupe, J12 at every width | SL-3, SL-4 | J12 | SL-a (SL-4); thumbnails, loupe-viewport; SuiteUI #1184 (SL-4) | yes | 0 | blocked | - | - |
| SL-c | inspector header facts, Library control identifiers, wide-width snapshots | SL-5..SL-8 | J12 | SL-a (SL-5, SL-7); SL-b (SL-6, SL-8) | yes | 0 | blocked | - | - |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| SL-1 | SL-a | - | layout model values | see status-and-layout.wave.json | MJ1 | - | blocked |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- Stage 0.4: SL-a waits on spine. Spine is `building` on dev and no spine task has merged, so no task can start.
- Commented on #1528 that the feature is blocked and what it waits on. No task started.

## Open
- Blocked on spine (#1044), thumbnails and loupe-viewport.
