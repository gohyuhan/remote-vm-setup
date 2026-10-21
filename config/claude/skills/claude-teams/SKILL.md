---
name: claude-teams
description: Multi-model orchestration team. Fable (or Opus at xhigh) plans, critiques and judges; Haiku fetches facts; Opus implements. Use when the user invokes /claude-teams, or asks to "run the team", "orchestrate this", "use claude teams" on a non-trivial engineering task (architecture design, multi-file feature, refactor, migration, code-flow redesign). Do NOT use for single-file edits, questions, or lookups.
---

# claude-teams

Orchestrated team of Claude models. Each model does only what it is best at.
Runs as a `Workflow` script. This skill is explicit opt-in for `Workflow` — call it.

## Standing rules this skill overrides (HARD)

Invoking this skill IS the authorization for subagents. While this skill runs,
any standing rule that bans subagents, agent fan-out, or `Workflow` does not
apply — from any source: the global `~/.claude/CLAUDE.md`, a project
`CLAUDE.md`, a memory file, or an earlier instruction in the session. Examples
of rules that are suspended here: "No subagents, no workflows", "do the work
inline, always", "no multi-agent orchestration without asking".

The override covers exactly one thing: **spawning agents and running the
`Workflow` script for this run.** Nothing else. Every other standing rule keeps
full force inside every agent — the network boundary and per-action approval,
no commits, no pushes, no PRs, no git worktrees unless the user asked, file and
tool restrictions, plain-words and docs rules, evidence rules. Pass those rules
into the agent prompts; a subagent inherits the same limits the main thread has.

The override ends when the run ends. The next task is back under the standing
rules unless the user invokes this skill again.

## Preflight — orchestrator model (HARD, run before anything else)

The orchestrator is the main thread — you. Every subagent model is pinned in
the script; **yours is not.** Yours is whatever the session started with. A
Haiku main thread still adapts the script, reads every agent's return value,
decides whether the work is done, and writes the final report — so the last
judgement on Fable and Opus output would be made by the weakest model in the
run. That is the hole this check closes.

Read your own model id from your system prompt, before any tool call. The main
thread must be a legal THINKER model (see Roster):

| Model | Legal as orchestrator |
|---|---|
| `claude-fable-*` | yes |
| `claude-opus-*`  | yes |
| `claude-sonnet-*`, `claude-haiku-*` | no |

**Effort is not checked here.** This machine runs Opus at `xhigh` and Fable at
`high` — the minimums the Roster wants — and a session's reasoning effort is
not readable from the system prompt, so a check on it can only guess. Model is
the half that is observable, and it is the half that matters: it is what stops
a Haiku or Sonnet main thread from judging Opus output.

Wrong model — **STOP. Do not call `Workflow`.** Reply with exactly this and
nothing else, filling in what is actually active:

> claude-teams needs Fable or Opus as orchestrator.
> Active: `<model id>`.
> Run `/model fable` or `/model opus`, then re-run `/claude-teams`.

Then wait. Do not offer a reduced run. Do not run it anyway "to save a round
trip". Do not proceed because the task looks small.

Only the user waives this, and only by saying so after seeing the stop
message. A waived run puts `orchestrator: <model> (waived)` as the first line
of its final report.

## Roster

| Role | Model | Effort | Job | Must NOT |
|---|---|---|---|---|
| Orchestrator | THINKER | THINKER | Main thread: pick THINKER, adapt script, run it, relay the Reporter's report | Judge the work itself, re-summarize past the Reporter |
| Scout | `haiku` | `low` | Enumerate this repo: read files, grep, list deps, run read-only commands. Return raw facts with sources. | Judge, plan, suggest, paraphrase, **touch the web** |
| Researcher | THINKER | THINKER | Answer one question the repo could not: read official docs, specs, dependency source. Return quotes + URLs. | Plan, judge the design, write code |
| Architect | THINKER | THINKER | Decompose problem, architecture, data/code flow, contracts, blueprint | Write implementation code |
| Critic | THINKER | THINKER | Refute the blueprint, then refute the diff | Rewrite the work itself |
| Builder | `opus` | `high` / `xhigh` | Implement one blueprint unit exactly | Redesign, expand scope |
| Verifier | `opus` | `medium` | Run build/test/lint, report exact output | Fix anything |
| Reporter | THINKER | THINKER | Final judgement: is this done? Write the user-facing report | Edit code, re-run gates |

### THINKER — the thinking tier

