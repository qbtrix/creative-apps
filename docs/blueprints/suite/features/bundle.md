# Feature packet: bundle

**Feature:** one `AfterGlow.app`. The release build graph links SuiteUI,
the suite model and shell, and the engines once as four frameworks; the
launcher and the five apps sit in one signed bundle that declares every
suite document type; the size report measures it and the size model can
judge it.
**Line:** `line:suite` · **Wave:** 1 (`waves.md`) · **Lead branch:** `lead/bundle`
**Blueprint:** `docs/blueprints/suite.md` sections 2.5 (route R1, changes
2–5), 2.6 (types), 5.6 (`Packaging.swift`), 7.5, 8.2 (F1).

**Covers:** #813, #814, #815, #816, #817, #818. Each closes
through its task PR. #819 (turn the size gate on) is filed with this
feature but waits for ten green dev runs after BU-4, so it is not in this
feature's done check; the supervisor merges it later.

**Depends on:** the targets feature (`targets.md`; its feature issue is filed once this packet PR merges, and `waves.md` names it). BU-3 also waits on #333 (SuiteUI
SH-7, the journey template in `project.yml`, part of #778).

**Supervisor merges.** BU-3 (`project.yml`), BU-4 (`scripts/bundle-apps`,
`scripts/size-report`) and BU-6 (`.github/workflows/ci.yml`). `project.yml`
is not on CLAUDE.md's protected list, but it is shared with SuiteUI's
harness (#333) and gallery (#776), so its edit goes through the supervisor
too and lands after SH-7. Every protected-path task of the suite is in
waves 0 and 1; nothing later touches `Package.swift`, `project.yml`,
`scripts/` or CI.

**What changed from the blueprint.**

- BU-5 is split in three (the AfterGlow plist and its test; the five app
  plists; placeholder icons), so no PR passes 400 lines.
- `PlistShapeTests` checks the plists against a literal table in the test,
  not against `SuiteTypeRegistry` (suite-contracts builds the registry in the
  same wave, and a cross-feature dependency inside a wave stalls a lead).
  The registry-vs-plist test stays recents-open-in's RO-1. The rule that
  test needs (review): document types (`CFBundleDocumentTypes`) equal
  `SuiteTypeRegistry.standard`; exported types with no document role (the
  hand-off and the three pasteboard-only types) equal
  `SuiteTypeRegistry.declaredOnly`, which suite-contracts SC-1a adds.
- The journey bundle compiles one glob, `UITests/AfterGlowJourneyTests*.swift`.
  The blueprint's `UITests/Journey+Suite.swift` would match SuiteUI's
  `UITests/Journey*.swift` template glob and land in all five app bundles,
  which can't see `SuiteApp` (review); home's harness file is
  `UITests/AfterGlowJourneyTests+Harness.swift` instead, and the budget
  files are `UITests/AfterGlowJourneyTests+Budgets<Area>.swift`, so no
  second glob is needed.
- BU-4 runs after the plists and icons exist (it copies them), and turns the
  placeholder PNGs into `.icns` on the Mac (`sips`, `iconutil`), so no
  binary icon tooling is needed on Linux.
- flare-in-halo's FH-1 (wave 5) adds `.halo` as a `.flare` reader; it must
  also own `Bundle/Info/Halo.plist` and `Bundle/Info/AfterGlow.plist` then
  (review). Noted in `waves.md` for that packet.

## Journey steps

No AfterGlow journey yet (home, wave 2). After this feature, on the dev CI
build:

1. `scripts/bundle-apps` produces `.build/apps/AfterGlow.app` with
   `Contents/MacOS/AfterGlow`, `Contents/Helpers/{Flare,Design,Photo,Library,Halo}.app`
   and `Contents/Frameworks/{SuiteUI,SuiteModel,SuiteShell,CreativeEngines}.framework`.
2. `.build/apps/<X>App.app` are symlinks into it, so every existing app
   journey launches the embedded app unchanged.
3. `codesign --verify --deep --strict` passes on the outer bundle;
   `otool -L` of each helper lists the four frameworks.
4. `size-report` lists every executable, framework, helper, the whole
   bundle and the tarball, and the SuiteUI symbols defined in each app
   executable (target 0).
5. On a Mac, `lsregister -f .build/apps/AfterGlow.app` then double-clicking a
   `.design` file opens Design (journey SJ5 proves it in wave 3).

## Screens and states

No screen. The states are the build's:

| State | What the person (or CI) sees |
|---|---|
| Empty | none |
| Error | `bundle-apps` exits non-zero naming the step (build, assemble, sign, verify) and the path; a helper that does not list a framework fails the step with "`<X>` does not link `<framework>`" |
| Loading | none (CI step log) |

## Contract slice

`Packaging.swift` (blueprint 5.6) moves into `Sources/SuiteModel/Packaging/`
unchanged except for the live checker:

```swift
public enum SizeEntryKind: String, Codable, Sendable { case executable, framework, appBundle, wholeBundle, tarball }
public struct SizeEntry: Codable, Equatable, Sendable { name, kind, bytes, suiteUISymbols: Int? }
public struct SizeReport: Codable, Equatable, Sendable { commit: String, entries: [SizeEntry] }
public struct SizeBudget: Codable, Equatable, Sendable { limits: [String: Int], reportOnly: Set<String> }
public struct SizeFinding: Equatable, Sendable { entry: String, bytes: Int, limit: Int, hard: Bool }
public protocol SizeBudgetChecking: Sendable { func evaluate(_ r: SizeReport, against b: SizeBudget) -> [SizeFinding] }
public struct SizeGate: SizeBudgetChecking { public init() }          // BU-2: FakeSizeBudget's rule, as the live type
public enum BundleLayout {                                            // BU-2
    public static let apps = ["Flare", "Design", "Photo", "Library", "Halo"]   // display names, as the bundle folders
    public static func executablePath(ofApp name: String?) -> String  // nil: the launcher, "Contents/MacOS/AfterGlow"; "Flare": "Contents/Helpers/Flare.app/Contents/MacOS/Flare"
    public static let frameworks = ["SuiteUI", "SuiteModel", "SuiteShell", "CreativeEngines"]
    public static func runPath(ofApp name: String?) -> String         // helpers: "@executable_path/../../../../Frameworks"; launcher: "@executable_path/../Frameworks"
}
```

`BundleLayout` takes the app's display name, not `SuiteApp`, so BU-2 needs
nothing from suite-contracts and the two wave-1 features never wait on each
other. suite-contracts' `SuiteApp.bundlePath` must agree with it; RO-1
(wave 3) adds the test that compares them.

## Pseudocode

```
SizeGate.evaluate(report, budget):                                  # BU-2
  for entry in report.entries:
    limit = budget.limits[entry.name] ?? continue
    if entry.bytes > limit: finding(entry, hard: !budget.reportOnly.contains(entry.name))
    if entry.kind == .executable, (entry.suiteUISymbols ?? 0) > budget.symbolLimit: finding(..., hard: !reportOnly)
SizeGateTests.reportFromEnvironment: if SUITE_SIZE_REPORT set: decode it; #expect(no hard finding)

BuildGraphTests (Linux, line scan, no YAML library):                # BU-3
  pkg = target names in Package.swift: .target(name:), .executableTarget(name:), model(...) expansions
  yml = names at the fixed indent under `targets:` in project.yml
  #expect(pkg macOS release set ⊆ yml release set); extra yml-only names allowed: CreativeEngines, *JourneyTests
  check: the same scan over project.yml's text with SuiteShell's lines removed in memory reports "SuiteShell missing from project.yml"

bundle-apps (macOS):                                                # BU-4
  xcodebuild -scheme Release build
  assemble: launcher -> Contents/MacOS/AfterGlow; each <X>App -> Contents/Helpers/<X>.app (+ its Info.plist from Bundle/Info/<X>.plist)
            frameworks -> Contents/Frameworks; Bundle/Samples/ -> Contents/Resources/Samples (empty until onboarding)
            Bundle/Icons/<X>.png -> sips/iconutil -> <X>.icns into each Resources
  for each helper: otool -L | must list the four frameworks, else fail
  sign inside out: frameworks, each helper, outer (ad-hoc "-")
  plutil -lint every Info.plist; codesign --verify --deep --strict
  ln -s AfterGlow.app/Contents/Helpers/<X>.app .build/apps/<X>App.app ; lsregister -f AfterGlow.app
  tar app-builds.tar.gz ; scripts/size-report (extended to AfterGlow.app rows)
```

## Tasks

Every task is one PR to `dev`: at most 400 changed lines and 15 files, body
lines `Belt-Lead:`, `Feature: bundle`, `Fast-Check: pass`, `Head:`. Lane PRs
carry `fast-lane`; BU-5c carries `feature-done` (it is the last lane PR;
BU-4 must have merged first, see the done check).

| id | issue | what | owned files | depends on | merges |
|---|---|---|---|---|---|
| BU-2 | #813 | `SizeReport`, `SizeBudget`, `SizeFinding`, `SizeGate`, `BundleLayout`; `SizeGateTests` reads `SUITE_SIZE_REPORT` when set | `Sources/SuiteModel/Packaging/` (`SizeReport.swift`, `SizeGate.swift`, `BundleLayout.swift`), `Tests/SuiteModelTests/Packaging/SizeGateTests.swift`, `Tests/SuiteModelTests/Packaging/BundleLayoutTests.swift` | BU-1a #810 | lane |
| BU-3 | #814 | Route R1: the `Release` graph in `project.yml` (four frameworks, five apps as application targets with the helper run path, the launcher) and the `AfterGlowJourneyTests` bundle (the template's files, `UITests/AfterGlowJourneyTests*.swift`, `Sources/SuiteModel/Values/`); `CreativeEngines.swift` re-exporting FlareCore, CoreRaster, CoreColor; `BuildGraphTests` | `project.yml`, `Bundle/Engines/CreativeEngines.swift`, `Tests/SuiteModelTests/BuildGraphTests.swift` | #333 (SH-7), BU-1a | supervisor |
| BU-5a | #815 | `AfterGlow.plist`: bundle id, every document type of 2.6 (Editor, Owner; images Alternate), exported and imported types, `LSMinimumSystemVersion` 26.0; `PlistShapeTests` | `Bundle/Info/AfterGlow.plist`, `Tests/SuiteModelTests/PlistShapeTests.swift` | BU-1a | lane |
| BU-5b | #816 | The five app plists: each app's own types (Owner for its format, Alternate for images it reads), the hand-off type as Viewer, `org.creativesuite.<x>`, icon file name | `Bundle/Info/Flare.plist`, `Design.plist`, `Photo.plist`, `Library.plist`, `Halo.plist`, `Tests/SuiteModelTests/PlistShapeAppsTests.swift` | BU-5a | lane |
| BU-5c | #817 | Placeholder icons (Q4): six 1024 px PNGs, a coloured rounded square with the app's initial; `Bundle/Icons/README.md` says how they were made and that art is pending | `Bundle/Icons/{AfterGlow,Flare,Design,Photo,Library,Halo}.png`, `Bundle/Icons/README.md`, `Tests/SuiteModelTests/IconFilesTests.swift` | BU-5b | lane |
| BU-4 | #818 | `scripts/bundle-apps` assembles, signs and verifies `AfterGlow.app`, symlinks the old paths, registers with `lsregister`; `scripts/size-report` adds the AfterGlow rows | `scripts/bundle-apps`, `scripts/size-report` | BU-3, BU-5c, BU-0 #809 | supervisor |
| BU-6 | #819 | After ten green dev runs since BU-4: set the budgets (measured maximum × 1.10, never above 7.5's provisional numbers; symbols 0 after one report-only run) and fail the `macos` job on a hard finding | `.github/workflows/ci.yml`, `Bundle/size-budget.json` | BU-4, BU-2 | supervisor, later |

Test fixtures are inline strings or read by path from `#filePath` (the
plists, `project.yml`); nothing non-Swift goes inside `Tests/SuiteModelTests/`,
where SwiftPM would warn about unhandled resources and `Package.swift` can't
change to declare them.

Order: BU-2, BU-3 and BU-5a at once; BU-5b after BU-5a;
BU-5c after BU-5b; BU-4 after BU-3 and BU-5c. Sizes: BU-2 ~300 lines / 6
files, BU-3 ~250 / 4, BU-5a ~300 / 2, BU-5b ~320 / 6, BU-5c ~80 / 8
(six binaries), BU-4 ~300 / 2.

**If R1 fails** (BU-3 finds a module that won't re-export, so the engines
link twice): file the core issue the blueprint names ("creative-core:
declare `CreativeEngines` as a `.dynamic` library product over FlareCore,
CoreRaster and CoreColor; acceptance: an executable depending on it links
`libCreativeEngines` dynamically (`otool -L`)") with `needs-core`, keep
BU-4 on today's static engines, and record it in RECORD.md. The rest of the
feature does not wait.

## Acceptance test per task

| id | test | fails when |
|---|---|---|
| BU-2 | `SizeGateTests`: an over-budget report (inline JSON in the test) with the 7.5 budget gives one hard finding naming `CreativeEngines.framework`; a report-only row over its limit gives a soft finding; an executable with 1 SuiteUI symbol and limit 0 is a finding; with `SUITE_SIZE_REPORT` unset the env test is skipped, set to the over fixture it fails. `BundleLayoutTests`: Flare's executable path and run path, the launcher's, and the four frameworks | a hard row passes, a soft row fails the gate, or a path is wrong |
| BU-3 | `BuildGraphTests`: every macOS target of `Package.swift` is a target of `project.yml`'s release graph; on `project.yml`'s text with the `SuiteShell` target lines removed (in memory) the scan reports `SuiteShell`; `AfterGlowJourneyTests` lists `UITests/AfterGlowJourneyTests*.swift` and `Sources/SuiteModel/Values/` | a target is dropped from either file, or the journey bundle misses its sources |
| BU-5a | `PlistShapeTests` (Linux, Foundation's XML property list decoding): `CFBundleIdentifier` is `org.creativesuite.afterglow`; the document types are exactly flare, design, halo, ora (Editor, Owner), png, jpeg, heic (Editor, Alternate) with their extensions; exported types are flare, design, halo, the hand-off (`aghandoff`) and the three pasteboard-only ids; `LSMinimumSystemVersion` is 26.0 | a type is missing, an image is Owner, or a version differs |
| BU-5b | `PlistShapeAppsTests`: each app plist's bundle id is `org.creativesuite.<x>`; it is Owner of its own format only; Photo and Library read the three image types as Alternate; every app opens the hand-off type as Viewer | an app claims another's format, or misses the hand-off |
| BU-5c | `IconFilesTests`: every `CFBundleIconFile` named in the six plists has `Bundle/Icons/<name>.png`, 1024 × 1024 (read from the PNG header) | an icon is missing or the wrong size |
| BU-4 | the dev macOS run: `bundle-apps` passes its own `otool -L` and `codesign --verify --deep --strict` checks; every existing app journey is green through the symlinks; `size-report` has the framework rows and per-app symbol counts | a helper links a framework statically, signing fails, or a journey breaks |
| BU-6 | `SizeGateTests` with `Bundle/size-budget.json` and the over-budget report fails; the next dev run after merge is green | the gate never fails, or fails on a good build |

## Quality tests

| quality row | budget | test |
|---|---|---|
| 7.5 each app executable | ≤ 60% of its BU-0 size; report only until BU-6 | `size-report` + `SizeGateTests` |
| 7.5 `SuiteUI.framework` / `CreativeEngines.framework` / `SuiteModel`+`SuiteShell` / launcher | ≤ 4 MB / ≤ 6 MB / ≤ 2 MB / ≤ 2 MB; report only until BU-6 | same |
| 7.5 whole bundle, tarball | ≤ BU-0's sum of executables + 10%; ≤ 15 MB | same |
| 7.5 SuiteUI symbols in an app executable | 0, report only for one run after BU-4, then hard (BU-6) | same |
| Two build graphs agree | every macOS target in both files | `BuildGraphTests` |

## Done check

- **Journeys green:** the dev macOS run after BU-4 and BU-5c is green, with
  every app journey launching through the symlinked helpers. BU-5c carries
  `feature-done`; if BU-4 has not merged when BU-5c is ready, the lead holds
  BU-5c's `feature-done` label until the supervisor merges BU-4.
- **Audit zero new:** no app count over `UITests/audit-baseline.json`.
- **Contact sheet:** `Belt-Contact-Sheet: <run link>` on the feature issue
  with the `size-report` table (before: BU-0's numbers; after: this run's)
  and the `otool -L` lines for one helper.
