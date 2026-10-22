# photo text-layers lead record

Issue: #3785 · Packet: docs/blueprints/photo/features/text-layers.md
Run: act-1a15e2da54d-qlg1 · Session: claude/feature-lead-playbook-t69dpt · Started: 2026-10-21T11:40Z
Stage: 4 done (contact sheet posted 2026-10-22T21:31Z)
Base: origin/dev be18ab629
Next: beta-hardening lane verifies TX-a TX-u TX-m TX-z

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| TX-a | text layer kind, TextStyleTarget adapter, text.add / text.set-words stubs, Model checks disabled | TX-1, TX-2 | MJ-TX | TS-a, ST-a | no | 0 | done (#4036) | https://github.com/qbtrix/creative-apps/actions/runs/39638325928 | – |
| TX-u | Type tool, text box on canvas, inspector style row on stubs | TX-3, TX-4 | PJ-TX | TX-a | yes | 0 | done (#4053, #4424) | https://github.com/qbtrix/creative-apps/actions/runs/39710840412 | – |
| TX-m | rasterize, edit as one undo step, .ora text attribute | TX-5, TX-6 | MJ-TX | TX-a, PF-m, TS-m | no | 0 | done (#4059 and TX-5) | https://github.com/qbtrix/creative-apps/actions/runs/39710840412 | – |
| TX-z | live end to end, RJ-P02, built | TX-7, TX-8 | PJ-TX, MJ-TX | TX-u, TX-m, PF-z, ST-z | yes | 0 | done (#4441, #4584 feature-done) | https://github.com/qbtrix/creative-apps/actions/runs/39854353256 | – |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- Lead branch lead/photo-text-layers, record in docs/leads/photo-text-layers/, as for gradient-fill and export-pack (lead/text-layers names could collide with other lines).
- TX-a starts before suite shell-text ST-a is on dev: the stubs need only SuiteKernel's TextStyleTarget, TextCommands and TextStyleRules (TS-a, on dev). Departure from the packet's waits, recorded here.
- The journey stub (UITests/PhotoJourneyTests+Text.swift) holds PJ-TX's steps as doc comments and skips, to keep the TX-a PR under 400 lines.

- TX-u ships as two stacked PRs: TX-3 (Type tool box, #4053, 316 lines) and TX-4 (inspector style row); both in one PR would pass 400 lines.
- A golden (`Tests/AfterGlowCLITests/Golden/apps/photo.list-commands.json`) lists every tool command; a new PhotoTool adds a line there.

- TX-6 ships before TX-5: the .ora attribute needs only the TX-1 kind, not rasterizing. Text is read back only from stack.xml's afterglow:text (document.json keeps kind pixels), so a file stripped of the attribute reads as pixels.
- Text layers are still left out of PhotoLayerComposite (composite and merged image); TX-5 adds them when it rasterizes.

## Open
- #4036 (TX-a) Linux check red at 76f1e990: CommandPathTests appMatchesItsBaseline(photo) on Sources/PhotoApp/PhotoPlace.swift:36, not TX code; the branch predates #4008 (909d29b3f) which fixed it on dev. Merged origin/dev into TX-1, gate rerun, new head pushed for a fresh lane check.
- TX-4 blocked: needs suiteui TextStyleRows (TS-a/TS-u) on dev.
- TX-5 blocked: needs TS-m (text command bodies) and shell-text ST-z (GlyphRasterizing) on dev.
- TS and ST slices belong to the text-style (#3779) and shell-text (#3725) leads; no needs-ui issue filed for TextStyleRows, it is TS-u's own deliverable.
