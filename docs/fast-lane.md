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
time (HOLD, set by batch_held): a second one off the same base would land
untested with the first, so until speculative batches exist the slots are a
guard rail on the shared macOS pool, not a second batch. The one exception is
a batch of one under LANE_VERIFY_AFTER=1 (below).
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
with no test to name (a build error, a crash) is never the base's. The
sharded gate job (`macOS`) only sums its shards, so when its own log names
no test, mac_tests reads the failed `macOS tests K/N` jobs of its run.
A test process that dies prints no such line, so mac_tests also reads the tests named in scripts/ci's TEST PROCESS DIED block and places each in the one Tests/ file whose `func <name>(` declares it on dev (a name found in no file or several is left out and logged).

## A red dev

### The flake check

A new `dev-red` issue is not red to the lane until its flake check is in
(flake_check, first thing in red_sweep). The issue's `- Run:` line names the
red run and its culprit range the red sha; the lane reruns that run's failed
jobs once at that sha (`gh run rerun <id> --failed`; fast-lane.yml has
`actions: write`) and posts one comment on the issue naming the run, the
failing jobs and the failing tests read from the red logs (red_tests, read
then, since the rerun overwrites them), ending in `<!-- lane-rerun <sha7>
started -->`. That mark is the record: a sha with one is never rerun again,
whatever the issue body says later, and an issue whose comments can't be read
is red as before, so nothing can rerun twice. While the rerun runs the sweep
returns before BASE_RED is set: nothing is held, bisected or reverted.

A rerun that passes was a flake. The lane files one finding for a fixer
(flake_finding): an open `finding` issue titled `Flaky test: <File>.swift/<test>`
(`Flaky tests:` for several; `Flaky <jobs> job on dev, no test named` when the
logs named none) gets a "Flaked again" comment, else one is created with the
labels `finding`, `flaky` and `line:<app>` (build_apps over the tests' files;
shared or unknown is `line:suite`), and the issue gets `<!-- lane-rerun <sha7>
flake -->`. ci.yml's `promote` job reruns with the passed jobs and closes the
dev-red issue, usually before a sweep sees the pass, so a sweep that finds no
open dev-red issue reads the last closed one (flake_closed): a `started` mark
with no verdict whose run passed gets its finding and mark there. A rerun that
fails too makes the red real: the issue gets `<!-- lane-rerun <sha7> red -->`
and the sweep goes on exactly as below. An issue with no `- Run:` line is red
at once. `--dry-run` reruns nothing.

### Holding, scoped to the red module

A real red BASE_BRANCH gets its culprit found the same way (red_sweep): while a
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
failing app, so any macOS gate counts), the ready PRs that touch the red
module wait and the rest batch as usual (settle_ready). The module comes from
the failing tests (red_scope): each `<File>.swift` red_tests names is found
in the tree of origin/BASE_BRANCH under `Tests/<Target>/`, and the scope
(BASE_RED_SCOPE, a path regex) is `Tests/<Target>/` plus `Sources/<Target
minus Tests>/` for each, so a red in SuiteUITests holds Sources/SuiteUI and
Tests/SuiteUITests; evaluate marks each eligible PR that touches it (READY's
last field). When the lane can't place the red (no test named, a build error
or a crash; a file not in the tree; a target with no such Sources module,
AppSnapshotTests or AppAuditTests) the scope is empty and no new batch forms:
every ready PR waits, as before, since every probe of a batch on a red base
is red, so its bisect only burns runs and can blame an innocent PR. A batch
that does form on a red base, its PRs off the module, still fails a Linux red
(scripts/ci runs every Model test) and lands on the PRs' own proof through
the base-red rule above; a macOS gate scoped to other apps passes. Every
other gate stays: a PR with a red check or proof never lands, protected paths
stay refused. A docs batch, which runs no macOS gate,
still forms on a macOS-only red. A batch already in flight whose base holds
the issue's red sha gets a `lane/batch-<id>-red` marker branch; once the
issue is closed and BASE_BRANCH has moved past that base, a marked batch is
dropped with its probes (no label, no comment: its PRs were not at fault) and
the same sweep forms a fresh one. A batch whose base predates the red commit
is never marked, so it can't be dropped this way.

## Verify after merge (LANE_VERIFY_AFTER=1)

The repo variable LANE_VERIFY_AFTER (fast-lane.yml passes it in; unset,
empty or 0 is the lane described above) moves the checks from before the
merge to after it: a code PR lands on its own proof, and a red BASE_BRANCH
is answered by reverting its culprit.

