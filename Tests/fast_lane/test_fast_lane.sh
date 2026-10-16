#!/usr/bin/env bash
# Tests/fast_lane/test_fast_lane.sh: fixture tests for the pure `decide`
# function in scripts/fast-lane.sh, its PROTECTED list against CLAUDE.md's
# "Never edit" bullet, the app audit guard (audit_loosens on before/after
# trees) and whole sweeps against a stub `gh`. No network, needs bash and jq.
#
# checks-green.json is a check rollup shaped like a green flare-core PR: the CI
# workflow's Linux and macOS jobs plus one SKIPPED CI job, a non-CI workflow
# check, a commit status, the fast-lane workflow's own in-progress check and a
# Copilot review check (decide must ignore the last two). Each case mutates a
# base PR / file list / rollup with jq. Most crew PRs have no CI on their head
# (CI runs on dev), so the worker's Fast-Check marker cases start from `[]`.
#
# Run: bash Tests/fast_lane/test_fast_lane.sh   (exit 0 = all pass)
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../scripts/fast-lane.sh
source "$here/../../scripts/fast-lane.sh"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fail=0

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

check "happy path" "eligible|150|2|5 checks green" . "$BASE_FILES" .
check "claude app bot author is not allowlisted" "not-eligible|author app/claude is not on the fast-lane allowlist" '.author.login = "app/claude"' "$BASE_FILES" .
check "deny path hit" "not-eligible|touches protected paths: .github/workflows/ci.yml" \
  . $'.github/workflows/ci.yml\nsrc/x.py' .
check "deny Package.swift" "not-eligible|touches protected paths: Package.swift" \
  . $'Package.swift\nSources/FlareModel/FlareWorkspace.swift' .
check "deny gate scripts" "not-eligible|touches protected paths: scripts/ci, scripts/cloud-setup.sh" \
  . $'scripts/ci\nscripts/cloud-setup.sh' .
check "deny agent rules, any case" "not-eligible|touches protected paths: docs/agents.md" \
  . 'docs/agents.md' .
check "similar names are allowed" "eligible|150|2|5 checks green" \
  . $'docs/scripts/ci.md\nSources/DesignModel/PackageSwiftNotes.swift' .
check "every script is protected (#292 changed scripts/ui-test)" "not-eligible|touches protected paths: scripts/ui-test" \
  . $'scripts/ui-test\nUITests/Audit.swift' .
check "deny .claude, Package.resolved and a nested CLAUDE.md" \
  "not-eligible|touches protected paths: .claude/settings.json, Package.resolved, Sources/FlareApp/CLAUDE.md" \
  . $'.claude/settings.json\nPackage.resolved\nSources/FlareApp/CLAUDE.md' .
check "deny the generated C4 model and waves.md" \
  "not-eligible|touches protected paths: docs/c4/model.json, docs/blueprints/halo/features/waves.md" \
  . $'docs/c4/model.json\ndocs/blueprints/halo/features/waves.md' .
check "C4 parts, feature data and packets stay eligible" "eligible|150|2|5 checks green" \
  . $'docs/c4/parts/creative-apps/halo-model/halo-model-sources.json\ndocs/blueprints/halo/features/easing.wave.json\ndocs/blueprints/halo/features/easing.md\ndocs/blueprints/halo/waves.in.md\ndocs/blueprints/halo/features/nested/waves.md' .
check "app code that built on macOS is eligible (taste review still happens after merge)" "eligible|150|2|5 checks green, macOS build $BUILD_URL" \
  . $'Sources/FlareApp/FlareApp.swift\nSources/FlareModel/FlareWorkspace.swift' .
check "SuiteUI outside MAC_GATED needs only the build" "eligible|150|2|5 checks green, macOS build $BUILD_URL" \
  . $'Sources/SuiteUI/GlassPanel.swift\nTests/SuiteUITests/GlassPanelTests.swift' .
check "models and tests stay eligible" "eligible|150|2|5 checks green" \
  . $'Sources/PhotoModel/PhotoWorkspace.swift\nTests/PhotoModelTests/PhotoWorkspaceTests.swift' .
check "a model named like an app is allowed" "eligible|150|2|5 checks green" \
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
check "docs only: any size on a green check" "eligible|1230|3|5 checks green, docs only: any size" "$BIG" "$DOCS" .
check "docs only: 40 files on the worker's marker" "eligible|1230|40|Fast-Check marker, docs only: any size" \
  "$(printf '.body = "Closes #1\\n\\nFast-Check: pass\\nHead: %s" | .additions = 1200 | .changedFiles = 40' "$HEAD_SHA")" \
  "$(many_docs 40)" '[]'
check "docs only under the cap: no tier note" "eligible|150|3|5 checks green" '.changedFiles = 3' "$DOCS" .
check "docs only still needs proof" "pending|no passing CI check and no Fast-Check: pass marker" "$BIG" "$DOCS" '[]'
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
check "no checks and no marker fails closed" "pending|no passing CI check and no Fast-Check: pass marker for head $HEAD_SHA" \
  . "$BASE_FILES" '[]'
