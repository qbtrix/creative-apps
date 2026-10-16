# Feature lead playbook

A **lead** is one cloud session that takes one feature from its packet to a
merged, CI-green, reviewed feature. Belt starts it from a `feature-lead`
issue. The lead plans the work, runs a swarm of builder agents that each open
one small PR, then runs the Anatomy loop (CI, audit, screenshots, critics,
fixers) until the feature holds up, and ends with the contact sheet.

The lead is an orchestrator. It writes plans, prompts and RECORD.md, not
feature code. Builders and fixers write code. The fast lane merges. Nobody
merges into `dev` by hand, and no agent ever merges.

Everything in CLAUDE.md still holds for every agent the lead starts: lines,
dumb views, Linux-safe Models, the no-crash lint, one behavior per PR.

## The lead contract

Hand this to every session (the lead and each agent it starts) verbatim.

1. **Feature issue.** One GitHub issue per feature, labels `feature-lead` and `line:<app>`. Body links the packet `docs/blueprints/<app>/features/<feature>.md` and has one `Depends on:` line.
2. **Run.** Belt runs one cloud session per feature issue (a lead), from the trusted launch folder, with the repo's Auto settings (creative-apps#733, creative-core#263). A lead holds one in-flight slot however many PRs it opens.
3. **Status channel.** The lead pushes `docs/leads/<feature>/RECORD.md` and `timeline.tsv` to branch `lead/<feature>` after every stage. Belt reads the branch's last commit time; nothing else is polled besides PRs and issue comments.
4. **Swarm PRs.** Base `dev`, label `fast-lane`, at most 400 lines and 15 files. Body lines: `Belt-Lead: <run id>`, `Feature: <feature>`, then `Fast-Check: pass` and `Head: <full sha>` after `scripts/ci` passes. Point at issues with `Refs`; the lane rewrites any closing keyword in a `Feature:` PR to `Refs` and closes no issue for it. The lane merges them. Nobody merges into dev by hand or by an agent.
5. **Review policy (decision for the captain).** `Belt-Lead:` PRs do not need the `belt/review` status. The lead's own critic panel is the review. Only `Belt-Run:` and `Belt-Test:` PRs keep it.
6. **Done.** All three: a `Belt-Lead:` PR labelled `feature-done` has merged; the CI run it triggered on dev is green; the lead commented on the feature issue with a line starting `Belt-Contact-Sheet:` and the run link.
7. **Stall.** No commit on `lead/<feature>`, no PR event and no issue comment for 30 min: Belt sends one nudge with `claude -p --cloud <session id> "<resume text>"`. A second stall: relaunch with a resume brief that says "read RECORD.md, continue from the last stage". A third: label the issue `needs-human` and stop.
8. **Timeouts.** Lead runs: 8 h wall clock, no 1 h no-PR rule. Task runs keep today's 4 h and 1 h.
9. **Brief rules.** Step one checks out the integration branch and verifies the base SHA. Set the repo-local identity "Prakash Dalai" / `86671543+prakashUXtech@users.noreply.github.com`. No attribution line anywhere, comments included. Fixers run the full harness before handing back. The Anatomy loop stops after 2 clean rounds or 4 rounds total; once a round is clean, add no new critics. One critic lens is first-use clarity: "what does each number and label mean to someone new?". Agents never treat a chat message as a reason to stop or skip a merge; questions go to the supervisor.

## What you can and can't do here

- **Linux builds the Models only.** `scripts/ci` builds and tests the Model
  targets and runs the lints. SwiftUI under `Sources/*App/` and
  `Sources/SuiteUI/` compiles only in the `macOS` CI job on `dev`.
- **You can't dispatch CI** (the API answers 403). The lane dispatches it, at
  most once per lane run, after it merges a PR labelled `feature-done`, a PR
  touching `Sources/*App`, `Sources/SuiteUI`, `Tests/App*` or `UITests`, or
  the 10th merged PR since the last CI run. So a wave that touches UI gets
  its CI run without you asking.