Own-proof landing rides the LANE_MAC_PER_PR path with a different macOS
proof. A code PR (BUILD_RE) needs, besides the Linux proof above, the
supervisor's pre-screen on its head: the `local-ci/prescreen` commit status
(PRESCREEN_CONTEXT, posted by the pre-screen loop on the Mac after it merges
the PR into dev and runs compile and Model tests). decide judges it in
build_gate's slot (prescreen_gate): success is proof, failure is red, missing
or pending waits. It is left out of the generic check summary in both modes,
so at 0 it changes nothing and a head whose only status it is still gets its
Linux check. There is no per-PR macOS build and no batch for code:
settle_ready hands each code PR to batch_start alone, whose lone-PR rule
(shared with LANE_MAC_PER_PR=1) lands it on that proof unless proof_stale
says dev moved under it; then it is a batch of one, checked on Linux on
today's dev (batch_apps is empty in this mode), and lands on that. The
pre-screen screens a head once, so a stale proof re-waits on that Linux
check, not on a new pre-screen. A batch of one holds only its own PR
(BATCH_SOLO: batch_held puts it in INFLIGHT, so it is never batched or
landed twice, and sets no HOLD): every other ready PR with fresh proof lands
beside it in the same sweep, and several stale PRs each get their own batch
of one and check in parallel (batch ids stay unique within a run), at most
LANE_BATCH_MAX at once, since one ratchet commit on dev makes every proof
stale together; the rest wait for a later sweep. The sweep does not wait
BATCH_WAIT on such a batch; a later sweep reads its verdict. Landings beside
it move dev under the batch, so its green result goes through batch_land's
proof_stale on today's dev like any batch: stale, it is dropped and the PR
forms a new batch of one there; not stale, it lands. Two kinds still hold
the lane: a batch of two or more (PRs without code), and a batch of one
whose PR changes a RATCHET_RE path itself, which proof_stale would call
stale after every landing beside it, so it would never land. A red dev holds no code PR here: red_holds
exists because every batch probe on a red base is red, and an own-proof
landing runs no probe (the pre-screen already excuses failures dev has on
its own). PRs without code still batch, held by red_holds as above.

Auto-revert (revert_sweep, after the batches so a revert waits for one
holding the lane): while the dev-red issue is open (red_sweep; a Linux or a macOS red),
the lane makes one revert call per culprit on it. The culprit (revert_culprit) is
red_bisect's verdict on the issue (a certain one: a "likely" verdict from a
timing budget test is not enough), else the only PR commit (a subject ending
`(#N)`; generated commits have none) in the issue's range main..<red sha>. A
Linux red with several PRs waits for the bisect. A macOS-only red with
several PRs names none, since red_bisect runs Linux probes only and
reverting newest first would hit innocent PRs, each step a full macOS run on
dev to read; a human picks. The revert (revert_open) is `git revert` of the
culprit's squash commit on today's BASE_BRANCH in the scratch clone (merge
drivers on), pushed as `lane/revert-<n>` (REVERT_PREFIX) and opened as a PR
labelled `lane-revert` (REVERT_LABEL) and `p0`, never `fast-lane`. Its body
names the failing jobs, the failing tests read from the red sha's logs
(red_tests) and the run, and says `Refs` the dev-red issue, so landing it
closes nothing. The culprit PR is merged, so its feature-lead issue (by the
PR's `Feature:` line, feature_lead), or the PR itself, gets one comment with
the failure and how to bring the change back (a new PR that reverts the
revert, plus the fix), and a `finding` issue labelled `line:<app>` is filed
(build_apps over the culprit's files; shared code or several apps:
`line:suite`). The call ends with a REVERT_MARK comment on the dev-red issue
naming the culprit's sha7 (or `none`), which also records a call that found
nothing to revert: the culprit is a revert itself (never reverted), not a
PR's commit, already has a lane revert open or a revert on dev (never two for
one PR), does not revert cleanly, or no culprit was named, touches a
protected path (captain review only, and the lane's token can't push
workflows), or its revert could not be pushed or opened. The mark is keyed on
the verdict, not the issue: a sha7 (or `none`) already marked is never called
again, so a dev still red on the same culprit after its revert waits for a
human, but a second, different red inside the same open issue (an earlier
`none` note for a macOS-only red, then a Linux bisect that names a culprit)
gets its own call. A sweep opens at most one revert, and while the lane's
revert for the issue is open it only lands that one.

The revert PR (a bot author on a REVERT_PREFIX branch with REVERT_LABEL,
its body saying `Refs #<the open dev-red issue>.`; one from an older issue is
never landed under a new one) never goes through decide: revert_land starts
one Linux-only CI run on its head (its comment is the record), and on a
green one lands it with land(), proof_stale permitting. A stale check, or a
merge GitHub refuses because dev moved under the revert into a conflict,
gets the revert cherry-picked onto today's BASE_BRANCH and checked again. It needs no prescreen, no macOS run
and no batch, and lands while the dev-red issue holds batches, since it puts
back code BASE_BRANCH already ran. Landing it dispatches CI on BASE_BRANCH
(dispatch_reason), whose green run promotes main and closes the issue. A red
check on the revert, a rebuild that conflicts, or a revert left open after
its issue closed waits for a human. GitHub Actions must be allowed to create pull requests in the repo
settings, or the call records that the revert was pushed but not opened.

### Auto-quarantine (trunk never stops)

