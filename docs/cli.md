# afterglow: the command line

`afterglow` drives every app's command catalog on files, with no window. It
builds and runs on Linux and macOS, so cloud leads, CI and scripts reach the
apps through the same command channel the menus use. The packet is
`docs/blueprints/suite/features/afterglow-cli.md`; the code is
`Sources/AfterGlowCLICore/` (the router, testable in process through
`CLI.run(_:io:)`) and `Sources/AfterGlowCLI/main.swift` (the executable,
product `afterglow`, which hands the arguments and the real file system to
`CLI.run`).

```bash
swift build --product afterglow        # .build/debug/afterglow
.build/debug/afterglow --version       # {"ok":true,"version":"0.1.0"}
```

## Forms

```
afterglow --version | --help | list-apps
afterglow <app> list-commands | describe <command> | open <file>
afterglow <app> new --out <file> [--json '{…}'] [--force]
afterglow <app> <command> --in <file> (--out <file> | --in-place) [--json '{…}'] [--force]
afterglow <app> export <file> --format <fmt> --out <path> [--json '{options}'] [--force]
afterglow run <script.jobs.json> [--dry-run] [--force]
afterglow mcp [...]
```

`--help` prints this table as `{"ok":true,"usage":"…"}`.

| form | what it does | prints (besides `"ok": true`) |
|---|---|---|
| `--version` | the tool's version | `version` |
| `--help` | the forms above | `usage` |
| `list-apps` | every app the binary knows | `apps`: `[{name, openExtensions, exportFormats}]` |
| `<app> list-commands` | the app's catalog | `app`, `commands`: `[{id, kind, summary, title, undoable}]` |
| `<app> describe <command>` | one command's full description, its params schema included | `command` |
| `<app> open <file>` | opens the file and prints its summary | `summary` (the app's own) |
| `<app> new --out <file>` | a new document from `--json` options, saved natively | `output` |
| `<app> <command> --in <file> …` | runs one command on the file and saves the result | `command`, `output`, `result`, `undoStep` |
| `<app> export <file> --format <fmt> --out <path>` | exports in a format the app lists | `outputs` |
| `run <script.jobs.json>` | runs a script over a set of inputs (Scripts below) | the run report |
| `mcp` | the MCP server (`afterglow-mcp.md`); not built yet, exits 69 | – |

`<app>` is `photo`, `design`, `flare`, `halo` or `library`, plus `fake`,
SuiteKernel's test document (`FakeCanvasDocument`: rectangles, saved as
JSON, extension `.fake`, exports `json`). The binary registers the fake too
(`CLI.registry`), so a shell session can be tried before any app adopts.

**The five apps are stubs today.** Each `<X>Headless` has an empty catalog,
no open extensions and no export formats until its
`adopt-command-catalog` slice lands: `list-commands` prints no commands,
`open` and `new` exit 69 (`notBuilt`, naming the adopting slice), any
command id exits 64 and any `--format` exits 64. Examples per app go here
as each one adopts.

### Flags

Parsing is strict. Each form knows its own flags and nothing else:

| form | value flags | switches |
|---|---|---|
| `new` | `--out`, `--json` | `--force` |
| `<command>` | `--in`, `--out`, `--json` | `--in-place`, `--force` |
| `export` | `--format`, `--out`, `--json` | `--force` |
| `run` | – | `--dry-run`, `--force` |
| every other form | – | – |

- Any other token starting with `-` is `unknown flag <token>` (64). A flag
  given twice, a value flag with no value, a missing operand or an extra one
  is 64 too, and the message names it.
- The app and the command id are checked against the registry before any
  flag: `unknown app <name>` and `unknown command <id> for <app>` are 64.
- `--json` must be one JSON object; anything else is 65. Left out, it is
  `{}`. For a command it is the params, checked against the command's schema
  (a mismatch is 65 with the schema `issues`); for `new` and `export` it is
  the options.
- A command takes exactly one of `--out <file>` and `--in-place`. Neither,
  or both, is 64.

### Files are never overwritten unless you say so

- `--out` to a file that exists is 73 (`<path> already exists; pass --force
  to replace it`). `--force` replaces it. `--in-place` writes back to `--in`
  and needs no `--force`.
- Everything is checked, and the command runs, before anything is written:
  a refused run writes nothing.
