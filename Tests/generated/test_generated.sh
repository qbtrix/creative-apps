#!/usr/bin/env bash
# Tests/generated/test_generated.sh: fixture tests for the two generators whose
# output only the dev workflow commits (.github/workflows/generated.yml):
# scripts/c4-assemble (docs/c4/model.json from docs/c4/parts/) and scripts/waves
# (each app's features/waves.md from its *.wave.json data). Covers: split then
# assemble reproduces a model byte for byte, sibling order, --check on a stale
# model, the part problems that fail (bad JSON, missing order, id/name mismatch,
# duplicate id, unknown relationship end); waves rendering, --check, --dry-run,
# and the checks (same-wave clash, a prefix clash, a dependency in the same
# wave, a missing field, a bad status, no owned or journeys, a journey without
# its class, an owned generated file, the C4 owner opt-in) and the slice checks (a file handed over
# across a contract-slice wait, two slices that can run at once owning a file,
# unknown waits, slice size, a task in two slices, journeys, owned in step,
# cycles, a "ui" flag that isn't a boolean). Also: the real repo's parts assemble, and
# the Generated workflow's guards on a scratch git repo: c4-assemble --absorb keeps
# a part edit, folds a direct model.json edit into the parts, and refuses a part
# changed both ways; waves render --guard regenerates after a data edit and leaves
# a direct waves.md edit, naming its commit. No network; needs bash, git, python3.
#
# Run: bash Tests/generated/test_generated.sh   (exit 0 = all pass)
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$here/../.."
asm="$repo/scripts/c4-assemble"
waves="$repo/scripts/waves"
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

# --- c4-assemble -------------------------------------------------------------
c4="$tmp/c4"
mkdir -p "$c4/docs/c4"
cat >"$c4/docs/c4/model.json" <<'JSON'
{
  "version": "1.0",
  "scope": "fixture",
  "model": {
    "people": [],
    "systems": [
      {
        "id": "zeta",
        "name": "Zeta – é",
        "containers": [
          {
            "id": "z-app",
            "name": "App",
            "components": [
              {
                "id": "z-app-b",
                "paths": [
                  "Sources/B/"
                ]
              },
              {
                "id": "z-app-a",
                "paths": [
                  "Sources/A/"
                ]
              }
            ]
          },
          {
            "id": "a-lib",
            "name": "Lib",
            "components": []
          }
        ]
      },
      {
        "id": "alpha",
        "name": "Alpha",
        "containers": []
      }
    ],
    "relationships": [
      {
        "source": "z-app",
        "target": "a-lib"
      },
      {
        "source": "z-app-a",
        "target": "alpha"
      }
    ]
  }
}
JSON
cp "$c4/docs/c4/model.json" "$tmp/want.json"
python3 "$asm" --root "$c4" --split
python3 "$asm" --root "$c4" --out "$tmp/got.json"
if cmp -s "$tmp/want.json" "$tmp/got.json"; then ok "split then assemble is byte for byte (order kept, not sorted by id)"
else bad "split then assemble differs: $(diff "$tmp/want.json" "$tmp/got.json" | head -5)"; fi
[[ -f "$c4/docs/c4/parts/zeta/z-app/z-app-a.json" && -f "$c4/docs/c4/parts/zeta/system.json" ]] \
  && ok "split writes one file per component and per system" || bad "split layout"
