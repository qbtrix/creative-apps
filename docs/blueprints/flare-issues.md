# Flare blueprint: tasks to issues

Every task in section 7 of `docs/blueprints/flare.md` is one issue, filed on
2026-10-13 after the blueprint merged in #239. This file maps each task id to
its issue. Issues in creative-core are written `qbtrix/creative-core#n`.
"Edited" means the task was appended to an issue that already existed, so
nothing was filed twice; its earlier spec stays above the blueprint section,
and the blueprint section wins where they differ.

Labels: SuiteUI tasks carry `line:suiteui`, `needs-ui`, `track:ui`. Flare
tasks carry `line:flare`, one `track:*` label and exactly one of `flare-ui`,
`flare-logic` or `flare-integrate`. creative-core tasks carry `suite`,
`needs-core` and `track:logic` (DOC-2 carries `documentation` instead of
`track:logic`). QH-1, QH-2, QH-2b and QH-4 sit in the SuiteUI section of
the blueprint, so they are on `line:suiteui`; QH-5, QH-6 and QH-7 are Flare
UI tasks and QH-3 is a Flare logic task.

## 7.0 Docs (creative-core)

| Task | Issue | Labels | Filed as |
|---|---|---|---|
| DOC-2 | qbtrix/creative-core#212 | `suite`, `needs-core`, `documentation` | new |

## 7.1 Logic: contracts, fakes and workspace

| Task | Issue | Labels | Filed as |
|---|---|---|---|
| LM-0a1 | #314 | `line:flare`, `track:logic`, `flare-logic` | new |
| LM-0a1b | #315 | `line:flare`, `track:logic`, `flare-logic` | new |
| LM-0a2 | #316 | `line:flare`, `track:logic`, `flare-logic` | new |
| LM-0a2b | #317 | `line:flare`, `track:logic`, `flare-logic` | new |
| LM-0a3 | #318 | `line:flare`, `track:logic`, `flare-logic` | new |
| LM-0a4 | #319 | `line:flare`, `track:logic`, `flare-logic` | new |
| LM-0b1 | #320 | `line:flare`, `track:logic`, `flare-logic` | new |
| LM-0b2 | #321 | `line:flare`, `track:logic`, `flare-logic` | new |
| LM-0c1 | #322 | `line:flare`, `track:logic`, `flare-logic` | new |
| LM-0c2 | #323 | `line:flare`, `track:logic`, `flare-logic` | new |
| LM-0c3 | #324 | `line:flare`, `track:logic`, `flare-logic` | new |
| LM-0c4 | #325 | `line:flare`, `track:logic`, `flare-logic` | new |
| LM-0c5 | #326 | `line:flare`, `track:logic`, `flare-logic` | new |
| LM-15 | #327 | `line:flare`, `track:logic`, `flare-logic` | new |
| QH-3 | #328 | `line:flare`, `track:logic`, `flare-logic` | new |

## 7.2 UI: SuiteUI and harnesses

