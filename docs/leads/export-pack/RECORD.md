# export-pack lead record

Issue: #3477 · Packet: docs/blueprints/suiteui/features/export-pack.md
Run: act-1a175ea55b7-729d (line lead, line:suiteui; relaunch 2026-10-26) · earlier: act-1a16fe1fa73-5x3s (line lead, line:suiteui; relaunch) · earlier: act-1a16c618fe7-h4fd (line lead, line:suiteui; unparked by the supervisor 2026-10-24)
Stage: XP-3 #5043 merged (99ace7038, dev tip 07:1xZ): XP-a merged; XP-4 #5065 restacked (add/add from the squash, ours kept) at b0f81dc6f; XP-5 #5104 and XP-8 #5106 restacked on it; all gates PASS; #5374 in lane
Base: origin/dev 8eff8ab85
Next: Belt-Slice-Done XP-a once a suiteui-scoped or full run contains 99ace7038; XP-10 after #5106 merges


## Run act-1a175ea55b7-729d decisions
- Brief rule 1: main checked out at d3323f6a7; main was rewritten, so each lead branch is rebuilt as origin/main plus this record (no merge base with the old branch), pushed --force-with-lease.
- PR base stays `dev` (CLAUDE.md; BASE_BRANCH=dev in scripts/fast-lane.sh; the lane retargets main PRs).
- Stacked PRs whose parent squash-merged carry the parent's commits (size FAIL, dirty): merge origin/dev into each branch, gate, move Head.
- XP-7 #5044 merged 16:19Z (c2681786c), XP-9 #5074 merged 16:59Z (5b1d3a19b), #4960 merged; scoped suiteui run 40247461868 at 30096d710 green and contains them.
- 2026-10-26T03:07:58Z: #5326 (packet's shape tolerance) fixed in the packet; the code's half-pixel rule stays, with a boundary test and two mutations (#5374).
- 2026-10-26T03:30:04Z heartbeat: all 7 PRs open and clean (#5043 #5065 #5104 #5106 #5374); waiting on lane; XP-10 after #5043+#5106
- 2026-10-26T04:01:17Z heartbeat: #5043 needs-fix (FormatListRatchet: gallery listed formats) fixed at d32cc2e2a, formats now from ExportFormats; #5065 #5104 #5106 restacked, gate PASS, Heads moved
- 2026-10-26T04:22:59Z heartbeat: all PRs open and clean, no labels; batches held while dev-red #5321 is open (not ours)
- 2026-10-26T04:53:11Z heartbeat: all PRs open and clean, no labels
- 2026-10-26T05:15:11Z heartbeat: all open PRs clean, no needs-fix/needs-rebase; #5297/#5299 over the size cap until #5295 lands; dev-red #5321 open (not ours)
- 2026-10-26T05:37:33Z heartbeat: no change: all open PRs clean, no labels to fix; dev-red #5321 open (not ours)
- 2026-10-26T06:00:09Z heartbeat: no change; lane holding (dev-red #5321 open)
- 2026-10-26T06:28:20Z heartbeat: no change; lane holding (dev-red #5321 open)
- 2026-10-26T06:53:25Z heartbeat: no change; lane holding (dev-red #5321 open); drift sweep has filed nothing on this feature yet
- 2026-10-26T07:15:52Z heartbeat: #5043 XP-3 merged; #5065/#5104/#5106 restacked and Head moved
- 2026-10-26T07:34:19Z heartbeat: XP-a scoped suiteui run 40284902781 at 99ace7038 in progress; #5065 restacked to 273 lines, lane re-evaluating; #5104/#5106 clean
- 2026-10-26T07:56:21Z heartbeat: Belt-Slice-Done XP-a posted (run 40284902781, comment 6411020269); XP-u #5065/#5104 and XP-z #5106 clean in fast-lane queue
- 2026-10-26T08:22:21Z heartbeat: no merges; dev-red #5321 (macos) holds code batches; red-triage blamed #5044, verified macOS failure is OnboardingModelTests timeouts, noted on #5321 (comment 6411461028)
- 2026-10-26T08:42:54Z heartbeat: no merges; dev-red #5321 (macos) still holds code batches; #5065/#5104/#5106 clean
- 2026-10-26T09:03:26Z heartbeat: no merges; dev-red #5321 (macos) still holds code batches; PRs clean
- 2026-10-26T09:22:44Z heartbeat: no merges; dev-red #5321 (macos) still holds code batches; PRs clean
- 2026-10-26T10:03:23Z heartbeat: XP-4 #5065 merged; #5104 (XP-5) and #5106 (XP-8) restacked on dev, gate pass; dev-red #5321 holds code batches
- 10:26 heartbeat: #5104/#5106 clean, waiting on dev-red #5321
- 10:47 heartbeat: waiting on fast lane; dev-red #5321 open
- 11:32 heartbeat: waiting on fast lane; dev-red #5321 open
- 2026-10-26T12:00:09Z heartbeat: all PRs open and clean; #5780 needs captain review (Package.swift); batches held while dev-red #5321 is open (not ours)
- 2026-10-26T12:33:28Z heartbeat: no change: all PRs open and clean, no needs-fix/needs-rebase; batches held while dev-red #5321 is open (not ours)
- 2026-10-26T13:09:30Z heartbeat: no change: all PRs open and clean; batches held while dev-red #5321 is open (not ours)

## Run act-1a16fe1fa73-5x3s decisions
- 22:59Z: the 22:27Z poll was one-shot, so no heartbeat ran from 22:28Z to 22:59Z. Each poll now schedules the next one 15 min out.
- Brief rule 1: main checked out at e79e9afc; lead/export-pack and lead/brush-keys rebased onto origin/main and pushed (--force-with-lease).
- PR base stays `dev`: CLAUDE.md, scripts/fast-lane.sh (BASE_BRANCH=dev) and every earlier run land through dev; a fast-lane PR on main is retargeted to dev anyway.
- PR bodies: the session's GitHub relay re-appends a generated-by footer on every edit; the fast lane strips it from the squash commit (its comment on #5043), so nothing waits on it.

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| XP-a | Export options, rules and format list as stubs; metadata contract and fake; Size and Metadata rows on a gallery page; checks written, disabled | XP-1, XP-2, XP-3 | SJ0 | AH-a (XP-1, shared C4 part), shell-media:SM-a (XP-2), tone-controls:TC-a + PL-a (XP-3) | no | 0 | building (XP-1 merged) | – | – |
| XP-u | Size modes with ratio lock and readout, Metadata picker, identified, within budget | XP-4, XP-5 | XJ1 | XP-a | yes | 0 | waiting | – | – |
| XP-m | Exact pixels, dropped tags, refusals; live metadata copy on JPEG and HEIC | XP-6, XP-7 | KJ-export, StillMetadataTests | XP-1 (XP-6); XP-2 + shell-media:SM-w (XP-7) | no | 0 | done (run 40247461868) | 40247461868 | – |
| XP-z | Gallery sheet plans through the rules; fake app exports at a size (RJ-X42); built | XP-8, XP-9, XP-10 | XJ1, KJ-export | XP-u, XP-m, tone-controls:TC-z, AH-z, TT-z, EY-z, SH-z, SS-d, PL-z | no | 0 | waiting | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| XP-1 | XP-a | 1 | ExportOptions.swift stubs, C4 part, suite written disabled | Sources/SuiteKernel/Export/ExportOptions.swift, Tests/SuiteKernelTests/ExportOptionsTests.swift, docs/c4/parts/creative-apps/suite-kernel/kernel-export-session.json | ExportOptionsTests compiles disabled; KernelShapeTests over Export/ | #3552 | merged #3552 09:28Z (fast lane) |
| XP-2 | XP-a | – | MetadataCarrying, FakeMetadata, SuiteServices.metadata | Sources/SuiteModel/Contracts/MetadataCarrying.swift, Sources/SuiteModel/Fakes/FakeMetadata.swift, Sources/SuiteModel/SuiteServices.swift, Tests/SuiteModelTests/FakeMetadataTests.swift | FakeMetadataTests | #4740 | merged (21074aea4) |
| XP-3 | XP-a | – | ExportPick.size/.metadata, placeholder rows, gallery page, journey skipped | Sources/SuiteUI/ExportSheet.swift, Sources/SuiteUI/Gallery/GalleryExportPack.swift, Sources/SuiteUI/SuiteGallery.swift, UITests/SuiteJourneyTests+Export.swift | SJ0 | #5043 | open (stacked on #4960) |
| XP-4 | XP-u | – | Size and Metadata rows | Sources/SuiteUI/ExportSheet.swift, Tests/SuiteUITests/ExportPackRowsTests.swift | ExportPackRowsTests | #5065 | open, stacked on #5043 (Wire: export-pack:LX-a) |
| XP-5 | XP-u | – | Snapshots, render budget, journey on | Tests/AppSnapshotTests/SuiteExportPackSnapshots.swift, Tests/AppSnapshotTests/RenderBudgetExportPackTests.swift, UITests/SuiteJourneyTests+Export.swift | XJ1 | #5104 | open, stacked on #5065 (journey on, 12 PNGs) |
| XP-6 | XP-m | 1 (stacked on XP-1) | ExportRules bodies, ExportOptions(json:), format list | Sources/SuiteKernel/Export/ExportOptions.swift, Tests/SuiteKernelTests/ExportOptionsTests.swift, Tests/mutations/SuiteKernel.ExportOptions.json | ExportOptionsTests on; Mutate | #3586 | merged #3586 by 11:14Z as b538c92c (fast lane; Mutate 5/5) |
| XP-7 | XP-m | – | StillMetadata live on ImageIO | Sources/SuiteShell/Media/StillMetadata.swift, Tests/AppSnapshotTests/StillMetadataTests.swift, Tests/RealJobs/fixtures/gps-phone.jpg | StillMetadataTests | #5044 | open, in lane |
| XP-8 | XP-z | – | Gallery sheet plans through ExportRules; live test | Sources/SuiteUI/Gallery/GalleryExportPack.swift, Tests/SuiteUITests/ExportPackLiveTests.swift | ExportPackLiveTests | #5106 | open, stacked on #5104 |
| XP-9 | XP-z | – | Fake app exports with ExportOptions(json:); RJ-X42 | Sources/SuiteKernel/Fakes/FakeCanvasDocument.swift, Tests/SuiteKernelTests/FakeCanvasExportTests.swift, Tests/mutations/SuiteKernel.FakeCanvasDocument.json, Tests/RealJobs/fake/export-pack/ | FakeCanvasExportTests | #5074 | open, in the lane (Wire: tone-controls:TC-z; Mutate 24/24) |
| XP-10 | XP-z | – | C4 names rows and rules; status built; feature-done | docs/c4/parts/creative-apps/suite-kernel/kernel-export-session.json, docs/blueprints/suiteui/features/export-pack.wave.json | scripts/ci | – | waits XP-7, XP-8, XP-9 |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- 2026-10-24T09:13:52Z Heartbeat 09:14Z: all PRs still open (chain #4960 → #5043 → #5065 → #5104 → #5106; #5044, #5074 in the lane). Dev-red #5113: the macOS job fails in setup (lottie-oracle cache skips brew install meson), not in code; not ours. No Belt-Slice-Done yet.
- 2026-10-24T08:51:29Z Heartbeat 08:52Z: chain #4960 → #5043 → #5065 → #5104 → #5106 open; #5044, #5074 in the lane. No merges, no Belt-Slice-Done. Full CI 40078344003 on dev 1bbaba6c1 is red on macOS; none of our PRs has merged, so it is not ours.
- 2026-10-24T08:31:23Z XP-8 #5106 (2 files, +164/−12): GalleryExportBoard plans each pick through ExportRules and writes through FakeMedia.still at the planned size; refused picks fail with the rules' sentence; fake writer capped at 4096 px per side. ExportPackLiveTests (5). Footer stripped and verified. XP-10 waits on merges.
- 2026-10-24T08:27:17Z Heartbeat 08:30Z: chain #4960 → #5043 → #5065 → #5104 open; #5044 and #5074 in the lane; XP-8 building. No merges yet, so no Belt-Slice-Done (dev CI 1bbaba6c1 holds none).
- 2026-10-24T08:20:37Z Wave 4: XP-8 stacked on XP-5 #5104 (XP-6 already merged as #3586). It plans through ExportRules and does not depend on XP-9 #5074's fake writer. XP-10 waits on XP-7, XP-8 and XP-9.
- 2026-10-24T08:20:07Z XP-5 #5104 opened (3 files, +158/−15): 6 snapshot states × light/dark, RenderBudgetExportPackTests (typing and mode switch at ≤ 2 bodies), journey steps 1 to 6 un-skipped. Footer stripped and verified. The typing budget test is new in shape; the batch macOS gate is its first real run.
- 2026-10-24T08:07:38Z Wave 3: XP-5 (snapshots, RenderBudgetExportPackTests, journey on) stacked on XP-4 #5065. XP-8 waits on XP-5 and XP-6; XP-10 last.
- 2026-10-24T08:06:39Z Wave 2 PRs: XP-4 #5065 (base lead/export-pack-XP-3) and XP-9 #5074 (base dev). Bodies checked: no attribution footer, trailer order right (moved #5074's Mutate line to sit above Fast-Check). Wave 3 starts XP-5 stacked on XP-4.
- 2026-10-24T07:01:05Z Wave 2: XP-4 (stacked on XP-3) and XP-9 (base dev; Wire: tone-controls:TC-z, met by contract-first since TC-a merged). AK-8 still waits: shared-codecs SC-f planned (re-read). TS-9 still waits: adjust-everywhere planned, AJ-a unmerged (re-read). No open findings for these features.
- 2026-10-24T06:59:46Z XP-3 opened as #5043 (base feat/export-pack-lx2, Wire: export-pack:LX-a; kernel type is SuiteExportSize) and XP-7 as #5044 (StillMetadata; ImageIO calls live in SuiteImageIO.swift because of ImageIOImportRatchetTests). Tool footers stripped from both bodies.
- 2026-10-24T05:34:08Z resume as run act-1a16c618fe7-h4fd. XP-2 is on dev (#4740). TC-a's placeholder (#4862) and editor-kernel are on dev, and placed-images PL-a's owned files are on dev, so XP-3 builds now. Per the supervisor, XP-3 builds on the ExportPick.metadata stub in Library's #4960 (LX-2) rather than adding a second one: it stacks on feat/export-pack-lx2 and adds only `.size`, the placeholder rows, the gallery page and the skipped journey. shell-media is built (SM-w), so XP-7 builds now. No open findings for XP slices (the FV-a findings #5012-#5021 are the Flare lead's).
- 2026-10-22 resume (#4523): same plan; base and target stay dev (the lane merges into dev; main fast-forwards from green dev).
- PRs target dev, not main: CLAUDE.md sends crew PRs to dev and the lane retargets main anyway; main was verified at b3011ab.
- XP-1's wait on autosave-history:AH-a is read as AH-1 only: the shared file is kernel-export-session.json, which AH-1 edits and AH-2 doesn't (the placed-images lead reads its A/C wait the same way). XP-1 is built now; its PR opens after #3543 merges.
- XP-6 waits on XP-1 only (packet task table): it needs only ExportOptions.swift, so it is unchained from XP-2 and XP-3 (lead.md stage 2) and stacked on XP-1.
- XP-a ships as more than one PR: its three tasks wait on three different features and together exceed 400 lines.
- Task branches are lead/export-pack-XP-n (a hyphen): lead/export-pack is a branch, so lead/export-pack/XP-n can't exist.
- XP-6's PR opens after #3552 merges, not stacked on dev now: with XP-1's commits it is 440 lines, over the 400 cap.
- XP-1 and XP-6 run in one builder, one after another: XP-6 fills XP-1's stub bodies.

## Open
- 2026-10-22: SM-a and SM-w on dev, so XP-2 starts; tone-controls is led in this run too, so XP-3 follows TC-2.
- 08:37Z: the lane's macOS build has been queued for 30 min behind run 39362977551 (#3409, running since 03:11Z); third identical poll, so asked the supervisor on #3477 (6286926687).
- XP-2 waits on shell-media SM-a (suite line, packet planned, no lead branch).
- XP-3 waits on tone-controls TC-a, which waits on #3144 (core pin 9ed9ef0), gradient-fill GF-a, AH-a, PL-a.
