# App audit: a UI gate that must reach zero (blueprint)

The journeys click through every app and shoot each step, but a person still
has to look at the shots to see that something is wrong. The review of #233
found by hand that disabled top bar buttons looked enabled: it measured the
greys and traced them to `EditorBarLabelStyle` in
`Sources/SuiteUI/EditorTopBar.swift`, which set the icon's color and so
overrode the disabled dimming (#233 fixed it before merging). The app audit
catches faults of that kind mechanically. At every journey step it walks the
window's accessibility tree and the screen's pixels, counts violations per
check, and fails when an app's count rises past a committed baseline. When a
count falls, CI on dev lowers the baseline to it. The baseline only goes
down, and the goal is zero.

The model is an illustration factory whose audit runs 13 checks that every
figure must pass at zero. The rule carried over from it: **rules from
faults**. Every check names the PR or issue that created it, in its own code.
A check with no fault behind it doesn't get built.

## Scope

- A registry of checks, one file each, run on every window shot of every
  journey.
- A JSON report per audited screen in the `ui-screens` artifact.
- A baseline per app per check in `UITests/audit-baseline.json`: a rise fails,
  a fall is written back by CI.

**Non-goals.** Fixing the apps (each finding is a `needs-ui` issue). Dark
mode, menus in the menu bar, keyboard focus order.

## The checks

Each check is a type in `Tests/AppAuditTests/Checks/` conforming to
`AppAudit.Check`: an `id` (the baseline key), its `fault`, a `scope` (all
apps, or one), a one-line `summary`, a `seeded` screen it must flag, and
`run(_:)`. `AppAudit.checks` lists them.

| id | Fails when | Fault |
|---|---|---|
| `disabled-dim` | A disabled control keeps more than 75% of the ink of the closest enabled control of its type: same parent first, else the same row, the most similar width first (icon-only meets icon-only), then the nearest. Pairs where the enabled ink is under 1.5:1 aren't judged. | #233 review |
| `overlap` | Two enabled controls in one layer, neither inside the other, overlap by more than 2 pt both ways. | #215: the inspector's divider sat over Photo's New Image button |
| `contrast` | Static text is under 4.5:1, or under 3:1 when its frame is at least 22 pt tall. Text inside a disabled control is exempt, as in WCAG. | #62, #101, #146 |
| `identifier` | A control has no accessibility identifier. | #262: XCUITest reads SwiftUI values as "", so journeys find controls by identifier |
| `offscreen` | A control or list row lies outside the part of the window on the display (for one in a sheet, popover or menu: outside the display), with 1 pt of slack. | #263: a 1280-wide window ran off the 1024 × 768 runner; #215 |
| `unnamed` | A control has no label, title or placeholder. Controls AppKit makes for itself (window buttons, `_XCUI:` identifiers; outline disclosure triangles, `NS...`) are the system's. | review rubric, #63 |

A **control** is a button, toolbar button, checkbox, radio button, switch,
toggle, slider, stepper, stepper arrow, pop-up or menu button, combo box,
text field or view, search field, link, color well, disclosure triangle, tab
or date picker. A **list row** is a cell, outline row or table row. An
element's **visible frame** is its frame cut by every scroll view around it;
one scrolled fully out of view is skipped. A **layer** is the window or one
sheet, popover, dialog, alert, menu or drawer in it.

**Ink** (`AuditPixels.swift`) is measured in the screenshot inside the part
of the visible frame that is on the window (or the display, in a layer).
Each pixel's WCAG 2.x relative luminance; the background is the most common
8-bit luma there; ink pixels are at least 1.25:1 off it; the ink is the 90th
percentile of their contrast, which skips antialiased edges and keeps stroke
cores. Fewer than 3 ink pixels: 1:1. While a sheet, dialog or alert is up the
pixel checks skip the window behind it, which macOS dims on purpose.

## Where it runs

`Journey.shot("step")` audits every window shot as screen `<app>-<step>`
(`UITests/Audit.swift`); `journey.audit("step")` audits without a shot. A
whole-screen shot (an open menu) isn't audited. Each audit:

1. Snapshots the first window's tree in one call (`XCUIElement.snapshot()`).
2. Screenshots the main screen once two shots a quarter second apart match
   (a focus ring fading in flipped a 4.6:1 header to 4.2:1 between two runs),
   into an sRGB buffer. Frames are in screen points; the scale is pixel width
   over the screen's width in points (`NSScreen`), so a 1x runner and a 2x
   laptop both map.
3. Runs every check whose scope covers the app, attaches the report as
   `audit-<app>-<step>.json`, and adds its violations to the app's tally.

The runner is sandboxed with read-only `/`: it reads the baseline from the
repo, and the report leaves as an attachment that `scripts/ui-test` exports
into `ui-screens`. So do the counts: each app's last journey attaches its
tally as `counts-<app>`, and `scripts/ui-test` merges them into
`audit-counts.json`, `{ "<app>": { "<check>": n } }` with every check of the
app's baseline line listed, 0 included. Audit failures don't stop a journey, so one run reports
every screen. An audit costs well under a second; on the first run the
journeys took as long as without it.

The pure code (`AuditPixels.swift`, `AuditCore.swift`, `Checks/`) and its
tests are the `AppAuditTests` target in `Tests/AppAuditTests/`, Foundation
only, so Linux builds and tests them. `project.yml` compiles that folder,
minus its `*Tests.swift`, into every journey bundle. Every name nests under
`enum AppAudit`, so nothing shadows a type in a journey bundle.

## The ratchet

```json
{ "photo": { "identifier": 41, "overlap": 1 } }
```

Each app's tally holds its **distinct** violations per check. A violation is
its element's type and name, so a slider seen on twenty screens counts once
wherever the panel puts it; an element with no name is told apart by its
frame. Then:

- **Up.** When a new violation takes a check past the app's baseline, the
  audit at that screen fails, naming the check, its fault and the element.
- **Down.** A count under its baseline doesn't fail. The class's last test
  (run order is by name) attaches the app's counts in its teardown, so that
  test must launch a Journey. On dev, after a green macOS job, the `Audit
  lower` job in `.github/workflows/ci.yml` runs `scripts/audit-lower`: when
  some count is under its baseline and none is over, it writes the measured
  numbers into the baseline (a check at 0 leaves its app's line) and opens, or
  updates, one PR to dev titled "test(audit): lower baselines to the measured
  counts". The PR changes only the baseline, carries the `fast-lane` label
  and the `Fast-Check: pass` / `Head:` marker, and the lane merges it on its
  next sweep. When a later run measures nothing under, the job closes that PR.
  A red macOS job lowers nothing: a failed journey leaves its later screens
  unaudited, so its counts would be too low.
- A check missing from a listed app has baseline 0. An app missing from the
  file is recorded, not judged, and never added.

A rise fails at once, so a new fault can't land quietly. A fall needs no
one: the Linux workers can't run the journeys, so they couldn't lower the
file themselves, and before the auto-lower job every real improvement turned
dev red until someone hand-lowered it. A measurement that flickers can still
bite: a lowered count that comes back fails the next run as a rise. That is
why the limits have wide margins; the report's `samples` show how far each
measurement sits from its limit.

## Growing the audit

The audit grows with the apps. Agents:

- **add checks freely.** A new rule needs a fault (the PR or issue where it
  went wrong), one file in `Checks/`, one entry in `AppAudit.checks`, and its
  starting counts in the baseline from the first macOS run, all in one PR.
  Any starting count is fine: a check that finds bugs nobody fixed yet is
  still stricter than no check. Its `seeded` screen must fail it: `everyCheckFlagsItsSeed` runs every registered check
  on its own seed on Linux, and a check that can't fail can't land. Edge
  cases it must let pass go in `AuditChecksTests`.
- **let CI lower baselines.** A fix needn't touch the baseline: the next dev
  run measures the lower count and opens the auto-lower PR. Lowering it in
  the fix's own PR is still fine, and the lane takes it.
- **audit every journey step.** `shot` does it already; a step that doesn't
  shoot calls `audit("step")`.

Anything that loosens the audit needs the captain's review, and the fast
lane enforces it. `audit_loosens` in `scripts/fast-lane.sh` compares the
baseline, the `Checks/` files and the `AppAudit.checks` entries at the PR's
merge base and head. These loosen it:

- raising a count. A check missing from a listed app counts as 0, so giving
  an existing check a new key above 0 is a raise.
- adding an app above 0. Its counts have no anchor yet.
- dropping an app. An app missing from the file isn't judged.
- removing or moving a check file, or dropping a registry entry.

Such a PR gets one comment, "loosens the app audit: needs the captain's
review", and loses its `fast-lane` label. Lowering a count, dropping a check
key from an app (its baseline becomes 0) and adding a check stay eligible.
The auto-lower PR's author is the `github-actions` bot, which is not on the
lane's allowlist; the lane takes it (`AUDIT_BOT` in `scripts/fast-lane.sh`)
only when the baseline is its one changed file, and judges it like any
other. A
new check's keys may start at any count in apps already in the file, as long
as the same PR adds its file and its registry entry. The lane matches a key
to the new file's `let id` and refuses an id that an existing check already
uses.

## The report

```json
{ "screen": "photo-opened", "app": "photo", "scale": 1, "modal": false,
  "display": { "x": 0, "y": 0, "width": 1024, "height": 768 },
  "window": { "x": 0, "y": 31, "width": 1024, "height": 679 },
  "counts": { "identifier": 30, "overlap": 0 },
  "violations": [{ "check": "identifier", "element": "button 'Undo'",
                   "frame": { "x": 601, "y": 40, "width": 40, "height": 22 },
                   "detail": "no accessibility identifier" }],
  "samples": [{ "check": "disabled-dim", "element": "button 'Undo'",
                "measure": { "value": 2.24, "limit": 4.58 } }] }
```

## What it can't see

- **Anything outside the accessibility tree.** Marks drawn in a `Canvas` or
  shape (ruler labels, #220; keyframe marks, #62; the grid's selection ring,
  #101; canvas handles) have no element.
- **Real hit testing.** "Hittable" means enabled with a visible frame. A
  control at zero opacity, or under a view that isn't a control, passes;
  `overlap` doesn't say which control wins the click.
- **Lone disabled controls.** `disabled-dim` needs an enabled control of the
  same type beside it; an all-disabled group isn't judged. It also can't
  tell a hover highlight on the peer from its normal look.
- **Text size and backdrop.** Large text is guessed from the frame height
  (multi-line text counts as large, 14 pt bold as small). The background is
  the most common color, so text over a photo or gradient measures poorly.
  Icons and other non-text graphics (WCAG 1.4.11) aren't measured.
- **Inactive windows.** Behind a sheet nothing is measured in pixels.
- **Moving screens.** A screen that never settles (a blinking caret, Flare's
  looping preview dot) is measured on its last shot, so a text near its limit
  there can still flicker.
- **What the journeys don't visit.** Only shot screens, only the runner's
  appearance (light) and 1024 × 768 screen, only the first window.
- **Tooltips.** XCUITest doesn't expose help text, so "a disabled control
  says why" stays with the Models' `<X>ToolsTests`.
- **Values.** SwiftUI values read as empty strings (#262); no check uses them.
- **Twins.** Two controls with the same type and name (a toolbar Export and a
  sheet's Export) count as one violation per check.

## Build

Four stacked PRs, each under the lane's cap:

1. This blueprint, plus the pixel math (`AuditPixels.swift`) and its tests.
2. The engine and registry (`AuditCore.swift`) with `identifier` and
   `unnamed`, and the registry tests every later check runs under.
3. `disabled-dim`, `overlap`, `contrast` and `offscreen`, with their edge tests.
4. The tally, the XCUITest side (`UITests/Audit.swift`, `Journey.shot`), the
   `project.yml` sources, the `.json` export in `scripts/ui-test`, the
   baselines from the first full macOS run, and the docs.
