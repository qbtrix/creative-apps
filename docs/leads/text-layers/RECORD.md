# text-layers lead record

Issue: #1509 · Packet: docs/blueprints/halo/features/text-layers.md
Run: act-1a149b53ef6-67v7 (line lead for #1035, #1509, #1505; earlier runs act-1a1487bf880-qmey, act-1a1429c87eb-3ecm) · Session: claude/feature-lead-playbook-l4ybf6 · Started: 2026-10-17T06:05Z
Stage: 4 Anatomy fix round 1 (round 1 not clean: 2 major, 5 minor)
Base: 8e868417eeaf2fd17229c21bc1087ef7eecb3d8f (origin/dev at 2026-10-17T13:53Z)
Next: fixer A (halo/text-inspector-fixes: #2175 #2177 #2180 #2181) and fixer B (halo/text-model-fixes: #2176 #2178 #2179) open PRs; after both merge, scoped halo run + Anatomy round 2; ≤2 fix rounds then leftover findings → gap; contact sheet on #1509 after green CI

## Tasks
| id | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|
| TX-1 | 1 | `setText`, `setFontSize`, `endTextSizeScrub`, `selectedText`, `fontSizeRange`, `sizeText`; edits store the measured box from `services.text.measure` (estimate when nil); one named step per commit, scrubs coalesced | Sources/HaloModel/HaloTextEdits.swift, Tests/HaloModelTests/HaloTextLayerTests.swift | HaloTextLayerTests | #2060 | merged |
| TX-2 | 1 | `setLayerColor` ("Change Color") for text, solid and shape; `selectedLayerColor`; `HaloLayerColor(bytes:)` and `bytes` | Sources/HaloModel/HaloTextEdits+Color.swift, Tests/HaloModelTests/HaloTextColorTests.swift | HaloTextColorTests | #2063 | merged |
| TX-3 | 1 | `HaloAvailability+Text.swift` replaced whole: the text commands answer state only | Sources/HaloModel/Availability/HaloAvailability+Text.swift, Tests/HaloModelTests/HaloTextAvailabilityTests.swift | HaloTextAvailabilityTests | #2065 | merged |
| TX-4 | 1 | `HaloTextRasterizer` on CoreText replaces W0's stub: `measure` and `rasterize` | Sources/HaloApp/HaloTextRasterizer.swift, Tests/AppSnapshotTests/HaloTextRasterizerTests.swift | HaloTextRasterizerTests (macOS) | #2064 | merged |
| TX-5 | 2 | HF-10 macOS half: ink inside the stored box; viewer matches `render` | Tests/AppSnapshotTests/HaloTextFidelityTests.swift | HaloTextFidelityTests (macOS) | #2107 | merged |
| TX-6 | 2 | App: `HaloTextInspector` (TEXT header, TextField with view-local draft, InspectorSliderRow size, InspectorColorRow, refusal caption) through `perform`; `HaloWindow+Text` routes the cases; snapshots | Sources/HaloApp/HaloTextInspector.swift, Sources/HaloApp/HaloWindow+Text.swift, Tests/AppSnapshotTests/HaloTextLayerSnapshots.swift | halo-text-layer-*.png, halo-text-refused-*.png | #2109 | merged |
| TX-7 | 3 | Journey H-J22 on `-HaloSample empty`; shared-doc edits (c4-planned.json, text-layers.wave.json `owned` and `status: built`); `feature-done`, `Closes #430` | UITests/HaloJourneyTests+Text.swift, docs/blueprints/halo/c4-planned.json, docs/blueprints/halo/features/text-layers.wave.json | H-J22 on dev CI | #2132 | merged (dd7ec767) |

Waves (combined with render-out, contract rule 19; checked against dev b8dfb4f0): W1 TX-1, TX-2, TX-3, TX-4 (all independent, with RO-1, RO-2, RO-3); W2 TX-5 (waits TX-1, TX-4), TX-6 (waits TX-1, TX-2, TX-3, TX-4) (independent of each other, with RO-4, RO-5); W3 TX-7 (waits TX-5, TX-6; feature-done) with RO-6, RO-7, RO-9.

## Rounds
| round | CI run | CI | audit vs baseline | lenses | confirmed | fixed by | clean |
|---|---|---|---|---|---|---|---|
| – | – | – | – | – | – | – | – |

## Decisions
- 2026-10-17T14:14Z TX-6 (#2109): the help text comes from public `unavailableHelp(for:)`, since `textHelp` is internal. The snapshots show the viewer and the text inspector side by side. The color row shows only when `selectedLayerColor` is set. Two suspects go to the Anatomy panel as inputs: (1) a duplicate refusal caption, because HaloLayerInspector catch-all also shows `halo.inspector.text.string`; (2) the draft committed on focus loss after a layer switch may land on the newly selected layer.
- 2026-10-17T13:55Z Between-wave check: the open Halo `CI finding:` issues (#1574, #1696-#1705, #2077-#2081) are all a launch crash, SuiteKernel.framework missing from AfterGlow.app (scripts/bundle-apps, from #1992). Filed #2099 for the supervisor. They are not findings of this feature (no Feature: line, not in its files), so the 5-open pause does not apply.
- 2026-10-17T13:53Z TX-1 (#2060) keeps a private copy of the selected text layer lookup because the one in HaloLayerEdits.swift is file-private (not its file); a later cleanup can share it. TX-3 (#2065) covers all four text commands (the packet said three).
- 2026-10-17T06:05Z: line lead for #1035 (done, supervisor decision 06:06Z), #1509 and #1505 in one run. Waits met: #1036 closed, #1037 built, #1035 done, #333 closed (#877 merged). The brief named `main` as the integration branch; the fast lane merges into `dev` and retargets a PR based on `main`, so PRs base `dev` as CLAUDE.md says.
- No Swift on this box at launch; installed swift 6.3.3 (CI's image version) under /opt/swift so `scripts/ci` can run the Model tests.
- Rule 18 for this v2 packet: wave 1's Model tasks TX-1 to TX-3 are themselves the signatures the UI calls (small, full bodies), so no separate stub task; TX-6 starts in wave 2 the moment they merge, beside TX-5. The packet's waves stand.
- Canonical first (rule 20): text edits, size and color are Halo-specific (no SuiteModel or other-app copy); undo goes through W0's `edit` and `services.history`, which is the grandfathered Halo history. No kernel concept is added.
- Work started after #1302: the critic panel files findings as `finding` issues (`issue`, `commit`, `open`), the fix batch takes issue numbers, round cap 2.
- lead/text-layers was 967 commits off main with no shared history; rebuilt as one records-only commit on origin/main (as Belt did for viewer-playback).

## Open
- none
- 2026-10-17T14:58Z TX-7 starts before render-out's RO-4/RO-5 merge: it depends only on TX-5, TX-6 (merged) and #333 (closed via #877) and shares no file with render-out.
- 2026-10-17T15:05Z TX-7 (#2132) reads the artboard through halo.viewer.summary (the only published element; halo.viewer.artboard is only the drag's refusal name), accepts "96 px" or 96 as the size bar value, finds the size field as the non-TEXT field on the bar's row; sets text-layers.wave.json status built and feature_issue #1509 per lead.md Finish step 1; journeys entry keeps HaloJourneyTests.testTextLayer naming (class is HaloTextJourneyTests), as easing's entry does. Audit baseline expected unchanged.
- 2026-10-17T16:22Z Anatomy round 1 (scoped halo 39045670179, dd7ec767): not clean. H-J22 red at step 4 (two refusal captions). Findings: #2175 major (duplicate refusal caption), #2176 major (white text on white artboard), #2177 minor (draft not keyed to layer), #2178 minor (duplicate selection lookup), #2179 minor (wave.json journey class name), #2180 minor (Size slider marker over label), #2181 minor ("Enter some text." under Color). Audit: identifier 17 over 0 (1 from this feature, already #2159; 16 from other journeys, filed); contrast 2 vs 2. 0 refuted. Fix round 1 batches by file: A inspector views, B Model + wave.json.
