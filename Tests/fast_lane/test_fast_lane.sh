#!/usr/bin/env bash
# Tests/fast_lane/test_fast_lane.sh: fixture tests for the pure `decide`
# function in scripts/fast-lane.sh, its PROTECTED list against CLAUDE.md's
# "Never edit" bullet, the app audit guard (audit_loosens on before/after
# trees), whole sweeps against a stub `gh`, and, against a local bare repo, the
# lane's integration of a conflicting PR (integrate) and its batches (two or
# more ready PRs get one Linux check together before they land; a red batch is
# bisected by prefix). No network, needs bash, git and jq.
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
build "a cancelled build is refused too" "$BREFUSE (cancelled)" "$MARKED" "$APP" '.conclusion = "cancelled"'
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

# A whole sweep against a stub `gh` that answers from per-PR fixtures and logs
# every write: #4 and #7 are eligible, #5 is based on main, #6 conflicts.
# sweep <PRs labelled feature-done> runs main() and leaves the writes in $sw/calls.
# Files come from $sw/files.<n>.json (raw API shape, the lane's --jq applied),
# the merge base is `mb` (`bad` for a head whose compare fails), and the trees
# and contents for a commit are the files under $sw/refs/<sha>.
sw="$tmp/sweep"
# real_pr <n>: gives fixture PR <n> a real branch feat/<n> at the test's bare
# remote $sw/origin.git (one docs file on top of dev), so the lane can batch
# it: headRefName, headRefOid and the body's Head: line move to that commit,
# and an audit tree or build run keyed by the old head follows it.
real_pr() {
  local n="$1" f old sha w="$sw/work"
  f="$sw/$n.json"
  if [[ ! -d "$sw/origin.git" ]]; then
    git init -q --bare "$sw/origin.git"; git -C "$sw/origin.git" config uploadpack.allowFilter true
    git init -q -b dev "$w"; git -C "$w" config user.name t; git -C "$w" config user.email t@t; git -C "$w" config commit.gpgsign false
    cp "$here/../../.gitattributes" "$w/"; echo base >"$w/base.md"
    git -C "$w" add -A; git -C "$w" commit -qm base; git -C "$w" push -q "$sw/origin.git" dev
  fi
  git -C "$w" switch -qc "feat/$n" dev; echo "pr $n" >"$w/pr$n.md"; git -C "$w" add -A; git -C "$w" commit -qm "pr $n"
  git -C "$w" push -q "$sw/origin.git" "feat/$n"; git -C "$w" switch -q dev
  sha=$(git -C "$w" rev-parse "feat/$n"); old=$(jq -r .headRefOid "$f")
  jq --arg b "feat/$n" --arg h "$sha" '.headRefName = $b | .headRefOid = $h | .body |= sub("Head: [^\n]*"; "Head: \($h)")' "$f" >"$sw/x" && mv "$sw/x" "$f"
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
    "pr list "*)
      for n in "$sw"/[0-9]*.json; do
        jq -e '[.labels[].name] | index("fast-lane")' "$n" >/dev/null || continue
        n="${n##*/}"; n="${n%.json}"; [[ -e "$sw/$n.merged" ]] || echo "$n"
      done ;;
    "pr view "*"--json title "*) echo "title $2" ;;
    "pr view "*"--json body "*) jq -r .body "$sw/$3.json" ;;
    "pr view "*"--json closingIssuesReferences "*) cat "$sw/$3.closes" 2>/dev/null || true ;;
    "pr view "*) live_pr "$3" ;;
    "api "*"/check-runs"*) u="${2#*/commits/}"; u="${u%%/*}"; cat "$sw/checks.$u.json" 2>/dev/null || echo '[]' ;;
    "api "*"/status "*) echo '[]' ;;
    "api "*"/pulls/"*"/files "*)
      n="${2#*/pulls/}"; n="${n%%/*}"
      if [[ -e "$sw/files.$n.json" ]]; then jq -r "${!#}" "$sw/files.$n.json"
      else jq -rn '[{filename: "Sources/FlareModel/FlareWorkspace.swift", status: "modified"}]' | jq -r "${!#}"; fi ;;
    "api "*"/pulls/"*) n="${2##*/}"; jq -r "${!#}" "$sw/pull.$n.json" 2>/dev/null || true ;;  # a PR's body (bisect_post)
    "api repos/"*"/issues?labels=dev-red"*) jq -r "${!#}" "$sw/red.json" 2>/dev/null || true ;;  # the open dev-red issue
    "api search/issues"*) jq -r "${!#}" "$sw/search.json" 2>/dev/null || true ;;
    "run view "*) cat "$sw/run.$3.json" 2>/dev/null || return 1 ;;
    "run list "*"--commit "*)
      u="${a#*--commit }"; u="${u%% *}"
      [[ ! -e "$sw/runlist.fail.$u" ]] || return 1
      jq -r "${!#}" "$sw/runs.$u.json" 2>/dev/null || jq -rn '[]' | jq -r "${!#}" ;;
    "workflow run "*)
      # A dispatch on a PR's head branch starts an in-progress CI run on its head.
      echo "$a" >>"$sw/calls"
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
    "run list "*) cat "$sw/ci_head" 2>/dev/null || echo cihead ;;
    "api "*"/compare/cihead...dev"*) cat "$sw/ci_ahead" 2>/dev/null || echo 0 ;;
    "api "*"/compare/"*) [[ "$2" != *bad ]] || return 1; echo mb ;;
    "api "*"/git/trees/"*)
      u="${2#*/git/trees/}"; u="${u%%\?*}"
      (cd "$sw/refs/$u" 2>/dev/null && find . -type f | sed 's:^\./::') | jq -R '{path: ., type: "blob"}' | jq -s '{truncated: false, tree: .}' ;;
    "api "*"/contents/"*) u="${!#}"; u="${u#*/contents/}"; cat "$sw/refs/${u##*\?ref=}/${u%%\?*}" ;;
    "api "*"/issues/"*"/comments "*) n="${2#*/issues/}"; cat "$sw/${n%%/*}.comments" 2>/dev/null || true ;;
    "api repos/"*"/issues/"*)  # an issue's labels: $sw/labels.<n>, none if absent, a failure if .fail
      n="${2##*/}"; echo "labels $n" >>"$sw/lookups"
      [[ ! -e "$sw/labels.$n.fail" ]] || return 1
      jq -c '{labels: map({name: .})}' <<<"$(cat "$sw/labels.$n" 2>/dev/null || echo '[]')" | jq -r "${!#}" ;;
    "pr comment "*|"issue comment "*) echo "$a" >>"$sw/calls"; printf '%s\n' "${!#}" >>"$sw/$3.comments" ;;
    "pr merge "*) echo "$a" >>"$sw/calls"; touch "$sw/$3.merged"; printf '%s\n' "${!#}" >"$sw/$3.squash" ;;
    "pr edit "*"--body "*) echo "pr edit $3 --body" >>"$sw/calls"; printf '%s\n' "${!#}" >"$sw/$3.edited" ;;
    "pr edit "*"--base "*) echo "$a" >>"$sw/calls"; jq '.baseRefName = "dev"' "$sw/$3.json" >"$sw/x" && mv "$sw/x" "$sw/$3.json" ;;
    "pr edit "*"--remove-label fast-lane"*) echo "$a" >>"$sw/calls"
      jq '.labels |= map(select(.name != "fast-lane"))' "$sw/$3.json" >"$sw/x" && mv "$sw/x" "$sw/$3.json" ;;
    "pr edit "*"--add-label needs-fix"*) echo "$a" >>"$sw/calls"
      jq '.labels += [{"name": "needs-fix"}]' "$sw/$3.json" >"$sw/x" && mv "$sw/x" "$sw/$3.json" ;;
    "pr edit "*"--remove-label needs-fix"*) echo "$a" >>"$sw/calls"
      jq '.labels |= map(select(.name != "needs-fix"))' "$sw/$3.json" >"$sw/x" && mv "$sw/x" "$sw/$3.json" ;;
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
  real_pr 4; real_pr 7
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

