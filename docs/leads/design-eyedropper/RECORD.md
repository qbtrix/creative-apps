# design-eyedropper lead record

Issue: #3438 · Packet: docs/blueprints/design/features/eyedropper.md
Run: act-1a15abb305f-lc8g · Session: claude/design-feature-lead-run-0oib91 · Started: 2026-10-20T19:16:13Z
Stage: 3 wave 2 (DY-a merged 23:24Z as 6f9c8928; DY-u merged 06:45Z as 6d7fcf14)
Base: a48992b7c85ded3959e12683f50bd5fe7531b011 (origin/dev); main verified at b3011ab9
Next: dev CI 39573184415 (296186f4) Linux went red on the two DY-a mutation anchors (DS-a #3857 reworded the shared case line after #3889 anchored on it); #3980 from the placed-images lead repoints them. Belt-Slice-Done DY-a and Mac-Finish-Wanted DY-a follow the first dev CI after #3980 with a green Linux job. DY-u critics running (wf_3582a1a8-d8b); J-DY skips until DY-7.

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| DY-a | Eyedropper tool on the palette; SampleTarget stubs | DY-1, DY-2 | MJ-DY | EY-a (done) | yes | 1 | merged (6f9c8928); round-1 fixes merged 45e8bd4d | – | wanted |
| DY-u | loupe follows the pointer, click and Option-click picks; snapshots, budget | DY-3, DY-4 | J-DY | DY-a; EY-u (done) | yes | 0 | merged 6d7fcf14 (#3816) | – | – |
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

## Open
- #3691 first head 667b9d18 failed DesignNodeTests.onlyThePenIsDisabledAndItSaysWhy and DesignDrawTests.theDrawingToolsAreAllEnabled (found by the DY-u builder); fixed at 344cbd8f and the Head line moved. DY-5 note: keep the eyedropper a no-op in model.drag, since the overlay tap already picks.
- The session proxy appends a Claude Code footer to PR bodies written via MCP or REST; it cannot be stripped from here. The fast lane strips attribution from the squash commit. Reported for the supervisor.
- DY-m waits transform:DT-m (Design transform #3436 has no running lead).
