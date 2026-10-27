# anchor-parenting lead record

Issue: #3755 (record began on #4522) · Packet: docs/blueprints/suiteui/features/anchor-parenting.md
Run: act-1a175f403b9-j4z9 (line lead, line:suiteui; resume) · earlier: act-1a1705bc1ae-pb09, act-1a1695ebfeb-d54n
Stage: 3 wave check (AN-u #4893 in the lane)
Base: d3323f6a7dc523e1986e1693b640cf377e362f08 (main at resume; dev 8987427d)
Next: lane merges AN-u #4893, then open AN-6 (lead/anchor-parenting-AN-u-6); AN-10 built on lead/anchor-parenting-AN-flare-m (149649c8, CI: PASS, 289 lines/14 files, Mutate 4/4): open its PR once CB-8 #4902 and DS-flare #4891 land (merge dev, regenerate flare golden, gate); AN-halo after AN-u

## Run act-1a175f403b9-j4z9 decisions
- Brief rule 1: main checked out at d3323f6a. The old lead branches share no history with main, so each lead branch is now origin/main plus one commit carrying docs/leads/ (the tree a rebase gives), pushed --force-with-lease.
- PR base stays dev (CLAUDE.md, scripts/fast-lane.sh BASE_BRANCH=dev); the lane retargets main PRs to dev anyway.
- PR bodies: the session's GitHub relay re-adds a generated-by footer on every edit; the lane strips it from the squash commit.
- 02:20Z: dev-red #5321 (macOS, range main..cc5c6234, none ours) holds every code batch; no open finding names this feature.
- 02:44Z: AN-10 built ahead (shared files with #4902, #4891 kept it unopened). Kernel gap: layer.set-parent schema refuses parent: null; filed #5367 (gap, line:suiteui), Flare widens its own copy meanwhile.
- LS-3/LS-6/LS-7/LS-11 in the old Next belong to layer-styles (another run); dropped from this record's Next.
- 03:08Z: three polls with nothing of ours landed; lane sweep shows #4939/#4887/#4893 eligible (marker + prescreen) behind a batch in flight, 107 ready PRs ordered p0/beta/oldest, dev-red #5321 open. Queue depth, not a blocker: no supervisor question. BK app PRs restack once #4939 lands (not twice).






## Status now
Run act-1a1695ebfeb-d54n, 2026-10-23T15:30Z; supersedes the tables' PR/state columns.
- Unparked by the supervisor (2026-10-23, contract-first waits, lead.md rule 12).
- AN-a #4076, AN-m #4107 merged; test halves AN-7 #4308, AN-9 #4303 merged (disabled).
- Wave 1: AN-u: AN-5 is PR #4893 (head 855d46c6, CI: PASS, 392 lines, 6 files); AN-6 is stacked on lead/anchor-parenting-AN-u-6 (8b151479) and opens once #4893 merges; on orientation-crop OC-a's fakes (OC-u's Wire line below).
- Wave 2: AN-flare-m (AN-10). Its core needs (layer.setParent, anchor) are on the pin since bump #3825 (7966e5a); it shares FlareCommandCatalog, flare.txt and the flare golden with clipboard-interop CB-8, so it starts after CB-8's PR.
- AN-halo (AN-8) and AN-flare-u wait AN-u's merge; AN-z last.

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| AN-a | The kernel declares Placement with its anchor, set-anchor that keeps place, and the three anchor and parent command specs as stubs, with their tests written and disabled. | AN-1, AN-2 | MJ-AN | editor-kernel, command-catalog (built, `depends`) | no | 0 | merged | – | – |
| AN-m | A layer turns and scales about its anchor, moving the anchor keeps the layer where it is on screen, and parenting or clearing a parent keeps the child in place through LayerFollow. | AN-3, AN-4 | MJ-AN | AN-a | no | 0 | merged | – | – |
| AN-u | SuiteUI draws the anchor mark on the canvas and drags it as one command, and the inspector shows anchor rows with a nine-point picker and a Parent menu, reachable from the gallery on the fakes. | AN-5, AN-6 | SJ-AN | AN-a; shared files, after orientation-crop:OC-u (AN-5) | yes | 0 | building | – | – |
| AN-halo | Halo's layers place through the kernel's Placement with its files and renders unchanged, the anchor can be dragged in the viewer and set from the nine-point picker without the layer moving, and Halo's parent command is the kernel's. | AN-7, AN-8 | MJ-AN-halo, HJ-AN | AN-a (AN-7); AN-m, AN-u, adopt-kernel-easing:AE-halo and adopt-kernel-layers:AL-halo (AN-8, `HaloKeyRules.swift`); shared files, after document-setup:DS-halo (AN-8) | yes | 0 | planned | – | – |
| AN-flare-m | A Flare layer carries an anchor and a parent from the bumped core, new shapes get their anchor at the shape's centre, set-anchor and set-parent keep layers in place, and Lottie writes and reads a and parent. | AN-9, AN-10 | MJ-AN-flare | AN-a (AN-9); AN-m and adopt-kernel-layers:AL-flare (AN-10); the creative-core bump and the Flare stopgap (cross-line); shared files, after document-setup:DS-flare (AN-10) | no | 0 | planned | – | – |
| AN-flare-u | Flare's stage shows and drags the anchor, its inspector has the anchor rows and Parent menu, and Layer > New Null adds a null to parent to. | AN-11, AN-12 | FJ-AN | AN-u, AN-flare-m; shared files, after adopt-kernel-autosave:AK-z (AN-11) | yes | 0 | planned | – | – |
| AN-z | The kernel's C4 parts name Placement and the parent commands, RJ-X75 and RJ-F14 pass, and the feature is built. | AN-13, AN-14 | MJ-AN, HJ-AN, FJ-AN | AN-halo, AN-flare-u; shared files, after transform-tools:TT-z (AN-13) | no | 0 | planned | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| AN-1 | AN-a | 1 | Contract as stubs. `Placement` (x, y, scale, rotation, anchor; `matrix`; `movingAnchor(to:)`; `anchorPoint(at:in:)`), `AnchorTarget`, `ParentTarget` and `Anc... | `Sources/SuiteKernel/Transform/Placement.swift`, `Sources/SuiteKernel/Transform/AnchorCommands.swift` | the kernel builds; `CommandShapeTests` with the three specs | – | planned |
| AN-2 | AN-a | 2 | `PlacementTests` and `AnchorCommandsTests` written, disabled (`waits on AN-3`, `waits on AN-4`) | `Tests/SuiteKernelTests/PlacementTests.swift`, `Tests/SuiteKernelTests/AnchorCommandsTests.swift` | compile, disabled | – | planned |
| AN-3 | AN-m | 3 | `Placement` bodies, lifted from `HaloKeyRules.localMatrix` and its keep-in-place step; turns on `PlacementTests` | `Sources/SuiteKernel/Transform/Placement.swift`, `Tests/SuiteKernelTests/PlacementTests.swift`, `Tests/mutations/SuiteKernel.Placement.json` | `PlacementTests`: a 100×100 box with its anchor at the centre, turned 90°, keeps its centre; `movingAnchor` to a corner leaves every corner where it was on screen, also when scaled 2x and turned 30°; `matrix` equals Halo's for 200 random placements | – | building |
| AN-4 | AN-m | 3 | `AnchorCommands` run: set-anchor through `movingAnchor`, set-parent through `LayerFollow.setFollow(keepingPlace:)`, new-null as an empty layer at the canvas ... | `Sources/SuiteKernel/Transform/AnchorCommands.swift`, `Tests/SuiteKernelTests/AnchorCommandsTests.swift`, `Tests/mutations/SuiteKernel.AnchorCommands.json` | `AnchorCommandsTests` on the fake document: parenting a turned child to a scaled parent leaves its world corners unchanged; clearing the parent too; a cycle is refused with the sentence; `{at: center}` lands on the box centre | – | building |
| AN-5 | AN-u | 3 | Reachable first: the gallery's Anchor page on the fakes; `CanvasMarks+Anchor` (crosshair in a circle, hover and pressed states, a drag sends one `transform.s... | `Sources/SuiteUI/CanvasMarks+Anchor.swift`, `Sources/SuiteUI/AnchorRows.swift`, `Sources/SuiteUI/Gallery/GalleryAnchor.swift`, `Sources/SuiteUI/SuiteGallery.swift`, `Tests/SuiteUITests/AnchorRowsTests.swift` | `AnchorRowsTests`: the picker sends `{at:}` for each point, the Parent menu lists the other layers and None and never the layer or its descendants; the mark's hit radius is 6 pt at any zoom | #4893 | pr-open |
| AN-6 | AN-u | 4 | The gallery journey and the render budget row | `UITests/SuiteJourneyTests+Anchor.swift`, `Tests/AppSnapshotTests/RenderBudgetAnchorTests.swift` | `SuiteAnchorJourneyTests.testDragAnchorAndParentInGallery`; `RenderBudgetAnchorTests.anchorDragInThreeBodies` | lead/anchor-parenting-AN-u-6 | stacked |
| AN-7 | AN-halo | 3 | Halo, test first. `HaloPlacementTests`, disabled: every fixture renders the same frames within 1 level; a viewer anchor drag keeps the layer in place and is ... | `Tests/HaloModelTests/HaloPlacementTests.swift`, `UITests/HaloJourneyTests+Anchor.swift`, `Tests/RealJobs/suite/spin-in-place/spin-in-place.jobs.json` | compile, disabled; `scripts/jobs check` | – | planned |
| AN-8 | AN-halo | 5 | `HaloPlacement+Kernel.swift`; `HaloKeyRules.localMatrix` builds a `Placement`; the viewer draws `CanvasMarks+Anchor` and its drag sends `transform.set-anchor... | `Sources/HaloModel/HaloPlacement+Kernel.swift`, `Sources/HaloModel/Live/HaloKeyRules.swift`, `Sources/HaloApp/HaloWindow+Viewer.swift`, `Sources/HaloApp/HaloInspector+Anchor.swift`, `Tests/HaloModelTests/HaloPlacementTests.swift`, `UITests/HaloJourneyTests+Anchor.swift`, `Tests/mutations/HaloModel.HaloPlacement+Kernel.json`, `Sources/HaloModel/HaloCommandCatalog.swift`, `Tests/command-ids/halo.txt`, `Tests/AfterGlowCLITests/Golden/apps/halo.list-commands.json` | `HaloPlacementTests`; `HaloViewerFidelityTests` unchanged; `HaloAnchorJourneyTests.testDragAnchorKeepsPlace` | – | planned |
| AN-9 | AN-flare-m | 3 | Flare, test first. `FlareAnchorParentTests`, disabled: a rectangle drawn with the tool and keyed 0 to 360° keeps its centre at frame 12 of 24; a hand parente... | `Tests/FlareModelTests/FlareAnchorParentTests.swift` | compiles, disabled | – | planned |
| AN-10 | AN-flare-m | 4 | `FlarePlacement+Kernel.swift` maps FlareCore's transform and parent onto `Placement` and `LayerFollow`; `FlareLayers+Kernel` builds the tree's follow links f... | `Sources/FlareModel/FlarePlacement+Kernel.swift`, `Sources/FlareModel/FlareLayers+Kernel.swift`, `Tests/FlareModelTests/FlareAnchorParentTests.swift`, `Tests/mutations/FlareModel.FlarePlacement+Kernel.json`, `Sources/FlareModel/FlareCommandCatalog.swift`, `Tests/command-ids/flare.txt`, `Tests/AfterGlowCLITests/Golden/apps/flare.list-commands.json` | `FlareAnchorParentTests`; Flare's export round-trip suites unchanged | – | planned |
| AN-11 | AN-flare-u | 5 | The stage draws `CanvasMarks+Anchor` for the selected layer and its drag runs `transform.set-anchor` (keyed under auto-key); `AnchorRows` under Transform in ... | `Sources/FlareApp/FlareInspectorGeometry.swift`, `Sources/FlareApp/FlareStage+Anchor.swift`, `Sources/FlareApp/FlareCommands.swift`, `Tests/command-path-baseline/flare.txt` | `CommandPathTests`; Flare's Model tests unchanged | – | planned |
| AN-12 | AN-flare-u | 6 | The journey and the render budget row | `UITests/FlareJourneyTests+Inspector.swift`, `Tests/AppSnapshotTests/RenderBudgetFlareTests.swift` | `FlareInspectorJourneys.testAnchorAndParent`; `RenderBudgetFlareTests.anchorDragInThreeBodies` | – | planned |
| AN-13 | AN-z | 7 | The kernel's C4 parts: `kernel-transform.json` names `Placement.swift` and `AnchorCommands.swift`, `kernel-layers.json` the parent commands | `docs/c4/parts/creative-apps/suite-kernel/kernel-transform.json`, `docs/c4/parts/creative-apps/suite-kernel/kernel-layers.json` | `scripts/c4-assemble --check` | – | planned |
| AN-14 | AN-z | 8 | `status: built`; `feature-done` | `docs/blueprints/suiteui/features/anchor-parenting.wave.json` | `scripts/waves check`; `scripts/jobs check` | – | planned |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- 2026-10-23: DS-flare #4891 (document-setup's lead) was refused by the fast lane at 17:06Z: it adds an app copy of a SuiteUI Sheet (FlareDocumentSheet), so it needs captain review; the Belt-Lead sweep keeps relabelling it. AN-10's file wait holds until it merges; nothing for this lead to change.
- 2026-10-23: AN-5+AN-6 came to ~540 lines, so AN-u is two PRs: AN-5 (#4893), AN-6 stacked on it (rule 22). AN-6's p95 budget is report-only until the supervisor adds RenderBudgetAnchorTests to Tests/perf-suites.txt. Stripped the server-added attribution footer from #4893's body.
- 2026-10-23 (act-1a1695ebfeb-d54n): feature issue is #3755 per the brief (#4522 also tracks it); PRs carry `Refs #3755`.
- 2026-10-23: AN-u joins wave 1: LS-1 is layer-styles' only wave-1 task, so SuiteGallery.swift has one writer (AN-5) this wave; LS-2 follows in wave 2.
- Base is origin/dev, PRs target dev: the brief names main as the integration branch, but CLAUDE.md and lead.md say never branch from or target main (the lane retargets main PRs to dev).
- One combined wave plan across anchor-parenting, frame-rates and clipboard-interop (rule 19); one PR per slice (rule 22), test commit first.
- Wave 1 is the three contract slices FR-a, AN-a, CB-a: kernel/model stubs plus disabled tests, disjoint files.
- Status channel is lead/suiteui-<feature> with docs/leads/suiteui-<feature>/ (the names Belt reads); the earlier lead/<feature> branches are superseded.
- Slice branches are named lead/<feature>-<slice> because lead/<feature> blocks lead/<feature>/<slice>.
- AN-a: Placement is a typealias for core FlareCore.Transform (same seven fields, identity and T·R·S·T(-anchor) matrix), so no second copy; only movingAnchor(to:) and anchorPoint(at:in:) are kernel extensions (rule 20).
- Wave 2 slices (AN-m) build stacked on their wave-1 slice branch and push without a PR; the lead opens each PR once its parent has merged, so the stacked PR never carries the parent's diff past the size cap.

## Wire
- [ ] Wire: orientation-crop:OC-u (built on OC-a's fakes in AN-5; swap in when it merges)

## Open
- 2026-10-22: AN-a and AN-m merged earlier; every remaining task waits on an upstream slice that has not started (orientation-crop, adopt-kernel-easing, adopt-kernel-layers, document-setup all `planned`). Polling with the other two features.
- AN-u waits on orientation-crop:OC-u; AN-halo on AE-halo, AL-halo, DS-halo; AN-flare-m on AL-flare, DS-flare, the creative-core anchor/parent bump and the Flare stopgap; AN-z on transform-tools:TT-z. Rechecked before each starts.
- dev-red #3856 fixed on dev by #4008; wave-1 slices merged dev and re-gated.
- AN-u waits on orientation-crop:OC-u, which is still planned.
- AN-a at 516c4d7e3 (dev merged): dev #4050 moved both Library timing tests into perf-suites; merged dev and re-gating serially (serialgate.sh).


- 2026-10-26T13:39:43Z (act-1a177ff0916-4jm7): 13:39Z poll: dev 01600e46; dev-red #5321 still open (not ours); no merges of ours. AN-u #4893 fast-lane, queued; CB-8 #4902 and DS-flare #4891 open, so AN-6 and AN-10 wait. Next: unchanged. No needs-fix/needs-rebase; 0 findings.
- 2026-10-26T14:04:02Z (act-1a177ff0916-4jm7): 14:04Z poll: dev 68be32fc; dev-red #5321 open (linux, range not ours); no merges of ours; #4893, #4902, #4891 open. No drift issue for anchor-parenting. Open findings 1 (#5367, kernel gap, filed earlier).
- 2026-10-26T14:05Z (act-1a177ff0916-4jm7): poll: dev 68be32fc; #4893, #4887, #4901, #4902 not merged yet; AN-6/AN-10 wait. Open findings 1 (#5367).
- 2026-10-26T14:45Z (act-1a177ff0916-4jm7): poll: dev f86f72f7; no merges of ours; #4893, #4887, #4901, #4902 queued; AN-6/AN-10 wait. Open findings 1 (#5367).
- 2026-10-26T15:02Z (act-1a177ff0916-4jm7): poll: dev f86f72f7; no merges of ours; #4893, #4887, #4901, #4902 queued; AN-6/AN-10 wait. Open findings 1 (#5367).
- 2026-10-26T15:21Z (act-1a177ff0916-4jm7): poll: dev f86f72f7; no merges of ours (#4893, #4902 open); AN-6 waits on #4893, AN-10 on #4902 and #4891; dev-red #5321 open
- 2026-10-26T15:39Z (act-1a177ff0916-4jm7): poll: dev 310d7d14; no merges of ours (#4893, #4902 open); AN-6 waits on #4893, AN-10 on #4902 and #4891; dev-red #5321 open
- 2026-10-26T15:56Z (act-1a177ff0916-4jm7): poll: dev 310d7d14; no merges of ours, dev unchanged; AN-6 waits on #4893, AN-10 on #4902 and #4891; dev-red #5321 open
- 2026-10-26T16:16Z (act-1a177ff0916-4jm7): poll: dev e14f65fa; no merges of ours; AN-6 waits on #4893, AN-10 on #4902 and #4891; dev-red #5321 open
- 2026-10-26T16:33Z (act-1a177ff0916-4jm7): poll: dev 527676af; no merges of ours; AN-6 waits on #4893, AN-10 on #4902 and #4891
- 2026-10-26T16:51Z (act-1a177ff0916-4jm7): poll: dev 527676af; no merges of ours, dev unchanged; AN-6 waits on #4893, AN-10 on #4902 and #4891; dev-red #5321 open
- 2026-10-26T17:12Z (act-1a177ff0916-4jm7): poll: dev df48c0ba; no merges of ours; AN-6 waits on #4893, AN-10 on #4902 and #4891; dev-red #5321 open
- 2026-10-26T17:28Z (act-1a177ff0916-4jm7): poll: dev df48c0ba; dev unchanged; AN-6 waits on #4893, AN-10 on #4902 and #4891
- 2026-10-26T17:46Z (act-1a177ff0916-4jm7): poll: dev fef52e66; no merges of ours (only #5808 quarantine); AN-6 waits on #4893, AN-10 on #4902 and #4891
- 2026-10-26T18:03Z (act-1a177ff0916-4jm7): poll: dev fef52e66; dev unchanged; no return label on #4893 or #4902; AN-6 waits on #4893, AN-10 on #4902 and #4891
- 2026-10-26T18:20Z (act-1a177ff0916-4jm7): poll: dev e69582e7; no merges of ours (only #5263 photo); AN-6 waits on #4893, AN-10 on #4902 and #4891
- 2026-10-26T18:37Z (act-1a177ff0916-4jm7): poll: dev e69582e7; dev unchanged; AN-6 waits on #4893, AN-10 on #4902 and #4891
- 2026-10-26T18:54Z (act-1a177ff0916-4jm7): poll: dev 5cffd4cf; no merges of ours (only #5295); AN-6 waits on #4893, AN-10 on #4902 and #4891
- 2026-10-26T19:13Z (act-1a177ff0916-4jm7): poll: dev 5cffd4cf; dev unchanged; AN-6 waits on #4893, AN-10 on #4902 and #4891
- 2026-10-26T19:30Z (act-1a177ff0916-4jm7): poll: dev 17a7848b; no merges of ours (only #5334); AN-6 waits on #4893, AN-10 on #4902 and #4891
- 2026-10-26T19:47Z (act-1a177ff0916-4jm7): poll: dev 17a7848b; dev unchanged; AN-6 waits on #4893, AN-10 on #4902 and #4891
- 2026-10-26T20:05Z (act-1a177ff0916-4jm7): poll: dev 17a7848b; dev unchanged; no suiteui PR updated since 18:00Z; AN-6 waits on #4893, AN-10 on #4902 and #4891
- 2026-10-26T20:22Z (act-1a177ff0916-4jm7): poll: dev 696d37fe; dev moved, none ours; AN-6 waits on #4893, AN-10 on #4902 and #4891
- 2026-10-26T20:38Z (act-1a177ff0916-4jm7): poll: dev 696d37fe; dev unchanged; AN-6 waits on #4893, AN-10 on #4902 and #4891
- 2026-10-26T20:56Z (act-1a177ff0916-4jm7): poll: dev 3ebc8d43; dev moved, none ours; AN-6 waits on #4893, AN-10 on #4902 and #4891
- 2026-10-26T21:15Z (act-1a177ff0916-4jm7): poll: dev 3ebc8d43; dev unchanged; AN-6 waits on #4893, AN-10 on #4902 and #4891
- 2026-10-26T21:32Z (act-1a177ff0916-4jm7): poll: dev 3ebc8d43; dev unchanged; AN-6 waits on #4893, AN-10 on #4902 and #4891
- 2026-10-26T21:35Z (act-1a177ff0916-4jm7): poll: dev 3ebc8d43; dev unchanged; AN-6 waits on #4893, AN-10 on #4902 and #4891
- 2026-10-26T21:50Z (act-1a177ff0916-4jm7): poll: dev c4cf4a75; AN-5 #4893 merged (d4cdad3a); opened AN-6 as #5819 (9dfc99f3, cherry-picked onto dev, fast-lane, no local gate: no swift); AN-u done once #5819 lands and a green ci.yml contains it; AN-10 waits on #4902
- 2026-10-26T22:11Z (act-1a177ff0916-4jm7): poll: dev c4cf4a75; no tracked merges; #5819 AN-u open; AN-10 waits on #4902
- 2026-10-26T22:29Z (act-1a177ff0916-4jm7): poll: dev 9810d71b; no tracked merges; #5819 AN-u open; AN-10 waits on #4902
- 2026-10-26T22:48Z (act-1a177ff0916-4jm7): poll: dev 3d94856c; #5819 AN-u in lane; AN-10 waits on #4902
- 2026-10-26T23:07Z (act-1a177ff0916-4jm7): poll: dev 3d94856c; #5819 AN-u in lane; AN-10 waits on #4902 (needs-rebase, not ours)
- 2026-10-26T23:23Z (act-1a177ff0916-4jm7): poll: dev 22d07ab9; #5819 AN-u in lane; AN-10 waits on #4902
- 2026-10-26T23:41Z (act-1a177ff0916-4jm7): poll: dev 22d07ab9; #5819 AN-u in lane; AN-10 waits on #4902
- 2026-10-26T23:58Z (act-1a177ff0916-4jm7): poll: dev 22d07ab9; #5819 AN-u in lane; AN-10 waits on #4902
- 2026-10-27T00:19Z (act-1a177ff0916-4jm7): poll: dev a80e88f4; lane merged 7 PRs, none ours; #5819 AN-u in lane; AN-10 waits on #4902
- 2026-10-27T00:37Z (act-1a177ff0916-4jm7): poll: dev 352d9d56; lane merged #4903 only; #5819 AN-u still queued at 9dfc99f3; AN-10 waits on #4902 (needs-rebase, not ours)
- 2026-10-27T00:58Z (act-1a177ff0916-4jm7): poll: dev f3ed4b32; lane merged 12 docs/test PRs, none ours; #5819 AN-u still queued at 9dfc99f3; AN-10 waits on #4902
- 2026-10-27T01:17Z (act-1a177ff0916-4jm7): poll: dev f3ed4b32; dev unchanged; #5819 AN-u still queued at 9dfc99f3; AN-10 waits on #4902
- 2026-10-27T01:40Z (act-1a177ff0916-4jm7): poll: dev 2cf71ce9; dev-red #5818 open (linux red, range main..2c20134c), lane holds PRs on the failing module; not ours to fix; #5819 AN-u still queued at 9dfc99f3; AN-10 waits on #4902
