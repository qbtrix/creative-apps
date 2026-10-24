# orientation-crop lead record

Issue: #3756 · Packet: docs/blueprints/suiteui/features/orientation-crop.md
Run: act-1a1693a3ff0-mwrd · Session: cloud line lead (line:suiteui: tone-controls, shared-codecs, orientation-crop) · Started: 2026-10-23T14:51Z
Stage: 3 wave 3
Base: origin/dev 8021b0f56a45a59540cd4ea0ff99651c5fb8dc2a
Next: #4582 (OC-u) merged 2026-10-24T15:48:35Z; post Belt-Slice-Done: OC-u once a green ci.yml run on dev (app=suiteui or full) includes it. Other slices blocked.

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| OC-a | contract: Orientation, CropAspect, CropRules stubs, CropCommands, C4 part; disabled tests | OC-1, OC-2 | – | – | false | 0 | done (#4082 → f080846e; Linux 39620526621; Belt-Slice-Done posted) | – | – |
| OC-m | Orientation and CropRules bodies; two mutation plans | OC-3, OC-4 | – | OC-a | false | 0 | done (#4088 → b48e63e3; Linux 39637279724; Belt-Slice-Done posted) | – | – |
| OC-u | CropAspectPicker, gallery, journey, render budget | OC-5, OC-6 | SJ-OC | OC-a; document-setup:DS-u (merged #4309) | true | 0 | merged #4582 (awaiting green suiteui/full run) | – | – |
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
| OC-3 | OC-m | 2 | Orientation bodies + plan SuiteKernel.Orientation | per packet | OrientationTests; mutate | #4088 b929af4a | merged |
| OC-4 | OC-m | 2 | CropRules bodies + plan SuiteKernel.Crop | per packet | CropRulesTests; mutate | #4088 b929af4a | merged |

| OC-5 | OC-u | 3 | CropAspectChoices (kernel) + CropAspectPicker + gallery Crop page | Sources/SuiteKernel/Crop/CropAspectChoices.swift, Sources/SuiteUI/CropAspectPicker.swift, Sources/SuiteUI/Gallery/GalleryCrop.swift, Sources/SuiteUI/SuiteGallery.swift | CropAspectChoicesTests, CropAspectPickerTests; mutate | #4582 | merged |
| OC-6 | OC-u | 3 | journey + render budget + snapshots | UITests/SuiteJourneyTests+Crop.swift, Tests/AppSnapshotTests/RenderBudgetCropPickerTests.swift | SJ-OC; swapInOneBody | #4582 | merged |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- 2026-10-21T11:26Z: one PR per slice (brief rule 8): OC-1+OC-2 ship as the OC-a PR; OC-3+OC-4 as OC-m stacked on it.
- 2026-10-21T11:26Z: document-setup, area-selection and clipboard-interop have no lead branch or issue: every UI and app slice is blocked on them.

- 2026-10-22T16:52Z: relaunch as #4528; OC-a/OC-m Slice-Done lines re-posted on #4528. OC-u targets dev (CLAUDE.md: never main). Picker decisions go in a kernel CropAspectChoices type so Linux tests them.
- 2026-10-22: #4582 body footer is server-appended and returns on edit; the lane strips it from the squash. C4 descriptions left alone (gate refuses edits to existing descriptions; new files already covered by paths).

## Open
- OC-library-m: suite-imaging:IM-z, clipboard-interop:CB-library. OC-photo-m: DS-photo. OC-photo-u: AR-photo-u. OC-z: CB-z.
- 2026-10-23T14:51:14Z: run act-1a1693a3ff0-mwrd takes over (issue #3756). Base and PR target stay dev (CLAUDE.md, the lane), not main as the brief says. #4582 macOS error: "property wrapper can only apply to a single variable" (2 files), fixed by one @State per line. scripts/ci fails on dev itself at the journey quarantine stage (6 Halo/Photo entries expired 2026-10-23, supervisor-owned): the gate is verified past it with an uncommitted renewal.
- 2026-10-23T16:45Z: dev now has the six quarantine entries renewed to 2026-10-27 (supervisor), so dev's gate passes that stage. The OC-u gate reruns on 8005f4a3. Waits unchanged: IM-z, CB-library, DS-photo, AR-photo-u, CB-z not on dev. Status now also pushed to lead/suiteui-orientation-crop (the branch Belt reads).
- 2026-10-24T06:57Z: run act-1a16cae7922-5nat resumes on #3756 (dev e5dcf939). #4582 (OC-u) was dirty: merged origin/dev into it (SuiteGallery.swift page list: kept GalleryToneRows and GalleryCrop), gating before push. Waits unchanged: IM-z, CB-library, DS-photo, AR-photo-u, CB-z. 0 open findings.
- 2026-10-24T07:18Z: #4582 head 5db0ce5a (origin/dev merged, CI: PASS), body moved to this run, footer dropped; merges clean with dev 830af22d.

- 2026-10-24T08:33Z check-in: no merges; no needs-fix/rebase; no new findings; waits unchanged
- 2026-10-24T15:48:35Z: #4582 (OC-u) merged by the lane batch. Belt-Slice-Done waits for a green scoped-suiteui or full ci.yml run on dev containing it. Waits unchanged: IM-z, CB-library, DS-photo, AR-photo-u, CB-z.
