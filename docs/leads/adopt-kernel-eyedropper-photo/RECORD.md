# adopt-kernel-eyedropper-photo lead record

Issue: #3723 · Packet: docs/blueprints/suiteui/features/adopt-kernel-eyedropper-photo.md
Run: act-1a16953ae34-05a4 (relaunch) · Started: 2026-10-23T15:30Z
Stage: 3 wave 1 (EP-m: EP-2)
Base: 721168a8f (origin/dev; brief main cb79cbb6 verified)
Next: EP-2 builder on lead/adopt-kernel-eyedropper-photo-EP-m (off dev); then EP-z (EP-3 + EP-4) stacked on it, built ahead of UP-z under contract-first waits.

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| EP-m | click and `color.sample` both read `SampleRules.mean` through Photo's kernel adapter; Photo's ColorSampling, SampledColor and FakeSampling gone | EP-1, EP-2 | MJ-EP | photo/eyedropper:PE-z (packet), adopt-kernel-export:AX-photo (EP-2), adopt-kernel-brush:AB-photo (EP-2) | false | 0 | building | – | – |
| EP-z | PhotoEyedropper.swift and LiveSampling.swift deleted, baseline shrunk, built | EP-3, EP-4 | MJ-EP, PJ-EP | EP-m, adopt-kernel-unsaved-prompt:UP-z (EP-3) | false | 0 | blocked | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| EP-1 | EP-m | 1 | PhotoSampleKernelTests (disabled), RJ-X49 job folder (mutation plan already on dev from PE-a) | Tests/PhotoModelTests/PhotoSampleKernelTests.swift, Tests/RealJobs/photo/sample-edge/*, Tests/mutations/PhotoModel.PhotoSample+Kernel.json | PhotoSampleKernelTests | #4579 | merged |
| EP-2 | EP-m | 2 | sampleDrag on SampleRules.mean; ColorSampling, SampledColor, FakeSampling, PhotoServices.sampling removed | Sources/PhotoModel/PhotoSample+Kernel.swift, Contracts/OutputContracts.swift, Fakes/FakeOutput.swift, PhotoServices.swift, PhotoStroke.swift, Tests/PhotoModelTests/PhotoSample*Tests.swift | PhotoSampleKernelTests | – | building |
| EP-3 | EP-z | 3 | delete PhotoEyedropper.swift, LiveSampling.swift and their tests and plan; shrink canonical baseline | Sources/PhotoModel/PhotoEyedropper.swift, Live/LiveSampling.swift, Live/NotBuilt.swift, Tests/PhotoModelTests/LiveSamplingTests.swift, Tests/mutations/PhotoModel.LiveSampling.json, Tests/canonical-baseline.txt | scripts/check-dup-logic | – | #4943 open (stacked on #4837; Wire UP-z) |
| EP-4 | EP-z | 4 | status built, feature-done | docs/blueprints/suiteui/features/adopt-kernel-eyedropper-photo.wave.json | waves render --dry-run | – | blocked on EP-3 |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- 2026-10-23T15:30Z Relaunch act-1a16953ae34-05a4. AB-photo is done (Belt-Slice-Done 2026-10-19, #3030) and AX-photo merged (#3890), so EP-2's waits are met with real code. EP-3's UP-z wait (file order on canonical-baseline.txt) is met under contract-first waits (lead.md rule 12, #4814; supervisor on #3723 15:12Z): UP-a is done, so EP-z builds ahead with a Wire line.
- 2026-10-22T16:45Z Relaunch under act-1a1647a67aa-dau5. photo/eyedropper is built (PE-z done), so EP-1's signatures are final and it starts now.
- 2026-10-22T16:45Z AB-photo still building (#3011 AB-p1 open, AB-p2 not started); UP-z blocked on UP-photo/shared-codecs. After 3 identical blocked polls past EP-1, ask the supervisor.
- 2026-10-21 relaunch (act-1a15e10a9c3-kwzx): no EP-1 branch or PR exists from the released run; EP-1 waits PE-6 so its disabled tests target final signatures, not PE-a stubs that PE-m may still change. Work continues on #3718/#3715 (line lead, rule 19).
- PRs target `dev`, not `main` as the brief's integration branch says: CLAUDE.md and the lane only take crew PRs on dev (a PR to main is retargeted). Brief main b3011ab9 is an ancestor of dev.
- EP-1 is held for photo/eyedropper PE-z even though the `.wave.json` lists no wait for EP-m beyond EP-2's. The packet makes EP-1 depend on PE-z, and its tests call photo/eyedropper's `PhotoSample+Kernel.swift` (`extension PhotoWorkspace: SampleTarget`) and Photo's `color.sample`. Neither is on dev 74844410, so a test written now would not compile.
- #3722 is a duplicate of this feature issue, labelled `needs-human`; it is left to the supervisor.
- `gh` has no token in this session, so issues and comments go through the GitHub MCP tools.

## Wire
- [ ] Wire: adopt-kernel-unsaved-prompt:UP-z (EP-3 built ahead; when UP-z merges, re-run scripts/check-dup-logic --update-baseline on the merged dev so canonical-baseline.txt holds both changes)

## Open
- photo/eyedropper (#3439) is at PE-a (#3706 open); PE-u, PE-m and PE-z have not started.
- adopt-kernel-export AX-photo is blocked on adopt-kernel-layers AL-photo (#1939 is `needs-human`).
- adopt-kernel-brush AB-photo is in wave B (#3011, AB-p1).
- adopt-kernel-unsaved-prompt UP-z (#3720/#3721) has not started.
- 2026-10-21T00:05Z poll 3: PE-a merged (#3706, 9749f9d1; Belt-Slice-Done: PE-a on #3439, run 39514893774). PhotoSample+Kernel.swift (SampleTarget stubs) and `color.sample` are on dev 0c2c10dd, which is the alternate condition in Next. EP-1 is disabled tests that only need that API to compile, so it starts now. EP-2 still waits for PE-z, because PE-6 writes the bodies EP-2 rewires.
- 2026-10-21T19:24Z poll 2 (run act-1a15fe5ef7c-rszn): unchanged. #3439 has Belt-Slice-Done for PE-a and PE-u only; PE-m waits history-panel:PH-m (prereq-priority comment 11:29Z), so PE-z is not near. AX-photo (#3890) merged; AB-photo and UP-z unchanged. EP-1 stays held.
- 2026-10-21T20:09Z poll 3: unchanged (PE-m waits PH-m, PE-z not started; AB-photo, UP-z unchanged). Third identical blocked poll: Question for the supervisor posted on #3723 (issuecomment-6325467452). Status channel now also lead/suiteui-adopt-kernel-eyedropper-photo.
- 2026-10-21T20:48Z: released by the supervisor (every slice waits on PE-z, AB-photo, UP-z). No branch or PR was opened in this run.
- 2026-10-22T00:22Z: Released by the supervisor; no further work in this run.
- 2026-10-23T15:20:44Z: EP-m builder started (EP-2) on lead/adopt-kernel-eyedropper-photo-EP-m; toolchain 6.3.3 ready
- 2026-10-23T17:32Z: wave 2: EP-m is #4837 (fast-lane, queued). EP-z builder started, stacked on EP-m.
- 2026-10-23T17:53Z: EP-z opened as #4943 (head 5457514, stacked on #4837, fast-lane + feature-done, CI: PASS, own commits 10 files +9/-107). The UP-z Wire line stays open. Stripped a tool-appended attribution footer from #4943 and from the #4840 comment.
- 2026-10-23T19:58:03Z: check: #4837 EP-m fast-lane queued (no checks/comments yet, lane backlog); #4943 waits (stacked size).
- 2026-10-23T20:20:47Z: heartbeat: #4837 EP-m fast-lane at 5d5b637, no checks yet (lane backlog); #4943 EP-z waits on EP-m
- 2026-10-23T20:42:27Z: heartbeat: #4837 EP-m still queued in lane, no checks/status on 5d5b637; #4943 EP-z waits on EP-m
- 2026-10-23T21:04:34Z: heartbeat: #4837 EP-m still queued, no checks on 5d5b637; dev idle 70 min (lane quiet); #4943 waits on EP-m
- 2026-10-23T21:26:16Z: heartbeat: #4837 EP-m no checks on 5d5b637; dev idle since 19:45Z; #4943 waits on EP-m
- 2026-10-23T21:50:28Z: dev batch at 21:40Z merged 12 PRs (#4841-#4862) and skipped #4837 (EP-m). The cause is the lane's open_list --limit 100: 144 PRs are open and #4837 was past the cutoff. Raised with the supervisor on #4837. #4840 (ST-a) is still waiting on the Mac re-gate. #4950/#4951 are drafts, #4943 waits on EP-m.
- 2026-10-23T22:13:39Z: No dev merges since 21:40Z. #4840 (ST-a) still waits on the supervisor's Mac re-gate. #4837 (EP-m) is 97th of the newest open PRs, just inside the lane's 100-PR window. Supervisor not yet answered. #4943/#4950/#4951 unchanged.
- 2026-10-23T22:34:57Z: Still no dev merges since 21:40Z. #4840 has no status on its head and is still waiting on the supervisor's Mac re-gate. #4837 is now 99th newest, so it is still inside the lane's window. No supervisor reply. Stacked slices unchanged.
- 2026-10-23T22:57:33Z: Dev only gained the generated-docs commit; no lane batch since 21:40Z. #4840 still has no status and is waiting on the supervisor. #4837 is 99th newest, still inside the lane's window. No supervisor reply. Stacked slices unchanged.
- 2026-10-23T23:19:03Z: #4837 (EP-m) is in lane/batch-20261023215139, a batch of 12 with #4818-#4870. Its Linux check passed and the macOS gate run 40029779505 is still in progress after 1.5h. I updated the supervisor note on #4837. #4840 (ST-a) still has no status and is waiting on the supervisor's Mac re-gate. A full CI run on dev 654fb36 is in progress.
- 2026-10-23T23:41:43Z: heartbeat: batch-20261023215139 macOS gate 40029779505 still in progress (~1h50m); #4837 EP-m waits in it; #4840 ST-a still needs-fix/no-fast-lane awaiting supervisor Mac re-gate; #4943/#4950/#4951 wait on parents
- 2026-10-24T00:04:08Z: check: batch-20261023215139 macOS gate 40029779505 FAILED 23:44Z on Design stroke tests (RenderBudgetDesignStrokeTests.widthScrubInThreeBodies, DesignStrokeSnapshots.editor: selectedStroke nil); not EP-m's Photo-only diff; lane bisect pending, #4837 not labelled needs-fix. #4840 ST-a unchanged (needs-fix/no-fast-lane, no status, supervisor re-gate).
- 2026-10-24T00:26:32Z: check: lane bisecting batch-20261023215139 (probe -6 = first 6 PRs, before #4837); #4837 open, no needs-fix; #4840 ST-a unchanged awaiting supervisor re-gate
- 2026-10-24T00:48:38Z: check: bisect still on probe batch-20261023215139-6 (macOS gate on first 6 PRs); #4837 open, no needs-fix; #4840 ST-a unchanged awaiting supervisor re-gate
