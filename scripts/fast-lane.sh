#!/usr/bin/env bash
# scripts/fast-lane.sh: merge small, checked crew PRs into BASE_BRANCH (dev)
# without waiting for captain review. The captain batch-reviews merged
# fast-lane PRs later and reverts anything wrong. Rules for agents: CLAUDE.md,
# "Fast lane".
#
# Run by .github/workflows/fast-lane.yml with this file from the trusted main
# branch. It only reads PR metadata and file contents through the GitHub API.
# It never checks out or runs PR code.
#
# The branch model: workers run scripts/ci on their own machine, the lane merges
# into dev at once, full CI runs on dev once a feature is built, and the
# `promote` job in ci.yml fast-forwards main to a dev SHA only when that run is
# green. A red dev run opens the "dev is red" issue. The lane keeps merging
# while dev is red, on purpose: promotion is the guard that keeps main green.
#
# Eligibility (all must hold): open, not draft, label `fast-lane`, base
# BASE_BRANCH, author in FAST_LANE_AUTHORS, size within MAX_LINES/MAX_FILES, no
# changed or renamed-away path under PROTECTED (CLAUDE.md's "Never edit" list),
# no looser app audit (audit_loosens), MERGEABLE, no red or running check on the
# head, and proof the head passed the gate: a passing check from CI_WORKFLOWS on
# the head, or the worker's marker in the PR body, a line `Fast-Check: pass`
# followed by the line `Head: <full head sha>` for the current head. A PR that
# changes or renames a MAC_GATED shared shell file also needs a completed CI
# run on its head whose macOS job passed or failed only where dev fails
# (mac_gate): the run a body line
# `Mac-Check: <run url>` names, or else the latest CI run on the head, which
# the lane dispatches itself when there is none. Any other PR that changes
# code (BUILD_RE: Swift under Sources/, Tests/ or UITests/, project.yml,
# Package.swift) needs a passing build-only CI run on its head (build_gate),
# also dispatched by the lane. A Belt PR
# (a body line starting `Belt-Run:` or `Belt-Test:`) also needs Belt's
# `belt/review` commit status at success on its head while REQUIRE_BELT_REVIEW=1.
# A fast-lane PR based on main is retargeted to BASE_BRANCH. A PR that conflicts
# with the base gets one comment per head and keeps its label for Belt's fixer.
#
# Every run sweeps all open fast-lane PRs, oldest first, and merges each
# eligible one. A lead's PR (a `Feature:` body line) never closes a
# `feature-lead` issue: before the squash the lane turns the closing keyword
# before one into `Refs` (lead_refs); its other closing references stay.
# After its merges the lane dispatches CI on BASE_BRANCH at most once per run
# (dispatch_reason), when it merged a PR labelled FEATURE_LABEL,
# merged a PR touching UI_RE (app shells, SuiteUI, snapshot tests, UI journeys),
# or BASE_BRANCH holds DISPATCH_EVERY merged PRs since the last CI run's head.
# Leads can't dispatch CI themselves (403), so the lane does it for them.
# Trade-off: the lane builds each code PR on macOS (build_gate) but runs
# nothing there, so snapshot and UI journey breakage sits on dev until that
# run, and the dev-red range can span PRs.
#
# `decide` is the pure decision function (no network). It reads a PR JSON file,
# a file-list file (one path per line), a check-rollup JSON file and, when the
# PR touches the app audit, two audit_snapshot directories (merge base, head),
# and, when it touches MAC_GATED, the `gh run view` JSON of its Mac-Check run
# and of the latest CI run on its head, and when it touches BUILD_RE, its
# latest build-only run.
# It logs each rule to stderr and prints one line to stdout:
#   skip|<why>  retarget|<from base>  not-eligible|<reasons>  red|<checks>
#   conflict|<head sha>  pending|<why>  mac-dispatch|<gated files>|<head branch>
#   build-dispatch|<code paths>|<head branch>
#   mac-gate|<what to do>  eligible|<lines>|<files>|<proof>
# Tests/fast_lane/test_fast_lane.sh sources this file and feeds `decide` fixtures.
#
# Usage: scripts/fast-lane.sh [--dry-run] [PR ...]   (no PR: every open fast-lane PR)
# --dry-run prints the decision and makes no API writes. Needs gh and jq.
set -euo pipefail

