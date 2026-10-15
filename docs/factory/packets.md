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

## The shape

Sections in this order. Keep the headings; the lead and the critics look
for them by name.

1. **Header.** Feature in one sentence; `**Line:**`, `**Wave:**` (the
   app's `waves.md`) and `**Lead branch:**`; `**Covers:**` (issues);
   `**Depends on:**` (feature issues, SuiteUI and creative-core issues);
   the blueprint sections it builds on.
2. **Journey steps.** The numbered steps a user takes, each naming the task
   and the journey test (`<X>-J<n>`) that proves it.
3. **Screens and states.** Each screen state the feature adds and the
   snapshot PNG that shows it.
4. **Contract slice.** The types, protocols and methods the feature adds or
   fills in, with signatures.
5. **Pseudocode.** The logic that isn't obvious from the contract.
6. **Tasks.** One table, one row per task, one PR per task:

   | id | issue | what | owned files | depends on | size |
   |---|---|---|---|---|---|

   - **what:** one behavior.
   - **owned files:** every file the task creates or edits, tests
     included. Nothing outside this list.
   - **depends on:** other task ids of this packet (and outside issues
     such as `#333`), under rule (b). `–` when none.
   - **size:** at most 400 changed lines and 15 files. Split anything
     bigger.
7. **Build waves.** Rule (c): one line per wave, then its independent
   tasks, then the longest chain:

   ```
   - Wave 1: EZ-1, EZ-4, EZ-5. Independent in this wave: all three.
   - Wave 2: EZ-2, EZ-6. Independent in this wave: both.
   - Wave 3: EZ-3, EZ-7, EZ-9 (shared docs, final).
   Longest chain: EZ-1 → EZ-2 → EZ-3 (3).
   ```
8. **Acceptance test per task.** `| id | test | fails when |`, one row per
   task. A test that fails before the task and passes after.
9. **Quality tests.** `| quality row | budget | test |`: budgets, no dead
   controls, one gesture one step, keyboard parity, the audit.
10. **Done check.** Journeys green on the `feature-done` CI run, audit zero
    new, the contact sheet comment.
11. **Review notes folded in** (optional). What a review changed.

## The three rules

**(a) Shared docs go in ONE final task.** Edits to `docs/c4/model.json`,
`docs/design.md`, a blueprint (`docs/blueprints/<app>.md`) or a `waves.md`
all go in the feature's last task, the one that carries `feature-done`
(or a docs-only task right before it when that task would pass 400 lines
or 15 files). No build task owns a shared doc, so no two build tasks chain
through one. A new file inside a target's folder is already covered by its
C4 component; a description that needs a new sentence gets it in the final
task.

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
3. **Shared-doc edits outside the final task.** `docs/c4/model.json`,
   `docs/design.md`, a blueprint or a `waves.md` in any task but the last.
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
