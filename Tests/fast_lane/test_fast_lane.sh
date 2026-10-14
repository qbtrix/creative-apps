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
BASE_PR='{"number":1,"state":"OPEN","isDraft":false,"baseRefName":"dev",
  "labels":[{"name":"fast-lane"}],"author":{"login":"prakashUXtech"},
  "additions":120,"deletions":30,"changedFiles":2,
  "mergeable":"MERGEABLE","mergeStateStatus":"CLEAN","headRefOid":"'"$HEAD_SHA"'",
  "body":"Closes #1"}'
BASE_FILES=$'Sources/FlareModel/FlareWorkspace.swift\nTests/FlareModelTests/FlareWorkspaceTests.swift'

# check <name> <expected stdout prefix> <pr jq> <files> <checks jq>
check() {
  local name="$1" want="$2" prq="$3" files="$4" chq="$5" got
  jq "$prq" <<<"$BASE_PR" >"$tmp/pr.json"
  printf '%s\n' "$files" >"$tmp/files.txt"
  jq "$chq" "$here/checks-green.json" >"$tmp/checks.json"
  got=$(decide "$tmp/pr.json" "$tmp/files.txt" "$tmp/checks.json" 2>/dev/null)
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
check "app shell is eligible (taste review happens after merge, on the snapshots)" "eligible|150|2|5 checks green" \
  . $'Sources/FlareApp/FlareApp.swift\nSources/FlareModel/FlareWorkspace.swift' .
check "SuiteUI is eligible" "eligible|150|2|5 checks green" \
  . $'Sources/SuiteUI/Tokens.swift\nTests/SuiteUITests/TokensTests.swift' .
check "models and tests stay eligible" "eligible|150|2|5 checks green" \
  . $'Sources/PhotoModel/PhotoWorkspace.swift\nTests/AppSnapshotTests/AppSnapshotTests.swift' .
check "a model named like an app is allowed" "eligible|150|2|5 checks green" \
  . $'Sources/HaloModel/HaloAppState.swift\nTests/HaloModelTests/HaloProjectTests.swift' .
check "UI with only the worker's marker is eligible" "eligible|150|2|Fast-Check marker" \
  "$(printf '.body = "Closes #1\\n\\nFast-Check: pass\\nHead: %s"' "$HEAD_SHA")" \
  $'Sources/FlareApp/FlareApp.swift\nSources/SuiteUI/Tokens.swift' '[]'
check "too big (lines)" "not-eligible|too big: 401 lines" '.additions = 401 | .deletions = 0' "$BASE_FILES" .
check "too big (files)" "not-eligible|too big: 150 lines, 16 files" '.changedFiles = 16' "$BASE_FILES" .
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
  got=$(decide "$tmp/pr.json" "$tmp/files.txt" "$here/checks-green.json" "$b" "$a" 2>/dev/null)
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
audit_decide "decide: the same without the script is eligible" "eligible|150|2|5 checks green" \
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
    "pr view "*"--json closingIssuesReferences "*) ;;
    "pr view "*) cat "$sw/$3.json" ;;
    "api "*"/check-runs"*|"api "*"/status "*) echo '[]' ;;
    "api "*"/pulls/"*"/files "*)
      n="${2#*/pulls/}"; n="${n%%/*}"
      if [[ -e "$sw/files.$n.json" ]]; then jq -r "${!#}" "$sw/files.$n.json"
      else jq -rn '[{filename: "Sources/FlareModel/FlareWorkspace.swift", status: "modified"}]' | jq -r "${!#}"; fi ;;
    "run list "*) cat "$sw/ci_head" 2>/dev/null || echo cihead ;;
    "api "*"/compare/cihead...dev"*) cat "$sw/ci_ahead" 2>/dev/null || echo 0 ;;
    "api "*"/compare/"*) [[ "$2" != *bad ]] || return 1; echo mb ;;
    "api "*"/git/trees/"*)
      u="${2#*/git/trees/}"; u="${u%%\?*}"
      (cd "$sw/refs/$u" 2>/dev/null && find . -type f | sed 's:^\./::') | jq -R '{path: ., type: "blob"}' | jq -s '{truncated: false, tree: .}' ;;
    "api "*"/contents/"*) u="${!#}"; u="${u#*/contents/}"; cat "$sw/refs/${u##*\?ref=}/${u%%\?*}" ;;
    "api "*"/issues/"*"/comments "*) n="${2#*/issues/}"; cat "$sw/${n%%/*}.comments" 2>/dev/null || true ;;
    "pr comment "*) echo "$a" >>"$sw/calls"; printf '%s\n' "${!#}" >>"$sw/$3.comments" ;;
    "pr merge "*) echo "$a" >>"$sw/calls"; touch "$sw/$3.merged" ;;
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
UI_FILES='[{"filename": "Sources/SuiteUI/Tokens.swift", "status": "modified"}]'
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
exit "$fail"
