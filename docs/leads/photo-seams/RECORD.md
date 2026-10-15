# photo-seams lead record

Issue: #812 · Packet: docs/blueprints/photo/features/photo-seams.md
Run: act-1a13d5e8ca4-huz5 · Session: cloud lead session · Started: 2026-10-15T02:23Z
Stage: 4 round 3
Base: c4ec07810683a4bc7d62dcc5205705229f248a71
Next: r3-b1 fixer (journey lookups) and round 3 panel running; fold confirmed in-scope findings into one more batch if time allows; then a feature-done PR for round 4 (last round)

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
| S-10a | 14 | top bar, status line, PhotoRailTool | A/PhotoEditor, PhotoTopBar, PhotoStatusLine, PhotoRailTool; ST/PhotoEditorSnapshots | photo-status-message-dark.png | #987 | merged |
| S-10b | 15 | overlays, hover, Return/Escape, StrokePacer modifiers | A/PhotoEditor, PhotoWindow, *Overlay.swift, StrokePacer; ST/PhotoStrokePacerTests | PhotoStrokePacerTests; V7, V9 | #988 | merged |
| S-11a | 16 | panel split 1: Adjust tab, tool options | A/PhotoPanel, PhotoAdjustTab, PhotoToolOptions, *Options.swift | snapshots unchanged | #989 | merged |
| S-11b | 17 | panel split 2: Layers tab, History stub | A/PhotoPanel, PhotoLayersTab, PhotoHistoryTab | PhotoLayerRowSnapshots | #991 | merged |
| S-12 | 18 | -PhotoFixture, -PhotoWindowWidth, Preview data pill | M/PhotoFixtures, A/PhotoApp, PhotoWindow, PhotoStatusLine | PhotoLaunchOptionsTests; photo-preview-pill-dark.png | #992 | merged |
| S-13a | 11 | PB-2 clone/heal and PB-9 move budgets (model half) | MT/PhotoBudgetTests | PhotoBudgetTests | #979 | merged |
| S-13b | 19 | PB-2 event-to-picture latency series (feature-done) | ST/PhotoBrushLatencyTests | PhotoBrushLatencyTests | #997 | merged |