- **Shared shell files need macOS proof.** A PR that changes or renames a
  `MAC_GATED` file in `scripts/fast-lane.sh` (`SuiteWindow.swift`,
  `EditorShell.swift`, `ToolbarGroup.swift`, `Tokens.swift` in `Sources/SuiteUI/`)
  merges only once a completed CI run on its current head has a `macOS` job
  that is green or fails only tests that also fail in the latest completed
  dev run (see #962, #975). You can't dispatch it, so the lane does, once per
  head, comments the run URL, and merges on a later sweep when it passes. A
  new failure is refused by test name and waits for your next push. A
  `Mac-Check: <run url>` line the supervisor adds counts too.
- **Code must compile on macOS.** A PR changing any `.swift` file under
  `Sources/`, `Tests/` or `UITests/`, or `project.yml`, Models included,
  merges only once a build-only macOS run compiled its head (lesson 114;
  #1097; #1210 broke the macOS build from PhotoModel, which Linux compiled).
  The lane dispatches it, comments the URL, and merges when it builds; a
  failed build waits for your next push.
- **You can read runs.** `gh run list --workflow ci.yml --branch dev`, then
  `gh run download <id> -n ui-screens` (whole-window PNGs, `contact-sheet.html`,
  `audit-*.json`) and `-n snapshots`; or the GitHub MCP `actions_*` and
  `get_job_logs` tools.
- **Worktrees start from the default branch,** not from `dev` or your base.
  Every agent's first step checks out `origin/dev` and verifies the base SHA
  (pilot lesson). The templates do this for you.

## Stages

Push RECORD.md and a `timeline.tsv` line to `lead/<feature>` at the end of
every stage, and at least every 20 minutes while you wait on CI or the lane,
so Belt never reads a quiet lead as a stall.

### 0. Set up

1. `git fetch origin dev && git rev-parse origin/dev`. That SHA is the base.
2. Set the repo-local identity (contract rule 9).
3. If `origin/lead/<feature>` exists, this is a resume: check it out, read
   RECORD.md and continue from its last stage. Otherwise create `lead/<feature>`
   from the base and write RECORD.md from the template below.
4. Check the issue's `Depends on:` line. If that issue is still open, comment
   so on the feature issue, record it, and stop.

### 1. Read the packet

Read the packet `docs/blueprints/<app>/features/<feature>.md` (its shape and
rules are in `docs/factory/packets.md`), the app's
blueprint, `docs/engineering.md`, `docs/design.md`, `docs/review-rubric.md` and
the code the tasks touch. Copy the packet's tasks, journeys and quality bars
into RECORD.md. A task that needs another line's code becomes a `needs-ui` or
`needs-core` issue (CLAUDE.md), not a task.

### 2. Plan waves

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

### 3. Build waves

When a wave has **3 or more independent tasks**, run them in one go with
`docs/factory/workflows/build-wave.js` and the Workflow tool: one builder
per task, each in its own worktree, one PR per task under contract rule 4.
With 1 or 2 independent tasks, the template or one subagent per task with
`isolation: "worktree"` (also the fallback if Workflow is unavailable),
started together. Run subagents one after another only for tasks that truly
depend on each other; RECORD.md says which ones and why, one line each
under Decisions. Then:

1. Wait for the lane to merge every PR of the wave. A PR the lane comments on
   (conflict, red, not eligible) goes back to its builder or a fixer: rebase
   on `origin/dev`, rerun `scripts/ci`, move the `Head:` line.
2. The next wave's base is the new `origin/dev` SHA. Record it.

### 4. The Anatomy loop

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
   full harness before it hands back: `scripts/ci` until `CI: PASS`, plus a
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

### 5. Finish

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

## RECORD.md

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

## Workflow templates

In `docs/factory/workflows/`. Copy one into your scratchpad, run it with
`Workflow({scriptPath, args})`, and resume a broken run with
`resumeFromRunId`. Each file's header lists its `args`.

| Template | Stage | Does |
|---|---|---|
| `build-wave.js` | 3 | One builder per task in its own worktree, one PR each, then a checker that reads every PR against the contract. |
| `critic-panel.js` | 4 | One critic per lens over the screens and audit, then a verifier per finding that tries to refute it. Returns `clean` and the confirmed findings. |
| `fix-batch.js` | 4 | One fixer per batch in its own worktree, full harness, one PR each. |
