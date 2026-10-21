# flare-export lead record

Last stage: done: Belt-Contact-Sheet posted on #1973 2026-10-20T21:04Z (run 39492947557); #1973 closed by the supervisor sentinel. Nothing left on this feature.

Issue: #1973 · Packet: docs/blueprints/flare/features/flare-export.md
Run: act-1a15b1de023-4xx7 (earlier act-1a15400ea40-y423) · Session: claude/feature-lead-playbook-zxpitc · Started: 2026-10-17T06:05Z (resumed 2026-10-19T12:00Z, line lead: stage-edit #1514, flare-export #1973)
Stage: done
Base: 6c2c7b05 (origin/dev)
Next: beta-hardening lane verifies FX-u, FX-z on the first macOS run (scoped flare 39491495208 queued); contact sheet posted on #1973

Loop: v3 (the packet has a `## Slices` table). Line lead with draw-key-save (#1365, rule 19).

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| FX-a | export intents with titles and ids; ExportState = ExportRun<ExportOptions>; every sheet signature stubbed; Model tests written, disabled | FX-1, FX-2 | MJ-FX0 | editor-kernel:EK-a (FX-2, cross-line) | no | 0 | done | | |
| FX-u | Export… opens SuiteUI's ExportSheet on the fakes; writes never overwrite; progress, Cancel, Reveal, Try Again; StageRasterizer draws pixels | FX-3, FX-5, FX-7 | J22, J23 | FX-a (FX-3, FX-5); editor-kernel:EK-chrome (FX-3); inspector-timeline (FX-5) | yes | 0 | done | https://github.com/qbtrix/creative-apps/actions/runs/39492947557 | wanted |
| FX-run | the run's transitions and readouts over ExportRun | FX-4, FX-11 | MJ-FX1 | FX-a; editor-kernel:EK-run (FX-4) | no | 0 | done | | |
| FX-live | LiveExportAdapter over the live stage; FakeExport delegates; round trip byte-identical | FX-6, FX-8 | MJ-FX2 | FX-a (FX-8) | no | 0 | done | https://github.com/qbtrix/creative-apps/actions/runs/39093972830 | |
| FX-z | .built exports live; J22/J23 live; prose; built | FX-9, FX-10 | J22, J23 | FX-u, FX-run, FX-live | no | 0 | done | https://github.com/qbtrix/creative-apps/actions/runs/39492947557 | |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| FX-1 | FX-a | 1 | every FlareIntent.Export case with name, identifier (format.<rawValue> for the chips) and title; examples and both intent tests grow | Sources/FlareModel/FlareIntent.swift, Sources/FlareModel/FlareIntent+Titles.swift, Tests/FlareModelTests/FlareIntentTests.swift, Tests/FlareModelTests/FlareIntentTitleTests.swift, Tests/mutations/FlareModel.FlareIntent.json | FlareIntentTests, FlareIntentTitleTests; Mutate FlareModel.FlareIntent | #1995 | merged (d45b8dab) |
| FX-6 | FX-live | 1 | LiveExportAdapter: Exporting over FlareCore's exporters and any StageRendering, text removed first, cancel between frames | Sources/FlareModel/Live/LiveExportAdapter.swift, Tests/FlareModelTests/LiveExportTests.swift, Tests/mutations/FlareModel.LiveExportAdapter.json, docs/c4/parts/creative-apps/flare-model/flare-model-sources.json | LiveExportTests; Mutate FlareModel.LiveExportAdapter | #1996 | merged (e217fcda) |
| FX-7 | FX-u | 1 | StageRasterizer: FrameRasterizing on CoreGraphics and ImageIO; RasterizerTests | Sources/FlareApp/StageRasterizer.swift, Tests/AppSnapshotTests/RasterizerTests.swift, docs/c4/parts/creative-apps/flare-app/flare-app-sources.json | RasterizerTests (macOS) | #2004 | merged (8a4ecc71) |
| FX-2a | FX-a | 2 | kernel-free half of FX-2: ExportWriteRefusal, ExportRefusal, the readout and setter stubs in FlareExport.swift, exportingOptions/openExport/startExport/retryExport stubs in FlareExport+Kernel.swift; FlareExportOptionsTests (shape enabled, MJ-FX1 readouts disabled) | Sources/FlareModel/FlareExport.swift, Sources/FlareModel/FlareExport+Kernel.swift, Tests/FlareModelTests/FlareExportOptionsTests.swift | FlareExportOptionsTests.shape | #2564 | merged |
| FX-2b | FX-a | 3+ | ExportState = ExportRun<ExportOptions>; exportProgressed/endExport(Result<[String],Error>)/dismissExport onto the kernel as stubs, beginExport and export(_:rasterizer:) dropped; FlareExportTests disabled; ExportScanTests run tests rewritten and disabled | Sources/FlareModel/FlareWorkspaceState.swift, Sources/FlareModel/FlareExport.swift, Sources/FlareModel/FlareExport+Kernel.swift, Tests/FlareModelTests/FlareExportTests.swift, Tests/FlareModelTests/ExportScanTests.swift | FlareExportTests.shape | | waits editor-kernel EK-a |
| FX-3a | FX-u | 4 | Export… opens SuiteExportSheet on the fakes via FlareExportSheetAdapter (format/size rows), performExport, exportHelp, writer never overwrites, chooseFolder; J22 first steps, the rest XCTSkip 'waits on #1989' | FlareExportSheetAdapter.swift, FlareWindow+Export.swift, FlareWindow.swift, FlareFilePanels.swift, UITests/FlareJourneyTests+Export.swift | J22 (part) | #2944 | merged (2026-10-18T20:38Z) |
| FX-3c | FX-u | 4 | J0 Export… row reads the real no-document reason | UITests/FlareJourneyTests.swift | J0 | #3006 | merged 85f4a229 22:08Z |
| FX-3b | FX-u | 5+ | the sheet on the fakes from Export…; adapter, performExport, exportHelp, writer, chooseFolder; J22, J23 on -FlareFixture | Sources/FlareApp/FlareExportSheetAdapter.swift, Sources/FlareApp/FlareWindow+Export.swift, Sources/FlareApp/FlareWindow.swift, Sources/FlareApp/FlareFilePanels.swift, UITests/FlareJourneyTests+Export.swift, UITests/FlareJourneyTests+ExportErrors.swift | J22, J23 | #3296 (9b37e1a) | in lane; Fixes #2484, Refs #3036 (Spinner layer id remains); SuiteUI asks in #3297 |
| FX-4 | FX-run | 2+ | the transitions over ExportRun in FlareExport+Kernel.swift; turns on FlareExportTests and the ExportScanTests run tests | Sources/FlareModel/FlareExport+Kernel.swift, Tests/mutations/FlareModel.FlareExport+Kernel.json, Tests/FlareModelTests/FlareExportTests.swift, Tests/FlareModelTests/ExportScanTests.swift | FlareExportTests; Mutate | | waits FX-2b, editor-kernel EK-run |
| FX-11 | FX-run | 3+ | readouts and setters in FlareExport.swift; turns on FlareExportOptionsTests | Sources/FlareModel/FlareExport.swift, Tests/mutations/FlareModel.FlareExport.json, Tests/FlareModelTests/FlareExportOptionsTests.swift | FlareExportOptionsTests; Mutate | | waits FX-2b |
| FX-8 | FX-live | 2 | FakeExport forwards to LiveExportAdapter(stage: FakeStage()); FlareExportRoundTripTests written and enabled on both adapters | Sources/FlareModel/Fakes/FakeExport.swift, Tests/FlareModelTests/FlareExportRoundTripTests.swift | FlareExportRoundTripTests | #2533 | merged |
| FX-5 | FX-u | 3+ | six sheet snapshots; render budget test; J0's toolbar row for Export… | Tests/AppSnapshotTests/FlareExportSnapshots.swift, Tests/AppSnapshotTests/RenderBudgetFlareExportTests.swift, UITests/FlareJourneyTests.swift | FlareExportSnapshots, RenderBudgetFlareExportTests | #3240 (ca41413) | merged ca41413; render budget disabled until #1989 (FX-3b re-enables) |
| FX-9 | FX-z | 4+ | .built holds LiveExportAdapter(stage: LiveStage()); J22 live on showcase; J23 steps 1-3 live on bounce | Sources/FlareModel/FlareServicesBuilt.swift, Tests/FlareModelTests/FlareServicesBuiltTests.swift, UITests/FlareJourneyTests+Export.swift, UITests/FlareJourneyTests+ExportErrors.swift | FlareServicesBuiltTests; J22, J23 | #3240 (9a, ca41413); #3298 (9b, fc90fa6) | 9a merged; 9b #3298 stacked on #3296, held with no-fast-lane until #3296 merges |
| FX-10 | FX-z | 5 | shared prose; status built; feature-done | docs/blueprints/flare.md, docs/blueprints/flare/waves.in.md, docs/blueprints/flare/features/flare-export.wave.json, docs/blueprints/flare/features/flare-export.md | scripts/waves render --dry-run | | waits FX-9 |

Wave 1: FX-1, FX-6, FX-7, independent (disjoint files, none needs unmerged code). FX-2 is held out: it needs SuiteKernel's ExportRun, which is editor-kernel's EK-a (not on dev: no Sources/SuiteKernel, #1933 planned, no lead branch).
Wave 2: FX-2a and FX-8, independent (disjoint files; FX-8 needs only FX-6, merged). Wave 3: FX-2b once EK-a merges; then FX-11; FX-4 once EK-run has merged too; FX-3 once EK-chrome (SuiteUI ExportSheet) has merged too.
Wave 3: FX-5 (waits FX-3 and inspector-timeline #1515). Wave 4: FX-9. Wave 5: FX-10 (feature-done).

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|
| – | full CI 39018046761, scoped flare 39013292801 | 453198ac | (no slice merged-done yet: FX-a, FX-u and FX-live each have unmerged tasks) | – | – |

## Decisions
- 2026-10-18T21:10Z FX-3c split out of FX-5: J0's Export… row went stale with #2944; a one-line fix now keeps the journey honest.
- FX-3a outcome (#2944): a name clash refuses with ExportWriteRefusal.alreadyThere (packet, J23 sentence) rather than SuiteModel UniqueFileNames, which picks a free name; changing that is a packet change. J0's Export… row (FX-5's file) still expects 'Not built yet (F15a).' and will report red until FX-5. The sheet shows no problem line until FX-3b (#1989).
- 2026-10-18T19:52Z FX-3 split: FX-3a now (SuiteExportSheet from #2744 has format/scale/quality rows and fixed suite.export.* ids); FX-3b after #1989 adds the host options slot and id prefix. FX-a and FX-run are done (Belt-Slice-Done posted); remaining FX-u, FX-z.
- Base and PR target are `dev` (CLAUDE.md, lead.md rule 4; scripts/fast-lane.sh BASE_BRANCH is dev), though the launch brief says main; main is dev's promoted SHA and 4 commits behind it.
- FX-2 cannot start: `ExportState = ExportRun<ExportOptions>` needs the SuiteKernel target that editor-kernel's EK-a creates (Package.swift is protected, another line's target). Rule 20 says wait on the kernel module, never an app copy. FX-1, FX-6 and FX-7 have no kernel dependency and run now.
- Packet slip: `bounce` has 48 frames (0...47), so MJ-FX2's "0...48 step 2 as 25 PNGs" reads 0...47 step 2 as 24 PNGs; the builder tests the fixture's real range.
- FX-7 (StageRasterizer) is macOS-only code a cloud builder can't compile; it gets the lane's build-only run and the Mac finisher (rule 17); its builder checks CoreGraphics and ImageIO against the docs MCP and lists `Unverified API:` lines.

- FX-2 split: FX-2a (now) declares every stub and test that doesn't need SuiteKernel (rule 18's 'declare the stubs the UI needs' as a small task); FX-2b (after EK-a) is only the kernel typealias, the three run methods onto it and the kernel-shaped disabled tests. FX-8 unchained from FX-2: it carries the round-trip tests itself, enabled, since both adapters are merged (rule 13 allows a test with its code).
- Wave 1's three PRs were flagged by the contract checker only for the PR service's appended footer, which the lane strips (CLAUDE.md); recorded as meeting the contract.
- editor-kernel (#1933, run act-1a1483c0771-g24c) is at wave 2 of EK-a; EK-1 (#1992) edits Package.swift and awaits the supervisor's merge, so EK-a is at least one wave out. EK-run and EK-chrome are its waves 4 to 5.

## Open
- 2026-10-18T19:52Z: #1989 open (FX-3b, FX-5 wait); inspector-timeline for FX-5. No open flare-export findings.
- editor-kernel (#1933) is `planned` with no lead branch: FX-2 (EK-a), FX-4 (EK-run) and FX-3 (EK-chrome) wait on it; checked between waves.
- inspector-timeline (#1515) is at stage 0 waiting on #1365's dependency confirmation: FX-5 waits on it.
- Filed #1989 (needs-ui): ExportSheet host options slot and control-id prefix (EK-30; beside #1981). Filed #1990 (needs-ui): SuiteModel's shared never-overwrite name rule from Library's LiveExporter. Commented on #1939: AX-flare's move happens in FX-2 and FX-4.
- Wave 1 workflow wf_b541828b-076 (build-wave: FX-1, FX-6, FX-7; alongside: draw-key-save round-2 panel).
- FX-live done: Belt-Slice-Done posted with scoped flare run 39093972830 (head f2b50fae contains #2533).
- CI findings (report-only macOS, run 39093972830): the Flare journeys are red on the overlap audit, and none is in this feature's files or carries Feature: flare-export, so the rule-10 count is 0. No export journey exists yet (FX-3 and FX-5 add them).
- FX-2a (#2564): the finished-run summary tests wait for FX-4 (endExport changes to Result). The MJ-FX1 readout tests are disabled "waits on FX-11", but FX-11 also needs FX-4's openExport, so FX-11 waits on FX-4 too.
- 05:30Z: editor-kernel EK-2 #2577 (History, Selection, LayerTree stubs) merged 05:24Z, but ExportRun is not on dev (Sources/SuiteKernel has no ExportRun), so FX-2b still waits on the rest of EK-a. Scoped flare run 39098049090 (success, contains FX-2a) does not close FX-a without FX-2b. No flare-export findings.
- 2026-10-18T06:04Z Decision: FX-4 ordered after FX-11, because its disabled tests use exportFileCount, exportProblem and the option setters.
- 2026-10-18T09:49Z #2649 (FX-2b) merged as 00684c2c. Decision: FX-11 cannot start before EK-22. Its setters write the editing options through ExportRun.begin, and its tests reach editing through openExport (FX-4); both are stubs. FX-4 and FX-11 waited on each other (06:04Z), so the order after EK-22 is FX-4 then FX-11: FX-4 turns on the transition tests that need no setter and leaves the setter ones disabled 'waits on FX-11', and FX-11 turns those on with its own.

## Findings (FX-u)

- #3036, #2484: identifier audit on scoped flare run 39171502038 (green otherwise; contains FX-3c). Export-sheet Format/Size ids are FX-3b's flare.export.* work (blocked on SuiteUI #1989). The layer-row ('Spinner', 'Title') and staticText violations on export screens come from line-wide timeline/layer views, shared with other flare findings; not widened into export PRs. FX-3b closes the export part; fix round 1 of 2.

- 2026-10-19T13:10Z #3240 opened (FX-5 + FX-9a, head 437bb504). RenderBudgetFlareExportTests are .disabled("waits on #1989"): no To row exists until the options slot; the png, problem and finished snapshots assert the Model state but show only what the current sheet has. FX-3b re-enables the budget and refreshes those PNGs. Asked supervisor (PR body) to add RenderBudgetFlareExportTests/timing to Tests/perf-suites.txt.
- 2026-10-19T17:15Z FX-3b opened as #3296 (head 9b37e1a, 6 files, +294/-38). It closes #2484 and refers to #3036. Two SuiteUI gaps went to #3297 (needs-ui): the host can't disable Export when there's a problem line, and the Size row has no id and duplicates the chips. While filing #3297 the lead overwrote #3290's body by mistake. That body now points to the edit history so the original can be restored, and the supervisor has been told.
- 2026-10-19T17:20Z FX-9b opened as #3298 (head fc90fa6), stacked on #3296. J22 now runs on `-FlareSample showcase` and checks that each PNG's IHDR width is 550. J23 steps 1–3 run live on bounce; step 4 (Cancel) stays on the fakes because the live run has no pause between frames. #3298 carries `no-fast-lane` until #3296 merges, then the label comes off. FX-10 should add `FlareExportErrorJourneys.testExportNeverOverwritesAndFailsLive` to flare-export.wave.json.
