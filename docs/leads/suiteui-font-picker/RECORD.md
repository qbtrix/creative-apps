# font-picker lead record

Issue: #3730 · Packet: docs/blueprints/suiteui/features/font-picker.md
Run: act-1a15c07cabb-mtlw · Session: e6bf0eb1-e2b8-518f-a36a-05b7f66e9a98 · Started: 2026-10-21T01:21:08Z
Stage: parked (blocked on shell-text ST-a, #3725)
Base: 2ab0eb96320db973b5aad0644449ee5ed3980ab9
Next: none this run. The supervisor relaunches font-picker once shell-text ST-a is on dev; FP-1 starts then.

## Slices

| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| FP-a | FontPick, FontPickerRules and FontPicker declared; checks written, disabled | FP-1, FP-2 | – | editor-kernel:EK-u (built), command-catalog:CC-u (built), shell-text:ST-a (planned) | true | 0 | blocked | – | – |
| FP-u | the picker lists, filters and previews families | FP-3, FP-4 | – | FP-a | true | 0 | planned | – | – |
| FP-m | rules: filter, face order, nearest face | FP-5, FP-8 | – | FP-a | false | 0 | planned | – | – |
| FP-z | live families; feature built | FP-6, FP-7 | – | FP-u, FP-m | true | 0 | planned | – | – |

## Tasks

| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| FP-1 | FP-a | – | see packet | see packet | see packet | – | blocked (ST-a) |
| FP-2 | FP-a | – | see packet | see packet | see packet | – | blocked |
| FP-3 | FP-u | – | see packet | see packet | see packet | – | planned |
| FP-4 | FP-u | – | see packet | see packet | see packet | – | planned |
| FP-5 | FP-m | – | see packet | see packet | see packet | – | planned |
| FP-8 | FP-m | – | see packet | see packet | see packet | – | planned |
| FP-6 | FP-z | – | see packet | see packet | see packet | – | planned |
| FP-7 | FP-z | – | see packet | see packet | see packet | – | planned |

## Reviews

| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions

- 2026-10-21T01:21:08Z: integration base is dev (7277a83a), not main.
- 2026-10-21T01:21:08Z: FP-1 waits on shell-text ST-a: no lead/shell-text branch, no Sources/SuiteModel/Values/Text.swift, no FontFamily/FontFace in Sources. Nothing in this feature can start; recorded on #3730.

- 2026-10-21T02:22Z: three identical blocked polls for shell-text ST-a; rule 23 question posted on #3730 (comment 6306414555) offering wait / local FontPick / park. Waiting (a) until answered.

- 2026-10-21T02:44Z: supervisor answered (c) on #3730: park font-picker, no throwaway FontPick type; shell-text #3725 and shell-media SM-a go in the next shift. Parked. Read the reply's "release this run" as about font-picker; adopt-kernel-autosave and text-style continue (no `Belt released this run.` message).

- 04:08Z heartbeat: still parked on shell-text #3725 (open).

- 04:36Z heartbeat: still parked on shell-text #3725.

- 05:04Z heartbeat: still parked on shell-text #3725.

- 05:30Z heartbeat: still parked on shell-text #3725.

- 06:03Z heartbeat: still parked on shell-text #3725.

- 06:30Z heartbeat: still parked on shell-text #3725.

- 2026-10-21T06:58Z heartbeat: parked on shell-text #3725, no change.

- 2026-10-21T07:24Z heartbeat: parked on shell-text #3725, no change.

- 2026-10-21T07:53Z heartbeat: parked on shell-text #3725, no change.

- 2026-10-21T08:33Z heartbeat: parked on shell-text #3725, no change.

- 2026-10-21T09:01Z heartbeat: parked on shell-text #3725.

- 2026-10-21T09:29Z heartbeat: parked on shell-text #3725.

- 2026-10-21T10:02Z heartbeat: parked on shell-text #3725.

- 2026-10-21T10:36Z heartbeat: Parked on shell-text #3725 (ST-a not merged).

## Open

- shell-text ST-a not started (wave planned, no feature issue filed).
