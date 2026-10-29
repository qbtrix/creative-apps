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
| `mcp` | the MCP server: every app's catalog as tools over stdio (MCP server below) | one JSON-RPC reply line per request, until stdin ends |

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
- `new` and a command save the app's native format, so their `--out` (or
  the `--in` of `--in-place`) must end in the app's native extension
  (`.flare`, `.ora`, ...), `--force` or not; anything else is 64. Use
  `export` for another format. A Lottie `.json` or a PNG you opened is never
  overwritten with the native format.
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

Every invocation but `mcp` prints exactly one JSON object on one line of stdout, keys
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

## MCP server: `afterglow mcp`

`afterglow mcp` is a Model Context Protocol server over stdio. It publishes
every app's command catalog as tools, so an MCP client edits documents
through the same catalog as the menus and the commands above. It runs on
Linux and macOS. The packet is
`docs/blueprints/suite/features/afterglow-mcp.md`; the code is
`Sources/AfterGlowCLICore/MCP/`.

### Set-up for a client

Build the binary once, then add one entry to your client's `.mcp.json`
(or to its MCP settings, which take the same command and args):

```bash
swift build -c release --product afterglow    # .build/release/afterglow
```

```json
{
  "mcpServers": {
    "afterglow": {
      "command": "/absolute/path/to/creative-apps/.build/release/afterglow",
      "args": ["mcp", "--root", "/Users/me/Art"]
    }
  }
}
```

That is all a client needs. It starts the process, writes one JSON-RPC
request per line to stdin and reads one reply per line from stdout. Use
absolute paths: the client picks the working directory, and a relative
`--root` is taken against it.

| flag | meaning |
|---|---|
| `--root <dir>` | a folder the tools may read and write. Required unless `--live` is given; give it more than once for more folders. With `--live` and no root, the file tools refuse. |
| `--app <name>` | serve only this app's tools (`photo`, `design`, `flare`, `halo`, `library` or `fake`); repeat for more. Left out, every app. |
| `--live` | also list the running apps' tools (Live mode below). macOS only. |

Parsing is strict, as for the other forms, and a bad command line exits
before serving, with the usual one JSON object:

| when | message | exit |
|---|---|---|
| no `--root` and no `--live` | `afterglow mcp needs --root <dir>, the folder its tools may read and write` | 64 |
| an unknown flag or app | `unknown flag --port`, `unknown app paint` | 64 |
| `--app <name>` or `--live` given twice | `--app fake is given twice`, `--live is given twice` | 64 |
| `--live` off macOS | `afterglow mcp --live runs only on macOS, where the apps listen` (kind `unavailable`) | 69 |

Once serving, stdout carries nothing but replies. Blank lines and
notifications get no reply, and the process exits 0 when stdin ends.

**The five apps' catalogs are empty today** (see Forms): each app lists only
its `open` and `new` tools until its `adopt-command-catalog` slice lands.
The `fake` app has a full catalog, so try the server on it first
(`--app fake`).

### Protocol versions

The server speaks three revisions of the specification, newest first:
`2026-07-28`, `2025-11-25` and `2025-06-18` (`MCPVersions.swift`).

- **2026-07-28** has no session: each request names its version in
  `params._meta["io.modelcontextprotocol/protocolVersion"]`, and
  `server/discover` returns the versions, the capabilities and the server's
  name.
- **2025-11-25 and 2025-06-18** start with `initialize`, which must carry a
  `protocolVersion`. The reply is in that version, and it stays the version
  of later requests that name none.
- A request that names no version, before any `initialize`, is answered as
  `2026-07-28`.

The methods are `server/discover`, `initialize`, `ping`, `tools/list` and
`tools/call`. The capabilities are `{"tools":{"listChanged":false}}`: no
resources, no prompts, no change notifications.

| error | code | when |
|---|---|---|
| Parse error | -32700 | the line isn't JSON (the reply's id is null) |
| Invalid Request | -32600 | not one request object: a batch, `jsonrpc` other than `"2.0"`, an id that is neither an integer nor a string, `params` that aren't an object, a line over 16 MiB |
| Method not found | -32601 | any other method |
| Invalid params | -32602 | an unsupported version (`data` lists `supportedVersions` and the `requested` one); `initialize` without `protocolVersion`; an unknown tool; `arguments` that aren't an object |

