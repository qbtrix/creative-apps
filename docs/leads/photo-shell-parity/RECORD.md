# photo-shell-parity lead record

Issue: #1502 · Packet: docs/blueprints/photo/features/shell-parity.md
Run: act-1a14a193a7a-rmz6 (relaunch 2; before: act-1a148875943-9arx, act-1a145e74c6c-9utm) · Session: claude/shell-parity-adjustment-layers-g6jfld (first claude/photo-shell-parity-p2mo9n) · Started: 2026-10-16T18:20Z
Stage: 4 round 3 review (read-only: rounds spent)
Base: d2c4fa212a4b4ea55bc551b783fc1c48520e5fbf (origin/main = origin/dev at relaunch 2, 2026-10-17T13:0xZ)
Next: critic panel on run 39032323316's photo ui-screens (round 3, review only); relabel the open line:photo findings to gap (both fix rounds spent: round 1 had no Photo fix wave, F-1910 was round 2 per the relaunch brief); post Belt-Contact-Sheet on #1502 from 39032323316.

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
| F-1910 | 5 (round 2 fix) | Photo journeys find the opened file's window by its name within the title (the save-state subtitle changed the accessibility title: #1910 and #1902-#1930); testFixtureLaunch measures suite.viewport; +Documents/+Edit/+Recovery/+PerfDocuments stale words | UITests/PhotoJourneyTests+Fixtures.swift (window(named:)), PhotoJourneyTests.swift, +Shell, +Recovery, +Crop, +AdjustmentLayers, +PerfDocuments, +LayerOps, +Edit, +Documents | the Photo journeys on the next dev run | #2008 | merged |
| PS-7 | 5 | feature-done: wave.json status built + feature issue; PhotoInspectorContent, PhotoIntent comments; photo-model C4 part; test-only comments | docs/blueprints/photo/features/shell-parity.wave.json + those files | scripts/ci renders waves | #2006 | merged |

Wave 1: PS-1 and PS-2 independent (disjoint files). Wave 2: PS-3 waits on PS-1 (uses PhotoToolbarItem) and PS-2 (uses PhotoLayerList/PhotoLayerSettings, same PhotoJourneyTests.swift). Wave 3: PS-4 and PS-5 independent of each other; both wait on PS-3 (PS-4 deletes what PS-3 stops using; PS-5 drives the new shell).

## Rounds
| round | CI run | CI | audit vs baseline | lenses | confirmed | fixed by | clean |
|---|---|---|---|---|---|---|---|
| 1 | scoped photo 38969445494 (653b674d; contains PS-1..PS-5) | red: snapshot step (journeys not reached) | not read (journeys not reached) | CI | #1674 PhotoWindowStrokeTests bigDisplays 1 (ours, new since #1583); #1603 curvesLayerTarget (not ours, adjustment-layers); RenderBudgetPhotoTests timing (perf list, report-only) | no Photo fix: cause is SuiteUI CanvasViewport's checkerboard (computed static checkerTile rebuilt per body; one body run, likely from the canvas taking focus on the first drag now that the sidebar list is first key view) -> SuiteUI #1295 (needs-ui) | no |
| 1b | scoped photo 38971693968 (4347bc74) | red: snapshot step; only gating failure is PhotoWindowStrokeTests (#1674 -> SuiteUI #1295); #1603 passes | not read | CI | – | waits on #1295 | no |
| 2 | scoped photo 38993910840 (124b118; first run past the snapshot step, after #1716) | journeys ran: 27 Photo journeys red, 25 at the window wait (#1910 + #1902-#1930: the subtitle changes the window's AX title), testFixtureLaunch's viewport measure (#1914), testShell1Empty's switcher centring (#1925, SuiteUI) | photo identifier 14 (baseline 22), no other key | CI (journeys) | #1910 and siblings | F-1910 (this wave) | no |

| 3 | full 39032323316 (d14e765; first full runs with PS-7 #2006 + F-1910 #2008: 39013069150 at 453198a, green overall) | Linux green; macOS report-only red: 10 Photo journeys (was 27) | photo identifier 17 (baseline 22) | CI (journeys), screens | #2015 #2016 #2019 #2021 #2023 #2024 #2025 #2076 (inspector below the fold / slider typing), #1927 #1930 (window 1 pt past the visible frame), #1925 (switcher, SuiteUI) | none: fix rounds spent -> gap | no |

## Decisions
- Relaunch 2 (act-1a14a193a7a-rmz6, 2026-10-17T13:0xZ): main = dev = d2c4fa2 verified; lead branches rebased onto origin/main. PS-7 #2006 and F-1910 #2008 merged 07:15Z; full CI 39013069150 on 453198a is green (Linux), the macOS job is report-only. Fix rounds: round 2 (F-1910) was this feature's last, as the first relaunch brief said ("take #1910 into your remaining round"), so round 3 is review only and every open finding becomes a gap. Screens of 39032323316 show why the rest are red: the tabless inspector puts Curves/Hue below the 680 pt window (photo-curves-dragged.png), and typing into the opacity slider leaves 38% (photo-layer-opacity.png), which also fails PJ-9's "Normal 0%".
- Relaunch 2026-10-17T06:06Z (supervisor): #1716 fixed the stroke test; #1910 is this feature's and goes in round 2; SuiteUI #1295 and #1456 are not waited on, they go in the contact sheet. The done check reads the Linux job.
- #1910 root cause: Design's subtitle-less SuiteWindow still matches `windows["journey.design"]` on dev (run 38991865764) and testShell1Empty's `window.title == "Photo"` passes with an empty subtitle, so a non-empty subtitle is what changes the window's accessibility title. The packet wants the subtitle (step 2), so the journeys match the name within the title (UITests only, no app change).
- PS-7 runs in the same wave as F-1910 (disjoint files: F-1910 takes the four UITests files #1706 left, PS-7 the Sources/Tests/C4 words and wave.json), so the full run PS-7's feature-done label triggers is both round 2's review run and the contact sheet run.
- The switcher-centring failure (testShell1Empty, J6 expectSwitcher: midX 635 in a 1024 window) is SuiteUI's principal item placement, Design's #1617/#1618 gaps show the same; not fixed in Photo, becomes a gap after round 2.
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
- Round 2 wave in flight: F-1910 and PS-7 (two worktree builders, started 2026-10-17T07:05Z).
- Scoped photo run 38982540952 (96bd5d9e) adds a second gating failure, not this feature's: PhotoProInspectorSnapshots.adjustTabEndIsReachable, a test #1733 (photo-adjustment-layers, #1501) added at 23:2x that fails on its first run (`changed 0`: the panel scrolled to its end draws the same as its top). It renders our tabless PhotoPanel; if its owner finds the cause is the inspector's scroll structure from PS-3/PS-4b, it comes back here as a finding.
- #1674 (finding) waits on SuiteUI #1295 (the checkerboard tile built once); Photo can't fix it without a look-alike checkerboard.
- SuiteUI #1456 (shell geometry) open; PS-5's geometry steps may stay red until it lands.
