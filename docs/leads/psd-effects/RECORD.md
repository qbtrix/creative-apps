# psd-effects lead record

Issue: #4521 · Packet: docs/blueprints/photo/features/psd-effects.md
Run: act-1a164697363-4fnm · Session: claude/feature-lead-photo-features-kilpzc · Started: 2026-10-22T16:00Z
Stage: 3 wave 1
Base: 7e9f260 (origin/dev)
Next: PS-1 builder running (belt/psd-effects/ps-1, with the opening(_:) stub); then re-read PK-m and PX-m for PS-2

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| PS-a | real `lfx2` corpus, PSD-open tests and RJ-P46 disabled; `.psd` in the open types on a refusing stub | PS-1, PS-2 | MJ-PS | masks-clipping:PK-m, export-pack:PX-m (PS-2 only, file ownership); file-flow:PF-m (done) | yes | 0 | building | – | – |
| PS-m | PSD opens as layers with masks, clipping, effects as styles; Linear Dodge/Burn round-trip `.ora`; drops named | PS-3, PS-4 | MJ-PS | PS-a; core LE-psd bump, suiteui LS-m (cross-line) | no | 0 | waiting | – | – |
| PS-z | known issues gone from the fidelity gate, RJ-P46 passes, built | PS-5, PS-6 | MJ-PS | PS-m; masks-clipping:PK-z (PS-6) | no | 0 | waiting | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| PS-1 | PS-a | 1 | gen.py writes a real `lfx2` descriptor and badge-effects.psd; PhotoPSDOpenTests disabled; RJ-P46 job disabled | Tests/import_fidelity/gen.py, Tests/import_fidelity/manifest.json, Tests/import_fidelity/psd/layer_effects.psd, Tests/PhotoModelTests/ImportFidelityPSDTests.swift, Tests/PhotoModelTests/PhotoPSDOpenTests.swift, Tests/RealJobs/photo/psd-effects/psd-effects.jobs.json, Tests/RealJobs/photo/psd-effects/input/badge-effects.psd | gen.py deterministic; suite compiles disabled; ImportFidelityPSDTests; scripts/jobs check | – | building |
| PS-2 | PS-a | 2+ | `opening(_:)` stub; `.psd` in openExtensions and the Open panel | Sources/PhotoModel/PhotoLayered+Imaging.swift, Sources/PhotoModel/PhotoHeadless.swift, Sources/PhotoModel/PhotoDocumentFile.swift, Sources/PhotoApp/PhotoWindow+File.swift | Photo Model tests; a `.psd` refuses with the stub's reason | – | waiting (PK-m, PX-m) |
| PS-3 | PS-m | – | `opening(_:)` body; PhotoPSDOpenTests on but blendKeys | Sources/PhotoModel/PhotoLayered+Imaging.swift, Tests/PhotoModelTests/PhotoPSDOpenTests.swift, Tests/mutations/PhotoModel.PhotoLayered+Imaging.json | PhotoPSDOpenTests | – | waiting (PS-1, PS-2, LE-psd, LS-m) |
| PS-4 | PS-m | – | Linear Dodge/Burn in `.ora`; blendKeys on | Sources/PhotoModel/PhotoDocumentFile.swift, Tests/PhotoModelTests/PhotoBlendModeTests.swift, Tests/mutations/PhotoModel.PhotoDocumentFile.json | PhotoBlendModeTests | – | waiting (PS-3) |
| PS-5 | PS-z | – | drop #3496/#3497 known issues | Tests/import_fidelity/gen.py, Tests/import_fidelity/manifest.json, Tests/import_fidelity/psd/blend_extended.psd | ImportFidelityPSDTests | – | waiting (PS-3, PS-4) |
| PS-6 | PS-z | – | photo.md row; status built; feature-done | docs/blueprints/photo.md, docs/blueprints/photo/features/psd-effects.wave.json | scripts/waves render --dry-run | – | waiting (PS-5, PK-z) |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- Worked from `origin/dev` 7e9f260, not `main` (verified at 0dd23d65): main is far behind and lacks the packets; CLAUDE.md says branch from and target dev.
- PS-1 has no waits (tests and corpus only), so it ships now as PS-a's first PR. PS-a's waits (PK-m, PX-m) hold only PS-2, whose `PhotoDocumentFile.swift` and `PhotoHeadless.swift` those slices also touch; PS-2 folds into a later PS-a PR once they merge.
- PS-1 carries the new `PhotoLayered+Imaging.swift` `opening(_:)` stub (a new file, refusing with "Opening PSD files is not built yet (PS-3).") so the disabled PhotoPSDOpenTests compile; the `.psd` routing of PS-2 stays for a later PS-a PR.
- Wave 1 is combined with masks-clipping PK-1 (disjoint files: tests/corpus vs PhotoModel mask/catalog files).

## Open
- PS-2 waits on masks-clipping:PK-m (this run) and export-pack:PX-m (lead blocked on SM-w).
- PS-3 waits on the core LE-psd bump (not on the pin) and suiteui LS-m (#3937, `waiting-on-prereq`).