check "only non-CI checks fails closed" "pending|no passing CI check" . "$BASE_FILES" \
  '[.[] | select(.__typename == "StatusContext")]'
check "one red check" "red|Linux" . "$BASE_FILES" \
  'map(if .name == "Linux" then .conclusion = "FAILURE" else . end)'
check "red status context" "red|ci/external" . "$BASE_FILES" \
  'map(if .context == "ci/external" then .state = "FAILURE" else . end)'
check "pending check" "pending|1 checks still running" . "$BASE_FILES" \
  'map(if .name == "macOS" then .status = "IN_PROGRESS" | .conclusion = null else . end)'
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
check "behind dev is still eligible (no freshness rule)" "eligible|150|2|5 checks green" \
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
check "marker for an older head waits" "pending|no passing CI check and no Fast-Check: pass marker" \
  "$(mark "Fast-Check: pass" "Head: ffffffffffffffffffffffffffffffffffffffff")" "$BASE_FILES" '[]'
check "short sha in the marker waits" "pending|no passing CI check" \
  "$(mark "Fast-Check: pass" "Head: ${HEAD_SHA:0:7}")" "$BASE_FILES" '[]'
check "Fast-Check: fail waits" "pending|no passing CI check" \
  "$(mark "Fast-Check: fail" "Head: $HEAD_SHA")" "$BASE_FILES" '[]'
check "Head line apart from the Fast-Check line waits" "pending|no passing CI check" \
  "$(mark "Fast-Check: pass" "x\nHead: $HEAD_SHA")" "$BASE_FILES" '[]'
check "Head line alone waits" "pending|no passing CI check" \
  '.body = "Head: '"$HEAD_SHA"'"' "$BASE_FILES" '[]'
check "marker does not outrank a red check" "red|Linux" "$MARKED" "$BASE_FILES" \
  'map(if .name == "Linux" then .conclusion = "FAILURE" else . end)'
check "marker does not outrank a running check" "pending|1 checks still running" "$MARKED" "$BASE_FILES" \
  'map(if .name == "macOS" then .status = "IN_PROGRESS" | .conclusion = null else . end)'
check "marker does not outrank hard rules" "not-eligible|too big" "$MARKED | .additions = 999" "$BASE_FILES" '[]'
check "marker does not outrank a conflict" "conflict|$HEAD_SHA" \
  "$MARKED | .mergeable = \"CONFLICTING\" | .mergeStateStatus = \"DIRTY\"" "$BASE_FILES" '[]'
check "marker on a draft is skipped" "skip|PR is a draft" "$MARKED | .isDraft = true" "$BASE_FILES" '[]'

# The macOS gate: a PR changing or renaming a MAC_GATED shared shell file needs
# a completed CI run on its head whose macOS job succeeded: the run a
# `Mac-Check: <run url>` line names (a supervisor's), else the latest CI run on
# the head, which the lane dispatches itself when there is none (authors get a
# 403 dispatching, #1040). mac <name> <want> <pr jq> <files> <mac-check run>
# <lane run> runs decide with both `gh run view` JSONs; each run is a jq
# filter on a green run on the head, or - for none.
RUN_URL="https://github.com/qbtrix/creative-apps/actions/runs/38700000001"
LANE_URL="https://github.com/qbtrix/creative-apps/actions/runs/38700000002"
GREEN_RUN='{"workflowName":"CI","status":"completed","conclusion":"success","headSha":"'"$HEAD_SHA"'",
  "url":"'"$LANE_URL"'",
  "jobs":[{"name":"Linux","status":"completed","conclusion":"success"},
          {"name":"macOS","status":"completed","conclusion":"success"}]}'
