# Feature lead playbook

A **lead** is one cloud session that takes 1 to N features of one app line
(3 by default) from their packets to merged, verified features: a line lead
(contract rule 19). Belt starts it from the features' `feature-lead` issues.
The lead plans the work, runs a swarm of builder agents that each open one
small PR, has critics review the screens, has fixers fix what they find, and
ends each feature with its contact sheet.

The lead is an orchestrator. It writes plans, prompts and RECORD.md, not
feature code. Builders and fixers write code. The fast lane merges. Nobody
merges into `dev` by hand, and no agent ever merges.

Everything in CLAUDE.md still holds for every agent the lead starts: lines,
dumb views, Linux-safe Models, the no-crash lint, one behavior per PR.

## Which loop

Look for a `## Slices` table in the packet.

- **With one (v3).** The lead runs a pipeline: builders open PRs wave after
  wave; critics review each slice's screens as soon as a scoped CI run shows
  them and file what they find as issues; each new wave takes the open
  findings first. The builder never waits on CI or critics. A slice is done
  (merged-done) once its tasks have merged and dev's Linux job is green with
  them, and the feature ends with the contact sheet once every slice is done.
  Journeys, the feel gate and the Mac finish verify it later, in a
  beta-hardening lane that never blocks the lead. This page's Stages (v3) and RECORD.md (v3).
- **Without one (v2).** The loop in "Packets without slices (v2)" at the end
  of this page, unchanged except that its first two waves follow contract
  rule 18 (stub the UI's Model calls, then the UI on the stubs beside the
  logic): build waves, then Anatomy rounds on dev CI, then the contact sheet.

The findings queue (contract rule 10) and the round cap (rule 11) apply to
both loops, but only to work started after this contract landed: a lead
whose RECORD.md `Started:` is earlier than PR #1302's merge
(`gh pr view 1302 --json mergedAt`) keeps the loop it started with.

## The lead contract

Hand this to every session (the lead and each agent it starts) verbatim.

Until beta, CI blocks only on compile and Model tests (captain, 2026-10-16).

