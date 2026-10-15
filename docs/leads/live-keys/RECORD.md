# live-keys lead record

Issue: #799 · Packet: docs/blueprints/flare/features/live-keys.md
Run: act-1a13d0020ff-4x51 · Session: cse_01BKSKFkuR1aFXhWhZAhsegU · Started: 2026-10-15T00:00Z
Stage: 3 wave 1
Base: c111439f2255b6691c16c8c053cf6f956a981c69
Next: wait for wave 1 PRs (KY-1, KY-5, KY-8) to merge, then start wave 2 on the new origin/dev

## Tasks
| id | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|
| KY-1 | 1 | `LiveProperties` struct + `properties` reads (values, key states, Mixed, any owner) | Live/LiveProperties.swift, LivePropertiesTests.swift | LivePropertiesTests | | building |
| KY-5 | 1 | `LiveKeyframes` struct + `rows`, `labels` | Live/LiveKeyframes.swift, LiveKeyframesTests.swift | LiveKeyframesTests | | building |
| KY-8 | 1 | `LiveEasing` owner path for symbol layers | Live/LiveEasing.swift, LiveEasingTests.swift | LiveEasingTests | | building |
| KY-2 | 2 | `setValue` (section 2 rule, NaN refused, merged scrub) | Live/LiveProperties.swift, LivePropertiesSetTests.swift | LivePropertiesSetTests | | waiting KY-1 |
| KY-6 | 2 | `moveKeys`, `removeKeys` | Live/LiveKeyframes+Edit.swift, LiveKeyframesEditTests.swift | LiveKeyframesEditTests | | waiting KY-5 |
| KY-3 | 3 | `toggleAnimated`, `toggleKey` | Live/LiveProperties+Keys.swift, LivePropertiesKeysTests.swift | LivePropertiesKeysTests | | waiting KY-2 |
| KY-7 | 3 | `insertFrames`, `removeFrames`, `setLabel` + `KeyframeEditing` | Live/LiveKeyframes+Frames.swift, LiveKeyframesFramesTests.swift | LiveKeyframesFramesTests | | waiting KY-6 |
| KY-4 | 4 | `setFill`, `setStroke` + `PropertyAnimating` | Live/LiveProperties+Paint.swift, LivePropertiesPaintTests.swift | LivePropertiesPaintTests | | waiting KY-3 |
| KY-9 | 5 | model journey steps 1–7 + QB-L7 budget (feature-done) | LiveKeysJourneyTests.swift, LiveKeysBudgetTests.swift | both | | waiting KY-4, KY-7, KY-8 |

## Rounds
| round | CI run | CI | audit vs baseline | lenses | confirmed | fixed by | clean |
|---|---|---|---|---|---|---|---|

## Decisions
- Base is c111439 (dev one commit past the briefed bcc3197, which is its ancestor: #896, a Flare test pin).
- #799 says `Depends on: none`; creative-core #171, #216, #219 are on creative-core main 98be31a, which Package.swift tracks.
- The container had no Swift; installed swift-6.3.3-RELEASE (the CI image's version) under /opt/swift.

- Waves follow the packet's chains (KY-1→2→3→4, KY-5→6→7, KY-8, then KY-9): five waves, each task's files disjoint from its wave-mates.
- No needs-ui/needs-core issues: every FlareCore call the packet names exists on 98be31a with `owner:` (SetKeyframe/MoveKeyframe merge, SetShapeStroke).
- No Flare UI changes in this feature (live types are not wired until IN-1/IN-2), so screens can't change; rounds judge on the Linux gate plus the dev CI run.

## Open
- none
