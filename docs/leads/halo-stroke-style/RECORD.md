# Lead record: Halo stroke-style

- Issue: #3447
- Packet: docs/blueprints/halo/features/stroke-style.md (v3, slices)
- Run: act-1a15d0eeefb-6z9l (from 2026-10-21T05:40Z; before: act-1a15a9f4e8d-hav0)
- Session: claude/halo-feature-lead-run-02scrb
- Started: 2026-10-20T18:45Z
- Stage: 3 wave 1 (blocked)
- Base: dev e382f9d7
- Next: HK-1 held on lead/halo-stroke-style-HK-1; HK-2 waits on gradient-fill HG-u (blocked on CL-probe/#3401 and suiteui GF-2/GF-3, per lead/halo-gradient-fill RECORD); re-check each poll

## Slices

| Slice | Tasks | UI | Waits | State | PRs |
|---|---|---|---|---|---|
| HK-a | HK-1, HK-2 | yes | shape-tools HS-a; gradient-fill HG-u (HK-2) | HK-1 built, held; HK-2 blocked (HG-u) | – (branch lead/halo-stroke-style-HK-1) |
| HK-u | HK-3, HK-4 | yes | HK-a | blocked | – |
| HK-m | HK-5, HK-6 | no | HK-a; shape-tools HS-m; gradient-fill HG-m; suiteui stroke-style SS-d (core bump, core #430) | blocked | – |
| HK-z | HK-7, HK-8 | yes | HK-u, HK-m | blocked | – |

## Reviews

| Slice | Round | Run | Findings | Verdict |
|---|---|---|---|---|

## Decisions

- 2026-10-20: status branch is `lead/halo-stroke-style`, not `lead/stroke-style`, which belongs to the SuiteUI stroke-style lead (#3450).
- 2026-10-20: HK-1 conforms to SuiteKernel's `StrokeTarget` (Sources/SuiteKernel/Fill/StrokeCommands.swift) and `VectorStroke`, which is where dev has them, not SuiteUI/SuiteModel as the Contract says. `HaloLayer.stroke` saves only when set, so old projects open unchanged. HK-1 is held without a PR because it is one task of HK-a, under the 150-line floor once HK-2 is added, and HK-2 waits on HG-u. Notes for HK-6: replace the test helper `toggleKeyRaw` with `toggleKey(.trimEnd)` once HK-5 adds `HaloProperty.trimEnd`; it changes `strokeHelp` to "Strokes are for shape layers."

## Open
- Blocked (rule 19, run act-1a15d0eeefb-6z9l): HK-a builds on HG-u, which needs #3401 (SuiteUI probe recorder, open, no PR) and SuiteUI GF-2/GF-3. Said on #3447: https://github.com/qbtrix/creative-apps/issues/3447#issuecomment-6311967268

## Run act-1a162462636-ft6b (2026-10-22T06:25Z)

- Base: origin/dev bdd92b41. Status branch stays lead/halo-stroke-style (lead/stroke-style is the SuiteUI lead's).
- Waits met: HS-a, HS-m (shape-tools built), HG-u, HG-m (gradient-fill built).
- Wave 1: HK-a (HK-1 commits 5c7e5ede, 56ea568f cherry-picked from lead/halo-stroke-style-HK-1 onto dev, plus HK-2).
- Wave 2: HK-m (HK-5 then HK-6, stacked on HK-a) and HK-u (HK-3, HK-4) in parallel (rule 18).
- Wave 3: HK-z (HK-7, HK-8 feature-done).
- 2026-10-22T08:15Z wave 1 PR: HK-a #4336 (branch lead/stroke-style-HK-a; GitHub refuses lead/stroke-style/HK-a next to lead/stroke-style). The lane gave it needs-rebase for HaloWindow.swift; the lead merged origin/dev (kept dev's Group/frame inspector column with runStroke inside), and scripts/ci --changed passed. Head is now 01699281.
- The attribution footer was removed from the PR body (the lane flagged it).
- Wave 2 starts now. HK-m (HK-5, HK-6) and HK-u (HK-3, HK-4) stack on lead/stroke-style-HK-a. HK-6's catalog edits go on top of HA-6 #4342, which also edits HaloCommandCatalog.swift and halo.txt.
- 2026-10-22T09:43Z wave 2 built (container restart lost the reports' delivery; read from the agent logs). HK-u: branch lead/stroke-style-HK-u, head d6e7d49e, CI: PASS, Mutate HaloModel.HaloStrokeTrimKeys 6/6; 438 lines on its own after HK-a, so it splits into HK-u1 (Model: HaloStrokeTrimKeys + tests + plan, ~159) and HK-u2 (view, App tests, snapshots, render budget, ~279). Filed #4374 (needs-ui: an accessory slot on StrokeEditor's trim rows). HK-m: HK-5 on lead/stroke-style-HK-m1 (ce212342, Mutate LiveFrameRendering 7/7, HaloOutlines 3/3, HaloScanline 3/3; 356 lines after HK-a), HK-6 on lead/stroke-style-HK-m2 (19b2ebdb, Mutate HaloStroke+Kernel 4/4, HaloCommandCatalog 10/10; 200 lines on m1). All PRs held until #4336 (HK-a) merges: against dev each is over 400 lines. #4336 is waiting on its macOS build (run 39747706162).
- 2026-10-22T09:49Z HK-u split: lead/stroke-style-HK-u1 (Model, 66aaeb91, 159 lines/3 files, CI: PASS) and lead/stroke-style-HK-u2 (view, on u1, 6b8b0cb4, 279 lines/5 files, CI: PASS); both pushed, PRs open once #4336 merges. HA-6 #4342 compiled on macOS.
- 2026-10-22T10:19Z #4336 (HK-a) compiled on macOS (run 39747706162, 10:09Z) and is mergeable; the lane is sweeping other PRs. Starting HK-z's HK-7 (journey live) as a builder on a merge of HK-u2 and HK-m2, so it is ready when they land; HK-8 (status built) follows on top.
- 2026-10-22T10:33Z HK-z built: lead/stroke-style-HK-z (merge of HK-m2 + HK-u2, then 3 commits, 5 files +80/-57), head dcb22b77, CI: PASS (864 tests), Mutate HaloStrokeTrimKeys 9/9. HK-7 makes testStrokeDrawOn live and swaps the stale trim reason for the real property's reason; HK-8 sets status built. The PR opens after HK-m2 and HK-u2 merge, with the feature-done label. Unconfirmed until a journeys run: typing into suite.stroke.width / trim-end.
- 2026-10-22T10:39Z HK-a #4336 merged (964c790e8). Merged dev into HK-m1 (13 files +331/-25) and HK-u1 (3 files +159); both gating, then their PRs open. HK-m2 and HK-u2 follow on top; HK-m2 merges dev for HA-6's catalog edits.
