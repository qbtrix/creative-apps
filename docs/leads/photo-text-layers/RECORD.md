# photo text-layers lead record

Issue: #3785 · Packet: docs/blueprints/photo/features/text-layers.md
Run: act-1a15e2da54d-qlg1 · Session: claude/feature-lead-playbook-t69dpt · Started: 2026-10-21T11:40Z
Stage: 3 wave 2 (TX-u)
Base: origin/dev ded2ca57a
Next: TX-u (TX-3 Type tool + text box, TX-4 if it fits) stacked on #4036

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| TX-a | text layer kind, TextStyleTarget adapter, text.add / text.set-words stubs, Model checks disabled | TX-1, TX-2 | MJ-TX | TS-a, ST-a | no | 0 | PR #4036 (fast-lane, gate PASS 76f1e990b) | – | – |
| TX-u | Type tool, text box on canvas, inspector style row on stubs | TX-3, TX-4 | PJ-TX | TX-a | yes | 0 | next | – | – |
| TX-m | rasterize, edit as one undo step, .ora text attribute | TX-5, TX-6 | MJ-TX | TX-a, PF-m, TS-m | no | 0 | – | – | – |
| TX-z | live end to end, RJ-P02, built | TX-7, TX-8 | PJ-TX, MJ-TX | TX-u, TX-m, PF-z, ST-z | yes | 0 | – | – | – |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- Lead branch lead/photo-text-layers, record in docs/leads/photo-text-layers/, as for gradient-fill and export-pack (lead/text-layers names could collide with other lines).
- TX-a starts before suite shell-text ST-a is on dev: the stubs need only SuiteKernel's TextStyleTarget, TextCommands and TextStyleRules (TS-a, on dev). Departure from the packet's waits, recorded here.
- The journey stub (UITests/PhotoJourneyTests+Text.swift) holds PJ-TX's steps as doc comments and skips, to keep the TX-a PR under 400 lines.

## Open
