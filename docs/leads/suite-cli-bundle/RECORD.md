# cli-bundle lead record

Issue: #3773 · Packet: docs/blueprints/suite/features/cli-bundle.md
Run: act-1a16a37a3ed-0kyn (relaunch; earlier act-1a166b69fd0-x9m8) · Started: 2026-10-23T03:08Z
Stage: CB-z: #4999 in lane, #5000 held
Base: 35a0b5e7e9520a764f3eabf02968a453082a87cc (main; PRs target dev)
Next: await #4999 merge, then release #5000

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| CB-a | BundleLayout.cliPath, AssistantConnect stubs, help catalog stubs, checks disabled | CB-1, CB-2 | MJ-CB | report-problem:RP-m (met) | no | 0 | done | 39983291011 | - |
| CB-u | Connect an AI Assistant sheet on the stubs; render budget | CB-5, CB-5b | XJ-CB | CB-a; RP-u (met) | yes | 0 | done | 39983291011 | - |
| CB-m | bodies + bundled signed afterglow (CB-3 supervisor merge) | CB-4, CB-3 | MJ-CB, XJ-CB | CB-a | no | 0 | done | 39983291011 | - |
| CB-z | Install Command-Line Tool; RJ-X62 on; built | CB-6, CB-7, CB-8 | XJ-CB, MJ-CB | CB-u, CB-m | yes | 0 | building (on CB-u + CB-m) | - | - |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| CB-1 | CB-a | 1 | cliPath, AssistantConnect stubs, disabled tests, C4 part | packet CB-1 (4 files) | compiles, disabled by name | - | open #4715 |
| CB-2 | CB-a | 1 | help.connect-assistant + help.install-cli stubs, ids, MCPConfig provider | packet CB-2 (4 files) | specs list | - | open #4715 |
| CB-5 | CB-u | 2 | Help item + AssistantConnectSheet; journey skipped | packet CB-5 (3 files) | XJ-CB | - | open |
| CB-5b | CB-u | 2 | RenderBudgetConnectTests | 1 file | openSheetInTwoBodies | - | open |
| CB-4 | CB-m | 2 | AssistantConnect + help bodies; tests on | packet CB-4 (5 files) | Mutate SuiteModel.AssistantConnect | - | open |
| CB-3 | CB-m | 2 | bundle-apps copies and signs afterglow (supervisor merge) | scripts/bundle-apps, C4, job | macOS bundle | - | open |
| CB-6 | CB-z | 3 | Install Command-Line Tool | InstallCommandLineTool.swift, journey | XJ-CB | - | waiting |
| CB-7 | CB-z | 4 | RJ-X62 on; suite.md 1.4 | 2 files | RJ-X62 | - | waiting |
| CB-8 | CB-z | 4 | status built; feature-done | wave.json | waves render | - | waiting |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- Base is origin/dev (e055e6713e4e852d6c19d98f7c2fd82c6758e67a), not main: the packet exists only on dev, and CLAUDE.md, lead.md and the fast lane all target dev. main HEAD 0dd23d65 verified at start.
- Status mirrored to lead/suite-cli-bundle (docs/leads/suite-cli-bundle/) as well as lead/cli-bundle, as earlier suite leads did.
- PR bodies carry no attribution footer; any footer the tooling adds is removed with update_pull_request after the PR opens.
- One combined wave plan across #3776, #3774 and #3773 (same session); builders are worktree subagents, at most 4 at once.
- CB-3 edits scripts/bundle-apps (protected): opened without fast-lane as a supervisor-merge PR.

## Open

- C4-only PR: suite-packaging description gains the CLI path and AssistantConnect: opened #4755.
- `--bundle` flag in Arguments.swift: wire in CB-m (MCPConfig.bundle(flag:) already takes it).
- CB-3 goes as its own PR on `lead/cli-bundle-CB-m-bundle` with `no-fast-lane` (protected scripts/bundle-apps; supervisor merges).
- 04:45Z #4715 (CB-a) merged. CB-m #4740, CB-m-bundle #4741 (no-fast-lane, supervisor), CB-u #4743 (test-first split, Mutate 3/3) merged origin/dev; gate rerun before retarget to dev. C4-only suite-packaging description PR is now due.
- 2026-10-23T05:22Z CB-u #4743 and CB-m-bundle #4741 merged origin/dev, gate rerun (CB-u: only dev-red #3856 fails; CB-m-bundle: CI: PASS), pushed, retargeted to dev.
- 2026-10-23T05:24Z #4741 got needs-split (1428/51 counted against the merged CB-a base); replied that on dev it is 3 files ~63 lines. CB-z builder started.

## 2026-10-23T06:20:27Z
- Merged: #4740 CB-m, #4743 CB-u, #4755 C4 packaging.
- CB-z split to stay ≤15 files: code on lead/cli-bundle-CB-z (13 files, 0e6a426b1), docs (suite.md, cli-bundle.wave.json built, jobs.json) on lead/cli-bundle-CB-z-docs (f6a22109b), which carries feature-done.
- Both PRs open after #4741 (supervisor, scripts/bundle-apps) merges; CB-z's diff against dev otherwise holds that protected path.
- Gap #4762: the bundle runner RJ-X62 waits on.
- 2026-10-23T19:28Z Relaunch act-1a16a37a3ed-0kyn: rebased on main 35a0b5e7e. Full CI https://github.com/qbtrix/creative-apps/actions/runs/39983291011 (green, main) holds CB-a (#4755), CB-u (#4743) and CB-m (#4740); done markers posted. #4741 (CB-m bundle script) is still open with the supervisor; CB-z waits on it.
