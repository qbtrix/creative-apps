# Feature packet: cli-bundle

**Feature:** a beta tester can reach the command layer. Today
`scripts/bundle-apps` copies the launcher, the five helpers and the frameworks,
but not the `afterglow` binary, so the CLI and MCP server exist only in the
source tree. This packet copies the release `afterglow` into
`AfterGlow.app/Contents/Helpers/afterglow`, signs it the same way as the
helpers (ad hoc until the captain's Developer ID, Q3), and checks it runs from
the bundle. Help > **Connect an AI Assistant…** shows the one line an MCP
client needs (`"<bundle>/Contents/Helpers/afterglow" mcp`) and the JSON block
for clients that take one, with Copy buttons and a link to the AI Access list.
**Install Command-Line Tool…** offers a symlink at `~/.local/bin/afterglow`
(no admin rights); it names the exact path and writes only after the person
clicks Install (RJ-X08). Both are commands in the suite Help catalog
(`help.connect-assistant` returns the text, `help.install-cli` makes the link
when asked), so an agent can run them through `afterglow run suite`.
**Line:** `line:suite` · **Wave:** BG1 (`waves.md`, the beta gaps) · **Lead branch:** `lead/cli-bundle`
**Beta:** captain, 2026-10-21 (beta gaps, suite must-haves). Labels `beta` and `p0` when filed.

**Covers:** `2026-10-21-beta-gaps-combined.md` suite must-have "bundle the
afterglow CLI + Help > Connect an AI Assistant"; suite audit row 6 and
under-specified 7; RJ-X62 (new).

**Depends on:** bundle (built: `scripts/bundle-apps`, `BundleLayout`),
afterglow-mcp (built: the stdio server). report-problem's **RP-u** (the Help
group, `SuiteHelpCommands.swift`) and **RP-m** (`SuiteHelpCatalog.swift`) come first,
since this packet adds an item to that group and two commands to that catalog.

**Supervisor merges.** CB-3 edits `scripts/bundle-apps`, which builds and
signs the shipped bundle, so it is off the fast lane. Signing stays ad hoc;
the Developer ID and notarization are the captain's call (Q3), not this packet.

**Rule 20.** One place knows the bundled path (`BundleLayout.cliPath`), one
builds the client text (`AssistantConnect`), and the sheet and the CLI both
read them.

**C4:** edits `suite-model/suite-packaging.json` (CB-1: the CLI's path) and
`afterglow-bundle`'s container part (CB-3: the helper binary).

**Clean-room.** The MCP client config shape from the protocol's public docs.

Blueprint sections: suite.md 1.4 and 1.5 (this reverses "no bundled CLI" for
the beta), 2.5 (bundle).

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| CB-a | SuiteModel knows where the bundled CLI lives and builds the assistant's command and config text and the install plan, as stubs, with the checks written and disabled. | CB-1, CB-2 | MJ-CB | report-problem:RP-m (CB-2: `SuiteHelpCatalog.swift`) |
| CB-u | Help > Connect an AI Assistant shows the bundled command and config with Copy buttons and an Install Command-Line Tool button, on the stubs, in the launcher and every editor, within the render budget. | CB-5, CB-5b | XJ-CB | CB-a; report-problem:RP-u (`SuiteHelpCommands.swift`) |
| CB-m | The bundle carries a signed afterglow that answers --version and an MCP handshake from inside the app, and the command text names that exact path. | CB-4, CB-3 | MJ-CB, XJ-CB | CB-a |
| CB-z | Install Command-Line Tool asks before it writes and runs live, RJ-X62 connects to the bundled server from the copied command, and the feature is built. | CB-6, CB-7, CB-8 | XJ-CB, MJ-CB | CB-u, CB-m |

**Screen early.** CB-u puts the real Help item and sheet on screen on CB-a's
stubs, beside CB-m; CB-6's install waits on CB-4's plan.

## Journey steps

`MJ-CB` on Linux (`AssistantConnectTests`, `MCPConfigTests`), then on the assembled bundle:
1. Help > Connect an AI Assistant…: the sheet shows `"…/AfterGlow.app/Contents/Helpers/afterglow" mcp`; Copy; Install Command-Line Tool…, Install: the link appears in the temp home's `.local/bin`; Close (CB-5, CB-6; `XJ-CB`, `AfterGlowHelpJourneyTests.testConnectAssistant`).

## Jobs

| job | closes or adds | run | check | fixture |
|---|---|---|---|---|
| RJ-X62 | adds, closes with `suite/cli-bundle` | Cm | `Tests/RealJobs/suite/connect-assistant/`: take `afterglow run suite help.connect-assistant`'s command, start it, send `initialize` and `tools/list` over stdio | the assembled `.build/apps/AfterGlow.app` |

Trap: the sheet shows a command that points into the source tree or an
unsigned binary that Gatekeeper kills. Assertion: the command's path is inside
the bundle, `codesign --verify` passes on it, and `tools/list` returns at least
one tool for each of the five apps. Mutation: `SuiteModel.AssistantConnect`
(`.pathWithSpaceQuoted`). CB-3 writes the check; CB-7 enables it.

## Screens and states

`suite-help-connect` (the sheet), `suite-help-install-alert`.

## Contract slice

```swift
// Sources/SuiteModel/Packaging/BundleLayout.swift (CB-1)
extension BundleLayout { public static let cliPath = "Contents/Helpers/afterglow" }
// Sources/SuiteModel/Packaging/AssistantConnect.swift (CB-1 stubs, CB-4 bodies). Linux-safe.
public enum AssistantConnect {
    public static func command(bundle: String) -> String          // ""<bundle>/Contents/Helpers/afterglow" mcp"
    public static func configJSON(bundle: String) -> String       // {"mcpServers": {"afterglow": {"command": …, "args": ["mcp"]}}}
    public enum InstallPlan: Equatable, Sendable { case link(at: String, to: String), alreadyLinked(String), refuse(reason: String) }
    public static func installPlan(home: String, bundle: String, existing: (String) -> String?) -> InstallPlan
}
```

| id | title | params | unavailable when |
|---|---|---|---|
| `help.connect-assistant` | – (query) | – → `{command, json}` | not in a bundle and no `--bundle` |
| `help.install-cli` | – (not an undo step) | `{confirm}` → the plan, or the link made | `confirm` false (returns the plan only); a foreign file (refused with the reason) |

## Pseudocode

- **Bundle path.** The running process's bundle (`Bundle.main`, walked up to
  `AfterGlow.app`); in a helper app that is three folders up from its own
  bundle. The CLI takes `--bundle` or resolves its own executable's path.
