# adopt-kernel-easing lead record

Issue: #1937 · Packet: docs/blueprints/suiteui/features/adopt-kernel-easing.md
Run: act-1a14dfbdefe-il38 · Session: claude/adopt-kernel-features-qyyie4 · Started: 2026-10-18T08:30Z
Stage: 0 setup
Base: 2202c7c3fe0e659a41ec79db5e921c671b789ef4
Next: wait for editor-kernel (#1933) slice EK-keys: EK-15 (Keys body) and EK-16 (KeyRules body) merged, or its `Belt-Slice-Done: EK-keys` line on #1933; then stage 1 and wave 1 (AE-f1; AE-h1 also waits on adopt-kernel-selection:AS-halo)

Line lead for #1938, #1937 and #1936 (contract rule 19); this record is the
adopt-kernel-easing part. The brief names `main` at
e01529f43474e4e80489c080e0f598eaa3b05052, verified as `origin/main` and an
ancestor of `origin/dev`; PRs target `dev` per CLAUDE.md (the lane retargets a
fast-lane PR opened against `main` to `dev`).

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| AE-flare | Flare easing on `KeyRef`, `Segment`, `KeyState`, `EasePreset`, `EaseCurve`, `KeyRules` behind its API; copy deleted | AE-f1, AE-f2 | MJ-AE-flare (`EasingEditingContractTests`) | editor-kernel:EK-keys (AE-f1) | false | 0 | blocked | – | – |
| AE-halo | Halo easing on the same kernel types behind its API; copy deleted | AE-h1, AE-h2 | MJ-AE-halo (`KeyEasingContractTests`) | editor-kernel:EK-keys, adopt-kernel-selection:AS-halo (AE-h1) | false | 0 | blocked | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| AE-f1 | AE-flare | 1 | Flare adapter: `EasingSegment` = `Segment<String>`, kernel `KeyRef` with `.all`, `EasingPreset` = `EasePreset`; `EasingCurve` calls `EaseCurve`; Live/Fake easing and keyframes compute with `KeyRules` | Sources/FlareModel/EasingEditing.swift, Sources/FlareModel/Live/LiveEasing.swift, Sources/FlareModel/Fakes/FakeEasing.swift, Sources/FlareModel/Live/LiveKeyframes+Edit.swift, Sources/FlareModel/Live/LiveKeyframes+Frames.swift, Sources/FlareModel/Fakes/FakeKeyframes.swift, Tests/FlareModelTests/EasingEditingContractTests.swift, Tests/FlareModelTests/FlareEasingTests.swift, Tests/FlareModelTests/LiveEasingTests.swift, Tests/FlareModelTests/LiveKeyframesEditTests.swift, Tests/FlareModelTests/LiveKeyframesFramesTests.swift, Tests/FlareModelTests/MoveKeysPastEndTests.swift, Tests/mutations/FlareModel.KernelEasingAdapter.json | those six unchanged; `scripts/mutate --plan FlareModel.KernelEasingAdapter` (dropped `endRun()` forward; refusal mapped to success) | – | waiting (EK-keys) |
| AE-f2 | AE-flare | 2 | Flare delete: `EasingCurve`, repeated summary-key logic, rule bodies in keyframes files; plans repointed | Sources/FlareModel/EasingEditing.swift, Sources/FlareModel/Live/LiveEasing.swift, Sources/FlareModel/Fakes/FakeEasing.swift, Sources/FlareModel/Live/LiveKeyframes+Edit.swift, Sources/FlareModel/Live/LiveKeyframes+Frames.swift, Sources/FlareModel/Fakes/FakeKeyframes.swift, Tests/mutations/FlareModel.LiveEasing.json, Tests/mutations/FlareModel.LiveKeyframes+Edit.json | same tests; `scripts/mutate --validate` | – | waiting (AE-f1) |
| AE-h1 | AE-halo | 1 | Halo adapter: `HaloKeySegment` wraps `Segment<HaloProperty>`, `HaloKeyRef` = `KeyRef<HaloProperty>` (Codable, same keys), `HaloEasingPreset` = `EasePreset` (five shown); handles call `EaseCurve`; `HaloKeyRules` toggle/remove/state call `KeyRules` | Sources/HaloModel/HaloKeySelection.swift, Sources/HaloModel/Live/HaloKeyRules.swift, Sources/HaloModel/Live/HaloEasingRules.swift, Sources/HaloModel/Contracts/HaloValues.swift, Tests/HaloModelTests/KeyEasingContractTests.swift, Tests/HaloModelTests/HaloEasingTests.swift, Tests/HaloModelTests/HaloKeySelectionTests.swift, Tests/HaloModelTests/PropertyKeyingContractTests.swift, Tests/HaloModelTests/HaloKeyToggleTests.swift, Tests/mutations/HaloModel.KernelEasingAdapter.json | those five unchanged; `scripts/mutate --plan HaloModel.KernelEasingAdapter` | – | waiting (EK-keys, AS-halo) |
| AE-h2 | AE-halo | 2 | Halo delete: handle math, `HaloEasingPreset`, rule bodies; plans repointed | Sources/HaloModel/HaloKeySelection.swift, Sources/HaloModel/Live/HaloKeyRules.swift, Sources/HaloModel/Live/HaloEasingRules.swift, Sources/HaloModel/Contracts/HaloValues.swift, Tests/mutations/HaloModel.HaloKeySelection.json, Tests/mutations/HaloModel.HaloKeyRules.json | same tests; `scripts/mutate --validate` | – | waiting (AE-h1) |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- 2026-10-18T08:37Z: no task can start. Both slices' first tasks wait on editor-kernel:EK-keys. On origin/dev 2202c7c, `Sources/SuiteKernel/Keys/Keys.swift` and `KeyRules.swift` are the EK-3 stubs ("Stubs change nothing"); EK-14's tests (#2655) are open and disabled and EK-15/EK-16 bodies are planned for editor-kernel's wave 4. Recorded on #1937; stopped per lead.md stage 0 step 4.
- `Sources/HaloModel/Live/HaloKeyRules.swift` is owned by AE-halo and by adopt-kernel-layers' AL-halo; AL-h1 waits on AE-halo, so AE-h1/AE-h2 go first.
- Both slices are Model only (`"ui": false`); merged-done reads dev's Linux job. The last delete to merge carries `feature-done`.

## Open
- 2026-10-18T11:01Z: recheck 6 (sixth Belt nudge): EK-20 merged (#2711) but EK-15/EK-16 (EK-ease) still planned on lead/editor-kernel (d11bc14e); still blocked, rechecking at the next poll.
- 2026-10-18T10:27Z: fifth Belt nudge; rechecked. dev now a80ed944; EK-15/EK-16 still planned; EK-keys bodies still EK-3 stubs; editor-kernel lead relaunched (wo0uruy8p, 10:26Z), still stage 3 wave 2. Still blocked; stopped again.
- 2026-10-18T09:56Z: fourth Belt nudge; rechecked. dev now 02c20bfb; EK-14 tests #2655 now on dev (877567cf), so EK-15/EK-16 bodies are unblocked for editor-kernel; not started; EK-keys bodies still EK-3 stubs; editor-kernel lead still stage 3 wave 2 (heartbeat 09:53Z). lead.md gained the `Belt released this run.` stop rule (#2717), noted. Still blocked; stopped again.
- 2026-10-18T09:25Z: third Belt nudge; rechecked. dev now ed52eaa8; EK-14 tests #2655 not yet on dev; EK-keys bodies still EK-3 stubs; editor-kernel lead still stage 3 wave 2. Still blocked; stopped again.
- 2026-10-18T08:54Z: second Belt nudge; rechecked. dev now 93b1e91 (one Library perf merge since 2202c7c); EK-keys bodies still EK-3 stubs; editor-kernel lead at stage 3 wave 2, waiting on lane batch-20261018081953, wave 4 (bodies) not started. Still blocked; stopped again.
- 2026-10-18T08:23Z: Belt nudge after 30 quiet min; rechecked. dev still 2202c7c (no merges since); EK-keys bodies still EK-3 stubs; editor-kernel lead stopped at stage 3 wave 2 on dev-red #2667, wave 4 (bodies) not started. Still blocked; stopped again.
- Blocked on #1933 editor-kernel EK-keys (EK-15, EK-16). AE-halo also on adopt-kernel-selection:AS-halo (#1934's lead, blocked on EK-sel).
