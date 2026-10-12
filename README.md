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
on Linux, so they test the Models locally and see the UI through CI: the macOS
job renders every app's main view to PNG and attaches them to each run. Model
changes that pass CI can merge on their own; UI changes wait for a human to
look at the pictures. Agent rules are in [CLAUDE.md](CLAUDE.md).

## Running it

You need macOS 26 and Xcode 26 (or Swift 6 on Linux for the Models).

```bash
scripts/ci            # lint, build and test: the same gate CI runs
swift run FlareApp    # open Flare (or DesignApp, PhotoApp, LibraryApp, HaloApp)
```

## License

GPL-3.0. See [LICENSE](LICENSE).
