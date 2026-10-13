# creative-apps: agent instructions

This repo holds the macOS app shells of a free, open-source, Swift-native
creative suite: Flare (2D animation), Design (vector and UI design), Photo
(raster editing), Library (photo catalog) and Halo (motion graphics). The
engines live in [qbtrix/creative-core](https://github.com/qbtrix/creative-core).
Many agents work here at once; these rules keep that safe and fast. AGENTS.md
points here.

## You are writing SwiftUI blind

Cloud workers run on Ubuntu and cannot build SwiftUI. On Linux, Package.swift
declares only the Model targets, so `scripts/ci` there builds and tests the
Models alone. Everything under `Sources/*App/` and `Sources/SuiteUI/` is
compiled only by the `macOS` CI job. So:

- Put every bit of logic you can in the Model target, where you can test it.
- For UI, push and read the macOS job: `gh run list --branch <branch>` and
  `gh run view <id> --log-failed`. Fix, push, repeat.
- Look at what you built: the `macOS` job uploads the `snapshots` artifact
  (`gh run download <id> -n snapshots`), PNGs written by
  `Tests/AppSnapshotTests`. Open the ones your change touched.
- Watch it run: the `macOS` job also clicks through every app
  (`UITests/<X>JourneyTests.swift`) and uploads whole-window screenshots as
  `ui-screens` (`gh run download <id> -n ui-screens`). A user-facing feature
  adds or extends its app's journey test (docs/engineering.md, Human-like UI
  tests).

## Targets and lines

| Target | Builds on | What it is |
|---|---|---|
| `<X>Model` | Linux + macOS | View-model state and logic for app X. Foundation only; calls creative-core. |
| `<X>App` | macOS | The SwiftUI app: a window built from SuiteUI. Reads its Model, calls its methods. |
| `SuiteUI` | macOS | The shared design system: tokens, Liquid Glass primitives, the window shell. |
| `<X>ModelTests` | Linux + macOS | Model tests. |
| `SuiteUITests`, `AppSnapshotTests` | macOS | SuiteUI tests; the snapshot PNGs. |

X is Flare, Design, Photo, Library or Halo. Each app is one **line** (label
`line:flare`, ...) and SuiteUI is its own line (`line:suiteui`).

- **A line never edits another line's targets.** Flare work touches only
  `FlareModel`, `FlareApp` and their tests. SuiteUI work touches only SuiteUI
  and its tests.
- **A missing SuiteUI component:** file an issue on this repo labelled
  `needs-ui` and `line:suiteui` saying what you need, use a plain SwiftUI
  placeholder in your app, and keep going. Don't build the component in your
  app's target.
- **A missing engine feature:** file an issue on qbtrix/creative-core labelled
  `needs-core` with the API you need and an acceptance test. Keep going with
  what exists; never copy engine code into a Model.

## Start here

1. If you were given an issue, do that issue.
2. Otherwise pick the highest-priority open issue labelled `gap` on your line
   that is not labelled `in-progress` (`p1` before `p2`, then the lowest
   number). Add `in-progress` before you start:
   ```bash
   gh issue list --label gap --label line:flare --state open --json number,title,labels
   gh issue edit <n> --add-label in-progress
   ```

## The loop

1. **Orient.** Read this file, `docs/engineering.md`, the issue, and the code
   it touches. For UI work also read `docs/design.md`. If the issue depends on
   one that has not merged, pick another.
2. **Implement with tests.** Model behavior gets a Swift Testing test first. A
   view change gets its state into a snapshot in `AppSnapshotTests` if no
   existing snapshot shows it.
3. **Gate.** Run `scripts/ci` (on Linux it covers the Models). It must print
   `CI: PASS`. Then push and get both CI jobs green.
4. **Ship.** `git fetch origin && git rebase origin/main`, rerun `scripts/ci`,
   then open ONE small PR to `main` that closes the issue (`Closes #<n>`). Add
   the `fast-lane` label. List the snapshot PNGs your change touched in the PR
   body. Then stop.
5. Don't ask questions. If the issue is impossible as written, comment on the
   issue saying why, remove `in-progress`, and stop.

## Journeys first

An app is only useful once someone can do its core job from start to finish.
Each line's first `p1` issues make that loop work end to end:

1. Open a file or create a document.
2. See it on the canvas.
3. Edit it with each tool the palette shows.
4. Undo the edit.
5. Save it.

Polish and panels (layers, adjustments, history, effects, extra menus) come
after the loop works. When you file or rank issues for a line whose loop is
broken, the missing step goes first.

**No dead controls.** Every button, tool and menu item on screen does
something. One that can't act yet is disabled and says why:

- A toolbar or palette item gets `unavailableHelp` on its `ToolbarAction`.
  That text is its tooltip, and an action can't be disabled without it.
- A menu item that can't run gets a nil action, so the menu disables it.
- A palette tool acts through its Model's `drag(from:to:)`. Until that case
  does something, the tool's `unavailableHelp` says why. The PR that makes a
  tool work sets it to nil and wires the canvas gesture to `drag`.
- `<X>ToolsTests` in Photo's, Flare's and Design's Model tests fails when an
  enabled tool's drag on an open document changes nothing, or a disabled tool
  has no help. A new tool enum gets the same test.

## Rules

- **One behavior per PR.** Ideally under 200 changed lines, hard cap 400, at
  most 15 files.
