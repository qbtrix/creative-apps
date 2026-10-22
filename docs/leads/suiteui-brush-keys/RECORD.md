# brush-keys lead record

Issue: #3758 (#4531 was a duplicate, closed 18:08) · Packet: docs/blueprints/suiteui/features/brush-keys.md
Run: act-1a164855f49-5pe1 · Session: cloud line lead (line:suiteui, with #4528) · Started: 2026-10-22T16:52Z
Stage: 3 wave 3 (blocked)
Base: 3578eaee20f317d368feda7ba35e4911285eebc5
Next: STOPPED 2026-10-22T18:15:42Z: supervisor closed #4531 as a duplicate of #3758 and asked the lead to stop and record its work there (comment on #3758). BK-u..BK-z remain, all blocked on other features.

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| BK-a | contract: BrushKeys stubs, BrushKeyCommands specs, disabled tests | BK-1, BK-2 | – | – | false | 0 | done (#4057; Linux 39643409752; Belt-Slice-Done posted) | – | – |
| BK-m | step bands, hardness, opacity digits; mutation plan; C4 part | BK-3, BK-4 | – | BK-a | false | 0 | done (#4058 → 1fe5c4ea; Linux 39661533247; Belt-Slice-Done posted) | – | – |
| BK-u | ToolKeys routing, readout, gallery, journey, render budget | BK-5, BK-6 | SJ-BK | BK-a; anchor-parenting:AN-u (planned; waits OC-u) | true | 0 | blocked | – | – |
| BK-photo | Photo adopts brush keys | BK-7, BK-8 | – | BK-a (BK-7); BK-m, BK-u, adopt-kernel-brush:AB-photo, adopt-suiteui-chrome:AC-colour, area-selection:AR-photo-u (not started), OC-photo-m (BK-8) | true | 0 | blocked | – | – |
| BK-design | Design adopts brush keys | BK-9, BK-10 | – | BK-m, BK-u, adopt-suiteui-chrome:AC-tools, document-setup:DS-design (not started) (BK-10) | true | 0 | blocked | – | – |
| BK-flare | Flare adopts brush keys | BK-11, BK-12 | – | BK-m, BK-u, anchor-parenting:AN-flare-u (not started) (BK-12) | true | 0 | blocked | – | – |
| BK-z | RJ-X76 on; status built; feature-done | BK-13, BK-14 | RJ-X76 | BK-photo, BK-design, BK-flare | false | 0 | blocked | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| BK-1 | BK-a | 1 | stubs + six CommandSpecs | Sources/SuiteKernel/Stroke/BrushKeys.swift, Sources/SuiteKernel/Stroke/BrushKeyCommands.swift | CommandShapeTests | #4057 66acfc5a | merged |
| BK-2 | BK-a | 1 | disabled BrushKeysTests | Tests/SuiteKernelTests/BrushKeysTests.swift | BrushKeysTests (disabled) | #4057 | merged |
| BK-3 | BK-m | 2 | bodies + plan SuiteKernel.BrushKeys | Sources/SuiteKernel/Stroke/BrushKeys.swift, Tests/SuiteKernelTests/BrushKeysTests.swift, Tests/mutations/SuiteKernel.BrushKeys.json | BrushKeysTests; mutate (5/5) | #4058 4987a228 | merged |
| BK-4 | BK-m | 2 | C4 part kernel-stroke | docs/c4/parts/creative-apps/suite-kernel/kernel-stroke.json | scripts/ci C4 | #4060 merged fb6f4b83 (docs-only; existing part description can only change in a docs-only PR) | merged |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- 2026-10-21T11:26Z: one PR per slice (brief rule 8): BK-1+BK-2 ship as the BK-a PR; BK-3+BK-4 as BK-m stacked on it.
- 2026-10-21T11:26Z: app slices start only when their external waits clear; their test-first tasks (BK-7, BK-9, BK-11) ride in the slice PR, not alone.
- 2026-10-21T11:26Z: anchor-parenting, document-setup and area-selection have no lead branch or issue: BK-u and every app slice are blocked on them.

## Open
- BK-u blocked: anchor-parenting:AN-u (feature not started).
