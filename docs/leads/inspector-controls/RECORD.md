# inspector-controls lead record

Issue: #1508 · Packet: docs/blueprints/suiteui/features/inspector-controls.md
Run: act-1a146cb0013-zu3h · Session: (this session) · Started: 2026-10-16T22:48Z
Stage: 2 plan
Base: 1f55a91db97af4921e3e46c7d66e3dcf91401097
Next: wave 1 (builders, contract rule 18 applies). Waiting on the supervisor's go-ahead to open the wave-1 PRs.

## Slices
Not a v3 packet (no `## Slices` table). v2 loop, contract rule 18 applies.

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| IC-1 | 1 | six inspector contracts and Fakes | Contracts/*.swift (six), InspectorFakeTests.swift | InspectorFakeTests | – | planned |
| IC-2 | 1 | ScrubField onEnd | ScrubField.swift | ScrubFieldEndTests | – | planned |
| IC-6 | 1 | Reset beside header (closes #622, #285) | InspectorRows.swift, InspectorAction.swift | InspectorSectionTests | – | planned |
| IC-9 | 1 | ToneCurveEditor on CurvePointEditing | ToneCurveEditor.swift | ToneCurveEditorTests | – | planned |
| IC-10 | 1 | KeyframeButton on KeyframeFacing | KeyframeButton.swift | KeyframeButtonTests | – | planned |
| IC-11 | 1 | PresetGrid on PresetNavigating | PresetGrid.swift, ChipRow.swift, ChoiceChips.swift | PresetGridTests | – | planned |
| IC-3 | 2 | HexColor onEnd (closes #718) | ColorWell.swift | HexColorTests | – | planned |
| IC-4 | 2 | ScrubTrack stepped (closes #591, #88) | ScrubValue.swift, ScrubField.swift | ScrubValueTests | – | planned |
| IC-8 | 2 | CurveEditor (closes #343) | CurveEditor.swift | CurveEditorTests | – | planned |
| IC-16 | 2 | baselines header, keyframe, presets | Golden/inspector | CI run actuals | – | planned |
| IC-5 | 3 | SuiteValueScrubbing | ScrubValue.swift, NumericInput.swift | ScrubReferenceTests | – | planned |
| IC-7 | 3 | bar slider value (closes #262) | ScrubField.swift, StudioScrubRow.swift | SliderBarTests | – | planned |
| IC-17 | 3 | baselines chips, easing, tone | Golden/inspector | CI run actuals | – | planned |
| IC-12 | 4 | inspector and curves gallery pages | Gallery/GalleryInspector.swift | CI gallery | – | planned |
| IC-15 | 4 | baselines bar, exact, colour | Golden/inspector | CI run actuals | – | planned |
| IC-13 | 5 | journeys SJ11 to SJ15 | UITests/SuiteJourneyTests+Inspector.swift | journey | – | planned |
| IC-14 | 5 | journeys SJ16, SJ20, SJ24, SP1, SP6, SP7 | UITests/SuiteJourneyTests+InspectorCurves.swift | journey | – | planned |
| IC-18 | 6 | baselines title, info card; feature-done | Golden/inspector | CI run | – | planned |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|
| – | – | – | – | – | – |

## Decisions
- Loop v2: no `## Slices` table in the packet.
- Suite-harness (#778) is `built`, so every wave-2 wait is met at this base.
- The three features own disjoint files, so one combined plan covers them. Per-packet waves merge by index (see the plan in the lead's scratchpad).
- Status channel: RECORD.md and timeline.tsv pushed to lead/inspector-controls at each stage, as the user asked. No PRs opened yet.

## Open
- Waiting on the supervisor: open the wave-1 PRs (builders, fast-lane label).
- Golden baselines (the last CM/LL/IC baseline tasks) need actuals from a dev CI run. They can't be done in one session.
- No macOS here: SwiftUI tasks are checked by the lane's build-only run and dev CI only.
