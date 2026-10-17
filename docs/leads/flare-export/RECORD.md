# flare-export lead record

Issue: #1973 · Packet: docs/blueprints/flare/features/flare-export.md
Run: act-1a1487603d9-vrd4 · Session: session_014CL56cxiN842wt8RaQGsi6 · Started: 2026-10-17T06:05Z
Stage: 3 wave 2
Base: 453198ac93bd637e13a6aea5f20273bd7ee728f4
Next: wave 2 (FX-2a, FX-8; workflow wf_25d336fa-c23) running beside draw-key-save's round-2 panel; between waves check editor-kernel (#1933, lead/editor-kernel RECORD) for EK-a merged (unblocks FX-2b), EK-run (FX-4), EK-chrome (FX-3), and inspector-timeline (#1515) for FX-5

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
| FX-1 | FX-a | 1 | every FlareIntent.Export case with name, identifier (format.<rawValue> for the chips) and title; examples and both intent tests grow | Sources/FlareModel/FlareIntent.swift, Sources/FlareModel/FlareIntent+Titles.swift, Tests/FlareModelTests/FlareIntentTests.swift, Tests/FlareModelTests/FlareIntentTitleTests.swift, Tests/mutations/FlareModel.FlareIntent.json | FlareIntentTests, FlareIntentTitleTests; Mutate FlareModel.FlareIntent | #1995 | merged (d45b8dab) |
| FX-6 | FX-live | 1 | LiveExportAdapter: Exporting over FlareCore's exporters and any StageRendering, text removed first, cancel between frames | Sources/FlareModel/Live/LiveExportAdapter.swift, Tests/FlareModelTests/LiveExportTests.swift, Tests/mutations/FlareModel.LiveExportAdapter.json, docs/c4/parts/creative-apps/flare-model/flare-model-sources.json | LiveExportTests; Mutate FlareModel.LiveExportAdapter | #1996 | merged (e217fcda) |
| FX-7 | FX-u | 1 | StageRasterizer: FrameRasterizing on CoreGraphics and ImageIO; RasterizerTests | Sources/FlareApp/StageRasterizer.swift, Tests/AppSnapshotTests/RasterizerTests.swift, docs/c4/parts/creative-apps/flare-app/flare-app-sources.json | RasterizerTests (macOS) | #2004 | merged (8a4ecc71) |
| FX-2a | FX-a | 2 | kernel-free half of FX-2: ExportWriteRefusal, ExportRefusal, the readout and setter stubs in FlareExport.swift, exportingOptions/openExport/startExport/retryExport stubs in FlareExport+Kernel.swift; FlareExportOptionsTests (shape enabled, MJ-FX1 readouts disabled) | Sources/FlareModel/FlareExport.swift, Sources/FlareModel/FlareExport+Kernel.swift, Tests/FlareModelTests/FlareExportOptionsTests.swift | FlareExportOptionsTests.shape | | building |
| FX-2b | FX-a | 3+ | ExportState = ExportRun<ExportOptions>; exportProgressed/endExport(Result<[String],Error>)/dismissExport onto the kernel as stubs, beginExport and export(_:rasterizer:) dropped; FlareExportTests disabled; ExportScanTests run tests rewritten and disabled | Sources/FlareModel/FlareWorkspaceState.swift, Sources/FlareModel/FlareExport.swift, Sources/FlareModel/FlareExport+Kernel.swift, Tests/FlareModelTests/FlareExportTests.swift, Tests/FlareModelTests/ExportScanTests.swift | FlareExportTests.shape | | waits editor-kernel EK-a |
| FX-3 | FX-u | 2+ | the sheet on the fakes from Export…; adapter, performExport, exportHelp, writer, chooseFolder; J22, J23 on -FlareFixture | Sources/FlareApp/FlareExportSheetAdapter.swift, Sources/FlareApp/FlareWindow+Export.swift, Sources/FlareApp/FlareWindow.swift, Sources/FlareApp/FlareFilePanels.swift, UITests/FlareJourneyTests+Export.swift, UITests/FlareJourneyTests+ExportErrors.swift | J22, J23 | | waits FX-2b, editor-kernel EK-chrome |
| FX-4 | FX-run | 2+ | the transitions over ExportRun in FlareExport+Kernel.swift; turns on FlareExportTests and the ExportScanTests run tests | Sources/FlareModel/FlareExport+Kernel.swift, Tests/mutations/FlareModel.FlareExport+Kernel.json, Tests/FlareModelTests/FlareExportTests.swift, Tests/FlareModelTests/ExportScanTests.swift | FlareExportTests; Mutate | | waits FX-2b, editor-kernel EK-run |
| FX-11 | FX-run | 3+ | readouts and setters in FlareExport.swift; turns on FlareExportOptionsTests | Sources/FlareModel/FlareExport.swift, Tests/mutations/FlareModel.FlareExport.json, Tests/FlareModelTests/FlareExportOptionsTests.swift | FlareExportOptionsTests; Mutate | | waits FX-2b |
| FX-8 | FX-live | 2 | FakeExport forwards to LiveExportAdapter(stage: FakeStage()); FlareExportRoundTripTests written and enabled on both adapters | Sources/FlareModel/Fakes/FakeExport.swift, Tests/FlareModelTests/FlareExportRoundTripTests.swift | FlareExportRoundTripTests | | building |
| FX-5 | FX-u | 3+ | six sheet snapshots; render budget test; J0's toolbar row for Export… | Tests/AppSnapshotTests/FlareExportSnapshots.swift, Tests/AppSnapshotTests/RenderBudgetFlareExportTests.swift, UITests/FlareJourneyTests.swift | FlareExportSnapshots, RenderBudgetFlareExportTests | | waits FX-3, inspector-timeline |
| FX-9 | FX-z | 4+ | .built holds LiveExportAdapter(stage: LiveStage()); J22 live on showcase; J23 steps 1-3 live on bounce | Sources/FlareModel/FlareServicesBuilt.swift, Tests/FlareModelTests/FlareServicesBuiltTests.swift, UITests/FlareJourneyTests+Export.swift, UITests/FlareJourneyTests+ExportErrors.swift | FlareServicesBuiltTests; J22, J23 | | waits FX-3, FX-4, FX-6, FX-11 |
| FX-10 | FX-z | 5 | shared prose; status built; feature-done | docs/blueprints/flare.md, docs/blueprints/flare/waves.in.md, docs/blueprints/flare/features/flare-export.wave.json, docs/blueprints/flare/features/flare-export.md | scripts/waves render --dry-run | | waits FX-9 |

