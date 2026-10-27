#!/usr/bin/env bash
# scripts/fast-lane.sh: merge small, checked crew PRs into BASE_BRANCH (dev)
# without waiting for captain review; the captain batch-reviews merged
# fast-lane PRs later. Run by .github/workflows/fast-lane.yml with this file
# from the trusted main branch. It reads PR metadata and file contents through
# the GitHub API and never checks out or runs PR code.
#
# Each sweep: red_sweep reads the open dev-red issue (flake_check reruns a
# new red's failed jobs once before it counts; a real Linux red is bisected
# to its culprit), a batch left in flight resumes (batch_resume: land, bisect
# by prefix, or drop), with LANE_VERIFY_AFTER=1 revert_sweep reverts a red
# dev's culprit and quarantine_sweep quarantines the failing tests of a red
# it has no revert for, every open fast-lane PR is evaluated (decide, the pure
# decision function), and settle_ready lands the ready ones or forms the next
# `lane/batch-<id>` (BATCH_PREFIX). Invariants a change must keep:
# - One batch at a time; while one is in flight nothing else merges, except
#   with LANE_VERIFY_AFTER=1, where a batch of one holds only its own PR.
# - The batch branch is the whole state: its merge commits (BATCH_SUBJECT_RE)
#   name each PR and head, `<batch>-<i>` are its probes and `<batch>-red`
#   marks a base that held dev's red commit (dropped once dev is green).
# - A red's failed jobs are rerun at most once per sha (RERUN_MARK on the
#   dev-red issue); until that rerun is judged, dev is not red to the lane.
# - While dev is red on a job a batch would run (red_holds), a PR touching
#   the red module (BASE_RED_SCOPE) waits; with no module placed, no batch forms.
# - A dropped batch never labels or comments on its PRs.
# - One revert call per culprit on a dev-red issue (REVERT_MARK <sha7|none>),
#   at most one revert per sweep, never two for one PR, never of a revert.
# - One quarantine call per red sha (QUAR_MARK), at most QUAR_MAX tests, none
#   on a QUAR_NEVER_RE path; the lane's own PR on QUAR_BRANCH that changes
#   exactly QUAR_FILE is the one protected-path change it lands (quarantine_land).
# - Merge drivers and helper scripts come from this checkout (main), never
#   from a PR.
# Rules for agents: CLAUDE.md, "Fast lane". How the gate, batches, bisects
# and the red-dev rules work: docs/fast-lane.md.
# Tests/fast_lane/test_fast_lane.sh sources this file and feeds it fixtures.
#
# Usage: scripts/fast-lane.sh [--dry-run] [PR ...]   (no PR: every open fast-lane PR)
#        scripts/fast-lane.sh --bisect <good sha>..<bad sha> <issue> [<branch holding bad>]
# --dry-run prints the decision and makes no API writes. Needs gh and jq.
set -euo pipefail

# Logins as `gh pr view --json author` reports them. Cloud Claude Code sessions
# open PRs with the captain's own GitHub token, so they appear as prakashUXtech.
FAST_LANE_AUTHORS="prakashUXtech"
MAX_LINES=400
MAX_FILES=15
# The docs tier: a PR whose every changed and renamed-away path is under docs/
# (packets, blueprints with their .wave.json feature data, C4 parts, any .md
# there) takes the lane at any size; the Design packets waited hours on the
# 400-line cap. Its proof is every PR's: the Fast-Check marker or a passing CI
# check, i.e. scripts/ci on its head, which renders the waves (scripts/waves
# render --dry-run) and assembles the C4 parts with the ownership check.
# PROTECTED paths under docs/ stay refused, and a file list shorter than the
# PR's file count (the API's cap) gets no tier.
DOCS_RE='^docs/'
# Belt PRs wait for Belt's pre-merge review: the `belt/review` commit status on
# the head must be success (missing or pending waits, failure is red). Not a
# ruleset-required check, since merge-queue group commits would never get it.
# Set to 0 to turn the gate off if Belt's reviewer misbehaves.
REQUIRE_BELT_REVIEW=0
BELT_REVIEW_CONTEXT="belt/review"
BASE_BRANCH="${FAST_LANE_BASE:-dev}"
LABEL="fast-lane"
# A Belt-Lead PR from the crew gets LABEL added by the sweep unless it carries one of these.
OPT_OUT_LABELS="no-fast-lane needs-human"
MERGED_LABEL="fast-lane-merged"
FEATURE_LABEL="feature-done"  # merging one dispatches full CI on BASE_BRANCH
CI_WORKFLOWS=("CI")
# CI job names, so CI runs started by workflow_dispatch (no PR association) still count.
CI_CHECKS=("Linux")
# Report-only jobs (ci.yml's macOS, journeys.yml's macOS journeys and its Journeys wait), matched by name: never red, pending or proof here.
REPORT_ONLY_RE='^(macOS( journeys)?( \(.*\))?|Journeys wait)$'
CI_FILE="ci.yml"  # the CI workflow file, dispatched on BASE_BRANCH after merges
SELF_WORKFLOW="Fast Lane"
# The lane job's own check run on the head. Check runs read off the commit carry
# no workflow name, so the lane drops its own (running) check by this name.
SELF_CHECK="fast-lane"
# UI code is eligible: the worker's Linux scripts/ci covers the Models, the
# macOS job in the next feature CI on dev covers the UI, and taste review
# happens after merge on the snapshot PNGs (fixes come back as new issues).
# PROTECTED is exactly the backticked paths in CLAUDE.md's "**Never edit**"
# bullet; Tests/fast_lane checks the two match. A path ending in / is that
# folder at the root, a path with a / is that file, and a bare name is that
# file in any folder (docs/AGENTS.md too). A * matches one folder name.
# Matching ignores case. .gitattributes names the merge drivers the lane runs
# when it integrates a PR, so a PR can't turn one on for itself. docs/c4/model.json, each app's waves.md and jobs.md are
# generated on dev (.github/workflows/generated.yml), so PRs never edit them.
# UITests/quarantine.json skips failing journeys (scripts/quarantine), so only
# the supervisor quarantines; Tests/perf-suites.txt takes tests out of the
# gate (scripts/test-scope), so only the supervisor lists them.
PROTECTED=(Package.swift Package.resolved .github/ .claude/ scripts/ .gitattributes CLAUDE.md AGENTS.md LICENSE
  docs/c4/model.json 'docs/blueprints/*/features/waves.md' 'docs/blueprints/*/jobs.md' UITests/quarantine.json Tests/perf-suites.txt)
deny_re() {
  local p re=""
  for p in "${PROTECTED[@]}"; do
    p="${p//./\\.}"
    p="${p//\*/[^/]*}"
    case "$p" in */) p="^$p" ;; */*) p="^$p\$" ;; *) p="(^|/)$p\$" ;; esac
    re+="${re:+|}$p"
  done
  echo "$re"
}
DENY_RE=$(deny_re)

# The app audit's ratchet (docs/blueprints/app-audit.md, "Growing the audit"):
# its baseline, and the folder holding AuditCore.swift (the AppAudit.checks
# registry) and Checks/. Both homes of the audit code are listed, so the guard
# holds while the move into its own test target waits to reach main.
AUDIT_BASELINE="UITests/audit-baseline.json"
AUDIT_DIRS='(Tests/PhotoModelTests/AppAudit|Tests/AppAuditTests)'
AUDIT_RE="^(UITests/audit-baseline\\.json\$|$AUDIT_DIRS/)"
AUDIT_REGISTRY_RE="^$AUDIT_DIRS/AuditCore\\.swift\$"
AUDIT_REASON="loosens the app audit: needs the captain's review"
# What a Linux proof is judged against besides the code (proof_stale): the
# gate scripts and ci.yml, every ratchet baseline (Tests/*-baseline*, the
# command-path baselines), the ratchet tests themselves, the canonical concept
# lists and the app audit. Matched ignoring case.
RATCHET_RE="(^scripts/|^\\.github/workflows/ci\\.yml\$|baseline|ratchet|commandpath|placeholdermenu|^tests/canonical-|${AUDIT_RE})"
# The files .github/workflows/generated.yml commits straight to dev (its `git
# add` list). A dev move made only of these never stales a proof: they hold no
# code, and a generated commit under a batch with a ratchet PR dropped the whole
# batch on 2026-10-23.
GENERATED_RE="^(docs/c4/(model\\.json\$|parts/)|docs/blueprints/[^/]+/(features/waves\\.md|jobs\\.md)\$)"
# Canonical first (docs/factory/lead.md rule 20): a PR that adds a Swift file
# under Sources/<X>Model or Sources/<X>App named for a canonical concept
# (Tests/canonical-concepts.txt) needs an `Allow-Dup: <concept> <reason>` body
# line. The lane runs main's scripts/check-dup-logic --paths on the PR's added
# and renamed-to files: names only, since it never reads PR code; the primary
# type rule and the grandfathered baseline are scripts/ci's (the head's proof).
DUP_REASON="adds app-local logic for a canonical concept (use the SuiteModel module, or add \`Allow-Dup: <concept> <reason>\` to the body)"
# SuiteUI first (lead.md rules 16 and 20), the same way for views: an added
# file under Sources/<X>App named for a UI concept (Tests/canonical-ui-concepts.txt:
# Sheet, Notice, Transport, ...) needs an `Allow-Dup-View: <concept> <reason>`
# line. main's scripts/check-dup-views --paths, names only; its signature and
# shape rules and baseline are scripts/ci's.
DUP_VIEW_REASON="adds an app copy of a SuiteUI piece (use the SuiteUI component, or add \`Allow-Dup-View: <concept> <reason>\` to the body)"
# Statics on Views (swiftui-rules.md rule 13) has no names-only form: it reads
# the code, which the lane never does. scripts/check-view-statics runs in the
# worker's scripts/ci on the head, the Head: proof above, so a fast-lane PR that
# adds an unmarked static on a View fails there, not here.

# A supervisor's `Mac-Check: <run url>` line names a CI run whose green
# macOS job built every app, which also proves a code PR builds (build_gate).
MAC_CHECK_LINE="Mac-Check:"
MAC_JOB="macOS"
# What a compiler reads: Swift under Sources/, Tests/ and UITests/, plus
# project.yml and Package.swift (protected anyway). A PR changing any of it,
# shared shell files such as SuiteWindow.swift included, merges only once a build-only CI run (ci.yml's
# `build_only` input: every SwiftPM target with its tests, then the journey
# bundles; nothing runs) compiled its head; the lane dispatches it, once per
# head, with `-f app=<apps>` when build_apps names apps (the run then builds
# only those apps, their Model tests, AppSnapshotTests and their journey
# bundles). A branch whose ci.yml predates the `app` input refuses the
# dispatch, so the lane dispatches again without it (a full build). Linux scripts/ci never builds the app targets (lesson 114: dev stopped
# compiling on macOS, run 38727890123; then a snapshot test, run 38732179619,
# #1097), and it can't see a macOS-only break in a target it does build:
# #1210 put an ObjCBool error in Sources/PhotoModel that Linux compiles fine.
# Tests/fast_lane checks every target in Package.swift and every project.yml
# source falls under it. Data files (UITests/audit-baseline.json) don't count.
BUILD_RE='^((Sources|Tests|UITests)/.*\.swift|project\.yml|Package\.swift)$'
BUILD_JOB="macOS build"    # the build-only job's name in ci.yml
BUILD_TITLE="macOS build"  # ci.yml's run-name for a build-only run
LINUX_TITLE="Linux check"  # ci.yml's run-name for a linux_only run (the lane's check on a head it integrated)
# The lane's own merge commit on a PR head (integrate). Fixed subject, so
# decide can tell such a head and ask for its Linux check (linux-dispatch).
LANE_MERGE_SUBJECT="fast lane: merge dev into the PR head"
NEEDS_REBASE_LABEL="needs-rebase"
# Batches (the header's second paragraph). The scratch branch and its probes
# live at REMOTE; each merge commit's subject names the PR and the head merged.
BATCH_PREFIX="lane/batch-"
BATCH_SUBJECT_RE='^fast lane batch: PR #([0-9]+) at ([0-9a-f]{40})$'
NEEDS_FIX_LABEL="needs-fix"
# The batch macOS gate. fast-lane.yml sets these from the repo variables of the
# same names; unset or empty means the default here.
case "${LANE_MAC_PER_PR:-0}" in 0) LANE_MAC_PER_PR=0 ;; *) LANE_MAC_PER_PR=1 ;; esac  # 1: the rollback (per-PR macOS build, Linux-only batches)
# 1: verify after merge (docs/fast-lane.md): a code PR lands alone on Linux proof plus
# PRESCREEN_CONTEXT (prescreen_gate, settle_ready), and a red dev's culprit is reverted (revert_sweep).
case "${LANE_VERIFY_AFTER:-0}" in 0) LANE_VERIFY_AFTER=0 ;; *) LANE_VERIFY_AFTER=1 ;; esac
LANE_MAC_SLOTS="${LANE_MAC_SLOTS:-4}"            # lane macOS runs queued or running before no batch forms (5 hosted runners, one kept for dev)
LANE_BATCH_MAX="${LANE_BATCH_MAX:-12}"           # PRs per batch, and probes per bisect (12 PRs need at most 4)
LANE_BATCH_WAIT_MIN="${LANE_BATCH_WAIT_MIN:-10}" # with no slot just freed, form once the oldest ready head is this old (minutes)
[[ "$LANE_MAC_SLOTS" =~ ^[0-9]+$ ]] || LANE_MAC_SLOTS=4
[[ "$LANE_BATCH_MAX" =~ ^[1-9][0-9]*$ ]] || LANE_BATCH_MAX=12
[[ "$LANE_BATCH_WAIT_MIN" =~ ^[0-9]+$ ]] || LANE_BATCH_WAIT_MIN=10
MAX_BATCH="$LANE_BATCH_MAX"
MAC_GATE_TITLE="macOS gate"         # ci.yml's run-name for a mac_only run ("macOS gate: <apps>" when scoped)
MAC_GATE_RE='^macOS( \(.*\))?$'     # its job, full or scoped; never "macOS build" or "macOS journeys"
LOCAL_MAC_CONTEXT="local-ci/macos"  # the local Mac gate's commit status, a macOS pass like the job
# The supervisor's pre-screen on the Mac (dev plus the PR: compile and Model
# tests): with LANE_VERIFY_AFTER=1 a code PR's macOS proof (prescreen_gate).
PRESCREEN_CONTEXT="local-ci/prescreen"
SLOT_FREED=0     # a batch resolved in this run: the next one forms without the timer
BATCH_APPS=""    # the batch being resumed: its macOS gate scope (apps, all, or empty for no macOS gate)
BATCH_IGNORE=""  # its jobs red on BASE_BRANCH alone (Linux, macOS), set aside while bisecting
BASE_MAC_SET=0   # 1: the base and tip fail macOS, judged by test against the base's (BASE_MAC_FAILS)
BASE_MAC_FAILS="" # those tests, one <File>.swift/<test> per line, sorted (mac_tests)
# After starting a Linux run on a batch, wait this long (seconds, polling
# every BATCH_POLL) for its verdict in the same run before leaving the rest to
# the next sweep. Tests set it to 0.
BATCH_WAIT="${FAST_LANE_BATCH_WAIT:-420}"
BATCH_POLL="${FAST_LANE_BATCH_POLL:-60}"
READY=()   # eligible PRs this pass, n|head|branch|proof (settle_ready lands or batches them)
HOLD=0     # a batch is in flight: eligible PRs wait for the next sweep
INFLIGHT=" "  # PRs in a batch still waiting (batch_held): never batched or landed twice
BASE_RED=""      # the open dev-red issue (red_sweep), whatever job it names
BASE_RED_JOBS="" # its "- Failing jobs:" line, lowercased: red_holds reads linux and macos off it
BASE_RED_SHA=""  # its culprit range's red sha: a batch whose base holds it gets a <batch>-red marker
SCRATCH="" # the run's scratch clone of REMOTE (scratch)
# Culprit by bisect on a red BASE_BRANCH (red_sweep, red_bisect).
RED_LABEL="dev-red"
BISECT_PREFIX="ci/bisect-"  # ci/bisect-<red7>-<i>: the i-th first-parent commit past the good one
MAX_BISECT="${FAST_LANE_MAX_BISECT:-8}"  # Linux runs per red, probes counted
MAX_BISECT_BUDGET="${FAST_LANE_MAX_BISECT_BUDGET:-12}"  # Linux runs per red in vote mode (a budget test), runs counted
BUDGET_NEAR="0.15"          # a measured value at most this far past its budget makes the culprit "likely"
CLEF_MIN="0.80"             # a red-triage culprit guess at or above this is probed first
BISECT_MARK="<!-- lane-bisect"  # the culprit comment's marker: "<!-- lane-bisect <red7> -->"
BASE_RED_RUN=""  # the dev-red issue's "- Run:" URL
# Flake check (flake_check): a red run's failed jobs are rerun once at the red
# sha before dev counts as red; the dev-red issue carries one mark per sha:
# "<!-- lane-rerun <sha7> started|flake|red -->".
RERUN_MARK="<!-- lane-rerun"
FLAKY_LABEL="flaky"
BASE_RED_SCOPE=""  # the red's module as a path regex (red_scope); a ready PR touching it waits, the rest batch. Empty: the whole queue waits.
# Auto-revert (revert_sweep, LANE_VERIFY_AFTER=1).
REVERT_PREFIX="lane/revert-"    # the revert's branch: lane/revert-<culprit PR>
REVERT_LABEL="lane-revert"      # on the lane's revert PR (never fast-lane: revert_land lands it)
REVERT_MARK="<!-- lane-revert"  # the lane's one revert call per culprit on a dev-red issue: "<!-- lane-revert <sha7|none> -->"
FINDING_LABEL="finding"
# Auto-quarantine (quarantine_sweep, LANE_VERIFY_AFTER=1): a real red the lane has no revert for.
QUAR_FILE="UITests/quarantine.json"  # PROTECTED; the lane's own PR is the one exception (quarantine_land)
QUAR_BRANCH="lane/quarantine"        # the lane's one quarantine PR at a time (adds or removes entries)
QUAR_LABEL="lane-quarantine"         # on it (never fast-lane: quarantine_land lands it on its Linux check)
QUAR_MARK="<!-- lane-quarantine"     # one quarantine call per red sha on the dev-red issue: "<!-- lane-quarantine <red7> -->"
QUAR_LINE="Lane-Quarantine:"         # the PR body's kind line: "Lane-Quarantine: add" or "Lane-Quarantine: remove #<owner> ..."
QUAR_MAX=5                           # more failing tests than this is a broad break: today's red handling stands
QUAR_HOURS=24                        # an entry's expiry; past it the owner issue is labelled BLOCKER_LABEL and the entry stays
QUAR_NEVER_RE='security|billing|auth|licen[cs]e|payment|keychain|entitlement'  # never quarantined (in the test's path or id, any case)
BLOCKER_LABEL="blocker"
quar_now() { echo "${FAST_LANE_NOW:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}"; }  # the sweep's clock; tests pin it
RED_UNRESOLVED=0  # revert_sweep: the red stands and the lane has no revert to make or land for it (quarantine_sweep acts)
# Where integrate fetches and pushes; tests point it at a local bare repo.
REMOTE="${FAST_LANE_REMOTE:-https://github.com/${GH_REPO:-qbtrix/creative-apps}.git}"
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# After dispatching, look this many times, 5s apart, for the new run's URL to comment.
RUN_LOOKUP_RETRIES="${FAST_LANE_RUN_LOOKUP_RETRIES:-6}"
# A cancelled build on a head is dispatched again once it has been cancelled
# this many seconds: at most one re-dispatch per head per interval.
BUILD_RETRY_SECS="${FAST_LANE_BUILD_RETRY_SECS:-1800}"

# The worker's proof that scripts/ci passed on the head: this line, then `Head: <sha>`.
MARKER_LINE="Fast-Check: pass"
HEAD_LINE="Head: "

REPO="${GH_REPO:-qbtrix/creative-apps}"
DRY_RUN=0
MERGED_ANY=0
DISPATCH_FEATURE=0  # merged a FEATURE_LABEL PR this run
DISPATCH_UI=0       # merged a PR touching UI_RE this run
DISPATCH_REVERT=0   # merged a REVERT_LABEL PR this run
MERGED_RUN=0        # PRs merged this run
# A merged PR touching these paths needs the macOS job (Belt v2 lessons 49, 73).
UI_RE='^(Sources/[A-Za-z0-9_]+App/|Sources/SuiteUI/|Tests/App|UITests/)'
DISPATCH_EVERY=10   # dispatch once the base holds this many merged PRs since the last CI run
# GitHub recomputes `mergeable` lazily after any push to the base branch and
# reports UNKNOWN meanwhile. Re-read the PR this many times, 5s apart, before
# calling it not ready; otherwise a PR checked right after another merge stalls.
UNKNOWN_RETRIES="${FAST_LANE_UNKNOWN_RETRIES:-8}"

# Drops AI attribution lines from a body on stdin: Co-Authored-By trailers
# naming Claude or Anthropic, claude-session links, and "Generated by/with
# Claude" footers anywhere on a line (the cloud's "_Generated by [Claude
# Code](...)_" and the "🤖 Generated with [Claude Code]" one). land() runs
# the squash message through it, so none reaches history; evaluate() asks the
# author once (ATTRIBUTION_ASK). The pattern is ASCII apart from the robot, so
# it matches in any locale.
strip_attribution() {
  grep -v -i -E '^[[:space:]]*(co-authored-by:.*(claude|anthropic)|claude-session:)|generated (with|by) \[?claude|🤖[[:space:]]*generated with' || true
}
ATTRIBUTION_ASK="Fast lane: this PR body has AI attribution lines (\"Generated by Claude Code\", \"🤖 Generated with\" or a Co-Authored-By: Claude trailer). The lane strips them from the squash commit, so nothing waits on this, but please delete them from the body and leave them out of your next PRs."

# A lead's PR has this line (CLAUDE.md, "Feature leads"): one slice of a
# feature, whose issue carries FEATURE_ISSUE_LABEL. Merging a slice must never
# close that issue (three were closed while their leads said not done), but
# the finding and gap issues the slice fixes still close.
LEAD_RE='^[[:space:]]*Feature:'
FEATURE_ISSUE_LABEL="feature-lead"
# A closing keyword (close, closes, closed, fix, fixes, fixed, resolve,
# resolves, resolved; any case, a colon or not) and the issue it closes: #n,
# owner/repo#n or an issue URL. jq (Oniguruma) syntax, matched with "i".
CLOSE_RE='(?<![A-Za-z0-9_])(?<kw>close[sd]?|fix(?:e[sd])?|resolve[sd]?)(?<sep>:?[ \t]*)(?<ref>#[0-9]+|[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+#[0-9]+|https://github\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+/issues/[0-9]+)'
# jq: a reference as owner/repo#n (#n is in REPO).
# shellcheck disable=SC2016 # jq code, not shell
REF_KEY_JQ='def key: if startswith("#") then $repo + . elif startswith("https://") then
  (capture("github\\.com/(?<r>[^/]+/[^/]+)/issues/(?<n>[0-9]+)") | "\(.r)#\(.n)") else . end;'

# closing_refs: the issues the closing keywords in the body on stdin point
# at, as owner/repo#n, one per line.
closing_refs() {
  jq -Rr --arg re "$CLOSE_RE" --arg repo "$REPO" "$REF_KEY_JQ"'match($re; "gi") | .captures[] | select(.name == "ref") | .string | key' | sort -u
}

# lead_refs <owner/repo#n lines>: the body on stdin with the closing keyword
# before each of those issues turned into `Refs`; every other line and
# keyword unchanged. Idempotent: `Refs` is no keyword.
lead_refs() {
  jq -Rr --arg re "$CLOSE_RE" --arg repo "$REPO" --arg f "$1" "$REF_KEY_JQ"'($f | split("\n")) as $f
    | gsub($re; (.ref | key) as $k | if any($f[]; . == $k) then "Refs \(.ref)" else "\(.kw)\(.sep // "")\(.ref)" end; "i")'
}

# issue_is_feature <owner/repo#n>: sets FEATURE to y when the issue carries
# FEATURE_ISSUE_LABEL, n when not; returns 1 when its labels can't be read.
# One gh call per issue per lane run: answers are cached in FEATURE_SEEN
# (" key=y key=n"; bash 3.2 has no associative arrays). Failures aren't.
FEATURE_SEEN="" FEATURE=""
issue_is_feature() {
  local k="$1" got
  case "$FEATURE_SEEN" in *" $k="*) got="${FEATURE_SEEN##*" $k="}"; FEATURE="${got%% *}"; return 0 ;; esac
  got=$(gh api "repos/${k%#*}/issues/${k##*#}" \
    --jq "if [.labels[]?.name] | index(\"$FEATURE_ISSUE_LABEL\") then \"y\" else \"n\" end" 2>/dev/null) || return 1
  case "$got" in y|n) ;; *) return 1 ;; esac
  FEATURE_SEEN+=" $k=$got" FEATURE="$got"
}

# lead_issues <body>: sorts the issues the body's closing keywords point at
# into LEAD_FEATURES (feature-lead issues, one per line) and LEAD_UNREAD
# (labels unreadable, joined by ", "). Runs in the caller's shell, so the
# cache outlives it.
LEAD_FEATURES="" LEAD_UNREAD=""
lead_issues() {
  local k
  LEAD_FEATURES="" LEAD_UNREAD=""
  while IFS= read -r k; do
    [[ -n "$k" ]] || continue
    if ! issue_is_feature "$k"; then LEAD_UNREAD+="${LEAD_UNREAD:+, }$k"
    elif [[ "$FEATURE" == y ]]; then LEAD_FEATURES+="$k"$'\n'
    fi
  done < <(closing_refs <<<"$1")
}

log() { printf '  %s\n' "$*" >&2; }

# has_marker <pr.json> <head sha>: the body has the line MARKER_LINE directly
# followed by `Head: <head sha>`, each compared after trimming spaces (Belt's
# verdict parsing). A marker for an older head does not count.
has_marker() {
  jq -r '.body // ""' "$1" | tr -d '\r' | awk -v mark="$MARKER_LINE" -v head="$HEAD_LINE$2" '
    { sub(/^[ \t]+/, ""); sub(/[ \t]+$/, "") }
    prev == mark && $0 == head { found = 1 }
    { prev = $0 }
    END { exit !found }'
}

# mac_check_url <pr.json>: the URL on the body's last `Mac-Check:` line, trimmed.
mac_check_url() {
  jq -r '.body // ""' "$1" | tr -d '\r' | awk -v mark="$MAC_CHECK_LINE" '
    { sub(/^[ \t]+/, ""); sub(/[ \t]+$/, "") }
    index($0, mark) == 1 { url = substr($0, length(mark) + 1); sub(/^[ \t]+/, "", url) }
    END { print url }'
}

# mac_run_id <url>: the run id when <url> is a workflow run of REPO, else nothing.
# Case-insensitive through nocasematch, restored after: ${x,,} needs bash 4,
# and the supervisor runs these tests with macOS's bash 3.2.
mac_run_id() {
  local re="^https://github\.com/${REPO//./\\.}/actions/runs/([0-9]+)(/.*)?\$" id="" was=0
  shopt -q nocasematch && was=1
  shopt -s nocasematch
  if [[ "$1" =~ $re ]]; then id="${BASH_REMATCH[1]}"; fi
  (( was )) || shopt -u nocasematch
  [[ -z "$id" ]] || echo "$id"
}

# mac_judge <run.json> <head sha>: nothing when the run (`gh run view --json
# workflowName,status,headSha,jobs`) is a completed CI run on <head sha> whose
# macOS job passed; else what is wrong.
mac_judge() {
  local runjson='{}'
  [[ -z "$1" || ! -s "$1" ]] || runjson=$(cat "$1")
  jq -r --arg wf "${CI_WORKFLOWS[0]}" --arg job "$MAC_JOB" --arg head "$2" '
    def lc: (. // "") | ascii_downcase;
    ([.jobs[]? | select(.name == $job)] | last) as $j
    | if (.workflowName // "") == "" then "its run could not be read"
      elif .workflowName != $wf then "its run is the \(.workflowName) workflow, not \($wf)"
      elif (.status | lc) != "completed" then "its run has not completed"
      elif $j == null then "its run has no \($job) job"
      elif ($j.conclusion | lc) != "success" then "its \($job) job is \($j.conclusion // "unfinished")"
      elif (.headSha // "") != $head then "its run is on \(.headSha // "no head"), not the head \($head)"
      else empty end' <<<"$runjson" 2>/dev/null || echo "its run could not be read"
}

# build_paths <files.txt>: the BUILD_RE files among <files.txt> by target
# folder (Sources/X, Tests/X, UITests) or manifest, joined by ", ".
build_paths() {
  grep -E "$BUILD_RE" "$1" | sed -E 's:^((Sources|Tests)/[^/]+|UITests)/.*:\1:' | sort -u | paste -sd, - | sed 's/,/, /g' || true
}

# build_apps <files.txt>: the apps a build-only run of the PR's BUILD_RE files
# compiles, comma-separated (photo or design,photo), from main's
# scripts/test-scope build-apps. `all` when that fails or prints anything
# else: when in doubt, build everything.
build_apps() {
  local apps
  apps=$(grep -E "$BUILD_RE" "$1" | python3 "$HERE/test-scope" build-apps 2>/dev/null) || apps=all
  [[ "$apps" =~ ^[a-z]+(,[a-z]+)*$ ]] || apps=all
  echo "$apps"
}

# mac_scope <files.txt>: the apps a batch macOS gate runs for these changed
# paths: build_apps over the code, joined with main's scripts/test-scope
# scopes over every path (a golden PNG or a fixture a test reads counts), so
# the gate runs the tests scripts/test-scope changed picks. `all` when either
# says so or test-scope fails; empty when nothing needs macOS.
mac_scope() {
  local code="" tests
  [[ -z "$(build_paths "$1")" ]] || code=$(build_apps "$1")
  tests=$(python3 "$HERE/test-scope" scopes <"$1" 2>/dev/null) || tests=all
  [[ "$tests" =~ ^([a-z]+(,[a-z]+)*)?$ ]] || tests=all
  case ",$code,$tests," in *,all,*) echo all; return ;; esac
  # shellcheck disable=SC2086 # comma lists split into words
  printf '%s\n' ${code//,/ } ${tests//,/ } | sort -u | paste -sd, -
}

# build_gate <pr.json> <files.txt> <mac-check run.json> <build run.json>:
# nothing when the PR touches no BUILD_RE code, else one line:
#   ok|<proof>  dispatch|<paths>|<branch>|<apps>  wait|<url>  refuse|<what to do>
# A green Mac-Check run on the head (it builds every app) counts; otherwise
# the latest build-only run on the head ({} when none: dispatch one). A
# queued or running one waits; a cancelled one is dispatched again once it is
# BUILD_RETRY_SECS old (by updatedAt), and waits until then.
build_gate() {
  local pr="$1" paths head branch url run='{}' st
  paths=$(build_paths "$2")
  [[ -n "$paths" ]] || return 0
  head=$(jq -r '.headRefOid' "$pr")
  branch=$(jq -r '.headRefName // ""' "$pr")
  url=$(mac_check_url "$pr")
  if [[ -n "$url" && -n "$(mac_run_id "$url")" && -z "$(mac_judge "${3:-}" "$head")" ]]; then
    echo "ok|$MAC_CHECK_LINE $url"; return
  fi
  [[ -z "${4:-}" || ! -s "$4" ]] || run=$(cat "$4")
  url=$(jq -r '.url // ""' <<<"$run" 2>/dev/null || true)
  if [[ -z "$url" || "$(jq -r '.headSha // ""' <<<"$run")" != "$head" ]]; then
    echo "dispatch|$paths|$branch|$(build_apps "$2")"; return
  fi
  st=$(jq -r '(.status // "" | ascii_downcase) + " " + (.conclusion // "" | ascii_downcase)' <<<"$run")
  case "$st" in
    "completed success") echo "ok|$BUILD_JOB $url" ;;
    "completed cancelled")
      local at
      at=$(jq -r '(.updatedAt // .createdAt // "") as $d | if $d == "" then 0 else ($d | try fromdateiso8601 catch 0) end' <<<"$run")
      if (( $(date +%s) - at >= BUILD_RETRY_SECS )); then echo "dispatch|$paths|$branch|$(build_apps "$2")"
      else echo "wait|$url"; fi ;;
    completed*) echo "refuse|changes code ($paths), and its head $head doesn't build on macOS: $url (${st#completed }). Fix it and push; the lane builds the new head on macOS again" ;;
    *) echo "wait|$url" ;;
  esac
}

# prescreen_gate <checks.json> <files.txt> <head sha>: with LANE_VERIFY_AFTER=1,
# nothing when the PR touches no BUILD_RE code, else its PRESCREEN_CONTEXT
# status on the head as one decide line: ok|<proof> on success, red|<context>
# on failure, pending|<why> while missing or pending. prescreen.sh screens a
# head once, so a new push waits for its next round.
prescreen_gate() {
  [[ -n "$(build_paths "$2")" ]] || return 0
  case "$(jq -r --arg c "$PRESCREEN_CONTEXT" '[.[] | select(.context == $c) | .state][0] // "MISSING"' "$1")" in
    SUCCESS) echo "ok|$PRESCREEN_CONTEXT" ;;
    FAILURE|ERROR) echo "red|$PRESCREEN_CONTEXT" ;;
    *) echo "pending|waiting for $PRESCREEN_CONTEXT on head $3" ;;
  esac
}

# audit_fetch <sha> <dir> <path>: <path> at <sha> into <dir>/<path>.
audit_fetch() {
  gh api -H 'Accept: application/vnd.github.raw+json' "repos/$REPO/contents/$3?ref=$1" >"$2/$3"
}

# audit_snapshot <sha> <dir>: the app audit's files at <sha>, mirrored under
# <dir>: the baseline and the registry's AuditCore.swift with their content,
# every other file empty (only its path counts, and a stray AuditCore.swift
# elsewhere can't pad the registry). Returns non-zero when the API fails.
audit_snapshot() {
  local sha="$1" out="$2" p
  mkdir -p "$out" || return 1
  gh api "repos/$REPO/git/trees/$sha?recursive=1" >"$out.tree" || return 1
  jq -e '.truncated | not' "$out.tree" >/dev/null || return 1
  jq -r --arg re "$AUDIT_RE" '.tree[] | select(.type == "blob" and (.path | test($re))) | .path' \
    "$out.tree" >"$out.paths" || return 1
  while IFS= read -r p; do
    mkdir -p "$out/$(dirname "$p")" || return 1
    if [[ "$p" == "$AUDIT_BASELINE" || "$p" =~ $AUDIT_REGISTRY_RE ]]; then
      audit_fetch "$sha" "$out" "$p" || return 1
    else
      : >"$out/$p"
    fi
  done <"$out.paths"
}

# audit_read_checks <base sha> <head sha> <before dir> <after dir>: when the
# head adds check files, reads them and every check file at the base, so
# audit_new_ids can match new baseline keys to new checks. Nothing otherwise.
audit_read_checks() {
  local p added
  added=$(comm -13 <(audit_checks "$3") <(audit_checks "$4"))
  [[ -n "$added" ]] || return 0
  while IFS= read -r p; do audit_fetch "$2" "$4" "$p" || return 1; done <<<"$added"
  while IFS= read -r p; do audit_fetch "$1" "$3" "$p" || return 1; done < <(audit_checks "$3")
}

# audit_lists <dir>: each `static let checks: [any Check] = [...]` declaration
# in the AuditCore.swift files under <dir>, one per line, comments stripped.
# ponytail: a text scan, not a parser; "//" inside a string or a `]` inside
# the list fools it. Upgrade to a SwiftSyntax tool if that bites.
audit_lists() {
  find "$1" -name AuditCore.swift -type f -exec cat {} + 2>/dev/null | sed 's://.*$::' | tr '\n' ' ' \
    | sed 's:/\*[^*]*\*/::g' | grep -oE 'static (let|var) checks *: *\[any Check\] *= *\[[^]]*\]' || true
}

