# export-pack lead record

Issue: #3477 · Packet: docs/blueprints/suiteui/features/export-pack.md
Run: act-1a15821c836-93pf · Session: claude/feature-lead-playbook-v981be · Started: 2026-10-20T07:09Z
Stage: 3 wave 1
Base: 5a17e0e54b9c356c371e90c7fc10f062bbb0dde1
Next: #3552 (XP-1) waits on the lane (macOS build); once it merges, merge dev into lead/export-pack-XP-6, rerun scripts/ci --changed, open the XP-6 PR (Slice: XP-m, Mutate 5/5)

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| XP-a | Export options, rules and format list as stubs; metadata contract and fake; Size and Metadata rows on a gallery page; checks written, disabled | XP-1, XP-2, XP-3 | SJ0 | AH-a (XP-1, shared C4 part), shell-media:SM-a (XP-2), tone-controls:TC-a + PL-a (XP-3) | no | 0 | building | – | – |
| XP-u | Size modes with ratio lock and readout, Metadata picker, identified, within budget | XP-4, XP-5 | XJ1 | XP-a | yes | 0 | waiting | – | – |
| XP-m | Exact pixels, dropped tags, refusals; live metadata copy on JPEG and HEIC | XP-6, XP-7 | KJ-export, StillMetadataTests | XP-1 (XP-6); XP-2 + shell-media:SM-w (XP-7) | no | 0 | waiting | – | – |
| XP-z | Gallery sheet plans through the rules; fake app exports at a size (RJ-X42); built | XP-8, XP-9, XP-10 | XJ1, KJ-export | XP-u, XP-m, tone-controls:TC-z, AH-z, TT-z, EY-z, SH-z, SS-d, PL-z | no | 0 | waiting | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| XP-1 | XP-a | 1 | ExportOptions.swift stubs, C4 part, suite written disabled | Sources/SuiteKernel/Export/ExportOptions.swift, Tests/SuiteKernelTests/ExportOptionsTests.swift, docs/c4/parts/creative-apps/suite-kernel/kernel-export-session.json | ExportOptionsTests compiles disabled; KernelShapeTests over Export/ | #3552 | PR open (head 55611e3, CI: PASS) |
| XP-2 | XP-a | – | MetadataCarrying, FakeMetadata, SuiteServices.metadata | Sources/SuiteModel/Contracts/MetadataCarrying.swift, Sources/SuiteModel/Fakes/FakeMetadata.swift, Sources/SuiteModel/SuiteServices.swift, Tests/SuiteModelTests/FakeMetadataTests.swift | FakeMetadataTests | – | waits SM-a |
| XP-3 | XP-a | – | ExportPick.size/.metadata, placeholder rows, gallery page, journey skipped | Sources/SuiteUI/ExportSheet.swift, Sources/SuiteUI/Gallery/GalleryExportPack.swift, Sources/SuiteUI/SuiteGallery.swift, UITests/SuiteJourneyTests+Export.swift | SJ0 | – | waits TC-a, PL-a |
| XP-4 | XP-u | – | Size and Metadata rows | Sources/SuiteUI/ExportSheet.swift, Tests/SuiteUITests/ExportPackRowsTests.swift | ExportPackRowsTests | – | waits XP-3 |
| XP-5 | XP-u | – | Snapshots, render budget, journey on | Tests/AppSnapshotTests/SuiteExportPackSnapshots.swift, Tests/AppSnapshotTests/RenderBudgetExportPackTests.swift, UITests/SuiteJourneyTests+Export.swift | XJ1 | – | waits XP-4 |
| XP-6 | XP-m | 1 (stacked on XP-1) | ExportRules bodies, ExportOptions(json:), format list | Sources/SuiteKernel/Export/ExportOptions.swift, Tests/SuiteKernelTests/ExportOptionsTests.swift, Tests/mutations/SuiteKernel.ExportOptions.json | ExportOptionsTests on; Mutate | – | built (lead/export-pack-XP-6 de396d4, +175 on XP-1, CI: PASS, Mutate 5/5) |
| XP-7 | XP-m | – | StillMetadata live on ImageIO | Sources/SuiteShell/Media/StillMetadata.swift, Tests/AppSnapshotTests/StillMetadataTests.swift, Tests/RealJobs/fixtures/gps-phone.jpg | StillMetadataTests | – | waits XP-2, SM-w |
| XP-8 | XP-z | – | Gallery sheet plans through ExportRules; live test | Sources/SuiteUI/Gallery/GalleryExportPack.swift, Tests/SuiteUITests/ExportPackLiveTests.swift | ExportPackLiveTests | – | waits XP-5, XP-6 |
| XP-9 | XP-z | – | Fake app exports with ExportOptions(json:); RJ-X42 | Sources/SuiteKernel/Fakes/FakeCanvasDocument.swift, Tests/SuiteKernelTests/FakeCanvasExportTests.swift, Tests/mutations/SuiteKernel.FakeCanvasDocument.json, Tests/RealJobs/fake/export-pack/ | FakeCanvasExportTests | – | waits XP-6, TC-z and A/C waits |
| XP-10 | XP-z | – | C4 names rows and rules; status built; feature-done | docs/c4/parts/creative-apps/suite-kernel/kernel-export-session.json, docs/blueprints/suiteui/features/export-pack.wave.json | scripts/ci | – | waits XP-7, XP-8, XP-9 |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- PRs target dev, not main: CLAUDE.md sends crew PRs to dev and the lane retargets main anyway; main was verified at b3011ab.
- XP-1's wait on autosave-history:AH-a is read as AH-1 only: the shared file is kernel-export-session.json, which AH-1 edits and AH-2 doesn't (the placed-images lead reads its A/C wait the same way). XP-1 is built now; its PR opens after #3543 merges.
- XP-6 waits on XP-1 only (packet task table): it needs only ExportOptions.swift, so it is unchained from XP-2 and XP-3 (lead.md stage 2) and stacked on XP-1.
- XP-a ships as more than one PR: its three tasks wait on three different features and together exceed 400 lines.
- Task branches are lead/export-pack-XP-n (a hyphen): lead/export-pack is a branch, so lead/export-pack/XP-n can't exist.
- XP-6's PR opens after #3552 merges, not stacked on dev now: with XP-1's commits it is 440 lines, over the 400 cap.
- XP-1 and XP-6 run in one builder, one after another: XP-6 fills XP-1's stub bodies.

## Open
- 08:37Z: the lane's macOS build has been queued for 30 min behind run 39362977551 (#3409, running since 03:11Z); third identical poll, so asked the supervisor on #3477 (6286926687).
- XP-2 waits on shell-media SM-a (suite line, packet planned, no lead branch).
- XP-3 waits on tone-controls TC-a, which waits on #3144 (core pin 9ed9ef0), gradient-fill GF-a, AH-a, PL-a.
