export const meta = {
  name: 'prospector-research',
  description: 'Discovery-first research: locate, deepen, verify every load-bearing claim, synthesize',
  phases: [
    { title: 'Locate' }, { title: 'Deepen' }, { title: 'Verify' }, { title: 'Synthesize' },
  ],
}

// Normalize args ONCE: the Workflow tool may pass `args` JSON-stringified.
// Read every field from these locals so a stringified payload never yields undefined.
const input = typeof args === 'string' ? JSON.parse(args) : args
const q = input.question
const outputShape = input.outputShape || 'report'
const destination = input.destination

const PLACE = { type: 'object', properties: { where: {type:'string'}, source: {type:'string'}, why: {type:'string'} }, required: ['where','source'] }
const LOCATE_SCHEMA = { type: 'object', properties: { places: { type: 'array', items: PLACE } }, required: ['places'] }

// Round 1 — Locate: fan out across the three discovery nets in parallel (barrier).
phase('Locate')
const rounds = await parallel([
  () => agent(`Search Glean for where this lives (repos, Confluence, Slack, Jira): "${q}". Return specific places.`, {label:'locate:glean', phase:'Locate', schema: LOCATE_SCHEMA}),
  () => agent(`Search GitHub org contentful via search_code and search_issues for: "${q}". Return specific repo+path and issue places.`, {label:'locate:github', phase:'Locate', schema: LOCATE_SCHEMA}),
  () => agent(`Search Jira via JQL for tickets/decisions about: "${q}". Return specific issue keys.`, {label:'locate:jira', phase:'Locate', schema: LOCATE_SCHEMA}),
])
const places = rounds.filter(Boolean).flatMap(r => r.places)

// Round 1 -> Round 2 — Deepen: pipeline each located place independently (no barrier).
phase('Deepen')
const READ_SCHEMA = { type:'object', properties:{ where:{type:'string'}, tier:{type:'string'}, content:{type:'string'}, unreachable:{type:'boolean'} }, required:['where','tier'] }
const readings = await pipeline(
  places,
  place => agent(`Pull ground truth for ${place.where} (source ${place.source}). Local repos/ grep if cloned, else GitHub get_file_contents / Glean read_document / Jira getJiraIssue. Tag the fidelity tier. If unreachable, say so with the reason.`, {label:`deepen:${place.where}`, phase:'Deepen', schema: READ_SCHEMA})
)
const evidence = readings.filter(Boolean).filter(r => !r.unreachable)

// Verify: draft the load-bearing claims, then refute each one in parallel against its source.
phase('Verify')
const CLAIMS_SCHEMA = { type:'object', properties:{ claims: { type:'array', items:{ type:'object', properties:{ claim:{type:'string'}, source:{type:'string'} }, required:['claim','source'] } } }, required:['claims'] }
const draft = await agent(`From this evidence, list the load-bearing claims (statements that would change the answer to "${q}" if false), each with its source.\n${JSON.stringify(evidence)}`, {label:'draft-claims', phase:'Verify', schema: CLAIMS_SCHEMA})
const VERDICT = { type:'object', properties:{ claim:{type:'string'}, survives:{type:'boolean'}, tier:{type:'string'}, note:{type:'string'} }, required:['claim','survives'] }
const verdicts = await parallel(draft.claims.map(c => () =>
  agent(`Try to REFUTE this claim by reading its cited source (${c.source}). Claim: "${c.claim}". Default survives=false if you cannot confirm against the source. Report the fidelity tier of the source.`, {label:`verify:${c.claim.slice(0,30)}`, phase:'Verify', schema: VERDICT})
))
const verified = verdicts.filter(Boolean).filter(v => v.survives)

// Synthesize: emit the chosen output shape using ONLY verified claims, each source-tagged.
phase('Synthesize')
const answer = await agent(`Write the "${outputShape}" output for "${q}" using ONLY these verified claims. Every claim carries its source pointer. End with a ## Sources section listing each source with its fidelity tier.\nVERIFIED: ${JSON.stringify(verified)}`, {label:'synthesize', phase:'Synthesize'})
return { answer, verifiedCount: verified.length, destination }