expect "check passes on a current model" 0 "matches its parts" python3 "$asm" --root "$c4" --check
python3 - "$c4/docs/c4/parts/zeta/z-app/z-app-a.json" <<'PY'
import sys
p = sys.argv[1]
text = open(p).read().replace('"Sources/A/"', '"Sources/A2/"')
open(p, "w").write(text)
PY
expect "check fails on a stale model" 1 "differs from docs/c4/parts/" python3 "$asm" --root "$c4" --check
python3 "$asm" --root "$c4"
grep -q '"Sources/A2/"' "$c4/docs/c4/model.json" && ok "assemble writes the edited part" || bad "assemble did not write"
mkdir -p "$c4/docs/c4/parts/zeta/z-app"
printf '{"id": "z-app-c", "order": 5, "paths": ["Sources/C/"]}\n' >"$c4/docs/c4/parts/zeta/z-app/z-app-c.json"
python3 "$asm" --root "$c4" --out "$tmp/new.json"
first=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["model"]["systems"][0]["containers"][0]["components"][0]["id"])' "$tmp/new.json")
[[ "$first" == "z-app-c" ]] && ok "a new component part lands by its order" || bad "new part order: $first"
printf '{"id": "z-app-c", "paths": []}\n' >"$c4/docs/c4/parts/zeta/z-app/z-app-c.json"
expect "a part without order fails" 1 'needs an integer "order"' python3 "$asm" --root "$c4" --out "$tmp/x.json"
printf '{"id": "other", "order": 1}\n' >"$c4/docs/c4/parts/zeta/z-app/z-app-c.json"
expect "an id that differs from its file name fails" 1 "must match its name" python3 "$asm" --root "$c4" --out "$tmp/x.json"
printf '{"id": "z-app-c", "order": 1,' >"$c4/docs/c4/parts/zeta/z-app/z-app-c.json"
expect "bad JSON fails" 1 "not valid JSON" python3 "$asm" --root "$c4" --out "$tmp/x.json"
printf '{"id": "z-app-c", "order": 1, "relationships": [{"source": "z-app-c", "target": "nowhere"}]}\n' >"$c4/docs/c4/parts/zeta/z-app/z-app-c.json"
expect "an unknown relationship end fails" 1 "unknown target 'nowhere'" python3 "$asm" --root "$c4" --out "$tmp/x.json"
mkdir -p "$c4/docs/c4/parts/alpha/z-app"
printf '{"id": "z-app", "order": 1}\n' >"$c4/docs/c4/parts/alpha/z-app/container.json"
rm "$c4/docs/c4/parts/zeta/z-app/z-app-c.json"
expect "a duplicate id fails" 1 "id 'z-app' is used twice" python3 "$asm" --root "$c4" --out "$tmp/x.json"

# The repo's own parts: they assemble, and to the same components as model.json
# (equal when dev's generated workflow has run; a PR may only add or change parts).
if python3 "$asm" --root "$repo" --out "$tmp/repo.json" >/dev/null; then ok "the repo's docs/c4/parts/ assemble"
else bad "the repo's docs/c4/parts/ do not assemble: $(python3 "$asm" --root "$repo" --out "$tmp/repo.json")"; fi

# --- waves -------------------------------------------------------------------
w="$tmp/w"
mkdir -p "$w/docs/blueprints/app/features"
cat >"$w/docs/blueprints/app/waves.in.md" <<'MD'
# App features: waves

Prose stays as written.

<!-- waves-table: wave | feature | packet | covers | waits on | tier | feature issue | status -->

