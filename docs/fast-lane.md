# Fast lane internals

How `scripts/fast-lane.sh` decides, batches, bisects and lands. It is run by
`.github/workflows/fast-lane.yml` with the script from the trusted main
branch. The rules for agents opening PRs are in CLAUDE.md, "Fast lane"; this
file is the reference for the script itself. Upper-case names are variables
in the script, lower-case ones are its functions.

## Purpose

The lane merges small, checked crew PRs into BASE_BRANCH (dev) without
waiting for captain review. The captain batch-reviews merged fast-lane PRs
later and reverts anything wrong. It reads PR metadata and file contents
through the GitHub API and never checks out or runs PR code.

## Proof and the macOS gate

Until beta only compile and Model tests block (captain, 2026-10-16). The
proof a head passed the gate is Linux-side: the worker's `Fast-Check: pass`
line followed by `Head: <full head sha>` in the body, or a passing CI
`Linux` check on the head. CI's `macOS` job and journeys.yml's `macOS
journeys` job (each also as `... (<app>)`) prove nothing for a PR, so the lane ignores them
(REPORT_ONLY_RE): a red or running one never holds a PR. macOS is gated
per batch, not per PR (below): a batch whose PRs change code (BUILD_RE)
lands only once its macOS gate is green too. LANE_MAC_PER_PR=1 is the
rollback to the per-PR gate: a code PR then also needs a passing build-only
CI run on its head (build_gate), which the lane dispatches itself, once per
head (workers get 403), scoped to the apps its code touches (build_apps:
main's scripts/test-scope build-apps; anything shared, unknown or
unreadable builds every app), and batches check Linux only.

## Belt PRs without the label

A crew PR into BASE_BRANCH with a `Belt-Lead:` body line and no `fast-lane`
label gets the label from the sweep (belt_label) unless it carries an
OPT_OUT_LABELS label; it is then evaluated like any labelled PR.

## Eligibility and integration

Eligibility (all must hold): open, not draft, label `fast-lane`, base
BASE_BRANCH, author in FAST_LANE_AUTHORS, size within MAX_LINES/MAX_FILES
(unless every path is under DOCS_RE), no changed or renamed-away path under
PROTECTED (CLAUDE.md's "Never edit" list), no looser app audit
(audit_loosens), no added app-local copy of a canonical concept without an
`Allow-Dup:` line (dup_logic), no added app copy of a SuiteUI piece without an
`Allow-Dup-View:` line (dup_views), MERGEABLE, no red or running check on the head, the proof
above, and for a Belt PR (`Belt-Run:` or `Belt-Test:` line) Belt's
`belt/review` status while REQUIRE_BELT_REVIEW=1. A PR based on main is
retargeted. A PR that is behind the base merges as it is. One that conflicts
is integrated by the lane (integrate): a scratch clone merges the base into
the PR head with the repo's merge drivers (scripts/install-merge-drivers and
scripts/merge-json from this checkout, i.e. main, never the PR's), pushes the
merge commit to the PR branch with a lease on the head it read, and the
re-sweep, seeing a head whose last commit is that merge (LANE_MERGE_SUBJECT)
with no check on it, dispatches a Linux-only CI run (linux-dispatch; ci.yml's
`linux_only`) and merges on its pass like any CI-proven head. Any other
unproven head with no check at all gets the same run, once per head (its
comment is the record), unless the PR comes from a fork. A conflict the
drivers can't resolve gets one comment naming the files and the
NEEDS_REBASE_LABEL label for a fixer; the label goes once the PR is
MERGEABLE again (checked each sweep, before the PR is evaluated), integrates
or merges.

## Batches and the batch bisect

Every run sweeps all open fast-lane PRs. Ready PRs land through batches
(batch_start), ordered p0, then beta, then the rest, oldest first within
each: BASE_BRANCH plus up to LANE_BATCH_MAX ready PRs merged in order on a
scratch branch `lane/batch-<id>` (BATCH_PREFIX, merge drivers on, one merge
commit per PR whose subject names the PR and its head). The batch gets one
Linux-only CI run and, when it needs macOS, one macOS gate run (ci.yml's
`mac_only`: scripts/ci on macOS scoped to BATCH_APPS, mac_scope over the
batch's changed paths: build-apps over its code plus the tests test-scope
changed picks, golden PNGs and fixtures included, anything shared meaning
every app). Its macOS pass is
that run's `macOS` job or a LOCAL_MAC_CONTEXT commit status (the local Mac
gate) on the batch head, unless the other one is red there: a red outranks a
green on the same head. When both are green every PR lands in order
(squash, head matched). A lone ready PR without code lands at once, as does
any lone PR with LANE_MAC_PER_PR=1; a lone code PR is a batch of one. No
proof is trusted once it is stale (proof_stale, lesson 244): dev changed a
ratchet, lint or baseline path (RATCHET_RE) since the proof's base, or the
PR changes one and dev moved on anything but the generated files
(GENERATED_RE). A lone PR with a stale proof is checked
as a batch of one on today's dev, and a batch whose base went stale that way
is dropped before it lands and forms again on today's dev. A batch
that needs macOS forms when a slot frees (a batch resolved in this run),
when LANE_BATCH_MAX PRs are ready, or once the oldest ready head is
LANE_BATCH_WAIT_MIN minutes old, and never while the lane's own queued and
running macOS runs (mac_slots_busy) fill LANE_MAC_SLOTS. One batch runs at a
time: a second one off the same base would land untested with the first, so
until speculative batches exist the slots are a guard rail on the shared
macOS pool, not a second batch.
A red batch is bisected by prefix on the same branch (batch_resume):
`lane/batch-<id>-<i>` points at the chain after i PRs and gets the same
Linux and macOS runs, until PR hi is the first that turns the chain red: PRs
before it land, PR hi gets NEEDS_FIX_LABEL and one comment naming the
failing job, its run and the open PRs stacked on its branch, and the PRs
after it wait for the next batch. When the red tip's failed Linux log holds
only budget failures (vote_mode), each probe's Linux check runs up to 3
times and is called on 2 of 3, under the same MAX_BATCH probe cap, and a
value within BUDGET_NEAR of its budget makes that comment say "likely". The
branch is the whole state, so a later sweep resumes a batch a run left
behind; while one is in flight nothing else merges. A PR whose head moved or
that conflicts with an earlier PR in the batch waits for the next sweep. A
red base (the chain before any PR) means BASE_BRANCH itself is red. On Linux
that is judged by job: when the base is red on every job the tip is red on,
a batch (one formed before the dev-red issue opened; none forms while it is
open, below) lands on the PRs' own proof, as before batches, so a fix can get
through; a job red only with the batch is still bisected, with the base's red
jobs set aside (BATCH_IGNORE). macOS is set aside that way only when the tip
passes it. When the tip fails macOS too, it goes by failing test instead
(mac_vs_base): every macOS gate on the chain is read against the tests that
fail on the base's own gate (BASE_MAC_FAILS), so a batch failing only those
lands, and one that adds a failing test is bisected to the PR that adds it,
whose comment names the new tests. A log that can't be read waits; a red
with no test to name (a build error, a crash) is never the base's.

