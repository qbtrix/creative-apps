# command-state lead record

Issue: #3771 · Packet: docs/blueprints/suite/features/command-state.md
Run: act-1a15e10aa98-lun9 · Session: https://claude.ai/code/session_01TyRi6dgCqqVCYgH3sXdspa · Started: 2026-10-21T10:50Z
Stage: 0 setup
Base: 11919406886e89e9e02adea13b113b66e852334d
Next: stage 1, read the packet and the code it touches, then plan wave 1 with the line's other features

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

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- Base is origin/dev, not main: this packet exists only on dev; PRs go to base dev.

## Open
- none