More prose.
MD
feature() { printf '%s\n' "$2" >"$w/docs/blueprints/app/features/$1.wave.json"; }
feature seam '{"title": "The seam", "wave": "0a", "status": "built", "feature_issue": "#1", "covers": "#10", "waits_on": "nothing", "owned": ["Sources/AppModel/Seam/"], "cells": {"tier": "p1"}, "journeys": ["AppJourneyTests.testSeam"]}'
feature edit '{"title": "Edit | cut", "wave": 1, "order": 20, "status": "planned", "feature_issue": "file when ready", "covers": "#11", "waits_on": "seam", "depends": ["seam"], "owned": ["Sources/AppModel/Edit.swift"], "journeys": ["AppJourneyTests.testEdit"]}'
feature draw '{"title": "Draw", "wave": 1, "order": 10, "status": "building", "feature_issue": "#3", "covers": "#12", "waits_on": "seam", "depends": ["seam"], "owned": ["Sources/AppModel/Draw.swift"], "journeys": ["AppJourneyTests.testDraw"]}'
: >"$w/docs/blueprints/app/features/seam.md"
: >"$w/docs/blueprints/app/features/draw.md"
expect "waves check passes" 0 "waves: OK" python3 "$waves" --root "$w" check
expect "render --dry-run writes nothing" 0 "waves: OK" python3 "$waves" --root "$w" render --dry-run
[[ ! -f "$w/docs/blueprints/app/features/waves.md" ]] && ok "dry run left no waves.md" || bad "dry run wrote waves.md"
python3 "$waves" --root "$w" render >/dev/null
want='| wave | feature | packet | covers | waits on | tier | feature issue | status |
|---|---|---|---|---|---|---|---|
| 0a | The seam | `seam.md` | #10 | nothing | p1 | #1 | built |
| 1 | Draw | `draw.md` | #12 | seam | – | #3 | building |
| 1 | Edit \| cut | no packet yet | #11 | seam | – | file when ready | planned |'
got=$(grep '^|' "$w/docs/blueprints/app/features/waves.md")
[[ "$got" == "$want" ]] && ok "render prints the table by wave, then order" || bad "render table: $got"
head -1 "$w/docs/blueprints/app/features/waves.md" | grep -q "Generated by scripts/waves" && ok "waves.md says it is generated" || bad "no notice"
grep -q "^More prose.$" "$w/docs/blueprints/app/features/waves.md" && ok "prose around the marker stays" || bad "prose lost"
expect "render --check passes when current" 0 "waves: OK" python3 "$waves" --root "$w" render --check
feature draw '{"title": "Draw", "wave": 1, "order": 10, "status": "built", "feature_issue": "#3", "covers": "#12", "waits_on": "seam", "depends": ["seam"], "owned": ["Sources/AppModel/Draw.swift"], "journeys": ["AppJourneyTests.testDraw"]}'
expect "render --check fails when a lead marked its feature built" 1 "differs from its data" python3 "$waves" --root "$w" render --check
feature draw '{"title": "Draw", "wave": 1, "status": "built", "feature_issue": "#3", "covers": "#12", "waits_on": "seam", "owned": ["Sources/AppModel/Edit.swift"], "journeys": ["AppJourneyTests.testDraw"]}'
expect "two features in one wave owning a file fail" 1 "wave 1: draw and edit both own Sources/AppModel/Edit.swift" python3 "$waves" --root "$w" check
feature draw '{"title": "Draw", "wave": 1, "status": "built", "feature_issue": "#3", "covers": "#12", "waits_on": "seam", "owned": ["Sources/AppModel/"], "journeys": ["AppJourneyTests.testDraw"]}'
expect "a folder owning another's file in one wave fails" 1 "both own Sources/AppModel/ / Sources/AppModel/Edit.swift" python3 "$waves" --root "$w" check
feature draw '{"title": "Draw", "wave": 1, "status": "built", "feature_issue": "#3", "covers": "#12", "waits_on": "edit", "depends": ["edit"], "owned": ["Sources/AppModel/Draw.swift"], "journeys": ["AppJourneyTests.testDraw"]}'
expect "a dependency in the same wave fails" 1 "must be in an earlier wave" python3 "$waves" --root "$w" check
feature draw '{"title": "Draw", "wave": 1, "status": "done", "feature_issue": "#3", "covers": "#12", "waits_on": "seam", "owned": ["Sources/AppModel/Draw.swift"], "journeys": ["AppJourneyTests.testDraw"]}'
expect "an unknown status fails" 1 '"status" must be one of' python3 "$waves" --root "$w" check
feature draw '{"wave": 1, "status": "built", "feature_issue": "#3", "covers": "#12", "waits_on": "seam"}'
expect "a missing title fails" 1 'needs a text "title"' python3 "$waves" --root "$w" render --dry-run
: >"$w/docs/blueprints/app/features/draw.md"
feature draw '{"title": "Draw", "wave": 1, "status": "built", "feature_issue": "#3", "covers": "#12", "waits_on": "seam", "journeys": ["AppJourneyTests.testDraw"]}'
expect "a feature without owned fails, naming it and its packet" 1 'draw: needs "owned", the files and globs its packet docs/blueprints/app/features/draw.md owns' python3 "$waves" --root "$w" check
feature draw '{"title": "Draw", "wave": 1, "status": "built", "feature_issue": "#3", "covers": "#12", "waits_on": "seam", "owned": ["Sources/AppModel/Draw.swift"]}'
expect "a feature without journeys fails" 1 'draw: needs "journeys", a list of "<Class>.<testMethod>" XCUITests from its packet' python3 "$waves" --root "$w" check
feature draw '{"title": "Draw", "wave": 1, "status": "built", "feature_issue": "#3", "covers": "#12", "waits_on": "seam", "owned": ["Sources/AppModel/Draw.swift"], "journeys": ["testDraw"]}'
expect "a journey without its class fails" 1 'draw: needs "journeys", a list of "<Class>.<testMethod>"' python3 "$waves" --root "$w" check
feature draw '{"title": "Draw", "wave": 1, "status": "built", "feature_issue": "#3", "covers": "#12", "waits_on": "seam", "owned": ["Sources/AppModel/Draw.swift"], "journeys": []}'
expect "empty journeys without a reason fail" 1 'draw: "journeys" is empty' python3 "$waves" --root "$w" check
feature draw '{"title": "Draw", "wave": 1, "status": "built", "feature_issue": "#3", "covers": "#12", "waits_on": "seam", "owned": ["Sources/AppModel/Draw.swift"], "journeys": [], "journeys_none": "Model only"}'
expect "empty journeys with journeys_none pass" 0 "waves: OK" python3 "$waves" --root "$w" check
rm "$w/docs/blueprints/app/features/draw.md"
feature draw '{"title": "Draw", "wave": 1, "status": "built", "feature_issue": "#3", "covers": "#12", "waits_on": "seam", "journeys": ["AppJourneyTests.testDraw"]}'
expect "a feature with no packet points at the blueprint" 1 "its blueprint's waves section (no packet yet)" python3 "$waves" --root "$w" check
feature draw '{"title": "Draw", "wave": 1, "status": "built", "feature_issue": "#3", "covers": "#12", "waits_on": "seam", "owned": ["docs/c4/model.json"], "journeys": ["AppJourneyTests.testDraw"]}'
expect "owning a generated file fails" 1 "draw: owns the generated docs/c4/model.json" python3 "$waves" --root "$w" check
feature draw '{"title": "Draw", "wave": 1, "status": "built", "feature_issue": "#3", "covers": "#12", "waits_on": "seam", "owned": ["Sources/AppModel/Draw.swift", "Sources/AppApp/Other.swift"], "journeys": ["AppJourneyTests.testDraw"]}'
printf '%s\n' '{"owned_files_planned": true, "model": {"systems": [{"containers": [{"components": [{"id": "m", "paths": ["Sources/AppModel"]}, {"id": "s", "paths": ["Sources/AppModel/Seam*"]}]}]}]}}' >"$w/docs/blueprints/app/c4-planned.json"
expect "with owned_files_planned, an owned file needs one planned owner (folder or glob)" 1 "draw: Sources/AppApp/Other.swift has 0 owners" python3 "$waves" --root "$w" check
feature draw '{"title": "Draw", "wave": 1, "status": "built", "feature_issue": "#3", "covers": "#12", "waits_on": "seam", "owned": ["Sources/AppModel/Draw.swift"], "journeys": ["AppJourneyTests.testDraw"]}'
expect "a folder entry without its slash owns the files under it" 0 "waves: OK" python3 "$waves" --root "$w" check
rm "$w/docs/blueprints/app/c4-planned.json"

