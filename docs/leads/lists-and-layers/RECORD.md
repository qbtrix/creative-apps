# lists-and-layers lead record

Issue: #1510 · Packet: docs/blueprints/suiteui/features/lists-and-layers.md
Run: act-1a146cb0013-zu3h · Session: (this session) · Started: 2026-10-16T22:48Z
Stage: 2 plan
Base: 1f55a91db97af4921e3e46c7d66e3dcf91401097
Next: wave 1 blocked. Needs a Swift toolchain (macOS) and a working GitHub connection to open PRs and comment. See Open.

## Slices
Not a v3 packet (no `## Slices` table). v2 loop, contract rule 18 applies.

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| LL-1 | 1 | list contracts and Fakes | Contracts/GridSelecting.swift, Contracts/ListEditing.swift | ListFakeTests | – | planned |
| LL-4 | 1 | SidebarItem.isDimmed | SidebarRow.swift | SidebarTests | – | planned |
| LL-2 | 2 | SuiteListEditing (QB-S14) | ListEditing.swift | ListEditingTests | – | planned |
| LL-3 | 3 | SuiteGridSelecting (QB-S28) | GridSelection.swift | GridSelectionReferenceTests | – | planned |
| LL-6 | 3 | refusable rename | SidebarRow.swift, SidebarSection.swift, SuiteWindow.swift | SidebarRenameRefusalTests | – | planned |
| LL-5 | 4 | LayerList (closes #146) | LayerList.swift | LayerListTests | – | planned |
| LL-7 | 4 | Return rename | SidebarRow.swift | SidebarKeyboardRenameTests | – | planned |
| LL-8a | 4 | row context menus (part of #73) | SidebarSection.swift, SuiteWindow.swift | SidebarContextMenuTests | – | planned |
| LL-12 | 4 | ThumbnailGrid | ThumbnailGrid.swift | SuiteGridSnapshots | – | planned |
| LL-8b | 5 | LayerList context menus (closes #73) | LayerList.swift | SidebarContextMenuTests | – | planned |
| LL-9 | 5 | app-owned expansion (closes #589, #111) | SidebarSection.swift, SuiteWindow.swift | SidebarNestingTests | – | planned |
| LL-10 | 6 | nesting snapshot (#249) | SuiteSidebarNestingSnapshots.swift | snapshot | – | planned |
| LL-11 | 6 | header colour pin (#284) | SidebarSection.swift | SidebarEdgeTests | – | planned |
| LL-13 | 6 | gallery list pages | Gallery/GalleryLists.swift | CI gallery | – | planned |
| LL-14 | 7 | journeys SJ1b, SJ17, SJ18 (closes #308, #311, #312) | UITests/SuiteJourneyTests+Lists.swift | journey | – | planned |
| LL-15 | 7 | journeys SJ22, SP4 | UITests/SuiteJourneyTests+ListMenus.swift | journey | – | planned |
| LL-16 | 7 | baselines sidebar, layers, nesting | Golden/lists | CI run actuals | – | planned |
| LL-17 | 8 | baselines grid; feature-done | Golden/lists | CI run | – | planned |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|
| – | – | – | – | – | – |

## Decisions
- Loop v2: no `## Slices` table in the packet.
- Suite-harness (#778) is `built`, so every wave-2 wait is met at this base.
- The three features own disjoint files, so one combined plan covers them. Per-packet waves merge by index (see the plan in the lead's scratchpad).
- Status channel: RECORD.md and timeline.tsv pushed to lead/lists-and-layers at each stage, as the user asked. No PRs opened yet.

## Open
- needs-human: no Swift toolchain in the cloud container (scripts/ci --changed fails at swift build), so Fast-Check cannot be proven and SuiteUI cannot compile here.
- needs-human: gh token is invalid and the GitHub MCP server is disconnected, so no PR or issue comment can be posted from this session.
- Waiting on the supervisor: open the wave-1 PRs (builders, fast-lane label).
- Golden baselines (the last CM/LL/IC baseline tasks) need actuals from a dev CI run. They can't be done in one session.
- No macOS here: SwiftUI tasks are checked by the lane's build-only run and dev CI only.
