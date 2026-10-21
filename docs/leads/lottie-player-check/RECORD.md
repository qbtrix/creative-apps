# lottie-player-check (Flare) lead record

Issue: #3792 · Packet: docs/blueprints/flare/features/lottie-player-check.md
Run: act-1a15e10a86f-7bk9 · Session: claude/feature-lead-playbook-yf71p7 · Started: 2026-10-21T10:50Z
Stage: 3 wave 1
Base: 11919406886e89e9e02adea13b113b66e852334d
Next: (2026-10-21T19:48Z) #4132 still waits on the supervisor's macOS run and hand merge (answered 17:11Z); LP-6 ready on its branch.

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| LP-a | oracle build script; parity suite (skips without the oracle) | LP-1, LP-2 | MJ-LP | – | no | 0 | done: run 39620526621 (Linux green at 3f96cd10) | #4025, #4026 | merged |
| LP-m | FrameParity rules in FlareModel; colour-key and trim fixtures | LP-3, LP-5 | MJ-LP | LP-a | no | 0 | PR open (13adaba0 after dev merge, Mutate 4/4); lane macOS build 15:25Z | #4033 | – |
| LP-z | CI builds the oracle (supervisor merge); RJ-F11 on; built (feature-done) | LP-4, LP-6 | MJ-LP | LP-a, LP-m | no | 0 | building | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| LP-1 | LP-a | 1 | scripts/lottie-oracle build + render | scripts/lottie-oracle/{build,render.c,VERSION,README} | build on a Mac; one-rect render | #4025 (5131fb58) | open, no-fast-lane, supervisor merge asked |
| LP-2 | LP-a | 1 | LottiePlayerParityTests + fixtures | Tests/AppSnapshotTests/LottiePlayerParityTests.swift, Tests/AppSnapshotTests/Fixtures/Lottie/* | skips without oracle | #4026 (a02110c4) | open, fast-lane |
| LP-3 | LP-m | 2 | FrameParity pure rules | Sources/FlareModel/FrameParity.swift, Tests/FlareModelTests/FrameParityTests.swift, Tests/mutations/FlareModel.FrameParity.json | FrameParityTests | #4033 | PR open |
| LP-5 | LP-m | 2 | colour-key, trim fixtures skipped | Tests/AppSnapshotTests/Fixtures/Lottie/{colour-key,trim}.flare | rows skip by name | #4033 | PR open |
| LP-4 | LP-z | 3 | ci.yml oracle cache + RJ-F11 | .github/workflows/ci.yml, jobs.json | macOS job runs suite unskipped | – | #4132 (supervisor merge) |
| LP-6 | LP-z | 4 | status built (feature-done) | lottie-player-check.wave.json | waves render | – | waiting |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- LP-1 pins ThorVG v1.1.2 (b004a778, MIT): v1.1.3 was under two weeks old.
- The server re-appends a Claude Code footer to PR and issue bodies written from this session; removing it with PATCH doesn't stick. Recorded, not fought.
- PRs target `dev` (CLAUDE.md, lead.md rule 4), not main.
- LP-a ships as two PRs: LP-2 through the fast lane, and LP-1 (`scripts/`, protected; the packet names the path) as a `no-fast-lane` PR for the supervisor to merge, with a question on #3792. LP-2 skips by name until the oracle is built, so it doesn't wait on LP-1.

- LP-3 ships loopIsClean(first:last:width:height:) (rule: last frame must not equal frame 0) instead of the sketch's (first:last:next:); every rule takes the frame size so 2% is over w*h.
- FrameParity is new in FlareModel: the only pixel tolerance (GoldenTolerance/GoldenImage) is macOS-only in SuiteUI/AppSnapshotTests (rule 20 search).

## Open
- 2026-10-21T18:42:09Z: LP-6 branch pushed (5cec7e97), PR held until #4132 merges. #4132 Linux green on 82c169e1.
- #4025 (LP-1) merged 13:08Z. #4132 (LP-4) waits on a supervisor merge; question on #3792 (issuecomment-6321827355). Linux build and one-rect render verified; Mac build comes with LP-4.
- LP-1 and LP-4 need a supervisor merge (protected paths).