# Slices: a contract-first app. "ui" waits on win's contract slice W-a for its view
# tasks, so it may take over a file W-a created; "model" waits on nothing in win.
s="$tmp/s"
mkdir -p "$s/docs/blueprints/app/features"
cp "$w/docs/blueprints/app/waves.in.md" "$s/docs/blueprints/app/"
sfeature() { printf '%s\n' "$2" >"$s/docs/blueprints/app/features/$1.wave.json"; }
base='"status": "planned", "feature_issue": "later", "covers": "-", "waits_on": "-", "journeys": ["AppJourneyTests.testSlot"]'
sfeature win '{"title": "Window", "wave": "0b", '"$base"', "owned": ["A/Slot.swift", "A/Win.swift"], "slices": [
  {"id": "W-a", "behavior": "The slot shows.", "tasks": ["W-1", "W-2"], "journeys": ["J1"], "owned": ["A/Slot.swift", "A/Win.swift"]},
  {"id": "W-b", "behavior": "The window finishes.", "tasks": ["W-3", "W-4"], "journeys": ["J2"], "owned": ["A/Win.swift"], "waits": {"W-a": ["W-3"]}}]}'
sfeature ui '{"title": "UI", "wave": 1, '"$base"', "owned": ["M/Ui.swift", "A/Slot.swift"], "slices": [
  {"id": "U-a", "behavior": "The slot fills.", "tasks": ["U-1", "U-2"], "journeys": ["J3"], "owned": ["M/Ui.swift", "A/Slot.swift"], "waits": {"win:W-a": ["U-2"]}}]}'
