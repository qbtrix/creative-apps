# design-gradient-fill lead record

Issue: #3415 · Packet: docs/blueprints/design/features/gradient-fill.md
Run: act-1a15da1b26c-9qo6 · Session: claude/design-feature-lead-run-1k035k · Started: 2026-10-21T08:46:56Z (prior run act-1a15ac70747-ky1f)
Stage: 3 DG-m PR #4189 open (DG-4+DG-5, mutate 3/3 + 9/9); DG-z: DG-7 PR #4197 open (journey file alone off dev; #4192 closed, oversize when stacked)
Base: 896cafe3 (origin/dev); main verified at 0dd23d65
Next: #4189 merges -> Belt-Slice-Done DG-m on a green design run; #4197 merges; DG-8 after DG-7 + design-export built (design-export still planned at 2026-10-21T22:05Z)

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| DG-a | DesignNode.gradient, GradientFillTarget stubs, Fill section on them | DG-1, DG-2 | MJ-DG | GF-a | yes | 0 | done | – | – |
| DG-u | canvas, text, PNG and PDF paint the gradient; snapshots, budget | DG-3, DG-6 | DJ-G1 | DG-a; GF-3 (DG-6) | yes | 0 | in lane | – | – |
| DG-m | fill commands as one step; SVG gradients | DG-4, DG-5 | MJ-DG | DG-a; GF-6, AC-design (DG-4); GF-7, DE-s (DG-5) | no | 0 | waiting | – | – |
| DG-z | journey on live; first-cut line; built | DG-7, DG-8 | DJ-G1 | DG-u, DG-m; design-export | no | 0 | waiting | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| DG-1 | DG-a | 1 | DesignNode.gradient, conformance and runFill stubs; DesignGradientTests disabled | Sources/DesignModel/DesignNode.swift, Sources/DesignModel/DesignFill+Kernel.swift, Tests/DesignModelTests/DesignGradientTests.swift | DesignGradientTests | #3687 | merged (b17264bf) |
| DG-2 | DG-a | 1 | Fill section on the stubs (placeholder until GF-2's GradientEditor) | Sources/DesignApp/DesignInspectorFill.swift, Sources/DesignApp/DesignInspector.swift | DesignInspectorSnapshots | #3687 | merged (b17264bf) |
| DG-3 | DG-u | 2 | canvas and text paint the gradient (exports draw through DesignArtwork); Fill section shows GradientEditor | Sources/DesignApp/DesignCanvasMarks.swift, Sources/DesignApp/DesignTextArtwork.swift, Sources/DesignApp/DesignInspectorFill.swift, Tests/AppSnapshotTests/DesignGradientPaintTests.swift | DesignGradientPaintTests | #3978 | in lane |
| DG-6 | DG-u | 2 | snapshots, render budget, journey skipped until DG-7 | Tests/AppSnapshotTests/DesignGradientSnapshots.swift, Tests/AppSnapshotTests/RenderBudgetDesignGradientTests.swift, UITests/DesignJourneyTests+Gradient.swift | RenderBudgetDesignGradientTests | #3978 | in lane |

## Critic reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|
| – | – | – | – | – | – |

## Decisions
- Run act-1a15a9a4e8b-kn6a: the prior run's DG-a builder opened no PR; this run rebuilds DG-a. On dev: GF-1 (#3421) only; GF-2 (editor and shading stubs), GF-5/6/7 (rule, command and SVG bodies) are not merged, so DG-2 uses a plain placeholder (CLAUDE.md, missing SuiteUI component) and DG-u, DG-m wait.
- Branch is lead/design-gradient-fill, not lead/gradient-fill: lead/gradient-fill belongs to another line's lead of the same feature name.
- PRs target dev (CLAUDE.md); main b3011ab9 is an ancestor of dev and only fast-forwards to green dev.
- Rule 22: one PR per slice; each slice's PR opens with its failing test commit.
- GF-2 (SuiteUI GradientEditor) is not on dev: DG-2 uses a plain SwiftUI placeholder (kind picker calling runFill), swapped for GradientEditor when GF-2 merges.

## Open
- DG-u adds DesignInspectorFill.swift beyond DG-3/DG-6's file lists: GradientEditor merged after DG-2, so the swap DG-2 promised rides here.
- none
- Belt's 00:0xZ nudge names lead/gradient-fill and lead/autosave-history; those hold other runs' records (flare pe5i, suiteui c6w5), left untouched. This run's records are lead/design-*.
