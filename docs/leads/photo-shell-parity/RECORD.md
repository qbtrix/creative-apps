# photo-shell-parity lead record

Issue: #1502 · Packet: docs/blueprints/photo/features/shell-parity.md
Run: act-1a145e74c6c-9utm · Session: claude/photo-shell-parity-p2mo9n · Started: 2026-10-16T18:20Z
Stage: 4 polling (lead stopped at its 8 h wall clock, 2026-10-17T02:05Z; resume from Next)
Base: 653b674d (round 1's run)
Next: (hand-off for a relaunched lead) 1. Poll scoped photo runs (`ci.yml` runs titled `scoped: photo` on dev) until 'Scoped build and tests' passes: it needs SuiteUI #1295 (CanvasViewport checkerboard tile built once; fixes PhotoWindowStrokeTests, finding #1674) (adjustTabEndIsReachable from #1733 passes since run 38990423996; only #1674 gates). 2. When a run reaches the journeys: download its ui-screens and snapshots, read PhotoJourneyTests* and PhotoShellJourneyTests (shell geometry steps are expected red until SuiteUI #1456), and run the critic panel (docs/factory/workflows/critic-panel.js; lenses: clarity, journey, design, layout/geometry, controls, audit) with `issue`=#1502 so findings are filed with `finding` + `line:photo`. This is round 2 of 2 (round 1 = #1674). 3. Fix the findings in one wave, then PS-7: wave.json status built + feature issue, plus the last stale words (+Documents/+Edit/+Recovery/+PerfDocuments messages, PhotoInspectorContent, PhotoIntent comments, the photo-model C4 part), label feature-done. 4. After the full dev run that PS-7 triggers: contact sheet on #1502 (Belt-Contact-Sheet: line). Push every record to lead/photo-shell-parity and mirror it to lead/shell-parity under docs/leads/photo-shell-parity/ (Belt watches lead/shell-parity).

Loop: v2 (no `## Slices` table in the packet or its wave.json). Started after #1302, so the findings queue (rule 10) and 2 fix rounds (rule 11) apply.

## Tasks
| id | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|
| PS-1 | 1 | PhotoToolbarItem: eight commands, titles, symbols, identifiers, reasons, save state | Sources/PhotoModel/PhotoToolbarItems.swift, Tests/PhotoModelTests/PhotoToolbarItemsTests.swift | PhotoToolbarItemsTests (Linux) | – | building |
| PS-2 | 1 | Layers tab splits into PhotoLayerList (rows + SidebarActionRow) and PhotoLayerSettings | Sources/PhotoApp/PhotoLayersTab.swift, PhotoLayerList.swift, PhotoLayerSettings.swift, Tests/AppSnapshotTests/PhotoLayerRowSnapshots.swift, UITests/PhotoJourneyTests.swift | testTier1Layers identifiers; PhotoLayerRowSnapshots | #1546 | merged |
| PS-3 | 2 | PhotoEditor on SuiteWindow + EditorDetail, floating palette, no tabs, subtitle, toolbar from PS-1 | PhotoEditor, PhotoPanel, PhotoLayersTab (deleted), PhotoWindow, PhotoApp, PhotoJourneyTests{,+Documents,+Edit,+LayerOps}, PhotoEditorSnapshots, PhotoProInspectorSnapshots | every Photo journey on the dev run | #1583 | merged |
| PS-4 | 3 | Subtract: PhotoTopBar gone, PhotoRailTool -> PhotoPaletteTool, -PhotoWindowWidth -> -SuiteWindowSize | see packet + PhotoSaveStatusLabel.swift (new), PhotoAdjustTab, PhotoJourneyTests+Fixtures/+Perf, photo-app C4 part | grep + PhotoLaunchOptionsTests | #1614 | merged |
| PS-4b | 3 | Layer settings after Tool Options; +AdjustmentLayers journey without tabs | PhotoAdjustTab, PhotoPanel, UITests/PhotoJourneyTests+AdjustmentLayers.swift | the journey on the dev run; snapshots | #1643 | merged |
| PS-5 | 3 | Shell journey steps 1-6 with geometry | UITests/PhotoJourneyTests+Shell.swift | PhotoJourneyTests+Shell on the dev run | #1612 | merged |
| PS-6 | 4 | feature-done: wave.json status built + feature issue | PS-4's 3 dropped leftovers (stale header comments in Sources/PhotoApp, PhotoStroke's "Layers tab" message + its 2 tests, the photo-app C4 part description) | scripts/ci; grep | #1682 | merged |
| PS-6b | 4 | the rest of the stale shell words (9 PhotoApp, 3 PhotoModel, 6 UITests files incl. failure messages) | listed in #1682's body | scripts/ci | #1706 | merged |
| PS-7 | 5 | feature-done: wave.json status built + feature issue; plus #1706's last stale words (+Documents, +Edit, +Recovery, +PerfDocuments messages; PhotoInspectorContent, PhotoIntent comments; photo-model C4 part) | docs/blueprints/photo/features/shell-parity.wave.json + those 7 files | scripts/ci renders waves | – | after the rounds |

