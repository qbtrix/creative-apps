# document-setup lead record

Issue: #3757 · Packet: docs/blueprints/suiteui/features/document-setup.md
Run: act-1a15fddd101-68r5 · Session: session_01BsyWa1bPrB44D73KoNLtrU · Started: 2026-10-21T19:15Z
Stage: 3 wave 1
Base: 58034759f2cdc515d7a44a9ec164509be2b6508b
Next: #4184 (DS-m) queued by the supervisor on the local Mac gate behind #4215; hold, merge dev only if the gate asks; DS-u waits on frame-rates FR-u (not started)

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| DS-a | contract stubs + disabled DocumentSetupTests + C4 part | DS-1, DS-2 | – | frame-rates:FR-a (merged) | false | 0 | merged #4182 | – | – |
| DS-m | DocumentSetup + commands bodies, mutation plans | DS-3, DS-4 | – | DS-a | false | 0 | pr #4184 | – | – |
| DS-u | shared NewDocumentSheet in the gallery; journey + render budget | DS-5, DS-6 | SuiteJourneyTests+DocumentSetup | DS-a, frame-rates:FR-u, area-selection:AR-u | true | 0 | blocked | – | – |
| DS-photo | Photo new image on the setup | DS-7, DS-8 | PhotoJourneyTests+Documents | DS-u, DS-m, CB-s, AC-zoom, CB-photo | true | 0 | blocked | – | – |
| DS-design | Design new document on the setup | DS-9, DS-10 | DesignJourneyTests+Page | DS-u, DS-m, CB-design | true | 0 | blocked | – | – |
| DS-halo | Halo composition settings on the setup | DS-11, DS-12 | HaloJourneyTests+Settings | DS-a (DS-11); DS-u, DS-m, FR-halo, UP-halo, CB-halo (DS-12) | true | 0 | blocked | – | – |
| DS-flare | Flare document setup on the setup | DS-13, DS-14 | FlareJourneyTests+NewSheet | DS-u, DS-m, FR-flare, CB-flare | true | 0 | blocked | – | – |
| DS-z | delete old sheets; status built; feature-done | DS-15, DS-16 | – | DS-halo, DS-flare, DS-photo, DS-design | true | 0 | blocked | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| DS-1 | DS-a | 1 | contract as stubs | Sources/SuiteKernel/Document/DocumentSetup.swift, Sources/SuiteKernel/Document/DocumentSetupCommands.swift, docs/c4/parts/creative-apps/suite-kernel/kernel-document.json | kernel builds; DocumentSetupTests.specsHaveSchemas | #4182 | pr |
| DS-2 | DS-a | 1 | DocumentSetupTests, disabled | Tests/SuiteKernelTests/DocumentSetupTests.swift | compiles, disabled by name | #4182 | pr |
| DS-3 | DS-m | 2 | DocumentSetup bodies | Sources/SuiteKernel/Document/DocumentSetup.swift, Tests/SuiteKernelTests/DocumentSetupTests.swift, Tests/mutations/SuiteKernel.DocumentSetup.json | DocumentSetupTests value half | #4184 | pr |
| DS-4 | DS-m | 2 | commands run with anchor, one undo step | Sources/SuiteKernel/Document/DocumentSetupCommands.swift, Tests/mutations/SuiteKernel.DocumentSetupCommands.json | DocumentSetupTests command half | #4184 | pr |
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

- Builders build the stacked slices one after another in one worktree; the lead opens the PRs.
- Status channel moved to `lead/suiteui-document-setup` (`docs/leads/suiteui-document-setup/`), the names Belt watches; `lead/document-setup` is retired.
- DS-m (#4184) is stacked with base `ds-a-document-setup-contract` so its diff stays its own (153 lines); against dev it would be 476 lines, over the lane's cap. It is retargeted to dev and merged with dev once #4182 lands.
- DS-m deviations (builder): frame-rate, resolution and duration problem sentences are ours (packet gives none); any `#RRGGBB00` reads transparent; schema `background` maxLength 11 so `transparent` validates.

## Open
- DS-u waits on frame-rates:FR-u (held) and area-selection:AR-u (waiting).
- Adopt slices wait on other features' app slices (FR-halo/flare, CB-photo/design/halo/flare, UP-halo).
