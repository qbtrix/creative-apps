# orientation-crop lead record

Issue: #3756 · Packet: docs/blueprints/suiteui/features/orientation-crop.md
Run: act-1a1702c569a-0puo · Session: claude/suiteui-feature-lead-run-azjeoo · Started: 2026-10-24T23:00Z (earlier: act-1a1693a3ff0-mwrd · Session: cloud line lead (line:suiteui: tone-controls, shared-codecs, orientation-crop) · Started: 2026-10-23T14:51Z)
Stage: 3 polling (wave 4 PRs on the lane)
Base: origin/dev ae3efdb8
Next: lane on #5246 #5244 #5263 #5266; OC-z (OC-15, OC-16) folds into whichever of #5263/#5266 is last, once the other has landed; critic panels for OC-photo-u and OC-library-u once a run shows their screens

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| OC-a | contract: Orientation, CropAspect, CropRules stubs, CropCommands, C4 part; disabled tests | OC-1, OC-2 | – | – | false | 0 | done (#4082 → f080846e; Linux 39620526621; Belt-Slice-Done posted) | – | – |
| OC-m | Orientation and CropRules bodies; two mutation plans | OC-3, OC-4 | – | OC-a | false | 0 | done (#4088 → b48e63e3; Linux 39637279724; Belt-Slice-Done posted) | – | – |
| OC-u | CropAspectPicker, gallery, journey, render budget | OC-5, OC-6 | SJ-OC | OC-a; document-setup:DS-u (merged #4309) | true | 0 | done: run 40109073275 green; Belt-Slice-Done posted 17:19Z | – | – |
| OC-library-m | Library adopts orientation | OC-7, OC-8 | – | OC-m, suite-imaging:IM-z, clipboard-interop:CB-library (not started) (OC-8) | false | 0 | building (#5246) | – | – |
| OC-library-u | Library crop UI | OC-9, OC-10 | – | OC-u, OC-library-m | true | 0 | building (#5266) | – | – |
| OC-photo-m | Photo adopts orientation and crop | OC-11, OC-12 | – | OC-m, document-setup:DS-photo (not started) (OC-12) | false | 0 | building (#5244) | – | – |
| OC-photo-u | Photo crop UI | OC-13, OC-14 | – | OC-u, OC-photo-m, area-selection:AR-photo-u (not started) | true | 0 | building (#5263) | – | – |
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
- 2026-10-24T17:19Z: scoped suiteui run 40109073275 (33cd6e97, contains #4582) concluded success; posted Belt-Slice-Done: OC-u on #3756.

## Run act-1a1702c569a-0puo decisions
- Integration branch: the brief says main, but the fast lane only merges into dev (main fast-forwards from green dev), so slice PRs base on and target dev, as earlier runs did.
- lead/<feature> was rebuilt on main ef37711d (its old history shares no base with the rewritten main): records copied onto main and force-pushed with lease.
- Contract-first waits (rule 12): every cross-feature wait is met, since each named feature's first slice has merged (checked by its owned files on dev).
- The earlier run held OC-library-m, OC-photo-m, OC-photo-u and OC-z as blocked on IM-z, CB-library, DS-photo, AR-photo-u and CB-z. Under rule 12 those are met (IM-a, CB-a, DS-a and AR-a merged), so they are startable. Cross-line hand-offs LF-m, PT-m and PF-m are treated the same way, with Wire lines.
- 2026-10-25T02:20Z: OC-photo-u opened as #5263 (OC-13, OC-14) on lead/orientation-crop-OC-photo-m. 13 files, +344/−53. Gate CI: PASS at f532b79d. It adds Image > Flip Canvas Horizontal/Vertical (image.flip) and puts CropAspectPicker in Photo's CropOptions. The lead added the missing `Wire: area-selection:AR-photo-u` line to the body. Unverified until the macOS gate: PhotoApp views, the snapshots, the flipCanvasInOneBody budget row and the PhotoCropJourneyTests journey.
- 2026-10-25T02:35Z: OC-library-u opened as #5266 (OC-9, OC-10) on lead/orientation-crop-OC-library-m. Gate CI: PASS at 7063fc44. Its diff carried a dev merge (26 files, +404/−59), so the builder is rebuilding it on library-m alone. Lead finding: the picker's bare-X swap clashes with Library's X Reject while a draft is open, and a crop-mode X must never reject the photo. The builder fixes it in the same PR, either by suppressing Reject during a crop draft or by giving the Library picker no X shortcut. Known until OC-z: Library's crop math frames the unturned pixel size.
- 2026-10-25T02:41Z: #5266 rebuilt on library-m by cherry-pick (15 files, +280/-27, head aa03993b, gate CI: PASS, 959 tests). X fix, option (a): LibraryCatalog.cullChange(forKey:) returns nil for X while cropDraft is set, so the window route and the cull handler leave X to the picker's swap; LibraryFakeOrientationTests.xNeverRejectsWhileACropDraftIsOpen proves it. Option (b) was out because SuiteUI's CropAspectPicker hard-codes the X shortcut. Footers stripped from #5244, #5246, #5263 and #5266 via the GitHub MCP.

- 2026-10-26T02:04:14Z run act-1a175ee1051-o29l: OC-library-m slice done (run 40247461868); #5266 dev merged, gate running; #5244/#5263 in lane

- 2026-10-26T02:28:27Z run act-1a175ee1051-o29l: #5266 dev merged, CI: PASS, Head 2432646a, fast-lane relabelled (15 files +280/-27); #5263 restacked on fabf6717, CI: PASS, Head 9b8cf01c; OC-z follows when both u slices land
- 2026-10-26T14:40:29Z Resume, run act-1a178a4b1c2-ibn1. Belt-Slice-Done: OC-library-u posted (run 40337540609, scoped suiteui green on 68be32fc, holds #5266/01600e46). OC-photo-u #5263 head 79ed59ec clean, no needs-fix; waits on the lane (dev-red #5321 holds code batches, not ours). OC-z follows OC-photo-u.
- 2026-10-26T14:57:13Z OC-z: PR #5802 opened (stacked on #5263), head 8bc91414, fast-lane + feature-done
- 2026-10-31T12:46:32Z critic panel waits on #5913
- 2026-10-31T13:09:25Z critic panel waits on #5913
- 2026-10-31T13:30:47Z critic panel waits on #5913
- 2026-10-31T13:52:12Z critic panel waits on #5913
- 2026-10-31T14:24:26Z critic panel waits on #5913
- 2026-10-31T14:55:34Z critic panel waits on #5913
- 2026-10-31T15:27:22Z critic panel waits on #5913
- 2026-10-31T16:29:51Z critic review of photo-crop-portrait waits on finding #5913
- 2026-10-31T17:31:24Z critic review of photo-crop-portrait waits on finding #5913
- 2026-10-31T18:32:46Z critic review of photo-crop-portrait waits on finding #5913
- 2026-10-31T19:34:34Z critic review of photo-crop-portrait waits on finding #5913
- 2026-10-31T20:36:29Z critic review of photo-crop-portrait waits on finding #5913
- 2026-10-31T21:39:55Z closed; critic review of photo-crop-portrait.png waits on finding #5913
- 2026-10-31T22:42:22Z closed; critic review of photo-crop-portrait.png waits on finding #5913
- 2026-10-31T23:44:35Z closed; critic review of photo-crop-portrait.png waits on finding #5913
- 2026-11-01T00:46:19Z closed; critic review of photo-crop-portrait.png waits on finding #5913
- 2026-11-01T01:48:12Z closed; critic review of photo-crop-portrait.png waits on finding #5913
- 2026-11-01T02:49:46Z closed; critic review of photo-crop-portrait.png waits on finding #5913
- 2026-11-01T03:50:59Z closed; critic review of photo-crop-portrait.png waits on finding #5913
- 2026-11-01T04:53:12Z closed; critic review of photo-crop-portrait.png waits on finding #5913
- 2026-11-01T05:55:07Z closed; critic review of photo-crop-portrait.png waits on finding #5913
- 2026-11-01T06:56:51Z closed; critic review of photo-crop-portrait.png waits on finding #5913
- 2026-11-01T07:58:09Z closed; critic review of photo-crop-portrait.png waits on finding #5913
- 2026-11-01T09:00:15Z closed; critic review of photo-crop-portrait.png waits on finding #5913
- 2026-11-01T10:02:17Z closed; critic review of photo-crop-portrait.png waits on finding #5913
- 2026-11-01T11:04:25Z closed; critic review of photo-crop-portrait.png waits on finding #5913
- 2026-11-01T12:06:35Z closed; critic review of photo-crop-portrait.png waits on finding #5913
- 2026-11-01T13:10:15Z closed; critic review of photo-crop-portrait.png waits on finding #5913
- 2026-11-01T14:14:53Z closed; critic review of photo-crop-portrait.png waits on finding #5913
- 2026-11-01T15:16:19Z closed; critic review of photo-crop-portrait.png waits on finding #5913
- 2026-11-01T16:17:51Z closed; critic review of photo-crop-portrait.png waits on finding #5913
- 2026-11-01T17:19:09Z closed; critic review of photo-crop-portrait.png waits on finding #5913
