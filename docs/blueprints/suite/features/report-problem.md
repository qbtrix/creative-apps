# Feature packet: report-problem

**Feature:** a way for testers to tell us what broke. Help > **Report a
Problem…** builds a plain report: the app, its version and build, the macOS
version, the Mac model, and the newest AfterGlow crash files from
`~/Library/Logs/DiagnosticReports` (the last three of the suite's processes, at
most seven days old, each trimmed to its header and crashed thread). It shows
the report in a sheet with the person's own note on top, and offers Copy,
Save…, and Email… (the system's compose-mail service, so the person's own
mail app sends it). The app never opens a socket: nothing leaves the Mac unless
the person sends it. Help > **Beta Notes** lists the build's known issues.
SuiteModel builds both (Linux-tested, with a redaction rule for the home path,
the user name and the host name), SuiteShell shows them in one Help group, and
every item is a command in one small suite catalog (`help.report-problem`,
`help.beta-notes`), which the Help group builds its items from and the
`afterglow` CLI runs as app `suite` (`afterglow run suite help.report-problem`),
so an agent can attach the same report.
**Line:** `line:suite` · **Wave:** BG1 (`waves.md`, the beta gaps) · **Lead branch:** `lead/report-problem`
**Beta:** captain, 2026-10-21 (beta gaps, suite must-haves). Labels `beta` and `p1` when filed.

**Covers:** `2026-10-21-beta-gaps-combined.md` suite must-have "Help > Report a
Problem + Beta Notes (no network call; the person sends it)"; suite audit row
3; RJ-X65 (new).

**Depends on:** onboarding (built; owns `AfterGlowApp.swift` and the launcher's
Help item), afterglow-cli (built; `Apps.swift` registers the CLI's apps). `editor-menus` (this
wave) adds the Help group to the five editors; this packet adds it to the
launcher and builds it.

**Rule 20.** One report builder (`SuiteModel/Help/ProblemReport.swift`), one
notes list (`BetaNotes.swift`), one Help catalog (`SuiteKernel/Commands/SuiteHelpCatalog.swift`,
Foundation only: SuiteModel can't link the kernel, so the catalog reads the
report through a `HelpProviding` protocol that SuiteShell and the CLI adapt),
and one Help group (`SuiteShell/SuiteHelpCommands.swift`) that builds its items
with `MenuCommand(spec:)`. No app writes its own Help item, and command-state's
CS-2 extends the command-path scan to `Sources/SuiteShell` and the launcher, so a
bare Help item would fail CI.

**Privacy.** No `URLSession`, socket or `NSWorkspace.open` of a URL carrying
report text; Email… goes through `NSSharingService(named: .composeEmail)`,
which hands the text to the person's mail app unsent. `ProblemReportTests`
holds the redaction; the job's check holds the no-socket rule.

**C4:** new component part `suite-model/suite-help.json`
(`Sources/SuiteModel/Help/`; RP-1). The SuiteShell file sits in
`shell-adoption`.

**Clean-room.** Nothing external is read.

Blueprint sections: suite.md 6 (menus), 1.3 (privacy).

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| RP-a | SuiteModel declares the report builder and the beta notes and SuiteShell the Help group, as stubs, with the report's checks written and disabled. | RP-1, RP-2 | MJ-RP | – |
| RP-u | Report a Problem opens a sheet with a note field and the report, Copy, Save and Email work without the app sending anything, and Beta Notes opens a window with the known issues, within the render budget. | RP-3, RP-3e | XJ-RP | RP-a |
| RP-m | The report reads the newest suite crash files and redacts the home path, user and host, the suite Help catalog runs it and the beta notes in the CLI and the menus, and the feature is built. | RP-4, RP-5, RP-6, RP-7 | MJ-RP, XJ-RP | RP-a, RP-u |

**Screen early.** RP-a already puts the Help items in the launcher on the
stubs (RP-2), and RP-u builds the real sheet beside RP-m. The five editors
get the same group from `editor-menus`.

## Journey steps

