# afterglow-cli lead record

Issue: #2998 · Packet: docs/blueprints/suite/features/afterglow-cli.md
Run: act-1a1514ffe22-lvmw · Session: cloud lead (line:suite, with afterglow-mcp #3000) · Started: 2026-10-18T23:21Z
Stage: 3 wave 1
Base: e0a627c0634a8586785adf4400d401667f5d7215 (origin/dev; brief's main head 349578b86d92793e52559b67e16a57bdfe202577 verified)
Next: get CL-1's PR opened (supervisor merges it: Package.swift, scripts/test-scope); CL-2 waits on command-catalog CC-a (#2996), not started

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| CL-a | targets, executable, stubs, FakeIO, app registry | CL-1, CL-2 | LJ0 | – (CL-2: command-catalog CC-a, cross-line) | false | 0 | building | – | – |
| CL-args | strict single-shot forms, one JSON object, sysexits, no overwrite | CL-3, CL-4, CL-5 | LJ1 | CL-a | false | 0 | waiting | – | – |
| CL-batch | `afterglow run` scripts | CL-6, CL-7 | LJ2 | CL-a | false | 0 | waiting | – | – |
| CL-jobs | real-jobs harness on Linux CI | CL-8, CL-9 | LJ3 | CL-a | false | 0 | waiting | – | – |
| CL-z | spawned binary, docs/cli.md, built | CL-10, CL-11 | LJ4 | every slice above | false | 0 | waiting | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| CL-1 | CL-a | 1 | targets, main.swift, CLI router stub, `--version` live, C4 container + cli-runner | Package.swift, scripts/test-scope, Sources/AfterGlowCLI/main.swift, Sources/AfterGlowCLICore/CLI.swift, Tests/AfterGlowCLITests/CLIShapeTests.swift, docs/c4/parts/creative-apps/afterglow-cli/container.json, docs/c4/parts/creative-apps/afterglow-cli/cli-runner.json | CLIShapeTests (LJ0) | – | building |
| CL-2 | CL-a | 2 | CLIIO/FakeIO, HeadlessApp/Session, Apps, ScriptRunner/RealJobs/MCPServer stubs | Sources/AfterGlowCLICore/{CLIIO,Apps,ScriptRunner,RealJobs}.swift, Sources/AfterGlowCLICore/MCP/MCPServer.swift, Tests/AfterGlowCLITests/CLIStubTests.swift | CLIStubTests | – | blocked on CC-a |
| CL-3 | CL-args | 3 | CLIArgsTests + CLIFileSafetyTests, disabled | Tests/AfterGlowCLITests/CLIArgsTests.swift, CLIFileSafetyTests.swift, Golden/ | exists, disabled | – | waiting |
| CL-6 | CL-batch | 3 | BatchTests + fixtures, disabled | Tests/AfterGlowCLITests/BatchTests.swift, Fixtures/Batch/ | exists, disabled | – | waiting |
| CL-8 | CL-jobs | 3 | RealJobsTests + fake jobs + broken fixture, disabled | Tests/AfterGlowCLITests/RealJobsTests.swift, Tests/RealJobs/fake/, Fixtures/RealJobsBroken/ | exists, disabled | – | waiting |
| CL-4 | CL-args | 4 | parser, router, output | CLI.swift, Arguments.swift, Output.swift, mutations Arguments plan, CLIArgsTests.swift | CLIArgsTests | – | waiting |
| CL-5 | CL-args | 4 | LiveIO | LiveIO.swift, mutations LiveIO plan, CLIFileSafetyTests.swift | CLIFileSafetyTests | – | waiting |
| CL-7 | CL-batch | 4 | Script + ScriptRunner bodies, cli-batch C4 | Script.swift, ScriptRunner.swift, mutations ScriptRunner plan, BatchTests.swift, cli-batch.json | BatchTests | – | waiting |
| CL-9 | CL-jobs | 4 | RealJobs body, cli-jobs C4 | RealJobs.swift, mutations RealJobs plan, RealJobsTests.swift, cli-jobs.json | RealJobsTests | – | waiting |
| CL-10 | CL-z | 5 | spawned binary journey | Tests/AfterGlowCLITests/CLIBinaryTests.swift | CLIBinaryTests | – | waiting |
| CL-11 | CL-z | 6 | docs/cli.md, status built, feature-done | docs/cli.md, afterglow-cli.wave.json | waves check, c4 check | – | waiting |

Wave independence: wave 1 CL-1 alone. Wave 2 CL-2 alone (waits on CL-1 for the targets, and on CC-a for HeadlessDocument, CommandEnvelope, CatalogError). Wave 3 CL-3, CL-6, CL-8 independent (each waits on CL-2's stubs). Wave 4 CL-4 (CL-3), CL-5 (CL-3), CL-7 (CL-6), CL-9 (CL-8), independent of each other. Wave 5 CL-10 (CL-4, CL-5, CL-7: runs their code from the binary). Wave 6 CL-11 (CL-9, CL-10: final prose).

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- PRs base `dev`, not `main`: CLAUDE.md and the lane only take `dev` (the lane retargets a fast-lane PR opened against main); the brief's "base main" read as the integration branch it verified.
- CL-1 starts now although the packet lists CC-a for "everything": CL-1 declares only targets, the router stub and `--version`, and calls no Commands type. CL-2 does (HeadlessDocument, CommandEnvelope, CatalogError, BatchReport, ExportedFile), so it waits on #2996 CC-a.
- CL-1 is a supervisor merge (protected Package.swift, scripts/test-scope): the PR carries Fast-Check and waits for the supervisor.
- No slice is UI (`ui_slice: none`), so no critic panel needs screens; reviews of Linux-only slices run as code reviews only when findings are plausible.

## Open
- command-catalog #2996 CC-a not started (no PR, no lead branch at 2026-10-18T23:21Z): holds CL-2 and every slice after CL-a, and all of afterglow-mcp.
