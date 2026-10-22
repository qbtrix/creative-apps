# document-setup lead record

Issue: #3757 · Packet: docs/blueprints/suiteui/features/document-setup.md
Run: act-1a1620043af-tzh0 · Started: 2026-10-22T05:00Z (resumed from act-1a15fddd101-68r5)
Stage: 3 wave 2 (finishing: DS-6 #4309 merged c0f2c506, waiting on dev Linux CI for Belt-Slice-Done; polled 08:11Z)
Base: 0dd23d659f4dbd8a0120aa85a321259327518251 (main); dev 8cf02113
Next: supervisor (06:19Z): stop after DS-u (#4309) lands; post DS-u Belt-Slice-Done + Mac-Finish-Wanted, then stop. Adopt slices and DS-z wait for a relaunch (waiting-on-prereq) once CB adopt slices and UP-halo land.

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| DS-a | contract stubs + disabled DocumentSetupTests + C4 part | DS-1, DS-2 | – | frame-rates:FR-a (merged) | false | 0 | done #4182 | 39724795297 | – |
| DS-m | DocumentSetup + commands bodies, mutation plans | DS-3, DS-4 | – | DS-a | false | 0 | done #4184 | – | – |
| DS-u | shared NewDocumentSheet in the gallery; journey + render budget | DS-5, DS-6 | SuiteJourneyTests+DocumentSetup | DS-a, frame-rates:FR-u, area-selection:AR-u | true | 0 | pr #4309 (DS-5 merged #4299) | – | – |
| DS-photo | Photo new image on the setup | DS-7, DS-8 | PhotoJourneyTests+Documents | DS-u, DS-m, CB-s, AC-zoom, CB-photo | true | 0 | blocked | – | – |
| DS-design | Design new document on the setup | DS-9, DS-10 | DesignJourneyTests+Page | DS-u, DS-m, CB-design | true | 0 | blocked | – | – |
| DS-halo | Halo composition settings on the setup | DS-11, DS-12 | HaloJourneyTests+Settings | DS-a (DS-11); DS-u, DS-m, FR-halo, UP-halo, CB-halo (DS-12) | true | 0 | blocked | – | – |
| DS-flare | Flare document setup on the setup | DS-13, DS-14 | FlareJourneyTests+NewSheet | DS-u, DS-m, FR-flare, CB-flare | true | 0 | blocked | – | – |
| DS-z | delete old sheets; status built; feature-done | DS-15, DS-16 | – | DS-halo, DS-flare, DS-photo, DS-design | true | 0 | blocked | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| DS-1 | DS-a | 1 | contract as stubs | Sources/SuiteKernel/Document/DocumentSetup.swift, Sources/SuiteKernel/Document/DocumentSetupCommands.swift, docs/c4/parts/creative-apps/suite-kernel/kernel-document.json | kernel builds; DocumentSetupTests.specsHaveSchemas | #4182 | merged |
| DS-2 | DS-a | 1 | DocumentSetupTests, disabled | Tests/SuiteKernelTests/DocumentSetupTests.swift | compiles, disabled by name | #4182 | merged |
| DS-3 | DS-m | 2 | DocumentSetup bodies | Sources/SuiteKernel/Document/DocumentSetup.swift, Tests/SuiteKernelTests/DocumentSetupTests.swift, Tests/mutations/SuiteKernel.DocumentSetup.json | DocumentSetupTests value half | #4184 | merged |
| DS-4 | DS-m | 2 | commands run with anchor, one undo step | Sources/SuiteKernel/Document/DocumentSetupCommands.swift, Tests/mutations/SuiteKernel.DocumentSetupCommands.json | DocumentSetupTests command half | #4184 | merged |
| DS-5 | DS-u | – | NewDocumentSheet in the gallery | Sources/SuiteUI/NewDocumentSheet.swift, Sources/SuiteUI/Gallery/GalleryNewDocument.swift, Sources/SuiteUI/SuiteGallery.swift, Tests/SuiteUITests/NewDocumentSheetTests.swift | NewDocumentSheetTests | #4299 | merged |
| DS-6 | DS-u | – | journey + render budget | UITests/SuiteJourneyTests+DocumentSetup.swift, Tests/AppSnapshotTests/RenderBudgetNewDocumentTests.swift | journey; RenderBudgetNewDocumentTests | #4309 | pr |
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
- Status channel: Belt watches `lead/suiteui-document-setup`, so the record is mirrored to `docs/leads/suiteui-document-setup/` there and to `lead/document-setup` (from 06:15Z).
- DS-m (#4184) is stacked with base `ds-a-document-setup-contract` so its diff stays its own (153 lines); against dev it would be 476 lines, over the lane's cap. It is retargeted to dev and merged with dev once #4182 lands.
- DS-m deviations (builder): frame-rate, resolution and duration problem sentences are ours (packet gives none); any `#RRGGBB00` reads transparent; schema `background` maxLength 11 so `transparent` validates.

## Open
- 2026-10-22T05:10Z wait check: CB-photo, CB-design, CB-halo, CB-flare planned (clipboard-interop lead building CB-5/7/9/11 test halves); UP-halo blocked behind UP-photo/UP-flare (unsaved-prompt run released); FR-halo, FR-flare, AC-zoom, CB-s, CB-m, CB-u done.
- DS-u waits on frame-rates:FR-u (held) and area-selection:AR-u (waiting).
- Adopt slices wait on other features' app slices (FR-halo/flare, CB-photo/design/halo/flare, UP-halo).
- 2026-10-22T06:15:11Z: rule 23, three identical blocked polls; Question for the supervisor posted on the issue.
- 2026-10-22T06:35:40Z: supervisor answered (06:19Z): finish the in-lane slice, then stop; issue labelled waiting-on-prereq. Note: the API proxy appends an attribution footer to every PR body and comment written from this session and re-adds it after edits; the lane strips it from the squash commit.
