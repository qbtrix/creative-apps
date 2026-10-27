# stroke-style lead record (Design)

Issue: #3441 · Packet: docs/blueprints/design/features/stroke-style.md
Run: act-1a17be7aff8-ivwy · Started: 2026-10-23 (this run resumed 2026-10-27T05:55Z; prior act-1a178669406-n4me)
Stage: 3 #5011 merged to dev at c21b2834 (2026-10-27T08:07Z; closes findings #5009 #5010 #4928); #5825 waits on lane; dev-red #5818 open
Base: origin/dev; main verified at fef52e66
Next: a green design-scoped or full ci.yml run on dev at or after c21b2834: Belt-Slice-Done DK-u (gaps #4990 #4991). When #5825 lands and a green run holds it: Belt-Slice-Done DK-z, then Belt-Contact-Sheet

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| DK-a | stroke adapter stubs, vectorStroke, Stroke section is StrokeEditor | DK-1, DK-2 | MJ-DK | SS-a (done) | yes | 2 | done; gaps #3865 #3871 #3873 | 39670298178 | wanted (posted) |
| DK-u | canvas strokes dashes, joins, caps; snapshots, budget | DK-3, DK-4 | J-DK | DK-a, shape-tools:DS-u | yes | 2 | #4864, #5002 (fa5d340f) and #5011 (c21b2834) merged; rounds spent; gaps #4990 #4991 | – | – |
| DK-m | DesignStroke is VectorStroke; commands; SVG | DK-5, DK-6, DK-7 | MJ-DK | DK-a, shape-tools:DS-m; SS-d | no | 2 | #4888 merged (63592c7b); #4916 merged (9810d71b); rounds spent | done: https://github.com/qbtrix/creative-apps/actions/runs/40414010435 | – |
| DK-z | journey on live; built | DK-8, DK-9 | J-DK | DK-u, DK-m | yes | 0 | #5825 open (findings #5009 #5010 closed by #5011) | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| DK-1 | DK-a | 1 | adapter and vectorStroke stubs | Sources/DesignModel/DesignStroke+Kernel.swift, Tests/DesignModelTests/DesignStrokeTests.swift | DesignStrokeTests | #3690 | merged |
| DK-2 | DK-a | 1 | Stroke section is StrokeEditor | Sources/DesignApp/DesignInspectorStyle.swift, UITests/DesignJourneyTests+Stroke.swift | DesignInspectorSnapshots | #3690 | merged |
| DK-3 | DK-u | 2 | canvas paints StrokeRules.paintedPath | Sources/DesignApp/DesignCanvas*.swift, Sources/DesignModel/DesignStrokeOutline.swift | DesignStrokeOutlineTests | #4864, #5002, #5011 | merged |
| DK-4 | DK-u | 2 | stroke snapshots, render budget | Tests/AppSnapshotTests/DesignStrokeSnapshots.swift | DesignStrokeSnapshots | #4864 | merged |
| DK-5 | DK-m | 2 | DesignStroke = VectorStroke, migration | Sources/DesignModel/DesignStroke+Kernel.swift, Tests/DesignModelTests/DesignStrokeTests.swift | DesignStrokeTests | #4888 | merged |
| DK-6 | DK-m | 2 | stroke.* commands | Sources/DesignModel/DesignCommandCatalog.swift, Tests/command-ids/design.txt | DesignCommandTests | #4888 | merged |
| DK-7 | DK-m | 2 | SVG stroke attributes via StrokeSVG | Sources/DesignModel/Live/DesignSVG.swift, Tests/DesignModelTests/DesignStrokeSVGTests.swift | DesignStrokeSVGTests | #4916 | open |
| DK-8 | DK-z | 3 | testDashedBorder on live | UITests/DesignJourneyTests+Stroke.swift | testDashedBorder | #5825 | open |
| DK-9 | DK-z | 3 | wave.json built, feature-done | docs/blueprints/design/features/stroke-style.wave.json | scripts/waves render --dry-run | #5825 | open |

## Critic reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|
| DK-a | – | 3785460f | first-use, correctness, design | #3865 #3871 #3873 | 2 |
| DK-u | – | b17f9002c / da662ed8 | first-use, correctness, render | #4925-#4928, #4989, #5009, #5010 | 2 |
| DK-m | done 2026-10-26T23:08Z (https://github.com/qbtrix/creative-apps/actions/runs/40414010435) | 63592c7b / 1910a2160 | first-use, correctness | #4919, #4920, #4940, #4941 | 2 |

## Decisions
- 2026-10-26T02:04:31Z run act-1a175ee11f8-jfg2: the brief asks to rebase lead/stroke-style onto origin/main. The branch held the SuiteUI stroke-style record (#3450, built; SS-z). Its old tip b131d9e6 is kept at lead/suiteui-stroke-style-archive (and the copy on lead/suiteui-stroke-style), so lead/stroke-style was rebuilt from main d3323f6a with this Design record. The earlier Design history is on lead/design-stroke-style (6ba49b2b). PRs still target dev.
- Packet-Review on #3441 (10-26 00:53Z): the packet's Tests/DesignModelTests/DesignStrokeMigrationTests.swift is Tests/DesignModelTests/DesignStrokeTests.swift (the suite exists there). DK-5 already uses it; DK-z's packet and wave.json edits will name it.
- creative-core#813: Path.dashed drops zero-length dashes; stopgap DesignNode.dotLength 0.001 in #5002.
- Contract-first waits (rule 12): shape-tools is built, so DK-u and DK-m started on its contract.

## Open
- 2026-10-26T13:35Z run act-1a178669406-n4me: asked the supervisor on #3441 whether DK-z may start stacked on #4916/#5011 while its 7 open findings each close with an open PR.
- 2026-10-26T22:14Z: #4916 (DK-m's last PR) merged as 9810d71b; #4919 closed. Full CI run https://github.com/qbtrix/creative-apps/actions/runs/40411399952 on 9810d71b holds it: Scoped design run 40414010435 on 9810d71b went green: Belt-Slice-Done: DK-m posted (issuecomment-6429472624). dev-red #5818 (macOS, range main..696d37fe; not ours) still holds code batches; #5002/#5011 wait in the lane. Open findings: 6.
- Open stroke-style findings past the round cap (#4925 #4926 #4927 #4919 #4940 #4941 #4989 #5009 #5010) are partly fixed in #5002/#5011; the rest go to gaps once those PRs merge.
- 2026-10-26T02:06:05Z: every open stroke-style finding is fixed by an open PR (#4916, #5002, #5011 Fixes lines); DK-z starts once they land and the combined open count is 5 or fewer.
- 2026-10-27T05:55Z run act-1a17be7aff8-ivwy: lead/stroke-style shares no history with main (2686 heartbeat commits), so it was rebuilt from main fef52e66 with the current RECORD.md and timeline.tsv; the old tip b68c1b5e is kept at lead/stroke-style-archive-1027.
- Status goes to both lead/design-stroke-style (Belt reads it) and lead/stroke-style (the brief's branch); same RECORD.md content.
