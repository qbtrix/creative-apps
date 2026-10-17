# flare-export lead record

Issue: #1973 · Packet: docs/blueprints/flare/features/flare-export.md
Run: act-1a1487603d9-vrd4 · Session: session_014CL56cxiN842wt8RaQGsi6 · Started: 2026-10-17T06:05Z
Stage: 3 wave 1
Base: 4a86f5fcff2f2cc18748a93e39f1491c6ae5c745
Next: wave 1 (FX-1, FX-6, FX-7) running; between waves check editor-kernel (#1933) for EK-a (unblocks FX-2), EK-run (FX-4), EK-chrome (FX-3) and inspector-timeline (#1515) for FX-5

Loop: v3 (the packet has a `## Slices` table). Line lead with draw-key-save (#1365, rule 19).

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| FX-a | export intents with titles and ids; ExportState = ExportRun<ExportOptions>; every sheet signature stubbed; Model tests written, disabled | FX-1, FX-2 | MJ-FX0 | editor-kernel:EK-a (FX-2, cross-line) | no | 0 | building | | |
| FX-u | Export… opens SuiteUI's ExportSheet on the fakes; writes never overwrite; progress, Cancel, Reveal, Try Again; StageRasterizer draws pixels | FX-3, FX-5, FX-7 | J22, J23 | FX-a (FX-3, FX-5); editor-kernel:EK-chrome (FX-3); inspector-timeline (FX-5) | yes | 0 | building | | |
| FX-run | the run's transitions and readouts over ExportRun | FX-4, FX-11 | MJ-FX1 | FX-a; editor-kernel:EK-run (FX-4) | no | 0 | waiting | | |
| FX-live | LiveExportAdapter over the live stage; FakeExport delegates; round trip byte-identical | FX-6, FX-8 | MJ-FX2 | FX-a (FX-8) | no | 0 | building | | |
| FX-z | .built exports live; J22/J23 live; prose; built | FX-9, FX-10 | J22, J23 | FX-u, FX-run, FX-live | no | 0 | waiting | | |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| FX-1 | FX-a | 1 | every FlareIntent.Export case with name, identifier (format.<rawValue> for the chips) and title; examples and both intent tests grow | Sources/FlareModel/FlareIntent.swift, Sources/FlareModel/FlareIntent+Titles.swift, Tests/FlareModelTests/FlareIntentTests.swift, Tests/FlareModelTests/FlareIntentTitleTests.swift, Tests/mutations/FlareModel.FlareIntent.json | FlareIntentTests, FlareIntentTitleTests; Mutate FlareModel.FlareIntent | | building |
| FX-6 | FX-live | 1 | LiveExportAdapter: Exporting over FlareCore's exporters and any StageRendering, text removed first, cancel between frames | Sources/FlareModel/Live/LiveExportAdapter.swift, Tests/FlareModelTests/LiveExportTests.swift, Tests/mutations/FlareModel.LiveExportAdapter.json, docs/c4/parts/creative-apps/flare-model/flare-model-sources.json | LiveExportTests; Mutate FlareModel.LiveExportAdapter | | building |
| FX-7 | FX-u | 1 | StageRasterizer: FrameRasterizing on CoreGraphics and ImageIO; RasterizerTests | Sources/FlareApp/StageRasterizer.swift, Tests/AppSnapshotTests/RasterizerTests.swift, docs/c4/parts/creative-apps/flare-app/flare-app-sources.json | RasterizerTests (macOS) | | building |
| FX-2 | FX-a | 2+ | ExportState = ExportRun<ExportOptions>, ExportWriteRefusal, every stub; FlareExportTests, FlareExportOptionsTests, FlareExportRoundTripTests disabled; ExportScanTests run tests rewritten and disabled | Sources/FlareModel/FlareWorkspaceState.swift, Sources/FlareModel/FlareExport.swift, Sources/FlareModel/FlareExport+Kernel.swift, Tests/FlareModelTests/FlareExportTests.swift, Tests/FlareModelTests/FlareExportOptionsTests.swift, Tests/FlareModelTests/FlareExportRoundTripTests.swift, Tests/FlareModelTests/ExportScanTests.swift | FlareExportTests.shape | | waits editor-kernel EK-a |
| FX-3 | FX-u | 2+ | the sheet on the fakes from Export…; adapter, performExport, exportHelp, writer, chooseFolder; J22, J23 on -FlareFixture | Sources/FlareApp/FlareExportSheetAdapter.swift, Sources/FlareApp/FlareWindow+Export.swift, Sources/FlareApp/FlareWindow.swift, Sources/FlareApp/FlareFilePanels.swift, UITests/FlareJourneyTests+Export.swift, UITests/FlareJourneyTests+ExportErrors.swift | J22, J23 | | waits FX-1, FX-2, FX-7, editor-kernel EK-chrome |
| FX-4 | FX-run | 2+ | the transitions over ExportRun in FlareExport+Kernel.swift; turns on FlareExportTests and the ExportScanTests run tests | Sources/FlareModel/FlareExport+Kernel.swift, Tests/mutations/FlareModel.FlareExport+Kernel.json, Tests/FlareModelTests/FlareExportTests.swift, Tests/FlareModelTests/ExportScanTests.swift | FlareExportTests; Mutate | | waits FX-2, editor-kernel EK-run |
| FX-11 | FX-run | 2+ | readouts and setters in FlareExport.swift; turns on FlareExportOptionsTests | Sources/FlareModel/FlareExport.swift, Tests/mutations/FlareModel.FlareExport.json, Tests/FlareModelTests/FlareExportOptionsTests.swift | FlareExportOptionsTests; Mutate | | waits FX-2 |
| FX-8 | FX-live | 2+ | FakeExport forwards to LiveExportAdapter(stage: FakeStage()); turns on FlareExportRoundTripTests | Sources/FlareModel/Fakes/FakeExport.swift, Tests/FlareModelTests/FlareExportRoundTripTests.swift | FlareExportRoundTripTests | | waits FX-2, FX-6 |
| FX-5 | FX-u | 3+ | six sheet snapshots; render budget test; J0's toolbar row for Export… | Tests/AppSnapshotTests/FlareExportSnapshots.swift, Tests/AppSnapshotTests/RenderBudgetFlareExportTests.swift, UITests/FlareJourneyTests.swift | FlareExportSnapshots, RenderBudgetFlareExportTests | | waits FX-3, inspector-timeline |
| FX-9 | FX-z | 4+ | .built holds LiveExportAdapter(stage: LiveStage()); J22 live on showcase; J23 steps 1-3 live on bounce | Sources/FlareModel/FlareServicesBuilt.swift, Tests/FlareModelTests/FlareServicesBuiltTests.swift, UITests/FlareJourneyTests+Export.swift, UITests/FlareJourneyTests+ExportErrors.swift | FlareServicesBuiltTests; J22, J23 | | waits FX-3, FX-4, FX-6, FX-11 |
| FX-10 | FX-z | 5 | shared prose; status built; feature-done | docs/blueprints/flare.md, docs/blueprints/flare/waves.in.md, docs/blueprints/flare/features/flare-export.wave.json, docs/blueprints/flare/features/flare-export.md | scripts/waves render --dry-run | | waits FX-9 |

Wave 1: FX-1, FX-6, FX-7, independent (disjoint files, none needs unmerged code). FX-2 is held out: it needs SuiteKernel's ExportRun, which is editor-kernel's EK-a (not on dev: no Sources/SuiteKernel, #1933 planned, no lead branch).
Wave 2: FX-11 and FX-8 once FX-2 merges; FX-4 once EK-run has merged too; FX-3 once EK-chrome (SuiteUI ExportSheet) has merged too.
Wave 3: FX-5 (waits FX-3 and inspector-timeline #1515). Wave 4: FX-9. Wave 5: FX-10 (feature-done).

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- Base and PR target are `dev` (CLAUDE.md, lead.md rule 4; scripts/fast-lane.sh BASE_BRANCH is dev), though the launch brief says main; main is dev's promoted SHA and 4 commits behind it.
- FX-2 cannot start: `ExportState = ExportRun<ExportOptions>` needs the SuiteKernel target that editor-kernel's EK-a creates (Package.swift is protected, another line's target). Rule 20 says wait on the kernel module, never an app copy. FX-1, FX-6 and FX-7 have no kernel dependency and run now.
- Packet slip: `bounce` has 48 frames (0...47), so MJ-FX2's "0...48 step 2 as 25 PNGs" reads 0...47 step 2 as 24 PNGs; the builder tests the fixture's real range.
- FX-7 (StageRasterizer) is macOS-only code a cloud builder can't compile; it gets the lane's build-only run and the Mac finisher (rule 17); its builder checks CoreGraphics and ImageIO against the docs MCP and lists `Unverified API:` lines.

## Open
- editor-kernel (#1933) is `planned` with no lead branch: FX-2 (EK-a), FX-4 (EK-run) and FX-3 (EK-chrome) wait on it; checked between waves.
- inspector-timeline (#1515) is at stage 0 waiting on #1365's dependency confirmation: FX-5 waits on it.
- needs-ui to file: ExportSheet options slot for app rows and a control-id prefix (EK-30; #1981 asks for scope and scale rows for Design). Kernel issue to file: the shared never-overwrite name rule extracted from Library's LiveExporter. Note to post on #1939 (adopt-kernel-export): AX-flare's move happens in FX-2 and FX-4.
