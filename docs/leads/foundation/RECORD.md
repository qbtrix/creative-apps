# foundation lead record

Issue: #777 · Packet: docs/blueprints/halo/features/foundation.md (on branch `docs/halo-feature-packets` until its PR merges)
Run: act-1a13b78bcdb-qu60 · Session: session_01Dc9GDxc9HxLtv9XMcFgSWh · Started: 2026-10-14T17:33Z
Stage: 4 round 4 (last by budget; r4 fixer + panel running)
Base: 52928d1dbbdd72b849f7fdb6363991f35b1adbeb
Next: merge the r4 fix (H-J1 Width label regression from #1009; layout L1 judged by visible frame like the audit), file round 4 panel findings as gap issues (no more rounds), then a small feature-done PR (packet status line) and the contact sheet once its dev CI run is green

## Tasks
| id | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|
| FD-1 | 1 | Key values and the W0 layer (HaloValues 1–186, 321–377; HaloLayer tracks/parentID/text/Codable; HaloLayerDefaults) | Contracts/HaloValues.swift, HaloLayer.swift, HaloLayerDefaults.swift + 3 tests | HaloPropertyTests, HaloLayersTests, HaloLayerOpacityClampTests | #785 | merged |
| FD-19 | 1 | Names collapse inner whitespace and drop Cf before comparing (#149) | NameKey.swift, HaloNameWhitespaceTests | HaloNameWhitespaceTests | #784 | merged |
| FD-2 | 2 | Document values, HaloComposition Codable, duplicate remaps parentID | Contracts/HaloDocumentValues.swift, HaloProject.swift + 2 tests | HaloDocumentValuesTests, HaloCompositionTests | | #794 | merged |
| FD-3 | 3 | The protocols | Contracts/HaloContracts.swift + test | HaloContractShapeTests | | #795 | merged |
| FD-4 | 4 | Fakes A (placing, drawing, keying) + suites | Fakes/ x3 + 3 tests | *ContractTests | | #796 | merged |
| FD-5 | 5 | Fakes B (dragging, easing, history, files) + suites | Fakes/ x4 + 4 tests | *ContractTests | | #894 | merged |
| FD-6 | 5 | Fakes C (clock, frame rendering, text, comp rendering) + suites | Fakes/ x4 + 3 tests | *ContractTests | | #895 | merged |
| FD-7 | 6 | Ten live stubs + HaloServices .fake/.live | Live/ x10, HaloServices.swift + test | HaloServicesTests | | #897 | merged |
| FD-8 | 7 | HaloProject holds document + every v1 stored property; == skips services | HaloProject.swift + 2 tests | HaloProjectTests | | #898 | merged |
| FD-9 | 8 | HaloFixtures (eight, huge ≤ 48 MiB) | HaloFixtures.swift + test | HaloFixturesTests | | #899 | merged |
| FD-10 | 9 | edit / endCoalescing / dismissRefusal / takeLayerID; mutators under edit; HB-9 | HaloProject, HaloTimeline + tests | HaloEditTests, HaloFoundationBudgetTests | | #903, #904 (split a/b) | merged |
| FD-11 | 10 | HaloCommand, unavailableHelp, title, nine Availability files | HaloCommand.swift, Availability/ x9 + test | HaloCommandTests | | #924 | merged |
| FD-12 | 10 | viewerDrawList, viewerSummary, row key frames, status suffix; HB-6 | HaloViewerState, HaloTimeline, HaloStatusText + tests | HaloViewerStateTests, HaloTimelineCostTests | | #926 | merged |
| FD-13a | 2 | App: HaloWindow and HaloViewer move to own files (pure move) | HaloApp.swift, HaloWindow.swift, HaloViewer.swift | snapshots unchanged | #893 | merged |
| FD-13b | 11 | HaloLaunch, HaloControls, stub rasterizer | Sources/HaloApp | macOS build, H-J13 | | #927 | merged |
| FD-14 | 12 | perform(_:) routes by area to nine HaloWindow+Area files | Sources/HaloApp x10 | macOS build, H-J13 | #930 | merged |
| FD-15 | 13 | Stub views, inspector LAYERS + layer header, key diamonds, refusal caption | Sources/HaloApp x11 + 3 snapshots | halo-inspector-layer-selected-*, halo-timeline-keys-*, halo-refusal-* |  | building |
| FD-16 | 13 | Menus on HaloCommand | Sources/HaloApp x5 | testEveryMenuOpens |  | building |
| FD-17 | 14 | Accessibility labels and halo.* identifiers (#286, #290) | Sources/HaloApp x5 + 2 snapshots | H-J1, audit unnamed 0 | #940 | merged |
| FD-18 | 15 | Journeys H-J0, H-J1, H-J13, layout (feature-done) | UITests/HaloJourneyTests.swift | the journeys | #941 | merged |

## Rounds
| round | CI run | CI | audit vs baseline | lenses | confirmed | fixed by | clean |
|---|---|---|---|---|---|---|---|
| 4 | 38694361192 (fdb7c8a, has #1007–#1009) | red: H-J1 'no Width field by its label' (regression from #1009's LabeledContent), testLayoutAtWidths raw-frame check: halo.timeline.track at x 8 in a window at 12 (detail column bleeds 4 pt, SuiteUI #1014); H-J0, H-J13, menus, scrub pass; Halo snapshots and HaloLayerListTests pass | halo offscreen 0, contrast 0, identifier 1, unnamed 0: at or under baseline | clarity, layout, controls, design | 2 journey + panel pending | r4 fixer; #1014 | no |
| 3 | 38687993459 (8f78bad, has #982–#984 and #996) | red only on testLayoutAtWidths: halo.timeline.track (8, 568) starts 4 pt left of the 880 window (the selected track row runs under the floating sidebar); H-J0, H-J1, H-J13, menus, scrub pass | halo offscreen 0 (≤ 8), contrast 0, identifier 1, unnamed 0: at or under baseline | clarity, layout, controls, design | track edge + 10 panel (4 major: ruler unit, Open Recent dead, diamonds dead, LAYERS misaligned; 6 minor) | #1007 (track + 1, 5); E #1008 (3, 6, 7, 8, 9); F #1009 (2, 4, 10) | no |
| 3a | 38682385432 (e8e5b52, after #962 revert; before #982–#984) | red: H-J1 (halo.inspector not found after Create), H-J13 (layer row click selects nothing), testLayoutAtWidths (no layer selected at 880); H-J0, scrub, menus pass | halo offscreen 16 > 8: the 880 window from testLayoutAtWidths leaks into later journeys (sidebar -68, inspector to 956); Halo's content column is a rigid 672 pt at both 1000 and 880; contrast 0, identifier 2 | journeys + audit (panel waits for the run with round 2 fixes) | 4 Halo-owned | #996 | no |
| 2 | 38679533707 (54e16aa) | red: H-J0, testScrubTheTimeline, testEveryMenuOpens pass; H-J1 (halo.inspector not found after Create), H-J13 (toolbar halo.composition.new not found), testLayoutAtWidths (no layer selected at 880) fail; -HaloWindowSize now sticks | halo offscreen 14 > 8 (#933); contrast 1 ≤ 2; identifier 2 ≤ 10; unnamed 0 ≤ 5 | clarity, layout, controls, design | 3 journey (all SuiteWindow / #962) + 14 panel (6 major, 8 minor) | journey: none (SuiteWindow, #962 revert); panel: batches A #984 (2,3,4), B #982 (6,7,13), C #983 (5,8,10,11,12); #976 (8, 9 SuiteUI roots); 1, 14 kept by packet | no |
| 1 | 38675308731 (1025fcc) | red: Halo journeys H-J0, H-J1, H-J13, testLayoutAtWidths, testScrubTheTimeline fail; testEveryMenuOpens passes | halo offscreen 14 > 8 (SuiteUI #933 split-view overflow: sidebar rows x -28/-8, inspector to x 1036 in a 12–1012 window); identifier 1 (system Hide Sidebar) < 10; unnamed 0 < 5 | CI + audit + screens (panel not run: blockers already confirmed by the journeys) | 5: layer row click doesn't select (major); H-J0 query misses EmptyStateView title; H-J1 no problem line for abc; -HaloWindowSize ignored (1000 not 880); offscreen over baseline (blocker, SuiteUI #933) | #961 (4); #933 (offscreen) | no |
| 1a | 38673821944 (3af1c0e) | red: macOS `swift test` failed on SuiteUITests.rowBodyAndItsTogglesCarryNoDoubleClickGesture (not foundation: #938's ids, fixed by #944); UI journeys skipped | not measured | – | – | – | no |

## Decisions
- The packet is read from `origin/docs/halo-feature-packets` (ed58c3a); the issue says so until that PR merges.

- Waves follow the packet's chains: Model FD-1 → … → (FD-11 ∥ FD-12), then App FD-13 → FD-14 → (FD-15 ∥ FD-16) → FD-17 → FD-18; FD-19 rides wave 1.
- Builders run as Agent subagents in worktrees (not build-wave.js) so each next task can start stacked on its predecessor's branch and rebase --onto dev once the predecessor merges; the chain is serial, so this removes the merge wait. Brief: builder-brief.md in the lead's scratchpad.
- Builder branches are `lead/foundation-fd-<k>` (`lead/foundation/<id>` can't coexist with the `lead/foundation` ref).
- The container had no Swift: installed 6.3.3 with scripts/cloud-setup.sh; baseline scripts/ci on 52928d1: CI: PASS in 2m34s.

- 18:00Z–22:05Z: paused by the plan usage limit; resumed from this record.

- Packet re-read from dev after #789/#791 merged it (FD-2 takes the error types, FD-13 split into 13a/13b, HaloCommand cases listed). FD-13a has no Model dependency, so it runs beside FD-2.
- After the pause, one chain builder takes several serial Model tasks in a row (context stays warm, next task starts stacked as soon as a PR opens).

- FD-13a's builder died in a container restart before opening its PR; the lead rebased it, passed scripts/ci and opened #893.
- A stale untracked Package.resolved pinned an old creative-core and broke FlareModel locally; `rm Package.resolved && swift package update` fixes it (noted in the builder brief).

- FD-10 came to 507 lines, so it shipped as #903 (edit, restore, mutators) and #904 (I/O refusals, HB-9).
- FD-7's 'every live stub is unbuilt' check sits in HaloServicesTests (FD-4..6 own the contract suites), written to stay true when a live type lands.

- FD-13b added `HaloProject(services:document:)` (new file HaloProjectLaunch.swift) so the app can open fixtures; `restore` stays internal.
- FD-14: `perform` is `@MainActor (HaloCommand) -> Void`; it does not gate on unavailableHelp so Model refusals (I/O with no layer) still show; window title kept as today's so H-J0 and the launch snapshot don't move.
- The halo.controls probe is a hidden element whose accessibility label is SuiteUI's ControlDocument JSON (same as suite.controls); FD-18 checks inspector controls reach it.

- FD-15 changed HaloCompositionInspectorSnapshots.swift (FD-17's file) only so it compiles with the new init; halo-open/-layers/-timeline snapshots change because the status bar now has the transport.

- FD-17's .haloControl also registers through SuiteUI's .suiteControl so controls in the toolbar, columns and inspector reach the probe; H-J13 merges halo.* entries of suite.controls with halo.controls. Expected audit: unnamed 5→0, identifier 10→3.

- Run 38673821944 compiled every Halo SwiftUI file and passed the Halo snapshot suites (halo(), HaloCompositionSnapshots); its only failure was a SuiteUI test fixed on dev by #944, so round 1 waits for the next run instead of fixing it here.

- Round 1 finding offscreen 14 > 8 is SuiteUI #933 (SuiteWindow owns the column widths; a Halo PR can't edit SuiteUI). Measurements posted on #933 and the plan on #777; the baseline is not raised.
- Artifacts download through the proxy with plain curl on api.github.com/.../actions/artifacts/<id>/zip (gh is unauthenticated here).

- Supervisor: SuiteUI #962 (inspector moved outside the split view) broke H-J1's halo.inspector lookup and the 880 layout selection in run 38679533707; it is being reverted, so round 2 is re-judged on the next run and only Halo-owned faults are fixed.

- Round 2 panel findings 1 and 14 ("Not built yet (#n)." and "Properties arrive with the layer inspector (#38)." cite issue numbers) are kept: the packet specifies both strings and HaloCommandTests pins the "Not built yet (#n)." form so W1 features can find their area's issue. A wording change belongs in the packet, for the supervisor.

- Supervisor (after #975): the remaining Halo failures are the feature's own. Lead's measurement backs part of that: Halo's detail column stays 672 pt whatever the window (Library's is 648), and #961's window sizer leaks an 880 frame into later journeys.

- Round 4: Halo's raw-frame L1 check is stricter than the packet's L1, which is the app audit (visible frame, 1 pt slack). The r4 fix aligns it to the audit's rule; the 4 pt column bleed is SuiteUI's (#1014). Round 4 is the last: its panel findings become gap issues.

## Open
- #1014 (needs-ui): SuiteWindow's detail column starts ~4 pt left of the window under the floating sidebar.
- #976 (needs-ui): ViewerStatusBar pills override disabled dimming; sidebar section add button looks disabled.
- #981 (needs-ui): per-pill tooltips on ViewerStatusBar (Halo uses one bar-level tooltip meanwhile).
- To file (needs-ui): TimelineStrip should reserve or hide its horizontal scroller; a compact EmptyStateView for short panes (from #982). SuiteUI has no LayerList component yet (from #983; pill dimming is #976).
- SuiteUI #933: split view wider than the window; blocks halo offscreen ≤ 8 and so H-J13 / testScrubTheTimeline.
- docs/c4/model.json "HaloApp sources" description still names only the Layer and Composition menus; the supervisor folds C4 descriptions in (packet: no shared docs).