`MJ-RP` on Linux (`ProblemReportTests`, `BetaNotesTests`, `SuiteHelpCatalogTests`, `HelpReportsTests`), then:
1. Launch AfterGlow with a fixture crash folder (`-SuiteCrashDir <path>`), Help > Report a Problem…: the sheet shows the app, version, macOS and the newest Photo crash with `~` for the home path; type a note; Copy; the pasteboard holds note plus report (RP-2, RP-3, RP-5; `XJ-RP`, `AfterGlowHelpJourneyTests.testReportAProblem`).
2. Help > Beta Notes opens the known-issues window; Close returns to Home.

## Jobs

| job | closes or adds | run | check | fixture |
|---|---|---|---|---|
| RJ-X65 | adds, closes with `suite/report-problem` | Cm | `Tests/RealJobs/suite/report-problem/`: `afterglow run suite help.report-problem` (app photo) against a fixture crash folder holding two Photo crashes, one Safari crash and one 10-day-old Halo crash, under a home named `/Users/tester` | the fixture folder |

Trap: the report leaks the tester's home path or user name, picks up another
app's crash, or the app phones home. Assertion: the JSON lists exactly the two
Photo crashes, newest first; no string `tester` or `/Users/` appears; and the
run opens no socket (the check runs it under `sandbox-exec` with network
denied and it still succeeds). Mutation: `SuiteModel.ProblemReport`
(`.redactsEveryOccurrence`, `.onlySuiteCrashes`). RP-5 writes the check.

## Screens and states

`suite-help-report` (note typed, report shown), `suite-help-beta-notes`.

## Contract slice

```swift
// Sources/SuiteModel/Help/ProblemReport.swift (RP-1 stubs, RP-4 bodies). Linux-safe.
public struct CrashFile: Hashable, Sendable { public var name: String; public var modified: Date; public var text: String }
public struct ProblemReport: Hashable, Sendable, Codable {
    public var app, version, build, macOS, model: String
    public var crashes: [String]                 // trimmed, redacted, newest first, at most 3
    public static func build(app: SuiteApp, version: String, build: String, macOS: String, model: String,
                             crashes: [CrashFile], now: Date, home: String, user: String, host: String) -> ProblemReport
    public func text(note: String) -> String     // the note, then the report, plain text
}
// Sources/SuiteModel/Help/BetaNotes.swift (RP-1, RP-4)
public enum BetaNotes { public static let current: [(title: String, detail: String)] }   // the build's known issues
// Sources/SuiteShell/SuiteHelpCommands.swift (RP-2, RP-3)
public struct SuiteHelpCommands: Commands { public init(app: SuiteApp) }
```

```swift
// Sources/SuiteKernel/Commands/SuiteHelpCatalog.swift (RP-1 specs, RP-5 bodies). Foundation only.
public protocol HelpProviding: Sendable {
    func report(app: String, note: String) -> JSONValue      // SuiteModel's ProblemReport, adapted
    func betaNotes() -> JSONValue
}
public struct SuiteHelpDocument: HeadlessDocument { public init(app: String, provider: any HelpProviding) }
public enum SuiteHelpCatalog { public static let catalog: CommandCatalog<SuiteHelpDocument> }
```

| id | title | params | unavailable when |
|---|---|---|---|
| `help.report-problem` | – (query) | `{app?, note?}` → the report | – |
| `help.beta-notes` | – (query) | – → the notes | – |
| `help.welcome` | – (opens the tour; launcher only) | – | not the launcher |

The ids go in a new ledger, `Tests/command-ids/suite.txt` (RP-1 adds it with the
three ids). The CLI runs them as `afterglow run suite <id>`.

## Pseudocode

- **Pick crashes.** List the crash folder; keep `.ips` (and `.crash`) files
  whose name starts with a suite process name (`AfterGlow`, `Photo`,
  `Design`, `Flare`, `Halo`, `Library`) and that are at most 7 days old;
  newest three by modified date.
- **Trim.** An `.ips` file is a JSON header line plus a JSON body: keep the
  header, the exception and the crashed thread's frames; drop the rest.
