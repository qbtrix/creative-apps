# no-placeholders lead record

Issue: #3776 · Packet: docs/blueprints/suite/features/no-placeholders.md
Run: act-1a166b69fd0-x9m8 · Session: session_012bybPMvARipEyKrs5oNQwY · Started: 2026-10-23T03:08Z
Stage: 3 wave 1
Base: e055e6713e4e852d6c19d98f7c2fd82c6758e67a
Next: wave 1 builders open the contract slice PR(s)

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| NP-a | ratchet test + launcher hides Check for Updates and Assets items | NP-1, NP-2 | MJ-NP, XJ-NP | report-problem:RP-a (met) | yes | 0 | open #4717 | - | - |
| NP-flare | Flare beta.2 items hidden, Library tab hidden, RJ-X64, built | NP-3, NP-4, NP-5, NP-6 | FJ-NP, XJ-NP, MJ-NP | NP-a; CS-flare (met); flare menu hand-offs | yes | 0 | building (stacked on #4717) | - | - |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| NP-1 | NP-a | 1 | PlaceholderMenuTests + baseline + fixture + mutations | packet NP-1 (4 files) | PlaceholderMenuTests; Mutate | - | building |
| NP-2 | NP-a | 1 | launcher drops LauncherCommandsUpdate/Assets; baseline shrinks; AfterGlow menus journey | packet NP-2 (3 files) | XJ-NP | - | building |
| NP-3 | NP-flare | 2 | FlareWorkspace.menuHidden + laterReason; FlareMenuVisibilityTests | packet NP-3 (3 files) | Mutate FlareModel.FlareCommandCatalog | - | waiting |
| NP-4 | NP-flare | 2 | Flare menus skip hidden ids; Library tab hidden; journey | packet NP-4 (5 files) | FJ-NP | - | waiting |
| NP-5 | NP-flare | 3 | RJ-X64 job | packet NP-5 | jobs check | - | waiting |
| NP-6 | NP-flare | 3 | status built; feature-done | wave.json | waves render | - | waiting |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- Base is origin/dev (e055e6713e4e852d6c19d98f7c2fd82c6758e67a), not main: the packet exists only on dev, and CLAUDE.md, lead.md and the fast lane all target dev. main HEAD 0dd23d65 verified at start.
- Status mirrored to lead/suite-no-placeholders (docs/leads/suite-no-placeholders/) as well as lead/no-placeholders, as earlier suite leads did.
- PR bodies carry no attribution footer; any footer the tooling adds is removed with update_pull_request after the PR opens.
- One combined wave plan across #3776, #3774 and #3773 (same session); builders are worktree subagents, at most 4 at once.
- NP-a is one PR (NP-1 + NP-2, about 240 lines, 7 files). NP-flare is one PR for NP-3 + NP-4 + NP-5; NP-6 folds into it as the feature-done PR if under the cap, else a separate last PR.
- NP-flare waits on svg-place PF-u (#4297, needs-fix): it edits `FlareCommands.swift` (the importExport group) and `FlareWindow.swift`; NP-flare edits `FlareCommands.swift` and `FlareWindow+View.swift`. PF-m (#4295) touches only FlareModel place files, no overlap. If #4297 is still open when NP-a merges, NP-flare goes ahead and its PR names #4297 so its lead knows.

## Open
- NP-a opened as #4717 (11 files, +380/-17; three existing tests that pinned the stubs changed too). Gap found: the ratchet matches only `Button(`, so the launcher's `MenuCommand` placeholders in LauncherCommands+Home.swift (Clear Menu, Show Sidebar, Show Inspector) slip past it. NP-flare's builder extends the scan to `MenuCommand(` disabled entries and baselines them, so the ratchet covers what NP-1 promised.
- NP-flare started 03:46Z, stacked on lead/no-placeholders-NP-a. #4297 (PF-u) is still needs-fix and dirty, so it goes ahead; the hand-off note is on #3459 (comment 6356870194). The MenuCommand scan extension rides in NP-flare only if it stays small; otherwise it becomes a gap issue.
