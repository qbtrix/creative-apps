# design-eyedropper lead record

Issue: #3438 · Packet: docs/blueprints/design/features/eyedropper.md
Run: act-1a15e909498-4bkk · Session: claude/feature-lead-stroke-eyedropper-il215c · Started: 2026-10-21T12:55Z (prior run act-1a15abb305f-lc8g)
Stage: 3 wave 2 fixes (DY-a done 10:30Z; DY-u merged 6d7fcf14, round 1 #3998 in the lane)
Base: 5bec8089 (origin/dev); main verified at 0dd23d65
Next: #3998 macOS build red (mutating openFixture inside #expect, DesignToolPaletteSnapshots.swift:53), fixed and back in the lane; DY-u round 2: #4062 split the timing test, #4061 Point truncation; #3990 #3994 wait on #4079 / #4078; #3987 rides DY-5. 11 open findings, so no new wave. DY-m waits transform:DT-m

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| DY-a | Eyedropper tool on the palette; SampleTarget stubs | DY-1, DY-2 | MJ-DY | EY-a (done) | yes | 1 | merged (6f9c8928); round-1 fixes merged 45e8bd4d | – | wanted |
| DY-u | loupe follows the pointer, click and Option-click picks; snapshots, budget | DY-3, DY-4 | J-DY | DY-a; EY-u (done) | yes | 1 | merged 6d7fcf14 (#3816); round 1 #3998 | – | – |
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

