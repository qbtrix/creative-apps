# Lead record: design/layer-styles (#3858)

Run: act-1a15d1af4b1-45qq (started 2026-10-21T06:22:42Z). Packet: docs/blueprints/design/features/layer-styles.md (v3, slices DL-a, DL-u, DL-m, DL-z).
Branch named lead/design-layer-styles, not the packet's lead/layer-styles, so it can't clash with Photo's and Halo's layer-styles leads.
PRs target dev (CLAUDE.md), not main.

## Slices

| slice | tasks | status | PRs | run |
|---|---|---|---|---|
| DL-a | DL-1, DL-2 | waiting | – | – |
| DL-u | DL-3, DL-4 | waiting (DL-a) | – | – |
| DL-m | DL-5, DL-6, DL-7 | waiting (DL-a, LS-m, DX-m) | – | – |
| DL-z | DL-8, DL-9 | waiting (DL-u, DL-m, LS-gpu, DP-z) | – | – |

## Waits (re-read 2026-10-21T06:22:42Z)

- suiteui layer-styles LS-a: no feature issue filed; suiteui/features/layer-styles.wave.json status planned. No LayerStyle, LayerStyleTarget, StyleCommands or LayerStyleSVG on dev.
- suite-imaging IM-a (IM-1 links SuiteImaging into DesignModel): #3715 open, not merged.
- design-seams-2: planned, no feature issue (owns DesignNode, DesignCanvas, DesignObjectMenu, DesignWindow first).
- pen-paths DP-m (#3517): open; it last owns DesignSVG, DesignCommandCatalog and the command ids.
- export-pack DX-m (#3467): open (DL-7).

DL-1 can't be written without LS-a's types (rule 20: no Design shadow type), so no slice starts this run.

## Reviews

| slice | lens | findings |
|---|---|---|

## Decisions

- 2026-10-21T06:22:42Z: every slice is blocked on cross-line contracts that aren't filed or merged. The waits are recorded here and a supervisor question is on #3858.
