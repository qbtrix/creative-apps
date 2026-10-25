# photo export-pack lead record

Issue: #3470 · Packet: docs/blueprints/photo/features/export-pack.md
Run: act-1a15e2da54d-qlg1 (resumed; earlier act-1a15a9f4eba-h30y) · Session: claude/feature-lead-playbook-t69dpt · Started: 2026-10-20T18:40Z
Stage: 3 building (unparked 2026-10-23T15:11Z under contract-first waits)
Base: e382f9d7fba02ffdefc8ba2f23c9461b4774fad6
Next: PX-5 waits XP-4; swap XP-3's Size/Metadata rows in when it merges; PX-4 still on the supervisor's codec hold; PX-8 waits PX-7, PX-5, tone-controls PT-z and place-image PP-z (PT-a merged #4845)

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| PX-a | Photo export reads ExportOptions on stubs; Export… opens SuiteExportSheet with Size row and four formats | PX-1, PX-2 | MJ-PX | XP-1, XP-6 (merged, PX-1); XP-3 + AX-photo (PX-2) | yes | 0 | done (Belt-Slice-Done 08:54Z, run 40077014447) | – | – |
| PX-u | sheet snapshots, render budget, journey written | PX-5, PX-6 | PJ-X1 | PX-a; XP-4 (PX-5) | yes | 0 | waiting | – | – |
| PX-m | exact-size resample, PNG/JPEG/HEIC/TIFF through the shared encoder, headless and in app | PX-3, PX-4 | MJ-PX | PX-1 + XP-6 (PX-3, met); SM-w (PX-4) | yes | 0 | building (PX-1, PX-3 merged; PX-4 parked) | – | – |
| PX-z | live services, journey, blueprint, built | PX-7, PX-8 | PJ-X1 | PX-u, PX-m; tone-controls:PT-z, place-image:PP-z (PX-8) | yes | 0 | waiting | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| PX-1 | PX-a | 1 | PhotoExport+Kernel stubs; PhotoExportPackTests disabled | Sources/PhotoModel/PhotoExport+Kernel.swift, Tests/PhotoModelTests/PhotoExportPackTests.swift | compiles; existing export tests pass | #3678 | merged 21:15Z (head 061e0972) |
| PX-2 | PX-a | – | Export… opens SuiteExportSheet; Photo's ExportSheet.swift deleted | Sources/PhotoApp/PhotoWindow+Export.swift, Sources/PhotoApp/ExportSheet.swift | PhotoExportPackSnapshots.sheet | #4832 | merged 08:02Z (head 383ff525) |
| PX-3 | PX-m | 1 (stacked on PX-1) | exportPixels and headless export on ExportOptions; RJ-P01 | Sources/PhotoModel/PhotoExport+Kernel.swift, Sources/PhotoModel/PhotoHeadless.swift, Tests/PhotoModelTests/PhotoExportPackTests.swift, Tests/mutations/PhotoModel.PhotoExport+Kernel.json, Tests/RealJobs/photo/instagram/ | PhotoExportPackTests | #3729 | merged 22:41Z (head e2c55886, Mutate 4/4) |
| PX-4 | PX-m | – | app writes formats through services.media.still | Sources/PhotoApp/ImageIOCodec.swift, Tests/AppSnapshotTests/PhotoExportFormatsTests.swift | PhotoExportFormatsTests | – | parked (supervisor: no third codec path; waits shared-codecs XK3 + shell-media, no issue yet) |
| PX-5 | PX-u | – | snapshots, render budget | Tests/AppSnapshotTests/PhotoExportPackSnapshots.swift, Tests/AppSnapshotTests/RenderBudgetPhotoExportPackTests.swift | RenderBudgetPhotoExportPackTests.typingWidthInTwoBodies | – | waits XP-4 |
| PX-6 | PX-u | – | journey written, skipped | UITests/PhotoJourneyTests+ExportPack.swift | compiles, skipped | #4836 | merged 08:02Z (head a1c038a6; skipped until PX-7) |
| PX-7 | PX-z | – | journey on live | UITests/PhotoJourneyTests+ExportPack.swift | PhotoExportPackJourneyTests.testExportForInstagram | – | waits PX-6, PX-3, PX-4 |
| PX-8 | PX-z | – | photo.md, status built, feature-done | docs/blueprints/photo.md, docs/blueprints/photo/features/export-pack.wave.json | scripts/waves render --dry-run | – | waits PX-7, PX-5, PT-z, PP-z |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- Lead branch is lead/photo-<feature> and the record lives in docs/leads/photo-<feature>/: the packet names lead/<feature>, but lead/gradient-fill, lead/export-pack and lead/file-flow already belong to the Flare, SuiteUI and Suite features of the same names, and are active. Earlier Photo leads use the photo- prefix (lead/photo-seams, lead/photo-documents).
- Base and PR target are origin/dev, not main: the brief names main (b3011ab9, verified), but the packets exist only on dev, CLAUDE.md sends crew PRs to dev and the lane retargets main PRs to dev.
- One PR per task, stacked: PRs stay under the 400-line cap, and each slice PR opens with its failing or disabled test as the first commit.
- PX-1 and PX-3 start without AX-photo: they own only new files (PhotoExport+Kernel.swift) and PhotoHeadless.swift, none of AX-p1/AX-p2's (PhotoWorkspace.swift, OutputContracts.swift, PhotoExportTests.swift), and they need only ExportOptions/ExportRules/ExportFormats, merged with XP-1 (#3552) and XP-6 (#3586). PX-2 still waits on AX-photo, since the sheet reads ExportRun.
- PX-3 stacks on PX-1 in wave 1 (it needs only PX-1 and XP-6).

## Wires
- [ ] Wire: suiteui/export-pack:XP-a (built on its fakes in PX-2: the sheet's scale-only Size row and no Metadata row; swap in XP-3's Size and Metadata rows when it merges)

## Open
- PX-2 waits suiteui export-pack XP-3 (Size row; lead/export-pack: XP-3 waits TC-a, PL-a) and adopt-kernel-export AX-photo (blocked on AL-photo). PX-4 waits shell-media SM-w (planned, no lead). PX-8 waits Photo tone-controls PT-z and place-image PP-z (no lead yet).
- PX-3 (#3729): RJ-P01 stays pending on gap #3692 (no `image.crop` catalog step; JPEG pixel check waits on image-codecs). `expected/landscape-instagram.png` is missing and must be added before RJ-P01 can go green. `exportPixels` honours a framed but unapplied crop (that is what `.cropThenSize` catches). The 6000 × 4000 long-edge test takes ~107 s in debug.
- 2026-10-25T22:07Z #5171 (PX-a follow-up: first-five export journey picks JPEG by the suite sheet's id, head 9c1cc325) merged through the lane, batch of 1. #5206 (PhotoHeadless open/new with services, #5193) and the captain's mac-finish #5353 (export note shows the pixel size; it should follow XP-3's Size row at the swap) are still open.
- Supervisor (19:54Z, #3470): PX-4 parked, not through ImageIOCodec. XP-3, XP-4 and AX-photo have no open PRs to stack on (polled 20:12Z), so PX-2 and PX-5 keep waiting.
- 2026-10-23T15:11Z supervisor unparked #3470 under contract-first waits (lead.md rule 12, #4814). XP-1 and XP-2 are on dev, XP-3 is not: PX-2 builds on SuiteExportSheet as dev has it with a Wire line. PX-2 offers only the formats the app writes today (PNG, JPEG) and hides the scale Size row, since the app's write ignores size until PX-4 sends it through exportPixels (no dead controls); HEIC, TIFF and Size come with PX-4. PT-a (tone-controls' contract) has not merged, so PX-8 stays waiting.