## A red dev

A red BASE_BRANCH gets its culprit found the same way (red_sweep): while a
`dev-red` issue for a red Linux job is open, each sweep bisects main..<red sha>
by first-parent commit with `ci/bisect-<red7>-<i>` probe branches and
Linux-only runs (at most MAX_BISECT per red), testing red-triage's confident
guess (a `Likely cause: #N ... (Clef p)` comment, p >= CLEF_MIN) first, and
posts the first red commit on the dev-red issue and on the owning
feature-lead issue (the PR's `Feature:` line), then deletes its probes. When
every failure in the red tip's log is a measured value against a budget
(budget_failure), the test can flip at random, so each probe runs up to 3
times and is called on 2 of 3, at most MAX_BISECT_BUDGET runs per red, and a
value within BUDGET_NEAR of its budget posts the culprit as "likely".
`--bisect <good>..<bad> <issue> [<branch>]` runs one such bisect by hand.

While the dev-red issue names a job a batch would run (red_holds: Linux
always, macOS when the batch runs the macOS gate; the issue never names the
failing app, so any macOS gate counts), no new batch forms and ready PRs
wait: every probe of a batch on a red base is red, so its bisect only burns
runs and can blame an innocent PR. A docs batch, which runs no macOS gate,
still forms on a macOS-only red. A batch already in flight whose base holds
the issue's red sha gets a `lane/batch-<id>-red` marker branch; once the
issue is closed and BASE_BRANCH has moved past that base, a marked batch is
dropped with its probes (no label, no comment: its PRs were not at fault) and
the same sweep forms a fresh one. A batch whose base predates the red commit
is never marked, so it can't be dropped this way.

## CI dispatch on dev

A lead's PR (a `Feature:` body line) never closes a `feature-lead` issue
(lead_refs). After its merges the lane dispatches CI on BASE_BRANCH at most
once per run (dispatch_reason): a FEATURE_LABEL PR, a UI_RE change, or
DISPATCH_EVERY merged PRs since the last CI run. Promotion of main is
ci.yml's job.

## decide and the tests

`decide` is the pure decision function (no network): it reads a PR JSON
file, a file-list file, a check-rollup JSON file, optional audit_snapshot
dirs (merge base, head), the Mac-Check run and the latest build-only run on
the head, and the PR's added files, logs each rule to stderr and prints one line to stdout:

```
skip|<why>  retarget|<from base>  not-eligible|<reasons>  red|<checks>
conflict|<head sha>  pending|<why>  build-dispatch|<code paths>|<head branch>|<apps or all>
linux-dispatch|<head branch>
build-gate|<what to do>  eligible|<lines>|<files>|<proof>
```

Tests/fast_lane/test_fast_lane.sh sources the script and feeds it fixtures.

## Usage

```
scripts/fast-lane.sh [--dry-run] [PR ...]   (no PR: every open fast-lane PR)
scripts/fast-lane.sh --bisect <good sha>..<bad sha> <issue> [<branch holding bad>]
```

`--dry-run` prints the decision and makes no API writes. Needs gh and jq.
