# adjust-everywhere lead record

Issue: #3777 · Packet: docs/blueprints/suiteui/features/adjust-everywhere.md
Run: act-1a15cb4e0f5-ipbr (took over from act-1a15c4e2e3b-zh3u, released 04:25Z) · Session: claude/lead-fill-heal-adjust-everywhere-4clx57 · Started: 2026-10-21T02:36Z, relaunched 2026-10-21T04:29Z
Stage: 3 wave 1
Base: 2ab0eb96320db973b5aad0644449ee5ed3980ab9
Next: wait on IM-a (#3715) per the supervisor's 04:24Z answer on #3777; poll every 20 min; if nothing lands by 06:30Z the run is released and relaunched once IM-a is on dev

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| AJ-a | kinds, filters, commands, looks and the preset store as stubs | AJ-1, AJ-2 | – | suite-imaging:IM-a (AJ-1) | false | 0 | building (AJ-2s) | – | – |
| AJ-u | shared adjust UI on the stubs | AJ-3, AJ-4 | – | AJ-a, OC-photo-u | true | 0 | waiting | – | – |
| AJ-k | kind and filter bodies | AJ-5, AJ-5f | – | AJ-a, IM-m | false | 0 | waiting | – | – |
| AJ-c | commands and looks live | AJ-6, AJ-7 | – | AJ-k, TC-m, AJ-a | false | 0 | waiting | – | – |
| AJ-photo | Photo adopts | AJ-8, AJ-9 | – | AJ-c, IM-photo, BK-photo, AJ-u | true | 0 | waiting | – | – |
| AJ-library | Library adopts | AJ-10, AJ-11 | – | AJ-c, IM-z, ST-m, OC-library-m, AJ-u | true | 0 | waiting | – | – |
| AJ-halo | Halo adopts | AJ-12, AJ-13 | – | AJ-c, AN-halo, AJ-u | true | 0 | waiting | – | – |
| AJ-z | finish | AJ-14, AJ-15 | – | all adopter slices | false | 0 | waiting | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| AJ-1 | AJ-a | 2+ | kinds, filters, commands stubs + disabled checks | Sources/SuiteImaging/Adjust/{AdjustKinds,FilterRules,AdjustCommands}.swift, tests, C4 part | suites compile | – | blocked (IM-a) |
| AJ-2s | AJ-a | 1 | PresetStoring, PresetRecord, PresetStore, FakePresetStore; PresetStoreTests disabled (waits on AJ-7); C4 part | Sources/SuiteModel/Presets/PresetStore.swift, Sources/SuiteModel/Fakes/FakePresetStore.swift, Tests/SuiteModelTests/PresetStoreTests.swift, docs/c4/parts/creative-apps/suite-model/suite-presets.json | compiles, disabled by name | #3846 | in lane (Fast-Check pass, clean) |
| AJ-2l | AJ-a | 2+ | LookPreset, BuiltInLooks as data | Sources/SuiteImaging/Adjust/LookPresets.swift | built-in looks decode | – | blocked (IM-a: target, ToneSettings) |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- Base dev, not main: CLAUDE.md and the lane retarget main to dev.
- Status mirrored to lead/suiteui-adjust-everywhere (docs/leads/suiteui-adjust-everywhere/), the branch name Belt's nudge read; lead/adjust-everywhere kept, per the brief.
- AJ-2 split: AJ-2s (SuiteModel store) has no wait and ships now; AJ-2l (LookPresets.swift) needs the SuiteImaging target and ToneSettings from IM-a, which aren't on dev.

## Open
- suite-imaging #3715: no lead branch, no slice done, Sources/SuiteImaging absent on dev (2026-10-21T02:36Z). Blocks AJ-1, AJ-2l, so every later slice.
- 2026-10-21T04:29Z: run act-1a15c4e2e3b-zh3u was released by Belt at 04:25Z; act-1a15cb4e0f5-ipbr carries its state (lead branches, open slice PRs) rather than redoing it. The supervisor (04:24Z, #3777): wait, do not build IM-a or BK-m; the p0 issues start next shift; release at 06:30Z if nothing has landed.

## Run act-1a1693a4009-hyio (line lead: area-selection, adjust-everywhere, shared-raw)
- 2026-10-23T14:53Z: IM-a and IM-m are on dev (SuiteImaging target, IM-3 #4390, IM-4 #4393, IM-15 #4389); AJ-1 and AJ-2l are unblocked.
- Wave 1 (base dev 8021b0f5): builder B AJ-a (AJ-1 + LookPresets.swift), then stacked AJ-k (AJ-5, AJ-5f), AJ-7, and AJ-6 if TC-m is on dev.
- Blocked: AJ-u on OC-photo-u; AJ-photo on IM-photo (#4619 needs-split); AJ-library on IM-z, ST-m, OC-library-m; AJ-halo on AN-halo.
- Open findings for this feature: 0, so no wave gate.
