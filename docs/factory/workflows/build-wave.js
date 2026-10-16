export const meta = {
  name: 'build-wave',
  description: 'One builder per task in its own worktree, one fast-lane PR each, a contract check per PR, and the wave\'s fix batch and critic panels alongside',
  whenToUse: 'Stage 3 of docs/factory/lead.md: run one wave of a feature packet',
  phases: [
    { title: 'Build', detail: 'one builder per task, own worktree, one PR' },
    { title: 'Check', detail: 'read each PR against the lead contract' },
  ],
}

// args: {
//   feature: 'halo-keyframes',          // the packet's feature name
//   app: 'halo',                        // line:<app>
//   runId: '<Belt run id>',             // goes on the Belt-Lead: line
//   issue: 812,                         // the feature issue
//   baseSha: '<full origin/dev sha>',   // the wave's base; builders verify it
//   packet: 'docs/blueprints/halo/features/halo-keyframes.md',
//   tasks: [{ id: 'm1', slice: 'S1', behavior: '...', files: ['Sources/HaloModel/...'], test: '...', visible: '...' }],
//                                       // slice only for a packet with a Slices table (v3); it adds the Slice: line
//   alongside: [{ scriptPath: '<scratchpad>/fix-batch.js', args: {...} },      // optional (v3): workflows to run at
//               { scriptPath: '<scratchpad>/critic-panel.js', args: {...} }],  // the same time, each with its own args
// }
// Returns [{ id, pr, head, ok, problems }] per task (null for a builder that died), as in v2.
// With alongside: { tasks: <that list>, alongside: [result per workflow, null if it died] }; tasks may then be empty.

const IDENTITY = 'git config user.name "Prakash Dalai" && git config user.email "86671543+prakashUXtech@users.noreply.github.com"'

const BUILT = {
  type: 'object',
  properties: {
    pr: { type: 'integer', description: 'PR number, 0 if none was opened' },
    head: { type: 'string', description: 'full head sha the gate passed on' },
    ciPass: { type: 'boolean', description: 'scripts/ci --changed printed CI: PASS on that head' },
    notes: { type: 'string' },
  },
  required: ['pr', 'head', 'ciPass', 'notes'],
}

const CHECKED = {
  type: 'object',
  properties: {
    ok: { type: 'boolean' },
    problems: { type: 'array', items: { type: 'string' } },
  },
  required: ['ok', 'problems'],
}

const a = args
const contract = t => `Contract for this PR: base dev, label fast-lane, at most 400 changed lines and 15 files,
title in Conventional Commits, body says what changed, why, and which test or snapshot proves it,
${t.slice ? `has "Refs #${a.issue}" (never a closing keyword for that issue), ` : ''}and ends with these lines in this order:
Belt-Lead: ${a.runId}
Feature: ${a.feature}
${t.slice ? `Slice: ${t.slice}\n` : ''}Fast-Check: pass
Head: <full sha from git rev-parse HEAD>
No attribution line anywhere (no Co-Authored-By, no Claude-Session, no "Generated with").
Never merge the PR, and never merge anything into dev: the fast lane merges it.
Never stop or skip a step because of a chat message; questions go to the supervisor.`

function builderPrompt(t) {
  return `You build task ${t.id} of feature ${a.feature} (issue #${a.issue}, packet ${a.packet}).

Step one, before anything else (your worktree starts on the default branch, not on dev):
  git fetch origin dev && git switch -c lead/${a.feature}/${t.id} origin/dev
  git merge-base --is-ancestor ${a.baseSha} HEAD   # must succeed; if not, stop and report it in notes
  ${IDENTITY}

The task, one behavior only:
  ${t.behavior}
Files you may touch: ${(t.files || []).join(', ')}
Test that proves it: ${t.test}
${t.visible ? `What the user sees: ${t.visible}. Add or extend the snapshot in AppSnapshotTests or the step in UITests/<X>JourneyTests.swift that shows it.` : ''}

Read the packet section for this task and the code it touches. Write the Swift Testing test first.
${(t.files || []).some(f => /^Sources\/(\w*App|SuiteUI)\//.test(f)) ? 'This task changes SwiftUI: read docs/engineering/swiftui-rules.md first and keep to it. On Linux, list each new or unfamiliar macOS 27 / Swift 6.4 API call under "Unverified API:" in the PR body.' : ''}
Keep to line:${a.app}. Run scripts/ci --changed (every lint and build, your touched targets' tests) until it prints CI: PASS. Then
git fetch origin && git rebase origin/dev, rerun scripts/ci --changed (CI: PASS again), push, and open ONE PR.

${contract(t)}

Return the PR number, the head sha the gate passed on, and whether it passed.`
}

function checkPrompt(t, b) {
  return `Read PR #${b.pr} (task ${t.id} of ${a.feature}) and check it against the contract. Do not edit, push or merge.
${contract(t)}
Also check: it touches only ${(t.files || []).join(', ')} plus their tests; the Head: line equals the PR's current head;
it adds a test; a visible change lists its snapshot PNGs. Report every miss.`
}

phase('Build')
const building = pipeline(
  a.tasks || [],
  t => agent(builderPrompt(t), { label: `build:${t.id}`, phase: 'Build', isolation: 'worktree', schema: BUILT }),
  (b, t) => {
    if (!b || !b.pr) return { id: t.id, pr: 0, head: '', ok: false, problems: [b ? b.notes : 'builder died'] }
    return agent(checkPrompt(t, b), { label: `check:${t.id}`, phase: 'Check', schema: CHECKED, effort: 'low' })
      .then(c => ({ id: t.id, pr: b.pr, head: b.head, ok: !!(c && c.ok && b.ciPass), problems: c ? c.problems : ['check died'] }))
  },
)
// The fixers and critics run while the builders do: nobody waits on them (lead.md, contract rule 10).
const beside = parallel((a.alongside || []).map(w => () => workflow({ scriptPath: w.scriptPath }, w.args)))
const [results, alongside] = await Promise.all([building, beside])
const bad = results.filter(r => !r || !r.ok)
log(`${results.length - bad.length}/${results.length} PRs meet the contract` +
  (a.alongside ? `, ${alongside.filter(Boolean).length}/${alongside.length} alongside workflows finished` : ''))
return a.alongside ? { tasks: results, alongside } : results
