# eyedropper lead record

Issue: #3448 · Packet: docs/blueprints/suiteui/features/eyedropper.md
Run: act-1a1579fdd22-6z1j · Session: session_01PjyLDm83LyEExMuxXuYsXP · Started: 2026-10-20T04:46Z
Stage: 3 wave 2
Base: 18464f26b93c6826d069e0107545d7aacfac033c
Next: #3531 and #3541 then #3597 restack to dev; EY-8 waits on transform-tools:TT-z; EY-a done once #3531 merges

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| EY-a | The kernel's sample size, mean, target and color.sample spec are declared as stubs, the colour rows take the eyedropper ... | EY-1, EY-2 | SJ0 | gradient-fill:GF-a | true | 0 | merged | – | – |
| EY-u | On the gallery page every colour row's eyedropper picks a colour from the screen as one gesture, the loupe follows the p... | EY-3, EY-4 | EJ1 | EY-a | true | 0 | pr-open | – | – |
| EY-m | The mean averages the visible pixels of the square weighted by alpha, and color.sample reads the colour at a document po... | EY-5, EY-6 | KJ-sample | EY-a | false | 0 | done | https://github.com/qbtrix/creative-apps/actions/runs/39413721862 | – |
| EY-z | The gallery samples through color.sample on a live target, the fake app samples its topmost rect so RJ-X33 runs on the C... | EY-7, EY-8, EY-9 | EJ1, KJ-sample | EY-u, EY-m, transform-tools:TT-z | true | 0 | planned | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| EY-1 | EY-a | 1 | The contract as stubs: `SampleSize`, `SampleRGBA`, `SampleRules`, `SampleTarget`, the `color.sample` spec w... | `Sources/SuiteKernel/Sample/SampleRules.swift`, `Sources/SuiteKernel/Sample/SampleCommands.swift`, `Tests/SuiteKernelTests/SampleRulesTests.swift`, `Tests/SuiteKernelTests/SampleCommandsTests.swift`, `docs/c4/parts/creative-apps/suite-kernel/kernel-sample.json` | see packet Acceptance | #3525 | merged |
| EY-2 | EY-a | 2 | The placeholder `EyedropperButton`, `SampleLoupe` and `SampleSizeChips`; the colour rows' `sampleable:` par... | `Sources/SuiteUI/Eyedropper.swift`, `Sources/SuiteUI/ColorWell.swift`, `Sources/SuiteUI/Gallery/GalleryEyedropper.swift`, `Sources/SuiteUI/Gallery/GalleryCanvasHost.swift`, `UITests/SuiteJourneyTests+Eyedropper.swift` | see packet Acceptance | #3531 | merged |
| EY-3 | EY-u | 3 | The views: the `NSColorSampler` button on every colour row (one change and one end per pick), the loupe, th... | `Sources/SuiteUI/Eyedropper.swift`, `Sources/SuiteUI/ColorWell.swift`, `Tests/SuiteUITests/EyedropperTests.swift` | see packet Acceptance | #3541 | open |
| EY-4 | EY-u | 4 | Snapshots, the render budget test, the journey turned on | `Tests/AppSnapshotTests/SuiteEyedropperSnapshots.swift`, `Tests/AppSnapshotTests/RenderBudgetEyedropperTests.swift`, `UITests/SuiteJourneyTests+Eyedropper.swift` | see packet Acceptance | #3541 | open |
| EY-5 | EY-m | 2 | `SampleRules` bodies; turns on `SampleRulesTests` | `Sources/SuiteKernel/Sample/SampleRules.swift`, `Tests/SuiteKernelTests/SampleRulesTests.swift`, `Tests/mutations/SuiteKernel.SampleRules.json` | see packet Acceptance | #3540 | merged |
| EY-6 | EY-m | 3 | The `color.sample` body; turns on `SampleCommandsTests` on a test target | `Sources/SuiteKernel/Sample/SampleCommands.swift`, `Tests/SuiteKernelTests/SampleCommandsTests.swift`, `Tests/mutations/SuiteKernel.SampleCommands.json` | see packet Acceptance | #3540 | merged |
| EY-7 | EY-z | 5 | The gallery page's tool samples its canvas through `color.sample` on a local target and sets the row as one... | `Sources/SuiteUI/Gallery/GalleryEyedropper.swift`, `Tests/SuiteUITests/EyedropperLiveTests.swift` | see packet Acceptance | #3597 | open |
| EY-8 | EY-z | 4 | The fake app samples: `FakeCanvasDocument` conforms to `SampleTarget` (the topmost rect under the point, it... | `Sources/SuiteKernel/Fakes/FakeCanvasDocument.swift`, `Tests/SuiteKernelTests/FakeSampleTests.swift`, `Tests/mutations/SuiteKernel.FakeCanvasDocument.json`, `Tests/RealJobs/fake/sample-color/sample-color.jobs.json`, `Tests/RealJobs/fake/sample-color/input/two-fills.fake` | see packet Acceptance | – | planned |
| EY-9 | EY-z | 6 | The C4 part names the command, the button and the loupe; `status: built`; `feature-done` | `docs/c4/parts/creative-apps/suite-kernel/kernel-sample.json`, `docs/blueprints/suiteui/features/eyedropper.wave.json` | see packet Acceptance | – | planned |

(wave = the packet's build wave; the combined slice-PR plan is under Decisions.)

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- 2026-10-20T13:54Z #3597 needs-split is a stale-stack artifact (its own diff is 263 lines / 2 files): restack EY-u onto dev instead of splitting, leaving EY-2 (macOS build green) as is.
- 2026-10-20T12:23Z #3531 macOS build red (Sendable closure in .merging on a literal). Fix: register GalleryEyedropper.pages in SuiteGallery.areas like every other area.
- 2026-10-20T11:38Z EY-7 opened as #3597 (fb38eac3, 263 lines in 2 files, stacked on #3541); critics: swatch .position vs journey coordinates, 5x5 step at green's left edge, loupe follows pointer.
- 2026-10-20T11:30Z EY-m done: Linux run 39413721862 holds 8d8919ca; Belt-Slice-Done posted on #3448 (not a UI slice, no Mac-Finish-Wanted).
- 2026-10-20T11:21Z EY-7 builder started on lead/eyedropper-EY-7 from #3541 (EY-u) with dev merged in for EY-m; its PR diff shrinks to EY-7's files once #3541 sits on dev.
- 2026-10-20T11:20Z #3531 needs-rebase fixed: dev merged at 5a8499cd (C4 description keeps the eyedropper and HistoryPanel clauses); #3541 restacked at e8e883c6 (397 lines); both CI: PASS.
- 2026-10-20T11:02Z #3540 (EY-m) merged as 8d8919ca; EY-m done waits on a green dev Linux run; EY-7 starts once the #3541 restack lands.
- 2026-10-20T10:46Z #3531 got needs-rebase (suiteui-sources.json description); fixer merges dev keeping all clauses, then restacks #3541.
- 2026-10-20T10:03Z Restacked after EY-1: #3531 -> dev head 67f26a6a (C4 description kept both), #3540 -> dev head b01a356d (kept slice code over EY-1 stubs), #3541 on EY-a-2 head 4500f6bf; all CI: PASS.
- 2026-10-20T09:44Z #3525 (EY-1) merged as d4ed4bde; fixer restacking #3531 and #3540 onto dev and #3541 onto the new EY-a-2. EY-a done once #3531 merges and a green Linux run holds it.
- 2026-10-20T06:39Z EY-u opened as #3541 (EY-3 and EY-4 in one PR, 397 lines, base lead/eyedropper-EY-a-2). Size options use ChoiceChips, so the journey looks for suite.sample.size.5. ColorRowFitTests checks "Background" at Flare's column. Journey steps 4-5 stay red until EY-7 adds suite.gallery.eyedropper.tool (report-only). Supervisor asked to add RenderBudgetEyedropperTests/loupeTrackTiming to perf-suites.
- 2026-10-20T06:33Z EY-m (#3540, 168 lines, mutate 4/4 + 3/3) on lead/eyedropper-EY-a. Gate red only on one Library/Design budget test per run under load; both pass alone. SampleRules.notBuilt removed (unused).
- 2026-10-20T06:17Z EY-a split into #3525 (EY-1, 227 lines, base dev) and #3531 (EY-2, 242 lines, stacked). Deferred ids: suite.gallery.eyedropper.hex to EY-3/EY-4, the page tool to EY-7. PhotoModel keeps its own SampleSize until the Photo adopt.
- 2026-10-20T05:48Z GF-a (#3421) merged; EY-a starts from dev 9a146777. Packet estimate ~420 lines, so the builder may split it into two stacked PRs, both Slice: EY-a.
- Base is origin/dev, not main: the packets exist only on dev and CLAUDE.md sends every PR to dev (the lane retargets main). Brief step one verified main HEAD b3011ab.
- Line lead (rule 19) over #3449 shape-tools, #3448 eyedropper, #3446 transform-tools; one combined plan.
- Combined plan by slice PRs: wave 1 SH-a, TT-a; wave 2 (stacked on each contract PR, rule 22) SH-m, TT-m, SH-u, TT-u; wave 3 SH-7, TT-7 (z slices, part one) and EY-a once GF-a merges; then EY-u/EY-m; fake tasks TT-8, EY-8, SH-8 in that order as their waits clear; the x-9 status tasks last with feature-done.
- A slice PR over 400 changed lines or 15 files splits into its tasks, the second stacked on the first; the Slice: line stays the slice id.
- EY-1 needs FillColor from gradient-fill:GF-a; no EY task can start until GF-a merges. Shape-tools and transform-tools go on meanwhile (rule 19).
- EY-a ships as one slice PR (EY-1 + EY-2), the rest one PR per slice (rule 22).
- EY-8 owns FakeCanvasDocument.swift like TT-8 and SH-8: runs after TT-8, before SH-8.

## Open
- Blocked: EY-a waits on gradient-fill:GF-a (#3418; its stubs PR #3421 is open, not merged).
- EY-8 waits on transform-tools:TT-z.