- Writes are atomic: the data goes to a temp file beside the target, then
  lands by rename (replace) or hard link (no replace), so the target is
  absent, as it was, or whole. Missing folders on the way are created.
- Reads take regular files only, up to 2 GiB. A missing file, a directory
  or a file over the cap is 74.
- `export` writes one file to `--out`; when the format makes several, `--out`
  is a folder and each file lands there under its suggested name.

## Output and exit codes

Every invocation prints exactly one JSON object on one line of stdout, keys
sorted. Success is `{"ok":true,…}`. Failure is
`{"ok":false,"error":{"kind","message","issues"?}}`, plus the message as one
line on stderr. Exit codes follow BSD `sysexits`:

| code | kind | when |
|---|---|---|
| 0 | – | ok |
| 64 | `usage` | unknown flag, app or command; a missing or extra operand; `--out` with `--in-place`; a format the app doesn't export; no arguments |
| 65 | `data` | `--json` not one object; params failing the schema (`issues` lists them); a file that isn't the app's document; a malformed script |
| 69 | `unavailable`, `notBuilt` | the command can't run now (the message is the app's own why-not, such as "Select a rectangle first."), or the entry point isn't built yet |
| 70 | `failed` | the command threw; an export that wrote no files; a script run in which an input refused; a real job whose output differs |
| 73 | `exists` | an output exists and `--force` wasn't given; two script inputs plan one output |
| 74 | `io` | a missing, unreadable or too large input; a failed write |

A session on the fake (the same one `CLIBinaryTests` runs through the built
binary):

```bash
# a.fake holds the fixture: Rect 1 (selected) and Rect 2 (locked)
afterglow fake list-commands
afterglow fake describe rect.add
afterglow fake rect.add --in a.fake --out b.fake --json '{"x":1,"y":2,"w":3,"h":4}'
# {"command":"rect.add","ok":true,"output":"b.fake","result":{"h":4,"id":3,…},"undoStep":"Add Rectangle"}
afterglow fake rect.add --in a.fake --out b.fake --colour red    # 64: unknown flag --colour
afterglow fake rect.add --in a.fake --out b.fake --json '{…}'    # 73: b.fake already exists
afterglow fake rect.move --in plain.fake --in-place --json '{"dx":1,"dy":1}'   # a saved file opens with nothing selected
# {"error":{"kind":"unavailable","message":"Select a rectangle first."},"ok":false}   exit 69
afterglow fake export b.fake --format json --out b.json
```

The golden outputs in `Tests/AfterGlowCLITests/Golden/` are these shapes,
compared exactly.

## Scripts: `afterglow run`

A script is a versioned `*.jobs.json` that runs a list of steps on every
input file and writes each result by a name template:

```json
{
  "version": 1,
  "app": "fake",
  "inputs": ["input/*.fake"],
  "steps": [
    {"id": "rect.select", "params": {"id": 1}},
    {"id": "rect.move", "params": {"dx": 5, "dy": -5}}
  ],
  "atomic": true,
  "output": {"dir": "out", "name": "{index}-{stem}", "format": "json", "options": {}}
}
```

