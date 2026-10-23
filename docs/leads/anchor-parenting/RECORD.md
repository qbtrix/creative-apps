# anchor-parenting lead record

Issue: #4522 · Packet: docs/blueprints/suiteui/features/anchor-parenting.md
Run: act-1a16469734c-d0s8 · Session: claude/feature-lead-playbook-d50vpe · Started: 2026-10-22 (earlier run act-1a161a658a7-2jql on #3755)
Stage: 3 polling
Base: origin/dev 7e9f260a
Next: poll orientation-crop OC-u (AN-5), AE-halo/AL-halo/DS-halo (AN-8), AL-flare/DS-flare (AN-10); all planned on dev, none merged






## Status now
Run act-1a161a658a7-2jql, status at 2026-10-22T07:24Z; this block supersedes the Task table's PR/state columns.
- 07:58Z: supervisor answered: park. Run ended for this feature; the remaining slices stay on the feature issue (waiting-on-prereq), no gap issues; the supervisor relaunches it once the upstream adopt slices land.
- 07:56Z: asked the supervisor whether to park the slices blocked on planned upstream features.
- 07:56Z: asked the supervisor whether to park the slices blocked on planned upstream features.
- AN-a #4076 merged · AN-m #4107 merged · AN-7 #4308 merged (disabled) · AN-9 #4303 merged (disabled)
- AN-u waits orientation-crop:OC-u for AN-5; AN-6 after AN-5
- AN-8 waits AE-halo, AL-halo, DS-halo (all still planned at 07:00Z)
- AN-10 waits AL-flare, DS-flare (still planned)
- AN-flare-u, AN-z wait upstream

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| AN-a | The kernel declares Placement with its anchor, set-anchor that keeps place, and the three anchor and parent command specs as stubs, with their tests written and disabled. | AN-1, AN-2 | MJ-AN | editor-kernel, command-catalog (built, `depends`) | no | 0 | merged | – | – |
| AN-m | A layer turns and scales about its anchor, moving the anchor keeps the layer where it is on screen, and parenting or clearing a parent keeps the child in place through LayerFollow. | AN-3, AN-4 | MJ-AN | AN-a | no | 0 | merged | – | – |
| AN-u | SuiteUI draws the anchor mark on the canvas and drags it as one command, and the inspector shows anchor rows with a nine-point picker and a Parent menu, reachable from the gallery on the fakes. | AN-5, AN-6 | SJ-AN | AN-a; shared files, after orientation-crop:OC-u (AN-5) | yes | 0 | planned | – | – |
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
| AN-5 | AN-u | 3 | Reachable first: the gallery's Anchor page on the fakes; `CanvasMarks+Anchor` (crosshair in a circle, hover and pressed states, a drag sends one `transform.s... | `Sources/SuiteUI/CanvasMarks+Anchor.swift`, `Sources/SuiteUI/AnchorRows.swift`, `Sources/SuiteUI/Gallery/GalleryAnchor.swift`, `Sources/SuiteUI/SuiteGallery.swift`, `Tests/SuiteUITests/AnchorRowsTests.swift` | `AnchorRowsTests`: the picker sends `{at:}` for each point, the Parent menu lists the other layers and None and never the layer or its descendants; the mark's hit radius is 6 pt at any zoom | – | planned |
| AN-6 | AN-u | 4 | The gallery journey and the render budget row | `UITests/SuiteJourneyTests+Anchor.swift`, `Tests/AppSnapshotTests/RenderBudgetAnchorTests.swift` | `SuiteAnchorJourneyTests.testDragAnchorAndParentInGallery`; `RenderBudgetAnchorTests.anchorDragInThreeBodies` | – | planned |
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
- Base is origin/dev, PRs target dev: the brief names main as the integration branch, but CLAUDE.md and lead.md say never branch from or target main (the lane retargets main PRs to dev).
- One combined wave plan across anchor-parenting, frame-rates and clipboard-interop (rule 19); one PR per slice (rule 22), test commit first.
- Wave 1 is the three contract slices FR-a, AN-a, CB-a: kernel/model stubs plus disabled tests, disjoint files.
- Status channel is lead/suiteui-<feature> with docs/leads/suiteui-<feature>/ (the names Belt reads); the earlier lead/<feature> branches are superseded.
- Slice branches are named lead/<feature>-<slice> because lead/<feature> blocks lead/<feature>/<slice>.
- AN-a: Placement is a typealias for core FlareCore.Transform (same seven fields, identity and T·R·S·T(-anchor) matrix), so no second copy; only movingAnchor(to:) and anchorPoint(at:in:) are kernel extensions (rule 20).
- Wave 2 slices (AN-m) build stacked on their wave-1 slice branch and push without a PR; the lead opens each PR once its parent has merged, so the stacked PR never carries the parent's diff past the size cap.

## Open
- 2026-10-22: AN-a and AN-m merged earlier; every remaining task waits on an upstream slice that has not started (orientation-crop, adopt-kernel-easing, adopt-kernel-layers, document-setup all `planned`). Polling with the other two features.
- AN-u waits on orientation-crop:OC-u; AN-halo on AE-halo, AL-halo, DS-halo; AN-flare-m on AL-flare, DS-flare, the creative-core anchor/parent bump and the Flare stopgap; AN-z on transform-tools:TT-z. Rechecked before each starts.
- dev-red #3856 fixed on dev by #4008; wave-1 slices merged dev and re-gated.
- AN-u waits on orientation-crop:OC-u, which is still planned.
- AN-a at 516c4d7e3 (dev merged): dev #4050 moved both Library timing tests into perf-suites; merged dev and re-gating serially (serialgate.sh).

