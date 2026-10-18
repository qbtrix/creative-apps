# design-seams-2 lead record

Issue: (feature issue not filed yet; packet says filed once S2-a's waits are done) · Packet: docs/blueprints/design/features/design-seams-2.md
Run: act-1a14cd4adaa-upx1 (resumes act-1a14a8f0634-uwzw) · Session: this session · Started: 2026-10-16T20:49Z
Stage: parked (out of the beta cut)
Base: 948bcbf40cb0efa747755eb338f50ca1f06012d6 (origin/main, 948bcbf)
Next: nothing until after beta. Supervisor on #1526, 2026-10-17T06:06Z: parked, needs-human stays, the line lead drops this feature from its brief.

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| S2-a | file v2 with path, component, bound variable; tier-2 contract | D2-1a, D2-1b, D2-2 | MJ6 | style-rows SR-m, SR-b; files-history FH-a; layers-panel LP-b; design-contracts (built) | no | 0 | waiting | – | – |
| S2-b | menus and sheet slots for Export, Components, Variables; pen and tier-2 model on the fakes | D2-3a, D2-3b, D2-4a, D2-4b | J1, MJ7 | S2-a; layers-panel LP-b; design-seams; select-several SS-b; design-window; style-rows SR-b; files-history FH-b; canvas-basics; snapping SN-b, SN-c | yes | 0 | waiting | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| D2-1a | S2-a | 1 | case path, path on node | DesignNode.swift, DesignInspectorContent.swift, DesignCorners.swift, DesignCanvasMarks.swift | DesignPathKindTests | – | waiting (style-rows SR-m, SR-b) |
| D2-1b | S2-a | 2 | componentID, fillVariableID, file version 2, MJ6 | DesignNode.swift, DesignFile.swift, Live/LiveFiling.swift, DesignHistory.swift, DesignWorkspace.swift | DesignTierTwoSchemaTests | – | waiting (D2-1a; FH-a; LP-b) |
| D2-2 | S2-a | 3 | tier-2 fakes and live stubs | Fakes/DesignTierTwoFakes.swift, Live/*, DesignServices.swift | DesignContractLawTierTwoTests | – | waiting (D2-1b) |
| D2-3a | S2-b | 4 | tier-2 actions, previewMode, displayFill | DesignActions+TierTwo.swift, DesignWorkspace.swift | DesignActionsTierTwoTests | – | waiting (D2-2; LP-b) |
| D2-3b | S2-b | 5 | pen routes; MJ7 | DesignCanvasEditing.swift, DesignActions+TierTwo.swift, DesignWorkspace.swift | DesignPenRouteTests, DesignSeams2JourneyTests | – | waiting (D2-3a; design-seams; SS-b; CB; SN-b) |
| D2-4a | S2-b | 6 | canvas draws paths, instances, bound fills | DesignCanvasMarks.swift, DesignCanvas.swift | DesignTierTwoCanvasSnapshots, DesignPenDragTests | – | waiting (D2-3b; design-window; SR-b; CB) |
| D2-4b | S2-b | 6 | menus, toolbar, sheet slots, J1; carries feature-done | DesignIntent.swift, DesignWindow.swift, DesignCommands.swift, DesignObjectMenu.swift, DesignEditor.swift, DesignExportSheet.swift, DesignVariablesSheet.swift, Sources/DesignModel/DesignWindowOptions.swift, UITests/DesignJourneyTests.swift | DesignTierTwoMenuSnapshots | – | waiting (D2-3a; design-window; FH-b; CB; SN-c) |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|
| – | – | – | – | – | – |

## Decisions
- Base: origin/dev (see design-seams RECORD). 
- Holds: the packet's waits are on features still marked "planned" (style-rows, files-history, layers-panel, select-several, canvas-basics, design-window, snapping). Nothing here starts before those merge.
- design-seams-2 is not started and no tasks are dispatched.

## Open
- Waits on planned features; the feature issue has not been filed yet (the packet says file it once S2-a's waits are done).
