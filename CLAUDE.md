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
under `Sources/*App/` and `Sources/SuiteUI/` is compiled only on macOS: by
the fast lane's batch gate before your PR lands (scoped to the batch's apps),
and by the full `macOS` job on `dev` once a feature is built. Neither runs
for your PR alone, and you never start one yourself for routine work. So:

- Put every bit of logic you can in the Model target, where you can test it.
- Keep view code small, follow `docs/design.md`, and copy the shape of a view
  that already builds. A UI mistake the batch gate catches comes back as
  `needs-fix` on your PR; one only the full run sees shows up in the next
  feature CI as a "dev is red" issue whose culprit range names your PR.
- The `macOS tests K/N` jobs upload the `snapshots-K` artifacts (PNGs written
  by `Tests/AppSnapshotTests`; `macOS` is the gate job over them), and the report-only `macOS journeys` job (its
  own workflow, journeys.yml, which each CI run on `dev` dispatches) clicks
  through every app (`UITests/<X>JourneyTests.swift`), uploading
  whole-window screenshots as `ui-screens`. Find a run with `gh run list --workflow ci.yml --branch dev`
  (`--workflow journeys.yml` for the journeys), then `gh run download <id> -p 'snapshots-*'`
  (`-n ui-screens` from a journeys run). A user-facing
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

creative-core is pinned to one commit: `revision:` in Package.swift, recorded
in the committed Package.resolved. You build against that commit, not core's
main. The pin moves only through a bump PR from `scripts/bump-core [<core sha>]`
("chore(core): bump creative-core to <sha>", the core range and a link to each
core PR in its body), which runs every Model test target and the brush perf
suites first. Both files are protected, so the supervisor runs the macOS job on
the bump and merges it. `scripts/ci` fails when the two files disagree.

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
  what exists; never copy engine code into a Model. A merged core feature
  reaches the apps only through a bump PR (`scripts/bump-core`, merged by the
  supervisor), so start work that uses the new API once that bump is on `dev`.

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
4. **Gate.** Run `scripts/ci --changed`. It must print `CI: PASS`. It runs
   every lint and builds every target (a shared change can break any app),
   then runs only the tests of the targets your branch touched since
   `origin/dev`: `Sources/<X>Model` runs `<X>ModelTests`, `Sources/<X>App`
   that app's `AppSnapshotTests` suites, `SuiteUI` `SuiteUITests`,
   `SuiteModel` every Model's tests, and `Package.swift` all of them
   (`scripts/test-scope` holds the table). Plain `scripts/ci` is the full
   gate CI runs. Neither runs the perf and timing tests in
   `Tests/perf-suites.txt`: they run nightly on the captain's Mac
   (perf-nightly), never in CI. On Linux it covers the Model targets and the lints; the
   macOS job on `dev` catches the rest.
   It is your whole check: no CI runs on your PR, and you never start CI
   yourself for routine work (no `gh workflow run`).
5. **Ship.** Push, then open ONE small PR to `dev`
   with `Closes #<n>`, the `fast-lane` label, the snapshot PNGs your change
   touches, and these two lines at the end of the body for the head you
   pushed:
   ```
   Fast-Check: pass
   Head: <full sha from git rev-parse HEAD>
   ```
   After every later push, rerun `scripts/ci --changed` and update the `Head:` line to
   the new head; the lane ignores a marker for an older head. Then stop.
   ```bash
   # body.md: what and why, Closes #<n>, the PNGs, then the two lines for $(git rev-parse HEAD)
   gh pr create --base dev --label fast-lane --title "<type(scope): what>" --body-file body.md
   # after a later push, once scripts/ci --changed passed on it: move the marker to the new head
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
  most 15 files. A PR that only changes `docs/` has no cap (Fast lane).
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
  Each target's folder is a component, so a new file in a target is covered
  and needs no C4 edit. Don't touch an existing part's `description`: it is
  one string, and two PRs that append to it always conflict, so
  `scripts/ci --changed` fails a PR that changes one unless the PR adds a
  part or changes nothing outside `docs/c4/parts/` (a C4-only refresh). The
  model is assembled from one file per component in `docs/c4/parts/`
  (`scripts/c4-assemble`): edit that part's `paths`, or add a part with its
  own description for a new component, never the generated model.json.
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
  `#expect`). In a v3 slice, a mutation that breaks the change must also
  fail that test: add 2 or more to the plan of the file you change in
  `Tests/mutations/` and run `scripts/mutate --plan <plan>` until each is
  caught (docs/factory/lead.md, contract rule 14).
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
- `docs/render-contract.md`: how a canvas draws (one GPU route, no CPU work per step); read it before touching a canvas, overlay or render route.
- Before you open a PR, check your diff against `docs/review-rubric.md` and fix
  every "no".

