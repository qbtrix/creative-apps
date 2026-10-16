# Writing a feature packet

A **packet** is the plan one feature lead builds from:
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
  covers, waits on, depends, owned files). A new packet adds its own
  `.wave.json`; a lead marking its feature built edits only that file
  (`status` and `feature_issue`).

No task ever edits `docs/c4/model.json` or a `waves.md`: the lane refuses
them, and on `dev` the Generated workflow rewrites both from their parts.
`scripts/ci` fails when the parts don't assemble or a feature's data breaks
the wave checks (two features of one wave owning a file, a dependency in the
same or a later wave).

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
     included. Nothing outside this list.
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
   task. A test that fails before the task and passes after.
10. **Quality tests.** `| quality row | budget | test |`: budgets, no dead
   controls, one gesture one step, keyboard parity, the audit.
11. **Done check.** Journeys green on the `feature-done` CI run, audit zero
    new, the contact sheet comment. With Slices, per slice instead: its
    journeys green on a scoped run (`ci.yml` with `app=<app>`) that contains
    its last merged PR, every app built, no open `finding` issue, then the
    contact sheet once every slice is done (`lead.md`, contract rule 6).
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
