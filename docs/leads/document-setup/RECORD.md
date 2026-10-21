# document-setup lead record

Issue: #3757 · Packet: docs/blueprints/suiteui/features/document-setup.md
Run: act-1a15fddd101-68r5 · Session: session_01BsyWa1bPrB44D73KoNLtrU · Started: 2026-10-21T19:15Z
Stage: 3 wave 1
Base: 58034759f2cdc515d7a44a9ec164509be2b6508b
Next: build DS-a (DS-1 + DS-2) as one slice PR, then stack DS-m (DS-3 + DS-4) on it

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| DS-a | contract stubs + disabled DocumentSetupTests + C4 part | DS-1, DS-2 | – | frame-rates:FR-a (merged) | false | 0 | building | – | – |
| DS-m | DocumentSetup + commands bodies, mutation plans | DS-3, DS-4 | – | DS-a | false | 0 | planned | – | – |
| DS-u | shared NewDocumentSheet in the gallery; journey + render budget | DS-5, DS-6 | SuiteJourneyTests+DocumentSetup | DS-a, frame-rates:FR-u, area-selection:AR-u | true | 0 | blocked | – | – |
| DS-photo | Photo new image on the setup | DS-7, DS-8 | PhotoJourneyTests+Documents | DS-u, DS-m, CB-s, AC-zoom, CB-photo | true | 0 | blocked | – | – |
| DS-design | Design new document on the setup | DS-9, DS-10 | DesignJourneyTests+Page | DS-u, DS-m, CB-design | true | 0 | blocked | – | – |
| DS-halo | Halo composition settings on the setup | DS-11, DS-12 | HaloJourneyTests+Settings | DS-a (DS-11); DS-u, DS-m, FR-halo, UP-halo, CB-halo (DS-12) | true | 0 | blocked | – | – |
| DS-flare | Flare document setup on the setup | DS-13, DS-14 | FlareJourneyTests+NewSheet | DS-u, DS-m, FR-flare, CB-flare | true | 0 | blocked | – | – |
| DS-z | delete old sheets; status built; feature-done | DS-15, DS-16 | – | DS-halo, DS-flare, DS-photo, DS-design | true | 0 | blocked | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| DS-1 | DS-a | 1 | contract as stubs | Sources/SuiteKernel/Document/DocumentSetup.swift, Sources/SuiteKernel/Document/DocumentSetupCommands.swift, docs/c4/parts/creative-apps/suite-kernel/kernel-document.json | kernel builds; CommandShapeTests | – | building |
| DS-2 | DS-a | 1 | DocumentSetupTests, disabled | Tests/SuiteKernelTests/DocumentSetupTests.swift | compiles, disabled by name | – | building |
| DS-3 | DS-m | 2 | DocumentSetup bodies | Sources/SuiteKernel/Document/DocumentSetup.swift, Tests/SuiteKernelTests/DocumentSetupTests.swift, Tests/mutations/SuiteKernel.DocumentSetup.json | DocumentSetupTests value half | – | planned |
| DS-4 | DS-m | 2 | commands run with anchor, one undo step | Sources/SuiteKernel/Document/DocumentSetupCommands.swift, Tests/mutations/SuiteKernel.DocumentSetupCommands.json | DocumentSetupTests command half | – | planned |
| DS-5 | DS-u | – | NewDocumentSheet in the gallery | Sources/SuiteUI/NewDocumentSheet.swift, Sources/SuiteUI/Gallery/GalleryNewDocument.swift, Sources/SuiteUI/SuiteGallery.swift, Tests/SuiteUITests/NewDocumentSheetTests.swift | NewDocumentSheetTests | – | blocked |
| DS-6 | DS-u | – | journey + render budget | UITests/SuiteJourneyTests+DocumentSetup.swift, Tests/AppSnapshotTests/RenderBudgetNewDocumentTests.swift | journey; RenderBudgetNewDocumentTests | – | blocked |
| DS-7..DS-16 | adopt slices, DS-z | – | see packet | see packet | see packet | – | blocked |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- PR base is `dev` (CLAUDE.md; the lane retargets `main` to `dev` anyway).
- DS-1 and DS-2 ship as one DS-a slice PR, failing (disabled) test first (rule 22).
- DS-3 and DS-4 ship as one DS-m PR stacked on DS-a.
- DS-11 (test only) is held for the DS-halo slice PR rather than a test-only PR (rule 22).

## Open
- DS-u waits on frame-rates:FR-u (held) and area-selection:AR-u (waiting).
- Adopt slices wait on other features' app slices (FR-halo/flare, CB-photo/design/halo/flare, UP-halo).
