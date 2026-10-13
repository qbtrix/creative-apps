# Review rubric

Apply this to every PR: the author before opening it, the reviewer after.
Every question is yes or no. A "no" blocks the merge unless the PR body
explains it. The rules behind each question are in `docs/engineering.md` and
`docs/design.md`.

## 1. Coherence: does it fit the design?

- [ ] The PR stays on one line: one app's targets, or SuiteUI, never two?
- [ ] State and logic live in the Model; views only read it and call its
      methods, and `scripts/ci` printed no app-state failure?
- [ ] The Model is Linux-safe (Foundation only, value types, `Sendable`)?
- [ ] Engine work goes through creative-core (and its commands for document
      edits), not a copy inside the Model?
- [ ] Names match the ones already used for the same idea?
- [ ] New files are owned by a C4 component: each new `Sources/` file is in
      exactly one component's `paths` in `docs/c4/model.json`, and that
      component's description still says what it holds?
- [ ] If the line's core loop (open or create, see, edit with each shown tool,
      undo, save) doesn't work end to end yet, does this PR build a missing
      step of it rather than polish or a panel (CLAUDE.md, Journeys first)?

## 2. Duplication: does it reuse what exists?

- [ ] The view is built from SuiteUI, and a missing component became a
      `needs-ui` issue plus a plain placeholder, not a private copy?
- [ ] `scripts/ci` printed no jscpd failure, and the threshold was not raised?
- [ ] No near-copy (same logic, renamed) of code in another app or in SuiteUI?

## 3. Correctness: can it crash or lose work?

- [ ] No crash-prone construct, unchecked index or division by a possible zero?
- [ ] A throwing call is handled, or a comment says why it cannot fail?
- [ ] Document edits are undoable?

## 4. Design: does it follow the HIG rules in docs/design.md?

- [ ] Glass only on controls that float over content; content surfaces flat;
      no glass on glass?
- [ ] Uses the system component when one exists (docs/design.md, Component
      order), and SuiteUI before anything custom?
- [ ] No hand-rolled look-alike of a system control or a SuiteUI component,
      and `scripts/ci` printed no design lint failure?
- [ ] Semantic colors and text styles from SuiteUI tokens; no hard-coded
      color for a system role?
- [ ] Every icon-only control has a tooltip and an accessibility label?
- [ ] Every button, tool and menu item the PR shows does something, or is
      disabled with a tooltip saying why (`unavailableHelp`), and the line's
      `<X>ToolsTests` passes?
- [ ] The new action is reachable from the menu bar or a shortcut, not only a
      toolbar button (or the PR says why not yet)?
- [ ] Both Light and Dark snapshots look right?

## 5. Proof: would we notice a regression?

- [ ] Each Model test asserts a concrete result that would fail if the code
      returned a default value?
- [ ] A bug fix comes with a test that failed before the fix?
- [ ] New visible state has a snapshot, and the PR body lists the PNGs it
      changed?
- [ ] A user-facing feature adds or extends its app's journey test in
      `UITests/<X>JourneyTests*.swift`, and the PR body lists the `ui-screens`
      PNGs that show it?
- [ ] Both CI jobs (`Linux`, `macOS`) are green on the rebased branch?

## 6. Quality: does it feel right, measured?

For every PR that adds or changes an interactive feature: something a person
drags, types into, clicks, plays, opens or exports. Each question names the
test that answers it. The ids (QB-…) are used by app blueprints such as
`docs/blueprints/flare.md`, whose coverage matrix gives every feature its row.

- [ ] The feature's row in its app blueprint names a latency budget, a
      fidelity check and a feel check from the tables below, and this PR adds
      or extends the test that measures each one?
- [ ] Latency: the perf journey passes on the macOS CI job against the gate
      written in `UITests/Journey+Budgets.swift` (a constant, not a recorded
      baseline that can drift), or the row is still report-only and the PR
      says so?
- [ ] Fidelity: every new visible state has a golden image compared with a
      tolerance, not only a PNG uploaded for eyes?
- [ ] Curves are drawn as curves: no path is flattened into line segments
      for drawing, and the fidelity test proves it?
- [ ] Feel: every control the PR shows reacts on press (hover, pressed or
      dragging state) and changes something, or is disabled with a reason
      (`<X>ToolsTests` and the every-control journey pass)?