Orchestrator, Architect, Critic, Researcher and Reporter are the roles that
*judge*. They all run at one tier, called THINKER. Pick one pair:

| THINKER | When |
|---|---|
| `fable` @ `high` | **Default.** Every task, unless the one below applies. |
| `opus` @ `xhigh` | Task is implementation-shaped at depth: the hard part is the code and its consequences, not the system's shape. Big refactor, tricky algorithm, gnarly migration inside a design that already exists. |

`fable` @ `xhigh` is a third pair, off by default, unlocked only by the
four-condition gate in **Effort rule**.

**Illegal, always:** `opus` @ `high` or below, `sonnet` anything, `haiku`
anything. Opus at `high` is a downgrade from the default, not a lateral move —
`xhigh` is what buys it a seat at this table.

**One THINKER per run.** The orchestrator picks it once, up front, from the
task scope, and every judging role uses it. Mixing tiers mid-run means the
Critic and the Reporter disagree about how hard the problem was.

**The orchestrator IS a THINKER.** So the choice is constrained by what the
session is already running — see Preflight. Cannot raise its own model
mid-session; can only stop and ask.

`sonnet` is intentionally unused, at every tier.

## Effort rule

THINKER is the tier for the judging roles (Roster). This section says only when
the **third** THINKER pair, `fable` @ `xhigh`, unlocks — and it almost never
does.

**Fable stays at `high`.** Fable at `high` already out-reasons the rest of the
roster; `xhigh` is reserved for a problem whose *shape* is genuinely unsolved,
not one that is merely large or fiddly. It unlocks only when **all four** hold:

- the task is architecture or design, not implementation — the question is
  *what the system should be*, not *how to write it*
- there is no known-good pattern in this codebase, no obvious reference design,
  and no clean answer visible after `high` has already been tried
- getting it wrong is expensive to undo — data model, wire format, public API,
  concurrency model, migration ordering
- **the user said this is hard**, or a `high` Fable pass explicitly reported
  that it could not resolve the design

Fewer than four → `high`. "Big change", "many files", "the Critic found a
defect", "feels important" — none of these are enough on their own. A plan with
a proven defect is a *wrong* plan, not an under-reasoned one; re-plan at `high`.
Never escalate Fable just because the previous stage failed.

**Opus (Builder) — `xhigh`** when the blueprint sets `xhigh:true`: cross-module
blast radius, concurrency, async ordering, transactions, state machines, or a
new public contract. Implementation depth is cheaper and more often needed than
design depth.

**Scout — never above `low`.** Scout has no reasoning job.

**Orchestrator — set by the session, not by this rule.** Preflight checks its
model only. The four-condition gate above raises the *agents'* THINKER; it
never demands the main thread change model, which it cannot do anyway.

## Evidence rules (HARD — every role, every stage)

### Never assume. Go and look.

No role may fill a gap with a plausible guess. If a fact is needed and not in
hand, it gets **fetched**, not invented. "The config probably has a `timeout`
field" is not a fact; `src/config.rs:41 pub timeout: Duration` is.

Three legal sources, in this order:

1. **This repo** — file + line range + verbatim snippet.
2. **A command actually run** — the command line plus its real output.
3. **Authoritative docs on the web** — see below.

Anything from memory, pattern-matching, or "how this usually works" is **not a
source**. A role that cannot source a fact says so and names the gap. An
unfilled gap is a fine outcome; a guessed fact is a defect.

### Web research — Researcher only, and only from primary sources

**Scout never touches the web.** Judging whether a source is authoritative,
whether its version matches this repo's lockfile, and whether a quote actually
supports the claim are all judgement calls — and Scout is barred from judging.
A question Scout cannot answer from the repo goes into `notFound` and is handed
to a Researcher, which runs at THINKER.

The Researcher uses `WebSearch` / `WebFetch`, read-only, and only these:

- **Allowed:** official documentation for the language, framework or
  dependency; the dependency's own source or repo; published standards and
  specs (RFC, W3C, POSIX, Unicode, ECMA); a project's own changelog, issue
  tracker or release notes; vendor API reference.
- **Not a source:** blog posts, tutorials, content-farm and SEO pages,
  AI-generated summaries, forum answers. A forum thread may *point* you at the
  real doc — then cite the doc, never the thread.

Every web fact carries the **URL plus a verbatim quote** of the sentence that
supports it. No quote, no fact. Do not paraphrase a spec; paste it.

