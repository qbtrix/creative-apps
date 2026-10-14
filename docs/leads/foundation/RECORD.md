# foundation lead record

Issue: #777 · Packet: docs/blueprints/halo/features/foundation.md (on branch `docs/halo-feature-packets` until its PR merges)
Run: act-1a13b78bcdb-qu60 · Session: session_01Dc9GDxc9HxLtv9XMcFgSWh · Started: 2026-10-14T17:33Z
Stage: 3 wave 1
Base: 52928d1dbbdd72b849f7fdb6363991f35b1adbeb
Next: wait for FD-1 and FD-19 builders; then FD-2 stacked on FD-1

## Tasks
| id | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|
| FD-1 | 1 | Key values and the W0 layer (HaloValues 1–186, 321–377; HaloLayer tracks/parentID/text/Codable; HaloLayerDefaults) | Contracts/HaloValues.swift, HaloLayer.swift, HaloLayerDefaults.swift + 3 tests | HaloPropertyTests, HaloLayersTests, HaloLayerOpacityClampTests | | building |
| FD-19 | 1 | Names collapse inner whitespace and drop Cf before comparing (#149) | NameKey.swift, HaloNameWhitespaceTests | HaloNameWhitespaceTests | | building |
| FD-2 | 2 | Document values, HaloComposition Codable, duplicate remaps parentID | Contracts/HaloDocumentValues.swift, HaloProject.swift + 2 tests | HaloDocumentValuesTests, HaloCompositionTests | | |
| FD-3 | 3 | The protocols | Contracts/HaloContracts.swift + test | HaloContractShapeTests | | |
| FD-4 | 4 | Fakes A (placing, drawing, keying) + suites | Fakes/ x3 + 3 tests | *ContractTests | | |
| FD-5 | 5 | Fakes B (dragging, easing, history, files) + suites | Fakes/ x4 + 4 tests | *ContractTests | | |
| FD-6 | 5 | Fakes C (clock, frame rendering, text, comp rendering) + suites | Fakes/ x4 + 3 tests | *ContractTests | | |
| FD-7 | 6 | Ten live stubs + HaloServices .fake/.live | Live/ x10, HaloServices.swift + test | HaloServicesTests | | |
| FD-8 | 7 | HaloProject holds document + every v1 stored property; == skips services | HaloProject.swift + 2 tests | HaloProjectTests | | |
| FD-9 | 8 | HaloFixtures (eight, huge ≤ 48 MiB) | HaloFixtures.swift + test | HaloFixturesTests | | |
| FD-10 | 9 | edit / endCoalescing / dismissRefusal / takeLayerID; mutators under edit; HB-9 | HaloProject, HaloTimeline + tests | HaloEditTests, HaloFoundationBudgetTests | | |
| FD-11 | 10 | HaloCommand, unavailableHelp, title, nine Availability files | HaloCommand.swift, Availability/ x9 + test | HaloCommandTests | | |
| FD-12 | 10 | viewerDrawList, viewerSummary, row key frames, status suffix; HB-6 | HaloViewerState, HaloTimeline, HaloStatusText + tests | HaloViewerStateTests, HaloTimelineCostTests | | |
| FD-13 | 11 | App: window/viewer split, HaloLaunch, HaloControls, stub rasterizer | Sources/HaloApp x6 | snapshot halo-window-launch-* | | |
| FD-14 | 12 | perform(_:) routes by area to nine HaloWindow+Area files | Sources/HaloApp x10 | macOS build, H-J13 | | |
| FD-15 | 13 | Stub views, inspector LAYERS + layer header, key diamonds, refusal caption | Sources/HaloApp x11 + 3 snapshots | halo-inspector-layer-selected-*, halo-timeline-keys-*, halo-refusal-* | | |
| FD-16 | 13 | Menus on HaloCommand | Sources/HaloApp x5 | testEveryMenuOpens | | |
| FD-17 | 14 | Accessibility labels and halo.* identifiers (#286, #290) | Sources/HaloApp x5 + 2 snapshots | H-J1, audit unnamed 0 | | |
| FD-18 | 15 | Journeys H-J0, H-J1, H-J13, layout (feature-done) | UITests/HaloJourneyTests.swift | the journeys | | |

## Rounds
| round | CI run | CI | audit vs baseline | lenses | confirmed | fixed by | clean |
|---|---|---|---|---|---|---|---|

## Decisions
- The packet is read from `origin/docs/halo-feature-packets` (ed58c3a); the issue says so until that PR merges.

- Waves follow the packet's chains: Model FD-1 → … → (FD-11 ∥ FD-12), then App FD-13 → FD-14 → (FD-15 ∥ FD-16) → FD-17 → FD-18; FD-19 rides wave 1.
- Builders run as Agent subagents in worktrees (not build-wave.js) so each next task can start stacked on its predecessor's branch and rebase --onto dev once the predecessor merges; the chain is serial, so this removes the merge wait. Brief: builder-brief.md in the lead's scratchpad.
- Builder branches are `lead/foundation-fd-<k>` (`lead/foundation/<id>` can't coexist with the `lead/foundation` ref).
- The container had no Swift: installed 6.3.3 with scripts/cloud-setup.sh; baseline scripts/ci on 52928d1: CI: PASS in 2m34s.

## Open
- none
