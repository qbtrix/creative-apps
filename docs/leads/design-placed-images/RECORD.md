# placed-images lead record (Design)

Issue: #3454 · Packet: docs/blueprints/design/features/placed-images.md
Run: act-1a175ee11f8-jfg2 · Started: 2026-10-20 (this run resumed 2026-10-26T02:04:31Z)
Stage: 3 wave 2: every slice PR is open, clean and labelled fast-lane; the lane holds batches while dev-red #5321 is open (not ours)
Base: origin/dev; main verified at d3323f6a
Next: once #5321 closes and the lane lands our PRs, post Belt-Slice-Done for PD-u and PD-m on the first green design ci.yml run that holds each slice's last PR; PD-z once findings are 5 or fewer

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| PD-a | picture fields and PlacedImageTarget stubs, CoreRaster linked | PD-1, PD-2 | MJ-PD | PL-a and the Design contracts | no | 0 | done (#3759 merged) | – | – |
| PD-u | Place… and drop, canvas draws by cover, inspector rows | PD-3, PD-4 | DJ-P1 | PD-a; DK-u and the Design u-slices | yes | 2 | #4963, #4964 (stacked), #5001 (round 2, stacked) open; rounds spent; gaps #4996 #4997 #4998, needs-ui #4985 | – | – |
| PD-m | fill into frame, focus as one step, SVG crop | PD-5, PD-6 | MJ-PD | PD-a; DK-m and the Design m-slices | no | 2 | #4922 open; rounds spent | – | – |
| PD-z | live journey, blueprint, feature-done | PD-7, PD-8 | DJ-P1 | PD-u, PD-m; DG-z | yes | 0 | held: open findings > 5 (rule 7) | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| PD-1 | PD-a | 1 | node fields, conformance stubs, CoreRaster link | Sources/DesignModel/DesignNode.swift, Sources/DesignModel/DesignPlace+Kernel.swift, Tests/DesignModelTests/DesignPlaceTests.swift | DesignPlaceTests | #3759 | merged |
| PD-2 | PD-a | 1 | SVG checks and RJ-D12 disabled | Tests/DesignModelTests/DesignPlaceSVGTests.swift, Tests/RealJobs/design/place-in-frame/ | compiles, disabled | #3759 | merged |
| PD-3 | PD-u | 2 | Place…, drop, ⌥-drag focus, drawPlaced | Sources/DesignApp/DesignPlace.swift, Sources/DesignApp/DesignCommands.swift, Sources/DesignApp/DesignCanvas.swift | DesignPlaceSnapshots.inFrame | #4963, #4964 | open |
| PD-4 | PD-u | 2 | inspector image rows, snapshots, budget, journey skipped | Sources/DesignApp/DesignInspectorImage.swift, Tests/AppSnapshotTests/DesignPlaceSnapshots.swift, Tests/AppSnapshotTests/RenderBudgetDesignPlaceTests.swift, UITests/DesignJourneyTests+Place.swift | DesignPlaceSnapshots | #4964, #5001 | open |
| PD-5 | PD-m | 2 | conformance bodies, specs | Sources/DesignModel/DesignPlace+Kernel.swift, Sources/DesignModel/DesignCommandCatalog.swift, Tests/command-ids/design.txt | DesignPlaceTests | #4922 | open |
| PD-6 | PD-m | 2 | SVG image with clip | Sources/DesignModel/Live/DesignSVG.swift, Tests/DesignModelTests/DesignPlaceSVGTests.swift | DesignPlaceSVGTests, RJ-D12 | #4922 | open |
| PD-7 | PD-z | 3 | journey on live | UITests/DesignJourneyTests+Place.swift | testPlacePhotoInFrame | – | held |
| PD-8 | PD-z | 3 | design.md, status built | docs/blueprints/design.md, docs/blueprints/design/features/placed-images.wave.json | scripts/waves render --dry-run | – | held |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|
| PD-m | – | 2412a61a / 3c334c7a4 | first-use, correctness | #4930-#4935, #4959 | 2 |
| PD-u | – | d709ee35 / 312c1dcbf / c0b36b504 | first-use, correctness, design, perf | #4966-#4981, #4992-#4994 | 2 |

## Decisions
- 2026-10-26T02:04:31Z run act-1a175ee11f8-jfg2: the brief asks to rebase lead/placed-images onto origin/main. The branch held the SuiteUI placed-images record (#3457, built; PL-z). Its old tip f00226fb is kept at lead/suiteui-placed-images-archive (and the copy on lead/suiteui-placed-images), so lead/placed-images was rebuilt from main d3323f6a with this Design record. The earlier Design history is on lead/design-placed-images (0ee507aa). PRs still target dev.
- #4963 was named the culprit of a red macOS batch: a type-check timeout in DesignPlaceSnapshots.swift:39. Fixed at d709ee35 by splitting the grid strokes into typed closures.
- Contract-first waits (rule 12): every other feature's contract slice has merged, so PD-u and PD-m started stacked on PD-a.

## Open
- dev-red #5321 (range main..cc5c6234a; not ours) holds every batch. Nothing to fix here.
- [ ] Wire: stroke-style:DK-m (merged #4888): recheck DesignNode.swift picture fields against VectorStroke when #4922 lands.
- 2026-10-26T02:06:05Z: findings past the round cap that no open PR fixes were closed into their gaps (#4932→#4991, #4971→#4996, #4973→#4998, #4975→#4997, #4970 and #4972→new gap #5359 after needs-ui #4985). The 26 findings still open are each closed by an open slice PR on merge (Fixes lines), so PD-z/DK-z start once those land.
- 2026-10-26T02:35:52Z: Belt watches this branch; the record is mirrored here and on lead/placed-images each heartbeat.
