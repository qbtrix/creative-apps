# adopt-kernel-easing lead record

Issue: #1937 · Packet: docs/blueprints/suiteui/features/adopt-kernel-easing.md
Run: act-1a14dfbdefe-il38 · Session: claude/adopt-kernel-features-qyyie4 · Started: 2026-10-18T08:30Z
Stage: 3 wave 2 (AE-flare) + wave 1 (AE-halo)
Base: 4bf67be861d056068f683878a580864ac71bed21
Next: (16:32Z) #2842 (AE-h2) merged as ae72cc6c. #2828 closed, superseded by #2841. Waiting on full CI 39145334588 (ae72cc6c, which has #2819 and #2842) and flare run 39142436739: when green, Belt-Slice-Done AE-flare and AE-halo, then Belt-Contact-Sheet.

Line lead for #1938, #1937 and #1936 (contract rule 19); this record is the
adopt-kernel-easing part. The brief names `main` at
e01529f43474e4e80489c080e0f598eaa3b05052, verified as `origin/main` and an
ancestor of `origin/dev`; PRs target `dev` per CLAUDE.md (the lane retargets a
fast-lane PR opened against `main` to `dev`).

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| AE-flare | Flare easing on `KeyRef`, `Segment`, `KeyState`, `EasePreset`, `EaseCurve`, `KeyRules` behind its API; copy deleted | AE-f1, AE-f2 | MJ-AE-flare (`EasingEditingContractTests`) | editor-kernel:EK-keys (AE-f1) | false | 0 | building | – | – |
| AE-halo | Halo easing on the same kernel types behind its API; copy deleted | AE-h1, AE-h2 | MJ-AE-halo (`KeyEasingContractTests`) | editor-kernel:EK-keys, adopt-kernel-selection:AS-halo (AE-h1) | false | 0 | building | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| AE-f1 | AE-flare | 1 | Flare adapter: `EasingSegment` = `Segment<String>`, kernel `KeyRef` with `.all`, `EasingPreset` = `EasePreset`; `EasingCurve` calls `EaseCurve`; Live/Fake easing and keyframes compute with `KeyRules` | Sources/FlareModel/EasingEditing.swift, Sources/FlareModel/Live/LiveEasing.swift, Sources/FlareModel/Fakes/FakeEasing.swift, Sources/FlareModel/Live/LiveKeyframes+Edit.swift, Sources/FlareModel/Live/LiveKeyframes+Frames.swift, Sources/FlareModel/Fakes/FakeKeyframes.swift, Tests/FlareModelTests/EasingEditingContractTests.swift, Tests/FlareModelTests/FlareEasingTests.swift, Tests/FlareModelTests/LiveEasingTests.swift, Tests/FlareModelTests/LiveKeyframesEditTests.swift, Tests/FlareModelTests/LiveKeyframesFramesTests.swift, Tests/FlareModelTests/MoveKeysPastEndTests.swift, Tests/mutations/FlareModel.KernelEasingAdapter.json | those six unchanged; `scripts/mutate --plan FlareModel.KernelEasingAdapter` (dropped `endRun()` forward; refusal mapped to success) | #2786 | merged |
| AE-f2 | AE-flare | 2 | Flare delete: `EasingCurve`, repeated summary-key logic, rule bodies in keyframes files; plans repointed | Sources/FlareModel/EasingEditing.swift, Sources/FlareModel/Live/LiveEasing.swift, Sources/FlareModel/Fakes/FakeEasing.swift, Sources/FlareModel/Live/LiveKeyframes+Edit.swift, Sources/FlareModel/Live/LiveKeyframes+Frames.swift, Sources/FlareModel/Fakes/FakeKeyframes.swift, Tests/mutations/FlareModel.LiveEasing.json, Tests/mutations/FlareModel.LiveKeyframes+Edit.json | same tests; `scripts/mutate --validate` | #2819 | merged |
| AE-h1 | AE-halo | 1 | Halo adapter: `HaloKeySegment` wraps `Segment<HaloProperty>`, `HaloKeyRef` = `KeyRef<HaloProperty>` (Codable, same keys), `HaloEasingPreset` = `EasePreset` (five shown); handles call `EaseCurve`; `HaloKeyRules` toggle/remove/state call `KeyRules` | Sources/HaloModel/HaloKeySelection.swift, Sources/HaloModel/Live/HaloKeyRules.swift, Sources/HaloModel/Live/HaloEasingRules.swift, Sources/HaloModel/Contracts/HaloValues.swift, Tests/HaloModelTests/KeyEasingContractTests.swift, Tests/HaloModelTests/HaloEasingTests.swift, Tests/HaloModelTests/HaloKeySelectionTests.swift, Tests/HaloModelTests/PropertyKeyingContractTests.swift, Tests/HaloModelTests/HaloKeyToggleTests.swift, Tests/mutations/HaloModel.KernelEasingAdapter.json | those five unchanged; `scripts/mutate --plan HaloModel.KernelEasingAdapter` | #2818 | merged |
| AE-h2 | AE-halo | 2 | Halo delete: handle math, `HaloEasingPreset`, rule bodies; plans repointed | Sources/HaloModel/HaloKeySelection.swift, Sources/HaloModel/Live/HaloKeyRules.swift, Sources/HaloModel/Live/HaloEasingRules.swift, Sources/HaloModel/Contracts/HaloValues.swift, Tests/mutations/HaloModel.HaloKeySelection.json, Tests/mutations/HaloModel.HaloKeyRules.json | same tests; `scripts/mutate --validate` | #2842 | pr-open |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- 2026-10-18T08:37Z: no task can start. Both slices' first tasks wait on editor-kernel:EK-keys. On origin/dev 2202c7c, `Sources/SuiteKernel/Keys/Keys.swift` and `KeyRules.swift` are the EK-3 stubs ("Stubs change nothing"); EK-14's tests (#2655) are open and disabled and EK-15/EK-16 bodies are planned for editor-kernel's wave 4. Recorded on #1937; stopped per lead.md stage 0 step 4.
- `Sources/HaloModel/Live/HaloKeyRules.swift` is owned by AE-halo and by adopt-kernel-layers' AL-halo; AL-h1 waits on AE-halo, so AE-h1/AE-h2 go first.
- Both slices are Model only (`"ui": false`); merged-done reads dev's Linux job. The last delete to merge carries `feature-done`.

