# Render budgets

What each app's most-used interactions cost its real window. The harness is
`Tests/AppSnapshotTests/RenderBudgetHarness.swift`. It hosts the app's window
view on a fixture off screen and paces every step at 120 Hz. A step's time is
the event's work plus the layout and display it forced.

Budgets ratchet. A body budget is exactly what `dev` measured (Design's is the
design-window DW-b bound of 3, Halo's viewer drag the 3 of
`HaloWindowLiveDragTests`). A step-time budget sits a little above it, so the
suite is green today and fails on a regression. When a fix lowers a number,
lower its budget in the same PR. Never raise one. The target is where the row
has to end up.

- **Window bodies** come from a debug-only `bodyRuns` counter in the app's window
  file. The count is deterministic, so `RenderBudget<App>Tests/bodies` runs in
  the merge gate. Every suite that reads one of these process-global counters
  nests in `BodyCountSuites`, which is `.serialized`, so two of them never run
  at once and count each other's renders. A new counter-reading suite nests
  there too, and its `perf-suites.txt` line reads
  `AppSnapshotTests.BodyCountSuites/<Suite>`.
- **Step p95** is wall time, so `RenderBudget<App>Tests/timing` is listed in
  `Tests/perf-suites.txt`. It runs in the report-only Perf step, one test at a
  time. The numbers below come from a debug build on an M2 Pro (max of
  3 runs). A release build is faster. Halo's were re-measured on `dev` with
  #1471 (no scrub ticks) and #1517 (live drag) in, at machine load 20 (a run at
  load ~70 gave up to 3x these); the other apps' times are the earlier ones.
- **Accessibility is on** in every run, because the harness finds controls by
  identifier. A Mac running any accessibility client pays that cost too:
  VoiceOver, a window manager, a password manager.

| App | Interaction | Bodies dev / budget / target | Step p95 dev / budget / target | Fix that should bring it to target |
|---|---|---|---|---|
| Halo | select a layer (click Ball's row) | 1 / 1 / 1 | 108 / 130 / 33 ms | was 1018 ms; #1471 removed the scrub rows' per-step accessibility ticks. Left: the selection's layout passes |
| Halo | drag the inspector divider, 120 samples, Ball selected | 0 / 0 / 0 | 97 / 130 / 8.3 ms | was 1057 ms (same fix). Still ~70 ms median per step; its SuiteWindow min-size change is the candidate for the rest, not measured yet |
| Halo | play 1 s at 120 Hz (24 fps), `HaloWindowPlaybackTests` | 24 / 24 (spec 12-30) / 24 | 17.0 / 27 / 8.3 ms | #1517 skips the lanes and rows a frame leaves unchanged (0 lanes, at most 96 rows per second, both asserted); the step time is mostly the window's own 24 bodies |
| Halo | drag Floor in the viewer, 120 samples | 2 / 3 / 3 | 2.9 / 4 / 8.3 ms | none: at the `haloViewerTakesActivationClicks` bound (3); could tighten to 2 |
| Design | drag a shape on `crowd`, 120 samples | 3 / 3 / 3 | 4.1 / 6 / 8.3 ms | none in flight; at design-window DW-b's bound |
| Design | marquee select on `crowd`, 120 samples | 3 / 3 / 3 | 2.7 / 4 / 8.3 ms | none in flight; at DW-b's bound |
| Library | scroll the grid, 120 steps of 12 pt (`samples`) | 0 / 0 / 0 | 6.6 / 10 / 8.3 ms | none in flight |
| Library | select, 10 clicks on grid cells | 10 / 10 / 10 | 80 / 120 / 33 ms | none in flight |
| Library | loupe step | not driven | not driven | the loupe's arrow keys need a key window, which a test process can't have |
| Flare | step the easing X1 scrub row 60 times | 60 / 60 / 60 | 13.0 / 20 / 8.3 ms | #1471 removed the per-step ticks; not re-measured on a quiet machine yet, so the time budget is unchanged |
| Flare | drag on the canvas, 120 samples | 0 / 0 / 0 | 0.08 / 1 / 8.3 ms | none: the canvas has no gesture yet, so this row bounds the shell alone |
| Photo | brush stroke, 120 samples (`large`), `PhotoWindowStrokeTests` | 0 / 1 / 1 | 7.1 / 11 / 8.3 ms | none in flight; the body bound is the stroke's existing one (`PhotoWindowStrokeTests`, measured 0) |

Bodies for Flare's scrub row and Library's selection count one per edit: each
step changes the model once. Their target is that count, not 3. Halo's
playback bound comes from #1296: at least `fps / 2` and at most `fps + 6`.

## What the harness can't drive

The test process is never the active app. Every press it sends is a
window-activation click, and a SwiftUI gesture ignores those unless it opts in
with `allowsWindowActivationEvents`. Two kinds of view handle them anyway:
SwiftUI's canvases (CanvasViewport) and AppKit controls (lists, split views).
Inspector scrub rows don't. (Halo's viewer does when the window is hosted with `haloViewerTakesActivationClicks`, which `RenderBudgetHaloTests` does.) So Flare's scrub row steps
through its accessibility slider, the way VoiceOver and XCUI adjust it, not
through a drag.

NSSplitView tracks a divider drag in a modal loop that a test can't pace, so
the divider moves through `setPosition(_:ofDividerAt:)`, which is what that
loop calls. A wheel event made in a test carries no phase, so the grid scrolls
its clip view directly.
