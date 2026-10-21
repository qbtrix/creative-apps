# orientation-crop lead record

Issue: #3756 · Packet: docs/blueprints/suiteui/features/orientation-crop.md
Run: act-1a15e33396b-eo15 · Session: cloud line lead (line:suiteui, with #3721 and #3758) · Started: 2026-10-21T11:26Z
Stage: 3 wave 1
Base: ac7f95c9f6b0516253108a270145e4280f243b69
Next: OC-a and OC-m done; remaining slices blocked on other features (see #3756 comment 6317098600); recheck blockers each poll, Question for the supervisor after 3 identical blocked polls

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| OC-a | contract: Orientation, CropAspect, CropRules stubs, CropCommands, C4 part; disabled tests | OC-1, OC-2 | – | – | false | 0 | done (#4082 → f080846e; Linux 39620526621; Belt-Slice-Done posted) | – | – |
| OC-m | Orientation and CropRules bodies; two mutation plans | OC-3, OC-4 | – | OC-a | false | 0 | done (#4088 → b48e63e3; Linux 39637279724; Belt-Slice-Done posted) | – | – |
| OC-u | CropAspectPicker, gallery, journey, render budget | OC-5, OC-6 | SJ-OC | OC-a; document-setup:DS-u (not started) | true | 0 | blocked | – | – |
| OC-library-m | Library adopts orientation | OC-7, OC-8 | – | OC-m, suite-imaging:IM-z, clipboard-interop:CB-library (not started) (OC-8) | false | 0 | blocked | – | – |
| OC-library-u | Library crop UI | OC-9, OC-10 | – | OC-u, OC-library-m | true | 0 | blocked | – | – |
| OC-photo-m | Photo adopts orientation and crop | OC-11, OC-12 | – | OC-m, document-setup:DS-photo (not started) (OC-12) | false | 0 | blocked | – | – |
| OC-photo-u | Photo crop UI | OC-13, OC-14 | – | OC-u, OC-photo-m, area-selection:AR-photo-u (not started) | true | 0 | blocked | – | – |
| OC-z | delete LibraryCrop and PhotoCropSize; status built; feature-done | OC-15, OC-16 | – | OC-library-u, OC-photo-u, clipboard-interop:CB-z | false | 0 | blocked | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| OC-1 | OC-a | 1 | stubs + CropCommands + C4 part kernel-crop | Sources/SuiteKernel/Crop/*, docs/c4/parts/creative-apps/suite-kernel/kernel-crop.json | CommandShapeTests | #4082 ea5ec5d7 | merged |
| OC-2 | OC-a | 1 | disabled OrientationTests, CropRulesTests | Tests/SuiteKernelTests/OrientationTests.swift, Tests/SuiteKernelTests/CropRulesTests.swift | disabled suites | #4082 ea5ec5d7 | merged |
| OC-3 | OC-m | 2 | Orientation bodies + plan SuiteKernel.Orientation | per packet | OrientationTests; mutate | #4088 b929af4a | open |
| OC-4 | OC-m | 2 | CropRules bodies + plan SuiteKernel.Crop | per packet | CropRulesTests; mutate | #4088 b929af4a | open |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- 2026-10-21T11:26Z: one PR per slice (brief rule 8): OC-1+OC-2 ship as the OC-a PR; OC-3+OC-4 as OC-m stacked on it.
- 2026-10-21T11:26Z: document-setup, area-selection and clipboard-interop have no lead branch or issue: every UI and app slice is blocked on them.

## Open
- OC-u blocked: document-setup:DS-u (feature not started).
