# creative-apps

The Mac apps of a free, open-source creative suite, written in Swift and
SwiftUI for macOS 26:

- **Flare**: 2D animation
- **Design**: vector and UI design
- **Photo**: raster editing
- **Library**: photo catalog
- **Halo**: motion graphics

The engines (animation document, color, raster) live in
[creative-core](https://github.com/qbtrix/creative-core). This repo holds each
app's Model (Linux-safe state and logic), its SwiftUI shell, and SuiteUI, the
shared design system. Today each app opens a window with its sidebar, canvas
or empty state, and inspector; the features come next.

## How it is built

A crew of AI coding agents builds it in the open from GitHub issues. They run
on Linux, so they test the Models locally. Small PRs that pass that check
merge into the `dev` branch on their own. Once a feature is built, CI on
`dev` builds the UI on macOS, renders every app's main view to PNG and clicks
through each app, and `main` only takes `dev` commits whose CI passed. A human
reviews the pictures after merge. Agent rules are in [CLAUDE.md](CLAUDE.md).

## Running it

You need macOS 26 and Xcode 26 (or Swift 6 on Linux for the Models).

```bash
scripts/ci            # lint, build and test: the same gate CI runs
scripts/ci --changed  # the same lints and build, then only the tests of the targets you touched
swift run FlareApp    # open Flare (or DesignApp, PhotoApp, LibraryApp, HaloApp)
```

## License

GPL-3.0. See [LICENSE](LICENSE), with additional terms under its
section 7 in [ADDITIONAL-TERMS.md](ADDITIONAL-TERMS.md) (notices,
marking modified versions, no trademark rights). The names and icons are
covered by [docs/trademark-policy.md](docs/trademark-policy.md); editions
and contributing: [docs/licensing.md](docs/licensing.md),
[CONTRIBUTING.md](CONTRIBUTING.md).
