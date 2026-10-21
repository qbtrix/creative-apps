# text-style lead record

Issue: #3779 · Packet: docs/blueprints/suiteui/features/text-style.md
Run: act-1a15c07cabb-mtlw · Session: e6bf0eb1-e2b8-518f-a36a-05b7f66e9a98 · Started: 2026-10-21T01:21:08Z
Stage: 3 wave 2
Base: 2ab0eb96320db973b5aad0644449ee5ed3980ab9
Next: wave 2 builder TS-m (TS-5 then TS-6) stacks on feat/ts-1-text-contract (#3836); then wait for a CI run on dev whose Linux job contains #3836.

## Slices

| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| TS-a | TextStyle, rules, commands and rows declared; checks written, disabled | TS-1, TS-2 | – | font-picker:FP-a (TS-2) | true | 0 | building (TS-1 #3836 open) | – | – |
| TS-u | the rows read and scrub the style | TS-3, TS-4 | – | TS-a, font-picker:FP-u | true | 0 | planned | – | – |
| TS-m | ranges clamp, tracking em-relative, layout, one undo step per scrub | TS-5, TS-6 | – | TS-1 | false | 0 | planned | – | – |
| TS-design | Design adopts | TS-7, TS-8 | – | TS-m, TS-u, adopt-command-catalog:AC-design (built), brush-keys:BK-design (planned) | true | 0 | planned | – | – |
| TS-halo | Halo adopts; feature built | TS-9, TS-10, TS-11, TS-12 | – | TS-design, TS-m, TS-u, AE-halo, AJ-halo, AN-halo (planned) | true | 0 | planned | – | – |

## Tasks

| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| TS-1 | TS-a | 1 | contract types, specs that throw NotBuilt, disabled suites | Sources/SuiteKernel/Text/TextStyle.swift, Sources/SuiteKernel/Text/TextStyleRules.swift, Sources/SuiteKernel/Text/TextCommands.swift, Tests/SuiteKernelTests/TextStyleRulesTests.swift, Tests/SuiteKernelTests/TextStyleLayoutTests.swift, Tests/SuiteKernelTests/TextCommandsTests.swift, docs/c4/parts/creative-apps/suite-kernel/kernel-text.json | suites compile disabled; KernelShapeTests unchanged | #3836 | open |
| TS-2 | TS-a | – | TextStyleRows | Sources/SuiteUI/TextStyleRows.swift | see packet | – | blocked (FP-a) |
| TS-5 | TS-m | 2 | rule and layout bodies | Sources/SuiteKernel/Text/TextStyleRules.swift, Tests/SuiteKernelTests/TextStyleRulesTests.swift, Tests/SuiteKernelTests/TextStyleLayoutTests.swift, Tests/mutations/SuiteKernel.TextStyleRules.json | .trackingIsEmRelative .lineHeightClamps .lastLineNotJustified | #3844 | open (Mutate 3/3; base feat/ts-1-text-contract) |
| TS-6 | TS-m | 2 | command bodies | Sources/SuiteKernel/Text/TextCommands.swift, Tests/SuiteKernelTests/TextCommandsTests.swift, Tests/mutations/SuiteKernel.TextCommands.json | .scrubIsOneStep .familyKeepsWeight | #3847 | open (Mutate 2/2; base feat/ts-5-text-rules) |
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

- 2026-10-21T02:19Z: TS-5 and TS-6 run in one builder on one branch (slice TS-m, one PR), split in two only if over 400 lines.
- 2026-10-21T02:19Z: TS-1 renamed TextField to TextStyleField and nested TextAlignment as TextStyle.Alignment (SwiftUI name clashes); packet's later tasks use the new names.

- 2026-10-21T02:53Z: TS-m split into #3844 (TS-5) and #3847 (TS-6, stacked on #3844): stacked on #3836, one PR measured 483 lines against dev. Both bases point at their parent branch so the lane waits; each retargets to dev when its parent merges.
- 2026-10-21T02:53Z: .lastLineNotJustified can't be planted in our file (FlareCore owns the last-line rule); the mutant drops the box width justify needs and justifySpansTheBoxButNotTheLastLine catches it.
- 2026-10-21T02:53Z: TS-6 adds "This family has no upright face." for italic off on an italic-only family. TextStyle keeps synthesized Codable.
- 2026-10-21T02:53Z: supervisor sentinel put needs-split on #3844 for the stacked 421 lines; replied that its own change is +60/-18 and asked to drop it.

- 2026-10-21T03:41Z: #3836's macOS build (39529243000) was cancelled, and the lane waits for a new head. Merged dev into it: that picks up #3837's C4 description check, which the first gate predates. Gating it, then pushing and moving Head:.

- 2026-10-21T03:49Z: #3836 merged head b51250b1 printed CI: PASS. It's pushed and Head: is moved; the lane builds it on macOS again.

- 04:08Z heartbeat: #3836 TS-1 macOS build 39541314123 queued on b51250b1. #3844 and #3847 stay stacked.

- 04:36Z heartbeat: #3836 TS-1 macOS build 39541314123 green and clean; waits on the lane batch. #3844 and #3847 stay stacked.

- 05:04Z heartbeat: #3836 still green and clean. Lane batch 20261021043428 (PRs #3466..#3703, oldest first) went red and is bisecting; ours queue behind that backlog. Nothing to fix.

- 05:30Z heartbeat: #3836 unchanged, green and queued behind the lane backlog.

- 06:03Z heartbeat: #3836 green and clean on b51250b1. Lane batch 20261021053311 (up to #3813) is bisecting; ours are next in line.

- 06:30Z heartbeat: #3836 green and clean on b51250b1. The lane landed batch 20261021053311 at 06:12Z; ours are next in line.

- 2026-10-21T06:58Z heartbeat: #3836 TS-1 green, waiting for the next lane batch; #3844 #3847 stacked.

- 2026-10-21T07:24Z heartbeat: #3836 TS-1 still waiting for a batch; #3844 #3847 stacked.

- 2026-10-21T07:53Z heartbeat: lane merged dev into #3836 TS-1 (new head 58daec0e); gating to move Head:.

- 2026-10-21T08:06Z heartbeat: #3836 gated CI: PASS on lane head 58daec0e, Head: moved; waits for macOS build and a batch.

- 2026-10-21T08:33Z heartbeat: #3836 macOS build 39565969626 success on 58daec0e; waits for a batch.

## Open

- TS-2 and everything UI wait on font-picker FP-a, itself blocked on shell-text ST-a.