MAC_PR="$MARKED | .body += \"\\nMac-Check: $RUN_URL\""
GATED=$'Sources/SuiteUI/SuiteWindow.swift\nTests/SuiteUITests/SuiteWindowTests.swift'
OLD_HEAD="ffffffffffffffffffffffffffffffffffffffff"
FAILED_MAC='.conclusion = "failure" | (.jobs[] | select(.name == "macOS")).conclusion = "failure"'
RUNNING='.status = "in_progress" | .conclusion = "" | (.jobs[] | select(.name == "macOS")) |= (.status = "in_progress" | .conclusion = "")'
mac() {
  local name="$1" want="$2" got
  jq "$3" <<<"$BASE_PR" >"$tmp/pr.json"
  printf '%s\n' "$4" >"$tmp/files.txt"
  if [[ "$5" == - ]]; then echo '{}' >"$tmp/run.json"; else jq "$5" <<<"$GREEN_RUN" >"$tmp/run.json"; fi
  if [[ "$6" == - ]]; then echo '{}' >"$tmp/lane.json"; else jq "$6" <<<"$GREEN_RUN" >"$tmp/lane.json"; fi
  got=$(decide "$tmp/pr.json" "$tmp/files.txt" "$tmp/empty.json" "" "" "$tmp/run.json" "$tmp/lane.json" "$tmp/gbuild.json" 2>/dev/null)
  if [[ "$got" == "$want"* ]]; then echo "ok   mac: $name -> ${got:0:120}"; else echo "FAIL mac: $name: want '$want*', got '$got'"; fail=1; fi
}
echo '[]' >"$tmp/empty.json"
DISPATCH="mac-dispatch|Sources/SuiteUI/SuiteWindow.swift|feat/x"
REFUSE="mac-gate|changes Sources/SuiteUI/SuiteWindow.swift, shared by every app's window, so it needs a macOS run on its head $HEAD_SHA that is green or fails only where dev fails, and the CI run the lane found there doesn't: $LANE_URL"
mac "no Mac-Check line and no run on the head: the lane dispatches" "$DISPATCH" "$MARKED" "$GATED" - -
mac "a Mac-Check run on an older head, none on the head: dispatches" "$DISPATCH" "$MAC_PR" "$GATED" ".headSha = \"$OLD_HEAD\"" -
mac "an unreadable Mac-Check run, none on the head: dispatches" "$DISPATCH" "$MAC_PR" "$GATED" '{}' -
mac "a Mac-Check URL of another repo, none on the head: dispatches" "$DISPATCH" \
  "$MARKED | .body += \"\\nMac-Check: https://github.com/someone/creative-apps/actions/runs/1\"" "$GATED" . -
mac "a lane run on an older head counts as none: dispatches" "$DISPATCH" "$MARKED" "$GATED" - ".headSha = \"$OLD_HEAD\""
mac "the run on the head still going: waits, no second dispatch" "pending|waiting for the macOS CI run $LANE_URL on head $HEAD_SHA" \
  "$MARKED" "$GATED" - "$RUNNING"
mac "the run on the head green: eligible as if Mac-Check were there" "eligible|150|2|Fast-Check marker, macOS run $LANE_URL" \
  "$MARKED" "$GATED" - .
mac "a failed macOS job with no dev run to compare is refused" \
  "$REFUSE (its macOS job failed, and no completed macOS run on dev could be read to compare). Fix it and push; the lane dispatches CI again on the new head" \
  "$MARKED" "$GATED" - "$FAILED_MAC"
mac "a skipped macOS job is refused" "$REFUSE (its macOS job is skipped)" \
  "$MARKED" "$GATED" - '(.jobs[] | select(.name == "macOS")).conclusion = "skipped"'
mac "a run without a macOS job is refused" "$REFUSE (its run has no macOS job)" "$MARKED" "$GATED" - '.jobs |= map(select(.name != "macOS"))'
mac "another workflow's run is refused" "$REFUSE (its run is the Fast Lane workflow, not CI)" "$MARKED" "$GATED" - '.workflowName = "Fast Lane"'
# Dev can be red for days from other lines: a failed macOS job passes when its
# failing tests (evaluate reads them from the job log into failedTests) all
# fail in the latest completed dev run too (base), matched on the identifier.
DEV_URL="https://github.com/qbtrix/creative-apps/actions/runs/38711122431"
T1='-[HaloJourneyTests.HaloJourneyTests testLayoutAtWidths]'
T2='-[PhotoJourneyTests.PhotoJourneyTests testFixtureLaunch]'
T3='-[HaloJourneyTests.HaloHistoryJourneyTests testUndoRedoEveryEdit]'
UI_STEP='[{"name":"Run scripts/ci","conclusion":"success"},{"name":"Run scripts/ui-test","conclusion":"failure"}]'
fails() {  # fails <run tests json> <dev tests json> [<dev failed steps json>]: a failed macOS run with a dev base
  printf '%s | (.jobs[] | select(.name == "macOS")).steps = %s | .failedTests = %s | .base = {url: "%s", failedTests: %s, failedSteps: %s}' \
    "$FAILED_MAC" "$UI_STEP" "$1" "$DEV_URL" "$2" "${3:-[\"Run scripts/ui-test\"]}"
}
mac "same failures as dev passes" "eligible|150|2|Fast-Check marker, macOS run $LANE_URL (its failing tests also fail on dev: $DEV_URL)" \
  "$MARKED" "$GATED" - "$(fails "[\"$T1\", \"$T2\"]" "[\"$T2\", \"$T1\", \"-[Suite.Other x]\"]")"
mac "one new failure refuses and names it" \
  "$REFUSE (its macOS job has 1 failing test(s) that the latest dev run ($DEV_URL) does not: $T3). Fix it and push" \
  "$MARKED" "$GATED" - "$(fails "[\"$T1\", \"$T3\"]" "[\"$T1\", \"$T2\"]")"