| field | meaning |
|---|---|
| `version` | must be `1`; anything else is 65 |
| `app` | the app whose documents the inputs are; unknown is 64 |
| `inputs` | glob patterns, relative to the script's folder. `*` and `?` match within one path segment (no `**`); a name starting with `.` matches only a pattern that does. Matches are de-duplicated and run in sorted order. A pattern matching nothing is 65, not an empty run. |
| `steps` | `{"id", "params"}` in order. Every id must be in the app's catalog, checked before any input runs (64). |
| `atomic` | default `true`: one input's steps run all or none, and a refused step writes nothing for that input. `false` stops the input at the refusal and writes what it has. Other inputs run either way. |
| `output.dir` | the output folder, relative to the script; default `out` |
| `output.name` | template of `{stem}`, `{ext}`, `{index}` (1-based, zero-padded to the input count's width) and `{app}`; default `{stem}`. The format's extension is appended. |
| `output.format` | the app's native extension (a save) or one of its export formats (which must write exactly one file); default native. A format the app can't write is 64. |
| `output.options` | the export options |

At least one input and one step are required (65). Every output is planned
before anything is written: two inputs planning one path, or a planned path
that exists without `--force`, is 73 and nothing runs. `--dry-run` prints the
plan, `{"dryRun":true,"inputs":[{"input","outputs"}],"ok":true}`, and writes
nothing. A missing script is 74.

The report:

```json
{"inputs":[{"input":"…","outputs":["…"],"steps":[{"id","ok","undoStep"?,"error"?}],"error"?:"…"}],
 "ok":true,"refused":0,"written":2}
```

`ok` is false and the exit is 70 when any input refused or couldn't be
opened (that input's `error` says why); a failed write makes it 74. The
report still prints in full.

## Real jobs

A real job is a script with expectations: the regression suite every app
runs headless. `RealJobsTests` (in `AfterGlowCLITests`, so the Linux CI job
and `scripts/ci --changed` on any `Sources/<X>Model` or `SuiteKernel` change
run it) checks every job through `RealJobs.check`, which runs the script
through `ScriptRunner` with `--force` and compares the outputs.

```bash
swift test --filter RealJobsTests
```

### Layout

```
Tests/RealJobs/<app>/<job>/
  <job>.jobs.json      exactly one script, with an expect block
  input/…              the inputs its globs name
  expected/…           reference images for pixel expectations
  out/                 written by a run; the harness ignores it, don't commit it
```

The tests copy each job folder into an in-memory file system, so a run never
touches the source tree. `Tests/RealJobs/fake/` holds `add-rect` (a JSON
expectation) and `move-each` (two sha256 expectations, `{index}` names).
`Tests/AfterGlowCLITests/Fixtures/RealJobsBroken/` holds a job with a wrong
digest that must fail.

### Fields beyond a script

`expect` maps each output path, relative to the job folder, to exactly one
expectation:

| expectation | passes when |
|---|---|
| `{"sha256": "<hex>"}` | the output's full SHA-256 equals the hex digest (any case) |
| `{"json": <value>}` | the output parses as JSON equal to the value |
| `{"pixels": {"tolerance": n, "reference": "expected/<name>.png"}}` | the decoded image is the reference's size and every channel is within `n` (in 255ths) of it |

An output that wasn't written fails. An entry with no key, two keys or
another key fails.

`platforms` lists `"linux"`, `"macos"` or both; left out, the job runs on
both. A job that leaves out the platform it is on is skipped before it runs,
with `"macOS-only: <why>"` on Linux (or `"Linux-only: <why>"` on macOS),
from its `why` field. Give every job a `why`: it says what the job proves,
and it is the skip reason. Leave out `linux` only for a job that needs a
macOS-only code path, such as a system codec or a live app.

### Pixel checks wait on image-codecs

Decoding PNG needs creative-core's `image-codecs` (qbtrix/creative-core#562),
which reaches the apps only through a `scripts/bump-core` PR. Until then
every pixel expectation is skipped: when a job's other expectations hold and
it has one, the job reports skipped with "waits on image-codecs
(qbtrix/creative-core#562): pixels can't be decoded yet". A pixel
expectation is never passed. The comparison it will run is
`RealJobs.pixelsMatch`.

### Reports

`check` prints one JSON object (keys sorted on the wire):

| result | shape | exit |
|---|---|---|
| pass | `{"ok":true,"job":"<folder>","checked":["<path>",…]}` | 0 |
| fail | `{"ok":false,"job":"<folder>","failures":[{"path","why"}]}` | 70 |
| skip | `{"job":"<folder>","skipped":"<reason>"}`, no `ok` key | 0 |

A skip is neither a pass nor a fail, which is why it has no `ok`. A fail
names each output path and why (`sha256 is <got>, expected <want>`, `JSON
differs from the expected value`, `was not written`). When the run itself
fails, the one failure is the script's path with the run's own output, and
the exit is the run's code. A folder without exactly one `*.jobs.json`, or a
script without an `expect` block, fails with 70.

### Adding a job

1. Make `Tests/RealJobs/<app>/<job>/` with the script and its inputs. Inputs
   are made by our own tools; nothing from other software.
2. Run it with `afterglow run <job>.jobs.json` and check the outputs by hand.
3. Write `expect` from them: sha256 for byte-exact formats, json for JSON,
   pixels for images. Delete `out/`.
4. `swift test --filter RealJobsTests` must pass or skip it with its reason.
