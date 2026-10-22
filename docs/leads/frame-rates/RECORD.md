# frame-rates lead record

Issue: #3754 · Packet: docs/blueprints/suiteui/features/frame-rates.md
Run: act-1a161a658a7-2jql · Session: session_01F3g9p2SjhinJcobKKf3Gn2 · Started: 2026-10-21T11:23Z
Stage: FR-flare merged, FR-z in progress
Base: dev
Next: FR-z after 4407: RJ-X74 turn-on, journey, FR-12 feature-done; critic round 2 for FR-u
























## Status now
Run act-1a161a658a7-2jql, status at 2026-10-22T07:00Z; this block supersedes the Task table's PR/state columns.
- 12:58Z: 4402 and 4408 (FR-flare) merged. 4407 (FR-halo) waits on its per-PR macOS build. FR-z started in wt-frz: FR-11 FrameRateHomeTests written and building; RJ-X74 turn-on, FJ-FR journey and FR-12 follow once 4407 lands.
- 12:25Z: heartbeat. Lane dispatched per-PR macOS builds for 4407 and 4408; 4402 waiting. Run 39765697963 still queued.
- 12:03Z: heartbeat. 4402 4407 4408 open and labelled, waiting for the lane. Run 39765697963 still queued.
- 11:58Z: opened #4407 (FR-8b, FR-halo, mutate 17 of 17), #4408 (FR-10b, FR-flare, mutate 13 of 13), #4402 (FR-flare wave list, docs). All gates PASS, fast-lane labelled.
- 11:50Z: #4293 (FR-10) and #4341 (FR-8) merged. FR-8b and FR-10b rebuilt on dev with only their own commits (squash-merged parents conflicted add-add). FR-8b: History merge resolved, anchors repointed, 14 files. FR-10b: gate PASS, 15 files (scene journey folded into FR-z, wave list to a docs PR). Mutate and gates running; both open next.
- 11:12Z: no change. #4293 (macOS build) and #4341 waiting in the lane, both clean; scoped suiteui run 39765697963 still queued (23 runs queued repo-wide).
- 10:49Z: #4373 and #4375 merged at 10:38Z (FR-u findings 4359-4369 closed, 0 FR findings open). Critic round 2 waits for scoped suiteui run 39765697963 at 5da8c3294 (queued). #4293 rebased head f87c2e98 in macOS build 397634319. #4341 in lane, clean.
- 10:25Z: #4293 needs-rebase resolved (golden list-commands merged by command id, clean), gate PASS + AfterGlowCLITests pass, pushed f87c2e98, Head moved. #4341/#4373/#4375 waiting in lane.
- 09:55Z: #4293's macOS build passed (09:12Z); it waits for the lane's batch. #4341/#4373/#4375 builds still queued (25 queued repo-wide). Nothing red.
- 09:33Z: no change: #4293, #4341, #4373, #4375 all wait on lane macOS builds; 27 runs queued repo-wide for macOS runners. Nothing red, nothing for the lead to build (FR-z held by findings, FR-10b/FR-8b by parents).
- 09:11Z: #4341 (FR-8) was needs-rebase on NewCompositionSheet.swift (dev's #4210 made Create a MenuCommand): merged origin/dev, kept both (MenuCommand Create hands draft.settings.withFrameRate(frameRate)), gate PASS, pushed d99ea37a, Head moved. #4293 still waits on the lane's macOS build; #4373/#4375 in the lane's macOS gate.
- 08:56Z: fix round 1 PRs open: #4373 (r-b2: #4362 #4366, head c516b940) and #4375 (r-b1: the other 9, head 24daa220). Moved r-b2's TimelineTime mutation entry into #4375 (array plans don't key-merge, so the pair would have conflicted). Both pass the gate; mutation plans can't be scored on Linux (SuiteUI), stated on the Mutate: line. Next: once both merge, critic round 2 on a scoped suiteui run.
- 08:42Z: #4293 and #4341 still open: their lane macOS builds are queued for a runner (#4293 since 06:35Z). FR-10b and FR-8b stay ready and open after their parents merge. FR-u fix round 1 (wf_c253f90f-05e) running.
- 08:27Z: FR-u critic panel (run 39726187078, e02f36c3): not clean, 11 findings #4359-#4369; fix round 1 launched via fix-batch.js on dev 2b31ba4c. FR-z held (findings > 5). #4293 and #4341 in the lane's macOS gate.
- 08:21Z: journeys run 39726187078 green; FR-u critic panel running (workflow wf_c10e4cde-7ad) over suiteui-timeline-2997-menu and suite-gallery-timeline-2997 at e02f36c3. #4293 and #4341 still wait on the lane's macOS gate.
- 08:07Z: FR-10b gate PASS at 7d5b638c, mutate 7/7 FlareModel.FlareCommandCatalog; PR opens once #4293 merges.
- 07:59Z: FR-10b merge with dev surfaced a semantic conflict (dev's file.new command passed Int fps to the now-FrameRate spec); fixed, anchor repointed, gate rerunning. AN and CB parked per supervisor; frame-rates continues.
- 07:56Z: FR-10b branch merged with FR-10 head (d1c5cb529), pushed, gate running; PR opens after #4293 merges (stacked diff vs dev is 19 files).
- 07:56Z: FR-10b branch merged with FR-10 head (d1c5cb529), pushed, gate running; PR opens after #4293 merges (stacked diff vs dev is 19 files).
- FR-a #4063 merged · FR-m #4142 merged · FR-u #4172 merged · FR-7 #4211 merged (disabled) · FR-9 #4212 merged (disabled)
- FR-10 #4293 open at d1c5cb529 (dev merged in after the CLI golden conflict); the lane's macOS build is in flight
- FR-8 #4341 open, fast-lane, head e5d562c5 (gate PASS on dev 1da00fb9, mutate 4/4); catalog command, movie writer timing, rate text and HJ-FR journey are the FR-8b follow-up
- FR-10b (Flare UI half) stacked on lead/frame-rates-FR-flare-10b, PR after #4293 merges
- FR-z (FR-11, FR-12) waits FR-8 and FR-10b
- FR-8b closed #4345 (sentinel counted 580 lines / 23 files because it carried #4341's commits; its own diff is 13 files, +297/-20). Branch lead/frame-rates-FR-8b at 45dc8dee kept: once #4341 merges, merge dev in, gate, open a fresh PR (gate PASS, mutate 7/7 so far)
- Note: this session's GitHub writes append a "Generated by" footer to every PR body (#4306, #4308, #4341, #4345); a REST edit gets it re-added. The lane strips it from squash commits; removing it from the bodies needs a write from outside this session.

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| FR-a | The kernel declares FrameRate, the common list, Timecode and the two time.* specs as stubs, with their tests written and disabled. | FR-1, FR-2 | MJ-FR | editor-kernel, command-catalog (built, `depends`) | no | 0 | merged | – | – |
| FR-m | Rates are exact rationals, a duration in seconds becomes whole frames by one rounding rule, and timecode is drop-frame at 29.97 and 59.94 and round-trips at every rate. | FR-3, FR-4 | MJ-FR | FR-a | no | 0 | open | – | – |
| FR-u | SuiteUI's timeline readout shows timecode at the document's rate and its rate menu offers the one list, reachable from the gallery's timeline page on the fakes. | FR-5, FR-6 | SJ-FR | FR-a; shared files, after timeline-select-all:TSA-a (FR-5) | yes | 0 | held | – | – |
| FR-halo | A Halo composition can be 23.976, 29.97, 50 or 59.94 fps, its render times every frame by the exact rate, its readout shows drop-frame timecode, and every old file opens byte for byte. | FR-7, FR-8 | MJ-FR-halo, HJ-FR | FR-a (FR-7); FR-m and FR-u (FR-8); adopt-kernel-easing AE-halo and the Halo catalog chain (cross-line); shared files, after adopt-command-catalog:AC-z (FR-8), adopt-kernel-session:AD-halo (FR-8) | yes | 0 | planned | – | – |
| FR-flare | A Flare scene can be 23.976, 29.97, 50 or 59.94 fps on the stage, in the inspector and in the Lottie it writes, and every old file opens unchanged. | FR-9, FR-10 | MJ-FR-flare, FJ-FR | FR-a (FR-9); FR-m and FR-u (FR-10); the creative-core rate bump, adopt-kernel-easing AE-flare and the Flare catalog chain (cross-line); shared files, after adopt-command-catalog:AC-z (FR-10) | yes | 0 | planned | – | – |
| FR-z | A test holds that no app keeps its own rate list, RJ-X74 passes, and the feature is built. | FR-11, FR-12 | MJ-FR, HJ-FR, FJ-FR | FR-halo, FR-flare | no | 0 | planned | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| FR-1 | FR-a | 1 | Contract as stubs. `FrameRate` (numerator, denominator, `common`, legacy `Int` and `Double` decode), `Timecode` (format, parse, drop-frame), `TimeCommands` s... | `Sources/SuiteKernel/Keys/FrameRate.swift`, `Sources/SuiteKernel/Keys/Timecode.swift`, `Sources/SuiteKernel/Keys/TimeCommands.swift` | the kernel builds; `CommandShapeTests` with `time.rates` and `time.timecode` | #4063 | pr-open |
| FR-2 | FR-a | 2 | `FrameRateTests` and `TimecodeTests` written, disabled (`waits on FR-3`); the kernel's C4 part names the two files | `Tests/SuiteKernelTests/FrameRateTests.swift`, `Tests/SuiteKernelTests/TimecodeTests.swift`, `docs/c4/parts/creative-apps/suite-kernel/kernel-keys.json` | compile, disabled | #4063 | pr-open |
| FR-3 | FR-m | 3 | `FrameRate` and `Timecode` bodies; `TimeCommands` run; turns on both suites | `Sources/SuiteKernel/Keys/FrameRate.swift`, `Sources/SuiteKernel/Keys/Timecode.swift`, `Sources/SuiteKernel/Keys/TimeCommands.swift`, `Tests/SuiteKernelTests/FrameRateTests.swift`, `Tests/SuiteKernelTests/TimecodeTests.swift`, `Tests/mutations/SuiteKernel.Timecode.json`, `Tests/mutations/SuiteKernel.FrameRate.json` | `TimecodeTests`: frame 1800 at 29.97 DF reads `00:01:00;02`, frame 17982 reads `00:10:00;00`, and every frame 0...107892 parses back to itself; 25 fps frame 90000 reads `01:00:00:00`; `FrameRateTests`: 10 s at 29.97 is 300 frames, 1 s at 23.976 is 24, `Int 30` decodes to 30/1, `29.97` decodes to 30000/1001 | – | building |
| FR-4 | FR-m | 4 | A golden list of 30 frame-to-timecode pairs per rate as a fixture, so a later edit can't drift | `Tests/SuiteKernelTests/Fixtures/timecode-golden.json` | `TimecodeTests.golden` reads it | – | building |
| FR-5 | FR-u | 3 | Reachable first: the gallery timeline page gets a rate menu over `FrameRate.common`; `TimelineTime` formats through `Timecode` (frames, seconds or timecode, ... | `Sources/SuiteUI/FrameRateMenu.swift`, `Sources/SuiteUI/TimelineTime.swift`, `Sources/SuiteUI/Gallery/GalleryTimeline.swift`, `Tests/SuiteUITests/FrameRateMenuTests.swift` | `FrameRateMenuTests`: nine items in order, 29.97 titled "29.97 fps", the checked item follows the bound rate; the readout at 29.97 reads `00:00:01;00` at frame 30 | – | planned |
| FR-6 | FR-u | 4 | The journey and the render budget row | `UITests/SuiteJourneyTests+Timeline.swift`, `Tests/AppSnapshotTests/RenderBudgetSuiteTimelineRateTests.swift` | `SuiteJourneyTests.testTimecodeAtNTSCRates`; `RenderBudgetSuiteTimelineRateTests.scrubAt2997` | – | planned |
| FR-7 | FR-halo | 3 | Halo, test first. `HaloFrameRateTests`, disabled: an old `fps: 30` file opens and re-saves byte for byte; a 29.97 composition renders frame 300 at 10.01 s; R... | `Tests/HaloModelTests/HaloFrameRateTests.swift`, `Tests/HaloModelTests/Fixtures/comp-30fps.halo`, `Tests/RealJobs/halo/ntsc-lower-third/ntsc-lower-third.jobs.json` | compile, disabled; `scripts/jobs check` | – | planned |
| FR-8 | FR-halo | 5 | `HaloFrameRate+Kernel.swift`; `CompositionSettings.frameRate: FrameRate` (`framesPerSecond` kept as a computed whole rate for old callers) and its `frameRate... | `Sources/HaloModel/HaloFrameRate+Kernel.swift`, `Sources/HaloModel/CompositionSettings.swift`, `Sources/HaloModel/Live/HaloFileValidation.swift`, `Sources/HaloModel/HaloPlayback.swift`, `Sources/HaloModel/HaloTimelineReadout.swift`, `Sources/HaloApp/NewCompositionSheet.swift`, `Tests/HaloModelTests/HaloFrameRateTests.swift`, `Tests/mutations/HaloModel.HaloFrameRate+Kernel.json`, `Sources/HaloModel/HaloCommandCatalog.swift`, `Tests/command-ids/halo.txt`, `Tests/AfterGlowCLITests/Golden/apps/halo.list-commands.json` | `HaloFrameRateTests`; `HaloTimelineJourneyTests.testCompositionAt2997` | – | planned |
| FR-9 | FR-flare | 3 | Flare, test first. `FlareFrameRateTests`, disabled: an old `fps: 24` file opens unchanged; a 23.976 scene exports Lottie `fr: 23.976` with `op` frames matchi... | `Tests/FlareModelTests/FlareFrameRateTests.swift` | compiles, disabled | – | planned |
| FR-10 | FR-flare | 5 | `FlareFrameRate+Kernel.swift` over the bumped core's rational rate; the scene inspector and New Animation pickers read `FrameRateMenu`; `NewDocumentSpec.fps`... | `Sources/FlareModel/FlareFrameRate+Kernel.swift`, `Sources/FlareModel/FlareNewDocument.swift`, `Sources/FlareApp/FlareInspectorScene.swift`, `Sources/FlareApp/FlareNewSheet.swift`, `Tests/FlareModelTests/FlareFrameRateTests.swift`, `Tests/mutations/FlareModel.FlareFrameRate+Kernel.json`, `Sources/FlareModel/FlareCommandCatalog.swift`, `Tests/command-ids/flare.txt`, `Tests/AfterGlowCLITests/Golden/apps/flare.list-commands.json` | `FlareFrameRateTests`; `FlareSceneInspectorJourneys.testSceneAt2398` | – | planned |
| FR-11 | FR-z | 6 | One list, held. `FrameRateHomeTests` fails on any frame-rate list literal under `Sources/*Model` or `Sources/*App` (the two app lists left with FR-8 and FR-10) | `Tests/SuiteKernelTests/FrameRateHomeTests.swift` | `FrameRateHomeTests`: no `frameRates` literal under `Sources/*Model` | – | planned |
| FR-12 | FR-z | 7 | `status: built`; `feature-done` | `docs/blueprints/suiteui/features/frame-rates.wave.json` | `scripts/waves check`; `scripts/jobs check` | – | planned |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- Base is origin/dev, PRs target dev: the brief names main as the integration branch, but CLAUDE.md and lead.md say never branch from or target main (the lane retargets main PRs to dev).
- One combined wave plan across anchor-parenting, frame-rates and clipboard-interop (rule 19); one PR per slice (rule 22), test commit first.
- Wave 1 is the three contract slices FR-a, AN-a, CB-a: kernel/model stubs plus disabled tests, disjoint files.
- Status channel is lead/suiteui-<feature> with docs/leads/suiteui-<feature>/ (the names Belt reads); the earlier lead/<feature> branches are superseded.
- Slice branches are named lead/<feature>-<slice> because lead/<feature> blocks lead/<feature>/<slice>.
- FR-a: TimeCommands.specs is a generic static func like the other kernel command sets, since CommandSpec is generic.
- Wave 2 slices (FR-m) build stacked on their wave-1 slice branch and push without a PR; the lead opens each PR once its parent has merged, so the stacked PR never carries the parent's diff past the size cap.

## Open
- FR-halo on adopt-command-catalog:AC-z and adopt-kernel-session:AD-halo; FR-flare on AC-z and a creative-core rational-rate bump. Rechecked before each starts.
- dev-red #3856 fixed on dev by #4008; wave-1 slices merged dev and re-gated.
- timeline-select-all is built, so FR-u can start once a builder slot frees.
- FR-m: dev #4050 moved both Library timing tests into perf-suites; merged dev and re-gating serially (serialgate.sh).