expect "slices: a file handed over across a contract-slice wait passes" 0 "waves: OK" python3 "$waves" --root "$s" check
sfeature ui '{"title": "UI", "wave": 1, '"$base"', "owned": ["M/Ui.swift", "A/Win.swift"], "slices": [
  {"id": "U-a", "behavior": "The slot fills.", "tasks": ["U-1", "U-2"], "journeys": ["J3"], "owned": ["M/Ui.swift", "A/Win.swift"], "waits": {"win:W-a": ["U-2"]}}]}'
expect "slices: two slices that can run at once owning a file fail" 1 "win:W-b and ui:U-a can run at once and both own A/Win.swift" python3 "$waves" --root "$s" check
sfeature ui '{"title": "UI", "wave": 1, '"$base"', "owned": ["M/Ui.swift"], "slices": [
  {"id": "U-a", "behavior": "The slot fills.", "tasks": ["U-1", "U-2"], "journeys": ["J3"], "owned": ["M/Ui.swift"], "waits": {"win:W-z": ["U-2"]}}]}'
expect "slices: a wait on an unknown slice fails" 1 "ui:U-a waits on unknown win:W-z" python3 "$waves" --root "$s" check
sfeature ui '{"title": "UI", "wave": 1, '"$base"', "owned": ["M/Ui.swift"], "slices": [
  {"id": "U-a", "behavior": "The slot fills.", "tasks": ["U-1", "U-2"], "journeys": ["J3"], "owned": ["M/Ui.swift"], "waits": {"win:W-a": ["U-9"]}}]}'
expect "slices: a wait naming a task outside the slice fails" 1 'must list tasks of this slice' python3 "$waves" --root "$s" check
sfeature ui '{"title": "UI", "wave": 1, '"$base"', "owned": ["M/Ui.swift"], "slices": [
  {"id": "U-a", "behavior": "Too big.", "tasks": ["U-1", "U-2", "U-3", "U-4", "U-5", "U-6"], "journeys": ["J3"], "owned": ["M/Ui.swift"]},
  {"id": "U-b", "behavior": "Repeats a task.", "tasks": ["U-1", "U-7"], "journeys": ["J4"], "owned": ["M/Ui.swift"], "waits": {"U-a": ["U-7"]}}]}'
expect "slices: a slice of six tasks fails" 1 '"tasks" must list 2 to 5 task ids' python3 "$waves" --root "$s" check
expect "slices: a task in two slices fails" 1 'task U-1 is in two slices' python3 "$waves" --root "$s" check
sfeature ui '{"title": "UI", "wave": 1, '"$base"', "owned": ["M/Ui.swift", "M/Other.swift"], "slices": [
  {"id": "U-a", "behavior": "The slot fills.", "tasks": ["U-1", "U-2"], "journeys": [], "owned": ["M/Ui.swift"]}]}'
