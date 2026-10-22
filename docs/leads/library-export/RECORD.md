# export (Library) lead record

Issue: #4510 · Packet: docs/blueprints/library/features/export.md
Run: act-1a16474bd12-7ncx · Session: claude/feature-lead-playbook-2mbx2f · Started: 2026-10-22T16:30Z (earlier lead: #1554, record on lead/export)
Stage: done (status PR pending)
Base: origin/dev 7e9f260ae8f69dea63663c1bc7ea945c6b1d2f80
Next: the docs-only status PR (export.wave.json status built, feature_issue #4510) through the lane

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| EX-a | contract, fakes, LiveExporter, ExportRunner | EX-1, EX-2, EX-3 | MX1 | - | no | 1 | done, gaps #3091 | https://github.com/qbtrix/creative-apps/actions/runs/39791836264 | - |
| EX-b | File > Export sheet, sRGB JPEG, never overwrites | EX-4, EX-5, EX-6 | J7 | - | yes | 0 | done | https://github.com/qbtrix/creative-apps/actions/runs/39791836264 | - |
| EX-c | PNG, TIFF, HEIC | EX-7, EX-8 | J7F | - | yes | 0 | done | https://github.com/qbtrix/creative-apps/actions/runs/39791836264 | - |
| EX-d | name templates, presets, last settings | EX-9, EX-10, EX-11 | J7N | - | yes | 0 | done | https://github.com/qbtrix/creative-apps/actions/runs/39791836264 | - |
| EX-e | progress, Cancel, Try Again, cropped export | EX-12, EX-13, EX-14 | J7B, P8 | - | no | 0 | done, gaps #3213 #3214 | https://github.com/qbtrix/creative-apps/actions/runs/39791836264 | - |
| EX-f | XMP sidecar | EX-15, EX-16, EX-17 | J7S | - | no | 0 | done | https://github.com/qbtrix/creative-apps/actions/runs/39791836264 | - |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| EX-1..EX-17 | all | - | see lead/export:docs/leads/export/RECORD.md | see export.wave.json | see packet | #3090 ... #3387 | merged under #1554 |
| status | EX-f | - | export.wave.json status built, feature_issue #4510 | docs/blueprints/library/features/export.wave.json | scripts/ci | - | gating |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- Belt reopened export as #4510. Every EX task merged under #1554 (contact sheet run 39363625797), but export.wave.json still read status planned, feature_issue "file when ready". This run marks it built in one docs-only PR and re-posts the slice lines on #4510.
- Proof run: scoped library run 39791836264 (dev 721ac8e9, success). It contains every export file on dev.
- Base and PR target are dev, not main. The brief names main, but main is far behind dev, the packets exist only on dev, and the lane retargets PRs to dev (CLAUDE.md).
- Record branch is lead/library-export. lead/export holds #1554's record, and the brief's lead/tone-controls and lead/file-flow are other leads' live records (suiteui #4520, suite #3480). This run's three Library records live on lead/library-export, lead/library-tone-controls and lead/library-file-flow, as earlier Library leads did.

## Open
- 2026-10-22T16:45Z: Belt-Slice-Done EX-a..EX-f and Belt-Contact-Sheet posted on #4510 on run 39791836264. The proxy footer was stripped from each comment. 0 open findings.