# dispatch_reason: feature-done, then a UI change, then the 10-merge count.
reason() {  # reason <name> <want> <feature> <ui> <since>
  local got; got=$(dispatch_reason "$3" "$4" "$5")
  if [[ "$got" == "$2" ]]; then echo "ok   dispatch: $1"; else echo "FAIL dispatch: $1: want '$2', got '$got'"; fail=1; fi
}
reason "feature-done" "merged a feature-done PR" 1 0 ""
reason "UI change" "merged a UI change" 0 1 ""
reason "10 merges since CI" "10 merged PRs since the last CI run" 0 0 10
reason "9 merges wait" "" 0 0 9
reason "unknown count waits" "" 0 0 ""
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
touch "$sw/runlist.fail.h22"
lane_sweep() { ( FAST_LANE_RUN_LOOKUP_RETRIES=0 main ) >/dev/null 2>&1 || { echo "FAIL sweep: main exited non-zero"; fail=1; }; }
lane_sweep
expect "shell: a SuiteWindow PR gets one build-only run, no full run" \
  "$(grep -c -- '-f build_only=true --ref b14$' "$sw/calls"),$(grep -c '^workflow run ci.yml -R qbtrix/creative-apps --ref b14$' "$sw/calls")" "1,0"
expect "shell: an unreadable run list writes nothing for the PR" "$(grep -cE '^pr [a-z]+ 22 |--ref b22' "$sw/calls")" 0
jq 'map(if .displayTitle == "macOS build" then .status = "completed" | .conclusion = "success" else . end)' "$sw/runs.h14.json" >"$sw/x" && mv "$sw/x" "$sw/runs.h14.json"
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
lane_sweep
expect "build: dispatches one build-only run on the app PR's branch, re-sweep included" \
  "$(grep -c '^workflow run ci.yml -R qbtrix/creative-apps -f build_only=true --ref b30$' "$sw/calls")" 1