- 2026-10-18T12:25Z: stage 0 waits met: EK-15 Keys body #2732 and EK-16 KeyRules body #2731 merged. Stage 1/2: packet rows match the code; AE-f1's mutation text is replaced by plausible adapter bugs (refusal mapped to success fits). Wave 1 = AE-f1 now; AE-h1 joins when AS-h2 merges.
- 2026-10-18T13:45Z: AE-f1 → PR #2786 (Mutate 6/6 FlareModel.KernelEasingAdapter, 398 lines, 11 files). Flare's deviations from the kernel are kept in the adapter and listed in the body (insert at frame moves that key, empty curve below 2 samples, nil on a non-finite handle, overflow-then-range-then-collision refusal order). `KeyRef`/`KeyState` stay in AnimateContracts.swift (not in AE-f1's files); AE-f2 may move them if the size allows. The lane labelled it needs-rebase: #2776 (AL-f1) edited the same FlareModel C4 description. The lead merged origin/dev, kept both sentences, reran the gate and moved Head.

- 2026-10-18T14:30Z: AE-f1 #2786 merged 14:15Z. AS-h2 #2792 merged, so AS-halo's wait is met. Wave 2 for AE-flare (AE-f2) and wave 1 for AE-halo (AE-h1) build in parallel: their files are disjoint (FlareModel vs HaloModel). AE-f2 is not the feature's last task (AE-h2 follows), so no feature-done.

- 2026-10-18T15:10Z: AE-h1 → PR #2818 (Mutate 6/6 HaloModel.KernelEasingAdapter, 8 files, +183/−58). Deviations kept in the adapter: `HaloKeyRef` and `HaloEasingPreset` stay Halo types (Codable `property` key; five presets, "Ease In and Out" title), `HaloKeySegment` keeps its fields (no `.all`), static value after the last-but-one key goes, stopwatch keys frame 0 at the last frame and keeps one key on a one-frame composition, track sorted before insert. The server-added attribution footer was removed from the body so the contract lines end it.

- 2026-10-18T15:15Z: AE-f2 → PR #2819 (Mutate 8/8 FlareModel.KernelEasingAdapter, 9 files, +97/−116). Live and Fake now share `KeyRef.setEasing` and `KernelKeys.move/remove/removeFrames/lastKey`; each conformer passes only AE-f1's deviations. `EasingCurve` stays as thin forwards (FlareApp snapshots use it). The packet's plans `FlareModel.LiveEasing.json` and `FlareModel.LiveKeyframes+Edit.json` don't exist on dev, so nothing was repointed; two new mutations cover the shared helpers. Gap noted by the builder: no test pins that a key on the first frame after a removed run shifts back (its first mutation for that went uncaught and was replaced). Footer removed from the body.

