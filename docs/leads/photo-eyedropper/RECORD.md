# eyedropper lead record

Issue: #3439 · Packet: docs/blueprints/photo/features/eyedropper.md
Run: act-1a15ac118a1-s70v · Session: claude/feature-lead-playbook-j1aygs · Started: 2026-10-20T21:30Z
Stage: 3 wave 1
Base: a48992b7c85ded3959e12683f50bd5fe7531b011
Next: read wave 1's PRs (PE-a) on the fast lane; then wave 2

Line lead (rule 19) for #3439 eyedropper, #3437 history-panel and #3435 transform: one combined wave plan, so the other two records show the same waves.

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| PE-a | stubs + tool on the fakes, size chips, palette | PE-1, PE-2 | journey written, skipped | shell-parity (built) | true | 0 | building | – | – |
| PE-u | loupe, click pick, Option-click with Brush; snapshots, budget | PE-3, PE-4 | – | PE-a | true | 0 | planned | – | – |
| PE-m | live sampling, adapter bodies, catalog | PE-5, PE-6 | RJ-P36 | PE-a; PH-5 (catalog order) | false | 0 | planned | – | – |
| PE-z | journey on live, feature-done | PE-7, PE-8 | PhotoJourneyTests+Eyedropper | PE-u, PE-m | true | 0 | planned | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| PE-1 | PE-a | 1 | adapter as stubs, SampleSize = kernel's, tests disabled | Sources/PhotoModel/PhotoSample+Kernel.swift, Sources/PhotoModel/Contracts/OutputContracts.swift, Tests/PhotoModelTests/PhotoSampleTests.swift | PhotoSampleTests (disabled) | – | building |
| PE-2 | PE-a | 1 | tool on stubs: SampleIntent, size chips, palette enabled; journey skipped | Sources/PhotoApp/PhotoWindow+Sample.swift, Sources/PhotoApp/SampleOptions.swift, Sources/PhotoApp/PhotoPaletteTool.swift, UITests/PhotoJourneyTests+Eyedropper.swift | macOS build | – | building |
| PE-3 | PE-u | 2 | loupe, click picks, Option-click with Brush | Sources/PhotoApp/PhotoWindow+Sample.swift, Sources/PhotoApp/LiveStroke.swift, Tests/AppSnapshotTests/PhotoEyedropperOverlayTests.swift | PhotoEyedropperOverlayTests | – | planned |
| PE-4 | PE-u | 3 | snapshots + render budget | Tests/AppSnapshotTests/PhotoEyedropperSnapshots.swift, Tests/AppSnapshotTests/RenderBudgetPhotoEyedropperTests.swift | snapshots | – | planned |
| PE-5 | PE-m | 2 | live ColorSampling on SampleRules.mean; NotBuilt stand-in removed | Sources/PhotoModel/Live/LiveSampling.swift, Sources/PhotoModel/Live/NotBuilt.swift, Tests/PhotoModelTests/LiveSamplingTests.swift, Tests/mutations/PhotoModel.LiveSampling.json | LiveSamplingTests; .squareCentred .skipsTransparent | – | planned |
| PE-6 | PE-m | 4 | adapter bodies, color.sample in catalog, tests on, RJ-P36 | Sources/PhotoModel/PhotoSample+Kernel.swift, Tests/PhotoModelTests/PhotoSampleTests.swift, Tests/mutations/PhotoModel.PhotoSample+Kernel.json, Sources/PhotoModel/PhotoCommandCatalog.swift, Tests/command-ids/photo.txt, Tests/RealJobs/photo/sample-mean/ | PhotoSampleTests; .samplesComposite .pickIsToolState | – | planned |
| PE-7 | PE-z | 5 | journey on live | UITests/PhotoJourneyTests+Eyedropper.swift | journey | – | planned |
| PE-8 | PE-z | 6 | status built, feature-done | docs/blueprints/photo/features/eyedropper.wave.json | scripts/ci | – | planned |

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
- PE-6 waits on PH-5 only for the catalog file (wave.json history-panel:PH-m), so it goes last in the chain.

## Open
- PE-z waits on PE-u and PE-m.