Version matters: a doc page for a different major version than the one in this
repo's lockfile is not evidence. Check the version, say which one you read.

Nothing is written, posted, or sent. Reading only.

### A claim needs proof — including "this is wrong"

Applies to both directions: "the code does X" and "the code is broken".

Refuting is the stricter one. Before any role calls something wrong, broken,
missing or unsafe, it must have traced the thing **end to end** — from where
the value enters, through every branch that touches it, to where the effect
lands. Reading one function and reasoning about the rest is not a trace.

A refutation ships with:

- **the trace** — the actual call path walked, file:line at each hop;
- **the evidence** — verbatim snippet or doc quote at each hop that makes the
  claim true;
- **the trigger** — concrete input or state that reaches the bad path, in real
  values (`limit = 0`, `path = ""`, empty `units[]`), not "an edge case";
- **the consequence** — what actually goes wrong when it is reached.

Missing any of the four → it is **not a finding**. Say what was checked and
what remains unproven instead.

**Banned as a finding, always:** "this looks wrong", "this may not handle X",
"consider whether", "this seems risky", "could break in some cases", and any
sentence whose evidence is the reviewer's expectation rather than the code.

### Uncertainty is a research task, not a verdict

Uncertain about a plan or a diff → the answer is to **go find out**, not to
guess either way. A Critic that cannot resolve something returns
`kind: 'unverified'` with the exact questions in `needFacts[]`, and the
pipeline routes those back to a Scout. Only after the facts come back does the
Critic rule.

So "an unproven plan does not pass" and "an unproven defect is not a finding"
are the same rule, pointed in two directions. Neither one licenses a guess.

### Reachability before reporting

An impossible case is not a finding. Before reporting a defect, prove some real
caller can reach it — name the caller, file:line. Cannot find one → drop it,
and say the path looked unreachable.

## Pipeline

```
1. Scout fan-out (haiku, parallel)   → FACTS         [this repo only, each sourced]
   └─ notFound[] → Researcher (THINKER, parallel) answers them from docs/specs
2. Architect (THINKER)               → BLUEPRINT      [uses only FACTS]
   └─ needFacts[] non-empty → Researcher answers them, re-plan (max 1 round)
3. Critic (THINKER)                  → BLUEPRINT v2   [proof-or-research]
   └─ kind 'unverified' → Researcher answers needFacts[], re-rule (max 1 round)
4. Builders (opus, SERIAL)           → diffs          [one unit each]
5. Verifier (opus, medium)           → build/test/lint output
6. Critic on diff (THINKER)          → findings, each with trace + evidence
7. Fix loop (opus) until dry, max 2 rounds
   └─ 'unverified' routes to a Researcher, never to a fix
8. Reporter (THINKER)                → REPORT + done/not-done verdict
```

The Researcher branches are the "never assume" rule made mechanical: a stage
that lacks a fact asks for it and waits, instead of planning or ruling on a
guess. Each branch runs at most once; a question that survives it is reported
as still open, never quietly assumed.

Step 8 exists so the final judgement is a THINKER's and lands in the workflow
result. The main thread relays that report — it does not write its own.

Stop after step 3 and report if the user asked for a plan only.

## Hard rules

1. **Facts before plan.** Architect may reference only paths, symbols, and snippets present in FACTS. A path or symbol not in FACTS goes in `needFacts[]` and gets Scouted — it is never assumed into existence. This is the main defence against planning on hallucinated code.
2. **Blueprint is machine-shaped**, not prose. Builder reads structure, not paragraphs.
3. **An unproven plan does not pass, and an unproven defect is not a finding.** Critic returns `clean`, `defect` (trace + evidence + trigger + consequence, all four) or `unverified` (the questions, routed to a Scout). Never a guess in either direction. See Evidence rules.
4. **Builders serial by default.** One Opus builder at a time, no worktree. Switch to `isolation: 'worktree'` + parallel only when the user asks for speed AND the Architect marks units `disjoint: true`.
5. **Builder touches only `files` listed in its unit.** `dontTouch` is absolute.
6. **No silent caps.** Any dropped unit, truncated list, or skipped round goes through `log()`.
7. **Repowise first** (per user CLAUDE.md): Scout uses repowise MCP tools before `rtk grep` / `rtk read`. State the fallback reason if repowise not used. Web is the Researcher's alone, and only after the repo has been tried and cannot answer.
8. **Report failures verbatim.** Verifier pastes exact output. No "should pass", no paraphrase, no summary of an error message.
11. **Every claim carries its source** — file:line + snippet, command + output, or URL + verbatim quote. An unsourced claim is dropped, not downgraded.
12. **Nothing leaves the machine.** Research is read-only: `WebSearch` and `WebFetch` only. No posting, no pushing, no publishing, no sending repo content to any service.
9. **Every spawned judging role runs at THINKER, one pair per run.** Only `fable`@`high`, `opus`@`xhigh`, or the gated `fable`@`xhigh`. Opus below `xhigh` never judges. The orchestrator is checked on model alone — see Preflight; the run does not start on a Sonnet or Haiku main thread.
10. **The main thread never issues the final verdict.** The Reporter does; the main thread relays it.

