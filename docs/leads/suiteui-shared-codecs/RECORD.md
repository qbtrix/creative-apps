# shared-codecs lead record

Issue: #3718 · Packet: docs/blueprints/suiteui/features/shared-codecs.md
Run: act-1a1702c569a-0puo · Session: claude/suiteui-feature-lead-run-azjeoo · Started: 2026-10-24T23:00Z (earlier: act-1a16cae7989-hj12 (line lead: area-selection, shared-codecs, shared-raw) · Session: claude/feature-lead-playbook-bs72fe · Started: 2026-10-24T06:50Z (earlier act-1a1693a4009-hyio, act-1a1693a3ff0-mwrd))
Stage: 3 polling (wave 4 PRs on the lane)
Base: origin/dev ae3efdb8
Next: wait for the lane on #5073 #5076 #5098 #5101 #5069 #5071 #5232; build SC-8 (on #5069 + SC-4c #5101) and SC-10 (on #5071 + SC-4c), SC-12 folded into the last. Done checks read the CI run on dev that contains each slice's last PR.

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| SC-f | one shared image-format list (SuiteImageFormats) every app and the CLI read | SC-13, SC-14, SC-15, SC-16 | photo open/export panels | – | yes | 0 | done (Belt-Slice-Done 2026-10-22) | – | – |
| SC-a | core PNG parity proven; SuiteImageIO stubs in SuiteShell | SC-1, SC-2 | – | suite-imaging:IM-a (SC-2 only) | no | 0 | done: run 40005632479 green; Belt-Slice-Done posted 19:41Z (ui false, no critic panel) | – | – |
| SC-photo | Photo's codec routes through SuiteImageIO | SC-3, SC-4 | rotated-photo | SC-a, IM-m (both done) | no | 0 | building (#5073, #5076, #5098, #5101) | – | – |
| SC-halo | Halo frame PNG writes through core | SC-5, SC-6 | – | SC-a (done) | no | 0 | done: full CI 40129856269 green; Belt-Slice-Done posted | – | – |
| SC-library | Library decode/JPEG through SuiteImageIO | SC-7, SC-8 | – | SC-a, SC-f (both done) | no | 0 | building (#5069; SC-8 next) | – | – |
| SC-raster | Design/Flare rasterizers write PNG through SuiteImageIO | SC-9, SC-10 | – | SC-a (done) | no | 0 | building (#5071; SC-10 next) | – | – |
| SC-z | HaloFramePNG retired, ImageIO baseline at its floor, feature built | SC-11, SC-12 | – | all slices, AK-z | no | 0 | building (#5232; SC-12 folds into the last) | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| SC-13 | SC-f | 1 | acceptance tests first; format-list ratchet live | Tests/SuiteModelTests/SuiteImageFormatsTests.swift, Tests/SuiteModelTests/FormatListRatchetTests.swift, Tests/format-lists-baseline.txt, Tests/AfterGlowCLITests/ImageFormatParityTests.swift | FormatListRatchetTests | #4019 | in review |
| SC-14 | SC-f | 2 | SuiteImageFormats value + plists read it | Sources/SuiteModel/Values/SuiteImageFormats.swift, Sources/SuiteModel/Values/SuiteTypes.swift, Bundle/Info/Photo.plist, Bundle/Info/Library.plist, Tests/SuiteModelTests/PlistShapeAppsTests.swift, Tests/mutations/SuiteModel.SuiteImageFormats.json, docs/c4/parts/creative-apps/suite-model/suite-identity.json | SuiteImageFormatsTests | #4238 | merged |
| SC-15 | SC-f | 3 | Photo open/export lists from SuiteImageFormats | Sources/PhotoModel/PhotoImageFile.swift, Sources/PhotoModel/PhotoHeadless.swift, Sources/PhotoApp/PhotoWindow+File.swift, Sources/PhotoApp/PhotoWindow+Export.swift | PhotoFormats tests | – | planned |
| SC-16 | SC-f | 4 | Library export lists from SuiteImageFormats | Sources/LibraryModel/Contracts/LibraryValues.swift, Sources/LibraryModel/Contracts/ExportFormats.swift, Sources/LibraryModel/Contracts/ExportPresets.swift, Sources/LibraryApp/Platform/JPEGWriter.swift | Library format tests | – | planned |
| SC-1 | SC-a | 1 | core PNG parity + ImageIO import ratchet live | Tests/PhotoModelTests/CorePNGParityTests.swift, Tests/SuiteModelTests/ImageIOImportRatchetTests.swift, Tests/imageio-baseline.txt, Tests/AppSnapshotTests/SuiteImageIOTests.swift, Tests/PhotoModelTests/Fixtures/png-parity/ | CorePNGParityTests, ImageIOImportRatchetTests | #4020 | merged |
| SC-2 | SC-a | 2 | SuiteImageIO stubs (supervisor merge: Package.swift) | Sources/SuiteShell/SuiteImageIO.swift, Package.swift, project.yml, docs/c4/parts/creative-apps/suite-shell/shell-imageio.json | SuiteImageIOTests | #4873 → 2f94f450 | merged |
| SC-3 | SC-photo | 3 | Photo codec route tests first | Tests/PhotoModelTests/PhotoCodecRouteTests.swift, Tests/RealJobs/photo/rotated-photo/ | PhotoCodecRouteTests | #5073 | open |
| SC-4 | SC-photo | 4 | Photo codec through SuiteImageIO | Sources/SuiteShell/SuiteImageIO.swift, Sources/PhotoApp/ImageIOCodec.swift, Sources/PhotoModel/CoreRasterImageCodec.swift, Sources/PhotoApp/PhotoPasteboard.swift | PhotoCodecRouteTests | #5076 #5098 #5101 | open |
| SC-5 | SC-halo | 3 | Halo frame PNG core tests first | Tests/HaloModelTests/HaloFramePNGCoreTests.swift | HaloFramePNGCoreTests | #4875 5e275b64 | open |
| SC-6 | SC-halo | 4 | Halo headless PNG through core | Sources/HaloModel/HaloHeadless.swift, Sources/HaloApp/HaloPNGWriter.swift, Tests/mutations/HaloModel.HaloHeadless.json | HaloFramePNGCoreTests | #4875 5e275b64 | open |
| SC-7 | SC-library | 3 | Library ImageIO tests first | Tests/AppSnapshotTests/LibraryImageIOTests.swift, Tests/AppSnapshotTests/Fixtures/library-imageio-expected.json | LibraryImageIOTests | #5069 | open |
| SC-8 | SC-library | 5 | Library decode/JPEG through SuiteImageIO | Sources/LibraryApp/Platform/ImageIODecoder.swift, Sources/LibraryApp/Platform/JPEGWriter.swift | LibraryImageIOTests | – | planned |
| SC-9 | SC-raster | 3 | rasterizer PNG tests first | Tests/AppSnapshotTests/RasterizerPNGTests.swift | RasterizerPNGTests | #5071 | open |
| SC-10 | SC-raster | 5 | Design/Flare rasterizers through SuiteImageIO | Sources/DesignApp/DesignRasterizer.swift, Sources/FlareApp/StageRasterizer.swift | RasterizerPNGTests | – | planned |
| SC-11 | SC-z | 5 | retire HaloFramePNG | Sources/HaloModel/HaloFramePNG.swift, Tests/mutations/HaloModel.HaloFramePNG.json, Tests/PhotoModelTests/CorePNGParityTests.swift, Tests/canonical-baseline.txt | CorePNGParityTests | #5232 | open |
| SC-12 | SC-z | 6 | ImageIO baseline floor; feature-done | Tests/imageio-baseline.txt, Tests/SuiteModelTests/ImageIOImportRatchetTests.swift, docs/c4/parts/creative-apps/suite-shell/shell-imageio.json, docs/blueprints/suiteui/features/shared-codecs.wave.json | ImageIOImportRatchetTests | – | planned |

Waves (combined plan, rule 19): 1 = SC-13, SC-1, suite-imaging:IM-1 (independent, disjoint files). 2 = SC-14 (waits SC-13: makes its disabled tests live), SC-2 (waits SC-1 and IM-a: links SuiteShell to CoreRaster beside IM-1's Package.swift edit), suite-imaging:IM-2. Later waves per the packet's Build waves.

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- Base is origin/dev (1191940), not main 0dd23d6: the packets and wave data live only on dev, and CLAUDE.md says branch from dev.
- One PR per task, not per slice: SC-13+SC-14 is ~580 lines, over the 400 cap (rule 22; same call as the photo lead).
- SC-14 is built stacked on SC-13 now; its PR opens once SC-13 merges so its diff against dev fits the cap.
- SC-2 edits Package.swift and project.yml as the packet says; it is a supervisor merge, off the fast lane.
- Wave work runs as one worktree subagent per task (Workflow needs opt-in; lead.md fallback).
- 2026-10-23T16:45Z: SC-halo builds from dev: it uses only core's PNG.write, which HaloModel already links, and no SC-2 API. SC-2 (#4873) is a supervisor merge (touches Package.swift for SuiteShell to link CoreRaster), no fast-lane label. SC-2 adds SuiteImageIO.swift to FormatListScan.allowed (FormatListRatchetTests; baseline and cap unchanged): a slight ratchet loosening for the supervisor to approve on #4873. encode has no profile: parameter yet (ColorProfile is CoreColor, not re-exported by CoreRaster); SC-4 adds it with an .sRGB default. HaloPNGWriter's line in Tests/imageio-baseline.txt is left for SC-11's prune (the ratchet ignores a listed file that no longer imports ImageIO).

## Open
- Under contract-first (lead.md rule 12): SC-photo, SC-library and SC-raster are startable; SC-z waits on the four slices plus AK-z's contract slice.
- Open findings for this feature: 0.
- 2026-10-21T19:24Z: #4019 and #4020 were held on red Linux by dev's CommandPathTests photo failure (PhotoPlace.swift:36), which #4008 fixed on dev; both branches merge origin/dev and re-gate.

- 2026-10-21T19:37Z: #4019 and #4020 merged dev (#4008 fix), baselined the pasteboard files dev added, re-gated CI: PASS, moved Head: lines. Both await the lane.
- 2026-10-21T20:10Z: #4019 and #4020 macOS build-only runs queued. SC-14 rebased onto SC-13 head 4e6f468, clean; scripts/ci --changed running.
- 2026-10-21T20:26Z: SC-14 ac167606 gated CI: PASS and pushed to lead/shared-codecs-SC-14; PR opens once #4019 merges.
- 2026-10-21T20:49Z: check-in: #4019 and #4020 macOS builds green, Fast-Check current; waiting on the lane sweep (run 39671360946 in progress). SC-14 gated, PR opens once #4019 merges.
- 2026-10-21T21:11Z: check-in: #4019 and #4020 still open, green macOS builds, no lane refusal; lane sweeps are being cancelled by newer ones. SC-14 still gated on #4019.
- 2026-10-21T21:33Z: check-in: #4019 is in lane batch 20261021205717; bisect probe -2 (ends at #4019) running, run 39679213310; the red is at probe -4 (#4163), after us. #4020 still waiting. SC-14 gated on #4019.
- 2026-10-21T21:56Z: #4019 (SC-13) still open: its lane probe lane/batch-20261021205717-2 (run 39679213310) went red on CommandPathTests/CommandPathLimitTests (library, launcher baselines). The cause is #3967 (LibraryBackupSheet baseline lines over #4023's limit), which sits ahead of #4019 in that probe. #4019 touches only Tests/SuiteModelTests, Tests/AfterGlowCLITests and the format-list baseline. Waiting for the bisect to name #3967. #4020 (SC-1) is still waiting. SC-14 is held until #4019 merges.
- 2026-10-21T22:18Z: #4019 (SC-13) merged as d2c129e51 and #4020 (SC-1) as d8b1b2109. SC-14 has dev merged in (it conflicted only on its own two test files, so SC-14's versions were kept) and scripts/ci --changed is running; its PR (slice SC-f) opens on CI: PASS. SC-2 waits on IM-a.
- 2026-10-21T22:26Z: SC-14 opened as PR #4238 (slice SC-f, fast-lane), head 5b6eba7365e00f49fcdb1b9effdd84f269ab64d1, scripts/ci --changed CI: PASS. SC-2 waits on IM-a (#4028 then IM-2).
- 2026-10-21T22:48Z: #4238 (SC-14): mergeable, no needs-fix; waiting on the lane's macOS build (run 39688920608). Removed a server-added footer from the body so Head: is the last line again.
- 2026-10-21T23:12Z: SC-14 #4238 (SC-f) waits on lane macOS build 39688920608 (queued since 22:46Z); no needs-fix, no refusal.
- 2026-10-21T23:35Z: SC-14 #4238 macOS build 39688920608 failed: dev's RenderBudgetPhotoPlaceTests uses PhotoPlaceIntent.files, removed by #4164 (not this PR's). Ported fix #4215 as 7b9039c0; re-gating before push.
- 2026-10-21T23:39Z: SC-14 #4238 pushed 7b9039c0 (CI: PASS; ports #4215's fix for dev's RenderBudgetPhotoPlaceTests break); Head line moved; waits on the lane's new macOS build.
- 2026-10-22T00:00Z: SC-14 #4238 head 7b9039c0 waits on lane macOS build 39695868336 (queued). #4215 merged on dev, so the port now equals dev.
- 2026-10-22T00:22Z: SC-14 #4238 (SC-f) waits on lane macOS build 39695868336, still queued since 23:49Z (runner backlog); mergeable, no needs-fix.
- 2026-10-22T00:44Z: SC-14 #4238 still waits on lane macOS build 39695868336, queued since 23:49Z; no needs-fix or refusal.
- 2026-10-22T00:55Z: dev is red on our ratchet: FormatListRatchetTests.realTreePasses flags Media.swift's StillFormat (SM-1 #4034 landed alongside SC-13 #4019). Shell-media's #4258 fixes it. A trial merge of dev, #4238 and #4258 merges cleanly and passes all 41 tests in the format, plist and media suites, so #4238 stays as it is.
- 2026-10-22T01:06Z: SC-14 #4238: lane macOS build 39695868336 has been running since 01:01Z. #4258 (dev's ratchet fix) is still open.
- 2026-10-22T01:28Z: Build 39695868336 passed on 7b9039c. At 00:56Z the supervisor merged #4270 (StillFormat from SuiteImageFormats) into SC-14, giving head b60d61fd; landing #4238 turns dev's ratchet green. The lane's new macOS build 39704535700 is queued. I'm re-gating b60d61fd so the Head: line can move to it.
- 2026-10-22T01:35Z: SC-14 #4238 head b60d61fd (dev merge + supervisor's #4270) re-gated: CI PASS; Head: line moved; lane macOS build 39704535700 queued.
- 2026-10-22T01:50Z: SC-14 #4238: lane macOS build 39704535700 green on b60d61fd; Fast-Check/Head current; waits for the lane's merge sweep.
- 2026-10-22T02:10Z: SC-14 #4238 eligible (green macOS build, current Head:, no needs-fix/refusal); lane sweeps are active on dev (#4243 merged 02:07Z). Other SC slices are blocked: SC-2 on IM-a, SC-photo on export-pack, SC-library on library spine, SC-z on AK-z.
- 2026-10-22T02:30Z: SC-14 #4238 merged as 6603b0f1d, so every SC-f task is merged (SC-13 #4019, SC-14 #4238). Merged-done waits on dev Linux check 39710840412 (b5a6e7e0, in progress); then Belt-Slice-Done SC-f on #3718. Scoped run 'suite' 39710836943 is queued on the same sha.
- 2026-10-22T02:43Z: SC-f is merged-done. The Linux job of dev run 39710840412 (b5a6e7e0a) is green, and Belt-Slice-Done SC-f is posted on #3718 (comment 6331405875). Its critic panel will review the screens of scoped suite run 39710836943 once that run finishes. Still waiting: SC-2 on IM-a, SC-photo, SC-library, SC-z.
- 2026-10-22T03:04Z: SC-f's critic panel waits on scoped suite run 39710836943, queued since 02:20Z. I asked the supervisor about it in the same question on #3715. SC-2 waits on IM-a.
- 2026-10-22T03:24Z: Scoped suite run 39710836943 is still queued (since 02:20Z), so SC-f's critic panel is held. No supervisor reply yet.
- 2026-10-22T03:45Z: Unchanged. Scoped suite run 39710836943 is still queued, so SC-f's critic panel is held.
- 2026-10-22T04:06Z: Scoped suite run 39710836943 started at about 03:52Z and is in progress. SC-f's critic panel starts when its ui-screens are up.
- 2026-10-22T04:23Z: Scoped suite run 39710836943 completed green: macOS (suite) passed, 03:52-04:09Z. It uploaded no snapshots or ui-screens. It handed the journeys to journeys.yml run 39720835412, which is pending behind three earlier journey runs. SC-f's critic panel runs on those ui-screens.
- 2026-10-22T04:44Z: Journeys run 39720835412 (suite) is still pending in the macOS queue. SC-f's critic panel waits on its ui-screens.
- 2026-10-22T05:05Z: Journeys run 39720835412 (suite) is still queued for macOS. SC-f's critic panel waits on its ui-screens.
- 2026-10-22T05:25Z: Journeys run 39720835412 (suite) is still queued for macOS. SC-f's critic panel waits on its ui-screens.
- 2026-10-22T05:47Z: SC-f critic panel still waits on journeys run 39720835412 (queued since 04:10Z).
- 2026-10-23T14:52:29Z: run act-1a1693a3ff0-mwrd resumes. SC-f done; SC-1 #4020 merged. IM-a is done, so SC-2 starts: SuiteImageIO.swift already exists on dev from shell-media SM-6/SM-7, and SC-2 adds its stubs beside them. SuiteShell does not yet link CoreRaster.
- 2026-10-23T16:45Z: SC-2 #4873 (SC-a) open for the supervisor merge. SC-5+SC-6 #4875 (SC-halo) open with fast-lane, current Fast-Check/Head. SC-photo, SC-library, SC-raster, SC-z stay blocked (export-pack, library spine, SC-4, AK-z). Status now also pushed to lead/suiteui-shared-codecs (the branch Belt reads).
- 2026-10-23T19:41Z: scoped suiteui run 40005632479 completed success; posted Belt-Slice-Done: SC-a on #3718 (issuecomment-6373270722). SC-a is ui:false (Model walk), so no critic panel. #4875 (SC-halo) still open on the lane.
- 2026-10-23T18:55Z: SC-2 #4873 merged 18:35Z (2f94f450), so SC-a's tasks are all merged. Scoped suiteui run 40005632479 on dev 0d4645bf (contains 2f94f450) is queued; Belt-Slice-Done SC-a posts when it completes green. #4875 (SC-halo) open on the lane. Other slices still blocked.
- 2026-10-24T07:05Z: run act-1a16cae7989-hj12 resumes on dev 830af22d. Server-added footers removed from #4848, #4859, #4865, #4872 bodies so Head: is the last line again (#4828, #4861, #4875, #4876 already clean). Contract-first waits (rule 12) applied to the slice table.

## Run act-1a1702c569a-0puo decisions
- Integration branch: the brief says main, but the fast lane only merges into dev (main fast-forwards from green dev), so slice PRs base on and target dev, as earlier runs did.
- lead/<feature> was rebuilt on main ef37711d (its old history shares no base with the rewritten main): records copied onto main and force-pushed with lease.
- Contract-first waits (rule 12): every cross-feature wait is met, since each named feature's first slice has merged (checked by its owned files on dev).
- SC-11 waits only on SC-6 (merged in #4875) and AK-z (met contract-first, AK-a merged), so it ships now as its own PR.
