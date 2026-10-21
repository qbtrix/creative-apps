# text-layers lead record

Issue: #1509 · Packet: docs/blueprints/halo/features/text-layers.md
Run: act-1a14c24f6d2-lrkw (line lead for #1035, #1509, #1505, resumed 2026-10-17T23:16Z; earlier runs act-1a149b53ef6-67v7, act-1a1487bf880-qmey, act-1a1429c87eb-3ecm) · Session: session_015KXNRSDGxdpyRwt5HgCf3U · Started: 2026-10-17T06:05Z
Stage: 6 stopped: run act-1a14c24f6d2-lrkw posted Belt-Contact-Sheet (39076534514, red) at 2026-10-18T00:36Z with the round budget spent, filed the remaining work as gaps, and stopped the lead. Older run act-1a149b53ef6-67v7 stood down at 2026-10-18T01:26Z. Full dev CI is also red on expired quarantine entries (supervisor asked on #1505, comment 6244022808)
Base: 59c435a6e190a84496ac81a2358cf13a8bdb5fcf (origin/main at 2026-10-17T23:16Z; dev e26c99f8)
Next: nothing. The lead stopped: Belt-Contact-Sheet posted at 00:36Z on run 39076534514 (red, round budget spent). Remaining work is in gaps #2510 (H-J22 step 5 draft) and #2512 (adopt the SuiteUI timeline prefix once #1789 lands). #1789 has an ask to make timelineIdentifierPrefix public (issuecomment-6243790881). The expired-quarantine question on #1505 (comment 6244022808) is the supervisor's.

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
- 2026-10-17T16:39Z Full CI 39045632781 on dd7ec767 ended cancelled (superseded); the scoped halo run 39045670179 stands for round 1. Fix A #2188 (head 9aea9534, 7 files +255/−29, full scripts/ci PASS): rules in new Sources/HaloModel/HaloTextInspectorRules.swift; Size drag range 1...200 (typing stays 1...1000); draft tagged with its layer (HaloTextDraft). H-J22 step 5 is a regression guard; the Model test aDraftStaysWithItsLayer is the failing-before test for #2177.
- 2026-10-17T16:40Z Fix B #2189 (head ba9db0e7, 7 files +64/−19, full scripts/ci PASS): text default ink #1A1A1A (WCAG ≥4.5:1 test, about 17:1); selectedLayerIndices made internal and reused; wave.json journey HaloTextJourneyTests.testTextLayer. It also edited HaloTextLayerTests.renderedFrameFillsTheStoredBox (assumed white ink) to check the layer's own color, as TX-1 states. #2188 and #2189 both list halo-text-layer and halo-text-refused PNGs; they touch different files, so they don't conflict.

- Round 2 (2026-10-17T19:08Z, scoped 39056662077, e17b68f9): #2175, #2176, #2178, #2179, #2180 and #2181 are fixed. #2177 is reopened: the Model is fixed but the view TextField keeps its focused draft (journey +Text.swift:137). No new findings. Audit identifier 38/0, none from text-layers (#1789, #1484, #2261).