Wave 1: PS-1 and PS-2 independent (disjoint files). Wave 2: PS-3 waits on PS-1 (uses PhotoToolbarItem) and PS-2 (uses PhotoLayerList/PhotoLayerSettings, same PhotoJourneyTests.swift). Wave 3: PS-4 and PS-5 independent of each other; both wait on PS-3 (PS-4 deletes what PS-3 stops using; PS-5 drives the new shell).

## Rounds
| round | CI run | CI | audit vs baseline | lenses | confirmed | fixed by | clean |
|---|---|---|---|---|---|---|---|
| 1 | scoped photo 38969445494 (653b674d; contains PS-1..PS-5) | red: snapshot step (journeys not reached) | not read (journeys not reached) | CI | #1674 PhotoWindowStrokeTests bigDisplays 1 (ours, new since #1583); #1603 curvesLayerTarget (not ours, adjustment-layers); RenderBudgetPhotoTests timing (perf list, report-only) | no Photo fix: cause is SuiteUI CanvasViewport's checkerboard (computed static checkerTile rebuilt per body; one body run, likely from the canvas taking focus on the first drag now that the sidebar list is first key view) -> SuiteUI #1295 (needs-ui) | no |
| 1b | scoped photo 38971693968 (4347bc74) | red: snapshot step; only gating failure is PhotoWindowStrokeTests (#1674 -> SuiteUI #1295); #1603 passes | not read | CI | – | waits on #1295 | no |

## Decisions
- Status branch is lead/photo-shell-parity (the packet's Lead branch): lead/shell-parity holds Design's shell-parity lead (#1325, done 22:33). Belt watches lead/shell-parity for this run, so from 23:25 every RECORD push also goes there, under docs/leads/photo-shell-parity/ (Design's docs/leads/shell-parity/ is left as it is).
- PRs target dev (CLAUDE.md; main is behind dev and the lane retargets main to dev). Brief base main = 2e0f7df verified; work starts from origin/dev 132d910.
- PR body uses `Feature: shell-parity` (Belt brief) plus "Part of the Photo shell-parity feature"; findings are told apart from Design's by `line:photo`.
- Stage-1 rename check: `fit()` lives in PhotoWindow.swift itself (no PhotoWindow+*.swift holds it); PhotoTopBar, PhotoRailTool, PhotoLayersTab, PhotoCommands+Image all exist as the packet names them.
- `photo.bar.saved` is read by the +Documents, +Recovery and +PerfDocuments journeys. PS-3 keeps PhotoSaveStatusLabel (`photo.bar.saved`) in the status line beside the window subtitle (as Halo keeps `halo.file`), so those journeys pass unchanged; PS-4 moves the label and its environment key out of PhotoTopBar.swift into PhotoSaveStatusLabel.swift before deleting PhotoTopBar.swift.
- The subtitle is the window's full PhotoSaveStatus title (also "Edited, autosaved" / "Not saved"); PS-1's `saveState(of:)` gives the Model's base state (Edited/Saved/nil) the packet tests.
- `radioButtons["Layers"]` is also in +Documents, +Edit and +LayerOps; PS-3 owns those journey edits (UITests/PhotoJourneyTests*.swift is the feature's).
- expectEditorWindow() needs suite.tools, which shows only with an image open: PS-3's launch check opens or creates an image first.
- editor-in-window #1079 is open, but every SuiteUI API used is on dev (Design's lead found the same). Known SuiteUI blockers for PS-5's geometry: needs-ui #1456 and switcher PR #1337 (Design DP-b gap #1452).
- PS-3 deviations: PhotoLayerSettings sits right after the inspector header (between Tool Options and the adjustments needs PhotoAdjustTab.swift, a 16th file): PS-4 moves it. Subtitle is `saveStatus?.title ?? ""` (a nil/non-nil swap rebuilds SuiteWindow's split view). Four more snapshot files passed `tab:`.
- PS-4 also takes PS-3's leftovers: the +Perf header's EditorShell note, the photo-app C4 part's description, "Adjust tab" comments in Sources/PhotoApp, the PhotoModel message naming "the Layers tab", and moving PhotoLayerSettings after Tool Options.
- PS-5: the sidebar list shows no "Layers" title on dev (packet step 1 wants one), so the journey checks `photo.layers` empty instead; a critic lens checks the title. parity-photo-* shots come from SuiteJourneyTests+Parity.swift, not PS-5.
- PS-4's first head (7bc4c8d) failed the macOS build: PhotoJourneyTests+PerfAdjustmentLayers.swift (#1595, in PS-4's base) still passed `windowWidth:`. Lead fixed the call on sp/ps-4 (16 files then), moved the inspector reorder (PhotoAdjustTab, PhotoPanel) out to PS-4b, and removed the perf journey's Adjust-tab click; PS-4 is 14 files at d9eb551. The PS-4 body carried a "Generated by Claude Code" footer: removed.
- #1595's adjustment-layer journeys (merged around PS-3) click the Adjust/Layers tabs PS-3 removed: +PerfAdjustmentLayers fixed in PS-4, +AdjustmentLayers in PS-4b.
- PS-4 hit the 15-file cap: three leftovers (stale header comments, the "Layers tab" message, the photo-app C4 part) ride PS-6, the final feature-done PR. PhotoLayerSettings sits after Tool Options via a `showsLayerSettings` flag on PhotoAdjustTab.
- feature-done goes on a last PS-7 (wave.json only) after the Anatomy rounds; PS-6 carries the leftovers without it.
- Scoped photo runs since 38959727642 stop in 'Scoped build and tests' (#1603 red before this feature), so no Photo journey has run on macOS since PS-3. The full CI runs' macOS job also stops early (scripts/ci step).
- feature-done moves from PS-5 to a small PS-6 after PS-4 and PS-5 merge, so the full run it triggers holds every PR (Design did the same with DS-5).
- SuiteUI #1337 (switcher) merged 20:06; #1456 (geometry) still open: PS-5 writes the packet's geometry checks unweakened and expects them red until #1456.
- Swift: dev's Package.swift needs Swift 6.3.3 on Linux (6.2 times out type-checking); installed at /opt/swift-6.3.3 and linked into /usr/local/bin.
- Saved state: the Model marks clean through didSave(as:kind:), not didSave(as:).
- Wave 1 has 2 tasks: one worktree subagent each, started together.

## Open
- Scoped photo run 38982540952 (96bd5d9e) adds a second gating failure, not this feature's: PhotoProInspectorSnapshots.adjustTabEndIsReachable, a test #1733 (photo-adjustment-layers, #1501) added at 23:2x that fails on its first run (`changed 0`: the panel scrolled to its end draws the same as its top). It renders our tabless PhotoPanel; if its owner finds the cause is the inspector's scroll structure from PS-3/PS-4b, it comes back here as a finding.
- #1674 (finding) waits on SuiteUI #1295 (the checkerboard tile built once); Photo can't fix it without a look-alike checkerboard.
- SuiteUI #1456 (shell geometry) open; PS-5's geometry steps may stay red until it lands.
