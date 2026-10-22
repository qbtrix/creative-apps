# develop lead record

Issue: #1527 · Packet: docs/blueprints/library/features/develop.md
Run: act-1a147b7188d-pjro · Session: claude/library-feature-lead-agcik2 · Started: 2026-10-17T02:36Z
Stage: 0 setup (re-checked at dev fe0f5f17, 2026-10-17T06:21Z: still blocked; needs-human comment posted on the issue)
Base: 37d996308670a9e50012b28d830fcd8736299b02 (origin/main; origin/dev is bc04c7d4)
Next: wait for spine (#1044), persist, thumbnails and loupe-viewport to merge DV-a's waits; then re-run stage 0.4

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| DV-a | new catalog fields open neutral, survive save, change thumbnail token | DV-1, DV-2 | MJ1 | spine, persist, thumbnails, loupe-viewport (not merged) | no | 0 | blocked | - | - |
| DV-b | slider, curve, levels, reset, copy, paste, sync as undo steps | DV-3, DV-4 | MJ2 | DV-a (DV-3) | no | 0 | blocked | - | - |
| DV-c | live renderer passes, fixed order, histogram | DV-5, DV-6 | MJ3 | DV-a | no | 0 | blocked | - | - |
| DV-d | Develop tab on the fakes, reachable from the inspector | DV-7..DV-10 | J5 | DV-a (DV-8, DV-9); spine follow-up (DV-9) | yes | 0 | blocked | - | - |
| DV-e | vibrance and saturation through CoreRaster | DV-11, DV-12 | MJ4 | DV-c; creative-core issue and its bump (DV-12) | no | 0 | blocked | - | - |
| DV-f | integrate: live services, relaunch survival, frame budget | DV-13..DV-15 | J5, P3 | DV-d, DV-c, DV-b, DV-e | no | 0 | blocked | - | - |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| DV-1 | DV-a | - | new develop fields in DevelopValues | see develop.wave.json | MJ1 | - | blocked |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- Stage 0.4: DV-a waits on spine, persist, thumbnails and loupe-viewport. None is merged (spine `building`, the other three `planned`), so no task can start.
- DV-12 also needs a creative-core issue for CoreRaster saturation and vibrance, and a bump. Not filed in this run.
- Commented on #1527 that the feature is blocked and what it waits on. No task started.

## Open
- Blocked on spine (#1044), persist, thumbnails and loupe-viewport.
- creative-core issue for CoreRaster saturation and vibrance (DV-12) not filed yet.
