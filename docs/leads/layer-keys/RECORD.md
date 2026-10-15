# layer-keys lead record

Issue: #1036 · Packet: docs/blueprints/halo/features/layer-keys.md
Run: act-1a13eb691a3-wg4n · Session: e0e565d9-6109-5c52-89fd-c254398040f9 · Started: 2026-10-15T08:39Z
Stage: 4 round 1
Base: 35a875b
Next: dev red on others' code (viewer-playback keyedFrame6 + driver timeouts; Photo crop; now LibraryWindow+Cull/Loupe build at 3d42e80). Round 2 on the first dev run past swift test. Wall clock ends 16:39Z: if still blocked by ~16:15, comment the state on #1036 and stop.

## Tasks
| id | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|
| LK-1 | 1 | HaloKeyRules sampling, matrices, follows; LiveLayerPlacing real; FakeLayerPlacing on the rules | Live/HaloKeyRules, Live/LiveLayerPlacing, Fakes/FakeLayerPlacing, LayerPlacingContractTests | LayerPlacingContractTests [fake, live], HF-3, HF-5 | #1054 | merged |
| LK-2a | 2 | read half: keyState, rows; LivePropertyKeying rows real | Live/HaloKeyRules, Live/LivePropertyKeying, Fakes/FakePropertyKeying, PropertyKeyingContractTests | PropertyKeyingContractTests (rows) | #1064 | merged |
| LK-2b | 3 | write half: setValue, toggleAnimation, toggleKey | same as LK-2a | PropertyKeyingContractTests (writes) | #1077 | merged |
| LK-3 | 4 | setParent in the rules, cycle refused, child kept on screen | same as LK-2a | PropertyKeyingContractTests on parented | #1088 | merged |
| LK-4 | 4 | LiveViewerDragging hit and commitMove; fake wraps it | Live/LiveViewerDragging, Fakes/FakeViewerDragging, ViewerDraggingContractTests | ViewerDraggingContractTests | #1086 | merged |
| LK-5 | 4 | propertyRows, setProperty to/text, endPropertyScrub, shown helpers | HaloKeying.swift, HaloKeyingTests | HaloKeyingTests | #1091 | merged |
| LK-6 | 5 | toggles, setParent, choices; keys availability | HaloKeying.swift, Availability/HaloAvailability+Keys, HaloKeyToggleTests, HaloKeysAvailabilityTests | both suites | #1109 | merged |
| LK-7 | 5 | compositionPoint and viewer drag begin/move/end/cancel | HaloViewerDrag.swift, HaloKeyByDragTests | HaloKeyByDragTests | #1105 | merged |
| LK-8 | 6 | budgets HB-1, HB-3, HB-4 | HaloKeysBudgetTests | HaloKeysBudgetTests | #1118 | merged |
| LK-9 | 6 | keys routes; TRANSFORM rows, key buttons, refusal caption | HaloApp/HaloWindow+Keys, HaloApp/HaloLayerInspector, HaloInspectorSnapshots | halo-inspector(-refusal) snapshots | #1117 | merged |
| LK-11 | 6 | HaloViewerGestures drag and Escape | HaloApp/HaloViewerGestures, HaloKeyByDragSnapshots | halo-key-by-drag snapshots | #1115 | merged |
| LK-10 | 7 | LAYER group Parent and Blend; narrow snapshot | HaloApp/HaloLayerInspector, HaloInspectorSnapshots | halo-inspector-layer, -narrow snapshots | #1119 | merged |
| LK-12 | 7 | H-J5 drag journey | UITests/HaloJourneyTests+Drag | H-J5 | #1122 | merged |
| LK-13 | 7 | H-J6 inspector journey | UITests/HaloJourneyTests+Inspector | H-J6 | #1126 | merged |
| LK-14 | 8 | H-J23 parent journey, feature-done | UITests/HaloJourneyTests+Parent | H-J23 | #1129 | merged |

Waves as in the packet. Independent per wave: W1 LK-1; W2 LK-2a; W3 LK-2b; W4 LK-3, LK-4, LK-5; W5 LK-6, LK-7; W6 LK-8, LK-9, LK-11; W7 LK-10, LK-12, LK-13; W8 LK-14.

