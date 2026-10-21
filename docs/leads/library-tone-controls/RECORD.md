# tone-controls (Library) lead record

Issue: #3475 · Packet: docs/blueprints/library/features/tone-controls.md
Run: act-1a15df37b73-k199 · Session: claude/library-line-lead-lqhhp8 (earlier act-1a15b98bc49-4lk9 on claude/task-k1zaw1) · Started: 2026-10-20T23:00Z (earlier run act-1a15b10caae-y18c on claude/lead-raw-tone-controls-ca9b2k)
Stage: 0 setup (blocked at 0.4; re-checked at dev e2b8aa76, 2026-10-21T10:18Z)
Base: 9781100bc432e119320c1bbbff41849ff4aeebdb (origin/dev; brief named main b3011ab9, see Decisions)
Next: wait for suiteui tone-controls TC-a (#3476; ToneSettings/ToneRules/ToneRows) to merge, then start LT-1/LT-2

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| LT-a | tone settings in the develop model, the contract | LT-1, LT-2 | - | suiteui tone-controls:TC-a (develop, crop built) | no | 0 | blocked | - | - |
| LT-u | see packet | LT-6, LT-7 | - | LT-a, suiteui tone-controls:TC-3 | yes | 0 | blocked | - | - |
| LT-m | see packet | LT-3, LT-4, LT-5 | - | LT-a, TC-5, suite-imaging:IM-library (LT-4), TC-6 and cull-finish:DR-m (LT-5) | yes | 0 | blocked | - | - |
| LT-z | finish | LT-8, LT-9 | - | LT-u, LT-m | yes | 0 | blocked | - | - |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| LT-1 | LT-a | - | see tone-controls.wave.json | - | - | - | blocked |
| LT-2 | LT-a | - | see tone-controls.wave.json | - | - | - | blocked |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- Record branch is lead/library-tone-controls, not lead/tone-controls: that branch holds the live suiteui tone-controls lead's record (#3476, run act-1a15821c836-93pf) and pushing there would clobber it.
- Base is dev, not main: the packet exists only on dev, and PRs target dev.
- Run act-1a15b98bc49-4lk9 keeps this record branch: Belt's nudge names lead/tone-controls, but that is the suiteui lead's live record (see above).
- Stage 0.4: no task can start. LT-1 needs ToneSettings/ToneRules/ToneRows from suiteui TC-a, absent from Sources; per #3476's record TC-a itself waits on gradient-fill GF-2 (and AH-a, PL-a).

- Run act-1a15df37b73-k199: the brief says to rebase lead/tone-controls onto origin/main with --force-with-lease. Not done: that branch is the suiteui tone-controls lead's record (#3476), it shares no merge base with main and carries 1,739 non-record commits, so a rebase rewrites another lead's live history. This record stays on lead/library-tone-controls. Raised as a question below.

## Open
- Blocked on suiteui tone-controls TC-a/TC-3/TC-5/TC-6, suite-imaging IM-library, library cull-finish DR-m (all planned).
- #3476 (suiteui tone-controls) is labelled needs-human and waiting-on-prereq; no TC-a PR is open and SuiteKernel has no tone files on dev e2b8aa76.
- Question for the supervisor, posted on #3475 at 11:30Z (issuecomment-6314752314): keep polling or park #3475 until #3476 moves; is the lead/tone-controls rebase still wanted? Waiting on the answer.
- Re-checked on dev ded2ca57 at 11:30Z: still no TC-a, and #3476 is waiting-on-prereq (needs-human is gone).
