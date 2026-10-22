# design-shape-tools lead record

Issue: #3440 · Packet: docs/blueprints/design/features/shape-tools.md
Run: act-1a162d0f852-70vb · Started: 2026-10-22T08:56Z (prior run act-1a15abb305f-lc8g shipped DS-a)
Stage: 3 wave 1 built; PRs opening
Base: dev 561ef1c5
Next: open DS-5 (on #4357 DY-m), DS-6 (on DS-5), DS-u (on DS-6); start DS-z (DS-7+DS-8) stacked on DS-u

## Slices
| slice | behavior | tasks | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|
| DS-a | .shape node and tool, ShapeTarget stubs, Shape tool on the palette | DS-1, DS-2 | – | yes | 0 | done (24202fb1; slice-done 39582236683) | 39582236683 | posted |
| DS-u | canvas paints the path, redraws on resize; snapshots, budget | DS-3, DS-4 | DS-a, DS-m | yes | 0 | built | – | – |
| DS-m | ShapeRules.dragged draw as one step; SVG path, catalog, RJ-D35 | DS-5, DS-6 | DS-a, eyedropper:DY-m (#4357) | no | 0 | built | – | – |
| DS-z | journey on live; built | DS-7, DS-8 | DS-u, DS-m | yes | 0 | planned | – | – |

## Tasks
| id | slice | wave | branch | head | PR | state |
|---|---|---|---|---|---|---|
| DS-1/DS-2 | DS-a | – | – | 24202fb1 | #3857 | merged |
| DS-5 | DS-m | 1 | lead/design-shape-tools-DS-5 (on lead/design-eyedropper-DY-m) | 77a418bd | – | built, CI: PASS |
| DS-6 | DS-m | 1 | lead/design-shape-tools-DS-m (on DS-5) | bdd84f62 | – | built, CI: PASS |
| DS-3/DS-4 | DS-u | 1 | lead/design-shape-tools-DS-u (on DS-m) | 933e7552 | – | built, CI: PASS |
| DS-7/DS-8 | DS-z | 2 | – | – | – | planned |

## Critic reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|
| – | – | – | – | – | – |

## Decisions
- Status branch is lead/design-<feature> (record docs/leads/design-<feature>/): lead/<feature> belongs to the SuiteUI lead of the same feature name.
- PRs target dev, not main (CLAUDE.md, lead.md); main b3011ab9 is an ancestor of dev and only fast-forwards to green dev.
- Rule 22: one PR per slice; each slice's PR opens with its failing test commit.
- One lead (this run) holds stroke-style, shape-tools and eyedropper; one wave plan across the three.
- (corrected) Design transform (#3436) is led; DT-a #3751 merged 03:57Z. Earlier note: Design transform (#3436) has no lead running (no lead/design-transform branch, wave.json planned); its DT-a needs gradient-fill:DG-a (building in run act-1a15a9a4e8b-kn6a). shape-tools DS-a and eyedropper DY-m wait on it; this lead does not build another feature's tasks.
- (run act-1a162d0f852-70vb) DS-m split into two PRs (DS-5, DS-6) to stay under 400 lines; both stack on #4357 (DY-m), which shares DesignCanvasEditing.swift, DesignCommandCatalog.swift and design.txt. They retarget to dev when DY-m merges.
- DS-u stacks on DS-m: its macOS paint tests assert DesignNode.path(in:), which DS-5 fills, so a batch gate without DS-m would mark it needs-fix.
- DesignDrawing plan 7/8: the surviving mutant is in placeText (Text drag), untouched by DS-5, and survives on the base too.
- This run first wrote its record to lead/shape-tools by mistake (the SuiteUI lead's branch); restored that branch to its prior head 8c7713f10 at 2026-10-22.

## Open
- DS-6 caveat: an exported line has a fill and no stroke in SVG (invisible); possible finding for the DS-m critics.
