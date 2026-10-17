# adopt-kernel-brush lead record

Issue: #1941 · Packet: docs/blueprints/suiteui/features/adopt-kernel-brush.md
Run: act-1a1487bf89a-zfq8 (line lead with #1079, #1480) · Session: claude/suiteui-feature-lead-t357v5 · Started: 2026-10-17T06:10Z
Stage: 0 setup
Base: fe0f5f176a95336c77a1d0cff7162e584db1d24c
Next: at every check, re-read #1933 for `Belt-Slice-Done: EK-stroke` (then AB-p1 may start) and `EK-chrome` (AB-p2); nothing can start before

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| AB-photo | Photo's brush, eraser, clone and heal sample through StrokeSmoother and DabSpacer, options in BrushSettings, LiveCopy<PhotoWorkspace> through SuiteUI's StrokePacer, PointerPressure and BrushCursorMark; the Photo copies deleted | AB-p1, AB-p2 | MJ-AB-photo (PhotoBrushTests on Linux; Photo's journeys on the scoped run) | editor-kernel:EK-stroke (AB-p1), editor-kernel:EK-chrome (AB-p2); hand-offs photo-seams and photo-edit on PhotoStroke.swift, PhotoRetouch.swift, PhotoWindow.swift | true | 0 | blocked | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| AB-p1 | AB-photo | 1 | Photo adapter: PhotoStroke.Sample is StrokeSample, curve and the 4-sample window route to StrokeSmoother, dabCenters to DabSpacer, ToolOptions to BrushSettings (ToolOptionEdit → BrushEdit; BrushPreset list behind the options view), LiveStroke to LiveCopy<PhotoWorkspace>; capsule, falloff and max-coverage blend stay behind `paint`; files the needs-core issue for a CoreRaster stamp op; existing tests unchanged; plan PhotoModel.KernelBrushAdapter | Sources/PhotoModel/PhotoStroke.swift, PhotoRetouch.swift, ToolOptions.swift, Sources/PhotoApp/LiveStroke.swift, StrokePacer.swift, PointerPressure.swift, BrushCursorOverlay.swift, PhotoToolOptions.swift, PhotoWindow.swift, Tests/PhotoModelTests/PhotoBrushTests.swift, PhotoLiveStrokeTests.swift, PhotoDragBatchTests.swift, PhotoBrushArcTests.swift, PhotoRetouchDabTests.swift, Tests/AppSnapshotTests/PhotoStrokePacerTests.swift, PhotoWindowStrokeTests.swift, Tests/mutations/PhotoModel.KernelBrushAdapter.json | the seven existing suites unchanged + `scripts/mutate --plan PhotoModel.KernelBrushAdapter` (drops endRun forward; maps refusal to success) | – | waits editor-kernel:EK-stroke |
| AB-p2 | AB-photo | 2 | Photo delete: the sampling, curve and dab code and the four app files go; plans repointed; C4 part updated; feature-done | the same Photo files, Tests/mutations/PhotoModel.PhotoStroke.json | the same suites, `scripts/mutate --validate`, `grep -rn <symbol> Sources` empty | – | waits AB-p1, editor-kernel:EK-chrome |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- Checked 2026-10-17T06:20Z: #1933 (editor-kernel) has no comments, no `lead/editor-kernel` branch exists, and no kernel type (StrokeSmoother, DabSpacer, BrushSettings, BrushPreset, LiveCopy) or SuiteUI StrokePacer/PointerPressure/BrushCursorMark exists on dev. Both waits are unmet; commented on #1941.
- The packet's AB-p1 owns 17 files (the cap is 15): when it starts, the test files it doesn't edit come off its list (the acceptance says the app's tests pass unchanged), which also keeps the "zero test edits" quality row honest.
- Base is `dev` for PRs (CLAUDE.md, fast-lane.sh); this status branch sits on main as Belt asked.

## Open
- Blocked on editor-kernel:EK-stroke and EK-chrome (#1933).
