# persist lead record

Issue: #1511 · Packet: docs/blueprints/library/features/persist.md
Run: act-1a14698db7e-jmb4 · Session: see Belt run page · Started: 2026-10-16T21:27Z
Stage: 2 plan
Base: origin/dev 653b674d (brief base main 8e0a5261; see Decisions)
Next: install a Swift toolchain, then run wave 1 (PE-1, PE-2, PE-4) through scripts/ci --changed; no PR is opened until the gate runs

## Tasks
| id | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|
| PE-1 | 1 | Restore, fail, save requests, revisions, missing files | LibraryPersistence.swift, LibraryPersistTests.swift | LibraryPersistTests | – | planned |
| PE-2 | 1 | LiveCatalogCoding v1 with develop and crop; golden literal | Live/LiveCatalogCoding.swift, LibraryCatalogCodingTests.swift, LibraryPersistGolden.swift | LibraryCatalogCodingTests | – | planned |
| PE-3 | 2 | Catalog budgets, 10,000 records | LibraryCatalogBudgetTests.swift | budget tests | – | planned (waits PE-2) |
| PE-4 | 1 | CatalogStore: folder, atomic write, setAside | Platform/CatalogStore.swift, LibraryCatalogStoreTests.swift | LibraryCatalogStoreTests | – | planned |
| PE-5 | 2 | Persist area: launch load, save, flush, library-restored | LibraryWindow+Persist.swift, LibraryRestoreSnapshots.swift | snapshots | – | planned (waits PE-1,2,4) |
| PE-6 | 3 | J8 and J9 | LibraryJourneyTests+Persist.swift | J8, J9 | – | planned (waits PE-5, #333 closed, import IM-6 unverified, cull CU-5 unverified) |
| PE-7 | 3 | P7 perf, report-only | LibraryJourneyTests+PerfLaunch.swift | P7 | – | planned (waits PE-5, #782 open) |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- v2 loop: the packet has no Slices table.
- The golden is a Swift string literal (LibraryPersistGolden.swift), not a Golden/ JSON file, because Package.swift declares no resources for the test target.
- JSON v1 with develop and crop; no creative-core issue (D1).

## Open
- Blocker: no Swift toolchain in this sandbox.
- Blocker: lead/persist status branch not created; this record is on the designated branch.
- import IM-6 and cull CU-5 statuses not verified.
