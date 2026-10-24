# layer-styles lead record

Issue: #3937 · Packet: docs/blueprints/suiteui/features/layer-styles.md
Run: act-1a16cdcb4a5-trd4 · Session: claude/feature-lead-playbook-9a8kbw · Started: 2026-10-23T15:30Z
Stage: 3 wave check
Base: 6744611877f4baf4a3493a35634fbc8f67ac6e40 (origin/dev)
Next: next check 23:59Z

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| LS-a | SuiteImaging's Style module declares the model, rules, presets, intents, the style command specs with ids and availability, the SVG writer and the program as stubs, the gallery has a layer-style page, and every check is written, disabled. | LS-1, LS-2 | SJ0, MJ-LS | brush-keys:BK-u; gradient-fill:GF-a; suite-imaging:IM-a | yes | 0 | building | – | – |
| LS-u | On the gallery page the panel lists the eight styles with their switches, shows the selected style's rows, applies a preset, and is reachable from the Layers panel's fx button and row menu where that work has landed, within the render budget. | LS-3, LS-4 | LJ1 | LS-a | yes | 0 | planned | – | – |
| LS-m | The rules clamp and default every parameter and keep one effect per kind, every style command records one undo step (a drag one), copy and paste round-trip as JSON, the SVG writer emits a filter for each style it can express and a warning for the rest, and StyleProgram maps a style to the core stack and back. | LS-5, LS-6, LS-7, LS-8 | MJ-LS | LS-a; gradient-fill:GF-m | no | 0 | planned | – | – |
| LS-gpu | The live route draws a styled layer on the GPU in one pass per step and matches the CPU within the core's parity tolerance, within 16 ms p95 for a 2,000 x 2,000 layer. | LS-9, LS-9b | MJ-LS-gpu | LS-m; suite-imaging:IM-m | no | 0 | planned | – | – |
| LS-clip | SuiteKernel finds a clipped layer's base, refuses a clip with no base, and layer.clip and layer.unclip record one step each. | LS-10, LS-11 | KJ-clip |  | no | 0 | building | – | – |
| LS-z | The gallery runs its intents through StyleCommands on a live target with a History, the panel draws its preview through the route, and the feature is built. | LS-12, LS-13 | LJ1, MJ-LS | LS-clip; LS-gpu; LS-m; LS-u | yes | 0 | planned | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| LS-1 | LS-a | 1 | The Style module as stubs, the C4 part, four suites written and disabled | Sources/SuiteImaging/Style/*.swift, Sources/SuiteImaging/Route/StyleRoute.swift, Tests/SuiteImagingTests/{LayerStyleRules,StyleCommands,LayerStyleSVG,StyleProgram}Tests.swift, docs/c4/parts/creative-apps/suite-imaging/imaging-style.json | the suites compile, disabled; ImagingBoundaryTests | #4911 | pr-open |
| LS-2 | LS-a | 2 | Placeholder panel, rows, pasteboard; gallery layer-style page; journey skipped | Sources/SuiteUI/{LayerStylePanel,LayerStyleRows}.swift, Sources/SuiteUI/Gallery/GalleryLayerStyle.swift, Sources/SuiteUI/SuiteGallery.swift, UITests/SuiteJourneyTests+LayerStyle.swift | SJ0 lists layer-style | lead/layer-styles-LS-a-2 @82d118e | stacked, gate pass |
| LS-10 | LS-clip | 1 | ClipRules with its tests; the C4 part | Sources/SuiteKernel/Layers/ClipRules.swift, Tests/SuiteKernelTests/ClipRulesTests.swift, Tests/mutations/SuiteKernel.ClipRules.json | ClipRulesTests | #4903 | pr-open |
| LS-11 | LS-clip | 2 | ClipTarget, ClipCommands (layer.clip, layer.unclip) | Sources/SuiteKernel/Layers/ClipCommands.swift, Tests/SuiteKernelTests/ClipCommandsTests.swift | ClipCommandsTests | lead/layer-styles-LS-clip-11 @511155a | stacked, gate pass, 4/4 mutations |
| LS-5 | LS-m | 2 | StyleRules bodies; LayerStyleRulesTests turned on | Sources/SuiteImaging/Style/StyleRules.swift, its tests, mutation plan | LayerStyleRulesTests | lead/layer-styles-LS-m @c15bf38 | stacked, gate pass, 4/4 mutations |
| LS-3 | see packet | 3 | LS-2 | per packet | per packet | lead/layer-styles-LS-u @e6baf6c | stacked, gate pass |
| LS-6 | see packet | 3 | LS-5 | per packet | per packet | lead/layer-styles-LS-m-6 @b99d9f8 | stacked, gate pass, 4/4 mutations |
| LS-7 | see packet | 3 | LS-5, GF-m | per packet | per packet | lead/layer-styles-LS-m-7 @d364612 | stacked, gate pass, 4/4 mutations |
| LS-4, LS-8..LS-9b, LS-12, LS-13 | see packet | 3+ | per the packet's Tasks table | per packet | per packet | – | planned |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- 2026-10-23: LS-3 built stacked on LS-a-2 (3 files, +359/-26): the panel emits one StyleIntent per control (toggle on change, scrub under one drag token, preset, Done), gradient editor for gradient fills, suite.style.* ids, LayerStylePasteboard on org.creative-apps.layer-style. SwiftUI not compiled here; the batch macOS gate is its first build. Wire: LayerActionBar fx button (effectsPending) and the app row menus Copy/Paste Style are hand-offs. Presets menu stays disabled until LS-5 lands on the same base. PR opens from scratchpad ls3-body.md once LS-2 merges.
- 2026-10-23: LS-7 built stacked on LS-m (3 files, +291/-3): LayerStyleSVG.filter. Shadow angle follows LS-8 (light direction, 135deg 8px -> 5.66,5.66 down-right). Modes outside SVG 1.1 feBlend write their Filter Effects 1 name plus one warning (no linear dodge/burn in core). Own 2-decimal number writer (StrokeSVG.number is internal and writes 4 decimals). Gradient overlay is an feImage of GradientSVG.definition. Bevel is a lighting approximation with a warning; bevel, inner shadow and inner glow output are untested; critics should look. PR opens from scratchpad ls7-body.md once LS-5 merges.
- 2026-10-23: LS-6 built stacked on LS-m (3 files, +295/-33): StyleCommands bodies, edits one setStyle step each with drag passed through, refusals throw unavailable with a reason at run time, paste checks each decoded effect. style.panel with no kind toggles; titles follow the packet; param names stay as LS-1 shipped (kind/on, value/drag). PR opens from scratchpad ls6-body.md (drop its title line) once LS-5 merges.
- 2026-10-23: Wave 3 started: LS-3 (stacked on LS-a-2), LS-6 and LS-7 (stacked on LS-m). GF-m merged (GradientSVG on dev), so LS-7 is unblocked. LS-8/LS-9 still wait the core LE-cpu bump. Stacked tasks get PRs only after their parents merge (rule 22).
- 2026-10-23: LS-2 built stacked on LS-a (6 files, +335/-1): placeholder LayerStylePanel (eight disabled checkboxes with the reason as tooltip), LayerStylePasteboard no-op until LS-3, LayerStyleRows/LayerStyleText, gallery page layer-style, journey steps 1-7 skipped "waits on LS-4". Wire: brush-keys:BK-u. No snapshot PNGs (LS-4 adds suiteui-layer-style*). Unverified API: View.help(_:), .constant binding on a disabled checkbox. PR opens from scratchpad ls2-body.md (drop its title line) once #4911 merges.
- 2026-10-23: LS-5 built stacked on LS-a (3 files, 388 lines): rules clamp/default every parameter, one effect per kind, NaN/inf refused with the field named (clamped leaves it for check); reach computed locally since core LayerStyleStack.reach still returns 0; .sizeCapInclusive rewritten as an exclusive-cap mutation since a >=/> swap on a clamp is equivalent. Its gate scoped tests to origin/lead/layer-styles-LS-a; rerun scripts/ci --changed against origin/dev before opening the PR from scratchpad ls5-body.md once #4911 merges.
- 2026-10-23: LS-11 built stacked on LS-10 (3 files, +202): ClipTarget follows the packet's clipSelection/setClipped(_:name:) shape; adds ClipCommands.selection(of:in:isClipped:) so adopters derive hasBase from ClipRules.base; new help strings "Select a layer first." and "The selected layer isn't clipped."; Mutate SuiteKernel.ClipCommands 4/4. PR opens from scratchpad ls11-body.md once #4903 merges.
- 2026-10-23: LS-1 #4911 (11 files, 399 lines): LayerStyleStack IS on pin 7966e5a, which corrects the earlier decision that core LE-a isn't on it; StyleProgram's stack signatures are in, no Wire line. BevelShape/BevelTechnique are core's; core BlendMode has no linear dodge/burn. The packet's shadow-angle prose contradicts LS-8's acceptance (down-right); tests follow LS-8 and LS-8 fixes the prose. Cut test cases are named in each suite's header for LS-5..LS-8. Gate passed on the third run after two 60s time-limit failures in untouched suites (Onboarding/Home) under load 20-45.
- 2026-10-23: LS-10 #4903 (5 files, +157/-1): kernel-layers' paths narrowed to Layers/Layer*.swift and a new part kernel-clip owns Layers/Clip*.swift (covers LS-11's ClipCommands.swift); description untouched. A future Layers/ file named otherwise needs an owner. Footer stripped.
- 2026-10-23: base is origin/dev and PRs target dev (CLAUDE.md: never target main), as in earlier suiteui records.
- 2026-10-23: unparked under contract-first waits (supervisor, #3937): IM-a #4028, BK-a #4057 merged; gradient-fill built.
- 2026-10-23: this file replaces the photo line's record that sat at docs/leads/layer-styles/ (feature names collide); photo's record lives at docs/leads/photo-layer-styles/ on this branch and on lead/photo-layer-styles, which Belt reads for photo. Mirrored to lead/suiteui-layer-styles.
- 2026-10-23: LS-a is two PRs (LS-1 ~380 lines, LS-2 ~220): together they pass the 400-line cap. LS-2 stacks on LS-1 and opens once LS-1 merges.
- 2026-10-23: core LE-a (LayerStyleStack) isn't on the pin (7966e5a, bump #3825). LS-1 declares every type but leaves StyleProgram's two LayerStyleStack signatures out; LS-8 adds them once the LE bump lands. No core type is copied.

## Wire
- [ ] Wire: core layer-style-engine:LE-a (StyleProgram.stack and style(_ stack:) declared once the bump PR carries LayerStyleStack; LS-8)
- [ ] Wire: brush-keys:BK-u (LS-2 builds on BK-a; SuiteGallery.swift's last owner; swap in when it merges)
- [ ] Wire: gradient-fill:GF-m (LS-7 uses GradientSVG; built)

## Open
- LS-gpu (LS-9) waits core LE-metal and suite-imaging IM-m; LS-8 waits core LE-cpu.