## Parallel agents

- Keep to your line and your issue's files. Prefer a new file over appending to
  a shared one.
- Run `scripts/install-merge-drivers` once per clone (cloud-setup.sh does): a
  rebase then merges `.json` files key by key (`.gitattributes`), so two PRs
  adding different keys to one C4 part, `.wave.json` or mutation plan no
  longer conflict.
- Don't rebase on `origin/dev` for drift. A PR that is behind merges as it is,
  and one that conflicts is integrated by the fast lane (it merges dev into
  your branch with the merge drivers and checks the result). Only a PR
  labelled `needs-rebase` comes back to you: merge `origin/dev` into your
  branch, resolve the files the lane named, rerun `scripts/ci --changed`,
  push, and move the `Head:` line. After the lane has pushed to your branch,
  fetch before you push again.
- If `scripts/ci` fails on `origin/dev` itself because of someone else's merge
  (look for the open `dev-red` issue), do not fix it in your PR. Comment on
  your issue with the failing test name and stop.
- **Never edit** `Package.swift`, `Package.resolved`, `.github/`, `.claude/`,
  `scripts/`, `.gitattributes`, `CLAUDE.md`, `AGENTS.md` or `LICENSE` unless your issue says to,
  and never the generated `docs/c4/model.json`,
  `docs/blueprints/*/features/waves.md` or `docs/blueprints/*/jobs.md` at all:
  edit your component's part in docs/c4/parts/, your feature's .wave.json or
  the app's jobs.json, and the generated workflow rewrites them on dev. Only
  the supervisor edits the test quarantine, `UITests/quarantine.json`, with
  one narrow exception: the fast lane adds and removes its own entries there
  (a lane-quarantine PR from its bot on lane/quarantine that changes that
  file and nothing else; Fast lane below), and only the supervisor edits
  the perf list the gate skips,
  `Tests/perf-suites.txt`.
  `scripts/` means all of it, the gate included. Every target already exists.
  If you think one of these must change, say so in an issue. The fast lane
  refuses exactly this list (PROTECTED in scripts/fast-lane.sh; its tests
  read this bullet), so every path here goes in backticks and nothing else.

## Feature leads

A session started from a `feature-lead` issue is a lead: it follows
`docs/factory/lead.md` and its workflow templates in `docs/factory/workflows/`.
A packet with a `## Slices` table runs the v3 loop: the lead never waits on
CI or critics, builds the slices wave after wave (the first slice, the
contract others plug into, first), critics review a slice once a scoped run
(`ci.yml` with `app=<app>`) shows its screens, and each done slice gets a
`Belt-Slice-Done:` comment before the closing `Belt-Contact-Sheet:`. A packet
without one runs the v2 loop in lead.md, unchanged. In both, work started
after v3 landed files critic findings as `finding` issues that each wave
fixes first (no new feature wave past 5 open), with at most 2 fix rounds
before the rest become `gap` issues. Every PR a lead or its agents open
carries `Belt-Lead: <run id>` and `Feature: <feature>` lines, plus
`Slice: <slice>` for a v3 packet, above the `Fast-Check:` / `Head:` lines.
`Belt-Lead:` PRs don't wait for `belt/review`; the lead's critic panel is
their review. A PR with a
`Feature:` line never closes a `feature-lead` issue: before the squash the
fast lane reads the labels of each issue its closing keywords point at
(close, fixes, `Resolved:` and the rest, any case) and turns the keyword
before a `feature-lead` issue into `Refs`. Its other closing references,
such as the critic findings and gaps it fixes, stay and close on merge. An
issue whose labels the lane can't read keeps its keyword, isn't closed, and
gets one comment on the PR.

