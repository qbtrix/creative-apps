# editor-menus lead record

Issue: #3774 · Packet: docs/blueprints/suite/features/editor-menus.md
Run: act-1a16a37a3ed-0kyn (relaunch; earlier act-1a166b69fd0-x9m8) · Started: 2026-10-23T03:08Z
Stage: EM-flare-halo: #4817, #4988 in lane
Base: 35a0b5e7e9520a764f3eabf02968a453082a87cc (main; PRs target dev)
Next: dev-red #5113 (lottie-oracle cache, supervisor) clears, then batch

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| EM-a | .suiteEditor + ReopenRule + delegate reopen | EM-1, EM-2 | XJ-EM | report-problem:RP-a (met) | yes | 0 | done | 39983291011 | - |
| EM-photo-design | Photo and Design adopt .suiteEditor (#3648) | EM-3, EM-4 | PJ-EM, DJ-EM | EM-a; file-flow adopts (on dev) | yes | 0 | done | 39983291011 | - |
| EM-flare-halo | Flare and Halo adopt .suiteEditor (#1018, #1081) | EM-5, EM-6 | FJ-EM, HJ-EM | EM-a; file-flow adopts (on dev) | yes | 0 | open #4738 | - | - |
| EM-library | Library adopts; RJ-X63; built | EM-7, EM-8, EM-9, EM-10 | LJ-EM + all | EM-a, every app slice | yes | 0 | done | 39983291011 | - |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| EM-1 | EM-a | 1 | SuiteEditorScene, ReopenRule stub, reopen tests, C4 part | packet EM-1 (4 files) | compiles | - | merged #4710 |
| EM-2 | EM-a | 1 | delegate applicationShouldHandleReopen + openWindow; ReopenRule body; tests on | packet EM-2 (4 files) | SuiteEditorReopenTests; Mutate SuiteModel.ReopenRule | - | merged #4710 |
| EM-3 | EM-photo-design | 2 | Photo adopts | PhotoApp.swift, journey | PJ-EM | - | open |
| EM-4 | EM-photo-design | 2 | Design adopts | DesignApp.swift, journey | DJ-EM | - | open |
| EM-5 | EM-flare-halo | 2 | Flare adopts | FlareApp.swift, journey | FJ-EM | - | open |
| EM-6 | EM-flare-halo | 2 | Halo adopts | HaloApp.swift, HaloFileMenu.swift, journey | HJ-EM | - | open |
| EM-7 | EM-library | 2 | Library adopts | LibraryApp.swift, journey | LJ-EM | - | waiting |
| EM-8 | EM-library | 2 | RJ-X63 job folder | jobs json | jobs check | - | waiting |
| EM-9 | EM-library | 3 | RJ-X63 on; every-control lists new ids | jobs json, EveryControl journey | RJ-X63 | - | waiting |
| EM-10 | EM-library | 3 | status built; feature-done | wave.json | waves render | - | waiting |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- Base is origin/dev (e055e6713e4e852d6c19d98f7c2fd82c6758e67a), not main: the packet exists only on dev, and CLAUDE.md, lead.md and the fast lane all target dev. main HEAD 0dd23d65 verified at start.
- Status mirrored to lead/suite-editor-menus (docs/leads/suite-editor-menus/) as well as lead/editor-menus, as earlier suite leads did.
- PR bodies carry no attribution footer; any footer the tooling adds is removed with update_pull_request after the PR opens.
- One combined wave plan across #3776, #3774 and #3773 (same session); builders are worktree subagents, at most 4 at once.
- EM-a is one PR (EM-1 + EM-2, about 290 lines, 6 files). Photo and Design keep their own delegates (PhotoAppDelegate, FlareAppDelegate): the adopt checks whether they subclass SuiteAppDelegate before replacing the adaptor.
- Delegates checked: Halo uses `SuiteAppDelegate` directly; Photo's `PhotoAppDelegate` subclasses it (inherits reopen); Flare's `FlareAppDelegate` is a plain `NSObject` delegate, so EM-flare makes it subclass `SuiteAppDelegate` (override `applicationDidFinishLaunching`, call super) or the reopen rule never runs in Flare. Library uses `.suiteApp` without a custom delegate; Design to be read at EM-photo-design.

## Open
- C4-only follow-up for shell-adoption description (text in #4710 body): open once #4710 merges, so the description never names code dev lacks.
- XJ-EM launcher-side journey skips: fold into EM-library.
- Design hand-off: told #3469's lead (comment 6356814669) that DesignApp.swift's scene line is EM-4's; DF-2 keeps File menu + drop.
- C4-only shell-adoption description PR #4737 opened (text from #4710). EM-flare-halo #4738 on dev; EM-photo-design #4739 stacked on it.

## 2026-10-23T06:20:27Z
- #4761 EM-library opened, stacked on #4739 → #4738; labels fast-lane, feature-done.
- #4738 conflicted with dev in FlareApp.swift (#4716 renamed FlareOpenQueue to FlareShell.openQueue). Merged dev, resolved, CI: PASS, head 9d59908ec, Head line moved.

## 2026-10-23T06:45:10Z
- #4738 EM-flare-halo merged (06:40:59Z). #4739 merged dev (FlareApp.swift conflict from the parent squash, resolved to dev, which the slice does not touch); retarget to dev once the gate passes. #4761 follows.
- 2026-10-23T06:51:45Z: #4739 on dev base, head b78892b7a, CI: PASS. #4761 merging the new head, gate running. Scoped runs for EM-flare-halo come from verify-dispatch (our dispatch is 403).
- 2026-10-23T06:56:28Z: #4761 head 721213065, CI: PASS; retarget to dev when #4739 merges.

- 2026-10-23T07:19:48Z: #4739 macOS build failed on a dev break (FlareStage.swift:81, FlareOpenQueue from #4708 after #4716). Opened fix #4771. Will merge dev into #4739 once it lands.
- 2026-10-23T09:06:31Z: #4739 EM-photo-design merged (09:02Z). #4761 merged origin/dev at e42863714 (no conflicts), CI: PASS, retargeted to dev, stacked note dropped, Head moved. It is the last slice (feature-done).

- 09:53Z: #4761 (EM-library, feature-done) merged. All editor-menus slices are on dev. Done markers wait on a green full CI (Linux+macOS) on a dev head that includes it, plus its journeys run.
- 2026-10-23T19:28Z Relaunch act-1a16a37a3ed-0kyn: rebased on main 35a0b5e7e. Full CI https://github.com/qbtrix/creative-apps/actions/runs/39983291011 (green, main) holds the newest PRs for EM-a (#4737), EM-photo-design (#4771) and EM-library (#4761); done markers posted. EM-flare-halo is open: #4816 merged after main; #4817 and #4818 are in the lane. The supervisor added #4830 (focused text fields keep edit keys, shared layer); builder started on lead/editor-menus-4830.