## Rounds
| round | CI run | CI | audit vs baseline | lenses | confirmed | fixed by | clean |
|---|---|---|---|---|---|---|---|
| 1 | 38734211999 (35a875b) | red: swift test fails only HaloViewerFidelityTests.keyedFrame6 (keyed frame 6, 40000 px differ; HF-1 from #1125); journeys did not run. All our snapshots rendered. (Earlier 38732179619: playback test compile, fixed by #1136) | – (no ui-screens) | clarity, journey, design, layout, controls | 3 major (one finding: narrow TRANSFORM labels clip), 6 minor | #1153 (TRANSFORM stacks key buttons under bars via ViewThatFits at narrow widths; layer snapshot at frame 0); SuiteUI slider ticks/marker → #1146 | no |

## Decisions
- Depends on #777 and #333: both closed, so the lead runs.
- Waves taken from the packet unchanged; checked against dev 62a8577: the stubs it replaces exist.
- LK-2a → LK-2b → LK-3 run serially: each edits HaloKeyRules, LivePropertyKeying and FakePropertyKeying and builds on the last.
- LK-6 waits on LK-3 (live setParent), LK-4 (drag availability needs the live dragging), LK-5 (shares HaloKeying.swift).
- The container had no Swift; the lead installed swift-6.3.3-RELEASE (CI's version) into /opt/swift. Base gate: CI: PASS.
- Single-task waves run as one worktree subagent; waves of 3 use build-wave.js.

- LK-1: FakeLayerPlacing wraps LiveLayerPlacing (jscpd flagged identical bodies); FakeLayerPlacing.follows stays as a forwarder because HaloFileValidation (not ours) calls it.
- Packet value `Floor.bounds(in:).midX` does not exist (HaloLayerRect has no midX); LK-1 used box.x + width/2.

- LK-2a: FakePropertyKeying wraps LivePropertyKeying for rows (same pattern); write tests stay fake-only until LK-2b.

- LK-2b: fake writes go through the wrapped LivePropertyKeying; HaloKeyRules.change is internal so the fake setParent uses it until LK-3.
- Session restarts kill in-flight builders silently; the lead now records the next action so a resume relaunches only missing PRs.

- LK-4: a non-invertible parent (scale 0) moves by the raw delta rather than throwing (packet silent). FakeViewerDragging now wraps LiveViewerDragging.
- LK-5: setProperty with no selected layer is a no-op (no refusal); HaloProject.propertyRowControl(_:) builds row ids.
- LK-5 PR body briefly carried a tool-appended attribution footer; it is gone now; builders re-read and strip it after opening.
- Flake seen: FlareEasingDragCostTests.handleDragP95UnderBudget (5.04 ms vs 5 ms under load), not ours.

- LK-8 and LK-11 start before LK-6 merges: they need only LK-5 and LK-7 (merged), per packets.md rule (b). LK-9 still waits on LK-6.

- LK-6: setParent availability also checks placing; setBlendMode needs only a composition and a layer.
- PR bodies opened over REST get an attribution footer re-added by the tooling; builders strip it with the GitHub MCP update_pull_request.

- LK-11: no `halo.viewer.artboard` control id added (H-J13 would click empty artboard); the overlay is accessibility-hidden and laid out like HaloDrawnLayers so it covers only the artboard. Escape needs focus: overlay is focusable with no focus effect.
- LK-8: the gate failed after rebase only on other lines' timing tests (Flare easing drag, Library metadata) at load 16 on 4 cores; a finisher reruns it.

- LK-9: the key button id halo.inspector.key.<raw> covers both stopwatch and diamond; journeys find them by label. The packet's "Select a layer to see its properties." empty text does not exist in code; empty state unchanged. Blend refusals use halo.inspector.row.blend (W0).
- LK-8: uses the shared haloP95 helper (quietest p95 of 3x100), not median+p95 of 200 runs.

- LK-12, LK-13: HaloJourneyTests helpers are private to their file, so each journey extension carries small private helpers. LK-12 finds the artboard from halo.viewer's frame (no artboard element) and allows max(2 px, one point) since a point is 5-9 comp px at 1000x640. LK-13 reads lane key counts from halo.timeline.track values; #262 (empty values on the runner) is its risk.
- LK-14 opened before LK-13 merges: separate file; the lane merges oldest first, so the feature-done run holds all three journeys.

- Round 1 minors not fixed: refusal text "Rotation needs a number." kept (packet LK-5 acceptance fixes that text); drag hint caption/ghost key (new behavior beyond the packet; noted for core-loop); SuiteUI tick/marker → #1146.

## Open
- Issue comments and new issue bodies from this session get a "Generated by Claude Code" footer appended by the tooling (REST and MCP); PR bodies could be cleaned with MCP update, issue comments could not (#763 comment 6192557777). Flagged for the supervisor.
- keyedFrame6 (HF-1, #1125) root cause: HaloViewerCanvas.swift:73 opacity blended in sRGB under ImageRenderer vs linear render; viewer-playback's code. Posted on #763; not ours to fix. Blocks the journeys until fixed.
- #1146 (needs-ui): InspectorSliderRow ticks under text, marker outside row at top of range, label/value at narrow widths.
- CI on the feature-done head 9af4454: swift build (all HaloApp keys views) passes on macOS; swift test stops compiling AppSnapshotTests at viewer-playback's HaloPlaybackDriverTests.swift:18 (#1097). Reported on #763 by others; not ours to fix. Journeys and audit wait on it.
- dev-red #763: macOS build fails in Sources/LibraryApp/LibraryInspector.swift:14-15 (mutating member on let model), not this feature; it hides any Halo compile error until fixed. Run 38726261412.
- #207 keeps `needs-human`; the captain decides (packet note). LK-11 says `Closes #207`.
- #783 (needs-ui): typed text that isn't a number never reaches the Model; H-J6 asserts only that the value is kept.
