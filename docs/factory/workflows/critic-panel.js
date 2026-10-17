export const meta = {
  name: 'critic-panel',
  description: 'One critic per lens over a CI run\'s screens and audit, a refuting verifier per finding, then the confirmed ones filed as finding issues',
  whenToUse: 'docs/factory/lead.md: a slice\'s review in v3 stage 3, or an Anatomy round\'s review in v2 stage 4',
  phases: [
    { title: 'Critique', detail: 'one critic per lens' },
    { title: 'Verify', detail: 'one verifier per finding tries to refute it' },
    { title: 'File', detail: 'one finding issue per confirmed finding (findings queue only)' },
  ],
}

// args: {
//   feature: 'halo-keyframes', app: 'halo',
//   packet: 'docs/blueprints/halo/features/halo-keyframes.md',
//   run: '<CI run link>',                   // v3: the scoped run
//   screens: '<scratchpad>/ui-screens',     // downloaded ui-screens artifact (PNGs, contact-sheet.html, audit-*.json)
//   snapshots: '<scratchpad>/snapshots',    // downloaded snapshots artifact
//   audit: 'halo: overlap 0 (=), contrast 1 (↓)',  // the contact sheet's audit row for the app
//   lenses: ['clarity', 'journey', ...],    // optional; keep the same list after a clean review. v3 default adds 'oracle'
//   round: 2,                               // v2: the Anatomy round
//   // The findings queue (work started after lead.md's v3 contract landed):
//   issue: 812,                             // the feature issue; with it, confirmed findings are filed as issues
//   commit: '<the run\'s full head sha>',
//   open: [{ number: 901, title: '...' }],  // the feature's open finding issues, so nothing is filed twice
//   slice: 'S2', journeys: ['H-J3'],        // v3 only: the slice and its journeys; judge only their screens
//   ui: true,                               // v3 UI slice ("ui": true in .wave.json): adds the mouse and taste lenses
//                                           // (lead.md rule 15, the feel gate); pass it from the slice's first review
// }
// Without issue (v2 work started before): returns { clean, confirmed: [finding], refuted: n } as it always did.
// With issue: returns { clean, filed: [issue numbers], confirmed: n, refuted: n }.
// clean = no confirmed blocker or major. Critics and verifiers only read; the filer only opens issues.