1. **Feature issue.** One GitHub issue per feature, labels `feature-lead` and `line:<app>`. Body links the packet `docs/blueprints/<app>/features/<feature>.md` and has one `Depends on:` line.
2. **Run.** Belt runs one cloud session (a line lead, rule 19) per group of 1 to N feature issues on the same `line:<app>` (N is 3 by default); the run owns that list and its brief lists every issue under `Features:`. It runs from the trusted launch folder, with the repo's Auto settings (creative-apps#733, creative-core#263). A lead holds one in-flight slot however many features and PRs it has.
3. **Status channel.** For each of its features, the lead pushes `docs/leads/<feature>/RECORD.md` and `timeline.tsv` to that feature's branch `lead/<feature>` after every stage (in v3, after every wave and every check between waves). Belt reads the branch's last commit time; nothing else is polled besides PRs and issue comments.
4. **Swarm PRs.** Base `dev`, label `fast-lane`, at most 400 lines and 15 files. Body lines: `Belt-Lead: <run id>`, `Feature: <feature>`, for a packet with slices `Slice: <slice>` (the slice ids the PR serves, comma separated), then `Fast-Check: pass` and `Head: <full sha>` after `scripts/ci --changed` passes (lints, every target built, the touched targets' tests; plain `scripts/ci` is the full gate). Point at the feature issue with `Refs`; the lane turns a closing keyword before a `feature-lead` issue into `Refs` anyway and never closes it. Findings and gaps a PR fixes take a closing keyword (`Fixes #n`) and close on merge. The lane merges them. Nobody merges into dev by hand or by an agent.
5. **Review policy (decision for the captain).** `Belt-Lead:` PRs do not need the `belt/review` status. The lead's own critic panel is the review. Only `Belt-Run:` and `Belt-Test:` PRs keep it.
6. **Done (v3), two levels.** Slices are the unit of done. Leads never wait on macOS runs. **Merged-done:** every task of the slice has merged, and the newest CI run on dev that contains the slice's last merged PR has a green `Linux` job (every Model built and its tests run; a scoped run has no Linux job, a full run does, and its Linux result shows long before its macOS job ends). Each code PR already compiled on macOS through the lane's build-only run and carries its full `Mutate:` score (rule 14), so nothing else is waited on. The lead then comments on the feature issue, one comment per slice, with the line `Belt-Slice-Done: <slice> <run url>`. When every slice has its line (the last PR, labelled `feature-done`, is in the last slice), the lead comments `Belt-Contact-Sheet: <run url>`. **Verified:** the slice's journeys ran green in a scoped or full run (a quarantined journey is skipped, not green; one quarantined for full runs only still runs in a scoped run), no `finding` issue for it is open, and a slice marked `"ui": true` passed the feel gate (rule 15) and has its `Mac-Finish:` line (rule 17). That belongs to the beta-hardening lane, never blocks the lead or the slice line, and ends with the finisher's comment `Belt-Slice-Verified: <slice> <run url>`, or ` gaps: #<n> #<m>` at its end for a slice closed under the round cap (rule 11). A red journey reaches the lead as a `CI finding: <Target/Class/test>` issue labelled `finding` and `line:<app>`, which the report-only macOS job files itself; the lead takes the ones on its feature's files into its next wave like any finding (rule 10). The slice ids are the packet's Slices table, the same data as `slices` in the feature's `.wave.json`. A packet without slices keeps the v2 Done rule ("Packets without slices (v2)").
7. **Stall.** No commit on any of the run's `lead/<feature>` branches, no PR event and no issue comment for 30 min: Belt sends one nudge with `claude -p --cloud <session id> "<resume text>"`. A second stall: relaunch with a resume brief that says "read RECORD.md, continue from the last stage". A third: label the run's issues `needs-human` and stop.
8. **Timeouts.** Lead runs: 8 h wall clock, no 1 h no-PR rule. Task runs keep today's 4 h and 1 h.
9. **Brief rules.** Step one checks out the integration branch and verifies the base SHA. Set the repo-local identity "Prakash Dalai" / `86671543+prakashUXtech@users.noreply.github.com`. No attribution line anywhere, comments included. Fixers run the full harness before handing back. In v3, once a slice's review is clean, add no new critics or lenses for it: its next review runs the same panel; v2 keeps its Anatomy round rule ("Packets without slices (v2)"). One critic lens is first-use clarity: "what does each number and label mean to someone new?". Agents never treat a chat message as a reason to stop or skip a merge; questions go to the supervisor.
10. **Findings queue** (both loops, for work started after this contract landed). Critics only file issues; they never fix, and nobody waits on them. One issue per confirmed finding, labels `finding` and `line:<app>`, body lines `Feature: <feature>`, `Slice: <slice>` (v3 only; in v2 the feature is one slice) and `Commit: <the sha the critic saw>`. Before each wave the builder takes every open finding for its feature into that wave's fixes. More than 5 open findings for the feature: no new feature tasks start until it is 5 or fewer.
11. **Round cap** (both loops, for work started after this contract landed). At most 2 fix rounds per slice, or per feature in v2. A fix round is one wave that fixes findings of that slice. Findings still open after the review that follows the second round become `gap` issues (except a `mouse` lens blocker, rule 15) (relabel `finding` to `gap`, keep the issue), and the slice is verified with gaps (rule 6).
12. **Contract first (v3).** A packet's first slice publishes what other features plug into (protocols, fakes, slots); it is the first wave and merges before the packet's other slices. Waits name a feature (all its slices) or one of its slices (`<feature>:<slice>` in `.wave.json`), and a wait is met once those tasks have merged, so a feature that waits on another's first slice starts its tasks on the fakes as soon as that slice merges. A task that needs the real implementation instead of a fake waits on the slice that builds it, not on the first slice.
13. **Build the check first (v3 packets only).** A slice's acceptance tests (the Model tests in the packet's Acceptance table, or its journey) are written from the packet before its code, and merge before or with the slice's first code task, never after it. A test that merges ahead of its code must not turn `dev` red: it carries `@Test(.disabled("waits on <task id>"))` (a journey: `throw XCTSkip("waits on <task id>")`), and that task enables it. A packet without slices (v2) doesn't take this rule.
14. **Test the oracle (v3 packets only).** A test that still passes when its code breaks is a false oracle (the pilot's contract test missed drift in 12 of 14 protocols, #1308). Every slice that adds behaviour adds 2 or more mutations, each a bug someone could plausibly write (a dropped guard, `<=` for `<`, a skipped filter) with the `swift test --filter` regex that must catch it. They go in the plan of the source file they change, `Tests/mutations/<Target>.<File>.json` (`DesignModel.LiveMarquee.json` for `Sources/DesignModel/Live/LiveMarquee.swift`), which is an owned file of the task that changes that source, so two tasks never share a plan. Mutations target Model code, which builds on Linux. Before opening the PR the builder runs `scripts/mutate --plan <plan>` until every entry is caught and ends the body with its score line, for example `Mutate: 5/5 DesignModel.LiveMarquee`. An escape is a missing test: add the test that catches it; drop the entry only when the change can't alter behaviour. A slice isn't done while any mutation of its plans escapes (rule 6). `scripts/ci` fails when a plan's `find` no longer occurs exactly once, so a task that refactors planned code repoints the plan in the same PR. A packet without slices (v2) doesn't take this rule.
15. **Feel gate (v3 slices marked `"ui": true`).** Part of the Verified level (rule 6): it belongs to the beta-hardening lane and never blocks the lead or the slice's `Belt-Slice-Done:` line. Journeys prove a control exists, not that it feels right (lesson 154: no way back from Library's loupe, Halo lag, a basic Design canvas, all "done"). A UI slice is verified only when all three hold. (a) **Render budget:** its real-window render budget test passes. That is the app's `Tests/AppSnapshotTests/RenderBudget*` suite on the SuiteUI harness, which hosts the shipped window, drives synthetic input and counts window bodies, against the packet's render budget row (`packets.md`, Slices). Count budgets ("120-sample drag ≤ 3 window bodies") run in the scoped run and gate verification. Time budgets ("divider drag p95 ≤ 8 ms") are reported, not gated (`docs/engineering.md`, Tests), so the Mac finisher checks them on a release build (rule 17). (b) **Mouse-only first-time user:** the critic panel's `mouse` lens finds nothing open: every new screen can be entered and left with the mouse, every control shows hover and pressed states, and nothing is reachable only by a shortcut. A screen you can't leave with the mouse is a blocker and never becomes a gap under rule 11. (c) **Taste:** the panel's `taste` lens compares the slice's snapshots with the taste board, `docs/design/taste` in paw-workspace when the session can read it. A cloud session can't, so it judges against the suite's reference look, Flare's easing style with `StudioScrubRow` and `ChoiceChips`, and the Mac finisher checks the board. Pass `ui: true` to the critic panel from the slice's first review, which turns on both lenses; adding them after a clean review breaks rule 9. Builders read `docs/engineering/swiftui-rules.md` before any UI task.
16. **SuiteUI first (both loops).** A UI fix or pattern that more than one app needs goes in SuiteUI, as a task on the SuiteUI line or a `needs-ui` issue (CLAUDE.md), never as a copy in each app. The critic panel's `design` lens flags an app-local view that copies a SuiteUI component or another app's pattern, and the fix moves it to SuiteUI.
17. **Mac finishing (v3 slices marked `"ui": true`).** Part of the Verified level (rule 6), in the beta-hardening lane; the lead never waits on it. Cloud leads can't compile SwiftUI, so they build the Model and draft the UI. A slice marked `"ui": true` in its feature's `.wave.json` gets a local Mac finisher pass before it is verified. Once the slice is merged-done, the lead comments `Mac-Finish-Wanted: <slice> <run url>` on the feature issue and moves on. The finisher, a session on the local Mac with Xcode, checks out `origin/dev`. It builds the apps, renders the snapshots, runs the render budget tests and times the budget row's time budgets on a release build, then profiles the real window during real input (`sample <pid> 20 1`, lesson 132). It checks every `Unverified API:` line in the slice's PR bodies against Xcode's documentation, and the taste board (rule 15c). It fixes what it finds in fast-lane PRs with the slice's `Slice:` line and runs a scoped run on them. Then it comments `Mac-Finish: <slice> <dev sha>`, or `Mac-Finish: <slice> <dev sha> gaps: #<n>` with the issues it filed and didn't fix. When the rest of the Verified level holds on a run that contains its fixes, it also posts the slice's `Belt-Slice-Verified:` line. Finisher PRs don't count against the round cap (rule 11).
18. **UI and logic in parallel (both loops).** The captain sees each feature on screen within hours, while it can still be steered, not last after its Model (on 2026-10-16, 127 PRs merged and 12 added anything visible, because features ran contract, fakes, Model, then screen). After the contract slice (rule 12: protocols, fakes, slots, control ids), a feature runs two tracks as parallel waves. The **UI slice** (`"ui": true`) builds the feature's real screen on the contract's fakes, clickable end to end; its waits name no slice of its own feature but the contract slice (another feature's slices are fine). Its first PR makes the feature reachable from a visible control, a menu item or a toolbar button, on the fakes. The **logic slices** build the real Model and the live services; they wait on the contract slice and never on the UI slice. A last **integrate** step, in a slice that waits on both tracks, swaps the fakes for the live services and runs the journeys on live. **Contract widening:** a UI task can't compile against a Model signature only a logic slice adds (the re-slice found that in every Design feature), so the contract slice declares every Model signature the feature's UI calls, as stubs: a stub returns the fake's value, or `NotBuilt` with a reason the UI shows. The logic slices fill those bodies in and never change the signatures. When a packet's contract slice doesn't declare them (every v2 packet and most v3 ones today), the lead's first UI task is "declare the stubs the UI needs", a small task; once it merges, the UI tasks and the logic tasks run in parallel. A v2 packet takes the rule the same way: its first two waves are "stub the UI's Model calls", then "UI on the stubs" beside the logic. A feature with no screen (Model only) says `"ui_slice": "none"` in its `.wave.json`, with its reason in `"ui_slice_reason"`. `scripts/waves check` warns about a feature that isn't built and has neither; the supervisor makes the warning an error once the open packets are re-sliced. The macOS gate is build-only (rule 6): journeys report `finding` issues and never hold up a UI slice's PRs, which merge on a green Linux build.
19. **Line lead (the default).** A lead takes 1 to N features of one app line at once (N is 3 by default), every issue labelled the same `line:<app>`, each issue's body linking its packet. Its brief lists them under `Features:`, one `#<n> <title> <packet path>` per line. The lead makes one combined wave plan across its features: tasks of different features share a wave when `scripts/waves check` allows it (it refuses two features, or two slices that can run at once, owning one file). Each wave is one `build-wave.js` call with every feature's tasks, and `critic-panel.js` runs per feature slice. The bookkeeping stays per feature: each keeps its own `lead/<feature>` branch and `docs/leads/<feature>/RECORD.md`, its own findings count (rule 10), its own `Belt-Slice-Done:` lines and contact sheet on its own issue, and its PRs keep their `Feature:` and `Slice:` lines (one feature per PR). When one feature blocks, the lead keeps going on the others and says so on that feature's issue and in its RECORD's `Open`.

## What you can and can't do here

- **Linux builds the Models only.** `scripts/ci` builds and tests the Model
  targets and runs the lints. SwiftUI under `Sources/*App/` and
  `Sources/SuiteUI/` compiles only on macOS: the lane's build-only run for
  each code PR, and the report-only `macOS` CI job on `dev`.
- **You can't dispatch CI** (the API answers 403). Two kinds of run come to
  you. A **scoped run** (`ci.yml` with `app=<app>`, titled `scoped: <app>`,
  job `macOS (<app>)`: builds every target, app bundle and journey bundle,
  then runs only that app's Model tests, snapshots and journeys; about 10
  minutes for Design) is started by the supervisor's verify-dispatch.sh after
  merges to your app; its screens feed reviews and the Verified level. A **full run**
  is dispatched by the lane, at most once per lane run, after it merges a PR
  labelled `feature-done`, a PR touching `Sources/*App`, `Sources/SuiteUI`,
  `Tests/App*` or `UITests`, or the 10th merged PR since the last CI run. A
  full run covers every app, so it counts as a scoped run for yours, and its
  `Linux` job is the one merged-done reads (rule 6). The macOS job in both
  is report-only: it never turns a run red.
- **Code must compile on macOS.** A PR changing any `.swift` file under
  `Sources/`, `Tests/` or `UITests/`, or `project.yml`, Models and shared
  shell files such as `SuiteWindow.swift` included,
  merges only once a build-only macOS run compiled its head (lesson 114;
  #1097; #1210 broke the macOS build from PhotoModel, which Linux compiled).
  The lane dispatches it, comments the URL, and merges when it builds; a
  failed build waits for your next push.
- **You can read runs.** `gh run list --workflow ci.yml --branch dev --json
  databaseId,headSha,status,conclusion,displayTitle,url` (a scoped run's
  `displayTitle` is `scoped: <app>`), then `gh run download <id> -n ui-screens` (whole-window PNGs,
  `contact-sheet.html`, `audit-*.json`) and `-n snapshots`; or the GitHub MCP
  `actions_*` and `get_job_logs` tools. A run contains a PR when
  `git merge-base --is-ancestor <merge sha> <run head sha>` succeeds.
- **You can read the findings queue.** Before you file the first finding
  yourself, make sure the label exists:
  `gh label create finding --color D93F0B --description "Critic finding a feature lead fixes" --force`.
  ```bash
  gh issue list --label finding --label line:<app> --state open --limit 200 --json number,title,body \
    --jq '.[] | select(.body | test("(^|\n)Feature: <feature>\r?(\n|$)")) | "\(.number)\t\(.title)"'
  ```
- **Worktrees start from the default branch,** not from `dev` or your base.
  Every agent's first step checks out `origin/dev` and verifies the base SHA
  (pilot lesson). The templates do this for you.

## Stages (v3)

For a packet with a `## Slices` table. A line lead (contract rule 19) runs
stages 0, 1 and 4 and the per-feature steps of 3 for each feature in its
brief's `Features:`, and makes one plan (2) and one run of waves (3) for all
of them. Push each feature's RECORD.md and a `timeline.tsv`
line to its `lead/<feature>` at the end of every stage, after every wave and
every check, and at least every 20 minutes
while you poll, so Belt never reads a quiet lead as a stall.

### 0. Set up

1. `git fetch origin dev && git rev-parse origin/dev`. That SHA is the base.
2. Set the repo-local identity (contract rule 9).
3. If `origin/lead/<feature>` exists, this is a resume: check it out, read
   RECORD.md and continue from its last stage. Otherwise create `lead/<feature>`
   from the base and write RECORD.md from the template below.
4. Check the waits of each slice (the `waits` in the feature's
   `.wave.json`; contract rule 12). A wait on another feature's slice is met
   once its tasks have merged: that slice's `Belt-Slice-Done:` line on its
   issue, its RECORD.md on `origin/lead/<dep>` showing it `merged` or `done`,
   or the issue closed. If no task of a packet can start yet, comment so on
   that feature's issue and record it; stop only when no feature in the
   brief can start.

### 1. Read the packet

Read the packet `docs/blueprints/<app>/features/<feature>.md` (its shape and
rules are in `docs/factory/packets.md`), the app's
blueprint, `docs/engineering.md`, `docs/engineering/swiftui-rules.md` (for any
UI slice), `docs/design.md`, `docs/review-rubric.md` and the code the tasks
touch. Copy the packet's slices, tasks, journeys and quality bars into
RECORD.md. A task that needs another line's code becomes a
`needs-ui` or `needs-core` issue (CLAUDE.md), not a task.

### 2. Plan waves

Take the waves from the packet's Build waves section (`packets.md`, rule
(c)) and check them against the code as it is now, and merge every
feature's waves into one plan (contract rule 19). Each packet's first
slice is in wave 1 (contract rule 12). After it, the UI slice and the logic
slices run as parallel waves: the UI slice waits only on the contract slice,
and its first task puts the feature behind a visible menu or toolbar control
on the fakes (rule 18). If the contract slice doesn't declare every Model
signature the UI calls, the first UI task declares them as stubs, and the
UI and logic tasks start in parallel once it merges. A wave is a set of tasks that touch disjoint
files and don't depend on each other's unmerged code. Each task gets: an id,
its slice, one behavior, the files it may touch, the test that proves it,
the 2 or more mutations that test must catch when it adds behaviour and the
plan they go in (contract rule 14), the snapshot or journey step it adds
when it changes what the user sees, and a size estimate under 400 lines and
15 files. Split anything bigger. Each slice's acceptance tests are in its
first code task or a task before it, never a later one (rule 13). A slice
whose tasks change `Sources/*App/` or `Sources/SuiteUI/` is a UI slice: its
`.wave.json` slice says `"ui": true` and the packet has its render budget row
(`packets.md`, Slices). If either is missing, the slice's first task adds
it, and that task owns the render budget test (rules 13 and 15).

A task waits on another only when it needs that task's merged code
(`packets.md`, rule (b)). Shared prose (`docs/design.md`, the blueprint,
the app's `waves.in.md`) goes in the one final task (rule (a)). The C4 model
and `waves.md` are generated: a task that adds a component adds its part in
`docs/c4/parts/` in the same PR as its code, and no task edits
`docs/c4/model.json` or a `waves.md` (`packets.md`, "Fragments, not shared
files"). If the packet chains tasks that don't need each other, unchain
them and record it under Decisions. For every wave, RECORD.md lists which
tasks are independent and, for each task that waits on another, which one
and why.

### 3. Waves and the Anatomy loop

The builder never waits on CI or critics. It runs waves back to back and
reads CI and findings between them, never by blocking on them. The Anatomy
loop (CI, audit, screenshots, critics, fixers) runs per slice beside the
builders: review, findings, a fix round in the next wave, review again, at
most 2 rounds (contract rule 11).

**Between waves: the check** (minutes, every time):

1. `git fetch origin dev`. The new `origin/dev` SHA is the next wave's
   base. Record it.
2. **CI.** Find the newest CI run on dev whose `Linux` job has finished.
   For each slice whose tasks have all merged, note whether that run
   contains its last merged PR and its Linux job is green (rule 6). A red
   Linux job: read its log; a failure in the feature's files is a finding
   (contract rule 10), others go to the open `dev-red` issue. The macOS job
   is report-only: list your line's open `CI finding:` issues (rule 6) and
   take those in the feature's files like any finding, but never wait for a
   macOS run to finish. Read the newest scoped or full run's
   `audit-<app>-*.json` and the contact sheet's audit table: a count over
   your app's baseline goes to the panel's audit lens.
3. **Reviews.** A slice is ready for review when a run contains its last
   merged PR and that run's `ui-screens` has its journey screens, and no
   review has run on it since that PR merged. For each ready slice, download
   that run's `ui-screens` and `snapshots` into your scratchpad and queue a
   critic panel (`critic-panel.js`) for this wave, with the run, its head
   sha, the slice's journeys, the feature's open findings, and `ui: true` for a
   UI slice (the `mouse` and `taste` lenses, rule 15). A Linux-only slice
   (a Model walk, no screens) gets no panel.
4. **Findings.** List the feature's open findings (the queue command
   above) and count them.
5. **Done.** Post `Belt-Slice-Done:` for each slice that is now merged-done
   (contract rule 6). A UI slice also gets its `Mac-Finish-Wanted:` comment
   (rule 17) once. For a slice past its 2 fix rounds whose last review has
   run, relabel its open findings `gap` (rule 11); the finisher's
   `Belt-Slice-Verified:` line names them. Red journeys, the feel gate and
   the Mac finish never hold a slice's `Belt-Slice-Done:` line.

**Then start the next wave:**

1. **Fixes.** Every open finding of the feature goes in, except findings
   of a slice that has used its 2 rounds. Each slice that gets a fix counts
   one round in RECORD.md.
2. **Feature tasks.** With 5 or fewer open findings, add the next tasks
   whose waits are met (their tasks merged, contract rule 12). With
   more than 5, the wave is fixes only.
3. **Run it.** One call to `docs/factory/workflows/build-wave.js` with
   every feature's tasks for the wave as `tasks`, and the fix batch (`fix-batch.js`) and the
   queued critic panels as `alongside`, so builders, fixers and critics run
   at once. A finding whose files a feature task of this wave owns waits for
   the next wave (fix-batch's `busy`). With only 1 or 2 tasks and nothing
   alongside, one subagent per task with `isolation: "worktree"` (also the
   fallback if Workflow is unavailable), started together. Run subagents
   one after another only for tasks that truly depend on each other;
   RECORD.md says which ones and why, one line each under Decisions.
4. **Merge.** Nobody rebases onto `dev` for drift: a PR that is behind
   merges as it is, and one that conflicts is integrated by the lane (it
   merges dev into the branch with the merge drivers, runs the Linux check
   on the result and merges). Only a PR the lane labels `needs-rebase`
   (comment names the files), or comments red or not eligible, goes back to
   its builder or a fixer: merge `origin/dev` into the branch, resolve the
   named files, rerun `scripts/ci --changed`, push, move the `Head:` line.
   Once the wave's PRs have merged, run the check and start the next wave.

Every fixer runs the full harness before it hands back: `scripts/ci --changed` until
`CI: PASS`, plus a test that fails before the fix, and the journey step or
snapshot that shows it when it is visible. A layout finding gets a geometric
test (frames inside the window, no overlap, minimum sizes): the pilot's
geometric test caught what 62 journeys missed.
An oracle finding (a mutation that escapes) is fixed by the test that
catches it plus that mutation in the file's plan, with a full `Mutate:`
score (rule 14).

**Nothing left to build.** When every remaining task waits on another
feature, or every task has merged and the slices wait only on a Linux job
that contains them, poll: run the check every 10 minutes, push a `heartbeat`
line, and keep RECORD.md's `Next:` naming the CI run you wait for, for
example `Next: wait for a CI run on dev whose Linux job contains #1312`, or
Belt reads a `Next:` that names CI as waiting, not as a stall. Never wait on
a macOS run, a review or a Mac finish: once every slice has its
`Belt-Slice-Done:` line, post the contact sheet (stage 4), write
`Next: beta-hardening lane verifies <slices>`, push RECORD.md and stop. The
finisher posts each slice's `Belt-Slice-Verified:` line.

### 4. Finish

1. The feature's final task carries the `feature-done` label (the shared
   prose, the packet's status line, or the RECORD summary in the packet). It
   marks the feature built in its own data only:
   `docs/blueprints/<app>/features/<feature>.wave.json` gets
   `"status": "built"` and the feature issue; the Generated workflow
   reprints `waves.md` on `dev`. It belongs to a slice like any other task,
   so that slice's done check covers it.
2. When every slice has its `Belt-Slice-Done:` line, comment on the feature
   issue: `Belt-Contact-Sheet: <run url>` (the newest run that contains
   every slice's last PR), then one line per slice with its run and gaps,
   one line per journey, and the audit counts.
3. Push the final RECORD.md and stop.

## RECORD.md (v3)

`docs/leads/<feature>/RECORD.md` on `lead/<feature>`. Rewrite it in place;
the timeline keeps the history. A relaunched lead reads only this file.
Belt parses the `Stage:` and `Next:` lines and the Tasks table (its `id` and
`files` headers), so keep those names.

```markdown
# <feature> lead record

Issue: #<n> · Packet: docs/blueprints/<app>/features/<feature>.md
Run: <Belt run id> · Session: <session id> · Started: <UTC time>
Stage: <0 setup | 1 packet | 2 plan | 3 wave <k> | 3 polling | 4 finish | done>
Base: <origin/dev SHA the current wave started from>
Next: <the one thing a resumed lead does first>

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |

## Reviews
| slice | run | commit | lenses | filed | after round |

## Decisions
- <what you chose and why, one line each>

## Open
- <blockers, needs-ui/needs-core issues, gap issues filed>
```

A slice's `state` is `building`, `merged` (all its tasks merged, no green
Linux job with them yet), `done` (its `Belt-Slice-Done:` line is posted),
then `verified` or `verified-with-gaps` once the finisher's
`Belt-Slice-Verified:` line is in. `mac finish` holds the `Mac-Finish:` sha,
or `wanted` once you asked.

`docs/leads/<feature>/timeline.tsv`: one appended line per event, tab
separated, header `utc	stage	event	ref	note`, for example
`2026-10-14T09:12Z	3	pr-opened	#741	task m1 HaloModel keyframe store`.
Events: `stage-start`, `stage-end`, `pr-opened`, `pr-merged`, `ci-run`,
`review`, `finding-filed`, `fix-round`, `slice-done`, `slice-verified`,
`heartbeat`, `stopped`.

## Workflow templates

In `docs/factory/workflows/`. Copy them into your scratchpad, run one with
`Workflow({scriptPath, args})`, and resume a broken run with
`resumeFromRunId`. Each file's header lists its `args`.

Each template serves both loops and picks its path from its args, as its
header says: v3 args carry slices; v2 args for work started before this
contract landed are the same as they always were.

| Template | Stage | Does |
|---|---|---|
| `build-wave.js` | 3 | One builder per task in its own worktree, one PR each, then a checker that reads every PR against the contract. A task with a `slice` gets the `Slice:` line. With `alongside`, it runs those workflows (a fix batch, critic panels) at the same time. |
| `critic-panel.js` | 3 (v3), 4 (v2) | One critic per lens over the screens and the audit, then a verifier per finding that tries to refute it. With `issue` (the findings queue) it files each confirmed finding as a `finding` issue, scoped to `slice` when given, and returns the issue numbers. Without it (v2 work started before), it returns `clean` and the confirmed findings for an inline fix round. |
| `fix-batch.js` | 3 (v3), 4 (v2) | With `findings` (issue numbers), reads the open `finding` issues and groups them into batches with disjoint files. With `batches` (v2 work started before), takes the batches as given. Then one fixer per batch in its own worktree, full harness, one PR each. |

## Packets without slices (v2)

A packet with no `## Slices` table runs this loop. The two contract rules,
the stages and the RECORD.md below are the v2 text as it was, unchanged; the
other contract rules above hold too, except rule 12. For work started after
this contract landed (see Which loop), rules 10 and 11 change two things:

- **Findings queue.** Pass the critic panel `issue`, `commit` and the
  feature's open findings as `open` (no `slice`): it files each confirmed
  finding as a `finding` issue with `Feature:` and `Commit:` lines and no
  `Slice:` line. The round's fix batch takes those issues (`findings`)
  instead of a list you group by hand. The panel first runs after the last
  wave, so the pause past 5 open findings doesn't come up.
- **Round cap.** At most 2 fix rounds for the feature, in place of "2 clean
  rounds or 4 rounds in total". After the review that follows the second
  round, relabel the feature's open findings `gap` and finish.

Contract rule 18 holds for v2 too, for work started after it landed: in
Plan waves below, the first wave is one small task that declares, as stubs,
every Model signature the UI calls, and the second wave builds the UI on
those stubs beside the logic tasks, which never wait on the UI.

A lead whose work started before keeps every line below as written, and
calls the templates with the args it always used.

### v2 contract rules 6 and 9

6. **Done.** All three: a `Belt-Lead:` PR labelled `feature-done` has merged; the CI run it triggered on dev is green; the lead commented on the feature issue with a line starting `Belt-Contact-Sheet:` and the run link.
9. **Brief rules.** Step one checks out the integration branch and verifies the base SHA. Set the repo-local identity "Prakash Dalai" / `86671543+prakashUXtech@users.noreply.github.com`. No attribution line anywhere, comments included. Fixers run the full harness before handing back. The Anatomy loop stops after 2 clean rounds or 4 rounds total; once a round is clean, add no new critics. One critic lens is first-use clarity: "what does each number and label mean to someone new?". Agents never treat a chat message as a reason to stop or skip a merge; questions go to the supervisor.

### Stages

Push RECORD.md and a `timeline.tsv` line to `lead/<feature>` at the end of
every stage, and at least every 20 minutes while you wait on CI or the lane,
so Belt never reads a quiet lead as a stall.

#### 0. Set up

1. `git fetch origin dev && git rev-parse origin/dev`. That SHA is the base.
2. Set the repo-local identity (contract rule 9).
3. If `origin/lead/<feature>` exists, this is a resume: check it out, read
   RECORD.md and continue from its last stage. Otherwise create `lead/<feature>`
   from the base and write RECORD.md from the template below.
4. Check the issue's `Depends on:` line. If that issue is still open, comment
   so on the feature issue, record it, and stop.

#### 1. Read the packet

Read the packet `docs/blueprints/<app>/features/<feature>.md` (its shape and
rules are in `docs/factory/packets.md`), the app's
blueprint, `docs/engineering.md`, `docs/design.md`, `docs/review-rubric.md` and
the code the tasks touch. Copy the packet's tasks, journeys and quality bars
into RECORD.md. A task that needs another line's code becomes a `needs-ui` or
`needs-core` issue (CLAUDE.md), not a task.

#### 2. Plan waves

Take the waves from the packet's Build waves section (`packets.md`, rule
(c)) and check them against the code as it is now. A wave is a set of tasks
that touch disjoint files and don't depend on each other's unmerged code.
Each task gets: an id, one behavior, the files it may touch, the test that
proves it, the snapshot or journey step it adds when it changes what the
user sees, and a size estimate under 400 lines and 15 files. Split anything
bigger.

A task waits on another only when it needs that task's merged code
(`packets.md`, rule (b)). Shared prose (`docs/design.md`, the blueprint,
the app's `waves.in.md`) goes in the one final task (rule (a)). The C4 model
and `waves.md` are generated: a task that adds a component adds its part in
`docs/c4/parts/` in the same PR as its code, and no task edits
`docs/c4/model.json` or a `waves.md` (`packets.md`, "Fragments, not shared
files"). If the packet chains tasks that don't need each other, unchain
them and record it under Decisions. For every wave, RECORD.md lists which
tasks are independent and, for each task that waits on another, which one
and why.

#### 3. Build waves

When a wave has **3 or more independent tasks**, run them in one go with
`docs/factory/workflows/build-wave.js` and the Workflow tool: one builder
per task, each in its own worktree, one PR per task under contract rule 4.
With 1 or 2 independent tasks, the template or one subagent per task with
`isolation: "worktree"` (also the fallback if Workflow is unavailable),
started together. Run subagents one after another only for tasks that truly
depend on each other; RECORD.md says which ones and why, one line each
under Decisions. Then:

1. Wait for the lane to merge every PR of the wave. The lane integrates a
   PR that conflicts with `dev` itself; only one it labels `needs-rebase`, or
   comments red or not eligible, goes back to its builder or a fixer: merge
   `origin/dev` into the branch, resolve the named files, rerun
   `scripts/ci --changed`, push, move the `Head:` line.
2. The next wave's base is the new `origin/dev` SHA. Record it.

#### 4. The Anatomy loop

One round:

1. **CI.** Find the CI run on `dev` whose head contains every PR merged so
   far. The lane dispatches it after a UI merge. If none of your merges
   touched a UI path, the screens can't have changed: judge the round on the
   Linux gate and the latest run, and note it in RECORD.md. A red run: read
   the failing job's log; failures in the feature's files become this
   round's fix batch, and others go to the open `dev-red` issue.
2. **Audit.** Read the run's `audit-<app>-*.json` and the contact sheet's
   audit table. Any count over the baseline for your app is a finding.
3. **Screenshots.** Download `ui-screens` and `snapshots` into your scratchpad.
4. **Critic panel.** Run `docs/factory/workflows/critic-panel.js` on the
   screens, the audit and the packet. 3 to 7 lenses; the clarity lens is
   always one. Critics only report; verifiers drop findings they can refute.
5. **Fix batch.** Group the confirmed findings into batches with disjoint
   files and run `docs/factory/workflows/fix-batch.js`. Every fixer runs the
   full harness before it hands back: `scripts/ci --changed` until `CI: PASS`, plus a
   test that fails before the fix, and the journey step or snapshot that
   shows it when it is visible. A layout finding gets a geometric test (frames
   inside the window, no overlap, minimum sizes): the pilot's geometric test
   caught what 62 journeys missed.
6. Wait for the lane to merge the batch, then start the next round on the CI
   run that contains it.

**Round budget.** A round is **clean** when CI is green, the audit is at or
under baseline for the app, and the panel confirms no blocker or major
finding. Stop after **2 clean rounds** in a row or **4 rounds** in total,
whichever comes first. Once a round is clean, add no new critics or lenses:
the next round runs the same panel. After 4 rounds with findings still open,
file each as a `gap` issue on the line and finish anyway.

#### 5. Finish

1. The last PR of the feature carries the `feature-done` label (a small last
   fix, the packet's status line, or the RECORD summary in the packet). It
   marks the feature built in its own data only:
   `docs/blueprints/<app>/features/<feature>.wave.json` gets
   `"status": "built"` and the feature issue; the Generated workflow
   reprints `waves.md` on `dev`. The lane merges it and dispatches CI on
   `dev`.
2. When that run is green, comment on the feature issue:
   `Belt-Contact-Sheet: <run link>` plus one line per journey and the audit
   counts. A red run is round work, not done: back to stage 4 if the budget
   allows, else file `gap` issues and say so in the comment.
3. Push the final RECORD.md and stop.

### RECORD.md

`docs/leads/<feature>/RECORD.md` on `lead/<feature>`. Rewrite it in place;
the timeline keeps the history. A relaunched lead reads only this file.

```markdown
# <feature> lead record

Issue: #<n> · Packet: docs/blueprints/<app>/features/<feature>.md
Run: <Belt run id> · Session: <session id> · Started: <UTC time>
Stage: <0 setup | 1 packet | 2 plan | 3 wave <k> | 4 round <r> | 5 finish | done>
Base: <origin/dev SHA the current stage started from>
Next: <the one thing a resumed lead does first>

## Tasks
| id | wave | behavior | files | test | PR | state |

## Rounds
| round | CI run | CI | audit vs baseline | lenses | confirmed | fixed by | clean |

## Decisions
- <what you chose and why, one line each>

## Open
- <blockers, needs-ui/needs-core issues, gap issues filed>
```

`docs/leads/<feature>/timeline.tsv`: one appended line per event, tab
separated, header `utc	stage	event	ref	note`, for example
`2026-10-14T09:12Z	3	pr-opened	#741	task m1 HaloModel keyframe store`.
Events: `stage-start`, `stage-end`, `pr-opened`, `pr-merged`, `ci-run`,
`round-clean`, `round-findings`, `heartbeat`, `stopped`.
