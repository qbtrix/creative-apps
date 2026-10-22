# photo file-flow lead record

Issue: #3471 · Packet: docs/blueprints/photo/features/file-flow.md
Run: act-1a15fc7d29e-gz1t (line lead with #3437 history-panel) · Session: claude/history-panel-file-flow-liwkxm · Started: 2026-10-21T18:30Z
Earlier run: act-1a15a9f4eba-h30y (PF-1, PF-3, PF-4 merged)
Stage: 3 wave A
Base: origin/dev 1b3913c
Next: #4165 (PF-u) merged add701fc; scoped photo run 39700970657 at add701fc (queued) proves PF-a and PF-u; PF-7 #4267 open (fast-lane, head 5d8cb7ef, ci --changed PASS); PF-8 waits export-pack:PX-z

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| PF-a | .suiteApp scene, suite Open Recent / Open In, drop | PF-1, PF-2 | MPF | place-image:PP-u (built, #4139) | yes | 0 | merged (#4164 f2953daf), waits scoped photo run | – | – |
| PF-u | menu and drop mark snapshots, render budget, journey written | PF-5, PF-6 | PFJ1 | PF-a | yes | 0 | merged add701fc; waits scoped photo run 39700970657 | – | – |
| PF-m | open/new/place hand-offs, recents import, opens and saves noted | PF-3, PF-4 | MPF | – | yes | 0 | done | [39566690076](https://github.com/qbtrix/creative-apps/actions/runs/39566690076) | wanted |
| PF-z | live drop, Open Recent, Open In; journey; built | PF-7, PF-8 | PFJ1 | PF-u, PF-m; export-pack:PX-z (PF-8, planned) | yes | 0 | waiting | – | – |

## Tasks
| id | slice | behavior | PR | state |
|---|---|---|---|---|
| PF-1 | PF-a | adapter stubs | #3679 | merged |
| PF-2 | PF-a | .suiteApp, SuiteFileCommands + Open In, .suiteFileDrop (reconcile with PP-3's canvas drop → place.image) | #4164 | merged f2953daf |
| PF-3 | PF-m | adapter bodies, catalog specs, recents import | #3815 | merged 709f928 (RJ-P42 pending gap #3741) |
| PF-4 | PF-m | window notes opens and saves | #3700 | merged 7ec53b5 |
| PF-5 | PF-u | snapshots, RenderBudgetPhotoFileDropTests.dragHoverInTwoBodies ≤ 2 | #4165 | in lane (fef845ec) |
| PF-6 | PF-u | UITests/PhotoJourneyTests+FileFlow.swift, XCTSkip("waits on PF-7") | #4165 | in lane (fef845ec) |
| PF-7 | PF-z | journey on live | #4267 | open at 9583c10a, fast-lane (Journey+FileDrag.swift drop source, drop steps on) |
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