# audit_registry <dir>: the check types in AppAudit.checks, one per line.
audit_registry() {
  audit_lists "$1" | sed 's/^.*= *\[//' | grep -oE '[A-Za-z_][A-Za-z0-9_]*\(' | tr -d '(' | sort -u || true
}

# audit_checks <dir>: the paths of the check files under <dir>.
audit_checks() {
  (cd "$1" 2>/dev/null && find . -path '*/Checks/*.swift' -type f | sed 's:^\./::' | sort -u) || true
}

# audit_new_ids <before dir> <after dir>: the ids of the checks this PR adds:
# a new file under Checks/ whose `struct X: Check` is new in AppAudit.checks
# and whose `let id = "..."` no check at the base already uses.
audit_new_ids() {
  local new_types base_ids p f t i
  new_types=$(comm -13 <(audit_registry "$1") <(audit_registry "$2"))
  base_ids=$(audit_checks "$1" | while IFS= read -r p; do audit_check_id "$1/$p"; done)
  while IFS= read -r p; do
    [[ -n "$p" ]] || continue
    f="$2/$p"
    t=$(sed 's://.*$::' "$f" | grep -oE 'struct +[A-Za-z_][A-Za-z0-9_]* *: *(AppAudit\.)?Check([^A-Za-z0-9_]|$)' \
      | head -1 | sed -E 's/struct +([A-Za-z0-9_]+).*/\1/' || true)
    i=$(audit_check_id "$f")
    if [[ -n "$t" && -n "$i" ]] && grep -qxF -- "$t" <<<"$new_types" && ! grep -qxF -- "$i" <<<"$base_ids"; then
      echo "$i"
    fi
  done < <(comm -13 <(audit_checks "$1") <(audit_checks "$2"))
}

# audit_check_id <check file>: its `let id = "..."`, comments stripped.
audit_check_id() {
  sed 's://.*$::' "$1" 2>/dev/null | grep -oE 'let id *= *"[^"]+"' | head -1 | sed -E 's/.*"(.*)"/\1/' || true
}

