# Writing a feature packet

A **packet** is the plan a lead builds one feature from:
`docs/blueprints/<app>/features/<feature>.md`. This page is the one
reference for whoever writes or re-cuts a packet, and for the packet critic
who checks it. The lead playbook (`lead.md`) says how a lead runs one.

A packet is written so the lead can build in parallel. Factory lesson 105:
leads built serially because packets chained their tasks (mac-platform was
six tasks in one chain, each editing its own line of `docs/c4/model.json`),
so the swarm had nothing to run side by side and a feature took 8 to 16
hours. Every rule below exists to give the lead independent tasks.

## Fragments, not shared files

Two files every feature used to edit are now generated, so tasks never
chain or conflict through them:

- **The C4 model.** `docs/c4/model.json` is assembled by
  `scripts/c4-assemble` from one file per component in `docs/c4/parts/`
  (`<system>/<container>/<component>.json`, with the container's own
  `container.json`). A task that changes what a component covers edits only
  that component's part; **a new component is a new part file in the same
  task that adds its code**, with an `order` that places it among its
  siblings.
- **Waves.** Each app's `features/waves.md` is printed by `scripts/waves`
  from the app's `waves.in.md` (the prose) and one data file per feature,
  `features/<feature>.wave.json` (title, wave, status, feature issue,
  covers, waits on, depends, owned files, journeys). A new packet adds its
  own `.wave.json`; a lead marking its feature built edits only that file
  (`status` and `feature_issue`).
- **`owned` and `journeys` are required.** Belt's blueprint view joins each
  feature to its C4 components and its journeys through them, so
  `scripts/waves check` fails a feature without them and names the feature
  and its packet.
  - `owned` lists every file and glob in the packet's task table's "owned
    files" column, as full paths from the repo root (a path ending in `/`
    or `+` covers what is under or starts with it). It never names a
    generated file: own the C4 part or the `.wave.json` instead.
  - `journeys` lists each XCUITest that proves the feature as
    `<Class>.<testMethod>` (`HaloJourneyTests.testRenderFrame`), the names
    the packet's Journey steps give. `<Class>` is the class that declares
    the test: a `UITests/<App>JourneyTests+<Area>.swift` file has its own
    (`HaloFilesJourneyTests.testSaveAndReopen`). A feature with no XCUITest
    (Model only, no packet yet) leaves it empty and says why in
    `journeys_none`. A slice's `journeys` are the packet's journey ids
    (`J12`, `MJ5`), not class names.
  - A task that adds or renames an owned file or a journey updates the
    `.wave.json` in the same PR, like its C4 part.

No task ever edits `docs/c4/model.json` or a `waves.md`: the lane refuses
them, and on `dev` the Generated workflow rewrites both from their parts.
`scripts/ci` fails when the parts don't assemble or a feature's data breaks
the wave checks (no `owned` or `journeys`, two features of one wave or two
slices that can run at once owning a file, a dependency in the same or a
later wave, an owned generated file).

## The shape

Sections in this order. Keep the headings; the lead and the critics look
for them by name.

