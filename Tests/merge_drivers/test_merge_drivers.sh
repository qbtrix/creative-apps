#!/usr/bin/env bash
# Tests/merge_drivers/test_merge_drivers.sh: the repo's .gitattributes merge
# drivers (scripts/install-merge-drivers, scripts/merge-json) on scratch git
# repos. Covers: the JSON driver merges distinct keys, nested keys, a key
# deleted on one side, an add/add of two objects, keeps ours' key order and
# jq's 2-space formatting; the same key changed both ways, a deletion against a
# change and two different array edits conflict with ordinary markers and a
# non-zero exit (git lists the file as unmerged); a side that isn't JSON falls
# back to git's line merge; a rebase uses the driver too; with the attribute
# but no driver installed git merges by lines, so the attribute is inert for
# anyone who never ran the installer; the installer sets rebase.updateRefs and
# defines every driver .gitattributes names. Hermetic: HOME and git config
# point into the temp dir. No network; needs bash, git, jq.
#
# Run: bash Tests/merge_drivers/test_merge_drivers.sh   (exit 0 = all pass)
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$here/../.."
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export HOME="$tmp" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
fail=0
ok() { echo "ok   $1"; }
bad() { echo "FAIL $1"; fail=1; }

# repo <dir> [--no-install]: a scratch repo with the real .gitattributes.
repo() {
  local d="$1"
  git init -q -b main "$d"
  git -C "$d" config user.name t; git -C "$d" config user.email t@t; git -C "$d" config commit.gpgsign false
  cp "$root/.gitattributes" "$d/.gitattributes"
  [[ "${2:-}" == --no-install ]] || bash "$root/scripts/install-merge-drivers" "$d" >/dev/null
}
# three <dir> <file> <base> <ours> <theirs>: base commit on main, `ours` and `theirs`
# branches each changing <file>; leaves <dir> on ours.
three() {
  local d="$1" f="$2"
  printf '%s\n' "$3" >"$d/$f"; git -C "$d" add -A; git -C "$d" commit -qm base
  git -C "$d" switch -qc theirs; printf '%s\n' "$5" >"$d/$f"; git -C "$d" commit -qam theirs
  git -C "$d" switch -qc ours main; printf '%s\n' "$4" >"$d/$f"; git -C "$d" commit -qam ours
}
# merge <dir>: merges theirs into ours; prints the exit code.
merge() { git -C "$1" merge -q --no-edit theirs >/dev/null 2>&1; echo $?; }
unmerged() { git -C "$1" diff --name-only --diff-filter=U; }

# 1. distinct keys, ours' order first, 2-space output
d="$tmp/distinct"; repo "$d"; three "$d" a.json '{"b": 1, "a": 2}' '{"b": 10, "a": 2, "c": 3}' '{"b": 1, "a": 20}'
[[ "$(merge "$d")" == 0 ]] && ok "distinct keys merge" || bad "distinct keys merge: $(cat "$d/a.json")"
want=$'{\n  "b": 10,\n  "a": 20,\n  "c": 3\n}'
[[ "$(cat "$d/a.json")" == "$want" ]] && ok "ours' key order and 2-space formatting" || bad "key order/format: $(cat "$d/a.json")"

# 2. nested keys
d="$tmp/nested"; repo "$d"; three "$d" n.json '{"x": {"p": 1, "q": 2}, "y": 0}' '{"x": {"p": 11, "q": 2}, "y": 0}' '{"x": {"p": 1, "q": 22}, "y": 5}'
[[ "$(merge "$d")" == 0 && "$(jq -c . "$d/n.json")" == '{"x":{"p":11,"q":22},"y":5}' ]] && ok "nested keys merge" || bad "nested: $(cat "$d/n.json")"

# 3. same key changed both ways: conflict with markers
d="$tmp/samekey"; repo "$d"; three "$d" s.json '{"a": 1}' '{"a": 2}' '{"a": 3}'
[[ "$(merge "$d")" != 0 && "$(unmerged "$d")" == s.json ]] && ok "same key both ways conflicts" || bad "same key: exit/unmerged"
grep -q '^<<<<<<<' "$d/s.json" && grep -q '^>>>>>>>' "$d/s.json" && ok "conflict carries ordinary markers" || bad "markers: $(cat "$d/s.json")"

# 4. deleted on one side, unchanged on the other: gone
d="$tmp/delete"; repo "$d"; three "$d" d.json '{"a": 1, "b": 2}' '{"b": 2}' '{"a": 1, "b": 3}'
[[ "$(merge "$d")" == 0 && "$(jq -c . "$d/d.json")" == '{"b":3}' ]] && ok "deletion against unchanged wins" || bad "delete: $(cat "$d/d.json")"

# 5. deleted on one side, changed on the other: conflict
d="$tmp/delmod"; repo "$d"; three "$d" d.json '{"a": 1, "b": 2}' '{"b": 2}' '{"a": 9, "b": 2}'
[[ "$(merge "$d")" != 0 && "$(unmerged "$d")" == d.json ]] && ok "deletion against a change conflicts" || bad "delmod"

