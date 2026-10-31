#!/usr/bin/env bash
# Tests/fast_lane/test_fast_lane.sh: fixture tests for the pure `decide`
# function in scripts/fast-lane.sh, its PROTECTED list against CLAUDE.md's
# "Never edit" bullet, the app audit guard (audit_loosens on before/after
# trees), whole sweeps against a stub `gh`, and, against a local bare repo, the
# lane's integration of a conflicting PR (integrate) and its batches (two or
# more ready PRs get one Linux check together before they land; a red batch is
# bisected by prefix; a proof gone stale on a ratchet or baseline change is
# checked again on today's dev), the batch macOS gate (LANE_MAC_PER_PR=0: one macOS gate
# per code batch scoped to its apps, priority order, slots, the timer, a red
# base set aside per job on Linux and judged by failing test on macOS, the culprit's stacked PRs named, and LANE_KILN=1's hold for a local Mac check's local-ci/macos), no batch forming on a red dev and a batch on a red base dropped once dev is green, and the red-dev
# bisect, with its 2-of-3 vote mode for a timing budget test, and the
# auto-revert of a red dev's culprit, own-proof landing on the pre-screen and a
# stale proof's batch of one holding only its own PR
# (LANE_VERIFY_AFTER=1). No network,
# needs bash, git and jq.
#
# checks-green.json is a check rollup shaped like a green flare-core PR: the CI
# workflow's Linux and macOS jobs plus one SKIPPED CI job, a non-CI workflow
# check, a commit status, the fast-lane workflow's own in-progress check and a
# Copilot review check (decide must ignore the last two, and CI's report-only
# macOS job, so 4 checks count). Each case mutates a
# base PR / file list / rollup with jq. Most crew PRs have no CI on their head
# (CI runs on dev), so the worker's Fast-Check marker cases start from `[]`.
#
# Run: bash Tests/fast_lane/test_fast_lane.sh   (exit 0 = all pass)
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FAST_LANE_BATCH_WAIT=0  # a sweep never sleeps for a batch's verdict here
# Every case up to "Batch macOS gate" runs with the rollback flag on, so they
# pin that LANE_MAC_PER_PR=1 is the lane from before the batch macOS gate:
# per-PR macOS builds and Linux-only batches. That section turns it off.
LANE_MAC_PER_PR=1
LANE_BATCH_WAIT_MIN=0   # no batch waits for its timer unless a case says so
# shellcheck source=../../scripts/fast-lane.sh
source "$here/../../scripts/fast-lane.sh"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fail=0
REMOTE="$tmp/no-such-remote"  # integrate's clone target; the integrate cases point it at a bare repo

HEAD_SHA="0123456789abcdef0123456789abcdef01234567"
BASE_PR='{"number":1,"state":"OPEN","isDraft":false,"baseRefName":"dev","headRefName":"feat/x",
  "labels":[{"name":"fast-lane"}],"author":{"login":"prakashUXtech"},
  "additions":120,"deletions":30,"changedFiles":2,
  "mergeable":"MERGEABLE","mergeStateStatus":"CLEAN","headRefOid":"'"$HEAD_SHA"'",
  "body":"Closes #1"}'
BASE_FILES=$'Sources/FlareModel/FlareWorkspace.swift\nTests/FlareModelTests/FlareWorkspaceTests.swift'
# Every code PR needs a macOS build of its head (build_gate). Unless a case
# says otherwise the head already has a green one (gbuild.json); the build
# gate's own cases are under `build` below.
BUILD_URL="https://github.com/qbtrix/creative-apps/actions/runs/38700000003"
GREEN_BUILD='{"databaseId":"38700000003","displayTitle":"macOS build","status":"completed","conclusion":"success",
  "url":"'"$BUILD_URL"'","headSha":"'"$HEAD_SHA"'"}'
jq . <<<"$GREEN_BUILD" >"$tmp/gbuild.json"

# check <name> <expected stdout prefix> <pr jq> <files> <checks jq>
check() {
  local name="$1" want="$2" prq="$3" files="$4" chq="$5" got
  jq "$prq" <<<"$BASE_PR" >"$tmp/pr.json"
  printf '%s\n' "$files" >"$tmp/files.txt"
  jq "$chq" "$here/checks-green.json" >"$tmp/checks.json"
  got=$(decide "$tmp/pr.json" "$tmp/files.txt" "$tmp/checks.json" "" "" "" "" "$tmp/gbuild.json" 2>/dev/null)
  if [[ "$got" == "$want"* ]]; then
    echo "ok   $name -> $got"
  else
    echo "FAIL $name: want '$want*', got '$got'"; fail=1
  fi
}

check "happy path" "eligible|150|2|4 checks green" . "$BASE_FILES" .
check "claude app bot author is not allowlisted" "not-eligible|author app/claude is not on the fast-lane allowlist" '.author.login = "app/claude"' "$BASE_FILES" .
check "deny path hit" "not-eligible|touches protected paths: .github/workflows/ci.yml" \
  . $'.github/workflows/ci.yml\nsrc/x.py' .
check "deny Package.swift" "not-eligible|touches protected paths: Package.swift" \
  . $'Package.swift\nSources/FlareModel/FlareWorkspace.swift' .
check "deny gate scripts" "not-eligible|touches protected paths: scripts/ci, scripts/cloud-setup.sh" \
  . $'scripts/ci\nscripts/cloud-setup.sh' .
check "deny agent rules, any case" "not-eligible|touches protected paths: docs/agents.md" \
  . 'docs/agents.md' .
check "similar names are allowed" "eligible|150|2|4 checks green" \
  . $'docs/scripts/ci.md\nSources/DesignModel/PackageSwiftNotes.swift' .
check "every script is protected (#292 changed scripts/ui-test)" "not-eligible|touches protected paths: scripts/ui-test" \
  . $'scripts/ui-test\nUITests/Audit.swift' .
check "deny .claude, Package.resolved and a nested CLAUDE.md" \
  "not-eligible|touches protected paths: .claude/settings.json, Package.resolved, Sources/FlareApp/CLAUDE.md" \
  . $'.claude/settings.json\nPackage.resolved\nSources/FlareApp/CLAUDE.md' .
check "deny the generated C4 model and waves.md" \
  "not-eligible|touches protected paths: docs/c4/model.json, docs/blueprints/halo/features/waves.md" \
  . $'docs/c4/model.json\ndocs/blueprints/halo/features/waves.md' .
check "C4 parts, feature data and packets stay eligible" "eligible|150|2|4 checks green" \
  . $'docs/c4/parts/creative-apps/halo-model/halo-model-sources.json\ndocs/blueprints/halo/features/easing.wave.json\ndocs/blueprints/halo/features/easing.md\ndocs/blueprints/halo/waves.in.md\ndocs/blueprints/halo/features/nested/waves.md' .
check "app code that built on macOS is eligible (taste review still happens after merge)" "eligible|150|2|4 checks green, macOS build $BUILD_URL" \
  . $'Sources/FlareApp/FlareApp.swift\nSources/FlareModel/FlareWorkspace.swift' .
check "SuiteUI needs only the build" "eligible|150|2|4 checks green, macOS build $BUILD_URL" \
  . $'Sources/SuiteUI/GlassPanel.swift\nTests/SuiteUITests/GlassPanelTests.swift' .
check "models and tests stay eligible" "eligible|150|2|4 checks green" \
  . $'Sources/PhotoModel/PhotoWorkspace.swift\nTests/PhotoModelTests/PhotoWorkspaceTests.swift' .
check "a model named like an app is allowed" "eligible|150|2|4 checks green" \
  . $'Sources/HaloModel/HaloAppState.swift\nTests/HaloModelTests/HaloProjectTests.swift' .
check "a model with only the worker's marker is eligible" "eligible|150|2|Fast-Check marker" \
  "$(printf '.body = "Closes #1\\n\\nFast-Check: pass\\nHead: %s"' "$HEAD_SHA")" \
  $'Sources/PhotoModel/PhotoWorkspace.swift\nTests/PhotoModelTests/PhotoWorkspaceTests.swift' '[]'
check "too big (lines)" "not-eligible|too big: 401 lines" '.additions = 401 | .deletions = 0' "$BASE_FILES" .
check "too big (files)" "not-eligible|too big: 150 lines, 16 files" '.changedFiles = 16' "$BASE_FILES" .

# The docs tier: every changed path under docs/ (packets, .wave.json feature
# data, C4 parts, any .md there) takes the lane at any size, on the same proof.
DOCS=$'docs/blueprints/design/packets/v3-select.md\ndocs/blueprints/design/features/select.wave.json\ndocs/c4/parts/creative-apps/design-model/design-model-sources.json'
BIG='.additions = 1200 | .changedFiles = 3'
many_docs() { local i; for (( i = 1; i <= $1; i++ )); do echo "docs/blueprints/design/packets/p$i.md"; done; }
check "docs only: any size on a green check" "eligible|1230|3|4 checks green, docs only: any size" "$BIG" "$DOCS" .
check "docs only: 40 files on the worker's marker" "eligible|1230|40|Fast-Check marker, docs only: any size" \
  "$(printf '.body = "Closes #1\\n\\nFast-Check: pass\\nHead: %s" | .additions = 1200 | .changedFiles = 40' "$HEAD_SHA")" \
  "$(many_docs 40)" '[]'
check "docs only under the cap: no tier note" "eligible|150|3|4 checks green" '.changedFiles = 3' "$DOCS" .
check "docs only still needs proof (a Linux check)" "linux-dispatch|feat/x" "$BIG" "$DOCS" '[]'
check "docs only still waits on a red check" "red|Linux" "$BIG" "$DOCS" \
  'map(if .name == "Linux" then .conclusion = "FAILURE" else . end)'
check "docs only still refuses a protected docs path, size aside" \
  "not-eligible|touches protected paths: docs/c4/model.json, docs/blueprints/halo/features/waves.md, docs/AGENTS.md" \
  "$BIG" $'docs/c4/model.json\ndocs/blueprints/halo/features/waves.md\ndocs/AGENTS.md' .
check "docs plus one Swift file keeps the cap" "not-eligible|too big: 1230 lines, 3 files" \
  "$BIG" $'docs/blueprints/design/packets/v3-select.md\nSources/DesignModel/DesignSelection.swift\ndocs/c4/parts/creative-apps/design-model/design-model-sources.json' .
check "a rename from code into docs keeps the cap" "not-eligible|too big: 1230 lines" \
  "$BIG" $'docs/notes/old-selection.md\nSources/DesignModel/OldSelection.swift' .
check "a docs folder outside the root isn't docs" "not-eligible|too big: 1230 lines" \
  "$BIG" $'README.md\nSources/FlareModel/docs/notes.md\ntools/docs/x.md' .
check "a file list shorter than the PR's file count gets no tier" "not-eligible|too big: 1230 lines, 3000 files" \
  '.additions = 1200 | .changedFiles = 3000' "$DOCS" .
check "non-allowlisted author" "not-eligible|author someone is not on the fast-lane allowlist" \
  '.author.login = "someone"' "$BASE_FILES" .
check "all hard rules listed" "not-eligible|author someone is not on the fast-lane allowlist;too big" \
  '.author.login = "someone" | .additions = 999' "$BASE_FILES" .
check "no checks and no marker: the lane starts a Linux check" "linux-dispatch|feat/x" \
  . "$BASE_FILES" '[]'
check "only non-CI checks fails closed" "pending|no passing CI check" . "$BASE_FILES" \
  '[.[] | select(.__typename == "StatusContext")]'
check "a fork's PR with no checks waits, no Linux check" "pending|no passing CI check and no Fast-Check: pass marker for head $HEAD_SHA" \
  '.isCrossRepository = true' "$BASE_FILES" '[]'
check "one red check" "red|Linux" . "$BASE_FILES" \
  'map(if .name == "Linux" then .conclusion = "FAILURE" else . end)'
check "red status context" "red|ci/external" . "$BASE_FILES" \
  'map(if .context == "ci/external" then .state = "FAILURE" else . end)'
check "pending check" "pending|1 checks still running" . "$BASE_FILES" \
  'map(if .name == "Linux" then .status = "IN_PROGRESS" | .conclusion = null else . end)'
check "draft PR" "skip|PR is a draft" '.isDraft = true' "$BASE_FILES" .
check "no label" "skip|no fast-lane label" '.labels = []' "$BASE_FILES" .
check "already merged" "skip|PR is MERGED" '.state = "MERGED"' "$BASE_FILES" .
check "base main is retargeted to dev" "retarget|main" '.baseRefName = "main"' "$BASE_FILES" .
check "base main without the label is left alone" "skip|no fast-lane label" \
  '.baseRefName = "main" | .labels = []' "$BASE_FILES" .
check "other base is skipped" "skip|base is release, not dev" '.baseRefName = "release"' "$BASE_FILES" .
check "mergeable unknown" "pending|not mergeable yet (UNKNOWN/UNKNOWN)" \
  '.mergeable = "UNKNOWN" | .mergeStateStatus = "UNKNOWN"' "$BASE_FILES" .
check "conflicting after an earlier merge" "conflict|$HEAD_SHA" \
  '.mergeable = "CONFLICTING" | .mergeStateStatus = "DIRTY"' "$BASE_FILES" .
check "behind dev is still eligible (no freshness rule)" "eligible|150|2|4 checks green" \
  '.mergeStateStatus = "BEHIND"' "$BASE_FILES" .
check "red CI outranks a conflict" "red|Linux" \
  '.mergeable = "CONFLICTING" | .mergeStateStatus = "DIRTY"' "$BASE_FILES" \
  'map(if .name == "Linux" then .conclusion = "FAILURE" else . end)'

# PROTECTED is exactly the backticked paths in CLAUDE.md's "**Never edit**"
# bullet, and decide refuses a file under each one.
# shellcheck disable=SC2016 # the backticks are literal markdown
claude_list=$(awk '/^- \*\*Never edit\*\*/ {on = 1} on && /^$/ {exit} on' "$here/../../CLAUDE.md" \
  | grep -oE '`[^`]+`' | tr -d '`' | sort -u)
lane_list=$(printf '%s\n' "${PROTECTED[@]}" | sort -u)
if [[ -n "$claude_list" && "$claude_list" == "$lane_list" ]]; then
  echo "ok   PROTECTED matches CLAUDE.md's Never edit list"
else
  echo "FAIL PROTECTED vs CLAUDE.md: $(diff <(echo "$claude_list") <(echo "$lane_list") | grep '^[<>]' | paste -sd' ' -)"; fail=1
fi
for p in "${PROTECTED[@]}"; do
  f="$p"; [[ "$p" == */ ]] && f="${p}x.swift"
  check "refuses $f" "not-eligible|touches protected paths: $f" . "$f" .
done

# The worker's marker: a line `Fast-Check: pass`, then `Head: <full head sha>`.
mark() { printf '.body = "Closes #1\n\n%s\n%s"' "$1" "$2"; }
MARKED=$(mark "Fast-Check: pass" "Head: $HEAD_SHA")
check "marker on the head, no CI: eligible" "eligible|150|2|Fast-Check marker" "$MARKED" "$BASE_FILES" '[]'
check "the lane's own running check (no workflow name) is ignored" "eligible|150|2|Fast-Check marker" "$MARKED" \
  "$BASE_FILES" '[{"__typename":"CheckRun","name":"fast-lane","workflowName":"","status":"IN_PROGRESS","conclusion":""}]'
check "marker with stray spaces still counts" "eligible|150|2|Fast-Check marker" \
  "$(mark "  Fast-Check: pass " "Head: $HEAD_SHA  ")" "$BASE_FILES" '[]'
check "marker with CRLF line ends still counts" "eligible|150|2|Fast-Check marker" \
  '.body = "Closes #1\r\nFast-Check: pass\r\nHead: '"$HEAD_SHA"'\r\n"' "$BASE_FILES" '[]'
check "marker for an older head waits" "linux-dispatch|feat/x" \
  "$(mark "Fast-Check: pass" "Head: ffffffffffffffffffffffffffffffffffffffff")" "$BASE_FILES" '[]'
check "short sha in the marker waits" "linux-dispatch|feat/x" \
  "$(mark "Fast-Check: pass" "Head: ${HEAD_SHA:0:7}")" "$BASE_FILES" '[]'
check "Fast-Check: fail waits" "linux-dispatch|feat/x" \
  "$(mark "Fast-Check: fail" "Head: $HEAD_SHA")" "$BASE_FILES" '[]'
check "Head line apart from the Fast-Check line waits" "linux-dispatch|feat/x" \
  "$(mark "Fast-Check: pass" "x\nHead: $HEAD_SHA")" "$BASE_FILES" '[]'
check "Head line alone waits" "linux-dispatch|feat/x" \
  '.body = "Head: '"$HEAD_SHA"'"' "$BASE_FILES" '[]'
check "marker does not outrank a red check" "red|Linux" "$MARKED" "$BASE_FILES" \
  'map(if .name == "Linux" then .conclusion = "FAILURE" else . end)'
check "marker does not outrank a running check" "pending|1 checks still running" "$MARKED" "$BASE_FILES" \
  'map(if .name == "Linux" then .status = "IN_PROGRESS" | .conclusion = null else . end)'
check "marker does not outrank hard rules" "not-eligible|too big" "$MARKED | .additions = 999" "$BASE_FILES" '[]'
check "marker does not outrank a conflict" "conflict|$HEAD_SHA" \
  "$MARKED | .mergeable = \"CONFLICTING\" | .mergeStateStatus = \"DIRTY\"" "$BASE_FILES" '[]'
check "marker on a draft is skipped" "skip|PR is a draft" "$MARKED | .isDraft = true" "$BASE_FILES" '[]'

# CI's macOS jobs are report-only until beta (captain, 2026-10-16): a red or
# running `macOS` or `macOS (<app>)` check never holds a PR, and a green one
# is no proof; the proof is Linux-side. Shared shell files such as
# SuiteWindow.swift need only what any code PR needs: the marker and a build.
check "a red macOS check doesn't block" "eligible|150|2|4 checks green" . "$BASE_FILES" \
  'map(if .name == "macOS" then .conclusion = "FAILURE" else . end)'
check "a running macOS check doesn't block" "eligible|150|2|4 checks green" . "$BASE_FILES" \
  'map(if .name == "macOS" then .status = "IN_PROGRESS" | .conclusion = null else . end)'
check "a red scoped macOS check doesn't block" "eligible|150|2|Fast-Check marker" "$MARKED" "$BASE_FILES" \
  '[{"__typename":"CheckRun","name":"macOS (halo)","workflowName":"","status":"COMPLETED","conclusion":"FAILURE"}]'
check "a red journeys check doesn't block" "eligible|150|2|Fast-Check marker" "$MARKED" "$BASE_FILES" \
  '[{"__typename":"CheckRun","name":"macOS journeys","workflowName":"","status":"COMPLETED","conclusion":"FAILURE"}]'
check "a red scoped journeys check doesn't block" "eligible|150|2|Fast-Check marker" "$MARKED" "$BASE_FILES" \
  '[{"__typename":"CheckRun","name":"macOS journeys (photo)","workflowName":"","status":"COMPLETED","conclusion":"FAILURE"}]'
check "a journeys run waiting for a macOS slot doesn't block" "eligible|150|2|Fast-Check marker" "$MARKED" "$BASE_FILES" \
  '[{"__typename":"CheckRun","name":"Journeys wait","workflowName":"Journeys","status":"IN_PROGRESS","conclusion":null}]'
check "a green macOS check alone is no proof (a Linux check)" "linux-dispatch|feat/x" . "$BASE_FILES" \
  '[{"__typename":"CheckRun","name":"macOS","workflowName":"","status":"COMPLETED","conclusion":"SUCCESS"}]'
check "a green Linux check alone is proof" "eligible|150|2|1 checks green" . "$BASE_FILES" \
  '[{"__typename":"CheckRun","name":"Linux","workflowName":"","status":"COMPLETED","conclusion":"SUCCESS"}]'
check "a check merely named like macOS still counts" "red|macOS lint" . "$BASE_FILES" \
  '. + [{"__typename":"CheckRun","name":"macOS lint","workflowName":"","status":"COMPLETED","conclusion":"FAILURE"}]'
GATED=$'Sources/SuiteUI/SuiteWindow.swift\nTests/SuiteUITests/SuiteWindowTests.swift'
check "SuiteWindow.swift on the marker and a build: eligible, no macOS run (#1337)" \
  "eligible|150|2|Fast-Check marker, macOS build $BUILD_URL" "$MARKED" "$GATED" '[]'

# A supervisor's `Mac-Check: <run url>` line names a CI run; one whose macOS
# job passed on the head proves the build (build cases below). mac_judge:
RUN_URL="https://github.com/qbtrix/creative-apps/actions/runs/38700000001"
GREEN_RUN='{"workflowName":"CI","status":"completed","conclusion":"success","headSha":"'"$HEAD_SHA"'",
  "url":"'"$RUN_URL"'",
  "jobs":[{"name":"Linux","status":"completed","conclusion":"success"},
          {"name":"macOS","status":"completed","conclusion":"success"}]}'
MAC_PR="$MARKED | .body += \"\\nMac-Check: $RUN_URL\""
OLD_HEAD="ffffffffffffffffffffffffffffffffffffffff"
FAILED_MAC='.conclusion = "failure" | (.jobs[] | select(.name == "macOS")).conclusion = "failure"'
RUNNING='.status = "in_progress" | .conclusion = "" | (.jobs[] | select(.name == "macOS")) |= (.status = "in_progress" | .conclusion = "")'
judge() {  # judge <name> <want> <run jq>
  local got; jq "$3" <<<"$GREEN_RUN" >"$tmp/run.json"; got=$(mac_judge "$tmp/run.json" "$HEAD_SHA")
  if [[ "$got" == "$2" ]]; then echo "ok   judge: $1"; else echo "FAIL judge: $1: want '$2', got '$got'"; fail=1; fi
}
judge "a green run on the head passes" "" .
judge "a failed macOS job" "its macOS job is failure" "$FAILED_MAC"
judge "a running run" "its run has not completed" "$RUNNING"
judge "a skipped macOS job" "its macOS job is skipped" '(.jobs[] | select(.name == "macOS")).conclusion = "skipped"'
judge "no macOS job" "its run has no macOS job" '.jobs |= map(select(.name != "macOS"))'
judge "another workflow" "its run is the Fast Lane workflow, not CI" '.workflowName = "Fast Lane"'
judge "an older head" "its run is on $OLD_HEAD, not the head $HEAD_SHA" ".headSha = \"$OLD_HEAD\""
judge "an unreadable run" "its run could not be read" '{}'
jq "$MARKED | .body += \"\\n  Mac-Check:   $RUN_URL/job/123  \"" <<<"$BASE_PR" >"$tmp/pr.json"
got=$(mac_run_id "$(mac_check_url "$tmp/pr.json")")
if [[ "$got" == 38700000001 ]]; then echo "ok   judge: a job URL with spaces reads its run id"; else echo "FAIL judge: job URL: got '$got'"; fail=1; fi
got=$(mac_run_id "https://github.com/QBTRIX/Creative-Apps/actions/runs/38700000001")
if [[ "$got" == 38700000001 ]]; then echo "ok   judge: an upper-case repo URL reads"; else echo "FAIL judge: upper-case URL: got '$got'"; fail=1; fi
got=$(mac_run_id "https://github.com/someone/creative-apps/actions/runs/1")
if [[ -z "$got" ]]; then echo "ok   judge: another repo's run is no run"; else echo "FAIL judge: another repo: got '$got'"; fail=1; fi
if shopt -q nocasematch; then echo "FAIL judge: mac_run_id leaves nocasematch on"; fail=1; else echo "ok   judge: mac_run_id restores nocasematch"; fi
echo '[]' >"$tmp/empty.json"

# The macOS build gate (lesson 114, #1210): a PR changing code (BUILD_RE)
# merges only once a build-only CI run (ci.yml's build_only
# input, run title "macOS build") compiled its head; the lane dispatches it.
# build <name> <want> <pr jq> <files> <build run jq on a green build, or -> [<checks json> [<Mac-Check run jq>]]
APP=$'Sources/LibraryApp/LibraryInspector.swift\nSources/LibraryModel/LibraryCatalog.swift'
build() {
  local got
  jq "$3" <<<"$BASE_PR" >"$tmp/pr.json"; printf '%s\n' "$4" >"$tmp/files.txt"; echo '{}' >"$tmp/run.json"
  [[ -z "${7:-}" ]] || jq "$7" <<<"$GREEN_RUN" >"$tmp/run.json"
  if [[ "$5" == - ]]; then echo '{}' >"$tmp/build.json"; else jq "$5" <<<"$GREEN_BUILD" >"$tmp/build.json"; fi
  printf '%s\n' "${6:-[]}" >"$tmp/bchecks.json"
  got=$(decide "$tmp/pr.json" "$tmp/files.txt" "$tmp/bchecks.json" "" "" "$tmp/run.json" "$tmp/run.json" "$tmp/build.json" 2>/dev/null)
  if [[ "$got" == "$2"* ]]; then echo "ok   build: $1 -> ${got:0:110}"; else echo "FAIL build: $1: want '$2*', got '$got'"; fail=1; fi
}
BREFUSE="build-gate|changes code (Sources/LibraryApp, Sources/LibraryModel), and its head $HEAD_SHA doesn't build on macOS: $BUILD_URL"
build "app code with no build on the head: the lane dispatches one" "build-dispatch|Sources/LibraryApp, Sources/LibraryModel|feat/x" "$MARKED" "$APP" -
build "a build on an older head counts as none" "build-dispatch|Sources/LibraryApp, Sources/LibraryModel|feat/x" "$MARKED" "$APP" ".headSha = \"$OLD_HEAD\""
build "every app folder is named" "build-dispatch|Sources/FlareApp, Sources/LibraryApp|feat/x" "$MARKED" \
  $'Sources/LibraryApp/A.swift\nSources/FlareApp/B.swift\nSources/LibraryApp/C.swift' -
build "a rename names both folders" "build-dispatch|Sources/HaloApp, Sources/HaloModel|feat/x" "$MARKED" $'Sources/HaloModel/X.swift\nSources/HaloApp/X.swift' -
build "the build still going: waits, no second dispatch" "pending|waiting for the macOS build $BUILD_URL on head $HEAD_SHA" \
  "$MARKED" "$APP" '.status = "in_progress" | .conclusion = ""'
build "the build compiled the head: eligible" "eligible|150|2|Fast-Check marker, macOS build $BUILD_URL" "$MARKED" "$APP" .
build "the build failed: refused, with what to do" \
  "$BREFUSE (failure). Fix it and push; the lane builds the new head on macOS again" "$MARKED" "$APP" '.conclusion = "failure"'
# A queued or running build waits; a re-dispatch would cancel it (ci.yml's
# per-branch -build concurrency group). A cancelled one is dispatched again
# once BUILD_RETRY_SECS after it was cancelled, and waits until then.
build "a queued build waits, no second dispatch" "pending|waiting for the macOS build $BUILD_URL on head $HEAD_SHA" \
  "$MARKED" "$APP" '.status = "queued" | .conclusion = ""'
build "a build pending on its concurrency group waits" "pending|waiting for the macOS build $BUILD_URL on head $HEAD_SHA" \
  "$MARKED" "$APP" '.status = "pending" | .conclusion = ""'
build "a build cancelled minutes ago waits" "pending|waiting for the macOS build $BUILD_URL on head $HEAD_SHA" \
  "$MARKED" "$APP" '.conclusion = "cancelled" | .updatedAt = (now - 300 | todate)'
build "a build cancelled past the interval is dispatched again" "build-dispatch|Sources/LibraryApp, Sources/LibraryModel|feat/x" \
  "$MARKED" "$APP" '.conclusion = "cancelled" | .updatedAt = (now - 7200 | todate)'
build "a red macOS build check is the gate's to name, not just red" "$BREFUSE (failure)" "$MARKED" "$APP" '.conclusion = "failure"' \
  '[{"__typename":"CheckRun","name":"macOS build","workflowName":"","status":"COMPLETED","conclusion":"FAILURE"},
    {"__typename":"CheckRun","name":"Linux","workflowName":"","status":"COMPLETED","conclusion":"SKIPPED"},
    {"__typename":"CheckRun","name":"macOS","workflowName":"","status":"COMPLETED","conclusion":"SKIPPED"}]'
# Linux compiles the Models, but not always the way macOS does: #1210's
# ObjCBool error in PhotoModel broke only the macOS build. So a Model gets it too.
build "a Model-only PR gets the build (#1210)" "build-dispatch|Sources/FlareModel, Tests/FlareModelTests|feat/x" "$MARKED" "$BASE_FILES" -
build "a Model-only PR whose head built: eligible" "eligible|150|2|Fast-Check marker, macOS build $BUILD_URL" "$MARKED" "$BASE_FILES" .
build "a Model that doesn't build on macOS is refused" \
  "build-gate|changes code (Sources/PhotoModel), and its head $HEAD_SHA doesn't build on macOS: $BUILD_URL (failure)" \
  "$MARKED" 'Sources/PhotoModel/PhotoRecovery.swift' '.conclusion = "failure"'