| Task | Issue | Labels | Filed as |
|---|---|---|---|
| S0 | #329 | `line:suiteui`, `needs-ui`, `track:ui` | new |
| QH-1 | #330 | `line:suiteui`, `needs-ui`, `track:ui` | new |
| QH-2 | #331 | `line:suiteui`, `needs-ui`, `track:ui` | new |
| QH-2b | #332 | `line:suiteui`, `needs-ui`, `track:ui` | new |
| QH-4 | #333 | `line:suiteui`, `needs-ui`, `track:ui` | new |
| S1 | #334 | `line:suiteui`, `needs-ui`, `track:ui` | new |
| S2 | #335 | `line:suiteui`, `needs-ui`, `track:ui` | new |
| S3 | #336 | `line:suiteui`, `needs-ui`, `track:ui` | new |
| S4 | #337 | `line:suiteui`, `needs-ui`, `track:ui` | new |
| S5 | #338 | `line:suiteui`, `needs-ui`, `track:ui` | new |
| S6 | #339 | `line:suiteui`, `needs-ui`, `track:ui` | new |
| S7 | #340 | `line:suiteui`, `needs-ui`, `track:ui` | new |
| S8 | #341 | `line:suiteui`, `needs-ui`, `track:ui` | new |
| S9 | #342 | `line:suiteui`, `needs-ui`, `track:ui` | new |
| S10 | #62 | `line:suiteui`, `needs-ui`, `track:ui` | edited |
| S11 | #63 | `line:suiteui`, `needs-ui`, `track:ui` | edited |
| S12 | #273 | `line:suiteui`, `needs-ui`, `track:ui` | edited |
| S13 | #343 | `line:suiteui`, `needs-ui`, `track:ui` | new |
| S14 | #344 | `line:suiteui`, `needs-ui`, `track:ui` | new |
| S15 | #146 | `line:suiteui`, `needs-ui`, `track:ui` | edited |
| S16 | #345 | `line:suiteui`, `needs-ui`, `track:ui` | new |

## 7.3 UI: Flare on fakes

| Task | Issue | Labels | Filed as |
|---|---|---|---|
| F1a | #346 | `line:flare`, `track:ui`, `flare-ui` | new |
| F1b | #347 | `line:flare`, `track:ui`, `flare-ui` | new |
| F2 | #15 | `line:flare`, `track:ui`, `flare-ui` | edited |
| F3a | #12 | `line:flare`, `track:ui`, `flare-ui` | edited |
| F3b | #204 | `line:flare`, `track:ui`, `flare-ui` | edited |
| F3c | #375 | `line:flare`, `track:ui`, `flare-ui` | new |
| F4a | #203 | `line:flare`, `track:ui`, `flare-ui` | edited |
| F4b | #390 | `line:flare`, `track:ui`, `flare-ui` | new |
| F5 | #391 | `line:flare`, `track:ui`, `flare-ui` | new |
| F6a | #186 | `line:flare`, `track:ui`, `flare-ui` | edited |
| F6b | #348 | `line:flare`, `track:ui`, `flare-ui` | new |
| F6c | #349 | `line:flare`, `track:ui`, `flare-ui` | new |
| F7a | #11 | `line:flare`, `track:ui`, `flare-ui` | edited |
| F7b | #376 | `line:flare`, `track:ui`, `flare-ui` | new |
| F8 | #377 | `line:flare`, `track:ui`, `flare-ui` | new |
| F9 | #378 | `line:flare`, `track:ui`, `flare-ui` | new |
| F10 | #379 | `line:flare`, `track:ui`, `flare-ui` | new |
| F11a | #350 | `line:flare`, `track:ui`, `flare-ui` | new |
| F11b | #351 | `line:flare`, `track:ui`, `flare-ui` | new |
| F12a | #14 | `line:flare`, `track:ui`, `flare-ui` | edited |
| F12b | #380 | `line:flare`, `track:ui`, `flare-ui` | new |
| F13a | #352 | `line:flare`, `track:ui`, `flare-ui` | new |
| F13b | #353 | `line:flare`, `track:ui`, `flare-ui` | new |
| F14 | #381 | `line:flare`, `track:ui`, `flare-ui` | new |
| F15a | #354 | `line:flare`, `track:ui`, `flare-ui` | new |
| F15b | #355 | `line:flare`, `track:ui`, `flare-ui` | new |
| F16a | #382 | `line:flare`, `track:ui`, `flare-ui` | new |
| F16b | #383 | `line:flare`, `track:ui`, `flare-ui` | new |
| F17a | #205 | `line:flare`, `track:ui`, `flare-ui` | edited |
| F17b | #392 | `line:flare`, `track:ui`, `flare-ui` | new |
| F17c | #393 | `line:flare`, `track:ui`, `flare-ui` | new |
| F18 | #384 | `line:flare`, `track:ui`, `flare-ui` | new |
| QH-5 | #394 | `line:flare`, `track:ui`, `flare-ui` | new |
| QH-6 | #395 | `line:flare`, `track:ui`, `flare-ui` | new |
| QH-7 | #396 | `line:flare`, `track:ui`, `flare-ui` | new |