- **Redact.** Replace every occurrence of the home path, then the user name
  and the host name, case-insensitively, in the whole text, after trimming.

## Tasks

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| RP-1 | – | **Checks first.** `ProblemReportTests`, `BetaNotesTests` and `SuiteHelpCatalogTests` written, disabled (`waits on RP-4`); `ProblemReport` (fields, `build(app:system:crashes:home:user:host:)`, `text`), `CrashFile`, `BetaNotes.current` as stubs; `SuiteHelpCatalog` with `HelpProviding` and the `help.report-problem`, `help.beta-notes` and `help.welcome` specs (real ids and schemas, runs throwing `NotBuilt`); the C4 part | `Sources/SuiteModel/Help/ProblemReport.swift`, `Sources/SuiteModel/Help/BetaNotes.swift`, `Sources/SuiteKernel/Commands/SuiteHelpCatalog.swift`, `Tests/SuiteModelTests/ProblemReportTests.swift`, `Tests/SuiteModelTests/BetaNotesTests.swift`, `Tests/SuiteKernelTests/SuiteHelpCatalogTests.swift`, `Tests/command-ids/suite.txt`, `docs/c4/parts/creative-apps/suite-model/suite-help.json` | – | ~230, 7 |
| RP-2 | – | `SuiteHelpCommands(app:)` built from `SuiteHelpCatalog` with `MenuCommand(spec:)` over a `ShellHelpProvider`: Help > Report a Problem…, Beta Notes, and (launcher only) Welcome to AfterGlow, replacing the system's empty app help item; the launcher adds it in place of its Welcome group; `AfterGlowHelpJourneyTests` written, skipped until RP-5 | `Sources/SuiteShell/SuiteHelpCommands.swift`, `Sources/SuiteShell/ShellHelpProvider.swift`, `Sources/AfterGlowApp/AfterGlowApp.swift`, `Sources/AfterGlowApp/LauncherCommands+Onboarding.swift`, `UITests/AfterGlowJourneyTests+Help.swift` | RP-1 | ~170, 5 |
| RP-3 | – | SuiteUI `ProblemReportSheet` (note field, read-only report, Copy, Save…, Email…, Close) and `BetaNotesView`; the Help group opens them on the stub report; render budget test | `Sources/SuiteUI/ProblemReportSheet.swift`, `Sources/SuiteUI/BetaNotesView.swift`, `Sources/SuiteShell/SuiteHelpCommands.swift`, `Tests/AppSnapshotTests/RenderBudgetHelpTests.swift` | RP-2 | ~220, 4 |
| RP-3e | – | Email… hands the note and report to `NSSharingService(.composeEmail)` with the subject "AfterGlow <app> <version> problem"; Save… writes a `.txt` where the person picks; neither touches the network | `Sources/SuiteShell/ProblemReportActions.swift` | RP-3 | ~90, 1 |
| RP-4 | – | `ProblemReport` and `BetaNotes` bodies: pick the newest three `.ips` files whose process is a suite app, at most 7 days old; keep each one's header and crashed thread; replace the home path with `~` and the user and host names with `<user>` and `<host>`; turns on both suites | `Sources/SuiteModel/Help/ProblemReport.swift`, `Sources/SuiteModel/Help/BetaNotes.swift`, `Tests/SuiteModelTests/ProblemReportTests.swift`, `Tests/SuiteModelTests/BetaNotesTests.swift`, `Tests/mutations/SuiteModel.ProblemReport.json` | RP-1 | ~220, 5 |
| RP-5 | – | `SuiteHelpCatalog` bodies; the CLI registers it as app `suite` with a `HelpReports` provider (`afterglow run suite help.report-problem --params '{"app":"photo"}'`), turning on `SuiteHelpCatalogTests`; the live crash folder reader in SuiteShell feeds the sheet; `AfterGlowHelpJourneyTests` on; RJ-X65's job folder | `Sources/SuiteKernel/Commands/SuiteHelpCatalog.swift`, `Tests/SuiteKernelTests/SuiteHelpCatalogTests.swift`, `Sources/AfterGlowCLICore/Apps.swift`, `Sources/AfterGlowCLICore/HelpReports.swift`, `Sources/SuiteShell/CrashFolderReader.swift`, `Tests/AfterGlowCLITests/HelpReportsTests.swift`, `UITests/AfterGlowJourneyTests+Help.swift`, `Tests/RealJobs/suite/report-problem/report-problem.jobs.json`, `Tests/mutations/SuiteKernel.SuiteHelpCatalog.json` | RP-4, RP-3 | ~200, 6 |
| RP-6 | – | The help part names its callers (the Help group, the CLI) | `docs/c4/parts/creative-apps/suite-model/suite-help.json` | RP-5 | ~15, 1 |
| RP-7 | – | `status: built`; `feature-done` | `docs/blueprints/suite/features/report-problem.wave.json` | RP-6, RP-3e | ~10, 1 |

