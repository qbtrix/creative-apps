# Priorities: most-used features first

What each app builds first, and why. The rule is simple: **build the
features people use in nearly every session first, then the weekly ones, then
the specialist ones.** An app that does its everyday loop well is worth more
than one that has half of everything.

The labels `p1`, `p2` and `p3` on issues in this repo and in
qbtrix/creative-core carry the ranking. This file explains it; the labels are
what workers read.

## The tiers

| label | tier | meaning |
|---|---|---|
| `p1` | tier 1 | Used in nearly every session, or a bug that breaks one of those workflows, or something a `p1` issue depends on ("p1 by dependency"). |
| `p2` | tier 2 | Used weekly by most users: reuse, filters, effects, export, accessibility basics. |
| `p3` | tier 3 | Specialist or occasional: interactions, assist, perf budgets, layout polish, test plumbing. |

A dependency is never ranked below the issue that needs it. When a `p1` issue
depends on tier-3 work only because of how its body is written, the fix is to
edit the issue's `Depends on` line, not to promote the tier-3 work forever.

## How the ranking was made

Clean-room. Only public sources: usage surveys, help-centre task articles,
course syllabi, shortcut cheat sheets that say "learn these first", and
community "can't live without" threads. No other app was opened or run.

No public study measures per-feature usage for any of these app categories.
The tiers are inferred from what every beginner course teaches first and what
every shortcut list repeats. Rows marked *inferred* have no direct source and
are the first candidates to move if usage data turns up. Some of the surveys
used:

- 2019 motion design survey (1,065 respondents): https://schoolofmotion.com/blog/2019-motion-design-survey
- Photo editing habits of 18-25s (2024): https://petapixel.com/2024/06/21/one-third-of-18-to-25-year-olds-edit-their-photos-for-social-media
- Photo editing software survey: https://shotkit.com/photo-editing-software-survey/
- State of design systems 2022-23: https://sympli.io/blog/state-of-design-systems-2022-2023
- UX tools survey 2022: https://designcompass.org/en/2022/12/07/ux-tools-2022-survey/

## How workers use the labels

CLAUDE.md's pick rule already reads them: take the open `gap` issue on your
line that is not `in-progress`, `p1` before `p2`, then the lowest number. Belt
mandates and crew agents follow the same order, so:

1. A line's `p1` issues form its everyday loop. Nothing `p2` starts on a line
   while one of its `p1` issues is open and unblocked.
2. If every open `p1` on a line waits on unmerged dependencies, take the
   lowest-numbered unblocked `p2`.
3. New issues get a priority label when they are filed. A bug takes the tier of
   the workflow it breaks. A refactor or test-only issue is `p3` unless a `p1`
   issue depends on it.
4. creative-core issue #211 ("dev is red") is a blocker outside the ranking.
   It comes before any feature work.

## Flare (2D vector animation)

Tier 1, nearly every session:

1. Keyframe position, scale, rotation and opacity on a timeline; retime and
   delete keys.
2. Easing presets (ease in, ease out). The curve editor is a later step.
3. Scrub, play and loop preview with Space. *Inferred.*
4. Draw rectangles and ellipses, fill and stroke, select and move on the stage,
   layers panel. Editing path anchors and handles is *inferred* and thin.
5. Open, save, undo, copy/paste/duplicate, zoom/pan. *Inferred.*

Tier 2: export (video, GIF, Lottie, SVG; once per deliverable, and the source is
vendor pages rather than usage data), symbols and instances, onion skin and
motion paths, the curve editor.

Tier 3: interactive state machines, assist, guides beyond the basics, perf
budgets.

