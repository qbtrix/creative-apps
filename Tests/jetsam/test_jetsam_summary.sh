#!/usr/bin/env bash
# Tests/jetsam/test_jetsam_summary.sh: fixture test for scripts/jetsam-summary.
# A JetsamEvent report shaped like macOS writes it (a JSON header line, then
# the body) must name the largest process, list the killed ones with their
# reason, and rank the top five by rpages × pageSize in MB. A report with no
# pageSize falls back to 16 KB pages, and a file that isn't a report exits 2.
# Needs bash and python3.
#
# Run: bash Tests/jetsam/test_jetsam_summary.sh   (exit 0 = all pass)
set -uo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }

cat >"$tmp/JetsamEvent-2026-10-15-152900.ips" <<'IPS'
{"bug_type":"298","timestamp":"2026-10-15 15:29:00.00 +0000","os_version":"macOS 26.5","incident_id":"X"}
{
  "build" : "macOS 26.5",
  "largestProcess" : "AppSnapshotTests",
  "memoryStatus" : { "pageSize" : 16384, "compressorSize" : 100000 },
  "processes" : [
    { "name" : "swift-test", "pid" : 900, "rpages" : 6400 },
    { "name" : "AppSnapshotTests", "pid" : 901, "rpages" : 262144, "reason" : "vm-pageshortage" },
    { "name" : "Runner.Worker", "pid" : 300, "rpages" : 12800, "reason" : "vm-pageshortage" },
    { "name" : "WindowServer", "pid" : 150, "rpages" : 19200 },
    { "name" : "kernel_task", "pid" : 0, "rpages" : 32000 },
    { "name" : "mds_stores", "pid" : 200, "rpages" : 640 }
  ]
}
IPS

out=$(python3 "$root/scripts/jetsam-summary" "$tmp/JetsamEvent-2026-10-15-152900.ips"); status=$?
check "a report exits 0" '[[ $status -eq 0 ]]'
check "it names the largest process" '[[ "$out" == *"largest process: AppSnapshotTests"* ]]'
check "it lists both killed processes with their reason" \
  '[[ "$out" == *"killed: 2"* && "$out" == *"AppSnapshotTests (pid 901): 4096 MB, vm-pageshortage"* && "$out" == *"Runner.Worker (pid 300): 200 MB, vm-pageshortage"* ]]'
top=$(printf '%s\n' "$out" | sed -n '/^top 5/,$p' | sed -n 's/^  \([^ ]*\) .*/\1/p' | tr '\n' ' ')
check "it ranks the top five by resident memory" '[[ "$top" == "AppSnapshotTests kernel_task WindowServer Runner.Worker swift-test " ]]'

printf '%s\n' '{"bug_type":"298"}' '{"processes":[{"name":"a","pid":1,"rpages":64}]}' >"$tmp/nopage.ips"
out=$(python3 "$root/scripts/jetsam-summary" "$tmp/nopage.ips")
check "no pageSize means 16 KB pages, and the largest is the biggest" '[[ "$out" == *"largest process: a"* && "$out" == *"a (pid 1): 1 MB"* ]]'

echo "not a report" >"$tmp/junk.ips"
python3 "$root/scripts/jetsam-summary" "$tmp/junk.ips" >/dev/null 2>&1; status=$?
check "a file that isn't a report exits 2" '[[ $status -eq 2 ]]'

exit $fail