const LENSES = {
  clarity: 'First-use clarity: what does each number and label mean to someone new? Flag any value without a unit or context, any jargon, any icon without a label or tooltip, and any state a first-time user cannot read.',
  journey: `The ${args.slice ? 'slice' : 'packet'}'s journeys: walk each one through the screens in order. Flag a step that is missing, out of order, or ends somewhere the packet does not say.`,
  design: 'docs/design.md: spacing, alignment, type, color tokens, glass, component order, light and dark. Flag anything that breaks a rule, naming the rule. ' +
    'Also flag an app-local view that copies a SuiteUI component or a pattern another app already has (SuiteUI first, lead.md rule 16); the fix moves it to SuiteUI. ' +
    `And read the Swift files the ${args.slice ? 'slice' : 'feature'}'s merged PRs added under Sources/*Model/ and Sources/*App/: flag logic for a concept SuiteModel, creative-core or another app's Model already has, ` +
    'or app-local undo, history, selection, layer tree, parenting, transform, marquee, snap, keyframe, easing, export or crop logic, the editor-kernel concepts (canonical first, lead.md rule 20; ' +
    'an <X>+Kernel.swift or <X>Adapter.swift adapter onto SuiteModel is fine). Use "-" for the screen; the fix uses the SuiteModel module or extracts the concept into it.',
  mouse: 'Mouse-only first-time user (the feel gate, lead.md rule 15): you know no shortcuts and only click what you see. Flag every new screen or mode you cannot enter or leave ' +
    'with a visible control (a blocker), any control with no hover or pressed state, and anything reachable only by a key or a menu shortcut. ' +
    'Check the journey steps too: a mode change proven only by a key press is a finding.',
  taste: 'Taste (the feel gate, lead.md rule 15): compare the slice\'s snapshots and screens with the taste board, docs/design/taste in paw-workspace, if this session can read it ' +
    '(judge against weight-3 references first). Otherwise compare with the suite\'s reference look: Flare\'s easing panel, StudioScrubRow and ChoiceChips. ' +
    'Flag what looks dated or basic next to it (flat controls with no feedback, cramped or uneven rows, missing live values), naming the reference.',
  layout: 'Geometry: clipped or overlapping content, controls off-window or under the toolbar, panels too narrow to read, text truncation. Propose a geometric test (frames inside the window, no overlap, minimum sizes) for each.',
  controls: 'No dead controls (CLAUDE.md): every visible button, tool and menu item acts or is disabled with help text that says why.',
  audit: 'The app audit: every count over baseline, and the screen and element behind it.',
  quality: 'The packet\'s quality bars and docs/review-rubric.md section 6 budgets: any perf report line over budget.',
  oracle: 'Test the oracle (docs/factory/lead.md, contract rule 14): would a planted bug in this code fail a test? This lens reads code, not PNGs: ' +
    `the Model source the ${args.slice ? 'slice' : 'feature'}'s merged PRs changed (their Slice: and Feature: lines), the tests that cover it, and its plans in Tests/mutations/. ` +
    'Name one mutation that would escape: the file, the exact line, the change (a dropped guard, <= for <, a skipped filter), and why no test fails. ' +
    'Use "-" for the screen. The fix is the test that catches it plus that mutation in the file\'s plan.',
}
const lenses = (args.lenses && args.lenses.length ? args.lenses
  : ['clarity', 'journey', 'design', 'layout', 'controls', ...(args.slice ? ['oracle'] : [])])
if (args.ui) for (const l of ['mouse', 'taste']) if (!lenses.includes(l)) lenses.push(l)
if (!lenses.includes('clarity')) lenses.unshift('clarity')

const FINDINGS = {
  type: 'object',
  properties: {
    findings: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          severity: { type: 'string', enum: ['blocker', 'major', 'minor'] },
          screen: { type: 'string', description: 'PNG file name the finding is visible in, or "-"' },
          what: { type: 'string' },
          why: { type: 'string', description: 'the rule, journey step or user confusion it breaks' },
          fix: { type: 'string', description: 'the smallest change that fixes it' },
          files: { type: 'array', items: { type: 'string' } },
          test: { type: 'string', description: 'the test that would fail before the fix' },
        },
        required: ['severity', 'screen', 'what', 'why', 'fix', 'files', 'test'],
      },
    },
  },
  required: ['findings'],
}
const VERDICT = {
  type: 'object',
  properties: { refuted: { type: 'boolean' }, reason: { type: 'string' } },
  required: ['refuted', 'reason'],
}
const FILED = {
  type: 'object',
  properties: { issues: { type: 'array', items: { type: 'integer' }, description: 'numbers of the issues opened' } },
  required: ['issues'],
}

const queue = !!args.issue
const scope = args.slice ? 'slice' : 'feature'
const open = (args.open || []).map(o => `#${o.number} ${o.title}`).join('\n') || '(none)'
const ctx = args.slice
  ? `Feature ${args.feature} (line:${args.app}), slice ${args.slice}, scoped CI run ${args.run} at ${args.commit}.
Packet: ${args.packet}. Journeys of this slice: ${(args.journeys || []).join(', ')}.
Screens: ${args.screens} (open contact-sheet.html first; judge only these journeys' screens). Snapshots: ${args.snapshots}.
Audit: ${args.audit}. Look at the PNGs themselves. Report only; do not edit, push or merge.`
  : `Feature ${args.feature} (line:${args.app}), Anatomy round ${args.round}, CI run ${args.run}.
Packet: ${args.packet}. Screens: ${args.screens} (open contact-sheet.html first). Snapshots: ${args.snapshots}.
Audit: ${args.audit}. Look at the PNGs themselves. Report only; do not edit, push or merge.`

