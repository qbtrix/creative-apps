# adjust-everywhere lead record

Issue: #3777 · Packet: docs/blueprints/suiteui/features/adjust-everywhere.md
Run: act-1a1693a4009-hyio (line lead: area-selection, adjust-everywhere, shared-raw) · Session: claude/feature-lead-playbook-fkjibd · Started: 2026-10-23T14:40Z
Stage: 3 wave 1
Base: 35a0b5e7e9520a764f3eabf02968a453082a87cc
Next: check between waves: which of #4834, #4846, #4853, #4863, #4867 merged; restack and drop needs-split on #4846/#4863 as their bases merge; start AJ-6 once tone-controls TC-m is on dev.

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| AJ-a | kinds, filters, commands, looks, preset store as stubs | AJ-1, AJ-2 | – | IM-a (met) | false | 0 | building (#4834, #4846; AJ-2s #3846 merged earlier) | – | – |
| AJ-u | shared adjust UI on the stubs | AJ-3, AJ-4 | – | AJ-a, OC-photo-u | true | 0 | waiting (OC-photo-u) | – | – |
| AJ-k | kind and filter bodies | AJ-5, AJ-5f | – | AJ-a, IM-m (met) | false | 0 | building (#4853, #4863) | – | – |
| AJ-c | commands and looks live | AJ-6, AJ-7 | – | AJ-k, TC-m | false | 0 | building (AJ-7 #4867; AJ-6 waits TC-m) | – | – |
| AJ-photo | Photo adopts | AJ-8, AJ-9 | – | AJ-c, IM-photo, BK-photo, AJ-u | true | 0 | waiting | – | – |
| AJ-library | Library adopts | AJ-10, AJ-11 | – | AJ-c, IM-z, ST-m, OC-library-m, AJ-u | true | 0 | waiting | – | – |
| AJ-halo | Halo adopts | AJ-12, AJ-13 | – | AJ-c, AN-halo, AJ-u | true | 0 | waiting | – | – |
| AJ-z | finish | AJ-14, AJ-15 | – | adopter slices | false | 0 | waiting | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| AJ-1a | AJ-a | 1 | AdjustKinds stubs, LookPresets, C4 part imaging-adjust-kinds | Sources/SuiteImaging/Adjust/{AdjustKinds,LookPresets}.swift, tests, docs/c4/parts | LookPresetsTests | #4834 | open, fast-lane (head 9074049) |
| AJ-1b | AJ-a | 1 | FilterRules, AdjustCommands stubs | Sources/SuiteImaging/Adjust/{FilterRules,AdjustCommands}.swift, tests | contractShape | #4846 | open, stacked on #4834 (needs-split) |
| AJ-5 | AJ-k | 1 | B&W and invert bodies | Sources/SuiteImaging/Adjust/AdjustKinds.swift | AdjustKindsTests, Mutate 2/2 | #4853 | open, stacked on #4834 (head 542a4c0) |
| AJ-5f | AJ-k | 1 | five filters over core | Sources/SuiteImaging/Adjust/FilterRules.swift | FilterRulesTests, Mutate 3/3 | #4863 | open, stacked on #4846 (needs-split) |
| AJ-7 | AJ-c | 1 | PresetStore over FileStore presets/looks.json | Sources/SuiteModel/Presets/PresetStore.swift | PresetStoreTests, Mutate 2/2 | #4867 | open, fast-lane (head 0b558d5) |
| AJ-6 | AJ-c | – | adjust commands live | Sources/SuiteImaging/Adjust/AdjustCommands.swift | AdjustCommandsTests | – | waiting (TC-m: ToneCommands/ToneRules/ToneSettings still stubs) |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- Status branch is lead/suiteui-adjust-everywhere (the name Belt reads); lead/adjust-everywhere kept as a mirror.
- AJ-5 B&W: one grey row on linear colour on both GPU and CPU (hue-band B&W isn't a 3x3 matrix); invert on linear levels to match core. Both stated in #4853.
- AJ-a ships as two PRs (#4834, #4846) to stay under 400 lines each.

## Open
- AJ-u waits on OC-photo-u; AJ-photo on IM-photo (#4619 needs-split); AJ-library on IM-z, ST-m, OC-library-m; AJ-halo on AN-halo; AJ-6 on TC-m.
- Open findings for this feature: 0.
