# Engineering rules

What good code looks like in creative-apps (CLAUDE.md covers picking work and
shipping it). Read this before you write code; check your diff against
`docs/review-rubric.md` before you open a PR. Look and behavior rules for views
are in `docs/design.md`. Before any SwiftUI work, read
`docs/engineering/swiftui-rules.md`: what makes a view slow or feel dead, with
a wrong and a right line for each rule.

Each rule names what enforces it. **Gate** means `scripts/ci` fails when the
rule is broken. **Compiler** means the build fails. **Test** names the test
that catches it. **Review-only** means nothing catches it yet, so the reviewer
must. When a review-only rule is broken twice, turn it into a check or a test
instead of repeating it here.

## Layers

Each app has three layers. Each depends only on the ones below it.

1. **creative-core** (another repo): the engines. FlareCore (animation
   document, commands, timeline, export), CoreColor (color spaces), CoreRaster
   (pixel buffers, compositing, image operations). Pure Swift, Linux-safe.
   Pinned to one commit (`revision:` in `Package.swift`, recorded in the
   committed `Package.resolved`), so a core merge can't reach the apps
   unchecked: `scripts/bump-core` moves the pin through a PR that names the
   core range and its PRs, after every Model test target and the brush perf
   suites pass on it, and the supervisor merges it once the macOS job is
   green. Gate: `scripts/ci` builds only from the committed `Package.resolved`
   and fails when it disagrees with `Package.swift`.
2. **`<X>Model`**: the app's state and logic: what is open, what is selected,
   which tool is active, and every operation a view can ask for. It calls
   creative-core to do the real work. Linux-safe, so it is where tests live.
3. **`<X>App`**: SwiftUI views and the `App` scene, built from **SuiteUI**.
   Views read the Model and call its methods. Nothing else.

A canvas draws by `docs/render-contract.md`: one GPU route to the screen, no
CPU pixel work or readback per step, no canvas-sized SwiftUI offscreen pass.

Every Model also links the **kernel tier**, `SuiteKernel`
(`Sources/SuiteKernel/`, packet
`docs/blueprints/suiteui/features/editor-kernel.md`): one Linux-safe library
with one module per editor concept the apps used to build on their own.
It imports Foundation and FlareCore only, never an app Model, SuiteModel or
SuiteUI, and `SuiteKernelTests` covers it on Linux.

| Folder | What it holds |
|---|---|
| `History/` | `History<Payload>`: named undo steps, coalescing runs, a drag as one step, step ids that never repeat, dirty as saved-vs-current |
| `Selection/` | `Selection<ID>` with a primary and an anchor, one `Pick`; the `Nudge` and `Marquee` rules |
| `Layers/` | `LayerTree<Payload>`: nesting, order, hide and lock cascades, moves into a parent; `LayerFollow`'s follow link (parenting) |
| `Keys/` | `KeyRules` on sorted key tracks of FlareCore's `Keyframe`; `EasePreset` and `EaseCurve` |
| `Transform/` | `BoxMath` (resize by a handle, several boxes as one) and `HandleHit` |
| `Snap/` | `Snapping`: the candidates and the order of offsets. The `SnapLines` and `SnapGaps` engines are stubs that the snapping feature fills |
| `Export/` | `ExportRun<Options>`: idle, editing, running, finished or failed |
| `Session/` | `DocumentSession` (dirty, save status, autosave, recovery) and `VersionedJSON` |
| `Stroke/` | `StrokeSmoother`, `DabSpacer`, `BrushSettings`, `BrushPreset`, `LiveCopy` |
| `Commands/` | `CommandSpec`, `CommandCatalog` (list, describe, run, batch), `ParamSchema`, `JSONValue` and `HeadlessDocument`: the command layer below |

**The command layer.** Every action an app offers is a command in its
catalog (packet `docs/blueprints/suiteui/features/command-catalog.md`). A
`CommandSpec` has a stable id (`edit.copy`), typed params with a
JSON schema, a kind (query, view, edit, file), a description written for
people and for models, and an availability that says why not when it can't
run. An `edit` run records exactly one undo step. Each Model's
`<X>Headless.swift` conforms its document to `HeadlessDocument` and lists its
catalog, so the `afterglow` CLI, the MCP server and the crews' tests open,
edit, undo, save and export a document with no window. Menus and buttons run
the same specs: SuiteUI's `MenuCommand(spec, on:)` takes its title from the
spec, is enabled when the spec is available, and shows the spec's summary as
help, or "Title: why" when disabled. Gate: `CommandPathTests` fails when an
app builds a menu item or toolbar button without a spec and the site isn't in
that app's baseline in `Tests/command-path-baseline/`, which only shrinks.