# Every target gets the build, each on its own (run 38732179619: a snapshot
# test broke the macOS build, #1097).
build "only a snapshot test (#1097): the build" "build-dispatch|Tests/AppSnapshotTests|feat/x" "$MARKED" 'Tests/AppSnapshotTests/HaloPlaybackDriverTests.swift' -
build "only a UI journey: the build" "build-dispatch|UITests|feat/x" "$MARKED" 'UITests/HaloJourneyTests+Layers.swift' -
build "only a SuiteUI test: the build" "build-dispatch|Tests/SuiteUITests|feat/x" "$MARKED" 'Tests/SuiteUITests/TokensTests.swift' -
build "only SuiteUI: the build" "build-dispatch|Sources/SuiteUI|feat/x" "$MARKED" 'Sources/SuiteUI/GlassPanel.swift' -
build "a shared shell file: the build, no full macOS run" "build-dispatch|Sources/SuiteUI|feat/x" "$MARKED" 'Sources/SuiteUI/SuiteWindow.swift' -
build "a Mac-Check run with a failed macOS job falls back to the build" "eligible|150|2|Fast-Check marker, macOS build $BUILD_URL" \
  "$MAC_PR" "$APP" . '[]' "$FAILED_MAC"
build "only project.yml: the build" "build-dispatch|project.yml|feat/x" "$MARKED" 'project.yml' -
build "only an app: the build" "build-dispatch|Sources/PhotoApp|feat/x" "$MARKED" 'Sources/PhotoApp/PhotoApp.swift' -
build "the audit baseline is data, not code: no build" "eligible|150|2|Fast-Check marker" "$MARKED" 'UITests/audit-baseline.json' -
build "the audit's checks (a Linux target): the build" "build-dispatch|Tests/AppAuditTests|feat/x" "$MARKED" 'Tests/AppAuditTests/Checks/Overlap.swift' -
build "a doc about project.yml: no build" "eligible|150|2|Fast-Check marker" "$MARKED" $'docs/project.yml.md\nproject.yml.bak' -
build "a docs-only PR: no build" "eligible|150|2|Fast-Check marker" "$MARKED" $'docs/factory/lead.md\ndocs/blueprints/halo/features/easing.wave.json' -
build "Swift outside the source roots, or no Swift there: no build" "eligible|150|2|Fast-Check marker" "$MARKED" \
  $'docs/Sources/A.swift\nTests/fast_lane/checks-green.json\nSources/FlareModel/README.md\nUITests/notes.swift.md' -
printf '%s\n' Package.swift project.yml UITests/A.swift Sources/X.swift >"$tmp/files.txt"
got=$(build_paths "$tmp/files.txt")
if [[ "$got" == "Package.swift, Sources/X.swift, UITests, project.yml" ]]; then echo "ok   build: build_paths names the manifests and folders"
else echo "FAIL build: build_paths: got '$got'"; fail=1; fi
# The build is scoped to the apps the code touches (build_apps, main's
# scripts/test-scope build-apps); a shared path, or a failure to tell, builds all.
build "one app's code: the build names that app" "build-dispatch|Sources/LibraryApp, Sources/LibraryModel|feat/x|library" "$MARKED" "$APP" -
build "a shared path: the build covers every app" "build-dispatch|Sources/PhotoApp, Sources/SuiteUI|feat/x|all" "$MARKED" \
  $'Sources/PhotoApp/A.swift\nSources/SuiteUI/B.swift' -
build "two apps' code: the build covers both" "build-dispatch|Sources/FlareApp, Sources/LibraryApp|feat/x|flare,library" "$MARKED" \
  $'Sources/LibraryApp/A.swift\nSources/FlareApp/B.swift' -
build "project.yml: the build covers every app" "build-dispatch|project.yml|feat/x|all" "$MARKED" 'project.yml' -
HERE_WAS=$HERE; HERE="$tmp/no-scripts"
build "no scripts/test-scope to ask: the build covers every app" "build-dispatch|Sources/PhotoApp|feat/x|all" "$MARKED" 'Sources/PhotoApp/PhotoApp.swift' -
HERE=$HERE_WAS
build "the build gate does not outrank the proof: a Linux check first" "linux-dispatch|feat/x" ".body = \"x\"" "$APP" .
build "a supervisor's green Mac-Check run covers the build" "eligible|150|2|Fast-Check marker, Mac-Check: $RUN_URL" "$MAC_PR" "$APP" - '[]' .
# Every source the manifests compile falls under BUILD_RE: each Package.swift
# target with its `#if os(macOS)` block switched on (swift package
# dump-package; a Mac and a Linux runner read it the same way), and each
# project.yml source.
if command -v swift >/dev/null 2>&1; then
  root="$here/../.."
  mkdir -p "$tmp/allmac"
  sed 's/^#if os(macOS)$/#if true/' "$root/Package.swift" >"$tmp/allmac/Package.swift"
  srcs=$( { (cd "$tmp/allmac" && swift package dump-package 2>/dev/null) | jq -r '.targets[]
      | .path // ((if .type == "test" then "Tests/" else "Sources/" end) + .name)'
    grep -oE '^ *- (path: )?[^ ]+' "$root/project.yml" | sed -E 's/^ *- (path: )?//'; } | sort -u)
  bad=""
  [[ $(echo "$srcs" | wc -l) -ge 15 ]] || bad+=" the manifests didn't parse;"
  while IFS= read -r d; do
    f="$d/x.swift"; [[ "$d" != *.swift ]] || f="$d"
    grep -qE "$BUILD_RE" <<<"$f" || bad+=" $d is compiled but not in BUILD_RE;"
  done <<<"$srcs"
  if [[ -z "$bad" ]]; then echo "ok   build: BUILD_RE covers every source in the manifests ($(echo "$srcs" | wc -l | tr -d ' '))"
  else echo "FAIL build: BUILD_RE vs the manifests:$bad"; fail=1; fi
else
  echo "skip build: no swift here to read Package.swift; BUILD_RE vs the manifests unchecked"
fi

# Belt PRs (a body line starting Belt-Run: or Belt-Test:) also need Belt's
# belt/review commit status at success on the head; other PRs ignore it.
BELT='.body = "Closes #1\n\nBelt-Run: act-1"'
review() { printf '. + [{"__typename":"StatusContext","context":"belt/review","state":"%s"}]' "$1"; }
# The review gate cases run with the gate on; the shipped default may be off.
REQUIRE_BELT_REVIEW=1
check "belt PR, review missing: waits" "pending|waiting for review" "$BELT" "$BASE_FILES" .
check "belt PR, review pending: waits" "pending|waiting for review" "$BELT" "$BASE_FILES" "$(review PENDING)"
check "belt PR, review success: eligible" "eligible|150|2|4 checks green" "$BELT" "$BASE_FILES" "$(review SUCCESS)"
check "belt PR, review failure: red" "red|review failed" "$BELT" "$BASE_FILES" "$(review FAILURE)"
check "belt PR, review error: red" "red|review failed" "$BELT" "$BASE_FILES" "$(review ERROR)"
check "a Belt-Test line makes a belt PR too" "pending|waiting for review" '.body = "Belt-Test: t-9"' "$BASE_FILES" .
check "red CI outranks the review" "red|Linux" "$BELT" "$BASE_FILES" \
  "$(review SUCCESS) | map(if .name == \"Linux\" then .conclusion = \"FAILURE\" else . end)"
check "non-belt PR ignores belt/review" "eligible|150|2|4 checks green" . "$BASE_FILES" "$(review FAILURE)"
check "belt PR with a marker still waits for review" "pending|waiting for review" \
  "$BELT | .body += \"\\nFast-Check: pass\\nHead: $HEAD_SHA\"" "$BASE_FILES" '[]'
REQUIRE_BELT_REVIEW=0
check "gate off: belt PR needs no review" "eligible|150|2|4 checks green" "$BELT" "$BASE_FILES" .
REQUIRE_BELT_REVIEW=1

# strip_attribution drops the footer cloud sessions add to PR bodies and keeps the rest.
body=$'Fixes the thing.\n\nCloses #1\n\n---\n_Generated by [Claude Code](https://claude.ai/code/session_x)_'
got=$(printf '%s\n' "$body" | strip_attribution)
if [[ "$got" == *"Closes #1"* && "$got" != *"Generated by"* ]]; then
  echo "ok   strip_attribution drops the cloud footer"
else
  echo "FAIL strip_attribution: got '$got'"; fail=1
fi
# Every attribution form leads and commits carry goes; a human co-author stays.
body=$'Fixes the thing.\n\nGenerated by Claude Code\n🤖 Generated with [Claude Code](https://claude.com/claude-code)\nCo-Authored-By: Claude <noreply@anthropic.com>\nco-authored-by: Claude Opus 5.5 <noreply@anthropic.com>\nCo-authored-by: Jane Doe <jane@example.com>'
got=$(printf '%s\n' "$body" | strip_attribution | paste -sd'|' -)
if [[ "$got" == "Fixes the thing.||Co-authored-by: Jane Doe <jane@example.com>" ]]; then
  echo "ok   strip_attribution drops the plain, robot and Co-Authored-By: Claude lines"
else
  echo "FAIL strip_attribution: got '$got'"; fail=1
fi
got=$(printf '%s\n' "$body" | LC_ALL=C strip_attribution | grep -c 'Generated' || true)
if [[ "$got" == 0 ]]; then echo "ok   strip_attribution works in the C locale"; else echo "FAIL strip_attribution under LC_ALL=C kept $got line(s)"; fail=1; fi

# lead_refs <issues>: the closing keyword before each listed issue (a
# feature-lead issue, as owner/repo#n) becomes Refs; every other one stays.
# closing_refs lists the issues a body's closing keywords point at.
F12="qbtrix/creative-apps#12"
refs() {  # refs <name> <want> <issues, one per line> <body lines...>
  local name="$1" want="$2" feats="$3" got; shift 3
  got=$(printf '%s\n' "$@" | lead_refs "$feats" | paste -sd'|' -)
  if [[ "$got" == "$want" ]]; then echo "ok   refs: $name"; else echo "FAIL refs: $name: want '$want', got '$got'"; fail=1; fi
}
refs "only the feature issue's keyword becomes Refs" "Refs #12, fixes #13|Feature: x" "$F12" "Closes #12, fixes #13" "Feature: x"
refs "every keyword form, any case, colon or not" \
  "Refs #12|Refs #13, Refs #14|Refs #15|Refs qbtrix/creative-core#16|Refs https://github.com/qbtrix/creative-apps/issues/17|Refs #18. Refs #19, Refs #20" \
  "$(printf 'qbtrix/creative-apps#%s\n' 12 13 14 15 17 18 19 20; echo qbtrix/creative-core#16)" \
  "Closes #12" "fixes: #13, Resolved #14" "CLOSE:#15" "closed qbtrix/creative-core#16" \
  "Fix https://github.com/qbtrix/creative-apps/issues/17" "FIXED #18. resolve  #19, Resolves: #20"
refs "the same number in another repo is another issue" "Fixes qbtrix/creative-core#12|Refs qbtrix/creative-apps#12" "$F12" \
  "Fixes qbtrix/creative-core#12" "Fixes qbtrix/creative-apps#12"
refs "words that only contain a keyword, or no reference, stay" \
  "prefixes #1, suffixed #2, fixed-width #3; closes the gap; see #4|Refs #5" \
  "$(printf 'qbtrix/creative-apps#%s\n' 1 2 3 4 5)" "prefixes #1, suffixed #2, fixed-width #3; closes the gap; see #4" "Refs #5"
refs "a CRLF body" "$(printf 'Refs #12\r|Fixes #13\r')" "$F12" "$(printf 'Closes #12\r')" "$(printf 'Fixes #13\r')"
refs "no feature issue: the body is unchanged" "Closes #12, fixes #13" "" "Closes #12, fixes #13"
lead_body=$'Adds keyframes.\n\nCloses #12, fixes #13\n\nBelt-Lead: r1\nFeature: halo-keyframes\nFast-Check: pass\nHead: h40'
once=$(lead_refs "$F12" <<<"$lead_body")
if [[ "$(lead_refs "$F12" <<<"$once")" == "$once" && "$once" == *$'\nRefs #12, fixes #13\n'* ]]; then echo "ok   refs: idempotent"
else echo "FAIL refs: a second pass changes the body: '$once'"; fail=1; fi
got=$(printf '%s\n' "Closes #12, fixes qbtrix/creative-core#3" "Resolves https://github.com/qbtrix/creative-apps/issues/14, see #15" "Refs #16" | closing_refs | paste -sd' ' -)
if [[ "$got" == "qbtrix/creative-apps#12 qbtrix/creative-apps#14 qbtrix/creative-core#3" ]]; then echo "ok   refs: closing_refs lists the closed issues"
else echo "FAIL refs: closing_refs: got '$got'"; fail=1; fi

# With the gate off, a Belt PR with no review is eligible like any other.
REQUIRE_BELT_REVIEW=0
check "gate off: belt PR without review is eligible" "eligible|150|2|4 checks green" '.body = "x\nBelt-Run: act-1"' "$BASE_FILES" .

# The app audit guard. audit_tree <dir> <baseline> <registry entries> <checks...>
# writes an audit tree; "-" leaves the baseline or AuditCore.swift out, and a
# check `Name=id` becomes Checks/Name.swift declaring `struct Name: Check` with
# that id. Each case builds a before tree $b and an after tree $a.
AD="Tests/PhotoModelTests/AppAudit"
BL='{ "photo": { "identifier": 54, "overlap": 1 }, "halo": { "contrast": 2 } }'
REG="DisabledDim(), Overlap(), TextContrast(), Identifier(), Offscreen(), Unnamed()"
CHECKS=(DisabledDim=disabled-dim Overlap=overlap TextContrast=contrast Identifier=identifier Offscreen=offscreen Unnamed=unnamed)
b="$tmp/before" a="$tmp/after"
audit_tree() {
  local d="$1" bl="$2" reg="$3" dir="${AUDIT_DIR:-$AD}" f; shift 3
  rm -rf "$d"; mkdir -p "$d/UITests" "$d/$dir/Checks"
  [[ "$bl" == - ]] || printf '%s\n' "$bl" >"$d/$AUDIT_BASELINE"
  [[ "$reg" == - ]] || printf 'extension AppAudit {\n    static let checks: [any Check] = [%s]\n}\n' "$reg" >"$d/$dir/AuditCore.swift"
  for f; do
    [[ -n "$f" ]] || continue
    printf 'extension AppAudit {\n    struct %s: Check {\n        let id = "%s"\n    }\n}\n' "${f%%=*}" "${f#*=}" \
      >"$d/$dir/Checks/${f%%=*}.swift"
  done
}
loosens() {  # loosens <name> <want: lines joined by ", ", empty = not looser>
  local got
  got=$(audit_loosens "$b" "$a" | paste -sd, - | sed 's/,/, /g')
  if [[ "$got" == "$2" ]]; then echo "ok   audit: $1"; else echo "FAIL audit: $1: want '$2', got '$got'"; fail=1; fi
}
same() { audit_tree "$b" "$BL" "$REG" "${CHECKS[@]}"; audit_tree "$a" "$1" "${2:-$REG}" "${CHECKS[@]}"; }

same "$BL"; loosens "nothing changed" ""
same '{ "photo": { "identifier": 55, "overlap": 1 }, "halo": { "contrast": 2 } }'
loosens "a raised count" "photo identifier 54 -> 55"
same '{ "photo": { "identifier": 53, "overlap": 0 }, "halo": { "contrast": 1 } }'
loosens "lowered counts" ""
same '{ "photo": { "identifier": 54 }, "halo": { "contrast": 2 } }'
loosens "a check key left out of an app is 0, so lower" ""
same '{ "photo": { "identifier": 54, "overlap": 1, "contrast": 3 }, "halo": { "contrast": 2 } }'
loosens "an existing check's key new to an app above 0 is a raise from 0" "photo contrast new -> 3"
same '{ "photo": { "identifier": 54, "overlap": 1, "contrast": 0 }, "halo": { "contrast": 2 } }'
loosens "a new check key at 0" ""
same '{ "photo": { "identifier": 54, "overlap": 1 }, "halo": { "contrast": 2 }, "suite": { "identifier": 4 } }'
loosens "a new app above 0" "suite identifier new -> 4"
same '{ "photo": { "identifier": 54, "overlap": 1 }, "halo": { "contrast": 2 }, "suite": { "identifier": 0 } }'
loosens "a new app at 0" ""
same '{ "photo": { "identifier": 54, "overlap": 1 } }'
loosens "a dropped app is no longer judged" "drops halo from the baseline"
audit_tree "$b" "$BL" "$REG" "${CHECKS[@]}"; audit_tree "$a" - "$REG" "${CHECKS[@]}"
loosens "a deleted baseline drops every app" "drops halo from the baseline, drops photo from the baseline"
same '{ "photo": { "identifier": 54, '
loosens "a broken baseline" "the baseline is not valid JSON"
same '{ "photo": { "identifier": "99" }, "halo": { "contrast": 2 } }'
loosens "a count that is not a number" "the baseline is not app -> check -> count"
audit_tree "$b" "$BL" "$REG" "${CHECKS[@]}"; audit_tree "$a" "$BL" "$REG" "${CHECKS[@]/Overlap=overlap}"
loosens "a removed check file" "removes $AD/Checks/Overlap.swift"
audit_tree "$b" "$BL" "$REG" "${CHECKS[@]}"; audit_tree "$a" "$BL" "$REG, Focus()" "${CHECKS[@]}" Focus=focus
loosens "an added check" ""
# A new check's keys may start at any count in existing apps, when the same PR
# adds its file and its registry entry (any check is stricter than none).
FOCUS_BL='{ "photo": { "identifier": 54, "overlap": 1, "focus": 7 }, "halo": { "contrast": 2, "focus": 2 } }'
added() {  # added <after baseline> <after registry> <checks beyond CHECKS...>
  local bl="$1" reg="$2"; shift 2
  audit_tree "$b" "$BL" "$REG" "${CHECKS[@]}"; audit_tree "$a" "$bl" "$reg" "${CHECKS[@]}" "$@"
}
added "$FOCUS_BL" "$REG, Focus()" Focus=focus
loosens "a new check with its keys above 0 in existing apps" ""
added "$FOCUS_BL" "$REG" Focus=focus
loosens "a new check file without a registry entry" "photo focus new -> 7, halo focus new -> 2"
added "$FOCUS_BL" "$REG, Focus()"
loosens "a registry entry without a new check file" "photo focus new -> 7, halo focus new -> 2"
added '{ "photo": { "identifier": 54, "overlap": 1, "blur": 3 }, "halo": { "contrast": 2 } }' "$REG, Focus()" Focus=focus
loosens "a new key that isn't the new check's id" "photo blur new -> 3"
added '{ "photo": { "identifier": 54, "overlap": 1, "disabled-dim": 5 }, "halo": { "contrast": 2 } }' "$REG, Dim2()" Dim2=disabled-dim
loosens "a new check reusing an existing check's id" "photo disabled-dim new -> 5"
added '{ "photo": { "identifier": 54, "overlap": 1 }, "halo": { "contrast": 2 }, "suite": { "focus": 4 } }' "$REG, Focus()" Focus=focus
loosens "a new app above 0 stays refused, even for a new check" "suite focus new -> 4"
added '{ "photo": { "identifier": 55, "overlap": 1, "focus": 7 }, "halo": { "contrast": 2 } }' "$REG, Focus()" Focus=focus
loosens "a new check doesn't cover a raise of an existing key" "photo identifier 54 -> 55"
same "$BL" "DisabledDim(), TextContrast(), Identifier(), Offscreen(), Unnamed()"
loosens "an entry dropped from AppAudit.checks" "drops Overlap from AppAudit.checks"
same "$BL" $'\n        DisabledDim(),\n        // Overlap(),\n        TextContrast(), Identifier(), /* Offscreen(), */ Unnamed(),\n    '
loosens "entries commented out" "drops Offscreen from AppAudit.checks, drops Overlap from AppAudit.checks"
same "$BL" $'\n        DisabledDim(), Overlap(),\n        TextContrast(), Identifier(), Offscreen(), Unnamed(),\n    '
loosens "the same registry over several lines" ""
same "$BL" -
loosens "AuditCore.swift deleted" "$(printf '%s\n' "${CHECKS[@]%%=*}" | sort | sed 's/.*/drops & from AppAudit.checks/' | paste -sd, - | sed 's/,/, /g')"
same "$BL" "$REG] + [Overlap(), TextContrast()]; let decoy: [any Check] = [] ; static let checks: [any Check] = [DisabledDim()"
loosens "a second list in AuditCore.swift" "AppAudit.checks is declared 2 times"
audit_tree "$b" "$BL" "$REG" "${CHECKS[@]}"; AUDIT_DIR=Tests/AppAuditTests audit_tree "$a" "$BL" "$REG" "${CHECKS[@]}"
loosens "moving a check file counts as removing it (the target move is captain-reviewed)" \
  "$(printf "removes $AD/Checks/%s.swift\n" "${CHECKS[@]%%=*}" | sort | paste -sd, - | sed 's/,/, /g')"
AUDIT_DIR=Tests/AppAuditTests audit_tree "$b" "$BL" "$REG" "${CHECKS[@]}"; AUDIT_DIR=Tests/AppAuditTests audit_tree "$a" "$BL" "$REG" Focus=focus "${CHECKS[@]}"
loosens "the new home is guarded the same way" ""

# The repo's own registry must parse, or the guard can't see a dropped entry.
if [[ $(audit_registry "$here/../../Tests" | wc -l) -ge 6 ]]; then
  echo "ok   audit: the repo's AppAudit.checks parses"
else
  echo "FAIL audit: audit_registry finds no AppAudit.checks list under Tests/; fix its pattern"; fail=1
fi

# decide takes the two trees as its 4th and 5th arguments.
audit_decide() {  # audit_decide <name> <exact want> [<changed files>]
  local got
  jq . <<<"$BASE_PR" >"$tmp/pr.json"; printf '%s\n' "${3:-$AUDIT_BASELINE}" >"$tmp/files.txt"
  got=$(decide "$tmp/pr.json" "$tmp/files.txt" "$here/checks-green.json" "$b" "$a" "" "" "$tmp/gbuild.json" 2>/dev/null)
  if [[ "$got" == "$2" ]]; then echo "ok   $1 -> $got"; else echo "FAIL $1: want '$2', got '$got'"; fail=1; fi
}
same '{ "photo": { "identifier": 55, "overlap": 0 }, "halo": { "contrast": 2 } }'
audit_decide "decide: a looser audit is not eligible" \
  "not-eligible|loosens the app audit: needs the captain's review (photo identifier 54 -> 55)"
same '{ "photo": { "identifier": 50, "overlap": 0 }, "halo": { "contrast": 2 } }'
audit_decide "decide: a lowered baseline is eligible" "eligible|150|2|4 checks green"
# Like #292: baselines for checks it adds, plus a scripts/ui-test change. Only
# the script keeps it off the lane.
added "$FOCUS_BL" "$REG, Focus()" Focus=focus
audit_decide "decide: #292-style, new check baselines pass, the script doesn't" \
  "not-eligible|touches protected paths: scripts/ui-test" \
  "$(printf '%s\n' "$AUDIT_BASELINE" "$AD/AuditCore.swift" "$AD/Checks/Focus.swift" scripts/ui-test)"
audit_decide "decide: the same without the script is eligible" "eligible|150|2|4 checks green, macOS build $BUILD_URL" \
  "$(printf '%s\n' "$AUDIT_BASELINE" "$AD/AuditCore.swift" "$AD/Checks/Focus.swift")"

# Canonical first (lead.md rule 20): decide's 9th argument lists the PR's
# added files; an added concept file needs an Allow-Dup line for its concept.
dup_decide() {  # dup_decide <name> <want prefix> <body> <added files>
  local got
  jq --arg b "$3" '.body = $b' <<<"$BASE_PR" >"$tmp/pr.json"
  printf '%s\n' "$4" >"$tmp/files.txt"; printf '%s\n' "$4" >"$tmp/added.txt"
  got=$(decide "$tmp/pr.json" "$tmp/files.txt" "$here/checks-green.json" "" "" "" "" "$tmp/gbuild.json" "$tmp/added.txt" 2>/dev/null)
  if [[ "$got" == "$2"* ]]; then echo "ok   $1 -> $got"; else echo "FAIL $1: want '$2*', got '$got'"; fail=1; fi
}
dup_decide "canonical: a new app-local undo stack is not eligible" \
  "not-eligible|$DUP_REASON: Sources/HaloModel/HaloUndoStack.swift (Undo)" "Closes #1" 'Sources/HaloModel/HaloUndoStack.swift'
dup_decide "canonical: Allow-Dup with a reason lets it through" "eligible|150|2|4 checks green" \
  $'Closes #1\nAllow-Dup: Undo the kernel lands in #2000' 'Sources/HaloModel/HaloUndoStack.swift'
dup_decide "canonical: an adapter onto the kernel is eligible" "eligible|150|2|4 checks green" "Closes #1" 'Sources/HaloModel/HaloHistory+Kernel.swift'
dup_decide "canonical: SuiteModel is the home, so it is eligible" "eligible|150|2|4 checks green" "Closes #1" 'Sources/SuiteModel/History/UndoStack.swift'
dup_decide "canonical: Snapshot is not Snap" "eligible|150|2|4 checks green" "Closes #1" 'Sources/PhotoApp/PhotoSnapshotGrid.swift'
HERE="$tmp/no-scripts" dup_decide "canonical: a lane that can't run the check waits" \
  "pending|scripts/check-dup-logic could not run" "Closes #1" 'Sources/PhotoModel/PhotoDocument.swift'
# SuiteUI first (lead.md rules 16 and 20): an added app file named for a UI
# concept needs an Allow-Dup-View line for it.
dup_decide "suiteui: a new app sheet is not eligible" \
  "not-eligible|$DUP_VIEW_REASON: Sources/HaloApp/HaloRenderSheet.swift (Sheet)" "Closes #1" 'Sources/HaloApp/HaloRenderSheet.swift'
dup_decide "suiteui: Allow-Dup-View with a reason lets it through" "eligible|150|2|4 checks green" \
  $'Closes #1\nAllow-Dup-View: Sheet SuiteSheet lands in #2001' 'Sources/HaloApp/HaloRenderSheet.swift'
dup_decide "suiteui: SuiteUI is the home, and +Suite adapters pass" "eligible|150|2|4 checks green" "Closes #1" \
  "$(printf '%s\n' Sources/SuiteUI/SuiteSheet.swift Sources/HaloApp/HaloRender+Suite.swift)"