- **Install.** `existing(path)` returns the link's target or nil; our own
  link is `alreadyLinked`, any other file or link is `refuse`; else `link`.

## Tasks

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| CB-1 | – | **Checks first.** `AssistantConnectTests` written, disabled (`waits on CB-4`); `BundleLayout.cliPath` (`Contents/Helpers/afterglow`); `AssistantConnect` (`command(bundle:)`, `configJSON(bundle:)`, `installPlan(home:)`) as stubs; the packaging part names the CLI | `Sources/SuiteModel/Packaging/BundleLayout.swift`, `Sources/SuiteModel/Packaging/AssistantConnect.swift`, `Tests/SuiteModelTests/AssistantConnectTests.swift`, `docs/c4/parts/creative-apps/suite-model/suite-packaging.json` | – | ~140, 4 |
| CB-2 | – | `help.connect-assistant` (query: the command and the JSON block for the bundle) and `help.install-cli` (`{confirm}`: the install plan, then the link) join `SuiteHelpCatalog` as stubs; ids in `Tests/command-ids/suite.txt`; the CLI's provider in `MCPConfig.swift` | `Sources/SuiteKernel/Commands/SuiteHelpCatalog.swift`, `Tests/command-ids/suite.txt`, `Sources/AfterGlowCLICore/MCPConfig.swift`, `Tests/AfterGlowCLITests/MCPConfigTests.swift` | CB-1 | ~110, 3 |
| CB-5 | – | **Reachable first.** The Help group gains Connect an AI Assistant…; SuiteUI `AssistantConnectSheet` (the command, the JSON, Copy for each, Install Command-Line Tool…, Open AI Access); `AfterGlowHelpJourneyTests.testConnectAssistant` written, skipped until CB-6 | `Sources/SuiteShell/SuiteHelpCommands.swift`, `Sources/SuiteUI/AssistantConnectSheet.swift`, `UITests/AfterGlowJourneyTests+Connect.swift` | CB-1 | ~200, 3 |
| CB-5b | – | Render budget test: open the Connect sheet | `Tests/AppSnapshotTests/RenderBudgetConnectTests.swift` | CB-5 | ~60, 1 |
| CB-4 | – | `AssistantConnect` and the two help command bodies: the command quotes the bundle path, the JSON is the stdio server block, the install plan refuses a foreign file; turns on `AssistantConnectTests` and `MCPConfigTests` | `Sources/SuiteModel/Packaging/AssistantConnect.swift`, `Tests/SuiteModelTests/AssistantConnectTests.swift`, `Sources/AfterGlowCLICore/MCPConfig.swift`, `Tests/AfterGlowCLITests/MCPConfigTests.swift`, `Tests/mutations/SuiteModel.AssistantConnect.json` | CB-1, CB-2 | ~170, 5 |
| CB-3 | – | **Supervisor merge.** `scripts/bundle-apps` builds `afterglow` in release, copies it to `Contents/Helpers/afterglow`, signs it inside out with the helpers (ad hoc), and its verify step runs `afterglow --version` from the bundle; RJ-X62's job folder | `scripts/bundle-apps`, `docs/c4/parts/creative-apps/afterglow-bundle/container.json`, `Tests/RealJobs/suite/connect-assistant/connect-assistant.jobs.json` | CB-1 | ~80, 3 |
| CB-6 | – | Install Command-Line Tool…: an alert naming `~/.local/bin/afterglow`, Install or Cancel; Install makes the folder if needed and the symlink, refuses to replace a file that isn't our link and says why; render budget test; the journey on | `Sources/SuiteShell/InstallCommandLineTool.swift`, `UITests/AfterGlowJourneyTests+Connect.swift` | CB-5, CB-4 | ~120, 2 |
| CB-7 | – | RJ-X62's check enabled on the assembled bundle; suite.md 1.4 says the beta ships the CLI inside the app | `Tests/RealJobs/suite/connect-assistant/connect-assistant.jobs.json`, `docs/blueprints/suite.md` | CB-3, CB-6 | ~30, 2 |
| CB-8 | – | `status: built`; `feature-done` | `docs/blueprints/suite/features/cli-bundle.wave.json` | CB-7 | ~10, 1 |

