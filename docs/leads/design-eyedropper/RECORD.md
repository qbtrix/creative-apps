# design-eyedropper lead record

Issue: #3438 · Packet: docs/blueprints/design/features/eyedropper.md
Run: act-1a1627ce3b4-ayhz · Session: claude/feature-lead-playbook-6guwwp · Started: 2026-10-22T07:24Z (prior runs act-1a1605b0534-rn47, act-1a15e909498-4bkk, act-1a15abb305f-lc8g)
Stage: relaunch (supervisor 13:33Z on #3438). Belt-Slice-Done DY-m and DY-z, Mac-Finish-Wanted DY-z posted 13:50Z against dev Linux check https://github.com/qbtrix/creative-apps/actions/runs/39782847630 (dev 1a518080, contains #4357 and #4376). DY-z critic panel running (code only: no design or full run with screens contains 1c85591f7 yet)
Base: 5bec8089 (origin/dev); main verified at 0dd23d65
Next: DY-z critic panel findings filed; Belt-Contact-Sheet on #3438; final RECORD

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| DY-a | Eyedropper tool on the palette; SampleTarget stubs | DY-1, DY-2 | MJ-DY | EY-a (done) | yes | 1 | merged (6f9c8928); round-1 fixes merged 45e8bd4d | – | wanted |
| DY-u | loupe follows the pointer, click and Option-click picks; snapshots, budget | DY-3, DY-4 | J-DY | DY-a; EY-u (done) | yes | 2 | merged 6d7fcf14 (#3816); round 1 #3998 merged 97713e0d; round 2 #4081 | – | – |
| DY-m | topmost visible colour; apply as one step; color.sample, color.pick, RJ-D34 | DY-5, DY-6 | MJ-DY | DY-a, transform:DT-m (met); EY-m (done) | no | 0 | #4356 merged; #4357 merged | https://github.com/qbtrix/creative-apps/actions/runs/39782847630 | – |
| DY-z | journey on live; built | DY-7, DY-8 | J-DY | DY-u, DY-m (in lane) | yes | 0 | merged #4376 (1c85591f7) | https://github.com/qbtrix/creative-apps/actions/runs/39782847630 | wanted |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| DY-1 | DY-a | 1 | DesignTool.eyedropper; SampleTarget stubs; DesignSampleTests disabled | Sources/DesignModel/DesignSample+Kernel.swift, Sources/DesignModel/DesignWorkspace.swift, Tests/DesignModelTests/DesignSampleTests.swift | DesignSampleTests | #3691 | merged |
| DY-2 | DY-a | 1 | Eyedropper on the palette (I); journey skipped | Sources/DesignApp/DesignIntent.swift, UITests/DesignJourneyTests+Eyedropper.swift | DesignToolPaletteSnapshots | #3691 | merged |
| DY-5 | DY-m | 2 | adapter bodies (topmost, hidden, gradient), one-step apply, Eyedropper enabled (#3987) | Sources/DesignModel/DesignSample+Kernel.swift, Sources/DesignModel/DesignWorkspace.swift, Sources/DesignApp/DesignCanvas.swift | DesignSampleTests; Mutate 6/6 | #4356 | merged 02d2e5be |
| DY-7 | DY-z | 3 | eyedropper journey on live (cards fixture colours stand in for the packet's red/blue) | UITests/DesignJourneyTests+Eyedropper.swift | DesignJourneyTests testPickFillFromShape (macOS only) | #4376 | merged 1c85591f7 |
| DY-8 | DY-z | 3 | eyedropper.wave.json status built | docs/blueprints/design/features/eyedropper.wave.json | scripts/waves render | #4376 | merged 1c85591f7 |
| DY-6 | DY-m | 2 | color.sample, color.pick; RJ-D34 pick-fill | Sources/DesignModel catalog, Tests/command-ids/design.txt, Tests/RealJobs/design/pick-fill/ | DesignSampleCommandTests | #4357 | merged |

## Critic reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|
| – | – | – | – | – | – |

## Decisions
- 10:47Z supervisor confirmed: Design run only, end once #4357 and #4376 are in the lane. #4376 was retargeted to dev at c27bcab1 instead of waiting stacked, because the lane never deletes merged branches (gh pr merge --delete-branch=false) and skips non-dev bases, so a stacked PR never gets in. Its diff carries DY-6's identical files until #4357 merges.
- 10:42Z Belt pointed this run at lead/eyedropper and lead/stroke-style, the SuiteUI records of other runs (#3448, #3450, both waiting-on-prereq). Treated as a branch-name mismatch; I asked the supervisor on #3438 (issuecomment-6338803954) and kept to the Design run.
- After #4356's squash, dev was merged into DY-m (conflict in the catalog and CLI golden: dev's viewSpecs and file.export kept beside color.*). The repo's JSON merge driver pointed at a removed builder worktree; it is repointed to scripts/merge-json in the main clone.
- DY-m split in two stacked PRs (20 files > 15 cap): #4356 DY-5 to dev, #4357 DY-6 on lead/design-eyedropper-DY-5. The enabled tool changes design-tool-palette-light/dark.png.
- Status branch is lead/design-<feature> (record docs/leads/design-<feature>/): lead/<feature> belongs to the SuiteUI lead of the same feature name.
- PRs target dev, not main (CLAUDE.md, lead.md); main b3011ab9 is an ancestor of dev and only fast-forwards to green dev.
- Rule 22: one PR per slice; each slice's PR opens with its failing test commit.
- One lead (this run) holds stroke-style, shape-tools and eyedropper; one wave plan across the three.
- Design transform (#3436) has no lead running (no lead/design-transform branch, wave.json planned); its DT-a needs gradient-fill:DG-a (building in run act-1a15a9a4e8b-kn6a). shape-tools DS-a and eyedropper DY-m wait on it; this lead does not build another feature's tasks.
- 2026-10-21 run act-1a15e909498-4bkk: the brief names lead/eyedropper as the status branch, but that branch is the SuiteUI eyedropper lead's (#3448). This run keeps lead/design-eyedropper.
- #3990 and #3994 need shared code: filed #4079 (SampleRules.bytes, line:suite) and #4078 (SampleLoupe size square, needs-ui). The Design halves follow those.

## Open
- Run act-1a1627ce3b4-ayhz: brief rule 2 asks to rebase and force-push lead/eyedropper onto main; that branch is the SuiteUI eyedropper lead's record (#3448), so this run does not rewrite it and keeps lead/design-<feature>.
- #3691 first head 667b9d18 failed DesignNodeTests.onlyThePenIsDisabledAndItSaysWhy and DesignDrawTests.theDrawingToolsAreAllEnabled (found by the DY-u builder); fixed at 344cbd8f and the Head line moved. DY-5 note: keep the eyedropper a no-op in model.drag, since the overlay tap already picks.
- The session proxy appends a Claude Code footer to PR bodies written via MCP or REST; it cannot be stripped from here. The fast lane strips attribution from the squash commit. Reported for the supervisor.
- DY-m waits transform:DT-m (Design transform #3436 has no running lead).

- Run act-1a1605b0534-rn47: the brief's "rebase lead/eyedropper onto origin/main" was not done: lead/eyedropper is the SuiteUI eyedropper lead's branch (#3448); this lead's status stays on lead/design-eyedropper.
- #4081 was labelled needs-split at 16 files: its stack still carried #3998's commits. Merging origin/dev into it (no force push) left 1 file, +18 lines.
- 2026-10-22T02:44Z: #4081 merged into dev as 66a84588 (lane noted dev was red on its own). Next: green design run containing 66a84588, then Belt-Slice-Done DY-u.
- 2026-10-22T06:16Z: DY-u Belt-Slice-Done posted on #3438 (scoped design run 39720061887, dev 6e19f406, macOS (design) green, contains 66a84588).