mac "a green dev run makes every failure new" "$REFUSE (its macOS job has 2 failing test(s)" \
  "$MARKED" "$GATED" - "$(fails "[\"$T1\", \"$T2\"]" '[]' '[]')"
mac "a failure with no failing test to compare (build or setup) refuses" \
  "$REFUSE (its macOS job failed in Run scripts/ui-test with no failing test to compare with dev)" \
  "$MARKED" "$GATED" - "$(fails '[]' "[\"$T1\"]")"
mac "a failed step that passed on dev refuses, even with known tests" \
  "$REFUSE (its macOS job failed in Run scripts/ci, which passed in the latest dev run ($DEV_URL))" \
  "$MARKED" "$GATED" - "$(fails "[\"$T1\"]" "[\"$T1\"]") | (.jobs[] | select(.name == \"macOS\")).steps[0].conclusion = \"failure\""
mac "a supervisor's Mac-Check run with dev's failures passes" \
  "eligible|150|2|Fast-Check marker, Mac-Check: $RUN_URL (its failing tests also fail on dev: $DEV_URL)" \
  "$MAC_PR" "$GATED" "$(fails "[\"$T1\"]" "[\"$T1\"]")" -
# A gated PR's red macOS check run on the head is the gate's to judge; any
# other PR's still makes it red.
RED_MAC='[{"__typename":"CheckRun","name":"Linux","workflowName":"","status":"COMPLETED","conclusion":"SUCCESS"},
          {"__typename":"CheckRun","name":"macOS","workflowName":"","status":"COMPLETED","conclusion":"FAILURE"}]'
redmac() {  # redmac <name> <want> <files> <lane run jq>
  jq "$MARKED" <<<"$BASE_PR" >"$tmp/pr.json"; printf '%s\n' "$3" >"$tmp/files.txt"
  echo '{}' >"$tmp/run.json"; jq "$4" <<<"$GREEN_RUN" >"$tmp/lane.json"; echo "$RED_MAC" >"$tmp/redmac.json"
  local got; got=$(decide "$tmp/pr.json" "$tmp/files.txt" "$tmp/redmac.json" "" "" "$tmp/run.json" "$tmp/lane.json" 2>/dev/null)
  if [[ "$got" == "$2"* ]]; then echo "ok   mac: $1 -> ${got:0:100}"; else echo "FAIL mac: $1: want '$2*', got '$got'"; fail=1; fi
}
redmac "a red macOS check with dev's failures doesn't block a gated PR" "eligible|150|2|1 checks green, macOS run $LANE_URL (its failing" \
  "$GATED" "$(fails "[\"$T1\"]" "[\"$T1\"]")"
redmac "a red macOS check with a new failure is refused by name, not just red" "$REFUSE (its macOS job has 1 failing test(s)" \
  "$GATED" "$(fails "[\"$T3\"]" "[\"$T1\"]")"
redmac "an ungated PR's red macOS check is still red" "red|macOS" "$BASE_FILES" .
# failed_tests reads XCTest and Swift Testing failures off a timestamped job log.
got=$(printf '%s\n' \
  "2026-10-15T09:42:18.8623840Z /x/UITests/PhotoJourneyTests.swift:60: error: -[PhotoJourneyTests.PhotoJourneyTests testFixtureLaunch] : XCTAssertTrue failed" \
  "2026-10-15T09:42:19.1773830Z Test Case '-[PhotoJourneyTests.PhotoJourneyTests testFixtureLaunch]' failed (12.014 seconds)." \
  "2026-10-15T09:42:20.0000000Z Test Case '-[PhotoJourneyTests.PhotoJourneyTests testSave]' passed (1.0 seconds)." \
  "2026-10-15T09:42:21.0000000Z $(printf '\033[1;31m')✘$(printf '\033[0m') Test openKeepsState() failed after 0.2 seconds with 1 issue." \
  "2026-10-15T09:42:22.0000000Z Test Suite 'All tests' failed at 2026-10-15 09:46:25.386." | failed_tests | paste -sd'|' -)
if [[ "$got" == "-[PhotoJourneyTests.PhotoJourneyTests testFixtureLaunch]|Test openKeepsState()" ]]; then
  echo "ok   mac: failed_tests reads the failing test identifiers"
else echo "FAIL mac: failed_tests: got '$got'"; fail=1; fi
mac "a supervisor's green Mac-Check run passes, no dispatch" "eligible|150|2|Fast-Check marker, Mac-Check: $RUN_URL" "$MAC_PR" "$GATED" . -
mac "a green Mac-Check run outranks a failed lane run" "eligible|150|2|Fast-Check marker, Mac-Check: $RUN_URL" "$MAC_PR" "$GATED" . "$FAILED_MAC"
mac "a Mac-Check run with a failed macOS job falls back to the lane run" "eligible|150|2|Fast-Check marker, macOS run $LANE_URL" \
  "$MAC_PR" "$GATED" "$FAILED_MAC" .
mac "a job URL of a green run passes" "eligible|150|2|Fast-Check marker, Mac-Check:" \
  "$MARKED | .body += \"\\n  Mac-Check:   $RUN_URL/job/123  \"" "$GATED" . -
mac "an upper-case repo URL passes" "eligible|150|2|Fast-Check marker, Mac-Check:" \
  "$MARKED | .body += \"\\nMac-Check: https://github.com/QBTRIX/Creative-Apps/actions/runs/38700000001\"" "$GATED" . -
if shopt -q nocasematch; then echo "FAIL mac: mac_run_id leaves nocasematch on"; fail=1; else echo "ok   mac: mac_run_id restores nocasematch"; fi
mac "every gated file is named" \
  "mac-dispatch|Sources/SuiteUI/EditorShell.swift, Sources/SuiteUI/Tokens.swift, Sources/SuiteUI/ToolbarGroup.swift|feat/x" \
  "$MARKED" $'Sources/SuiteUI/Tokens.swift\nSources/SuiteUI/ToolbarGroup.swift\nSources/SuiteUI/EditorShell.swift' - -
mac "a rename away from a gated file is gated" "$DISPATCH" "$MARKED" $'Sources/SuiteUI/Window.swift\nSources/SuiteUI/SuiteWindow.swift' - -
mac "a PR touching no gated path is unaffected" "eligible|150|2|Fast-Check marker" "$MARKED" "$BASE_FILES" - -
mac "a gated PR still needs the Fast-Check marker" "pending|no passing CI check" ".body = \"Mac-Check: $RUN_URL\"" "$GATED" . .
mac "the gate does not outrank hard rules" "not-eligible|too big" "$MARKED | .additions = 999" "$GATED" - -
check "a gated PR with no run JSON at all dispatches" "$DISPATCH" "$MARKED" "$GATED" '[]'

# The macOS build gate (lesson 114, #1210): a PR changing code (BUILD_RE) that
# isn't MAC_GATED merges only once a build-only CI run (ci.yml's build_only
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
BREFUSE="mac-gate|changes code (Sources/LibraryApp, Sources/LibraryModel), and its head $HEAD_SHA doesn't build on macOS: $BUILD_URL"
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
  "mac-gate|changes code (Sources/PhotoModel), and its head $HEAD_SHA doesn't build on macOS: $BUILD_URL (failure)" \
  "$MARKED" 'Sources/PhotoModel/PhotoRecovery.swift' '.conclusion = "failure"'
# Every target gets the build, each on its own (run 38732179619: a snapshot
# test broke the macOS build, #1097).
build "only a snapshot test (#1097): the build" "build-dispatch|Tests/AppSnapshotTests|feat/x" "$MARKED" 'Tests/AppSnapshotTests/HaloPlaybackDriverTests.swift' -
build "only a UI journey: the build" "build-dispatch|UITests|feat/x" "$MARKED" 'UITests/HaloJourneyTests+Layers.swift' -
build "only a SuiteUI test: the build" "build-dispatch|Tests/SuiteUITests|feat/x" "$MARKED" 'Tests/SuiteUITests/TokensTests.swift' -
build "only SuiteUI outside MAC_GATED: the build" "build-dispatch|Sources/SuiteUI|feat/x" "$MARKED" 'Sources/SuiteUI/GlassPanel.swift' -
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
build "the build gate does not outrank the marker" "pending|no passing CI check" ".body = \"x\"" "$APP" .
build "a supervisor's green Mac-Check run covers the build" "eligible|150|2|Fast-Check marker, Mac-Check: $RUN_URL" "$MAC_PR" "$APP" - '[]' .
# A MAC_GATED PR that also touches app code takes the full Mac run only: it builds every app too.
jq "$MARKED" <<<"$BASE_PR" >"$tmp/pr.json"; printf '%s\n' 'Sources/SuiteUI/Tokens.swift' 'Sources/FlareApp/FlareApp.swift' >"$tmp/files.txt"
echo '{}' >"$tmp/run.json"; jq . <<<"$GREEN_BUILD" >"$tmp/build.json"
got=$(decide "$tmp/pr.json" "$tmp/files.txt" "$tmp/empty.json" "" "" "$tmp/run.json" "$tmp/run.json" "$tmp/build.json" 2>/dev/null)
if [[ "$got" == "mac-dispatch|Sources/SuiteUI/Tokens.swift|feat/x" ]]; then echo "ok   build: a gated PR with app code takes the full Mac run only -> $got"
else echo "FAIL build: a gated PR with app code: got '$got'"; fail=1; fi
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
check "belt PR, review success: eligible" "eligible|150|2|5 checks green" "$BELT" "$BASE_FILES" "$(review SUCCESS)"
check "belt PR, review failure: red" "red|review failed" "$BELT" "$BASE_FILES" "$(review FAILURE)"
check "belt PR, review error: red" "red|review failed" "$BELT" "$BASE_FILES" "$(review ERROR)"
check "a Belt-Test line makes a belt PR too" "pending|waiting for review" '.body = "Belt-Test: t-9"' "$BASE_FILES" .
check "red CI outranks the review" "red|Linux" "$BELT" "$BASE_FILES" \
  "$(review SUCCESS) | map(if .name == \"Linux\" then .conclusion = \"FAILURE\" else . end)"
check "non-belt PR ignores belt/review" "eligible|150|2|5 checks green" . "$BASE_FILES" "$(review FAILURE)"
check "belt PR with a marker still waits for review" "pending|waiting for review" \
  "$BELT | .body += \"\\nFast-Check: pass\\nHead: $HEAD_SHA\"" "$BASE_FILES" '[]'
REQUIRE_BELT_REVIEW=0
check "gate off: belt PR needs no review" "eligible|150|2|5 checks green" "$BELT" "$BASE_FILES" .
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
check "gate off: belt PR without review is eligible" "eligible|150|2|5 checks green" '.body = "x\nBelt-Run: act-1"' "$BASE_FILES" .

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
audit_decide "decide: a lowered baseline is eligible" "eligible|150|2|5 checks green"
# Like #292: baselines for checks it adds, plus a scripts/ui-test change. Only
# the script keeps it off the lane.
added "$FOCUS_BL" "$REG, Focus()" Focus=focus
audit_decide "decide: #292-style, new check baselines pass, the script doesn't" \
  "not-eligible|touches protected paths: scripts/ui-test" \
  "$(printf '%s\n' "$AUDIT_BASELINE" "$AD/AuditCore.swift" "$AD/Checks/Focus.swift" scripts/ui-test)"
audit_decide "decide: the same without the script is eligible" "eligible|150|2|5 checks green, macOS build $BUILD_URL" \
  "$(printf '%s\n' "$AUDIT_BASELINE" "$AD/AuditCore.swift" "$AD/Checks/Focus.swift")"

# A whole sweep against a stub `gh` that answers from per-PR fixtures and logs
# every write: #4 and #7 are eligible, #5 is based on main, #6 conflicts.
# sweep <PRs labelled feature-done> runs main() and leaves the writes in $sw/calls.
# Files come from $sw/files.<n>.json (raw API shape, the lane's --jq applied),
# the merge base is `mb` (`bad` for a head whose compare fails), and the trees
# and contents for a commit are the files under $sw/refs/<sha>.
sw="$tmp/sweep"
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
    "pr view "*) cat "$sw/$3.json" ;;
    "api "*"/check-runs"*|"api "*"/status "*) echo '[]' ;;
    "api "*"/pulls/"*"/files "*)
      n="${2#*/pulls/}"; n="${n%%/*}"
      if [[ -e "$sw/files.$n.json" ]]; then jq -r "${!#}" "$sw/files.$n.json"
      else jq -rn '[{filename: "Sources/FlareModel/FlareWorkspace.swift", status: "modified"}]' | jq -r "${!#}"; fi ;;
    "run view "*) cat "$sw/run.$3.json" 2>/dev/null || return 1 ;;
    "run list "*"--status completed"*) jq -r "${!#}" "$sw/devruns.json" 2>/dev/null || true ;;
    "api "*"/actions/jobs/"*"/logs") u="${2#*/actions/jobs/}"; cat "$sw/log.${u%%/*}" 2>/dev/null || return 1 ;;
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
    "pr comment "*) echo "$a" >>"$sw/calls"; printf '%s\n' "${!#}" >>"$sw/$3.comments" ;;
    "pr merge "*) echo "$a" >>"$sw/calls"; touch "$sw/$3.merged"; printf '%s\n' "${!#}" >"$sw/$3.squash" ;;
    "pr edit "*"--body "*) echo "pr edit $3 --body" >>"$sw/calls"; printf '%s\n' "${!#}" >"$sw/$3.edited" ;;
    "pr edit "*"--base "*) echo "$a" >>"$sw/calls"; jq '.baseRefName = "dev"' "$sw/$3.json" >"$sw/x" && mv "$sw/x" "$sw/$3.json" ;;
    "pr edit "*"--remove-label fast-lane"*) echo "$a" >>"$sw/calls"
      jq '.labels |= map(select(.name != "fast-lane"))' "$sw/$3.json" >"$sw/x" && mv "$sw/x" "$sw/$3.json" ;;
    *) echo "$a" >>"$sw/calls" ;;
  esac
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
  ( main ) >/dev/null 2>&1 || { echo "FAIL sweep: main exited non-zero"; fail=1; }
}
expect() {  # expect <name> <actual> <wanted>
  if [[ "$2" == "$3" ]]; then echo "ok   sweep: $1"; else echo "FAIL sweep: $1: want '$3', got '$2'"; fail=1; fi
}
sweep
expect "merges every eligible PR, oldest first, and the retargeted one on the re-sweep" \
  "$(grep -oE '^pr merge [0-9]+' "$sw/calls" | paste -sd, -)" "pr merge 4,pr merge 7,pr merge 5"
