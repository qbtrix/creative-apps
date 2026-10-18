# adopt-kernel-brush lead record

Issue: #1941 · Packet: docs/blueprints/suiteui/features/adopt-kernel-brush.md
Run: act-1a1509b245f-653k (line lead with #1933, #1941, #1940)
Stage: 3 wave B
Base: b1526f3e (origin/dev); lead branch rebased on main 71facd44
Next: #3011 (AB-p1) waits on the lane's macOS build; then AB-p2 (feature-done): app-side routing (LiveStroke → LiveCopy needs #3012 item 1 or another hand-off; presets in the options view) plus the delete

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| AB-photo | Photo's brush, eraser, clone and heal sample through StrokeSmoother and DabSpacer, options in BrushSettings, LiveCopy<PhotoWorkspace> through SuiteUI's StrokePacer, PointerPressure and BrushCursorMark; the Photo copies deleted | AB-p1, AB-p2 | MJ-AB-photo (PhotoBrushTests on Linux; Photo's journeys on the scoped run) | editor-kernel:EK-stroke (AB-p1), editor-kernel:EK-chrome (AB-p2); hand-offs photo-seams and photo-edit on PhotoStroke.swift, PhotoRetouch.swift, PhotoWindow.swift | true | 0 | building | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| AB-p1 | AB-photo | 1 | Photo adapter: PhotoStroke.Sample is StrokeSample, curve and the 4-sample window route to StrokeSmoother, dabCenters to DabSpacer, ToolOptions to BrushSettings (ToolOptionEdit → BrushEdit; BrushPreset list behind the options view), LiveStroke to LiveCopy<PhotoWorkspace>; capsule, falloff and max-coverage blend stay behind `paint`; files the needs-core issue for a CoreRaster stamp op; existing tests unchanged; plan PhotoModel.KernelBrushAdapter | Sources/PhotoModel/PhotoStroke.swift, PhotoRetouch.swift, ToolOptions.swift, Sources/PhotoApp/LiveStroke.swift, StrokePacer.swift, PointerPressure.swift, BrushCursorOverlay.swift, PhotoToolOptions.swift, PhotoWindow.swift, Tests/PhotoModelTests/PhotoBrushTests.swift, PhotoLiveStrokeTests.swift, PhotoDragBatchTests.swift, PhotoBrushArcTests.swift, PhotoRetouchDabTests.swift, Tests/AppSnapshotTests/PhotoStrokePacerTests.swift, PhotoWindowStrokeTests.swift, Tests/mutations/PhotoModel.KernelBrushAdapter.json | the seven existing suites unchanged + `scripts/mutate --plan PhotoModel.KernelBrushAdapter` (drops endRun forward; maps refusal to success) | #3011 | open (lane mac build) |
| AB-p2 | AB-photo | 2 | Photo delete: the sampling, curve and dab code and the four app files go; plans repointed; C4 part updated; feature-done | the same Photo files, Tests/mutations/PhotoModel.PhotoStroke.json | the same suites, `scripts/mutate --validate`, `grep -rn <symbol> Sources` empty | – | waits AB-p1 |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- Checked 2026-10-17T06:20Z: #1933 (editor-kernel) has no comments, no `lead/editor-kernel` branch exists, and no kernel type (StrokeSmoother, DabSpacer, BrushSettings, BrushPreset, LiveCopy) or SuiteUI StrokePacer/PointerPressure/BrushCursorMark exists on dev. Both waits are unmet; commented on #1941.
- The packet's AB-p1 owns 17 files (the cap is 15): when it starts, the test files it doesn't edit come off its list (the acceptance says the app's tests pass unchanged), which also keeps the "zero test edits" quality row honest.
- Base is `dev` for PRs (CLAUDE.md, fast-lane.sh); this status branch sits on main as Belt asked.
- 2026-10-18 relaunch act-1a14f91ff8b-nq4v: EK-stroke and EK-chrome are done (Belt; StrokePacer, PointerPressure, BrushCursorMark merged in #2744), so both waits are met.

- 2026-10-18 relaunch act-1a1509b245f-653k: the previous run's AB-p1 builder never opened a PR. AB-p1 rebuilds from dev b1526f3e. Its 17 packet files exceed the 15-file cap: it edits only the ones the adapter needs (the unchanged test files stay out of the diff).

## Open
- AB-p2 waits AB-p1.
- 2026-10-18 AB-p1 #3011 is the Model half (7 files, +251/-93, Mutate 7/7): Sample = StrokeSample, smoother, DabSpacer, BrushSettings, presets. App routing moves to AB-p2. Kernel gaps filed as #3012 (gap, line:suiteui). needs-core CoreRaster stamp op not filed (creative-core 403); draft in #3011's body.
- 2026-10-18T21:38:11Z check: dev 8640f00f; #3011 AB-p1 waits on lane; 0 findings
- 2026-10-18T22:16:45Z check: #3011 AB-p1 merged dev for #2990 fix, gate PASS, head 5095cc93
- 22:36Z dev 349578b8; #2973/#2979/#3010/#3011 wait on lane mac builds of their new heads; 0 findings
- 22:56Z #3011 AB-p1 merged; AB-p2 builder started