SuiteUI sits beside the apps. It knows nothing about any app Model, and it
links SuiteKernel only to draw the kernel's values: `LayerTreeList` (the one
layers panel), `SelectionHandles`, `SnapGuideMarks`, `SuiteExportSheet`,
`SuiteStrokePacer`, `SuitePointerPressure`, `BrushCursorMark` and `ToolKeys`,
all shown on the gallery's `editor-kernel` page, and `MenuCommand(spec, on:)`,
which builds a menu item from a command spec (the gallery's `command-catalog`
page).

- **State lives in the Model; views are dumb.** A view holds its Model in one
  `@State private var model` at the window root and passes values and closures
  down. It never assigns Model state, never binds to it (`$model`), and never
  mutates a collection inside it. Gate: the app-state rule in `scripts/ci`.
  Compiler: Model stored state is `public private(set)`.
- **A view may own presentation state only.** Whether a popover is open, hover,
  focus, scroll position: `@State` in the view is fine. Anything that changes
  the document, the selection or the tool belongs in the Model. Review-only.
- **Logic goes down a layer.** A computation in a view (formatting a duration,
  clamping a value, deciding what is enabled) moves to the Model, where Linux
  tests cover it. Arithmetic that can fail (division, indexing) never lives in
  a view. Review-only.
- **Models call creative-core; they don't copy it.** If the engine lacks
  something, file `needs-core` on creative-core (CLAUDE.md) and keep going;
  the merged core feature arrives with the next bump PR.
  Document edits go through the engine's commands (FlareCore's `Command` and
  `CommandEngine`), so undo works. Review-only.
- **Models adapt onto the kernel; they don't copy it.** A Model that needs
  undo, selection, a layer tree, keys and easing, box math, snapping, an
  export run, a document session or a stroke uses SuiteKernel's module and
  converts its own types in an adapter file named `<X>+Kernel.swift` (or
  `<X>Adapter.swift`), such as `FlareLayers+Kernel.swift` or
  `DesignSession+Kernel.swift`. It never keeps its own copy. A missing kernel
  behaviour is a `gap` issue on `line:suiteui`. The `adopt-kernel-*` features
  (undo, selection, layers, easing, transform, export, session, brush) move
  the apps' remaining copies onto the kernel and delete them. Gate:
  `scripts/check-dup-logic` in `scripts/ci` fails on a new app file whose
  name or first type names a kernel concept, unless it is an adapter
  (docs/factory/lead.md rule 20).
- **Models are Linux-safe.** Foundation only, through the FoundationEssentials
  import pattern; value types, `Sendable`, Swift 6 mode. Gate: the Linux CI
  job builds every Model.
- **Views use SuiteUI.** Window shell, toolbars, palettes, sidebar rows, cards,
  empty states, spacing, type and color come from SuiteUI. Plain `Text`,
  `Image` and stacks are fine for content. A missing component is a
  `needs-ui` issue plus a plain placeholder, never a private copy in an app.
  Gate: the design lint in `scripts/ci` (raw colors, fonts and sizes,
  hand-made glass, look-alike controls; docs/design.md, Component order), and
  jscpd catches the copies.

## Reuse before you write

- **Search first.** Before you write a view or a helper, grep `Sources/SuiteUI`
  and your Model. Before you write engine-like code in a Model, grep
  creative-core.
- **Shared view code goes to SuiteUI.** Five apps with the same window means
  the same code five times unless it lives in one place. `SuiteWindow` is the
  shell; apps pass in content. Gate: the jscpd check in `scripts/ci` fails when
  duplicated lines in `Sources/` pass its threshold, which only goes down.
- **Subtract first.** If a change can delete code, delete it in the same PR.
  Review-only.

## Errors and crashes

- **Never crash on input.** No `try!`, `as!`, `fatalError(`, `precondition(`,
  force-unwrapped `.first!`/`.last!`. Gate: the no-crash lint.
- **Models throw typed errors** (the engine's, or one error enum per Model when
  it needs its own). A view that calls a throwing method shows the failure or
  handles a case that cannot fail with a comment saying why. Review-only.

## Snapshots (the eye-bridge)

- **Every main content view has snapshots.** `Tests/AppSnapshotTests` renders
  each app's content view at 1440x900 in Light and Dark, empty and with a
  document open, plus a SuiteUI gallery, to `.build/snapshots/`. CI uploads
  them as the `snapshots` artifact.