- [ ] One gesture is one undo step with a named action, and the journey
      asserts the Edit menu title after it?
- [ ] Keyboard parity: every value the pointer can change can also be
      changed from the keyboard, and the journey does it once?
- [ ] Error, empty and loading states the feature can reach each have a
      journey step or a golden?
- [ ] Reduce Motion and Increase Contrast are covered for any new animated
      or tinted state (goldens for the look, probe marks for the motion)?
- [ ] No budget, tolerance or ratio was loosened in this PR, or the PR body
      says why and the captain approved it?

### Where the tests live

| Harness | Home | What it measures |
|---|---|---|
| Frame probe | `Sources/SuiteUI/FrameProbe.swift`; journeys read it with `perf()` from `UITests/Journey+Input.swift` and attach it as `perf-<test>.json` | For each pointer or key event, how many display refreshes pass between the event's timestamp and the refresh whose frame first shows it (**frames late**); dropped frames and tick jitter during playback; and in-app marks: a drag preview drawn before mouse-up, a progress state first shown after its command, an animation's measured duration, autosave done, a state switch. Exposed as the `suite.perf` accessibility value only when the app runs with its perf flag |
| Model budget | `Tests/<X>ModelTests/Budget.swift` (Linux and macOS) and creative-core `Tests/FlareCoreTests/FlareBudgetTests.swift` | Wall time of a model call over N runs on a fixed reference document, median and p95 |
| Golden image | `Tests/AppSnapshotTests/GoldenImage.swift` and `SnapshotHost.swift`; baselines in `Tests/AppSnapshotTests/Golden/`, found with `#filePath` | Per-pixel difference against a committed PNG rendered at backing scale 2 in the named appearance (Light, Dark, and each with Increase Contrast), with a channel tolerance and a maximum share of differing pixels |

Why frames late and not milliseconds: the probe's own end point is a display
refresh, so a millisecond figure already includes up to one refresh of
waiting, which differs at 60 Hz and 120 Hz. Counting refreshes is fair on
both.

Goldens are recorded on the macOS CI runner, never on a laptop, because a
different GPU and display give different anti-aliasing. A mismatch (or a
missing baseline) always writes the actual image and a diff image into
`.build/snapshots/`, which CI already uploads as the `snapshots` artifact;
the agent copies the new baseline from there into the PR and lists it. There
is no record switch on CI. When the hosted runner image changes its font
rendering, expect many goldens to move at once: that is one re-record PR
listing every changed baseline, reviewed by eye. The tolerance does not
loosen for it.

Perf journeys run on the release bundles that `scripts/bundle-apps` builds
(the same ones `scripts/ui-test` runs), so their numbers are release
numbers. Model budgets run under `swift test` in debug, which is why their
CI gates carry a factor of 10 over the device target.

### How gates are set

A new perf row ships **report-only**: the test asserts only that it
collected enough samples, and attaches its JSON. After ten green CI runs the
gate is set to the measured CI p95 times 1.5, never tighter than the device
target, and written as a constant in `UITests/Journey+Budgets.swift`, with
this table updated in the same PR. A gate never loosens without the captain.
The CI gates below marked "set from CI" are placeholders until then.

### Latency