phase('Critique')
const verified = await pipeline(
  lenses,
  lens => agent(`${ctx}\n\nYour lens: ${LENSES[lens] || lens}\nReport each problem once, only from this lens. No problem: return an empty list.`,
    { label: `critic:${lens}`, phase: 'Critique', schema: FINDINGS }),
  (r, lens) => parallel((r ? r.findings : []).map(f => () =>
    agent(`${ctx}\n\nA ${lens} critic reports (${f.severity}) on ${f.screen}: ${f.what}\nWhy: ${f.why}\n` +
      (lens === 'oracle'
        ? 'Try to refute it: read the tests, or run it with scripts/mutate as a one-entry plan. refuted=true if a test fails with that change, the change cannot alter behaviour, '
        : 'Try to refute it: check the screen and the code. refuted=true if it is not visible, not a problem, ') +
      (queue ? `already fixed on dev, outside this ${scope}, or already covered by one of these open findings:\n${open}\n`
        : 'already fixed on dev, or outside this feature. ') +
      'Keep it only if you can see it.',
      { label: `verify:${lens}`, phase: 'Verify', schema: VERDICT, effort: 'low' })
      .then(v => ({ ...f, lens, refuted: !v || v.refuted, reason: v ? v.reason : 'verifier died' })))),
)
const all = verified.filter(Boolean).flat().filter(Boolean)
const confirmed = all.filter(f => !f.refuted)
const clean = !confirmed.some(f => f.severity !== 'minor')
if (!queue) {
  log(`round ${args.round}: ${confirmed.length} confirmed, ${all.length - confirmed.length} refuted, ${clean ? 'clean' : 'not clean'}`)
  return { clean, confirmed, refuted: all.length - confirmed.length }
}

// One filer for the whole panel: two lenses can report the same problem, and it needs them all to merge them.
let filed = []
if (confirmed.length) {
  phase('File')
  const list = confirmed.map((f, i) => `${i + 1}. (${f.severity}, ${f.lens}) ${f.what}\n   screen: ${f.screen}\n   why: ${f.why}\n` +
    `   fix: ${f.fix}\n   files: ${f.files.join(', ')}\n   test: ${f.test}`).join('\n')
  const r = await agent(`File the confirmed findings of a critic panel as GitHub issues on this repo. Do not edit code, push or merge.

First, once: gh label create finding --color D93F0B --description "Critic finding a feature lead fixes" --force

Findings (feature ${args.feature}${args.slice ? `, slice ${args.slice}` : ''}, run ${args.run}, commit ${args.commit}):
${list}

Two entries about the same problem on the same screen become one issue. Skip one an open finding already covers:
${open}

Each issue: gh issue create --label finding --label line:${args.app} --title "${args.feature}${args.slice ? ` ${args.slice}` : ''}: <what, short> (<severity>)"
and a body with what, why, the fix, "Files: <comma separated>", "Test: <test>", "Screen: <png>", "Lens: <lens>",
then these lines at the end, each on its own line:
Feature: ${args.feature}
${args.slice ? `Slice: ${args.slice}\n` : ''}Commit: ${args.commit}
Run: ${args.run}
Refs #${args.issue}
No closing keyword anywhere, and no attribution line. Return the numbers of the issues you opened.`,
  { label: 'file', phase: 'File', schema: FILED, effort: 'low' })
  filed = r ? r.issues : []
  if (!r) log('filer died: confirmed findings were not filed, rerun with resumeFromRunId')
}
log(`${args.slice || 'round ' + args.round}: ${confirmed.length} confirmed, ${all.length - confirmed.length} refuted, ${filed.length} issues filed`)
return { clean, filed, confirmed: confirmed.length, refuted: all.length - confirmed.length }