A handshake-era session with `--app fake` (real output):

```
> {"jsonrpc":"2.0","id":1,"method":"server/discover"}
< {"id":1,"jsonrpc":"2.0","result":{"capabilities":{"tools":{"listChanged":false}},"serverInfo":{"name":"afterglow","version":"0.1.0"},"supportedVersions":["2026-07-28","2025-11-25","2025-06-18"]}}
> {"jsonrpc":"2.0","id":2,"method":"initialize","params":{"protocolVersion":"2025-06-18","clientInfo":{"name":"my-client","version":"1"},"capabilities":{}}}
< {"id":2,"jsonrpc":"2.0","result":{"capabilities":{"tools":{"listChanged":false}},"protocolVersion":"2025-06-18","serverInfo":{"name":"afterglow","version":"0.1.0"}}}
> {"jsonrpc":"2.0","method":"notifications/initialized"}
> {"jsonrpc":"2.0","id":90,"method":"tools/list","params":{"_meta":{"io.modelcontextprotocol/protocolVersion":"2024-01-01"}}}
< {"error":{"code":-32602,"data":{"requested":"2024-01-01","supportedVersions":["2026-07-28","2025-11-25","2025-06-18"]},"message":"Unsupported protocol version"},"id":90,"jsonrpc":"2.0"}
> {bad json
< {"error":{"code":-32700,"message":"Parse error: the line is not one JSON value"},"id":null,"jsonrpc":"2.0"}
```

### The tools

`tools/list` returns the same list, in the same order, on every call:

1. each served app's `<app>.open {path}` and `<app>.new {options?}`;
2. `afterglow.save {doc, path?, force?}`, `afterglow.export {doc, format,
   path, options?, force?}` and `afterglow.close {doc}`, for any app's
   document;
3. every command of every served app as `<app>.<id>`, by id, with input
   `{doc, params}`: the command's own params schema sits under `params`.

A command tool's title is the command's title. Its description is the
command's summary, plus `Undoable: one step named '<title>'.` for an edit,
and its output schema is `{result, undoStep?}`. The annotations follow the
command's kind: a query is `readOnlyHint: true`; a view or an edit is
`destructiveHint: false`; a file command is destructive only when it takes
`force`. Save and export are `destructiveHint: true`, and every tool is
`openWorldHint: false`. With `--app fake` the list is `fake.open`,
`fake.new`, `afterglow.save`, `afterglow.export`, `afterglow.close`,
`fake.doc.export-json`, `fake.edit.redo`, `fake.edit.undo`, `fake.rect.add`,
`fake.rect.list`, `fake.rect.move`, `fake.rect.remove`, `fake.rect.select`.

A `tools/call` reply has one text content (the result as JSON text, or the
error), `structuredContent` and `isError`. Anything the model can act on is
a tool error (`isError: true`), never a protocol error: the app's why-not,
each schema issue as `/path: message`, a path outside the roots, a full
handle table, a dead handle, a file that exists. Only an unknown tool and
`arguments` that aren't an object are -32602.

**Rate limit:** at most 50 calls a second. One more is the tool error
`slow down: at most 50 calls a second`, and it runs nothing.

### Design's key commands

Design keys a layer's `x`, `y` and `opacity` with these ids, so a script or a
model can animate a file without the window, for example
`afterglow design keyframe.set --in ui.design --in-place --json '{"node":"node-2","property":"x","frame":60,"value":47}'`;
over MCP the tool is `design.keyframe.set`.
Every key edit is one undo step named its title, and the three that edit a
key are off with `Set a key first.` on a file with no keys. Easing names are
`linear`, `ease`, `easeIn`, `easeOut`, `easeInOut` and `hold`.

