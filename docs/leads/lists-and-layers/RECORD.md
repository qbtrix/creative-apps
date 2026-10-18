# lists-and-layers lead record

Issue: #1510 · Packet: docs/blueprints/suiteui/features/lists-and-layers.md
Run: act-1a1504abd7d-2wty (line lead with #1344, #1512, #1510; took over from act-1a14d48ae2f-857a)
Stage: waiting on scoped suiteui 39175856233 (dev e0a627c, carries #2992; in progress). Scoped suite 39172233475 ran no journeys or snapshots; full 39173775025 cancelled; full 39176304199 pending
Base: 2e27b8db (origin/dev)
Next: on suiteui artifacts: golden PRs (canvas, sidebar), editor-chrome contact sheet or gaps, #2839 call, list journeys check

## Slices
Not a v3 packet (no `## Slices` table). v2 loop, contract rule 18 applies.

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| LL-1 | 1 | list contracts and Fakes | Contracts/GridSelecting.swift, Contracts/ListEditing.swift | ListFakeTests | merged | merged |
| LL-4 | 1 | SidebarItem.isDimmed | SidebarRow.swift | SidebarTests | merged | merged |
| LL-2 | 2 | SuiteListEditing (QB-S14) | ListEditing.swift | ListEditingTests | #2547 | merged |
| LL-3 | 3 | SuiteGridSelecting (QB-S28) | GridSelection.swift | GridSelectionReferenceTests | #2648 | open, lane |
| LL-6 | 3 | refusable rename | SidebarRow.swift, SidebarSection.swift, SuiteWindow.swift | SidebarRenameRefusalTests | #2651 | open, lane (MAC_GATED) |
| LL-5 | 4 | withdrawn: LayerTreeList is editor-kernel EK-4 | LayerList.swift | LayerListTests | – | withdrawn |
| LL-7 | 4 | Return rename | SidebarRow.swift | SidebarKeyboardRenameTests | – | planned |
| LL-8a | 4 | row context menus (part of #73) | SidebarSection.swift, SuiteWindow.swift | SidebarContextMenuTests | – | planned |
| LL-12 | 4 | ThumbnailGrid | ThumbnailGrid.swift | SuiteGridSnapshots | – | planned |
| LL-8b | 5 | withdrawn: menus on LayerTreeList, EK-5 | LayerList.swift | SidebarContextMenuTests | – | withdrawn |
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
- 2026-10-18: LL-5 and LL-8b withdrawn by the packet's kernel fold (2026-10-17); LL-13 shows LayerTreeList, LL-16 records its baseline.
- 2026-10-18: resumed under run act-1a14c4f9bb5-swq8; base moved to dev a6150139a815efa68d34af8723a1b58eea894f9c; no task of this feature was built in the meantime (checked dev for each owned symbol).
- 2026-10-18: wave 1 built, PRs held: scripts/ci fails on dev itself (five quarantine entries expire 2026-10-18), raised as #2504. Builder branches use a dash (lead/lists-and-layers-<id>) because lead/lists-and-layers exists as a ref.
- 2026-10-18T06:12Z: wave 3 PRs #2648, #2651. Tool footers stripped and verified; line:suiteui added. LL-6 also touches SuiteSidebarList.swift (the rename passes through it between SidebarSection and SuiteWindow). It is in this line, so accepted.
