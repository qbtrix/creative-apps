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
Models and runs the lints (app-state rule, design lint, C4, jscpd). Everything
under `Sources/*App/` and `Sources/SuiteUI/` is compiled only by the `macOS`
CI job, and that job runs on `dev` once a feature is built, not on your PR.
You never start it yourself for routine work. So:

- Put every bit of logic you can in the Model target, where you can test it.
- Keep view code small, follow `docs/design.md`, and copy the shape of a view
  that already builds. A UI mistake shows up in the next feature CI as a
  "dev is red" issue whose culprit range names your PR.
- The `macOS` job uploads the `snapshots` artifact (PNGs written by
  `Tests/AppSnapshotTests`) and clicks through every app
  (`UITests/<X>JourneyTests.swift`), uploading whole-window screenshots as
  `ui-screens`. Find a run with `gh run list --workflow ci.yml --branch dev`,
  then `gh run download <id> -n snapshots` or `-n ui-screens`. A user-facing
  feature adds or extends its app's journey test (docs/engineering.md,
  Human-like UI tests).

## Targets and lines

| Target | Builds on | What it is |
|---|---|---|
| `<X>Model` | Linux + macOS | View-model state and logic for app X. Foundation only; calls creative-core. |
| `<X>App` | macOS | The SwiftUI app: a window built from SuiteUI. Reads its Model, calls its methods. |
| `SuiteUI` | macOS | The shared design system: tokens, Liquid Glass primitives, the window shell. |
| `<X>ModelTests` | Linux + macOS | Model tests. |
| `SuiteUITests`, `AppSnapshotTests` | macOS | SuiteUI tests; the snapshot PNGs. |
| `AppAuditTests` | Linux + macOS | The app audit's checks and their tests (docs/blueprints/app-audit.md). |

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
2. **Branch from dev.** `git fetch origin && git switch -c <branch> origin/dev`.
   Never branch from or target `main`: it only takes `dev` SHAs that passed
   full CI.
3. **Implement with tests.** Model behavior gets a Swift Testing test first. A
   view change gets its state into a snapshot in `AppSnapshotTests` if no
   existing snapshot shows it.
4. **Gate.** Run `scripts/ci`. It must print `CI: PASS`. On Linux it covers
   the Model targets and the lints; the macOS job on `dev` catches the rest.
   It is your whole check: no CI runs on your PR, and you never start CI
   yourself for routine work (no `gh workflow run`).
5. **Ship.** `git fetch origin && git rebase origin/dev`, rerun `scripts/ci`
   (it must print `CI: PASS` again), push, then open ONE small PR to `dev`
   with `Closes #<n>`, the `fast-lane` label, the snapshot PNGs your change
   touches, and these two lines at the end of the body for the head you
   pushed:
   ```
   Fast-Check: pass
   Head: <full sha from git rev-parse HEAD>
   ```
   After every later push, rerun `scripts/ci` and update the `Head:` line to
   the new head; the lane ignores a marker for an older head. Then stop.
   ```bash
   # body.md: what and why, Closes #<n>, the PNGs, then the two lines for $(git rev-parse HEAD)
   gh pr create --base dev --label fast-lane --title "<type(scope): what>" --body-file body.md
   # after a later push, once scripts/ci passed on it: move the marker to the new head
   gh pr view <n> --json body --jq .body | sed "s/^Head: .*/Head: $(git rev-parse HEAD)/" >body.md
   gh pr edit <n> --body-file body.md
   ```
6. Don't ask questions. If the issue is impossible as written, comment on the
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
  the description in the same PR. The model is assembled from one file per
  component in `docs/c4/parts/` (`scripts/c4-assemble`): edit that part, or
  add a part for a new component, never the generated model.json.
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
  creative software or from GPL-incompatible sources. This repo is GPL-3.0.
  Behavior comes only from public documentation, published specs (W3C,
  Lottie, SVG, PDF, OpenRaster, XMP and the like) and code under a
  GPL-3.0-compatible license. Permissive code (MIT, Apache-2.0) may be studied
  and reused with attribution, after you read the license file of that exact
  repo at that exact commit; storytold's craft apps were MIT OR Apache-2.0 on
  2026-10-10. Record the source repo, commit and license in `NOTICE`, or in
  the header of the copied file.
- **Never reverse engineer an app we don't own.** No decompiling,
  disassembling, or inspecting its binaries or bundles, and no
  reverse-engineering tools or MCPs (REA, Hopper, Ghidra, IDA and the like).
  Don't automate or scrape competitors' apps either. Reverse engineering a
  file format so we can open users' files is a legal call: get the captain's
  sign-off first.

## Quality

- `docs/engineering.md`: how code is laid out (Models, views, SuiteUI).
- `docs/design.md`: the look and behavior rules for every view.
- Before you open a PR, check your diff against `docs/review-rubric.md` and fix
  every "no".

## Parallel agents

- Keep to your line and your issue's files. Prefer a new file over appending to
  a shared one.
- Rebase on `origin/dev` before opening the PR, and rerun `scripts/ci` after.
- If `scripts/ci` fails on `origin/dev` itself because of someone else's merge
  (look for the open `dev-red` issue), do not fix it in your PR. Comment on
  your issue with the failing test name and stop.
- **Never edit** `Package.swift`, `Package.resolved`, `.github/`, `.claude/`,
  `scripts/`, `CLAUDE.md`, `AGENTS.md` or `LICENSE` unless your issue says to,
  and never the generated `docs/c4/model.json` or
  `docs/blueprints/*/features/waves.md` at all: edit your component's part in
  docs/c4/parts/ or your feature's .wave.json, and the generated workflow
  rewrites them on dev.
  `scripts/` means all of it, the gate included. Every target already exists.
  If you think one of these must change, say so in an issue. The fast lane
  refuses exactly this list (PROTECTED in scripts/fast-lane.sh; its tests
  read this bullet), so every path here goes in backticks and nothing else.