# Logins as `gh pr view --json author` reports them. Cloud Claude Code sessions
# open PRs with the captain's own GitHub token, so they appear as prakashUXtech.
FAST_LANE_AUTHORS="prakashUXtech"
MAX_LINES=400
MAX_FILES=15
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
CI_CHECKS=("Linux" "macOS")
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
# Matching ignores case. docs/c4/model.json and each app's waves.md are
# generated on dev (.github/workflows/generated.yml), so PRs never edit them.
# UITests/quarantine.json skips failing journeys (scripts/quarantine), so only
# the supervisor quarantines; Tests/perf-suites.txt takes tests out of the
# gate (scripts/test-scope), so only the supervisor lists them.
PROTECTED=(Package.swift Package.resolved .github/ .claude/ scripts/ CLAUDE.md AGENTS.md LICENSE
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

# Shared shell files every app's window is built from. SwiftUI can't build on
# Linux, so a change here can pass scripts/ci and still break every app's UI
# journeys: #962 moved SuiteWindow's inspector, merged on the Linux gate, broke
# Flare, Library, Halo and Suite on dev (run 38679533707) and was reverted in
# #975. A PR that changes or renames one merges only with proof from macOS: a
# completed CI run on its head whose macOS job passed, or failed only tests
# that also fail in the latest completed dev run (mac_judge). Cloud sessions
# can't dispatch workflows (403, #1040), so the lane dispatches CI on the PR's
# head branch itself, once per head, and merges when that run passes. A
# `Mac-Check: <run url>` line a supervisor adds by hand counts too. Not
# PROTECTED: agents may edit these, with that proof.
MAC_GATED=(Sources/SuiteUI/SuiteWindow.swift Sources/SuiteUI/EditorShell.swift
  Sources/SuiteUI/ToolbarGroup.swift Sources/SuiteUI/Tokens.swift)
MAC_CHECK_LINE="Mac-Check:"
MAC_JOB="macOS"
# What a compiler reads: Swift under Sources/, Tests/ and UITests/, plus
# project.yml and Package.swift (protected anyway). A PR changing any of it
# that isn't MAC_GATED merges only once a build-only CI run (ci.yml's
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

# mac_gated <files.txt>: the MAC_GATED paths among <files.txt>, joined by ", ".
mac_gated() {
  grep -Fx -f <(printf '%s\n' "${MAC_GATED[@]}") "$1" | sort -u | paste -sd, - | sed 's/,/, /g' || true
}

# failed_tests: the failing test identifiers in a job log on stdin, one per
# line: XCTest's `-[Module.Class testName]` from its "Test Case '...' failed"
# lines, and Swift Testing's `Test name()` from its "✘ Test name() failed" lines.
failed_tests() {
  sed -e 's/^[0-9T:.-]*Z //' -e $'s/\x1b\\[[0-9;]*m//g' \
    | sed -n -e "s/.*Test Case '\(-\[[^]]*\]\)' failed.*/\1/p" -e 's/.*✘ \(Test .*\) failed after .*/\1/p' \
    | sort -u || true
}

# mac_judge <run.json> <head sha>: nothing when the run (`gh run view --json
# workflowName,status,headSha,jobs`) is a completed CI run on <head sha> whose
# macOS job passed, or failed only where dev fails too; else what is wrong.
# Dev has been red for days at a time from other lines, so a failed macOS job
# passes when the run's `failedTests` (failed_tests on its log) are all in
# `.base.failedTests`, the latest completed dev run's, its failed steps are
# all failed there too, and it has at least one failing test to compare (a
# build or setup failure has none). evaluate adds both (mac_add_failures).
mac_judge() {
  local runjson='{}'
  [[ -z "$1" || ! -s "$1" ]] || runjson=$(cat "$1")
  jq -r --arg wf "${CI_WORKFLOWS[0]}" --arg job "$MAC_JOB" --arg head "$2" '
    def lc: (. // "") | ascii_downcase;
    ([.jobs[]? | select(.name == $job)] | last) as $j
    | ([$j.steps[]? | select((.conclusion | lc) == "failure") | .name]) as $steps
    | (.failedTests // []) as $tests
    | if (.workflowName // "") == "" then "its run could not be read"
      elif .workflowName != $wf then "its run is the \(.workflowName) workflow, not \($wf)"
      elif (.status | lc) != "completed" then "its run has not completed"
      elif $j == null then "its run has no \($job) job"
      elif ($j.conclusion | lc) == "success" then
        (if (.headSha // "") != $head then "its run is on \(.headSha // "no head"), not the head \($head)" else empty end)
      elif ($j.conclusion | lc) != "failure" then "its \($job) job is \($j.conclusion // "unfinished")"
      elif .base == null then "its \($job) job failed, and no completed \($job) run on dev could be read to compare"
      elif ($tests | length) == 0 then "its \($job) job failed in \($steps | join(", ")) with no failing test to compare with dev"
      elif ($tests - .base.failedTests | length) > 0 then
        ($tests - .base.failedTests) as $new
        | "its \($job) job has \($new | length) failing test(s) that the latest dev run (\(.base.url)) does not: \($new | join(", "))"
      elif ($steps - .base.failedSteps | length) > 0 then
        "its \($job) job failed in \($steps - .base.failedSteps | join(", ")), which passed in the latest dev run (\(.base.url))"
      elif (.headSha // "") != $head then "its run is on \(.headSha // "no head"), not the head \($head)"
      else empty end' <<<"$runjson" 2>/dev/null || echo "its run could not be read"
}

# mac_dev_note <run.json>: when the run's macOS job failed (and mac_judge
# passed it), a note naming the dev run with the same failures.
mac_dev_note() {
  jq -r --arg job "$MAC_JOB" '
    if ([.jobs[]? | select(.name == $job) | .conclusion // "" | ascii_downcase] | last) == "failure"
    then " (its failing tests also fail on dev: \(.base.url))" else "" end' "$1" 2>/dev/null || true
}

# mac_gate <pr.json> <files.txt> <mac-check run.json> <lane run.json>: nothing
# when the PR touches no MAC_GATED path, else one line:
#   ok|<proof>                 a CI run on the head passes mac_judge
#   dispatch|<files>|<branch>  no CI run on the head yet: the lane starts one
#   wait|<url>                 the CI run on the head is still going
#   refuse|<what to do>        the CI run on the head failed on macOS beyond dev
# The Mac-Check line's run counts first (a supervisor can add one by hand);
# otherwise the latest CI run on the head (<lane run.json>, {} when none).
mac_gate() {
  local pr="$1" files="$2" gated head branch url lane='{}' why
  gated=$(mac_gated "$files")
  [[ -n "$gated" ]] || return 0
  head=$(jq -r '.headRefOid' "$pr")
  branch=$(jq -r '.headRefName // ""' "$pr")
  url=$(mac_check_url "$pr")
  if [[ -n "$url" && -n "$(mac_run_id "$url")" && -z "$(mac_judge "${3:-}" "$head")" ]]; then
    echo "ok|$MAC_CHECK_LINE $url$(mac_dev_note "$3")"; return
  fi
  [[ -z "${4:-}" || ! -s "$4" ]] || lane=$(cat "$4")
  url=$(jq -r '.url // ""' <<<"$lane" 2>/dev/null || true)
  # No run on the head (a run on an older head doesn't count): dispatch one.
  if [[ -z "$url" || "$(jq -r '.headSha // ""' <<<"$lane")" != "$head" ]]; then
    echo "dispatch|$gated|$branch"; return
  fi
  why=$(mac_judge "$4" "$head")
  if [[ -z "$why" ]]; then echo "ok|macOS run $url$(mac_dev_note "$4")"; return; fi
  if [[ "$why" == "its run has not completed" ]]; then echo "wait|$url"; return; fi
  echo "refuse|changes $gated, shared by every app's window, so it needs a macOS run on its head $head that is green or fails only where dev fails, and the CI run the lane found there doesn't: $url ($why). Fix it and push; the lane dispatches CI again on the new head. A supervisor can instead add a line \`$MAC_CHECK_LINE <run url>\` naming a green CI run on this head"
}

# mac_job_failures <run.json>: the failing tests in the log of the run's
# failed macOS job, as a JSON array; nothing when it didn't fail or the log
# can't be read.
mac_job_failures() {
  local jid log
  jid=$(jq -r --arg job "$MAC_JOB" '[.jobs[]? | select(.name == $job and ((.conclusion // "") | ascii_downcase) == "failure")
    | .databaseId] | last // ""' "$1" 2>/dev/null || true)
  [[ -n "$jid" ]] || return 0
  log=$(gh api "repos/$REPO/actions/jobs/$jid/logs" 2>/dev/null) || return 0
  failed_tests <<<"$log" | jq -R . | jq -sc .
}

# mac_base_json: the latest completed CI run on BASE_BRANCH whose macOS job
# passed or failed, as {url, failedTests, failedSteps}; nothing when none can
# be read. Read once per lane run (MAC_BASE, MAC_BASE_READ).
MAC_BASE="" MAC_BASE_READ=0
mac_base_json() {
  if (( ! MAC_BASE_READ )); then
    MAC_BASE_READ=1
    local id ids f tests
    f=$(mktemp)
    ids=$(gh run list -R "$REPO" --workflow "$CI_FILE" --branch "$BASE_BRANCH" --status completed --limit 10 \
      --json databaseId --jq '.[].databaseId' 2>/dev/null || true)
    for id in $ids; do
      gh run view "$id" -R "$REPO" --json jobs,url >"$f" 2>/dev/null || continue
      case "$(jq -r --arg job "$MAC_JOB" '[.jobs[]? | select(.name == $job) | .conclusion // "" | ascii_downcase] | last // ""' "$f")" in
        success) tests='[]' ;;
        failure) tests=$(mac_job_failures "$f"); [[ -n "$tests" ]] || continue ;;
        *) continue ;;
      esac
      MAC_BASE=$(jq -c --arg job "$MAC_JOB" --argjson t "$tests" '{url, failedTests: $t,
        failedSteps: [.jobs[]? | select(.name == $job) | .steps[]? | select(((.conclusion // "") | ascii_downcase) == "failure") | .name]}' "$f")
      break
    done
    rm -f "$f"
  fi
  [[ -z "$MAC_BASE" ]] || echo "$MAC_BASE"
}

# mac_add_failures <run.json>: when the run's macOS job failed, adds its
# `failedTests` and the dev run to compare with as `base` (mac_judge).
mac_add_failures() {
  local tests base
  tests=$(mac_job_failures "$1")
  [[ -n "$tests" ]] || return 0
  base=$(mac_base_json)
  jq --argjson t "$tests" --argjson b "${base:-null}" '.failedTests = $t | if $b == null then . else .base = $b end' \
    "$1" >"$1.x" && mv "$1.x" "$1"
}

# build_paths <files.txt>: the BUILD_RE files among <files.txt> by target
# folder (Sources/X, Tests/X, UITests) or manifest, joined by ", ".
build_paths() {
  grep -E "$BUILD_RE" "$1" | sed -E 's:^((Sources|Tests)/[^/]+|UITests)/.*:\1:' | sort -u | paste -sd, - | sed 's/,/, /g' || true
}

# build_gate <pr.json> <files.txt> <mac-check run.json> <build run.json>:
# nothing when the PR touches no BUILD_RE code, else a line like mac_gate's. A green
# Mac-Check run on the head (it builds every app) counts; otherwise the latest
# build-only run on the head ({} when none: dispatch one).
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

# decide <pr.json> <files.txt> <checks.json> [<audit before dir> <audit after dir>
#   [<mac-check run.json> <lane run.json> [<build run.json>]]]
# (pass "" "" for the audit dirs when the PR doesn't touch the audit)
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

  local skip="" retarget="" reasons=() pending="" red="" ngreen=0 review=""

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

  # A gated PR's macOS check is mac_gate's to judge (it may fail only where dev
  # fails), and a code PR's macOS build check is build_gate's, so each leaves
  # the red and running lists below. A MAC_GATED PR needs only mac_gate: its
  # full run builds every app too.
  local mac macdrop="" gate=mac
  mac=$(mac_gate "$pr" "$files" "${6:-}" "${7:-}")
  if [[ -n "$mac" ]]; then
    macdrop="$MAC_JOB"
  else
    gate=build
    mac=$(build_gate "$pr" "$files" "${6:-}" "${8:-}")
    [[ -z "$mac" ]] || macdrop="$BUILD_JOB"
  fi

  # Drop our own check, Belt's review and Copilot review checks, then classify the rest.
  local ci_json summary
  ci_json=$(printf '%s\n' "${CI_WORKFLOWS[@]}" "${CI_CHECKS[@]}" | jq -R . | jq -s .)
  summary=$(jq -c --arg self "$SELF_WORKFLOW" --arg selfcheck "$SELF_CHECK" \
      --arg review "$BELT_REVIEW_CONTEXT" --argjson ci "$ci_json" --arg macdrop "$macdrop" '
    [ .[]
      | select((.workflowName // "") != $self and (.name // "") != $selfcheck)
      | select($macdrop == "" or (.name // "") != $macdrop)
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
  # ponytail: "CI passed" = at least one *passing* check from CI_WORKFLOWS, so a
  # head where every CI job was skipped still needs the worker's marker.
  log "checks: green=$ngreen pending=$npending red=[${red}] ci_passed=$nci marker=$marker"

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
    echo "pending|no passing CI check and no $MARKER_LINE marker for head $head"; return
  fi
  if (( belt )) && [[ "$review" != "SUCCESS" ]]; then echo "pending|waiting for review"; return; fi
  log "$gate gate: ${mac:-not gated}"
  case "$mac" in
    dispatch\|*) echo "$gate-dispatch|${mac#dispatch|}"; return ;;
    wait\|*)
      if [[ "$gate" == mac ]]; then echo "pending|waiting for the macOS CI run ${mac#wait|} on head $head"
      else echo "pending|waiting for the macOS build ${mac#wait|} on head $head"; fi
      return ;;
    refuse\|*) echo "mac-gate|${mac#refuse|}"; return ;;
  esac
  local proof="Fast-Check marker"
  (( nci == 0 )) || proof="$ngreen checks green"
  [[ "$mac" != ok\|* ]] || proof+=", ${mac#ok|}"
  echo "eligible|$lines|$nfiles|$proof"
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
    gh pr view "$n" -R "$REPO" --json number,state,isDraft,baseRefName,labels,author,body,additions,deletions,changedFiles,mergeable,mergeStateStatus,headRefOid,headRefName,statusCheckRollup >"$tmp/pr.json"
    [[ "$(jq -r '.mergeable' "$tmp/pr.json")" == "UNKNOWN" ]] || break
    (( tries++ < UNKNOWN_RETRIES )) || break
    sleep 5
  done
  # Read check runs off the head commit itself, newest per name. The PR's rollup
  # misses CI dispatched on the branch, and keeps the PR-event run that GitHub
  # parks as action_required for bot pushes.
  local head
  head=$(jq -r '.headRefOid' "$tmp/pr.json")
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
  gh api "repos/$REPO/pulls/$n/files" --paginate --jq '.[] | .filename, (.previous_filename // empty)' >"$tmp/files.txt"
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
  # A MAC_GATED change brings the run its Mac-Check line names and the latest
  # CI run on the head (mac_gate judges them). A failed run list skips the PR
  # this sweep, so an API hiccup never dispatches a second run for one head.
  local mac=() id fields=workflowName,status,conclusion,headSha,jobs,url
  if [[ -n "$(mac_gated "$tmp/files.txt")" ]]; then
    echo '{}' >"$tmp/mac.json"; echo '{}' >"$tmp/lane.json"
    id=$(mac_run_id "$(mac_check_url "$tmp/pr.json")")
    if [[ -n "$id" ]]; then
      gh run view "$id" -R "$REPO" --json "$fields" >"$tmp/mac.json" 2>/dev/null || echo '{}' >"$tmp/mac.json"
      mac_add_failures "$tmp/mac.json"
    fi
    if ! id=$(gh run list -R "$REPO" --workflow "$CI_FILE" --commit "$head" --limit 20 --json databaseId,displayTitle \
        --jq "[.[] | select(.displayTitle != \"$BUILD_TITLE\")][0].databaseId // \"\""); then
      log "PR #$n: could not list CI runs on the head; the next sweep looks again"; rm -rf "$tmp"; return
    fi
    if [[ -n "$id" ]]; then
      gh run view "$id" -R "$REPO" --json "$fields" >"$tmp/lane.json" 2>/dev/null || echo '{}' >"$tmp/lane.json"
      mac_add_failures "$tmp/lane.json"
    fi
    (( ${#audit[@]} )) || audit=("" "")
    mac=("$tmp/mac.json" "$tmp/lane.json")
  elif [[ -n "$(build_paths "$tmp/files.txt")" ]]; then
    # Code: the Mac-Check line's run, if any, and the latest build-only run on the head.
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
  decision=$(decide "$tmp/pr.json" "$tmp/files.txt" "$tmp/checks.json" ${audit[@]+"${audit[@]}"} ${mac[@]+"${mac[@]}"})
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
      # Usually an earlier merge in this sweep. Belt's fixer rebases it; the label stays.
      comment_once "$n" "Fast lane: not merged, this PR conflicts with $BASE_BRANCH at head $rest. Rebase on origin/$BASE_BRANCH, rerun scripts/ci, and update the Fast-Check marker."
      ;;
    mac-dispatch|build-dispatch)
      # Authors can't dispatch (403, #1040), so the lane does, once per head:
      # the next sweep finds this run on the head and waits for it, then merges.
      local what branch url="" i flags=() sel="!="
      IFS='|' read -r what branch <<<"$rest"
      [[ "$kind" == mac-dispatch ]] || { flags=(-f build_only=true); sel="=="; }
      if ! write gh workflow run "$CI_FILE" -R "$REPO" "${flags[@]+"${flags[@]}"}" --ref "$branch"; then
        log "could not dispatch CI on $branch; the next sweep tries again"; rm -rf "$tmp"; return
      fi
      for (( i = 0; i <= RUN_LOOKUP_RETRIES; i++ )); do
        url=$(gh run list -R "$REPO" --workflow "$CI_FILE" --commit "$head" --limit 20 --json url,displayTitle \
          --jq "[.[] | select(.displayTitle $sel \"$BUILD_TITLE\")][0].url // \"\"" 2>/dev/null || true)
        [[ -z "$url" && $i -lt $RUN_LOOKUP_RETRIES ]] || break
        sleep 5
      done
      [[ -n "$url" ]] || url="https://github.com/$REPO/actions/workflows/$CI_FILE?query=branch%3A$branch"
      if [[ "$kind" == mac-dispatch ]]; then
        comment_once "$n" "Fast lane: this PR changes $what, shared by every app's window, so it needs a green macOS run on its head $head. The lane dispatched CI on $branch: $url. A later sweep merges this PR once that run's macOS job passes on this head; a new push gets a new run."
      else
        comment_once "$n" "Fast lane: this PR changes code ($what), so its head $head must build on macOS first. The lane dispatched a macOS build on $branch: $url. A later sweep merges this PR once it compiles; a new push gets a new build."
      fi
      ;;
    mac-gate)
      # The label stays: a push gets a new run on the new head, and a later sweep merges it once green.
      comment_once "$n" "Fast lane: waiting for macOS proof. This PR $rest."
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
      local lines files proof
      IFS='|' read -r lines files proof <<<"$rest"
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
        log "merge failed; the next sweep looks again"; rm -rf "$tmp"; return
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
      comment_once "$n" "Fast lane: merged into $BASE_BRANCH ($lines lines, $files files, $proof)."
      ;;
  esac
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
  local prs=()
  while (( $# )); do
    case "$1" in
      --dry-run) DRY_RUN=1 ;;
      -h|--help) sed -n '2,60p' "$0"; return 0 ;;
      *) prs+=("$1") ;;
    esac
    shift
  done
  if (( ${#prs[@]} == 0 )); then
    while read -r n; do [[ -n "$n" ]] && prs+=("$n"); done < <(open_prs)
  fi
  (( ${#prs[@]} )) || { echo "fast-lane: no open $LABEL PRs" >&2; return 0; }
  local n pass
  for n in "${prs[@]}"; do evaluate "$n"; done
  # A merge changes every other PR's mergeable state, and GitHub reports
  # UNKNOWN until it recomputes. Sweep again after any merge, until a pass
  # merges nothing, so a PR that settles late still merges in this run.
  for (( pass = 0; MERGED_ANY && pass < 5; pass++ )); do
    MERGED_ANY=0
    while read -r n; do [[ -n "$n" ]] && evaluate "$n"; done < <(open_prs)
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
