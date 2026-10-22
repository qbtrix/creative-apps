# history-panel lead record

Issue: #3437 · Packet: docs/blueprints/photo/features/history-panel.md
Run: act-1a1627ce472-14rw (relaunch 07:20Z); before: act-1a15fc7d29e-gz1t (line lead with #3471 file-flow) · Session: claude/history-panel-file-flow-liwkxm · Started: 2026-10-21T18:30Z
Earlier run: act-1a15ac118a1-s70v (PH-a, PH-u done)
Stage: done
Base: origin/dev 9f1b3d5
Next: beta-hardening lane verifies PH-a, PH-u, PH-m, PH-z (Belt-Contact-Sheet posted 07:26Z)
Record: docs/leads/photo-history-panel/RECORD.md on lead/photo-history-panel (lead/history-panel holds the copy before 20:05Z)

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| PH-a | stubs + History tab, Window > History | PH-1, PH-2 | written, skipped | – | true | – | done | – | Mac-Finish: PH-a 2d6ff1f |
| PH-u | tab follows the listing; snapshots, render budget | PH-3, PH-4 | – | – | true | – | done | – | – |
| PH-m | jump body + catalog; autosave on RecoveryFolder | PH-5, PH-6 | – | transform:PT-m (built, #4136) | true | 0 | done | [39722915670](https://github.com/qbtrix/creative-apps/actions/runs/39722915670) | wanted |
| PH-z | journeys on live, feature-done | PH-7, PH-8 | PhotoJourneyTests+History | PH-m | true | 0 | done per brief (ae7bce19; first in queued scoped photo 39740271644) | – | – |

## Tasks
| id | slice | behavior | PR | state |
|---|---|---|---|---|
| PH-1, PH-2 | PH-a | stubs, tab, menu | #3708 | merged |
| PH-3, PH-4 | PH-u | listing, snapshots, budget | #3762, #3818 | merged (mac fixes #3979, #4111) |
| PH-5 | PH-m | jump body, catalog specs (additive), PhotoHistoryJumpTests on, plan PhotoModel.PhotoHistory+Kernel | #4162 | merged 03:29Z as 4c6ad5ed |
| PH-6 | PH-m | autosave on RecoveryFolder | #4160 | merged 8c75b620 |
| PH-7 | PH-z | journeys on live | #4271 | merged ae7bce19 |
| PH-8 | PH-z | status built, feature-done | #4271 | merged ae7bce19 |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- Base and PR target are origin/dev (brief's main HEAD 0dd23d6 verified; packets live on dev).
- Old combined wave plan (eyedropper, transform) is retired: this run leads history-panel with Photo file-flow only.
- transform:PT-m wait treated as met: transform is status built (#4136); PT-6 (#4131) still open, so PH-5's catalog and command-id edits stay additive (append only), as the supervisor allowed for PF-3.
- autosave-history AH-m/AH-z treated as met (AH-8 #3629 merged; Design and Halo adopted).
- PH-m ships as two PRs (PH-6, PH-5): combined they pass ~500 lines.
- PR bodies: the session's GitHub proxy appends an attribution footer to PR bodies and comments; commits are clean and the lane strips it from squash commits. Asked the supervisor.
- #4162 held: dev is red on CommandPathTests.appMatchesItsBaseline(launcher), a stale launcher.txt line after #4049. Not fixed in our PR (CLAUDE.md); the merge 7a991bd is ready in scratchpad fix-4162 and gets pushed when dev is green.
- PH-m done on scoped photo run 39722915670 (success, head 71987f72, contains 4c6ad5ed and 8c75b620); Belt-Slice-Done + Mac-Finish-Wanted posted 07:24Z. PH-z treated as done per the relaunch brief; no slice line posted for it. Belt-Contact-Sheet posted 07:26Z. Journeys green in journeys photo 39712355440 (add701fc); 39739396461 at 71987f72 pending. No open finding on this feature, so no critic round was queued.
