#!/usr/bin/env bash
# Tests/jobs/test_jobs.sh: fixture tests for scripts/jobs, the real-jobs data
# check and the jobs.md it renders. Covers: a good file passes and renders its
# rows, --check passes on a fresh render and fails on a stale one, --dry-run
# writes nothing; the checks that fail: a needs id that isn't a feature-map row,
# a missing field, an id whose letter isn't the app's, a key that differs from
# its id, closes_with outside needs, empty needs with no needs_note, a bad
# enum, a source that isn't a URL or "captain", a folder that isn't an app.
# Also: the repo's own jobs.json files pass. No network; needs bash, python3.
#
# Run: bash Tests/jobs/test_jobs.sh   (exit 0 = all pass)
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$here/../.."
jobs="$repo/scripts/jobs"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fail=0
ok() { echo "ok   $1"; }
bad() { echo "FAIL $1"; fail=1; }
# expect <name> <want exit> <want substring of output> <command...>
expect() {
  local name="$1" want="$2" sub="$3" got status; shift 3
  got=$("$@" 2>&1); status=$?
  if [[ "$status" == "$want" && "$got" == *"$sub"* ]]; then ok "$name"; else bad "$name (exit $status): $got"; fi
}

root="$tmp/r"
mkdir -p "$root/docs/blueprints/suite" "$root/docs/blueprints/photo"
cat >"$root/docs/blueprints/suite/feature-map.json" <<'JSON'
{"features": [{"id": "S11"}, {"id": "photo/photo-crop"}]}
JSON
good='{"$comment": "fixture",
 "RJ-P01": {"id": "RJ-P01", "app": "photo", "weight": "high", "job": "Crop for Instagram.",
  "outcome": "Output is 1080x1350 | unsquashed.", "needs": ["photo/photo-crop", "S11"], "closes_with": "S11",
  "trap": "No 4:5 chip", "run": "Cm", "baseline": "partial", "since": "2026-10-19",
  "sources": ["captain", "https://example.com/a"]},
 "RJ-P02": {"id": "RJ-P02", "app": "photo", "weight": "low", "job": "Liquify.", "outcome": "Smooth.",
  "needs": [], "needs_note": "none: not planned", "closes_with": null, "trap": "Tearing", "run": "C",
  "baseline": "fail", "since": "2026-10-19", "sources": ["https://example.com/b"]}}'
data="$root/docs/blueprints/photo/jobs.json"
md="$root/docs/blueprints/photo/jobs.md"
# with <python expr on d>: rewrite the fixture from $good with one change.
with() { python3 -c "import json,sys; d=json.loads(sys.argv[1]); $1; json.dump(d, open(sys.argv[2], 'w'))" "$good" "$data"; }

printf '%s\n' "$good" >"$data"
expect "a good file passes" 0 "jobs: OK (2 jobs)" python3 "$jobs" check --root "$root"
expect "--dry-run writes nothing" 0 "jobs: OK" python3 "$jobs" render --dry-run --root "$root"
[[ ! -e "$md" ]] && ok "--dry-run left no jobs.md" || bad "--dry-run wrote jobs.md"
expect "render writes jobs.md" 0 "jobs: OK" python3 "$jobs" render --root "$root"
grep -q '^| RJ-P01 | Crop for Instagram. → Output is 1080x1350 \\| unsquashed. | high | `photo/photo-crop`, `S11`' "$md" \
  && ok "a row escapes | and lists needs" || bad "row for RJ-P01: $(grep RJ-P01 "$md")"
grep -q '^| RJ-P02 | .* | none: not planned | – | fail |' "$md" && ok "no row: the note and no closes_with" || bad "row for RJ-P02: $(grep RJ-P02 "$md")"
grep -q 'baseline score \*\*3.8/10\*\*' "$md" && ok "baseline score (10 x 3 x 0.5 / 4)" || bad "score: $(grep score "$md")"
expect "--check passes on a fresh render" 0 "jobs: OK" python3 "$jobs" render --check --root "$root"
echo "edited" >>"$md"
expect "--check fails on a stale jobs.md" 1 "differs from its data" python3 "$jobs" render --check --root "$root"

with 'd["RJ-P01"]["needs"].append("S99")'
expect "a needs id not on the map fails" 1 "needs 'S99' is not a feature id" python3 "$jobs" check --root "$root"
with 'del d["RJ-P01"]["trap"]'
expect "a missing field fails" 1 "RJ-P01: missing trap" python3 "$jobs" check --root "$root"
with 'd["RJ-D01"] = dict(d.pop("RJ-P01"), id="RJ-D01")'
expect "an id with another app's letter fails" 1 "is not RJ-P<nn>" python3 "$jobs" check --root "$root"
with 'd["RJ-P01"]["id"] = "RJ-P09"'
expect "a key that differs from its id fails" 1 "differs from its key" python3 "$jobs" check --root "$root"
with 'd["RJ-P01"]["closes_with"] = "photo/other"'
expect "closes_with outside needs fails" 1 "closes_with 'photo/other' is not one of its needs" python3 "$jobs" check --root "$root"
with 'del d["RJ-P02"]["needs_note"]'
expect "empty needs without a note fails" 1 "say why there is none in needs_note" python3 "$jobs" check --root "$root"
with 'd["RJ-P01"]["run"] = "UI"'
expect "a bad run fails" 1 "run 'UI' is not one of C, Cm, J" python3 "$jobs" check --root "$root"
with 'd["RJ-P01"]["sources"] = ["a forum"]'
expect "a source that isn't a URL fails" 1 "is not a URL or \"captain\"" python3 "$jobs" check --root "$root"
with 'd["RJ-P01"]["outcome"] = " "'
expect "an empty outcome fails" 1 "RJ-P01: outcome is empty" python3 "$jobs" check --root "$root"
printf '%s\n' "$good" >"$data"
mkdir -p "$root/docs/blueprints/notes" && echo '{}' >"$root/docs/blueprints/notes/jobs.json"
expect "a folder that isn't an app fails" 1 "'notes' is not an app" python3 "$jobs" check --root "$root"

expect "the repo's jobs.json files pass" 0 "jobs: OK" python3 "$jobs" check

if (( fail )); then echo "test_jobs: FAIL"; exit 1; fi
echo "test_jobs: PASS"