expect "retargets the main-based PR once" "$(grep -c '^pr edit 5 .*--base dev' "$sw/calls")" 1
expect "one conflict comment" "$(grep -c '^pr comment 6 .*conflicts with dev' "$sw/calls")" 1
expect "never merges the conflicting PR" "$(grep -c '^pr merge 6' "$sw/calls")" 0
expect "routine merges start no CI" "$(grep -c '^workflow run' "$sw/calls")" 0
sweep 4 7
expect "feature-done merges dispatch CI on dev once" "$(grep -c '^workflow run ci.yml .*--ref dev' "$sw/calls")" 1

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
expect "9 merged PRs since the last CI run start no CI" "$(grep -c '^workflow run' "$sw/calls")" 0
SWEEP_AHEAD=10 sweep
expect "the 10th merged PR since the last CI run dispatches once" "$(grep -c '^workflow run ci.yml .*--ref dev' "$sw/calls")" 1
SWEEP_CI_HEAD="" sweep
expect "a base with no CI run yet dispatches once" "$(grep -c '^workflow run ci.yml .*--ref dev' "$sw/calls")" 1
SWEEP_AHEAD=10 SWEEP_FILES="$UI_FILES" sweep 4
expect "every rule at once still dispatches once" "$(grep -c '^workflow run' "$sw/calls")" 1

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
# The macOS gate through sweeps. #14 changes SuiteWindow.swift with no
# Mac-Check line and no CI run on its head: the lane dispatches CI on its
# branch once and comments the run URL, and a later sweep merges it when that
# run is green on the head. #16 carries a supervisor's green Mac-Check run and
# merges at once. #18 touches no gated path. #20's run on the head failed on
# macOS. #22's run list fails, so nothing is written for it.
rm -rf "$sw"; mkdir -p "$sw"; : >"$sw/calls"
SWF='[{"filename": "Sources/SuiteUI/SuiteWindow.swift", "status": "modified"}]'
for n in 14 16 18 20 22; do
  pr_at "$n" "h$n" "$SWF"
  jq --arg b "b$n" '.headRefName = $b' "$sw/$n.json" >"$sw/x" && mv "$sw/x" "$sw/$n.json"