# A whole sweep against a stub `gh` that answers from per-PR fixtures and logs
# every write: #4 and #7 are eligible, #5 is based on main, #6 conflicts.
# sweep <PRs labelled feature-done> runs main() and leaves the writes in $sw/calls.
# Files come from $sw/files.<n>.json (raw API shape, the lane's --jq applied),
# the merge base is `mb` (`bad` for a head whose compare fails), and the trees
# and contents for a commit are the files under $sw/refs/<sha>.
sw="$tmp/sweep"
# real_pr <n> [<path>] [<branch>]: gives fixture PR <n> a real branch (feat/<n>
# unless <branch> names another) at the test's bare remote $sw/origin.git (one
# file on top of dev, a docs file unless <path> names another), so the lane
# can batch it, or land it alone after comparing it with dev: headRefName,
# headRefOid and the body's Head: line move to that commit, and an audit tree
# or build run keyed by the old head follows it.
real_pr() {
  local n="$1" f old sha w="$sw/work"
  f="$sw/$n.json"
  if [[ ! -d "$sw/origin.git" ]]; then
    git init -q --bare "$sw/origin.git"; git -C "$sw/origin.git" config uploadpack.allowFilter true
    git init -q -b dev "$w"; git -C "$w" config user.name t; git -C "$w" config user.email t@t; git -C "$w" config commit.gpgsign false
    cp "$here/../../.gitattributes" "$w/"; echo base >"$w/base.md"
    git -C "$w" add -A; git -C "$w" commit -qm base; git -C "$w" push -q "$sw/origin.git" dev
  fi
  local p="${2:-pr$n.md}" b="${3:-feat/$n}"
  git -C "$w" switch -qc "$b" dev; mkdir -p "$w/$(dirname "$p")"; echo "pr $n" >"$w/$p"; git -C "$w" add -A; git -C "$w" commit -qm "pr $n"
  git -C "$w" push -q "$sw/origin.git" "$b"; git -C "$w" switch -q dev
  sha=$(git -C "$w" rev-parse "$b"); old=$(jq -r .headRefOid "$f")
  jq --arg b "$b" --arg h "$sha" '.headRefName = $b | .headRefOid = $h | .body |= sub("Head: [^\n]*"; "Head: \($h)")' "$f" >"$sw/x" && mv "$sw/x" "$f"
  [[ ! -d "$sw/refs/$old" ]] || mv "$sw/refs/$old" "$sw/refs/$sha"
  [[ ! -e "$sw/runs.$old.json" ]] || jq --arg h "$sha" 'map(.headSha = $h)' "$sw/runs.$old.json" >"$sw/runs.$sha.json"
}
# The batch at the bare remote: its tip, a probe's sha, and a Linux verdict on a sha.
batch_tip() { git -C "$sw/origin.git" for-each-ref 'refs/heads/lane/batch-*' --format='%(objectname) %(refname:short)' 2>/dev/null | awk '$2 ~ /^lane\/batch-[0-9]+$/ { print $1 }'; }
probe_sha() { git -C "$sw/origin.git" for-each-ref "refs/heads/lane/batch-*-$1" --format='%(objectname)' 2>/dev/null; }
verdict() {  # verdict <sha> <success|failure|in_progress>
  local st=completed c="\"$2\""
  [[ "$2" != in_progress ]] || { st=in_progress; c=null; }
  jq -n --arg s "$st" --argjson c "$c" '[{name: "Linux", status: $s, conclusion: $c, started_at: "2026-01-01T00:00:00Z",
    details_url: "https://github.com/qbtrix/creative-apps/actions/runs/777"}]' >"$sw/checks.$1.json"
}
batch_green() { verdict "$(batch_tip)" success; }
REMOTE="$sw/origin.git"
gh() {
  local a="$*" n u
  case "$a" in
    "pr list "*)  # every open PR in the --json shape; the lane picks the labelled ones itself
      u=()
      for n in "$sw"/[0-9]*.json; do
        [[ ! -e "$n" || -e "${n%.json}.merged" ]] || u+=("$n")
      done
      if (( ${#u[@]} )); then jq -s . "${u[@]}"; else echo '[]'; fi ;;
    "pr view "*"--json title "*) echo "title $2" ;;
    "pr view "*"--json headRefName "*) jq -r .headRefName "$sw/$3.json" ;;
    "pr view "*"--json body "*) jq -r .body "$sw/$3.json" ;;
    "pr view "*"--json closingIssuesReferences "*) cat "$sw/$3.closes" 2>/dev/null || true ;;
    "pr view "*) live_pr "$3" ;;
    "api "*"/check-runs"*) u="${2#*/commits/}"; u="${u%%/*}"; cat "$sw/checks.$u.json" 2>/dev/null || echo '[]' ;;
    "api "*"/status "*)  # a commit's statuses: $sw/status.<sha>.json ({statuses: [...]}), none if absent
      u="${2#*/commits/}"; u="${u%%/*}"
      jq -r "${!#}" "$sw/status.$u.json" 2>/dev/null || jq -rn '{statuses: []}' | jq -r "${!#}" ;;
    "api "*"/commits/"*"--jq .commit.committer.date"*)  # a commit's committer date (mac_hold), from the bare remote, in UTC
      u="${2#*/commits/}"
      TZ=UTC git -C "$sw/origin.git" log -1 --date=format-local:%Y-%m-%dT%H:%M:%SZ --format=%cd "$u" 2>/dev/null \
        | jq -R '{commit: {committer: {date: .}}}' | jq -r "${!#}" ;;
    "api "*"/pulls/"*"/files "*)
      n="${2#*/pulls/}"; n="${n%%/*}"
      if [[ -e "$sw/files.$n.json" ]]; then jq -r "${!#}" "$sw/files.$n.json"
      else jq -rn '[{filename: "Sources/FlareModel/FlareWorkspace.swift", status: "modified"}]' | jq -r "${!#}"; fi ;;
    "api "*"/pulls/"*) n="${2##*/}"; jq -r "${!#}" "$sw/pull.$n.json" 2>/dev/null || true ;;  # a PR's body (bisect_post)
    "api repos/"*"/issues?labels=dev-red&state=closed"*) jq -r "${!#}" "$sw/redclosed.json" 2>/dev/null || true ;;  # the last closed dev-red issue (flake_closed)
    "api repos/"*"/issues?labels=dev-red"*) jq -r "${!#}" "$sw/red.json" 2>/dev/null || true ;;  # the open dev-red issue
    "issue list "*) cat "$sw/issues.json" 2>/dev/null || echo '[]' ;;  # the open finding issues (flake_finding)
    "issue create "*) echo "$a" >>"$sw/calls"; echo "https://github.com/qbtrix/creative-apps/issues/$((699 + $(grep -c '^issue create' "$sw/calls")))" ;;  # #700, #701, ...
    "api search/issues"*) jq -r "${!#}" "$sw/search.json" 2>/dev/null || true ;;
    "api "*"/actions/runs/"*"/jobs"*) u="${2#*/actions/runs/}"; jq -r "${!#}" "$sw/jobs.${u%%/*}.json" 2>/dev/null || true ;;  # a run's jobs (mac_tests' shards)
    "run view --job "*) cat "$sw/joblog.$4" 2>/dev/null || return 1 ;;  # a job's failed-step log (budget_failure)
    "run view "*) cat "$sw/run.$3.json" 2>/dev/null || return 1 ;;
    "run list "*"--commit "*)
      u="${a#*--commit }"; u="${u%% *}"
      [[ ! -e "$sw/runlist.fail.$u" ]] || return 1
      # $sw/headsha.flaky: GitHub's head_sha filter answers an empty list (#4441).
      [[ ! -e "$sw/headsha.flaky" ]] || { jq -rn '[]' | jq -r "${!#}"; return; }
      jq -r "${!#}" "$sw/runs.$u.json" 2>/dev/null || jq -rn '[]' | jq -r "${!#}" ;;
    "run list "*"--branch "*"--json databaseId,"*|"run list "*"--branch "*"--json url,displayTitle,headSha "*)
      # A branch's runs: every runs.<sha>.json of the fixture PRs on that branch.
      u="${a#*--branch }"; u="${u%% *}"
      local h=() f
      for f in "$sw"/[0-9]*.json; do
        [[ "$(jq -r .headRefName "$f")" == "$u" ]] || continue
        f=$(jq -r .headRefOid "$f"); [[ ! -e "$sw/runlist.fail.$f" ]] || return 1
        [[ ! -e "$sw/runs.$f.json" ]] || h+=("$sw/runs.$f.json")
      done
      if (( ${#h[@]} )); then jq -s 'add' "${h[@]}" | jq -r "${!#}"; else jq -rn '[]' | jq -r "${!#}"; fi ;;
    "workflow run "*)
      # A dispatch on a PR's head branch starts an in-progress CI run on its head.
      echo "$a" >>"$sw/calls"
      # $sw/noapp: the branch's ci.yml predates the `app` input, so GitHub refuses it.
      [[ ! -e "$sw/noapp" || "$a" != *"-f app="* ]] || return 1
      # With -f build_only=true it is a build-only run (title "macOS build"),
      # listed ahead of the head's other runs.
      for n in "$sw"/[0-9]*.json; do
        [[ "$(jq -r .headRefName "$n")" == "${!#}" ]] || continue
        u=$(jq -r .headRefOid "$n"); n="${n##*/}"; n="${n%.json}"
        if [[ "$a" == *"build_only=true"* ]]; then
          jq -n --arg id "8$n" --arg h "$u" --arg url "https://github.com/qbtrix/creative-apps/actions/runs/8$n" \
            '{databaseId: $id, displayTitle: "macOS build", status: "in_progress", conclusion: "", url: $url, headSha: $h}' \
            | jq -s --slurpfile old <(cat "$sw/runs.$u.json" 2>/dev/null || echo '[]') '. + $old[0]' >"$sw/x" && mv "$sw/x" "$sw/runs.$u.json"
          continue
        fi
        n="9$n"
        jq --arg h "$u" --arg url "https://github.com/qbtrix/creative-apps/actions/runs/$n" \
          ".headSha = \$h | .url = \$url | $RUNNING" <<<"$GREEN_RUN" >"$sw/run.$n.json"
        jq -n --arg id "$n" --arg url "https://github.com/qbtrix/creative-apps/actions/runs/$n" \
          '[{databaseId: $id, displayTitle: " ", url: $url}]' >"$sw/runs.$u.json"
      done ;;
    "run list "*"--json status,displayTitle "*)  # the lane's macOS runs (slots): $sw/macruns.json, none if absent
      jq -r "${!#}" "$sw/macruns.json" 2>/dev/null || jq -rn '[]' | jq -r "${!#}" ;;
    "run list "*) cat "$sw/ci_head" 2>/dev/null || echo cihead ;;
    "api "*"/compare/cihead...dev"*) cat "$sw/ci_ahead" 2>/dev/null || echo 0 ;;
    "api "*"/compare/"*) [[ "$2" != *bad ]] || return 1; echo mb ;;
    "api "*"/git/trees/"*)
      u="${2#*/git/trees/}"; u="${u%%\?*}"
      (cd "$sw/refs/$u" 2>/dev/null && find . -type f | sed 's:^\./::') | jq -R '{path: ., type: "blob"}' | jq -s '{truncated: false, tree: .}' ;;
    "api "*"/contents/"*) u="${!#}"; u="${u#*/contents/}"; cat "$sw/refs/${u##*\?ref=}/${u%%\?*}" ;;
    "api "*"/issues/"*"/comments "*) n="${2#*/issues/}"; cat "$sw/${n%%/*}.comments" 2>/dev/null || true ;;
    "api repos/"*"/issues/"*)  # an issue's state ($sw/state.<n>, OPEN if absent) and labels ($sw/labels.<n>, none if absent, a failure if .fail)
      n="${2##*/}"; echo "labels $n" >>"$sw/lookups"
      [[ ! -e "$sw/labels.$n.fail" ]] || return 1
      jq -c --arg s "$(cat "$sw/state.$n" 2>/dev/null || echo OPEN)" '{state: $s, labels: map({name: .})}' <<<"$(cat "$sw/labels.$n" 2>/dev/null || echo '[]')" | jq -r "${!#}" ;;
    "pr comment "*|"issue comment "*) echo "$a" >>"$sw/calls"; printf '%s\n' "${!#}" >>"$sw/$3.comments" ;;
    "pr merge "*) [[ ! -e "$sw/merge.fail.$3" ]] || return 1  # $sw/merge.fail.<n>: GitHub refuses the merge
      echo "$a" >>"$sw/calls"; touch "$sw/$3.merged"; printf '%s\n' "${!#}" >"$sw/$3.squash" ;;
    "pr edit "*"--body "*) echo "pr edit $3 --body" >>"$sw/calls"; printf '%s\n' "${!#}" >"$sw/$3.edited" ;;
    "pr edit "*"--base "*) echo "$a" >>"$sw/calls"; jq '.baseRefName = "dev"' "$sw/$3.json" >"$sw/x" && mv "$sw/x" "$sw/$3.json" ;;
    "pr edit "*"--add-label fast-lane") echo "$a" >>"$sw/calls"
      jq '.labels += [{"name": "fast-lane"}]' "$sw/$3.json" >"$sw/x" && mv "$sw/x" "$sw/$3.json" ;;
    "pr edit "*"--remove-label fast-lane"*) echo "$a" >>"$sw/calls"
      jq '.labels |= map(select(.name != "fast-lane"))' "$sw/$3.json" >"$sw/x" && mv "$sw/x" "$sw/$3.json" ;;
    "pr edit "*"--add-label needs-fix"*) echo "$a" >>"$sw/calls"
      jq '.labels += [{"name": "needs-fix"}]' "$sw/$3.json" >"$sw/x" && mv "$sw/x" "$sw/$3.json" ;;
    "pr edit "*"--remove-label needs-fix"*) echo "$a" >>"$sw/calls"
      jq '.labels |= map(select(.name != "needs-fix"))' "$sw/$3.json" >"$sw/x" && mv "$sw/x" "$sw/$3.json" ;;
    "pr create "*)  # a lane PR (a revert or a quarantine change): the next fixture from #600 on the branch it pushed, by the
      # lane's bot, with the command's labels; its files are the branch's diff against dev
      echo "$a" >>"$sw/calls"; u="${a#*--head }"; u="${u%% *}"
      n=600; while [[ -e "$sw/$n.json" ]]; do n=$((n + 1)); done
      git -C "$sw/origin.git" diff --name-only dev "refs/heads/$u" | jq -R '{filename: ., status: "modified"}' | jq -s . >"$sw/files.$n.json"
      jq -n --argjson n "$n" --arg b "$u" --arg h "$(git -C "$sw/origin.git" rev-parse "refs/heads/$u")" --arg body "${!#}" \
        --argjson labels "$(grep -oE -- '--label [^ ]+' <<<"$a" | cut -d' ' -f2 | jq -R '{name: .}' | jq -s .)" '{number: $n, state: "OPEN",
        isDraft: false, baseRefName: "dev", headRefName: $b, headRefOid: $h, labels: $labels,
        author: {login: "app/github-actions", is_bot: true}, additions: 1, deletions: 1, changedFiles: 1,
        mergeable: "MERGEABLE", mergeStateStatus: "CLEAN", body: $body}' >"$sw/$n.json"
      echo "https://github.com/qbtrix/creative-apps/pull/$n" ;;
    "pr close "*) echo "$a" >>"$sw/calls"; touch "$sw/$3.merged" ;;  # a closed PR leaves the open list like a merged one
    *) echo "$a" >>"$sw/calls" ;;
  esac
}
# live_pr <n>: the PR's fixture, with the head moved to the bare remote's
# branch tip when the lane pushed one there (GitHub would show the new head,
# mergeable again, and the lane's merge as the last commit).
live_pr() {
  local f="$sw/$1.json" br tip
  br=$(jq -r .headRefName "$f"); tip=$(git -C "$sw/origin.git" rev-parse --verify -q "refs/heads/$br" 2>/dev/null || true)
  if [[ -n "$tip" && "$tip" != "$(jq -r .headRefOid "$f")" ]]; then
    jq --arg t "$tip" --arg s "$(git -C "$sw/origin.git" log -1 --format=%s "$tip")" \
      '.headRefOid = $t | .mergeable = "MERGEABLE" | .mergeStateStatus = "CLEAN" | .commits = [{oid: $t, messageHeadline: $s}]' "$f"
  else cat "$f"; fi
}
sweep() {
  rm -rf "$sw"; mkdir -p "$sw"; : >"$sw/calls"
  local n
  [[ -z "${SWEEP_AHEAD:-}" ]] || echo "$SWEEP_AHEAD" >"$sw/ci_ahead"
  [[ -z "${SWEEP_CI_HEAD+x}" ]] || printf '%s' "$SWEEP_CI_HEAD" >"$sw/ci_head"
  # Code gets the macOS build: the head already compiled.
  jq -c '[.]' <<<"$GREEN_BUILD" >"$sw/runs.$HEAD_SHA.json"
  [[ -z "${SWEEP_FILES:-}" ]] || for n in 4 7; do printf '%s\n' "$SWEEP_FILES" >"$sw/files.$n.json"; done
  for n in 4 5 6 7; do jq --argjson n "$n" '.number = $n' <<<"$BASE_PR" | jq "$MARKED" >"$sw/$n.json"; done
  jq '.baseRefName = "main"' "$sw/5.json" >"$sw/x" && mv "$sw/x" "$sw/5.json"
  jq '.mergeable = "CONFLICTING" | .mergeStateStatus = "DIRTY"' "$sw/6.json" >"$sw/x" && mv "$sw/x" "$sw/6.json"
  for n in "$@"; do jq '.labels += [{"name":"feature-done"}]' "$sw/$n.json" >"$sw/x" && mv "$sw/x" "$sw/$n.json"; done
  # #4 and #7 are ready together, so the first run batches them and the
  # second lands the green batch.
  real_pr 4; real_pr 7; real_pr 5
  ( main ) >/dev/null 2>&1 || { echo "FAIL sweep: main exited non-zero"; fail=1; }
  batch_green
  ( main ) >/dev/null 2>&1 || { echo "FAIL sweep: main exited non-zero"; fail=1; }
}
expect() {  # expect <name> <actual> <wanted>
  if [[ "$2" == "$3" ]]; then echo "ok   sweep: $1"; else echo "FAIL sweep: $1: want '$3', got '$2'"; fail=1; fi
}
sweep
expect "merges every eligible PR, oldest first, and the retargeted one on the re-sweep" \
  "$(grep -oE '^pr merge [0-9]+' "$sw/calls" | paste -sd, -)" "pr merge 4,pr merge 7,pr merge 5"
expect "retargets the main-based PR once" "$(grep -c '^pr edit 5 .*--base dev' "$sw/calls")" 1
expect "a conflicting PR the lane can't reach (its branch isn't at the remote) gets no comment yet" "$(grep -c '^pr comment 6 ' "$sw/calls")" 0
expect "never merges the conflicting PR" "$(grep -c '^pr merge 6' "$sw/calls")" 0

expect "routine merges start no CI on dev" "$(grep -c -- '--ref dev' "$sw/calls")" 0
sweep 4 7
expect "feature-done merges dispatch CI on dev once" "$(grep -c '^workflow run ci.yml .*--ref dev' "$sw/calls")" 1

# The lane integrates a conflicting PR (rung 2 of the agentic VCS layer): a
# bare "origin" with dev, feat/json (a key the JSON driver merges with dev's)
# and feat/text (the same Markdown line changed both ways). Both PRs are
# CONFLICTING for GitHub. lane_sweep runs main() with no run-lookup retries.
lane_sweep() { ( FAST_LANE_RUN_LOOKUP_RETRIES=0 main ) >/dev/null 2>&1 || { echo "FAIL sweep: main exited non-zero"; fail=1; }; }
w="$tmp/remote-work"
rm -rf "$sw"; mkdir -p "$sw"; : >"$sw/calls"
git init -q --bare "$sw/origin.git"; git -C "$sw/origin.git" config uploadpack.allowFilter true
git init -q -b dev "$w"; git -C "$w" config user.name t; git -C "$w" config user.email t@t; git -C "$w" config commit.gpgsign false
cp "$here/../../.gitattributes" "$w/"
printf '{"a": 1}\n' >"$w/a.json"; printf 'one\ntwo\nthree\n' >"$w/t.md"; git -C "$w" add -A; git -C "$w" commit -qm base
git -C "$w" switch -qc feat/json; printf '{"a": 1, "b": 2}\n' >"$w/a.json"; git -C "$w" commit -qam "feat: b"
git -C "$w" switch -qc feat/text dev; printf 'one\nTWO ours\nthree\n' >"$w/t.md"; git -C "$w" commit -qam "docs: two"
git -C "$w" switch -q dev; printf '{"a": 1, "c": 3}\n' >"$w/a.json"; printf 'one\nTWO theirs\nthree\n' >"$w/t.md"; git -C "$w" commit -qam "dev moves"
git -C "$w" push -q "$sw/origin.git" dev feat/json feat/text
JSON_HEAD=$(git -C "$w" rev-parse feat/json); TEXT_HEAD=$(git -C "$w" rev-parse feat/text); DEV_TIP=$(git -C "$w" rev-parse dev)
for spec in "6 feat/json $JSON_HEAD" "8 feat/text $TEXT_HEAD"; do
  read -r n br h <<<"$spec"
  jq --argjson n "$n" --arg br "$br" --arg h "$h" '.number = $n | .headRefName = $br | .headRefOid = $h
    | .mergeable = "CONFLICTING" | .mergeStateStatus = "DIRTY" | .commits = [{oid: $h, messageHeadline: "a change"}]' <<<"$BASE_PR" \
    | jq "$(mark "Fast-Check: pass" "Head: $h")" >"$sw/$n.json"
  printf '%s\n' '[{"filename": "docs/x.md", "status": "modified"}]' >"$sw/files.$n.json"
done
REMOTE="$sw/origin.git" lane_sweep
MERGE_TIP=$(git -C "$sw/origin.git" rev-parse feat/json)
expect "integrate: feat/json now ends in the lane's merge commit" "$(git -C "$sw/origin.git" log -1 --format=%s feat/json)" "$LANE_MERGE_SUBJECT"
expect "integrate: its parents are the old head and dev" "$(git -C "$sw/origin.git" rev-parse feat/json^1 feat/json^2 | paste -sd' ' -)" "$JSON_HEAD $DEV_TIP"
expect "integrate: the JSON driver merged both keys" "$(git -C "$sw/origin.git" show feat/json:a.json | jq -c .)" '{"a":1,"b":2,"c":3}'
expect "integrate: one comment says the lane merged dev in" "$(grep -c "^pr comment 6 .*merged origin/dev into feat/json itself ($MERGE_TIP)" "$sw/calls")" 1
expect "integrate: the re-sweep starts a Linux-only check on the new head" "$(grep -c '^workflow run ci.yml .*-f linux_only=true --ref feat/json' "$sw/calls")" 1
expect "integrate: and says so once" "$(grep -c "^pr comment 6 .*started a Linux check on head $MERGE_TIP" "$sw/calls")" 1
expect "integrate: not merged before the check" "$(grep -c '^pr merge 6' "$sw/calls")" 0
expect "integrate: a real conflict leaves the branch alone" "$(git -C "$sw/origin.git" rev-parse feat/text)" "$TEXT_HEAD"
expect "integrate: and labels it needs-rebase" "$(grep -c '^label create needs-rebase' "$sw/calls"),$(grep -c '^pr edit 8 .*--add-label needs-rebase' "$sw/calls")" "1,1"
expect "integrate: with one comment naming the files and the head" "$(grep -c "^pr comment 8 .*conflicts with dev in t.md, and the lane could not integrate it at head $TEXT_HEAD" "$sw/calls")" 1
# Later sweeps: the Linux check runs, then passes; the fixer's PR is left alone.
jq -n '[{name: "Linux", status: "in_progress", conclusion: null, started_at: "2026-01-01T00:00:00Z"}]' >"$sw/checks.$MERGE_TIP.json"
REMOTE="$sw/origin.git" lane_sweep
expect "integrate: while the check runs nothing more is dispatched or said" \
  "$(grep -c '^workflow run' "$sw/calls"),$(grep -c '^pr comment 6 ' "$sw/calls"),$(grep -c '^pr comment 8 ' "$sw/calls"),$(grep -c '^pr edit 8 ' "$sw/calls")" "1,2,1,1"
jq -n '[{name: "Linux", status: "completed", conclusion: "success", started_at: "2026-01-01T00:00:00Z"}]' >"$sw/checks.$MERGE_TIP.json"
REMOTE="$sw/origin.git" lane_sweep
expect "integrate: a green Linux check on the lane's head merges the PR" "$(grep -c "^pr merge 6 .*--match-head-commit $MERGE_TIP" "$sw/calls")" 1
expect "integrate: with the check as its proof" "$(grep -c '^pr comment 6 .*merged into dev (.*1 checks green)' "$sw/calls")" 1
expect "integrate: the fixer's PR is still not merged" "$(grep -c '^pr merge 8' "$sw/calls")" 0

# decide on the lane's own merge commit as the head.
LANE_HEAD_PR='.commits = [{oid: "'"$HEAD_SHA"'", messageHeadline: "'"$LANE_MERGE_SUBJECT"'"}]'
check "lane head with no check: dispatch the Linux check" "linux-dispatch|feat/x" "$LANE_HEAD_PR" "$BASE_FILES" '[]'
check "lane head with a running Linux check waits" "pending|1 checks still running" "$LANE_HEAD_PR" "$BASE_FILES" \
  '[{"__typename":"CheckRun","name":"Linux","workflowName":"","status":"IN_PROGRESS","conclusion":""}]'
check "lane head with a green Linux check is eligible" "eligible|150|2|1 checks green" "$LANE_HEAD_PR" "$BASE_FILES" \
  '[{"__typename":"CheckRun","name":"Linux","workflowName":"","status":"COMPLETED","conclusion":"SUCCESS"}]'
check "lane head with a red Linux check is red" "red|Linux" "$LANE_HEAD_PR" "$BASE_FILES" \
  '[{"__typename":"CheckRun","name":"Linux","workflowName":"","status":"COMPLETED","conclusion":"FAILURE"}]'
check "the lane's subject on an older commit: a Linux check all the same" "linux-dispatch|feat/x" \
  '.commits = [{oid: "'"$OLD_HEAD"'", messageHeadline: "'"$LANE_MERGE_SUBJECT"'"}, {oid: "'"$HEAD_SHA"'", messageHeadline: "feat"}]' "$BASE_FILES" '[]'

# A labelled PR with no proof and no check at all on its head (per-PR CI
# doesn't run on dev PRs): the lane starts one Linux check per head, and a red
# check gets none.
rm -rf "$sw"; mkdir -p "$sw"; : >"$sw/calls"
jq '.number = 20' <<<"$BASE_PR" >"$sw/20.json"
printf '%s\n' '[{"filename": "docs/x.md", "status": "modified"}]' >"$sw/files.20.json"
lane_sweep
expect "no check: one Linux check on the head" "$(grep -c '^workflow run ci.yml .*-f linux_only=true --ref feat/x$' "$sw/calls")" 1
expect "no check: and one comment naming the head" "$(grep -c "^pr comment 20 .*started a Linux check on head $HEAD_SHA" "$sw/calls")" 1
lane_sweep
expect "no check, same head next sweep: no second dispatch or comment" \
  "$(grep -c '^workflow run' "$sw/calls"),$(grep -c '^pr comment 20 ' "$sw/calls"),$(grep -c '^pr merge 20' "$sw/calls")" "1,1,0"
rm -rf "$sw"; mkdir -p "$sw"; : >"$sw/calls"
jq '.number = 20' <<<"$BASE_PR" >"$sw/20.json"
printf '%s\n' '[{"filename": "docs/x.md", "status": "modified"}]' >"$sw/files.20.json"
verdict "$HEAD_SHA" failure
lane_sweep
expect "a red check: no Linux check dispatched" "$(grep -c '^workflow run' "$sw/calls")" 0

# A stale needs-rebase (#2672, #2624, #2636 kept it after a fixer's push made
# them mergeable): #84 is MERGEABLE again, so the sweep drops the label and
# evaluates it in the same pass (no proof yet: its Linux check starts). #85
# still conflicts at a head already handed to a fixer, and #86's mergeable is
# UNKNOWN: both keep the label.
rm -rf "$sw"; mkdir -p "$sw"; : >"$sw/calls"
for spec in "84 MERGEABLE CLEAN" "85 CONFLICTING DIRTY" "86 UNKNOWN UNKNOWN"; do
  read -r n m s <<<"$spec"
  jq --argjson n "$n" --arg m "$m" --arg s "$s" '.number = $n | .headRefName = "b\($n)" | .mergeable = $m | .mergeStateStatus = $s
    | .labels += [{name: "needs-rebase"}]' <<<"$BASE_PR" >"$sw/$n.json"
  printf '%s\n' '[{"filename": "docs/x.md", "status": "modified"}]' >"$sw/files.$n.json"
done
printf '%s\n' "Fast lane: this PR conflicts with dev in t.md, and the lane could not integrate it at head $HEAD_SHA (the merge drivers don't resolve these)." >"$sw/85.comments"
( UNKNOWN_RETRIES=0 FAST_LANE_RUN_LOOKUP_RETRIES=0 main ) >/dev/null 2>&1 || { echo "FAIL sweep: main exited non-zero"; fail=1; }
expect "needs-rebase: a mergeable PR loses the label and is evaluated in the same sweep" \
  "$(grep -c '^pr edit 84 .*--remove-label needs-rebase' "$sw/calls"),$(grep -c -- '-f linux_only=true --ref b84$' "$sw/calls")" "1,1"
expect "needs-rebase: a PR that still conflicts keeps it" "$(grep -c '^pr edit 85 ' "$sw/calls")" 0
expect "needs-rebase: an UNKNOWN mergeable state is left alone" "$(grep -cE '^pr edit 86 |--ref b86$' "$sw/calls")" 0

# dispatch_reason: feature-done, then a UI change, then the 10-merge count.
reason() {  # reason <name> <want> <feature> <ui> <since> [<revert>]
  local got; got=$(dispatch_reason "$3" "$4" "$5" "${6:-0}")
  if [[ "$got" == "$2" ]]; then echo "ok   dispatch: $1"; else echo "FAIL dispatch: $1: want '$2', got '$got'"; fail=1; fi
}
reason "feature-done" "merged a feature-done PR" 1 0 ""
reason "UI change" "merged a UI change" 0 1 ""
reason "10 merges since CI" "10 merged PRs since the last CI run" 0 0 10
reason "9 merges wait" "" 0 0 9
reason "unknown count waits" "" 0 0 ""
reason "a landed lane revert dispatches first" "merged a revert of a red dev's culprit" 1 1 10 1
# UI_RE: what counts as a UI change.
for f in Sources/FlareApp/FlareApp.swift Sources/SuiteUI/Tokens.swift Tests/AppSnapshotTests/A.swift \
    Tests/AppAuditTests/AuditCore.swift UITests/PhotoJourneyTests.swift; do
  if grep -qE "$UI_RE" <<<"$f"; then echo "ok   UI path: $f"; else echo "FAIL UI path: $f"; fail=1; fi
done
for f in Sources/FlareModel/FlareWorkspace.swift Tests/FlareModelTests/T.swift docs/factory/lead.md Sources/HaloModel/HaloAppState.swift; do
  if grep -qE "$UI_RE" <<<"$f"; then echo "FAIL not UI: $f"; fail=1; else echo "ok   not UI: $f"; fi
done
UI_FILES='[{"filename": "Sources/SuiteUI/GlassPanel.swift", "status": "modified"}]'
SWEEP_FILES="$UI_FILES" sweep
expect "UI merges dispatch CI on dev once" "$(grep -c '^workflow run ci.yml .*--ref dev' "$sw/calls")" 1
SWEEP_AHEAD=9 sweep
expect "9 merged PRs since the last CI run start no CI on dev" "$(grep -c -- '--ref dev' "$sw/calls")" 0
SWEEP_AHEAD=10 sweep
expect "the 10th merged PR since the last CI run dispatches once" "$(grep -c '^workflow run ci.yml .*--ref dev' "$sw/calls")" 1
SWEEP_CI_HEAD="" sweep
expect "a base with no CI run yet dispatches once" "$(grep -c '^workflow run ci.yml .*--ref dev' "$sw/calls")" 1
SWEEP_AHEAD=10 SWEEP_FILES="$UI_FILES" sweep 4
expect "every rule at once still dispatches once" "$(grep -c -- '--ref dev' "$sw/calls")" 1

