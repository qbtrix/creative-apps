# Feature packet: afterglow-cli

**Feature:** `afterglow`, a headless command line tool that drives every
app's command catalog on files with no window: `afterglow <app> <command>
--json '{…}'`, `afterglow <app> open|export|list-commands|describe`, and a
scripting form, `afterglow run <script.jobs.json>`, that runs a JSON list of
commands over a set of input files (batch resize, watermark, export every
frame). It builds and runs on Linux, so cloud leads and CI drive every app
through it, and the **real-jobs suites** (defined here) are its scripts with
expected outputs.
**Line:** `line:suite` · **Wave:** AI1 (`waves.md`, the AI-first track;
beta-80 **W0**, `p0`) · **Lead branch:** `lead/afterglow-cli`

**Covers:** the captain's AI-accessible-first call (the CLI half: "the UI,
CLI and MCP all drive the same command channel, which is also how crews
test the app"); beta-80 plan "W0: command layer"; suite.md 1.5.

**Depends on:**
- `suiteui/command-catalog` (#2996; cross-line, so prose, not
  `waits`): **CC-a** for everything here (the `Commands/` stubs, the fake
  headless document, the five `<X>Headless` stubs). The CLI runs end to end
  on the fake from CC-a; real apps arrive slice by slice as
  `adopt-command-catalog` fills each `<X>Headless`.
- `suite/targets` (#873, built).
- No creative-core issue for the CLI itself. Pixel expectations in the
  real-jobs harness (`"pixels"`) decode PNG through creative-core
  `image-codecs` (qbtrix/creative-core#562, IC-png) once `scripts/bump-core` brings it in; until
  then a pixel expectation reports "waits on image-codecs" and is skipped
  with that reason, never passed.

**Supervisor merges CL-1.** It edits `Package.swift` and
`scripts/test-scope`, protected paths: the lead opens the PR with
`Fast-Check: pass`, the supervisor runs the macOS build-only job and merges
it, as editor-kernel's EK-1 did. Every other task takes the fast lane.

**C4:** ✚ new container `afterglow-cli` (`docs/c4/parts/creative-apps/
afterglow-cli/container.json`, order 155, tags `internal`, technology
"Swift 6, Foundation, Linux and macOS"), with components `cli-runner`
(CL-1), `cli-batch` (CL-7), `cli-jobs` (CL-9) and `cli-mcp` (the
afterglow-mcp packet). Relationships: afterglow-cli → suite-kernel (runs
every catalog), → each `*-model` (opens, saves and exports through its
`<X>Headless`). The beta-80 plan's section 8 said no new container was
needed; a CLI is a new deployable, so it is one.

**Clean-room.** Behaviour only. Exit codes follow the BSD `sysexits`
convention (public). No other product's code or docs are read.

Blueprint sections: suite.md 1.5 (principle), 2.2 (containers), 4
(journeys: real jobs run headless).

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| CL-a | The `AfterGlowCLICore` library, the `afterglow` executable and their tests exist on Linux and macOS with every entry point as a documented stub, an in-memory file system and the app registry over the five `<X>Headless` types plus the fake. | CL-1, CL-2 | LJ0 | – |
| CL-args | Every single-shot form parses strictly (an unknown flag, app or command is a usage error that names it), prints one JSON object on stdout, exits with a sysexits code, and never overwrites a file unless told to. | CL-3, CL-4, CL-5 | LJ1 | CL-a |
| CL-batch | `afterglow run` reads a versioned `*.jobs.json`, expands its inputs relative to the script, runs its steps on each input (all or none per input when atomic), writes outputs by name template, refuses collisions, and reports every step. | CL-6, CL-7 | LJ2 | CL-a |
| CL-jobs | The real-jobs harness runs every `Tests/RealJobs/<app>/<job>/` through the CLI on Linux CI and fails on any output that differs from its expectation (sha256, JSON equal, or pixels within a tolerance), skipping a macOS-only job with its reason. | CL-8, CL-9 | LJ3 | CL-a |
| CL-z | The built binary runs a whole session on the fake from a real shell, the CLI reference is written, and the feature is built. | CL-10, CL-11 | LJ4 | every slice above |

No screen (`"ui_slice": "none"`): the CLI is headless by design. Its UI is
the five apps' menus, which reach the same catalog through
`adopt-command-catalog`. CL-a is the contract (rule 12); the three logic
slices wait only on it and run in parallel; CL-z integrates.

## Journey steps

All Linux, in `Tests/AfterGlowCLITests/`, through `CLI.run(_:io:)` in
process (the same entry `main.swift` calls), on the fake app (`fake`,
registered only by the tests) until the adopt slices land:

1. LJ0 (CL-1, CL-2): `afterglow --version` prints `{"version": …}`; every
   stub answers or exits 69 naming its slice.
2. LJ1 (CL-3 to CL-5): `afterglow fake list-commands` lists six ids;
   `afterglow fake describe rect.add` prints its schema; `afterglow fake
   rect.add --in a.fake --out b.fake --json '{"x":1,"y":2,"w":3,"h":4}'`
   writes b.fake with one more rect and prints `{"ok": true, "undoStep":
   "Add Rectangle", …}`; `--colour red` exits 64 "unknown flag --colour";
   writing over b.fake again without `--force` exits 73.
3. LJ2 (CL-6, CL-7): `afterglow run resize.jobs.json` over three inputs
   writes three outputs named `{stem}-small.fake`; a second run refuses the
   collisions; with one bad input and `"atomic": true` that input's output
   is not written and the report names its step and why.
4. LJ3 (CL-8, CL-9): `RealJobsTests` runs `Tests/RealJobs/fake/*` green; a
   fixture job whose expected sha256 is wrong fails naming the job and the
   output path.
5. LJ4 (CL-10): the built `afterglow` binary, spawned as a process, runs
   step 2 and step 3 and exits 0.

## Screens and states

None (headless). The CLI's output shapes are this packet's "screens": each
is a JSON snapshot in `Tests/AfterGlowCLITests/Golden/` (`list-commands`,
`describe`, `run-ok`, `run-refused`, `batch-report`), compared exactly.

## Contract slice

`Package.swift` (CL-1), outside `#if os(macOS)` so both platforms build
them:

```swift
.target(name: "AfterGlowCLICore", dependencies: ["SuiteKernel", "SuiteModel"] + apps.map { .target(name: "\($0)Model") }),
.executableTarget(name: "AfterGlowCLI", dependencies: ["AfterGlowCLICore"]),     // product "afterglow"
.testTarget(name: "AfterGlowCLITests", dependencies: ["AfterGlowCLICore"]),
products += [.executable(name: "afterglow", targets: ["AfterGlowCLI"])]
```

`scripts/test-scope`: `Sources/AfterGlowCLI*` and `Tests/RealJobs/` map to
`AfterGlowCLITests`; every `Sources/<X>Model` and `Sources/SuiteKernel`
also map to it, so an adopt PR runs its app's real jobs.

The command line (CL-4 body; CL-1 declares the router):

```
afterglow --version | --help
afterglow list-apps
afterglow <app> list-commands
afterglow <app> describe <command>
afterglow <app> open <file>                                     # prints the document summary
afterglow <app> new --out <file> [--json '{…}']
afterglow <app> <command> --in <file> (--out <file> | --in-place) [--json '{…}'] [--force]
afterglow <app> export <file> --format <fmt> --out <path> [--json '{options}'] [--force]
afterglow run <script.jobs.json> [--dry-run] [--force]
afterglow mcp [...]                                             # the afterglow-mcp packet
```

Output: exactly one JSON object on stdout per invocation, sorted keys,
`{"ok": true, ...}` or `{"ok": false, "error": {"kind", "message",
"issues"?}}`; a one-line human message on stderr only when `ok` is false.
Exit codes: 0 ok; 64 usage (unknown flag, app or command, missing operand);
65 data (malformed `--json`, params failing the schema, a damaged file); 69
unavailable (the command can't run now: the message is the app's why-not;
also `notBuilt`); 70 failed (the command threw); 73 cannot create (output
exists, no `--force`); 74 I/O.

```swift
// Sources/AfterGlowCLICore/CLI.swift (CL-1 stub, CL-4 body)
public enum CLI { public static func run(_ arguments: [String], io: any CLIIO) -> Int32 }
// Sources/AfterGlowCLICore/CLIIO.swift (CL-2): everything the CLI touches outside itself
public protocol CLIIO: Sendable {
    func read(_ path: String) throws -> Data; func write(_ data: Data, to path: String, replace: Bool) throws   // atomic
    func exists(_ path: String) -> Bool; func glob(_ pattern: String, relativeTo dir: String) throws -> [String]
    func out(_ line: String); func err(_ line: String) }
public final class FakeIO: CLIIO   // in-memory files, captured stdout and stderr; the tests' file system
// Sources/AfterGlowCLICore/Apps.swift (CL-2)
public struct HeadlessApp: Sendable {   // a HeadlessDocument type, erased so the router can list and pick
    public let name: String; public let openExtensions: [String]; public let exportFormats: [String]
    public init<D: HeadlessDocument>(_ type: D.Type)
    public func describeAll() -> [CommandDescription]
    public func session(open data: Data, name: String) throws -> HeadlessSession }
public struct HeadlessSession: Sendable {  // one open document of any app
    public mutating func run(_ step: CommandEnvelope) throws(CatalogError) -> CommandOutcome
    public mutating func runBatch(_ steps: [CommandEnvelope], atomic: Bool) -> BatchReport
    public func save() throws -> Data; public func export(_ format: String, options: JSONValue) throws -> [ExportedFile]
    public func summary() -> JSONValue }
public enum Apps { public static let all: [HeadlessApp]   // photo, design, flare, halo, library (the <X>Headless types)
    public static func named(_ name: String, in apps: [HeadlessApp]) -> HeadlessApp? }
```

The script form, `*.jobs.json` (CL-6 checks, CL-7 body). It is also the
real-jobs suite format:

```json
{
  "version": 1,
  "app": "photo",
  "inputs": ["input/*.png"],
  "steps": [
    {"id": "image.resize", "params": {"longSide": 1080}},
    {"id": "layer.place", "params": {"file": "input/logo.png", "anchor": "bottomRight", "inset": 24}},
    {"id": "layer.opacity", "params": {"value": 0.6}}
  ],
  "atomic": true,
  "output": {"dir": "out", "name": "{stem}-1080", "format": "png", "options": {}},
  "expect": {"out/beach-1080.png": {"pixels": {"tolerance": 2}}},
  "platforms": ["linux", "macos"]
}
```

- Paths are relative to the script's folder. `inputs` globs expand in
  sorted order; an input matching nothing is an error, not an empty run.
- `output.name` tokens: `{stem}`, `{ext}`, `{index}` (1-based, zero-padded
  to the input count's width), `{app}`. Without `output`, documents are
  saved in their native format next to the script under `out/`.
- `"atomic": true` runs one input's steps with `runBatch(atomic: true)`: a
  refused step writes nothing for that input. Other inputs still run.
  `false` stops that input at the first refusal and writes what it has.
- `expect` (real jobs only): per output path, one of `{"sha256": "…"}`,
  `{"json": <value>}` (the output parsed and compared equal) or
  `{"pixels": {"tolerance": n, "reference": "expected/<name>.png"}}` (each
  channel within n of 255). `platforms` defaults to both; a job without
  `linux` is skipped on Linux with "macOS-only: <reason>" from its
  `"why"` field.

Report (stdout): `{"ok", "inputs": [{"input", "steps": [BatchReport.Step],
"outputs": [paths], "error"?}], "written": n, "refused": n}`.

## Pseudocode

```
CLI.run(args, io):
  parse strictly: every flag known for its form, else usage(64, "unknown flag X")
  route:
    list-apps        → Apps.all names, extensions, formats
    <app> list-commands / describe → catalog.describeAll() / describe(id) ?? usage
    <app> open f     → session(open: io.read(f)).summary()
    <app> <cmd>      → s = open(--in); outcome = s.run(Envelope(cmd, json)); 
                       target = --in-place ? --in : --out; refuse (73) if exists && !force && !inPlace
                       io.write(s.save(), target, replace: force || inPlace)
    <app> export f   → for file in s.export(fmt, opts): write under --out (a dir when several)
    run script       → ScriptRunner.run(script, io)
  map: CatalogError.unknownCommand → 64; malformedParams → 65; unavailable/notBuilt → 69;
       failed → 70; decode of a document → 65; io → 74

ScriptRunner.run(script):
  validate version == 1, app known, every step id in the catalog (before any input runs)
  inputs = sorted(glob(each pattern)); empty match → 65
  plan outputs for every input first; a planned output that exists (no --force) or two inputs
    planning one path → 73 before anything is written
  dry-run: print the plan and stop
  per input: s = open; report = s.runBatch(steps, atomic); if refused && atomic: record, continue
             write outputs; record
```

## Tasks

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| CL-1 | – | The targets task (supervisor merges): `AfterGlowCLICore`, `AfterGlowCLI` (product `afterglow`), `AfterGlowCLITests` in `Package.swift` outside the macOS block; `scripts/test-scope` rows; `main.swift` calling `CLI.run`; the `CLI` router stub; the C4 container and `cli-runner` part; LJ0 written, `--version` live | `Package.swift`, `scripts/test-scope`, `Sources/AfterGlowCLI/main.swift`, `Sources/AfterGlowCLICore/CLI.swift`, `Tests/AfterGlowCLITests/CLIShapeTests.swift`, `docs/c4/parts/creative-apps/afterglow-cli/container.json`, `docs/c4/parts/creative-apps/afterglow-cli/cli-runner.json` | – | ~220, 7 |
| CL-2 | – | Stubs with doc comments: `CLIIO` with `FakeIO`, `HeadlessApp`, `HeadlessSession`, `Apps` (the five `<X>Headless` and, for tests, the fake), `ScriptRunner`, `RealJobs`, `MCPServer.serve` (exits 69 "afterglow-mcp is not built yet"); LJ0 covers them | `Sources/AfterGlowCLICore/CLIIO.swift`, `Sources/AfterGlowCLICore/Apps.swift`, `Sources/AfterGlowCLICore/ScriptRunner.swift`, `Sources/AfterGlowCLICore/RealJobs.swift`, `Sources/AfterGlowCLICore/MCP/MCPServer.swift`, `Tests/AfterGlowCLITests/CLIStubTests.swift` | CL-1 | ~320, 6 |
| CL-3 | – | Checks first: `CLIArgsTests` (every form, the exit-code table, one JSON object per run, unknown flag/app/command named, the golden outputs) and `CLIFileSafetyTests` (never overwrite without `--force`, `--in-place` explicit, atomic write leaves no partial file, a directory or a missing input is 74); LJ1, disabled | `Tests/AfterGlowCLITests/CLIArgsTests.swift`, `Tests/AfterGlowCLITests/CLIFileSafetyTests.swift`, `Tests/AfterGlowCLITests/Golden/` | CL-2 | ~340, 3 |
| CL-4 | – | The parser, router and output bodies and the plan; turns on `CLIArgsTests` | `Sources/AfterGlowCLICore/CLI.swift`, `Sources/AfterGlowCLICore/Arguments.swift`, `Sources/AfterGlowCLICore/Output.swift`, `Tests/mutations/AfterGlowCLICore.Arguments.json`, `Tests/AfterGlowCLITests/CLIArgsTests.swift` | CL-3 | ~380, 5 |
| CL-5 | – | `LiveIO` on Foundation (`FileManager`, write to a temp file then rename, a 2 GiB read cap, globs without a shell) and the plan; `Apps`' sessions over it; turns on `CLIFileSafetyTests` | `Sources/AfterGlowCLICore/LiveIO.swift`, `Tests/mutations/AfterGlowCLICore.LiveIO.json`, `Tests/AfterGlowCLITests/CLIFileSafetyTests.swift` | CL-3 | ~240, 3 |
| CL-6 | – | Checks first: `BatchTests` (version, unknown step id before any run, sorted globs, empty match, name tokens, collisions refused before writing, atomic per input, dry run, the report) and its fixtures; LJ2, disabled | `Tests/AfterGlowCLITests/BatchTests.swift`, `Tests/AfterGlowCLITests/Fixtures/Batch/` | CL-2 | ~300, 2 |
| CL-7 | – | `Script` (the Codable format and its validation) and `ScriptRunner` bodies, the plan, the `cli-batch` C4 part; turns on `BatchTests` | `Sources/AfterGlowCLICore/Script.swift`, `Sources/AfterGlowCLICore/ScriptRunner.swift`, `Tests/mutations/AfterGlowCLICore.ScriptRunner.json`, `Tests/AfterGlowCLITests/BatchTests.swift`, `docs/c4/parts/creative-apps/afterglow-cli/cli-batch.json` | CL-6 | ~360, 5 |
| CL-8 | – | Checks first: `RealJobsTests` (enumerates every `Tests/RealJobs/<app>/<job>/`, runs it into a temp dir, compares) with two fake jobs and a broken-expectation fixture that must fail; LJ3, disabled | `Tests/AfterGlowCLITests/RealJobsTests.swift`, `Tests/RealJobs/fake/`, `Tests/AfterGlowCLITests/Fixtures/RealJobsBroken/` | CL-2 | ~220, 3 |
| CL-9 | – | `RealJobs` body (sha256, JSON equal, pixels within tolerance through CoreRaster once image-codecs is in, else skipped with that reason; platform skips with the job's why), the plan, the `cli-jobs` C4 part; turns on `RealJobsTests` | `Sources/AfterGlowCLICore/RealJobs.swift`, `Tests/mutations/AfterGlowCLICore.RealJobs.json`, `Tests/AfterGlowCLITests/RealJobsTests.swift`, `docs/c4/parts/creative-apps/afterglow-cli/cli-jobs.json` | CL-8 | ~260, 4 |
| CL-10 | – | LJ4: spawn the built `afterglow` (`.build/debug/afterglow`, found from the test bundle's path) and run LJ1's step and LJ2's script from a temp dir | `Tests/AfterGlowCLITests/CLIBinaryTests.swift` | CL-4, CL-5, CL-7 | ~140, 1 |
| CL-11 | – | Shared prose: `docs/cli.md` (the reference: forms, exit codes, the script and real-jobs format, examples per app as they adopt), `status: built`; `feature-done`. suite.md already names the container and the principle (the packet PR wrote them), so this task doesn't edit it | `docs/cli.md`, `docs/blueprints/suite/features/afterglow-cli.wave.json` | CL-9, CL-10 | ~240, 2; `feature-done` |

CL-4 and CL-5 fill different files; CL-4's router reaches files only
through `CLIIO`, so it tests on `FakeIO` and needs nothing of CL-5.
`CLIIO.swift` (CL-2) keeps the protocol and `FakeIO`; CL-5 adds `LiveIO`
in its own file so the two never share one.

## Build waves

- Wave 1: CL-1. Independent in this wave: CL-1 alone.
- Wave 2: CL-2. Independent in this wave: CL-2 alone.
- Wave 3: CL-3, CL-6, CL-8. Independent in this wave: all three.
- Wave 4: CL-4, CL-5, CL-7, CL-9. Independent in this wave: all four.
- Wave 5: CL-10. Independent in this wave: CL-10 alone.
- Wave 6: CL-11 (shared prose, `feature-done`, final). Independent in this wave: CL-11 alone.

Longest chain: CL-1 → CL-2 → CL-3 → CL-4 → CL-10 → CL-11 (6). Chain of 6:
CL-2 adds the stubs CL-3's checks call, CL-4 turns them on, CL-10 runs
CL-4's router from a real binary, CL-11 is the final prose task.

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| CL-1 | `CLIShapeTests` (LJ0): `--version` prints one JSON object and exits 0; both targets build on Linux | the target or the entry is missing | – (targets) |
| CL-2 | `CLIStubTests`: `Apps.all` names the five apps in order; every stub exits 69 naming its slice; `FakeIO` round trips a file | a stub answers, or an app is missing | – (stubs) |
| CL-3 | the two test files exist, disabled by name | – | – (tests) |
| CL-4 | `CLIArgsTests` (LJ1) | a form parses loosely, prints two objects, or maps an error to the wrong code | unknown flags ignored → `.unknownFlagIs64`; `unavailable` mapped to 70 → `.unavailableIs69`; output written before the run succeeds → `.refusedWritesNothing` |
| CL-5 | `CLIFileSafetyTests` | a file is overwritten without `--force`, or a failed write leaves a partial file | replace defaulted to true → `.neverOverwrites`; write straight to the target, not via temp → `.atomicWrite` |
| CL-6 | `BatchTests` exists, disabled | – | – (tests) |
| CL-7 | `BatchTests` (LJ2) | a collision writes, an atomic input half-writes, or a bad step id runs anything | collisions checked per input, not up front → `.collisionsBeforeWriting`; atomic ignored → `.atomicPerInput`; globs unsorted → `.sortedInputs` |
| CL-8 | `RealJobsTests` exists, disabled; the broken fixture is in place | – | – (tests) |
| CL-9 | `RealJobsTests` (LJ3): fake jobs green; the broken fixture fails naming job and path; a macOS-only job is skipped on Linux with its why; a pixel job before image-codecs is skipped, never passed | a wrong output passes, or a skip passes silently | sha256 compared on a prefix → `.fullDigest`; tolerance checked with `<=` against 255·t → `.toleranceInclusive`; a skip counted as a pass → `.skipIsNotPass` |
| CL-10 | `CLIBinaryTests` (LJ4) | the binary and `CLI.run` disagree | – (integration) |
| CL-11 | `scripts/waves check`, `scripts/c4-assemble --check` | the data or parts don't assemble | – (prose) |

## Quality tests

| quality row | budget | test |
|---|---|---|
| start-up | `afterglow --version` ≤ 150 ms wall on Linux CI (no catalog built) | `CLIBinaryTests.versionIsFast` (reported) |
| batch throughput | 100 fake inputs × 3 steps ≤ 2 s on Linux CI; memory flat across inputs (one session alive at a time) | `BatchTests.hundredInputsWithinBudget` (reported) |
| strict parsing | every unknown flag, app and command exits 64 and names it | `CLIArgsTests.unknownFlagIs64` |
| no partial files | a run killed or refused mid-write leaves the target absent or whole | `CLIFileSafetyTests.atomicWrite` |
| untrusted script | a fuzzed `*.jobs.json` (1,000 seeded mutations) exits 64 or 65; never crashes, never writes | `BatchTests.fuzzedScriptsNeverCrash` |
| one output object | stdout parses as exactly one JSON object for every golden form | `CLIArgsTests.goldenOutputs` |

## Done check

Per slice: its tasks merged and the newest dev CI run containing its last
PR has a green `Linux` job (that job runs `AfterGlowCLITests`, so LJ0 to
LJ4 and the real jobs run there). No `"ui": true` slice, so no feel gate
and no Mac finisher pass. Then the contact sheet comment, which for this
feature is the golden outputs and the real-jobs table.