- **New visible state, new snapshot.** When a change shows something no
  snapshot shows yet, add a case. Name files `<app>-<state>-<light|dark>.png`.
- **Snapshots render SwiftUI only.** `ImageRenderer` skips AppKit-backed chrome
  (split view, toolbar, inspector, lists), so keep the interesting pixels in
  the content view. It also drops glass views entirely, content and all, so
  the snapshot tests set `suiteSnapshotRendering` and SuiteUI draws glass as a
  flat bordered stand-in. Judge real glass on a Mac.
- **Glass goes through `suiteGlass(in:)`.** SuiteUI applies Liquid Glass only
  through that modifier (`Glass.swift`), never `.glassEffect` directly, or the
  control disappears from every snapshot. Apps never apply glass at all.
  Review-only.
- **The PR names the PNGs it changed.** Review-only.

## Human-like UI tests

Snapshots show a content view. The UI tests show the real app: each one
launches an app's window, clicks through it the way a person would, and
screenshots the whole window, chrome and system controls included, after
every step.

- **Where they live.** `UITests/<X>JourneyTests.swift`, one file per app, plus
  the shared steps in `UITests/Journey.swift`. They are XCUITest bundles, which
  SwiftPM cannot host, so `project.yml` describes them and XcodeGen generates
  `CreativeApps.xcodeproj` on demand. Never commit or hand-edit the project.
  The apps themselves stay SwiftPM targets: the tests launch the bundles that
  `scripts/bundle-apps` writes to `.build/apps`.
- **How they run.** `scripts/ui-test` builds the bundles, generates the
  project, runs the `Journeys` scheme and exports every screenshot to
  `.build/ui-screens/<app>-<step>.png`. The `macOS journeys` job runs it
  in its own workflow, `.github/workflows/journeys.yml`, which every full or
  scoped CI run on `dev` dispatches from its last job (scoped to the CI run's
  app, if any), and
  uploads the folder as the `ui-screens` artifact of that journeys run
  (`gh run list --workflow journeys.yml`, then `gh run download <id> -n
  ui-screens`). Its own concurrency group means a journeys job waiting for a
  macOS runner never holds CI's, and its `Journeys wait` job holds the run
  on ubuntu until no CI run is queued for a macOS runner and fewer than two
  older journeys runs are alive, so the journeys hold at most two of the
  pool's five macOS runners and the lane's gate goes first. A failed step fails that job and
  files a `finding` issue on dev; the job is report-only, so it never holds
  `main` or a PR. Gate: none (report-only).
- **Quarantine is owned and expires.** The supervisor can skip a journey that
  keeps failing on `dev` by adding it to `UITests/quarantine.json` with an
  open owner issue, a reason and an expiry at most 7 days out. An entry with
  `"scope": "full"` is skipped in full runs only, so a scoped run still runs
  it and its owner keeps the proof while `main` can promote. `scripts/ui-test`
  lists every entry in its output and the job summary, and `scripts/ci` fails
  once an entry expires, its owner issue closes, or its test is gone, so the
  list can't grow quietly. A swift test goes in the same file in the perf
  list's form (`Target.Suite/test`) and `scripts/ci` skips it. Agents never
  edit the file; the fast lane adds and removes its own entries (a `lane`
  block: the dev-red issue, the culprit range, a 24 h expiry) when dev is red
  with no culprit to revert, through its `lane-quarantine` PR that changes
  that file alone (docs/fast-lane.md, Auto-quarantine); `scripts/quarantine
  release` fails while one is in. Gate: `scripts/ci`.
- **Key-press journeys run on the local Mac only.** A journey that posts key
  events as CGEvents (a held Space, Escape mid-drag) needs the test runner's
  Accessibility access, which GitHub's hosted macOS runners don't have. Those
  journeys are listed in `localkeys` in `scripts/ui-test`, which skips them
  when `RUNNER_ENVIRONMENT=github-hosted` and prints `ui-test: skipped: needs
  local key events: <test>` (and a job summary list), so a skip never reads as
  a pass. Run anywhere else, as `scripts/ui-test` on the Mac, they run. Unlike
  the quarantine this is permanent, with no owner or expiry. A journey that
  checks `CGPreflightPostEventAccess()` and skips only its key step by name
  stays off the list, so its other steps keep their hosted coverage.
  Gate: `scripts/ci` (Tests/ui_test).
