# persist lead record

Issue: #1511 · Packet: docs/blueprints/library/features/persist.md
Run: act-1a14fc0ecee-9q8k (resumes act-1a14cdfa655-jrmy) · Session: see Belt run page · Started: 2026-10-18T02:45Z
Stage: 5 fix round 1 (fix PRs in the lane)
Base: origin/dev 21066130 (wave 2)
Next: round 2 (last) merged; waiting on scoped library 39189402196 (17dc84c), queued behind dev CI 39180214762 (running since 00:18, supervisor: cancel if hung). Green: contact sheets on #1513 #1511 #1506. Red: gaps.

## Tasks
| id | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|
| PE-1 | 1 | Restore, fail, save requests, revisions, missing files | LibraryPersistence.swift, LibraryPersistTests.swift | LibraryPersistTests | #2540 | merged |
| PE-2 | 1 | LiveCatalogCoding v1; the golden | Live/LiveCatalogCoding.swift, LibraryCatalogCodingTests.swift, LibraryPersistGolden.swift | LibraryCatalogCodingTests | #2542 | merged |
| PE-4 | 1 | CatalogStore: folder, atomic write, writeNow, set aside | Platform/CatalogStore.swift, LibraryCatalogStoreTests.swift | LibraryCatalogStoreTests (macOS) | #2541 | merged |
| PE-3 | 2 | Catalog budgets: decode 10k ≤ 1 s, encode ≤ 500 ms | LibraryCatalogBudgetTests.swift | budget tests | #2605 | merged 05:25Z |
| PE-5 | 2 | Persist area: launch restore, save, flush, Show in Finder; library-restored | LibraryWindow+Persist.swift, LibraryRestoreSnapshots.swift | snapshot + J8 step 2 | #2602 | merged 05:25Z |
| PE-6 | 3 | J8 and J9 | LibraryJourneyTests+Persist.swift | J8, J9 | #2720 | merged 10:44 (feature-done) |
| PE-7 | – | P7 perf, report-only | LibraryJourneyTests+PerfLaunch.swift | P7 | – | waits #782 (open) |
| PE-8 | 2f | No "No Photos" flash while loading | LibraryReadouts.swift, LibraryBrowser.swift, new test | loading empty-state test | #2613 | merged 05:49Z |

## Rounds
| round | CI run | CI | audit vs baseline | lenses | confirmed | fixed by | clean |
|---|---|---|---|---|---|---|---|
| 1 | 39122753293 (scoped library, e3a4582) | red | not reached | journeys, clarity | #2765 (J8 help tag reads empty) | #2860 merged | no |

## Decisions
- 2026-10-18: new run act-1a14cdfa655-jrmy replaces act-1a14698db7e-jmb4; toolchain installed by scripts/cloud-setup.sh (Swift 6.3.3), so the earlier blocker is gone.
- v2 loop: the packet has no Slices table. Rules 10 and 11 apply (#1302 merged before this run): critics file `finding` issues; more than 5 open pauses new feature tasks; at most 2 fix rounds, then open findings become `gap` issues.
- PRs target dev (CLAUDE.md: never branch from or target main), although the brief names main as the integration branch; main moves only by full CI on dev.
- Rule 18 (contract first): every Model signature the UI calls depends only on the spine, so wave 1 builds those signatures for real instead of as throwaway stubs; where a later task fills a method (thumbnails TH-2) wave 1 declares it as a stub. Wave 2 builds the UI on them, alongside the remaining logic.
- Rule 20 (canonical first): searched SuiteModel, SuiteKernel, SuiteUI and every Sources/*Model for zoom steps, an image LRU, a latest-wins render queue and catalog JSON coding; none exists, and none is a kernel concept in Tests/canonical-concepts.txt. The new files stay in LibraryModel.
- Perf tasks (P1, P4, P7) wait on #782, which is open; they become `gap` issues if #782 is still open at the finish.
- The golden is a Swift literal in Tests/LibraryModelTests/LibraryPersistGolden.swift, pasted from the real encoder's output, so the test target needs no resources.
- PE-4's tests live in AppSnapshotTests (macOS); on Linux they only run on the lane's macOS build-only check and the next dev CI.

## Open
- PE-6 waits on loupe-viewport LV-7 (J8 step 3) and cull CU-5 (built).
- PE-8 (lead-added): emptyState returned "No Photos" for .loading and the browser drew it, so relaunch flashed "No Photos". The packet expected the spine browser to handle it; it did not. Fix touches LibraryBrowser.swift (Library line), against the packet note that persist never edits it, because no other task owns it.
- PE-5 (#2602) puts applyLaunch (a LibraryCatalog extension routing to restore/markMissing/failRestore) in the app target; it calls Model methods only and passes the app-state rule. Accepted; a critic may still ask to move it into LibraryModel.