## Feature leads

A session started from a `feature-lead` issue is a lead: it follows
`docs/factory/lead.md` (packet, build waves, Anatomy loop, contact sheet) and
its workflow templates in `docs/factory/workflows/`. Every PR a lead or its
agents open carries `Belt-Lead: <run id>` and `Feature: <feature>` lines
above the `Fast-Check:` / `Head:` lines. `Belt-Lead:` PRs don't wait for
`belt/review`; the lead's critic panel is their review.

## Fast lane

Crew PRs merge into `dev` at once; `main` moves only when full CI passes on
`dev`.

- `.github/workflows/fast-lane.yml` squash-merges a PR labelled `fast-lane`
  into `dev` when all of these hold: base `dev`, author on the allowlist in
  `scripts/fast-lane.sh`, at most 400 changed lines and 15 files, no protected
  path touched (the files above), mergeable, no red or running check on the
  head, and proof the head passed the gate: the `Fast-Check: pass` /
  `Head: <sha>` lines for the current head, or a passing CI check on it.
- A PR that changes or renames a shared shell file (`MAC_GATED` in
  scripts/fast-lane.sh: SuiteWindow, EditorShell, ToolbarGroup and Tokens in
  Sources/SuiteUI) also needs a completed CI run on its current head whose
  `macOS` job is green, or fails only tests that also fail in the latest
  completed dev run. You can't dispatch CI (403), so the lane does: once per
  head it runs `ci.yml` on your branch, comments the run URL, and merges on a
  later sweep when that run passes. A run with a new failure is refused by
  test name and waits for your next push. A `Mac-Check: <run url>` line a
  supervisor adds counts too.
- Any other PR changing Swift that Linux `scripts/ci` doesn't compile
  (`MAC_ONLY` in scripts/fast-lane.sh: `Sources/*App`, `Sources/SuiteUI`, `Sources/SuiteShell`,
  `Tests/SuiteUITests`, `Tests/AppSnapshotTests`, `UITests`, and
  `project.yml`; its tests derive the list from the manifests) merges only
  once its head compiles on macOS: the lane dispatches a build-only CI run
  (`ci.yml` with `build_only`: every target with its tests, then the journey
  bundles; nothing runs) once per head, comments its URL, and merges when it
  succeeds. A failed build waits for your next push.
- Otherwise UI code takes the lane on the Linux check alone. A human reviews
  the snapshots after the next feature CI and files fixes as new issues.
- Each lane run merges every eligible PR, oldest first. A PR that conflicts
  after an earlier merge gets one comment and waits for a rebase. A fast-lane
  PR opened against `main` is retargeted to `dev`.
- A Belt PR (its body has a `Belt-Run:` or `Belt-Test:` line) also waits for
  Belt's `belt/review` commit status to be success on its head;
  `REQUIRE_BELT_REVIEW` in `scripts/fast-lane.sh` turns that off.
- A PR that loosens the app audit (docs/blueprints/app-audit.md) raises a
  count in `UITests/audit-baseline.json` (an existing check's key that is new
  to an app counts as a raise from 0), adds an app there above 0, drops an
  app from it, removes or moves a file in `Checks/`, or drops an entry from
  `AppAudit.checks`. Lowering a count is fine, and so is adding a check with
  its starting counts in existing apps, at any count, when the same PR adds
  its file and registry entry.
- A count that falls doesn't fail the journeys, and you don't lower the
  baseline by hand: after a green macOS run on `dev`, CI's `Audit lower` job
  commits the measured counts to `UITests/audit-baseline.json` ("test(audit):
  lower baselines to the measured counts") straight onto `dev`. It only ever
  lowers; a count over its baseline fails instead.
- A PR that breaks a hard rule (author, size, protected path, a looser app
  audit) loses the label with a comment saying why and waits for review.
- Full CI (`Linux`, `macOS` with snapshots and the UI journeys) runs on `dev`
  once a feature is built, not per merge: when the supervisor or Belt
  dispatches it, when the lane merges a PR labelled `feature-done` or one
  touching `Sources/*App`, `Sources/SuiteUI`, `Tests/App*` or `UITests`, after
  every 10 merged PRs (at most once per lane run), and once a day. Green: `main` fast-forwards to that exact SHA. Red: one issue titled
  "dev is red" (label `dev-red`) names the failing jobs and the culprit range
  `main..<sha>`. SwiftUI breakage can sit on `dev` until that run, so the range
  can span several PRs. The lane keeps merging while the issue is open; the
  next green run moves `main` and closes it.

## Commands

```bash
scripts/ci                                   # lint + app-state rule + design lint + C4 ownership + jscpd + build + test: the gate
swift test --filter FlareModelTests          # one suite while iterating
bash Tests/fast_lane/test_fast_lane.sh       # fast-lane decision tests (needs jq)
bash Tests/audit_lower/test_audit_lower.sh   # decision tests for scripts/audit-lower, CI's baseline lowering (needs jq)
gh run list --workflow ci.yml --branch dev    # feature CI runs on dev
gh run download <run-id> -n snapshots        # the PNGs from a macOS CI run
gh run download <run-id> -n ui-screens       # whole-window PNGs from the UI journeys
scripts/ui-test                              # macOS + Xcode + xcodegen: run the UI journeys locally
scripts/contact-sheet                        # after ui-test: .build/ui-screens/contact-sheet.html, the page to review per run
scripts/bundle-apps                          # macOS: release builds as signed FlareApp.app ... HaloApp.app in .build/apps; CI uploads them as `app-builds` (app-builds.tar.gz)
```