## Schemas

```js
const FACTS = {
  type: 'object',
  required: ['findings'],
  properties: {
    findings: { type: 'array', items: {
      type: 'object',
      required: ['origin', 'where', 'what', 'quote'],
      properties: {
        origin: { enum: ['repo', 'command', 'web'] },
        where:  { type: 'string' },         // "src/config.rs:40-88" | "cargo tree" | "https://…"
        what:   { type: 'string' },         // the fact, stated flatly
        quote:  { type: 'string' },         // VERBATIM snippet / output / doc sentence. never a paraphrase
        version: { type: 'string' },        // web only: which version of the doc was read
      },
    }},
    notFound: { type: 'array', items: { type: 'string' } },  // questions that could not be answered
  },
}

const BLUEPRINT = {
  type: 'object',
  required: ['summary', 'units'],
  properties: {
    summary: { type: 'string' },
    risks:   { type: 'array', items: { type: 'string' } },
    xhigh:   { type: 'boolean' },           // builders need xhigh?
    needFacts: { type: 'array', items: { type: 'string' } },  // questions blocking the design — sent back to Scout
    units: { type: 'array', items: {
      type: 'object',
      required: ['id', 'goal', 'files', 'steps'],
      properties: {
        id: { type: 'string' },
        goal: { type: 'string' },
        files: { type: 'array', items: { type: 'string' } },
        contract: { type: 'string' },       // signatures / types / API shape
        steps: { type: 'array', items: { type: 'string' } },
        dontTouch: { type: 'array', items: { type: 'string' } },
        disjoint: { type: 'boolean' },
        verify: { type: 'string' },         // how to prove this unit done
      },
    }},
  },
}

// kind decides what the pipeline does next:
//   'clean'      → proceed
//   'defect'     → a PROVEN problem. trace + evidence + trigger + consequence all required.
//   'unverified' → cannot rule yet. needFacts[] goes back to a Scout, NOT to a fixer.
const VERDICT = {
  type: 'object',
  required: ['kind', 'reason'],
  properties: {
    kind: { enum: ['clean', 'defect', 'unverified'] },
    reason: { type: 'string' },
    // 'defect' — all four, or it is not a finding
    trace: { type: 'array', items: { type: 'string' } },      // call path walked, "src/a.rs:12 → src/b.rs:88"
    evidence: { type: 'array', items: {
      type: 'object',
      required: ['where', 'quote'],
      properties: {
        where: { type: 'string' },        // "src/b.rs:88" | "https://…"
        quote: { type: 'string' },        // verbatim, never paraphrased
      },
    }},
    trigger: { type: 'string' },          // real values that reach it: "limit = 0"
    consequence: { type: 'string' },      // what actually goes wrong
    reachedFrom: { type: 'string' },      // real caller, file:line — proves it is not dead
    fix: { type: 'string' },
    // 'unverified' — the exact questions to answer
    needFacts: { type: 'array', items: { type: 'string' } },
  },
}

const REPORT = {
  type: 'object',
  required: ['done', 'built', 'failures', 'unresolved', 'openRisks'],
  properties: {
    done:  { type: 'boolean' },              // false if ANY gate failed or anything is unresolved
    built: { type: 'array', items: { type: 'string' } },   // one line per unit
    failures:   { type: 'array', items: { type: 'string' } }, // verbatim gate output
    unresolved: { type: 'array', items: { type: 'string' } },
    openRisks:  { type: 'array', items: { type: 'string' } },
    unproven:   { type: 'array', items: { type: 'string' } },  // questions nobody could answer — say them, never paper over
    sources:    { type: 'array', items: { type: 'string' } },  // external docs relied on, URL + version
  },
}
```

## Workflow script