## Fast lane

Crew PRs merge into `dev` at once; `main` moves only when full CI passes on
`dev`.

- `.github/workflows/fast-lane.yml` squash-merges a PR labelled `fast-lane`
  into `dev` when all of these hold: base `dev`, author on the allowlist in
  `scripts/fast-lane.sh`, at most 400 changed lines and 15 files, no protected
  path touched (the files above), mergeable, no red or running check on the
  head, and proof the head passed the gate: the `Fast-Check: pass` /
  `Head: <sha>` lines for the current head, or a passing CI check on it.
  A head with neither and no check at all gets a Linux-only CI run from the
  lane (`ci.yml` with `linux_only`), once per head, and merges when it
  passes. A fork's PR doesn't.
- A PR whose every changed path is under `docs/` (packets, blueprints and
  their `.wave.json` feature data, `docs/c4/parts/`, any `.md` there) takes
  the lane at any size. It needs the same proof, and that proof is
  `scripts/ci` on its head, which renders the waves and assembles the C4
  parts with the ownership check. Protected paths under `docs/` stay refused,
  and one file outside `docs/`, a rename included, brings the size cap back.
- A PR that changes code (`BUILD_RE` in scripts/fast-lane.sh: a `.swift`
  file under `Sources/`, `Tests/` or `UITests/`, `project.yml`, or
  `Package.swift`), a Model included, lands only after its batch passes the
  macOS gate (below). Linux `scripts/ci` never builds the apps, and it misses
  macOS-only breaks in the targets it does build (#1210: an `ObjCBool` error
  in PhotoModel). Nothing runs on macOS for your PR alone, and you never
  start it. A PR with no code (docs, data, packets) needs no macOS gate.
- The rollback, `LANE_MAC_PER_PR=1` (a repo variable, read by
  `.github/workflows/fast-lane.yml`), restores the per-PR build: once per head
  the lane dispatches a build-only CI run (`ci.yml` with `build_only`, scoped
  by `app` to the apps your code touches, `scripts/test-scope build-apps`;
  shared code builds everything), comments its URL, and merges when it
  compiles; a failed build waits for your next push. A `Mac-Check: <run url>`
  line a supervisor adds counts too. Batches then check Linux only.
