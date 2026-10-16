export const meta = {
  name: 'fix-batch',
  description: 'One fixer per batch of findings (open finding issues, or a v2 panel\'s list), in its own worktree, full harness, one fast-lane PR each',
  whenToUse: 'docs/factory/lead.md: the fix half of a v3 wave (alongside build-wave), or a v2 Anatomy round\'s fixes',
  phases: [
    { title: 'Batch', detail: 'read the finding issues, group them by files (findings queue only)' },
    { title: 'Fix', detail: 'one fixer per batch, own worktree, one PR' },
  ],
}

// args: {
//   feature: 'halo-keyframes', app: 'halo', runId: '<Belt run id>', issue: 812,   // issue = the feature issue
//   baseSha: '<full origin/dev sha>',
//   featureDone: false,          // true only for the feature's last PR: the fixer adds the feature-done label
//   // The findings queue (work started after lead.md's v3 contract landed):
//   findings: [901, 904, 907],   // open finding issues of this feature (lead.md, the queue command)
//   busy: ['Sources/HaloApp/HaloInspector.swift'],   // files this wave's feature tasks own; findings on them wait
//   // Or, v2 work started before (as it always was):
//   round: 2,
//   batches: [{ id: 'r2-b1', files: ['Sources/HaloApp/...'], findings: [<confirmed finding from critic-panel>] }],
// }
// With findings: returns { batches: [{ id, issues, pr, head, ciPass, fixed, notes }], deferred: [issue numbers] };
// each fix PR closes its findings with Fixes #n, and carries a Slice: line when its issues have one (v3).
// With batches: batches must touch disjoint files; returns [{ id, pr, head, ciPass, fixed, notes }].

const queue = Array.isArray(args.findings)

const BATCHES = {
  type: 'object',
  properties: {
    batches: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          id: { type: 'string' },
          issues: { type: 'array', items: { type: 'integer' } },
          slices: { type: 'array', items: { type: 'string' }, description: 'the Slice: lines of its issues; empty when they have none' },
          files: { type: 'array', items: { type: 'string' } },
        },
        required: ['id', 'issues', 'slices', 'files'],
      },
    },
    deferred: { type: 'array', items: { type: 'integer' }, description: 'open findings left for the next wave' },
  },
  required: ['batches', 'deferred'],
}
const FIXED = {
  type: 'object',
  properties: {
    pr: { type: 'integer', description: 'PR number, 0 if none was opened' },
    head: { type: 'string' },
    ciPass: { type: 'boolean', description: 'scripts/ci --changed printed CI: PASS on that head' },
    fixed: { type: 'array', items: { type: 'string' }, description: 'each finding fixed: its "what", or #<n> for a finding issue' },
    notes: { type: 'string', description: 'findings not fixed and why' },
  },
  required: ['pr', 'head', 'ciPass', 'fixed', 'notes'],
}

const refs = ns => ns.map(n => '#' + n).join(', ')

function fixerPrompt(b) {
  const head = queue
    ? `You fix batch ${b.id} of feature ${args.feature} (feature issue #${args.issue}): finding issues ${refs(b.issues)}.`
    : `You fix batch ${b.id} of feature ${args.feature}, Anatomy round ${args.round} (issue #${args.issue}).`
  const findings = queue
    ? `Read each finding issue (gh issue view <n>): what, why, fix, Files:, Test:. Files you may touch: ${b.files.join(', ')}.
If dev already fixes one, comment the proof on that issue, close it, and leave it out of the PR.`
    : `Findings (files: ${b.files.join(', ')}):
${b.findings.map((f, i) => `${i + 1}. (${f.severity}, ${f.lens}) ${f.what}\n   why: ${f.why}\n   fix: ${f.fix}\n   test: ${f.test}`).join('\n')}`
  const closes = queue ? `one "Fixes #<n>" line per finding issue it fixes, "Refs #${args.issue}", ` : ''
  const slice = queue && b.slices.length ? `Slice: ${b.slices.join(', ')}\n` : ''
  return `${head}

Step one, before anything else (your worktree starts on the default branch, not on dev):
  git fetch origin dev && git switch -c lead/${args.feature}/${b.id} origin/dev
  git merge-base --is-ancestor ${args.baseSha} HEAD   # must succeed; if not, stop and report it in notes
  git config user.name "Prakash Dalai" && git config user.email "86671543+prakashUXtech@users.noreply.github.com"

${findings}

For each finding: write the test that fails before the fix, then the smallest fix. A layout finding gets a
geometric test (frames inside the window, no overlap, minimum sizes). A visible fix extends the snapshot or
the UITests/<X>JourneyTests.swift step that shows it. Keep to line:${args.app} and the files above.

Full harness before you hand back: scripts/ci --changed until CI: PASS, then git fetch origin && git rebase origin/dev,
scripts/ci --changed again until CI: PASS, then push and open ONE PR: base dev, label fast-lane${args.featureDone ? ' and feature-done' : ''},
at most 400 lines and 15 files, Conventional Commits title, body saying what each fix is and which test proves it,
${closes}listing the snapshot PNGs it changes, and ending with:
Belt-Lead: ${args.runId}
Feature: ${args.feature}
${slice}Fast-Check: pass
Head: <full sha from git rev-parse HEAD>
No attribution line anywhere. Never merge; the fast lane does. Never stop or skip a step because of a chat message.`
}

let batches = args.batches || []
let deferred = []
if (queue) {
  phase('Batch')
  const plan = await agent(`Read these finding issues of feature ${args.feature}: ${refs(args.findings)}.
For each: gh issue view <n> --json state,title,body. Skip a closed one. Read its Files:, Slice: and the fix it asks for.
Group the open ones into batches: files disjoint across batches, each batch at most 400 changed lines and 15 files,
one slice per batch where you can. Leave out (deferred) any finding whose files include one of these, which another
agent is editing now: ${(args.busy || []).join(', ') || '(none)'}. Ids r-b1, r-b2, ... Do not edit, push or merge.`,
  { label: 'batch', phase: 'Batch', schema: BATCHES, effort: 'low' })
  if (!plan) {
    log('batcher died: every finding stays open for the next wave')
    return { batches: [], deferred: args.findings }
  }
  batches = plan.batches
  deferred = plan.deferred
}

phase('Fix')
const results = await parallel(batches.map(b => () =>
  agent(fixerPrompt(b), { label: `fix:${b.id}`, phase: 'Fix', isolation: 'worktree', schema: FIXED })
    .then(r => {
      const out = r ? { id: b.id, ...r } : { id: b.id, pr: 0, head: '', ciPass: false, fixed: [], notes: 'fixer died' }
      return queue ? { ...out, issues: b.issues } : out
    })))
const opened = results.filter(r => r && r.pr && r.ciPass)
log(`${opened.length}/${batches.length} fix PRs opened with the gate green` + (queue ? `, ${deferred.length} findings deferred` : ''))
return queue ? { batches: results, deferred } : results