Set `THINKER` first, then adapt `SCOUTS` and the task text. Keep the stage
order. State the chosen THINKER pair and the one-line reason to the user before
launching — `opus @ xhigh` costs more than `fable @ high`, so an unexplained
pick is a silent cost decision.

```js
export const meta = {
  name: 'claude-teams',
  description: 'THINKER plans and critiques, Haiku fetches facts, Opus implements',
  phases: [
    { title: 'Scout',   detail: 'haiku fact-gathering, parallel' },
    { title: 'Plan',    detail: 'THINKER architecture + blueprint' },
    { title: 'Critique',detail: 'THINKER refutes the blueprint' },
    { title: 'Build',   detail: 'opus implements, serial' },
    { title: 'Verify',  detail: 'build/test/lint + diff critique' },
    { title: 'Report',  detail: 'THINKER writes the final verdict' },
  ],
}

const TASK = args?.task ?? args

// THINKER — Architect, Critic and Reporter all run here. Legal pairs ONLY:
//   { model: 'fable', effort: 'high'  }  default
//   { model: 'opus',  effort: 'xhigh' }  implementation-shaped depth
//   { model: 'fable', effort: 'xhigh' }  four-condition gate, see Effort rule
// Never opus below xhigh. Never sonnet or haiku. Picked once by the orchestrator.
const THINKER = args?.thinker ?? { model: 'fable', effort: 'high' }

const SCOUTS = args?.scouts ?? [
  'Locate the files and symbols this task touches. Report paths + line ranges + exact snippets.',
  'Report existing conventions: naming, file layout, error handling, state, styling, in the touched area.',
  'Report the build/test/lint commands and the test files covering the touched area.',
  'Report the exact locked versions of every dependency the task touches, straight from the lockfile, plus how the repo already calls them (call sites + snippets). Do not describe what those APIs do — that is a research question, put it in notFound.',
]

const NO_GUESSING = `
NEVER guess, never infer, never fill a gap from how it "usually works". A
question you could not answer goes in notFound, verbatim. An empty findings list
with an honest notFound beats one invented fact.
Quote, do not paraphrase. Report FACTS ONLY — no opinions, no plan, no suggestions.`

// Scout lane — mechanical enumeration inside this repo. No web, no judgement.
const SCOUT_RULES = `
Repowise MCP tools FIRST, rtk read/grep only as fallback (state the reason).

This repo and read-only commands ONLY. Do NOT use the web — deciding whether a
web source is authoritative is a judgement call and it is not yours to make. A
question that needs an external doc goes straight into notFound.

EVERY finding needs origin + where + what + quote:
- origin 'repo'    → where "src/x.rs:40-88", quote = the exact lines
- origin 'command' → where = the command you ran, quote = its real output
${NO_GUESSING}`

// Research lane — runs at THINKER, because picking a source and reading a spec
// against this repo's version IS judgement, and Scout is barred from judging.
const RESEARCH_RULES = `
Repo first: repowise / rtk read / rtk grep, and read-only commands. Go to the web
only when the repo genuinely cannot answer the question.

EVERY finding needs origin + where + what + quote:
- origin 'repo'    → where "src/x.rs:40-88", quote = the exact lines
- origin 'command' → where = the command you ran, quote = its real output
- origin 'web'     → where = the URL, quote = the exact supporting sentence,
                     version = which version of the doc you read

Web is limited to primary sources: official docs, the dependency's own source or
repo, published specs (RFC/W3C/POSIX/Unicode/ECMA), changelogs, vendor API
reference. Blogs, tutorials, forum answers and AI summaries are NOT sources — a
forum post may point you at the real doc, then cite the doc.
Check the doc version against this repo's lockfile and say which one you read.
A page for a different major version is not evidence for this repo.
Read only. Never post, push, submit or send anything anywhere.
${NO_GUESSING}`

phase('Scout')
const facts = (await parallel(SCOUTS.map((s, i) => () => agent(
  `Task context: ${TASK}
Your job: ${s}
${SCOUT_RULES}`,
  { model: 'haiku', effort: 'low', label: `scout:${i}`, phase: 'Scout', schema: FACTS },
)))).filter(Boolean)

let FACTS_TEXT = JSON.stringify(facts)
log(`facts: ${facts.flatMap(f => f.findings).length} findings, ${facts.flatMap(f => f.notFound ?? []).length} gaps`)

const openQuestions = []   // asked, researched, still unanswered — reaches the final report

// Fill a gap by going and looking, never by assuming. Used by Plan and Critique.
// Runs at THINKER: choosing a source, matching its version, and deciding whether a
// quote actually supports the claim are all judgement, which Scout may not do.
async function research(questions, tag) {
  log(`researching ${questions.length} open question(s): ${questions.join(' | ')}`)
  const more = (await parallel(questions.map((q, i) => () => agent(
    `Task context: ${TASK}
