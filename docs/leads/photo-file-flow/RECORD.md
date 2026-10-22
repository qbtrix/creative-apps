# photo file-flow lead record

Issue: #3471 · Packet: docs/blueprints/photo/features/file-flow.md
Run: act-1a1627ce472-14rw (relaunch 07:20Z); before: act-1a15fc7d29e-gz1t (line lead with #3437 history-panel) · Session: claude/history-panel-file-flow-liwkxm · Started: 2026-10-21T18:30Z
Earlier run: act-1a15a9f4eba-h30y (PF-1, PF-3, PF-4 merged)
Stage: done
Base: origin/dev 9f1b3d5
Next: beta-hardening lane verifies PF-a, PF-u, PF-m, PF-z (Belt-Contact-Sheet posted 07:26Z); PF-8 still waits export-pack:PX-z

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| PF-a | .suiteApp scene, suite Open Recent / Open In, drop | PF-1, PF-2 | MPF | place-image:PP-u (built, #4139) | yes | 0 | done | [39722915670](https://github.com/qbtrix/creative-apps/actions/runs/39722915670) | wanted |
| PF-u | menu and drop mark snapshots, render budget, journey written | PF-5, PF-6 | PFJ1 | PF-a | yes | 0 | done | [39722915670](https://github.com/qbtrix/creative-apps/actions/runs/39722915670) | wanted |
| PF-m | open/new/place hand-offs, recents import, opens and saves noted | PF-3, PF-4 | MPF | – | yes | 0 | done | [39566690076](https://github.com/qbtrix/creative-apps/actions/runs/39566690076) | wanted |
| PF-z | live drop, Open Recent, Open In; journey; built | PF-7, PF-8 | PFJ1 | PF-u, PF-m; export-pack:PX-z (PF-8, planned) | yes | 0 | done per brief (PF-7 57685d8b; PF-8 waits PX-z) | – | – |

## Tasks
| id | slice | behavior | PR | state |
|---|---|---|---|---|
| PF-1 | PF-a | adapter stubs | #3679 | merged |
| PF-2 | PF-a | .suiteApp, SuiteFileCommands + Open In, .suiteFileDrop (reconcile with PP-3's canvas drop → place.image) | #4164 | merged f2953daf |
| PF-3 | PF-m | adapter bodies, catalog specs, recents import | #3815 | merged 709f928 (RJ-P42 pending gap #3741) |
| PF-4 | PF-m | window notes opens and saves | #3700 | merged 7ec53b5 |
| PF-5 | PF-u | snapshots, RenderBudgetPhotoFileDropTests.dragHoverInTwoBodies ≤ 2 | #4165 | merged add701fc |
| PF-6 | PF-u | UITests/PhotoJourneyTests+FileFlow.swift, XCTSkip("waits on PF-7") | #4165 | merged add701fc |
| PF-7 | PF-z | journey on live | #4267 | merged 57685d8b |
| F-4260 | PF-m | PhotoDocumentHost + PhotoAppDelegate as SuiteAppDelegate (finding #4260) | #4307 | merged b2794c20 |
| PF-8 | PF-z | photo.md, status built, feature-done | – | waits PX-z |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|
| PF-m | 39566690076 | 260f7a8 | – (merged before this run) | 0 | 0 |

## Decisions
- Record stays on lead/photo-file-flow: lead/file-flow belongs to the Suite file-flow feature (#3480).
- Base and PR target are origin/dev (packets live on dev; the lane retargets main PRs). Brief's main HEAD 0dd23d6 verified.
- PF-m marked done on run 39566690076 (scoped photo, success, head 260f7a8, contains #3815 and #3700). Posted Belt-Slice-Done and Mac-Finish-Wanted.
- PF-2's place-image:PP-u wait is met (place-image status built, #4139).
- PR bodies: the session's GitHub proxy appends an attribution footer to PR bodies and comments; commits are clean and the lane strips it from squash commits. Asked the supervisor.
- PF-a and PF-u done on scoped photo run 39722915670 (success, head 71987f72, contains f2953daf and add701fc); Belt-Slice-Done + Mac-Finish-Wanted posted 07:24Z. PF-z treated as done per the relaunch brief; no slice line posted for it. Belt-Contact-Sheet posted 07:26Z. Journey green in journeys photo 39712355440 (add701fc). No open finding on this feature.