| id | Interaction | Device target | CI gate | Test |
|---|---|---|---|---|
| QB-L1 | Drag on the canvas: move a shape, draw a shape, drag a pen handle, pan | p95 ≤ 2 frames late | set from CI (placeholder 3) | P1, one series per interaction, each with at least 60 samples |
| QB-L2 | Drag an inspector bar slider or a curve handle | p95 ≤ 2 frames late | set from CI (placeholder 3) | P2 |
| QB-L3 | Drag the playhead or a key on the timeline | p95 ≤ 2 frames late | set from CI (placeholder 3) | P3 |
| QB-L4 | Play at the document rate for 5 s | 0 dropped frames, tick jitter p95 < 2 ms | at most 2 dropped frames in 5 s (an absolute count, so one stall on a shared machine does not fail it alone) | P4 |
| QB-L5 | Hit test per pointer move, 1,000 shapes | ≤ 1 ms | ≤ 10 ms debug | `StageBudgetTests`, `FlareBudgetTests` |
| QB-L6 | Draw list for one frame, reference scene | ≤ 2 ms | ≤ 20 ms debug | `StageBudgetTests`, `FlareBudgetTests` |
| QB-L7 | One drag step through the command engine (perform and validate) | ≤ 1 ms | ≤ 10 ms debug | `StageBudgetTests`, `FlareBudgetTests` |
| QB-L8 | Export: SVG frame, Lottie of 300 frames, 48 PNG frames at 1080p | < 0.1 s, < 1 s, < 5 s | < 1 s, < 10 s, < 10 s | export budget tests; the export journey's timing |
| QB-L9 | Any action that waits (open, export, assist) shows a progress state | ≤ 100 ms after the command, by the probe's mark | set from CI (placeholder 200 ms) | the probe mark in the journey's JSON, never an XCUI query |
| QB-L10 | Scroll the timeline and layer list of a 300-layer, 5,000-key document | p95 frame interval ≤ 1.5 refreshes | set from CI | P6; model half: building 300 timeline rows ≤ 5 ms (debug ≤ 50 ms) |
| QB-L11 | Play 500 animated nested instances at 30 fps | 0 dropped frames | set from CI | P5; model half: one frame's draw list ≤ 4 ms (debug ≤ 40 ms) |
| QB-L12 | Open a large document (decode up to 64 MB) | the main thread never stalls longer than 2 refreshes | set from CI | P7 |

### Visual fidelity

| id | Check | Test |
|---|---|---|
| QB-V1 | Curves stay curves: rectangles with corner radius, ellipses and pen curves reach the drawing layer as cubic segments; each FlareCore `cubic` maps to exactly one `addCurve` | Linux: draw list element kinds; macOS: `StagePathTests` element for element |
| QB-V2 | Anti-aliased edges: the stage golden at 2x matches within channel tolerance 2/255 and at most 0.5% differing pixels; a diagonal edge has partial-coverage pixels | `GoldenImage` on the stage goldens, edge coverage assertion |
| QB-V3 | Retina sharpness: the stage and marks render at the backing scale; a 1 pt hairline is exactly 2 device pixels at 2x; handles sit on the pixel grid | `SnapshotHost` at scale 2, hairline column test |
| QB-V4 | What you see is what you export: the PNG export of a frame equals the stage golden of that frame within QB-V2's tolerance; converting to a symbol changes no pixel | `RasterizerTests`; the convert render diff |
| QB-V5 | Every component state has a golden: rest, hover, focus, pressed or dragging, editing, disabled, and each state color it can show. SuiteUI components in Light, Dark, Light + Increase Contrast and Dark + Increase Contrast; editor screens in Dark and Dark + Increase Contrast; `SuiteWindow` app screens in all four. One contact sheet per component per appearance, so a component PR stays inside the 15-file cap | `GoldenImage` through `SnapshotHost` |
| QB-V6 | Contrast: every text and state color meets 4.5:1 and every non-text mark 3:1 against every background it is drawn on, including the slider's value and drag fills, in all four appearances | `TokensTests.contrast` over the full table in `docs/design.md` |

### Feel

| id | Check | Test |
|---|---|---|
| QB-F1 | No dead controls: every enabled control changes state; every other one is disabled with a reason | `<X>ToolsTests`; the every-control journey |
| QB-F2 | Immediate feedback: a drag shows a live preview before mouse-up; a refusal or failure shows where it happened; a mode (recording, onion, preview data) shows its color and symbol | the probe's "preview before mouse-up" mark (a journey cannot screenshot mid-drag); journey asserts for messages; goldens for modes |
| QB-F3 | One gesture, one named undo step; scrubbing and playback are not undo steps | the journey reads the Edit menu after the gesture; Model tests count undo entries |
| QB-F4 | Keyboard parity: arrows step, Shift coarse, Option fine, Return types, Escape cancels; every tool has a one-key shortcut | journey steps on one bar slider and on the tool rail |
| QB-F5 | Reduce Motion: state changes do not animate; Increase Contrast: outlines appear | probe mark: measured animation duration is 0 under Reduce Motion; goldens for Increase Contrast |
| QB-F6 | Geometry holds: row, button, radius and type sizes match the tokens, so a slide back to framework defaults fails | `TokensTests.geometry` plus the component goldens |
