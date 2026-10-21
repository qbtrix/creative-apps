# key-select-all (Flare) lead record

Issue: #3538 · Packet: docs/blueprints/flare/features/key-select-all.md
Run: act-1a15cf358c6-wj2q · Session: claude/feature-lead-playbook-lw6pjl · Started: 2026-10-21T05:39:29Z (line lead: stroke-style #3452, shape-tools #3451, key-select-all #3538)
Stage: 3 (wave 1)
Base: 71ffa4d1 (origin/dev); main 0dd23d65 verified
Next: the KS-a slice PR (KS-1 + KS-2) once its builder hands back CI: PASS and the mutate score

Loop: v3 (the packet has a `## Slices` table).

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| KS-a | Select All Keys selects every key of the edited owner's layers, from the timeline menu and from ⌘A while the timeline has focus | KS-1, KS-2 | MJ-KS | AC-flare (met: Belt-Slice-Done on #2999, 04:24Z); suiteui TSA-a (met: built, TimelineStrip+Keys on dev) | yes | 0 | building | | |
| KS-z | journey, snapshots, render budget; built | KS-3, KS-4 | J-KS | KS-a; PR #3499 (KS-4) | yes | 0 | waiting | | |

## Tasks
| id | slice | wave | PR | state |
|---|---|---|---|---|
| KS-1 | KS-a | 1 | | building on flare/ks-a-select-all-keys |
| KS-2 | KS-a | 1 | | building on flare/ks-a-select-all-keys |
| KS-3 | KS-z | 2 | | waits KS-a |
| KS-4 | KS-z | 3 | | waits KS-3, #3499 (open, no lane label) |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- Lead branch is the packet's lead/key-select-all (free; SuiteUI's is lead/timeline-select-all).
- Base and PR target are dev (CLAUDE.md), though the brief names main.
- KS-a goes first in the line: gradient-fill's FG-m waits on it, and FS-6 and FK-6 wait on FG-m (the catalog chain).
- One PR for KS-a (KS-1 + KS-2), its first commit the failing tests.

## Open
- Comments posted from this session get a server-appended attribution footer that an edit can't remove.
