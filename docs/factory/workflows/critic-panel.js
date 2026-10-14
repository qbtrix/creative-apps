export const meta = {
  name: 'critic-panel',
  description: 'One critic per lens over a CI run\'s screens and audit, then a refuting verifier per finding',
  whenToUse: 'Stage 4 of docs/factory/lead.md: one Anatomy loop round\'s review',
  phases: [
    { title: 'Critique', detail: 'one critic per lens' },
    { title: 'Verify', detail: 'one verifier per finding tries to refute it' },
  ],
}

// args: {
//   feature: 'halo-keyframes', app: 'halo', round: 2,
//   packet: 'docs/blueprints/halo/features/halo-keyframes.md',
//   run: '<CI run link>',
//   screens: '<scratchpad>/ui-screens',     // downloaded ui-screens artifact (PNGs, contact-sheet.html, audit-*.json)
//   snapshots: '<scratchpad>/snapshots',    // downloaded snapshots artifact
//   audit: 'halo: overlap 0 (=), contrast 1 (↓)',  // the contact sheet's audit row for the app
//   lenses: ['clarity', 'journey', ...],    // optional; keep the same list after a clean round
// }
// Returns { clean, confirmed: [finding], refuted: n }. clean = no confirmed blocker or major.

const LENSES = {
  clarity: 'First-use clarity: what does each number and label mean to someone new? Flag any value without a unit or context, any jargon, any icon without a label or tooltip, and any state a first-time user cannot read.',
  journey: 'The packet\'s journeys: walk each one through the screens in order. Flag a step that is missing, out of order, or ends somewhere the packet does not say.',
  design: 'docs/design.md: spacing, alignment, type, color tokens, glass, component order, light and dark. Flag anything that breaks a rule, naming the rule.',
  layout: 'Geometry: clipped or overlapping content, controls off-window or under the toolbar, panels too narrow to read, text truncation. Propose a geometric test (frames inside the window, no overlap, minimum sizes) for each.',
  controls: 'No dead controls (CLAUDE.md): every visible button, tool and menu item acts or is disabled with help text that says why.',
  audit: 'The app audit: every count over baseline, and the screen and element behind it.',
  quality: 'The packet\'s quality bars and docs/review-rubric.md section 6 budgets: any perf report line over budget.',
}
const lenses = (args.lenses && args.lenses.length ? args.lenses : ['clarity', 'journey', 'design', 'layout', 'controls'])
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

const ctx = `Feature ${args.feature} (line:${args.app}), Anatomy round ${args.round}, CI run ${args.run}.
Packet: ${args.packet}. Screens: ${args.screens} (open contact-sheet.html first). Snapshots: ${args.snapshots}.
Audit: ${args.audit}. Look at the PNGs themselves. Report only; do not edit, push or merge.`

phase('Critique')
const verified = await pipeline(
  lenses,
  lens => agent(`${ctx}\n\nYour lens: ${LENSES[lens] || lens}\nReport each problem once, only from this lens. No problem: return an empty list.`,
    { label: `critic:${lens}`, phase: 'Critique', schema: FINDINGS }),
  (r, lens) => parallel((r ? r.findings : []).map(f => () =>
    agent(`${ctx}\n\nA ${lens} critic reports (${f.severity}) on ${f.screen}: ${f.what}\nWhy: ${f.why}\n` +
      'Try to refute it: check the screen and the code. refuted=true if it is not visible, not a problem, ' +
      'already fixed on dev, or outside this feature. Keep it only if you can see it.',
      { label: `verify:${lens}`, phase: 'Verify', schema: VERDICT, effort: 'low' })
      .then(v => ({ ...f, lens, refuted: !v || v.refuted, reason: v ? v.reason : 'verifier died' })))),
)
const all = verified.filter(Boolean).flat().filter(Boolean)
const confirmed = all.filter(f => !f.refuted)
const clean = !confirmed.some(f => f.severity !== 'minor')
log(`round ${args.round}: ${confirmed.length} confirmed, ${all.length - confirmed.length} refuted, ${clean ? 'clean' : 'not clean'}`)
return { clean, confirmed, refuted: all.length - confirmed.length }