# The audit through a sweep: #8 raises a count, #9 lowers one, #10 renames
# scripts/ci away, #11's merge base can't be read, #12 drops Overlap() and
# hides it behind a stray AuditCore.swift, #13 adds a check with its counts
# (the lane must read the new check file to match its id). Each has its own head.
pr_at() {  # pr_at <n> <head sha> <files json>
  jq --argjson n "$1" --arg h "$2" '.number = $n | .headRefOid = $h
    | .body = "Closes #1\n\nFast-Check: pass\nHead: \($h)"' <<<"$BASE_PR" >"$sw/$1.json"
  printf '%s\n' "$3" >"$sw/files.$1.json"
}
rm -rf "$sw"; mkdir -p "$sw/refs"; : >"$sw/calls"
BLF='[{"filename": "UITests/audit-baseline.json", "status": "modified"}]'
audit_tree "$sw/refs/mb" "$BL" "$REG" "${CHECKS[@]}"
pr_at 8 h8 "$BLF"; audit_tree "$sw/refs/h8" '{ "photo": { "identifier": 55, "overlap": 1 }, "halo": { "contrast": 2 } }' "$REG" "${CHECKS[@]}"
pr_at 9 h9 "$BLF"; audit_tree "$sw/refs/h9" '{ "photo": { "identifier": 50, "overlap": 1 }, "halo": { "contrast": 2 } }' "$REG" "${CHECKS[@]}"
pr_at 10 h10 '[{"filename": "tools/ci", "previous_filename": "scripts/ci", "status": "renamed"}]'
pr_at 11 bad "$BLF"
pr_at 12 h12 '[{"filename": "Tests/PhotoModelTests/AppAudit/AuditCore.swift", "status": "modified"}]'
audit_tree "$sw/refs/h12" "$BL" "DisabledDim(), TextContrast(), Identifier(), Offscreen(), Unnamed()" "${CHECKS[@]}"
mkdir -p "$sw/refs/h12/$AD/Old"; cp "$sw/refs/mb/$AD/AuditCore.swift" "$sw/refs/h12/$AD/Old/AuditCore.swift"
pr_at 13 h13 '[{"filename": "Tests/PhotoModelTests/AppAudit/Checks/Focus.swift", "status": "added"}]'
audit_tree "$sw/refs/h13" "$FOCUS_BL" "$REG, Focus()" "${CHECKS[@]}" Focus=focus
jq -c '[.headSha = "h13"]' <<<"$GREEN_BUILD" >"$sw/runs.h13.json"
real_pr 9; real_pr 13  # ready together: one batch, landed on its green check
( main ) >/dev/null 2>&1 || { echo "FAIL sweep: main exited non-zero"; fail=1; }
batch_green
( main ) >/dev/null 2>&1 || { echo "FAIL sweep: main exited non-zero"; fail=1; }
expect "audit: merges only the PRs that lower a count or add a check with its counts" \
  "$(grep -oE '^pr merge [0-9]+' "$sw/calls" | paste -sd, -)" "pr merge 9,pr merge 13"
expect "audit: one comment on the looser PR" \
  "$(grep -c "^pr comment 8 .*not eligible. loosens the app audit: needs the captain's review (photo identifier 54 -> 55)" "$sw/calls")" 1
expect "audit: the looser PR loses its label" "$(grep -c '^pr edit 8 .*--remove-label fast-lane' "$sw/calls")" 1
expect "a rename away from a protected path is refused" \
  "$(grep -c '^pr comment 10 .*touches protected paths: scripts/ci\.' "$sw/calls")" 1
expect "audit: an unreadable merge base skips the PR, no writes" "$(grep -c '^pr [a-z]* 11 ' "$sw/calls")" 0
expect "audit: a stray AuditCore.swift can't hide a dropped entry" \
  "$(grep -c "^pr comment 12 .*loosens the app audit: needs the captain's review (drops Overlap from AppAudit.checks)" "$sw/calls")" 1
# A shared shell file through sweeps (#1337 waited hours on a full macOS
# run): #14 changes SuiteWindow.swift and gets one build-only run, like any
# code PR, then merges once it compiled. #22's run list fails, so nothing is
# written for it.
rm -rf "$sw"; mkdir -p "$sw"; : >"$sw/calls"
SWF='[{"filename": "Sources/SuiteUI/SuiteWindow.swift", "status": "modified"}]'
for n in 14 22; do
  pr_at "$n" "h$n" "$SWF"
  jq --arg b "b$n" '.headRefName = $b' "$sw/$n.json" >"$sw/x" && mv "$sw/x" "$sw/$n.json"
done
touch "$sw/runlist.fail.h22"; real_pr 14 pr14.md b14; H14=$(jq -r .headRefOid "$sw/14.json")
lane_sweep() { ( FAST_LANE_RUN_LOOKUP_RETRIES=0 main ) >/dev/null 2>&1 || { echo "FAIL sweep: main exited non-zero"; fail=1; }; }
lane_sweep
expect "shell: a SuiteWindow PR gets one build-only run, no full run" \
  "$(grep -c -- '-f build_only=true --ref b14$' "$sw/calls"),$(grep -c '^workflow run ci.yml -R qbtrix/creative-apps --ref b14$' "$sw/calls")" "1,0"
expect "shell: an unreadable run list writes nothing for the PR" "$(grep -cE '^pr [a-z]+ 22 |--ref b22' "$sw/calls")" 0
jq 'map(if .displayTitle == "macOS build" then .status = "completed" | .conclusion = "success" else . end)' "$sw/runs.$H14.json" >"$sw/x" && mv "$sw/x" "$sw/runs.$H14.json"
lane_sweep
expect "shell: once it compiled, a later sweep merges it" "$(grep -c '^pr merge 14' "$sw/calls")" 1

# The macOS build gate through sweeps (lesson 114). #30 changes
# Sources/LibraryApp with no build on its head: the lane dispatches a
# build-only run on its branch once (-f build_only=true) and comments its URL,
# waits while it builds, and merges once it compiled. #32's build on its head
# failed: refused by URL, no dispatch. #34 touches SuiteWindow.swift and app
# code: one build-only run, never a full one.
rm -rf "$sw"; mkdir -p "$sw"; : >"$sw/calls"
for n in 30 32 34; do
  pr_at "$n" "h$n" '[{"filename": "Sources/LibraryApp/LibraryInspector.swift", "status": "modified"}]'
  jq --arg b "b$n" '.headRefName = $b' "$sw/$n.json" >"$sw/x" && mv "$sw/x" "$sw/$n.json"
done
printf '%s\n' '[{"filename": "Sources/SuiteUI/SuiteWindow.swift", "status": "modified"}, {"filename": "Sources/FlareApp/FlareApp.swift", "status": "modified"}]' >"$sw/files.34.json"
echo '[{"databaseId": "32", "displayTitle": "macOS build", "status": "completed", "conclusion": "failure", "url": "https://github.com/qbtrix/creative-apps/actions/runs/32", "headSha": "h32"}]' >"$sw/runs.h32.json"
real_pr 30 pr30.md b30; H30=$(jq -r .headRefOid "$sw/30.json")
lane_sweep
expect "build: dispatches one build-only run on the app PR's branch, re-sweep included" \
  "$(grep -c '^workflow run ci.yml -R qbtrix/creative-apps -f build_only=true -f app=library --ref b30$' "$sw/calls")" 1
expect "build: comments the build's URL once" \
  "$(grep -c '^pr comment 30 .*The lane dispatched a macOS build on b30 (apps: library): https://github.com/qbtrix/creative-apps/actions/runs/830\.' "$sw/calls")" 1
expect "build: doesn't merge before it compiles" "$(grep -c '^pr merge 30' "$sw/calls")" 0
expect "build: a failed build is refused by URL" \
  "$(grep -c "^pr comment 32 .*doesn't build on macOS: https://github.com/qbtrix/creative-apps/actions/runs/32 (failure)\. Fix it and push" "$sw/calls")" 1
expect "build: a failed build never re-dispatches" "$(grep -c -- '--ref b32' "$sw/calls")" 0
expect "build: a shared shell file with app code gets one build, not a full run" \
  "$(grep -c -- '--ref b34$' "$sw/calls"),$(grep -c -- 'build_only=true --ref b34' "$sw/calls")" "1,1"
expect "build: refused PRs keep the fast-lane label" "$(grep -c -- '--remove-label fast-lane' "$sw/calls")" 0
lane_sweep
expect "build: a later sweep while it builds dispatches and comments nothing more" \
  "$(grep -c -- '--ref b30$' "$sw/calls"),$(grep -c '^pr comment 30 ' "$sw/calls"),$(grep -c '^pr merge 30' "$sw/calls")" "1,1,0"
jq 'map(if .displayTitle == "macOS build" then .status = "completed" | .conclusion = "success" else . end)' "$sw/runs.$H30.json" >"$sw/x" && mv "$sw/x" "$sw/runs.$H30.json"
lane_sweep
expect "build: once it compiled the head, a later sweep merges it" "$(grep -c '^pr merge 30' "$sw/calls")" 1
expect "build: the merge comment names the build" \
  "$(grep -c '^pr comment 30 .*merged into dev.*macOS build https://github.com/qbtrix/creative-apps/actions/runs/830' "$sw/calls")" 1
expect "build: still one build for its head" "$(grep -c -- '--ref b30$' "$sw/calls")" 1
# The cancel loop (#4441, #4472): GitHub's head_sha filter sometimes answers
# an empty list, which read as "no build on the head", so each sweep
# dispatched again and the new run cancelled the queued one (ci.yml's
# per-branch -build group); in a full macOS queue nothing ever built. #40's
# build is queued while head_sha answers empty: no dispatch. #42's build was
# cancelled 5 minutes ago: it waits. #44's was cancelled 2 hours ago: one
# dispatch, and the re-sweep waits on it.
rm -rf "$sw"; mkdir -p "$sw"; : >"$sw/calls"; touch "$sw/headsha.flaky"
for n in 40 42 44; do
  pr_at "$n" "h$n" '[{"filename": "Sources/LibraryApp/LibraryInspector.swift", "status": "modified"}]'
  jq --arg b "b$n" '.headRefName = $b' "$sw/$n.json" >"$sw/x" && mv "$sw/x" "$sw/$n.json"
done
for spec in "40 queued null 0" "42 completed cancelled 300" "44 completed cancelled 7200"; do
  read -r n st c ago <<<"$spec"
  jq -n --arg n "$n" --arg st "$st" --arg c "$c" --argjson ago "$ago" '[{databaseId: "7\($n)", displayTitle: "macOS build",
    status: $st, conclusion: (if $c == "null" then "" else $c end), updatedAt: (now - $ago | todate),
    url: "https://github.com/qbtrix/creative-apps/actions/runs/7\($n)", headSha: "h\($n)"}]' >"$sw/runs.h$n.json"
done
lane_sweep
expect "cancel loop: a queued build is never dispatched over" "$(grep -c -- '--ref b40$' "$sw/calls")" 0
expect "cancel loop: a build cancelled minutes ago waits" "$(grep -c -- '--ref b42$' "$sw/calls")" 0
expect "cancel loop: a build cancelled past the interval is dispatched again once" "$(grep -c -- 'build_only=true .*--ref b44$' "$sw/calls")" 1
lane_sweep
expect "cancel loop: the re-sweep waits on the new build" "$(grep -c -- '--ref b4[024]$' "$sw/calls")" 1
expect "cancel loop: nothing merges before it compiles" "$(grep -c '^pr merge 4[024]' "$sw/calls")" 0
# #36 touches only Tests/AppSnapshotTests (#1097's break): it gets the build too.
rm -rf "$sw"; mkdir -p "$sw"; : >"$sw/calls"
pr_at 36 h36 '[{"filename": "Tests/AppSnapshotTests/HaloPlaybackDriverTests.swift", "status": "modified"}]'
jq '.headRefName = "b36"' "$sw/36.json" >"$sw/x" && mv "$sw/x" "$sw/36.json"
lane_sweep
expect "build: a PR touching only a snapshot test gets one build, not a merge" \
  "$(grep -c -- '-f build_only=true -f app=halo --ref b36$' "$sw/calls"),$(grep -c '^pr merge 36' "$sw/calls")" "1,0"
expect "build: its comment names the folder" \
  "$(grep -c '^pr comment 36 .*changes code (Tests/AppSnapshotTests)' "$sw/calls")" 1
# #38 changes only PhotoModel (#1210's shape): it gets one build, not a merge.
# #39 changes only docs: it merges with no build.
rm -rf "$sw"; mkdir -p "$sw"; : >"$sw/calls"
pr_at 38 h38 '[{"filename": "Sources/PhotoModel/PhotoRecovery.swift", "status": "modified"}]'
pr_at 39 h39 '[{"filename": "docs/blueprints/photo/features/recovery.md", "status": "modified"}]'
for n in 38 39; do jq --arg b "b$n" '.headRefName = $b' "$sw/$n.json" >"$sw/x" && mv "$sw/x" "$sw/$n.json"; done
real_pr 39 pr39.md b39
lane_sweep
expect "build: a Model-only PR gets one build, not a merge" \
  "$(grep -c -- '-f build_only=true -f app=photo --ref b38$' "$sw/calls"),$(grep -c '^pr merge 38' "$sw/calls")" "1,0"
expect "build: a docs-only PR merges with no build" \
  "$(grep -c -- '--ref b39' "$sw/calls"),$(grep -c '^pr merge 39' "$sw/calls")" "0,1"
# #40 is a Photo PR on a branch whose ci.yml has no `app` input: the scoped
# dispatch is refused, so the lane dispatches a full build instead, once.
rm -rf "$sw"; mkdir -p "$sw"; : >"$sw/calls"; touch "$sw/noapp"
pr_at 40 h40 '[{"filename": "Sources/PhotoApp/PhotoWindow.swift", "status": "modified"}]'
jq '.headRefName = "b40"' "$sw/40.json" >"$sw/x" && mv "$sw/x" "$sw/40.json"
lane_sweep
expect "build: a refused scoped dispatch falls back to one full build" \
  "$(grep -c -- '-f build_only=true -f app=photo --ref b40$' "$sw/calls"),$(grep -c -- '-f build_only=true --ref b40$' "$sw/calls")" "1,1"
expect "build: the fallback's comment says every app" \
  "$(grep -c '^pr comment 40 .*macOS build on b40 (every app)' "$sw/calls")" 1

# AI attribution in a PR body never reaches history, and its author hears
# about it once. #45 lands alone: its squash message has no attribution line.
# #46 is a draft, so it stays open: two sweeps, still one comment.
rm -rf "$sw"; mkdir -p "$sw"; : >"$sw/calls"
for n in 45 46; do pr_at "$n" "h$n" '[{"filename": "docs/blueprints/halo/features/keyframes.md", "status": "modified"}]'; done
for n in 45 46; do
  jq --arg h "h$n" '.body = "Adds keyframes.\n\nFast-Check: pass\nHead: \($h)\n\n🤖 Generated with [Claude Code](https://claude.com/claude-code)\nCo-Authored-By: Claude <noreply@anthropic.com>"' \
    "$sw/$n.json" >"$sw/x" && mv "$sw/x" "$sw/$n.json"
done
jq '.isDraft = true' "$sw/46.json" >"$sw/x" && mv "$sw/x" "$sw/46.json"; real_pr 45
lane_sweep; lane_sweep
expect "attribution: the PR still merges" "$(grep -oE '^pr merge [0-9]+' "$sw/calls" | paste -sd, -)" "pr merge 45"
expect "attribution: the squash message keeps the body and drops the lines" \
  "$(grep -c 'Adds keyframes' "$sw/45.squash"),$(grep -ciE 'generated with|co-authored-by' "$sw/45.squash")" "1,0"
expect "attribution: one comment asks the author to remove them" \
  "$(grep -c '^pr comment 45 .*AI attribution lines' "$sw/calls"),$(grep -c '^pr comment 46 .*AI attribution lines' "$sw/calls")" "1,1"

# A lead's PR never closes a feature-lead issue, and still closes the rest.
# #40 (a Feature: line) says "Closes #12, fixes #13": #12 is the feature,
# #13 a critic finding, and GitHub lists both as closing. The lane edits the
# body to "Refs #12, fixes #13" before the squash, squashes with it, and
# closes #13 only. #42 points at #12 again and at #14, whose labels can't be
# read: its keyword stays, the lane comments once and closes neither. #12's
# labels are read once in the sweep. #41 is no lead's: no lookup, keyword kept.
rm -rf "$sw"; mkdir -p "$sw"; : >"$sw/calls"; : >"$sw/lookups"
for n in 40 41 42; do pr_at "$n" "h$n" '[{"filename": "docs/blueprints/halo/features/keyframes.md", "status": "modified"}]'; done
jq --arg b "$lead_body" '.body = $b' "$sw/40.json" >"$sw/x" && mv "$sw/x" "$sw/40.json"
jq '.body = "Closes #15\n\nFast-Check: pass\nHead: h41"' "$sw/41.json" >"$sw/x" && mv "$sw/x" "$sw/41.json"
jq '.body = "Fixes #12, closes #14\nFeature: halo-keyframes\nFast-Check: pass\nHead: h42"' "$sw/42.json" >"$sw/x" && mv "$sw/x" "$sw/42.json"
printf '%s\n' 12 13 >"$sw/40.closes"; echo 15 >"$sw/41.closes"; printf '%s\n' 12 14 >"$sw/42.closes"
echo '["feature-lead", "line:halo"]' >"$sw/labels.12"; echo '["critic-finding", "line:halo"]' >"$sw/labels.13"; touch "$sw/labels.14.fail"
for n in 40 41 42; do real_pr "$n"; done  # ready together: one batch
lane_sweep; batch_green; lane_sweep
expect "refs: all three merge" "$(grep -oE '^pr merge [0-9]+' "$sw/calls" | paste -sd, -)" "pr merge 40,pr merge 41,pr merge 42"
expect "refs: the lead's body is edited before the squash, the feature's keyword only" \
  "$(grep -nE '^pr (edit 40 --body|merge 40)' "$sw/calls" | cut -d' ' -f2 | paste -sd, -),$(grep -c '^Refs #12, fixes #13$' "$sw/40.edited")" "edit,merge,1"
expect "refs: the squash message carries the same line" "$(grep -c '^Refs #12, fixes #13$' "$sw/40.squash")" 1
expect "refs: the finding closes, the feature doesn't" \
  "$(grep -c '^issue close 13 ' "$sw/calls"),$(grep -c '^issue close 12 ' "$sw/calls")" "1,0"
expect "refs: an unreadable label keeps its keyword, the feature's still becomes Refs" \
  "$(grep -c '^Refs #12, closes #14$' "$sw/42.squash")" 1
expect "refs: an unreadable label gets one comment, and its issue isn't closed" \
  "$(grep -c '^pr comment 42 .*could not read the labels of qbtrix/creative-apps#14' "$sw/calls"),$(grep -c '^issue close 14 ' "$sw/calls")" "1,0"
expect "refs: one label lookup per issue in the sweep" "$(grep -c '^labels 12$' "$sw/lookups"),$(grep -c '^labels 13$' "$sw/lookups")" "1,1"
expect "refs: another PR keeps its keyword, needs no lookup, and gets its issue closed" \
  "$(grep -c '^Closes #15$' "$sw/41.squash"),$(grep -c '^labels 15$' "$sw/lookups"),$(grep -c '^issue close 15 ' "$sw/calls")" "1,0,1"

# Canonical first through a sweep: evaluate turns the files API's statuses into
# added.txt. #60 adds HaloKeyframeEasing.swift, #61 renames a file to
# PhotoCropper.swift with an Allow-Dup line, #62 only modifies a grandfathered
# copy. Each head already compiled on macOS.
rm -rf "$sw"; mkdir -p "$sw"; : >"$sw/calls"
pr_at 60 h60 '[{"filename": "Sources/HaloModel/HaloKeyframeEasing.swift", "status": "added"}]'
pr_at 61 h61 '[{"filename": "Sources/PhotoModel/PhotoCropper.swift", "previous_filename": "Sources/PhotoModel/PhotoTrim.swift", "status": "renamed"}]'
jq '.body = "Closes #1\nAllow-Dup: Crop moves to the kernel in #2001\n\nFast-Check: pass\nHead: h61"' "$sw/61.json" >"$sw/x" && mv "$sw/x" "$sw/61.json"
pr_at 62 h62 '[{"filename": "Sources/PhotoModel/PhotoHistory.swift", "status": "modified"}]'
for n in 60 61 62; do jq -c --arg h "h$n" '[.headSha = $h]' <<<"$GREEN_BUILD" >"$sw/runs.h$n.json"; done
real_pr 61; real_pr 62  # ready together: one batch, landed on its green check
lane_sweep; batch_green; lane_sweep
expect "canonical: merges the allowed rename and the edit, not the new copy" \
  "$(grep -oE '^pr merge [0-9]+' "$sw/calls" | paste -sd, -)" "pr merge 61,pr merge 62"
expect "canonical: one comment naming the new copy" \
  "$(grep -c '^pr comment 60 .*adds app-local logic for a canonical concept.*Sources/HaloModel/HaloKeyframeEasing.swift (Easing)' "$sw/calls")" 1

# Batches (rung 2b of the agentic VCS layer): two or more ready PRs get one
# Linux check together on lane/batch-<id> before any of them lands. #50 and
# #51 are ready; #52 arrives while the batch runs.
DOCS='[{"filename": "docs/blueprints/photo/features/a.md", "status": "modified"}]'
rm -rf "$sw"; mkdir -p "$sw"; : >"$sw/calls"
for n in 50 51; do pr_at "$n" "h$n" "$DOCS"; real_pr "$n"; done
H50=$(jq -r .headRefOid "$sw/50.json"); H51=$(jq -r .headRefOid "$sw/51.json")
lane_sweep
TIP=$(batch_tip)
expect "batch: two ready PRs merge nothing yet" "$(grep -c '^pr merge' "$sw/calls")" 0
expect "batch: one scratch branch holds dev plus both PRs, oldest first" \
  "$(git -C "$sw/origin.git" log --first-parent --reverse --format=%s "dev..$TIP" | paste -sd'~' -)" \
  "fast lane batch: PR #50 at $H50~fast lane batch: PR #51 at $H51"
expect "batch: its base is dev" "$(git -C "$sw/origin.git" rev-parse "$TIP~2")" "$(git -C "$sw/origin.git" rev-parse dev)"
expect "batch: one Linux-only check on it, nothing on the PR branches" \
  "$(grep -c '^workflow run ci.yml .*-f linux_only=true --ref lane/batch-[0-9]*$' "$sw/calls"),$(grep -c -- '--ref feat/' "$sw/calls")" "1,0"
pr_at 52 h52 "$DOCS"; real_pr 52
verdict "$TIP" in_progress
lane_sweep
expect "batch: while it runs nothing lands, nothing more starts, the late PR waits" \
  "$(grep -c '^pr merge' "$sw/calls"),$(grep -c '^workflow run' "$sw/calls")" "0,1"
verdict "$TIP" success
lane_sweep
expect "batch: green: both land in order, then the late PR alone" \
  "$(grep -oE '^pr merge [0-9]+' "$sw/calls" | paste -sd, -)" "pr merge 50,pr merge 51,pr merge 52"
expect "batch: each merge matches the head the batch checked" \
  "$(grep -c "^pr merge 50 .*--match-head-commit $H50 " "$sw/calls"),$(grep -c "^pr merge 51 .*--match-head-commit $H51 " "$sw/calls")" "1,1"
expect "batch: the merge comment names the batch and its run" \
  "$(grep -c '^pr comment 50 .*merged into dev (.*batch of 2 PRs checked together on Linux: https://github.com/qbtrix/creative-apps/actions/runs/777)' "$sw/calls")" 1
expect "batch: the late PR lands on its own proof" "$(grep -c '^pr comment 52 .*merged into dev (.*Fast-Check marker)' "$sw/calls")" 1
expect "batch: the scratch branch is gone" "$(batch_tip)" ""

# Ratchet race (lesson 244): a proof that ran before dev changed a ratchet,
# lint or baseline file proves nothing about the PR on today's dev, and a PR
# that changes one proves nothing about code dev gained since its base. Such a
# PR is not landed on that proof: it becomes a batch of one, checked on Linux
# on the current dev, and lands on that. A batch whose base is stale that way
# is dropped and formed again on the current dev.
dev_moves() {  # dev_moves <path>: a commit on dev at the bare remote changing <path>
  git -C "$sw/work" switch -q dev; mkdir -p "$sw/work/$(dirname "$1")"; echo "dev $RANDOM" >>"$sw/work/$1"
  git -C "$sw/work" add -A; git -C "$sw/work" commit -qm "dev moves $1"; git -C "$sw/work" push -q "$sw/origin.git" dev
}
rm -rf "$sw"; mkdir -p "$sw"; : >"$sw/calls"
pr_at 80 h80 "$DOCS"; real_pr 80
dev_moves Tests/command-path-baseline/halo.txt
lane_sweep
expect "ratchet race: dev changed a baseline after the proof: no merge on it" "$(grep -c '^pr merge 80' "$sw/calls")" 0
expect "ratchet race: one Linux check on the PR merged into today's dev" \
  "$(grep -c '^workflow run ci.yml .*-f linux_only=true --ref lane/batch-[0-9]*$' "$sw/calls"),$(git -C "$sw/origin.git" rev-parse "$(batch_tip)~1")" \
  "1,$(git -C "$sw/origin.git" rev-parse dev)"
batch_green; lane_sweep
expect "ratchet race: it lands on that check" "$(grep -c '^pr comment 80 .*merged into dev (.*batch of 1 PRs checked together on Linux' "$sw/calls")" 1
rm -rf "$sw"; mkdir -p "$sw"; : >"$sw/calls"
pr_at 81 h81 "$DOCS"; real_pr 81
dev_moves docs/other.md
lane_sweep
expect "ratchet race: dev moved, no ratchet changed: lands on its own proof" \
  "$(grep -c '^pr comment 81 .*merged into dev (.*Fast-Check marker)' "$sw/calls"),$(grep -c '^workflow run' "$sw/calls")" "1,0"
rm -rf "$sw"; mkdir -p "$sw"; : >"$sw/calls"
pr_at 82 h82 "$DOCS"; real_pr 82 Tests/placeholder-menu-baseline.txt
dev_moves Sources/HaloApp/HaloTransport.swift
lane_sweep
expect "ratchet race: a PR changing a baseline, dev moved under it: no merge on its own proof" \
  "$(grep -c '^pr merge 82' "$sw/calls"),$(grep -c '^workflow run ci.yml .*-f linux_only=true --ref lane/batch-[0-9]*$' "$sw/calls")" "0,1"
rm -rf "$sw"; mkdir -p "$sw"; : >"$sw/calls"
for n in 83 84; do pr_at "$n" "h$n" "$DOCS"; real_pr "$n"; done
lane_sweep
OLD_TIP=$(batch_tip)
dev_moves Tests/format-lists-baseline.txt
verdict "$OLD_TIP" success
lane_sweep
expect "ratchet race: a green batch on a dev that since changed a ratchet lands nothing" "$(grep -c '^pr merge' "$sw/calls")" 0
expect "ratchet race: it forms again on today's dev, with a new Linux check" \
  "$(git -C "$sw/origin.git" rev-parse "$(batch_tip)~2"),$(grep -c '^workflow run ci.yml .*-f linux_only=true --ref lane/batch-[0-9]*$' "$sw/calls")" \
  "$(git -C "$sw/origin.git" rev-parse dev),2"
batch_green; lane_sweep
expect "ratchet race: the new batch lands on its check" "$(grep -oE '^pr merge [0-9]+' "$sw/calls" | paste -sd, -)" "pr merge 83,pr merge 84"
# The Generated workflow (.github/workflows/generated.yml) pushes docs/c4/model.json,
# docs/c4/parts, waves.md and jobs.md straight to dev every few hours. Those
# commits touch no code, so they don't make a proof stale: a batch with a
# ratchet-touching PR still lands (on 10-23 one dropped an 8-PR batch after 6 h).
rm -rf "$sw"; mkdir -p "$sw"; : >"$sw/calls"
pr_at 85 h85 "$DOCS"; real_pr 85
pr_at 86 h86 "$DOCS"; real_pr 86 Tests/placeholder-menu-baseline.txt
lane_sweep
OLD_TIP=$(batch_tip)
dev_moves docs/c4/model.json; dev_moves docs/blueprints/photo/jobs.md; dev_moves docs/blueprints/photo/features/waves.md
dev_moves docs/c4/parts/creative-apps/photo-model/photo-model-sources.json
verdict "$OLD_TIP" success
lane_sweep
expect "generated: dev moved only by generated files: a batch with a ratchet PR lands on its check" \
  "$(grep -oE '^pr merge [0-9]+' "$sw/calls" | paste -sd, -),$(grep -c '^workflow run ci.yml .*-f linux_only=true --ref lane/batch-[0-9]*$' "$sw/calls")" "pr merge 85,pr merge 86,1"
rm -rf "$sw"; mkdir -p "$sw"; : >"$sw/calls"
pr_at 85 h85 "$DOCS"; real_pr 85
pr_at 86 h86 "$DOCS"; real_pr 86 Tests/placeholder-menu-baseline.txt
lane_sweep
OLD_TIP=$(batch_tip)
dev_moves docs/c4/model.json; dev_moves Sources/HaloApp/HaloTransport.swift
verdict "$OLD_TIP" success
lane_sweep
expect "generated: dev also moved by another path: the batch lands nothing and forms again on today's dev" \
  "$(grep -c '^pr merge' "$sw/calls"),$(git -C "$sw/origin.git" rev-parse "$(batch_tip)~2"),$(grep -c '^workflow run ci.yml .*-f linux_only=true --ref lane/batch-[0-9]*$' "$sw/calls")" \
  "0,$(git -C "$sw/origin.git" rev-parse dev),2"

