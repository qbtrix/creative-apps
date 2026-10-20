# transform lead record

Issue: #3435 · Packet: docs/blueprints/photo/features/transform.md
Run: act-1a15ac118a1-s70v · Session: claude/feature-lead-playbook-j1aygs · Started: 2026-10-20T19:30Z
Stage: 3 wave 1
Base: a48992b7c85ded3959e12683f50bd5fe7531b011
Next: read wave 1's PRs (PT-a) on the fast lane; then wave 2

Line lead (rule 19) for #3439 eyedropper, #3437 history-panel and #3435 transform: one combined wave plan, so the other two records show the same waves.

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| PT-a | stubs + Free Transform on the fakes, Edit menu | PT-1, PT-2 | journey written, skipped | – | true | 0 | building | – | – |
| PT-u | Canvas Size sheet, snapshots, render budget | PT-3, PT-7 | – | PT-a, shell-parity (built) | true | 0 | planned | – | – |
| PT-m | resample, adapter bodies, canvas size body | PT-4, PT-5, PT-6 | RJ-P17, RJ-P18 | PT-a | false | 0 | planned | – | – |
| PT-z | journey on live, feature-done | PT-8, PT-9 | PhotoJourneyTests+Transform | PT-u, PT-m | true | 0 | planned | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| PT-1 | PT-a | 1 | adapter + four methods as stubs, FlipAxis = FlipDirection, tests disabled | Sources/PhotoModel/PhotoTransform+Kernel.swift, Sources/PhotoModel/Contracts/LayerContracts.swift, Tests/PhotoModelTests/PhotoTransformTests.swift | PhotoTransformTests (disabled) | – | building |
| PT-2 | PT-a | 1 | Free Transform on stubs: intent, overlay, TransformRows, Edit menu; journey skipped | Sources/PhotoApp/PhotoWindow+Transform.swift, Sources/PhotoApp/TransformOverlay.swift, Sources/PhotoApp/TransformOptions.swift, Sources/PhotoApp/PhotoCommands+Edit.swift, UITests/PhotoJourneyTests+Transform.swift | macOS build | – | building |
| PT-3 | PT-u | 2 | Image > Canvas Size… sheet | Sources/PhotoApp/CanvasSizeSheet.swift, Sources/PhotoApp/PhotoCommands+Image.swift, Sources/PhotoApp/PhotoWindow+Transform.swift, Tests/AppSnapshotTests/PhotoCanvasSizeSheetTests.swift | PhotoCanvasSizeSheetTests | – | planned |
| PT-4 | PT-m | 2 | applied/flipped on CoreRaster; TransformRules.local and matrix | Sources/PhotoModel/Live/LiveTransform+Kernel.swift, Tests/PhotoModelTests/LiveTransformTests.swift, Tests/mutations/PhotoModel.LiveTransform+Kernel.json | LiveTransformTests; .turn90Size .flipHorizontal | – | planned |
| PT-5 | PT-m | 3 | adapter bodies, catalog specs, tests on, RJ-P17 | Sources/PhotoModel/PhotoTransform+Kernel.swift, Tests/PhotoModelTests/PhotoTransformTests.swift, Tests/mutations/PhotoModel.PhotoTransform+Kernel.json, Sources/PhotoModel/PhotoCommandCatalog.swift, Tests/command-ids/photo.txt, Tests/RealJobs/photo/free-transform/ | PhotoTransformTests; .flipInPlace .identityCommitsNothing .lockedRefuses | – | planned |
| PT-6 | PT-m | 4 | resizeCanvas and image.canvas-size, RJ-P18 | Sources/PhotoModel/PhotoImageOps.swift, Tests/PhotoModelTests/PhotoCanvasSizeTests.swift, Tests/mutations/PhotoModel.PhotoImageOps.json, Tests/RealJobs/photo/canvas-border/ | PhotoCanvasSizeTests; .canvasSizeCentred .borderIsBackground | – | planned |
| PT-7 | PT-u | 3 | snapshots + render budget | Tests/AppSnapshotTests/PhotoTransformSnapshots.swift, Tests/AppSnapshotTests/RenderBudgetPhotoTransformTests.swift | snapshots | – | planned |
| PT-8 | PT-z | 5 | journey on live | UITests/PhotoJourneyTests+Transform.swift | journey | – | planned |
| PT-9 | PT-z | 6 | status built, feature-done | docs/blueprints/photo/features/transform.wave.json | scripts/ci | – | planned |

## Waves (combined plan, all three features)
- W1 (independent, disjoint files): PT-a (PT-1, then PT-2 stacked), PH-a (PH-1+PH-2), PE-a (PE-1+PE-2).
- W2: PT-4 (waits on PT-1: FlipAxis), PE-5 (waits on PE-1: SampleSize), PH-6 (waits on PH-1: recovery stubs), PT-3 (waits on PT-2: the transform area), PH-3 (waits on PH-2), PE-3 (waits on PE-2). Each one is stacked on its parent.
- W3: PT-5 (waits on PT-4: resample), PT-7 (waits on PT-3), PH-4 (waits on PH-3), PE-4 (waits on PE-3).
- W4: PT-6 (waits on PT-5: canvas-size through the registered command), PH-5 (waits on PT-5: catalog order), then PE-6 (waits on PH-5: catalog order, and on PE-5).
- W5: PT-8, PH-7, PE-7 (journeys on live, each waits on its feature's last code task).
- W6: PT-9, PH-8, PE-8 (feature-done).

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|
| – | – | – | – | – | – |

## Decisions
- v3 loop: each packet has a `## Slices` table.
- Base `dev`, not `main`: CLAUDE.md and the lead contract say branch from and target dev; the fast lane only merges dev PRs. Brief step one checked main at b3011ab; waves start from origin/dev.
- Status branch and folder carry a `photo-` prefix where `lead/<feature>` already belongs to another live lead (SuiteUI eyedropper #3448 on `lead/eyedropper`, Halo transform #3443 on `lead/transform`). Overwriting them would break those leads. history-panel has no clash and uses `lead/history-panel`.
- PRs keep `Feature: <packet feature>`, without the prefix.
- One PR per slice (rule 22), split per task when a slice is over the 400-line cap: PT-a (~470), PT-m (~780) and PH-m (~500). A stacked PR is opened only once its diff against dev fits the cap, so the lane never strips the label for size.
- Catalog serialization: PhotoCommandCatalog.swift and Tests/command-ids/photo.txt are edited in turn by PT-5, PH-5 and PE-6, each stacked on the one before. The wave.json waits transform:PT-m on PH-5 and history-panel:PH-m on PE-6 exist only for that file ordering.
- PT-5's waits on gradient-fill:PG-m and multi-layer-select:PM-m are dropped. Both features are `planned` with no feature issue ("file when ready") and nobody is building them, so the waits only ordered edits to the shared catalog. PT-5 goes first in the chain.
- Cross-line waits met on dev a48992b: SuiteKernel Transform/Sample/History rules and commands (TT-a #3485/#3486, #3524, #3573), SuiteUI SampleLoupe/SampleSizeChips (EY #3525/#3531/#3540/#3541), TransformRows and handles #3512, HistoryPanel #3568/#3596/#3607, RecoveryFolder #3572, AutosaveSchedule #3576. shell-parity (photo) and AC-photo are built.
- The swift toolchain was missing on this machine; it was installed with scripts/cloud-setup.sh (6.3.3) so `scripts/ci --changed` runs here.
- PT-4 runs in parallel with PT-2: it needs only PT-1's FlipAxis.

## Open
- PT-z waits on PT-u and PT-m.
