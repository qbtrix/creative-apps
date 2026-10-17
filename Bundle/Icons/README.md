# App icons: generated, do not edit

Every PNG here is a render of an SVG in `Bundle/Marks/`, the only
hand-edited form of the suite's marks. To change a mark, edit its SVG and run

```bash
scripts/render-marks        # needs rsvg-convert: brew install librsvg
```

which rewrites, for each of AfterGlow, Flare, Design, Photo, Library and Halo:

| File | What |
|---|---|
| `<App>.png` | 1024 x 1024, the art `CFBundleIconFile` names in `Bundle/Info/<App>.plist` |
| `<App>-<px>.png` | 16, 32, 64, 128, 256 and 512 px; at 32 px and under the SVG's `-small` groups draw (a heavier rim and a simpler glyph, so each mark keeps its silhouette in grayscale) |
| `marks.json` | FNV-1a 64 digests of each SVG and of every PNG rendered from it |

plus `Sources/SuiteUI/AppMarkArt.swift`, the same art as path data for
`AppMark`, the view every window uses to draw a mark. `scripts/bundle-apps`
packs each app's PNGs into its `.icns` with `iconutil`.

`IconFilesTests` fails when an SVG changed without a rerender or a PNG no
longer matches its recorded digest; `scripts/render-marks --check` (in
`scripts/ci`) does the same and also checks `AppMarkArt.swift`, and
`AppMarkTests` checks that `AppMark` draws what the PNGs show.
