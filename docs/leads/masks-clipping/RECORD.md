# masks-clipping lead record

Issue: #4517 · Packet: docs/blueprints/photo/features/masks-clipping.md
Run: act-1a164697363-4fnm · Session: claude/feature-lead-photo-features-kilpzc · Started: 2026-10-22T16:00Z
Stage: 3 wave 1
Base: 7e9f260 (origin/dev)
Next: open PK-a's first PR (PK-1, mask half); then PK-5 stacked on it

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| PK-a | mask and clip commands in the catalog on stubs with reasons; clip flag; Layer menu and rows show them | PK-1, PK-2 | MJ-PK | layer-styles:PY-a (unchained for PK-1, see Decisions); multi-layer-select (built) | yes | 0 | building | – | – |
| PK-u | snapshots, render budget, both journeys written | PK-3, PK-4 | PJ-13, PJ-K2 | PK-a | yes | 0 | waiting | – | – |
| PK-m | add/delete/apply/enable/paint mask, clip/release, one step each; composite; `.ora` | PK-5, PK-6, PK-7, PK-8 | MJ-PK | PK-a; layer-styles:PY-m (PK-7, PK-8); LS-clip (PK-8, cross-line) | no | 0 | waiting | – | – |
| PK-z | journeys on live; photo.md built | PK-9, PK-10 | PJ-13, PJ-K2 | PK-u, PK-m | no | 0 | waiting | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| PK-1 | PK-a | 1 | `PhotoLayer.isClipped`; mask API stubs with reasons; five mask specs and ids; PhotoLayerMaskTests disabled | Sources/PhotoModel/PhotoLayer.swift, Sources/PhotoModel/PhotoMask.swift, Sources/PhotoModel/PhotoCommandCatalog.swift, Tests/command-ids/photo.txt, Tests/PhotoModelTests/PhotoLayerMaskTests.swift | command ids match; each mask command unavailable with its reason | – | building |
| PK-5 | PK-m | 2 | mask bodies, geometry hook; PhotoLayerMaskTests on | Sources/PhotoModel/PhotoMask.swift, Tests/PhotoModelTests/PhotoLayerMaskTests.swift, Tests/mutations/PhotoModel.PhotoMask.json | PhotoLayerMaskTests | – | waiting (PK-1) |
| PK-6 | PK-m | 3 | paint the mask: grey dabs, eraser | Sources/PhotoModel/PhotoStroke.swift, Tests/PhotoModelTests/PhotoMaskPaintTests.swift, Tests/mutations/PhotoModel.PhotoStroke.json | PhotoMaskPaintTests | – | waiting (PK-5) |
| PK-2 | PK-a | – | Layer menu items; row badge and clip indent | Sources/PhotoApp/PhotoCommands+Layer.swift, Sources/PhotoApp/PhotoLayerList.swift | PhotoMaskSnapshots.badge | – | waiting (PK-1; PY-2 for the Layer menu file) |
| PK-3 | PK-u | – | snapshots, render budget | Tests/AppSnapshotTests/PhotoMaskSnapshots.swift, Tests/AppSnapshotTests/RenderBudgetPhotoMaskTests.swift | RenderBudgetPhotoMaskTests.maskStrokeInThreeBodies | – | waiting (PK-2) |
| PK-4 | PK-u | – | journeys written, skipped | UITests/PhotoJourneyTests+Mask.swift | compiles, skipped | – | waiting (PK-2) |
| PK-7 | PK-m | – | masked/clipped composite; RJ-P05, RJ-P45 | Sources/PhotoModel/PhotoLayerComposite.swift, Tests/PhotoModelTests/PhotoMaskCompositeTests.swift, Tests/mutations/PhotoModel.PhotoLayerComposite.json, Tests/RealJobs/photo/soft-mask-blend/, Tests/RealJobs/photo/clip-texture/ | PhotoMaskCompositeTests | – | waiting (PK-5, PK-8, PY-6) |
| PK-8 | PK-m | – | ClipTarget conformance, clip specs and ids, bodies; flag in `.ora`; PhotoClipTests written and on | Sources/PhotoModel/PhotoClip+Kernel.swift, Sources/PhotoModel/PhotoDocumentFile.swift, Tests/PhotoModelTests/PhotoClipTests.swift, Tests/mutations/PhotoModel.PhotoClip+Kernel.json, Tests/mutations/PhotoModel.PhotoDocumentFile.json | PhotoClipTests | – | waiting (LS-clip, PY-6) |
| PK-9 | PK-z | – | journeys on | UITests/PhotoJourneyTests+Mask.swift | both journeys | – | waiting |
| PK-10 | PK-z | – | photo.md rows; built; feature-done | docs/blueprints/photo.md, docs/blueprints/photo/features/masks-clipping.wave.json | scripts/waves render --dry-run | – | waiting |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- Worked from `origin/dev` 7e9f260, not `main`: main lacks the packets; CLAUDE.md says dev.
- Unchained PK-1 from layer-styles:PY-1. PK-1 needs none of PY-1's code; the wait only ordered edits to `PhotoLayer.swift` and `PhotoCommandCatalog.swift`, and PY-1 can't start (suiteui LS-a #3937 not started). The lane integrates the later conflict.
- PK-1 ships the mask half only. `ClipTarget`, `ClipRules` and `ClipCommands` (suiteui LS-clip) don't exist on dev, and rule 20 forbids a Photo copy, so the clip conformance, `layer.clip`/`layer.unclip` ids and `PhotoClipTests` move to PK-8, which already waits on LS-clip. `isClipped` lands in PK-1.
- PK-5 starts right after PK-1, stacked on its branch (rule 22); PK-2 waits on PY-2 only for `PhotoCommands+Layer.swift` and is re-read each check.

## Open
- PK-8 waits on suiteui LS-clip (#3937, `waiting-on-prereq`); PK-7/PK-8 on layer-styles:PY-6 (blocked on LS-m).