## 7.4 Logic: engine gaps (creative-core)

| Task | Issue | Labels | Filed as |
|---|---|---|---|
| LC-1 | qbtrix/creative-core#213 | `suite`, `needs-core`, `track:logic` | new |
| LC-2 | qbtrix/creative-core#214 | `suite`, `needs-core`, `track:logic` | new |
| LC-3 | qbtrix/creative-core#215 | `suite`, `needs-core`, `track:logic` | new |
| LC-4 | qbtrix/creative-core#182 | `suite`, `needs-core`, `track:logic` | edited |
| LC-5 | qbtrix/creative-core#171 | `suite`, `needs-core`, `track:logic` | edited |
| LC-6 | qbtrix/creative-core#173 | `suite`, `needs-core`, `track:logic` | edited |
| LC-7 | qbtrix/creative-core#216 | `suite`, `needs-core`, `track:logic` | new |
| LC-8 | qbtrix/creative-core#217 | `suite`, `needs-core`, `track:logic` | new |
| LC-9 | qbtrix/creative-core#218 | `suite`, `needs-core`, `track:logic` | new |
| LC-10 | qbtrix/creative-core#219 | `suite`, `needs-core`, `track:logic` | new |
| LC-11a | qbtrix/creative-core#220 | `suite`, `needs-core`, `track:logic` | new |
| LC-11b | qbtrix/creative-core#221 | `suite`, `needs-core`, `track:logic` | new |
| LC-11c | qbtrix/creative-core#222 | `suite`, `needs-core`, `track:logic` | new |
| LC-11d | qbtrix/creative-core#223 | `suite`, `needs-core`, `track:logic` | new |
| LC-11e | qbtrix/creative-core#224 | `suite`, `needs-core`, `track:logic` | new |
| LC-12 | qbtrix/creative-core#225 | `suite`, `needs-core`, `track:logic` | new |
| LC-12b | qbtrix/creative-core#226 | `suite`, `needs-core`, `track:logic` | new |
| LC-13 | qbtrix/creative-core#227 | `suite`, `needs-core`, `track:logic` | new |
| LC-14 | qbtrix/creative-core#228 | `suite`, `needs-core`, `track:logic` | new |

## 7.5 Logic: live conformances and platform files

| Task | Issue | Labels | Filed as |
|---|---|---|---|
| LM-1 | #356 | `line:flare`, `track:logic`, `flare-logic` | new |
| LM-2 | #357 | `line:flare`, `track:logic`, `flare-logic` | new |
| LM-3 | #206 | `line:flare`, `track:logic`, `flare-logic` | edited |
| LM-4 | #13 | `line:flare`, `track:logic`, `flare-logic` | edited |
| LM-5 | #358 | `line:flare`, `track:logic`, `flare-logic` | new |
| LM-6 | #359 | `line:flare`, `track:logic`, `flare-logic` | new |
| LM-7 | #360 | `line:flare`, `track:logic`, `flare-logic` | new |
| LM-8 | #361 | `line:flare`, `track:logic`, `flare-logic` | new |
| LM-9 | #362 | `line:flare`, `track:logic`, `flare-logic` | new |
| LM-10 | #363 | `line:flare`, `track:logic`, `flare-logic` | new |
| LM-11 | #364 | `line:flare`, `track:logic`, `flare-logic` | new |
| LM-12 | #365 | `line:flare`, `track:logic`, `flare-logic` | new |
| LM-13a | #366 | `line:flare`, `track:logic`, `flare-logic` | new |
| LM-13b | #367 | `line:flare`, `track:logic`, `flare-logic` | new |
| LM-14 | #369 | `line:flare`, `track:logic`, `flare-logic` | new |
| LA-0 | #370 | `line:flare`, `track:logic`, `flare-logic` | new |
| LA-1 | #371 | `line:flare`, `track:logic`, `flare-logic` | new |
| LA-2 | #372 | `line:flare`, `track:logic`, `flare-logic` | new |
| LA-3 | #373 | `line:flare`, `track:logic`, `flare-logic` | new |

