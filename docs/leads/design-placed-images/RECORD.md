# placed-images lead record

Issue: #3454 · Packet: docs/blueprints/design/features/placed-images.md
Run: act-1a16cc9673d-cmzv · Session: claude/feature-lead-placed-images-dkjo55 · Started: 2026-10-24T07:20Z (prior runs act-1a16953aed5-oxsi, act-1a15da1b26c-9qo6, act-1a15ac70747-ky1f)
Stage: 3 wave 1 (17:30Z): PD-a #3759 pushed 3fc0a384 (dev merge + format-ratchet fix), gate rerun waiting on load; PD-m #4922 open (stacked on #3759, gate PASS); PD-u gating on design/pd-u-place-canvas (PD-a + DK-u #4864)
Base: 721168a8 (origin/dev); main verified at cb79cbb6
Next: supervisor merges #3759; PD-u and PD-m slice PRs stacked on design/pd-a-placed-image-stubs; then PD-z

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| PD-a | picture fields and PlacedImageTarget stubs, CoreRaster linked, checks and RJ-D12 written disabled | PD-1, PD-2 | MJ-PD | PL-a; gradient-fill:DG-a; transform:DT-a; shape-tools:DS-a; stroke-style:DK-m | no | 0 | open #3759 (supervisor-queued) | – | – |
| PD-u | Place… and drop on the stubs, canvas draws by cover, inspector rows | PD-3, PD-4 | DJ-P1 | PD-a; DG-u; DE-u; PL-3; DA-a; DT-a; DT-u; DS-a; DS-u; DK-u | yes | 0 | waiting | – | – |
| PD-m | fill into frame, focus as one step, SVG crop | PD-5, PD-6 | MJ-PD | PD-a; DG-m; DE-s; PL-7; DA-m; DT-m; DY-m; DS-m; DK-m | no | 1 | open #4922 (stacked on #3759) at 2412a61a: round 1 fixed #4930, #4933-#4935; #4931 (no clear fill) and part of #4932 (kernel availability) left; round 2 critic running | – | – |
| PD-z | live journey, blueprint, feature-done | PD-7, PD-8 | DJ-P1 | PD-u, PD-m; DG-z | yes | 0 | waiting | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| PD-1 | PD-a | 2 | node fields, conformance stubs, CoreRaster link | Sources/DesignModel/DesignNode.swift, Sources/DesignModel/DesignPlace+Kernel.swift, Package.swift, Tests/DesignModelTests/DesignPlaceTests.swift | fixtures byte-equal; copy keeps picture | – | waiting |
| PD-2 | PD-a | 2 | SVG checks and RJ-D12 disabled | Tests/DesignModelTests/DesignPlaceSVGTests.swift, Tests/RealJobs/design/place-in-frame/ | compiles, disabled | – | waiting |
| PD-3 | PD-u | 3 | Place…, drop, ⌥-drag focus, drawPlaced | Sources/DesignApp/DesignPlace.swift, Sources/DesignApp/DesignCommands.swift, Sources/DesignApp/DesignCanvas.swift, Sources/DesignApp/DesignCanvasMarks.swift | DesignPlaceSnapshots.inFrame | – | waiting |
| PD-4 | PD-u | 3 | inspector image rows, snapshots, budget, journey skipped | Sources/DesignApp/DesignInspectorImage.swift, Sources/DesignApp/DesignInspector.swift, Tests/AppSnapshotTests/DesignPlaceSnapshots.swift, Tests/AppSnapshotTests/RenderBudgetDesignPlaceTests.swift, UITests/DesignJourneyTests+Place.swift | DesignPlaceSnapshots | – | waiting |
| PD-5 | PD-m | 3 | conformance bodies, specs | Sources/DesignModel/DesignPlace+Kernel.swift, Sources/DesignModel/DesignCommandCatalog.swift, Tests/command-ids/design.txt, Tests/DesignModelTests/DesignPlaceTests.swift, Tests/mutations/DesignModel.DesignPlace+Kernel.json | DesignPlaceTests | – | waiting |
| PD-6 | PD-m | 4 | SVG image with clip | Sources/DesignModel/Live/DesignSVG.swift, Tests/DesignModelTests/DesignPlaceSVGTests.swift, Tests/mutations/DesignModel.DesignSVG.json, Tests/RealJobs/design/place-in-frame/ | DesignPlaceSVGTests, RJ-D12 | – | waiting |
| PD-7 | PD-z | 5 | journey on live | UITests/DesignJourneyTests+Place.swift | testPlacePhotoInFrame | – | waiting |
| PD-8 | PD-z | 6 | design.md, status built | docs/blueprints/design.md, docs/blueprints/design/features/placed-images.wave.json | scripts/waves render --dry-run | – | waiting |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- 2026-10-24 run act-1a16cc9673d-cmzv: resumed; brief main HEAD 654fb363 verified, dev 830af22d. Status branches stay lead/design-*; PRs target dev. All slice PRs are clean and wait on the lane (PD-a #3759 on the supervisor); no new feature task while open findings exceed 5.
- 2026-10-23 run act-1a16953aed5-oxsi: contract-first waits (lead.md rule 12, supervisor 15:11Z): every other feature's contract slice has merged (stroke-style DK-a, design-export, gradient/transform/shape-tools/eyedropper built), so PD-u and PD-m start now, stacked on PD-a #3759 since PD-a is this feature's own contract. One lead holds placed-images and stroke-style.
- PRs target dev (CLAUDE.md); brief's main HEAD b3011ab9 verified, work branches from origin/dev a48992b7.
- PD-1 touches Package.swift (protected): the packet says the supervisor merges it after the macOS build; the PR will say so.

## Open
- [ ] Wire: stroke-style:DK-m (PD-a/PD-m built before DesignStroke = VectorStroke; recheck DesignNode.swift when DK-m merges)
- [ ] Wire: stroke-style:DK-u (PD-u built before the canvas strokes paintedPath; recheck DesignCanvasMarks.swift when DK-u merges)
- PD-a blocked: suiteui placed-images PL-a not merged (kernel Place stubs #3578 and bodies #3626 merged; SuiteUI slice not yet), gradient-fill DG-a (#3687 open), transform DT-a (this run, waits on DG-a), shape-tools DS-a and stroke-style DK-m (no PR found).
- 2026-10-23 PD-m round 1: the GitHub write path re-appends a "Generated by Claude Code" footer to PR bodies and issue comments (#4922 body; comments on #4930-#4935). Edits can't remove it; it needs deleting by hand. The fast lane strips it from squash commits.

## 2026-10-23T20:36Z PD-m fix round 2

- #4922 is now at head 614b8785. It fixes #4959: a placed picture is refitted inside the frame under its centre. CI: PASS, and the DesignPlace+Kernel mutations are 11/11.
- PD-m has used both of its fix rounds. Gaps filed: #4990 (no clear fill; from #4931) and #4991 (Replace, Reset Size and focus stay available on a locked picture; the rest of #4932).
- PD-u round-1 fixer: its u2 gate is running.
- DK-u fixer: #4925-#4928 and #4989 are in progress.
- DK-z and PD-z are held: open findings are above 5.

## 2026-10-23T20:44Z PD-u fix round 1

- #4963 is at 6a4229b4: 7 files, 400 lines, DesignPlace+Canvas mutations 12/12. It fixes #4974 and #4976-#4979. #4971 is fixed in the Model part only.
- #4964 is at caab1ba5: 15 files, 398 lines, DesignPlace+Inspector mutations 8/8. It fixes #4966-#4969, #4980 and #4981. #4970, #4972, #4973 and #4975 are partly fixed; their SuiteUI parts are filed as needs-ui #4985.
- Both PR bodies now carry the new Head lines and Fixes lines, with no footer.
- The PD-u round-2 critic has started.

## 2026-10-23T20:59Z PD-u critic round 2

- 12 of the 16 claimed fixes hold. #4970, #4972, #4973 and #4975 are partial.
- New findings: #4992 (major: ⌥-drag pans with several layers selected or another layer on top), #4993 (a drop on a rotated frame tests the unrotated box) and #4994 (Place in Frame… is enabled on a locked frame).
- Fix round 2, PD-u's last: one new PR stacked on #4964, because #4963 and #4964 are at their size caps.
- Gaps filed: #4996 (the ⌥-drag pan pointer and hint), #4997 (the kernel's place wording) and #4998 (the hand-drawn drop ring). #4970 and #4972 continue in needs-ui #4985.

## 2026-10-23T21:40Z PD-u fix round 2

- #5001 is at 3ecf2a5e: 7 files, 113 lines, stacked on #4964. It fixes #4992, #4993 and #4994. CI: PASS. Mutations: DesignPlace+Canvas 14/14, DesignPlace+Inspector 11/11.
- The PR body and the builder's three issue comments had the attribution footer. I rewrote them via MCP without it.
- PD-u has used both of its fix rounds. Its leftovers are gaps #4996-#4998, and its SuiteUI parts are in #4985.
