# flare export-pack lead record

Issue: #3481 · Packet: docs/blueprints/flare/features/export-pack.md
Run: act-1a178432d03-7n20 (feature lead, line:flare; FV-z only)
Stage: FV-z (FV-7, FV-8): PR #4854 on lead/export-pack-fvz, journey step 4 moved to the fakes plus the GIF hover step (#5019); FV-a fix round PR #5025 open
Base: origin/dev
Next: Belt-Slice-Done FV-z, Mac-Finish-Wanted FV-z and Belt-Contact-Sheet on #3481 once a flare-scoped or full ci.yml run contains #4854 and #5025

## Run act-1a178432d03-7n20 decisions
- The record lives at docs/leads/flare-export-pack/: docs/leads/export-pack/ on this branch is the SuiteUI export-pack lead's, so it is left as is. The earlier Flare record was lost when the branch was rebuilt from main.
- FV-z needs no new PR: #4854 (FV-7, FV-8, Packet-Review amendment 5) and #5025 (FV-a fixes, amendments 1 to 3) are open and clean.
- PR base stays dev (CLAUDE.md; the lane retargets main).
- Both PRs are held only by dev-red #5321 (OnboardingModelTests timeouts on macOS, range main..2eab5aeb2, not ours); asked the supervisor on #3481 whether they land on their own proof.
- Journey step 4 (Cancel on a running MP4) moves to -FlareFixture bounce: live frames have no pause, so Cancel may never show (as in FlareExportErrorJourneys). Added a hover on flare.export.format.gif with its own shot for #5019's Flare half (Refs, the SuiteUI half remains).
- Packet-Review 2 answered on #3481; gaps #5380 (headless video) and #5381 (cost perf test) filed.
