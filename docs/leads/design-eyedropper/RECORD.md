# design-eyedropper lead record

Issue: #3438 · Packet: docs/blueprints/design/features/eyedropper.md
Run: act-1a15abb305f-lc8g · Session: claude/design-feature-lead-run-0oib91 · Started: 2026-10-20T19:16:13Z
Stage: 3 wave 1 (DY-a building)
Base: a48992b7c85ded3959e12683f50bd5fe7531b011 (origin/dev); main verified at b3011ab9
Next: DY-a PR (DY-1 + DY-2); then DY-u (DY-3, DY-4) stacked on it. DY-m waits transform:DT-m

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| DY-a | Eyedropper tool on the palette; SampleTarget stubs | DY-1, DY-2 | MJ-DY | EY-a (done) | yes | 0 | building | – | – |
| DY-u | loupe follows the pointer, click and Option-click picks; snapshots, budget | DY-3, DY-4 | J-DY | DY-a; EY-u (done) | yes | 0 | next | – | – |
| DY-m | topmost visible colour; apply as one step; color.sample, color.pick, RJ-D34 | DY-5, DY-6 | MJ-DY | DY-a, transform:DT-m; EY-m (done) | no | 0 | waiting | – | – |
| DY-z | journey on live; built | DY-7, DY-8 | J-DY | DY-u, DY-m | yes | 0 | waiting | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| DY-1 | DY-a | 1 | DesignTool.eyedropper; SampleTarget stubs; DesignSampleTests disabled | Sources/DesignModel/DesignSample+Kernel.swift, Sources/DesignModel/DesignWorkspace.swift, Tests/DesignModelTests/DesignSampleTests.swift | DesignSampleTests | – | building |
| DY-2 | DY-a | 1 | Eyedropper on the palette (I); journey skipped | Sources/DesignApp/DesignIntent.swift, UITests/DesignJourneyTests+Eyedropper.swift | DesignToolPaletteSnapshots | – | building |

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
- DY-m waits transform:DT-m (Design transform #3436 has no running lead).
