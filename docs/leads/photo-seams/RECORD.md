# photo-seams lead record

Issue: #812 · Packet: docs/blueprints/photo/features/photo-seams.md
Run: act-1a13d5e8ca4-huz5 · Session: cloud lead session · Started: 2026-10-15T02:23Z
Stage: 3 wave 8
Base: c4ec07810683a4bc7d62dcc5205705229f248a71
Next: wait for the S-7a builder (stacked on S-5, now on dev); read CI run 723/724 (first to include #956) for the macOS compile

## Tasks

One builder per task, in packet order; each wave is one task because the
packet chains every task on the one before it (shared files or new types).
`S-13`'s model half may run beside the app chain once S-7b has merged.

| id | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|
| S-1 | 1 | shared, document, edit and crop contracts (5.1) | M/Contracts/{PhotoContractTypes,DocumentContracts,EditContracts,CropContracts}.swift | PhotoContractsTests | #932 | merged |
| S-2 | 2 | selection, layer and output contracts (5.1) | M/Contracts/{Selection,Layer,Output}Contracts.swift | PhotoContractsLayerTests | #948 | merged |
| S-3 | 3 | fakes (5.2) | M/Fakes/Fake{Documents,Edit,Geometry,Output}.swift | PhotoFakesTests | #950 | merged |
| S-4 | 4 | PhotoServices, NotBuilt, Live/ stubs | M/PhotoServices.swift, M/Live/*.swift | LiveServicesTests | #951 | merged |
| S-6a | 5 | v2 stored state, layer kinds, .eyedropper, toolHelp, insertLayer, geometry hook decl | M/PhotoWorkspace, PhotoLayer, AdjustmentSettings, PhotoMask, PhotoStroke; A/PhotoIntent, A/PhotoPanel | PhotoV2StateTests | #956 | merged |
| S-6b | 6 | step ids, isDirty, .selection/.maskTiles steps | M/PhotoHistory.swift | PhotoStepIDTests | #959 | merged |
| S-5 | 7 | fixtures empty/sample/layered/large | M/PhotoFixtures.swift | PhotoFixturesTests | #966 | merged |
| S-7a | 8 | drags with modifiers and zoom, routing, eyedropper stub | M/PhotoStroke, PhotoSelectionMask, PhotoCropSize, PhotoTransform, PhotoEyedropper | PhotoToolsTests, PhotoDragRoutingTests | – | todo |
| S-7c | 9 | paintTarget, selectionCoverage weighting | M/PhotoStroke, PhotoRetouch, PhotoSelection, PhotoSelectionMask | PhotoPaintTargetTests | – | todo |
| S-7b | 10 | PhotoLayerComposite hook; geometry hook calls | M/PhotoRender, PhotoLayerComposite, PhotoImageOps, PhotoStraighten | PhotoLayerCompositeTests | – | todo |
| S-8a | 11 | PhotoIntent sub-enums, nine area files | A/PhotoIntent, PhotoWindow, PhotoWindow+*.swift | app-state rule; V1–V12 | – | todo |
| S-8b | 12 | open/save/export into area files; fileServices | A/PhotoWindow{,+File,+Export}.swift | V2, V5, V6 | – | todo |
| S-9 | 13 | menu bar split per menu | A/PhotoCommands{,+File,+Edit,+Select,+Image,+Layer,+View}.swift | V4; PhotoSelectAllMenuTests | – | todo |
| S-10a | 14 | top bar, status line, PhotoRailTool | A/PhotoEditor, PhotoTopBar, PhotoStatusLine, PhotoRailTool; ST/PhotoEditorSnapshots | photo-status-message-dark.png | – | todo |
| S-10b | 15 | overlays, hover, Return/Escape, StrokePacer modifiers | A/PhotoEditor, PhotoWindow, *Overlay.swift, StrokePacer; ST/PhotoStrokePacerTests | PhotoStrokePacerTests; V7, V9 | – | todo |
| S-11a | 16 | panel split 1: Adjust tab, tool options | A/PhotoPanel, PhotoAdjustTab, PhotoToolOptions, *Options.swift | snapshots unchanged | – | todo |
| S-11b | 17 | panel split 2: Layers tab, History stub | A/PhotoPanel, PhotoLayersTab, PhotoHistoryTab | PhotoLayerRowSnapshots | – | todo |
| S-12 | 18 | -PhotoFixture, -PhotoWindowWidth, Preview data pill | M/PhotoFixtures, A/PhotoApp, PhotoWindow, PhotoStatusLine | PhotoLaunchOptionsTests; photo-preview-pill-dark.png | – | todo |
| S-13 | 19 | budgets PB-2, PB-9 (feature-done) | MT/PhotoBudgetTests, ST/PhotoBrushLatencyTests | PhotoBudgetTests | – | todo |

## Rounds
| round | CI run | CI | audit vs baseline | lenses | confirmed | fixed by | clean |
|---|---|---|---|---|---|---|---|

## Decisions
- Waves of one task each, in the packet's chain order; the next builder starts once the previous PR has merged into dev.
- Builder branches are lead/photo-seams-<id> (a dash: lead/photo-seams already exists). The next builder stacks on the previous branch and opens its PR after rebasing onto dev once the previous PR merged.
- Lead step after S-4 merges: file the four needs-ui issues of blueprint 6.3 (SelectionPathOutline, SelectionHandles with rotation, BrushCursorMark, LayerList row symbol and accessory).

## Open
- needs-ui filed: #952 SelectionPathOutline, #953 BrushCursorMark, #954 LayerList symbol and accessory. SelectionHandles with rotation is SuiteUI canvas-marks CM-4 (#273), no new issue.
- Watch: first app-code merge is #956 (ce3e768). Check the first completed macOS CI run on dev at or after ce3e768 for PhotoIntent/PhotoPanel compile errors.
- S-6b: a coalesced step gets a fresh id; PhotoStack keeps masks but not selectionMask (S-7c may add it).
- dev CI was red before this feature (runs 717-722 fail in UI journeys of other lines; Linux green). Not ours; the dev-red issue tracks it.
- S-6a adds `extension CurvePoint: @retroactive Codable`; it must go if creative-core makes CurvePoint Codable. The "I" key still selects the disabled Eyedropper until S-10a.