1. **Header.** Feature in one sentence; `**Line:**`, `**Wave:**` (the
   app's `waves.md`) and `**Lead branch:**`; `**Covers:**` (issues);
   `**Depends on:**` (feature issues, SuiteUI and creative-core issues);
   the blueprint sections it builds on.
2. **Slices** (contract-first packets, Design first). One table:
   `| slice | behavior (one sentence) | tasks | journeys | waits on |`. A
   slice is the unit of done: 2 to 5 tasks, at least one journey that
   exists or that one of its tasks adds (a Linux Model walk for a
   Model-only slice), and what its tasks wait on outside the slice (a
   feature, or another feature's contract slice). The same data goes in the
   feature's `.wave.json` under `slices`, with each slice's owned files;
   `scripts/waves check` fails when two slices that can run at once own one
   file. A feature's first slice publishes what other features plug into.
   A task that needs another feature's real code, not its fake, waits on
   the slice that builds it, not on that feature's first slice. A packet
   with this table runs the v3 lead loop (`lead.md`, Which loop); one
   without it runs the v2 loop unchanged.
   - **UI slices.** A slice whose tasks change `Sources/*App/` or
     `Sources/SuiteUI/` declares `"ui": true` on its entry in `slices`
     (`scripts/waves check` fails on a value that isn't `true` or `false`).
     It also gets a render budget row in Quality tests for each
     interaction it adds or changes, for example "120-sample drag ≤ 3
     window bodies; divider drag p95 ≤ 8 ms", with its
     `Tests/AppSnapshotTests/RenderBudget*` test. Body counts gate; times
     are checked by the Mac finisher. A UI slice is done only through the
     feel gate and a Mac finisher pass (`lead.md`, contract rules 15 and
     17). Its builders read `docs/engineering/swiftui-rules.md`.
   - **Screen early** (`lead.md`, contract rule 18). Every packet has a
     UI slice that builds the feature's real screen on the contract
     slice's fakes, clickable end to end. Its waits name no slice of its own
     feature but the first (contract) slice, so it runs beside the logic
     slices (real Model, live services), which never wait on it. Its first
     task makes the feature reachable from a visible menu or toolbar
     control. The contract slice declares every Model signature the UI
     calls, as stubs (a stub returns the fake's value, or `NotBuilt` with a
     reason the UI shows); the logic slices fill in the bodies and never
     change the signatures. A packet whose contract slice doesn't (every
     v2 packet, most v3 ones today) gets a small first UI task that
     declares the stubs, and the UI and logic tasks wait only on it. A last slice waits on both and swaps the fakes for live, with
     the journeys on live. A feature with no screen (Model only) puts
     `"ui_slice": "none"` and its reason in `"ui_slice_reason"` in its
     `.wave.json` instead. `scripts/waves check` warns when a feature that
     isn't built has neither (an error once the open packets are re-sliced).
3. **Journey steps.** The numbered steps a user takes, each naming the task
   and the journey test (`<X>-J<n>`) that proves it.
4. **Screens and states.** Each screen state the feature adds and the
   snapshot PNG that shows it.
5. **Contract slice.** The types, protocols and methods the feature adds or
   fills in, with signatures.
6. **Pseudocode.** The logic that isn't obvious from the contract.
7. **Tasks.** One table, one row per task, one PR per task:

   | id | issue | what | owned files | depends on | size |
   |---|---|---|---|---|---|

   - **what:** one behavior.
   - **owned files:** every file the task creates or edits, tests
     included, and with Slices the mutation plan of each source file it
     changes (`Tests/mutations/<Target>.<File>.json`, `lead.md` contract
     rule 14). Nothing outside this list.
   - **depends on:** other task ids of this packet (and outside issues
     such as `#333`), under rule (b). `–` when none.
   - **size:** at most 400 changed lines and 15 files. Split anything
     bigger.
8. **Build waves.** Rule (c): one line per wave, then its independent
   tasks, then the longest chain:

   ```
   - Wave 1: EZ-1, EZ-4, EZ-5. Independent in this wave: all three.
   - Wave 2: EZ-2, EZ-6. Independent in this wave: both.
   - Wave 3: EZ-3, EZ-7, EZ-9 (blueprint prose and design.md, final).
   Longest chain: EZ-1 → EZ-2 → EZ-3 (3).
   ```
9. **Acceptance test per task.** `| id | test | fails when |`, one row per
   task. A test that fails before the task and passes after. With Slices
   (`lead.md`, contract rules 13 and 14):
   - **Build the check first.** A slice's acceptance tests are owned by its
     first code task or a task before it, never a later one. A test that
     merges ahead of its code is disabled until that task
     (`@Test(.disabled("waits on <task id>"))`), so `dev` stays green.
   - **Test the oracle.** The table gains a `mutations` column: for each
     task that adds behaviour, 2 or more bugs that test must catch (`<=`
     for `<` on the left edge; a locked layer moves), which the builder adds
     to the plan of the file it changes and runs with `scripts/mutate`.
10. **Quality tests.** `| quality row | budget | test |`: budgets, no dead
   controls, one gesture one step, keyboard parity, the audit, and a render
   budget row per UI slice (`render: <interaction>` | `120-sample drag ≤ 3
   window bodies; p95 ≤ 8 ms` | `RenderBudget<App>Tests.<test>`).
11. **Done check.** Journeys green on the `feature-done` CI run, audit zero
    new, the contact sheet comment. With Slices, per slice instead: its
    journeys green on a scoped run (`ci.yml` with `app=<app>`) that contains
    its last merged PR, every app built, no open `finding` issue, for a UI
    slice the feel gate and its `Mac-Finish:` line, then the contact sheet
    once every slice is done (`lead.md`, contract rules 6, 15 and 17).
12. **Review notes folded in** (optional). What a review changed.

## The three rules

**(a) Shared prose goes in ONE final task; fragments go with their code.**
Edits to `docs/design.md`, a blueprint (`docs/blueprints/<app>.md`) or an
app's `waves.in.md` all go in the feature's last task, the one that carries
`feature-done` (or a docs-only task right before it when that task would
pass 400 lines or 15 files). No build task owns shared prose, so no two
build tasks chain through it. A C4 part and the feature's `.wave.json` are
fragments, not shared docs: the task that adds a component adds its part,
a task that changes what its component covers edits that part, and the
`feature-done` task sets the feature's `status` to `built`. Two tasks that
edit the same part are owned-file overlap (rule (c)), so give a new area its
own component part rather than chain. A new file inside a target's folder
is already covered by its C4 component.

**(b) Depend only on merged code you need.** Task B depends on task A only
when B cannot be built and pass `scripts/ci` without A merged: B calls a
type or method A adds, B's test needs A's behavior, or B edits a file A
owns. Order of the table, "the Model before the view", "same area" or "the
journey comes last" are not reasons on their own. A task that needs only
a contract can code against the protocol and the fake that already exist.
A chain longer than 3 tasks (four or more in one depends-on path) gets a
one-line reason next to it in the Build waves section, for example
`Chain of 4: D0-2.1 → D0-2.4 each add types the next one's fakes conform to.`
When the only link in a chain is a shared file, split the file (a new
`+Area.swift` extension file) rather than chain; that is the one reason to
split a task.

**(c) Each wave lists its independent tasks.** A wave is a set of tasks
whose depends-on lines point only at earlier waves, and whose owned files
don't overlap. Its line says which of them are independent, so the lead
builds them together (`lead.md`, stage 3). Put every task in the earliest
wave its dependencies allow.

**Counting a chain.** The longest chain is the most tasks on one
depends-on path inside the packet. Outside issues (`#333`, a SuiteUI or
creative-core issue) don't count. Each app's `waves.md` records the longest
chain per feature.

## Packet critic checks

A packet critic reads the packet against this page and reports each miss
with the task ids. It refutes; it doesn't rewrite.

1. **Chain over 3 without a reason.** Any depends-on path of four or more
   tasks with no one-line reason in Build waves.
2. **A link that isn't needed.** A depends-on whose task doesn't call
   anything the other adds, doesn't need its behavior in a test, and
   doesn't share an owned file.
3. **Shared-prose edits outside the final task.** `docs/design.md`, a
   blueprint or a `waves.in.md` in any task but the last; any task that
   lists the generated `docs/c4/model.json` or a `waves.md` at all (it
   edits the C4 part or the feature's `.wave.json` instead); a new
   component whose part is not in the task that adds its code.
4. **Owned files overlapping inside a wave.** Two tasks of one wave that
   list the same file.
5. **A missing link.** A task that uses something another task adds, or
   edits its file, without a depends-on (the wave would build it too
   early).
6. **Wave lines wrong.** A task not in the earliest wave its depends-on
   allows, a wave without an "Independent in this wave" line, or a task in
   no wave.
7. **Size.** A task over 400 lines or 15 files.
8. **Shape.** A section missing, or a task without an acceptance test.
9. **Data out of step.** The packet's `.wave.json` missing a file its task
   table owns or a journey its Journey steps name, or naming one the packet
   doesn't (`owned`, `journeys`).
10. **Check after code** (with Slices). A slice whose acceptance tests are
    owned only by a task that comes after its first code task.
11. **No oracle** (with Slices). A task that adds behaviour with fewer than
    2 mutations in its Acceptance row, or that changes planned source
    without owning that file's plan in `Tests/mutations/`.
12. **UI slice unmarked** (with Slices). A slice whose tasks own files under
    `Sources/*App/` or `Sources/SuiteUI/` without `"ui": true`, or a UI
    slice with no render budget row in Quality tests.
13. **Screen last.** A UI task that calls a Model signature no contract
    task or stub task declares (it can't compile until a logic slice
    lands); every packet, v2 included. With Slices, also: no `"ui": true`
    slice whose waits, within its own feature, name only the contract
    slice (never a logic slice), or a UI slice whose first task doesn't
    reach the feature from a visible menu or toolbar control on the fakes.
    A feature with no screen instead declares `"ui_slice": "none"` with a
    `"ui_slice_reason"`; a reason that doesn't hold (the feature adds a
    control or a screen) is a miss too.
14. **App-local copy** (a blocker; every packet, v2 included). A task that
    adds app-local logic, in `Sources/<X>Model/` or `Sources/<X>App/`, for a
    concept SuiteModel, SuiteUI, creative-core or another app's Model
    already has, or for a concept with a planned editor-kernel module (undo
    and history, selection, the layer tree and parenting, transform with
    marquee and snapping, keyframes and easing, export, crop). The fix uses
    the shared module, or adds a contract task that extracts the concept
    into SuiteModel first and both apps use it (`lead.md`, contract rule
    20). An adapter onto the shared module (`<X>+Kernel.swift`,
    `<X>Adapter.swift`) isn't a copy.
