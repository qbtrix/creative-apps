# loupe-viewport lead record

Issue: #1513 · Packet: docs/blueprints/library/features/loupe-viewport.md
Run: act-1a14698db7e-jmb4 · Session: see Belt run page · Started: 2026-10-16T21:27Z
Stage: 2 plan
Base: origin/dev 653b674d (brief base main 8e0a5261; see Decisions)
Next: install a Swift toolchain, then run wave 1 (LV-1 to LV-5) through scripts/ci --changed; no PR is opened until the gate runs

## Tasks
| id | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|
| LV-1 | 1 | Loupe zoom steps, titles | LoupeZoom.swift, LibraryLoupeZoomTests.swift | LibraryLoupeZoomTests | – | planned |
| LV-2 | 1 | Loupe picture state, latest wins, neighbours | LibraryLoupeImage.swift, LibraryLoupeImageTests.swift | LibraryLoupeImageTests | – | planned |
| LV-3 | 1 | RenderQueue (one running, latest waiting) | RenderQueue.swift, LibraryRenderQueueTests.swift | LibraryRenderQueueTests | – | planned |
| LV-4 | 1 | Home, End, readout with name | LoupeState.swift, LibraryLoupeTests.swift | LibraryLoupeTests | – | planned |
| LV-5 | 1 | LiveLoupeImaging, 3-buffer cache | Live/LiveLoupeImaging.swift, LibraryLiveLoupeTests.swift | LibraryLiveLoupeTests | – | planned |
| LV-6 | 2 | Loupe model budgets | LibraryLoupeBudgetTests.swift | budget tests | – | planned (waits LV-2) |
| LV-7 | 2 | Loupe on CanvasViewport, remove loupeArtboard, snapshots | LibraryLoupe.swift, LoupeState.swift, LibraryLoupeSnapshots.swift | LibraryLoupeSnapshots | – | planned (waits LV-1,2,4) |
| LV-8 | 3 | Loupe area: View menu, render queue, prefetch | LibraryWindow+Loupe.swift | J3 steps 2-5 | – | planned (waits LV-7) |
| LV-9 | 4 | J3 (F) steps | LibraryJourneyTests+Loupe.swift | J3 (F) | – | planned (waits LV-8; #333 closed) |
| LV-10 | 5 | J3 (L) step 1 | LibraryJourneyTests+Loupe.swift | J3 (L) | – | planned (waits LV-5, LV-9, import IM-6: unverified) |
| LV-11 | 4 | P4 perf, report-only | LibraryJourneyTests+PerfLoupe.swift | P4 | – | planned (waits #782, open) |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- v2 loop: the packet has no Slices table.
- Integration base: the brief says main, CLAUDE.md says branch from and target dev. Used origin/dev for planning; PRs target dev per CLAUDE.md.
- Pan: no panLoupe, per the packet (CanvasViewport already pans).
- #333 and #779 are closed (merged). #782 is open and report-only, so LV-11 may land after this feature.

## Open
- Blocker: no Swift toolchain in this sandbox, so scripts/ci and the Model tests cannot run.
- Blocker: the lead/loupe-viewport status branch was not created; this record is on the designated branch claude/feature-lead-loupe-persist-thumbnails-5nbuax.
- import IM-6 status not verified: gates LV-10.
