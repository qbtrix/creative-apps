# design-gradient-fill lead record

Issue: #3415 · Packet: docs/blueprints/design/features/gradient-fill.md
Run: act-1a159c9b6b4-va3c · Session: claude/design-lead-snapping-gradient-stroke-brepev · Started: 2026-10-20T14:50Z
Stage: 3 wave 1
Base: 0dd23d65 (origin/dev); main verified at b3011ab9
Next: wait for wave 1's DG-a PR; then DG-u (DG-3) once it merges

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| DG-a | DesignNode.gradient, GradientFillTarget stubs, Fill section on them | DG-1, DG-2 | MJ-DG | GF-a | yes | 0 | building | – | – |
| DG-u | canvas, text, PNG and PDF paint the gradient; snapshots, budget | DG-3, DG-6 | DJ-G1 | DG-a; GF-3 (DG-6) | yes | 0 | waiting | – | – |
| DG-m | fill commands as one step; SVG gradients | DG-4, DG-5 | MJ-DG | DG-a; GF-6, AC-design (DG-4); GF-7, DE-s (DG-5) | no | 0 | waiting | – | – |
| DG-z | journey on live; first-cut line; built | DG-7, DG-8 | DJ-G1 | DG-u, DG-m; design-export | no | 0 | waiting | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| DG-1 | DG-a | 1 | DesignNode.gradient, conformance and runFill stubs; DesignGradientTests disabled | Sources/DesignModel/DesignNode.swift, Sources/DesignModel/DesignFill+Kernel.swift, Tests/DesignModelTests/DesignGradientTests.swift | DesignGradientTests | – | building |
| DG-2 | DG-a | 1 | Fill section on the stubs (placeholder until GF-2's GradientEditor) | Sources/DesignApp/DesignInspectorFill.swift, Sources/DesignApp/DesignInspector.swift | DesignInspectorSnapshots | – | building |

## Critic reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|
| – | – | – | – | – | – |

## Decisions
- Branch is lead/design-gradient-fill, not lead/gradient-fill: lead/gradient-fill belongs to another line's lead of the same feature name.
- PRs target dev (CLAUDE.md); main b3011ab9 is an ancestor of dev and only fast-forwards to green dev.
- Rule 22: one PR per slice; each slice's PR opens with its failing test commit.
- GF-2 (SuiteUI GradientEditor) is not on dev: DG-2 uses a plain SwiftUI placeholder (kind picker calling runFill), swapped for GradientEditor when GF-2 merges.

## Open
- none
