# shared-raw lead record

Issue: #4508 · Packet: docs/blueprints/suiteui/features/shared-raw.md
Run: act-1a16474bd3a-i9ae · Session: session_01Rid1ErRRerebigzwJKJtpV · Started: 2026-10-22T16:36Z
Stage: 3 (wave 1)
Base: 7e9f260ae8f69dea63663c1bc7ea945c6b1d2f80 (origin/dev)
Next: open the SR-1 PR when its builder pushes lead/shared-raw-SR-1; then SR-2 stacked on it (its first commit adds RawFormatTests, RawDecodePlanTests, RawHeadroomTests, disabled)

## Slices

| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| SR-a | test DNGs written in-repo; Raw/ module as stubs over a fake decoder; tests disabled | SR-1, SR-2 | MJ-SR | suite-imaging:IM-a (built: #4028) | false | 0 | building | – | – |
| SR-m | formats parse, plan, refusals, system decoder with headroom | SR-3, SR-4 | MJ-SR, MJ-SR-mac | SR-a; IM-4 (merged #4393) | false | 0 | planned | – | – |
| SR-photo | Photo opens RAW as a float layer | SR-5, SR-6 | MJ-SR-photo, PJ-SR | SR-a; shared-codecs SC-15, SC-4 (SR-6; not merged) | true | 0 | planned | – | – |
| SR-z | live, RJ-X50, concept line, built | SR-7, SR-8 | PJ-SR, MJ-SR | SR-m, SR-photo; tone-controls:TC-a, pen-paths:PN-a (SR-8) | true | 0 | planned | – | – |

## Tasks

| id | slice | wave | state | PR |
|---|---|---|---|---|
| SR-1 | SR-a | 1 | building | – |
| SR-2 | SR-a | 2 | planned | – |
| SR-3 | SR-m | 3 | planned | – |
| SR-4 | SR-m | 3 | planned | – |
| SR-5 | SR-photo | 3 | planned | – |
| SR-6 | SR-photo | – | blocked (SC-15, SC-4) | – |
| SR-7 | SR-z | – | planned | – |
| SR-8 | SR-z | – | blocked (TC-a) | – |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- Base is origin/dev, PRs target dev (CLAUDE.md: never target main).
- SR-a is ~700 lines (SR-1 ~400, SR-2 ~300): over the 400-line cap, so it ships as two PRs, SR-1 first (the test commit), SR-2 stacked on it.
- Slice branches are lead/shared-raw-<slice>.
- SR-1 carries only the fixtures, writers and TinyDNGTests: the three Raw*Tests reference SR-2's types and can't compile before them, so they are SR-2's first commit (rule 22, test first in the slice PR).
- SR-1 builder relaunched after a container restart (first attempt lost before any commit).
- Belt reads lead/suiteui-shared-raw (docs/leads/suiteui-shared-raw/); each push mirrors the RECORD and timeline there as well.

## Open
- SR-6 waits on shared-codecs SC-15 and SC-4 (no commits on dev); SR-8 waits on tone-controls TC-a.
