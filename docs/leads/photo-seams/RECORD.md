# photo-seams lead record

Issue: #812 · Packet: docs/blueprints/photo/features/photo-seams.md
Run: act-1a13d5e8ca4-huz5 · Session: cloud lead session · Started: 2026-10-15T02:23Z
Stage: 3 wave 15 (S-10b)
Base: c4ec07810683a4bc7d62dcc5205705229f248a71
Next: wait for #987; S-10b stacks on lead/photo-seams-S-10a; no macOS run yet contains #978 (726 started before it)

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
| S-7a | 8 | drags with modifiers and zoom, routing, eyedropper stub | M/PhotoStroke, PhotoSelectionMask, PhotoCropSize, PhotoTransform, PhotoEyedropper | PhotoToolsTests, PhotoDragRoutingTests | #969 | merged |
| S-7c | 9 | paintTarget, selectionCoverage weighting | M/PhotoStroke, PhotoRetouch, PhotoSelection, PhotoSelectionMask | PhotoPaintTargetTests | #972 | merged |
| S-7b | 10 | PhotoLayerComposite hook; geometry hook calls | M/PhotoRender, PhotoLayerComposite, PhotoImageOps, PhotoStraighten | PhotoLayerCompositeTests | #974 | merged |
| S-8a | 11 | PhotoIntent sub-enums, nine area files | A/PhotoIntent, PhotoWindow, PhotoWindow+*.swift | app-state rule; V1–V12 | #978 | merged |
| S-8b | 12 | open/save/export into area files; fileServices | A/PhotoWindow{,+File,+Export}.swift | V2, V5, V6 | #985 | merged |
| S-9 | 13 | menu bar split per menu | A/PhotoCommands{,+File,+Edit,+Select,+Image,+Layer,+View}.swift | V4; PhotoSelectAllMenuTests | #986 | merged |
| S-10a | 14 | top bar, status line, PhotoRailTool | A/PhotoEditor, PhotoTopBar, PhotoStatusLine, PhotoRailTool; ST/PhotoEditorSnapshots | photo-status-message-dark.png | #987 | open |
| S-10b | 15 | overlays, hover, Return/Escape, StrokePacer modifiers | A/PhotoEditor, PhotoWindow, *Overlay.swift, StrokePacer; ST/PhotoStrokePacerTests | PhotoStrokePacerTests; V7, V9 | – | todo |
| S-11a | 16 | panel split 1: Adjust tab, tool options | A/PhotoPanel, PhotoAdjustTab, PhotoToolOptions, *Options.swift | snapshots unchanged | – | todo |
| S-11b | 17 | panel split 2: Layers tab, History stub | A/PhotoPanel, PhotoLayersTab, PhotoHistoryTab | PhotoLayerRowSnapshots | – | todo |
| S-12 | 18 | -PhotoFixture, -PhotoWindowWidth, Preview data pill | M/PhotoFixtures, A/PhotoApp, PhotoWindow, PhotoStatusLine | PhotoLaunchOptionsTests; photo-preview-pill-dark.png | – | todo |
| S-13a | 11 | PB-2 clone/heal and PB-9 move budgets (model half) | MT/PhotoBudgetTests | PhotoBudgetTests | #979 | merged |
| S-13b | 19 | PB-2 event-to-picture latency series (feature-done) | ST/PhotoBrushLatencyTests | PhotoBrushLatencyTests | – | todo |

## Rounds
| round | CI run | CI | audit vs baseline | lenses | confirmed | fixed by | clean |
|---|---|---|---|---|---|---|---|

## Decisions
- Waves of one task each, in the packet's chain order; the next builder starts once the previous PR has merged into dev.
- S-7c clips brush, eraser, clone and heal to an existing selection rect (coverage 0 outside). Kept: the packet says coverage is 1 inside the rect; no v1 journey paints with a selection active (checked UITests/PhotoJourneyTests.swift). Crop undo does not restore selectionMask: left to PV-5 (add selectionMask to PhotoStack).
- S-13 split in two: its model half (PhotoBudgetTests) runs beside the app chain as the packet allows; the latency series carries feature-done last.
- S-8a: flat .export became .export(.openSheet) (a case name clash); area modifiers take PhotoPerform (@MainActor); confirmTransform/dismissTransform are app stubs returning false until PV-7.
- S-10a: existing editor snapshots should not change (they already ran on .live with the Eyedropper disabled); the 4 s clearStatus task lives in PhotoWindow; status message id photo.status.message.
- S-7b reference digests were recorded on Linux; if a macOS model test disagrees, check PhotoLayerCompositeTests first.
- Builder branches are lead/photo-seams-<id> (a dash: lead/photo-seams already exists). The next builder stacks on the previous branch and opens its PR after rebasing onto dev once the previous PR merged.
- Lead step after S-4 merges: file the four needs-ui issues of blueprint 6.3 (SelectionPathOutline, SelectionHandles with rotation, BrushCursorMark, LayerList row symbol and accessory).

## Open
- needs-ui filed: #952 SelectionPathOutline, #953 BrushCursorMark, #954 LayerList symbol and accessory. SelectionHandles with rotation is SuiteUI canvas-marks CM-4 (#273), no new issue.
- Quality finding for round 1 (quality lens): S-13a times 6 px steps with a 64 px brush, so many events put down no dab; heal release p50 0.56 ms but p95 4.6 ms, likely the real per-dab cost (> PB-2 1 ms). Round 1 fix: time events that each dab (step >= dab spacing); if heal misses PB-2 per dab, file a line:photo gap for heal speed.
- #956 app code verified: run 38679533707 (723, 54e16aa) macOS scripts/ci green (compile + snapshots); all 12 Photo journeys ran; photo audit at or under baseline (identifier 16 vs 23). Run red from halo (identifier 14>8) and library (identifier 21>16), not this feature; dev-red #763.
- S-6b: a coalesced step gets a fresh id; PhotoStack keeps masks but not selectionMask (S-7c may add it).
- dev CI was red before this feature (runs 717-722 fail in UI journeys of other lines; Linux green). Not ours; the dev-red issue tracks it.
- docs/c4/model.json PhotoModel description should mention contracts, fakes, services and drag routing; the packet defers it to the supervisor (no c4 edit in this feature).
- S-6a adds `extension CurvePoint: @retroactive Codable`; it must go if creative-core makes CurvePoint Codable. The "I" key still selects the disabled Eyedropper until S-10a.
