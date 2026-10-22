# tone-controls (Library) lead record

Issue: #4516 (earlier #3475) · Packet: docs/blueprints/library/features/tone-controls.md
Run: act-1a16474bd12-7ncx · Session: claude/feature-lead-playbook-2mbx2f · Started: 2026-10-22T16:30Z (earlier act-1a15df37b73-k199)
Stage: 0 setup (blocked at 0.4, re-checked at dev 7e9f260a, 2026-10-22T16:50Z)
Base: origin/dev 7e9f260ae8f69dea63663c1bc7ea945c6b1d2f80
Next: start LT-1/LT-2 when suiteui tone-controls TC-a (#4520: TC-1 building, no PR open yet; TC-2 after) is on dev

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
- Parked on the supervisor's answer, 2026-10-21T11:29Z. Resume at Stage 0 once #3475 loses waiting-on-prereq.
- Record branch is lead/library-tone-controls, not lead/tone-controls: that branch holds the live suiteui tone-controls lead's record (#3476, run act-1a15821c836-93pf) and pushing there would clobber it.
- Base is dev, not main: the packet exists only on dev, and PRs target dev.
- Run act-1a15b98bc49-4lk9 keeps this record branch: Belt's nudge names lead/tone-controls, but that is the suiteui lead's live record (see above).
- Stage 0.4: no task can start. LT-1 needs ToneSettings/ToneRules/ToneRows from suiteui TC-a, absent from Sources; per #3476's record TC-a itself waits on gradient-fill GF-2 (and AH-a, PL-a).

- Run act-1a15df37b73-k199: the brief says to rebase lead/tone-controls onto origin/main with --force-with-lease. Not done: that branch is the suiteui tone-controls lead's record (#3476), it shares no merge base with main and carries 1,739 non-record commits, so a rebase rewrites another lead's live history. This record stays on lead/library-tone-controls. Raised as a question below.

## Open
- 2026-10-22T16:50Z (run act-1a16474bd12-7ncx, #4516): rule 23 re-read. TC-a is still unmerged: #4520 record says TC-1 is building, and no open PR carries Feature: tone-controls. Sources/SuiteImaging/Tone/ is absent on dev. LT-a stays blocked. 0 open findings.
- Parked by the supervisor (#3475, 11:29Z): LT-a waits on suiteui TC-a (#3476), and TC-a waits on suite-imaging IM-a and autosave-history AH-a. #3475 is labelled waiting-on-prereq; the supervisor removes the label once TC-a is on dev. This run is released from tone-controls and polls it no more.
- No rebase of lead/tone-controls. The supervisor confirmed it is the suiteui lead's record; this lead's record is on lead/library-tone-controls.