expect "slices: a slice with no journey fails" 1 '"journeys" must be a non-empty list' python3 "$waves" --root "$s" check
expect "slices: owned that differs from the slices' owned fails" 1 "only in the feature: ['M/Other.swift']" python3 "$waves" --root "$s" check
sfeature ui '{"title": "UI", "wave": 1, '"$base"', "owned": ["M/Ui.swift"], "slices": [
  {"id": "U-a", "behavior": "One.", "tasks": ["U-1", "U-2"], "journeys": ["J3"], "owned": ["M/Ui.swift"], "waits": {"U-b": ["U-1"]}},
  {"id": "U-b", "behavior": "Two.", "tasks": ["U-3", "U-4"], "journeys": ["J4"], "owned": ["M/Ui.swift"], "waits": {"U-a": ["U-3"]}}]}'
expect "slices: waits that go round fail" 1 "cycle through ui" python3 "$waves" --root "$s" check
sfeature ui '{"title": "UI", "wave": 1, '"$base"', "owned": ["M/Ui.swift"], "slices": [
  {"id": "U-a", "behavior": "The slot fills.", "tasks": ["U-1", "U-2"], "journeys": ["J3"], "owned": ["M/Ui.swift"], "ui": true}]}'
expect "slices: a UI slice marked \"ui\": true passes" 0 "waves: OK" python3 "$waves" --root "$s" check
sfeature ui '{"title": "UI", "wave": 1, '"$base"', "owned": ["M/Ui.swift"], "slices": [
  {"id": "U-a", "behavior": "The slot fills.", "tasks": ["U-1", "U-2"], "journeys": ["J3"], "owned": ["M/Ui.swift"], "ui": "yes"}]}'
expect "slices: a \"ui\" that isn't a boolean fails" 1 'ui:U-a: "ui" must be true or false' python3 "$waves" --root "$s" check

# --- the Generated workflow's guards (git history) ----------------------------
# A scratch repo with scripts/ copied in; commit <msg> commits everything.
g="$tmp/g"
mkdir -p "$g/scripts" "$g/docs/c4"
cp "$asm" "$waves" "$g/scripts/"
commit() { git -C "$g" add -A && git -C "$g" -c user.name=t -c user.email=t@t commit -q -m "$1"; }
git -C "$g" init -q
cp "$tmp/want.json" "$g/docs/c4/model.json"
python3 "$g/scripts/c4-assemble" --split
mkdir -p "$g/docs/blueprints/app/features"
cp "$w/docs/blueprints/app/waves.in.md" "$g/docs/blueprints/app/"
feature() { printf '%s\n' "$2" >"$g/docs/blueprints/app/features/$1.wave.json"; }
feature seam '{"title": "The seam", "wave": 1, "status": "planned", "feature_issue": "#1", "covers": "#10", "waits_on": "nothing", "owned": ["Sources/AppModel/Seam.swift"], "journeys": ["AppJourneyTests.testSeam"]}'
feature draw '{"title": "Draw", "wave": 2, "status": "planned", "feature_issue": "#3", "covers": "#12", "waits_on": "seam", "owned": ["Sources/AppModel/Draw.swift"], "journeys": ["AppJourneyTests.testDraw"]}'
python3 "$g/scripts/waves" render >/dev/null
commit "consistent base"
edit() {  # edit <file> <python expression on the parsed JSON d>
  python3 - "$1" "$2" <<'PY'
import json, sys
p, expr = sys.argv[1], sys.argv[2]
d = json.load(open(p))
exec(expr)
open(p, "w").write(json.dumps(d, indent=2, ensure_ascii=False) + "\n")
PY
}
P="$g/docs/c4/parts/zeta/z-app"
# A normal PR: a part edited, model.json untouched (stale). Absorb keeps the part.
edit "$P/z-app-a.json" 'd["paths"] = ["Sources/A3/"]'
commit "part edit"
expect "absorb keeps a part edit when model.json was not edited" 0 "no direct edits" python3 "$g/scripts/c4-assemble" --absorb
grep -q '"Sources/A3/"' "$g/docs/c4/model.json" && ok "absorb then writes model.json from the edited part" || bad "part edit lost"
commit "generated"
# A direct model.json edit plus a different part edit: both land.
edit "$g/docs/c4/model.json" 'd["model"]["systems"][0]["containers"][0]["components"][0]["paths"] = ["Sources/B9/"]; d["model"]["systems"][0]["containers"][0]["components"].append({"id": "z-app-new", "paths": ["Sources/N/"]})'
edit "$P/z-app-a.json" 'd["paths"] = ["Sources/A4/"]'
commit "direct model.json edit and a part edit"
expect "absorb folds a direct model.json edit into the parts" 0 "z-app-b.json written" python3 "$g/scripts/c4-assemble" --absorb
grep -q '"Sources/B9/"' "$P/z-app-b.json" && [[ -f "$P/z-app-new.json" ]] && ok "the direct edits became parts (an edited one and a new one)" || bad "direct edit not in parts"
grep -q '"Sources/B9/"' "$g/docs/c4/model.json" && grep -q '"Sources/A4/"' "$g/docs/c4/model.json" && grep -q '"z-app-new"' "$g/docs/c4/model.json" \
  && ok "model.json keeps both the direct edit and the part edit" || bad "absorb lost an edit"