Answer exactly this question and nothing else: ${q}
${RESEARCH_RULES}`,
    { ...THINKER, label: `research:${tag}:${i}`, phase: 'Scout', schema: FACTS },
  )))).filter(Boolean)
  facts.push(...more)
  FACTS_TEXT = JSON.stringify(facts)
  const stillMissing = more.flatMap(f => f.notFound ?? [])
  if (stillMissing.length) {
    log(`STILL UNANSWERED: ${stillMissing.join(' | ')}`)
    openQuestions.push(...stillMissing)     // survives to the Reporter — never silently dropped
  }
  return stillMissing
}

// Whatever the repo could not answer is exactly what research exists for.
const gaps = facts.flatMap(f => f.notFound ?? [])
if (gaps.length) await research(gaps, 'gaps')

phase('Plan')
const PLAN_PROMPT = () => `Design the implementation for: ${TASK}

FACTS — the ONLY ground truth. Every path, symbol, signature and dependency
behavior you rely on must appear here with its quote:
${FACTS_TEXT}

Produce a blueprint: architecture, code flow, contracts, and units of work.
Match the existing conventions in FACTS. Simplest design that solves it — no speculative abstraction.
Set xhigh:true only if implementation needs deep reasoning (cross-module, concurrency, new public contract).
Mark disjoint:true on a unit only if it shares no file with any other unit.

NEVER assume a file, function, signature, field or library behavior that is not
in FACTS. If the design depends on something you cannot see there, do not guess
it and do not design around the guess — put the exact question in needFacts[]
and it will be researched before you are asked again.
If you cannot resolve the DESIGN itself at this effort — not the details, the shape —
say so explicitly in risks[] as "DESIGN UNRESOLVED: <what>". Do not guess past it.`

let blueprint = await agent(PLAN_PROMPT(), { ...THINKER, label: 'architect', phase: 'Plan', schema: BLUEPRINT })

if (blueprint?.needFacts?.length) {
  await research(blueprint.needFacts, 'plan')
  blueprint = await agent(
    `${PLAN_PROMPT()}

You previously asked for: ${blueprint.needFacts.join(' | ')}
Those answers are now in FACTS above. Anything still absent stayed unanswerable —
state it in risks[] rather than assuming it.`,
    { ...THINKER, label: 'architect:facts', phase: 'Plan', schema: BLUEPRINT },
  )
}

const CRITIC_RULES = `
Three outcomes, and only three:

- kind 'defect'     — a PROVEN problem. Requires ALL of: trace (the call path you
                      actually walked, file:line per hop), evidence (verbatim
                      snippet or doc quote at each hop), trigger (real values that
                      reach it, e.g. "limit = 0", not "an edge case"), consequence
                      (what actually goes wrong), reachedFrom (a real caller,
                      file:line — proving the path is not dead).
                      Missing any one → it is NOT a defect. Do not report it.
- kind 'unverified' — you cannot rule without a fact you do not have. Put the exact
                      questions in needFacts[]. They will be researched and you will
                      be asked again. This is the ONLY correct move when uncertain.
- kind 'clean'      — you traced it end to end and found nothing provable.

BANNED as a defect: "looks wrong", "may not handle", "consider whether", "seems
risky", "could break". If your evidence is your own expectation rather than a
quote from the code or a spec, it is not evidence — it is 'unverified', go ask.
Never call something broken from the surface. Walk the whole path first.
You may read official docs / specs / dependency source on the web to prove a
point; cite URL + verbatim quote. Read only.`

phase('Critique')
let planVerdict = await agent(
  `Try to break this blueprint. An unproven plan does not pass — but an unproven
accusation is not a finding either.

Check: an assumption about the code that FACTS does not actually support, missing unit,
unit that cannot be built from its own contract, scope creep beyond the task,
conflict with the conventions in FACTS, simpler design available.
${CRITIC_RULES}

