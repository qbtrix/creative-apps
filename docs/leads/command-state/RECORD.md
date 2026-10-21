# command-state lead record

Issue: #3771 · Packet: docs/blueprints/suite/features/command-state.md
Run: act-1a15e10aa98-lun9 · Session: https://claude.ai/code/session_01TyRi6dgCqqVCYgH3sXdspa · Started: 2026-10-21T10:50Z
Stage: 3 build, wave 1
Base: 11919406886e89e9e02adea13b113b66e852334d
Next: wave 1 builders running; then mark stacked drafts ready after their parents merge, critics on merge

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| CS-a | ControlEntry.selected reported by SuiteUI toggles; command-path max limits | CS-1, CS-2 | see packet | - | yes | 0 | planned | | |
| CS-library-1 | Library catalog + wiring (part 1) | CS-3, CS-4 | see packet | CS-a (CS-3) | yes | 0 | planned | | |
| CS-library-2 | Library catalog + wiring (part 2) | CS-5, CS-6 | see packet | CS-a, CS-library-1 (CS-5) | yes | 0 | planned | | |
| CS-halo | Halo catalog + wiring | CS-7, CS-8 | see packet | CS-a (CS-7) | yes | 0 | planned | | |
| CS-photo | Photo catalog + wiring | CS-9, CS-10 | see packet | CS-a (CS-9) | yes | 0 | planned | | |
| CS-flare | Flare catalog + wiring | CS-11, CS-12 | see packet | CS-a (CS-11) | yes | 0 | planned | | |
| CS-design | Design catalog + wiring | CS-13, CS-14 | see packet | CS-a (CS-13) | yes | 0 | planned | | |
| CS-z | RJ-X61 job + journey on; feature-done | CS-15, CS-16 | see packet | all app slices (CS-15) | no | 0 | planned | | |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| CS-1 | CS-a | 1 | ControlEntry.selected, reported by InspectorAction, toggles, SegmentedTabs, KeyframeButton | packet CS-1 (7 files) | ControlStateTests | – | building |
| CS-2 | CS-a | 1 | baseline `# max: N` caps, dismiss rule, shell + launcher scans | packet CS-2 (10 files) | CommandPathLimitTests, CommandPathTests; Mutate SuiteKernelTests.CommandPathTests | – | building |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- Baseline: `scripts/ci --changed` on dev 1191940 printed CI: PASS (Linux build 232 s, 4m13s total) before wave 1.
- CS-a is two independent PRs, CS-1 and CS-2: together they touch 17 files (cap 15). CS-2's launcher.txt baseline is taken at today's counts; RP-2 (report-problem) adds launcher Help items built from specs, so whichever lands second rebaselines launcher.txt.
- Base is origin/dev, not main: this packet exists only on dev; PRs go to base dev.

## Open
- none