Wave 1: FX-1, FX-6, FX-7, independent (disjoint files, none needs unmerged code). FX-2 is held out: it needs SuiteKernel's ExportRun, which is editor-kernel's EK-a (not on dev: no Sources/SuiteKernel, #1933 planned, no lead branch).
Wave 2: FX-2a and FX-8, independent (disjoint files; FX-8 needs only FX-6, merged). Wave 3: FX-2b once EK-a merges; then FX-11; FX-4 once EK-run has merged too; FX-3 once EK-chrome (SuiteUI ExportSheet) has merged too.
Wave 3: FX-5 (waits FX-3 and inspector-timeline #1515). Wave 4: FX-9. Wave 5: FX-10 (feature-done).

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|
| – | full CI 39018046761, scoped flare 39013292801 | 453198ac | (no slice merged-done yet: FX-a, FX-u and FX-live each have unmerged tasks) | – | – |

## Decisions
- Base and PR target are `dev` (CLAUDE.md, lead.md rule 4; scripts/fast-lane.sh BASE_BRANCH is dev), though the launch brief says main; main is dev's promoted SHA and 4 commits behind it.
- FX-2 cannot start: `ExportState = ExportRun<ExportOptions>` needs the SuiteKernel target that editor-kernel's EK-a creates (Package.swift is protected, another line's target). Rule 20 says wait on the kernel module, never an app copy. FX-1, FX-6 and FX-7 have no kernel dependency and run now.
- Packet slip: `bounce` has 48 frames (0...47), so MJ-FX2's "0...48 step 2 as 25 PNGs" reads 0...47 step 2 as 24 PNGs; the builder tests the fixture's real range.
- FX-7 (StageRasterizer) is macOS-only code a cloud builder can't compile; it gets the lane's build-only run and the Mac finisher (rule 17); its builder checks CoreGraphics and ImageIO against the docs MCP and lists `Unverified API:` lines.

- FX-2 split: FX-2a (now) declares every stub and test that doesn't need SuiteKernel (rule 18's 'declare the stubs the UI needs' as a small task); FX-2b (after EK-a) is only the kernel typealias, the three run methods onto it and the kernel-shaped disabled tests. FX-8 unchained from FX-2: it carries the round-trip tests itself, enabled, since both adapters are merged (rule 13 allows a test with its code).
- Wave 1's three PRs were flagged by the contract checker only for the PR service's appended footer, which the lane strips (CLAUDE.md); recorded as meeting the contract.
- editor-kernel (#1933, run act-1a1483c0771-g24c) is at wave 2 of EK-a; EK-1 (#1992) edits Package.swift and awaits the supervisor's merge, so EK-a is at least one wave out. EK-run and EK-chrome are its waves 4 to 5.

## Open
- editor-kernel (#1933) is `planned` with no lead branch: FX-2 (EK-a), FX-4 (EK-run) and FX-3 (EK-chrome) wait on it; checked between waves.
- inspector-timeline (#1515) is at stage 0 waiting on #1365's dependency confirmation: FX-5 waits on it.
- Filed #1989 (needs-ui): ExportSheet host options slot and control-id prefix (EK-30; beside #1981). Filed #1990 (needs-ui): SuiteModel's shared never-overwrite name rule from Library's LiveExporter. Commented on #1939: AX-flare's move happens in FX-2 and FX-4.
- Wave 1 workflow wf_b541828b-076 (build-wave: FX-1, FX-6, FX-7; alongside: draw-key-save round-2 panel).
