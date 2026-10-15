#!/usr/bin/env bash
# Tests/generated/test_generated.sh: fixture tests for the two generators whose
# output only the dev workflow commits (.github/workflows/generated.yml):
# scripts/c4-assemble (docs/c4/model.json from docs/c4/parts/) and scripts/waves
# (each app's features/waves.md from its *.wave.json data). Covers: split then
# assemble reproduces a model byte for byte, sibling order, --check on a stale
# model, the part problems that fail (bad JSON, missing order, id/name mismatch,
# duplicate id, unknown relationship end); waves rendering, --check, --dry-run,
# and the checks (same-wave clash, a prefix clash, a dependency in the same
# wave, a missing field, a bad status). Also: the real repo's parts assemble to
# a model with the same components. No network; needs bash and python3.
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
feature seam '{"title": "The seam", "wave": "0a", "status": "built", "feature_issue": "#1", "covers": "#10", "waits_on": "nothing", "owned": ["Sources/AppModel/Seam/"], "cells": {"tier": "p1"}}'
feature edit '{"title": "Edit | cut", "wave": 1, "order": 20, "status": "planned", "feature_issue": "file when ready", "covers": "#11", "waits_on": "seam", "depends": ["seam"], "owned": ["Sources/AppModel/Edit.swift"]}'
feature draw '{"title": "Draw", "wave": 1, "order": 10, "status": "building", "feature_issue": "#3", "covers": "#12", "waits_on": "seam", "depends": ["seam"], "owned": ["Sources/AppModel/Draw.swift"]}'
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
feature draw '{"title": "Draw", "wave": 1, "order": 10, "status": "built", "feature_issue": "#3", "covers": "#12", "waits_on": "seam", "depends": ["seam"], "owned": ["Sources/AppModel/Draw.swift"]}'
expect "render --check fails when a lead marked its feature built" 1 "differs from its data" python3 "$waves" --root "$w" render --check
feature draw '{"title": "Draw", "wave": 1, "status": "built", "feature_issue": "#3", "covers": "#12", "waits_on": "seam", "owned": ["Sources/AppModel/Edit.swift"]}'
expect "two features in one wave owning a file fail" 1 "wave 1: draw and edit both own Sources/AppModel/Edit.swift" python3 "$waves" --root "$w" check
feature draw '{"title": "Draw", "wave": 1, "status": "built", "feature_issue": "#3", "covers": "#12", "waits_on": "seam", "owned": ["Sources/AppModel/"]}'
expect "a folder owning another's file in one wave fails" 1 "both own Sources/AppModel/ / Sources/AppModel/Edit.swift" python3 "$waves" --root "$w" check
feature draw '{"title": "Draw", "wave": 1, "status": "built", "feature_issue": "#3", "covers": "#12", "waits_on": "edit", "depends": ["edit"]}'
expect "a dependency in the same wave fails" 1 "must be in an earlier wave" python3 "$waves" --root "$w" check
feature draw '{"title": "Draw", "wave": 1, "status": "done", "feature_issue": "#3", "covers": "#12", "waits_on": "seam"}'
expect "an unknown status fails" 1 '"status" must be one of' python3 "$waves" --root "$w" check
feature draw '{"wave": 1, "status": "built", "feature_issue": "#3", "covers": "#12", "waits_on": "seam"}'
expect "a missing title fails" 1 'needs a text "title"' python3 "$waves" --root "$w" render --dry-run

if [[ $fail -ne 0 ]]; then echo "generated: FAIL"; exit 1; fi
echo "generated: all pass"
