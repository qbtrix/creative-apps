#!/usr/bin/env bash
# scripts/fast-lane.sh: merge small, checked crew PRs into BASE_BRANCH (dev)
# without waiting for captain review. The captain batch-reviews merged
# fast-lane PRs later and reverts anything wrong. Rules for agents: CLAUDE.md,
# "Fast lane". Run by .github/workflows/fast-lane.yml with this file from the
# trusted main branch; it reads PR metadata and file contents through the
# GitHub API and never checks out or runs PR code.
#
# Until beta only compile and Model tests block (captain, 2026-10-16). The
# proof a head passed the gate is Linux-side: the worker's `Fast-Check: pass`
# line followed by `Head: <full head sha>` in the body, or a passing CI
# `Linux` check on the head. CI's `macOS` and `macOS (<app>)` jobs are
# report-only, so the lane ignores them (REPORT_ONLY_RE): a red or running
# one never holds a PR. A PR that changes code (BUILD_RE) also needs a
# passing build-only CI run on its head (build_gate), which the lane
# dispatches itself, once per head (workers get 403).
#
# Eligibility (all must hold): open, not draft, label `fast-lane`, base
# BASE_BRANCH, author in FAST_LANE_AUTHORS, size within MAX_LINES/MAX_FILES
# (unless every path is under DOCS_RE), no changed or renamed-away path under
# PROTECTED (CLAUDE.md's "Never edit" list), no looser app audit
# (audit_loosens), no added app-local copy of a canonical concept without an
# `Allow-Dup:` line (dup_logic), MERGEABLE, no red or running check on the head, the proof
# above, and for a Belt PR (`Belt-Run:` or `Belt-Test:` line) Belt's
# `belt/review` status while REQUIRE_BELT_REVIEW=1. A PR based on main is
# retargeted. A PR that is behind the base merges as it is. One that conflicts
# is integrated by the lane (integrate): a scratch clone merges the base into
# the PR head with the repo's merge drivers (scripts/install-merge-drivers and
# scripts/merge-json from this checkout, i.e. main, never the PR's), pushes the
# merge commit to the PR branch with a lease on the head it read, and the
# re-sweep, seeing a head whose last commit is that merge (LANE_MERGE_SUBJECT)
# with no check on it, dispatches a Linux-only CI run (linux-dispatch; ci.yml's
# `linux_only`) and merges on its pass like any CI-proven head. Any other
# unproven head with no check at all gets the same run, once per head (its
# comment is the record), unless the PR comes from a fork. A conflict the
# drivers can't resolve gets one comment naming the files and the
# NEEDS_REBASE_LABEL label for a fixer; the label goes when a later head
# integrates or merges.
#
# Every run sweeps all open fast-lane PRs, oldest first. Eligible PRs don't
# merge one by one: with one ready PR the lane squash-merges it (land); with two
# or more it builds a batch (batch_start): BASE_BRANCH plus every ready PR
# merged in order on a scratch branch `lane/batch-<id>` (BATCH_PREFIX, merge
# drivers on, one merge commit per PR whose subject names the PR and its head),
# runs ONE Linux-only CI run on it and, when green, lands every PR in that
# order (squash, head matched). A red batch is bisected by prefix on the same
# branch (batch_resume): `lane/batch-<id>-<i>` points at the chain after i PRs
# and gets its own Linux run, until PR hi is the first that turns the chain
# red: PRs before it land, PR hi gets NEEDS_FIX_LABEL and one comment naming
# the run, and the PRs after it wait for the next batch. The branch is the
# whole state, so a later sweep resumes a batch a run left behind; while one is
# in flight nothing else merges (one batch at a time, arrivals wait). A PR
# whose head moved or that conflicts with an earlier PR in the batch waits for
# the next sweep. A red base (the chain before any PR) means BASE_BRANCH itself
# is red: the batch lands on the PRs' own proof, as before batches, so a fix
# can get through.
#
# A red BASE_BRANCH gets its culprit found the same way (red_sweep): while a
# `dev-red` issue for a red Linux job is open, each sweep bisects main..<red sha>
# by first-parent commit with `ci/bisect-<red7>-<i>` probe branches and
# Linux-only runs (at most MAX_BISECT per red), testing red-triage's confident
# guess (a `Likely cause: #N ... (Clef p)` comment, p >= CLEF_MIN) first, and
# posts the first red commit on the dev-red issue and on the owning
# feature-lead issue (the PR's `Feature:` line), then deletes its probes.
# `--bisect <good>..<bad> <issue> [<branch>]` runs one such bisect by hand.
#
# A lead's PR (a `Feature:` body line) never closes a `feature-lead` issue
# (lead_refs). After its merges the lane dispatches CI on BASE_BRANCH at most
# once per run (dispatch_reason): a FEATURE_LABEL PR, a UI_RE change, or
# DISPATCH_EVERY merged PRs since the last CI run. Promotion of main is
# ci.yml's job.
#
# `decide` is the pure decision function (no network): it reads a PR JSON
# file, a file-list file, a check-rollup JSON file, optional audit_snapshot
# dirs (merge base, head), the Mac-Check run and the latest build-only run on
# the head, and the PR's added files, logs each rule to stderr and prints one line to stdout:
#   skip|<why>  retarget|<from base>  not-eligible|<reasons>  red|<checks>
#   conflict|<head sha>  pending|<why>  build-dispatch|<code paths>|<head branch>
#   linux-dispatch|<head branch>
#   build-gate|<what to do>  eligible|<lines>|<files>|<proof>
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
MERGED_LABEL="fast-lane-merged"
FEATURE_LABEL="feature-done"  # merging one dispatches full CI on BASE_BRANCH
CI_WORKFLOWS=("CI")
# CI job names, so CI runs started by workflow_dispatch (no PR association) still count.
CI_CHECKS=("Linux")
# CI's report-only jobs (ci.yml): never red, pending or proof here.
REPORT_ONLY_RE='^macOS( \(.*\))?$'
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
# when it integrates a PR, so a PR can't turn one on for itself. docs/c4/model.json and each app's waves.md are
# generated on dev (.github/workflows/generated.yml), so PRs never edit them.
# UITests/quarantine.json skips failing journeys (scripts/quarantine), so only
# the supervisor quarantines; Tests/perf-suites.txt takes tests out of the
# gate (scripts/test-scope), so only the supervisor lists them.
PROTECTED=(Package.swift Package.resolved .github/ .claude/ scripts/ .gitattributes CLAUDE.md AGENTS.md LICENSE
  docs/c4/model.json 'docs/blueprints/*/features/waves.md' UITests/quarantine.json Tests/perf-suites.txt)
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
# Canonical first (docs/factory/lead.md rule 20): a PR that adds a Swift file
# under Sources/<X>Model or Sources/<X>App named for a canonical concept
# (Tests/canonical-concepts.txt) needs an `Allow-Dup: <concept> <reason>` body
# line. The lane runs main's scripts/check-dup-logic --paths on the PR's added
# and renamed-to files: names only, since it never reads PR code; the primary
# type rule and the grandfathered baseline are scripts/ci's (the head's proof).
DUP_REASON="adds app-local logic for a canonical concept (use the SuiteModel module, or add \`Allow-Dup: <concept> <reason>\` to the body)"

