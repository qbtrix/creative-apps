# design-eyedropper lead record

Issue: #3438 · Packet: docs/blueprints/design/features/eyedropper.md
Run: act-1a1605b0534-rn47 · Session: claude/feature-leads-stroke-eyedropper-e84htn · Started: 2026-10-21T21:05Z (prior runs act-1a15e909498-4bkk, act-1a15abb305f-lc8g)
Stage: DY-u round 2 #4081 merged (66a84588); waiting on a green scoped design run containing it for Belt-Slice-Done DY-u gaps #3987 #3990 #3994; DY-m waits on DT-m (#4255 in lane) (2026-10-22T03:06Z)
Base: 5bec8089 (origin/dev); main verified at 0dd23d65
Next: #4081 (round 2, #4061; head 1a5a24be with #4215 ported for dev's Photo compile break, Fast-Check pass) merges -> Belt-Slice-Done DY-u gaps #3987 #3990 #3994 on the next green design run. DY-m waits transform:DT-m (#4187 open; DT-6 after DG-m)

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| DY-a | Eyedropper tool on the palette; SampleTarget stubs | DY-1, DY-2 | MJ-DY | EY-a (done) | yes | 1 | merged (6f9c8928); round-1 fixes merged 45e8bd4d | – | wanted |
| DY-u | loupe follows the pointer, click and Option-click picks; snapshots, budget | DY-3, DY-4 | J-DY | DY-a; EY-u (done) | yes | 2 | merged 6d7fcf14 (#3816); round 1 #3998 merged 97713e0d; round 2 #4081 | – | – |
| DY-m | topmost visible colour; apply as one step; color.sample, color.pick, RJ-D34 | DY-5, DY-6 | MJ-DY | DY-a, transform:DT-m; EY-m (done) | no | 0 | waiting | – | – |
| DY-z | journey on live; built | DY-7, DY-8 | J-DY | DY-u, DY-m | yes | 0 | waiting | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| DY-1 | DY-a | 1 | DesignTool.eyedropper; SampleTarget stubs; DesignSampleTests disabled | Sources/DesignModel/DesignSample+Kernel.swift, Sources/DesignModel/DesignWorkspace.swift, Tests/DesignModelTests/DesignSampleTests.swift | DesignSampleTests | #3691 | merged |
| DY-2 | DY-a | 1 | Eyedropper on the palette (I); journey skipped | Sources/DesignApp/DesignIntent.swift, UITests/DesignJourneyTests+Eyedropper.swift | DesignToolPaletteSnapshots | #3691 | merged |

## Critic reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|
| – | – | – | – | – | – |

## Decisions
- Status branch is lead/design-<feature> (record docs/leads/design-<feature>/): lead/<feature> belongs to the SuiteUI lead of the same feature name.
- PRs target dev, not main (CLAUDE.md, lead.md); main b3011ab9 is an ancestor of dev and only fast-forwards to green dev.
- Rule 22: one PR per slice; each slice's PR opens with its failing test commit.
- One lead (this run) holds stroke-style, shape-tools and eyedropper; one wave plan across the three.
- Design transform (#3436) has no lead running (no lead/design-transform branch, wave.json planned); its DT-a needs gradient-fill:DG-a (building in run act-1a15a9a4e8b-kn6a). shape-tools DS-a and eyedropper DY-m wait on it; this lead does not build another feature's tasks.
- 2026-10-21 run act-1a15e909498-4bkk: the brief names lead/eyedropper as the status branch, but that branch is the SuiteUI eyedropper lead's (#3448). This run keeps lead/design-eyedropper.
- #3990 and #3994 need shared code: filed #4079 (SampleRules.bytes, line:suite) and #4078 (SampleLoupe size square, needs-ui). The Design halves follow those.

## Open
- #3691 first head 667b9d18 failed DesignNodeTests.onlyThePenIsDisabledAndItSaysWhy and DesignDrawTests.theDrawingToolsAreAllEnabled (found by the DY-u builder); fixed at 344cbd8f and the Head line moved. DY-5 note: keep the eyedropper a no-op in model.drag, since the overlay tap already picks.
- The session proxy appends a Claude Code footer to PR bodies written via MCP or REST; it cannot be stripped from here. The fast lane strips attribution from the squash commit. Reported for the supervisor.
- DY-m waits transform:DT-m (Design transform #3436 has no running lead).

- Run act-1a1605b0534-rn47: the brief's "rebase lead/eyedropper onto origin/main" was not done: lead/eyedropper is the SuiteUI eyedropper lead's branch (#3448); this lead's status stays on lead/design-eyedropper.
- #4081 was labelled needs-split at 16 files: its stack still carried #3998's commits. Merging origin/dev into it (no force push) left 1 file, +18 lines.
- 2026-10-22T02:44Z: #4081 merged into dev as 66a84588 (lane noted dev was red on its own). Next: green design run containing 66a84588, then Belt-Slice-Done DY-u.
