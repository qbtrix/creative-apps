# layer-styles lead record

Issue: #3793 · Packet: docs/blueprints/photo/features/layer-styles.md
Run: act-1a16155057c-20lg · Session: claude/layer-styles-lead-hdzmvt · Started: 2026-10-22T02:00Z
Stage: 0 setup
Base: e9933116600a7ff143185ac15a968c4888cf4612 (origin/dev)
Next: re-read suiteui layer-styles (#3937) for LS-a merged (`LayerStyle`, `LayerStyleTarget`, `StyleCommands.specs` on dev); once it is, start wave 1 (PY-1)

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| PY-a | `PhotoLayer.style`, `style.*` in the catalog on stubs, Layer > Layer Style… opens the panel | PY-1, PY-2 | MJ-PY | multi-layer-select (built #3535); file-flow:PF-m (done); suiteui layer-styles LS-a (not started) | yes | 0 | blocked (LS-a) | – | – |
| PY-u | panel snapshots, render budget, journey written | PY-3, PY-4 | PJ-Y1 | PY-a | yes | 0 | waiting | – | – |
| PY-m | style commands as one undo step, composite draws styles padded, `.ora` keeps them | PY-5, PY-6 | MJ-PY | PY-a; LS-m | no | 0 | waiting | – | – |
| PY-z | live canvas through `StyleRoute`, journey on live, photo.md built | PY-7, PY-8 | PJ-Y1 | PY-u, PY-m; text-layers:TX-z (PY-8); LS-gpu, IM-photo (PY-7) | yes | 0 | waiting | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| PY-1 | PY-a | 1 | `PhotoLayer.style`; adapter stubs (`showStylePanel` real); catalog specs and ids; tests disabled | Sources/PhotoModel/PhotoLayer.swift, Sources/PhotoModel/PhotoStyle+Kernel.swift, Sources/PhotoModel/PhotoCommandCatalog.swift, Tests/command-ids/photo.txt, Tests/PhotoModelTests/PhotoLayerStyleTests.swift | PhotoLayerStyleTests (disabled), command-id list | – | blocked (LS-a) |
| PY-2 | PY-a | 2 | Layer menu items by id; panel sheet while `stylePanel` is set; pasteboard via `LayerStylePasteboard` | Sources/PhotoApp/PhotoCommands+Layer.swift, Sources/PhotoApp/PhotoWindow+Styling.swift, Sources/PhotoApp/PhotoWindow.swift | PhotoLayerStyleSnapshots.panel | – | waiting (PY-1) |
| PY-5 | PY-m | 2 | adapter bodies; tests on | Sources/PhotoModel/PhotoStyle+Kernel.swift, Tests/PhotoModelTests/PhotoLayerStyleTests.swift, Tests/mutations/PhotoModel.PhotoStyle+Kernel.json | PhotoLayerStyleTests | – | waiting (PY-1, LS-m) |
| PY-6 | PY-m | 2 | styles in composite and `.ora`; RJ-P44, RJ-X51 | Sources/PhotoModel/PhotoLayerComposite.swift, Sources/PhotoModel/PhotoDocumentFile.swift, Tests/PhotoModelTests/PhotoStyleRenderTests.swift, Tests/mutations/PhotoModel.PhotoLayerComposite.json, Tests/mutations/PhotoModel.PhotoDocumentFile.json, Tests/RealJobs/photo/outline-cutout/, Tests/RealJobs/photo/style-drop-shadow/ | PhotoStyleRenderTests | – | waiting (PY-1, LS-m) |
| PY-3 | PY-u | 3 | snapshots, render budget | Tests/AppSnapshotTests/PhotoLayerStyleSnapshots.swift, Tests/AppSnapshotTests/RenderBudgetPhotoLayerStyleTests.swift | RenderBudgetPhotoLayerStyleTests.distanceScrubInThreeBodies | – | waiting (PY-2) |
| PY-4 | PY-u | 3 | journey written, skipped | UITests/PhotoJourneyTests+LayerStyle.swift | compiles, skipped | – | waiting (PY-2) |
| PY-7 | PY-z | 4 | live canvas via `StyleRoute`; journey on | Sources/PhotoModel/PhotoRenderRoute.swift, UITests/PhotoJourneyTests+LayerStyle.swift | PhotoLayerStyleJourneyTests.testDropShadowAndStroke | – | waiting (PY-4..6, LS-gpu, IM-photo) |
| PY-8 | PY-z | 5 | photo.md row; `status: built`; `feature-done` | docs/blueprints/photo.md, docs/blueprints/photo/features/layer-styles.wave.json | scripts/waves render --dry-run | – | waiting (PY-7, PY-3, TX-z) |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- Worked from `origin/dev`, not `main`: the brief named `main` (verified at 0dd23d65), but the packet exists only on dev (main is 365 commits behind) and CLAUDE.md says branch from and target dev.
- No task starts: PY-1 needs SuiteImaging's `LayerStyle`, `LayerStyleTarget` and `StyleCommands`, none of which exist on dev (no SuiteImaging target yet). Rule 20 forbids a Photo copy, and LS-a is the suiteui line's work, so nothing is stubbed here.

## Open
- Blocked on suiteui layer-styles LS-a (#3937, not started, `waiting-on-prereq`). LS-a itself waits on suite-imaging:IM-a (IM-1 #4028 in the Mac gate, IM-2 stacked), brush-keys:BK-u, gradient-fill:GF-a, and a creative-core bump carrying LE-a's types (bump PR #3825, per #3935).
