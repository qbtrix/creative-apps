# text-layers lead record

Issue: #1509 · Packet: docs/blueprints/halo/features/text-layers.md
Run: act-1a149b53ef6-67v7 (line lead for #1035, #1509, #1505; earlier runs act-1a1487bf880-qmey, act-1a1429c87eb-3ecm) · Session: claude/feature-lead-playbook-l4ybf6 · Started: 2026-10-17T06:05Z
Stage: 3 wave 2
Base: 8e868417eeaf2fd17229c21bc1087ef7eecb3d8f (origin/dev at 2026-10-17T13:53Z)
Next: wave 2 running (TX-5, TX-6 beside render-out's RO-4, RO-5); when the lane has merged them, start wave 3 (TX-7 feature-done)

## Tasks
| id | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|
| TX-1 | 1 | `setText`, `setFontSize`, `endTextSizeScrub`, `selectedText`, `fontSizeRange`, `sizeText`; edits store the measured box from `services.text.measure` (estimate when nil); one named step per commit, scrubs coalesced | Sources/HaloModel/HaloTextEdits.swift, Tests/HaloModelTests/HaloTextLayerTests.swift | HaloTextLayerTests | #2060 | merged |
| TX-2 | 1 | `setLayerColor` ("Change Color") for text, solid and shape; `selectedLayerColor`; `HaloLayerColor(bytes:)` and `bytes` | Sources/HaloModel/HaloTextEdits+Color.swift, Tests/HaloModelTests/HaloTextColorTests.swift | HaloTextColorTests | #2063 | merged |
| TX-3 | 1 | `HaloAvailability+Text.swift` replaced whole: the text commands answer state only | Sources/HaloModel/Availability/HaloAvailability+Text.swift, Tests/HaloModelTests/HaloTextAvailabilityTests.swift | HaloTextAvailabilityTests | #2065 | merged |
| TX-4 | 1 | `HaloTextRasterizer` on CoreText replaces W0's stub: `measure` and `rasterize` | Sources/HaloApp/HaloTextRasterizer.swift, Tests/AppSnapshotTests/HaloTextRasterizerTests.swift | HaloTextRasterizerTests (macOS) | #2064 | merged |
| TX-5 | 2 | HF-10 macOS half: ink inside the stored box; viewer matches `render` | Tests/AppSnapshotTests/HaloTextFidelityTests.swift | HaloTextFidelityTests (macOS) | – | building |
| TX-6 | 2 | App: `HaloTextInspector` (TEXT header, TextField with view-local draft, InspectorSliderRow size, InspectorColorRow, refusal caption) through `perform`; `HaloWindow+Text` routes the cases; snapshots | Sources/HaloApp/HaloTextInspector.swift, Sources/HaloApp/HaloWindow+Text.swift, Tests/AppSnapshotTests/HaloTextLayerSnapshots.swift | halo-text-layer-*.png, halo-text-refused-*.png | – | building |
| TX-7 | 3 | Journey H-J22 on `-HaloSample empty`; shared-doc edits (c4-planned.json, text-layers.wave.json `owned` and `status: built`); `feature-done`, `Closes #430` | UITests/HaloJourneyTests+Text.swift, docs/blueprints/halo/c4-planned.json, docs/blueprints/halo/features/text-layers.wave.json | H-J22 on dev CI | – | planned |

Waves (combined with render-out, contract rule 19; checked against dev b8dfb4f0): W1 TX-1, TX-2, TX-3, TX-4 (all independent, with RO-1, RO-2, RO-3); W2 TX-5 (waits TX-1, TX-4), TX-6 (waits TX-1, TX-2, TX-3, TX-4) (independent of each other, with RO-4, RO-5); W3 TX-7 (waits TX-5, TX-6; feature-done) with RO-6, RO-7, RO-9.

## Rounds
| round | CI run | CI | audit vs baseline | lenses | confirmed | fixed by | clean |
|---|---|---|---|---|---|---|---|
| – | – | – | – | – | – | – | – |

## Decisions
- 2026-10-17T13:53Z TX-1 (#2060) keeps a private copy of the selected text layer lookup because the one in HaloLayerEdits.swift is file-private (not its file); a later cleanup can share it. TX-3 (#2065) covers all four text commands (the packet said three).
- 2026-10-17T06:05Z: line lead for #1035 (done, supervisor decision 06:06Z), #1509 and #1505 in one run. Waits met: #1036 closed, #1037 built, #1035 done, #333 closed (#877 merged). The brief named `main` as the integration branch; the fast lane merges into `dev` and retargets a PR based on `main`, so PRs base `dev` as CLAUDE.md says.
- No Swift on this box at launch; installed swift 6.3.3 (CI's image version) under /opt/swift so `scripts/ci` can run the Model tests.
- Rule 18 for this v2 packet: wave 1's Model tasks TX-1 to TX-3 are themselves the signatures the UI calls (small, full bodies), so no separate stub task; TX-6 starts in wave 2 the moment they merge, beside TX-5. The packet's waves stand.
- Canonical first (rule 20): text edits, size and color are Halo-specific (no SuiteModel or other-app copy); undo goes through W0's `edit` and `services.history`, which is the grandfathered Halo history. No kernel concept is added.
- Work started after #1302: the critic panel files findings as `finding` issues (`issue`, `commit`, `open`), the fix batch takes issue numbers, round cap 2.
- lead/text-layers was 967 commits off main with no shared history; rebuilt as one records-only commit on origin/main (as Belt did for viewer-playback).

## Open
- none