done
printf '%s\n' '[{"filename": "Sources/FlareModel/FlareWorkspace.swift", "status": "modified"}]' >"$sw/files.18.json"
jq -c '[.headSha = "h18"]' <<<"$GREEN_BUILD" >"$sw/runs.h18.json"
jq '.body += "\nMac-Check: https://github.com/qbtrix/creative-apps/actions/runs/16"' "$sw/16.json" >"$sw/x" && mv "$sw/x" "$sw/16.json"
jq '.headSha = "h16"' <<<"$GREEN_RUN" >"$sw/run.16.json"
jq --arg u "https://github.com/qbtrix/creative-apps/actions/runs/20" '.headSha = "h20" | .url = $u | '"$FAILED_MAC" <<<"$GREEN_RUN" >"$sw/run.20.json"
echo '[{"databaseId": "20", "url": "https://github.com/qbtrix/creative-apps/actions/runs/20"}]' >"$sw/runs.h20.json"
touch "$sw/runlist.fail.h22"
# #20's macOS job (id 2020) fails a test dev doesn't. Dev's latest completed CI
# runs: 701 was cancelled before macOS ran (skipped), 700 failed -[A.B old].
jq '(.jobs[] | select(.name == "macOS")) |= (.databaseId = 2020 | .steps = [{"name": "Run scripts/ui-test", "conclusion": "failure"}])' \
  "$sw/run.20.json" >"$sw/x" && mv "$sw/x" "$sw/run.20.json"
