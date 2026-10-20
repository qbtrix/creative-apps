# design-export lead record

Issue: #1970 · Packet: docs/blueprints/design/features/design-export.md
Run: act-1a15a9a4e8b-kn6a · Session: claude/feature-lead-playbook-y5rnbx · Started: 2026-10-20T18:42:31Z (prior runs act-1a14852c11d-65cg, act-1a14fd6514a-4hke, act-1a156b3f640-ytq0)
Stage: 3 wave 1 of this run (DE-z in the lane, #3684)
Base: 875b44d22d79dcfb782d7276af76dfc72a23f11a (origin/dev); main verified at b3011ab9
Next: DE-u critics on the next scoped: design or full run on dev (none yet; macOS queue backed up); DE-z #3684 (head b4c35e57, feature-done) waits on its batch; its CI then the contact sheet

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| DE-a | options, scope, run type, live and fake export slots plan like the fake, UniqueFileNames in SuiteModel | DE-1, DE-0, DE-2 | MJ13 | design-contracts (built); editor-kernel EK-a (DE-2) | no | 0 | done | https://github.com/qbtrix/creative-apps/actions/runs/39018046761 | – |
| DE-u | File > Export… ⇧⌘E opens SuiteUI ExportSheet on the fakes; Export runs the fake steps; Cancel/Escape close; a failed step names its file | DE-6, DE-7 | J19 | DE-a; design-window DW-c; files-history FH-b; snapping SN-c; canvas-basics CB-c; editor-kernel EK-chrome | yes | 0 | merged, waits CI | 39475897385 (pending) | wanted |
| DE-s | the plan picks layers per scope, unique names, sizes per scale, refusals; SVG equals the reference | DE-3, DE-5 | MJ13, MJ14 | DE-a | no | 0 | done | – | – |
| DE-w | PNG at 1x/2x/3x and one-page PDF off the window from the canvas artwork | DE-8, DE-9 | DesignRasterizerTests | DE-a | yes | 0 | done | – | – |
| DE-z | real files, never overwriting, progress, failures, journeys on live | DE-10, DE-11 | J17, J18 | DE-u, DE-s, DE-w; files-history FH-b; editor-kernel EK-run | yes | 0 | in lane #3684 | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| DE-0 | DE-a | 1 | UniqueFileNames.name in SuiteModel, its plan, C4 sentence, its test | Sources/SuiteModel/Values/UniqueFileNames.swift, Tests/SuiteModelTests/UniqueFileNamesTests.swift, Tests/mutations/SuiteModel.UniqueFileNames.json, docs/c4/parts/creative-apps/suite-model/suite-identity.json | UniqueFileNamesTests (3 mutations) | #1987 | merged 0d7a3db |
| DE-2 | DE-a | 1 | DesignExportScope, DesignExportOptions, LiveExport (fake plan, stub svg), DesignSVG stub, workspace readouts, both slots LiveExport, NotBuilt tests updated, plans, C4 sentence, shape half of DesignExportPlanTests | Sources/DesignModel/DesignExport+Kernel.swift, Sources/DesignModel/Live/DesignSVG.swift, Sources/DesignModel/DesignServices.swift, Sources/DesignModel/DesignWorkspace.swift (one stored field), Tests/DesignModelTests/{DesignLiveStubTests,DesignNotBuiltTests,DesignArrangeFakesTests,DesignExportPlanTests}.swift, Tests/mutations/DesignModel.{DesignServices,DesignExport+Kernel}.json, docs/c4/parts/creative-apps/design-model/design-model-sources.json | DesignExportPlanTests shape half (3 mutations + the repointed DesignServices entry) | #1997 | merged 4f2988a (07:05Z) |
| DE-2b | DE-u | with DE-6 | `public typealias DesignExportRun = ExportRun<DesignExportOptions>` once SuiteKernel is linkable from DesignModel | Sources/DesignModel/DesignExport+Kernel.swift | DesignExportPlanTests shape | – | waits on editor-kernel EK-a and a Package.swift dependency (supervisor) |
| DE-1 | DE-a | – | dropped: each Model task carries its own check (rule 13 "with"); the shape half shipped with DE-2, the rules half and MJ13 go with DE-3, the SVG suites and MJ14 with DE-5 | – | – | – | dropped |
| DE-8 | DE-w | 2 | DesignRasterizer.png over DesignArtwork, DesignRasterizerTests, RenderBudgetDesignRasterTests | Sources/DesignApp/DesignRasterizer.swift, Tests/AppSnapshotTests/{DesignRasterizerTests,RenderBudgetDesignRasterTests}.swift | DesignRasterizerTests.pixelSize (macOS) | – | building |
| DE-3 | DE-s | 3 | the plan: scopes, hidden dropped, UniqueFileNames against existing, pixel sizes, refusals; turns on the rules half and MJ13 | Sources/DesignModel/DesignExport+Kernel.swift, Tests/mutations/DesignModel.DesignExport+Kernel.json, Tests/DesignModelTests/{DesignExportPlanTests,DesignExportWalkTests}.swift | DesignExportPlanTests, MJ13 (7 mutations) | – | building |
| DE-5 | DE-s | 3 | DesignSVG.document per the pseudocode (QD-V8); turns on DesignSVGTests, svgExport budget, MJ14 | Sources/DesignModel/Live/DesignSVG.swift, Tests/mutations/DesignModel.DesignSVG.json, Tests/DesignModelTests/{DesignSVGTests,DesignExportBudgetTests,DesignSVGWalkTests}.swift | DesignSVGTests, MJ14 (7 mutations) | – | building |
| DE-9 | DE-w | 3 | DesignRasterizer.pdf, pdfOnePage test | Sources/DesignApp/DesignRasterizer.swift, Tests/AppSnapshotTests/DesignRasterizerTests.swift | pdfOnePage (macOS) | – | planned |
| DE-6 | DE-u | 4 | File > Export… ⇧⌘E, DesignExportArea hosting SuiteUI ExportSheet on the fakes, ids, launch args, J19 skipped, snapshots, render budget test | per packet | DesignExportSnapshots, J19 | #3389 | merged |
| DE-7 | DE-u | 5 | the run on the fakes, Cancel/Escape/Return, -DesignExportFail, J19 on, J17/J18 skipped | per packet | J19 | #3391 | merged 18:30Z (ad0f902e) |
| DE-10 | DE-z | 6 | real files, never overwriting, progress, rememberExport, J17 on | per packet | J17 | #3684 | open (b4c35e57) |
| DE-11 | DE-z | 7 | failures, Cancel mid-run, blueprint rows, feature-done, Closes #418 | per packet | J18 | #3684 | open (b4c35e57) |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- Run act-1a15a9a4e8b-kn6a (one line lead for design-export, gradient-fill (Design) and autosave-history (Design)): DE-a, DE-s, DE-w done before it; DE-u merged (#3389, #3391). DE-z ships as one PR (DE-10 + DE-11, ~390 lines; files-history FH-b and editor-kernel are built), carrying `feature-done`, `Closes #418` and `Fixes #3528` (Export writes no file).
- PRs target dev, not main: main only takes dev SHAs that passed full CI (CLAUDE.md).
- DE-2b (the `DesignExportRun` typealias) re-homed from DE-a to DE-u: only the App export area reads it, SuiteKernel is not on dev, and DE-a's behaviour (options, scope, slots, readouts, the name rule) is complete and green. Belt-Slice-Done: DE-a posted on run 39018046761 (full CI on 453198a, Linux green).
- DE-1 dropped (10:45Z): after the session lost 06:55 to 10:40Z to a usage limit, a test-only wave ahead of DE-3 and DE-5 costs a serial lane round for nothing rule 13 needs; each Model task merges with its own tests, as DE-2 and DE-0 did. DE-3 owns DesignExportPlanTests and DesignExportWalkTests, DE-5 owns DesignSVGTests, DesignExportBudgetTests and DesignSVGWalkTests, so their files stay disjoint.
- DE-2 as built: `exportPlan` throws `.nothingSelected` itself for an empty selection scope (the slot reads empty ids as every top-level frame); the `defaultsNotAStep` mutation appends to `history.undo` directly because `record` no-ops on an unchanged document; pixel sizes guard non-finite sides (`whole()`), so DE-3 keeps that helper.
- The brief's base fdaabbfb had moved by the time the lead started; the base is origin/dev at start (0e3c08ea52648f6654e583a64ddf07ccb5aa328c), which main also points at.
- PRs target dev per CLAUDE.md (the lane retargets a main-based PR to dev anyway); main moves when full CI on dev is green.
- Rule 13 vs the packet's wave 1: DE-1's suites can't compile against types no code declares yet, so wave 1 is DE-0 and DE-2 (disjoint files, the contract) and DE-1 (the rest of the disabled suites) follows in wave 2, still ahead of DE-3 and DE-5, the code it checks. DE-2 carries the shape half of DesignExportPlanTests and DE-0 its own test, so each code task merges with its check.
- DE-2 drops the `DesignExportRun` typealias: SuiteKernel is not on dev (editor-kernel EK-a) and DesignModel can't depend on it without a Package.swift change, which is protected. DE-2b adds the one line later; the App's run (DE-6) waits on it anyway.
- `exportDefaults` needs one stored field, and an extension can't add one: DE-2 adds `exportOptions` to DesignWorkspace.swift beside `services` (outside the snapshot, so it is never a history step). layers-panel and adopt-kernel-undo also list that file; one added line merges by lines.
- DE-8 waits on neither DE-2 nor DE-1: its signatures use only `DesignExportItem`, which design-contracts put on dev, and its files are new. It started as soon as #1987 merged; DE-1 starts when #1997 merges.
- editor-kernel EK-1 makes every Model depend on SuiteKernel in Package.swift, so DE-2b needs nothing from the supervisor: it waits on EK-a's Belt-Slice-Done line alone.

## Open
- The lead session was rate-limited from about 06:55Z to 10:40Z (the DE-8 builder died at its first step and was resumed); Belt nudged in that window. Nothing was lost on dev.
- dev was red on the app-marks check from #1977 until #1985 merged (06:28Z); #1987 merged dev past it and carries Fast-Check: pass. Commented on #1970.
- editor-kernel has a lead now: EK-1 (the SuiteKernel target) is PR #1992; DE-2b waits on EK-a's Belt-Slice-Done line.
- Follow-ups filed (the packet's list): #1981 SuiteUI ExportSheet scope and scale rows (needs-ui); #1982 SuiteUI one image file writer (needs-ui); #1983 Library LiveExporter uses UniqueFileNames (line:library); #1984 Design Export… in the top bar (line:design, depends on #339).
- No Swift toolchain was on the machine; scripts/cloud-setup.sh installed 6.3.3 (first build warming while wave 1 starts).
- editor-kernel (#1933) has no SuiteKernel on dev yet: DE-2 (ExportRun typealias) and DE-6 (ExportSheet) wait on EK-a and EK-chrome.
- design-window DW-c (DesignWindowOptions.swift), files-history FH-b, snapping SN-c and canvas-basics CB-c are not merged: DE-6 waits.

## Run act-1a14fd6514a-4hke (resumed 2026-10-18)

Resume point: Stage 3, wave 3 on dev@ae72cc6c.

- The previous run's DE-3, DE-5 and DE-8 builders left no PRs, so all three are rebuilt.
- SuiteKernel is linked into the Models (Package.swift), and EK-a, EK-chrome (#2744) and EK-run (#2745) have merged. DE-2b, the `DesignExportRun` typealias, is folded into DE-3 because both edit `DesignExport+Kernel.swift`.
- DE-6 still waits: snapping SN-c and canvas-basics CB-c have not merged, and files-history FH-b is still building.
- No open `finding` issue names design-export.
- Wave 3 builders: DE-3 (the plan, plus DE-2b), DE-5 (the SVG text), DE-8 (the PNG rasterizer).
- Wave 4, next: DE-9 after DE-8; DE-6 and DE-7 once their waits merge.
- The packet's follow-ups are already filed: #1984 (Export… in the top bar), #1981 (ExportSheet scope and scale row), #1982 (one image file writer), #1983 (Library UniqueFileNames), #1989 (ExportSheet host slot).
- Wave 3 PRs:
  - DE-3: #2874 (head 5193c4c0, Mutate 10/10; the 3 mutations from DE-a plus the packet's 7).
  - DE-5: merged as #2869 (head 62bb4782, Mutate 7/7 DesignModel.DesignSVG).
  - DE-8: #2868 (head 9c011357).
- The contract check failed all three on the attribution footer the server adds to PR bodies. I removed it through the GitHub MCP update.
- DE-8 also failed rule 20: the rasterizer held export logic and tree walks in DesignApp. Fix round 1 moved them into DesignModel (DesignRaster.swift, Mutate 5/5 DesignModel.DesignRaster). New head 85924c5b, 8 files, +378/-2.
- Slice done lines: DE-a (run 39018046761).

- 2026-10-18T18:18:09Z: DE-3 #2874 merged; DE-s is fully on dev. DE-8 #2868 waits on its macOS build.
- 2026-10-18T18:40:06Z: DE-8 #2868 merged. DE-9 builder started (wa1s1kr3m). Full CI 39153086055 still pending.
- 2026-10-18T18:47:47Z: DE-9 #2904 (head 6000c666) opened; contract check passed, body clean. DE-w completes when it merges.
- 2026-10-18T19:03Z heartbeat: full CI 39153086055 was cancelled. DE-s waits on scoped design run 39155524227 (dev 2e27b8db), queued. #2904 DE-9 waits on its macOS build; body clean.
- 2026-10-18T19:25Z heartbeat: #2904 DE-9's macOS build 39155906830 is queued. Scoped design run 39155524227 is in progress.
- 2026-10-18T19:44Z: scoped design run 39155524227 (dev 2e27b8db) is green and contains #2869 and #2874, so I posted `Belt-Slice-Done: DE-s` on #1970. The DE-s critic panel (wf_911d45d5-238) is running. #2904 DE-9's macOS build 39155906830 is still queued.
- 2026-10-18T19:47Z: the DE-s critic panel confirmed 4 findings: #2932, #2933 and #2934 are minor canonical-first findings, and #2935 is a major oracle gap in the frames-only scope. Fix round 1 for DE-s is fix-batch wf_522f956e-a97 on dev f7e03506, with DE-9's files marked busy.
- Decision: lead.md stage 3 says a Linux-only slice gets no panel, but DE-s got one. Its findings are real, so they stay in the queue and count as DE-s's round 1.
- 2026-10-18T20:03:36Z heartbeat: #2904 (DE-9) awaiting lane merge. DE-6 still blocked on SN-c (#1552 open) and CB-c (#1500 open). Fix round 1 (wlsqmteyb) running.
- 2026-10-18T20:13:50Z DE-s fix round 1 done: #2949 (hidden rule, UniqueFileNames, frames-only test; mutate 12/12) and #2950 (SuiteModel XMLText; 3/3, 7/7). Follow-up noted: Library FakeExporter still loops its own unique names (line:library). Round 2 is the last for DE-s.
- 2026-10-18T20:24:54Z #2904 (DE-9) merged as 3200018a: all DE-w PRs are on dev. DE-w slice-done waits on a design/full run at or after 3200018a. DE-6 still blocked.
- 2026-10-18T21:11:23Z heartbeat: full CI 39164756292 still pending (DE-w). #2950 waits on its macOS build. DE-6 still blocked (#1552, #1500 open).
- 2026-10-18T21:33:10Z heartbeat: #2950 (fixes #2932, DE-s round 1) merged as 2cc932d1. DE-w now waits on full 39167964719 or scoped design 39167807664. DE-6 still blocked (#1552, #1500).
- 2026-10-18T21:56:05Z heartbeat: full CI 39167964719 was cancelled. DE-w waits on full 39169434591 or scoped design 39167807664. DE-6 still blocked (#1552, #1500).
- 2026-10-18T22:18:50Z heartbeat: scoped design 39167807664 is running; full CI moved to 39171061138. DE-6 still blocked (#1552, #1500).
- 2026-10-18T22:41:39Z heartbeat: DE-w waits on scoped design 39167807664 (contains 3200018a), still running; full CI now 39171756438 (queued). DE-6 still blocked (#1552, #1500 open).
- 2026-10-18T23:07:59Z heartbeat: scoped design 39167807664 does not count. Its design job failed on the `TileCanvasView` compile break that #2990 fixed. DE-w waits on 39173700610 (46f6ce21) or full 39173775025. DE-6 still blocked (#1552, #1500).
- 2026-10-18T23:29:58Z heartbeat: DE-w waits on scoped design 39173700610 (in progress) or full 39176304199 (pending). DE-6 still blocked (#1552, #1500).
- 2026-10-18T23:53:06Z heartbeat: DE-w waits on scoped design 39173700610 (design job in progress) or full 39177967096. No findings are open. DE-6 still blocked (#1552, #1500).
- 2026-10-19T00:17:39Z heartbeat: scoped design 39173700610 macOS job red, so DE-w isn't slice-done. DesignRasterizerTests passed, and none of the failures are in export files. DE-6 is still blocked on #1552 and #1500. Next: 39178639545, 39178441058.
- 2026-10-19T00:39:17Z heartbeat: scoped design 39178639545 is still running. Full run 39178441058 was cancelled. DE-w isn't slice-done yet. DE-6 is still blocked on #1552 and #1500.
- 2026-10-19T01:01:41Z heartbeat: scoped design 39178639545 macOS job red. None of the failures are in DE files, and DesignRasterizerTests passed. DE-w isn't slice-done yet. DE-6 is still blocked on #1552 and #1500. Next: 39182410909, full 39183169319.
- 2026-10-19T01:24:38Z heartbeat: scoped design 39182410909 is running and full 39184285016 is pending. DE-w isn't slice-done yet. DE-6 is still blocked on #1552 and #1500.
- 2026-10-19T01:46:15Z heartbeat: scoped design 39182410909 still running; full 39186699154 (ed0fed9e, contains d1abaef0) pending; earlier fulls cancelled. DE-6 still blocked (#1552, #1500 open).
- 2026-10-19T02:08:30Z heartbeat: scoped design 39182410909 red on 7ccb643d (pre-#3057). J16 failed with the alert contrast that d1abaef0 fixes; every other failure is in the known non-FH/DE set. Full 39186699154 cancelled. Waiting on scoped design 39187798386 (0cb8bb88) and full 39188162085 (17dc84c7). DE-6 still blocked (#1552, #1500 open).
- 2026-10-19T02:29:30Z heartbeat: scoped design 39187798386 (0cb8bb88) still queued behind the macOS runner backlog; full 39188162085 (17dc84c7) pending. DE-6 still blocked (#1552, #1500 open).
- 2026-10-19T02:51:46Z heartbeat: scoped design 39187798386 (0cb8bb88) macOS job in progress; full 39188162085 pending. DE-6 still blocked (#1552, #1500 open).
- 2026-10-19T03:15Z heartbeat: scoped design 39187798386 (0cb8bb88) red; J16 now passes; every failure is in the known non-FH/DE set (P4 is the shared perf-probe 'no window opened'); full 39188162085 cancelled; waiting on scoped design 39193348540 and full 39192572958 (cc14022e, queued); DE-6 still blocked (#1552, #1500 open).
- 2026-10-19T03:36Z heartbeat: scoped design 39193348540 and full 39192572958 (cc14022e) still queued on the macOS runner (full's Linux green); no newer design run; no open dev-red; DE-6 still blocked (#1552, #1500 open).
- 2026-10-19T03:58Z heartbeat: scoped design 39193348540 (cc14022e) macOS job running since 03:50Z; full 39192572958 still queued; newer full 39196649963 (7acc00bf) pending; no open dev-red; DE-6 still blocked (#1552, #1500 open).
- 2026-10-19T04:23Z heartbeat: scoped design 39193348540 (cc14022e) macOS red only on non-DE tests; every DE suite passed; DE-w slice-done held, raised on #1970; DE-6 still blocked (#1552, #1500 open).
- 2026-10-19T04:46Z heartbeat: no design macOS run finished: full 39192572958 macOS still running, scoped design 39198969299 (9f098e23, has 3200018a) running; DE-w slice-done held; DE-6 blocked (#1552, #1500 open); no supervisor reply.
- 2026-10-19T05:09Z heartbeat: scoped design 39198969299 (9f098e23, has 3200018a) macOS red only on non-DE tests; no DE test failed; DE-w slice-done held; DE-6 blocked (#1552, #1500 open); no supervisor reply.
- 2026-10-19T05:30Z heartbeat: no design macOS run finished (39192572958 running, scoped design 39204091833 queued); DE-w slice-done held; DE-6 blocked (#1552, #1500 open); no supervisor reply.
- 2026-10-19T05:56Z heartbeat: no qualifying run for DE-w (39203617095, 39204091833 queued); DE-6 deps #1552 #1500 open; no supervisor reply.
- 2026-10-19T06:25Z heartbeat: no qualifying run for DE-w yet (39204091833 in progress, 39203617095 and 39208339251 queued); DE-6 deps #1552 #1500 open; no supervisor reply.
- 2026-10-19T06:49Z heartbeat: no qualifying run for DE-w (39204091833 macOS red on non-DE tests; 39203617095 queued; 39211721703 queued); DE-6 deps #1552 #1500 open; no supervisor reply.
- 2026-10-19T07:18Z heartbeat: no qualifying run for DE-w (39211721703 queued, 39203617095 macOS in progress); DE-6 deps #1552 #1500 open; no supervisor reply.
- 2026-10-19T07:46Z heartbeat: no qualifying run for DE-w (39211721703 queued, 39203617095 macOS in progress); DE-6 deps #1552 #1500 open; no supervisor reply.
Last check: 2026-10-20T00:14:12Z (#1500 closed; DE-u blocked on #1552, EK-chrome or a supervisor go)

## Run act-1a156b3f640-ytq0
- 2026-10-20T00:26Z supervisor go on #1970: DE-u (DE-6 + DE-7) goes first.
- Decision: no window-files handoff swap needed: snapping SN-8 merged as #3282 and canvas-basics #1500 is closed; EK-chrome, DW-c, FH-b done. DE-2b is already folded in (DesignExportRun typealias on dev).
- Decision: lead/design-export rebuilt from origin/dev plus this record, not rebased on main: main trails dev, and slice PRs target dev (CLAUDE.md, fast lane).
- Decision: DE-6 + DE-7 come to ~620 lines, over the 400 cap; DE-u ships as a DE-6 PR plus a stacked DE-7 PR when one PR would exceed the cap.
- Findings queue for design-export: empty at 00:30Z.
- DE-u merged-done: ci.yml on dev a48992b7 (run 39479914225, Linux green) contains #3389 and #3391; Belt-Slice-Done posted on #1970 (comment 6299503101). Run 39475897385 on 875b44d2 still pending, superseded.
