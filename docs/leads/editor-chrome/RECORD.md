# editor-chrome lead record

Issue: #1344 · Packet: docs/blueprints/suiteui/features/editor-chrome.md
Run: act-1a145e74bc5-jgg4 · Session: claude/editor-chrome-lead-9soj7i · Started: 2026-10-16T18:10Z
Stage: 0 setup (stopped: needs-human; packet superseded, needs rescope)
Base: 7ab292cdb1022222c00314a2b52c44c087811c46
Next: when editor-chrome.wave.json on dev gains a Slices rescope off EditorShell/EditorTopBar/.rail (supervisor note 2026-10-16: "wave data is being re-sliced"), restart at stage 1 on the v3 loop; until then nothing in the packet can start as written

## Tasks
| id | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|
| EC-1 | 1 | four chrome contracts and Fakes | Sources/SuiteUI/Contracts/{ShellLayingOut,ToolPicking,TransportStepping,StatusPillComposing}.swift, Tests/SuiteUITests/ChromeFakeTests.swift | ChromeFakeTests | – | not started (ShellLayingOut needs rescope) |
| EC-2 | 2 | SuiteShellLayout | Sources/SuiteUI/ShellLayout.swift, Tests/SuiteUITests/ShellLayoutTests.swift | ShellLayoutTests | – | blocked: rescope |
| EC-3 | 3 | EditorShell(timeline:) | Sources/SuiteUI/EditorShell.swift, … | EditorShellTests | – | blocked: EditorShell is deleted (captain 2026-10-15) |
| EC-4 | 1 | EditorBarItem .primary, EditorSaveStatus | Sources/SuiteUI/EditorTopBar.swift, … | SuiteEditorBarDimmingTests | – | blocked: EditorTopBar is deleted |
| EC-5 | 2 | TransportCapsule, SuiteTransport | Sources/SuiteUI/TransportCapsule.swift, … | TransportTests | – | valid as written; not started |
| EC-6 | 2 | SuiteStatusPills behind ViewerStatusBar | Sources/SuiteUI/ViewerStatusBar.swift, … | StatusPillTests | – | valid as written; not started |
| EC-7 | 1 | capsule tabs, rail colors | Sources/SuiteUI/SegmentedTabs.swift, ToolbarGroup.swift, … | SuiteTabsSnapshots | – | half blocked: .rail is deleted |
| EC-8 | 2 | SuiteToolPicking behind ToolbarGroup | Sources/SuiteUI/ToolbarGroup.swift, … | ToolPickingTests | – | valid for .floating; ToolbarGroup also owned by editor-shell-removal |
| EC-9 | 4 | editor, editor-plain, empty gallery pages | Sources/SuiteUI/Gallery/GalleryChrome.swift | SJ0 | – | blocked: pages draw EditorShell |
| EC-10 | 5 | SJ1–SJ4 | UITests/SuiteJourneyTests+Chrome.swift | journeys | – | blocked: SJ1–SJ3 drive EditorShell/EditorTopBar |
| EC-11 | 5 | SJ5–SJ8, SP9, SP10 | UITests/SuiteJourneyTests+ChromePanels.swift | journeys | – | blocked: SP10 is the slot drag |
| EC-12 | 4 | goldens: shell, top bar, transport | Tests/AppSnapshotTests/Golden/chrome/ | Golden checks | – | blocked |
| EC-13 | 6 | goldens: pills, tabs, rail; feature-done | Tests/AppSnapshotTests/Golden/chrome/ | Golden checks | – | blocked |

## Rounds
| round | CI run | CI | audit vs baseline | lenses | confirmed | fixed by | clean |
|---|---|---|---|---|---|---|---|

## Decisions
- Packet has no `## Slices` table: v2 loop, with findings queue and 2-round cap (started after #1302).
- Dependency #778 (suite-harness) is closed; harness pieces (suiteControl, suiteProbes, assertGolden, GalleryChrome stub) are on dev.
- Stopped at stage 0: blueprint suiteui.md section 6 (captain decision 2026-10-15) deletes EditorShell, EditorTopBar and .rail, and docs/blueprints/suite/features/shell-parity-waves.md says editor-chrome must be rescoped (EC-3 and EC-4 retarget SuiteWindow and EditorDetail, EC-7's rail colors are dropped) and filed after editor-shell-removal, which is not filed yet. Building EC-3, EC-4, EC-7 rail, EC-9 to EC-13 as written would build into files that feature deletes.
- PRs would target dev, not main (CLAUDE.md: never target main); the brief's "base main" predates the dev flow.

## Open
- Third stall nudge (2026-10-16T19:46Z): dev at 7ab292cd, no change to the editor-chrome packet or wave.json, no reply on #1344. Contract rule 7: third stall stops the lead with needs-human (already on #1344). A relaunch is useful only after the rescope lands on dev.
- Second stall nudge (2026-10-16T19:15Z): dev at 583bb69b; #1536 re-sliced timeline only, editor-chrome packet and wave.json unchanged (no Slices, still on EditorShell/EditorTopBar/.rail). No supervisor reply on #1344; needs-human stays. Still stopped.
- Resumed after a Belt stall nudge (2026-10-16T18:44Z): the packet and wave.json on dev are unchanged and editor-shell-removal is unfiled. The supervisor note of 2026-10-16 18:13Z (build UI and logic in parallel; wave data being re-sliced) does not lift the rescope, so the lead stays stopped.
- Packet rescope by the supervisor (comment on #1344).
- Optional: EC-5 (transport), EC-6 (status pills) and the non-shell half of EC-1/EC-8 are valid as written and could run as a separate small feature if the supervisor splits them out.
