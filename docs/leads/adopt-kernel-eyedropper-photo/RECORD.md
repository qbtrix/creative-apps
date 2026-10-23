# adopt-kernel-eyedropper-photo lead record

Issue: #3723 · Packet: docs/blueprints/suiteui/features/adopt-kernel-eyedropper-photo.md
Run: act-1a1647a67aa-dau5 (relaunch) · Started: 2026-10-22T16:45Z
Stage: 3 wave 1 (EP-m)
Base: 11919406886e89e9e02adea13b113b66e852334d (origin/dev)
Next: EP-1 (disabled PhotoSampleKernelTests + RJ-X49) PR to dev now; EP-2 waits adopt-kernel-brush AB-photo (#3011 open); EP-3 waits UP-z (released, waiting-on-prereq).

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| EP-m | click and `color.sample` both read `SampleRules.mean` through Photo's kernel adapter; Photo's ColorSampling, SampledColor and FakeSampling gone | EP-1, EP-2 | MJ-EP | photo/eyedropper:PE-z (packet), adopt-kernel-export:AX-photo (EP-2), adopt-kernel-brush:AB-photo (EP-2) | false | 0 | blocked | – | – |
| EP-z | PhotoEyedropper.swift and LiveSampling.swift deleted, baseline shrunk, built | EP-3, EP-4 | MJ-EP, PJ-EP | EP-m, adopt-kernel-unsaved-prompt:UP-z (EP-3) | false | 0 | blocked | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| EP-1 | EP-m | 1 | PhotoSampleKernelTests (disabled), RJ-X49 job folder (mutation plan already on dev from PE-a) | Tests/PhotoModelTests/PhotoSampleKernelTests.swift, Tests/RealJobs/photo/sample-edge/*, Tests/mutations/PhotoModel.PhotoSample+Kernel.json | PhotoSampleKernelTests | – | building |
| EP-2 | EP-m | 2 | sampleDrag on SampleRules.mean; ColorSampling, SampledColor, FakeSampling, PhotoServices.sampling removed | Sources/PhotoModel/PhotoSample+Kernel.swift, Contracts/OutputContracts.swift, Fakes/FakeOutput.swift, PhotoServices.swift, PhotoStroke.swift, Tests/PhotoModelTests/PhotoSample*Tests.swift | PhotoSampleKernelTests | – | blocked on EP-1, AX-photo, AB-photo |
| EP-3 | EP-z | 3 | delete PhotoEyedropper.swift, LiveSampling.swift and their tests and plan; shrink canonical baseline | Sources/PhotoModel/PhotoEyedropper.swift, Live/LiveSampling.swift, Live/NotBuilt.swift, Tests/PhotoModelTests/LiveSamplingTests.swift, Tests/mutations/PhotoModel.LiveSampling.json, Tests/canonical-baseline.txt | scripts/check-dup-logic | – | blocked on EP-2, UP-z |
| EP-4 | EP-z | 4 | status built, feature-done | docs/blueprints/suiteui/features/adopt-kernel-eyedropper-photo.wave.json | waves render --dry-run | – | blocked on EP-3 |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- 2026-10-22T16:45Z Relaunch under act-1a1647a67aa-dau5. photo/eyedropper is built (PE-z done), so EP-1's signatures are final and it starts now.
- 2026-10-22T16:45Z AB-photo still building (#3011 AB-p1 open, AB-p2 not started); UP-z blocked on UP-photo/shared-codecs. After 3 identical blocked polls past EP-1, ask the supervisor.
- 2026-10-21 relaunch (act-1a15e10a9c3-kwzx): no EP-1 branch or PR exists from the released run; EP-1 waits PE-6 so its disabled tests target final signatures, not PE-a stubs that PE-m may still change. Work continues on #3718/#3715 (line lead, rule 19).
- PRs target `dev`, not `main` as the brief's integration branch says: CLAUDE.md and the lane only take crew PRs on dev (a PR to main is retargeted). Brief main b3011ab9 is an ancestor of dev.
- EP-1 is held for photo/eyedropper PE-z even though the `.wave.json` lists no wait for EP-m beyond EP-2's. The packet makes EP-1 depend on PE-z, and its tests call photo/eyedropper's `PhotoSample+Kernel.swift` (`extension PhotoWorkspace: SampleTarget`) and Photo's `color.sample`. Neither is on dev 74844410, so a test written now would not compile.
- #3722 is a duplicate of this feature issue, labelled `needs-human`; it is left to the supervisor.
- `gh` has no token in this session, so issues and comments go through the GitHub MCP tools.

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
