#!/usr/bin/env bash
# Tests/roadmap_numbers/test_roadmap_numbers.sh: fixture test for
# scripts/roadmap-numbers. A small beta-progress JSON fills the table between
# the markers with its counts and date, text outside the markers stays
# byte-identical, a second run changes nothing, and a file without the end
# marker exits 1 untouched. Needs bash and python3.
#
# Run: bash Tests/roadmap_numbers/test_roadmap_numbers.sh   (exit 0 = all pass)
set -uo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
run() { python3 "$root/scripts/roadmap-numbers" "$tmp/p.json" "$1" 2026-01-02; }

cat >"$tmp/p.json" <<'JSON'
{"groups": {"flare": {"features": 19, "done": 12, "slices": 51, "slices_done": 36},
            "core": {"features": 23, "done": 22, "slices": 79, "slices_done": 77}},
 "total": {"features": 42, "done": 34, "slices": 130, "slices_done": 113},
 "apps": {"eta": "2026-01-09"}}
JSON
printf '# Head\n\n<!-- numbers:start -->\nold table\n<!-- numbers:end -->\n\nTail line.\n' >"$tmp/r.md"
cp "$tmp/r.md" "$tmp/orig.md"

run "$tmp/r.md"
check "exits 0 with both markers" "[ \$? -eq 0 ]"
check "flare row carries its counts" "grep -q '^| Flare | .* | 12 / 19 | 36 / 51 |\$' '$tmp/r.md'"
check "a group missing from the JSON reads 0 / 0" "grep -q '^| Halo | .* | 0 / 0 | 0 / 0 |\$' '$tmp/r.md'"
check "total row and date" "grep -q '34 / 42' '$tmp/r.md' && grep -q 'measured on 2026-01-02' '$tmp/r.md' && grep -q 'around 2026-01-09' '$tmp/r.md'"
check "old table is gone" "! grep -q 'old table' '$tmp/r.md'"
check "text outside the markers is unchanged" "[ \"\$(sed '/numbers:start/,/numbers:end/d' '$tmp/r.md')\" = \"\$(sed '/numbers:start/,/numbers:end/d' '$tmp/orig.md')\" ]"
cp "$tmp/r.md" "$tmp/once.md"; run "$tmp/r.md"
check "a second run changes nothing" "cmp -s '$tmp/r.md' '$tmp/once.md'"

printf '# Head\n<!-- numbers:start -->\nold\n' >"$tmp/bad.md"; cp "$tmp/bad.md" "$tmp/bad0.md"
run "$tmp/bad.md" 2>/dev/null
check "a missing end marker exits 1" "[ \$? -eq 1 ]"
check "and leaves the file alone" "cmp -s '$tmp/bad.md' '$tmp/bad0.md'"

exit $fail