BLUEPRINT: ${JSON.stringify(blueprint)}
FACTS: ${FACTS_TEXT}
TASK: ${TASK}`,
  { ...THINKER, label: 'critic:plan', phase: 'Critique', schema: VERDICT },
)

if (planVerdict?.kind === 'unverified' && planVerdict.needFacts?.length) {
  await research(planVerdict.needFacts, 'plan-critique')
  planVerdict = await agent(
    `You asked for: ${planVerdict.needFacts.join(' | ')}
The answers are in FACTS below. Now rule on the blueprint.
Anything still missing from FACTS stayed unanswerable — say so in reason, do not assume it.
${CRITIC_RULES}

BLUEPRINT: ${JSON.stringify(blueprint)}
FACTS: ${FACTS_TEXT}
TASK: ${TASK}`,
    { ...THINKER, label: 'critic:plan:2', phase: 'Critique', schema: VERDICT },
  )
}

if (planVerdict?.kind === 'defect') {
  log(`plan defect: ${planVerdict.reason}`)
  blueprint = await agent(
    `Revise the blueprint. The Critic proved this defect:
REASON: ${planVerdict.reason}
TRACE: ${(planVerdict.trace ?? []).join(' → ')}
EVIDENCE: ${JSON.stringify(planVerdict.evidence ?? [])}
TRIGGER: ${planVerdict.trigger ?? 'n/a'}
SUGGESTED: ${planVerdict.fix ?? 'n/a'}

Previous: ${JSON.stringify(blueprint)}
FACTS: ${FACTS_TEXT}
Same rule as before: nothing outside FACTS. Still missing a fact → needFacts[].`,
    // Same THINKER — a refuted plan is a wrong plan, not an under-reasoned one.
    { ...THINKER, label: 'architect:v2', phase: 'Critique', schema: BLUEPRINT },
  )
}

phase('Build')
const builderEffort = blueprint.xhigh ? 'xhigh' : 'high'
const built = []
for (const u of blueprint.units) {                    // SERIAL — later units see earlier edits
  built.push(await agent(
    `Implement this unit. Nothing more.

GOAL: ${u.goal}
FILES YOU MAY EDIT: ${u.files.join(', ')}
DO NOT TOUCH: ${(u.dontTouch ?? []).join(', ') || 'anything outside FILES'}
CONTRACT: ${u.contract ?? 'n/a'}
STEPS:
${u.steps.map((s, i) => `${i + 1}. ${s}`).join('\n')}
DONE WHEN: ${u.verify ?? 'the steps are complete and the code compiles'}

Match the surrounding style exactly. No refactoring, no extra features, no unrequested error handling.

Read before you write. Never call a function, field or API whose real signature
you have not seen — open it, or read the official docs for it. If the contract
turns out to be different from what the blueprint assumed, STOP that step and
report the mismatch with the file:line or URL that shows it. Do not code around
a guess.

Return: files changed + a one-line summary per file + anything you could not do,
and any place where the blueprint disagreed with the real code.`,
    { model: 'opus', effort: builderEffort, label: `build:${u.id}`, phase: 'Build' },
  ))
}

phase('Verify')
const [testOut, diffVerdict] = await parallel([
  () => agent(
    `Run the project's build, test, and lint for the changed area (commands are in FACTS: ${FACTS_TEXT}).
Paste the EXACT output of anything that fails — the real bytes, not a summary of them.
Do not fix anything. Do not interpret a failure. If a gate was not run, say which and why.`,
    { model: 'opus', effort: 'medium', label: 'verifier', phase: 'Verify' },
  ),
  () => agent(
    `Review the uncommitted diff against this blueprint.
Check: unit not actually implemented, scope creep, broken existing consumer, style mismatch, dead orphan left behind.
For "broken existing consumer" you must actually find the consumers — grep every
caller of what changed and read them. A consumer you did not open cannot be
called broken, and cannot be called fine either; that is 'unverified'.
${CRITIC_RULES}

BLUEPRINT: ${JSON.stringify(blueprint)}
FACTS: ${FACTS_TEXT}`,
    { ...THINKER, label: 'critic:diff', phase: 'Verify', schema: VERDICT },
  ),
])

let round = 0
let verdict = diffVerdict
while (verdict && verdict.kind !== 'clean' && round < 2) {
  round++

  // 'unverified' is a missing fact, not a bug. Research it — never hand it to a fixer.
  if (verdict.kind === 'unverified') {
    log(`round ${round}: unverified — ${verdict.reason}`)
    await research(verdict.needFacts ?? [verdict.reason], `diff-${round}`)
    verdict = await agent(
      `You asked for: ${(verdict.needFacts ?? []).join(' | ') || verdict.reason}