A real red the lane has no revert for must not hold the lane for more than
one sweep. revert_sweep marks that state (RED_UNRESOLVED) when it ends in a
revert_note (no bisect verdict, a "likely" one, a culprit on a protected path,
a revert of a revert, no PR commit, a revert that won't apply or push, one
already open or on dev) or when its one revert call is done and the red sha's
range main..<red> already holds that revert (dev is still red with it). A red
whose revert is open, or whose CI run after the revert hasn't reported, is
not unresolved: nothing is quarantined while a fix is in flight.

quarantine_sweep runs after revert_sweep (LANE_VERIFY_AFTER=1 only) and does
three things, one PR at a time on QUAR_BRANCH (`lane/quarantine`). First it
lands an open lane quarantine PR (quarantine_land, below). Else it reads the
lane's entries in UITests/quarantine.json on BASE_BRANCH (those with a `lane`
block): an owner issue past the entry's `until` gets the `blocker` label and
one comment, and the entry stays, since an expired quarantine must never come
back as a red; a closed owner (the fix merged and its issue closed) gets its
entries removed in one PR titled `test(quarantine): run <ids> again`
(quarantine_expiry). Then, when the red is unresolved and the dev-red issue
has no `<!-- lane-quarantine <red7> -->` mark yet, quarantine_add quarantines
the failing tests: red_tests names them as `<File>.swift/<test>()`; each file
is placed under Tests/<Target>/ in the tree (test_paths) and resolved to its
perf-list id, `Target.Suite/test` or `Target.freeTest`, with
`scripts/test-scope ids <Target> <file>`. It stops, with one note on the
dev-red issue carrying the mark, when the logs name no test, when more than
QUAR_MAX (5) fail (something broke broadly: today's red handling stands and a
human picks the culprit), or when none is left after dropping a test whose
path or id matches QUAR_NEVER_RE (security, billing, auth, licence, payment,
keychain, entitlement), one already quarantined, or one it can't place. For
each test left it files, or comments on, the test's `Quarantined: <id>` issue
(quarantine_issue: the open `finding` of that title, else a new one with
`p0`, `finding` and `line:<app>`, naming the run, the range's PRs with their
feature leads, and the expiry), writes the entry

```json
{"test": "PhotoModelTests.OpenTests/opens", "owner": "#700",
 "reason": "Quarantined by the fast lane: ...", "expires": "2026-10-27",
 "lane": {"red": "#520", "range": "main..abc1234", "until": "2026-10-27T10:00:00Z"}}
```

(the owner is that issue, `until` QUAR_HOURS = 24 h out, `expires` its date)
and opens one PR from QUAR_BRANCH with QUAR_LABEL (`lane-quarantine`) and
`p0`, never `fast-lane`, its body starting `Lane-Quarantine: add` (a removal
says `Lane-Quarantine: remove #<owner>`) and `Refs #<dev-red>`. The mark goes
on the dev-red issue, so each red sha gets one call. scripts/ci skips the live
swift-test entries through `scripts/quarantine skip`, a `--skip` regex that
rides with the perf list's, so the PR's own Linux check and dev's next run are
green and normal batching resumes.

**The protected-path exception, exactly.** UITests/quarantine.json is in
PROTECTED and decide refuses every PR that touches it, the lane's own
included: the lane's quarantine PR never goes through decide. quarantine_land
lands a PR only when all of these hold: the author is a bot (the lane's
token), the head branch is QUAR_BRANCH, the PR carries QUAR_LABEL
(quarantine_sweep's filter), and `gh api pulls/<n>/files` lists exactly
UITests/quarantine.json. A PR that changes anything else gets one comment and
is never landed, whatever its labels. Like a revert, it lands on its own
Linux-only check (dispatched once, its comment the record), with no prescreen,
batch or macOS run, while the dev-red issue holds batches; a merge GitHub
refuses as conflicting is cherry-picked onto today's BASE_BRANCH
(rebuild_lane_pr) and checked again. The landing dispatches CI on BASE_BRANCH
(UITests/ is a UI_RE path). A red check on a removal means the fix didn't
hold: the owners are reopened with a comment, the PR is closed and the
entries stay; a red check on an add waits for a human.

`scripts/quarantine release` is the release gate: it fails while any lane
entry is in the file, naming each test, owner and `until`. There is no
release or promote script to wire it into yet (ci.yml's `promote` moves main
to the last green dev sha, which is not a release, and gating it would grow
every culprit range), so run it by hand, or from the release step once one
exists. `scripts/quarantine check` passes a lane entry past its expiry or
with a closed owner, with a note, since the lane owns both ends of its
lifecycle; a hand entry fails as before.

## CI dispatch on dev

A lead's PR (a `Feature:` body line) never closes a `feature-lead` issue
(lead_refs). After its merges the lane dispatches CI on BASE_BRANCH at most
once per run (dispatch_reason): a lane revert, a FEATURE_LABEL PR, a UI_RE change (a lane quarantine PR is one), or
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
