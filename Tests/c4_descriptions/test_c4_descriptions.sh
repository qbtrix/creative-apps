#!/usr/bin/env bash
# Tests/c4_descriptions/test_c4_descriptions.sh: scripts/check-c4-descriptions
# on scratch git repos. Covers: a feature PR that appends to an existing part's
# description fails, also when the edit is uncommitted; editing only `paths`,
# adding a key, or reformatting passes; a PR that adds a part (committed or
# still untracked) may touch descriptions; a PR that changes only
# docs/c4/parts/ may refresh the prose. Hermetic: HOME and git config point
# into the temp dir. No network; needs bash, git, python3.
#
# Run: bash Tests/c4_descriptions/test_c4_descriptions.sh   (exit 0 = all pass)
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
check="$here/../../scripts/check-c4-descriptions"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export HOME="$tmp" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
fail=0
P=docs/c4/parts/s/c/comp.json
base_part='{"id":"comp","description":"Holds A.","order":1,"paths":["Sources/A/"]}'

# case <name> <want exit> <setup commands...>: a repo with one part on main,
# a branch where the setup runs (in the repo dir), then the check against main.
case_() {
  local name="$1" want="$2"; shift 2
  local d="$tmp/$name"
  git init -q -b main "$d"
  git -C "$d" config user.name t; git -C "$d" config user.email t@t; git -C "$d" config commit.gpgsign false
  mkdir -p "$d/docs/c4/parts/s/c" "$d/Sources/A"
  printf '%s\n' "$base_part" >"$d/$P"; : >"$d/Sources/A/One.swift"
  git -C "$d" add -A; git -C "$d" commit -qm base; git -C "$d" switch -qc feat
  (cd "$d" && eval "$*")
  local out got
  out=$(cd "$d" && python3 "$check" main 2>&1); got=$?
  if [[ "$got" == "$want" ]]; then echo "ok   $name"; else echo "FAIL $name (want $want, got $got): $out"; fail=1; fi
}
code='echo "// x" >Sources/A/Two.swift'
append="sed -i.bak 's/Holds A\\./Holds A and B./' $P && rm $P.bak"

case_ append-fails          1 "$code; $append; git add -A; git commit -qm f"
case_ uncommitted-fails     1 "$code; $append"
case_ paths-only-passes     0 "$code; printf '%s\n' '{\"id\":\"comp\",\"description\":\"Holds A.\",\"order\":1,\"paths\":[\"Sources/A/\",\"Sources/B/\"]}' >$P; git add -A; git commit -qm f"
case_ new-key-passes        0 "$code; printf '%s\n' '{\"id\":\"comp\",\"description\":\"Holds A.\",\"order\":1,\"paths\":[\"Sources/A/\"],\"relationships\":[{\"source\":\"comp\",\"target\":\"x\",\"description\":\"uses\"}]}' >$P; git add -A; git commit -qm f"
case_ reformat-passes       0 "$code; python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); json.dump(d, open(sys.argv[1],\"w\"), indent=4)' $P; git add -A; git commit -qm f"
case_ new-part-passes       0 "$code; $append; printf '%s\n' '{\"id\":\"b\",\"description\":\"Holds B.\",\"order\":2,\"paths\":[\"Sources/B/\"]}' >docs/c4/parts/s/c/b.json; git add -A; git commit -qm f"
case_ untracked-part-passes 0 "$code; $append; printf '%s\n' '{\"id\":\"b\",\"description\":\"Holds B.\",\"order\":2,\"paths\":[\"Sources/B/\"]}' >docs/c4/parts/s/c/b.json"
case_ c4-only-passes        0 "$append; git add -A; git commit -qm f"
case_ no-c4-passes          0 "$code; git add -A; git commit -qm f"

(( fail == 0 )) && echo "all passed"
exit $fail