printf "%s\n" "2026-10-15T09:00:00.0Z Test Case '-[A.B old]' failed (1 seconds)." "2026-10-15T09:00:01.0Z Test Case '-[A.B new]' failed (1 seconds)." >"$sw/log.2020"
echo '[{"databaseId": "701"}, {"databaseId": "700"}]' >"$sw/devruns.json"
jq '.url = "https://github.com/qbtrix/creative-apps/actions/runs/701" | (.jobs[] | select(.name == "macOS")).conclusion = "skipped"' <<<"$GREEN_RUN" >"$sw/run.701.json"
jq '.url = "https://github.com/qbtrix/creative-apps/actions/runs/700" | '"$FAILED_MAC"' | (.jobs[] | select(.name == "macOS")) |= (.databaseId = 7000 | .steps = [{"name": "Run scripts/ui-test", "conclusion": "failure"}])' <<<"$GREEN_RUN" >"$sw/run.700.json"
printf "%s\n" "2026-10-15T08:00:00.0Z Test Case '-[A.B old]' failed (1 seconds)." >"$sw/log.7000"
# #24's run on its head (id 24) fails only -[A.B old], as dev does: it merges.
pr_at 24 h24 "$SWF"; jq '.headRefName = "b24"' "$sw/24.json" >"$sw/x" && mv "$sw/x" "$sw/24.json"
jq '.headSha = "h24" | .url = "https://github.com/qbtrix/creative-apps/actions/runs/24" | '"$FAILED_MAC"' | (.jobs[] | select(.name == "macOS")) |= (.databaseId = 2424 | .steps = [{"name": "Run scripts/ui-test", "conclusion": "failure"}])' <<<"$GREEN_RUN" >"$sw/run.24.json"
echo '[{"databaseId": "24", "url": "https://github.com/qbtrix/creative-apps/actions/runs/24"}]' >"$sw/runs.h24.json"
printf "%s\n" "2026-10-15T09:00:00.0Z Test Case '-[A.B old]' failed (1 seconds)." >"$sw/log.2424"
lane_sweep() { ( FAST_LANE_RUN_LOOKUP_RETRIES=0 main ) >/dev/null 2>&1 || { echo "FAIL sweep: main exited non-zero"; fail=1; }; }
lane_sweep
expect "mac: merges the supervisor-proved and the ungated PR, not the one waiting on its run" \
  "$(grep -oE '^pr merge [0-9]+' "$sw/calls" | paste -sd, -)" "pr merge 16,pr merge 18,pr merge 24"