The `p1` set is everything the three end-to-end integration tasks need: IN-1
stage and shapes (#397), IN-2 timeline, easing and playback (#385), and IN-4
files (#398). That covers draw, key, ease, play, save and open. Export (IN-7,
#374) and the issues only it needs are `p2`.

Flare's `p1` share is high (54 of 101) because about 20 of those issues are
fakes, shell and engine work the loop cannot run without. Some `p1` issues
used to depend on tier-3 work only because of how their bodies were written.
Those `Depends on` lines are now trimmed, and the blueprint rows match:

- #324 depends on #322, not #323, and #326 on #324, not #325. #323 and #325
  (machines and assist fakes) are `p3`.
- #397 no longer waits on #390 (its Direct Select journey J4 goes live with
  #390), and #357 no longer waits on #326 (the large-fixture checks run once
  #326 lands). #390 and #326 are `p2`.
- #399 (no-argument live launch) depends on #397, #385 and #398 only, so it is
  `p1`. Members whose integrate task is still open stay on their fakes, and a
  test lists them.
- creative-core#226 depends on creative-core#217, not #224, so
  creative-core#220-224 are `p3`.

## Halo (motion graphics and compositing)

Tier 1:

1. Create or pick a composition (size, fps, duration).
2. Timeline: layers, in and out points, scrub the playhead (#36).
3. Keyframe position, scale, rotation, opacity (#38, #207).
4. Preview and playback at the playhead (#37).
5. Drag a layer in the viewer to key its position. *Inferred.*
6. Undo and redo (#208), save and open (#209). *Inferred.*
7. Easing presets (#428). Same evidence as Flare.

Tier 2: render to a file (export is `p2` for Halo and Flare alike), effects
stack (#39), text layers, precompose, parenting, blend modes.

Tier 3: expressions, masks, keying, tracking, 3D layers.

`p1`: #36, #37, #38, #207, #208, #209, and easing (#428). #127 (Delete
Composition is not undoable) is closed in favour of #208, whose acceptance test
now covers undo after Delete Composition.

`p2` gaps filed: render to a movie or PNG sequence (#429, after #40) and text
layers (#430).

## Design (vector UI and graphic design)

Tier 1:

1. Zoom, pan, fit, zoom to selection.
2. Select, move, resize.
3. Draw frames and basic shapes.
4. Text: place, edit, font and size (#267, #268).
5. Properties inspector: position, size, fill, stroke, opacity, radius (#18).
   *Inferred.*
6. Layers panel: select, rename, nest, hide, lock (#45).
7. Duplicate (#414), group (#416), copy/paste (#415), align and distribute
   (#417). They act on several layers, so selecting several (#413) comes
   first.
8. Undo, redo, save and reopen (#275). *Inferred.*

Tier 2: export to PNG, SVG and PDF; components and instances (#19); shared
color variables (#20); pages.

Tier 3: variables with light and dark modes, wide-gamut color (#21), advanced
prototyping.

`p1`: #18, #45, #267, #268, #275, #413, #414, #415, #416, #417.

`p2` gap filed: export to PNG, SVG and PDF (#418).

## Photo (raster editor)

Tier 1:

1. Open, save, export with format and quality.
2. Crop, straighten, resize.
3. Tone and color: exposure, levels, curves, hue and saturation.
4. Undo, redo, zoom and pan. *Inferred.*
5. Layers: stack, opacity, adjustment layers.

Tier 2: heal and clone, selections and masks, brush and eraser (#26), history
beyond one step (#25), transform.

Tier 3: blend modes and layer styles, text, paths, print setup, specialist
controls (#231).

`p1`: #255 (Levels click-away changes the image), #419, #420. Open, save, export with
quality, crop, resize, rotate, layers, exposure, levels and hue/saturation
already exist on dev, so most of tier 1 is done. Photo's low `p1` count means
its remaining tier-1 gaps are unfiled, not that its issues were demoted.

Filed: straighten by any angle (#419, after creative-core#230) and Curves
(#420, after the SuiteUI tone curve editor #412) are `p1`; ellipse and lasso
selections with layer masks (#421) and Clone and Heal (#422, after
creative-core#232) are `p2`.

## Library (photo catalog and develop)

Tier 1:

1. Import a folder of photos (#210).
2. Browse a thumbnail grid (#33), then a loupe with arrow keys (#29).
3. Cull with keys: pick, reject, unflag, 0-5 stars, auto-advance (#211).
4. Basic develop: exposure, white balance, contrast, highlights, shadows.
5. Export a JPEG at a set size.
6. The catalog persists between launches (#212). *Inferred.*
7. Crop and straighten. *Inferred.*

Tier 2: filter by flag or rating, collections (#31); metadata panel (#30);
copy and paste develop settings; compare views.

Tier 3: keywords, smart collections, local masks, denoise.

`p1`: #29, #32, #33, #210, #211, #212, plus the filed gaps: render develop
settings to pixels (#423, after creative-core#231), export JPEG at a set size
(#424), crop and straighten (#425, after creative-core#230) and auto-advance
after a rating or flag (#426). The develop sliders (#32) are `p1` again now
that #423 turns them into pixels.

`p2` gap filed: camera raw files (#427, pending evidence).

## SuiteUI

SuiteUI has no users of its own. Its issues take the rank of the app work that
needs them: tokens (#329), snapshots (#331, #332), journeys (#333), inspector
rows (#334-#338), status bar (#340), timeline slot (#342), curve editor (#343),
canvas surface (#6), the timeline keyframe bugs (#62, #63) and Photo's tone
curve editor (#412) are `p1` by dependency. #215 (the window overflows at its minimum width) is a `p1` bug on
every app. Contrast and keyboard access fixes are `p2`. Density polish (#221),
the node graph (#344), frame probes (#330) and test plumbing are `p3`.

## creative-core

Engine issues take the rank of the app issue that needs them; most sit under
Flare. The suite tasks for the asset model, command catalog and command journal
(#148-#154) serve no tier-1 workflow, so they are `p3`. CoreRaster gaps filed
for the apps: rotate by any angle (#230, Photo straighten and Library crop)
and white balance, contrast, highlights and shadows (#231, Library develop)
are `p1` by dependency; clone and heal (#232, Photo) is `p2`. #22 is an ops probe and
is not ranked.