# A supervisor's `Mac-Check: <run url>` line names a CI run whose green
# macOS job built every app, which also proves a code PR builds (build_gate).
MAC_CHECK_LINE="Mac-Check:"
MAC_JOB="macOS"
# What a compiler reads: Swift under Sources/, Tests/ and UITests/, plus
# project.yml and Package.swift (protected anyway). A PR changing any of it,
# shared shell files such as SuiteWindow.swift included, merges only once a build-only CI run (ci.yml's
# `build_only` input: every SwiftPM target with its tests, then the journey
# bundles; nothing runs) compiled its head; the lane dispatches it, once per
# head. Linux scripts/ci never builds the app targets (lesson 114: dev stopped
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
MAX_BATCH=8          # PRs per batch; a bisect then needs at most 4 probes
NEEDS_FIX_LABEL="needs-fix"
# After starting a Linux run on a batch, wait this long (seconds, polling
# every BATCH_POLL) for its verdict in the same run before leaving the rest to
# the next sweep. Tests set it to 0.
BATCH_WAIT="${FAST_LANE_BATCH_WAIT:-420}"
BATCH_POLL="${FAST_LANE_BATCH_POLL:-60}"
READY=()   # eligible PRs this pass, n|head|branch|proof (settle_ready lands or batches them)
HOLD=0     # a batch is in flight: eligible PRs wait for the next sweep
SCRATCH="" # the run's scratch clone of REMOTE (scratch)
# Culprit by bisect on a red BASE_BRANCH (red_sweep, red_bisect).
RED_LABEL="dev-red"
BISECT_PREFIX="ci/bisect-"  # ci/bisect-<red7>-<i>: the i-th first-parent commit past the good one
MAX_BISECT="${FAST_LANE_MAX_BISECT:-8}"  # Linux runs per red, probes counted
CLEF_MIN="0.80"             # a red-triage culprit guess at or above this is probed first
BISECT_MARK="<!-- lane-bisect"  # the culprit comment's marker: "<!-- lane-bisect <red7> -->"
# Where integrate fetches and pushes; tests point it at a local bare repo.
REMOTE="${FAST_LANE_REMOTE:-https://github.com/${GH_REPO:-qbtrix/creative-apps}.git}"
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# After dispatching, look this many times, 5s apart, for the new run's URL to comment.
RUN_LOOKUP_RETRIES="${FAST_LANE_RUN_LOOKUP_RETRIES:-6}"

