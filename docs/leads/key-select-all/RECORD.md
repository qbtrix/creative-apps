# key-select-all (Flare) lead record

Issue: #3538 · Packet: docs/blueprints/flare/features/key-select-all.md
Run: act-1a15cf358c6-wj2q · Session: claude/feature-lead-playbook-lw6pjl · Started: 2026-10-21T05:39:29Z (line lead: stroke-style #3452, shape-tools #3451, key-select-all #3538)
Stage: 3 (wave 1)
Base: 0865916d (origin/dev); main 0dd23d65 verified
Next: KS-a merged 11:14Z as 80ac6639 (#3921, batch landed on own proof while dev red). Waiting for a dev CI run whose Linux job contains 80ac6639 and is green (dev Linux red on photo CommandPathTests, #3976), then Belt-Slice-Done KS-a on #3538 and critics once a scoped flare run shows its screens. KS-z waits on #3499. Branch is lead/key-select-all, not lead/flare-key-select-all

Loop: v3 (the packet has a `## Slices` table).

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| KS-a | Select All Keys selects every key of the edited owner's layers, from the timeline menu and from ⌘A while the timeline has focus | KS-1, KS-2 | MJ-KS | AC-flare (met: Belt-Slice-Done on #2999, 04:24Z); suiteui TSA-a (met: built, TimelineStrip+Keys on dev) | yes | 0 | merged 80ac6639 (#3921), awaiting green dev Linux | | |
| KS-z | journey, snapshots, render budget; built | KS-3, KS-4 | J-KS | KS-a; PR #3499 (KS-4) | yes | 0 | waiting | | |

## Tasks
| id | slice | wave | PR | state |
|---|---|---|---|---|
| KS-1 | KS-a | 1 | #3921 | merged #3921 (80ac6639), Mutate 4/4 |
| KS-2 | KS-a | 1 | #3921 | merged #3921 |
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
- 2026-10-21T13:09Z: resumed on Belt's 30-min nudge (it named lead/flare-key-select-all; this feature's branch is lead/key-select-all). KS-a (#3921, 80ac6639) is not slice-done: every dev Linux check containing it is red on dev's own failures (photo CommandPathTests; library timing budgets LibraryFoldersTests.tenThousandPaths, LargeCatalogBudgetTests), latest 73754132 run 39601343733; 5bec8089 run 39604117821 running; full CI 39600323802 pending. Critics wait for a scoped flare or full run with screens. KS-z waits #3499 (open).
- #3921 view code (⌘A routing in FlareCommands) is unverified until the lane's macOS build and the journey.
- Comments posted from this session get a server-appended attribution footer that an edit can't remove.