# A red batch is bisected by prefix: #60 good, #61 bad, #62 good. The tip is
# red; the chain after 1 PR is green; after 2 red: #61 is the culprit. #60
# lands, #61 gets needs-fix and one comment, #62 lands alone on the re-sweep.
rm -rf "$sw"; mkdir -p "$sw"; : >"$sw/calls"
for n in 60 61 62; do pr_at "$n" "h$n" "$DOCS"; real_pr "$n"; done
H60=$(jq -r .headRefOid "$sw/60.json"); H61=$(jq -r .headRefOid "$sw/61.json")
lane_sweep
TIP=$(batch_tip); BR=$(git -C "$sw/origin.git" for-each-ref 'refs/heads/lane/batch-*' --format='%(refname:short)')
verdict "$TIP" failure
lane_sweep
expect "bisect: a red batch of 3 probes the chain after 1 PR" "$(probe_sha 1)" "$(git -C "$sw/origin.git" rev-parse "$TIP~2")"
expect "bisect: with one Linux check on the probe" "$(grep -c -- "-f linux_only=true --ref $BR-1\$" "$sw/calls")" 1
expect "bisect: nothing lands yet" "$(grep -c '^pr merge' "$sw/calls")" 0
verdict "$(probe_sha 1)" success
lane_sweep
expect "bisect: a green prefix moves the probe to the chain after 2 PRs" "$(probe_sha 2)" "$(git -C "$sw/origin.git" rev-parse "$TIP~1")"
verdict "$(probe_sha 2)" failure
lane_sweep
expect "bisect: the first red prefix names the culprit; the PRs before it land, the one after lands alone" \
  "$(grep -oE '^pr merge [0-9]+' "$sw/calls" | paste -sd, -)" "pr merge 60,pr merge 62"
expect "bisect: the culprit gets needs-fix and one comment naming its head, the run and what it landed after" \
  "$(grep -c '^label create needs-fix' "$sw/calls"),$(grep -c '^pr edit 61 .*--add-label needs-fix' "$sw/calls"),$(grep -c "^pr comment 61 .*head $H61 fails the Linux check once it lands on dev after #60: https://github.com/qbtrix/creative-apps/actions/runs/777\. Those PRs merged; " "$sw/calls")" "1,1,1"
expect "bisect: the landed PR's comment says what it was checked with" "$(grep -c '^pr comment 60 .*batch of 1 PRs checked together on Linux before #61 broke the chain' "$sw/calls")" 1
expect "bisect: every batch branch is gone" "$(git -C "$sw/origin.git" for-each-ref 'refs/heads/lane/batch-*' | wc -l | tr -d ' ')" 0
lane_sweep
expect "needs-fix: the culprit waits at that head, no writes" "$(grep -c '^pr [a-z]* 61 ' "$sw/calls")" 2
git -C "$sw/work" switch -q feat/61; echo fix >>"$sw/work/pr61.md"; git -C "$sw/work" commit -qam fix; git -C "$sw/work" push -q "$sw/origin.git" feat/61; git -C "$sw/work" switch -q dev
lane_sweep
expect "needs-fix: a new head drops the label" "$(grep -c '^pr edit 61 .*--remove-label needs-fix' "$sw/calls")" 1

# A red batch whose first PR alone is red asks about the base: a red base means
# dev itself is red, and the batch lands on the PRs' own proof.
rm -rf "$sw"; mkdir -p "$sw"; : >"$sw/calls"
for n in 70 71; do pr_at "$n" "h$n" "$DOCS"; real_pr "$n"; done
lane_sweep
TIP=$(batch_tip)
verdict "$TIP" failure; lane_sweep
verdict "$(probe_sha 1)" failure; lane_sweep
expect "dev red: a red first PR probes the base alone" "$(probe_sha 0)" "$(git -C "$sw/origin.git" rev-parse dev)"
verdict "$(probe_sha 0)" failure; lane_sweep
expect "dev red: a red base lands the batch on each PR's own proof" "$(grep -oE '^pr merge [0-9]+' "$sw/calls" | paste -sd, -)" "pr merge 70,pr merge 71"
expect "dev red: and says so" "$(grep -c '^pr comment 71 .*dev was red on its own (https://github.com/qbtrix/creative-apps/actions/runs/777), so this batch landed on each PR.s own proof' "$sw/calls")" 1
expect "dev red: no needs-fix" "$(grep -c -- '--add-label needs-fix' "$sw/calls")" 0
expect "dev red: the branches are gone" "$(git -C "$sw/origin.git" for-each-ref 'refs/heads/lane/batch-*' | wc -l | tr -d ' ')" 0

