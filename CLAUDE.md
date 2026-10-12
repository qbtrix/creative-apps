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
   the `fast-lane` label. UI PRs are refused by the lane and wait for a human;
   that is expected. Then stop.
5. Don't ask questions. If the issue is impossible as written, comment on the
   issue saying why, remove `in-progress`, and stop.

## Rules

- **One behavior per PR.** Ideally under 200 changed lines, hard cap 400, at
  most 15 files.
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
both CI jobs. Protected paths are the files above plus all UI code:
`Sources/*App/` and `Sources/SuiteUI/`, because a human must look at the
snapshots. Model and test PRs can take the lane. Otherwise the label is
removed with a comment saying why, and the PR waits for review.

## Commands

```bash
scripts/ci                                   # lint + app-state rule + design lint + jscpd + build + test: the gate
swift test --filter FlareModelTests          # one suite while iterating
bash Tests/fast_lane/test_fast_lane.sh       # fast-lane decision tests (needs jq)
gh run download <run-id> -n snapshots        # the PNGs from a macOS CI run
```