## 7.6 Integrate

| Task | Issue | Labels | Filed as |
|---|---|---|---|
| IN-1 | #397 | `line:flare`, `track:integrate`, `flare-integrate` | new |
| IN-2 | #385 | `line:flare`, `track:integrate`, `flare-integrate` | new |
| IN-3 | #386 | `line:flare`, `track:integrate`, `flare-integrate` | new |
| IN-4 | #398 | `line:flare`, `track:integrate`, `flare-integrate` | new |
| IN-5 | #387 | `line:flare`, `track:integrate`, `flare-integrate` | new |
| IN-6 | #388 | `line:flare`, `track:integrate`, `flare-integrate` | new |
| IN-7 | #374 | `line:flare`, `track:integrate`, `flare-integrate` | new |
| IN-8 | #389 | `line:flare`, `track:integrate`, `flare-integrate` | new |
| IN-9 | #399 | `line:flare`, `track:integrate`, `flare-integrate` | new |

## Existing issues folded in without a task of their own

Each got a comment pointing at the task that covers it. The task's PR
should close it too (`Closes #n`).

- #6 (SuiteUI `CanvasSurface` content and zoom): F3a, #12
- #61 (last ruler label clipped) and #219 (long-timeline snapshots blank): S10, #62
- #287 (Flare controls with no accessibility identifier): F1b, #347
- qbtrix/creative-core#101 (the Q5 parent): its Q5c and Q5e parts are LC-5, qbtrix/creative-core#171, and LC-6, qbtrix/creative-core#173

## Dependencies with no issue

- QH-7 (#396) waits for ten green CI runs of the perf journeys.
- IN-8 (#389) waits for the suite model provider (Phase 3 of the suite plan), which has no issue yet.

## Tasks that start from code already on dev

The blueprint read `main` at d1e57a3. Dev has since gained the easing editor
and its SuiteUI parts, so these issues say what to reuse instead of building
a second copy:

- LM-0a1 (#314): the name clash is resolved. Section 6.2's per-keyframe
  protocol is `KeyframeEasing` (#368); dev's `EasingEditing` stays the
  window-level editor protocol, and both use dev's `EasingPreset`.
- LM-0b2 (#321): `FakeEasing` is a new `KeyframeEasing` fake in
  `Sources/FlareModel/Fakes/FakeEasing.swift`, the one `FlareServices.easing`
  holds (section 6.3). It may reuse `EasingPreset` and sample
  `Easing.value(at:)` as `FakeEasingEditing` does, but
  `Sources/FlareModel/FakeEasingEditing.swift` stays as it is: it is the
  `EasingEditing` stand-in for `FlareEasingInspector` and
  `EasingEditingContractTests`, not the services fake.
- LM-6 (#359): `LiveEasing` conforms to `KeyframeEasing`. It may wrap or
  share `FlareWorkspace`'s `SetKeyframeEasing` code; `FlareWorkspace` keeps
  its `EasingEditing` conformance.

No script regenerates issue bodies from this file. When an entry here
changes, edit the issue body by hand in the same change: the LM-0b2 and LM-6
entries above were copied into #321 and #359 on 2026-10-13 (#454).
- F9 (#378): build the popover from `FlareEasingInspector`, and keep one
  easing editor, not two.
- S1 (#334), S5 (#338), S13 (#343): `StudioScrubRow`, `ChoiceChips` and
  `CurveEditor` already exist.
- F1a (#346), F2 (#15), LM-0a2 (#316): keep New Sample Animation working and
  extend `FlareCommands.swift`.
