# Lead record: Halo shape-tools

- Issue: #3445
- Packet: docs/blueprints/halo/features/shape-tools.md (v3, slices)
- Run: act-1a15d0eeefb-6z9l (from 2026-10-21T05:40Z; before: act-1a15a9f4e8d-hav0)
- Session: claude/halo-feature-lead-run-02scrb
- Started: 2026-10-20T18:45Z
- Stage: 3 wave 2
- Base: dev e382f9d7
- Next: watch #3933 (HS-m part 1, to dev) land, then retarget #3934 (part 2) to dev, then #3929 (HS-z, feature-done); Belt-Slice-Done for HS-m and HS-z on green runs containing them, then Belt-Contact-Sheet

## Slices

| Slice | Tasks | UI | Waits | State | PRs |
|---|---|---|---|---|---|
| HS-a | HS-1, HS-2 | yes | gradient-fill HG-a (done), transform HT-a (file order, see Decisions) | done | #3676 merged 2026-10-21T03:14Z as 268098eab; Belt-Slice-Done on Linux run 39537764239 |
| HS-u | HS-3, HS-4 | yes | HS-a | done (#3693 merged 71ffa4d1; Belt-Slice-Done on Linux run 39550229338; Mac-Finish-Wanted, scoped halo 39550225476 queued) | #3693 retargeted to dev (49f64139 after merging dev; C4 descriptions kept as on dev, the gate refuses description edits; 10 files +386/-9, CI PASS, mutate 3/3 HaloModel.HaloShapeDraft) |
| HS-m | HS-5, HS-6 | no | HS-a; transform HT-m (file order, see Decisions) | in review | #3694 closed by needs-split (16 files); split into #3933 (HS-5 Model+tests, 8 files, to dev, 718324d9) and #3934 (HS-6 catalog+RJ-H35, 9 files, on #3933, 67a04531); both CI PASS, mutate 5/5 |
| HS-z | HS-7, HS-8 | yes | HS-u, HS-m | in review | #3929 on #3934 (38363991, 2 files +76/-8, CI PASS), fast-lane + feature-done |

## Reviews

| Slice | Round | Run | Findings | Verdict |
|---|---|---|---|---|

## Decisions

- 2026-10-20: status branch is `lead/halo-shape-tools`, not `lead/shape-tools`, which belongs to the SuiteUI shape-tools lead (#3449).
- 2026-10-20: transform HT-a and HT-m are file-order waits (shared HaloLayer.swift, HaloViewer.swift, catalog and id list). Halo transform (#3443) has no lead, branch or PR, so nothing is in flight on those files; HS-a and HS-m go first and the transform lead builds on them.
- 2026-10-20: HS-a adds `HaloProject.runShape(_:)` (no-op) and `HaloViewer.onShapeIntent`, not wired in HaloWindow yet; HS-5 wires them. `HaloViewerSnapshots.swift` is created by HS-a, so transform HT-2 extends it.
- 2026-10-20: HS-u splits the P95 timing into `RenderBudgetHaloShapeTests/starDragTiming`; it needs a `Tests/perf-suites.txt` entry (supervisor only), asked on #3445. HS-5 adds the dropped "drawing adds one shape layer" check.
- 2026-10-20: stacked slices #3693 and #3694 are based on `lead/halo-shape-tools-HS-a`, not dev, until #3676 merges. With dev as base, the lane's size cap counted HS-a's changes too (#3693 showed 633/18 and got `needs-split`). The lane skips a PR whose base isn't dev, so neither merges before HS-a. After #3676 merges, retarget both to dev; whichever lands second resolves conflicts in HaloProject shapeTool and HaloWindow. HS-m left HaloWindow wiring to HS-u, and HS-u or HS-z updates the HaloModel C4 description.

- 2026-10-21: dev added a "C4 descriptions" lint that refuses edits to an existing part's description, so HS-u keeps the Halo parts as on dev; new files are owned through the parts' paths. Whichever of #3693/#3694 lands second may conflict in shape code; the lane integrates it or labels needs-rebase.
- 2026-10-21: new run act-1a15d0eeefb-6z9l takes over from act-1a15a9f4e8d-hav0; PRs get the new Belt-Lead line on their next push.
- 2026-10-21: the supervisor's needs-split on #3694 (16 files after its dev merge counted 16 > 15). Split by layer: Model + its tests in #3933, the catalog wiring, its tests and the RJ-H35 job in #3934. The HS-6 tests moved to a new HaloShapeCommandIDTests.swift so each half carries its own proof.