# The worker's proof that scripts/ci passed on the head: this line, then `Head: <sha>`.
MARKER_LINE="Fast-Check: pass"
HEAD_LINE="Head: "

REPO="${GH_REPO:-qbtrix/creative-apps}"
DRY_RUN=0
MERGED_ANY=0
DISPATCH_FEATURE=0  # merged a FEATURE_LABEL PR this run
DISPATCH_UI=0       # merged a PR touching UI_RE this run
MERGED_RUN=0        # PRs merged this run
# A merged PR touching these paths needs the macOS job (Belt v2 lessons 49, 73).
UI_RE='^(Sources/[A-Za-z0-9_]+App/|Sources/SuiteUI/|Tests/App|UITests/)'
DISPATCH_EVERY=10   # dispatch once the base holds this many merged PRs since the last CI run
# GitHub recomputes `mergeable` lazily after any push to the base branch and
# reports UNKNOWN meanwhile. Re-read the PR this many times, 5s apart, before
# calling it not ready; otherwise a PR checked right after another merge stalls.
UNKNOWN_RETRIES="${FAST_LANE_UNKNOWN_RETRIES:-8}"

# Drops AI attribution lines (co-author trailers, session links, "Generated with" footers).
strip_attribution() {
  grep -v -i -E '^[[:space:]]*(co-authored-by:.*(claude|anthropic)|claude-session:|_?generated (with|by) \[?claude)' || true
}

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

# build_gate <pr.json> <files.txt> <mac-check run.json> <build run.json>:
# nothing when the PR touches no BUILD_RE code, else one line:
#   ok|<proof>  dispatch|<paths>|<branch>  wait|<url>  refuse|<what to do>
# A green Mac-Check run on the head (it builds every app) counts; otherwise
# the latest build-only run on the head ({} when none: dispatch one).
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
    echo "dispatch|$paths|$branch"; return
  fi
  st=$(jq -r '(.status // "" | ascii_downcase) + " " + (.conclusion // "" | ascii_downcase)' <<<"$run")
  case "$st" in
    "completed success") echo "ok|$BUILD_JOB $url" ;;
    completed*) echo "refuse|changes code ($paths), and its head $head doesn't build on macOS: $url (${st#completed }). Fix it and push; the lane builds the new head on macOS again" ;;
    *) echo "wait|$url" ;;
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

