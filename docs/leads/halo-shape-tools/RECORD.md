# Lead record: Halo shape-tools

- Issue: #3445
- Packet: docs/blueprints/halo/features/shape-tools.md (v3, slices)
- Run: act-1a15a9f4e8d-hav0
- Session: claude/feature-lead-playbook-rmflin
- Started: 2026-10-20T18:45Z
- Stage: 3 wave 1
- Base: dev e382f9d7
- Next: HS-a PR #3676 (da26317f) waits on the lane's macOS build; HS-u #3693 and HS-m #3694 are based on its branch until it merges, then go back to dev; HS-z after both

## Slices

| Slice | Tasks | UI | Waits | State | PRs |
|---|---|---|---|---|---|
| HS-a | HS-1, HS-2 | yes | gradient-fill HG-a (done), transform HT-a (file order, see Decisions) | done | #3676 merged 2026-10-21T03:14Z as 268098eab; Belt-Slice-Done on Linux run 39537764239 |
| HS-u | HS-3, HS-4 | yes | HS-a | in review | #3693 retargeted to dev (49f64139 after merging dev; C4 descriptions kept as on dev, the gate refuses description edits; 10 files +386/-9, CI PASS, mutate 3/3 HaloModel.HaloShapeDraft) |
| HS-m | HS-5, HS-6 | no | HS-a; transform HT-m (file order, see Decisions) | in review | #3694 retargeted to dev (f6c7d851 after merging the HS-a branch then dev; 15 files +176/-34, CI PASS, mutate 5/5 HaloModel.HaloShape+Kernel) |
| HS-z | HS-7, HS-8 | yes | HS-u, HS-m | planned | – |

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