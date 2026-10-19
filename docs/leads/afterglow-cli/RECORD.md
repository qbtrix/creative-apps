# afterglow-cli lead record

Issue: #2998 · Packet: docs/blueprints/suite/features/afterglow-cli.md
Run: act-1a1514ffe22-lvmw · Session: cloud lead (line:suite, with afterglow-mcp #3000) · Started: 2026-10-18T23:21Z
Stage: 4 build wave 4
Base: 1200886790fc1044eee6f644fb72508668e570cf (origin/dev after CL-1 #3037 and CC-1 #3056 merged)
Next: CL-4 and CL-5 builders running (from 05:24Z). #3123 CL-8 in lane → then CL-9. CL-7 after CC-7 #3120 merges. Then CL-10 (after CL-4, CL-5, CL-7).

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| CL-a | targets, executable, stubs, FakeIO, app registry | CL-1, CL-2 | LJ0 | – (CL-2: command-catalog CC-a, cross-line) | false | 0 | building (CL-1 merged) | – | – |
| CL-args | strict single-shot forms, one JSON object, sysexits, no overwrite | CL-3, CL-4, CL-5 | LJ1 | CL-a | false | 0 | waiting | – | – |
| CL-batch | `afterglow run` scripts | CL-6, CL-7 | LJ2 | CL-a | false | 0 | waiting | – | – |
| CL-jobs | real-jobs harness on Linux CI | CL-8, CL-9 | LJ3 | CL-a | false | 0 | waiting | – | – |
| CL-z | spawned binary, docs/cli.md, built | CL-10, CL-11 | LJ4 | every slice above | false | 0 | waiting | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| CL-1 | CL-a | 1 | targets, main.swift, CLI router stub, `--version` live, C4 container + cli-runner | Package.swift, scripts/test-scope, Sources/AfterGlowCLI/main.swift, Sources/AfterGlowCLICore/CLI.swift, Tests/AfterGlowCLITests/CLIShapeTests.swift, docs/c4/parts/creative-apps/afterglow-cli/container.json, docs/c4/parts/creative-apps/afterglow-cli/cli-runner.json | CLIShapeTests (LJ0) | #3037 | merged 0487e28 |
| CL-2 | CL-a | 2 | CLIIO/FakeIO, HeadlessApp/Session, Apps, ScriptRunner/RealJobs/MCPServer stubs | Sources/AfterGlowCLICore/{CLIIO,Apps,ScriptRunner,RealJobs}.swift, Sources/AfterGlowCLICore/MCP/MCPServer.swift, Tests/AfterGlowCLITests/CLIStubTests.swift | CLIStubTests | – | waits on CC-2 #3074 |
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
- command-catalog #2996 CC-a: CC-1 merged (#3056); CC-2 open as #3074. CL-2 needs CC-2's five <X>Headless types and the fake for `Apps.all`, so it holds CL-2, every slice after CL-a, and all of afterglow-mcp.

## CL-3 handoff notes (PR #3118, head 8f1f4af)
- CLIArgsTests disabled "waits on CL-4"; CLIFileSafetyTests disabled "waits on CL-5" (needs a liveIO() helper filled by CL-5).
- Output shapes fixed by tests: error kinds usage/data/unavailable/failed/exists/io; reply keys commands, command, summary, output, outputs, undoStep; unavailable message is the app's own text.
- CL-4 must route over Apps.all + [Apps.fake] (tests call CLI.run(_:io:)); command-editing tests also need CC-7 (catalog run body).
- CL-4 enabling breaks CLIShapeTests.everyOtherFormIsAStubThatNamesItsSlice (list-apps, --help, --version --json no longer stubs): CL-4 must update that test.
- Fake catalog has 8 commands (incl. edit.undo/edit.redo), not 6.

## CL-8 handoff notes (PR #3123, head 788e8b8)
- RealJobsTests (LJ3) disabled "waits on CL-9"; RealJobsLayoutTests (2, file-only) enabled.
- Assumed report: RealJobs.check prints one JSON object: "ok": true on pass; "ok": false + non-zero exit on failure; "skipped": "<reason>" + exit 0 on skip ("macOS-only: <why>" or "waits on image-codecs").
- Fixtures export with "format": "json"; output extension comes from the format. Broken fixture fake/wrong-sha differs in the last hex digit (catches .fullDigest).
- The pixel-expectation test needs updating once image-codecs is bumped in.

## CL-6 handoff notes (PR #3124, head 458e9ec)
- BatchTests (16) disabled "waits on CL-7"; also need CC-7 runBatch. Fixtures in Tests/AfterGlowCLITests/Fixtures/Batch/, loaded via #filePath into FakeIO.
- Fixed choices for CL-7: any refused input in a run exits 70 and the report still prints; output.format equal to the app's native extension ("fake") saves natively; report paths are CLIIO.read-style (batch/out/beach-small.fake).
- Exit codes: version != 1 → 65; unknown app/step → 64 naming it, nothing written; missing script 74, malformed 65; empty pattern 65; collisions 73 unless force.
- hundredInputsWithinBudget only prints; ask supervisor if it should join Tests/perf-suites.txt.