- **Check current docs, not memory.** Before using any platform or library
  API (SwiftUI, AppKit, macOS 26 APIs, GRDB, Swift stdlib), check current docs
  with the docs MCP tools; don't rely on memory. If the tools are unavailable,
  say so in the PR body. `.mcp.json` provides them: `apple-docs`
  (`searchAppleDocumentation`, then `fetchAppleDocumentation`; Apple's
  developer docs, Swift stdlib and HIG, read live from developer.apple.com)
  and `context7` (`resolve-library-id`, then `query-docs`; SwiftUI is
  `/websites/developer_apple_swiftui`, AppKit `/websites/developer_apple_appkit`,
  GRDB `/groue/grdb.swift` and Swift `/swiftlang/swift`).
- **Every source file has a C4 owner.** `scripts/ci` fails when a file under
  `Sources/` is not in exactly one component's `paths` in `docs/c4/model.json`.
  Each target's folder is a component, so a new file in a target is covered;
  if it adds something that component's description doesn't mention, update
  the description in the same PR.
- **Views are dumb.** Files under `Sources/*App/` read their Model and call its
  methods; they never assign its state, bind to it, or mutate its collections.
  `scripts/ci` fails on that (the app-state rule). Model state is
  `public private(set)`; add a method when a view needs a new change.
- **System components first, then SuiteUI, never a look-alike.** Follow the
  Component order in `docs/design.md`; the design lint in `scripts/ci` fails
  on raw colors, fonts and sizes, hand-made glass and look-alike controls.
- **Every UI PR lists the snapshot PNGs it changed** in the PR body (for
  example `flare-open-light.png, flare-open-dark.png`), so the reviewer opens
  exactly those from the artifact.
- **Never crash.** `scripts/ci` fails on `try!`, `as!`, `fatalError(`,
  `preconditionFailure(`, `precondition(`, `unowned ` and `.first!` / `.last!`
  anywhere in `Sources/`. No unchecked indexing, no division by a value that
  can be zero.
- **Models stay Linux-safe.** No SwiftUI, AppKit, Combine, CoreGraphics or
  other Darwin-only API in a Model. When a Model needs Foundation, import it as
  `#if canImport(FoundationEssentials) import FoundationEssentials #else import Foundation #endif`.
  Swift 6 language mode. Value types, `Sendable`.
- **Every change gets a test.** Swift Testing (`import Testing`, `@Test`,
  `#expect`).
- **No new dependencies** without an issue that approves them.
- **PR title** in Conventional Commits (`feat(flare): onion skin toggle`). The
  body says what changed, why, and which test or snapshot proves it.
- **No AI attribution anywhere.** Commits, PR titles and bodies, and issue
  comments carry no `Co-Authored-By: Claude`, no `Claude-Session:` link and no
  "Generated with Claude Code" line. `.claude/settings.json` turns these off;
  if your tooling adds one anyway, delete it before you push. The fast lane
  also strips them from the squash commit.
- **No product names.** Don't name other companies' creative apps in code,
  docs or UI; describe the behavior instead.
- **Clean-room.** Never copy code, files, text or artwork from proprietary
  creative software or from GPL-incompatible sources. Behavior comes only from
  public documentation and specs. This repo is GPL-3.0.

## Quality

- `docs/engineering.md`: how code is laid out (Models, views, SuiteUI).
- `docs/design.md`: the look and behavior rules for every view.
- Before you open a PR, check your diff against `docs/review-rubric.md` and fix
  every "no".

## Parallel agents

- Keep to your line and your issue's files. Prefer a new file over appending to
  a shared one.
- Rebase on `main` before opening the PR, and rerun `scripts/ci` after.
- If `main` is red because of someone else's merge, do not fix it in your PR.
  Comment on your issue with the failing test name and stop.
- **Never edit** `Package.swift`, `.github/`, `scripts/` (including
  `scripts/ci`), `CLAUDE.md`, `AGENTS.md` or `LICENSE`. Every target already
  exists. If you think one of these must change, say so in an issue.

## Fast lane

A PR labelled `fast-lane` is merged automatically by
`.github/workflows/fast-lane.yml` when all of these hold: base `main`, author
on the allowlist in `scripts/fast-lane.sh`, at most 400 changed lines and 15
files, no protected path touched, mergeable, and every check green including
both CI jobs. Protected paths are the files above. UI code can take the lane
once both CI jobs are green; a human reviews the snapshots after merge and
files fixes as new issues. A Belt PR (its body has a `Belt-Run:` or
`Belt-Test:` line) also waits for Belt's `belt/review` commit status to be
success on its head; `REQUIRE_BELT_REVIEW` in `scripts/fast-lane.sh` turns
that off. Otherwise the label is removed with a comment saying why, and the PR
waits for review.

## Commands

```bash
scripts/ci                                   # lint + app-state rule + design lint + C4 ownership + jscpd + build + test: the gate
swift test --filter FlareModelTests          # one suite while iterating
bash Tests/fast_lane/test_fast_lane.sh       # fast-lane decision tests (needs jq)
gh run download <run-id> -n snapshots        # the PNGs from a macOS CI run
gh run download <run-id> -n ui-screens       # whole-window PNGs from the UI journeys
scripts/ui-test                              # macOS + Xcode + xcodegen: run the UI journeys locally
scripts/bundle-apps                          # macOS: release builds as signed FlareApp.app ... HaloApp.app in .build/apps; CI uploads them as `app-builds` (app-builds.tar.gz)
```
