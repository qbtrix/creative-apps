#!/usr/bin/env bash
# Tests/bump_core/test_bump_core.sh: tests for scripts/bump-core against a
# scratch repo (origin is a local bare repo), a fake `gh` that answers
# `gh api` from canned JSON through the script's own --jq and records
# `gh pr create`, and a fake `swift` that logs its calls and rewrites
# Package.resolved on `package resolve`. Covers the bump PR (title, pins,
# range, one link per core PR, the checks it ran), the already-pinned exit,
# a commit behind the pin, a failing check and a dirty tree. No network;
# needs bash 3.2+, git and jq.
#
# Run: bash Tests/bump_core/test_bump_core.sh   (exit 0 = all pass)
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fail=0

OLD=1111111111111111111111111111111111111111
NEW=2222222222222222222222222222222222222222
BEHIND=0000000000000000000000000000000000000000
CORE=repos_qbtrix_creative-core

export FAKE="$tmp/fake"
mkdir -p "$FAKE/api" "$tmp/bin"
cat >"$tmp/bin/gh" <<'EOF'
#!/usr/bin/env bash
echo "gh $*" >>"$FAKE/calls"
if [[ "$1" == api ]]; then
  f="$FAKE/api/$(printf '%s' "$2" | tr '/' '_').json"
  [[ -f "$f" ]] || { echo "gh: Not Found (HTTP 404)" >&2; exit 1; }
  if [[ "${3:-}" == --jq ]]; then exec jq -r "$4" "$f"; fi
  exec cat "$f"
fi
if [[ "$1 $2" == "pr create" ]]; then
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --title) printf '%s\n' "$2" >"$FAKE/title"; shift ;;
      --body-file) cp "$2" "$FAKE/body"; shift ;;
    esac
    shift
  done
  echo "https://github.com/qbtrix/creative-apps/pull/9999"
fi
EOF
cat >"$tmp/bin/swift" <<'EOF'
#!/usr/bin/env bash
echo "swift $*" >>"$FAKE/calls"
case "$1" in
  package)
    rev=$(sed -n 's/.*revision: "\([0-9a-f]*\)".*/\1/p' Package.swift)
    printf '{\n  "pins" : [\n    {\n      "identity" : "creative-core",\n      "state" : {\n        "revision" : "%s"\n      }\n    }\n  ]\n}\n' "$rev" >Package.resolved ;;
  test) exit "${FAKE_TEST_STATUS:-0}" ;;
esac
EOF
chmod +x "$tmp/bin/gh" "$tmp/bin/swift"
export PATH="$tmp/bin:$PATH"

echo "{\"sha\":\"$NEW\"}" >"$FAKE/api/${CORE}_commits_main.json"
echo "{\"sha\":\"$OLD\"}" >"$FAKE/api/${CORE}_commits_$OLD.json"
echo "{\"sha\":\"$BEHIND\"}" >"$FAKE/api/${CORE}_commits_behind.json"
echo '{"status":"identical"}' >"$FAKE/api/${CORE}_compare_$NEW...main.json"
echo '{"status":"ahead"}' >"$FAKE/api/${CORE}_compare_$BEHIND...main.json"
echo '{"status":"behind","total_commits":0,"commits":[]}' >"$FAKE/api/${CORE}_compare_$OLD...$BEHIND.json"
cat >"$FAKE/api/${CORE}_compare_$OLD...$NEW.json" <<EOF
{"status":"ahead","total_commits":3,"commits":[
  {"sha":"aaaaaaa1$OLD","commit":{"message":"feat(color): a new space (#300)\n\nlong body (#1)"}},
  {"sha":"bbbbbbb2$OLD","commit":{"message":"chore: a direct push"}},
  {"sha":"$NEW","commit":{"message":"perf(raster): rgba8 through display tables (#321)"}}]}
EOF

# The origin: a dev branch with a pinned Package.swift, its Package.resolved,
# two Model test targets and the script under test.
seed="$tmp/seed"
mkdir -p "$seed/scripts" "$seed/Tests/AModelTests" "$seed/Tests/BModelTests" "$seed/Tests/AppSnapshotTests"
cp "$here/../../scripts/bump-core" "$seed/scripts/"
for t in AModelTests BModelTests AppSnapshotTests; do : >"$seed/Tests/$t/T.swift"; done
printf '    .package(url: "https://github.com/qbtrix/creative-core", revision: "%s"),\n' "$OLD" >"$seed/Package.swift"
(
  cd "$seed" && git init -q -b dev && git config user.name t && git config user.email t@t \
    && swift package resolve && git add -A && git commit -q -m seed \
    && git clone -q --bare . "$tmp/origin.git"
) || { echo "FAIL setup: could not build the scratch repo"; exit 1; }

