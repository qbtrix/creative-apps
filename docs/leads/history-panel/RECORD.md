# history-panel lead record

Issue: #3437 · Packet: docs/blueprints/photo/features/history-panel.md
Run: act-1a15ac118a1-s70v · Session: claude/feature-lead-playbook-j1aygs · Started: 2026-10-20T19:30Z
Stage: 3 wave 1
Base: a48992b7c85ded3959e12683f50bd5fe7531b011
Next: read wave 1's PRs (PH-a) on the fast lane; then wave 2

Line lead (rule 19) for #3439 eyedropper, #3437 history-panel and #3435 transform: one combined wave plan, so the other two records show the same waves.

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| PH-a | stubs + History tab on the fakes, Window > History | PH-1, PH-2 | journeys written, skipped | shell-parity (built) | true | 0 | building | – | – |
| PH-u | tab follows the listing; snapshots, render budget | PH-3, PH-4 | – | PH-a | true | 0 | planned | – | – |
| PH-m | jump body + catalog; autosave on RecoveryFolder | PH-5, PH-6 | – | PH-a; PT-5 (catalog order) | true | 0 | planned | – | – |
| PH-z | journeys on live, feature-done | PH-7, PH-8 | PhotoJourneyTests+History | PH-u, PH-m | true | 0 | planned | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| PH-1 | PH-a | 1 | adapter signatures as stubs; jump tests disabled | Sources/PhotoModel/PhotoHistory+Kernel.swift, Sources/PhotoModel/PhotoRecovery+Kernel.swift, Tests/PhotoModelTests/PhotoHistoryJumpTests.swift | PhotoHistoryJumpTests (disabled) | – | building |
| PH-2 | PH-a | 1 | History tab on stubs, HistoryIntent.jump, Window > History; journeys skipped | Sources/PhotoApp/PhotoHistoryTab.swift, Sources/PhotoApp/PhotoWindow+History.swift, Sources/PhotoApp/PhotoPanel.swift, Sources/PhotoApp/PhotoCommands+View.swift, UITests/PhotoJourneyTests+History.swift | macOS build | – | building |
| PH-3 | PH-u | 2 | tab follows listing after undo/redo/jump | Sources/PhotoApp/PhotoHistoryTab.swift, Tests/AppSnapshotTests/PhotoHistoryTabTests.swift | PhotoHistoryTabTests | – | planned |
| PH-4 | PH-u | 3 | snapshots + render budget | Tests/AppSnapshotTests/PhotoHistorySnapshots.swift, Tests/AppSnapshotTests/RenderBudgetPhotoHistoryTests.swift | snapshots | – | planned |
| PH-5 | PH-m | 4 | jump body, catalog specs, tests on | Sources/PhotoModel/PhotoHistory+Kernel.swift, Tests/PhotoModelTests/PhotoHistoryJumpTests.swift, Tests/mutations/PhotoModel.PhotoHistory+Kernel.json, Sources/PhotoModel/PhotoCommandCatalog.swift, Tests/command-ids/photo.txt | PhotoHistoryJumpTests; .jumpEndsRun .jumpRecordsNothing .baseIsOpen | – | planned |
| PH-6 | PH-m | 2 | autosave on RecoveryFolder; PhotoAutosave.swift deleted | Sources/PhotoModel/PhotoRecovery+Kernel.swift, Sources/PhotoModel/Live/LiveRecovery.swift, Sources/PhotoApp/PhotoWindow+File.swift, Sources/PhotoApp/PhotoAutosave.swift, Tests/PhotoModelTests/PhotoRecoveryFolderTests.swift, Tests/mutations/PhotoModel.LiveRecovery.json, Tests/canonical-baseline.txt | PhotoRecoveryFolderTests; .saveRemovesRecovery .newestOffered | – | planned |
| PH-7 | PH-z | 5 | journeys on live | UITests/PhotoJourneyTests+History.swift | journeys | – | planned |
| PH-8 | PH-z | 6 | status built, feature-done | docs/blueprints/photo/features/history-panel.wave.json | scripts/ci | – | planned |

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
- PH-5 waits on PT-5 only for the catalog file (wave.json transform:PT-m), so it goes in W4 after PT-5.

## Open
- PH-z waits on PH-u and PH-m.
