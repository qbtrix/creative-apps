# stroke-style lead record (Design)

Issue: #3441 · Packet: docs/blueprints/design/features/stroke-style.md
Run: act-1a175ee11f8-jfg2 · Started: 2026-10-23 (this run resumed 2026-10-26T02:04:31Z)
Stage: 3 wave 2: every slice PR is open, clean and labelled fast-lane; the lane holds batches while dev-red #5321 is open (not ours)
Base: origin/dev; main verified at d3323f6a
Next: once #5321 closes and the lane lands our PRs, post Belt-Slice-Done for DK-u and DK-m on the first green design ci.yml run that holds each slice's last PR; DK-z once findings are 5 or fewer

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| DK-a | stroke adapter stubs, vectorStroke, Stroke section is StrokeEditor | DK-1, DK-2 | MJ-DK | SS-a (done) | yes | 2 | done; gaps #3865 #3871 #3873 | 39670298178 | wanted (posted) |
| DK-u | canvas strokes dashes, joins, caps; snapshots, budget | DK-3, DK-4 | J-DK | DK-a, shape-tools:DS-u | yes | 2 | #4864 merged; #5002 (round 1) and #5011 (round 2, stacked) open; rounds spent; gaps #4990 #4991 | – | – |
| DK-m | DesignStroke is VectorStroke; commands; SVG | DK-5, DK-6, DK-7 | MJ-DK | DK-a, shape-tools:DS-m; SS-d | no | 2 | #4888 merged (63592c7b); #4916 (DK-7 SVG) open; rounds spent | – | – |
| DK-z | journey on live; built | DK-8, DK-9 | J-DK | DK-u, DK-m | yes | 0 | held: open findings > 5 (rule 7) | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| DK-1 | DK-a | 1 | adapter and vectorStroke stubs | Sources/DesignModel/DesignStroke+Kernel.swift, Tests/DesignModelTests/DesignStrokeTests.swift | DesignStrokeTests | #3690 | merged |
| DK-2 | DK-a | 1 | Stroke section is StrokeEditor | Sources/DesignApp/DesignInspectorStyle.swift, UITests/DesignJourneyTests+Stroke.swift | DesignInspectorSnapshots | #3690 | merged |
| DK-3 | DK-u | 2 | canvas paints StrokeRules.paintedPath | Sources/DesignApp/DesignCanvas*.swift, Sources/DesignModel/DesignStrokeOutline.swift | DesignStrokeOutlineTests | #4864, #5002, #5011 | merged / open / open |
| DK-4 | DK-u | 2 | stroke snapshots, render budget | Tests/AppSnapshotTests/DesignStrokeSnapshots.swift | DesignStrokeSnapshots | #4864 | merged |
| DK-5 | DK-m | 2 | DesignStroke = VectorStroke, migration | Sources/DesignModel/DesignStroke+Kernel.swift, Tests/DesignModelTests/DesignStrokeTests.swift | DesignStrokeTests | #4888 | merged |
| DK-6 | DK-m | 2 | stroke.* commands | Sources/DesignModel/DesignCommandCatalog.swift, Tests/command-ids/design.txt | DesignCommandTests | #4888 | merged |
| DK-7 | DK-m | 2 | SVG stroke attributes via StrokeSVG | Sources/DesignModel/Live/DesignSVG.swift, Tests/DesignModelTests/DesignStrokeSVGTests.swift | DesignStrokeSVGTests | #4916 | open |
| DK-8 | DK-z | 3 | testDashedBorder on live | UITests/DesignJourneyTests+Stroke.swift | testDashedBorder | – | held |
| DK-9 | DK-z | 3 | wave.json built, feature-done | docs/blueprints/design/features/stroke-style.wave.json | scripts/waves render --dry-run | – | held |

## Critic reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|
| DK-a | – | 3785460f | first-use, correctness, design | #3865 #3871 #3873 | 2 |
| DK-u | – | b17f9002c / da662ed8 | first-use, correctness, render | #4925-#4928, #4989, #5009, #5010 | 2 |
| DK-m | – | 63592c7b / 1910a2160 | first-use, correctness | #4919, #4920, #4940, #4941 | 2 |

## Decisions
- 2026-10-26T02:04:31Z run act-1a175ee11f8-jfg2: the brief asks to rebase lead/stroke-style onto origin/main. The branch held the SuiteUI stroke-style record (#3450, built; SS-z). Its old tip b131d9e6 is kept at lead/suiteui-stroke-style-archive (and the copy on lead/suiteui-stroke-style), so lead/stroke-style was rebuilt from main d3323f6a with this Design record. The earlier Design history is on lead/design-stroke-style (6ba49b2b). PRs still target dev.
- Packet-Review on #3441 (10-26 00:53Z): the packet's Tests/DesignModelTests/DesignStrokeMigrationTests.swift is Tests/DesignModelTests/DesignStrokeTests.swift (the suite exists there). DK-5 already uses it; DK-z's packet and wave.json edits will name it.
- creative-core#813: Path.dashed drops zero-length dashes; stopgap DesignNode.dotLength 0.001 in #5002.
- Contract-first waits (rule 12): shape-tools is built, so DK-u and DK-m started on its contract.

## Open
- dev-red #5321 (range main..cc5c6234a; not ours) holds every batch. Nothing to fix here.
- Open stroke-style findings past the round cap (#4925 #4926 #4927 #4919 #4940 #4941 #4989 #5009 #5010) are partly fixed in #5002/#5011; the rest go to gaps once those PRs merge.
