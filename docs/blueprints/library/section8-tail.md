#### Order at a glance

```
wave 1   spine ─────────────────────────────────────────────────────────┐
wave 2   import · thumbnails · cull · persist · loupe-viewport          │ (#333 for journey files,
wave 3   develop (needs loupe-viewport, thumbnails) · status-and-layout │  #330 for perf rows)
wave 4   crop (needs develop) · export (needs develop, import)          │
         ── v1: J0–J12 green live, P1–P8 reporting, audit 0 ──          │
wave 5   filters-collections · metadata-more · raw                      ┘
```

- **Journey files before #333.** Until SuiteUI's QH-4 (#333) merges, the
  Journey template compiles only `UITests/LibraryJourneyTests.swift`. Then
  in each wave exactly one feature may add journey steps, to that file: the
  spine in wave 1, import in wave 2, develop in wave 3, export in wave 4.
  The others ship Model tests and snapshots and add their `+<Area>` file as
  soon as #333 lands. `check_waves.py` treats the `+<Area>` files as owned
  already.
- **No engine waits for v1.** Every CoreRaster call v1 needs is on
  creative-core `main` (section 0.2). The one possible core issue is the
  fused develop pass, filed only if QB-LIB-6's model budget fails (develop's
  row above has its one-line spec).
- **SuiteUI waits are soft.** Each `needs-ui` part has a placeholder path
  (CLAUDE.md); a feature never blocks on one. The harness issues (#330,
  #331, #332, #333) block only the perf rows, goldens and journey files.
- **Live order.** Fakes first (UI track), then each feature's last task
  replaces its `Live/` stub, which turns its journeys from
  `-LibraryFixture` to live files. v1 is done when J0–J12 run live, P1–P8
  report numbers, every Library audit count is 0, and the captain has
  looked at the contact sheet.

Checklist:

- [x] Every open `line:library` issue maps to a feature or says "not v1"
      (`check_waves.py`).
- [x] Every feature has owned files, and no two features in a wave share
      one (`check_waves.py`).
- [x] Every feature names the creative-core work it waits on: an existing
      issue (closed ones named), "none", or a one-line spec for a new one.
