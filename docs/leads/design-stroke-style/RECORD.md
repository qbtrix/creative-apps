# design-stroke-style lead record

Issue: #3441 · Packet: docs/blueprints/design/features/stroke-style.md
Run: act-1a170488b43-wwo9 · resumed after Belt nudge 2026-10-25T00:11:38Z · Started: 2026-10-23
Stage: 3 wave 1 (16:50Z): DK-u #4864 open (critic running); DK-m #4888 open (DK-5, DK-6, critic running); DK-7 building on design/dk-m-stroke-svg (15-file cap split)
Base: 721168a8 (origin/dev); main verified at cb79cbb6
Next: wait for the lane to batch our open PRs (batch-20261024235353 holds none of them); then slice-done on the first ci.yml run on dev that contains each slice's last PR

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| DK-a | stroke adapter stubs, vectorStroke, Stroke section is StrokeEditor on them | DK-1, DK-2 | MJ-DK | SS-a (done) | yes | 2 | merged (3785460f); rounds spent (#3884, #4001); #3865 #3871 #3873 are gap p2 | 39670298178 | wanted (posted) |
| DK-u | canvas strokes dashes, joins, caps; snapshots, budget | DK-3, DK-4 | J-DK | DK-a, shape-tools:DS-u | yes | 1 | open #4864, fix round 1 (#4925-#4928) | – | – |
| DK-m | DesignStroke is VectorStroke; commands; SVG | DK-5, DK-6, DK-7 | MJ-DK | DK-a, shape-tools:DS-m; SS-d (DK-7) | no | 1 | fix round 1: #4888 (#4919, #4920), #4916 (#4940, #4941) | – | – |
| DK-z | journey on live; built | DK-8, DK-9 | J-DK | DK-u, DK-m | yes | 0 | waiting | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| DK-1 | DK-a | 1 | adapter and DesignNode.vectorStroke stubs; DesignStrokeTests disabled | Sources/DesignModel/DesignStroke+Kernel.swift, Tests/DesignModelTests/DesignStrokeTests.swift | DesignStrokeTests | #3690 | merged |
| DK-2 | DK-a | 1 | Stroke section is StrokeEditor (no trim) on the stubs; journey skipped | Sources/DesignApp/DesignInspectorStyle.swift, UITests/DesignJourneyTests+Stroke.swift | DesignInspectorSnapshots | #3690 | merged |

## Critic reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|
| – | – | – | – | – | – |

## Decisions
- 2026-10-24 run act-1a16cc9673d-cmzv: resumed; brief main HEAD 654fb363 verified, dev 830af22d. Status branches stay lead/design-*; PRs target dev. All slice PRs are clean and wait on the lane (PD-a #3759 on the supervisor); no new feature task while open findings exceed 5.
- 2026-10-23 run act-1a16953aed5-oxsi: one lead holds stroke-style and placed-images (#3454, record lead/design-placed-images); one wave plan. Contract-first waits (lead.md rule 12): shape-tools is built, so DK-u and DK-m start now. Brief says integration branch main; PRs still target dev (the lane retargets main). #4014 is closed, so DK-u's StrokeEditor wiring can use styleHelp.
- 2026-10-22T09:03Z supervisor: don't take DS-u/DS-m into this run; finish the eyedropper slices and end the run; stroke-style relaunches after DS-u and DS-m.
- Status branch is lead/design-<feature> (record docs/leads/design-<feature>/): lead/<feature> belongs to the SuiteUI lead of the same feature name.
- PRs target dev, not main (CLAUDE.md, lead.md); main b3011ab9 is an ancestor of dev and only fast-forwards to green dev.
- Rule 22: one PR per slice; each slice's PR opens with its failing test commit.
- One lead (this run) holds stroke-style, shape-tools and eyedropper; one wave plan across the three.
- Design transform (#3436) has no lead running (no lead/design-transform branch, wave.json planned); its DT-a needs gradient-fill:DG-a (building in run act-1a15a9a4e8b-kn6a). shape-tools DS-a and eyedropper DY-m wait on it; this lead does not build another feature's tasks.
- 2026-10-21 run act-1a15e909498-4bkk: the brief names lead/stroke-style as the status branch, but that branch is the SuiteUI stroke-style lead's (#3450, pushed 13:03Z). Rebasing or force-pushing it would destroy their record, so this run keeps lead/design-stroke-style, as the earlier Design runs did.
- #3865 (Join/Cap chips act on nothing) became gap p2 after round 2: Design cannot disable those rows until #4014 (StrokeEditor styleHelp, needs-ui) lands; DK-5 also closes it.

## Open
- 2026-10-22T08:59Z: 3 identical blocked polls (07:24Z, 08:20Z, 08:58Z); asked the supervisor on #3441 (comment 6336857347) whether to wait for a shape-tools lead or take DS-u/DS-m.
- Run act-1a1627ce3b4-ayhz: brief rule 2 asks to rebase and force-push lead/eyedropper onto main; that branch is the SuiteUI eyedropper lead's record (#3448), so this run does not rewrite it and keeps lead/design-<feature>.

- Run act-1a1605b0534-rn47: the brief's "rebase lead/eyedropper onto origin/main" was not done: lead/eyedropper is the SuiteUI eyedropper lead's branch (#3448); this lead's status stays on lead/design-*.

## 2026-10-23T21:57Z DK-u fix round 1

- #4864 reset to b17f9002c: the slice plus the #4928 tests (371 lines). Gate rerun on that head.
- #5002 (design/dk-u2-stroke-fixes, da662ed8) stacks the canvas fixes for #4925, #4926, #4927 and #4989. Mutation plan DesignModel.DesignStrokeOutline: 8/8.
- Asked the supervisor on #3441 to file a needs-core issue: `Path.dashed` drops zero-length dashes. Workaround: dotLength 0.001.
- Footers stripped from the #3759 and #4888 bodies.
- Next: critic round 2 on #4864 and #5002. DK-z waits until 5 or fewer findings are open.

## 2026-10-23T22:01Z DK-u gate, DK-m rebase

- #4864: the gate passed at b17f9002c. The body now carries Head b17f9002c and Fixes #4928. needs-split was dropped after a reply to the sentinel (379 lines, 7 files).
- The DK-u round-2 critic is running on #5002 (da662ed8).
- #4888 needs-rebase: dev merged in at d6494151, resolving DesignCommandCatalog, its tests and the CLI golden (the stroke.* and select.* ids kept). Its gate is running; push after CI: PASS.

## 2026-10-23T22:23Z DK-u critic round 2

- The critic read #5002 at da662ed8. #4925, #4926 and #4989 are fixed. #4927 is partly fixed: its solid half is done, and the dashed and trimmed half became #5009. #4928 is partly fixed: the corner-radius mutation is still missing.
- New findings: #5009, where a dashed or trimmed trace on a rounded box uses circular corners while the fill uses continuous ones, and #5010, where the dash phase is scaled by zoom but no test covers it.
- Next: DK-u fix round 2, the last one, stacked on #5002. It fixes #5009 and #5010 and adds the #4928 mutation. Whatever is still open after that becomes a gap.

## 2026-10-23T22:33Z DK-u fix round 2 (last)

- Opened #5011 (design/dk-u3-stroke-corners, 1110e183), stacked on #5002. Rounded boxes now fill with circular corners, which fixes #5009. It adds a dash-phase test (#5010) and the corner-radius mutation (#4928). Plan DesignModel.DesignStrokeOutline: 10/10 caught. The gate is running.
- This was DK-u's last round. Anything left open after #5011 becomes a gap.

## 2026-10-24T02:44Z fix: #4864 macOS gate failure (DK-u)
The lane probe batch-20261023215139-9's macOS gate (run 40050012604) failed on DesignStrokeSnapshots.editor and RenderBudgetDesignStrokeTests. Cause: DesignStrokeSeed stroked only top-level nodes, and node-3 sits in the Desktop frame. Fix 2bd18bb86 uses page.nodes.update. Gate rerunning; then move the Head: line and merge the new base into #5002 and #5011.

## 2026-10-24T04:35Z needs-fix on #4864 (DK-u)
At 04:14Z the supervisor pulled #4864 from the lane for the batch -9 macOS failures, which ran the old head 97439dd8. The fix 2bd18bb86 was already on the head; the Width id matches StrokeEditorRow.width. I re-added fast-lane so the next batch's macOS gate proves the fix, and replied on the PR.

## 2026-10-25T01:23:28Z supervisor answer, beta labels
- Supervisor (#3441, 01:07Z): no runner problem. Each macOS bisect step of batch-20261024235353 takes 60-90 min; the likely culprit is #5174. Our 8 PRs need nothing; keep them clean and labelled beta.
- beta added to #4888 #4916 #5002 #5011 #4922 #4963 #4964 #5001; all heads unchanged, no conflicts.
- DK-z and PD-z stay held: open findings are still above 5 (the Fixes in the 8 PRs close them only on merge, e.g. #4925 #4926 #4927 #4928 #4989 #5009 #5010 #4919 #4940 #4941 #4934 #4966). Both slices also stack on two unmerged parents each, so a PR now would break the 400/15 cap (rule 22).
- Next: wait for the next batch; then slice-done for DK-m, DK-u, PD-m and PD-u on the first design ci.yml run that contains them; then DK-z and PD-z.

### 2026-10-25T04:42:20Z: stage

#4888, #4916, #5002 and #5011 are clean and wait on the next batch. The batch red was #4963 (placed-images), not ours. DK-z is held while more than 5 findings are open.

### 2026-10-25T05:54:44Z: stage

#4888 merged 05:23Z; #4916 needs-split cleared by merging dev (192 lines/10 files), ci --changed PASS, Head 1910a216; #5002/#5011 queued
