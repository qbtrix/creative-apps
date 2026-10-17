# shell-parity lead record

Issue: #1325 · Packet: docs/blueprints/design/features/shell-parity.md
Run: act-1a149c0c306-8ckd (before: act-1a1487bf8e3-hwdj; first run act-1a14478b134-5to5) · Session: claude/design-shell-parity-lead-0l668u · Started: 2026-10-16T12:00Z
Stage: done
Base: 0e3c08ea52648f6654e583a64ddf07ccb5aa328c
Next: nothing. Feature done: DP-a done (38956034097), DP-b done with gaps #1452 #1572 #1573 #1617 #1618 #1877 #1878 #1993 #1994 (38971702274), Belt-Contact-Sheet posted on #1325. The gaps close when SuiteUI #1456 lands. This branch was recut onto main on 2026-10-17 (Belt: 290 commits behind).

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| DP-a | The toolbar's eight commands each act or say why, and Add Page and Delete Page sit in a row under the pages. | DS-1, DS-2 | J3 | editor-in-window APIs (on dev) | no | 2 | done | 38956034097 | – |
| DP-b | Design opens in the suite window with pages and layers in the sidebar, Properties in the inspector and the floating tool box over the canvas, in light and dark. | DS-3, DS-4 | J0, DS-J1..DS-J5 | DP-a (DS-3) | no | 2 | done-with-gaps (#1452 #1572 #1573 #1617 #1618 #1877 #1878 #1993 #1994) | 38971702274 | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| DS-1 | DP-a | 1 | DesignToolbarItem: eight commands, titles, symbols, identifiers, reasons | Sources/DesignModel/DesignToolbarItems.swift, Tests/DesignModelTests/DesignToolbarItemsTests.swift, Tests/mutations/DesignModel.DesignToolbarItems.json | DesignToolbarItemsTests + Mutate 6/6 | #1335 | merged |
| DS-2 | DP-a | 1 | Page actions under Pages become a SidebarActionRow | Sources/DesignApp/DesignLayersPanel.swift, Tests/AppSnapshotTests/DesignLayersSnapshots.swift, UITests/DesignJourneyTests.swift | core journey asserts design.page.add/delete; DesignLayersSnapshots | #1329 | merged |
| DS-3 | DP-b | 2 | DesignEditor on SuiteWindow + EditorDetail, floating palette; DesignTopBar/DesignPanel tabs go | DesignEditor, DesignPanel, DesignIntent, DesignWindow, DesignApp, DesignJourneyTests, 3 snapshot files | every Design journey on the scoped run | #1391 | merged |
| DS-4 | DP-b | 1 | Shell journey steps 1-5 with geometry, merged skipped ("waits on DS-3") | UITests/DesignJourneyTests+Shell.swift | DesignJourneyTests+Shell on the scoped run, once DS-3 enables it | #1330 | merged |
| DS-5 | DP-b | 3 | feature-done: wave.json status built + feature issue | docs/blueprints/design/features/shell-parity.wave.json | scripts/ci renders waves | #1610 | merged (c97f2782) |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|
| DP-a | 38906785154 | b2e5453c | clarity, journey, design, layout, controls, oracle | #1385 (major), #1386, #1387 | 0 |
| DP-b | 38917492060 (CI lens: failed journeys) | fb72b7e5 | journey (CI) | #1443 (blocker), #1444 | 0 |
| DP-a, DP-b | 38931490731 (CI: failed journeys) | 82b239c9 | journey, layout (CI) | #1451 (DP-a), #1452 (DP-b) | 1 |
| DP-b | 38991865764 (CI findings) | 6c4ad16a | journey (CI) | #1877, #1878 (same geometry as #1456) | 2 (cap reached: relabelled gap) |

## Decisions
- 2026-10-17T13:30Z: CI findings #1993/#1994 (DesignShellJourneyTests light/dark at 93c2103, run 39033633296) repeat #1877/#1878 (SuiteUI #1456). DP-b is past its 2 rounds, so both relabelled `gap` and added to the gap list. No new Design PR.
- 2026-10-17 relaunch: CI findings #1877 and #1878 (DesignShellJourneyTests light/dark, `suite.inspector` 280 under 304 and the column overlaps) repeat #1572/#1573 at a newer commit. DP-b has used its 2 fix rounds and the cause is SuiteUI's #1456, so both are relabelled `gap` under rule 11 and added to DP-b's gap list. No new Design PR.
- Belt asked for lead/shell-parity to be rebased onto main: the branch was recut from main 0e3c08e with the docs/leads records carried over (shell-parity, and photo-shell-parity which an earlier lead kept on this branch); docs/leads/switching keeps main's copy.
- DP-a done on run 38956034097 (successful under the 18:13 policy: journeys report findings, don't fail the run). CI filed #1572/#1573 for DP-b's shell journeys; both relabelled gap (round cap) with #1452. DP-b closes with gaps on the run that contains DS-5 #1610, per the supervisor's "macOS journeys never hold you". #1337 (switcher) merged on dev at 72c5aeab.
- Supervisor note 18:13: CI now blocks only on compile and Model tests; journeys report findings and never hold a slice. Our slices carry no "ui": true, so rules 15/17 (feel gate, Mac finisher) don't apply.
- Wave 1: DS-1 and DS-2 independent (disjoint files). Wave 2: DS-3 waits on DS-1 and DS-2. DS-4 moved to wave 1 under contract rule 13 (acceptance journey before code), merged with `throw XCTSkip("waits on DS-3")`; DS-3 removed the skips. The feature-done label moved to a small DS-5 (wave.json status) after DS-3.
- DP-a's wait on editor-in-window (#1079): every API this feature uses was on dev at the base, so the wait was met for code.
- PRs target dev (CLAUDE.md; the lane retargets main to dev). Builder branches were sp/<task>.
- Fixers were briefed directly (Agent per finding), not via fix-batch.js (branch-name collision with lead/shell-parity).

## Open
- gap #1452, #1572, #1573, #1617, #1618, #1877, #1878 (DP-b): all SuiteUI's needs-ui #1456 (EditorDetail regions bleed under the floating sidebar/inspector, suite.inspector lands inside SuiteWindow's padding at 280 vs 304). DP-b's geometry assertions stay until it lands; the next green shell journey closes them through CI's findings job.
- gap #1561 (from the editor-in-window lead): fixed by #1655 (e16a3edd).
- #1079 editor-in-window still open (needs-human); not blocking code.
- 2026-10-17T14:04Z heartbeat: dev 25b220e4; no DW-a/DW-b, EK-tree or LL-9 merge or open PR; nothing unblocked. CI findings #2074 #2075 #2083-#2087 (scoped design run 39037761414 at d2c4fa21) all fail at launch: 'Application org.creativesuite.design does not have a process ID'. App-launch infra (bundle packaging, cf #2099 line:suite, after #2073), not in this feature's files and carry no Feature: line; not counted as this feature's findings, not fixed here.
- 2026-10-17T14:20Z heartbeat: dev 8c05d002 (Flare merges only); no DW-a/DW-b, EK-tree or LL-9 merge or open PR; nothing unblocked; full CI 39036875578 macOS still running; no new line:design findings.
- 2026-10-17T14:36Z heartbeat: dev 8c05d002 unchanged; no DW-a/DW-b, EK-tree or LL-9 merge or open PR; nothing unblocked; full CI 39036875578 macOS still running; no new line:design findings.
- 2026-10-17T14:52Z heartbeat: dev 2c5003b5 (Flare/Halo merges only); no DW-a/DW-b, EK-tree or LL-9 merge or open PR; nothing unblocked; full CI 39036875578 macOS still running; no new line:design findings.