- **Every user-facing feature extends its app's journey.** When a PR adds
  something a person can see or do, it adds the steps that do it to
  `<X>JourneyTests`: a new `test...` method for a new journey, or more steps in
  an existing one. When a feature completes a journey that is still an
  `XCTSkip` placeholder, replace the skip with the real steps. Review-only.
- **How to write a step.** Use `Journey`: `click("Title", step: "name")`
  clicks the button with that title in the window's content (`in: .toolbar` or
  `in: .sheet` for the others) and shoots `<app>-name`; `shot("name")` shoots
  the window as it is; `clickEachTool()` (shoots the palette, then clicks
  each enabled tool) and `openEachMenu()` cover the canvas palette and the
  menu bar. Find things by the title a person reads. When a
  control has no title, give it an `.accessibilityIdentifier` in the view
  (SuiteUI's use a `suite.` prefix: `suite.sidebar`, `suite.inspector`,
  `suite.tools`) and find it with `app.descendants(matching: .any)["id"]`.
  Step names are unique within an app, because they become the PNG names.
- **Look at the shots.** Name the `<app>-*.png` files your change touches in
  the PR body. The reviewer opens them from the `ui-screens` artifact of the
  journeys.yml run that follows the next feature CI run on `dev`. Review-only.
- **The app audit checks every shot.** Each window shot runs the audit's
  checks (disabled controls look dimmer, no overlapping controls, text
  contrast, identifiers, nothing off the window, every control named) and
  counts each app's distinct violations against `UITests/audit-baseline.json`.
  A count may only go down: a rise fails the journeys and raising the
  baseline needs the captain's review; a fall is written back by CI, which
  pushes the lower baseline to `dev`. New checks come from faults
  (docs/blueprints/app-audit.md, Growing the audit). Gate: the `macOS
  journeys` job (report-only).
- **One page per run: the contact sheet.** After the journeys, the `macOS
  journeys` job runs `scripts/contact-sheet`, which writes `contact-sheet.html` into
  `ui-screens`: the commit, each app's audit counts against the baseline,
  every journey's steps in order with each screen's violations, and the perf
  reports (`BRUSH-LATENCY` and the like) from `.build/snapshots`. Download
  `ui-screens` and open the page; the job summary carries the audit table.
  Tested by `Tests/contact_sheet` in `scripts/ci`.

## Tests

- **Test behavior, not wiring.** Call the Model's public API with one concrete
  input and assert the literal result. A test that would still pass if the code
  returned a default value proves nothing. Review-only.
- **Bug fixes start red.** Write the test that reproduces the bug, see it fail,
  then fix the cause. Review-only.
- **Proof is the gate.** "It compiles" is not done. Gate: `scripts/ci --changed`
  (every lint and build, then the tests of the targets you touched) prints
  `CI: PASS` on your branch rebased on `origin/dev`, and the PR body carries
  the `Fast-Check: pass` / `Head: <sha>` marker for that head. Both CI jobs
  run on `dev` once a feature is built; `main` only takes a green `dev` SHA.
- **Proof is per app.** A slice is verified by a green scoped run on `dev`
  (`ci.yml` with `app`, titled `scoped: <app>`): every target and bundle
  builds, and only that app's Model tests, snapshots and journeys run, so
  another app's red test can't block it. Only a full run moves `main`.
  Gate: the `macOS (<app>)` job.
- **Timing is reported, not gated.** A test that asserts a wall-clock or
  allocation budget can fail on a busy machine while the code is fine, so it
  goes in `Tests/perf-suites.txt` (the supervisor edits it). The gate and
  scoped runs skip it; it runs alone nightly on the captain's Mac (perf-nightly),
  which reports its numbers and warns when a bound is missed by more than 3x.
  `scripts/ci` fails when an enabled test asserts a wall-clock bound and isn't
  listed (`scripts/test-scope timing` names it): land a new one `.disabled` and
  ask for its line in the PR body. A `// not-timing: <why>` comment in the
  test's body is only for a look-alike (an injected clock, a hang guard).
  Gate: none, by design. A local gate on a different toolchain than CI can set
  `CI_LOCAL_SKIP='<swift-testing --skip regex>'` to skip tests that only differ
  there (rendering tint); CI never sets it and stays canonical.

## Reading cost

- One idea per file. No wrapper with one caller and no decision in it. Each
  file opens with a short comment on what it is for now and the invariants a
  reader must keep; edit it when the file changes, history belongs in git.
  Review-only.
