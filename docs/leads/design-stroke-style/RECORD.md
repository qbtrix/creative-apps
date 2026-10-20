# design-stroke-style lead record

Issue: #3441 · Packet: docs/blueprints/design/features/stroke-style.md
Run: act-1a159c9b6b4-va3c · Session: claude/design-lead-snapping-gradient-stroke-brepev · Started: 2026-10-20T14:50Z
Stage: 3 wave 1
Base: 0dd23d65 (origin/dev); main verified at b3011ab9
Next: wait for wave 1's DK-a PR; DK-u and DK-m wait on shape-tools DS-u / DS-m

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| DK-a | stroke adapter stubs, vectorStroke, Stroke section on them | DK-1, DK-2 | MJ-DK | – | yes | 0 | building | – | – |
| DK-u | canvas strokes dashes, joins, caps; snapshots, budget | DK-3, DK-4 | J-DK | DK-a, shape-tools:DS-u | yes | 0 | waiting | – | – |
| DK-m | DesignStroke is VectorStroke; commands; SVG | DK-5, DK-6, DK-7 | MJ-DK | DK-a, shape-tools:DS-m | no | 0 | waiting | – | – |
| DK-z | journey on live; built | DK-8, DK-9 | J-DK | DK-u, DK-m | no | 0 | waiting | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| DK-1 | DK-a | 1 | adapter and DesignNode.vectorStroke stubs; DesignStrokeTests disabled | Sources/DesignModel/DesignStroke+Kernel.swift, Tests/DesignModelTests/DesignStrokeTests.swift | DesignStrokeTests | – | building |
| DK-2 | DK-a | 1 | Stroke section on the stubs (placeholder until SS-2's StrokeEditor) | Sources/DesignApp/DesignInspectorStyle.swift, UITests/DesignJourneyTests+Stroke.swift | DesignInspectorSnapshots | – | building |

## Critic reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|
| – | – | – | – | – | – |

## Decisions
- Branch is lead/design-stroke-style, not lead/stroke-style: lead/stroke-style belongs to another line's lead of the same feature name.
- PRs target dev (CLAUDE.md); main b3011ab9 is an ancestor of dev and only fast-forwards to green dev.
- Rule 22: one PR per slice; each slice's PR opens with its failing test commit.
- SS-2 StrokeEditor (#3601) is open: DK-2 uses a plain SwiftUI placeholder if it has not merged, swapped when it does.
- shape-tools (DS-u, DS-m) is planned with no tasks merged: DK-u and DK-m wait.

## Open
- none
