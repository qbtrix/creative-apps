#!/usr/bin/env bash
# Tests/contact_sheet/test_contact_sheet.sh: fixture test for
# scripts/contact-sheet. A fake ui-screens folder (two empty step PNGs, one
# audit report, an xcresult manifest listing newest first, as the real one
# does), a baseline and a perf report go in; the page must list both steps in
# capture order, show and escape the violation,
# count distinct violations the way AppAudit.Tally does (one ↑, one ↓, one =),
# skip audit-counts.json, inline the perf line, and write the step summary. A
# run on dev with only ↓ notes the auto-lower commit. A last run without the
# manifest falls back to name order. No network; needs bash and jq.
#
# Run: bash Tests/contact_sheet/test_contact_sheet.sh   (exit 0 = all pass)
set -uo pipefail
# CI sets these; the fixture sets its own, and must not write the job's summary.
unset GITHUB_REPOSITORY GITHUB_SERVER_URL GITHUB_STEP_SUMMARY GITHUB_RUN_ID GITHUB_SHA GITHUB_REF_NAME
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fail=0

s="$tmp/screens"
mkdir -p "$s" "$tmp/snaps"
: >"$s/photo-launch.png"
: >"$s/photo-opened.png"
# Two hits on one named button (one distinct) and one nameless button (keyed
# by its frame, truncated toward zero like Swift's Int()).
cat >"$s/audit-photo-opened.json" <<'JSON'
{ "screen": "photo-opened", "app": "photo", "counts": { "identifier": 2, "overlap": 0, "unnamed": 1 },
  "violations": [
    { "check": "identifier", "element": "button 'Undo <all>'", "frame": { "x": 1, "y": 2, "width": 3, "height": 4 }, "detail": "no accessibility identifier" },
    { "check": "identifier", "element": "button 'Undo <all>'", "frame": { "x": 9, "y": 2, "width": 3, "height": 4 }, "detail": "no accessibility identifier" },
    { "check": "identifier", "element": "button ''", "frame": { "x": -1.5, "y": 2, "width": 3, "height": 4 }, "detail": "no accessibility identifier" },
    { "check": "unnamed", "element": "button ''", "frame": { "x": -1.5, "y": 2, "width": 3, "height": 4 }, "detail": "no label, title or placeholder" } ] }
JSON
# scripts/ui-test's merged counts: not a screen report, so the sheet skips it.
echo '{ "photo": { "identifier": 2 } }' >"$s/audit-counts.json"
cat >"$s/manifest.json" <<'JSON'
[ { "testIdentifier": "PhotoJourneyTests/testOpenImage()", "attachments": [
      { "exportedFileName": "c.png", "suggestedHumanReadableName": "photo-launch_1_4E5F.png", "timestamp": 20.5 },
      { "exportedFileName": "b.json", "suggestedHumanReadableName": "audit-photo-opened_0_3D.json", "timestamp": 10.5 },
      { "exportedFileName": "a.png", "suggestedHumanReadableName": "photo-opened_0_0A1B-2C.png", "timestamp": 10 } ] } ]
JSON
echo '{ "photo": { "identifier": 2, "overlap": 1 } }' >"$tmp/baseline.json"
echo 'BRUSH-LATENCY config=debug drag p50 0.6 p95 2.3 | budget p50 drag <= 3.0' >"$tmp/snaps/photo-brush-latency.txt"

# has <name> <file> <fixed string>
has() {
  if grep -qF -- "$3" "$2"; then echo "ok   $1"; else echo "FAIL $1: no '$3' in ${2##*/}"; fail=1; fi
}

GITHUB_STEP_SUMMARY="$tmp/summary.md" GITHUB_RUN_ID=42 GITHUB_SHA=0123456789abcdef GITHUB_REF_NAME=feat/x GITHUB_REPOSITORY=o/r \
  "$here/../../scripts/contact-sheet" "$s" "$tmp/baseline.json" "$tmp/snaps" >/dev/null || { echo "FAIL script exited $?"; exit 1; }
page="$s/contact-sheet.html"
has "first step, relative image" "$page" '<a href="photo-opened.png"><img src="photo-opened.png"'
has "second step" "$page" '<img src="photo-launch.png"'
has "steps in timestamp order (the manifest lists newest first)" "$page" '<h3>PhotoJourneyTests/testOpenImage()</h3><div class="grid"><figure class="flag"><a href="photo-opened.png">'
has "violation shown" "$page" '<li><b>identifier</b> button '
has "violation escaped" "$page" 'Undo &lt;all&gt;'  # the quotes become &apos; or &#39; by jq version
has "violation summary" "$page" '4 violations: identifier 3, unnamed 1'
has "unaudited step" "$page" 'launch</span> <span class="muted">not audited'
has "header" "$page" 'branch <code>feat/x</code> · run <a href="https://github.com/o/r/actions/runs/42">42</a>'
has "distinct count on the baseline" "$page" '<td class="same"><b>2</b> = 2</td>'
has "under the baseline" "$page" '<td class="down"><b>0</b> ↓ 1</td>'
has "over the baseline" "$page" '<td class="up"><b>1</b> ↑ 0</td>'
has "perf report inlined" "$page" '<th>BRUSH-LATENCY</th><td>photo-brush-latency.txt</td><td>config=debug drag p50 0.6 p95 2.3<br>budget p50 drag &lt;= 3.0'
has "summary reminder" "$tmp/summary.md" 'Download **ui-screens** → open `contact-sheet.html`'
has "summary row" "$tmp/summary.md" '| photo | 2 | 1 | 2 = 2 | 0 ↓ 1 | 1 ↑ 0 |'
# hasnt <name> <file> <fixed string>
hasnt() {
  if grep -qF -- "$3" "$2"; then echo "FAIL $1: '$3' in ${2##*/}"; fail=1; else echo "ok   $1"; fi
}
hasnt "no auto-lower note off dev, or with a count over" "$page" 'Audit lower job'

# On dev, two counts under the baseline and none over: the note, on the page and in the summary.
echo '{ "photo": { "identifier": 3, "overlap": 1, "unnamed": 1 } }' >"$tmp/baseline.json"
GITHUB_STEP_SUMMARY="$tmp/summary-dev.md" GITHUB_REF_NAME=dev \
  "$here/../../scripts/contact-sheet" "$s" "$tmp/baseline.json" "$tmp/snaps" >/dev/null || { echo "FAIL dev run exited $?"; exit 1; }
has "auto-lower note on the page" "$page" '<p class="note">↓ only: once this macOS job is green, the Audit lower job pushes the lower baseline to dev as “test(audit): lower baselines to the measured counts”'
has "auto-lower note in the summary" "$tmp/summary-dev.md" '↓ only: once this macOS job is green, the Audit lower job pushes the lower baseline'
has "dev cells" "$tmp/summary-dev.md" '| photo | 2 | 1 | 2 ↓ 3 | 0 ↓ 1 | 1 = 1 |'

rm "$s/manifest.json"
"$here/../../scripts/contact-sheet" "$s" "$tmp/baseline.json" "$tmp/nowhere" >/dev/null || { echo "FAIL rerun exited $?"; exit 1; }
has "no manifest: name order" "$page" 'Steps, by name (no manifest.json from scripts/ui-test)</h3><div class="grid"><figure><a href="photo-launch.png">'
has "no perf reports" "$page" 'None reported.'

exit $fail