# decide <pr.json> <files.txt> <checks.json> [<audit before dir> <audit after dir>
#   [<mac-check run.json> <unused> [<build run.json> [<added.txt>]]]]
# (pass "" "" for the audit dirs when the PR doesn't touch the audit; the
# seventh argument is ignored, a slot kept so callers didn't shift; added.txt
# lists the PR's added and renamed-to paths, "" or missing skips dup_logic)
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

  # A code PR's macOS build check is build_gate's to judge, so it leaves the
  # red and running lists below.
  local mac macdrop=""
  mac=$(build_gate "$pr" "$files" "${6:-}" "${8:-}")
  [[ -z "$mac" ]] || macdrop="$BUILD_JOB"

  # Drop our own check, CI's report-only macOS jobs, Belt's review and
  # Copilot review checks, then classify the rest.
  local ci_json summary
  ci_json=$(printf '%s\n' "${CI_WORKFLOWS[@]}" "${CI_CHECKS[@]}" | jq -R . | jq -s .)
  summary=$(jq -c --arg self "$SELF_WORKFLOW" --arg selfcheck "$SELF_CHECK" \
      --arg review "$BELT_REVIEW_CONTEXT" --argjson ci "$ci_json" --arg macdrop "$macdrop" \
      --arg report "$REPORT_ONLY_RE" '
    [ .[]
      | select((.workflowName // "") != $self and (.name // "") != $selfcheck)
      | select($macdrop == "" or (.name // "") != $macdrop)
      | select((.name // "") | test($report) | not)
      | select((.context // .name // "") != $review)
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

# dispatch_linux <branch>: ci.yml's Linux job alone on <branch>, once per
# batch_resume call (DISPATCHED): a run takes seconds to show up, and a second
# dispatch on the same ref would cancel the first (ci.yml's concurrency).
DISPATCHED=""
dispatch_linux() {
  case "$DISPATCHED" in *" $1 "*) log "Linux check on $1 just started; waiting for it to show up"; return 0 ;; esac
  DISPATCHED+=" $1 "
  write gh workflow run "$CI_FILE" -R "$REPO" -f linux_only=true --ref "$1" || log "could not dispatch the Linux check on $1"
}

# settle_ready: what the pass found eligible (READY: n|head|branch|proof). One
# PR lands as before; two or more become a batch; while a batch is in flight
# they all wait.
settle_ready() {
  local items=("${READY[@]+"${READY[@]}"}") n head branch proof
  READY=()
  (( ${#items[@]} )) || return 0
  if (( HOLD )); then log "a batch is in flight: ${#items[@]} ready PR(s) wait for the next sweep"; return 0; fi
  if (( ${#items[@]} == 1 )); then
    IFS='|' read -r n head branch proof <<<"${items[0]}"
    land "$n" "$head" "$proof" || true
    return 0
  fi
  batch_start "${items[@]}"
}

# batch_start <n|head|branch|proof>...: BASE_BRANCH plus the ready
# PRs in order on a scratch branch, pushed as lane/batch-<id> with one Linux run
# started, then batch_resume on it. A PR whose branch can't be fetched or moved
# past its head, or that conflicts with an earlier PR in the batch, waits for
# the next sweep. Fewer than two PRs left makes no batch: one lands as before.
batch_start() {
  local items=("$@") it n head branch merged=() d id br
  if (( DRY_RUN )); then log "dry-run, would batch ${#items[@]} PRs: $(printf '#%s ' "${items[@]%%|*}")"; return 0; fi
  if ! scratch "$BASE_BRANCH"; then log "batch: could not fetch $BASE_BRANCH from $REMOTE; the ready PRs wait for the next sweep"; return 0; fi
  d="$SCRATCH"
  if ! git -C "$d" checkout -q -B batch "origin/$BASE_BRANCH" 2>/dev/null || ! bash "$HERE/install-merge-drivers" "$d" >/dev/null 2>&1; then
    log "batch: could not check out $BASE_BRANCH with the merge drivers; the ready PRs wait"; return 0
  fi
  for it in "${items[@]}"; do
    (( ${#merged[@]} < MAX_BATCH )) || { log "batch: full at $MAX_BATCH PRs; the rest wait"; break; }
    IFS='|' read -r n head branch _ <<<"$it"
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
  if (( ${#merged[@]} < 2 )); then
    log "batch: ${#merged[@]} PR(s) could join; no batch"
    (( ${#merged[@]} == 0 )) || { READY=("${merged[0]}"); settle_ready; }
    return 0
  fi
  id=$(date -u +%Y%m%d%H%M%S); br="${BATCH_PREFIX}$id"
  if ! git -C "$d" push -q origin "HEAD:refs/heads/$br" 2>/dev/null; then log "batch: could not push $br; the ready PRs wait"; return 0; fi
  log "batch $br: ${#merged[@]} PRs ($(printf '#%s ' "${merged[@]%%|*}")), one Linux check"
  batch_resume "$br"
  [[ "$BATCH_STATE" != waiting ]] || HOLD=1
}

# batch_resume <branch>: reads the batch chain (BASE_BRANCH, then one merge
# commit per PR) and the Linux verdicts on its tip and probes, acts, and sets
# BATCH_STATE to done (the branch is gone) or waiting (a run is still going;
# nothing else merges meanwhile). Red tip: a prefix bisect with lo = the
# longest green prefix, hi = the shortest red one; the probe is their midpoint;
# hi = lo + 1 names the culprit. Probe 0 is the base alone and is only asked
# for when PR 1 is the suspect: a red base means BASE_BRANCH is red, and the
# batch lands on the PRs' own proof so a fix can get through.
BATCH_STATE=""
batch_resume() {
  local br="$1" d k i sha v lo hi mid url waited=0 line probes
  local chain=() verd=()
  DISPATCHED=""; BATCH_STATE=waiting
  if ! scratch "$BASE_BRANCH" "$br"; then log "batch $br: could not fetch it; the next sweep tries again"; return; fi
  d="$SCRATCH"
  while read -r sha line; do
    [[ "$line" =~ $BATCH_SUBJECT_RE ]] || continue
    chain+=("$sha|${BASH_REMATCH[1]}|${BASH_REMATCH[2]}")
  done < <(git -C "$d" log --first-parent --reverse --format='%H %s' "origin/$BASE_BRANCH..origin/$br" 2>/dev/null)
  k=${#chain[@]}
  if (( k == 0 )); then log "batch $br: nothing left to land; dropping it"; batch_drop "$br"; BATCH_STATE=done; return; fi
  chain=("$(git -C "$d" rev-parse "origin/$br~$k")||" "${chain[@]}")  # [0] = the base
  while :; do
    for (( i = 0; i <= k; i++ )); do verd[i]=""; done
    verd[k]=$(check_verdict "${chain[k]%%|*}")
    probes=$(batch_branches | grep -E " ${br//./\\.}-[0-9]+\$" || true)
    while read -r sha line; do
      [[ -n "$line" ]] || continue
      i="${line##*-}"
      (( i >= 0 && i < k )) && [[ "${chain[i]%%|*}" == "$sha" ]] || continue
      verd[i]=$(check_verdict "$sha")
    done <<<"$probes"
    v="${verd[k]}"
    if (( DRY_RUN )); then log "dry-run: batch $br ($k PRs) tip is $v; probes: $(printf '%s ' "${verd[@]}")"; return; fi
    case "$v" in
      none) log "batch $br: no Linux run on its tip; starting one"; dispatch_linux "$br" ;;
      running) log "batch $br: Linux check running" ;;
      green*)
        batch_land "$br" "$k" "batch of $k PRs checked together on Linux: ${v#green|}" "${chain[@]}"
        BATCH_STATE=done; return ;;
      red*)
        lo=-1; hi=$k
        case "${verd[0]}" in
          red*)
            log "batch $br: $BASE_BRANCH itself is red (${verd[0]#red|}); landing on the PRs' own proof"
            batch_land "$br" "$k" "$BASE_BRANCH was red on its own (${verd[0]#red|}), so this batch landed on each PR's own proof" "${chain[@]}"
            BATCH_STATE=done; return ;;
          green*) lo=0 ;;
        esac
        for (( i = 1; i < k; i++ )); do
          case "${verd[i]}" in green*) lo=$i ;; red*) (( i < hi )) && hi=$i ;; esac
        done
        if (( lo >= 0 && hi == lo + 1 )); then
          batch_culprit "$br" "$lo" "$hi" "${verd[hi]#red|}" "${chain[@]}"
          BATCH_STATE=done; return
        elif (( lo == -1 && hi == 1 )); then
          batch_probe "$br" 0 "${chain[0]%%|*}" "${verd[0]}"
        else
          mid=$(( ( (lo < 0 ? 0 : lo) + hi ) / 2 ))
          batch_probe "$br" "$mid" "${chain[mid]%%|*}" "${verd[mid]}"
        fi ;;
    esac
    if (( waited >= BATCH_WAIT )); then return; fi
    sleep "$BATCH_POLL"; waited=$(( waited + BATCH_POLL ))
  done
}

# batch_probe <branch> <i> <sha> <verdict>: makes sure the chain after i PRs
# has a Linux run: pushes lane/batch-<id>-<i> at <sha> and dispatches when
# there is none; says so when one is running.
batch_probe() {
  local br="$1" i="$2" sha="$3" v="$4"
  case "$v" in
    running) log "batch $br: probe $i running" ;;
    "")
      if (( $(batch_branches | grep -cE " ${br//./\\.}-[0-9]+\$" || true) >= MAX_BATCH )); then
        log "batch $br: too many probes; dropping the batch, its PRs wait"; batch_drop "$br"; return
      fi
      if git -C "$SCRATCH" push -q origin "$sha:refs/heads/$br-$i" 2>/dev/null; then
        log "batch $br: probing the chain after $i PR(s)"; dispatch_linux "$br-$i"
      else log "batch $br: could not push probe $i; the next sweep tries again"; fi ;;
    *) log "batch $br: probe $i has no run yet"; dispatch_linux "$br-$i" ;;
  esac
}

# batch_land <branch> <upto> <proof> <chain...>: lands PRs 1..upto in order,
# stopping at the first that won't (its head moved: the rest were proven on
# top of it and wait), then drops the branch.
batch_land() {
  local br="$1" upto="$2" proof="$3"; shift 3
  local chain=("$@") i n head
  for (( i = 1; i <= upto; i++ )); do
    IFS='|' read -r _ n head <<<"${chain[i]}"
    if ! land "$n" "$head" "$proof"; then log "batch $br: #$n did not land; the PRs after it wait for the next batch"; break; fi
  done
  batch_drop "$br"
}

# batch_culprit <branch> <lo> <hi> <run url> <chain...>: PRs 1..lo land, PR hi
# gets NEEDS_FIX_LABEL and one comment, the rest wait for the next batch.
batch_culprit() {
  local br="$1" lo="$2" hi="$3" url="$4"; shift 4
  local chain=("$@") n head after="" i pn
  IFS='|' read -r _ n head <<<"${chain[hi]}"
  for (( i = 1; i <= lo; i++ )); do IFS='|' read -r _ pn _ <<<"${chain[i]}"; after+="${after:+, }#$pn"; done
  log "batch $br: PR #$n at $head is the culprit ($url)"
  write gh label create "$NEEDS_FIX_LABEL" -R "$REPO" --color d93f0b --force \
    --description "The lane's Linux check fails with this PR on dev; push a fix" >/dev/null 2>&1 || true
  write gh pr edit "$n" -R "$REPO" --add-label "$NEEDS_FIX_LABEL" || log "could not add $NEEDS_FIX_LABEL"
  comment_once "$n" "Fast lane: head $head fails the Linux check once it lands on $BASE_BRANCH${after:+ after $after}: $url. ${after:+Those PRs merged; }This one has the $NEEDS_FIX_LABEL label and waits. Fix it, rerun scripts/ci --changed, push, and move the Head: line; the lane drops the label on the new head and checks it again."
  batch_land "$br" "$lo" "batch of $lo PRs checked together on Linux before #$n broke the chain" "${chain[@]}"
}

# batch_drop <branch>: deletes the batch branch and its probes at REMOTE.
batch_drop() {
  local br="$1" names
  names=$(batch_branches | awk -v b="$br" '$2 == b || index($2, b "-") == 1 { print $2 }' | paste -sd' ' -)
  [[ -z "$names" ]] || git -C "$SCRATCH" push -q origin --delete $names 2>/dev/null || log "batch $br: could not delete $names"
}

# red_sweep: when a dev-red issue for a red Linux job is open, bisects its
# culprit range. Probes an earlier sweep left pin the red they bisect, since
# ci.yml rewrites the issue body for every newer red run.
red_sweep() {
  local issue body bad pin
  { read -r issue || true; body=$(cat); } < <(gh api "repos/$REPO/issues?labels=$RED_LABEL&state=open&per_page=5" \
      --jq 'first(.[] | select(.pull_request == null)) | .number, (.body // "")' 2>/dev/null || true)
  [[ -n "${issue:-}" ]] || return 0
  grep -qiE '^- Failing jobs:.*linux' <<<"$body" || { log "dev-red #$issue: not a Linux red; nothing to bisect"; return 0; }
  bad=$(grep -oE '^- Culprit range: `main\.\.[0-9a-f]{40}`' <<<"$body" | grep -oE '[0-9a-f]{40}' | head -1 || true)
  pin=$(git ls-remote --heads "$REMOTE" "refs/heads/${BISECT_PREFIX}*" 2>/dev/null | sed -E 's:.*refs/heads/'"$BISECT_PREFIX"'([0-9a-f]+)-[0-9]+$:\1:' | sort -u | head -1 || true)
  [[ -z "$pin" ]] || bad="$pin"
  [[ -n "$bad" ]] || { log "dev-red #$issue: no culprit range in the body"; return 0; }
  red_bisect "$issue" main "$bad" "$BASE_BRANCH"
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
# the owning feature-lead issue, and the probes are deleted.
red_bisect() {
  local issue="$1" good="$2" bad="$3" branch="$4" d k i sha v lo hi mid red7 hint=0 waited=0 line probes n p
  local chain=() verd=()
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
  while :; do
    for (( i = 0; i <= k; i++ )); do verd[i]=""; done
    verd[k]=$(check_verdict "$bad")
    probes=$(git ls-remote --heads "$REMOTE" "refs/heads/${BISECT_PREFIX}${red7}-*" 2>/dev/null | sed 's:[[:space:]]*refs/heads/: :' || true)
    while read -r sha line; do
      [[ -n "$line" ]] || continue
      i="${line##*-}"
      (( i >= 1 && i < k )) && [[ "${chain[i]}" == "$sha" ]] || continue
      verd[i]=$(check_verdict "$sha")
    done <<<"$probes"
    case "${verd[k]}" in
      green*) log "bisect: $red7 is green now (${verd[k]#green|}); nothing to find"; bisect_drop "$red7"; return ;;
    esac
    lo=0; hi=$k
    for (( i = 1; i < k; i++ )); do
      case "${verd[i]}" in green*) lo=$i ;; red*) (( i < hi )) && hi=$i ;; esac
    done
    if (( hi == lo + 1 )); then
      bisect_post "$issue" "$red7" "$lo" "$hi" "$(grep -c . <<<"$probes" || true)" "${verd[lo]}" "${verd[hi]}" "${chain[@]}"
      bisect_drop "$red7"; return
    fi
    if (( DRY_RUN )); then log "dry-run: bisect $red7 on #$issue: $k commits, green prefix $lo, red from $hi"; return; fi
    if (( $(grep -c . <<<"$probes" || true) >= MAX_BISECT )); then
      log "bisect: $red7 used $MAX_BISECT runs; stopping between $lo and $hi"
      write gh issue comment "$issue" -R "$REPO" --body "Bisect on $BASE_BRANCH stopped after $MAX_BISECT Linux runs: the Linux job is green at ${chain[lo]:0:7} and red at ${chain[hi]:0:7}; the culprit is one of the $((hi - lo)) commits between them (git log --first-parent ${chain[lo]:0:7}..${chain[hi]:0:7}). $BISECT_MARK $red7 -->"
      bisect_drop "$red7"; return
    fi
    if (( hint > lo && hint <= hi )) && (( hint - 1 > lo )) && [[ -z "${verd[hint - 1]}" ]]; then mid=$((hint - 1))
    elif (( hint > lo && hint < hi )) && [[ -z "${verd[hint]}" ]]; then mid=$hint
    else mid=$(( (lo + hi) / 2 )); fi
    case "${verd[mid]}" in
      running) log "bisect: $red7 probe $mid running" ;;
      "")
        if git -C "$d" push -q origin "${chain[mid]}:refs/heads/${BISECT_PREFIX}${red7}-$mid" 2>/dev/null; then
          log "bisect: $red7 probing commit $mid of $k (${chain[mid]:0:7})"; dispatch_linux "${BISECT_PREFIX}${red7}-$mid"
        else log "bisect: could not push probe $mid; the next sweep tries again"; fi ;;
      *) dispatch_linux "${BISECT_PREFIX}${red7}-$mid" ;;
    esac
    if (( waited >= BATCH_WAIT )); then return; fi
    sleep "$BATCH_POLL"; waited=$(( waited + BATCH_POLL ))
  done
}

# bisect_post <issue> <red7> <lo> <hi> <runs> <green verdict> <red verdict> <chain...>:
# the culprit on the dev-red issue and on the owning feature-lead issue.
bisect_post() {
  local issue="$1" red7="$2" lo="$3" hi="$4" runs="$5" gv="$6" rv="$7"; shift 7
  local chain=("$@") c subj n body fid lead
  c="${chain[hi]}"; subj=$(git -C "$SCRATCH" log -1 --format=%s "$c")
  n=$(grep -oE '\(#[0-9]+\)$' <<<"$subj" | tr -dc 0-9 || true)
  log "bisect: culprit ${c:0:7} $subj (green at ${chain[lo]:0:7}, $runs probes)"
  write gh issue comment "$issue" -R "$REPO" --body "Bisect: ${c:0:7} $subj is the first commit on $BASE_BRANCH whose Linux job fails. Green at ${chain[lo]:0:7} (${gv#green|}), red at ${c:0:7} (${rv#red|}); $runs Linux run(s) on ci/bisect branches, now deleted. $BISECT_MARK $red7 -->"
  [[ -n "$n" ]] || return 0
  body=$(gh api "repos/$REPO/pulls/$n" --jq '.body // ""' 2>/dev/null) || return 0
  fid=$(grep -E '^[[:space:]]*\**Feature:' <<<"$body" | head -1 | sed -E 's/^[[:space:]]*\**Feature:\**[[:space:]]*`?#?//; s/`.*//; s/[[:space:]].*//' || true)
  [[ -n "$fid" ]] || return 0
  lead=$(gh api "search/issues?q=repo:$REPO+label:$FEATURE_ISSUE_LABEL+state:open+in:title+%22Feature:+$fid%22" \
    --jq "[.items[] | select(.title == \"Feature: $fid\" or (.title | endswith(\"($fid)\")))] | first // empty | .number" 2>/dev/null) || return 0
  [[ -n "$lead" ]] || { log "bisect: no open $FEATURE_ISSUE_LABEL issue for $fid"; return 0; }
  write gh issue comment "$lead" -R "$REPO" --body "Bisect on dev-red #$issue: your PR #$n ($subj) is the first commit that turns $BASE_BRANCH's Linux job red: ${rv#red|}. $BISECT_MARK $red7 -->"
}

# bisect_drop <red7>: deletes that red's probe branches at REMOTE.
bisect_drop() {
  local names
  names=$(git ls-remote --heads "$REMOTE" "refs/heads/${BISECT_PREFIX}$1-*" 2>/dev/null | sed 's:.*refs/heads/::' | paste -sd' ' -)
  [[ -z "$names" ]] || git -C "$SCRATCH" push -q origin --delete $names 2>/dev/null || log "bisect: could not delete $names"
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
  # Read check runs off the head commit itself, newest per name. The PR's rollup
  # misses CI dispatched on the branch, and keeps the PR-event run that GitHub
  # parks as action_required for bot pushes.
  local head
  head=$(jq -r '.headRefOid' "$tmp/pr.json")
  # A batch's culprit (NEEDS_FIX_LABEL) waits at the head the lane named; a new
  # head gets the label dropped and a fresh look.
  if jq -e --arg l "$NEEDS_FIX_LABEL" '[.labels[]?.name] | index($l) != null' "$tmp/pr.json" >/dev/null; then
    if has_comment "$n" "Fast lane: head $head fails the Linux check"; then
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
    # Check runs carry no commit statuses; add Belt's review status from the head.
    gh api "repos/$REPO/commits/$head/status" --jq "[.statuses[] | select(.context == \"$BELT_REVIEW_CONTEXT\")
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
  # build-only run on the head. A failed run list skips the PR this sweep, so
  # an API hiccup never dispatches a second build for one head.
  local mac=() id fields=workflowName,status,conclusion,headSha,jobs,url
  if [[ -n "$(build_paths "$tmp/files.txt")" ]]; then
    echo '{}' >"$tmp/mac.json"
    id=$(mac_run_id "$(mac_check_url "$tmp/pr.json")")
    if [[ -n "$id" ]]; then
      gh run view "$id" -R "$REPO" --json "$fields" >"$tmp/mac.json" 2>/dev/null || echo '{}' >"$tmp/mac.json"
    fi
    if ! gh run list -R "$REPO" --workflow "$CI_FILE" --commit "$head" --limit 20 \
        --json databaseId,displayTitle,status,conclusion,url,headSha \
        --jq "[.[] | select(.displayTitle == \"$BUILD_TITLE\")][0] // {}" >"$tmp/build.json"; then
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
      local what="" branch url="" i flags=(-f build_only=true) title="$BUILD_TITLE"
      if [[ "$kind" == linux-dispatch ]]; then branch="$rest"; flags=(-f linux_only=true); title="$LINUX_TITLE"
      else IFS='|' read -r what branch <<<"$rest"; fi
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
      if ! write gh workflow run "$CI_FILE" -R "$REPO" "${flags[@]}" --ref "$branch"; then
        log "could not dispatch CI on $branch; the next sweep tries again"; rm -rf "$tmp"; return
      fi
      for (( i = 0; i <= RUN_LOOKUP_RETRIES; i++ )); do
        url=$(gh run list -R "$REPO" --workflow "$CI_FILE" --commit "$head" --limit 20 --json url,displayTitle \
          --jq "[.[] | select(.displayTitle == \"$title\")][0].url // \"\"" 2>/dev/null || true)
        [[ -z "$url" && $i -lt $RUN_LOOKUP_RETRIES ]] || break
        sleep 5
      done
      [[ -n "$url" ]] || url="https://github.com/$REPO/actions/workflows/$CI_FILE?query=branch%3A$branch"
      if [[ "$kind" == linux-dispatch ]]; then
        comment_once "$n" "Fast lane: nothing on head $head proves it yet (no CI check, no Fast-Check marker for it), so the lane started a Linux check on head $head: $url. A later sweep merges this PR once it passes (a code PR gets its macOS build on this head first)."
      else
        comment_once "$n" "Fast lane: this PR changes code ($what), so its head $head must build on macOS first. The lane dispatched a macOS build on $branch: $url. A later sweep merges this PR once it compiles; a new push gets a new build."
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
      # settle_ready lands it, or batches it with the pass's other eligible PRs.
      READY+=("$n|$head|$(jq -r '.headRefName // ""' "$tmp/pr.json")|${rest#*|*|}")
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
# empty when unknown>: why CI on the base should run now, nothing when it
# shouldn't. Pure, so the self-tests can call it.
dispatch_reason() {
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

# Open fast-lane PRs on any base, oldest first (decide retargets main and skips the rest).
open_prs() {
  gh pr list -R "$REPO" --state open --label "$LABEL" --limit 100 --json number --jq '.[].number' | sort -n
}

main() {
  local prs=() bisect="" bisect_issue="" bisect_branch="$BASE_BRANCH"
  while (( $# )); do
    case "$1" in
      --dry-run) DRY_RUN=1 ;;
      --bisect) bisect="${2:-}"; bisect_issue="${3:-}"; [[ -z "${4:-}" || "${4:-}" == --* ]] || { bisect_branch="$4"; shift; }; shift 2 ;;
      -h|--help) sed -n '2,60p' "$0"; return 0 ;;
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
    [[ "$BATCH_STATE" != waiting ]] || HOLD=1
  done < <(batch_branches)
  local explicit=${#prs[@]}
  if (( explicit == 0 )); then
    while read -r n; do [[ -n "$n" ]] && prs+=("$n"); done < <(open_prs)
  fi
  (( ${#prs[@]} )) || { (( HOLD || MERGED_RUN )) || echo "fast-lane: no open $LABEL PRs" >&2; return 0; }
  local n pass
  for n in "${prs[@]}"; do evaluate "$n"; done
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
  (( DISPATCH_FEATURE || DISPATCH_UI )) || since=$(merges_since_ci)
  why=$(dispatch_reason "$DISPATCH_FEATURE" "$DISPATCH_UI" "$since")
  if [[ -n "$why" ]]; then
    log "dispatching CI on $BASE_BRANCH: $why"
    write gh workflow run "$CI_FILE" -R "$REPO" --ref "$BASE_BRANCH" || log "could not dispatch CI on $BASE_BRANCH"
  fi
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then main "$@"; fi
