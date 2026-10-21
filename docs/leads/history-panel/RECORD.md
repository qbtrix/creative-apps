# history-panel lead record

Issue: #3437 · Packet: docs/blueprints/photo/features/history-panel.md
Run: act-1a15fc7d29e-gz1t (line lead with #3471 file-flow) · Session: claude/history-panel-file-flow-liwkxm · Started: 2026-10-21T18:30Z
Earlier run: act-1a15ac118a1-s70v (PH-a, PH-u done)
Stage: 3 wave A
Base: origin/dev 1b3913c
Next: PH-6 (revive lead/history-panel-PH-6) and PH-5 builders in parallel (PH-m); then PH-7, PH-8 (PH-z)

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| PH-a | stubs + History tab, Window > History | PH-1, PH-2 | written, skipped | – | true | – | done | – | Mac-Finish: PH-a 2d6ff1f |
| PH-u | tab follows the listing; snapshots, render budget | PH-3, PH-4 | – | – | true | – | done | – | – |
| PH-m | jump body + catalog; autosave on RecoveryFolder | PH-5, PH-6 | – | transform:PT-m (built, #4136) | true | 0 | building | – | – |
| PH-z | journeys on live, feature-done | PH-7, PH-8 | PhotoJourneyTests+History | PH-m | true | 0 | waiting | – | – |

## Tasks
| id | slice | behavior | PR | state |
|---|---|---|---|---|
| PH-1, PH-2 | PH-a | stubs, tab, menu | #3708 | merged |
| PH-3, PH-4 | PH-u | listing, snapshots, budget | #3762, #3818 | merged (mac fixes #3979, #4111) |
| PH-5 | PH-m | jump body, catalog specs (additive), PhotoHistoryJumpTests on, plan PhotoModel.PhotoHistory+Kernel | – | building |
| PH-6 | PH-m | autosave on RecoveryFolder (branch lead/history-panel-PH-6, 3 commits from 2026-10-20) | – | building (merge dev, regate) |
| PH-7 | PH-z | journeys on live | – | waits PH-m |
| PH-8 | PH-z | status built, feature-done | – | waits PH-7 |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- Base and PR target are origin/dev (brief's main HEAD 0dd23d6 verified; packets live on dev).
- Old combined wave plan (eyedropper, transform) is retired: this run leads history-panel with Photo file-flow only.
- transform:PT-m wait treated as met: transform is status built (#4136); PT-6 (#4131) still open, so PH-5's catalog and command-id edits stay additive (append only), as the supervisor allowed for PF-3.
- autosave-history AH-m/AH-z treated as met (AH-8 #3629 merged; Design and Halo adopted).
- PH-m ships as two PRs (PH-6, PH-5): combined they pass ~500 lines.