# A red dev (#5234): while an open dev-red issue names a red Linux job, no new
# batch forms and ready PRs wait; once the issue closes, they batch.
# redissue <sha or empty> [<failing jobs>]: the open dev-red issue #510 (jobs
# default linux), its range main..<sha>, with a bisect verdict already posted
# so red_bisect stays out of the way.
redissue() {
  jq -n --arg b "$(printf 'CI on dev is red.\n\n- Failing jobs: %s\n%s' "${2:-linux}" "${1:+- Culprit range: \`main..$1\`}")" \
    '[{number: 510, body: $b, pull_request: null}]' >"$sw/red.json"
  printf '%s\n' "$BISECT_MARK ${1:0:7} -->" >"$sw/510.comments"
}
redref() { git -C "$sw/origin.git" for-each-ref 'refs/heads/lane/batch-*-red' --format='%(refname:short)' | wc -l | tr -d ' '; }
rm -rf "$sw"; mkdir -p "$sw"; : >"$sw/calls"
for n in 72 73; do pr_at "$n" "h$n" "$DOCS"; real_pr "$n"; done
redissue ""; lane_sweep
expect "red dev: no batch forms, nothing merges, nothing runs" "$(batch_tip),$(grep -oE "^pr merge [0-9]+" "$sw/calls" | paste -sd, -),$(grep -c '^workflow run' "$sw/calls")" ",,0"
rm -f "$sw/red.json"; lane_sweep
expect "red dev: once dev is green the ready PRs batch" "$(git -C "$sw/origin.git" log --first-parent --format=%s "dev..$(batch_tip)" | grep -oE '#[0-9]+' | paste -sd, -)" "#73,#72"

# A batch in flight on a base that holds dev's red commit is marked
# (<batch>-red) while dev is red; once dev is green again on a newer commit
# it is dropped with its probes and marker, and the same sweep forms a fresh
# batch on today's dev. Its PRs get no label and no comment.
rm -rf "$sw"; mkdir -p "$sw"; : >"$sw/calls"
for n in 74 75; do pr_at "$n" "h$n" "$DOCS"; real_pr "$n"; done
lane_sweep; TIP=$(batch_tip); BASE=$(git -C "$sw/origin.git" rev-parse dev)
redissue "$BASE"; lane_sweep
expect "red base: a batch on dev's red commit is marked" "$(redref)" 1
verdict "$TIP" failure; lane_sweep
expect "red base: it bisects meanwhile" "$( [[ -n "$(probe_sha 1)" ]] && echo probe)" "probe"
rm -f "$sw/red.json"; dev_moves docs/fix.md; FIX=$(git -C "$sw/origin.git" rev-parse dev); lane_sweep
expect "red base: once dev is green the marked batch, its probes and marker are gone" \
  "$(git -C "$sw/origin.git" for-each-ref 'refs/heads/lane/batch-*' --format='%(refname:short)' | grep -cvE '^lane/batch-[0-9]+$' || true),$(redref)" "0,0"
expect "red base: a fresh batch forms on the fix" \
  "$(git -C "$sw/origin.git" rev-parse "$(batch_tip)~2"),$(git -C "$sw/origin.git" log --first-parent --format=%s "dev..$(batch_tip)" | grep -oE '#[0-9]+' | paste -sd, -)" "$FIX,#75,#74"
expect "red base: its PRs get no label and no comment" "$(grep -cE '^pr (edit|comment) (74|75) ' "$sw/calls")" 0

# A batch whose base predates dev's red commit is never marked or dropped.
rm -rf "$sw"; mkdir -p "$sw"; : >"$sw/calls"
for n in 76 77; do pr_at "$n" "h$n" "$DOCS"; real_pr "$n"; done
lane_sweep; TIP=$(batch_tip)
dev_moves docs/red.md; redissue "$(git -C "$sw/origin.git" rev-parse dev)"; lane_sweep
rm -f "$sw/red.json"; lane_sweep
expect "red base: a batch on a base before the red commit is kept" "$(redref),$(batch_tip)" "0,$TIP"

# Culprit by bisect on a red dev (rung 2c): main at the base, dev three
# first-parent commits past it (#101 good, #102 bad, #103 good), the dev-red
# issue #500 naming main..<dev tip> with a Linux red, and red-triage's comment
# blaming #102 at 0.93. The lane probes #102's parent, then #102: two Linux
# runs, then the verdict on #500 and on #102's feature-lead issue (#78, by
# the PR body's Feature: line), and the probes go.
rm -rf "$sw"; mkdir -p "$sw"; : >"$sw/calls"
w="$sw/work"
git init -q --bare "$sw/origin.git"; git -C "$sw/origin.git" config uploadpack.allowFilter true
git init -q -b main "$w"; git -C "$w" config user.name t; git -C "$w" config user.email t@t; git -C "$w" config commit.gpgsign false
echo base >"$w/base.md"; git -C "$w" add -A; git -C "$w" commit -qm base
git -C "$w" switch -qc dev
for spec in "c1 fix(a): one (#101)" "c2 feat(b): two (#102)" "c3 docs: three (#103)"; do
  echo "${spec%% *}" >"$w/${spec%% *}.md"; git -C "$w" add -A; git -C "$w" commit -qm "${spec#* }"
done
git -C "$w" push -q "$sw/origin.git" main dev
M=$(git -C "$w" rev-parse main); C1=$(git -C "$w" rev-parse dev~2); C2=$(git -C "$w" rev-parse dev~1); C3=$(git -C "$w" rev-parse dev)
R7=${C3:0:7}
jq -n --arg b "$(printf 'CI on dev is red.\n\n- Run: https://github.com/qbtrix/creative-apps/actions/runs/9001\n- Failing jobs: linux\n- Culprit range: `main..%s`\n' "$C3")" '[{number: 500, body: $b, pull_request: null}]' >"$sw/red.json"
printf '%s\n' "Likely cause: #102 feat(b): two (Clef 0.93). Flaky: 0.10." "$RERUN_MARK $R7 red -->" >"$sw/500.comments"
jq -n '{body: "Adds two.\n\nFeature: easing\nFast-Check: pass"}' >"$sw/pull.102.json"
jq -n '{items: [{number: 70, title: "Feature: easing (old)"}, {number: 78, title: "Feature: easing"}]}' >"$sw/search.json"
verdict "$M" success; verdict "$C3" failure
lane_sweep
bprobe() { git -C "$sw/origin.git" rev-parse --verify -q "refs/heads/ci/bisect-$R7-$1" 2>/dev/null || true; }
expect "bisect dev: red-triage's confident guess gets its parent probed first" "$(bprobe 1)" "$C1"
expect "bisect dev: with one Linux run on the probe" "$(grep -c -- "-f linux_only=true --ref ci/bisect-$R7-1\$" "$sw/calls")" 1
verdict "$C1" success; lane_sweep
expect "bisect dev: a green parent probes the guess itself" "$(bprobe 2)" "$C2"
verdict "$C2" failure; lane_sweep
expect "bisect dev: the first red commit is posted on the dev-red issue" \
  "$(grep -c "^issue comment 500 .*Bisect: ${C2:0:7} feat(b): two (#102) is the first commit on dev whose Linux job fails. Green at ${C1:0:7} (https://github.com/qbtrix/creative-apps/actions/runs/777), red at ${C2:0:7} (.*); 2 Linux run(s)" "$sw/calls")" 1
expect "bisect dev: and on the open feature-lead issue the PR's Feature: line names" \
  "$(grep -c "^issue comment 78 .*your PR #102 (feat(b): two (#102)) is the first commit that turns dev's Linux job red" "$sw/calls")" 1
expect "bisect dev: the probes are gone" "$(git -C "$sw/origin.git" for-each-ref 'refs/heads/ci/bisect-*' | wc -l | tr -d ' ')" 0
lane_sweep
expect "bisect dev: a red with its verdict posted is not redone (two runs, two comments, nothing more)" "$(grep -c '^issue comment\|^workflow run' "$sw/calls")" 4
# dev stays red and ci.yml moves the issue's range to the newer red run (c4):
# the issue already has its verdict, so nothing is bisected again.
echo c4 >"$w/c4.md"; git -C "$w" add -A; git -C "$w" commit -qm "docs: four (#104)"; git -C "$w" push -q "$sw/origin.git" dev
C4=$(git -C "$w" rev-parse dev); verdict "$C4" failure
printf '%s\n' "$RERUN_MARK ${C4:0:7} red -->" >>"$sw/500.comments"
jq --arg b "$(printf 'CI on dev is red.\n\n- Run: https://github.com/qbtrix/creative-apps/actions/runs/9002\n- Failing jobs: linux\n- Culprit range: `main..%s`\n' "$C4")" '.[0].body = $b' "$sw/red.json" >"$sw/x" && mv "$sw/x" "$sw/red.json"
lane_sweep
expect "bisect dev: a newer red run on the same issue starts no second bisect" \
  "$(grep -c '^issue comment\|^workflow run' "$sw/calls"),$(git -C "$sw/origin.git" for-each-ref 'refs/heads/ci/bisect-*' | wc -l | tr -d ' ')" "4,0"

# The same chain by hand (--bisect), no guess: the midpoint first. With the
# run cap at 1 the second sweep stops and says where the culprit sits.
rm -f "$sw/500.comments" "$sw/checks.$C1.json"; : >"$sw/calls"
( FAST_LANE_RUN_LOOKUP_RETRIES=0 main --bisect "$M..$C3" 500 dev ) >/dev/null 2>&1 || { echo "FAIL sweep: main --bisect exited non-zero"; fail=1; }
expect "bisect by hand: probes the midpoint" "$(bprobe 1)" "$C1"
verdict "$C1" success
( MAX_BISECT=1 FAST_LANE_RUN_LOOKUP_RETRIES=0 main --bisect "$M..$C3" 500 dev ) >/dev/null 2>&1 || { echo "FAIL sweep: main --bisect exited non-zero"; fail=1; }
expect "bisect by hand: at the run cap it stops and names the range left" \
  "$(grep -c "^issue comment 500 .*stopped after 1 Linux runs: the Linux job is green at ${C1:0:7} and red at ${C3:0:7}; the culprit is one of the 2 commits between them" "$sw/calls")" 1
expect "bisect by hand: and drops its probes" "$(git -C "$sw/origin.git" for-each-ref 'refs/heads/ci/bisect-*' | wc -l | tr -d ' ')" 0

# A red on a timing budget test (rung 2c's vote mode): when every issue in the
# tip's failed log is a measured value against a budget, a probe is run up to
# 3 times and called on 2 of 3, the run cap is MAX_BISECT_BUDGET runs, and a
# value within BUDGET_NEAR of its budget makes the culprit "likely".
ISSUE_LINE='✘ Test focusChangeWithinBudget() recorded an issue at LibraryLoupeBudgetTests.swift:59:5: Expectation failed: (cost.median → 1.046542) <= (1 * scale → 1.0)'
bf() { printf '%s\n' "$@" | budget_failure; }
expect "budget: a median over its budget is a budget failure" "$(bf "$ISSUE_LINE" '✘ Test focusChangeWithinBudget() failed after 44.392 seconds with 1 issue.')" "1.046542 <= 1.0"
expect "budget: a literal budget counts" "$(bf '✘ Test keysWithinBudget() recorded an issue at LiveKeysBudgetTests.swift:37:9: Expectation failed: (costs[60] → 0.31) <= 0.25')" "0.31 <= 0.25"
expect "budget: one other failure means no budget mode" "$(bf "$ISSUE_LINE" '✘ Test opens() recorded an issue at OpenTests.swift:9:5: Expectation failed: (doc.layers.count → 3) == (4 → 4)')" ""
expect "budget: a size compare outside a budget test is no budget failure" "$(bf '✘ Test rows() recorded an issue at RowTests.swift:9:5: Expectation failed: (rows.count → 9) <= (8 → 8)')" ""
expect "budget: a known issue alone is no failure" "$(bf '✘ Test x() recorded a known issue at XTests.swift:1:1: Expectation failed: (median → 2.0) <= (budget → 1.0)')" ""
near() { if budget_near "$@"; then echo near; else echo far; fi; }
expect "budget: 4.7% over is near, 50% over is far, under is far" "$(near 1.046542 '<=' 1.0),$(near 1.5 '<=' 1.0),$(near 0.9 '<=' 1.0)" "near,far,far"
expect "budget: a floor works the other way" "$(near 54 '>=' 60),$(near 40 '>=' 60)" "near,far"

votes() {  # votes <sha> <conclusion>...: completed Linux runs on <sha>, oldest first
  local sha="$1" i=0 c; shift
  for c in "$@"; do
    i=$((i + 1))
    jq -n --arg c "$c" --arg t "2026-01-01T00:0$i:00Z" --arg u "https://github.com/qbtrix/creative-apps/actions/runs/88$i/job/77$i" \
      '{name: "Linux", status: "completed", conclusion: $c, started_at: $t, details_url: $u}'
  done | jq -s . >"$sw/checks.$sha.json"
}
red_tip() {  # red_tip <issue line>: the tip's one red Linux run, whose failed log holds that line
  jq -n '[{name: "Linux", status: "completed", conclusion: "failure", started_at: "2026-01-01T00:00:00Z",
    details_url: "https://github.com/qbtrix/creative-apps/actions/runs/9100/job/4242"}]' >"$sw/checks.$C3.json"
  printf '%s\nCI: FAIL (swift test (all) exited 1)\n' "$1" >"$sw/joblog.4242"
}
bisect_by_hand() { ( FAST_LANE_RUN_LOOKUP_RETRIES=0 main --bisect "$M..$C3" "$1" dev ) >/dev/null 2>&1 || { echo "FAIL sweep: main --bisect exited non-zero"; fail=1; }; }
dispatches() { grep -c -- "-f linux_only=true --ref ci/bisect-$R7-$1\$" "$sw/calls" || true; }

# 4.7% over a 1 ms budget: probe 1 needs 3 runs (red, green, red) and the verdict is "likely".
rm -f "$sw/checks.$C1.json" "$sw/checks.$C2.json"; : >"$sw/calls"; red_tip "$ISSUE_LINE"
bisect_by_hand 501
expect "vote: a budget red probes the midpoint once" "$(bprobe 1),$(dispatches 1)" "$C1,1"
votes "$C1" failure; bisect_by_hand 501
expect "vote: one red run is not a verdict, the probe runs again" "$(dispatches 1),$(grep -c '^issue comment 501 ' "$sw/calls")" "2,0"
votes "$C1" failure success; bisect_by_hand 501
expect "vote: one each, a third run" "$(dispatches 1),$(grep -c '^issue comment 501 ' "$sw/calls")" "3,0"
votes "$C1" failure success failure; bisect_by_hand 501
expect "vote: 2 of 3 red names the culprit as likely, counting runs" \
  "$(grep -c "^issue comment 501 .*Bisect (likely): ${C1:0:7} fix(a): one (#101) is likely the first commit on dev whose Linux job fails.*3 Linux run(s).*measured 1.046542 against 1.0, within 15% of it" "$sw/calls")" 1
expect "vote: and drops its probes" "$(git -C "$sw/origin.git" for-each-ref 'refs/heads/ci/bisect-*' | wc -l | tr -d ' ')" 0

# Twice the budget: 2 green runs settle probe 1, 2 red settle probe 2, and the verdict is certain.
rm -f "$sw/checks.$C1.json" "$sw/checks.$C2.json"; : >"$sw/calls"
red_tip "${ISSUE_LINE/1.046542/2.1}"
bisect_by_hand 502; votes "$C1" success success; bisect_by_hand 502
expect "vote: 2 green runs settle a probe without a third" "$(dispatches 1),$(bprobe 2)" "1,$C2"
votes "$C2" failure failure; bisect_by_hand 502
expect "vote: far past the budget the verdict is certain and says how it was voted" \
  "$(grep -c "^issue comment 502 .*Bisect: ${C2:0:7} feat(b): two (#102) is the first commit on dev whose Linux job fails.*4 Linux run(s).*2 of 3" "$sw/calls"),$(grep -c 'likely' "$sw/calls")" "1,0"

# The run cap counts runs in vote mode.
rm -f "$sw/checks.$C1.json" "$sw/checks.$C2.json"; : >"$sw/calls"; red_tip "$ISSUE_LINE"
bisect_by_hand 503; votes "$C1" failure success
( MAX_BISECT_BUDGET=2 FAST_LANE_RUN_LOOKUP_RETRIES=0 main --bisect "$M..$C3" 503 dev ) >/dev/null 2>&1 || { echo "FAIL sweep: main --bisect exited non-zero"; fail=1; }
expect "vote: at the run cap it stops and names the range left" \
  "$(grep -c "^issue comment 503 .*stopped after 2 Linux runs: the Linux job is green at ${M:0:7} and red at ${C3:0:7}" "$sw/calls")" 1

# A tip log with a non-budget failure keeps one run per probe.
rm -f "$sw/checks.$C1.json" "$sw/checks.$C2.json"; : >"$sw/calls"
red_tip '✘ Test opens() recorded an issue at OpenTests.swift:9:5: Expectation failed: (doc.layers.count → 3) == (4 → 4)'
bisect_by_hand 504; votes "$C1" failure; bisect_by_hand 504
expect "vote: a plain red names its culprit on one run" \
  "$(dispatches 1),$(grep -c "^issue comment 504 .*Bisect: ${C1:0:7} fix(a): one (#101) is the first commit.*; 1 Linux run(s) on ci/bisect branches, now deleted. <!--" "$sw/calls")" "1,1"

# Vote mode in a batch bisect (rung 2b, #2641 took needs-fix from one flaky
# run): when the red tip's failed log holds only budget failures, each probe
# runs up to 3 times and is called on 2 of 3. #90 good, #91 bad, #92 good, the
# value twice its budget: probe 1's first run is red, then green, green, so
# #91 is the culprit, not #90.
DOCS='[{"filename": "docs/blueprints/photo/features/a.md", "status": "modified"}]'
tip_red() {  # tip_red <sha> <job id> <failed-log line>: one red Linux run on <sha> whose failed log holds that line
  jq -n --arg u "https://github.com/qbtrix/creative-apps/actions/runs/9200/job/$2" '[{name: "Linux", status: "completed",
    conclusion: "failure", started_at: "2026-01-01T00:00:00Z", details_url: $u}]' >"$sw/checks.$1.json"
  printf '%s\nCI: FAIL (swift test (all) exited 1)\n' "$3" >"$sw/joblog.$2"
}
batch_br() { git -C "$sw/origin.git" for-each-ref 'refs/heads/lane/batch-*' --format='%(refname:short)' | grep -E '^lane/batch-[0-9]+$'; }
bdispatches() { grep -c -- "-f linux_only=true --ref $BR-$1\$" "$sw/calls" || true; }
rm -rf "$sw"; mkdir -p "$sw"; : >"$sw/calls"
for n in 90 91 92; do pr_at "$n" "h$n" "$DOCS"; real_pr "$n"; done
H91=$(jq -r .headRefOid "$sw/91.json")
lane_sweep
TIP=$(batch_tip); BR=$(batch_br)
tip_red "$TIP" 4300 "${ISSUE_LINE/1.046542/2.1}"
lane_sweep
expect "batch vote: a budget red probes the chain after 1 PR once" "$(probe_sha 1),$(bdispatches 1)" "$(git -C "$sw/origin.git" rev-parse "$TIP~2"),1"
votes "$(probe_sha 1)" failure; lane_sweep
expect "batch vote: one red run is no verdict, the probe runs again (no move to the base)" \
  "$(bdispatches 1),$(grep -c -- '--add-label needs-fix' "$sw/calls"),$(probe_sha 0)" "2,0,"
votes "$(probe_sha 1)" failure success; lane_sweep
expect "batch vote: one each, a third run" "$(bdispatches 1),$(grep -c -- '--add-label needs-fix' "$sw/calls")" "3,0"
votes "$(probe_sha 1)" failure success success; lane_sweep
expect "batch vote: 2 of 3 green moves on to the chain after 2 PRs" "$(probe_sha 2)" "$(git -C "$sw/origin.git" rev-parse "$TIP~1")"
votes "$(probe_sha 2)" failure failure; lane_sweep
expect "batch vote: 2 of 3 red names the right PR" \
  "$(grep -c '^pr edit 91 .*--add-label needs-fix' "$sw/calls"),$(grep -c '^pr edit 90 .*--add-label needs-fix' "$sw/calls")" "1,0"
expect "batch vote: the PRs around it land" "$(grep -oE '^pr merge [0-9]+' "$sw/calls" | paste -sd, -)" "pr merge 90,pr merge 92"
expect "batch vote: the comment says how it was voted, and far from the budget it is not likely" \
  "$(grep -c "^pr comment 91 .*head $H91 fails the Linux check once it lands on dev after #90: .*measured 2.1 against 1.0.*2 of 3" "$sw/calls"),$(grep -c 'likely' "$sw/calls")" "1,0"

# 4.7% over its budget: the needs-fix comment says likely, and the culprit
# still waits at its head on the next sweep.
rm -rf "$sw"; mkdir -p "$sw"; : >"$sw/calls"
for n in 93 94; do pr_at "$n" "h$n" "$DOCS"; real_pr "$n"; done
H94=$(jq -r .headRefOid "$sw/94.json")
lane_sweep
TIP=$(batch_tip); BR=$(batch_br)
tip_red "$TIP" 4301 "$ISSUE_LINE"
lane_sweep
votes "$(probe_sha 1)" success success; lane_sweep
expect "batch vote: near its budget the needs-fix comment says likely" \
  "$(grep -c '^pr edit 94 .*--add-label needs-fix' "$sw/calls"),$(grep -c "^pr comment 94 .*head $H94 fails the Linux check once it lands on dev after #93: .*measured 1.046542 against 1.0, within 15% of it.*treat this as likely, not certain" "$sw/calls")" "1,1"
lane_sweep
expect "batch vote: a likely culprit still waits at its head, no writes" "$(grep -c '^pr [a-z]* 94 ' "$sw/calls")" 2

# A plain red with a readable log keeps one run per probe: #95 good, #96 bad.
rm -rf "$sw"; mkdir -p "$sw"; : >"$sw/calls"
for n in 95 96; do pr_at "$n" "h$n" "$DOCS"; real_pr "$n"; done
lane_sweep
TIP=$(batch_tip); BR=$(batch_br)
tip_red "$TIP" 4302 '✘ Test opens() recorded an issue at OpenTests.swift:9:5: Expectation failed: (doc.layers.count → 3) == (4 → 4)'
lane_sweep
verdict "$(probe_sha 1)" success; lane_sweep
expect "batch vote: a plain red names its culprit on one run per probe" \
  "$(bdispatches 1),$(grep -c '^pr edit 96 .*--add-label needs-fix' "$sw/calls"),$(grep -c '2 of 3' "$sw/calls")" "1,1,0"

# A Belt lead often opens its PR without the label (#2637, #2796, #2814, #2815).
# The sweep lists every open PR once and labels the crew's Belt-Lead PRs into
# dev that carry no opt-out, then evaluates them like any labelled PR.
# #30 is such a PR; #31 has no Belt-Lead line; #32's author is off the
# allowlist; #33 and #34 carry an opt-out label. Only #30 is labelled and merged.
rm -rf "$sw"; mkdir -p "$sw"; : >"$sw/calls"
for n in 30 31 32 33 34; do
  pr_at "$n" "h$n" "$DOCS"
  jq '.labels = [] | .body += "\nBelt-Lead: act-20261018-1"' "$sw/$n.json" >"$sw/x" && mv "$sw/x" "$sw/$n.json"
done
jq '.body = "Closes #1\n\nFast-Check: pass\nHead: h31"' "$sw/31.json" >"$sw/x" && mv "$sw/x" "$sw/31.json"
jq '.author.login = "someone-else"' "$sw/32.json" >"$sw/x" && mv "$sw/x" "$sw/32.json"
jq '.labels = [{"name":"no-fast-lane"}]' "$sw/33.json" >"$sw/x" && mv "$sw/x" "$sw/33.json"
jq '.labels = [{"name":"needs-human"}]' "$sw/34.json" >"$sw/x" && mv "$sw/x" "$sw/34.json"; real_pr 30
lane_sweep
expect "autolabel: a crew PR with a Belt-Lead line gets the label and one comment" \
  "$(grep -c '^pr edit 30 .*--add-label fast-lane$' "$sw/calls"),$(grep -c '^pr comment 30 .*Fast lane: labelled because the PR carries Belt-Lead\.' "$sw/calls")" "1,1"
expect "autolabel: the labelled PR is evaluated in the same sweep" "$(grep -c '^pr merge 30' "$sw/calls")" 1
expect "autolabel: a PR without a Belt-Lead line is left alone" "$(grep -cE '^pr [a-z]+ 31 ' "$sw/calls")" 0
expect "autolabel: a non-crew author is left alone" "$(grep -cE '^pr [a-z]+ 32 ' "$sw/calls")" 0
expect "autolabel: no-fast-lane and needs-human PRs are left alone" "$(grep -cE '^pr [a-z]+ (33|34) ' "$sw/calls")" 0

# Batch macOS gate: with LANE_MAC_PER_PR=0 (the default) no code PR gets a
# macOS build of its own. A batch whose PRs change code runs one macOS gate
# (ci.yml's mac_only) next to its Linux check, scoped to the union of its apps
# (scripts/test-scope build-apps over the batch's changed code), and lands
# only when both are green on its head. Batches order p0, beta, the rest; one
# forms when a slot frees, at LANE_BATCH_MAX, or on the timer, and never while
# the lane's macOS runs fill LANE_MAC_SLOTS.
LANE_MAC_PER_PR=0
build "flag off: a code PR needs no build of its own" "eligible|150|2|Fast-Check marker" "$MARKED" "$APP" -
build "flag off: a red per-PR macOS build holds nothing" "eligible|150|2|Fast-Check marker" "$MARKED" "$APP" '.conclusion = "failure"' \
  '[{"__typename":"CheckRun","name":"macOS build","workflowName":"","status":"COMPLETED","conclusion":"FAILURE"}]'
LINUX_URL="https://github.com/qbtrix/creative-apps/actions/runs/777"
MAC_URL="https://github.com/qbtrix/creative-apps/actions/runs/888/job/88"
gate() {  # gate <sha> <Linux> <macOS> [<macOS job name>]: each success, failure, in_progress or none
  jq -n --arg l "$2" --arg m "$3" --arg mn "${4:-macOS}" --arg lu "$LINUX_URL" --arg mu "$MAC_URL" '
    def run(n; c; u): if c == "none" then empty else {name: n, status: (if c == "in_progress" then "in_progress" else "completed" end),
      conclusion: (if c == "in_progress" then null else c end), started_at: "2026-01-01T00:00:00Z", details_url: u} end;
    [run("Linux"; $l; $lu), run($mn; $m; $mu)]' >"$sw/checks.$1.json"
}
cpr() {  # cpr <n> <path>: fixture PR <n> changing <path>, with a real branch
  pr_at "$1" "h$1" "$(jq -n --arg p "$2" '[{filename: $p, status: "modified"}]')"; real_pr "$1" "$2"
}
label() { jq --arg l "$2" '.labels += [{name: $l}]' "$sw/$1.json" >"$sw/x" && mv "$sw/x" "$sw/$1.json"; }
dated() { jq --argjson ago "$2" '.commits = [{oid: .headRefOid, messageHeadline: "x", committedDate: (now - $ago | todate)}]' "$sw/$1.json" >"$sw/x" && mv "$sw/x" "$sw/$1.json"; }
merges() { grep -oE '^pr merge [0-9]+' "$sw/calls" | paste -sd, -; }
fresh() { rm -rf "$sw"; mkdir -p "$sw"; : >"$sw/calls"; }

# Flag on: a lone code PR gets today's per-PR build and no batch.
fresh; cpr 90 Sources/PhotoModel/PhotoDocument.swift
LANE_MAC_PER_PR=1 lane_sweep
expect "flag on: a lone code PR gets one per-PR build, no batch" \
  "$(grep -c -- '-f build_only=true -f app=photo --ref feat/90$' "$sw/calls"),$(grep -c -- '-f mac_only=true' "$sw/calls"),$(batch_tip)" "1,0,"
# Flag off: the same PR is a batch of one with a Linux check and a macOS gate.
fresh; cpr 90 Sources/PhotoModel/PhotoDocument.swift
lane_sweep
TIP=$(batch_tip); BR=$(batch_br)
expect "flag off: a lone code PR is a batch of one, no per-PR build, nothing merged" \
  "$(grep -c -- '-f build_only=true' "$sw/calls"),$(merges),${BR:+batch}" "0,,batch"
expect "flag off: the batch gets a Linux check and one macOS gate scoped to its app" \
  "$(grep -c -- "-f linux_only=true --ref $BR\$" "$sw/calls"),$(grep -c -- "-f mac_only=true -f app=photo --ref $BR\$" "$sw/calls")" "1,1"
gate "$TIP" success in_progress "macOS (photo)"; lane_sweep
expect "gate: a green Linux check alone lands nothing and starts nothing more" \
  "$(merges),$(grep -c -- '-f mac_only=true' "$sw/calls")" ",1"
gate "$TIP" success success "macOS (photo)"; lane_sweep
expect "gate: Linux and macOS green: it lands, and its comment names both runs" \
  "$(merges),$(grep -c "^pr comment 90 .*batch of 1 PRs checked together on Linux and macOS: $LINUX_URL, $MAC_URL" "$sw/calls")" "pr merge 90,1"

# A green batch: a p0 docs PR, a beta Design PR and a plain Photo PR land in
# priority order, and the macOS gate covers the union of their apps.
fresh
cpr 91 Sources/PhotoApp/PhotoCanvas.swift; cpr 92 Sources/DesignModel/DesignDocument.swift
pr_at 93 h93 "$DOCS"; real_pr 93
label 93 p0; label 92 beta
lane_sweep
TIP=$(batch_tip); BR=$(batch_br)
expect "order: p0, then beta, then the rest" \
  "$(git -C "$sw/origin.git" log --first-parent --reverse --format=%s "dev..$TIP" | grep -oE '#[0-9]+' | paste -sd, -)" "#93,#92,#91"
expect "union: one macOS gate for both apps, no Linux-less landing" \
  "$(grep -c -- "-f mac_only=true -f app=design,photo --ref $BR\$" "$sw/calls"),$(merges)" "1,"
gate "$TIP" success success "macOS (design,photo)"; lane_sweep
expect "union: green on both lands all three in that order" "$(merges)" "pr merge 93,pr merge 92,pr merge 91"

# A shared path builds and tests every app: the gate runs with no app.
fresh; cpr 94 Sources/SuiteUI/GlassPanel.swift; lane_sweep; BR=$(batch_br)
expect "shared: SuiteUI gets the full macOS gate" \
  "$(grep -c -- "-f mac_only=true --ref $BR\$" "$sw/calls"),$(grep -c -- '-f app=' "$sw/calls")" "1,0"
# The scope also covers the tests scripts/test-scope changed picks for every
# changed path, code or not: SuiteUI's tests next to an app's, a fixture a
# Model test reads, a golden PNG (every snapshot suite, so the full gate).
fresh; cpr 130 Tests/SuiteUITests/Fixtures/glass.png; cpr 133 Sources/PhotoApp/A.swift; lane_sweep; BR=$(batch_br || true)
expect "scope: a SuiteUITests fixture adds suiteui to the app's gate" "$(grep -c -- "-f mac_only=true -f app=photo,suiteui --ref $BR\$" "$sw/calls")" 1
fresh; cpr 131 Tests/PhotoModelTests/Fixtures/png-parity/a.png; lane_sweep; BR=$(batch_br || true)
expect "scope: a fixture a Model test reads gets a macOS gate, not an instant landing" \
  "$(merges),$(grep -c -- "-f mac_only=true -f app=photo --ref $BR\$" "$sw/calls")" ",1"
fresh; cpr 132 Tests/AppSnapshotTests/Golden/canvas/brush.png; lane_sweep; BR=$(batch_br || true)
expect "scope: a golden PNG gets the full macOS gate" "$(merges),$(grep -c -- "-f mac_only=true --ref $BR\$" "$sw/calls")" ",1"

# A docs-only batch needs no macOS: Linux alone lands it, as before.
fresh; pr_at 95 h95 "$DOCS"; real_pr 95; pr_at 96 h96 "$DOCS"; real_pr 96; lane_sweep
gate "$(batch_tip)" success none; lane_sweep
expect "docs: a batch with no code has no macOS gate and lands on Linux" \
  "$(grep -c -- '-f mac_only=true' "$sw/calls"),$(merges)" "0,pr merge 95,pr merge 96"

# A red batch: #95 and #97 are fine, #96 breaks the macOS gate. The bisect
# probes each prefix on Linux and macOS, ejects #96 naming the macOS job and
# #98 (stacked on its branch), lands #95, and at once (a slot just freed)
# starts the next batch with #97.
fresh
cpr 95 Sources/PhotoModel/A.swift; cpr 96 Sources/PhotoApp/B.swift; cpr 97 Sources/PhotoModel/C.swift
pr_at 98 h98 "$DOCS"; jq '.baseRefName = "feat/96" | .headRefName = "feat/98"' "$sw/98.json" >"$sw/x" && mv "$sw/x" "$sw/98.json"
H96=$(jq -r .headRefOid "$sw/96.json")
lane_sweep
TIP=$(batch_tip); BR=$(batch_br)
gate "$TIP" success failure "macOS (photo)"; lane_sweep
expect "red: a macOS-red tip probes the chain after 1 PR on Linux and macOS" \
  "$(probe_sha 1),$(grep -c -- "-f linux_only=true --ref $BR-1\$" "$sw/calls"),$(grep -c -- "-f mac_only=true -f app=photo --ref $BR-1\$" "$sw/calls")" \
  "$(git -C "$sw/origin.git" rev-parse "$TIP~2"),1,1"
gate "$(probe_sha 1)" success in_progress "macOS (photo)"; lane_sweep
expect "red: a probe waits for its macOS gate too" "$(probe_sha 2),$(merges)" ","
gate "$(probe_sha 1)" success success "macOS (photo)"; lane_sweep
gate "$(probe_sha 2)" success failure "macOS (photo)"; lane_sweep
expect "red: the culprit's PRs before it land" "$(merges)" "pr merge 95"
expect "red: the culprit gets needs-fix and one comment naming the macOS job, its run and its stacked PR" \
  "$(grep -c '^pr edit 96 .*--add-label needs-fix' "$sw/calls"),$(grep -c "^pr comment 96 .*head $H96 fails the macOS (photo) check once it lands on dev after #95: $MAC_URL\. Those PRs merged; This one has the needs-fix label and waits\. Stacked on its branch: #98, which wait for the fix" "$sw/calls")" "1,1"
expect "red: a slot freed, so the next batch (#97) forms in the same run" \
  "$(git -C "$sw/origin.git" log --first-parent --format=%s "dev..$(batch_tip)" | grep -oE '#[0-9]+' | paste -sd, -)" "#97"
lane_sweep
expect "red: the culprit waits at its head" "$(grep -c '^pr merge 96' "$sw/calls")" 0

# The local Mac gate's commit status is a macOS pass like the GitHub job.
fresh; cpr 99 Sources/PhotoModel/A.swift; lane_sweep; TIP=$(batch_tip)
gate "$TIP" success none
jq -n '{statuses: [{context: "local-ci/macos", state: "success", target_url: "https://mac.local/ci/1"}]}' >"$sw/status.$TIP.json"
lane_sweep
expect "local: a local-ci/macos pass lands the batch" \
  "$(merges),$(grep -c '^pr comment 99 .*on Linux and macOS: .*https://mac.local/ci/1' "$sw/calls")" "pr merge 99,1"
# A red on the same head outranks a green: the local gate skips known reds
# (CI_LOCAL_SKIP), so its pass never covers a GitHub macOS failure, nor the
# other way round. A GitHub job still running doesn't hold a local pass.
lstatus() { jq -n --arg s "$2" '{statuses: [{context: "local-ci/macos", state: $s, target_url: "https://mac.local/ci/1"}]}' >"$sw/status.$1.json"; }
fresh; cpr 120 Sources/PhotoModel/A.swift; lane_sweep; TIP=$(batch_tip)
gate "$TIP" success failure "macOS (photo)"; lstatus "$TIP" success; lane_sweep
expect "local: a local pass doesn't land a batch GitHub's macOS job fails" "$(merges),$(grep -c '^pr merge 120' "$sw/calls")" ",0"
fresh; cpr 121 Sources/PhotoModel/A.swift; lane_sweep; TIP=$(batch_tip)
gate "$TIP" success success "macOS (photo)"; lstatus "$TIP" failure; lane_sweep
expect "local: a GitHub pass doesn't land a batch the local gate fails" "$(merges)" ""
fresh; cpr 122 Sources/PhotoModel/A.swift; lane_sweep; TIP=$(batch_tip)
gate "$TIP" success in_progress "macOS (photo)"; lstatus "$TIP" success; lane_sweep
expect "local: a local pass lands while GitHub's macOS job still runs" "$(merges)" "pr merge 122"

# LANE_KILN=1: a fresh batch holds its mac_only run up to LANE_KILN_WAIT_MIN
# minutes for the local Mac check's local-ci/macos status, read by state and
# context, never by its description. Its `error` is no answer: no red, no
# bisect, and mac_only goes out once the wait runs out (LANE_KILN_WAIT_MIN=0
# here stands for a batch older than the wait).
mac_only() { grep -c -- "-f mac_only=true -f app=photo --ref $1\$" "$sw/calls" || true; }
ldesc() { jq -n --arg s "$2" --arg d "$3" '{statuses: [{context: "local-ci/macos", state: $s, description: $d, target_url: "https://mac.local/ci/1"}]}' >"$sw/status.$1.json"; }
fresh; cpr 140 Sources/PhotoModel/A.swift
LANE_KILN=1 lane_sweep; TIP=$(batch_tip); BR=$(batch_br)
expect "local hold: a fresh batch gets its Linux check and no mac_only run" \
  "$(grep -c -- "-f linux_only=true --ref $BR\$" "$sw/calls"),$(mac_only "$BR")" "1,0"
gate "$TIP" success none; ldesc "$TIP" success "mac check ✘ (a description the lane ignores)"; LANE_KILN=1 lane_sweep
expect "local hold: a green local-ci/macos within the wait lands it with no mac_only run" \
  "$(merges),$(mac_only "$BR")" "pr merge 140,0"
fresh; cpr 141 Sources/PhotoModel/A.swift
LANE_KILN=1 lane_sweep; TIP=$(batch_tip); BR=$(batch_br)
gate "$TIP" success none; LANE_KILN=1 lane_sweep
expect "local hold: no answer yet keeps holding" "$(mac_only "$BR"),$(merges)" "0,"
gate "$TIP" success none; LANE_KILN=1 LANE_KILN_WAIT_MIN=0 lane_sweep
expect "local hold: no answer within the wait dispatches mac_only as before" "$(mac_only "$BR"),$(merges)" "1,"
fresh; cpr 142 Sources/PhotoModel/A.swift; cpr 143 Sources/PhotoModel/B.swift
LANE_KILN=1 lane_sweep; TIP=$(batch_tip); BR=$(batch_br)
gate "$TIP" success none; ldesc "$TIP" error "mac check ✘ infra"; LANE_KILN=1 lane_sweep
expect "local hold: an error within the wait is no answer: held, not red" \
  "$(mac_only "$BR"),$(probe_sha 1),$(redref),$(grep -c '^pr edit .*needs-fix' "$sw/calls" || true)" "0,,0,0"
LANE_KILN=1 LANE_KILN_WAIT_MIN=0 lane_sweep
expect "local hold: an error past the wait dispatches mac_only, no bisect" \
  "$(mac_only "$BR"),$(probe_sha 1),$(redref),$(merges)" "1,,0,"
fresh; cpr 144 Sources/PhotoModel/A.swift; cpr 145 Sources/PhotoModel/B.swift
LANE_KILN=1 lane_sweep; TIP=$(batch_tip); BR=$(batch_br)
gate "$TIP" success none; ldesc "$TIP" failure "mac check ✔ (a description the lane ignores)"; LANE_KILN=1 lane_sweep
expect "local hold: a failure is red: the bisect probes the chain after 1 PR" \
  "$(probe_sha 1),$(grep -c -- "-f linux_only=true --ref $BR-1\$" "$sw/calls"),$(mac_only "$BR"),$(merges)" \
  "$(git -C "$sw/origin.git" rev-parse "$TIP~1"),1,0,"

# Slots: the lane's queued and running macOS runs (gates and per-PR builds;
# other runs don't count) at LANE_MAC_SLOTS form no batch.
fresh; cpr 100 Sources/PhotoModel/A.swift
jq -n '[range(4) | {status: "in_progress", displayTitle: "macOS gate: photo"}] + [{status: "in_progress", displayTitle: "scoped: photo"}]' >"$sw/macruns.json"
lane_sweep
expect "slots: 4 of 4 busy: no batch, no dispatch" "$(batch_tip),$(grep -c '^workflow run' "$sw/calls")" ",0"
jq '.[0].status = "completed"' "$sw/macruns.json" >"$sw/x" && mv "$sw/x" "$sw/macruns.json"
lane_sweep
expect "slots: one frees: the batch forms" "$( [[ -n "$(batch_tip)" ]] && echo formed)" "formed"
rm -f "$sw/macruns.json"

# The timer: with no slot just freed, a code batch waits until its oldest
# ready head is LANE_BATCH_WAIT_MIN old; a batch that resolves frees a slot,
# and the PRs ready then batch at once.
LANE_BATCH_WAIT_MIN=10
fresh; cpr 101 Sources/PhotoModel/A.swift; dated 101 60
lane_sweep
expect "timer: a 1-minute-old head waits" "$(batch_tip),$(grep -c '^workflow run' "$sw/calls")" ",0"
dated 101 1200; lane_sweep; TIP=$(batch_tip)
expect "timer: at 20 minutes the batch forms" "${TIP:+formed}" "formed"
cpr 102 Sources/PhotoModel/B.swift; dated 102 60
gate "$TIP" success success "macOS (photo)"; lane_sweep
expect "timer: the batch lands, and the fresh PR batches at once" \
  "$(merges),$(git -C "$sw/origin.git" log --first-parent --format=%s "dev..$(batch_tip)" | grep -oE '#[0-9]+' | paste -sd, -)" "pr merge 101,#102"
LANE_BATCH_WAIT_MIN=0

# A red base is only "dev is red" for the jobs it is red on: dev red on Linux
# alone doesn't wave through a batch that also breaks macOS. Linux is set aside
# and the bisect names the macOS culprit.
fresh; cpr 103 Sources/PhotoApp/A.swift; cpr 104 Sources/PhotoModel/B.swift
lane_sweep; TIP=$(batch_tip); BR=$(batch_br)
gate "$TIP" failure failure "macOS (photo)"; lane_sweep
gate "$(probe_sha 1)" failure failure "macOS (photo)"; lane_sweep
expect "red base: a red first PR probes the base alone" "$(probe_sha 0)" "$(git -C "$sw/origin.git" rev-parse dev)"
gate "$(probe_sha 0)" failure success "macOS (photo)"; lane_sweep
expect "red base: dev red on Linux only lands nothing on own proof" "$(merges),$(grep -c "own proof" "$sw/calls")" ",0"
expect "red base: the macOS culprit is named" \
  "$(grep -c '^pr edit 103 .*--add-label needs-fix' "$sw/calls"),$(grep -c '^pr comment 103 .*fails the macOS (photo) check once it lands on dev:' "$sw/calls")" "1,1"
fresh; cpr 105 Sources/PhotoApp/A.swift; cpr 106 Sources/PhotoModel/B.swift
lane_sweep; TIP=$(batch_tip)
gate "$TIP" failure success "macOS (photo)"; lane_sweep
gate "$(probe_sha 1)" failure success "macOS (photo)"; lane_sweep
gate "$(probe_sha 0)" failure failure "macOS (photo)"; lane_sweep
expect "red base: red on every job the tip is red on lands on own proof, as before" "$(merges)" "pr merge 105,pr merge 106"
# Never on own proof while the tip's macOS gate still runs: dev red on Linux
# sets Linux aside, and the tip waits for macOS; green there, it lands.
fresh; cpr 107 Sources/PhotoApp/A.swift; cpr 108 Sources/PhotoModel/B.swift
lane_sweep; TIP=$(batch_tip)
gate "$TIP" failure in_progress "macOS (photo)"; lane_sweep
gate "$(probe_sha 1)" failure in_progress "macOS (photo)"; lane_sweep
gate "$(probe_sha 0)" failure success "macOS (photo)"; lane_sweep
expect "red base: a tip whose macOS gate still runs lands nothing" "$(merges),$(grep -c "own proof" "$sw/calls")" ",0"
gate "$TIP" failure success "macOS (photo)"; lane_sweep
expect "red base: once macOS passes, red only where dev is red, it lands on own proof" \
  "$(merges),$(grep -c '^pr comment 108 .*so this batch landed on each PR.s own proof' "$sw/calls")" "pr merge 107,pr merge 108,1"
# dev red on macOS: the batch is judged by failing tests, not by the job.
# Each chain commit's macOS gate has its own job (joblog.<id> is its failed
# log); the base's failing tests are set aside, any other one is the batch's.
mlog() {  # mlog <job id> <test>...: a macOS job's failed log with those tests failing
  local t; : >"$sw/joblog.$1"
  for t in "${@:2}"; do
    printf 'macOS (photo)\tScoped build and tests\t2026-10-23T04:39:07.2585450Z \xe2\x9c\x98 Test %s recorded an issue at %s:41:22: Expectation failed: (a \xe2\x86\x92 1) == (b \xe2\x86\x92 2)\n' "${t#*/}" "${t%%/*}" >>"$sw/joblog.$1"
  done
  printf 'macOS (photo)\tScoped build and tests\t2026-10-23T04:39:07.2588190Z \xe2\x9c\x98 Test run with 9 tests failed after 3.1 seconds with %s issues.\n' "$(( $# - 1 ))" >>"$sw/joblog.$1"
}
devred() {  # devred <n>: PRs n and n+1 batched, the tip, probe 1 and the base all red on macOS
  fresh; cpr "$1" Sources/PhotoApp/A.swift; cpr "$(( $1 + 1 ))" Sources/PhotoModel/B.swift
  lane_sweep; TIP=$(batch_tip)
  MAC_URL="$JOB/201" gate "$TIP" success failure "macOS (photo)"; lane_sweep
  MAC_URL="$JOB/202" gate "$(probe_sha 1)" success failure "macOS (photo)"; lane_sweep
  MAC_URL="$JOB/203" gate "$(probe_sha 0)" success failure "macOS (photo)"
}
JOB="https://github.com/qbtrix/creative-apps/actions/runs/888/job"
devred 110; mlog 201 Old.swift/a\(\); mlog 202 Old.swift/a\(\); mlog 203 Old.swift/a\(\); lane_sweep
expect "dev red macOS: a batch failing only dev's tests lands" "$(merges),$(grep -c '^pr edit .*needs-fix' "$sw/calls")" "pr merge 110,pr merge 111,0"
devred 112; mlog 201 Old.swift/a\(\) New.swift/b\(\); mlog 202 Old.swift/a\(\); mlog 203 Old.swift/a\(\); lane_sweep
expect "dev red macOS: a new failing test is not set aside" "$(grep -c "own proof" "$sw/calls"),$(grep -c '^pr merge 113' "$sw/calls")" "0,0"
expect "dev red macOS: the PR that adds it is named with the test" \
  "$(merges),$(grep -c '^pr edit 113 .*--add-label needs-fix' "$sw/calls"),$(grep -c "^pr comment 113 .*fails the macOS (photo) check once it lands on dev after #112: $JOB/201\. Tests failing with it that pass on dev: New\.swift/b()\." "$sw/calls")" \
  "pr merge 112,1,1"
devred 114; mlog 202 Old.swift/a\(\); mlog 203 Old.swift/a\(\); lane_sweep
expect "dev red macOS: an unreadable log lands nothing and names nothing" "$(merges),$(grep -c 'needs-fix' "$sw/calls")" ",0"
devred 116; printf 'macOS (photo)\tscripts/ci\t2026-10-23T04:39:07Z TEST PROCESS DIED\n' >"$sw/joblog.201"; mlog 202 Old.swift/a\(\); mlog 203 Old.swift/a\(\); lane_sweep
expect "dev red macOS: a crash with no test named is red, never dev's" \
  "$(merges),$(grep -c '^pr edit 117 .*--add-label needs-fix' "$sw/calls"),$(grep -c "own proof" "$sw/calls")" "pr merge 116,1,0"
# Sharded macOS tests (#5775): the `macOS` gate job only sums its shards, so
# the failing tests are read from the run's failed `macOS tests i/n` jobs.
fresh
printf 'macOS\tUNKNOWN STEP\t2026-10-26T21:58:21Z | macOS tests 1/3 | failure | 26 |\n' >"$sw/joblog.300"
jq -n '{jobs: [{id: 301, name: "macOS tests 1/3", conclusion: "failure"}, {id: 302, name: "macOS tests 2/3", conclusion: "failure"},
  {id: 303, name: "macOS compile", conclusion: "success"}, {id: 300, name: "macOS", conclusion: "failure"}]}' >"$sw/jobs.889.json"
printf 'macOS tests 1/3\tUNKNOWN STEP\t2026-10-26T21:32:14Z \xe2\x9c\x98 Test homeAtEachWidth() recorded an issue at AfterGlowHomeLayoutTests.swift:182:29: Expectation failed\n' >"$sw/joblog.301"
printf 'macOS tests 2/3\tUNKNOWN STEP\t2026-10-26T21:32:14Z \xe2\x94\x81 Test opens(_:) recorded a known issue with 1 argument c at ImportTests.swift:55:13: x\n' >"$sw/joblog.302"
SHARD_RED="red|https://github.com/qbtrix/creative-apps/actions/runs/889/job/300|macOS"
expect "dev red macOS: a sharded run's failing test is read from its shard, a known issue isn't" "$(mac_tests "$SHARD_RED")" "AfterGlowHomeLayoutTests.swift/homeAtEachWidth()"
rm "$sw/joblog.302"
expect "dev red macOS: an unreadable shard log fails the read, never a partial list" "$(mac_tests "$SHARD_RED" || echo unread)" "unread"
# dev red on macOS only (#5183's "Failing jobs: macos"): a batch that would
# run the macOS gate can't pass on that base, so none forms, and one in flight
# on the red sha is marked and dropped once dev is green on a fix. A docs batch
# runs no macOS gate and still forms.
fresh; cpr 140 Sources/PhotoModel/A.swift; cpr 141 Sources/PhotoModel/B.swift
redissue "" macos; lane_sweep
expect "dev red macOS only: no code batch forms, nothing runs" "$(batch_tip),$(merges),$(grep -c '^workflow run' "$sw/calls")" ",,0"
fresh; pr_at 142 h142 "$DOCS"; real_pr 142; pr_at 143 h143 "$DOCS"; real_pr 143
redissue "" macos; lane_sweep
expect "dev red macOS only: a docs batch (no macOS gate) still forms" "$( [[ -n "$(batch_tip)" ]] && echo formed)" "formed"
fresh; cpr 144 Sources/PhotoModel/A.swift; cpr 145 Sources/PhotoModel/B.swift
lane_sweep; BASE=$(git -C "$sw/origin.git" rev-parse dev)
redissue "$BASE" macos; lane_sweep
expect "dev red macOS only: a code batch on the red sha is marked" "$(redref)" 1
rm -f "$sw/red.json"; dev_moves docs/fix.md; FIX=$(git -C "$sw/origin.git" rev-parse dev); lane_sweep
expect "dev red macOS only: green on a fix drops it and forms a fresh batch there, no PR writes" \
  "$(redref),$(git -C "$sw/origin.git" rev-parse "$(batch_tip)~2"),$(git -C "$sw/origin.git" log --first-parent --format=%s "dev..$(batch_tip)" | grep -oE '#[0-9]+' | paste -sd, -),$(grep -cE '^pr (edit|comment) (144|145) ' "$sw/calls")" \
  "0,$FIX,#145,#144,0"
# Verify after merge, auto-revert (LANE_VERIFY_AFTER=1): a red dev gets its
# culprit's squash commit reverted in a PR the lane opens (lane/revert-<n>,
# lane-revert and p0, never fast-lane) and lands on its own Linux check, with
# no prescreen and no batch; CI on dev runs once it lands. The culprit's
# feature-lead issue hears why and a finding is filed for its app. One revert
# call per culprit (its marker on the issue), never a revert of a revert.
rvdev() {  # rvdev <jobs> <path|subject>...: main at a base, dev one commit per spec past it, dev-red #520 naming main..<dev tip> (RED), red on Linux there
  local jobs="$1" w="$sw/work" spec; shift
  fresh
  git init -q --bare "$sw/origin.git"; git -C "$sw/origin.git" config uploadpack.allowFilter true
  git init -q -b main "$w"; git -C "$w" config user.name t; git -C "$w" config user.email t@t; git -C "$w" config commit.gpgsign false
  cp "$here/../../.gitattributes" "$w/"; echo base >"$w/base.md"; git -C "$w" add -A; git -C "$w" commit -qm base
  git -C "$w" switch -qc dev
  for spec in "$@"; do
    mkdir -p "$w/$(dirname "${spec%%|*}")"; echo "$RANDOM" >>"$w/${spec%%|*}"; git -C "$w" add -A; git -C "$w" commit -qm "${spec#*|}"
  done
  git -C "$w" push -q "$sw/origin.git" main dev
  RED=$(git -C "$w" rev-parse dev)
  jq -n --arg b "$(printf 'CI on dev is red.\n\n- Run: https://github.com/qbtrix/creative-apps/actions/runs/9500\n- Failing jobs: %s\n- Culprit range: `main..%s`\n' "$jobs" "$RED")" \
    '[{number: 520, body: $b, pull_request: null}]' >"$sw/red.json"
  tip_red "$RED" 4343 '✘ Test opens() recorded an issue at OpenTests.swift:9:5: Expectation failed: (doc.layers.count → 3) == (4 → 4)'
  # The dev-red run 9500's jobs, every attempt (red_tests reads its newest failed attempt): that Linux job failed in attempt 1.
  jq -n '{jobs: [{id: 4343, name: "Linux", conclusion: "failure", run_attempt: 1}]}' >"$sw/jobs.9500.json"
  # The flake check already judged this red real (its rerun failed), so these cases start where today's lane does.
  printf '%s\n' "$RERUN_MARK ${RED:0:7} red -->" >"$sw/520.comments"
  jq -n '{body: "Adds a.\n\nFeature: easing"}' >"$sw/pull.201.json"
  jq -n '{items: [{number: 78, title: "Feature: easing"}]}' >"$sw/search.json"
}
creates() { grep -c '^pr create' "$sw/calls" || true; }
rvdev linux "Sources/PhotoModel/A.swift|feat(photo): a (#201)"
lane_sweep
expect "auto-revert: off by default (LANE_VERIFY_AFTER=0): a red dev opens no revert" \
  "$(creates),$(git -C "$sw/origin.git" for-each-ref 'refs/heads/lane/revert-*' | wc -l | tr -d ' '),$(grep -c 'lane-revert' "$sw/calls")" "0,0,0"
# One PR in range, Linux red: red_bisect names it and the same sweep reverts it.
LANE_VERIFY_AFTER=1 lane_sweep
RB=$(git -C "$sw/origin.git" rev-parse --verify -q refs/heads/lane/revert-201 || true)
expect "auto-revert: one revert of the culprit's squash commit, on today's dev, as lane/revert-201" \
  "$(git -C "$sw/origin.git" log -1 --format=%s "$RB"),$(git -C "$sw/origin.git" rev-parse "$RB~1"),$(git -C "$sw/origin.git" diff --name-only "$RB~1" "$RB")" \
  "Revert \"feat(photo): a (#201)\",$RED,Sources/PhotoModel/A.swift"
expect "auto-revert: opened as a lane-revert p0 PR, never fast-lane" \
  "$(creates),$(grep -c -- '^pr create .*--head lane/revert-201 --label lane-revert --label p0 --title Revert "feat(photo): a (#201)" ' "$sw/calls"),$(grep -c -- '--label fast-lane' "$sw/calls")" "1,1,0"
expect "auto-revert: its body names the failing job, test and run, and refs dev-red without closing it" \
  "$(jq -r .body "$sw/600.json" | grep -cF "Reverts #201 (feat(photo): a (#201)): dev went red on linux at ${RED:0:7} (dev-red #520, run https://github.com/qbtrix/creative-apps/actions/runs/9500), failing OpenTests.swift/opens()."),$(jq -r .body "$sw/600.json" | grep -cE '(^|[^A-Za-z])([Cc]loses|[Ff]ixes|[Rr]esolves) #520')" "1,0"
expect "auto-revert: the dev-red issue records the one call" \
  "$(grep -c "^issue comment 520 .*Auto-revert: #201 (${RED:0:7}) is the culprit (the bisect on dev-red #520 named it); the lane opened #600 to revert it\. <!-- lane-revert ${RED:0:7} -->" "$sw/calls")" 1
expect "auto-revert: the culprit's feature-lead issue hears why and how to bring it back" \
  "$(grep -c '^issue comment 78 .*Fast lane: #201 was reverted by #600\. dev went red on linux .*reverts #600.s commit and fixes the failure' "$sw/calls")" 1
expect "auto-revert: a finding is filed for its app" \
  "$(grep -c '^issue create .*--title Reverted #201: dev red on linux --label finding --label line:photo --body #201 (feat(photo): a (#201)) was reverted by #600\.' "$sw/calls")" 1
LANE_VERIFY_AFTER=1 lane_sweep; LANE_VERIFY_AFTER=1 lane_sweep
RH=$(jq -r .headRefOid "$sw/600.json")
expect "auto-revert: then one Linux check on the revert, once, and no second revert" \
  "$(grep -c -- '-f linux_only=true --ref lane/revert-201$' "$sw/calls"),$(creates),$(merges)" "1,1,"
verdict "$RH" success; LANE_VERIFY_AFTER=1 lane_sweep
expect "auto-revert: it lands on that check alone (no prescreen, no batch, dev red and all), and CI on dev runs" \
  "$(merges),$(batch_tip),$(grep -c '^workflow run ci.yml -R qbtrix/creative-apps --ref dev$' "$sw/calls"),$(grep -c '^pr comment 600 .*merged into dev (.*its own Linux check' "$sw/calls")" "pr merge 600,,1,1"
LANE_VERIFY_AFTER=1 lane_sweep
expect "auto-revert: dev still red after its revert waits for a human: no second revert" "$(creates),$(grep -c '^issue comment 520 .*Auto-revert' "$sw/calls")" "1,1"

# Never a revert of a revert: the only PR in range is one, so the issue says so, once.
rvdev linux 'Sources/PhotoModel/A.swift|Revert "feat(photo): a (#201)" (#205)'
LANE_VERIFY_AFTER=1 lane_sweep; LANE_VERIFY_AFTER=1 lane_sweep
expect "auto-revert: never reverts a revert, and says so once on the issue" \
  "$(creates),$(grep -c "^issue comment 520 .*is a revert itself, and the lane never reverts a revert, so a human looks\. <!-- lane-revert ${RED:0:7} -->" "$sw/calls"),$(grep -c '^issue comment 520 .*Auto-revert' "$sw/calls")" "0,1,1"

# A revert lands only under the dev-red issue it refs: one left open from an
# older red is never landed under a new issue.
rvdev linux "Sources/PhotoModel/A.swift|feat(photo): a (#201)"
LANE_VERIFY_AFTER=1 lane_sweep; verdict "$(jq -r .headRefOid "$sw/600.json")" success
jq '.[0].number = 530' "$sw/red.json" >"$sw/x" && mv "$sw/x" "$sw/red.json"
printf '%s\n' "Auto-revert: an earlier call. <!-- lane-revert none -->" "$RERUN_MARK ${RED:0:7} red -->" >"$sw/530.comments"
LANE_VERIFY_AFTER=1 lane_sweep
expect "auto-revert: a revert from an older dev-red issue is never checked or landed under a new one" \
  "$(merges),$(grep -c -- '--ref lane/revert-201$' "$sw/calls"),$(creates)" ",0,1"

# A culprit on a protected path stays with a human (the lane's token can't push workflows either).
rvdev linux "scripts/tool.sh|chore: tool (#201)"
LANE_VERIFY_AFTER=1 lane_sweep
expect "auto-revert: a culprit touching a protected path is left to a human" \
  "$(creates),$(git -C "$sw/origin.git" for-each-ref 'refs/heads/lane/revert-*' | wc -l | tr -d ' '),$(grep -c "^issue comment 520 .*touches protected paths (scripts/tool.sh), so a human reverts it\. <!-- lane-revert" "$sw/calls")" "0,0,1"

# A revert GitHub refuses as conflicting (dev moved under it) is rebuilt on today's dev.
rvdev linux "Sources/PhotoModel/A.swift|feat(photo): a (#201)"
LANE_VERIFY_AFTER=1 lane_sweep; verdict "$(jq -r .headRefOid "$sw/600.json")" success
dev_moves docs/later.md; DEV=$(git -C "$sw/origin.git" rev-parse dev)
jq '.mergeable = "CONFLICTING"' "$sw/600.json" >"$sw/x" && mv "$sw/x" "$sw/600.json"; touch "$sw/merge.fail.600"
LANE_VERIFY_AFTER=1 lane_sweep
expect "auto-revert: a revert refused as conflicting is rebuilt on today's dev, not merged" \
  "$(merges),$(git -C "$sw/origin.git" rev-parse refs/heads/lane/revert-201~1),$(git -C "$sw/origin.git" diff --name-only "$DEV" refs/heads/lane/revert-201)" ",$DEV,Sources/PhotoModel/A.swift"

# A Linux red with two PRs waits for the bisect, then reverts the PR it names.
rvdev linux "docs/a.md|docs: a (#201)" "docs/b.md|docs: b (#202)"
LANE_VERIFY_AFTER=1 lane_sweep
expect "auto-revert: two PRs and no bisect verdict yet: no revert, no note" "$(creates),$(grep -c '^issue comment 520 .*Auto-revert' "$sw/calls")" "0,0"
verdict "$(git -C "$sw/origin.git" rev-parse dev~1)" failure; LANE_VERIFY_AFTER=1 lane_sweep
expect "auto-revert: once the bisect names #201, only #201 is reverted" \
  "$(creates),$(grep -c -- '^pr create .*--head lane/revert-201 ' "$sw/calls"),$(git -C "$sw/origin.git" diff --name-only dev refs/heads/lane/revert-201),$(grep -c 'line:suite' "$sw/calls")" "1,1,docs/a.md,1"

# One call per certain culprit, not per issue (#5350): an open dev-red issue
# whose first call was a no-culprit note still reverts the PR a later bisect
# names, once; later sweeps on the same culprit open none.
rvdev linux "docs/a.md|docs: a (#201)" "Sources/PhotoModel/B.swift|feat(photo): b (#202)"
printf '%s\n' "Auto-revert: 2 PRs in main..abc1234 and no bisect verdict names one of them (red: macos), so a human picks the culprit. <!-- lane-revert none -->" >>"$sw/520.comments"
LANE_VERIFY_AFTER=1 lane_sweep
verdict "$(git -C "$sw/origin.git" rev-parse dev~1)" failure; C201=$(git -C "$sw/origin.git" rev-parse dev~1); LANE_VERIFY_AFTER=1 lane_sweep
expect "auto-revert: after a no-culprit note, a certain Linux culprit still gets exactly one revert" \
  "$(creates),$(grep -c -- '^pr create .*--head lane/revert-201 ' "$sw/calls"),$(grep -c "^issue comment 520 .*<!-- lane-revert ${C201:0:7} -->" "$sw/calls")" "1,1,1"
LANE_VERIFY_AFTER=1 lane_sweep; verdict "$(jq -r .headRefOid "$sw/600.json")" success; LANE_VERIFY_AFTER=1 lane_sweep; LANE_VERIFY_AFTER=1 lane_sweep
expect "auto-revert: later sweeps on the same culprit, its revert open or landed, open no second one" \
  "$(creates),$(merges),$(grep -c "^issue comment 520 .*<!-- lane-revert ${C201:0:7} -->" "$sw/calls")" "1,pr merge 600,1"

# macOS-only reds: no bisect runs there. One PR in range is the culprit; with
# two, the lane names none and leaves the pick to a human.
rvdev macos "Sources/LibraryApp/A.swift|fix(library): a (#201)"
LANE_VERIFY_AFTER=1 lane_sweep
expect "auto-revert: a macOS red with one PR in range reverts it" \
  "$(creates),$(grep -c "^issue comment 520 .*is the culprit (it is the only PR in main\.\.${RED:0:7}); the lane opened #600" "$sw/calls"),$(grep -c -- '--label line:library ' "$sw/calls")" "1,1,1"
rvdev macos "Sources/PhotoModel/A.swift|feat(photo): a (#201)" "Sources/DesignModel/B.swift|feat(design): b (#202)"
LANE_VERIFY_AFTER=1 lane_sweep
expect "auto-revert: a macOS red with two PRs reverts nothing and leaves the pick to a human" \
  "$(creates),$(grep -c "^issue comment 520 .*2 PRs in main\.\.${RED:0:7} and no bisect verdict names one of them (red: macos), so a human picks the culprit\. <!-- lane-revert none -->" "$sw/calls")" "0,1"
# macOS compile reds (10-27: #5235, #5128, #4912 sat red until a human
# fixed them): the run's failed `macOS compile` job log names the files its
# Swift errors are in (an `error:` line, or the `expanded code originates
# here` note under a macro's error); the newest PR in range that changed one
# of them is the culprit. One PR: reverted. None, or several for different
# files: a note naming the files and PRs, no revert. A macOS test red is never
# reverted this way. Two PRs in range each time, so the only-PR rule can't decide.
R=/Users/runner/work/creative-apps/creative-apps
CPFX=$'macOS compile\tRun scripts/ci --build-only\t2026-10-27T01:02:03.4567890Z '
macjobs() {  # macjobs <compile conclusion> <tests conclusion>: run 9500's macOS jobs, the compile job's log at joblog.9601
  jq -n --arg c "$1" --arg t "$2" '{jobs: [{id: 9601, name: "macOS compile", conclusion: $c},
    {id: 9602, name: "macOS tests 1/3", conclusion: $t}, {id: 9603, name: "macOS", conclusion: "failure"}]}' >"$sw/jobs.9500.json"
}
rvdev macos "Sources/PhotoModel/A.swift|feat(photo): a (#201)" "Sources/SuiteUI/Theme.swift|refactor(suite): drop gone (#202)"
macjobs failure skipped
printf '%s\n' "${CPFX}Building for debugging..." "${CPFX}$R/Sources/PhotoModel/A.swift:3:9: error: cannot find 'gone' in scope" \
  "${CPFX}$R/Sources/SuiteUI/Theme.swift:10:5: note: 'gone' declared here" "${CPFX}CI: FAIL (swift build)" >"$sw/joblog.9601"