| id | does |
|---|---|
| `keyframe.set` | sets a key on `property` at `frame` to `value`, replacing one there; the rest pose stays |
| `keyframe.remove` | removes the key at `frame`; the other keys stay |
| `keyframe.move` | moves the key at `frame` to `to`; refused when a key is there |
| `keyframe.set-easing` | sets the easing from the key at `frame` to the next one |
| `time.sample` | returns `{x, y, opacity}` of `node` as the canvas shows it at `frame`, its containers' keys included |
| `time.playhead` | shows the file at `frame` (left out: the rest pose); no undo step, the file is unchanged |

`file.export` takes an optional `frame`: an animated file is written as it
shows at that frame, a still file the same at any frame. Design's SVG export
reads `frame` from its options the same way, for example
`afterglow design export ui.design --format svg --out out --json '{"frame":60}'`;
PNG export stays in the window for now.

### Handles

`<app>.open` and `<app>.new` hold the document in the server and return
`{doc, summary}`: `doc` is an opaque handle (a UUID), `summary` the app's
own. Every other tool takes `doc`. A handle ends on `afterglow.close`, after
1 hour without a call, or when the server exits; a dead one answers `this
document handle expired; open it again`. At most 16 documents are open at
once; the 17th is `at most 16 documents may be open; close one first`.
Nothing reaches the disk until `afterglow.save`: closing drops unsaved
edits.

A session in the current revision (real output, run in a folder holding
`root/a.fake`, an empty fake document). Every request carries
`"_meta":{"io.modelcontextprotocol/protocolVersion":"2026-07-28"}` in its
`params`. The lines are shortened to the tool's name and arguments and the
reply's `isError` and `structuredContent`; `<doc>` is the handle and `…` a
shortened path:

```
> fake.open {"path":"a.fake"}
< false {"doc":"CD539B7F-33E6-4402-8664-A591B93B46ED","summary":{"rects":0,"selected":null}}
> fake.rect.add {"doc":<doc>,"params":{"x":10,"y":10,"w":40,"h":30,"name":"Box"}}
< false {"result":{"h":30,"id":1,"locked":false,"name":"Box","w":40,"x":10,"y":10},"undoStep":"Add Rectangle"}
> fake.rect.add {"doc":<doc>,"params":{"x":10,"y":10}}
< true {"error":"rect.add params: /w: missing required key; /h: missing required key"}
> afterglow.save {"doc":<doc>}
< true {"error":"…/root/a.fake already exists; pass force: true to replace it"}
> afterglow.save {"doc":<doc>,"path":"b.fake"}
< false {"path":"…/root/b.fake"}
> afterglow.export {"doc":<doc>,"format":"json","path":"out/b.json"}
< false {"path":"…/root/out/b.json"}
> fake.open {"path":"/etc/passwd"}
< true {"error":"/etc/passwd is outside the allowed roots (root)"}
> afterglow.close {"doc":<doc>}
< false {}
> fake.rect.list {"doc":<doc>}
< true {"error":"this document handle expired; open it again"}
```

and an unknown tool, in full:

```
< {"error":{"code":-32602,"message":"Unknown tool: fake.nope"},"id":12,"jsonrpc":"2.0"}
```

### Roots

Every path a tool takes, to open, save or export, must lie inside a
`--root`:

- A relative path is placed against the **first** root, with `.` and `..`
  folded; the paths in replies are absolute.
- The check uses the real location, every symlink resolved (the roots' own
  too), so a link inside a root that points out of it is refused.
- A path must lie under a root, not be the root folder itself.
- Outside, the call is the tool error `<path> is outside the allowed roots
  (<the roots as given>)`.
- No file is replaced without `"force": true`, not even the one the document
  was opened from. Missing folders on the way are created, and writes are
  atomic, as for `--out`.

### Live mode (macOS)

`afterglow mcp --live [--root <dir>]` also bridges the apps running on this
Mac, so a client edits the document in an open window, each edit an
ordinary undo step there. In `.mcp.json`, add `"--live"` to `args`. Off
macOS it exits 69 (above).

**No app turns its live channel on yet.** An app opts in by handing a
`LiveCommandChannel` to `.suiteApp(_:host:live:)`, whose `live` defaults to
nil, and none of the five passes one today. So `--live` lists no `live.`
tools yet and the server behaves as it does without the flag. The rest of
this section is what the code does once an app passes a channel.