expect "mac: the PR failing only where dev fails merges, its comment naming dev's run" \
  "$(grep -c '^pr comment 24 .*merged into dev.*macOS run https://github.com/qbtrix/creative-apps/actions/runs/24 (its failing tests also fail on dev: https://github.com/qbtrix/creative-apps/actions/runs/700)' "$sw/calls")" 1
expect "mac: dispatches CI on the gated PR's branch once, re-sweep included" \
  "$(grep -c '^workflow run ci.yml -R qbtrix/creative-apps --ref b14$' "$sw/calls")" 1
expect "mac: comments the dispatched run's URL once" \
  "$(grep -c '^pr comment 14 .*The lane dispatched CI on b14: https://github.com/qbtrix/creative-apps/actions/runs/914\.' "$sw/calls")" 1
expect "mac: no dispatch for a supervisor's Mac-Check run" "$(grep -c -- '--ref b16' "$sw/calls")" 0
expect "mac: a failed macOS run is refused with what to do, no new dispatch" \
  "$(grep -c "^pr comment 20 .*doesn't: https://github.com/qbtrix/creative-apps/actions/runs/20 (its macOS job has 1 failing test(s) that the latest dev run (https://github.com/qbtrix/creative-apps/actions/runs/700) does not: -\[A.B new\])\. Fix it and push" "$sw/calls")" 1
expect "mac: a failed run never re-dispatches" "$(grep -cE -- '--ref b2[04]' "$sw/calls")" 0
expect "mac: an unreadable run list writes nothing for the PR" "$(grep -cE '^pr [a-z]+ 22 |--ref b22' "$sw/calls")" 0
expect "mac: refused PRs keep the fast-lane label" "$(grep -c -- '--remove-label fast-lane' "$sw/calls")" 0
lane_sweep
expect "mac: a later sweep while the run is going dispatches nothing more" \
  "$(grep -c -- '--ref b14$' "$sw/calls")" 1
expect "mac: and comments nothing more" "$(grep -c '^pr comment 14 ' "$sw/calls")" 1
expect "mac: and doesn't merge it" "$(grep -c '^pr merge 14' "$sw/calls")" 0
jq '.status = "completed" | .conclusion = "success" | .jobs[].status = "completed" | .jobs[].conclusion = "success"' \
  "$sw/run.914.json" >"$sw/x" && mv "$sw/x" "$sw/run.914.json"
lane_sweep
expect "mac: once that run is green on the head, a later sweep merges it" "$(grep -c '^pr merge 14' "$sw/calls")" 1
expect "mac: the merge comment names the run" \
  "$(grep -c '^pr comment 14 .*merged into dev.*macOS run https://github.com/qbtrix/creative-apps/actions/runs/914' "$sw/calls")" 1
expect "mac: still one dispatch for its head" "$(grep -c -- '--ref b14$' "$sw/calls")" 1

# The macOS build gate through sweeps (lesson 114). #30 changes
# Sources/LibraryApp with no build on its head: the lane dispatches a
# build-only run on its branch once (-f build_only=true) and comments its URL,
# waits while it builds, and merges once it compiled. #32's build on its head
# failed: refused by URL, no dispatch. #34 is MAC_GATED and touches app code:
# it gets the full run only, never a build-only one.
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
expect "build: a MAC_GATED PR with app code gets the full run, not a build" \
  "$(grep -c -- '--ref b34$' "$sw/calls"),$(grep -c -- 'build_only=true --ref b34' "$sw/calls")" "1,0"
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
lane_sweep
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
exit "$fail"
