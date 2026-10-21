# lottie-oracle

The reference Lottie player for the lottie-player-check feature
(`docs/blueprints/flare/features/lottie-player-check.md`). `LottiePlayerParityTests`
renders Flare's exported Lottie with it and compares the frames with
`StageRasterizer`'s. It is a test oracle: no target links it (rule 20).

## Use

```bash
brew install meson ninja          # macOS; on Linux: pip install meson ninja
scripts/lottie-oracle/build       # fetch, check and build into .build/lottie-oracle/ (cached)
scripts/lottie-oracle/build render bounce.json 12 200 200 > frame.rgba
.build/lottie-oracle/render bounce.json 12 200 200 > frame.rgba   # the same, without the wrapper
```

`render <file.json> <frame> <w> <h>`:

- `frame` is 0-based and relative to the Lottie's `ip`; it must be below the
  total frame count (`op - ip`, `op` exclusive). A fraction is allowed.
- The animation is fitted into `w` x `h` (1 to 8192 each), keeping its aspect
  ratio, over opaque white.
- **Output:** exactly `w * h * 4` bytes of raw RGBA on **stdout**: 8 bits a
  channel, straight (un-premultiplied) alpha, row-major, top row first. Nothing
  else goes to stdout; errors go to stderr with a non-zero exit.

## Pin and supply chain

`VERSION` holds the ThorVG release: `tag=`, `commit=` (the tag's commit) and
`date=` (its release date, for people). `build` refuses the tag when it
doesn't resolve to `commit=`, or when it is less than 7 days old by its own
commit or tag date. `LOTTIE_ORACLE_NOW` (epoch seconds) replaces the clock in
that check. A rebuild happens only when `VERSION` or `render.c` changes, so CI
can cache `.build/lottie-oracle` keyed by `VERSION`.

ThorVG is built static with the CPU engine, the Lottie loader and the C API
only (`-Dloaders=lottie -Dbindings=capi -Dstatic=true -Ddefault_library=static`).

## Licence and clean-room

- Source: https://github.com/thorvg/thorvg, tag `v1.1.2`, commit
  `b004a778f53a5df61f06be45748761ae42c52dda` (2026-09-18).
- Licence: MIT ("Copyright (c) 2020 - 2026 ThorVG Project"), read from
  `LICENSE` at that tag. MIT is GPL-3.0-compatible.
- No ThorVG code is copied into this repo. `build` downloads it into the
  ignored `.build/`, and `render.c` is our own code that calls only the public
  C API in `thorvg_capi.h`, checked against that header at the pinned tag.
