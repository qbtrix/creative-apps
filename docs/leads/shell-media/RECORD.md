# shell-media lead record

Issue: #3711 · Packet: docs/blueprints/suite/features/shell-media.md
Run: act-1a15e10aa98-lun9 · Session: https://claude.ai/code/session_01TyRi6dgCqqVCYgH3sXdspa · Started: 2026-10-21T10:50Z
Stage: 0 setup
Base: 11919406886e89e9e02adea13b113b66e852334d
Next: stage 1, read the packet and the code it touches, then plan wave 1 with the line's other features

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| SM-a | Callers code against MediaEncoding, MediaDecoding, the media values and FakeMedia through SuiteServices.media; Linux checks and macOS live checks written and disabled | SM-1, SM-2 | MJ-SM0 | - | no | 0 | planned | | |
| SM-m | Settings refuse what each codec can't write; FrameClock gives exact times and drift-free GIF delays | SM-3, SM-4 | MJ-SM1 | SM-a | no | 0 | planned | | |
| SM-w | On a Mac, movies write in four codecs, GIF/APNG and stills encode, cancel deletes | SM-5, SM-6 | MJ-SM2 | SM-a | no | 0 | planned | | |
| SM-r | On a Mac, stills decode upright to 8-bit sRGB, movie info and frames read back | SM-7, SM-8 | MJ-SM3 | SM-a, SM-w (SM-8) | no | 0 | planned | | |
| SM-z | Slot live, write/read walk on the Mac, shared prose, feature built | SM-9, SM-10 | MJ-SM4 | SM-m, SM-w, SM-r | no | 0 | planned | | |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- Base is origin/dev, not main: the brief names main (0dd23d6, verified) but CLAUDE.md and lead.md target dev, and report-problem and command-state packets exist only on dev. PRs go to base dev.
- One line lead plan across shell-media, report-problem and command-state (rule 19).
- Every slice is ui:false (ui_slice none): no critic panel with screens; Model walks prove SM-a/SM-m on Linux.

## Open
- none