The answers are in FACTS below. Now rule on the uncommitted diff.
Still unanswerable → say exactly that in reason. Never assume it either way.
${CRITIC_RULES}

BLUEPRINT: ${JSON.stringify(blueprint)}
FACTS: ${FACTS_TEXT}`,
      { ...THINKER, label: `critic:diff:${round}`, phase: 'Verify', schema: VERDICT },
    )
    continue
  }

  log(`fix round ${round}: ${verdict.reason}`)
  await agent(
    `Fix exactly this proven defect, nothing else.
REASON: ${verdict.reason}
TRACE: ${(verdict.trace ?? []).join(' → ')}
EVIDENCE: ${JSON.stringify(verdict.evidence ?? [])}
TRIGGER: ${verdict.trigger ?? 'n/a'}
SUGGESTED: ${verdict.fix ?? 'n/a'}
Read the code at each hop of the trace before editing. Do not fix what you have not read.`,
    { model: 'opus', effort: builderEffort, label: `fix:${round}`, phase: 'Verify' },
  )
  verdict = await agent(
    `Re-review the uncommitted diff. Was "${verdict.reason}" actually fixed, and did the fix break anything?
Prove the answer at the same trace you were given — re-read those lines, do not assume the edit landed.
${CRITIC_RULES}

BLUEPRINT: ${JSON.stringify(blueprint)}
FACTS: ${FACTS_TEXT}`,
    { ...THINKER, label: `critic:diff:${round}:recheck`, phase: 'Verify', schema: VERDICT },
  )
}
if (verdict && verdict.kind !== 'clean') log(`UNRESOLVED after ${round} rounds (${verdict.kind}): ${verdict.reason}`)

phase('Report')
const report = await agent(
  `Write the final report for this run. You hold the final judgement — the main
thread only relays what you return, so anything you leave out is lost.

Set done:false if ANY gate failed, ANY unit was not implemented, or the last
critic verdict is anything other than 'clean'. Copy failing gate output VERBATIM
into failures — never paraphrase it, never write "should pass".

Every line you write must be traceable to something below: a gate's real output,
a builder's report, or the critic's evidence. Do not assert that something works
because it plausibly should. Anything nobody could prove either way goes in
unproven[] in plain words — an honest open question is a good outcome, a papered
-over one is a defect. List every external doc relied on in sources[], URL + version.

TASK: ${TASK}
BLUEPRINT: ${JSON.stringify(blueprint)}
BUILDER RESULTS: ${JSON.stringify(built)}
GATE OUTPUT: ${testOut}
FACTS AND SOURCES: ${FACTS_TEXT}
LAST CRITIC VERDICT: ${JSON.stringify(verdict)} (after ${round} rounds)
QUESTIONS RESEARCHED AND STILL UNANSWERED: ${JSON.stringify(openQuestions)}`,
  { ...THINKER, label: 'reporter', phase: 'Report', schema: REPORT },
)

return { blueprint, built, testOut, verdict, report, unresolved: !!verdict && verdict.kind !== 'clean' }
```

## Reporting back

`report` is the Reporter's, written at THINKER. **Relay it — do not re-judge
it.** Lead with the THINKER pair actually used. You may reformat and shorten; you may not add a verdict, soften a
failure, or promote `done:false` to done. Order:

1. `report.built` — one line per unit.
2. `report.failures` — verbatim.
3. `report.unresolved`, plus anything the workflow `log()`ed as dropped or STILL UNANSWERED.
4. `report.unproven` — the open questions, in the user's words. Never drop these to make the run look clean.
5. `report.openRisks`.
6. `report.sources` — external docs relied on, if any.

Never report "done" while `report.done` is false or `unresolved` is true.
Never add a claim of your own on top of the report — if the user asks something
the report does not answer, say the run did not establish it.
If `report` is missing (Reporter died), say the run has no final verdict and
show the raw `testOut` and `verdict` — do not substitute your own judgement.

## Cost note

A full run is roughly 12-20 agents, several at `high`/`xhigh`. The spread is the
research rounds, which fire only when a stage is actually missing a fact — one
Researcher per open question, in parallel, at THINKER. They are the expensive
part and they are never skipped to save cost, because the only cheaper option is
a guess. For a task that one Opus pass would finish, do not use this skill.
