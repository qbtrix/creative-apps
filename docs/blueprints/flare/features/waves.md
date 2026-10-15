# Flare features: waves

The open `p1` logic work on `line:flare` (refreshed in section 0 of
`docs/blueprints/flare.md`, 2026-10-14) grouped into four features, one
feature-lead session each. A wave starts when everything it waits on has
merged. Two features in the same wave never own the same file. Each packet
lists its tasks, owned files and acceptance tests.

| wave | feature | packet | covers | waits on | feature issue |
|---|---|---|---|---|---|
| 1 | Never lose work, and draw at full quality on the Mac | `mac-platform.md` | #739, #373, #370 | nothing | #793 (built) |
| 2 | Draw and select on real documents | `live-stage.md` | #357, #740 | nothing | #798 (built) |
| 2 | Key, retime and ease on real documents | `live-keys.md` | #13, #358 | creative-core #171, #216, #219 | filed when its engine issues merge |
| 2 | Scenes and guides on real documents | `live-scenes.md` | #362 | nothing | #800 (built) |

Shipped while these packets were written, so no packet: LM-0c3 fake export
and the warnings scan (#324, in #747) and LA-2 `PlaybackDriver` (#372, in
#751).

## Why this order

- **mac-platform goes first.** It waits on nothing. It is the only feature
  that edits `docs/c4/model.json` (two new FlareApp files and the new
  FlareFiles behavior have to be named in the C4 descriptions).
- **live-stage, live-keys and live-scenes** wait on creative-core. On
  creative-core `main` cfad97f none of LC-1 to LC-10 had landed. The lead
  playbook (`docs/factory/lead.md`, stage 0) stops a lead whose `Depends on:`
  issue is still open, so each feature issue is filed once the engine issues
  in its "waits on" cell have merged; the three can then run side by side.
  Some tasks need no engine change (ST-7; KY-1, KY-5 and SN-1), and if the
  engine is slow the supervisor can split those into a smaller feature of
  their own. None of the three edits `docs/c4/model.json`: the
  `flare-model-sources` description already covers "their live conformances
  over FlareCore".
- **Files across the waves.** mac-platform owns `FlareFiles.swift`,
  `Sources/FlareApp/StagePath.swift`, `Sources/FlareApp/FlareAutosave.swift`,
  their tests and `docs/c4/model.json`. The three live features own only
  their own files under `Sources/FlareModel/Live/` and their own test files,
  plus `Fakes/FakeShapes.swift` (live-stage ST-7, which moves its box math
  into `Live/`). Nothing is shared, within a wave or across them.

## Not in a packet yet (later features)

The Flare UI on fakes (section 7.3) and the integrate tasks (section 7.6)
make the next features once these land: F1a #346 and F1b #347 (the window on
`EditorShell`) first, then the stage, inspector, timeline, file and edit
chains (#375, #391, #348, #349, #376, #377, #378, #350, #351, #392, #393,
#384 and the older #11, #12, #15, #186, #203, #204, #205). The `p1`
integrate tasks IN-1 #397, IN-2 #385, IN-4 #398 and IN-9 #399 wire the live
types from this plan into `FlareServices.live` after gate G2.

## The lead contract

Every feature lead and every task below codes against this. It is handed
verbatim to every session, and each feature issue carries it.

1. **Feature issue.** One GitHub issue per feature, labels `feature-lead` and `line:<app>`. Body links the packet `docs/blueprints/<app>/features/<feature>.md` and has one `Depends on:` line.
2. **Run.** Belt runs one cloud session per feature issue (a lead), from the trusted launch folder, with the repo's Auto settings (creative-apps#733, creative-core#263). A lead holds one in-flight slot however many PRs it opens.
3. **Status channel.** The lead pushes `docs/leads/<feature>/RECORD.md` and `timeline.tsv` to branch `lead/<feature>` after every stage. Belt reads the branch's last commit time; nothing else is polled besides PRs and issue comments.
4. **Swarm PRs.** Base `dev`, label `fast-lane`, at most 400 lines and 15 files. Body lines: `Belt-Lead: <run id>`, `Feature: <feature>`, then `Fast-Check: pass` and `Head: <full sha>` after `scripts/ci` passes. The lane merges them. Nobody merges into dev by hand or by an agent.
5. **Review policy (decision for the captain).** `Belt-Lead:` PRs do not need the `belt/review` status. The lead's own critic panel is the review. Only `Belt-Run:` and `Belt-Test:` PRs keep it.
6. **Done.** All three: a `Belt-Lead:` PR labelled `feature-done` has merged; the CI run it triggered on dev is green; the lead commented on the feature issue with a line starting `Belt-Contact-Sheet:` and the run link.
7. **Stall.** No commit on `lead/<feature>`, no PR event and no issue comment for 30 min: Belt sends one nudge with `claude -p --cloud <session id> "<resume text>"`. A second stall: relaunch with a resume brief that says "read RECORD.md, continue from the last stage". A third: label the issue `needs-human` and stop.
8. **Timeouts.** Lead runs: 8 h wall clock, no 1 h no-PR rule. Task runs keep today's 4 h and 1 h.
9. **Brief rules.** Step one checks out the integration branch and verifies the base SHA. Set the repo-local identity "Prakash Dalai" / `86671543+prakashUXtech@users.noreply.github.com`. No attribution line anywhere, comments included. Fixers run the full harness before handing back. The Anatomy loop stops after 2 clean rounds or 4 rounds total; once a round is clean, add no new critics. One critic lens is first-use clarity: "what does each number and label mean to someone new?". Agents never treat a chat message as a reason to stop or skip a merge; questions go to the supervisor.