## Build waves

- Wave 1: CB-1. Independent in this wave: CB-1 alone.
- Wave 2: CB-2, CB-5, CB-3. Independent in this wave: all.
- Wave 3: CB-5b, CB-4. Independent in this wave: both.
- Wave 4: CB-6. Independent in this wave: CB-6 alone.
- Wave 5: CB-7. Independent in this wave: CB-7 alone.
- Wave 6: CB-8. Independent in this wave: CB-8 alone.

Longest chain: CB-1 → CB-2 → CB-4 → CB-6 → CB-7 → CB-8 (6). Chain of 6: the path first, then the CLI verb, its bodies, the sheet's install, the job and the done task.

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| CB-1 | compiles, disabled by name; `BundleLayoutTests` (existing) still pass | a path the sheet or the bundle script reads is missing | – (stubs) |
| CB-2 | both specs list with their schemas | a command the sheet runs is missing | – (stub) |
| CB-5 | the item and the sheet's controls carry their ids; Copy puts the command on the pasteboard | a control has no id, or Copy copies the wrong text | – (view; render budget row) |
| CB-5b | `RenderBudgetConnectTests.openSheetInTwoBodies` | opening re-renders the window | – (budget) |
| CB-4 | `AssistantConnectTests`: a bundle path with a space is quoted; the JSON parses and names `mcp`; the plan for an existing foreign file is a refusal with its reason | an unquoted path, bad JSON, or an overwrite | `SuiteModel.AssistantConnect`: quoting dropped → `.pathWithSpaceQuoted`; foreign-file check skipped → `.neverOverwritesForeignFile` |
| CB-3 | `scripts/bundle-apps` on the macOS job; RJ-X62 (`Cm`) | the binary is missing, unsigned, or fails to start from the bundle | – (script; RJ-X62 holds it) |
| CB-6 | `XJ-CB` (Install into a temp home passed by `-SuiteHomeDir`) | it writes before the click, or overwrites someone else's file | – (AppKit glue; CB-4's plan covers the plan) |
| CB-7 | RJ-X62 green on macOS | the copied command doesn't connect | – (job) |
| CB-8 | `scripts/waves render --dry-run` | status not built | – |

## Quality tests

| quality row | budget | test |
|---|---|---|
| render: open the Connect sheet | ≤ 2 window bodies | `RenderBudgetConnectTests.openSheetInTwoBodies` |
| writes only where asked | nothing written before Install; never over a foreign file | `AssistantConnectTests`, `XJ-CB` |
| no dead controls | every sheet button does what it says | `AfterGlowHelpJourneyTests.testConnectAssistant` |
| bundle size | the CLI adds under 40 MB; the size gate's report shows it | `scripts/size-report` (existing) |

## Done check

Per slice (rules 6, 15, 17, 21, 22): CB-a and CB-m green (CB-3 on the macOS
job, merged by the supervisor); CB-u through the feel gate (`mouse`) with its
`Mac-Finish:` line; RJ-X62 green on macOS at CB-z. Then `Belt-Contact-Sheet:`.