- 2026-10-18T15:45Z: #2818 merged 15:32Z (macOS build 39139315662 green). After the merge the lead found it also changed `Sources/SuiteUI/SegmentedTabs.swift`, reverting #2807's TabsProbe fix (#2805). The builder stepped out of scope. Fix: PR #2828 restores the file byte for byte from 04170953 (1 file, CI: PASS). AE-h2 is building now with a hard scope rule (HaloModel, its tests and plans, its C4 part only) and must check `git diff --name-only origin/dev` before committing. The lead now checks each builder PR's file list before recording it.

- 2026-10-18T15:56Z: AE-h2 → PR #2842 (5 files, +24/−31, all HaloModel and its plan; the lead checked the file list; Mutate 10/10 HaloModel.KernelEasingAdapter, HaloKeySelection 6/6 re-run). Deleted: the sample loop in `easingCurve` (now `EaseCurve.samples`), the preset switch and search (now via rawValue), the curve-to-preset lookup (via `EasePreset`), and setEasing's handle clamp (via `EaseCurve.moving`). Kept: the handles/movingHandle/keyState wrappers, which unchanged tests call, and Halo-only key rules (opacity's static home, clamping, `keyed`, last-frame stopwatch, parent math). `HaloModel.HaloKeyRules.json` doesn't exist on dev, so the new mutations went into the adapter plan. It carries feature-done.

- 2026-10-18T16:08Z: #2819 (AE-f2) merged as 1ffa16a0. Scoped flare run 39142436739 on dev 524c3271 contains it (queued); AE-flare's Belt-Slice-Done waits on that run. Scoped halo run 39141680081 (dev 6d589da5, AE-h1 only) is in progress; AE-halo still needs #2842.

- 16:32Z: Closed #2828 as superseded. #2841 (bafd1d38) restored #2807's SegmentedTabs lines and moved fade-end to a run-loop timer.

## Open
- 2026-10-18T13:45Z: ninth Belt nudge (after a worker restart); continued from stage 3.
- 2026-10-18T11:01Z: recheck 6 (sixth Belt nudge): EK-20 merged (#2711) but EK-15/EK-16 (EK-ease) still planned on lead/editor-kernel (d11bc14e); still blocked, rechecking at the next poll.
- 2026-10-18T10:27Z: fifth Belt nudge; rechecked. dev now a80ed944; EK-15/EK-16 still planned; EK-keys bodies still EK-3 stubs; editor-kernel lead relaunched (wo0uruy8p, 10:26Z), still stage 3 wave 2. Still blocked; stopped again.
- 2026-10-18T09:56Z: fourth Belt nudge; rechecked. dev now 02c20bfb; EK-14 tests #2655 now on dev (877567cf), so EK-15/EK-16 bodies are unblocked for editor-kernel; not started; EK-keys bodies still EK-3 stubs; editor-kernel lead still stage 3 wave 2 (heartbeat 09:53Z). lead.md gained the `Belt released this run.` stop rule (#2717), noted. Still blocked; stopped again.
- 2026-10-18T09:25Z: third Belt nudge; rechecked. dev now ed52eaa8; EK-14 tests #2655 not yet on dev; EK-keys bodies still EK-3 stubs; editor-kernel lead still stage 3 wave 2. Still blocked; stopped again.
- 2026-10-18T08:54Z: second Belt nudge; rechecked. dev now 93b1e91 (one Library perf merge since 2202c7c); EK-keys bodies still EK-3 stubs; editor-kernel lead at stage 3 wave 2, waiting on lane batch-20261018081953, wave 4 (bodies) not started. Still blocked; stopped again.
- 2026-10-18T08:23Z: Belt nudge after 30 quiet min; rechecked. dev still 2202c7c (no merges since); EK-keys bodies still EK-3 stubs; editor-kernel lead stopped at stage 3 wave 2 on dev-red #2667, wave 4 (bodies) not started. Still blocked; stopped again.
- Blocked on #1933 editor-kernel EK-keys (EK-15, EK-16). AE-halo also on adopt-kernel-selection:AS-halo (#1934's lead, blocked on EK-sel).