## Rounds
| round | CI run | CI | audit vs baseline | lenses | confirmed | fixed by | clean |
|---|---|---|---|---|---|---|---|
| 1 | 38687993459 (727, 8f78bad) | photo green (12 journeys pass; macOS scripts/ci green); run red from SuiteUI testGalleryOpensEveryPage and Halo testLayoutAtWidths (#763) | photo all at or under (identifier 16 vs 23) | clarity, journey, design, layout, controls, quality | 6 (2 major: preview pill not a warning pill; no Escape-cancels-crop journey. 4 minor: refusal names no place; refusal in warning not error style; no -PhotoFixture launch journey; clone/heal re-stamp the previous dab). 3 refuted (NotBuilt wording by design; Help menu and SuiteUI slider marker outside feature) | #1012 (r1-b1 status line), #1010 (r1-b2 model; heal release p50 0.60 -> 0.31 ms), #1011 (r1-b3 journeys) | no |
| 2 | 38694361192 (fdb7c8a) | photo green (13 journeys incl. testFixtureLaunch and crop-cancelled; macOS scripts/ci green); run red from SuiteUI testGalleryOpensEveryPage, Halo testLayoutAtWidths and testNewComposition (#763) | photo all at or under (identifier 16 vs 23, 93 steps) | same six | 14 kept; in scope: 1 major (fixture launch not fitted) + 8 minor (eyedropper hint x3, pill tooltip, refusal type role, step-5 journey gaps x2, budget step); out of scope v1 -> gap issues #1024 tile-edge lines (p1), #1025 clone source, #1026 selection unit, #1027 render pill | #1029 (r2-b1 fit), #1030 (r2-b2 hint, tooltip, caption type), #1031 (r2-b3 journeys + 20 px budget) | no |
| 3 | 38700713285 (1dcd1a6) | macOS scripts/ci red on SuiteUI FrameProbeTests.summaryWithinBudget (24.4 ms vs 20 ms timing, not this feature; noted on #763); every Photo test passed; UI journeys skipped, so no screens | – | – | – | – | wait for a run with journeys |
| 3b | 38704216123 (731, 92db316) | red in this feature's file: testFixtureLaunch (zoom pill not found by label) and testLaunchShowsWindowShell (help tag not shown on hover), both #1031 test lookups; other failures SuiteUI/Halo (#763) | photo all at or under (identifier 16 vs 23, 92 steps) | same six | panel running | r3-b1 (journey lookups) | no |

## Decisions
- Waves of one task each, in the packet's chain order; the next builder starts once the previous PR has merged into dev.
- S-7c clips brush, eraser, clone and heal to an existing selection rect (coverage 0 outside). Kept: the packet says coverage is 1 inside the rect; no v1 journey paints with a selection active (checked UITests/PhotoJourneyTests.swift). Crop undo does not restore selectionMask: left to PV-5 (add selectionMask to PhotoStack).
- Each round's CI comes from a final feature-done PR (the packet status line, kept current) because the lane on main dispatches only after a feature-done merge.
- Round 1 lead (b) refuted: the hover @State re-runs PhotoCanvas's body but TileCanvas returns early when nothing changed; no picture redraw.
- S-13 split in two: its model half (PhotoBudgetTests) ran beside the app chain as the packet allows. S-13b carries feature-done: the lane script on main (ee57a15, stuck while dev is red) dispatches CI only after a feature-done merge, so that merge starts round 1's run. Each later round's last fix PR carries feature-done again to get its run.
- S-8a: flat .export became .export(.openSheet) (a case name clash); area modifiers take PhotoPerform (@MainActor); confirmTransform/dismissTransform are app stubs returning false until PV-7.
- S-10a: existing editor snapshots should not change (they already ran on .live with the Eyedropper disabled); the 4 s clearStatus task lives in PhotoWindow; status message id photo.status.message.
- S-12: PhotoLaunchOptions, PhotoWorkspace.launch(_:), isPreviewData (services.archive is FakeArchive); -PhotoWindowWidth only sets defaultSize, so a saved frame still wins (Halo used a window sizer).
- S-7b reference digests were recorded on Linux; if a macOS model test disagrees, check PhotoLayerCompositeTests first.
- Builder branches are lead/photo-seams-<id> (a dash: lead/photo-seams already exists). The next builder stacks on the previous branch and opens its PR after rebasing onto dev once the previous PR merged.
- Lead step after S-4 merges: file the four needs-ui issues of blueprint 6.3 (SelectionPathOutline, SelectionHandles with rotation, BrushCursorMark, LayerList row symbol and accessory).

## Open
- #1032 heal dab barely meets PB-2 (release median 0.75-0.97 ms vs 1 ms).
- gap issues from round 2 (v1 behaviour, outside photo-seams): #1024 (tile-edge lines at fractional zoom, p1), #1025, #1026, #1027.
- needs-ui filed: #952 SelectionPathOutline, #953 BrushCursorMark, #954 LayerList symbol and accessory. SelectionHandles with rotation is SuiteUI canvas-marks CM-4 (#273), no new issue.
- Quality finding for round 1 (quality lens): S-13a times 6 px steps with a 64 px brush, so many events put down no dab; heal release p50 0.56 ms but p95 4.6 ms, likely the real per-dab cost (> PB-2 1 ms). Round 1 fix: time events that each dab (step >= dab spacing); if heal misses PB-2 per dab, file a line:photo gap for heal speed.
- Quality watch for round 1: S-10b stores CanvasViewport hover in @State, so every pointer move redraws PhotoCanvas; check PB-1 brush latency and the hitch journey (testBrushStrokeHitchesOnALargePhoto).
- #956 app code verified: run 38679533707 (723, 54e16aa) macOS scripts/ci green (compile + snapshots); all 12 Photo journeys ran; photo audit at or under baseline (identifier 16 vs 23). Run red from halo (identifier 14>8) and library (identifier 21>16), not this feature; dev-red #763.
- S-6b: a coalesced step gets a fresh id; PhotoStack keeps masks but not selectionMask (S-7c may add it).
- dev CI was red before this feature (runs 717-722 fail in UI journeys of other lines; Linux green). Not ours; the dev-red issue tracks it.
- docs/c4/model.json PhotoModel description should mention contracts, fakes, services and drag routing; the packet defers it to the supervisor (no c4 edit in this feature).
- S-6a adds `extension CurvePoint: @retroactive Codable`; it must go if creative-core makes CurvePoint Codable. The "I" key still selects the disabled Eyedropper until S-10a.
