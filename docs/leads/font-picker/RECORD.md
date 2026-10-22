# font-picker lead record

Issue: #4507 · Packet: docs/blueprints/suiteui/features/font-picker.md
Run: act-1a16474bd3a-i9ae · Session: session_01Rid1ErRRerebigzwJKJtpV · Started: 2026-10-22T16:36Z
Stage: 3 (wave 1)
Base: 7e9f260ae8f69dea63663c1bc7ea945c6b1d2f80 (origin/dev)
Next: FP-a (FP-1 + FP-2, one slice PR, test commit first)

## Slices

| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| FP-a | FontPick, FontPickerRules and FontPicker declared as stubs; gallery page; checks written, disabled | FP-1, FP-2 | SJ0 | EK-u (built), CC-u (built), shell-text:ST-a (built: FontFamily/FontFace in SuiteModel) | true | 0 | building | – | – |
| FP-u | the picker lists, filters and previews families within the render budget | FP-3, FP-4 | testFontPickerPicksAFace | FP-a | true | 0 | planned | – | – |
| FP-m | rules: filter, face order, nearest face | FP-5, FP-8 | FJ-m | FP-a | false | 0 | planned | – | – |
| FP-z | live families; feature built | FP-6, FP-7 | testFontPickerPicksAFace | FP-u, FP-m | true | 0 | planned | – | – |

## Tasks

| id | slice | wave | state | PR |
|---|---|---|---|---|
| FP-1 | FP-a | 1 | building | – |
| FP-2 | FP-a | 1 | building | – |
| FP-3 | FP-u | 2 | planned | – |
| FP-4 | FP-u | 2 | planned | – |
| FP-5 | FP-m | 2 | planned | – |
| FP-8 | FP-m | 2 | planned | – |
| FP-6 | FP-z | 3 | planned | – |
| FP-7 | FP-z | 3 | planned | – |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- Base is origin/dev, PRs target dev: the brief names main, but CLAUDE.md says never branch from or target main (the lane retargets main PRs to dev); main lacks the packets.
- Earlier runs (#3730) parked on shell-text ST-a; FontFamily and FontFace are now in Sources/SuiteModel/Values/Text.swift on dev, so FP-a starts.
- Slice branches are lead/font-picker-<slice> (lead/font-picker blocks lead/font-picker/<slice>).
- One combined wave plan across font-picker, shared-raw and clipboard-interop (rule 19).

## Open
- FP-m's tests and mutations live in SuiteUITests (macOS only): its Mutate line needs a Mac pass.
