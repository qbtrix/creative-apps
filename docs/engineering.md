# Engineering rules

What good code looks like in creative-apps (CLAUDE.md covers picking work and
shipping it). Read this before you write code; check your diff against
`docs/review-rubric.md` before you open a PR. Look and behavior rules for views
are in `docs/design.md`.

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
2. **`<X>Model`**: the app's state and logic: what is open, what is selected,
   which tool is active, and every operation a view can ask for. It calls
   creative-core to do the real work. Linux-safe, so it is where tests live.
3. **`<X>App`**: SwiftUI views and the `App` scene, built from **SuiteUI**.
   Views read the Model and call its methods. Nothing else.

SuiteUI sits beside the apps: it knows nothing about any Model or engine.

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
  something, file `needs-core` on creative-core (CLAUDE.md) and keep going.
  Document edits go through the engine's commands (FlareCore's `Command` and
  `CommandEngine`), so undo works. Review-only.
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
  `.build/ui-screens/<app>-<step>.png`. The `macOS` CI job runs it after the
  bundles are built and uploads the folder as the `ui-screens` artifact
  (`gh run download <id> -n ui-screens`). A failed step fails the job. Gate:
  the `macOS` job.
- **Every user-facing feature extends its app's journey.** When a PR adds
  something a person can see or do, it adds the steps that do it to
  `<X>JourneyTests`: a new `test...` method for a new journey, or more steps in
  an existing one. When a feature completes a journey that is still an
  `XCTSkip` placeholder, replace the skip with the real steps. Review-only.
- **How to write a step.** Use `Journey`: `click("Title", step: "name")`
  clicks the button with that title in the window's content (`in: .toolbar` or
  `in: .sheet` for the others) and shoots `<app>-name`; `shot("name")` shoots
  the window as it is; `clickEachTool()` (clicks each enabled tool,
  hovers a disabled one so the shot shows why) and `openEachMenu()` cover the
  canvas palette and the menu bar. Find things by the title a person reads. When a control has no title, give it an
  `.accessibilityIdentifier` in the view (SuiteUI's use a `suite.` prefix:
  `suite.sidebar`, `suite.inspector`, `suite.tools`) and find it with
  `app.descendants(matching: .any)["id"]`. Step names are unique within an
  app, because they become the PNG names.
- **Look at the shots.** Open the `<app>-*.png` files your change touched from
  `ui-screens`, the same way you check snapshots, and name them in the PR
  body. Review-only.

## Tests

- **Test behavior, not wiring.** Call the Model's public API with one concrete
  input and assert the literal result. A test that would still pass if the code
  returned a default value proves nothing. Review-only.
- **Bug fixes start red.** Write the test that reproduces the bug, see it fail,
  then fix the cause. Review-only.
- **Proof is the gate.** "It compiles" is not done. Gate: `scripts/ci` prints
  `CI: PASS`, and both CI jobs are green on the PR.

## Reading cost

- One idea per file. No wrapper with one caller and no decision in it. Each
  file opens with a short comment on what it is for now and the invariants a
  reader must keep; edit it when the file changes, history belongs in git.
  Review-only.