- **The wire.** A running app listens on a Unix socket,
  `~/Library/Application Support/AfterGlow/live/<app>-<pid>.sock` (folder
  0700, socket 0600), and opens no network port. It serves peers running as
  the same user only, at most 8 connections at once, and removes its own
  stale sockets when it starts.
- **The tools.** Each `tools/list` asks every socket again, skips the ones
  that don't answer, and adds `live.<app>.<id>` for each command of each
  running app (apps by name, commands by id), such as
  `live.photo.layer.add`. The input is `{params}` only: the document is the
  window's, so there is no handle. The description starts `In the open
  <Title> window: ` before the command's summary. Title, output schema and
  annotations are the headless tool's. Live calls share the 50-a-second
  limit.
- **Calls.** A live call runs the command on the window's document on the
  main thread, through the same catalog. When the app has quit, the call is
  the tool error `Photo is not running; open it with a document, then list
  the tools again`; with no document open, `Photo has no document open; open
  one, then call again`.
- **Seeing and painting (Photo).** `live.photo.document.read` lists the
  canvas size, the layers top-first (id, name, kind, box, hidden, opacity)
  and the selected ids. `live.photo.view.snapshot {maxSide, region?}`
  returns `{png, width, height}`: the canvas, or one region of it, as the
  window shows it, scaled so its longer side is at most `maxSide` (16 to
  2048), base64 PNG. Both change nothing. `live.photo.paint.stroke
  {points: [{x, y}], size, hardness, color: {r, g, b, a}, opacity}` paints
  one brush stroke on the selected image layer as one undo step, "Brush
  Stroke", with Photo's own brush; hardness, colour and opacity run 0 to 1,
  and the person's brush and tool are left as they were.

#### Approval

A live command runs only for a client the user approved. The client is the
`clientInfo.name` it sent with `initialize` (cut to 128 characters); a
client that never sends `initialize`, as in the 2026-07-28 revision, is
`MCP client`.

1. A call from a client with no grant asks the user in the app:
   "Allow “<client>” to control <app>?", with **Allow Once**, **Always
   Allow** and **Deny**. The bridge waits up to 120 s for the app's reply.
2. Allowed within 110 s, the call runs and returns its result.
3. Denied, or answered after 110 s, the call is refused. The client sees the
   tool error `Photo asked you to approve this client; answer it in Photo,
   then call again`. After a late Always Allow, calling again runs.

- **Allow Once** is never remembered. It lasts one connection, and a
  reconnect asks again. The bridge opens a fresh connection to the app for
  each list and each call, so today Allow Once covers the one call it
  answered, and the next call asks again.
- **Always Allow** and **Deny** are remembered per client per app, in the
  suite preferences (`preferences.json`, the app's `aiAccess.<client>`
  key). A remembered deny refuses at once with no prompt, and the client
  sees the same "asked you to approve" text.
- **A file command always asks**, whatever the grant, and Allow Once never
  covers one.
- **Stop.** The channel's `stop()` closes every client's connection and
  removes the socket, so every client then finds the app not running.

The approval sheet, the "Controlled by <client>" title-bar chip with its
**Stop** button, and Window > AI Access… (the remembered grants, each with
**Revoke**) are built, and today run on a demo request (the
`-AIAccessDemoRequest <client>` launch argument), not on the channel. The
app that wires its channel connects them: the sheet becomes the channel's
`ask`, the chip reads its `connectedClient`, and Stop calls `stop()`.

#### The audit log

Every live command the app decides on leaves one line in
`~/Library/Logs/AfterGlow/ai-access.log` (folder 0700, file 0600): one JSON
object, keys sorted, with `client`, `app`, `id` (the command), `time`
(ISO 8601, UTC) and `outcome` (`ran`, `refused` or `failed`). The params are
never written. Nothing rotates or trims the log. A line has this shape:

```json
{"app":"photo","client":"my-client","id":"layer.add","outcome":"ran","time":"2026-10-19T09:30:00Z"}
```
