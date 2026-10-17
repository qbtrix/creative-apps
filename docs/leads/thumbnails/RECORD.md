# thumbnails lead record

Issue: #1506 · Packet: docs/blueprints/library/features/thumbnails.md
Run: act-1a14698db7e-jmb4 · Session: see Belt run page · Started: 2026-10-16T21:27Z
Stage: 2 plan
Base: origin/dev 653b674d (brief base main 8e0a5261; see Decisions)
Next: install a Swift toolchain, then run wave 1 (TH-1) through scripts/ci --changed; no PR is opened until the gate runs

## Tasks
| id | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|
| TH-1 | 1 | Buckets, visible requests, tokens, eviction under 128 MB | LibraryThumbnails.swift, LibraryThumbnailTests.swift | LibraryThumbnailTests | – | planned |
| TH-2 | 2 | Results: stale drops, failures, invalidate | LibraryThumbnailResultTests.swift (+ LibraryThumbnails.swift) | LibraryThumbnailResultTests | – | planned (waits TH-1) |
| TH-3 | 2 | LiveThumbnails actor, LRU 256 MB | Live/LiveThumbnails.swift, LibraryLiveThumbnailsTests.swift | LibraryLiveThumbnailsTests | – | planned (waits TH-1) |
| TH-4 | 2 | Grid model budgets | LibraryGridBudgetTests.swift | budget tests | – | planned (waits TH-1) |
| TH-5 | 3 | Cells show images, values, marks, snapshots | LibraryGrid.swift, LibraryThumbnailSnapshots.swift, LibraryGridSnapshots.swift | snapshots | – | planned (waits TH-2, #779 closed) |
| TH-6 | 3 | Thumbnails area: visible ids to requests | LibraryWindow+Thumbnails.swift | J2 steps 1-2 | – | planned (waits TH-2) |
| TH-7 | 4 | J2 (F) steps | LibraryJourneyTests+Grid.swift | J2 (F) | – | planned (waits TH-5, TH-6) |
| TH-8 | 5 | J2 (L) step 1 | LibraryJourneyTests+Grid.swift | J2 (L) | – | planned (waits TH-3, TH-7, import IM-6 unverified) |
| TH-9 | 4 | P1 perf, report-only | LibraryJourneyTests+PerfGrid.swift | P1 | – | planned (waits #782 open) |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- v2 loop: the packet has no Slices table.
- The packet's tasks say LibraryJourneyTests+Grid.swift, and TH-6 touches LibraryWindow+Thumbnails.swift only; no shared-doc task.

## Open
- Blocker: no Swift toolchain in this sandbox.
- Blocker: lead/thumbnails status branch not created; this record is on the designated branch.
- import IM-6 status not verified: gates TH-8.
- The feature issue's dependency on loupe-viewport LV-7 (persist J8 step 3) is noted, not a wait for thumbnails.