# audit_loosens <before dir> <after dir>: one line per way the PR loosens the
# app audit, nothing when it doesn't. Looser: an existing count goes up (a
# check missing from a listed app counts as 0), a new app arrives above 0 (its
# counts aren't anchored), an app leaves the baseline (an app missing from the
# file isn't judged), a check file goes (moving one counts), an entry leaves
# AppAudit.checks, or a second list appears to hide that. Fine: lowering a
# count, and a new check's key at any count in an existing app when the same
# PR adds that check's file and registry entry (any check beats none).
audit_loosens() {
  local before="$1" after="$2" lists
  jq -rn --slurpfile b <(cat "$before/$AUDIT_BASELINE" 2>/dev/null || echo '{}') \
         --slurpfile a <(cat "$after/$AUDIT_BASELINE" 2>/dev/null || echo '{}') \
         --argjson new "$(audit_new_ids "$before" "$after" | jq -R . | jq -s .)" '
    def counts: type == "object" and all(.[]; type == "object" and all(.[]; type == "number"));
    ($b[0] // {}) as $b | ($a[0] // {}) as $a
    | if ($a | counts) and ($b | counts) then
        ( $a | to_entries[] | .key as $app | .value | to_entries[]
          | ($b[$app] // {})[.key] as $was
          | select(.value > ($was // 0))
          | select($was != null or $b[$app] == null or (.key as $k | $new | any(. == $k) | not))
          | "\($app) \(.key) \($was // "new") -> \(.value)" ),
        ( $b | keys[] | select($a[.] == null) | "drops \(.) from the baseline" )
      else "the baseline is not app -> check -> count" end' 2>/dev/null \
    || echo "the baseline is not valid JSON"
  comm -23 <(audit_checks "$before") <(audit_checks "$after") | sed 's/^/removes /'
  comm -23 <(audit_registry "$before") <(audit_registry "$after") | sed 's/^/drops /; s/$/ from AppAudit.checks/'
  lists=$(audit_lists "$after" | wc -l | tr -d ' ')
  (( lists <= 1 )) || echo "AppAudit.checks is declared $lists times"
}

# dup_logic <pr.json> <added.txt>: one line per added concept file the body has
# no Allow-Dup line for, or `error: <why>` when the check can't run (the PR
# then waits, like an unreadable audit: never merged unchecked).
dup_logic() {
  local out rc=0
  out=$(python3 "$HERE/check-dup-logic" --paths "$2" --body <(jq -r '.body // ""' "$1") 2>/dev/null) || rc=$?
  if (( rc > 1 )); then echo "error: scripts/check-dup-logic could not run (exit $rc)"; else printf '%s' "$out"; fi
}

# dup_views <pr.json> <added.txt>: dup_logic for views (scripts/check-dup-views,
# Allow-Dup-View lines), with the same `error: <why>` when it can't run.
dup_views() {
  local out rc=0
  out=$(python3 "$HERE/check-dup-views" --paths "$2" --body <(jq -r '.body // ""' "$1") 2>/dev/null) || rc=$?
  if (( rc > 1 )); then echo "error: scripts/check-dup-views could not run (exit $rc)"; else printf '%s' "$out"; fi
}

# decide <pr.json> <files.txt> <checks.json> [<audit before dir> <audit after dir>
#   [<mac-check run.json> <unused> [<build run.json> [<added.txt>]]]]
# (pass "" "" for the audit dirs when the PR doesn't touch the audit; the
# seventh argument is ignored, a slot kept so callers didn't shift; added.txt
# lists the PR's added and renamed-to paths, "" or missing skips dup_logic and dup_views)
decide() {
  local pr="$1" files="$2" checks="$3"
  local state draft base has_label author adds dels nfiles lines mergeable mstate head
  state=$(jq -r '.state' "$pr")
  draft=$(jq -r '.isDraft' "$pr")
  base=$(jq -r '.baseRefName' "$pr")
  has_label=$(jq -r --arg l "$LABEL" '[.labels[]?.name] | index($l) != null' "$pr")
  author=$(jq -r '.author.login' "$pr")
  adds=$(jq -r '.additions' "$pr")
  dels=$(jq -r '.deletions' "$pr")
  nfiles=$(jq -r '.changedFiles' "$pr")
  mergeable=$(jq -r '.mergeable' "$pr")
  mstate=$(jq -r '.mergeStateStatus' "$pr")
  head=$(jq -r '.headRefOid' "$pr")
  lines=$((adds + dels))

  local skip="" retarget="" reasons=() pending="" red="" ngreen=0 review="" tier=""

  log "state=$state draft=$draft base=$base label=$has_label"
  [[ "$state" == "OPEN" ]] || skip="PR is $state"
  [[ -n "$skip" || "$draft" != "true" ]] || skip="PR is a draft"
  [[ -n "$skip" || "$has_label" == "true" ]] || skip="no $LABEL label"
  if [[ -z "$skip" && "$base" != "$BASE_BRANCH" ]]; then
    if [[ "$base" == "main" ]]; then retarget="$base"; else skip="base is $base, not $BASE_BRANCH"; fi
  fi

  if [[ " $FAST_LANE_AUTHORS " == *" $author "* ]]; then
    log "author: ok ($author)"
  else
    log "author: FAIL ($author)"; reasons+=("author $author is not on the fast-lane allowlist")
  fi
  if (( lines <= MAX_LINES && nfiles <= MAX_FILES )); then
    log "size: ok ($lines lines, $nfiles files)"
  elif grep -qE "$DOCS_RE" "$files" && ! grep -qvE "$DOCS_RE|^\$" "$files" \
      && (( $(grep -c . "$files") >= nfiles )); then
    log "size: ok, docs only ($lines lines, $nfiles files)"; tier=", docs only: any size"
  else
    log "size: FAIL ($lines lines, $nfiles files)"
    reasons+=("too big: $lines lines, $nfiles files (max $MAX_LINES lines, $MAX_FILES files)")
  fi
  local denied
  denied=$(grep -Ei -- "$DENY_RE" "$files" | paste -sd, - || true)
  if [[ -z "$denied" ]]; then
    log "paths: ok"
  else
    log "paths: FAIL ($denied)"; reasons+=("touches protected paths: ${denied//,/, }")
  fi
  if [[ -n "${4:-}" ]]; then
    local loose
    loose=$(audit_loosens "$4" "$5" | paste -sd, -)
    if [[ -z "$loose" ]]; then
      log "audit: ok"
    else
      log "audit: FAIL ($loose)"; reasons+=("$AUDIT_REASON (${loose//,/, })")
    fi
  fi

  if [[ -n "${9:-}" && -s "${9:-}" ]]; then
    local dups
    dups=$(dup_logic "$pr" "$9" | paste -sd, -)
    case "$dups" in
      "") log "canonical first: ok" ;;
      error:*) log "canonical first: ${dups#error: }"; pending="${dups#error: }" ;;
      *) log "canonical first: FAIL ($dups)"; reasons+=("$DUP_REASON: ${dups//,/, }") ;;
    esac
    dups=$(dup_views "$pr" "$9" | paste -sd, -)
    case "$dups" in
      "") log "suiteui first: ok" ;;
      error:*) log "suiteui first: ${dups#error: }"; pending="${pending:-${dups#error: }}" ;;
      *) log "suiteui first: FAIL ($dups)"; reasons+=("$DUP_VIEW_REASON: ${dups//,/, }") ;;
    esac
  fi

  local conflict=0
  if [[ "$mergeable" == "MERGEABLE" && ! "$mstate" =~ ^(DIRTY|UNKNOWN|BLOCKED|DRAFT)$ ]]; then
    log "mergeable: ok ($mstate)"
  elif [[ "$mergeable" == "CONFLICTING" ]]; then
    log "mergeable: CONFLICTING ($mstate)"; conflict=1
  else
    log "mergeable: not ready ($mergeable/$mstate)"; pending="not mergeable yet ($mergeable/$mstate)"
  fi

  # Belt's review status is judged on its own below, and only for Belt PRs.
  local belt=0
  if (( REQUIRE_BELT_REVIEW )) && jq -r '.body // ""' "$pr" | grep -qE '^[[:space:]]*Belt-(Run|Test):'; then
    belt=1
    review=$(jq -r --arg c "$BELT_REVIEW_CONTEXT" \
      '[.[] | select((.context // .name // "") == $c) | (.state // .conclusion // "")][0] // "MISSING"' "$checks")
    log "belt review: $review"
  fi

  # With LANE_VERIFY_AFTER=1 a code PR's macOS proof is the pre-screen
  # (prescreen_gate). With LANE_MAC_PER_PR=1 it is the macOS build check,
  # build_gate's to judge. Otherwise macOS is the batch's gate and a per-PR
  # build proves nothing. Either way it leaves the red and running lists below.
  local mac="" macdrop="$BUILD_JOB"
  if (( LANE_VERIFY_AFTER )); then
    mac=$(prescreen_gate "$checks" "$files" "$head")
  elif (( LANE_MAC_PER_PR )); then
    mac=$(build_gate "$pr" "$files" "${6:-}" "${8:-}")
    [[ -n "$mac" ]] || macdrop=""
  fi

  # Drop our own check, CI's report-only macOS jobs, Belt's review, the
  # pre-screen (judged above, and only in that mode) and Copilot review
  # checks, then classify the rest.
  local ci_json summary
  ci_json=$(printf '%s\n' "${CI_WORKFLOWS[@]}" "${CI_CHECKS[@]}" | jq -R . | jq -s .)
  summary=$(jq -c --arg self "$SELF_WORKFLOW" --arg selfcheck "$SELF_CHECK" \
      --arg review "$BELT_REVIEW_CONTEXT" --argjson ci "$ci_json" --arg macdrop "$macdrop" \
      --arg report "$REPORT_ONLY_RE" --arg prescreen "$PRESCREEN_CONTEXT" '
    [ .[]
      | select((.workflowName // "") != $self and (.name // "") != $selfcheck)
      | select($macdrop == "" or (.name // "") != $macdrop)
      | select((.name // "") | test($report) | not)
      | select((.context // .name // "") != $review and (.context // .name // "") != $prescreen)
      | select(((.name // .context // "") + " " + (.workflowName // "")) | test("copilot"; "i") | not)
      | { name: (.name // .context),
          wf: (.workflowName // ""),
          s: (if .__typename == "StatusContext" then
                (if .state == "SUCCESS" then "ok"
                 elif (.state == "PENDING" or .state == "EXPECTED") then "pending"
                 else "red" end)
              elif .status != "COMPLETED" then "pending"
              elif (.conclusion == "SUCCESS" or .conclusion == "NEUTRAL" or .conclusion == "SKIPPED") then "ok"
              else "red" end) } ]
    | { red: [ .[] | select(.s == "red") | .name ],
        pending: [ .[] | select(.s == "pending") | .name ],
        green: ([ .[] | select(.s == "ok") ] | length),
        ci_passed: ([ .[] | select(.s == "ok" and ((.wf as $w | $ci | index($w) != null) or (.name as $n | $ci | index($n) != null))) ] | length) }' "$checks")
  red=$(jq -r '.red | join(", ")' <<<"$summary")
  ngreen=$(jq -r '.green' <<<"$summary")
  local npending nci marker=0
  npending=$(jq -r '.pending | length' <<<"$summary")
  nci=$(jq -r '.ci_passed' <<<"$summary")
  if has_marker "$pr" "$head"; then marker=1; fi
  # The lane's own merge commit as the head (integrate): no marker can name it,
  # so its proof is a Linux run, which the lane starts when none exists yet.
  # So does any other head with no check at all (per-PR CI doesn't run on dev
  # PRs), unless it comes from a fork; the sweep starts it once per head.
  local lane_head=0
  if [[ "$(jq -r --arg h "$head" '.commits // [] | last // {} | select(.oid == $h) | .messageHeadline // ""' "$pr")" == "$LANE_MERGE_SUBJECT" ]]; then
    lane_head=1
  fi
  # ponytail: "CI passed" = at least one *passing* check from CI_WORKFLOWS, so a
  # head where every CI job was skipped still needs the worker's marker.
  log "checks: green=$ngreen pending=$npending red=[${red}] ci_passed=$nci marker=$marker lane_head=$lane_head"

  if [[ -n "$skip" ]]; then echo "skip|$skip"; return; fi
  if [[ -n "$retarget" ]]; then echo "retarget|$retarget"; return; fi
  if (( ${#reasons[@]} )); then
    local IFS=';'; echo "not-eligible|${reasons[*]}"; return
  fi
  if [[ -n "$red" ]]; then echo "red|$red"; return; fi
  if (( belt )) && [[ "$review" =~ ^(FAILURE|ERROR)$ ]]; then echo "red|review failed"; return; fi
  if (( conflict )); then echo "conflict|$head"; return; fi
  if [[ -n "$pending" ]]; then echo "pending|$pending"; return; fi
  if (( npending )); then echo "pending|$npending checks still running"; return; fi
  if (( nci == 0 && marker == 0 )); then
    if (( lane_head || ngreen == 0 )) && [[ "$(jq -r '.isCrossRepository // false' "$pr")" != true ]]; then
      echo "linux-dispatch|$(jq -r '.headRefName // ""' "$pr")"; return
    fi
    echo "pending|no passing CI check and no $MARKER_LINE marker for head $head"; return
  fi
  if (( belt )) && [[ "$review" != "SUCCESS" ]]; then echo "pending|waiting for review"; return; fi
  log "build gate: ${mac:-no code}"
  case "$mac" in
    dispatch\|*) echo "build-dispatch|${mac#dispatch|}"; return ;;
    wait\|*) echo "pending|waiting for the macOS build ${mac#wait|} on head $head"; return ;;
    refuse\|*) echo "build-gate|${mac#refuse|}"; return ;;
    red\|*|pending\|*) echo "$mac"; return ;;
  esac
  local proof="Fast-Check marker"
  (( nci == 0 )) || proof="$ngreen checks green"
  [[ "$mac" != ok\|* ]] || proof+=", ${mac#ok|}"
  echo "eligible|$lines|$nfiles|$proof$tier"
}

# integrate <head sha> <head branch>: in a scratch clone, merges
# origin/BASE_BRANCH into the PR head with the repo's merge drivers (installed
# from this checkout: main's scripts, never the PR's) and pushes the merge
# commit to the head branch with a lease on <head sha>. Runs git and the
# drivers only; nothing from the PR's tree is executed. Prints one line:
#   integrated|<new head sha>   conflict|<unmerged files>   failed|<why>
integrate() {
  local head="$1" branch="$2" d files new
  d=$(mktemp -d)
  if ! git init -q "$d" || ! git -C "$d" remote add origin "$REMOTE" \
      || ! { git -C "$d" fetch -q --filter=blob:none origin "$BASE_BRANCH" "$branch" 2>/dev/null \
             || git -C "$d" fetch -q origin "$BASE_BRANCH" "$branch" 2>/dev/null; }; then
    echo "failed|could not fetch $BASE_BRANCH and $branch from $REMOTE"; rm -rf "$d"; return
  fi
  if [[ "$(git -C "$d" rev-parse "origin/$branch" 2>/dev/null)" != "$head" ]]; then
    echo "failed|$branch no longer points at $head"; rm -rf "$d"; return
  fi
  if ! git -C "$d" checkout -q -b work "origin/$branch" 2>/dev/null || ! bash "$HERE/install-merge-drivers" "$d" >/dev/null 2>&1; then
    echo "failed|could not check out $branch with the merge drivers"; rm -rf "$d"; return
  fi
  if ! git -C "$d" -c user.name="github-actions[bot]" -c user.email="41898282+github-actions[bot]@users.noreply.github.com" \
      merge -q --no-edit -m "$LANE_MERGE_SUBJECT" "origin/$BASE_BRANCH" >/dev/null 2>&1; then
    files=$(git -C "$d" diff --name-only --diff-filter=U | sort -u | paste -sd, - | sed 's/,/, /g')
    git -C "$d" merge --abort >/dev/null 2>&1 || true
    echo "conflict|${files:-files git could not name}"; rm -rf "$d"; return
  fi
  new=$(git -C "$d" rev-parse HEAD)
  if ! git -C "$d" push -q --force-with-lease="refs/heads/$branch:$head" origin "HEAD:refs/heads/$branch" 2>/dev/null; then
    echo "failed|push to $branch refused (it moved past $head)"; rm -rf "$d"; return
  fi
  rm -rf "$d"
  echo "integrated|$new"
}

# scratch <ref>...: fetches <ref>s from REMOTE into the run's one scratch clone
# (blob:none where the remote allows it) so origin/<ref> is current. Non-zero
# when the fetch fails.
scratch() {
  if [[ -z "$SCRATCH" ]]; then
    SCRATCH=$(mktemp -d)
    if ! git init -q "$SCRATCH" || ! git -C "$SCRATCH" remote add origin "$REMOTE"; then rm -rf "$SCRATCH"; SCRATCH=""; return 1; fi
  fi
  git -C "$SCRATCH" fetch -q --filter=blob:none origin "$@" 2>/dev/null || git -C "$SCRATCH" fetch -q origin "$@" 2>/dev/null
}

# proof_stale <base> <tip>: why a Linux proof of <tip>, run on top of <base>,
# no longer holds on origin/BASE_BRANCH in the scratch clone (lesson 244);
# nothing when it still does. Stale: dev changed a RATCHET_RE path since
# <base>, or <base>..<tip> changes one and dev moved on anything but the
# generated files (GENERATED_RE). A comparison that fails counts as stale.
# Trees only (--no-renames), so blob:none is enough.
proof_stale() {
  local mine dev hit
  if [[ -z "$1" ]] || ! mine=$(git -C "$SCRATCH" diff --name-only --no-renames "$1" "$2" 2>/dev/null) \
      || ! dev=$(git -C "$SCRATCH" diff --name-only --no-renames "$1" "origin/$BASE_BRANCH" 2>/dev/null); then
    echo "could not compare it with $BASE_BRANCH"; return
  fi
  hit=$(grep -iE -- "$RATCHET_RE" <<<"$dev" | paste -sd, - | sed 's/,/, /g' || true)
  if [[ -n "$hit" ]]; then echo "$BASE_BRANCH changed $hit since"; return; fi
  hit=$(grep -iE -- "$RATCHET_RE" <<<"$mine" | paste -sd, - | sed 's/,/, /g' || true)
  if [[ -n "$hit" ]] && grep -vE -- "$GENERATED_RE" <<<"$dev" | grep -q .; then echo "it changes $hit and $BASE_BRANCH moved since"; fi
}

# batch_branches: every batch branch at REMOTE, `<sha> <name>` per line.
batch_branches() {
  git ls-remote --heads "$REMOTE" "refs/heads/${BATCH_PREFIX}*" 2>/dev/null | sed 's:[[:space:]]*refs/heads/: :' | sort -k2 || true
}

# check_verdict <sha>: the newest Linux check run on <sha>:
#   none   running   green|<url>   red|<url>
check_verdict() {
  local runs
  runs=$(gh api "repos/$REPO/commits/$1/check-runs?per_page=100" --jq '.check_runs' 2>/dev/null) || { echo none; return; }
  jq -r --arg name "${CI_CHECKS[0]}" '
    ([ .[] | select(.name == $name and .conclusion != "action_required") ] | sort_by(.started_at // "") | last) as $r
    | if $r == null then "none"
      elif ($r.status | ascii_downcase) != "completed" then "running"
      elif (($r.conclusion // "") | ascii_downcase) == "success" then "green|\($r.details_url // $r.html_url // "")"
      else "red|\($r.details_url // $r.html_url // "")" end' <<<"$runs" 2>/dev/null || echo none
}

# dispatch_linux <branch> [<key>]: ci.yml's Linux job alone on <branch>, once
# per key (default the branch) per batch_resume or red_bisect call
# (DISPATCHED): a run takes seconds to show up, and a second dispatch on the
# same ref would cancel the first (ci.yml's concurrency). A vote probe keys on
# its run count, so its next run can start once the last one is in.
DISPATCHED=""
dispatch_linux() {
  local key="${2:-$1}"
  case "$DISPATCHED" in *" $key "*) log "Linux check on $1 just started; waiting for it to show up"; return 0 ;; esac
  DISPATCHED+=" $key "
  write gh workflow run "$CI_FILE" -R "$REPO" -f linux_only=true --ref "$1" || log "could not dispatch the Linux check on $1"
}

# dispatch_mac <branch> <key>: ci.yml's macOS gate alone (mac_only) on
# <branch>, scoped to BATCH_APPS, once per key per call like dispatch_linux.
dispatch_mac() {
  local app=()
  case "$DISPATCHED" in *" $2 "*) log "macOS gate on $1 just started; waiting for it to show up"; return 0 ;; esac
  DISPATCHED+=" $2 "
  [[ "$BATCH_APPS" == all ]] || app=(-f app="$BATCH_APPS")
  write gh workflow run "$CI_FILE" -R "$REPO" -f mac_only=true ${app[@]+"${app[@]}"} --ref "$1" || log "could not dispatch the macOS gate on $1"
}

# mac_verdict <sha>: the macOS gate on <sha>, from the newest MAC_GATE_RE check
# run and the LOCAL_MAC_CONTEXT commit status. A red from either outranks a
# green from the other (the local gate skips its known reds, CI_LOCAL_SKIP, so
# its pass never covers a GitHub failure); otherwise a pass from either counts,
# so a local pass lands while the GitHub job still runs:
#   none   running   green|<url>   red|<url>|<job>
# Any other conclusion (cancelled, timed out) is red, as check_verdict reads
# Linux. An unreadable API answers running, so a blip never starts a second run.
mac_verdict() {
  local runs st
  runs=$(gh api "repos/$REPO/commits/$1/check-runs?per_page=100" --jq '.check_runs' 2>/dev/null) || { echo running; return; }
  st=$(gh api "repos/$REPO/commits/$1/status" --jq '.statuses' 2>/dev/null) || { echo running; return; }
  jq -rn --argjson runs "${runs:-[]}" --argjson st "${st:-[]}" --arg re "$MAC_GATE_RE" --arg ctx "$LOCAL_MAC_CONTEXT" '
    def lc: (. // "") | ascii_downcase;
    ([ $runs[] | select((.name // "" | test($re)) and .conclusion != "action_required") ] | sort_by(.started_at // "") | last) as $r
    | ([ $st[] | select(.context == $ctx) ] | first) as $s
    | (if $r == null then "none" elif ($r.status | lc) != "completed" then "running"
       elif ($r.conclusion | lc) == "success" then "green|\($r.details_url // $r.html_url // "")"
       else "red|\($r.details_url // $r.html_url // "")|\($r.name)" end) as $gh
    | (if $s == null then "none" elif ($s.state | lc) == "success" then "green|\($s.target_url // "")"
       elif ($s.state | lc) == "pending" then "running" else "red|\($s.target_url // "")|\($ctx)" end) as $loc
    | [$gh, $loc] as $v
    | first(($v[] | select(startswith("red|"))), ($v[] | select(startswith("green|"))),
            ($v[] | select(. == "running")), "none")' 2>/dev/null || echo running
}

# batch_verdict <sha> <mode>: a chain commit's verdict from its Linux run(s)
# (vote mode: probe_votes) and, when the batch has one (BATCH_APPS), its macOS
# gate (judged by test against the base's: mac_vs_base), then a tab and the
# Linux run count. A job in BATCH_IGNORE counts as green. red|<url>|<job>[|<new
# tests>] when a job is red (Linux first), else none, more (a
# vote wants another run) or running when either is, else green|<urls>.
batch_verdict() {
  local l n=0 m="green|" v
  if [[ -n "$2" ]]; then v=$(probe_votes "$1"); l="${v%%$'\t'*}" n="${v##*$'\t'}"; else l=$(check_verdict "$1"); fi
  [[ "$l" != red* ]] || l="$l|Linux"
  [[ " $BATCH_IGNORE " != *" Linux "* ]] || l="green|"
  [[ -z "$BATCH_APPS" || " $BATCH_IGNORE " == *" macOS "* ]] || m=$(mac_verdict "$1")
  (( ! BASE_MAC_SET )) || [[ "$m" != red* ]] || m=$(mac_vs_base "$m")
  for v in "$l" "$m"; do [[ "$v" != red* ]] || { printf '%s\t%s\n' "$v" "$n"; return; }; done
  for v in none more running; do
    [[ "$l" != "$v" && "$m" != "$v" ]] || { printf '%s\t%s\n' "$v" "$n"; return; }
  done
  v="${l#green|}"; m="${m#green|}"
  printf 'green|%s\t%s\n' "$v${v:+${m:+, }}$m" "$n"
}

# red_jobs <sha>: the jobs red on <sha> (Linux, and macOS when the batch has
# a macOS gate, judged by test once BASE_MAC_SET; a log not read yet counts
# red), space-separated.
red_jobs() {
  local j="" m
  [[ "$(check_verdict "$1")" != red* ]] || j="Linux"
  if [[ -n "$BATCH_APPS" ]]; then
    m=$(mac_verdict "$1")
    (( ! BASE_MAC_SET )) || [[ "$m" != red* ]] || { m=$(mac_vs_base "$m"); [[ "$m" != running ]] || m=red; }
    [[ "$m" != red* ]] || j="${j:+$j }macOS"
  fi
  echo "$j"
}

# died_file <test name>: the Tests/ file whose `func <name>(` declares the test
# a TEST PROCESS DIED block names (scripts/test-died prints `name(args)`, or
# `-[Class name]` for XCTest), as <File>.swift, found in origin/BASE_BRANCH of
# the scratch clone (callers run it in a subshell, so they scratch first).
# Non-zero, with the reason logged, when the clone isn't there, no file has it
# or more than one does.
died_file() {
  local n="$1" f
  [[ "$n" != -\[* ]] || { n="${n##* }"; n="${n%]}"; }
  n="${n%%(*}"
  if [[ -z "$SCRATCH" ]] || ! git -C "$SCRATCH" rev-parse -q --verify "origin/$BASE_BRANCH" >/dev/null 2>&1; then
    log "died test $n: no scratch clone of $BASE_BRANCH to place it in"; return 1
  fi
  f=$(git -C "$SCRATCH" grep -lF -e "func $n(" "origin/$BASE_BRANCH" -- Tests 2>/dev/null | sed 's|^[^:]*:||; s|.*/||' | sort -u || true)
  case $(grep -c . <<<"$f") in
    1) echo "$f" ;;
    0) log "died test $n: no 'func $n(' under Tests/ on $BASE_BRANCH, so it isn't named"; return 1 ;;
    *) log "died test $n: 'func $n(' is in several files on $BASE_BRANCH ($(paste -sd, - <<<"$f")), so it isn't named"; return 1 ;;
  esac
}

# mac_log_ids <failed log>: the failing tests one log names, <File>.swift/<name>
# per line: the `recorded an issue` lines, then scripts/ci's TEST PROCESS DIED
# block (a test process that dies prints no issue lines), whose indented names
# up to the first blank line are the tests that started and never finished.
# They carry no file, so died_file places each one.
mac_log_ids() {
  local n f
  LC_ALL=C sed -nE 's/.* Test (.+) recorded an issue.* at ([^ :]+\.swift):[0-9].*/\2\/\1/p' <<<"$1"
  while IFS= read -r n; do
    f=$(died_file "$n") && echo "$f/$n"
  done < <(LC_ALL=C awk '{ s = $0; sub(/^[^\t]*\t[^\t]*\t[^ ]* ?/, "", s)
      if (s ~ /TEST PROCESS DIED/) { on = 1; next }
      if (on && s ~ /^[ \t]+[^ \t]/) { sub(/^[ \t]+/, "", s); sub(/[ \t\r]+$/, "", s); print s; next }
      on = 0 }' <<<"$1")
}

# mac_tests <red macOS verdict>: the tests its job's failed log says recorded
# an issue (swift-testing's `Test <name> recorded an issue ... at <File>.swift:`;
# a known issue doesn't count) or died unfinished (mac_log_ids), one
# <File>.swift/<name> per line, sorted. The file and name stay put when lines
# move; suite lines interleave under parallel tests, so they aren't used.
# Nothing for the local gate (its log isn't readable here). A sharded macOS
# gate job (`macOS`, #5775) only sums its shards, so when its log names no
# test the run's failed `macOS tests` jobs are read instead (each job's log,
# readable while the run goes on).
# Fails when the GitHub log, or any shard's, can't be read.
mac_tests() {
  local log ids jobs j
  [[ "$1" != *"|$LOCAL_MAC_CONTEXT" ]] || return 0
  log=$(failure_log "$1")
  [[ -n "$log" ]] || return 1
  ids=$(mac_log_ids "$log")
  if [[ -z "$ids" && "${1##*|}" =~ $MAC_GATE_RE && "$1" =~ /actions/runs/([0-9]+)/job/ ]]; then
    jobs=$(gh api "repos/$REPO/actions/runs/${BASH_REMATCH[1]}/jobs?per_page=100" \
      --jq '.jobs[] | select((.name | startswith("macOS tests")) and .conclusion != "success" and .conclusion != "skipped") | .id' 2>/dev/null) || return 1
    for j in $jobs; do
      log=$(failure_log "red|/job/$j"); [[ -n "$log" ]] || return 1
      ids+=$'\n'$(mac_log_ids "$log")
    done
  fi
  grep . <<<"$ids" | LC_ALL=C sort -u || true
}

# mac_vs_base <red macOS verdict>: that red judged against BASE_MAC_FAILS:
# green|<url> when every failing test also fails on the base, red|<url>|<job>
# with |<the new ones> when it adds any, red|<url>|<job> when it names none (a
# build error or a crash is never the base's), running when the log can't be
# read yet (never a pass).
mac_vs_base() {
  local rest="${1#red|}" ids new
  ids=$(mac_tests "$1") || { echo running; return; }
  new=$(LC_ALL=C comm -23 <(printf '%s\n' "$ids") <(printf '%s\n' "$BASE_MAC_FAILS") | grep . | paste -sd, - | sed 's/,/, /g' || true)
  if [[ -n "$ids" && -z "$new" ]]; then echo "green|${rest%%|*} (fails only tests that fail on $BASE_BRANCH too)"
  else echo "red|$rest${new:+|$new}"; fi
}

# settled <sha>: true when every job the batch runs (Linux, and its macOS gate
# when it has one) has finished on <sha>, green or red.
settled() {
  [[ "$(check_verdict "$1")" =~ ^(green|red) ]] || return 1
  [[ -z "$BATCH_APPS" ]] || [[ "$(mac_verdict "$1")" =~ ^(green|red) ]]
}

# batch_dispatch <ref> <sha> <key> [<mode>]: starts what the chain commit
# <sha> lacks on <ref>: its Linux run (in vote mode, another one while the
# vote is open) and, when the batch has one, its macOS gate. Jobs in
# BATCH_IGNORE are not run.
batch_dispatch() {
  local v
  if [[ " $BATCH_IGNORE " != *" Linux "* ]]; then
    if [[ -n "${4:-}" ]]; then v=$(probe_votes "$2"); v="${v%%$'\t'*}"; else v=$(check_verdict "$2"); fi
    case "$v" in none|more) dispatch_linux "$1" "$3" ;; esac
  fi
  if [[ -n "$BATCH_APPS" && " $BATCH_IGNORE " != *" macOS "* && "$(mac_verdict "$2")" == none ]]; then
    dispatch_mac "$1" "$1#mac"
  fi
}

# batch_apps <base sha> <tip sha>: the batch's macOS gate scope: mac_scope
# over the paths it changes, `all` for anything shared or when the diff can't
# be read, nothing when no changed path needs macOS or LANE_MAC_PER_PR=1 or
# LANE_VERIFY_AFTER=1 (macOS is then proven per PR).
batch_apps() {
  local f
  (( ! LANE_MAC_PER_PR && ! LANE_VERIFY_AFTER )) || return 0
  f=$(mktemp)
  git -C "$SCRATCH" diff --no-renames --name-only "$1" "$2" >"$f" 2>/dev/null || echo Package.swift >"$f"
  mac_scope "$f"
  rm -f "$f"
}

# mac_slots_busy: the lane's own queued and running macOS runs on ci.yml
# (macOS gates, and per-PR builds); LANE_MAC_SLOTS when they can't be listed,
# so a blind sweep forms no batch that needs macOS.
mac_slots_busy() {
  local n
  n=$(gh run list -R "$REPO" --workflow "$CI_FILE" --limit 100 --json status,displayTitle \
    --jq "[.[] | select(.status != \"completed\" and ((.displayTitle | startswith(\"$MAC_GATE_TITLE\")) or .displayTitle == \"$BUILD_TITLE\"))] | length" 2>/dev/null) || n=""
  [[ "$n" =~ ^[0-9]+$ ]] || n="$LANE_MAC_SLOTS"
  echo "$n"
}

# red_holds <needs macOS 0|1>: the open dev-red issue names a job a batch
# would run, so no probe on that base can pass: Linux always, macOS when the
# batch runs the macOS gate. The issue never names the failing app, so any
# macOS gate counts.
red_holds() {
  [[ -n "$BASE_RED" ]] || return 1
  [[ "$BASE_RED_JOBS" == *linux* ]] || { [[ "$BASE_RED_JOBS" == *macos* ]] && (( $1 )); }
}

# settle_ready: what the pass found eligible (READY:
# rank|n|head|branch|apps|since|proof), ordered p0, beta, the rest, then
# oldest. While a batch holds the lane (HOLD) they all wait; a PR in a batch
# still waiting (INFLIGHT) is left to it. A lone PR that needs no
# macOS goes to batch_start, which lands it on its own proof unless that is
# stale (proof_stale); anything else becomes a batch, at once when none of
# it needs macOS, otherwise when a macOS slot is free and one of: a batch
# resolved in this run, LANE_BATCH_MAX are ready, or the oldest has been
# ready LANE_BATCH_WAIT_MIN minutes.
settle_ready() {
  local items=() it apps need=0 busy oldest now
  while IFS= read -r it; do  # a PR in a batch still waiting (INFLIGHT) is that batch's
    [[ -z "$it" || "$INFLIGHT" == *" $(cut -d'|' -f2 <<<"$it") "* ]] || items+=("$it")
  done < <(printf '%s\n' ${READY[@]+"${READY[@]}"} | sort -t'|' -k1,1n -k2,2n)
  READY=()
  (( ${#items[@]} )) || return 0
  if (( HOLD )); then log "a batch is in flight: ${#items[@]} ready PR(s) wait for the next sweep"; return 0; fi
  # Verify after merge: each code PR lands alone on its own proof (Linux and
  # the pre-screen), red dev or not, through batch_start of one: a stale proof
  # (proof_stale) makes it a Linux batch of one on today's dev, which holds
  # only that PR (batch_held). PRs without code batch as before.
  if (( LANE_VERIFY_AFTER )); then
    local rest=()
    for it in "${items[@]}"; do
      IFS='|' read -r _ _ _ _ apps _ <<<"$it"
      if [[ -z "$apps" ]]; then rest+=("$it"); else batch_start "$it"; fi
    done
    (( ${#rest[@]} && ! HOLD )) || return 0
    items=("${rest[@]}")
  fi
  if (( ! LANE_MAC_PER_PR )); then
    for it in "${items[@]}"; do IFS='|' read -r _ _ _ _ apps _ <<<"$it"; [[ -z "$apps" ]] || need=1; done
  fi
  if red_holds "$need"; then
    if [[ -z "$BASE_RED_SCOPE" ]]; then log "$BASE_BRANCH is red on a job this batch runs (dev-red #$BASE_RED: ${BASE_RED_JOBS#*: }): no batch forms; ${#items[@]} ready PR(s) wait"; return 0; fi
    # A red the lane could place (red_scope) holds only the PRs touching its
    # module (READY's last field, set by evaluate); the rest batch as usual.
    local keep=() hit held=0
    for it in "${items[@]}"; do
      IFS='|' read -r _ _ _ _ _ _ _ hit <<<"$it"
      if [[ "$hit" == 1 ]]; then held=$((held + 1)); else keep+=("$it"); fi
    done
    log "$BASE_BRANCH is red in $BASE_RED_SCOPE (dev-red #$BASE_RED: ${BASE_RED_JOBS#*: }): $held ready PR(s) touching it wait; ${#keep[@]} batch"
    (( ${#keep[@]} )) || return 0
    items=("${keep[@]}"); need=0
    if (( ! LANE_MAC_PER_PR )); then
      for it in "${items[@]}"; do IFS='|' read -r _ _ _ _ apps _ <<<"$it"; [[ -z "$apps" ]] || need=1; done
    fi
  fi
  if (( need )); then
    busy=$(mac_slots_busy)
    if (( busy >= LANE_MAC_SLOTS )); then
      log "batch: the lane's macOS runs fill its slots ($busy of $LANE_MAC_SLOTS queued or running); ${#items[@]} ready PR(s) wait"; return 0
    fi
    oldest=$(printf '%s\n' "${items[@]}" | cut -d'|' -f6 | sort -n | head -1); now=$(date -u +%s)
    if (( ! SLOT_FREED && ${#items[@]} < LANE_BATCH_MAX && now - oldest < LANE_BATCH_WAIT_MIN * 60 )); then
      log "batch: ${#items[@]} ready PR(s); it forms at $LANE_BATCH_MAX, when a slot frees, or once the oldest is $LANE_BATCH_WAIT_MIN min old ($(( (now - oldest) / 60 )) min now)"
      return 0
    fi
  fi
  batch_start "${items[@]}"
}

# batch_start <rank|n|head|branch|apps|since|proof|hit>...: BASE_BRANCH plus the
# ready PRs in order on a scratch branch, pushed as lane/batch-<id>, then
# batch_resume on it (which starts its checks). A PR whose branch can't be
# fetched or moved past its head, or that conflicts with an earlier PR in the
# batch, waits for the next sweep. If only one PR joins and it needs no macOS
# gate, it lands on its own proof, unless that is stale (proof_stale against
# its merge base): then it is a batch of one, checked on today's dev.
batch_start() {
  local items=("$@") it n head branch apps proof merged=() d id br stale
  if (( DRY_RUN )); then
    log "dry-run, would batch ${#items[@]} PRs: $(for it in "${items[@]}"; do IFS='|' read -r _ n _ <<<"$it"; printf '#%s ' "$n"; done)"; return 0
  fi
  if ! scratch "$BASE_BRANCH"; then log "batch: could not fetch $BASE_BRANCH from $REMOTE; the ready PRs wait for the next sweep"; return 0; fi
  d="$SCRATCH"
  if ! git -C "$d" checkout -q -B batch "origin/$BASE_BRANCH" 2>/dev/null || ! bash "$HERE/install-merge-drivers" "$d" >/dev/null 2>&1; then
    log "batch: could not check out $BASE_BRANCH with the merge drivers; the ready PRs wait"; return 0
  fi
  for it in "${items[@]}"; do
    (( ${#merged[@]} < MAX_BATCH )) || { log "batch: full at $MAX_BATCH PRs; the rest wait"; break; }
    IFS='|' read -r _ n head branch _ <<<"$it"
    if ! scratch "$branch"; then log "batch: #$n: could not fetch $branch; it waits"; continue; fi
    if [[ "$(git -C "$d" rev-parse "origin/$branch" 2>/dev/null)" != "$head" ]]; then log "batch: #$n: $branch moved past $head; it waits"; continue; fi
    if git -C "$d" -c user.name="github-actions[bot]" -c user.email="41898282+github-actions[bot]@users.noreply.github.com" \
        merge -q --no-ff --no-edit -m "fast lane batch: PR #$n at $head" "$head" >/dev/null 2>&1; then
      merged+=("$it")
    else
      git -C "$d" merge --abort >/dev/null 2>&1 || true
      log "batch: #$n conflicts with an earlier PR in the batch; it waits for the next one"
    fi
  done
  (( ${#merged[@]} )) || { log "batch: no PR could join; no batch"; return 0; }
  IFS='|' read -r _ n head _ apps _ proof _ <<<"${merged[0]}"
  if (( ${#merged[@]} == 1 )) && { (( LANE_MAC_PER_PR || LANE_VERIFY_AFTER )) || [[ -z "$apps" ]]; }; then
    stale=$(proof_stale "$(git -C "$d" merge-base "$head" "origin/$BASE_BRANCH" 2>/dev/null || true)" "$head")
    if [[ -z "$stale" ]]; then
      log "batch: only #$n could join and it needs no macOS gate; no batch"
      land "$n" "$head" "$proof" || true
      return 0
    fi
    log "batch: #$n's own proof is stale ($stale); checking it on $BASE_BRANCH as a batch of one"
    # Batches of one run side by side (batch_held); a dev ratchet change makes
    # every proof stale at once, so at most LANE_BATCH_MAX run.
    if (( $(wc -w <<<"$INFLIGHT") >= LANE_BATCH_MAX )); then
      log "batch: $LANE_BATCH_MAX batches of one are in flight; #$n waits for the next sweep"; return 0
    fi
  fi
  # Batches of one can form several per second (LANE_VERIFY_AFTER=1): ids stay unique.
  id=$(date -u +%Y%m%d%H%M%S); (( id > LAST_BATCH_ID )) || id=$(( LAST_BATCH_ID + 1 )); LAST_BATCH_ID=$id; br="${BATCH_PREFIX}$id"
  if ! git -C "$d" push -q origin "HEAD:refs/heads/$br" 2>/dev/null; then log "batch: could not push $br; the ready PRs wait"; return 0; fi
  log "batch $br: ${#merged[@]} PRs ($(for it in "${merged[@]}"; do IFS='|' read -r _ n _ <<<"$it"; printf '#%s ' "$n"; done))"
  batch_resume "$br"
  batch_held || true
}

# batch_held: after batch_resume, true when the batch still waits: its PRs
# join INFLIGHT, and HOLD stops every other merge, except for a BATCH_SOLO one
# (a stale proof's recheck, which needs no other PR to wait). Whatever lands
# beside it moves BASE_BRANCH, so its green result is judged again by
# batch_land's proof_stale and rechecked on today's dev, not landed, when that
# says the base went stale.
LAST_BATCH_ID=0
batch_held() {
  [[ "$BATCH_STATE" == waiting ]] || return 1
  INFLIGHT+="$BATCH_PRS"
  (( BATCH_SOLO )) || HOLD=1
}

# batch_resume <branch>: reads the batch chain (BASE_BRANCH, then one merge
# commit per PR), its macOS scope (batch_apps over the chain) and the verdicts
# on its tip and probes (batch_verdict), acts, and sets BATCH_STATE to done
# (the branch is gone) or waiting (a run is still going; nothing else merges
# meanwhile). Red tip: a prefix bisect with lo = the longest green prefix,
# hi = the shortest red one; the probe is their midpoint; hi = lo + 1 names
# the culprit. Probe 0 is the base alone and is only asked for when PR 1 is
# the suspect: a base red on every job the tip is red on means BASE_BRANCH is
# red, and the batch lands on the PRs' own proof so a fix can get through; a
# base red on fewer jobs has those set aside (BATCH_IGNORE) and the bisect
# goes on with the rest. A tip failing macOS where the base does too is judged
# by failing test instead (BASE_MAC_SET, mac_vs_base).
BATCH_STATE=""
BATCH_SIZE=0  # its PR count, 0 until read
BATCH_PRS=""  # its PR numbers, " <n> " each
# A batch of one with LANE_VERIFY_AFTER=1 whose PR changes no RATCHET_RE path:
# it holds no other PR and never sleeps for its verdict (the next sweep reads
# it). A ratchet-changing PR would go stale under every landing beside it, so
# its batch holds the lane as before.
BATCH_SOLO=0
batch_resume() {
  local br="$1" d k i sha v lo hi mid waited=0 line probes mode="" moded=0 bj tj on
  local chain=() verd=() nruns=()
  DISPATCHED=""; BATCH_STATE=waiting; BATCH_SIZE=0; BATCH_PRS=""; BATCH_SOLO=0; BATCH_IGNORE=""; BATCH_APPS=""; BASE_MAC_SET=0; BASE_MAC_FAILS=""
  if ! scratch "$BASE_BRANCH" "$br"; then log "batch $br: could not fetch it; the next sweep tries again"; return; fi
  d="$SCRATCH"
  while read -r sha line; do
    [[ "$line" =~ $BATCH_SUBJECT_RE ]] || continue
    chain+=("$sha|${BASH_REMATCH[1]}|${BASH_REMATCH[2]}")
  done < <(git -C "$d" log --first-parent --reverse --format='%H %s' "origin/$BASE_BRANCH..origin/$br" 2>/dev/null)
  k=${#chain[@]}; BATCH_SIZE=$k
  for line in ${chain[@]+"${chain[@]}"}; do IFS='|' read -r _ i _ <<<"$line"; BATCH_PRS+=" $i "; done
  if (( k == 0 )); then log "batch $br: nothing left to land; dropping it"; batch_drop "$br"; BATCH_STATE=done; return; fi
  chain=("$(git -C "$d" rev-parse "origin/$br~$k")||" "${chain[@]}")  # [0] = the base
  BATCH_APPS=$(batch_apps "${chain[0]%%|*}" "${chain[k]%%|*}")
  if (( LANE_VERIFY_AFTER && k == 1 )) && line=$(git -C "$d" diff --name-only --no-renames "${chain[0]%%|*}" "${chain[k]%%|*}" 2>/dev/null) \
      && ! grep -qiE -- "$RATCHET_RE" <<<"$line"; then BATCH_SOLO=1; fi
  # A base holding dev's red commit gets a <batch>-red marker while dev is red;
  # once dev is green on a newer commit, a marked batch can't pass and is
  # dropped (its PRs untouched) so this sweep forms a fresh one.
  if (( ! DRY_RUN )); then
    if red_holds "$([[ -n "$BATCH_APPS" ]] && echo 1 || echo 0)" && [[ -n "$BASE_RED_SHA" ]] && git -C "$d" merge-base --is-ancestor "$BASE_RED_SHA" "${chain[0]%%|*}" 2>/dev/null; then
      batch_branches | grep -qE " ${br//./\\.}-red\$" \
        || git -C "$d" push -q origin "${chain[0]%%|*}:refs/heads/$br-red" 2>/dev/null \
        || log "batch $br: could not mark its red base"
    elif [[ -z "$BASE_RED" && "${chain[0]%%|*}" != "$(git -C "$d" rev-parse "origin/$BASE_BRANCH")" ]] \
        && batch_branches | grep -qE " ${br//./\\.}-red\$"; then
      log "batch $br: formed on a red $BASE_BRANCH that is green again; dropping it, its PRs batch again"
      batch_drop "$br"; BATCH_STATE=done; return
    fi
  fi
  on="Linux${BATCH_APPS:+ and macOS}"
  log "batch $br: $k PR(s), checked on Linux${BATCH_APPS:+ and macOS ($BATCH_APPS)}"
  while :; do
    for (( i = 0; i <= k; i++ )); do verd[i]=""; nruns[i]=0; done
    v=$(batch_verdict "${chain[k]%%|*}" ""); verd[k]="${v%%$'\t'*}"
    # Vote mode is read once per call, from a red tip's failed Linux log.
    if (( ! moded )) && [[ "${verd[k]}" == red*"|Linux" ]]; then
      moded=1; mode=$(vote_mode "${verd[k]}")
      [[ -z "$mode" ]] || log "batch $br: the tip fails only a budget test (${mode#* }); each probe votes 2 of 3"
    fi
    probes=$(batch_branches | grep -E " ${br//./\\.}-[0-9]+\$" || true)
    while read -r sha line; do
      [[ -n "$line" ]] || continue
      i="${line##*-}"
      (( i >= 0 && i < k )) && [[ "${chain[i]%%|*}" == "$sha" ]] || continue
      v=$(batch_verdict "$sha" "$mode"); verd[i]="${v%%$'\t'*}" nruns[i]="${v##*$'\t'}"
    done <<<"$probes"
    v="${verd[k]}"
    if (( DRY_RUN )); then log "dry-run: batch $br ($k PRs) tip is $v; probes: $(printf '%s ' "${verd[@]}")"; return; fi
    case "$v" in
      none) log "batch $br: its tip lacks a check; starting it"; batch_dispatch "$br" "${chain[k]%%|*}" "$br" ;;
      running) log "batch $br: checks running" ;;
      green*)
        batch_land "$br" "$k" "batch of $k PRs checked together on $on${BATCH_IGNORE:+ ($BATCH_IGNORE red on $BASE_BRANCH alone, set aside)}: ${v#green|}" "${chain[@]}"
        BATCH_STATE=done; return ;;
      red*)
        lo=-1; hi=$k
        case "${verd[0]}" in
          red*)
            # A base and a tip both failing macOS: read the base's failing tests
            # once, judge every macOS gate on the chain against them
            # (mac_vs_base) and look again. A tip passing macOS sets it aside below.
            v=$(mac_verdict "${chain[0]%%|*}")
            if [[ -n "$BATCH_APPS" ]] && (( ! BASE_MAC_SET )) && [[ "$v" == red* && "$(mac_verdict "${chain[k]%%|*}")" != green* ]]; then
              if ! BASE_MAC_FAILS=$(mac_tests "$v"); then log "batch $br: could not read the failing macOS tests on $BASE_BRANCH yet; waiting"; return; fi
              BASE_MAC_SET=1
              log "batch $br: $BASE_BRANCH is red on macOS on its own (${BASE_MAC_FAILS:-no test it could name}); judging macOS by failing test"
              continue
            fi
            # Judged by test, macOS is never set aside or counted for own proof.
            bj=$(red_jobs "${chain[0]%%|*}"); (( ! BASE_MAC_SET )) || bj="${bj%macOS}"; bj="${bj% }"
            tj=$(red_jobs "${chain[k]%%|*}"); line="${verd[0]#red|}"; line="${line%%|*}"
            # Own proof only once every job on the tip has finished: a macOS gate
            # still running must not land code unproven. Until then the base's
            # red jobs are set aside below, so the tip waits on the rest.
            if settled "${chain[k]%%|*}" && [[ -n "$tj" && -z "$(comm -23 <(tr ' ' '\n' <<<"$tj" | sort) <(tr ' ' '\n' <<<"$bj" | sort) | grep . || true)" ]]; then
              log "batch $br: $BASE_BRANCH itself is red ($bj: $line); landing on the PRs' own proof"
              batch_land "$br" "$k" "$BASE_BRANCH was red on its own ($line), so this batch landed on each PR's own proof" "${chain[@]}"
              BATCH_STATE=done; return
            fi
            if [[ "$bj" != "$BATCH_IGNORE" ]]; then
              log "batch $br: $BASE_BRANCH is red on $bj on its own, the tip on $tj; setting $bj aside"
              BATCH_IGNORE="$bj"; continue
            fi ;;
          green*) lo=0 ;;
        esac
        for (( i = 1; i < k; i++ )); do
          case "${verd[i]}" in green*) lo=$i ;; red*) (( i < hi )) && hi=$i ;; esac
        done
        if (( lo >= 0 && hi == lo + 1 )); then
          batch_culprit "$br" "$lo" "$hi" "${verd[hi]#red|}" "$mode" "${chain[@]}"
          BATCH_STATE=done; return
        elif (( lo == -1 && hi == 1 )); then
          batch_probe "$br" 0 "${chain[0]%%|*}" "${verd[0]}" "${nruns[0]}" "$mode"
        else
          mid=$(( ( (lo < 0 ? 0 : lo) + hi ) / 2 ))
          batch_probe "$br" "$mid" "${chain[mid]%%|*}" "${verd[mid]}" "${nruns[mid]}" "$mode"
        fi ;;
    esac
    if (( waited >= BATCH_WAIT || BATCH_SOLO )); then return; fi
    sleep "$BATCH_POLL"; waited=$(( waited + BATCH_POLL ))
  done
}

# batch_probe <branch> <i> <sha> <verdict> [<runs> [<mode>]]: makes sure the
# chain after i PRs has its checks: pushes lane/batch-<id>-<i> at <sha> and
# starts them when there is none, or starts what is missing (a vote's next
# Linux run, verdict `more`); says so when they are running. The Linux
# dispatch key carries the run count, so a vote's next run can start in the
# same call once the last one is in.
batch_probe() {
  local br="$1" i="$2" sha="$3" v="$4" key="$1-$2#${5:-0}"
  case "$v" in
    running) log "batch $br: probe $i running" ;;
    "")
      if (( $(batch_branches | grep -cE " ${br//./\\.}-[0-9]+\$" || true) >= MAX_BATCH )); then
        log "batch $br: too many probes; dropping the batch, its PRs wait"; batch_drop "$br"; return
      fi
      if git -C "$SCRATCH" push -q origin "$sha:refs/heads/$br-$i" 2>/dev/null; then
        log "batch $br: probing the chain after $i PR(s)"; batch_dispatch "$br-$i" "$sha" "$key" "${6:-}"
      else log "batch $br: could not push probe $i; the next sweep tries again"; fi ;;
    *) log "batch $br: probe $i needs a run (${5:-0} Linux so far)"; batch_dispatch "$br-$i" "$sha" "$key" "${6:-}" ;;
  esac
}

# batch_land <branch> <upto> <proof> <chain...>: lands PRs 1..upto in order,
# stopping at the first that won't (its head moved: the rest were proven on
# top of it and wait), then drops the branch. A check gone stale since the
# batch formed (proof_stale on a fresh BASE_BRANCH) lands nothing: the branch
# is dropped and its PRs batch again on today's dev.
batch_land() {
  local br="$1" upto="$2" proof="$3"; shift 3
  local chain=("$@") i n head stale="could not fetch $BASE_BRANCH"
  scratch "$BASE_BRANCH" && stale=$(proof_stale "${chain[0]%%|*}" "${chain[upto]%%|*}")
  if [[ -n "$stale" ]]; then
    log "batch $br: its check is stale ($stale); dropping it, its PRs batch again on $BASE_BRANCH"
    batch_drop "$br"; return
  fi
  for (( i = 1; i <= upto; i++ )); do
    IFS='|' read -r _ n head <<<"${chain[i]}"
    if ! land "$n" "$head" "$proof"; then log "batch $br: #$n did not land; the PRs after it wait for the next batch"; break; fi
  done
  batch_drop "$br"
}

# batch_culprit <branch> <lo> <hi> <run url>|<job> <mode> <chain...>: PRs
# 1..lo land, PR hi gets NEEDS_FIX_LABEL and one comment naming the failing
# job and run (with vote_note's sentences for a vote_mode <mode>) and the open
# PRs based on its branch, the rest wait for the next batch. The comment's
# first words are what evaluate looks for to hold the label at that head.
batch_culprit() {
  local br="$1" lo="$2" hi="$3" url="${4%%|*}" job="Linux" mode="$5" new=""
  [[ "$4" != *"|"* ]] || job="${4#*|}"
  [[ "$job" != *"|"* ]] || { new="${job#*|}"; job="${job%%|*}"; }
  shift 5
  local chain=("$@") n head after="" i pn hbr deps=""
  IFS='|' read -r _ n head <<<"${chain[hi]}"
  for (( i = 1; i <= lo; i++ )); do IFS='|' read -r _ pn _ <<<"${chain[i]}"; after+="${after:+, }#$pn"; done
  # Stacked dependents (a lead's next slice is based on this branch) wait with it.
  hbr=$(gh pr view "$n" -R "$REPO" --json headRefName --jq .headRefName 2>/dev/null || true)
  [[ -z "$hbr" ]] || deps=$(gh pr list -R "$REPO" --state open --limit 1000 --json number,baseRefName 2>/dev/null \
    | jq -r --arg b "$hbr" '[.[] | select(.baseRefName == $b) | "#\(.number)"] | join(", ")' 2>/dev/null || true)
  log "batch $br: PR #$n at $head is the culprit ($job: $url${mode:+, $mode}${deps:+; stacked on it: $deps})"
  write gh label create "$NEEDS_FIX_LABEL" -R "$REPO" --color d93f0b --force \
    --description "The lane's batch check fails with this PR on dev; push a fix" >/dev/null 2>&1 || true
  write gh pr edit "$n" -R "$REPO" --add-label "$NEEDS_FIX_LABEL" || log "could not add $NEEDS_FIX_LABEL"
  comment_once "$n" "Fast lane: head $head fails the $job check once it lands on $BASE_BRANCH${after:+ after $after}: $url.${new:+ Tests failing with it that pass on $BASE_BRANCH: $new.}$(vote_note "$mode") ${after:+Those PRs merged; }This one has the $NEEDS_FIX_LABEL label and waits.${deps:+ Stacked on its branch: $deps, which wait for the fix; restack them on it.} Fix it, rerun scripts/ci --changed, push, and move the Head: line; the lane drops the label on the new head and checks it again."
  batch_land "$br" "$lo" "batch of $lo PRs checked together on Linux${BATCH_APPS:+ and macOS} before #$n broke the chain" "${chain[@]}"
}

# batch_drop <branch>: deletes the batch branch and its probes at REMOTE.
batch_drop() {
  local br="$1" names
  names=$(batch_branches | awk -v b="$br" '$2 == b || index($2, b "-") == 1 { print $2 }' | paste -sd' ' -)
  [[ -z "$names" ]] || git -C "$SCRATCH" push -q origin --delete $names 2>/dev/null || log "batch $br: could not delete $names"
}

# probe_votes <sha>: the Linux runs on <sha> as one vote-mode verdict and the
# number of runs, tab-separated: none, running, more (no 2 of 3 yet),
# green|<url> or red|<url> (2 green or 2 red runs; cancelled runs don't vote).
probe_votes() {
  local runs
  runs=$(gh api "repos/$REPO/commits/$1/check-runs?per_page=100" --jq '.check_runs' 2>/dev/null) || { printf 'none\t0\n'; return; }
  jq -r --arg name "${CI_CHECKS[0]}" '
    def lc: (. // "") | ascii_downcase;
    def url: sort_by(.started_at // "") | last | (.details_url // .html_url // "");
    [ .[] | select(.name == $name and .conclusion != "action_required") ] as $all
    | [ $all[] | select((.status | lc) == "completed" and (.conclusion | lc) == "success") ] as $g
    | [ $all[] | select((.status | lc) == "completed" and ((.conclusion | lc) == "failure" or (.conclusion | lc) == "timed_out")) ] as $r
    | if ($all | length) == 0 then "none"
      elif ($r | length) >= 2 then "red|\($r | url)"
      elif ($g | length) >= 2 then "green|\($g | url)"
      elif any($all[]; (.status | lc) != "completed") then "running"
      else "more" end
    | "\(.)\t\($all | length)"' <<<"$runs" 2>/dev/null || printf 'none\t0\n'
}

# budget_failure: reads a Linux job's failed-step log on stdin. When every
# issue a test recorded (swift-testing's "recorded an issue" lines; a known
# issue doesn't count) is a numeric comparison in a budget test (the line
# names a budget, median or p95), like
#   ... recorded an issue at LibraryLoupeBudgetTests.swift:59:5: Expectation failed: (cost.median → 1.046542) <= (1 * scale → 1.0)
# prints "<measured> <op> <budget>" for the first; else nothing.
budget_failure() {
  local line got first="" n=0
  while IFS= read -r line; do
    [[ "$line" == *"recorded an issue"* ]] || continue
    n=$((n + 1))
    grep -qiE 'budget|median|p9[05]' <<<"$line" || return 0
    got=$(sed -nE 's/.*Expectation failed: \(.* → (-?[0-9.]+)\) (<=|<|>=|>) (\(.* → )?(-?[0-9.]+)\)?[[:space:]]*$/\1 \2 \4/p' <<<"$line")
    [[ -n "$got" ]] || return 0
    [[ -n "$first" ]] || first="$got"
  done
  (( n )) && echo "$first"
  return 0
}

# budget_near <measured> <op> <budget>: true when the value is past its
# budget by at most BUDGET_NEAR of it (a ceiling for < and <=, a floor for > and >=).
budget_near() {
  awk -v m="$1" -v op="$2" -v b="$3" -v f="$BUDGET_NEAR" 'BEGIN {
    if (op ~ /^</) exit !(m + 0 > b + 0 && m + 0 <= (b + 0) * (1 + f))
    exit !(m + 0 < b + 0 && m + 0 >= (b + 0) * (1 - f)) }'
}

# vote_mode <red verdict>: how a bisect reads its probes, from that red run's
# failed log: nothing (a plain red: one run each), "budget <m> <op> <b>" (only
# budget failures: 2 of 3 runs) or "likely <m> <op> <b>" (the same, with the
# value within BUDGET_NEAR of its budget).
vote_mode() {
  local b
  b=$(failure_log "$1" | budget_failure)
  [[ -n "$b" ]] || return 0
  # shellcheck disable=SC2086 # three words: measured, op, budget
  if budget_near $b; then echo "likely $b"; else echo "budget $b"; fi
}

# vote_note <mode>: what a verdict found in vote mode says about it, with a
# leading space; nothing for a plain red.
vote_note() {
  local m b
  [[ -n "$1" ]] || return 0
  read -r _ m _ b <<<"$1"
  printf ' The failing test is a timing budget test (measured %s against %s), so each probe ran up to 3 times and was called on 2 of 3.' "$m" "$b"
  [[ "$1" != likely* ]] || printf ' The value measured %s against %s, within %s%% of it, so the test sits on its line: treat this as likely, not certain.' \
    "$m" "$b" "$(awk -v f="$BUDGET_NEAR" 'BEGIN { print f * 100 }')"
}

# failure_log <verdict>: the failed steps' log of the job a red|<job url>
# verdict names; nothing when it has no job id or the log can't be read.
failure_log() {
  [[ "$1" =~ /job/([0-9]+) ]] || return 0
  gh run view --job "${BASH_REMATCH[1]}" --log-failed -R "$REPO" 2>/dev/null || true
}

# red_sweep: reads the open dev-red issue. A red the flake check hasn't judged
# (flake_check) is not red yet: nothing is held, bisected or reverted. A real
# red sets BASE_RED and its scope (red_scope), and a red Linux job gets its
# culprit range bisected. Probes an earlier sweep left pin the red they
# bisect, since ci.yml rewrites the issue body for every newer red run.
red_sweep() {
  local issue body bad pin jobs run
  { read -r issue || true; body=$(cat); } < <(gh api "repos/$REPO/issues?labels=$RED_LABEL&state=open&per_page=5" \
      --jq 'first(.[] | select(.pull_request == null)) | .number, (.body // "")' 2>/dev/null || true)
  [[ -n "${issue:-}" ]] || { flake_closed; return 0; }
  bad=$(grep -oE '^- Culprit range: `main\.\.[0-9a-f]{40}`' <<<"$body" | grep -oE '[0-9a-f]{40}' | head -1 || true)
  jobs=$(grep -iE '^- Failing jobs:' <<<"$body" | head -1 | tr '[:upper:]' '[:lower:]' || true)
  run=$(grep -oE '^- Run: [^ ]+' <<<"$body" | head -1 | cut -c8- || true)
  flake_check "$issue" "$run" "$bad" "${jobs#*: }" || return 0
  BASE_RED="$issue"; BASE_RED_SHA="$bad"; BASE_RED_JOBS="$jobs"; BASE_RED_RUN="$run"
  # scratch runs here, in the sweep's shell: red_scope runs in a subshell, which must not be the one that creates SCRATCH.
  BASE_RED_SCOPE=""; [[ -z "$bad" ]] || ! scratch "$BASE_BRANCH" || BASE_RED_SCOPE=$(red_scope "$bad")
  [[ -z "$BASE_RED_SCOPE" ]] || log "dev-red #$issue: red in $BASE_RED_SCOPE; only ready PRs touching it wait"
  grep -qiE '^- Failing jobs:.*linux' <<<"$body" || { log "dev-red #$issue: not a Linux red; nothing to bisect"; return 0; }
  pin=$(git ls-remote --heads "$REMOTE" "refs/heads/${BISECT_PREFIX}*" 2>/dev/null | sed -E 's:.*refs/heads/'"$BISECT_PREFIX"'([0-9a-f]+)-[0-9]+$:\1:' | sort -u | head -1 || true)
  [[ -z "$pin" ]] || bad="$pin"
  [[ -n "$bad" ]] || { log "dev-red #$issue: no culprit range in the body"; return 0; }
  red_bisect "$issue" main "$bad" "$BASE_BRANCH"
}

# rerun_state <run id>: the run's state as one word: running, success, red
# (any other finished conclusion) or unknown (the API could not be read).
rerun_state() {
  local json st
  json=$(gh run view "$1" -R "$REPO" --json status,conclusion 2>/dev/null) || { echo unknown; return; }
  st=$(jq -r '((.status // "") | ascii_downcase) + " " + ((.conclusion // "") | ascii_downcase)' <<<"$json" 2>/dev/null || echo unknown)
  case "$st" in "completed success") echo success ;; completed*) echo "red|${st#completed }" ;; unknown) echo unknown ;; *) echo running ;; esac
}

# flake_check <issue> <run url> <red sha> <jobs>: true when dev is red for
# real, false when the lane must not treat it as red this sweep. A red sha not
# yet checked gets the run's failed jobs rerun once (gh run rerun --failed) and
# a RERUN_MARK <sha7> started comment naming the run and the failing tests
# (red_tests, read now: the rerun overwrites the logs). A running rerun waits;
# a passing one is a flake (flake_finding, mark flake); a failing one is real
# (mark red). An issue with no run, or comments the lane can't read, is red as
# before: that never reruns, so a sha is rerun at most once. A judged sha is
# never rerun or read again.
flake_check() {
  local issue="$1" url="$2" sha7="${3:0:7}" jobs="$4" id comments tests st
  id=$(mac_run_id "$url"); [[ -n "$id" && -n "$3" ]] || return 0
  comments=$(gh api "repos/$REPO/issues/$issue/comments" --paginate --jq '.[].body' 2>/dev/null) || return 0
  if ! grep -qF -- "$RERUN_MARK $sha7 " <<<"$comments"; then
    tests=$(red_tests "$3")
    if ! write gh run rerun "$id" -R "$REPO" --failed; then log "flake check: could not rerun the failed jobs of run $id; $BASE_BRANCH counts as red"; return 0; fi
    log "flake check: rerunning the failed jobs ($jobs) of run $id once at $sha7${tests:+ (failing $tests)}; $BASE_BRANCH is not held meanwhile"
    write gh issue comment "$issue" -R "$REPO" --body "Flake check: re-running the failed jobs ($jobs) of $url once at $sha7${tests:+; failing $tests}. A pass makes this red a flake (the lane files a finding for the test and holds nothing); a second failure makes it real. $RERUN_MARK $sha7 started -->" \
      || log "could not comment on #$issue"
    return 1
  fi
  if grep -qF -- "$RERUN_MARK $sha7 red -->" <<<"$comments"; then return 0; fi
  if grep -qF -- "$RERUN_MARK $sha7 flake -->" <<<"$comments"; then log "flake check: $sha7 was a flake; waiting for CI on $BASE_BRANCH to close dev-red #$issue"; return 1; fi
  st=$(rerun_state "$id")
  case "$st" in
    success) flake_finding "$issue" "$sha7" "$url" "$comments"; return 1 ;;
    red*)
      log "flake check: the rerun of run $id failed too (${st#red|}); $BASE_BRANCH is red"
      write gh issue comment "$issue" -R "$REPO" --body "Flake check: the rerun of $url failed too (${st#red|}), so this red is real. $RERUN_MARK $sha7 red -->" || log "could not comment on #$issue"
      return 0 ;;
    *) log "flake check: the rerun of run $id is $st; $BASE_BRANCH is not held meanwhile"; return 1 ;;
  esac
}

# flake_closed: ci.yml's promote reruns with the passed jobs and closes the
# dev-red issue, usually before a sweep sees the pass. With no open issue, the
# last closed one is read: a started mark with no verdict whose rerun passed
# gets its finding and mark there; one whose rerun failed gets the red mark.
flake_closed() {
  local issue comments sha7 line url st
  issue=$(gh api "repos/$REPO/issues?labels=$RED_LABEL&state=closed&sort=updated&per_page=1" \
    --jq 'first(.[] | select(.pull_request == null)) | .number' 2>/dev/null || true)
  [[ -n "$issue" ]] || return 0
  comments=$(gh api "repos/$REPO/issues/$issue/comments" --paginate --jq '.[].body' 2>/dev/null) || return 0
  for sha7 in $(grep -oE -- "$RERUN_MARK [0-9a-f]{7} started -->" <<<"$comments" | awk '{ print $3 }' | sort -u); do
    grep -qE -- "$RERUN_MARK $sha7 (flake|red) -->" <<<"$comments" && continue
    line=$(grep -F -- "$RERUN_MARK $sha7 started -->" <<<"$comments" | head -1)
    url=$(grep -oE 'https://[^ ]+/actions/runs/[0-9]+' <<<"$line" | head -1); [[ -n "$(mac_run_id "$url")" ]] || continue
    st=$(rerun_state "$(mac_run_id "$url")")
    case "$st" in
      success) flake_finding "$issue" "$sha7" "$url" "$comments" ;;
      red*) write gh issue comment "$issue" -R "$REPO" --body "Flake check: the rerun of $url failed too (${st#red|}), so that red was real. $RERUN_MARK $sha7 red -->" || log "could not comment on #$issue" ;;
    esac
  done
}

# flake_finding <issue> <sha7> <run url> <issue comments>: the flake's one
# finding, for a fixer: an open FINDING_LABEL issue with the same title gets a
# comment, else one is filed with FINDING_LABEL, FLAKY_LABEL and line:<app>
# (build_apps over the tests' files; shared or unknown: line:suite). The tests
# and jobs come from the sha's started mark. Then the mark on the dev-red
# issue says flake. A finding list that fails files nothing (a duplicate
# otherwise); the next sweep tries again.
flake_finding() {
  local issue="$1" sha7="$2" url="$3" line tests jobs title paths app n what body plural=""
  line=$(grep -F -- "$RERUN_MARK $sha7 started -->" <<<"$4" | head -1)
  tests=$(sed -nE 's/.*; failing (.*)\. A pass makes.*/\1/p' <<<"$line")
  jobs=$(sed -nE 's/.*failed jobs \(([^)]*)\) of .*/\1/p' <<<"$line")
  if [[ -n "$tests" ]]; then
    [[ "$tests" != *,* ]] || plural=s
    title="Flaky test$plural: $tests"
  else
    title="Flaky ${jobs:-CI} job on $BASE_BRANCH, no test named"
  fi
  scratch "$BASE_BRANCH" || true  # here, not in test_paths' subshell, so SCRATCH outlives it
  paths=$(test_paths "$tests"); app=suite
  if [[ -n "$paths" ]]; then app=$(build_apps <(printf '%s\n' "$paths")); [[ "$app" =~ ^[a-z]+$ && "$app" != all ]] || app=suite; fi
  body="The ${jobs:-CI} job on $BASE_BRANCH failed in $url at $sha7${tests:+, failing $tests}, and passed when the fast lane reran the failed jobs once at the same sha, so the test is flaky. The lane held nothing on it. Make the assertion runner-speed proof (a wall-clock ratio needs 10x of slack, see Tests/perf-suites.txt), or ask the supervisor to move the test to Tests/perf-suites.txt so it runs nightly instead of in the gate."
  if ! n=$(gh issue list -R "$REPO" --state open --label "$FINDING_LABEL" --limit 1000 --json number,title 2>/dev/null \
      | jq -r --arg t "$title" 'first(.[] | select(.title == $t)) | .number // empty' 2>/dev/null); then
    log "flake check: could not list the open findings; the next sweep files the flake"; return 0
  fi
  if [[ -n "$n" ]]; then
    write gh issue comment "$n" -R "$REPO" --body "Flaked again: $body" || log "could not comment on #$n"
    what="updated #$n"
  else
    write gh label create "$FLAKY_LABEL" -R "$REPO" --color fbca04 --force --description "A test that failed on dev and passed one rerun at the same sha" >/dev/null 2>&1 || true
    what=$(write gh issue create -R "$REPO" --title "$title" --label "$FINDING_LABEL" --label "$FLAKY_LABEL" --label "line:$app" --body "$body" 2>/dev/null) || what=""
    what="filed ${what:-a finding}"
  fi
  log "flake check: $sha7 was a flake ($title); $what"
  write gh issue comment "$issue" -R "$REPO" --body "Flake check: the rerun of $url passed at $sha7, so that red was a flake and the lane held nothing on it; $what. $RERUN_MARK $sha7 flake -->" || log "could not comment on #$issue"
}

# test_files <tests>: the file names in red_tests' list (<File>.swift/<test>,
# comma-separated), one per line, each once.
test_files() {
  # shellcheck disable=SC2086 # the comma list splits into words
  printf '%s\n' ${1//,/ } | sed 's:/.*::' | grep '\.swift$' | sort -u || true
}

# test_paths <tests>: the Tests/ paths of the files red_tests named, from the
# tree of origin/BASE_BRANCH in the scratch clone (trees only, so blob:none is
# enough), one per line; a file not in the tree prints nothing. Callers run it
# in a subshell, so they call scratch first: a SCRATCH made here would die with it.
test_paths() {
  local f tree
  [[ -n "$1" ]] && scratch "$BASE_BRANCH" || return 0
  tree=$(git -C "$SCRATCH" ls-tree -r --name-only "origin/$BASE_BRANCH" -- Tests 2>/dev/null) || return 0
  while IFS= read -r f; do
    [[ -z "$f" ]] || grep -E "^Tests/[^/]+/(.*/)?${f//./\\.}\$" <<<"$tree" || true
  done < <(test_files "$1") | sort -u
}

# red_scope <red sha>: the paths a PR must not touch while that red stands, as
# a regex: for each failing test's file (red_tests) under Tests/<Target>/,
# Tests/<Target>/ and Sources/<Target minus Tests>/. Nothing (the whole queue
# waits, as before) when no test is named, a file is not in the tree, or a
# target has no such Sources module (AppSnapshotTests, AppAuditTests).
red_scope() {
  local tests paths f p target module re=""
  tests=$(red_tests "$1"); [[ -n "$tests" ]] || return 0
  paths=$(test_paths "$tests")
  while IFS= read -r f; do
    grep -qE "(^|/)${f//./\\.}\$" <<<"$paths" || return 0
  done < <(test_files "$tests")
  while IFS= read -r p; do
    [[ -n "$p" ]] || return 0
    target=$(cut -d/ -f2 <<<"$p"); module="${target%Tests}"
    [[ "$module" != "$target" && -n "$(git -C "$SCRATCH" ls-tree -d "origin/$BASE_BRANCH" -- "Sources/$module" 2>/dev/null)" ]] || return 0
    [[ "$re" == *"Sources/$module/|"* ]] || re+="${re:+|}Sources/$module/|Tests/$target/"
  done <<<"$paths"
  echo "^($re)"
}

# red_bisect <issue> <good> <bad> <branch>: finds the first commit in the
# first-parent chain <good>..<bad> (on <branch> at REMOTE) whose Linux job is
# red, with at most MAX_BISECT probes ci/bisect-<bad7>-<i> (each pushed at the
# chain's i-th commit and given a Linux-only run), waiting up to BATCH_WAIT
# for a running probe. lo is the longest green prefix (the good commit counts
# as 0), hi the shortest red one; a red-triage guess on <issue> is probed
# first (its parent, then itself); hi = lo + 1 names the culprit, which is
# posted on <issue> (with BISECT_MARK, so an issue with a verdict is never
# bisected again, whichever red sha its range names now) and on
# the owning feature-lead issue, and the probes are deleted. Vote mode (the
# header's rung 2c paragraph) is chosen once per call from the tip's failed log.
red_bisect() {
  local issue="$1" good="$2" bad="$3" branch="$4" d k i sha v lo hi mid red7 hint=0 waited=0 line probes n p
  local mode="" cap="$MAX_BISECT" used nr runs
  local chain=() verd=() nruns=()
  DISPATCHED=""
  if ! scratch "$branch" "$good"; then log "bisect: could not fetch $branch and $good from $REMOTE"; return; fi
  d="$SCRATCH"
  bad=$(git -C "$d" rev-parse --verify -q "$bad^{commit}" 2>/dev/null) || { log "bisect: $3 is not a commit at $REMOTE"; return; }
  good=$(git -C "$d" rev-parse --verify -q "origin/$good^{commit}" 2>/dev/null || git -C "$d" rev-parse --verify -q "$good^{commit}" 2>/dev/null) \
    || { log "bisect: $2 is not a commit at $REMOTE"; return; }
  red7=${bad:0:7}
  # One verdict per issue, whatever the red sha: ci.yml moves the issue's range
  # to each newer red run, and the culprit found once is the culprit.
  if has_comment "$issue" "$BISECT_MARK "; then log "bisect: #$issue already has its verdict; not bisecting $red7"; return; fi
  while read -r sha; do chain+=("$sha"); done < <(git -C "$d" rev-list --first-parent --reverse "$good..$bad" 2>/dev/null)
  k=${#chain[@]}
  (( k )) || { log "bisect: $good..$bad holds no first-parent commits"; return; }
  chain=("$good" "${chain[@]}")
  # red-triage's confident guess: the chain index of the PR it names.
  line=$(gh api "repos/$REPO/issues/$issue/comments" --paginate --jq '.[].body' 2>/dev/null \
    | grep -oE 'Likely cause: #[0-9]+ .*\(Clef [0-9.]+\)' | tail -1 || true)
  if [[ -n "$line" ]]; then
    n=$(grep -oE '#[0-9]+' <<<"$line" | head -1 | tr -d '#'); p=$(grep -oE '\(Clef [0-9.]+' <<<"$line" | grep -oE '[0-9.]+$')
    if awk -v p="$p" -v m="$CLEF_MIN" 'BEGIN { exit !(p + 0 >= m + 0) }'; then
      for (( i = 1; i <= k; i++ )); do
        [[ "$(git -C "$d" log -1 --format=%s "${chain[i]}")" == *"(#$n)" ]] && hint=$i
      done
      (( hint )) && log "bisect: red-triage names #$n (Clef $p), commit $hint of $k; probing around it first"
    fi
  fi
  mode=$(vote_mode "$(check_verdict "$bad")")
  if [[ -n "$mode" ]]; then
    cap="$MAX_BISECT_BUDGET"
    log "bisect: $red7 fails only a budget test (${mode#* }); each probe votes 2 of 3, at most $cap runs"
  fi
  while :; do
    for (( i = 0; i <= k; i++ )); do verd[i]=""; nruns[i]=0; done
    runs=0
    verd[k]=$(check_verdict "$bad")
    probes=$(git ls-remote --heads "$REMOTE" "refs/heads/${BISECT_PREFIX}${red7}-*" 2>/dev/null | sed 's:[[:space:]]*refs/heads/: :' || true)
    while read -r sha line; do
      [[ -n "$line" ]] || continue
      i="${line##*-}"
      (( i >= 1 && i < k )) && [[ "${chain[i]}" == "$sha" ]] || continue
      if [[ -n "$mode" ]]; then
        v=$(probe_votes "$sha"); nr="${v##*$'\t'}"
        verd[i]="${v%%$'\t'*}" nruns[i]="$nr" runs=$((runs + nr))
      else
        verd[i]=$(check_verdict "$sha")
      fi
    done <<<"$probes"
    used=$(grep -c . <<<"$probes" || true)
    [[ -z "$mode" ]] || used="$runs"
    case "${verd[k]}" in
      green*) log "bisect: $red7 is green now (${verd[k]#green|}); nothing to find"; bisect_drop "$red7"; return ;;
    esac
    lo=0; hi=$k
    for (( i = 1; i < k; i++ )); do
      case "${verd[i]}" in green*) lo=$i ;; red*) (( i < hi )) && hi=$i ;; esac
    done
    if (( hi == lo + 1 )); then
      bisect_post "$issue" "$red7" "$lo" "$hi" "$used" "${verd[lo]}" "${verd[hi]}" "$mode" "${chain[@]}"
      bisect_drop "$red7"; return
    fi
    if (( DRY_RUN )); then log "dry-run: bisect $red7 on #$issue: $k commits, green prefix $lo, red from $hi"; return; fi
    if (( used >= cap )); then
      log "bisect: $red7 used $cap runs; stopping between $lo and $hi"
      write gh issue comment "$issue" -R "$REPO" --body "Bisect on $BASE_BRANCH stopped after $cap Linux runs: the Linux job is green at ${chain[lo]:0:7} and red at ${chain[hi]:0:7}; the culprit is one of the $((hi - lo)) commits between them (git log --first-parent ${chain[lo]:0:7}..${chain[hi]:0:7}). $BISECT_MARK $red7 -->"
      bisect_drop "$red7"; return
    fi
    # A probe still voting is finished before a new one opens.
    mid=""
    for (( i = lo + 1; i < hi; i++ )); do [[ "${verd[i]}" != more ]] || { mid=$i; break; }; done
    if [[ -n "$mid" ]]; then :
    elif (( hint > lo && hint <= hi )) && (( hint - 1 > lo )) && [[ -z "${verd[hint - 1]}" ]]; then mid=$((hint - 1))
    elif (( hint > lo && hint < hi )) && [[ -z "${verd[hint]}" ]]; then mid=$hint
    else mid=$(( (lo + hi) / 2 )); fi
    p="${BISECT_PREFIX}${red7}-$mid"
    case "${verd[mid]}" in
      running) log "bisect: $red7 probe $mid running" ;;
      "")
        if git -C "$d" push -q origin "${chain[mid]}:refs/heads/$p" 2>/dev/null; then
          log "bisect: $red7 probing commit $mid of $k (${chain[mid]:0:7})"; dispatch_linux "$p" "$p#0"
        else log "bisect: could not push probe $mid; the next sweep tries again"; fi ;;
      *) dispatch_linux "$p" "$p#${nruns[mid]}" ;;
    esac
    if (( waited >= BATCH_WAIT )); then return; fi
    sleep "$BATCH_POLL"; waited=$(( waited + BATCH_POLL ))
  done
}

# bisect_post <issue> <red7> <lo> <hi> <runs> <green verdict> <red verdict>
# <mode> <chain...>: the culprit on the dev-red issue and on the owning
# feature-lead issue. <mode> is empty, "budget <m> <op> <b>" (vote mode) or
# "likely <m> <op> <b>" (vote mode, the value near its budget: not certain).
bisect_post() {
  local issue="$1" red7="$2" lo="$3" hi="$4" runs="$5" gv="$6" rv="$7" mode="$8"; shift 8
  local chain=("$@") c subj n lead head="Bisect:" is="is" note
  c="${chain[hi]}"; subj=$(git -C "$SCRATCH" log -1 --format=%s "$c")
  n=$(grep -oE '\(#[0-9]+\)$' <<<"$subj" | tr -dc 0-9 || true)
  note=$(vote_note "$mode")
  if [[ "$mode" == likely* ]]; then head="Bisect (likely):" is="is likely"; fi
  log "bisect: culprit ${c:0:7} $subj (green at ${chain[lo]:0:7}, $runs runs${mode:+, $mode})"
  write gh issue comment "$issue" -R "$REPO" --body "$head ${c:0:7} $subj $is the first commit on $BASE_BRANCH whose Linux job fails. Green at ${chain[lo]:0:7} (${gv#green|}), red at ${c:0:7} (${rv#red|}); $runs Linux run(s) on ci/bisect branches, now deleted.$note $BISECT_MARK $red7 -->"
  [[ -n "$n" ]] || return 0
  lead=$(feature_lead "$n")
  [[ -n "$lead" ]] || return 0
  write gh issue comment "$lead" -R "$REPO" --body "Bisect on dev-red #$issue: your PR #$n ($subj) $is the first commit that turns $BASE_BRANCH's Linux job red: ${rv#red|}. $BISECT_MARK $red7 -->"
}

# feature_lead <PR n>: the open feature-lead issue the PR body's `Feature:`
# line names, or nothing.
feature_lead() {
  local body fid
  body=$(gh api "repos/$REPO/pulls/$1" --jq '.body // ""' 2>/dev/null) || return 0
  fid=$(grep -E '^[[:space:]]*\**Feature:' <<<"$body" | head -1 | sed -E 's/^[[:space:]]*\**Feature:\**[[:space:]]*`?#?//; s/`.*//; s/[[:space:]].*//' || true)
  [[ -n "$fid" ]] || return 0
  gh api "search/issues?q=repo:$REPO+label:$FEATURE_ISSUE_LABEL+state:open+in:title+%22Feature:+$fid%22" \
    --jq "[.items[] | select(.title == \"Feature: $fid\" or (.title | endswith(\"($fid)\")))] | first // empty | .number" 2>/dev/null || true
}

# bisect_drop <red7>: deletes that red's probe branches at REMOTE.
bisect_drop() {
  local names
  names=$(git ls-remote --heads "$REMOTE" "refs/heads/${BISECT_PREFIX}$1-*" 2>/dev/null | sed 's:.*refs/heads/::' | paste -sd' ' -)
  [[ -z "$names" ]] || git -C "$SCRATCH" push -q origin --delete $names 2>/dev/null || log "bisect: could not delete $names"
}

# revert_sweep: with LANE_VERIFY_AFTER=1, lands the lane's open revert PR
# (revert_land), or while a dev-red issue is open (red_sweep) makes one revert
# call per verdict revert_culprit gives: a revert of that culprit
# (revert_open), or a note on why there is none. REVERT_MARK <sha7|none> on
# the issue records each call, so a culprit (or "none") is called once, and a
# later bisect naming a different culprit in the same issue gets its own call.
# At most one revert per sweep, never two for one PR (an open lane revert of
# it, or a revert of it on dev), never a revert of a revert.
revert_sweep() {
  (( LANE_VERIFY_AFTER )) || return 0
  local all open comments got c c7 subj n
  [[ -n "$BASE_RED" ]] || return 0
  # The lane's revert PRs: a bot's (the lane's token) on a REVERT_PREFIX branch
  # with REVERT_LABEL. The one whose body refs this dev-red issue lands; one
  # left from an older red is never landed under a new one; a human closes it.
  if ! all=$(open_list 2>/dev/null | jq -ce --arg l "$REVERT_LABEL" --arg p "$REVERT_PREFIX" '[.[]
      | select(.author.is_bot == true and ((.headRefName // "") | startswith($p)) and any(.labels[]?; .name == $l))]' 2>/dev/null); then
    log "auto-revert: could not list open PRs; the next sweep looks again"; return 0
  fi
  open=$(jq -r --arg r "Refs #$BASE_RED." 'first(.[] | select((.body // "") | contains($r)))
    | "\(.number)|\(.headRefOid)|\(.headRefName)"' <<<"$all" 2>/dev/null || true)
  if [[ -n "$open" ]]; then revert_land "$open"; return 0; fi
  if ! comments=$(gh api "repos/$REPO/issues/$BASE_RED/comments" --paginate --jq '.[].body' 2>/dev/null); then
    log "auto-revert: could not read dev-red #$BASE_RED's comments; the next sweep looks again"; return 0
  fi
  [[ -n "$BASE_RED_SHA" ]] || { log "auto-revert: dev-red #$BASE_RED names no culprit range"; return 0; }
  if ! scratch main "$BASE_BRANCH"; then log "auto-revert: could not fetch main and $BASE_BRANCH"; return 0; fi
  got=$(revert_culprit "$comments") || return 0
  c="${got%%|*}"; c7=none; [[ "$c" == - ]] || c7="${c:0:7}"
  if grep -qF -- "$REVERT_MARK $c7 -->" <<<"$comments"; then
    # A call that made no revert, or a revert already in the red range (dev is still red with it), leaves the red to quarantine_sweep.
    if [[ "$c7" == none ]] || [[ "$(git -C "$SCRATCH" log --format=%B "origin/main..$BASE_RED_SHA" 2>/dev/null)" == *"This reverts commit $c"* ]]; then RED_UNRESOLVED=1; fi
    log "auto-revert: dev-red #$BASE_RED already had its revert call on $c7; waiting for CI on $BASE_BRANCH or a human"; return 0
  fi
  if [[ "$c" == - ]]; then revert_note none "${got#*|}"; return 0; fi
  subj=$(git -C "$SCRATCH" log -1 --format=%s "$c")
  n=$(grep -oE '\(#[0-9]+\)$' <<<"$subj" | tr -dc 0-9 || true)
  if [[ "$subj" == 'Revert "'* ]]; then revert_note "$c7" "the culprit $c7 ($subj) is a revert itself, and the lane never reverts a revert, so a human looks"; return 0; fi
  [[ -n "$n" ]] || { revert_note "$c7" "the culprit $c7 ($subj) is no PR's squash commit, so a human looks"; return 0; }
  if jq -e --arg b "$REVERT_PREFIX$n" 'any(.[]; .headRefName == $b)' <<<"$all" >/dev/null 2>&1 \
      || [[ "$(git -C "$SCRATCH" log --format=%B "origin/main..origin/$BASE_BRANCH" 2>/dev/null)" == *"This reverts commit $c"* ]]; then
    revert_note "$c7" "#$n ($c7) is the culprit (${got#*|}), but a revert of it is already open or on $BASE_BRANCH, so a human looks"; return 0
  fi
  revert_open "$c" "$n" "$subj" "${got#*|}"
}

# revert_culprit <dev-red issue comments>: the culprit as <sha>|<how it was
# found>: red_bisect's verdict on the issue (a certain one: "likely" means a
# timing budget test on its line), else the only PR commit in
# main..BASE_RED_SHA. A Linux red the bisect hasn't judged yet waits
# (non-zero). Anything else prints -|<why none>: red_bisect runs only on
# Linux, and reverting newest first would hit innocent PRs, each step a full
# macOS run on dev to read.
revert_culprit() {
  local s c prs np
  s=$(grep -oE '^Bisect: [0-9a-f]{7} ' <<<"$1" | tail -1 | cut -d' ' -f2 || true)
  if [[ -n "$s" ]] && c=$(git -C "$SCRATCH" rev-parse --verify -q "$s^{commit}" 2>/dev/null); then
    echo "$c|the bisect on dev-red #$BASE_RED named it"; return 0
  fi
  prs=$(git -C "$SCRATCH" log --first-parent --format='%H %s' "origin/main..$BASE_RED_SHA" 2>/dev/null | grep -E '\(#[0-9]+\)$' || true)
  np=$(grep -c . <<<"$prs" || true)
  if (( np == 1 )); then echo "${prs%% *}|it is the only PR in main..${BASE_RED_SHA:0:7}"; return 0; fi
  if [[ "$BASE_RED_JOBS" == *linux* ]] && ! grep -qF -- "$BISECT_MARK " <<<"$1"; then
    log "auto-revert: $np PRs in main..${BASE_RED_SHA:0:7}; waiting for the bisect"; return 1
  fi
  echo "-|$np PRs in main..${BASE_RED_SHA:0:7} and no bisect verdict names one of them (red: ${BASE_RED_JOBS#*: }), so a human picks the culprit"
}

# revert_note <sha7|none> <text>: the lane's one revert call on that culprit
# (or on none), logged and posted on the dev-red issue with REVERT_MARK.
revert_note() {
  RED_UNRESOLVED=1
  log "auto-revert: $2"
  write gh issue comment "$BASE_RED" -R "$REPO" --body "Auto-revert: $2. $REVERT_MARK $1 -->" || log "could not comment on #$BASE_RED"
}

# red_tests <sha>: the tests failing in <sha>'s red Linux and macOS logs
# (mac_tests), joined by ", "; nothing when no log names one.
red_tests() {
  local v t=""
  for v in "$(check_verdict "$1")" "$(mac_verdict "$1")"; do
    [[ "$v" != red* ]] || t+="$(mac_tests "$v" || true)"$'\n'
  done
  grep . <<<"$t" | LC_ALL=C sort -u | paste -sd, - | sed 's/,/, /g' || true
}

# revert_open <sha> <PR n> <subject> <how>: `git revert` of the culprit's
# squash commit on today's BASE_BRANCH, pushed as REVERT_PREFIX<n> and opened
# as a PR with REVERT_LABEL and p0 (never fast-lane: revert_land lands it on
# its Linux check alone), then the issue's REVERT_MARK note. The culprit PR is
# merged, so its feature-lead issue (or the PR) is told why and how to bring
# it back, and a `finding` issue is filed for its app (line:<app>, line:suite
# for shared code).
revert_open() {
  local c="$1" n="$2" subj="$3" how="$4" br="$REVERT_PREFIX$2" d="$SCRATCH" why tests url m lead f app denied
  local bot=(-c user.name="github-actions[bot]" -c user.email="41898282+github-actions[bot]@users.noreply.github.com")
  f=$(mktemp); git -C "$d" diff --no-renames --name-only "$c^" "$c" >"$f" 2>/dev/null || true
  # A protected path stays captain-reviewed, a revert by the lane included (and its token can't push workflows).
  denied=$(grep -Ei -- "$DENY_RE" "$f" | paste -sd, - | sed 's/,/, /g' || true)
  if [[ -n "$denied" ]]; then
    rm -f "$f"; revert_note "${c:0:7}" "#$n (${c:0:7}) is the culprit ($how), but it touches protected paths ($denied), so a human reverts it"; return 0
  fi
  app=$(build_apps "$f"); rm -f "$f"
  [[ "$app" =~ ^[a-z]+$ && "$app" != all ]] || app=suite
  if (( DRY_RUN )); then log "dry-run, would revert #$n (${c:0:7}: $how) on $br"; return 0; fi
  if ! git -C "$d" checkout -q -B revert "origin/$BASE_BRANCH" 2>/dev/null || ! bash "$HERE/install-merge-drivers" "$d" >/dev/null 2>&1 \
      || ! git -C "$d" "${bot[@]}" revert --no-edit "$c" >/dev/null 2>&1; then
    git -C "$d" revert --abort >/dev/null 2>&1 || true
    revert_note "${c:0:7}" "#$n (${c:0:7}) is the culprit ($how), but it does not revert cleanly on today's $BASE_BRANCH, so a human reverts it"; return 0
  fi
  if ! git -C "$d" push -q -f origin "HEAD:refs/heads/$br" 2>/dev/null; then
    revert_note "${c:0:7}" "#$n (${c:0:7}) is the culprit ($how), but the lane could not push its revert to $br, so a human reverts it"; return 0
  fi
  tests=$(red_tests "$BASE_RED_SHA")
  why="$BASE_BRANCH went red on ${BASE_RED_JOBS#*: } at ${BASE_RED_SHA:0:7} (dev-red #$BASE_RED, run ${BASE_RED_RUN:-not named})${tests:+, failing $tests}"
  write gh label create "$REVERT_LABEL" -R "$REPO" --color b60205 --force --description "The fast lane's revert of a red dev's culprit" >/dev/null 2>&1 || true
  if ! url=$(gh pr create -R "$REPO" --base "$BASE_BRANCH" --head "$br" --label "$REVERT_LABEL" --label p0 --title "Revert \"$subj\"" \
      --body "Reverts #$n ($subj): $why. The culprit is ${c:0:7}: $how.

Refs #$BASE_RED. This reverts commit $c. The fast lane opened this PR and lands it on its Linux check alone, since it puts back code $BASE_BRANCH already ran; CI on $BASE_BRANCH runs once it lands. To bring the change back, open a new PR that reverts this revert and adds the fix." 2>/dev/null); then
    revert_note "${c:0:7}" "#$n (${c:0:7}) is the culprit ($how). The lane pushed its revert to $br but could not open the PR (can GitHub Actions create PRs in this repo?), so a human opens it"; return 0
  fi
  m="${url##*/}"
  revert_note "${c:0:7}" "#$n (${c:0:7}) is the culprit ($how); the lane opened #$m to revert it"
  RED_UNRESOLVED=0  # the one note that is a revert: the red has its fix in flight
  lead=$(feature_lead "$n")
  write gh issue comment "${lead:-$n}" -R "$REPO" --body "Fast lane: #$n was reverted by #$m. $why, and the lane found #$n as the culprit ($how). Nothing is lost: to bring it back, open a new PR that reverts #$m's commit and fixes the failure, run scripts/ci --changed, and send it through the lane again." \
    || log "could not comment on #${lead:-$n}"
  write gh issue create -R "$REPO" --title "Reverted #$n: $BASE_BRANCH red on ${BASE_RED_JOBS#*: }" --label "$FINDING_LABEL" --label "line:$app" \
    --body "#$n ($subj) was reverted by #$m. $why. The lane found it as the culprit: $how. Fix the failure and bring the change back in a new PR that reverts #$m's commit." >/dev/null \
    || log "could not file the finding for #$n"
}

# revert_land <n>|<head>|<branch>: the lane's open revert PR for the open
# dev-red issue lands, once no batch holds the lane (HOLD), on its own Linux
# check (started once per head, its comment the record). A stale check
# (proof_stale), or a merge refused because dev moved under it into a
# conflict, gets the revert rebuilt on today's BASE_BRANCH and checked again;
# a red check, or a rebuild that conflicts, leaves it to a human.
revert_land() {
  local m head br v stale
  IFS='|' read -r m head br <<<"$1"
  v=$(check_verdict "$head")
  case "$v" in
    none)
      if has_comment "$m" "started a Linux check on head $head"; then log "auto-revert: #$m: its Linux check on $head started; waiting"; return 0; fi
      dispatch_linux "$br"
      comment_once "$m" "Fast lane: started a Linux check on head $head; this revert lands once it passes." ;;
    running) log "auto-revert: #$m: its Linux check is running" ;;
    red*) comment_once "$m" "Fast lane: the Linux check on this revert is red (${v#red|}), so a human looks." ;;
    green*)
      if (( HOLD )); then log "auto-revert: #$m waits for the batch in flight"; return 0; fi
      if ! scratch "$BASE_BRANCH" "$br"; then log "auto-revert: could not fetch $br; the next sweep looks again"; return 0; fi
      stale=$(proof_stale "$(git -C "$SCRATCH" merge-base "$head" "origin/$BASE_BRANCH" 2>/dev/null || true)" "$head")
      if [[ -z "$stale" ]]; then
        land "$m" "$head" "its own Linux check, ${v#green|}" && return 0
        [[ "$(gh pr view "$m" -R "$REPO" --json mergeable 2>/dev/null | jq -r '.mergeable // ""')" == CONFLICTING ]] || return 0
        stale="it conflicts with $BASE_BRANCH"
      fi
      rebuild_lane_pr "$m" "$head" "$br" revert "$stale" ;;
  esac
}

# rebuild_lane_pr <n> <head> <branch> <what> <why>: the lane's own PR (a
# revert or a quarantine change) cherry-picked onto today's BASE_BRANCH and
# force-pushed, so it gets a fresh Linux check; a pick that conflicts leaves it
# to a human, with one comment.
rebuild_lane_pr() {
  local m="$1" head="$2" br="$3" what="$4" why="$5"
  log "$what: #$m's Linux check no longer holds ($why); rebuilding it on today's $BASE_BRANCH"
  if (( DRY_RUN )); then log "dry-run, would rebuild $br"; return 0; fi
  if ! git -C "$SCRATCH" checkout -q -B rebuild "origin/$BASE_BRANCH" 2>/dev/null \
      || ! git -C "$SCRATCH" -c user.name="github-actions[bot]" -c user.email="41898282+github-actions[bot]@users.noreply.github.com" cherry-pick "$head" >/dev/null 2>&1 \
      || ! git -C "$SCRATCH" push -q -f origin "HEAD:refs/heads/$br" 2>/dev/null; then
    git -C "$SCRATCH" cherry-pick --abort >/dev/null 2>&1 || true
    comment_once "$m" "Fast lane: this $what's Linux check no longer holds ($why) and the lane could not rebuild it on $BASE_BRANCH, so a human looks."
  fi
}

# quarantine_sweep: with LANE_VERIFY_AFTER=1, lands the lane's open
# QUAR_BRANCH PR (quarantine_land), else reads the lane's entries in QUAR_FILE
# on BASE_BRANCH: an owner past its `until` gets BLOCKER_LABEL and a comment
# (quarantine_expiry), a closed owner gets the PR that removes its entries,
# and, when revert_sweep left the red unresolved (RED_UNRESOLVED), the red's
# failing tests are quarantined (quarantine_add). One PR at a time.
quarantine_sweep() {
  (( LANE_VERIFY_AFTER )) || return 0
  local all open json
  if ! all=$(open_list 2>/dev/null | jq -ce --arg l "$QUAR_LABEL" --arg b "$QUAR_BRANCH" '[.[]
      | select(.author.is_bot == true and .headRefName == $b and any(.labels[]?; .name == $l))]' 2>/dev/null); then
    log "auto-quarantine: could not list open PRs; the next sweep looks again"; return 0
  fi
  open=$(jq -r --arg q "$QUAR_LINE" 'first(.[]) | "\(.number)|\(.headRefOid)|\(.headRefName)|\((.body // "") | capture($q + " (?<k>add|remove)(?<o>[#0-9 ]*)") // {k: "add", o: ""} | "\(.k)|\(.o)")"' <<<"$all" 2>/dev/null || true)
  if [[ -n "$open" ]]; then quarantine_land "$open"; return 0; fi
  if ! scratch main "$BASE_BRANCH"; then log "auto-quarantine: could not fetch $BASE_BRANCH"; return 0; fi
  json=$(git -C "$SCRATCH" show "origin/$BASE_BRANCH:$QUAR_FILE" 2>/dev/null) || json='[]'
  jq -e 'type == "array"' <<<"$json" >/dev/null 2>&1 || { log "auto-quarantine: $QUAR_FILE on $BASE_BRANCH is not a JSON array; a human looks"; return 0; }
  quarantine_expiry "$json" || return 0
  (( RED_UNRESOLVED )) && [[ -n "$BASE_RED" && -n "$BASE_RED_SHA" ]] || return 0
  quarantine_add "$json"
}

# quarantine_expiry <quarantine json>: each lane entry's owner is read once:
# closed, its entries go into one removal PR (returns 1 once that is open);
# open and past the entry's `until`, it gets BLOCKER_LABEL and a comment, once.
# The entry stays either way: an expired quarantine never comes back as a red.
quarantine_expiry() {
  local json="$1" owner until tests st labels closed="" new ids
  while IFS=$'\t' read -r owner until tests; do
    [[ -n "$owner" ]] || continue
    st=$(gh api "repos/$REPO/issues/${owner#\#}" --jq '"\(.state)\t\([.labels[]?.name] | join(","))"' 2>/dev/null) || { log "auto-quarantine: could not read $owner; the next sweep looks again"; continue; }
    labels="${st#*$'\t'}"; st="${st%%$'\t'*}"
    if [[ "$st" != OPEN ]]; then closed+="${closed:+ }$owner"; continue; fi
    [[ "$until" < "$(quar_now)" ]] || continue
    [[ ",$labels," != *",$BLOCKER_LABEL,"* ]] || continue
    log "auto-quarantine: $owner is past its quarantine expiry ($until); labelling it $BLOCKER_LABEL"
    write gh label create "$BLOCKER_LABEL" -R "$REPO" --color b60205 --force --description "A quarantined test whose fix is overdue" >/dev/null 2>&1 || true
    write gh issue edit "${owner#\#}" -R "$REPO" --add-label "$BLOCKER_LABEL" || log "could not label $owner"
    write gh issue comment "${owner#\#}" -R "$REPO" --body "Blocker: the quarantine of $tests expired at $until and this issue is still open. The test stays skipped on $BASE_BRANCH until this closes (the lane never un-quarantines into a red); \`scripts/quarantine release\` fails while it is in. Fix it, close this issue, and the lane removes the entry." \
      || log "could not comment on $owner"
  done < <(jq -r '[.[] | select((.lane | type) == "object")] | group_by(.owner)[] | [.[0].owner, .[0].lane.until, ([.[].test] | join(", "))] | @tsv' <<<"$json")
  [[ -n "$closed" ]] || return 0
  ids=$(jq -r --arg o " $closed " '[.[] | .owner as $w | select((.lane | type) == "object" and ($o | contains(" " + $w + " "))) | .test] | join(", ")' <<<"$json")
  new=$(jq --arg o " $closed " 'map(.owner as $w | select(((.lane | type) == "object" and ($o | contains(" " + $w + " "))) | not))' <<<"$json")
  log "auto-quarantine: $closed closed; removing $ids from the quarantine"
  quarantine_pr remove "$new" "test(quarantine): run $ids again" "$QUAR_LINE remove $closed
Removes the fast lane's quarantine entries of $ids: their owner issue ($closed) closed, so the fix should be on $BASE_BRANCH. This PR's own Linux check runs the test again; red, the lane reopens the owner and closes this PR." >/dev/null || return 0
  return 1
}

# quarantine_add <quarantine json>: one call per red sha (QUAR_MARK on the
# dev-red issue). The red's failing tests (red_tests) are placed in the tree
# and resolved to perf-list ids (scripts/test-scope ids); more than QUAR_MAX
# of them, a test on a QUAR_NEVER_RE path, one already quarantined, or one
# that can't be placed is a note, not an entry. Each entry's owner is its
# `Quarantined: <id>` finding (quarantine_issue); then the one PR.
quarantine_add() {
  local json="$1" red7="${BASE_RED_SHA:0:7}" comments tests n t f name path target id why="" e until prs p lead list="" app issue entry new added="" m title
  local ids=()
  comments=$(gh api "repos/$REPO/issues/$BASE_RED/comments" --paginate --jq '.[].body' 2>/dev/null) || { log "auto-quarantine: could not read dev-red #$BASE_RED's comments"; return 0; }
  ! grep -qF -- "$QUAR_MARK $red7 -->" <<<"$comments" || return 0
  tests=$(red_tests "$BASE_RED_SHA")
  [[ -n "$tests" ]] || { quarantine_note "$red7" "no failing test is named in the red logs at $red7 (a build error or a crash), so nothing is quarantined and the red stays with today's handling"; return 0; }
  n=$(tr ',' '\n' <<<"$tests" | grep -c .)
  if (( n > QUAR_MAX )); then
    quarantine_note "$red7" "$n tests fail at $red7 ($tests): more than $QUAR_MAX, so something broke broadly; nothing is quarantined and the red stays with today's handling (a human picks the culprit)"; return 0
  fi
  for t in ${tests//,/ }; do
    f="${t%%/*}"; name="${t#*/}"; name="${name%%(*}"
    path=$(test_paths "$t" | head -1)
    [[ -n "$path" ]] || { why+="${why:+; }$t: its file is not under Tests/ on $BASE_BRANCH"; continue; }
    target=$(cut -d/ -f2 <<<"$path")
    id=$(git -C "$SCRATCH" show "origin/$BASE_BRANCH:$path" 2>/dev/null >"$SCRATCH/.quar.swift" \
      && python3 "$HERE/test-scope" ids "$target" "$SCRATCH/.quar.swift" 2>/dev/null | grep -E "(/|\.)$name\$" | head -1 || true)
    [[ -n "$id" ]] || { why+="${why:+; }$t: no @Test $name in $path"; continue; }
    if grep -qiE -- "$QUAR_NEVER_RE" <<<"$path $id"; then why+="${why:+; }$id: a security, billing or auth test is never quarantined"; continue; fi
    if jq -e --arg t "$id" 'any(.[]; .test == $t)' <<<"$json" >/dev/null; then why+="${why:+; }$id is already quarantined"; continue; fi
    ids+=("$id|$path")
  done
  (( ${#ids[@]} )) || { quarantine_note "$red7" "nothing to quarantine: $why; the red stays with today's handling"; return 0; }
  prs=$(git -C "$SCRATCH" log --first-parent --format=%s "origin/main..$BASE_RED_SHA" 2>/dev/null | grep -oE '\(#[0-9]+\)$' | tr -dc '0-9\n' | sort -un)
  for p in $prs; do lead=$(feature_lead "$p"); list+="${list:+, }#$p${lead:+ (lead #$lead)}"; done
  until=$(jq -rn --arg n "$(quar_now)" --argjson h "$QUAR_HOURS" '$n | fromdate + $h * 3600 | todate')
  new="$json"
  for e in "${ids[@]}"; do
    id="${e%%|*}"; path="${e#*|}"
    app=$(build_apps <(printf '%s\n' "$path")); [[ "$app" =~ ^[a-z]+$ && "$app" != all ]] || app=suite
    issue=$(quarantine_issue "$id" "$app" "The fast lane quarantined \`$id\` ($path): $BASE_BRANCH is red on ${BASE_RED_JOBS#*: } at $red7 (dev-red #$BASE_RED, run ${BASE_RED_RUN:-not named}) and the lane found no culprit to revert. PRs in the culprit range main..$red7: ${list:-none found}; their leads own the fix. The test is skipped on $BASE_BRANCH until $until; past that this issue is a \`$BLOCKER_LABEL\`, and the test stays skipped until the fix lands and this issue closes, when the lane removes the entry (its PR's Linux check runs the test again). \`scripts/quarantine release\` fails while the entry is in.") || continue
    entry=$(jq -nc --arg t "$id" --arg o "#$issue" --arg r "Quarantined by the fast lane: fails on $BASE_BRANCH at $red7 (dev-red #$BASE_RED) with no culprit to revert; #$issue owns the fix" \
      --arg x "${until:0:10}" --arg red "#$BASE_RED" --arg range "main..$red7" --arg u "$until" \
      '{test: $t, owner: $o, reason: $r, expires: $x, lane: {red: $red, range: $range, until: $u}}')
    new=$(jq --argjson e "$entry" '. + [$e]' <<<"$new")
    added+="${added:+, }$id (#$issue)"
  done
  [[ -n "$added" ]] || { log "auto-quarantine: could not file an issue for any failing test; the next sweep tries again"; return 0; }
  title="test(quarantine): skip $(sed -E 's/ \(#[0-9]+\)//g' <<<"$added")"
  m=$(quarantine_pr add "$new" "$title" "$QUAR_LINE add
Quarantines $added for $QUAR_HOURS h: $BASE_BRANCH is red on ${BASE_RED_JOBS#*: } at $red7 and the lane has no culprit to revert (range main..$red7: ${list:-no PR}). Each entry's owner issue is the p0 finding for its line; the fix lands through a normal PR, then its owner closes and the lane removes the entry.

Refs #$BASE_RED. The fast lane opened this PR and lands it on its Linux check alone: it changes only $QUAR_FILE, the one protected path the lane may edit itself (quarantine_land in scripts/fast-lane.sh). CI on $BASE_BRANCH runs once it lands.") || { quarantine_note "$red7" "the lane could not open its quarantine PR for $added (each has its issue); a human adds the entries"; return 0; }
  quarantine_note "$red7" "quarantined $added for $QUAR_HOURS h in #$m, which lands on its own Linux check; then CI on $BASE_BRANCH runs green and normal batching resumes. Past the expiry each open owner is a $BLOCKER_LABEL"
}

# quarantine_issue <id> <app> <body>: the test's `Quarantined: <id>` finding,
# its number on stdout: an open one (FINDING_LABEL, that title) gets a
# comment, else one is filed with p0, FINDING_LABEL and line:<app>. Nothing
# (non-zero) when the list fails or the filing does, so no duplicate is filed.
quarantine_issue() {
  local id="$1" app="$2" body="$3" title="Quarantined: $1" n url
  if ! n=$(gh issue list -R "$REPO" --state open --label "$FINDING_LABEL" --limit 1000 --json number,title 2>/dev/null \
      | jq -r --arg t "$title" 'first(.[] | select(.title == $t)) | .number // empty' 2>/dev/null); then
    log "auto-quarantine: could not list the open findings; the next sweep tries again"; return 1
  fi
  if [[ -n "$n" ]]; then
    write gh issue comment "$n" -R "$REPO" --body "Quarantined again: $body" || log "could not comment on #$n"
    echo "$n"; return 0
  fi
  url=$(write gh issue create -R "$REPO" --title "$title" --label p0 --label "$FINDING_LABEL" --label "line:$app" --body "$body" 2>/dev/null) || { log "auto-quarantine: could not file the finding for $id"; return 1; }
  [[ "$url" =~ /([0-9]+)$ ]] || { (( DRY_RUN )) && echo 0 && return 0; return 1; }
  echo "${BASH_REMATCH[1]}"
}

# quarantine_pr <add|remove> <quarantine json> <title> <body>: QUAR_FILE
# rewritten on today's BASE_BRANCH, pushed to QUAR_BRANCH and opened as a PR
# with QUAR_LABEL and p0 (never fast-lane); its number on stdout.
quarantine_pr() {
  local kind="$1" json="$2" title="$3" body="$4" d="$SCRATCH" url
  local bot=(-c user.name="github-actions[bot]" -c user.email="41898282+github-actions[bot]@users.noreply.github.com")
  if (( DRY_RUN )); then log "dry-run, would open the quarantine $kind PR: $title"; echo 0; return 0; fi
  if ! git -C "$d" checkout -q -B quarantine "origin/$BASE_BRANCH" 2>/dev/null || ! mkdir -p "$d/$(dirname "$QUAR_FILE")" \
      || ! jq . <<<"$json" >"$d/$QUAR_FILE" || ! git -C "$d" add "$QUAR_FILE" || ! git -C "$d" "${bot[@]}" commit -qm "$title" >/dev/null 2>&1 \
      || ! git -C "$d" push -q -f origin "HEAD:refs/heads/$QUAR_BRANCH" 2>/dev/null; then
    log "auto-quarantine: could not push the $kind to $QUAR_BRANCH"; return 1
  fi
  write gh label create "$QUAR_LABEL" -R "$REPO" --color b60205 --force --description "The fast lane's own change to UITests/quarantine.json" >/dev/null 2>&1 || true
  url=$(gh pr create -R "$REPO" --base "$BASE_BRANCH" --head "$QUAR_BRANCH" --label "$QUAR_LABEL" --label p0 --title "$title" --body "$body" 2>/dev/null) \
    || { log "auto-quarantine: pushed $QUAR_BRANCH but could not open the PR (can GitHub Actions create PRs in this repo?)"; return 1; }
  echo "${url##*/}"
}

# quarantine_note <red7> <text>: the lane's one quarantine call on that red
# sha, logged and posted on the dev-red issue with QUAR_MARK.
quarantine_note() {
  log "auto-quarantine: $2"
  write gh issue comment "$BASE_RED" -R "$REPO" --body "Auto-quarantine: $2. $QUAR_MARK $1 -->" || log "could not comment on #$BASE_RED"
}

# quarantine_land <n>|<head>|<branch>|<add|remove>|<owners>: the lane's open
# quarantine PR lands on its own Linux check, once no batch holds the lane.
# THE protected-path exception, and all of it: the PR is the lane's bot's on
# QUAR_BRANCH with QUAR_LABEL (quarantine_sweep's filter) AND changes exactly
# QUAR_FILE; anything else is never landed. A red check on a removal means the
# fix didn't hold: the owners are reopened and the PR closed (the entries
# stay); on an add a human looks. A merge dev moved under is rebuilt.
quarantine_land() {
  local m head br kind owners files v o
  IFS='|' read -r m head br kind owners <<<"$1"
  files=$(gh api "repos/$REPO/pulls/$m/files" --paginate --jq '.[].filename' 2>/dev/null) || { log "auto-quarantine: could not read #$m's files; the next sweep looks again"; return 0; }
  if [[ "$files" != "$QUAR_FILE" ]]; then
    comment_once "$m" "Fast lane: this $QUAR_LABEL PR changes more than $QUAR_FILE ($(paste -sd, - <<<"$files" | sed 's/,/, /g')), so the lane will not land it; a human looks."; return 0
  fi
  v=$(check_verdict "$head")
  case "$v" in
    none)
      if has_comment "$m" "started a Linux check on head $head"; then log "auto-quarantine: #$m: its Linux check on $head started; waiting"; return 0; fi
      dispatch_linux "$br"
      comment_once "$m" "Fast lane: started a Linux check on head $head; this quarantine change lands once it passes." ;;
    running) log "auto-quarantine: #$m: its Linux check is running" ;;
    red*)
      if [[ "$kind" == remove ]]; then
        for o in $owners; do
          write gh issue reopen "${o#\#}" -R "$REPO" >/dev/null || log "could not reopen $o"
          write gh issue comment "${o#\#}" -R "$REPO" --body "Reopened: the test still fails without its quarantine entry (#$m's Linux check: ${v#red|}), so the fix didn't hold. The entry stays until this closes again." || log "could not comment on $o"
        done
        write gh pr close "$m" -R "$REPO" --comment "Fast lane: the Linux check is red (${v#red|}), so the test still fails; its owner is reopened and the entry stays." >/dev/null || log "could not close #$m"
      else
        comment_once "$m" "Fast lane: the Linux check on this quarantine change is red (${v#red|}), so a human looks."
      fi ;;
    green*)
      if (( HOLD )); then log "auto-quarantine: #$m waits for the batch in flight"; return 0; fi
      if ! scratch "$BASE_BRANCH" "$br"; then log "auto-quarantine: could not fetch $br; the next sweep looks again"; return 0; fi
      land "$m" "$head" "its own Linux check, ${v#green|}" && return 0
      [[ "$(gh pr view "$m" -R "$REPO" --json mergeable 2>/dev/null | jq -r '.mergeable // ""')" == CONFLICTING ]] || return 0
      rebuild_lane_pr "$m" "$head" "$br" "quarantine change" "it conflicts with $BASE_BRANCH" ;;
  esac
}

# has_comment <pr> <text>: a comment on the PR contains <text>.
has_comment() {
  gh api "repos/$REPO/issues/$1/comments" --paginate --jq '.[].body' 2>/dev/null | grep -qF -- "$2"
}

write() {  # run a mutating command unless --dry-run
  if (( DRY_RUN )); then log "dry-run, would: $*"; else "$@"; fi
}

comment_once() {  # comment unless an identical comment already exists
  local n="$1" body="$2"
  local existing
  existing=$(gh api "repos/$REPO/issues/$n/comments" --paginate --jq '.[].body')
  if grep -Fxq -- "$body" <<<"$existing"; then
    log "comment already present, not repeating"
    return
  fi
  write gh pr comment "$n" -R "$REPO" --body "$body"
}

evaluate() {
  local n="$1" tmp
  [[ "$n" =~ ^[0-9]+$ ]] || { echo "fast-lane: bad PR number: $n" >&2; return 1; }
  tmp=$(mktemp -d)
  local tries=0
  while :; do
    gh pr view "$n" -R "$REPO" --json number,state,isDraft,baseRefName,labels,author,body,additions,deletions,changedFiles,mergeable,mergeStateStatus,headRefOid,headRefName,isCrossRepository,statusCheckRollup,commits >"$tmp/pr.json"
    [[ "$(jq -r '.mergeable' "$tmp/pr.json")" == "UNKNOWN" ]] || break
    (( tries++ < UNKNOWN_RETRIES )) || break
    sleep 5
  done
  # A needs-rebase PR that GitHub reports mergeable again (a fixer's push, or dev
  # moving) loses the label here and is evaluated below; CONFLICTING keeps it,
  # UNKNOWN is left for a later sweep.
  if [[ "$(jq -r --arg l "$NEEDS_REBASE_LABEL" '([.labels[]?.name] | index($l) != null) and .mergeable == "MERGEABLE" and .mergeStateStatus != "DIRTY"' "$tmp/pr.json")" == true ]]; then
    log "PR #$n: mergeable again; dropping $NEEDS_REBASE_LABEL"
    write gh pr edit "$n" -R "$REPO" --remove-label "$NEEDS_REBASE_LABEL" || log "could not remove $NEEDS_REBASE_LABEL"
  fi
  # Attribution never blocks (land strips it); the author is asked once.
  if [[ "$(jq -r '.body // ""' "$tmp/pr.json")" != "$(jq -r '.body // ""' "$tmp/pr.json" | strip_attribution)" ]]; then
    comment_once "$n" "$ATTRIBUTION_ASK" || log "PR #$n: could not ask about its attribution lines"
  fi
  # Read check runs off the head commit itself, newest per name. The PR's rollup
  # misses CI dispatched on the branch, and keeps the PR-event run that GitHub
  # parks as action_required for bot pushes.
  local head
  head=$(jq -r '.headRefOid' "$tmp/pr.json")
  # A batch's culprit (NEEDS_FIX_LABEL) waits at the head the lane named; a new
  # head gets the label dropped and a fresh look.
  if jq -e --arg l "$NEEDS_FIX_LABEL" '[.labels[]?.name] | index($l) != null' "$tmp/pr.json" >/dev/null; then
    if has_comment "$n" "Fast lane: head $head fails the "; then
      log "PR #$n: $NEEDS_FIX_LABEL at head $head; waiting for a fix"; rm -rf "$tmp"; return
    fi
    write gh pr edit "$n" -R "$REPO" --remove-label "$NEEDS_FIX_LABEL" || log "could not remove $NEEDS_FIX_LABEL"
  fi
  if gh api "repos/$REPO/commits/$head/check-runs?per_page=100" --jq '.check_runs' >"$tmp/runs.json" 2>/dev/null; then
    jq '[ group_by(.name)[] | sort_by(.started_at // "") | last
          | select(.conclusion != "action_required")
          | { __typename: "CheckRun", name, status: (.status | ascii_upcase),
              conclusion: ((.conclusion // "") | ascii_upcase), workflowName: "" } ]' \
      "$tmp/runs.json" >"$tmp/checks.json"
    # Check runs carry no commit statuses; add Belt's review and the pre-screen from the head.
    gh api "repos/$REPO/commits/$head/status" --jq "[.statuses[] | select(.context == \"$BELT_REVIEW_CONTEXT\" or .context == \"$PRESCREEN_CONTEXT\")
      | {__typename: \"StatusContext\", context, state: (.state | ascii_upcase)}]" \
      >"$tmp/status.json" 2>/dev/null || echo '[]' >"$tmp/status.json"
    jq -s 'add' "$tmp/checks.json" "$tmp/status.json" >"$tmp/all.json" && mv "$tmp/all.json" "$tmp/checks.json"
  else
    jq '.statusCheckRollup // []' "$tmp/pr.json" >"$tmp/checks.json"
  fi
  # A rename counts under both names, so moving a protected file away is caught.
  # added.txt: the paths the PR adds, a rename's new name included (dup_logic).
  gh api "repos/$REPO/pulls/$n/files" --paginate \
    --jq '.[] | [.status, .filename, (.previous_filename // "")] | @tsv' >"$tmp/files.tsv"
  cut -f2,3 "$tmp/files.tsv" | tr '\t' '\n' | grep -v '^$' >"$tmp/files.txt" || true
  awk -F'\t' '$1 == "added" || $1 == "renamed" || $1 == "copied" { print $2 }' "$tmp/files.tsv" >"$tmp/added.txt"
  # The app audit is judged on its files at the merge base and the head (the
  # PR's own diff: a count dev lowered meanwhile isn't this PR's raise). An
  # API failure skips the PR this sweep rather than judging it blind.
  local audit=()
  if grep -qE "$AUDIT_RE" "$tmp/files.txt"; then
    local base_sha
    if ! base_sha=$(gh api "repos/$REPO/compare/$(jq -r .baseRefName "$tmp/pr.json")...$head" --jq .merge_base_commit.sha) \
        || ! audit_snapshot "$base_sha" "$tmp/before" || ! audit_snapshot "$head" "$tmp/after" \
        || ! audit_read_checks "$base_sha" "$head" "$tmp/before" "$tmp/after"; then
      log "PR #$n: could not read the app audit files; the next sweep looks again"; rm -rf "$tmp"; return
    fi
    audit=("$tmp/before" "$tmp/after")
  fi
  # Code brings the run its Mac-Check line names, if any, and the latest
  # build-only run on the head, a queued or running one first. A failed run
  # list skips the PR this sweep, so an API hiccup never dispatches a second
  # build for one head. Runs are listed by branch, not --commit: GitHub's
  # head_sha filter sometimes answers an empty list, which read as "no build"
  # and dispatched a new one that cancelled the queued one (#4441).
  local mac=() id fields=workflowName,status,conclusion,headSha,jobs,url
  if (( LANE_MAC_PER_PR )) && [[ -n "$(build_paths "$tmp/files.txt")" ]]; then
    echo '{}' >"$tmp/mac.json"
    id=$(mac_run_id "$(mac_check_url "$tmp/pr.json")")
    if [[ -n "$id" ]]; then
      gh run view "$id" -R "$REPO" --json "$fields" >"$tmp/mac.json" 2>/dev/null || echo '{}' >"$tmp/mac.json"
    fi
    if ! gh run list -R "$REPO" --workflow "$CI_FILE" --branch "$(jq -r '.headRefName // ""' "$tmp/pr.json")" --limit 20 \
        --json databaseId,displayTitle,status,conclusion,url,headSha,updatedAt \
        --jq "[.[] | select(.displayTitle == \"$BUILD_TITLE\" and .headSha == \"$head\")] | (map(select(.status != \"completed\"))[0] // .[0]) // {}" >"$tmp/build.json"; then
      log "PR #$n: could not list CI runs on the head; the next sweep looks again"; rm -rf "$tmp"; return
    fi
    (( ${#audit[@]} )) || audit=("" "")
    mac=("$tmp/mac.json" "$tmp/mac.json" "$tmp/build.json")
  fi

  echo "PR #$n:" >&2
  local decision kind rest
  (( ${#audit[@]} )) || audit=("" "")
  (( ${#mac[@]} )) || mac=("" "" "")
  decision=$(decide "$tmp/pr.json" "$tmp/files.txt" "$tmp/checks.json" "${audit[@]}" "${mac[@]}" "$tmp/added.txt")
  echo "decision: $decision"
  kind="${decision%%|*}"; rest="${decision#*|}"

  case "$kind" in
    skip|pending) ;;
    retarget)
      # mergeable goes UNKNOWN after the edit; the next sweep evaluates it on the new base.
      if write gh pr edit "$n" -R "$REPO" --base "$BASE_BRANCH"; then
        comment_once "$n" "Fast lane: retargeted from $rest to $BASE_BRANCH. Crew PRs merge into $BASE_BRANCH; $rest only takes $BASE_BRANCH heads whose full CI is green."
      else
        log "could not retarget to $BASE_BRANCH"
      fi
      ;;
    conflict)
      # The lane integrates: merge the base into the head with the merge
      # drivers and push. The re-sweep then sees the lane's merge commit as the
      # head with no check and starts its Linux run (linux-dispatch). A conflict
      # the drivers can't resolve goes to a fixer once per head, with the files.
      local branch out why
      branch=$(jq -r '.headRefName // ""' "$tmp/pr.json")
      if has_comment "$n" "could not integrate it at head $rest"; then
        log "conflict at head $rest already handed to a fixer"
      elif (( DRY_RUN )); then
        log "dry-run, would integrate $BASE_BRANCH into $branch at $rest"
      else
        gh auth setup-git >/dev/null 2>&1 || true
        out=$(integrate "$rest" "$branch"); why="${out#*|}"
        case "${out%%|*}" in
          integrated)
            MERGED_ANY=1  # re-sweep: the new head gets its Linux check now, not next run
            if jq -e --arg l "$NEEDS_REBASE_LABEL" '[.labels[]?.name] | index($l) != null' "$tmp/pr.json" >/dev/null; then
              write gh pr edit "$n" -R "$REPO" --remove-label "$NEEDS_REBASE_LABEL" || log "could not remove $NEEDS_REBASE_LABEL"
            fi
            comment_once "$n" "Fast lane: this PR conflicted with $BASE_BRANCH, so the lane merged origin/$BASE_BRANCH into $branch itself ($why) with the repo's merge drivers. Next it starts a Linux check on that head and merges once it passes; nothing to do on your side. If you push again, fetch first."
            ;;
          conflict)
            write gh label create "$NEEDS_REBASE_LABEL" -R "$REPO" --color d93f0b --force \
              --description "The lane could not merge dev into this PR; a fixer resolves the named files" >/dev/null 2>&1 || true
            write gh pr edit "$n" -R "$REPO" --add-label "$NEEDS_REBASE_LABEL" || log "could not add $NEEDS_REBASE_LABEL"
            comment_once "$n" "Fast lane: this PR conflicts with $BASE_BRANCH in $why, and the lane could not integrate it at head $rest (the merge drivers don't resolve these). A fixer takes it: merge origin/$BASE_BRANCH into $branch, resolve those files, rerun scripts/ci --changed, push, and move the Head: line. The lane then drops the $NEEDS_REBASE_LABEL label and merges."
            ;;
          *) log "integration failed ($why); the next sweep tries again" ;;
        esac
      fi
      ;;
    build-dispatch|linux-dispatch)
      # Authors can't dispatch (403, #1040), so the lane does, once per head:
      # the next sweep finds this run on the head and waits for it, then merges.
      local what="" branch url="" i flags=(-f build_only=true) title="$BUILD_TITLE" apps=all
      if [[ "$kind" == linux-dispatch ]]; then branch="$rest"; flags=(-f linux_only=true); title="$LINUX_TITLE"
      else IFS='|' read -r what branch apps <<<"$rest"; fi
      # A Linux check is started once per head: its comment is the record, read
      # fail-closed so an API hiccup never starts a second run.
      if [[ "$kind" == linux-dispatch ]]; then
        local seen
        if ! seen=$(gh api "repos/$REPO/issues/$n/comments" --paginate --jq '.[].body'); then
          log "PR #$n: could not read its comments; the next sweep looks again"; rm -rf "$tmp"; return
        fi
        if grep -qF -- "started a Linux check on head $head" <<<"$seen"; then
          log "PR #$n: Linux check on head $head already started; waiting for it"; rm -rf "$tmp"; return
        fi
      fi
      # A scoped build first; a branch whose ci.yml has no `app` input refuses
      # it, so a full build is the fallback (and the same retry covers a blip).
      if [[ -n "$apps" && "$apps" != all ]] && write gh workflow run "$CI_FILE" -R "$REPO" "${flags[@]}" -f app="$apps" --ref "$branch"; then
        :
      elif apps=all; ! write gh workflow run "$CI_FILE" -R "$REPO" "${flags[@]}" --ref "$branch"; then
        log "could not dispatch CI on $branch; the next sweep tries again"; rm -rf "$tmp"; return
      fi
      for (( i = 0; i <= RUN_LOOKUP_RETRIES; i++ )); do
        url=$(gh run list -R "$REPO" --workflow "$CI_FILE" --branch "$branch" --limit 20 --json url,displayTitle,headSha \
          --jq "[.[] | select(.displayTitle == \"$title\" and .headSha == \"$head\")][0].url // \"\"" 2>/dev/null || true)
        [[ -z "$url" && $i -lt $RUN_LOOKUP_RETRIES ]] || break
        sleep 5
      done
      [[ -n "$url" ]] || url="https://github.com/$REPO/actions/workflows/$CI_FILE?query=branch%3A$branch"
      if [[ "$kind" == linux-dispatch ]]; then
        comment_once "$n" "Fast lane: nothing on head $head proves it yet (no CI check, no Fast-Check marker for it), so the lane started a Linux check on head $head: $url. A later sweep merges this PR once it passes ($( if (( LANE_VERIFY_AFTER )); then echo "a code PR also needs $PRESCREEN_CONTEXT on this head"; elif (( LANE_MAC_PER_PR )); then echo "a code PR gets its macOS build on this head first"; else echo "a code PR's macOS gate runs with its batch"; fi ))."
      else
        comment_once "$n" "Fast lane: this PR changes code ($what), so its head $head must build on macOS first. The lane dispatched a macOS build on $branch ($( [[ "$apps" == all ]] && echo "every app" || echo "apps: $apps" )): $url. A later sweep merges this PR once it compiles; a new push gets a new build."
      fi
      ;;
    build-gate)
      # The label stays: a push gets a new build on the new head, and a later sweep merges it once it compiles.
      comment_once "$n" "Fast lane: waiting for a macOS build. This PR $rest."
      ;;
    not-eligible)
      write gh pr edit "$n" -R "$REPO" --remove-label "$LABEL" || log "could not remove label"
      comment_once "$n" "Fast lane: not eligible. ${rest//;/; }. This PR now needs normal captain review."
      ;;
    red)
      if [[ "$rest" == "review failed" ]]; then
        comment_once "$n" "Fast lane: waiting, Belt's review failed ($BELT_REVIEW_CONTEXT is failure on the head)."
      else
        comment_once "$n" "Fast lane: waiting, CI is red ($rest)"
      fi
      ;;
    eligible)
      # settle_ready lands it, or batches it with the pass's other eligible PRs:
      # rank|n|head|branch|apps|ready since|proof|hit. rank orders p0, beta, the
      # rest; apps is what it needs on macOS (mac_scope; empty: nothing); hit is
      # 1 when it touches the red module (BASE_RED_SCOPE), so a red dev holds it.
      # ponytail: "ready since" is the head commit's date (no state is kept),
      # unreadable counts as old: a smaller batch, never a stuck one.
      local apps="" rank since hit=0
      apps=$(mac_scope "$tmp/files.txt")
      rank=$(jq -r '[.labels[]?.name] as $l | if ($l | index("p0")) then 0 elif ($l | index("beta")) then 1 else 2 end' "$tmp/pr.json")
      since=$(jq -r '(.commits // [] | last // {} | .committedDate // "") as $d | if $d == "" then 0 else ($d | try fromdateiso8601 catch 0) end' "$tmp/pr.json" 2>/dev/null || echo 0)
      [[ -z "$BASE_RED_SCOPE" ]] || ! grep -qE -- "$BASE_RED_SCOPE" "$tmp/files.txt" || hit=1
      READY+=("$rank|$n|$head|$(jq -r '.headRefName // ""' "$tmp/pr.json")|$apps|$since|${rest#*|*|}|$hit")
      ;;
  esac
  rm -rf "$tmp"
}

# land <n> <head> <proof>: squash-merges PR <n> at <head> into BASE_BRANCH with
# the bookkeeping: attribution stripped from the squash message, a lead's
# closing keywords before feature-lead issues turned into Refs, linked issues
# closed, labels, one comment. Non-zero when it did not merge (the head moved,
# or the base changed under it): the next sweep looks again.
land() {
  local n="$1" head="$2" proof="$3" tmp lines files
  tmp=$(mktemp -d)
  if ! gh pr view "$n" -R "$REPO" --json labels,additions,deletions,changedFiles >"$tmp/pr.json" 2>/dev/null \
      || ! gh api "repos/$REPO/pulls/$n/files" --paginate --jq '.[] | .filename' >"$tmp/files.txt" 2>/dev/null; then
    log "PR #$n: could not read it before the merge; the next sweep looks again"; rm -rf "$tmp"; return 1
  fi
  lines=$(jq -r '(.additions // 0) + (.deletions // 0)' "$tmp/pr.json")
  files=$(jq -r '.changedFiles // 0' "$tmp/pr.json")
  # Squash message = PR title + body, minus any AI attribution lines.
  local title body
  title=$(gh pr view "$n" -R "$REPO" --json title --jq .title)
  body=$(gh pr view "$n" -R "$REPO" --json body --jq .body | strip_attribution)
  # A lead's closing keyword before a feature-lead issue becomes Refs, in the body and so
  # in the squash message. An issue whose labels can't be read keeps its keyword.
  local lead=0
  if grep -qE "$LEAD_RE" <<<"$body"; then
    lead=1
    lead_issues "$body"
    body=$(lead_refs "$LEAD_FEATURES" <<<"$body")
    [[ -z "$LEAD_UNREAD" ]] || comment_once "$n" "Fast lane: could not read the labels of $LEAD_UNREAD, so the closing keyword before it stays and the lane closes none of them. A PR must never close a $FEATURE_ISSUE_LABEL issue: if one is, reopen it after the merge."
  fi
  # Cloud sessions append a "Generated by Claude Code" footer to the PR body; drop it there too.
  write gh pr edit "$n" -R "$REPO" --body "$body" || log "could not strip attribution from the PR body"
  # A failed merge (head moved, or the base changed under it) is left for the next sweep.
  if ! write gh pr merge "$n" -R "$REPO" --squash --delete-branch=false --match-head-commit "$head" \
      --subject "$title (#$n)" --body "$body"; then
    log "merge failed; the next sweep looks again"; rm -rf "$tmp"; return 1
  fi
  MERGED_ANY=1
  MERGED_RUN=$((MERGED_RUN + 1))
  # GITHUB_TOKEN merges fire no workflows; a finished feature or a UI change gets a CI run.
  if jq -e --arg l "$FEATURE_LABEL" '[.labels[]?.name] | index($l) != null' "$tmp/pr.json" >/dev/null; then
    DISPATCH_FEATURE=1
  fi
  if grep -qE "$UI_RE" "$tmp/files.txt"; then DISPATCH_UI=1; fi
  if jq -e --arg l "$REVERT_LABEL" '[.labels[]?.name] | index($l) != null' "$tmp/pr.json" >/dev/null; then DISPATCH_REVERT=1; fi
  # GitHub does not auto-close linked issues when GITHUB_TOKEN merges, so close them here.
  # For a lead's PR only issues known not to be feature-lead: GitHub may still list one
  # whose keyword lead_refs just rewrote, or one linked by hand.
  local issue
  for issue in $(gh pr view "$n" -R "$REPO" --json closingIssuesReferences --jq '.closingIssuesReferences[].number'); do
    if (( lead )) && ! { issue_is_feature "$REPO#$issue" && [[ "$FEATURE" == n ]]; }; then
      log "not closing #$issue: a $FEATURE_ISSUE_LABEL issue, or its labels can't be read"; continue
    fi
    write gh issue close "$issue" -R "$REPO" --reason completed --comment "Done in #$n (fast lane)." || log "could not close #$issue"
    write gh issue edit "$issue" -R "$REPO" --remove-label in-progress || true
  done
  write gh pr edit "$n" -R "$REPO" --add-label "$MERGED_LABEL" || log "could not add $MERGED_LABEL label"
  if jq -e --arg l "$NEEDS_REBASE_LABEL" '[.labels[]?.name] | index($l) != null' "$tmp/pr.json" >/dev/null; then
    write gh pr edit "$n" -R "$REPO" --remove-label "$NEEDS_REBASE_LABEL" || true
  fi
  comment_once "$n" "Fast lane: merged into $BASE_BRANCH ($lines lines, $files files, $proof)."
  rm -rf "$tmp"
}

# dispatch_reason <feature 0|1> <ui 0|1> <merged PRs since the last CI run, or
# empty when unknown> [<revert 0|1>]: why CI on the base should run now,
# nothing when it shouldn't. A landed lane revert needs the run that closes
# dev-red. Pure, so the self-tests can call it.
dispatch_reason() {
  if (( ${4:-0} )); then echo "merged a revert of a red $BASE_BRANCH's culprit"; return; fi
  if (( $1 )); then echo "merged a $FEATURE_LABEL PR"; return; fi
  if (( $2 )); then echo "merged a UI change"; return; fi
  if [[ "$3" =~ ^[0-9]+$ ]] && (( $3 >= DISPATCH_EVERY )); then echo "$3 merged PRs since the last CI run"; fi
}

# merges_since_ci: the merged PRs (squash subjects ending in `(#n)`) on the base
# since the head of its latest CI run, any status. A base with no CI run counts
# as DISPATCH_EVERY; an API failure prints nothing, so the count rule waits.
merges_since_ci() {
  local sha
  sha=$(gh run list -R "$REPO" --workflow "$CI_FILE" --branch "$BASE_BRANCH" --limit 1 --json headSha --jq '.[0].headSha // ""') || return 0
  if [[ -z "$sha" ]]; then echo "$DISPATCH_EVERY"; return; fi
  gh api "repos/$REPO/compare/$sha...$BASE_BRANCH" \
    --jq '[.commits[] | select(.commit.message | split("\n")[0] | test("\\(#[0-9]+\\)$"))] | length' || true
}

# Every open PR, one call: the sweep's labelled PRs and the Belt leads to label both come from it.
open_list() {
  gh pr list -R "$REPO" --state open --limit 1000 --json number,labels,author,baseRefName,body,headRefName,headRefOid
}

# lane_prs <open_list json>: open fast-lane PRs on any base, oldest first (decide retargets main and skips the rest).
lane_prs() {
  jq -r --arg l "$LABEL" '.[] | select(any(.labels[]?; .name == $l)) | .number' <<<"$1" | sort -n
}

# belt_unlabelled <open_list json>: the crew's PRs into BASE_BRANCH whose body has a
# `Belt-Lead:` line, with no LABEL and no opt-out label. Belt leads often forget the label.
belt_unlabelled() {
  jq -r --arg l "$LABEL" --arg base "$BASE_BRANCH" --arg authors "$FAST_LANE_AUTHORS" --arg out "$OPT_OUT_LABELS" '
    ([$l] + ($out | split(" "))) as $skip
    | .[] | select(.baseRefName == $base
        and (.author.login as $a | ($authors | split(" ")) | index($a) != null)
        and ((.body // "") | test("(^|\n)Belt-Lead:"))
        and (all(.labels[]?; .name as $n | ($skip | index($n)) == null)))
    | .number' <<<"$1" | sort -n
}

# belt_label <open_list json>: label each belt_unlabelled PR; the sweep then evaluates it as usual.
belt_label() {
  local n
  for n in $(belt_unlabelled "$1"); do
    log "PR #$n: Belt-Lead and no $LABEL label; labelling"
    write gh pr edit "$n" -R "$REPO" --add-label "$LABEL" || { log "could not add $LABEL to #$n"; continue; }
    write gh pr comment "$n" -R "$REPO" --body "Fast lane: labelled because the PR carries Belt-Lead." || true
  done
}

open_prs() { lane_prs "$(open_list)"; }

main() {
  local prs=() bisect="" bisect_issue="" bisect_branch="$BASE_BRANCH"
  while (( $# )); do
    case "$1" in
      --dry-run) DRY_RUN=1 ;;
      --bisect) bisect="${2:-}"; bisect_issue="${3:-}"; [[ -z "${4:-}" || "${4:-}" == --* ]] || { bisect_branch="$4"; shift; }; shift 2 ;;
      -h|--help) sed -n '2,/^set -euo/p' "$0" | sed '$d'; return 0 ;;
      *) prs+=("$1") ;;
    esac
    shift
  done
  (( DRY_RUN )) || gh auth setup-git >/dev/null 2>&1 || true
  if [[ -n "$bisect" ]]; then
    [[ "$bisect" == *..* && "$bisect_issue" =~ ^[0-9]+$ ]] || { echo "fast-lane: --bisect <good>..<bad> <issue> [<branch>]" >&2; return 1; }
    red_bisect "$bisect_issue" "${bisect%%..*}" "${bisect##*..}" "$bisect_branch"; return 0
  fi
  # A red BASE_BRANCH gets its culprit found while the lane keeps merging.
  red_sweep
  # A batch a run left behind comes first: its verdict lands or bisects it, and
  # while it is still running nothing else merges (settle_ready holds). The
  # open PRs are listed after it, so what it landed isn't looked at again.
  local br
  while read -r _ br; do
    [[ "$br" =~ ^${BATCH_PREFIX}[0-9]+$ ]] || continue  # probes (<batch>-<i>) belong to their batch
    batch_resume "$br"
    batch_held || SLOT_FREED=1
  done < <(batch_branches)
  # With LANE_VERIFY_AFTER=1 a red dev gets its culprit reverted; after the
  # batches, so a revert waits for one holding the lane (HOLD).
  revert_sweep
  # A red the revert left standing gets its failing tests quarantined; expired and closed entries are swept every time.
  quarantine_sweep
  local explicit=${#prs[@]}
  if (( explicit == 0 )); then
    local list; list=$(open_list)
    belt_label "$list"
    while read -r n; do [[ -n "$n" ]] && prs+=("$n"); done < <({ lane_prs "$list"; belt_unlabelled "$list"; } | sort -un)
  fi
  # A sweep that only landed a revert still goes on to dispatch CI on dev.
  (( ${#prs[@]} )) || { (( HOLD || MERGED_RUN )) || echo "fast-lane: no open $LABEL PRs" >&2; (( MERGED_RUN )) || return 0; }
  local n pass
  for n in ${prs[@]+"${prs[@]}"}; do evaluate "$n"; done
  settle_ready
  # A merge changes every other PR's mergeable state, and GitHub reports
  # UNKNOWN until it recomputes. Sweep again after any merge (or a lane
  # integration, whose new head needs its Linux check), until a pass changes
  # nothing, so a PR that settles late still merges in this run.
  for (( pass = 0; MERGED_ANY && pass < 5; pass++ )); do
    MERGED_ANY=0
    while read -r n; do [[ -n "$n" ]] && evaluate "$n"; done < <(open_prs)
    settle_ready
  done
  # At most one dispatch per run, and only after a run that merged something.
  (( MERGED_RUN )) || return 0
  local since="" why
  (( DISPATCH_FEATURE || DISPATCH_UI || DISPATCH_REVERT )) || since=$(merges_since_ci)
  why=$(dispatch_reason "$DISPATCH_FEATURE" "$DISPATCH_UI" "$since" "$DISPATCH_REVERT")
  if [[ -n "$why" ]]; then
    log "dispatching CI on $BASE_BRANCH: $why"
    write gh workflow run "$CI_FILE" -R "$REPO" --ref "$BASE_BRANCH" || log "could not dispatch CI on $BASE_BRANCH"
  fi
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then main "$@"; fi
