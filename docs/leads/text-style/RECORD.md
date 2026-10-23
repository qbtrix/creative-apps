# text-style lead record

Issue: #3779 (relaunch #4519) · Packet: docs/blueprints/suiteui/features/text-style.md
Run: act-1a16958d72f-a4mg · Session: cloud line lead (line:suiteui; with text-style, brush-keys, document-setup) · Started: 2026-10-23T15:25Z
Stage: 3 wave 1 (combined waves across the three features)
Base: 721168a8f0ae8897cce7279184c52015ecef0f4f (dev)
Next: wave 1 builds TS-a (TS-2) beside BK-u and the DS adopt slices; then TS-u, TS-design; TS-halo waits on adjust-everywhere AJ-a (no contract merged)

## Slices

| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| TS-a | TextStyle, rules, commands and rows declared; checks written, disabled | TS-1, TS-2 | – | font-picker:FP-a (TS-2) | true | 0 | TS-1 merged #3836; TS-2 blocked (FP-a) | – | – |
| TS-u | the rows read and scrub the style | TS-3, TS-4 | – | TS-a, font-picker:FP-u | true | 0 | planned | – | – |
| TS-m | ranges clamp, tracking em-relative, layout, one undo step per scrub | TS-5, TS-6 | – | TS-1 | false | 0 | done | 39808732641 | – |
| TS-design | Design adopts | TS-7, TS-8 | – | TS-m, TS-u, adopt-command-catalog:AC-design (built), brush-keys:BK-design (planned) | true | 0 | planned | – | – |
| TS-halo | Halo adopts; feature built | TS-9, TS-10, TS-11, TS-12 | – | TS-design, TS-m, TS-u, AE-halo, AJ-halo, AN-halo (planned) | true | 0 | planned | – | – |

## Tasks

| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| TS-1 | TS-a | 1 | contract types, specs that throw NotBuilt, disabled suites | Sources/SuiteKernel/Text/TextStyle.swift, Sources/SuiteKernel/Text/TextStyleRules.swift, Sources/SuiteKernel/Text/TextCommands.swift, Tests/SuiteKernelTests/TextStyleRulesTests.swift, Tests/SuiteKernelTests/TextStyleLayoutTests.swift, Tests/SuiteKernelTests/TextCommandsTests.swift, docs/c4/parts/creative-apps/suite-kernel/kernel-text.json | suites compile disabled; KernelShapeTests unchanged | #3836 | merged |
| TS-2 | TS-a | – | TextStyleRows | Sources/SuiteUI/TextStyleRows.swift | see packet | – | blocked (FP-a) |
| TS-5 | TS-m | 2 | rule and layout bodies | Sources/SuiteKernel/Text/TextStyleRules.swift, Tests/SuiteKernelTests/TextStyleRulesTests.swift, Tests/SuiteKernelTests/TextStyleLayoutTests.swift, Tests/mutations/SuiteKernel.TextStyleRules.json | .trackingIsEmRelative .lineHeightClamps .lastLineNotJustified | #3844 | merged |
| TS-6 | TS-m | 2 | command bodies | Sources/SuiteKernel/Text/TextCommands.swift, Tests/SuiteKernelTests/TextCommandsTests.swift, Tests/mutations/SuiteKernel.TextCommands.json | .scrubIsOneStep .familyKeepsWeight | #3847 | merged |
| TS-3 | TS-u | – | see packet | see packet | see packet | – | blocked |
| TS-4 | TS-u | – | see packet | see packet | see packet | – | blocked |
| TS-7..TS-12 | TS-design, TS-halo | – | see packet | see packet | see packet | – | blocked |

## Wire
- [ ] Wire: anchor-parenting:AN-halo (TS-halo shares a Halo app file)
- [ ] Wire: brush-keys:BK-design (TS-design shares a Design app file)
- [ ] Wire: adjust-everywhere:AJ-halo (TS-halo
- [ ] Wire:  contract not merged)

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

- 2026-10-21T09:01Z heartbeat: #3836 TS-1 waits lane batch; #3844/#3847 stay stacked.

- 2026-10-21T09:29Z heartbeat: dev red #3856 (Design anchors, not ours). #3836 TS-1 macOS green, waits lane batch; #3844/#3847 stay stacked.

- 2026-10-21T10:02Z heartbeat: #3836 TS-1 merged. #3844 TS-5: dev merged in (25912c56, TS-5 side kept), base dev; gate blocked by dev red #3856, SuiteKernelTests pass, Head: held. #3847 stays on TS-5.

- 2026-10-21T10:36Z heartbeat: #3844 merged dev at b14ab8cb; the anchors pass now. The gate fails only on CommandPathTests photo (PhotoPlace.swift:36, #3976), which fails the same way on dev alone (#3856). Head held at a880a6f9; noted on #3779 and #3856. TS-a still needs TS-2 (FP-a). #3847 stacked on TS-5.

- 2026-10-21T11:03Z heartbeat: #3844 Head: held at a880a6f9, dev still red (#3856, CommandPathTests photo); #3847 stacked

- 2026-10-21T11:30Z Heartbeat: dev still red (#3856, CommandPathTests photo; red-triage names #3976, photo line). #3844 Head: held at a880a6f9, #3847 stacked on it.

- 2026-10-21T11:57Z Heartbeat: dev still red (#3856); #3844 held at a880a6f9, #3847 stacked.

- 2026-10-21T12:25Z Heartbeat: dev still red (#3856); #3844 held at a880a6f9, #3847 stacked.

- 2026-10-21T12:52Z heartbeat: #3844 TS-5 held while dev red (#3856, photo line); #3847 stacked
- 2026-10-22T16:40Z: run act-1a164697376-dv7u on new issue #4519. TS-1 #3836, TS-5 #3844, TS-6 #3847 merged and in green dev Linux run 39808732641 (401242a59): Belt-Slice-Done TS-m posted on #4519.
- 2026-10-23T15:25Z (act-1a16958d72f-a4mg): contract-first waits (lead.md rule 12, #4814): a wait on another feature is met once that feature's first slice merged; each wait built ahead of its slice is listed under Wire. Merged-done = green `Linux` on a dev CI run containing the slice's last PR.

## Open

- TS-2 and everything UI wait on font-picker FP-a, itself blocked on shell-text ST-a.
- 2026-10-22T16:40Z: shell-text is built now, so font-picker FP-a (#3730, parked) can relaunch; TS-a, TS-u, TS-design, TS-halo wait on it.