expect "build: comments the build's URL once" \
  "$(grep -c '^pr comment 30 .*The lane dispatched a macOS build on b30: https://github.com/qbtrix/creative-apps/actions/runs/830\.' "$sw/calls")" 1
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
jq 'map(if .displayTitle == "macOS build" then .status = "completed" | .conclusion = "success" else . end)' "$sw/runs.h30.json" >"$sw/x" && mv "$sw/x" "$sw/runs.h30.json"
lane_sweep
expect "build: once it compiled the head, a later sweep merges it" "$(grep -c '^pr merge 30' "$sw/calls")" 1
expect "build: the merge comment names the build" \
  "$(grep -c '^pr comment 30 .*merged into dev.*macOS build https://github.com/qbtrix/creative-apps/actions/runs/830' "$sw/calls")" 1
expect "build: still one build for its head" "$(grep -c -- '--ref b30$' "$sw/calls")" 1
# #36 touches only Tests/AppSnapshotTests (#1097's break): it gets the build too.
rm -rf "$sw"; mkdir -p "$sw"; : >"$sw/calls"
pr_at 36 h36 '[{"filename": "Tests/AppSnapshotTests/HaloPlaybackDriverTests.swift", "status": "modified"}]'
jq '.headRefName = "b36"' "$sw/36.json" >"$sw/x" && mv "$sw/x" "$sw/36.json"
lane_sweep
expect "build: a PR touching only a snapshot test gets one build, not a merge" \
  "$(grep -c -- '-f build_only=true --ref b36$' "$sw/calls"),$(grep -c '^pr merge 36' "$sw/calls")" "1,0"
expect "build: its comment names the folder" \
  "$(grep -c '^pr comment 36 .*changes code (Tests/AppSnapshotTests)' "$sw/calls")" 1
# #38 changes only PhotoModel (#1210's shape): it gets one build, not a merge.
# #39 changes only docs: it merges with no build.
rm -rf "$sw"; mkdir -p "$sw"; : >"$sw/calls"
pr_at 38 h38 '[{"filename": "Sources/PhotoModel/PhotoRecovery.swift", "status": "modified"}]'
pr_at 39 h39 '[{"filename": "docs/blueprints/photo/features/recovery.md", "status": "modified"}]'
for n in 38 39; do jq --arg b "b$n" '.headRefName = $b' "$sw/$n.json" >"$sw/x" && mv "$sw/x" "$sw/$n.json"; done
lane_sweep
expect "build: a Model-only PR gets one build, not a merge" \
  "$(grep -c -- '-f build_only=true --ref b38$' "$sw/calls"),$(grep -c '^pr merge 38' "$sw/calls")" "1,0"
expect "build: a docs-only PR merges with no build" \
  "$(grep -c -- '--ref b39' "$sw/calls"),$(grep -c '^pr merge 39' "$sw/calls")" "0,1"

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
printf '%s\n' "Likely cause: #102 feat(b): two (Clef 0.93). Flaky: 0.10." >"$sw/500.comments"
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

exit "$fail"