LANE_VERIFY_AFTER=1 lane_sweep
expect "auto-revert: a macOS compile error in one PR's file reverts that PR, not the newest one (a declared-here note is no blame)" \
  "$(creates),$(grep -c -- '^pr create .*--head lane/revert-201 ' "$sw/calls"),$(grep -c "^issue comment 520 .*Auto-revert: #201 (.*) is the culprit (its macOS compile errors are in Sources/PhotoModel/A\.swift, last changed in main\.\.${RED:0:7} by #201); the lane opened #600 to revert it\. <!-- lane-revert " "$sw/calls"),$(grep -c -- '--label line:photo ' "$sw/calls")" "1,1,1,1"
LANE_VERIFY_AFTER=1 lane_sweep
expect "auto-revert: a macOS compile culprit is called once" "$(creates),$(grep -c '^issue comment 520 .*Auto-revert' "$sw/calls")" "1,1"

rvdev macos "Sources/PhotoModel/A.swift|feat(photo): a (#201)" "Sources/DesignModel/B.swift|feat(design): b (#202)"
macjobs failure skipped
printf '%s\n' "${CPFX}$R/Sources/LibraryModel/C.swift:4:1: error: cannot find 'x' in scope" >"$sw/joblog.9601"
LANE_VERIFY_AFTER=1 lane_sweep; LANE_VERIFY_AFTER=1 lane_sweep
expect "auto-revert: macOS compile errors in a file no PR in range changed: one note naming it, no revert" \
  "$(creates),$(grep -c "^issue comment 520 .*Auto-revert: the macOS compile errors are in Sources/LibraryModel/C\.swift, which no PR in main\.\.${RED:0:7} changed, so a human picks the culprit\. <!-- lane-revert none -->" "$sw/calls"),$(grep -c '^issue comment 520 .*Auto-revert' "$sw/calls")" "0,1,1"

rvdev macos "Sources/PhotoModel/A.swift|feat(photo): a (#201)" "Tests/AppSnapshotTests/X.swift|test(suite): snapshots (#202)"
macjobs failure skipped
printf '%s\n' "${CPFX}$R/Sources/PhotoModel/A.swift:3:9: error: cannot find 'gone' in scope" \
  "${CPFX}/var/folders/q1/T/swift-generated-sources/@__swiftmacro_16AppSnapshotTests1XV4testyyF6expectfMf_.swift:1:5: error: type 'Y' has no member 'z'" \
  "${CPFX}$R/Tests/AppSnapshotTests/X.swift:7:3: note: expanded code originates here" >"$sw/joblog.9601"
