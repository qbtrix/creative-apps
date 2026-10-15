# layer-keys lead record

Issue: #1036 · Packet: docs/blueprints/halo/features/layer-keys.md
Run: act-1a13eb691a3-wg4n · Session: e0e565d9-6109-5c52-89fd-c254398040f9 · Started: 2026-10-15T08:39Z
Stage: 3 wave 1
Base: 62a857755d8d554b311bb2e056d8562b27dfea26
Next: wait for LK-1's PR to merge, then start wave 2 (LK-2a) from the new origin/dev.

## Tasks
| id | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|
| LK-1 | 1 | HaloKeyRules sampling, matrices, follows; LiveLayerPlacing real; FakeLayerPlacing on the rules | Live/HaloKeyRules, Live/LiveLayerPlacing, Fakes/FakeLayerPlacing, LayerPlacingContractTests | LayerPlacingContractTests [fake, live], HF-3, HF-5 | – | building |
| LK-2a | 2 | read half: keyState, rows; LivePropertyKeying rows real | Live/HaloKeyRules, Live/LivePropertyKeying, Fakes/FakePropertyKeying, PropertyKeyingContractTests | PropertyKeyingContractTests (rows) | – | waits LK-1 |
| LK-2b | 3 | write half: setValue, toggleAnimation, toggleKey | same as LK-2a | PropertyKeyingContractTests (writes) | – | waits LK-2a |
| LK-3 | 4 | setParent in the rules, cycle refused, child kept on screen | same as LK-2a | PropertyKeyingContractTests on parented | – | waits LK-2b |
| LK-4 | 4 | LiveViewerDragging hit and commitMove; fake wraps it | Live/LiveViewerDragging, Fakes/FakeViewerDragging, ViewerDraggingContractTests | ViewerDraggingContractTests | – | waits LK-2b |
| LK-5 | 4 | propertyRows, setProperty to/text, endPropertyScrub, shown helpers | HaloKeying.swift, HaloKeyingTests | HaloKeyingTests | – | waits LK-2b |
| LK-6 | 5 | toggles, setParent, choices; keys availability | HaloKeying.swift, Availability/HaloAvailability+Keys, HaloKeyToggleTests, HaloKeysAvailabilityTests | both suites | – | waits LK-3,4,5 |
| LK-7 | 5 | compositionPoint and viewer drag begin/move/end/cancel | HaloViewerDrag.swift, HaloKeyByDragTests | HaloKeyByDragTests | – | waits LK-4 |
| LK-8 | 6 | budgets HB-1, HB-3, HB-4 | HaloKeysBudgetTests | HaloKeysBudgetTests | – | waits LK-5,7 |
| LK-9 | 6 | keys routes; TRANSFORM rows, key buttons, refusal caption | HaloApp/HaloWindow+Keys, HaloApp/HaloLayerInspector, HaloInspectorSnapshots | halo-inspector(-refusal) snapshots | – | waits LK-6,7 |
| LK-11 | 6 | HaloViewerGestures drag and Escape | HaloApp/HaloViewerGestures, HaloKeyByDragSnapshots | halo-key-by-drag snapshots | – | waits LK-7 |
| LK-10 | 7 | LAYER group Parent and Blend; narrow snapshot | HaloApp/HaloLayerInspector, HaloInspectorSnapshots | halo-inspector-layer, -narrow snapshots | – | waits LK-9 |
| LK-12 | 7 | H-J5 drag journey | UITests/HaloJourneyTests+Drag | H-J5 | – | waits LK-9,11 |
| LK-13 | 7 | H-J6 inspector journey | UITests/HaloJourneyTests+Inspector | H-J6 | – | waits LK-9 |
| LK-14 | 8 | H-J23 parent journey, feature-done | UITests/HaloJourneyTests+Parent | H-J23 | – | waits LK-10,12,13 |

Waves as in the packet. Independent per wave: W1 LK-1; W2 LK-2a; W3 LK-2b; W4 LK-3, LK-4, LK-5; W5 LK-6, LK-7; W6 LK-8, LK-9, LK-11; W7 LK-10, LK-12, LK-13; W8 LK-14.

## Rounds
| round | CI run | CI | audit vs baseline | lenses | confirmed | fixed by | clean |
|---|---|---|---|---|---|---|---|

## Decisions
- Depends on #777 and #333: both closed, so the lead runs.
- Waves taken from the packet unchanged; checked against dev 62a8577: the stubs it replaces exist.
- LK-2a → LK-2b → LK-3 run serially: each edits HaloKeyRules, LivePropertyKeying and FakePropertyKeying and builds on the last.
- LK-6 waits on LK-3 (live setParent), LK-4 (drag availability needs the live dragging), LK-5 (shares HaloKeying.swift).
- The container had no Swift; the lead installed swift-6.3.3-RELEASE (CI's version) into /opt/swift. Base gate: CI: PASS.
- Single-task waves run as one worktree subagent; waves of 3 use build-wave.js.

## Open
- #207 keeps `needs-human`; the captain decides (packet note). LK-11 says `Closes #207`.
- #783 (needs-ui): typed text that isn't a number never reaches the Model; H-J6 asserts only that the value is kept.