expect "after absorb, model.json matches its parts" 0 "matches its parts" python3 "$g/scripts/c4-assemble" --root "$g" --check
commit "generated"
# The same part changed both ways: exit 2, nothing written.
edit "$g/docs/c4/model.json" 'd["model"]["systems"][0]["containers"][0]["components"][0]["paths"] = ["Sources/X/"]'
edit "$P/z-app-b.json" 'd["paths"] = ["Sources/Y/"]'
commit "conflict"
cp "$P/z-app-b.json" "$tmp/before.json"
expect "a part changed in its file and in model.json is a conflict" 2 "zeta/z-app/z-app-b.json changed both" python3 "$g/scripts/c4-assemble" --absorb
cmp -s "$P/z-app-b.json" "$tmp/before.json" && grep -q '"Sources/X/"' "$g/docs/c4/model.json" && ok "a conflict writes nothing" || bad "conflict wrote"
# waves: a data edit regenerates; a direct waves.md edit is left and named.
WM="$g/docs/blueprints/app/features/waves.md"
feature draw '{"title": "Draw", "wave": 2, "status": "built", "feature_issue": "#3", "covers": "#12", "waits_on": "seam", "owned": ["Sources/AppModel/Draw.swift"], "journeys": ["AppJourneyTests.testDraw"]}'
commit "lead marks draw built"
expect "guard regenerates a waves.md after a data edit" 0 "waves: OK" python3 "$g/scripts/waves" render --guard
grep -q '| Draw | .* | built |' "$WM" && ok "the data edit reached waves.md" || bad "waves.md not regenerated"
commit "generated"
printf 'Hand note.\n' >>"$WM"
feature seam '{"title": "The seam", "wave": 1, "status": "built", "feature_issue": "#1", "covers": "#10", "waits_on": "nothing", "owned": ["Sources/AppModel/Seam.swift"], "journeys": ["AppJourneyTests.testSeam"]}'
commit "direct waves.md edit"
expect "guard leaves a direct waves.md edit and names its commit" 2 "edited directly by $(git -C "$g" rev-parse --short=7 HEAD) (direct waves.md edit); left as is" \
  python3 "$g/scripts/waves" render --guard
tail -1 "$WM" | grep -q "^Hand note.$" && ok "the direct edit is still there" || bad "guard overwrote a direct edit"

if [[ $fail -ne 0 ]]; then echo "generated: FAIL"; exit 1; fi
echo "generated: all pass"