n=0
# bump [args...]: a fresh clone of origin in $work, then scripts/bump-core
# there; its output in $out, its exit status in $status.
bump() {
  n=$((n + 1))
  work="$tmp/work$n"
  rm -f "$FAKE/title" "$FAKE/body"
  : >"$FAKE/calls"
  git clone -q -b dev "$tmp/origin.git" "$work" && git -C "$work" config user.name t && git -C "$work" config user.email t@t
  [[ -z "${DIRTY:-}" ]] || echo "// edit" >>"$work/Package.swift"
  out=$(cd "$work" && scripts/bump-core "$@" 2>&1)
  status=$?
}
# expect <name> <got> <want>
expect() {
  if [[ "$2" == "$3" ]]; then echo "ok   $1"; else printf 'FAIL %s\n  want: %s\n  got:  %s\n' "$1" "$3" "$2"; fail=1; fi
}
calls() { grep -c "$1" "$FAKE/calls"; }  # basic regex: ( | ^ mid-pattern are literal

bump
expect "bump: exits 0" "$status" 0
expect "bump: the PR title names the short sha" "$(cat "$FAKE/title" 2>/dev/null)" "chore(core): bump creative-core to 2222222"
expect "bump: Package.swift and Package.resolved pin the new commit" \
  "$(grep -c "revision: \"$NEW\"" "$work/Package.swift"),$(grep -c "\"revision\" : \"$NEW\"" "$work/Package.resolved")" "1,1"
expect "bump: one commit on the bump branch, pushed to origin" \
  "$(git -C "$work" rev-list --count origin/dev..HEAD),$(git -C "$tmp/origin.git" rev-parse --verify -q chore/bump-core-2222222 >/dev/null && echo pushed)" "1,pushed"
expect "bump: the commit holds only the package files" \
  "$(git -C "$work" show --name-only --format= HEAD | paste -sd, -)" "Package.resolved,Package.swift"
expect "bump: the PR targets dev without the fast-lane label" \
  "$(calls '^gh pr create --base dev --head chore/bump-core-2222222 '),$(calls 'fast-lane')" "1,0"
expect "bump: the body has the compare link" \
  "$(grep -c "^Core range (3 commits): https://github.com/qbtrix/creative-core/compare/$OLD...$NEW$" "$FAKE/body")" 1
expect "bump: one link per core PR, subject without its (#N)" \
  "$(grep -E '^- \[creative-core#' "$FAKE/body" | paste -sd'|' -)" \
  "- [creative-core#300](https://github.com/qbtrix/creative-core/pull/300) feat(color): a new space|- [creative-core#321](https://github.com/qbtrix/creative-core/pull/321) perf(raster): rgba8 through display tables"
expect "bump: a commit without a PR is listed by sha" "$(grep -c '^- bbbbbbb chore: a direct push$' "$FAKE/body")" 1
expect "bump: resolve, build with tests, then every Model test target" \
  "$(calls '^swift package resolve$'),$(calls '^swift build --build-tests'),$(calls 'swift test --skip-build.* --filter ^(AModelTests|BModelTests)\\.$')" "1,1,1"
if [[ "$(uname)" == Darwin ]]; then perf=1; else perf=0; fi
expect "bump: the perf suites run on macOS only" \
  "$(calls 'filter ^AppSnapshotTests\\.(PhotoBrushDisplayTests|PhotoBrushLatencyTests|PhotoBrushInkLatencyTests)/ --no-parallel$')" "$perf"

bump "$OLD"
expect "already pinned: exits 0 with no branch and no PR" \
  "$status,$(git -C "$work" branch --show-current),$(calls '^gh pr create')" "0,dev,0"

bump behind
expect "behind the pin: refused before any branch or swift run" \
  "$status,$(git -C "$work" branch --show-current),$(calls '^swift '),$(calls '^gh pr create')" "1,dev,0,0"
expect "behind the pin: says why" "$(grep -c 'is not ahead of the pin' <<<"$out")" 1

FAKE_TEST_STATUS=1 bump
expect "failing Model tests: stops before the commit and the PR" \
  "$status,$(git -C "$work" rev-list --count origin/dev..HEAD),$(calls '^gh pr create')" "1,0,0"
expect "failing Model tests: says so" "$(grep -c 'Model tests failed at 2222222' <<<"$out")" 1

DIRTY=1 bump
expect "dirty tree: refused" "$status,$(calls '^gh '),$(grep -c 'tracked changes' <<<"$out")" "1,0,1"

exit "$fail"