- Verify after merge, `LANE_VERIFY_AFTER=1` (a repo variable, off by
  default): a code PR lands on its own as soon as its head has the Linux
  proof above and a green `local-ci/prescreen` status (the supervisor's
  pre-screen on the Mac), with no batch and no macOS run, also while `dev`
  is red; without the pre-screen it waits. A proof `dev` moved under (a
  ratchet or baseline change) is checked again on today's `dev` first.
  While a `dev-red` issue is open, the lane reverts the culprit
  PR, the one the dev bisect names or the only PR in the issue's range. It
  opens a `lane-revert` PR from `lane/revert-<n>` and lands it on its own
  Linux check, then runs CI on `dev`. Your merged PR's feature-lead issue
  (or the PR) gets a comment saying why and how to bring the change back
  (a new PR that reverts the revert, plus the fix), and a `finding` is filed
  for your app. One revert per `dev-red` issue, never a revert of a revert.
  A real red the lane has no certain culprit to revert for (an inconclusive
  bisect, a culprit on a protected path, a revert that didn't fix it) gets
  its failing tests quarantined instead, so trunk never stops: one
  `Quarantined: <id>` issue per test (`p0`, `finding`, `line:<app>`, naming
  the run, the range's PRs and their leads, and a 24 h expiry) owns the fix,
  and a `lane-quarantine` PR from `lane/quarantine` adds the entries to
  `UITests/quarantine.json` (the one protected path the lane may change
  itself: that file alone, on that branch, by the lane's bot) and lands on
  its own Linux check; `scripts/ci` then skips those tests and dev's next
  run is green. Past the expiry the issue is a `blocker`; the entry stays
  until the issue closes, when the lane's PR removes it (red again: the issue
  is reopened). Never more than 5 tests per sweep, never a security, billing
  or auth test. `scripts/quarantine release` fails while a lane entry is in.
  Details: `docs/fast-lane.md`.
- A crew PR into `dev` whose body has a `Belt-Lead:` line but no `fast-lane`
  label gets the label from the lane's next sweep, with one comment, and is
  evaluated in that sweep under the same rules. `no-fast-lane` or
  `needs-human` on the PR stops it (`OPT_OUT_LABELS` in scripts/fast-lane.sh).
- Ready PRs land in batches, ordered `p0`, then `beta`, then the rest,
  oldest first within each. The lane merges `dev` plus up to 12 ready PRs
  (`LANE_BATCH_MAX`), in order, onto a scratch `lane/batch-<id>` branch (merge
  drivers on) and runs one Linux-only CI run on it. When the batch has code it
  also runs one macOS gate (`ci.yml` with `mac_only`: `scripts/ci` on macOS
  scoped to the union of the batch's apps by `scripts/test-scope build-apps`,
  every app for shared code; no journeys). A green `macOS` job or a
  `local-ci/macos` commit status on the batch head (the local Mac gate) is the
  macOS pass. When both are green it squash-merges every PR in that order.
  A lone PR without code lands at once; a lone code PR is a batch of one. A
  batch with code forms when a macOS slot frees (a batch just resolved), when
  12 PRs are ready, or once the oldest ready head is 10 minutes old
  (`LANE_BATCH_WAIT_MIN`), and never while the lane's own queued and running
  macOS runs fill `LANE_MAC_SLOTS` (4). On red it bisects the batch by prefix
  (`lane/batch-<id>-<i>` probes, each with its Linux run and, for code, its
  macOS gate; when the red tip fails only a timing budget test on Linux, each
  probe's Linux run goes up to 3 times and is called on 2 of 3) until it finds
  the first PR that turns the chain red: the PRs before it merge, that PR gets
  one comment naming the failing job, its run and any open PRs stacked on its
  branch, and the `needs-fix` label (the comment says "likely" when the
  measured value sat within 15% of its budget), and the PRs after it wait for
  the next batch. Fix it, rerun `scripts/ci --changed`, push, and move the
  `Head:` line; the lane drops the label on the new head. When `dev` alone is
  red on every job the batch is red on, the batch lands on each PR's own proof
  so a fix can get through; a job red only with the batch is still bisected.
  A new `dev-red` first gets its run's failed jobs rerun once at the same
  sha (the lane's flake check): a pass is a flake, which files a `finding`
  labelled `flaky` for the test and holds nothing; a failure makes the red
  real. While a real `dev-red` issue names a job a batch would run (Linux
  always, macOS when the batch has code), ready PRs that touch the failing
  module (its test target's `Tests/<X>Tests/` and `Sources/<X>/`) wait and
  the rest batch as usual; when the lane can't place the red, no new batch
  forms and every ready PR waits. A
  batch already in flight on a base that holds the red commit is marked
  (`lane/batch-<id>-red`); once `dev` is green again on a newer commit the
  lane drops it and its probes, with no label or comment on its PRs, and
  forms a fresh batch on today's `dev` in the same sweep. How the script
  does all of this: `docs/fast-lane.md`.
  One batch runs at a time; a PR that becomes ready while one is in flight
  waits for the next sweep (a few minutes). A PR that is behind
  `dev` merges as it is. A PR that conflicts is integrated by the lane: in a
  scratch clone it merges `origin/dev` into the PR branch with the repo's
  merge drivers (`.gitattributes`, from main, which is why that file is
  protected), pushes the merge commit to the branch, starts a Linux-only CI
  run (`ci.yml` with `linux_only`) on it, and merges on a later sweep when
  that run passes. The old `Head:` marker no longer matches, by design: the
  Linux run is the proof for the integrated head, and a code PR still lands
  only through its batch's macOS gate. A conflict the drivers can't resolve gets one
  comment naming the files and the `needs-rebase` label; a fixer merges dev,
  resolves, pushes, and the lane drops the label. A fast-lane PR opened
  against `main` is retargeted to `dev`.
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
  baseline by hand: after a full journeys run on `dev` passes, journeys.yml's `Audit lower` job
  commits the measured counts to `UITests/audit-baseline.json` ("test(audit):
  lower baselines to the measured counts") straight onto `dev`. It only ever
  lowers; a count over its baseline fails instead.
- A PR that breaks a hard rule (author, size outside the docs tier, protected
  path, a looser app audit) loses the label with a comment saying why and
  waits for review.
- Full CI (`Linux`; `macOS`: `macOS compile` then the `macOS tests K/N`
  shards, scripts/ci with the snapshots) runs on `dev`
  once a feature is built, not per merge: when the supervisor or Belt
  dispatches it, when the lane merges a PR labelled `feature-done` or one
  touching `Sources/*App`, `Sources/SuiteUI`, `Tests/App*` or `UITests`, after
  every 10 merged PRs (at most once per lane run), and once a day. Green
  (`Linux` and `macOS`): `main` fast-forwards to that exact SHA. A red journey
  files a `finding` issue and holds nothing. Red: one issue titled
  "dev is red" (label `dev-red`) names the failing jobs and the culprit range
  `main..<sha>`. SwiftUI breakage can sit on `dev` until that run, so the range
  can span several PRs. The lane keeps merging while the issue is open; the
  next green run moves `main` and closes it. While it is open the lane also
  bisects the range for the first red commit: `ci/bisect-<sha>-<i>` branches
  each get a Linux-only run (red-triage's confident guess first, at most 8
  runs per red), and the verdict lands as a comment on the `dev-red` issue
  and on the owning feature-lead issue (the PR body's `Feature:` line).
- The report-only UI journeys run in their own workflow,
  `.github/workflows/journeys.yml` (job `macOS journeys`, `macOS journeys
  (<app>)` when scoped; artifact `ui-screens`; Findings and `Audit lower`),
  dispatched by ci.yml's last job, `Journeys dispatch`, once a full or scoped
  CI run on `dev` has finished its gate jobs (a full run: every journey; a
  scoped run: that app's; a Linux check, build-only run or macOS gate: none).
  It is a dispatch, not a workflow_run trigger, because CI runs the lane
  starts with GITHUB_TOKEN fire no workflow_run. Its run is titled `after CI
  run <id>: journeys <app|full> at <sha>` and checks out the commit that CI
  run tested. Its concurrency group is
  `journeys-<branch>-<app|full>`, so a journeys job waiting for a macOS
  runner never holds `ci-dev`. A running journeys run is never cancelled;
  only the newest pending run of each scope waits. Its `Journeys wait` job
  (scripts/journeys-wait) holds the run on ubuntu until no CI run is queued
  for a macOS runner and fewer than two older journeys runs are alive, so
  journeys hold at most two macOS runners and the lane's gate goes first; a
  run a newer one of its scope supersedes cancels itself. On a branch, or to ask for one by hand: `gh workflow
  run journeys.yml --ref <branch> [-f app=<app>]` (findings and the audit
  baseline move only on `dev`).
- A scoped run proves one app: `gh workflow run ci.yml --ref dev -f
  app=<flare|design|photo|library|halo|suite|suiteui>`. It still builds every
  target and app bundle, then runs only that app's Model
  tests and snapshot tests (titled `scoped: <app>`, job `macOS (<app>)`;
  about 10 min for Design), and on `dev` its `Journeys dispatch` job starts that app's
  journeys (`macOS journeys (<app>)` in journeys.yml; on a branch, dispatch
  journeys.yml with `-f app=<app>` yourself). It skips the Linux job and never promotes `main`,
  opens `dev-red` or lowers the audit baseline. The supervisor's
  verify-dispatch.sh starts one per app after that app's merges.
- A journey that keeps failing on `dev` for a known reason can be quarantined,
  by the supervisor only, in `UITests/quarantine.json`: entries of
  `{"test": "Target/Class/testName", "owner": "#<open issue>", "reason": ..., "expires": "YYYY-MM-DD", "scope": "all"|"full"}`,
  at most 7 days out. A swift test goes in the same file as
  `Target.Suite/test` or `Target.freeTest` (the `Tests/perf-suites.txt`
  form) and `scripts/ci` skips it; the fast lane's own entries carry a
  `lane` block (Fast lane above). `scope` is optional: `all` (the default) skips the
  journey in every run; `full` skips it only in full runs, so a full run can
  go green and promote `main` while the owner's scoped run (`app=<app>`)
  still runs it and shows the truth. `scripts/ui-test` skips each live entry
  that applies and lists every entry, with where it is skipped, in its output
  and the job summary. `scripts/ci` fails on an expired entry, a closed or
  missing owner issue, an empty reason, a scope other than `all` or `full`, or
  a test that isn't in `UITests/` or `Tests/`. When the owner's fix merges, the
  supervisor removes the entry and the next `dev` run proves it (the lane
  removes its own once the owner issue closes).

## Commands

```bash
scripts/ci                                   # lint + app-state rule + design lint + C4 ownership + jscpd + mutation anchors + build + test: the gate
scripts/mutate --plan DesignModel.LiveMarquee # plant each bug in that plan (Tests/mutations/) and require a test to fail; prints the score
scripts/mutate --validate                    # every plan's `find` occurs exactly once (no build; scripts/ci runs it)
scripts/ci --changed [base]                  # the same lints and build, then only the touched targets' tests (base: origin/dev)
swift test --filter "$(scripts/test-scope perf photo)" --no-parallel   # Photo's perf and timing tests, which the gate skips
swift test --filter FlareModelTests          # one suite while iterating
bash Tests/fast_lane/test_fast_lane.sh       # fast-lane decision tests (needs jq)
bash Tests/audit_lower/test_audit_lower.sh   # decision tests for scripts/audit-lower, CI's baseline lowering (needs jq)
scripts/quarantine check                     # the test quarantine's entries: owned, reasoned, unexpired (needs jq; gh for owner state)
scripts/quarantine release                   # the release gate: fails while the fast lane's own quarantine entries are in
bash Tests/quarantine/test_quarantine.sh     # scripts/quarantine's fixture tests (needs jq)
scripts/bump-core [<core sha>]               # move the creative-core pin (default: core main's head): checks, then the bump PR
bash Tests/bump_core/test_bump_core.sh       # scripts/bump-core against a fake gh and swift (needs jq)
scripts/install-merge-drivers                # once per clone: .gitattributes merge drivers (JSON by key) and rebase.updateRefs; cloud-setup.sh runs it
bash Tests/merge_drivers/test_merge_drivers.sh # the merge drivers on scratch repos (needs git, jq)
gh run list --workflow ci.yml --branch dev    # feature CI runs on dev
gh run list --workflow journeys.yml          # the UI journeys runs that follow them
gh run download <run-id> -p 'snapshots-*'    # the PNGs from a CI run's macOS test shards
gh run download <run-id> -n ui-screens       # whole-window PNGs from a journeys.yml run
scripts/ui-test                              # macOS + Xcode + xcodegen: run the UI journeys locally
scripts/contact-sheet                        # after ui-test: .build/ui-screens/contact-sheet.html, the page to review per run
scripts/bundle-apps                          # macOS: release builds as signed FlareApp.app ... HaloApp.app in .build/apps; CI uploads them as `app-builds` (app-builds.tar.gz)
```
