# Feature packet: lottie-player-check

**Feature:** Lottie output is the reason to choose Flare, so a file that plays
differently in a standard player is a broken file whatever the stage shows.
Today flare-export only checks a byte round trip through `.flare`. This packet
adds a reference player to CI and a parity suite: for each fixture animation
Flare exports a Lottie, the player renders frames 0, the middle and the last,
Flare's `StageRasterizer` renders the same frames, and the two must agree
(at most 2% of pixels differing by more than 8 levels). The player is
**ThorVG** (MIT licence, a Lottie loader and a C API), built from a release tag
pinned in `scripts/lottie-oracle/VERSION` that must be at least 7 days old
(the workspace's supply-chain rule); the script states its install command
(`brew install meson ninja` on the macOS runner) and caches the build. A small
C renderer (`render.c`, about 60 lines over ThorVG's C API) writes each frame
as raw RGBA. The suite also catches RJ-F01's trap: a loop whose first and last
frames are the same frame, so it stutters.
**Line:** `line:flare` · **Wave:** 8 (`waves.md`) · **Lead branch:** `lead/lottie-player-check`
**Beta:** captain, 2026-10-21 (beta gaps, Flare must-haves). Labels `beta` and `p1` when filed.

**Covers:** `2026-10-21-beta-gaps-combined.md` Flare must-have "a CI check that
Lottie plays the same in a reference player"; Flare audit B6; RJ-F11
(re-pointed here from the built flare-export) and RJ-F01's loop trap (RJ-F01
stays with flare-export).

**Depends on:** flare-export (built). `StageRasterizer` is FlareApp code on
macOS, so the suite runs on the macOS job (`Cm`). Colour, trim and morph
fixtures join once the stage-matches-export fix (creative-core
`fix/flare-sampler`, creative-apps `fix/flare-stage-matches-export`, in
flight) merges; until then they're listed and skipped with that reason.

**Supervisor merges.** LP-4 edits `.github/workflows/ci.yml` (CI files are off
the fast lane).

**Rule 20.** No second Lottie renderer in the apps: the player is a test
oracle under `scripts/`, never linked into a target.

**C4:** none (a test oracle, not a component).

**Clean-room.** ThorVG is used as a black box through its public C API; no
Flare code is derived from it.

Blueprint sections: flare.md 6 (Lottie), docs/engineering.md (tests).

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| LP-a | A pinned reference player builds on macOS from a script, and the parity suite is written with its fixtures and skipped until the runner has the player. | LP-1, LP-2 | MJ-LP | – |
| LP-m | The comparison's tolerance and the loop rule are tested on Linux, and the suite gains colour and trim fixtures once the stage samples them. | LP-3, LP-5 | MJ-LP | LP-a |
| LP-z | CI builds the player on the macOS job and runs the suite there, RJ-F11 passes, and the feature is built. | LP-4, LP-6 | MJ-LP | LP-a, LP-m |

**No screen.** The packet is a check, so it has no UI slice
(`"ui_slice": "none"`); its acceptance is the parity suite itself.

## Journey steps

`MJ-LP`: `FrameParityTests` on Linux; `LottiePlayerParityTests` on the macOS
job once the oracle is built (bounce, spinner, stroke-on; colour-key and trim
after the stage fix).

## Jobs

| job | closes or adds | run | check | fixture |
|---|---|---|---|---|
| RJ-F11 | closes (re-pointed to `flare/lottie-player-check`; `needs` keep `flare/flare-export`) | Cm | `Tests/RealJobs/flare/lottie-player/`: export the bounce and the spinner as Lottie, render frames 0, middle and last with the oracle, compare with Flare's PNG frames | the two fixtures |

Trap: the stage looks right but a standard player shows the loop stutter, a
key one frame late, or the wrong easing. Assertion: every compared frame is
within 2% at 8 levels and the loop rule holds. Mutation:
`FlareModel.FrameParity` (`.thresholdIsStrict`). LP-4 enables it.

## Screens and states

None.

## Contract slice

```swift
// Sources/FlareModel/FrameParity.swift (LP-3). Linux-safe.
public enum FrameParity {
    /// The fraction of pixels whose largest channel difference is above `levels`.
    public static func mismatch(_ a: [UInt8], _ b: [UInt8], levels: Int) -> Double
    public static func matches(_ a: [UInt8], _ b: [UInt8]) -> Bool          // mismatch(levels: 8) <= 0.02
    /// True when the last frame of a loop isn't a repeat of the first (`ip`/`op` exclusive end).
    public static func loopIsClean(first: [UInt8], last: [UInt8], next: [UInt8]) -> Bool
}
```

`scripts/lottie-oracle build | render <json> <frame> <w> <h>`; `VERSION`
holds the ThorVG tag and its release date.

## Pseudocode

- **Frames.** For a scene of `n` frames compare 0, `n / 2` and `n - 1`; render
  both at the scene's size, straight alpha over white.
- **Loop.** The Lottie's `op` is exclusive; the oracle's frame `op - 1` must
  differ from frame 0 when the animation moves, else the loop repeats a frame.

## Tasks

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| LP-1 | – | `scripts/lottie-oracle`: `build` fetches the ThorVG tag in `VERSION` (refuses one under 7 days old), builds it with meson into `.build/lottie-oracle/`, compiles `render.c`; `render <file.json> <frame> <w> <h>` writes raw RGBA; the install line in its header | `scripts/lottie-oracle/build`, `scripts/lottie-oracle/render.c`, `scripts/lottie-oracle/VERSION`, `scripts/lottie-oracle/README.md` | – | ~170, 4 |
| LP-2 | – | **The check.** `LottiePlayerParityTests` (AppSnapshotTests, macOS): fixtures bounce, spinner and stroke-on exported by `FlareHeadless`, frames 0, middle and last from the oracle and from `StageRasterizer`, compared at 2% over 8 levels; the loop check (the last frame isn't the first frame again); skipped with the reason when the oracle isn't built | `Tests/AppSnapshotTests/LottiePlayerParityTests.swift`, `Tests/AppSnapshotTests/Fixtures/Lottie/spinner.flare`, `Tests/AppSnapshotTests/Fixtures/Lottie/stroke-on.flare` | LP-1 | ~200, 3 |
| LP-3 | – | `FrameParity` (FlareModel, Linux-safe): the pixel diff rule and the loop rule as pure functions, used by the suite; `FrameParityTests` with mutations | `Sources/FlareModel/FrameParity.swift`, `Tests/FlareModelTests/FrameParityTests.swift`, `Tests/mutations/FlareModel.FrameParity.json`, `Tests/AppSnapshotTests/LottiePlayerParityTests.swift` | LP-2 | ~140, 4 |
| LP-5 | – | Colour-key and trim fixtures (fill blue to orange, a stroke drawn on), listed and skipped with "waits on the stage-matches-export fix" until it merges | `Tests/AppSnapshotTests/Fixtures/Lottie/colour-key.flare`, `Tests/AppSnapshotTests/Fixtures/Lottie/trim.flare` | LP-3 | ~40, 2 |
| LP-4 | – | **Supervisor merge.** `ci.yml`'s macOS job caches `.build/lottie-oracle` by `VERSION` and runs `scripts/lottie-oracle build` before the tests; RJ-F11 re-pointed and enabled | `.github/workflows/ci.yml`, `Tests/RealJobs/flare/lottie-player/lottie-player.jobs.json` | LP-2, LP-3 | ~60, 2 |
| LP-6 | – | `status: built`; `feature-done` | `docs/blueprints/flare/features/lottie-player-check.wave.json` | LP-4, LP-5 | ~10, 1 |

## Build waves

- Wave 1: LP-1. Independent in this wave: LP-1 alone.
- Wave 2: LP-2. Independent in this wave: LP-2 alone.
- Wave 3: LP-3. Independent in this wave: LP-3 alone.
- Wave 4: LP-5, LP-4. Independent in this wave: both.
- Wave 5: LP-6. Independent in this wave: LP-6 alone.

Longest chain: LP-1 → LP-2 → LP-3 → LP-4 → LP-6 (5). Chain of 5: the oracle, the suite, the parity rules, CI, the done task.

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| LP-1 | `scripts/lottie-oracle build` on a Mac; `render` of a one-rect fixture gives that rect | the tag is too new, or the renderer draws nothing | – (tooling) |
| LP-2 | with the oracle built: green on today's writer for bounce and spinner; a deliberately broken export (keys shifted a frame) fails | a frame drift passes | – (the suite is the oracle; its plan is LP-3) |
| LP-3 | `FrameParityTests`: 1% of pixels off by 20 passes, 3% fails; 5% off by 6 passes; a loop whose last frame equals frame 0 fails | the tolerance or the loop rule is wrong | `FlareModel.FrameParity`: level threshold compared with `>=` → `.thresholdIsStrict`; fraction against the wrong total → `.fractionOfAllPixels` |
| LP-5 | the fixtures load; their rows skip by name | a fixture is missing | – (fixtures) |
| LP-4 | the macOS job runs `LottiePlayerParityTests` unskipped; RJ-F11 (`Cm`) | the suite is skipped in CI | – (CI) |
| LP-6 | `scripts/waves render --dry-run` | status not built | – |

## Quality tests

| quality row | budget | test |
|---|---|---|
| CI time | the oracle build cached; the suite under 60 s on the macOS job | `ci.yml` timing |
| supply chain | the pinned tag at least 7 days old; build refuses a newer one | `scripts/lottie-oracle build` |
| the oracle catches drift | a one-frame key shift fails | `LottiePlayerParityTests` (broken-export case) |

## Done check

Per slice (rules 6, 21, 22): LP-a and LP-m merged-done with `FrameParityTests`
green on Linux and `Mutate:` clean; LP-z when the macOS job runs the suite
unskipped and RJ-F11 is green. Then `Belt-Contact-Sheet:` with one compared
frame pair.