## Build waves

- Wave 1: RP-1. Independent in this wave: RP-1 alone.
- Wave 2: RP-2, RP-4. Independent in this wave: both.
- Wave 3: RP-3. Independent in this wave: RP-3 alone.
- Wave 4: RP-3e, RP-5. Independent in this wave: both.
- Wave 5: RP-6. Independent in this wave: RP-6 alone.
- Wave 6: RP-7. Independent in this wave: RP-7 alone.

Longest chain: RP-1 → RP-2 → RP-3 → RP-5 → RP-6 → RP-7 (6). Chain of 6: the stubs before the Help group, the group before the sheet, the sheet and the rules before the CLI and the journey, then the done tasks.

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| RP-1 | compiles, disabled by name | a signature the sheet or the CLI calls is missing | – (stubs) |
| RP-2 | the launcher's Help menu lists the three items with their ids; Welcome still opens the tour | the system's empty help item stays, or Welcome is lost | – (view) |
| RP-3 | `RenderBudgetHelpTests.typeNoteInTwoBodiesEach`; the sheet's controls carry `suite.help.report.<control>` ids | typing re-renders the window, or a control has no id | – (view; render budget row) |
| RP-3e | the email service is asked with the text and no recipients beyond the beta address; the saved file equals the sheet's text | the app sends anything itself | – (AppKit glue; RJ-X65 holds the no-socket rule) |
| RP-4 | `ProblemReportTests` (fixture crash files): only suite processes, newest first, at most three, none older than 7 days; no `/Users/<name>`, user or host string survives anywhere in `text`; a report with no crashes says so | a foreign app's crash or a private path leaks into the report | `SuiteModel.ProblemReport`: redaction only on the first occurrence → `.redactsEveryOccurrence`; age filter dropped → `.onlyRecentCrashes`; process filter dropped → `.onlySuiteCrashes` |
| RP-5 | `HelpReportsTests`; `XJ-RP`; RJ-X65 on macOS (`Cm`) | the CLI's report differs from the sheet's, or the journey can't open the sheet | – (glue; RP-4's plan covers the rules) |
| RP-6 | `scripts/c4-assemble --check` | the part names no caller | – |
| RP-7 | `scripts/waves render --dry-run` | status not built | – |

## Quality tests

| quality row | budget | test |
|---|---|---|
| render: typing a note in the report sheet | ≤ 2 window bodies per keystroke | `RenderBudgetHelpTests.typeNoteInTwoBodiesEach` |
| privacy | the report is built and shown with the network denied | RJ-X65 (`sandbox-exec`, network denied) |
| no dead controls | every Help item opens something | `AfterGlowHelpJourneyTests` |
| keyboard parity | every sheet button reachable by Tab; ⌘C copies the report | `AfterGlowHelpJourneyTests` |

## Done check

Per slice (rules 6, 15, 17, 21, 22): RP-m green on Linux with `Mutate:` clean;
RP-a and RP-u through the feel gate (`mouse`: open, copy, close by mouse) with
their `Mac-Finish:` lines; RJ-X65 green on macOS at RP-m's merged-done. Then
`Belt-Contact-Sheet:`.
