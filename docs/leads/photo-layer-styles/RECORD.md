# layer-styles lead record

Issue: #3793 · Packet: docs/blueprints/photo/features/layer-styles.md
Run: act-1a16f6941b7-zb0r · Session: claude/feature-lead-tone-layer-styles-v57ny4 · Started: 2026-10-24T19:30Z (takes over from act-1a16cd04539-4jc0)
Stage: W1 shipped (PY-1 #5177 in the lane); W2 waiting on LS-a's LS-2 #5174 (PY-2) and LS-m #5176 (PY-5, PY-6)
Base: 78983bc33 (PY-1); dev 6f66ca334 at 19:39Z
Next: PY-2 stacked on #5177 once #5174 (panel, `LayerStylePasteboard`) merges; PY-5/PY-6 once #5176 (LS-m) merges

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| PY-a | `PhotoLayer.style`, `style.*` in the catalog on stubs, Layer > Layer Style… opens the panel | PY-1, PY-2 | MJ-PY | multi-layer-select (built #3535); file-flow:PF-m (done); suiteui layer-styles LS-a (merged #4911) | yes | 0 | building | – | – |
| PY-u | panel snapshots, render budget, journey written | PY-3, PY-4 | PJ-Y1 | PY-a | yes | 0 | waiting | – | – |
| PY-m | style commands as one undo step, composite draws styles padded, `.ora` keeps them | PY-5, PY-6 | MJ-PY | PY-a; LS-m | no | 0 | waiting | – | – |
| PY-z | live canvas through `StyleRoute`, journey on live, photo.md built | PY-7, PY-8 | PJ-Y1 | PY-u, PY-m; text-layers:TX-z (PY-8); LS-gpu, IM-photo (PY-7) | yes | 0 | waiting | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| PY-1 | PY-a | 1 | `PhotoLayer.style`; adapter stubs (`showStylePanel` real); catalog specs and ids; tests disabled | Sources/PhotoModel/PhotoLayer.swift, Sources/PhotoModel/PhotoStyle+Kernel.swift, Sources/PhotoModel/PhotoCommandCatalog.swift, Tests/command-ids/photo.txt, Tests/PhotoModelTests/PhotoLayerStyleTests.swift | PhotoLayerStyleTests (disabled), command-id list | #5177 | PR open, fast-lane (head 484c897c7); head 11905cabb (dev merged 15:10Z), back in the lane |
| PY-2 | PY-a | 2 | Layer menu items by id; panel sheet while `stylePanel` is set; pasteboard via `LayerStylePasteboard` | Sources/PhotoApp/PhotoCommands+Layer.swift, Sources/PhotoApp/PhotoWindow+Styling.swift, Sources/PhotoApp/PhotoWindow.swift | PhotoLayerStyleSnapshots.panel | – | waiting (PY-1 #5177, LS-2 #5174) |
| PY-5 | PY-m | 2 | adapter bodies; tests on | Sources/PhotoModel/PhotoStyle+Kernel.swift, Tests/PhotoModelTests/PhotoLayerStyleTests.swift, Tests/mutations/PhotoModel.PhotoStyle+Kernel.json | PhotoLayerStyleTests | – | building ahead on lead/photo-layer-styles-PY-5 (stacked on PY-1); command-level tests wait on LS-6 |
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
- Run act-1a16f6941b7-zb0r (2026-10-24T19:30Z) takes over; base dev. The brief named lead/layer-styles; it belongs to the live SuiteUI lead (#3937, last commit 19:35Z), so it is not force-pushed and status stays on lead/photo-layer-styles.

## Open
- 2026-10-26 (run act-1a175e3e605-92wn): resumed; main d3323f6 verified, base dev 8eff8ab. #5177 (PY-1, head 9aa01d737, Linux run 40237322830 green, prescreen success), #5174 (LS-2) and #5176 (LS-5) all open, clean, in the lane; dev-red #5321 (macOS, none ours). PY-5's Photo-side `setStyle` body needs nothing from LS-6, so it is built now, stacked on PY-1; the PR opens once #5177 lands.
- 13:12Z: PY-1 PR #5177 open (186+/3−, 10 files, Mutate 4/4, Wire: PY-5). Lead accepts its +4/−1 to Sources/PhotoModel/PhotoWorkspace.swift (same line; the contract's `stylePanel` must be stored and an extension can't store). PY-2 needs the SuiteUI style panel and `LayerStylePasteboard`, not on dev: they come with LS-2 #5174.
- 12:22Z: LS-1 #4911 merged (78983bc33); `Sources/SuiteImaging/Style/` on dev. PY-1 builder launched on that base.
- 2026-10-24T07:35Z (run act-1a16cd04539-4jc0): LS-1 #4911 (the LS-a contract, `Style/` stubs) is open, clean and queued in the lane; dev 830af22de has SuiteImaging Adjust, Color, Retouch, Route, Select and Tone, but no Style. PY-1 still waits; rule 20 rules out a Photo copy.
- 2026-10-23T15:35Z: dev 721168a8f has SuiteImaging (Adjust, Color, Retouch, Route, Tone) but no Style/: no `LayerStyle`, `LayerStyleTarget` or `StyleCommands`. #3937 is unparked under rule 12 too but has no LS-a PR yet. Rule 20 still rules out a Photo copy, so PY-1 waits; this run builds tone-controls meanwhile.
- Blocked on suiteui layer-styles LS-a (#3937, still `waiting-on-prereq` at 03:13Z). LS-a waits on suite-imaging:IM-a (IM-1 #4028 still open: Linux green at 02:30Z, macOS job skipped, awaiting the supervisor macOS run and merge; IM-2 stacked), brush-keys:BK-u, gradient-fill:GF-a, and core types from LE-a. Bump #3825 (7966e5a) merged 2026-10-21 but carries only Flare core PRs. No `SuiteImaging` target or `LayerStyle` types on dev 66a8458.
- Belt watches `lead/photo-layer-styles` (with `docs/leads/photo-layer-styles/`). This record is mirrored there; `lead/layer-styles` is the brief's original channel and stays in sync.
- 09:27Z: LS-1 #4911 is 6th of 12 in lane batch 20261024081307, which is bisecting. PY-1 starts when it lands on dev.

- Note: editing a PR body via `gh api -X PATCH` appends a footer; edit bodies via the GitHub MCP update_pull_request tool instead.
