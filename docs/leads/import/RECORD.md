# import lead record

Issue: #1334 · Packet: docs/blueprints/library/features/import.md
Run: act-1a1448a5fa3-a8rg · Session: claude/library-import-feature-c0rl9g · Started: 2026-10-16T11:49Z
Stage: 3 wave 1
Base: ebc68bff2c46f99ac266d69fda013cc2625008da
Next: wait for wave 1 PRs (IM-1, IM-2, IM-4) to merge through the fast lane, then start wave 2 on the new origin/dev

## Tasks
| id | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|
| IM-1 | 1 | Catalog import state machine: begin, progress, batches, finish, fail, dismiss, help | Sources/LibraryModel/LibraryImport.swift, Tests/LibraryModelTests/LibraryImportTests.swift | LibraryImportTests | – | building |
| IM-2 | 1 | LiveImporter: skip known, capture-date order, path ids, batches, throttled progress, cancel; unavailable = nil | Sources/LibraryModel/Live/LiveImporter.swift, Tests/LibraryModelTests/LibraryLiveImporterTests.swift | LibraryLiveImporterTests | – | building |
| IM-4 | 1 | ImageIODecoder: scan with metadata and orientation, decode to sRGB RGBA8 | Sources/LibraryApp/Platform/ImageIODecoder.swift, Tests/AppSnapshotTests/LibraryDecodeTests.swift | LibraryDecodeTests (macOS) | – | building |
| IM-3 | 2 | Import model budgets | Tests/LibraryModelTests/LibraryImportBudgetTests.swift | LibraryImportBudgetTests | – | planned |
| IM-6 | 2 | Import area: File > Import Folder…, open panel or -LibraryImportFolder, off-main task, import on launch | Sources/LibraryApp/LibraryWindow+Import.swift | J1 step 6 (fakes), IM-8 live | – | planned |
| IM-7 | 2 | Progress row and notice (placeholders until #780/#781) and snapshots | Sources/LibraryApp/LibraryBrowser.swift, Tests/AppSnapshotTests/LibraryImportSnapshots.swift | LibraryImportSnapshots | – | planned |
| IM-8 | 3 | J1 testImportAFolder; delete skipped testImportRateAndRelaunch; feature-done | UITests/LibraryJourneyTests.swift, UITests/LibraryJourneyTests+Import.swift, UITests/LibraryJourneyTests+Files.swift, docs/blueprints/library/features/import.wave.json | J1 | – | planned |
| IM-9 | 3 | P6 perf journey (report-only) | UITests/LibraryJourneyTests+PerfImport.swift | P6 | – | blocked on #782 |

Wave 1: IM-1, IM-2, IM-4 independent. Wave 2: IM-3 (waits IM-1, IM-2: benchmarks their code), IM-6 (waits IM-1: calls its catalog methods), IM-7 (waits IM-1: reads its state and calls dismissImportNotice); independent of each other. Wave 3: IM-8 (waits IM-2, IM-4, IM-6, IM-7: runs the live import).

## Rounds
| round | CI run | CI | audit vs baseline | lenses | confirmed | fixed by | clean |
|---|---|---|---|---|---|---|---|

## Decisions
- No `## Slices` table in the packet: v2 loop; work started after #1302 merged (04:20Z), so findings queue and a 2-round cap apply.
- PRs target `dev` (CLAUDE.md, lead.md, fast lane); the brief's "main" is the promotion branch, not a PR base. HEAD 9e3c5f8 verified as origin/main; base is origin/dev ebc68bf (main + 1).
- Spine #1044 closed: waits met. #330 and #333 closed; #782 open, so IM-9 cannot run in this feature; IM-8 carries feature-done.
- #780 InlineNotice and #781 ProgressRow open: IM-7 uses plain SwiftUI placeholders (packet's soft wait).
- #333 merged: J1 goes in UITests/LibraryJourneyTests+Import.swift.

## Open
- IM-9 blocked on #782 (S-L8 FrameProbe marks).
- Swap-in of InlineNotice/ProgressRow once #780/#781 merge.
