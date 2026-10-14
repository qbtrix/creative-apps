# Golden baselines

Committed reference PNGs for `assertGolden` (`../GoldenImage.swift`, #331).
The compare is `GoldenImage`, the live `GoldenComparing` from SuiteUI.

## Layout

A baseline sits beside the test file that asserts it, found by `#filePath`:

```
Tests/AppSnapshotTests/Golden/<area>/<name>-<appearance>.png
```

One PNG per component per appearance (a contact sheet), so a component PR
stays inside the 15-file cap. SuiteUI components are recorded in `light`,
`dark`, `light-contrast` and `dark-contrast`.

## Tolerance

`GoldenTolerance.standard`: a pixel differs when any channel is more than
2/255 away from the baseline, and the image passes while at most 0.5 % of
its pixels differ. Different sizes or a malformed buffer always fail with
share 1. No test loosens the tolerance to make a golden pass.

## The recording rule

1. **No baseline yet.** `assertGolden` writes the actual to
   `.build/snapshots/golden-new/<area>/<name>-<appearance>.png` and records a
   Swift Testing known issue, so adding a component never turns `dev` red.
   The compare itself still fails (`GoldenResult.passes` is false, share 1).
2. **Record it on CI.** Goldens come from the macOS job, never from a local
   Mac. Download the `snapshots` artifact of the macOS run on `dev`
   (`gh run download <id> -n snapshots`), look at the PNG, and commit it
   under `Golden/<area>/` in the feature's next PR, listing it in the body.
3. **A baseline that differs always fails.** The actual and a diff (the
   differing pixels magenta over a grey copy of the baseline) go to
   `.build/snapshots/golden-diff/<area>/<name>-<appearance>.png` and
   `<name>-<appearance>-diff.png`. Fix the view, or, when the change is
   intended, replace the baseline with the new actual from the artifact in
   the PR that makes the change and say why in its body.
