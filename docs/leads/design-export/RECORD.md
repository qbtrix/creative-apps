# design-export lead record

Issue: #1970 · Packet: docs/blueprints/design/features/design-export.md
Run: act-1a14852c11d-65cg · Session: (cloud) · Started: 2026-10-17T05:59Z
Stage: 1 packet
Base: 0e3c08ea52648f6654e583a64ddf07ccb5aa328c
Next: finish reading the packet and the code it touches, then plan the waves (stage 2)

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
| DE-1 | DE-a | 1 | the Model tests from the packet, disabled by name | Tests/DesignModelTests/DesignExportPlanTests.swift, DesignSVGTests.swift, DesignExportBudgetTests.swift, DesignExportWalkTests.swift, DesignSVGWalkTests.swift, Tests/SuiteModelTests/UniqueFileNamesTests.swift | every suite compiles and skips | – | planned |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- The brief's base fdaabbfb had moved by the time the lead started; the base is origin/dev at start (0e3c08ea52648f6654e583a64ddf07ccb5aa328c), which main also points at.
- PRs target dev per CLAUDE.md (the lane retargets a main-based PR to dev anyway); main moves when full CI on dev is green.

## Open
- editor-kernel (#1933) has no SuiteKernel on dev yet: DE-2 (ExportRun typealias) and DE-6 (ExportSheet) wait on EK-a and EK-chrome.
- design-window DW-c (DesignWindowOptions.swift), files-history FH-b, snapping SN-c and canvas-basics CB-c are not merged: DE-6 waits.
