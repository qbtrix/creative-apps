# text-style lead record

Issue: #3779 · Packet: docs/blueprints/suiteui/features/text-style.md
Run: act-1a15c07cabb-mtlw · Session: e6bf0eb1-e2b8-518f-a36a-05b7f66e9a98 · Started: 2026-10-21T01:21:08Z
Stage: 3 wave 1
Base: 7277a83ac040f759d8bdefc150a72e7cdf2900d6
Next: wave 1 builds TS-1 (contract); wave 2 stacks TS-5 then TS-6 (TS-m) on it.

## Slices

| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| TS-a | TextStyle, rules, commands and rows declared; checks written, disabled | TS-1, TS-2 | – | font-picker:FP-a (TS-2) | true | 0 | building | – | – |
| TS-u | the rows read and scrub the style | TS-3, TS-4 | – | TS-a, font-picker:FP-u | true | 0 | planned | – | – |
| TS-m | ranges clamp, tracking em-relative, layout, one undo step per scrub | TS-5, TS-6 | – | TS-1 | false | 0 | planned | – | – |
| TS-design | Design adopts | TS-7, TS-8 | – | TS-m, TS-u, adopt-command-catalog:AC-design (built), brush-keys:BK-design (planned) | true | 0 | planned | – | – |
| TS-halo | Halo adopts; feature built | TS-9, TS-10, TS-11, TS-12 | – | TS-design, TS-m, TS-u, AE-halo, AJ-halo, AN-halo (planned) | true | 0 | planned | – | – |

## Tasks

| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| TS-1 | TS-a | 1 | contract types, specs that throw NotBuilt, disabled suites | Sources/SuiteKernel/Text/TextStyle.swift, Sources/SuiteKernel/Text/TextStyleRules.swift, Sources/SuiteKernel/Text/TextCommands.swift, Tests/SuiteKernelTests/TextStyleRulesTests.swift, Tests/SuiteKernelTests/TextStyleLayoutTests.swift, Tests/SuiteKernelTests/TextCommandsTests.swift, docs/c4/parts/creative-apps/suite-kernel/kernel-text.json | suites compile disabled; KernelShapeTests unchanged | – | building |
| TS-2 | TS-a | – | TextStyleRows | Sources/SuiteUI/TextStyleRows.swift | see packet | – | blocked (FP-a) |
| TS-5 | TS-m | 2 | rule and layout bodies | Sources/SuiteKernel/Text/TextStyleRules.swift, Tests/SuiteKernelTests/TextStyleRulesTests.swift, Tests/SuiteKernelTests/TextStyleLayoutTests.swift, Tests/mutations/SuiteKernel.TextStyleRules.json | .trackingIsEmRelative .lineHeightClamps .lastLineNotJustified | – | planned |
| TS-6 | TS-m | 3 | command bodies | Sources/SuiteKernel/Text/TextCommands.swift, Tests/SuiteKernelTests/TextCommandsTests.swift, Tests/mutations/SuiteKernel.TextCommands.json | .scrubIsOneStep .familyKeepsWeight | – | planned |
| TS-3 | TS-u | – | see packet | see packet | see packet | – | blocked |
| TS-4 | TS-u | – | see packet | see packet | see packet | – | blocked |
| TS-7..TS-12 | TS-design, TS-halo | – | see packet | see packet | see packet | – | blocked |

## Reviews

| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions

- 2026-10-21T01:21:08Z: integration base is dev (7277a83a), not main.
- 2026-10-21T01:21:08Z: TS-m unchained from TS-a: TS-5 and TS-6 need only TS-1's kernel code, not TS-2's SuiteUI rows (which wait on font-picker FP-a); they stack on TS-1.
- 2026-10-21T01:21:08Z: TS tests measure with a fixed-advances closure of their own, since FakeText belongs to shell-text ST-a (not built).

## Open

- TS-2 and everything UI wait on font-picker FP-a, itself blocked on shell-text ST-a.
