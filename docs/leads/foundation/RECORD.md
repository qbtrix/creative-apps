# foundation lead record

Issue: #777 · Packet: docs/blueprints/halo/features/foundation.md (on branch `docs/halo-feature-packets` until its PR merges)
Run: act-1a13b78bcdb-qu60 · Session: session_01Dc9GDxc9HxLtv9XMcFgSWh · Started: 2026-10-14T17:33Z
Stage: 3 wave 14
Base: 52928d1dbbdd72b849f7fdb6363991f35b1adbeb
Next: chain builder does FD-17 (stacked on FD-15 #937) then FD-18 (fast-lane + feature-done); then find the dev CI run the lane dispatches and start round 1 of the Anatomy loop

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
| FD-17 | 14 | Accessibility labels and halo.* identifiers (#286, #290) | Sources/HaloApp x5 + 2 snapshots | H-J1, audit unnamed 0 | | building |
| FD-18 | 15 | Journeys H-J0, H-J1, H-J13, layout (feature-done) | UITests/HaloJourneyTests.swift | the journeys | | building |

## Rounds
| round | CI run | CI | audit vs baseline | lenses | confirmed | fixed by | clean |
|---|---|---|---|---|---|---|---|

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

## Open
- docs/c4/model.json "HaloApp sources" description still names only the Layer and Composition menus; the supervisor folds C4 descriptions in (packet: no shared docs).
