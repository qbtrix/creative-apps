# report-problem lead record

Issue: #3772 · Packet: docs/blueprints/suite/features/report-problem.md
Run: act-1a15e10aa98-lun9 · Session: https://claude.ai/code/session_01TyRi6dgCqqVCYgH3sXdspa · Started: 2026-10-21T10:50Z
Stage: 0 setup
Base: 11919406886e89e9e02adea13b113b66e852334d
Next: stage 1, read the packet and the code it touches, then plan wave 1 with the line's other features

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| RP-a | Contract stubs and disabled checks; Help group in the launcher | RP-1, RP-2 | see packet | - | yes | 0 | planned | | |
| RP-u | SuiteUI ProblemReportSheet and BetaNotesView on the stubs; compose-email and Save | RP-3, RP-3e | see packet | RP-a (RP-3) | yes | 0 | planned | | |
| RP-m | Report bodies (redaction, suite filter, 7 days, newest 3), help catalog + CLI, C4, feature-done | RP-4, RP-5, RP-6, RP-7 | see packet | RP-a (RP-4, RP-5), RP-u (RP-6) | no | 0 | planned | | |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- Base is origin/dev, not main: this packet exists only on dev; PRs go to base dev.
- The issue body names an RP-z slice; the packet and .wave.json have RP-a, RP-u, RP-m only (RP-7 feature-done sits in RP-m). Following the packet.

## Open
- none
