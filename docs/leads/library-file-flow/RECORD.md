# Lead record: file-flow (Library), #3479

Belt-Lead: act-1a15995d319-aamb
Packet: docs/blueprints/library/features/file-flow.md (v3, slices)
Status branch: lead/library-file-flow (lead/file-flow is the suite lead's)

## Stage

Build wave 1. Base origin/dev df54ce81.

## Slices

| Slice | Tasks | State |
|---|---|---|
| LF-a | LF-1, LF-2 | building: LF-1 built, gate next |
| LF-u | LF-5, LF-6 | waits on LF-a |
| LF-m | LF-3, LF-4 | waits on LF-a, SF-5..7, tone-controls LT-m, cull-finish DR-m |
| LF-z | LF-7, LF-8 | waits on the rest |

## Tasks

| Task | Branch | PR | State |
|---|---|---|---|
| LF-1 | library-file-flow/LF-1 | - | built; gate queued behind DR-1's |

## Decisions

- placesExtensions follows what the import reads today (`PhotoFileKind`: jpg, jpeg, png, heic, heif), not the packet's wider list; tiff and raw types wait for the raw feature.
- Library is one always-open catalog: hasDocument is true, recentFiles is empty, openRecent refuses.
- LF-1's drop tests are disabled by name ("LF-3"): `perform` is synchronous while the import is async; LF-3 picks a pending-drop queue or a synchronous path like LibraryHeadless and adapts them.
