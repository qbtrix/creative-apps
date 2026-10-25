# text-style lead record

Issue: #3779 (relaunch #4519) · Packet: docs/blueprints/suiteui/features/text-style.md
Run: act-1a16c618fe7-h4fd (line lead, line:suiteui) · earlier run act-1a16958d72f-a4mg
Stage: 3 wave 1 PRs open (TS-7 #5047); TS-8 waits on TS-u #4958, TS-9 blocked on AJ-a
Base: origin/dev 830af22de
Next: Lane: #4871 TS-a and #5047 TS-7 in the lane. After #4871 merges, merge dev into #4958, rerun gate, move Head and add fast-lane. TS-8 after TS-u; TS-9 after AJ-a merges.

## Slices

| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| TS-a | TextStyle, rules, commands and rows declared; checks written, disabled | TS-1, TS-2 | – | font-picker:FP-a (TS-2) | true | 0 | pr #4871 | – | – |
| TS-u | the rows read and scrub the style | TS-3, TS-4 | – | TS-a, font-picker:FP-u | true | 0 | pr #4958 | – | – |
| TS-m | ranges clamp, tracking em-relative, layout, one undo step per scrub | TS-5, TS-6 | – | TS-1 | false | 0 | done | 39808732641 | – |
| TS-design | Design adopts | TS-7, TS-8 | – | TS-m, TS-u, adopt-command-catalog:AC-design (built), brush-keys:BK-design (planned) | true | 0 | planned | – | – |
| TS-halo | Halo adopts; feature built | TS-9, TS-10, TS-11, TS-12 | – | TS-design, TS-m, TS-u, AE-halo, AJ-halo, AN-halo (planned) | true | 0 | planned | – | – |

## Tasks

| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| TS-1 | TS-a | 1 | contract types, specs that throw NotBuilt, disabled suites | Sources/SuiteKernel/Text/TextStyle.swift, Sources/SuiteKernel/Text/TextStyleRules.swift, Sources/SuiteKernel/Text/TextCommands.swift, Tests/SuiteKernelTests/TextStyleRulesTests.swift, Tests/SuiteKernelTests/TextStyleLayoutTests.swift, Tests/SuiteKernelTests/TextCommandsTests.swift, docs/c4/parts/creative-apps/suite-kernel/kernel-text.json | suites compile disabled; KernelShapeTests unchanged | #3836 | merged |
| TS-2 | TS-a | – | TextStyleRows | Sources/SuiteUI/TextStyleRows.swift | TextStyleRowsTests | #4871 | pr |
| TS-5 | TS-m | 2 | rule and layout bodies | Sources/SuiteKernel/Text/TextStyleRules.swift, Tests/SuiteKernelTests/TextStyleRulesTests.swift, Tests/SuiteKernelTests/TextStyleLayoutTests.swift, Tests/mutations/SuiteKernel.TextStyleRules.json | .trackingIsEmRelative .lineHeightClamps .lastLineNotJustified | #3844 | merged |
| TS-6 | TS-m | 2 | command bodies | Sources/SuiteKernel/Text/TextCommands.swift, Tests/SuiteKernelTests/TextCommandsTests.swift, Tests/mutations/SuiteKernel.TextCommands.json | .scrubIsOneStep .familyKeepsWeight | #3847 | merged |
| TS-3 | TS-u | – | see packet | see packet | see packet | – | blocked |
| TS-4 | TS-u | – | see packet | see packet | see packet | – | blocked |
| TS-7 | TS-design | 3 | Design adopts TextStyleTarget (test first) | see packet | DesignTextStyleTests; Mutate | #5047 | open, in lane |
| TS-8..TS-12 | TS-design, TS-halo | – | see packet | see packet | see packet | – | waits (TS-3; AJ-a, AE-flare) |

## Wire
- [ ] Wire: brush-keys:BK-design (built ahead in TS-7: TS-design shares a Design app file; BK-a is on dev)
- [ ] Wire: anchor-parenting:AN-halo (TS-9, when built: AN-a is on dev)
- [ ] Wire: adjust-everywhere:AJ-halo (TS-9 waits: AJ-a's contract isn't merged)
- [ ] Wire: adopt-kernel-easing:AE-halo (TS-9 waits: AE-flare not done)

## Reviews

| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions

- 2026-10-24T09:14:14Z Heartbeat 09:14Z: #4958 kept fast-lane, stacked on #4871; #5047 in the lane. TS-9 waits on AJ-a (adjust-everywhere planned). Dev-red #5113 is a macOS setup failure, not ours.
- 2026-10-24T08:51:52Z Heartbeat 08:52Z: #4958 had no fast-lane after the restack (the lane only labels PRs based on dev), so I added it; it waits on #4871 as a stacked PR. #5047 in the lane. TS-9 waits on AJ-a (adjust-everywhere planned).
- 2026-10-24T08:28:38Z Heartbeat 08:30Z: the lane kept dropping fast-lane from TS-u #4958 because, based on dev, it carries #4871's commits (579 lines, over the 400 cap). Retargeted it to lead/text-style-TS-a (stacked, own diff ~275 lines). Fixed its body: Belt-Lead set to this run, Refs #3779 added, Mutate moved after Refs. Head unchanged. GitHub retargets it to dev when #4871 merges. #5047 in the lane. TS-9 still waits on AJ-a (adjust-everywhere planned).
- 2026-10-24T08:07:00Z Heartbeat 07:40Z: #5047 in the lane. TS-u #4958 now carries fast-lane with base dev (lane sweep); it still merges after #4871. TS-8 starts once TS-u merges; TS-9 still waits on AJ-a (adjust-everywhere planned).
- 2026-10-24T07:00:09Z TS-7 opened as #5047 (Wire: brush-keys:BK-design).
- 2026-10-24T05:34:44Z relaunch as run act-1a16c618fe7-h4fd, using contract-first waits (lead.md rule 12). BK-a is on dev, so TS-7 builds now on TS-m's kernel and gets a Wire: line for BK-design. TS-9 still waits, because adjust-everywhere's first slice AJ-a hasn't merged (FilterRules and AdjustCommands are missing on dev). TS-m's Belt-Slice-Done was posted on #4519 (run 39808732641).
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


- 2026-10-24T21:54:37Z (act-1a16fe1fad3-lsp3): Belt-Slice-Done TS-m posted on #3779 (full CI 40129856269, ef37711de9, contains #3847). Open: TS-u #4958 (96663e95) and TS-7 #5047 (a05c0e2a) are queued in the lane. TS-8 is building, stacked on TS-7. TS-9 is building from dev.
- Wire: brush-keys:BK-design (TS-design, #5047)
- Wire: adopt-kernel-easing:AE-halo (TS-halo)
- Wire: adjust-everywhere:AJ-halo (TS-halo)
- Wire: anchor-parenting:AN-halo (TS-halo)
- 2026-10-24T22:25:39Z (act-1a16fe1fad3-lsp3): resumed on the Belt nudge. Belt reads lead/suiteui-text-style, which had fallen behind lead/text-style. It is synced again, and both are written on every stage from now on.
- 2026-10-24T23:29:22Z (act-1a16fe1fad3-lsp3): opened TS-9 #5226 (TS-halo, adb9e98a, fast-lane, clean). Opened TS-8 #5228 (TS-design, 59358e68), stacked on TS-7 #5047; it gets fast-lane once retargeted to dev. Queued in the lane with no flags: TS-u #4958 and TS-7 #5047. Dev is at afef017c, and no slice has merged yet. Open findings: 0. Next: TS-10, TS-11 and TS-12 once TS-9 lands.
- 2026-10-24T23:51:25Z (act-1a16fe1fad3-lsp3): poll. Dev is still at afef017c, and no slice has merged. No needs-fix or needs-rebase on this feature's PRs. The lane's batch 20261024205137-1 macOS gate went green at 23:50Z, so merges are close.
- 2026-10-25T00:13:12Z (act-1a16fe1fad3-lsp3): poll. Dev is still at afef017c. Lane batch 20261024235353 went red on Linux (run 40144575552), and the lane is bisecting it (probe -6 is at PR #5214). This feature's PRs have no needs-fix or needs-rebase so far.
- 2026-10-25T00:35:25Z (act-1a16fe1fad3-lsp3): poll. Dev is still at afef017c. Lane probe 20261024235353-6 (up to #5214) is green on Linux, and its macOS gate is running. No needs-fix or needs-rebase on this feature's PRs.
