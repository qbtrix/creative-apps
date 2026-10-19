# inspector-controls lead record

Issue: #1508 · Packet: docs/blueprints/suiteui/features/inspector-controls.md
Run: act-1a15409e144-cyb5 (was act-1a150947ee2-hc6b, act-1a14c4f9bb5-swq8) · Session: claude/inspector-controls-adopt-kernel-export-ct4yeg · Started: 2026-10-16T22:48Z (resumed 2026-10-19T12:04Z)
Stage: 6 feature-done merged (#3094, cc14022e); waiting on a completed green suiteui/full dev run
Base: cd7d4120 (origin/dev)
Next: #3236 merged 15:18 as 452534d; full run 39278490377 (b3011ab) macOS scripts/ci step failed 16:54 (log still partial; head commit notes known #1625 PhotoTileCanvasTests, not this feature); red run cannot be the contact-sheet run; post Belt-Contact-Sheet on #1508 at the next green ci.yml run containing 452534d.

## Slices
Not a v3 packet (no `## Slices` table). v2 loop, contract rule 18 applies.

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| IC-1 | 1 | six inspector contracts and Fakes | Contracts/*.swift (six), InspectorFakeTests.swift | InspectorFakeTests | – | merged |
| IC-2 | 1 | ScrubField onEnd | ScrubField.swift | ScrubFieldEndTests | – | merged |
| IC-6 | 1 | Reset beside header (closes #622, #285) | InspectorRows.swift, InspectorAction.swift | InspectorSectionTests | – | merged |
| IC-9 | 1 | ToneCurveEditor on CurvePointEditing | ToneCurveEditor.swift | ToneCurveEditorTests | – | merged |
| IC-10 | 1 | KeyframeButton on KeyframeFacing | KeyframeButton.swift | KeyframeButtonTests | – | merged |
| IC-11 | 1 | PresetGrid on PresetNavigating | PresetGrid.swift, ChipRow.swift, ChoiceChips.swift | PresetGridTests | – | merged |
| IC-3 | 2 | HexColor onEnd (closes #718) | ColorWell.swift | HexColorTests | – | merged |
| IC-4 | 2 | ScrubTrack stepped (closes #591, #88) | ScrubValue.swift, ScrubField.swift | ScrubValueTests | – | merged |
| IC-8 | 2 | CurveEditor (closes #343) | CurveEditor.swift | CurveEditorTests | – | merged |
| IC-16 | 2 | baselines section-header, keyframe, presets | Golden/inspector | CI run actuals | #2946 | merged |
| IC-5 | 3 | SuiteValueScrubbing | ScrubValue.swift, NumericInput.swift | ScrubReferenceTests | – | merged |
| IC-7 | 3 | bar slider value (closes #262) | ScrubField.swift, StudioScrubRow.swift | SliderBarTests | – | merged |
| IC-17 | 3 | baselines chips, easing, tone | Golden/inspector | CI run actuals | #2947 | merged |
| IC-12 | 4 | inspector and curves gallery pages | Gallery/GalleryInspector.swift | CI gallery | #2699 | merged |
| IC-15 | 4 | baseline suiteui-slider-log | Golden/inspector | run 39153976103 actuals | #2943 | merged |
| IC-13 | 5 | journeys SJ11 to SJ15 | UITests/SuiteJourneyTests+Inspector.swift | journey | #2814 | merged |
| IC-14 | 5 | journeys SJ16, SJ20, SJ24, SP1, SP6, SP7 | UITests/SuiteJourneyTests+InspectorCurves.swift | journey | #2815, #2816 | merged |
| IC-18 | 6 | baseline header; wave.json built; feature-done | Golden/inspector, inspector-controls.wave.json | CI run | branch only | held |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|
| feature | 39153976103 | c91b1468 | clarity, journey, design, controls | #2951 to #2964 (4 blockers, 7 major, 3 minor; 1 refuted) | round 1 |

## Decisions
- Loop v2: no `## Slices` table in the packet.
- Suite-harness (#778) is `built`, so every wave-2 wait is met at this base.
- The three features own disjoint files, so one combined plan covers them. Per-packet waves merge by index (see the plan in the lead's scratchpad).
- Status channel: RECORD.md and timeline.tsv pushed to lead/inspector-controls at each stage, as the user asked. No PRs opened yet.
- Round 1 found that the fixes change what the inspector goldens render (slider, section header, curves, keyframe and header fixtures), so the baseline PRs #2943, #2946 and #2947 left the lane unmerged and IC-18 stays unopened. They get re-recorded from the first dev run after the fixes, so no stale golden turns dev red.

## Open
- needs-human: no Swift toolchain in the cloud container (scripts/ci --changed fails at swift build), so Fast-Check cannot be proven and SuiteUI cannot compile here.
- needs-human: gh token is invalid and the GitHub MCP server is disconnected, so no PR or issue comment can be posted from this session.
- Waiting on the supervisor: open the wave-1 PRs (builders, fast-lane label).
- Golden baselines (the last CM/LL/IC baseline tasks) need actuals from a dev CI run. They can't be done in one session.
- No macOS here: SwiftUI tasks are checked by the lane's build-only run and dev CI only.
- 2026-10-18: resumed under run act-1a14c4f9bb5-swq8; base moved to dev a6150139a815efa68d34af8723a1b58eea894f9c; no task of this feature was built in the meantime (checked dev for each owned symbol).
- 2026-10-18: wave 1 built, PRs held: scripts/ci fails on dev itself (five quarantine entries expire 2026-10-18), raised as #2504. Builder branches use a dash (lead/inspector-controls-<id>) because lead/inspector-controls exists as a ref.
- 2026-10-18T20:08Z: resumed under run act-1a150947ee2-hc6b. Scoped suiteui run 39153976103 (dev c91b1468, success, contains #2814/#2815/#2816) wrote 8 inspector golden-new names x 4 appearances (32 PNGs): suiteui-slider-log, section-header, suiteui-keyframe, presets, chips, suite-easing-curve, tone-curve, header. No exact-field or colour-row golden exists in code, so the packet's 44 becomes 32; split IC-15 (4), IC-16 (12), IC-17 (12), IC-18 (4, feature-done). Each PNG viewed before commit.
- 2026-10-18T20:14Z: round 1 not clean. The journey blockers SJ11, SJ13, SJ14, SJ15, SJ16 and SJ20 fail in run 39153976103, whose conclusion still reads success. Fix batch launched against base b1526f3e.
- 2026-10-18T20:37Z: fix batch done. r-b1 #2977 (#2951 #2955 #2957 #2958), r-b2 #2978 (#2952 #2961 #2963 #2964), r-b3 #2976 (#2953 #2959 #2960), r-b4 #2970 (#2954 #2956), each CI: PASS on Linux. #2962 still open. Removed the attribution footers that the REST writes added to the bodies of #2970, #2977 and #2978. Baselines #2943, #2946 and #2947 held with no-fast-lane.
- 2026-10-18T20:55Z: the lane merged #2943, #2946 and #2947 in a batch it started before the hold labels landed. These baselines are now stale against the round-1 fixes. IC-19 #2997 (slider-log, section-header, keyframe) and IC-20 #3001 (easing, tone curve) delete them. A missing baseline is only a known issue, so dev stays green; the deleted baselines get re-recorded from the first dev run containing the fixes. Chips and presets are not touched by any fix and stay.
- 2026-10-19T12:04Z: resumed under run act-1a15409e144-cyb5. All IC tasks and fix rounds merged (#2970 #2976 #2977 #2978 #3013 #3083 #3084 #3127 #3128 #3141 #3147 #3155 #3157 #3161 #3164 #3165 #3175); feature-done #3094 merged as cc14022e. Every dev ci.yml run since 11:14Z was cancelled (superseded); full run 39249031049 at cd7d4120 pending. #3236 open, clean, lane build 39243165907 queued.
