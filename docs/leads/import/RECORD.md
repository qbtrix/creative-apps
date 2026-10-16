# import lead record

Issue: #1334 · Packet: docs/blueprints/library/features/import.md
Run: act-1a1448a5fa3-a8rg · Session: claude/library-import-feature-c0rl9g · Started: 2026-10-16T11:49Z
Stage: 4 round 1
Base: 8243ce4435006760f7ec9a87147fef094f6be4ed
Next: wait for the full CI run 38904662639 on dev 905efdc0 (contains #1355, feature-done), then Anatomy round 1 on it; IM-3 PR still building

## Tasks
| id | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|
| IM-1 | 1 | Catalog import state machine: begin, progress, batches, finish, fail, dismiss, help | Sources/LibraryModel/LibraryImport.swift, Tests/LibraryModelTests/LibraryImportTests.swift | LibraryImportTests | #1338 | merged |
| IM-2 | 1 | LiveImporter: skip known, capture-date order, path ids, batches, throttled progress, cancel; unavailable = nil | Sources/LibraryModel/Live/LiveImporter.swift, Tests/LibraryModelTests/LibraryLiveImporterTests.swift, Tests/LibraryModelTests/LibraryServicesTests.swift | LibraryLiveImporterTests | #1346 | merged |
| IM-4 | 1 | ImageIODecoder: scan with metadata and orientation, decode to sRGB RGBA8 | Sources/LibraryApp/Platform/ImageIODecoder.swift, Tests/AppSnapshotTests/LibraryDecodeTests.swift | LibraryDecodeTests (macOS) | #1342 | merged |
| IM-3 | 2 | Import model budgets | Tests/LibraryModelTests/LibraryImportBudgetTests.swift | LibraryImportBudgetTests | – | building |
| IM-6 | 2 | Import area: File > Import Folder…, open panel or -LibraryImportFolder, off-main task, import on launch | Sources/LibraryApp/LibraryWindow+Import.swift | J1 step 6 (fakes), IM-8 live | #1347 | merged |
| IM-7 | 2 | Progress row and notice (placeholders until #780/#781) and snapshots | Sources/LibraryApp/LibraryBrowser.swift, Tests/AppSnapshotTests/LibraryImportSnapshots.swift | LibraryImportSnapshots | #1348 | merged |
| IM-8 | 3 | J1 testImportAFolder; delete skipped testImportRateAndRelaunch; feature-done | UITests/LibraryJourneyTests.swift, UITests/LibraryJourneyTests+Import.swift, UITests/LibraryJourneyTests+Files.swift, docs/blueprints/library/features/import.wave.json | J1 | #1355 | merged (feature-done) |
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

- IM-2 also edits Tests/LibraryModelTests/LibraryServicesTests.swift: its spine assertions expected the importer stub (gate failed without it).
- IM-6 and IM-7 started beside IM-2's retry: they need only IM-1 (merged), so wave 2 overlaps wave 1's tail.
- PR bodies get a session footer appended outside the builders' control; the lane strips attribution from the squash commit.
- IM-6 adds no Linux test (SwiftUI area only); its proof is J1 in IM-8, per the packet.
- Builder branches are lead/import-<id>: lead/import/<id> can't coexist with the lead/import branch.

- IM-8 started before IM-7 (#1348) merged: it only reads IM-7's identifiers, which are fixed in #1348; the lane merges it after a macOS build either way.

## Open
- IM-9 blocked on #782 (S-L8 FrameProbe marks).
- Swap-in of InlineNotice/ProgressRow once #780/#781 merge.
