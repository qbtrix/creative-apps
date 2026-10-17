# design-export lead record

Issue: #1970 · Packet: docs/blueprints/design/features/design-export.md
Run: act-1a14852c11d-65cg · Session: (cloud) · Started: 2026-10-17T05:59Z
Stage: 3 wave 1
Base: 0e3c08ea52648f6654e583a64ddf07ccb5aa328c
Next: wave 1 (DE-0, DE-2) builders are running; when their PRs merge, run the check and start wave 2 (DE-1, DE-8)

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| DE-a | options, scope, run type, live and fake export slots plan like the fake, UniqueFileNames in SuiteModel | DE-1, DE-0, DE-2 | MJ13 | design-contracts (built); editor-kernel EK-a (DE-2) | no | 0 | building | – | – |
| DE-u | File > Export… ⇧⌘E opens SuiteUI ExportSheet on the fakes; Export runs the fake steps; Cancel/Escape close; a failed step names its file | DE-6, DE-7 | J19 | DE-a; design-window DW-c; files-history FH-b; snapping SN-c; canvas-basics CB-c; editor-kernel EK-chrome | yes | 0 | waiting | – | – |
| DE-s | the plan picks layers per scope, unique names, sizes per scale, refusals; SVG equals the reference | DE-3, DE-5 | MJ13, MJ14 | DE-a | no | 0 | waiting | – | – |
| DE-w | PNG at 1x/2x/3x and one-page PDF off the window from the canvas artwork | DE-8, DE-9 | DesignRasterizerTests | DE-a | yes | 0 | waiting | – | – |
| DE-z | real files, never overwriting, progress, failures, journeys on live | DE-10, DE-11 | J17, J18 | DE-u, DE-s, DE-w; files-history FH-b; editor-kernel EK-run | yes | 0 | waiting | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| DE-0 | DE-a | 1 | UniqueFileNames.name in SuiteModel, its plan, C4 sentence, its test | Sources/SuiteModel/Values/UniqueFileNames.swift, Tests/SuiteModelTests/UniqueFileNamesTests.swift, Tests/mutations/SuiteModel.UniqueFileNames.json, docs/c4/parts/creative-apps/suite-model/suite-identity.json | UniqueFileNamesTests (3 mutations) | – | building |
| DE-2 | DE-a | 1 | DesignExportScope, DesignExportOptions, LiveExport (fake plan, stub svg), DesignSVG stub, workspace readouts, both slots LiveExport, NotBuilt tests updated, plans, C4 sentence, shape half of DesignExportPlanTests | Sources/DesignModel/DesignExport+Kernel.swift, Sources/DesignModel/Live/DesignSVG.swift, Sources/DesignModel/DesignServices.swift, Sources/DesignModel/DesignWorkspace.swift (one stored field), Tests/DesignModelTests/{DesignLiveStubTests,DesignNotBuiltTests,DesignArrangeFakesTests,DesignExportPlanTests}.swift, Tests/mutations/DesignModel.{DesignServices,DesignExport+Kernel}.json, docs/c4/parts/creative-apps/design-model/design-model-sources.json | DesignExportPlanTests shape half (3 mutations + the repointed DesignServices entry) | – | building |
| DE-2b | DE-a | later | `public typealias DesignExportRun = ExportRun<DesignExportOptions>` once SuiteKernel is linkable from DesignModel | Sources/DesignModel/DesignExport+Kernel.swift | DesignExportPlanTests shape | – | waits on editor-kernel EK-a and a Package.swift dependency (supervisor) |
| DE-1 | DE-a | 2 | the remaining packet tests, disabled by name: DesignExportPlanTests rules half, DesignSVGTests, DesignExportBudgetTests, DesignExportWalkTests (MJ13), DesignSVGWalkTests (MJ14) | Tests/DesignModelTests/{DesignExportPlanTests,DesignSVGTests,DesignExportBudgetTests,DesignExportWalkTests,DesignSVGWalkTests}.swift | every suite compiles and skips | – | planned |
| DE-8 | DE-w | 2 | DesignRasterizer.png over DesignArtwork, DesignRasterizerTests, RenderBudgetDesignRasterTests | Sources/DesignApp/DesignRasterizer.swift, Tests/AppSnapshotTests/{DesignRasterizerTests,RenderBudgetDesignRasterTests}.swift | DesignRasterizerTests.pixelSize (macOS) | – | planned |
| DE-3 | DE-s | 3 | the plan: scopes, hidden dropped, UniqueFileNames against existing, pixel sizes, refusals; turns on the rules half and MJ13 | Sources/DesignModel/DesignExport+Kernel.swift, Tests/mutations/DesignModel.DesignExport+Kernel.json, Tests/DesignModelTests/{DesignExportPlanTests,DesignExportWalkTests}.swift | DesignExportPlanTests, MJ13 (7 mutations) | – | planned |
| DE-5 | DE-s | 3 | DesignSVG.document per the pseudocode (QD-V8); turns on DesignSVGTests, svgExport budget, MJ14 | Sources/DesignModel/Live/DesignSVG.swift, Tests/mutations/DesignModel.DesignSVG.json, Tests/DesignModelTests/{DesignSVGTests,DesignExportBudgetTests,DesignSVGWalkTests}.swift | DesignSVGTests, MJ14 (7 mutations) | – | planned |
| DE-9 | DE-w | 3 | DesignRasterizer.pdf, pdfOnePage test | Sources/DesignApp/DesignRasterizer.swift, Tests/AppSnapshotTests/DesignRasterizerTests.swift | pdfOnePage (macOS) | – | planned |
| DE-6 | DE-u | 4 | File > Export… ⇧⌘E, DesignExportArea hosting SuiteUI ExportSheet on the fakes, ids, launch args, J19 skipped, snapshots, render budget test | per packet | DesignExportSnapshots, J19 | – | waits on DE-2b, editor-kernel EK-chrome, design-window DW-c, files-history FH-b, snapping SN-c, canvas-basics CB-c |
| DE-7 | DE-u | 5 | the run on the fakes, Cancel/Escape/Return, -DesignExportFail, J19 on, J17/J18 skipped | per packet | J19 | – | waits on DE-6 |
| DE-10 | DE-z | 6 | real files, never overwriting, progress, rememberExport, J17 on | per packet | J17 | – | waits on DE-7, DE-3, DE-5, DE-9, editor-kernel EK-run |
| DE-11 | DE-z | 7 | failures, Cancel mid-run, blueprint rows, feature-done, Closes #418 | per packet | J18 | – | waits on DE-10, files-history FH-b |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- The brief's base fdaabbfb had moved by the time the lead started; the base is origin/dev at start (0e3c08ea52648f6654e583a64ddf07ccb5aa328c), which main also points at.
- PRs target dev per CLAUDE.md (the lane retargets a main-based PR to dev anyway); main moves when full CI on dev is green.
- Rule 13 vs the packet's wave 1: DE-1's suites can't compile against types no code declares yet, so wave 1 is DE-0 and DE-2 (disjoint files, the contract) and DE-1 (the rest of the disabled suites) follows in wave 2, still ahead of DE-3 and DE-5, the code it checks. DE-2 carries the shape half of DesignExportPlanTests and DE-0 its own test, so each code task merges with its check.
- DE-2 drops the `DesignExportRun` typealias: SuiteKernel is not on dev (editor-kernel EK-a) and DesignModel can't depend on it without a Package.swift change, which is protected. DE-2b adds the one line later; the App's run (DE-6) waits on it anyway.
- `exportDefaults` needs one stored field, and an extension can't add one: DE-2 adds `exportOptions` to DesignWorkspace.swift beside `services` (outside the snapshot, so it is never a history step). layers-panel and adopt-kernel-undo also list that file; one added line merges by lines.
- DE-8 waits on DE-2 rather than all of DE-a: it needs only the export types, and DE-1 is tests alone. It runs in wave 2 beside DE-1.
- editor-kernel EK-1 makes every Model depend on SuiteKernel in Package.swift, so DE-2b needs nothing from the supervisor: it waits on EK-a's Belt-Slice-Done line alone.

## Open
- Follow-ups filed (the packet's list): #1981 SuiteUI ExportSheet scope and scale rows (needs-ui); #1982 SuiteUI one image file writer (needs-ui); #1983 Library LiveExporter uses UniqueFileNames (line:library); #1984 Design Export… in the top bar (line:design, depends on #339).
- No Swift toolchain was on the machine; scripts/cloud-setup.sh installed 6.3.3 (first build warming while wave 1 starts).
- editor-kernel (#1933) has no SuiteKernel on dev yet: DE-2 (ExportRun typealias) and DE-6 (ExportSheet) wait on EK-a and EK-chrome.
- design-window DW-c (DesignWindowOptions.swift), files-history FH-b, snapping SN-c and canvas-basics CB-c are not merged: DE-6 waits.