# 6. arrays are atomic
d="$tmp/arr1"; repo "$d"; three "$d" a.json '{"l": [1, 2], "k": 0}' '{"l": [1, 2, 3], "k": 0}' '{"l": [1, 2], "k": 1}'
[[ "$(merge "$d")" == 0 && "$(jq -c . "$d/a.json")" == '{"l":[1,2,3],"k":1}' ]] && ok "array changed on one side is taken" || bad "arr1: $(cat "$d/a.json")"
d="$tmp/arr2"; repo "$d"; three "$d" a.json '{"l": [1, 2]}' '{"l": [1, 2, 3]}' '{"l": [0, 1, 2]}'
[[ "$(merge "$d")" != 0 && "$(unmerged "$d")" == a.json ]] && ok "two array edits conflict" || bad "arr2"

# 7. not JSON on one side: git's line merge
d="$tmp/text"; repo "$d"; three "$d" t.json $'{\n"a": 1,\n"b": 2\n}' $'{\n"a": 1,\n"b": 2\n}\n// not json' $'{\n"a": 0,\n"b": 2\n}'
[[ "$(merge "$d")" == 0 && "$(cat "$d/t.json")" == $'{\n"a": 0,\n"b": 2\n}\n// not json' ]] && ok "a non-JSON side falls back to the line merge" || bad "text: $(cat "$d/t.json")"

# 8. add/add of two objects
d="$tmp/addadd"; repo "$d"
printf 'x\n' >"$d/README"; git -C "$d" add -A; git -C "$d" commit -qm base
git -C "$d" switch -qc theirs; printf '{"t": 1}\n' >"$d/new.json"; git -C "$d" add -A; git -C "$d" commit -qm theirs
git -C "$d" switch -qc ours main; printf '{"o": 1}\n' >"$d/new.json"; git -C "$d" add -A; git -C "$d" commit -qm ours
[[ "$(merge "$d")" == 0 && "$(jq -c . "$d/new.json")" == '{"o":1,"t":1}' ]] && ok "add/add of two objects merges" || bad "addadd: $(cat "$d/new.json" 2>&1)"

# 9. a rebase uses the driver too
d="$tmp/rebase"; repo "$d"; three "$d" r.json '{"a": 1, "b": 1}' '{"a": 2, "b": 1}' '{"a": 1, "b": 2}'
if git -C "$d" rebase -q theirs >/dev/null 2>&1 && [[ "$(jq -c . "$d/r.json")" == '{"a":2,"b":2}' ]]; then ok "rebase merges by key"; else bad "rebase: $(cat "$d/r.json")"; fi

# 10. attribute without the installer: inert, git merges by lines
PAD=$'"m": 0,\n"n": 0,\n"o": 0,'  # three unchanged lines, so a line merge can tell the two edits apart
d="$tmp/noinstall"; repo "$d" --no-install; three "$d" a.json $'{\n"a": 1,\n'"$PAD"$'\n"b": 1\n}' $'{\n"a": 2,\n'"$PAD"$'\n"b": 1\n}' $'{\n"a": 1,\n'"$PAD"$'\n"b": 2\n}'
[[ -z "$(git -C "$d" config --get merge.json.driver)" ]] && ok "no driver config without the installer" || bad "driver config leaked"
[[ "$(merge "$d")" == 0 && "$(cat "$d/a.json")" == $'{\n"a": 2,\n'"$PAD"$'\n"b": 2\n}' ]] && ok "without the installer git merges by lines" || bad "noinstall: $(cat "$d/a.json")"

# 11. the installer: updateRefs, every attribute driver defined, idempotent, absolute path
d="$tmp/inst"; repo "$d"
[[ "$(git -C "$d" config --get rebase.updateRefs)" == true ]] && ok "rebase.updateRefs=true" || bad "updateRefs"
for drv in $(grep -oE 'merge=[A-Za-z0-9_-]+' "$root/.gitattributes" | cut -d= -f2 | sort -u); do
  [[ "$drv" == union ]] && continue
  [[ -n "$(git -C "$d" config --get "merge.$drv.driver")" ]] && ok "driver '$drv' in .gitattributes is defined" || bad "driver '$drv' named in .gitattributes but not installed"
done
[[ "$(git -C "$d" config --get merge.json.driver)" == "'$(cd "$root/scripts" && pwd)/merge-json"* ]] && ok "driver path is absolute" || bad "driver path: $(git -C "$d" config --get merge.json.driver)"
bash "$root/scripts/install-merge-drivers" "$d" >/dev/null && [[ "$(git -C "$d" config --get-all merge.json.driver | wc -l | tr -d ' ')" == 1 ]] && ok "installer is idempotent" || bad "installer not idempotent"

(( fail == 0 )) && echo "merge drivers: PASS" || { echo "merge drivers: FAIL"; exit 1; }