LANE_VERIFY_AFTER=1 lane_sweep
expect "auto-revert: macOS compile errors in two PRs' files (one under a macro): a note naming both, no revert" \
  "$(creates),$(grep -c "^issue comment 520 .*Auto-revert: the macOS compile errors are in files 2 PRs in main\.\.${RED:0:7} changed: Tests/AppSnapshotTests/X\.swift (#202), Sources/PhotoModel/A\.swift (#201), so a human picks the culprit\. <!-- lane-revert none -->" "$sw/calls")" "0,1"

rvdev macos "Sources/PhotoModel/A.swift|feat(photo): a (#201)" "Sources/DesignModel/B.swift|feat(design): b (#202)"
macjobs success failure
printf '%s\n' "${CPFX}$R/Sources/PhotoModel/A.swift:3:9: error: stale log line" >"$sw/joblog.9601"
LANE_VERIFY_AFTER=1 lane_sweep
expect "auto-revert: a macOS test red (compile green) is never reverted by file: the human-picks note as before" \
  "$(creates),$(grep -c "^issue comment 520 .*Auto-revert: 2 PRs in main\.\.${RED:0:7} and no bisect verdict names one of them (red: macos), so a human picks the culprit\. <!-- lane-revert none -->" "$sw/calls")" "0,1"

rvdev macos "Sources/PhotoModel/A.swift|feat(photo): a (#201)" "Sources/DesignModel/B.swift|feat(design): b (#202)"
macjobs failure skipped
LANE_VERIFY_AFTER=1 lane_sweep
expect "auto-revert: a macOS compile log not readable yet: no revert, no note, the next sweep looks again" \
  "$(creates),$(grep -c '^issue comment 520 .*Auto-revert' "$sw/calls")" "0,0"
# Verify after merge, own-proof landing (LANE_VERIFY_AFTER=1): a code PR lands
# alone as soon as its head has Linux proof and a green local-ci/prescreen (the
# supervisor's pre-screen on the Mac), with no batch and no macOS run; without
# the pre-screen it waits, a red one is red, a stale proof becomes a Linux
# batch of one on today's dev, and a red dev holds nothing. PRs without code
# need no pre-screen.
PS='. + [{"__typename":"StatusContext","context":"local-ci/prescreen","state":"%s"}]'
LANE_VERIFY_AFTER=1 check "verify after: Linux proof and a green prescreen make a code PR eligible" \
  "eligible|150|2|4 checks green, local-ci/prescreen" . "$BASE_FILES" "$(printf "$PS" SUCCESS)"
LANE_VERIFY_AFTER=1 check "verify after: no prescreen on the head waits" "pending|waiting for local-ci/prescreen on head $HEAD_SHA" . "$BASE_FILES" .
LANE_VERIFY_AFTER=1 check "verify after: a pending prescreen waits" "pending|waiting for local-ci/prescreen on head $HEAD_SHA" . "$BASE_FILES" "$(printf "$PS" PENDING)"
LANE_VERIFY_AFTER=1 check "verify after: a red prescreen is red" "red|local-ci/prescreen" . "$BASE_FILES" "$(printf "$PS" FAILURE)"
LANE_VERIFY_AFTER=1 check "verify after: Linux proof still comes first" "linux-dispatch|feat/x" . "$BASE_FILES" "[] | $(printf "$PS" SUCCESS)"
LANE_VERIFY_AFTER=1 check "verify after: a PR without code needs no prescreen" "eligible|150|2|4 checks green" . $'docs/a.md\ndocs/b.md' .
check "verify after off: the prescreen is ignored, red or not" "eligible|150|2|4 checks green" . "$BASE_FILES" "$(printf "$PS" FAILURE)"
prescreen() { jq -n --arg s "$2" '{statuses: [{context: "local-ci/prescreen", state: $s}]}' >"$sw/status.$1.json"; }
head_of() { jq -r .headRefOid "$sw/$1.json"; }
fresh; cpr 160 Sources/PhotoModel/A.swift; cpr 161 Sources/DesignModel/B.swift
LANE_VERIFY_AFTER=1 lane_sweep
expect "verify after: code PRs with Linux proof and no prescreen wait: no merge, no batch, nothing runs" \
  "$(merges),$(batch_tip),$(grep -c '^workflow run' "$sw/calls")" ",,0"
prescreen "$(head_of 160)" success; prescreen "$(head_of 161)" success
LANE_VERIFY_AFTER=1 lane_sweep
expect "verify after: with a green prescreen each lands on its own proof, no batch, no macOS run" \
  "$(merges),$(batch_tip),$(grep -c '^workflow run' "$sw/calls")" "pr merge 160,pr merge 161,,0"
expect "verify after: the merge comment names the prescreen" "$(grep -c '^pr comment 160 .*merged into dev (.*Fast-Check marker, local-ci/prescreen)' "$sw/calls")" 1
fresh; cpr 162 Sources/PhotoModel/A.swift; cpr 163 Sources/DesignModel/B.swift
prescreen "$(head_of 162)" success; prescreen "$(head_of 163)" success
lane_sweep
expect "verify after off: the same PRs still batch with a macOS gate" \
  "$(merges),$( [[ -n "$(batch_tip)" ]] && echo batch),$(grep -c -- '-f mac_only=true' "$sw/calls")" ",batch,1"
fresh; cpr 164 Sources/PhotoModel/A.swift; prescreen "$(head_of 164)" success
dev_moves Tests/command-path-baseline/halo.txt; DEV=$(git -C "$sw/origin.git" rev-parse dev)
LANE_VERIFY_AFTER=1 lane_sweep
expect "verify after: a stale proof re-waits as a Linux batch of one on today's dev, no macOS gate" \
  "$(merges),$(git -C "$sw/origin.git" rev-parse "$(batch_tip)~1"),$(grep -c -- '-f mac_only=true' "$sw/calls"),$(grep -c -- '-f linux_only=true --ref lane/batch-[0-9]*$' "$sw/calls")" ",$DEV,0,1"
batch_green; LANE_VERIFY_AFTER=1 lane_sweep
expect "verify after: and lands on that check" "$(merges)" "pr merge 164"
fresh; cpr 165 Sources/PhotoModel/A.swift; prescreen "$(head_of 165)" success; redissue "" linux
LANE_VERIFY_AFTER=1 lane_sweep
expect "verify after: a red dev holds no code PR that has its own proof" "$(merges),$(batch_tip)" "pr merge 165,"
# A stale proof's batch of one holds only its own PR (LANE_VERIFY_AFTER=1):
# ready PRs with fresh proof land beside it, it never gets a second batch, and
# a result on a base a landing made stale (proof_stale) is checked again on
# today's dev, not merged. With LANE_VERIFY_AFTER=0 it holds the lane as before.
held() {  # held <verify after 0|1>: #170 a batch of one on a stale proof, then #171 and #172 ready with fresh proof
  fresh; cpr 170 Sources/PhotoModel/A.swift; prescreen "$(head_of 170)" success
  dev_moves Tests/command-path-baseline/halo.txt; DEV=$(git -C "$sw/origin.git" rev-parse dev)
  LANE_VERIFY_AFTER=$1 lane_sweep; verdict "$(batch_tip)" in_progress
  cpr 171 Sources/DesignModel/B.swift; cpr 172 Sources/LibraryModel/C.swift
  prescreen "$(head_of 171)" success; prescreen "$(head_of 172)" success
  LANE_VERIFY_AFTER=$1 lane_sweep
}
held 1
expect "verify after: a batch of one in flight holds no other ready PR: both land this sweep" \
  "$(merges),$(git -C "$sw/origin.git" rev-parse "$(batch_tip)~1")" "pr merge 171,pr merge 172,$DEV"
expect "verify after: the PR in the batch of one gets no second batch" \
  "$(batch_br | wc -l | tr -d ' '),$(grep -c -- '-f linux_only=true --ref lane/batch-[0-9]*$' "$sw/calls")" "1,1"
OLD_TIP=$(batch_tip)
dev_moves Tests/format-lists-baseline.txt; DEV=$(git -C "$sw/origin.git" rev-parse dev)
verdict "$OLD_TIP" success; LANE_VERIFY_AFTER=1 lane_sweep
expect "verify after: its green result on a base a landing made stale is checked again on today's dev, not merged" \
  "$(merges),$(git -C "$sw/origin.git" rev-parse "$(batch_tip)~1"),$(grep -c -- '-f linux_only=true --ref lane/batch-[0-9]*$' "$sw/calls")" \
  "pr merge 171,pr merge 172,$DEV,2"
batch_green; LANE_VERIFY_AFTER=1 lane_sweep
expect "verify after: and lands on the new check" "$(merges)" "pr merge 171,pr merge 172,pr merge 170"
held 0
expect "verify after off: a batch of one in flight still holds every other ready PR" "$(merges),$(batch_br | wc -l | tr -d ' ')" ",1"
# Several stale proofs re-check in parallel, each its own batch of one, at
# most LANE_BATCH_MAX at once, and a sweep never sleeps for their verdicts.
fresh; for n in 173 174 175; do cpr "$n" "Sources/PhotoModel/A$n.swift"; prescreen "$(head_of "$n")" success; done
dev_moves Tests/command-path-baseline/halo.txt; DEV=$(git -C "$sw/origin.git" rev-parse dev)
( sleep() { echo "sleep $*" >>"$sw/calls"; }; BATCH_WAIT=60 BATCH_POLL=60 LANE_BATCH_MAX=2 LANE_VERIFY_AFTER=1 lane_sweep )
expect "verify after: stale proofs become batches of one on today's dev in one sweep, LANE_BATCH_MAX at most, no sleep" \
  "$(merges),$(batch_br | wc -l | tr -d ' '),$(for t in $(batch_tip); do git -C "$sw/origin.git" rev-parse "$t~1"; done | sort -u),$(grep -c -- '-f linux_only=true --ref lane/batch-[0-9]*$' "$sw/calls"),$(grep -c '^sleep' "$sw/calls")" \
  ",2,$DEV,2,0"
for t in $(batch_tip); do verdict "$t" success; done; LANE_VERIFY_AFTER=1 lane_sweep
expect "verify after: each lands on its own check, and the one that waited gets its batch" "$(merges),$(batch_br | wc -l | tr -d ' ')" "pr merge 173,pr merge 174,1"
# A stale PR that changes a ratchet path itself goes stale under every landing
# beside it (proof_stale), so its batch of one still holds the lane.
fresh; pr_at 176 h176 '[{"filename": "Sources/PhotoModel/A.swift", "status": "modified"}]'; real_pr 176 Tests/placeholder-menu-baseline.txt
prescreen "$(head_of 176)" success; dev_moves docs/other.md
LANE_VERIFY_AFTER=1 lane_sweep; verdict "$(batch_tip)" in_progress
cpr 177 Sources/DesignModel/B.swift; prescreen "$(head_of 177)" success
LANE_VERIFY_AFTER=1 lane_sweep
expect "verify after: a batch of one changing a ratchet path still holds the lane" "$(merges),$(batch_br | wc -l | tr -d ' ')" ",1"

# Flake check (dev red 10 h on a 3.1x-vs-3x timing ratio, 2026-10-26): before
# the lane treats dev as red it reruns the red run's failed jobs once at the
# red sha (gh run rerun --failed) and records that on the dev-red issue
# (RERUN_MARK <sha7> started). While the rerun runs nothing is held, bisected
# or reverted; a pass is a flake (one finding naming the tests, no hold, the
# mark says flake); a failure makes the red real (the mark says red) and the
# lane goes on as before. One rerun per sha, never a second.
runstate() { jq -n --arg s "$1" --arg c "${2:-}" '{status: $s, conclusion: $c}' >"$sw/run.9500.json"; }
bisects() { git -C "$sw/origin.git" for-each-ref 'refs/heads/ci/bisect-*' | wc -l | tr -d ' '; }
reruns() { grep -c '^run rerun 9500 -R qbtrix/creative-apps --failed$' "$sw/calls" || true; }
findings() { grep -c -- '^issue create .*--label flaky ' "$sw/calls" || true; }  # the lane's flake findings (a revert files one too)
FLAKE_RUN="https://github.com/qbtrix/creative-apps/actions/runs/9500"
flakedev() {  # flakedev <jobs> <spec>...: rvdev with the red's test file in the tree (no PR's commit) and no flake check done yet
  rvdev "$1" "Tests/PhotoModelTests/OpenTests.swift|test(photo): opens" "${@:2}"
  : >"$sw/520.comments"; rm -f "$sw/run.9500.json"
}
flakedev linux "Sources/PhotoModel/A.swift|feat(photo): a (#201)"
cpr 190 docs/flake.md
LANE_VERIFY_AFTER=1 lane_sweep
expect "flake check: a new red gets one rerun of its failed jobs, recorded on the dev-red issue with the failing tests" \
  "$(reruns),$(grep -c "^issue comment 520 .*Flake check: re-running the failed jobs (linux) of $FLAKE_RUN once at ${RED:0:7}; failing OpenTests.swift/opens(). .* <!-- lane-rerun ${RED:0:7} started -->" "$sw/calls")" "1,1"
expect "flake check: meanwhile dev is not red: no bisect, no revert, the ready docs PR lands" "$(bisects),$(creates),$(merges)" "0,0,pr merge 190"
runstate in_progress; LANE_VERIFY_AFTER=1 lane_sweep
expect "flake check: a running rerun is waited for, never a second rerun, still no hold" "$(reruns),$(bisects),$(creates)" "1,0,0"
runstate completed success; LANE_VERIFY_AFTER=1 lane_sweep
expect "flake check: a passing rerun files one finding naming the test, labelled for a fixer and the app" \
  "$(findings),$(grep -c -- "^issue create -R qbtrix/creative-apps --title Flaky test: OpenTests.swift/opens() --label finding --label flaky --label line:photo --body .*$FLAKE_RUN.*${RED:0:7}" "$sw/calls")" "1,1"
expect "flake check: and marks the issue as a flake, with no bisect or revert" \
  "$(grep -c "^issue comment 520 .*Flake check: the rerun of $FLAKE_RUN passed at ${RED:0:7}, so that red was a flake and the lane held nothing on it; filed https://github.com/qbtrix/creative-apps/issues/700\. <!-- lane-rerun ${RED:0:7} flake -->" "$sw/calls"),$(bisects),$(creates)" "1,0,0"
LANE_VERIFY_AFTER=1 lane_sweep
expect "flake check: a judged flake is not rerun, refiled or held on later sweeps" "$(reruns),$(findings),$(bisects)" "1,1,0"
# An open finding with that title is updated, never duplicated.
flakedev linux "Sources/PhotoModel/A.swift|feat(photo): a (#201)"
jq -n '[{number: 701, title: "Flaky test: OpenTests.swift/opens()"}]' >"$sw/issues.json"
LANE_VERIFY_AFTER=1 lane_sweep; runstate completed success; LANE_VERIFY_AFTER=1 lane_sweep
expect "flake check: an open finding for the test gets a comment, not a duplicate" \
  "$(findings),$(grep -c "^issue comment 701 .*Flaked again: .*$FLAKE_RUN.*${RED:0:7}" "$sw/calls"),$(grep -c "updated #701\. <!-- lane-rerun ${RED:0:7} flake -->" "$sw/calls")" "0,1,1"
# A rerun that fails too: the red is real, and the lane holds, bisects and reverts as today.
flakedev linux "Sources/PhotoModel/A.swift|feat(photo): a (#201)"
LANE_VERIFY_AFTER=1 lane_sweep; runstate completed failure; LANE_VERIFY_AFTER=1 lane_sweep
expect "flake check: a failing rerun makes the red real: marked once, then the culprit is reverted as before" \
  "$(reruns),$(grep -c "^issue comment 520 .*Flake check: the rerun of $FLAKE_RUN failed too (failure), so this red is real\. <!-- lane-rerun ${RED:0:7} red -->" "$sw/calls"),$(creates),$(findings)" "1,1,1,0"
LANE_VERIFY_AFTER=1 lane_sweep
expect "flake check: a judged red is never rerun again" "$(reruns)" 1
# ci.yml's promote reruns with the passed jobs and closes the issue, usually
# before a sweep sees the pass: the finding is still filed, off the closed issue.
flakedev linux "Sources/PhotoModel/A.swift|feat(photo): a (#201)"
LANE_VERIFY_AFTER=1 lane_sweep
mv "$sw/red.json" "$sw/redclosed.json"; runstate completed success; LANE_VERIFY_AFTER=1 lane_sweep
expect "flake check: a flake whose issue promote closed first still gets its one finding and mark" \
  "$(findings),$(grep -c "<!-- lane-rerun ${RED:0:7} flake -->" "$sw/calls")" "1,1"
LANE_VERIFY_AFTER=1 lane_sweep
expect "flake check: and only one" "$(findings),$(grep -c "<!-- lane-rerun ${RED:0:7} flake -->" "$sw/calls")" "1,1"
# A dev-red issue without a run to rerun is red at once, as today.
flakedev linux "Sources/PhotoModel/A.swift|feat(photo): a (#201)"
jq '.[0].body |= sub("- Run: [^\n]*\n"; "")' "$sw/red.json" >"$sw/x" && mv "$sw/x" "$sw/red.json"
LANE_VERIFY_AFTER=1 lane_sweep
expect "flake check: no run named, nothing to rerun: red as today" "$(reruns),$(creates)" "0,1"
# A cancelled rerun (the concurrency group replaced it, or no runner took it)
# says nothing about the red (lesson 351): the failed jobs are rerun once
# more; cancelled again, the lane waits for the next dev run. Never "failed
# too", never a red mark, nothing held, bisected, reverted or quarantined.
flakedev linux "Sources/PhotoModel/A.swift|feat(photo): a (#201)"
LANE_VERIFY_AFTER=1 lane_sweep; runstate completed cancelled; LANE_VERIFY_AFTER=1 lane_sweep
expect "flake check: a cancelled rerun is inconclusive: one more rerun, said on the issue, never 'failed too' or red" \
  "$(reruns),$(grep -c "^issue comment 520 .*Flake check: the rerun of $FLAKE_RUN was cancelled, so it says nothing about this red; re-running the failed jobs once more at ${RED:0:7}\. <!-- lane-rerun ${RED:0:7} again -->" "$sw/calls"),$(grep -c 'failed too' "$sw/calls"),$(grep -c "lane-rerun ${RED:0:7} red" "$sw/calls"),$(bisects),$(creates)" "2,1,0,0,0,0"
LANE_VERIFY_AFTER=1 lane_sweep; LANE_VERIFY_AFTER=1 lane_sweep
expect "flake check: cancelled again, it waits for the next dev run: no third rerun, no red, no revert or quarantine" \
  "$(reruns),$(grep -c 'failed too' "$sw/calls"),$(grep -c "lane-rerun ${RED:0:7} red" "$sw/calls"),$(creates),$(grep -c 'Auto-quarantine' "$sw/calls")" "2,0,0,0,0"
runstate completed failure; LANE_VERIFY_AFTER=1 lane_sweep
expect "flake check: the retry failing for real makes the red real, and the lane goes on as before" \
  "$(reruns),$(grep -c "^issue comment 520 .*the rerun of $FLAKE_RUN failed too (failure), so this red is real\. <!-- lane-rerun ${RED:0:7} red -->" "$sw/calls"),$(creates)" "2,1,1"
# The same off a closed issue (flake_closed): a cancelled rerun is never called real.
flakedev linux "Sources/PhotoModel/A.swift|feat(photo): a (#201)"
LANE_VERIFY_AFTER=1 lane_sweep
mv "$sw/red.json" "$sw/redclosed.json"; runstate completed cancelled; LANE_VERIFY_AFTER=1 lane_sweep
expect "flake check: a closed issue's cancelled rerun gets no 'failed too' and no red mark" \
  "$(grep -c 'failed too' "$sw/calls"),$(grep -c "lane-rerun ${RED:0:7} red" "$sw/calls")" "0,0"

# Scoped hold: a red dev holds only the ready PRs that touch the failing
# module (red_scope: the failing tests' files in the tree give Tests/<Target>/
# and Sources/<Target minus Tests>/); the rest batch as if dev were green. A
# red whose module can't be placed (no test named, or a target with no
# Sources module) holds the whole queue as before. LANE_VERIFY_AFTER=0 batches
# code; code PRs on their own proof under LANE_VERIFY_AFTER=1 land as before.
LANE_MAC_PER_PR=0
batch_prs() { git -C "$sw/origin.git" log --first-parent --format=%s "dev..$(batch_tip)" 2>/dev/null | grep -oE '#[0-9]+' | sort | paste -sd, -; }
flakedev linux "Sources/PhotoModel/A.swift|feat(photo): a (#201)"; printf '%s\n' "$RERUN_MARK ${RED:0:7} red -->" >"$sw/520.comments"
cpr 191 Sources/PhotoModel/B.swift; cpr 192 Sources/DesignModel/C.swift; cpr 193 docs/scope.md
lane_sweep
expect "scoped hold: PRs off the red module batch; the one touching it waits" "$(batch_prs),$(merges)" "#192,#193,"
expect "scoped hold: the held PR gets no label and no comment" "$(grep -cE '^pr (edit|comment) 191 ' "$sw/calls")" 0
# The module is read from the fixture remote's tree, never from the checkout
# the tests run in: FooModel exists only at the fixture (a SCRATCH made in a
# subshell died with it and the lane read this repo instead, which passed on a
# Mac and failed on Linux).
rvdev linux "Tests/FooModelTests/OpenTests.swift|test(foo): opens" "Sources/FooModel/A.swift|feat(foo): a (#201)"
printf '%s\n' "$RERUN_MARK ${RED:0:7} red -->" >"$sw/520.comments"; rm -f "$sw/run.9500.json"
cpr 1001 Sources/FooModel/B.swift; cpr 1002 docs/scope.md
lane_sweep
expect "scoped hold: the red module comes from the remote's tree, not this checkout: the lone docs PR lands, the FooModel one waits" "$(batch_prs),$(merges)" ",pr merge 1002"
flakedev linux "Sources/PhotoModel/A.swift|feat(photo): a (#201)"; printf '%s\n' "$RERUN_MARK ${RED:0:7} red -->" >"$sw/520.comments"
printf 'error: compile failed\nCI: FAIL\n' >"$sw/joblog.4343"
cpr 194 Sources/DesignModel/C.swift; cpr 195 docs/scope.md
lane_sweep
expect "scoped hold: a red naming no test holds the whole queue as before" "$(batch_tip),$(merges)" ","
flakedev linux "Sources/PhotoModel/A.swift|feat(photo): a (#201)" "Tests/AppSnapshotTests/SnapTests.swift|test(snap): s (#202)"
printf '%s\n' "$RERUN_MARK ${RED:0:7} red -->" >"$sw/520.comments"
tip_red "$RED" 4343 '✘ Test snaps() recorded an issue at SnapTests.swift:9:5: Expectation failed: (a → 3) == (4 → 4)'
cpr 196 Sources/DesignModel/C.swift; cpr 197 docs/scope.md
lane_sweep
expect "scoped hold: a test target with no Sources module holds the whole queue as before" "$(batch_tip),$(merges)" ","
flakedev linux "Sources/PhotoModel/A.swift|feat(photo): a (#201)"; printf '%s\n' "$RERUN_MARK ${RED:0:7} red -->" >"$sw/520.comments"
cpr 198 Sources/PhotoModel/B.swift; prescreen "$(head_of 198)" success
LANE_VERIFY_AFTER=1 lane_sweep
expect "scoped hold: verify after still lands a code PR on its own proof, red module or not" "$(merges)" "pr merge 198"
LANE_MAC_PER_PR=1

# Auto-quarantine (LANE_VERIFY_AFTER=1, "trunk never stops"): a real red the
# lane has no revert for (revert_sweep ended in a note, or its revert is in
# the red range and dev is still red) gets its failing tests quarantined: one
# `Quarantined: <id>` p0 finding per test as owner, a `lane` entry in
# UITests/quarantine.json (dev-red issue, culprit range, expiry 24 h out) on
# the lane's one lane/quarantine PR (lane-quarantine, p0, never fast-lane),
# landed on its own Linux check: the one protected-path change the lane lands,
# keyed on the bot author, the branch, the label and the file set being exactly
# that file. Past its expiry the owner is labelled blocker and the entry stays;
# once the owner closes, the same PR path removes it. Never more than 5 tests
# per sweep, never a security, billing or auth test, one call per red sha.
quardev() {  # quardev <jobs> <spec>...: rvdev, then dev gains the red tests' real files and an empty quarantine; the red is that tip
  rvdev "$@"
  local w="$sw/work"
  mkdir -p "$w/Tests/PhotoModelTests" "$w/UITests"
  printf '%s\n' 'import Testing' '@Suite struct OpenTests {' '    @Test func opens() {}' '    @Test func saves() {}' '}' >"$w/Tests/PhotoModelTests/OpenTests.swift"
  printf '%s\n' 'import Testing' '@Suite struct AuthTests {' '    @Test func login() {}' '}' >"$w/Tests/PhotoModelTests/AuthTests.swift"
  echo '[]' >"$w/UITests/quarantine.json"
  git -C "$w" add -A; git -C "$w" commit -qm "test(photo): fixtures"; git -C "$w" push -q "$sw/origin.git" dev
  RED=$(git -C "$w" rev-parse dev)
  jq --arg r "$RED" '.[0].body |= sub("main\\.\\.[0-9a-f]+"; "main..\($r)")' "$sw/red.json" >"$sw/x" && mv "$sw/x" "$sw/red.json"
  tip_red "$RED" 4343 '✘ Test opens() recorded an issue at OpenTests.swift:9:5: Expectation failed: (doc.layers.count → 3) == (4 → 4)'
  printf '%s\n' "$RERUN_MARK ${RED:0:7} red -->" >"$sw/520.comments"
  jq -n '{body: "Adds b.\n\nFeature: easing"}' >"$sw/pull.202.json"
}
qbranch() { git -C "$sw/origin.git" rev-parse --verify -q refs/heads/lane/quarantine || true; }
qjson() { git -C "$sw/origin.git" show "refs/heads/lane/quarantine:UITests/quarantine.json" 2>/dev/null || echo '[]'; }
quarantines() { grep -c -- '^pr create .*--label lane-quarantine ' "$sw/calls" || true; }
qnotes() { grep -c '^issue comment 520 .*Auto-quarantine' "$sw/calls" || true; }
NOW=2026-10-26T10:00:00Z
TWO=("Sources/PhotoModel/A.swift|feat(photo): a (#201)" "Sources/DesignModel/B.swift|feat(design): b (#202)")
check "a human PR touching the quarantine stays refused (the lane's exception is its own PR only)" \
  "not-eligible|touches protected paths: UITests/quarantine.json" . $'UITests/quarantine.json\nTests/PhotoModelTests/OpenTests.swift' .
quardev macos "${TWO[@]}"
FAST_LANE_NOW=$NOW lane_sweep
expect "auto-quarantine: off with LANE_VERIFY_AFTER=0: a red with no revert quarantines nothing" "$(quarantines),$(qbranch),$(qnotes)" "0,,0"
FAST_LANE_NOW=$NOW LANE_VERIFY_AFTER=1 lane_sweep
expect "auto-quarantine: no certain culprit (a macOS red, two PRs): the failing test is quarantined on lane/quarantine, off today's dev, that file only" \
  "$(git -C "$sw/origin.git" diff --name-only dev "$(qbranch)" | paste -sd, -),$(git -C "$sw/origin.git" rev-parse "$(qbranch)~1")" "UITests/quarantine.json,$RED"
expect "auto-quarantine: the entry carries the test id, its p0 issue as owner, the dev-red issue, the culprit range and a 24 h expiry" \
  "$(qjson | jq -c '[.[] | .test, .owner, .expires, .lane.red, .lane.range, .lane.until]')" \
  "[\"PhotoModelTests.OpenTests/opens\",\"#700\",\"2026-10-27\",\"#520\",\"main..${RED:0:7}\",\"2026-10-27T10:00:00Z\"]"
expect "auto-quarantine: one p0 finding per test, labelled for its line, naming the run, the range's PRs with their leads, and the expiry" \
  "$(grep -c -- "^issue create -R qbtrix/creative-apps --title Quarantined: PhotoModelTests.OpenTests/opens --label p0 --label finding --label line:photo --body .*runs/9500.*#201 (lead #78), #202 (lead #78).*2026-10-27T10:00:00Z" "$sw/calls")" 1
expect "auto-quarantine: opened as a lane-quarantine p0 PR, never fast-lane, that refs dev-red without closing it" \
  "$(quarantines),$(grep -c -- '^pr create .*--head lane/quarantine --label lane-quarantine --label p0 --title test(quarantine): skip PhotoModelTests.OpenTests/opens ' "$sw/calls"),$(grep -c -- '--label fast-lane' "$sw/calls"),$(jq -r .body "$sw/600.json" | grep -c 'Refs #520'),$(jq -r .body "$sw/600.json" | grep -cE '([Cc]loses|[Ff]ixes) #520')" "1,1,0,1,0"
expect "auto-quarantine: the dev-red issue records the one call" \
  "$(grep -c "^issue comment 520 .*Auto-quarantine: .*quarantined PhotoModelTests.OpenTests/opens (#700) for 24 h in #600.*<!-- lane-quarantine ${RED:0:7} -->" "$sw/calls")" 1
# The exception is exactly that file: a lane-quarantine PR changing anything else is never landed.
cp "$sw/files.600.json" "$sw/x"; jq '. + [{filename: "Sources/PhotoModel/A.swift", status: "modified"}]' "$sw/x" >"$sw/files.600.json"
FAST_LANE_NOW=$NOW LANE_VERIFY_AFTER=1 lane_sweep
expect "auto-quarantine: a lane-quarantine PR touching more than the quarantine file gets no check, no merge, one comment" \
  "$(grep -c -- '--ref lane/quarantine$' "$sw/calls"),$(merges),$(grep -c '^pr comment 600 .*changes more than UITests/quarantine.json (UITests/quarantine.json, Sources/PhotoModel/A.swift), so the lane will not land it' "$sw/calls")" "0,,1"
mv "$sw/x" "$sw/files.600.json"
FAST_LANE_NOW=$NOW LANE_VERIFY_AFTER=1 lane_sweep; FAST_LANE_NOW=$NOW LANE_VERIFY_AFTER=1 lane_sweep
expect "auto-quarantine: then one Linux check on it, once; no second PR, issue or note" \
  "$(grep -c -- '-f linux_only=true --ref lane/quarantine$' "$sw/calls"),$(quarantines),$(grep -c '^issue create' "$sw/calls"),$(qnotes)" "1,1,1,1"
verdict "$(head_of 600)" success; FAST_LANE_NOW=$NOW LANE_VERIFY_AFTER=1 lane_sweep
expect "auto-quarantine: it lands on that check alone (no prescreen, no batch, dev red and all) and CI on dev runs" \
  "$(merges),$(batch_tip),$(grep -c '^workflow run ci.yml -R qbtrix/creative-apps --ref dev$' "$sw/calls")" "pr merge 600,,1"
# Expiry: past `until` with the owner open, the owner is labelled blocker and told once; the entry stays.
git -C "$sw/origin.git" update-ref refs/heads/dev "$(qbranch)"  # the merge landed on dev
FAST_LANE_NOW=2026-10-27T10:00:01Z LANE_VERIFY_AFTER=1 lane_sweep
expect "expiry: past its expiry with the issue open, the owner gets the blocker label and a comment, and the entry stays" \
  "$(grep -c '^issue edit 700 -R qbtrix/creative-apps --add-label blocker$' "$sw/calls"),$(grep -c '^issue comment 700 .*expired at 2026-10-27T10:00:00Z.*stays skipped' "$sw/calls"),$(quarantines)" "1,1,1"
echo '["p0", "blocker"]' >"$sw/labels.700"
FAST_LANE_NOW=2026-10-27T10:00:01Z LANE_VERIFY_AFTER=1 lane_sweep
expect "expiry: said once" "$(grep -c -- '--add-label blocker' "$sw/calls"),$(grep -c '^issue comment 700 ' "$sw/calls")" "1,1"
# Removal: once the owner closes, the lane's PR removes the entry; its Linux check runs the test again.
rm -f "$sw/red.json"; echo CLOSED >"$sw/state.700"
FAST_LANE_NOW=$NOW LANE_VERIFY_AFTER=1 lane_sweep
expect "removal: a closed owner gets a lane-quarantine PR removing its entry, off today's dev" \
  "$(quarantines),$(qjson | jq length),$(grep -c -- '^pr create .*--head lane/quarantine --label lane-quarantine --label p0 --title test(quarantine): run PhotoModelTests.OpenTests/opens again ' "$sw/calls"),$(git -C "$sw/origin.git" rev-parse "$(qbranch)~1")" "2,0,1,$(git -C "$sw/origin.git" rev-parse dev)"
verdict "$(head_of 601)" failure; FAST_LANE_NOW=$NOW LANE_VERIFY_AFTER=1 lane_sweep
expect "removal: a red check means the fix didn't hold: the owner is reopened and told, the PR closed, nothing merged" \
  "$(grep -c '^issue reopen 700 ' "$sw/calls"),$(grep -c '^issue comment 700 .*still fails without its quarantine entry' "$sw/calls"),$(grep -c '^pr close 601 ' "$sw/calls"),$(merges)" "1,1,1,pr merge 600"
echo OPEN >"$sw/state.700"; FAST_LANE_NOW=$NOW LANE_VERIFY_AFTER=1 lane_sweep
expect "removal: with the owner open again nothing is opened" "$(quarantines)" 2
echo CLOSED >"$sw/state.700"; FAST_LANE_NOW=$NOW LANE_VERIFY_AFTER=1 lane_sweep
verdict "$(head_of 602)" success; FAST_LANE_NOW=$NOW LANE_VERIFY_AFTER=1 lane_sweep
expect "removal: a green check lands it and CI on dev runs" \
  "$(quarantines),$(merges),$(grep -c '^workflow run ci.yml -R qbtrix/creative-apps --ref dev$' "$sw/calls")" "3,pr merge 600,pr merge 602,2"
# A Linux red whose bisect stopped short (no `Bisect:` verdict) has no certain culprit either.
quardev macos "${TWO[@]}"
printf '%s\n' "Bisect on dev stopped after 8 Linux runs: the Linux job is green at aaaaaaa and red at ${RED:0:7}; the culprit is one of the 2 commits between them. $BISECT_MARK ${RED:0:7} -->" >>"$sw/520.comments"
FAST_LANE_NOW=$NOW LANE_VERIFY_AFTER=1 lane_sweep
expect "auto-quarantine: a Linux red with an inconclusive bisect quarantines the test and reverts nothing" \
  "$(quarantines),$(grep -c -- '--label lane-revert' "$sw/calls"),$(qjson | jq -r '.[0].test')" "1,0,PhotoModelTests.OpenTests/opens"
# Never more than 5 tests in one sweep: more means something broke broadly, so today's red handling stands.
quardev macos "${TWO[@]}"
for t in a b c d e f; do echo "✘ Test $t() recorded an issue at OpenTests.swift:9:5: x"; done >"$sw/joblog.4343"
FAST_LANE_NOW=$NOW LANE_VERIFY_AFTER=1 lane_sweep; FAST_LANE_NOW=$NOW LANE_VERIFY_AFTER=1 lane_sweep
expect "auto-quarantine: 6 failing tests quarantine nothing and say so on the dev-red issue, once" \
  "$(quarantines),$(grep -c "^issue comment 520 .*Auto-quarantine: 6 tests fail at ${RED:0:7}.*more than 5, so something broke broadly; nothing is quarantined.*<!-- lane-quarantine ${RED:0:7} -->" "$sw/calls")" "0,1"
# Never a test on a security, billing or auth path.
quardev macos "${TWO[@]}"
printf '%s\n' '✘ Test login() recorded an issue at AuthTests.swift:3:5: x' 'CI: FAIL' >"$sw/joblog.4343"
FAST_LANE_NOW=$NOW LANE_VERIFY_AFTER=1 lane_sweep
expect "auto-quarantine: a test on a protected path is never quarantined, and the issue says why" \
  "$(quarantines),$(grep -c '^issue comment 520 .*Auto-quarantine: nothing to quarantine: PhotoModelTests.AuthTests/login: a security, billing or auth test is never quarantined.*<!-- lane-quarantine' "$sw/calls")" "0,1"
# A failing test whose file isn't in the tree (rvdev's bare fixtures) can't be placed: a note, no PR.
rvdev macos "${TWO[@]}"
FAST_LANE_NOW=$NOW LANE_VERIFY_AFTER=1 lane_sweep
expect "auto-quarantine: a test the lane can't place in the tree is noted, not quarantined" \
  "$(quarantines),$(grep -c '^issue comment 520 .*Auto-quarantine: nothing to quarantine: OpenTests.swift/opens(): its file is not under Tests/ on dev' "$sw/calls")" "0,1"
# A certain culprit is reverted, never quarantined.
quardev linux "Sources/PhotoModel/A.swift|feat(photo): a (#201)"
FAST_LANE_NOW=$NOW LANE_VERIFY_AFTER=1 lane_sweep
expect "auto-quarantine: a certain culprit gets the revert and no quarantine" "$(creates),$(quarantines),$(qnotes)" "1,0,0"

# The quarantine reads the dev-red run's failed attempt and only its real
# failures (lessons 351, 355; dev-red #6001, run 40761742332): attempt 1 failed
# opens() and logged known issues, the rerun (attempt 2) was cancelled with no
# jobs, and the sha's newest macOS check is another run's (a scoped dispatch)
# failing saves(). Only opens() is quarantined.
KPFX=$'macOS tests 3/3\tUNKNOWN STEP\t2026-10-28T21:19:22.9439410Z '
quardev macos "${TWO[@]}"
jq -n '{jobs: [{id: 9511, name: "macOS tests 3/3", conclusion: "failure", run_attempt: 1}, {id: 9512, name: "macOS", conclusion: "failure", run_attempt: 1},
  {id: 9513, name: "macOS tests 1/3", conclusion: "success", run_attempt: 1}]}' >"$sw/jobs.9500.json"
printf '%s\n' "${KPFX}━ Test saves() recorded a known issue at OpenTests.swift:4:5: Issue recorded" "${KPFX}━ Test saves() passed after 2.684 seconds with 1 known issue." \
  "${KPFX}◇ Test opens() started." "${KPFX}✘ Test opens() recorded an issue at OpenTests.swift:3:6: Time limit was exceeded: 120.000 seconds" \
  "${KPFX}✘ Test opens() failed after 120.764 seconds with 1 issue." "${KPFX}✘ Suite OpenTests failed after 243.006 seconds with 1 issue." \
  "${KPFX}✘ Test run with 210 tests in 137 suites failed after 2795.477 seconds with 2 issues (including 1 known issue)." >"$sw/joblog.9511"
printf '%s\n' $'macOS\tUNKNOWN STEP\t2026-10-28T21:24:22Z | macOS tests 3/3 | failure | 52 |' >"$sw/joblog.9512"
jq -n '[{name: "macOS (photo)", status: "completed", conclusion: "failure", started_at: "2026-10-28T21:12:06Z",
  details_url: "https://github.com/qbtrix/creative-apps/actions/runs/9300/job/9301"}]' >"$sw/checks.$RED.json"
printf '%s\n' '✘ Test saves() recorded an issue at OpenTests.swift:4:5: Time limit was exceeded: 60.000 seconds' >"$sw/joblog.9301"
FAST_LANE_NOW=$NOW LANE_VERIFY_AFTER=1 lane_sweep
expect "auto-quarantine: the red run's failed attempt names the test, not a cancelled rerun or another run on the sha, and a known issue is skipped" \
  "$(quarantines),$(qjson | jq -c '[.[] | .test]')" '1,["PhotoModelTests.OpenTests/opens"]'
# A failed log whose only issues are known issues names no test: nothing is quarantined.
quardev macos "${TWO[@]}"
printf '%s\n' "${KPFX}━ Test saves() recorded a known issue at OpenTests.swift:4:5: Issue recorded" "${KPFX}━ Test saves() passed after 2.684 seconds with 1 known issue." \
  "${KPFX}━ Test opens() recorded a known issue at OpenTests.swift:3:6: Issue recorded" \
  "${KPFX}✘ Test run with 210 tests in 137 suites failed after 2795.477 seconds with 2 issues (including 2 known issues)." 'CI: FAIL' >"$sw/joblog.4343"
FAST_LANE_NOW=$NOW LANE_VERIFY_AFTER=1 lane_sweep
expect "auto-quarantine: a log with only known issues quarantines nothing and says no test is named" \
  "$(quarantines),$(grep -c "^issue comment 520 .*Auto-quarantine: no failing test is named in the red logs at ${RED:0:7}" "$sw/calls")" "0,1"
# A `failed after` line with no `recorded an issue` line still names its test, placed by its func.
quardev macos "${TWO[@]}"
printf '%s\n' "${KPFX}✘ Test saves() failed after 3.100 seconds with 1 issue." 'CI: FAIL' >"$sw/joblog.4343"
FAST_LANE_NOW=$NOW LANE_VERIFY_AFTER=1 lane_sweep
expect "auto-quarantine: a test with only a 'failed after' line is quarantined, its file found by func name" \
  "$(quarantines),$(qjson | jq -c '[.[] | .test]')" '1,["PhotoModelTests.OpenTests/saves"]'

# A test process that dies (scripts/ci's TEST PROCESS DIED block) prints no
# "recorded an issue" line: mac_tests reads the block's names and places each in
# the Tests/ file whose `func <name>(` declares it on dev. The quarantine takes
# it from there; a name in several files or none is left out.
DIED=$'TEST PROCESS DIED: swift test printed no \'Test run with\' summary; 1 test(s) started and never finished:\n  opens()'
quardev macos "${TWO[@]}"
tip_red "$RED" 4343 "$DIED"
FAST_LANE_NOW=$NOW LANE_VERIFY_AFTER=1 lane_sweep
expect "auto-quarantine: a test the process died in is quarantined, its file found by func name" \
  "$(quarantines),$(qjson | jq -c '[.[] | .test]')" '1,["PhotoModelTests.OpenTests/opens"]'
w="$sw/work"
for f in OpenTests AuthTests; do printf '%s\n' '    func twin() {}' >>"$w/Tests/PhotoModelTests/$f.swift"; done
git -C "$w" add -A; git -C "$w" commit -qm "test(photo): twin"; git -C "$w" push -q "$sw/origin.git" dev
SCRATCH=""; scratch dev
PFX=$'macOS tests 1/3\tscripts/ci\t2026-10-27T01:02:03.4567890Z '
printf '%s\n' "${PFX}Test run started." "${PFX}" "${PFX}TEST PROCESS DIED: swift test printed no 'Test run with' summary; 3 test(s) started and never finished:" \
  "${PFX}  opens()" "${PFX}  twin()" "${PFX}  ghost()" "${PFX}" "${PFX}  saves()" "${PFX}✘ Test login() recorded an issue at AuthTests.swift:3:5: x" >"$sw/joblog.9100"
DIEDRED="red|https://github.com/qbtrix/creative-apps/actions/runs/889/job/9100|macOS"
expect "dev red: a died process's tests are named by file; an ambiguous or unfound name, and lines after the block, are left out" \
  "$(mac_tests "$DIEDRED" 2>/dev/null | paste -sd, -)" "AuthTests.swift/login(),OpenTests.swift/opens()"

exit "$fail"
