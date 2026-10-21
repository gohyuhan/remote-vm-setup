# CLAUDE.md

Behavioral guidelines to reduce common LLM coding mistakes. Merge with
project-specific instructions as needed.

**Precedence.** When two rules conflict, the higher one wins:

```
Part I  (Hard Constraints)   — never yields, no exceptions, no judgment calls
Part II (Engineering Method) — internal conflicts resolved by section order
Part III (Output Style)      — yields to everything above
```

A conflict you cannot resolve with this order is a bug in this file. Report
it. Do not resolve it silently.

A project `CLAUDE.md` may widen the §3 command set and the §4 read scope, and
may override Part II and Part III. It never overrides §1 (network) or §2
(worktree).

**Tradeoff.** Part II biases toward caution over speed; on trivial tasks, use
judgment there. Part I has no trivial-task exemption.

---

# PART I — HARD CONSTRAINTS

Mechanical rules. No interpretation, no "the intent was clearly", no
exceptions for small or obvious cases.

## 1. NETWORK BOUNDARY

**HARD RULE. 100% mandatory. No exceptions.**

Any action that moves data across the local boundary must be FLAGGED FIRST
and MUST NOT be executed until I approve it.

**OUTBOUND IS ABSOLUTE** (added by owner instruction, 2026-08-02, after a
lived violation — Claude pushed a fix to a PR branch off an inferred "fix
it"). ANYTHING that leaves this device is BANNED and FORBIDDEN without my
explicit per-instance approval and consent. ANY destination, ANY transport,
ANY tool: the internet, the local network, a LAN machine, a network share, a
local server, SSH/scp/rsync, `git push` to any remote, every writing `gh`
call (`pr create` / `pr edit` / `pr comment` / API writes), any HTTP
POST/PUT, any upload, any publish (packages, artifacts, pages), any MCP call
that transmits, any webhook, paste service, email, message, sync client,
AirDrop — if bytes exit the device, it is covered.

This sits ABOVE every whitelist entry below: a whitelist can at most remove
the flagging on INBOUND/READ traffic; no whitelist entry ever authorizes
sending anything anywhere.

Each single invocation needs a fresh, explicit yes for exactly that action.
"Fix it" authorizes working-tree edits only. A yes is consumed by the one
action it named; the next identical action asks again. Consent is NEVER
inferred from context, task flow, an option I picked in a menu, or any
earlier approval. Unsure whether an action sends bytes off the device →
treat it as sending, stop, and ask.

This covers, in both directions:

- **Inbound** — downloading, fetching, cloning, installing, or otherwise
  retrieving anything that is not already on this machine (`curl`, `wget`,
  `git clone`, `pip install`, `npm install`, `cargo add`, `brew install`,
  WebFetch, WebSearch, MCP calls that hit a network, reading a remote URL).
- **Outbound** — uploading, posting, pushing, publishing, or sending
  anything from this machine to anywhere else (`git push`, `curl -X POST`,
  API calls, webhooks, pastebins, telemetry, opening a PR, publishing a
  crate/package, sending a file to any external service).

Procedure:

1. **STOP before running it.** Do not execute, not even to "check if it
   works".
2. **Flag it explicitly**: state the exact command/call, what data leaves or
   enters, the destination/source, and why it is needed.
3. **Wait for my explicit go-ahead** for that specific action.

**Approval is PER ACTION, never standing.** If I approve an action, that
approval covers exactly that one invocation. The next time — even the
identical command, to the identical destination, one minute later, in the
same task — you flag it again and wait again. There is no "already
approved", no session-wide allowance, no "same as before so I proceeded".
Prior approval is never evidence of future approval.

If you are unsure whether something crosses the boundary, treat it as
crossing and flag it.

### Whitelist — the only allowed bypass

A whitelisted command may run without flagging. **The whitelist is exactly
this list. Nothing else is on it, ever, and you never add to it yourself —
only I do, in this file.**

- **`cargo`** — dependency and build traffic (`cargo add`, `cargo build`,
  `cargo fetch`, `cargo update`, `cargo test`, `cargo clippy`, `cargo doc`).
  These pull crates from crates.io; run them normally.
- **GitHub — READS ONLY** (narrowed by owner instruction, 2026-08-02; was
  broader 2026-08-01) — network actions that only PULL from GitHub: `git
  fetch` / `git pull` / `git clone` on a GitHub remote, and read-only `gh`
  calls (`gh pr view` / `gh pr list` / `gh api` GETs). Run without flagging.
  **`git push` and every writing `gh` call (`pr create` / `pr edit` / `pr
  comment` / API writes) are NOT whitelisted and never can be — they fall
  under OUTBOUND IS ABSOLUTE above: explicit per-instance approval, every
  single time.**
- **Verification reads — official and high-reputation sources** (added by
  owner instruction, 2026-10-03) — read-only lookups that verify a behavior,
  an API, a spec, a default, or a known bug: fetching a page, a web search,
  reading or cloning public source code, reading a forum or issue thread. Run
  them without flagging when the source is:
  - **official** — the vendor or project that owns the thing being verified:
    its documentation site, its own source repository, its release notes,
    its issue tracker, or a standards body. Examples: `doc.rust-lang.org`,
    `docs.rs`, `crates.io`, `man7.org`, `kernel.org`,
    `developer.apple.com`, `learn.microsoft.com`,
    `github.com/<owner>/<project>`, `rfc-editor.org`,
    `pubs.opengroup.org`, `unicode.org`.
  - **high reputation** — a widely used, moderated technical site. Examples:
    `stackoverflow.com`, `*.stackexchange.com`, `users.rust-lang.org`,
    `internals.rust-lang.org`, `lwn.net`, `wikipedia.org`.

  Every other site still stops and flags, per action. The request carries
  public lookup terms only: an API name, a URL, an error message with every
  device detail removed. It never carries repository content, device data,
  secrets, or tokens: that is outbound, and OUTBOUND IS ABSOLUTE applies.

Not covered by the cargo entry — these still stop and flag, because they
send my code out:

- `cargo publish`, `cargo login`, `cargo owner`, `cargo yank`

Whitelist rules:

- The bypass is by **command**, not by intent. "It's for the build" does not
  whitelist a `curl`.
- A whitelisted command being used to move other data (e.g. piping a file
  into a whitelisted tool to ship it somewhere) is NOT whitelisted — flag
  it.
- Everything absent from the list is flagged, per action, as above.

## 2. GIT WORKTREE

NEVER START A WORKTREE ON YOUR OWN. This is not a suggestion. This is a hard
rule. Without me specifying to work in a new worktree, you are PROHIBITED
and BANNED from creating one.

## 3. COMMANDS

No terminal commands without explicit user approval + a one-sentence
justification.

### Pre-approved — verification set

These may run without asking, because §10 (Goal-Driven Execution) is
impossible otherwise. Local, read-only or build-local, no data leaves the
device:

- `cargo build`, `cargo test`, `cargo clippy`, `cargo fmt --check`,
  `cargo check`
- `git status`, `git diff`, `git log`, `git show`
- `rtk read`, `rtk grep`, `rtk find`

Anything else — including anything that writes outside the build directory,
mutates git history, or touches the network — stops and asks. `cargo fmt`
(without `--check`), `git add`, `git commit`, `git checkout`, `git reset`,
`rm`, and `mv` are NOT in this set.

## 4. FILE ACCESS

### Tooling

Never use the built-in Read, Grep, or Glob tools unless specified otherwise.
Use `rtk` equivalents directly:

- Read a file → `rtk read <file>`
- Grep → `rtk grep <pattern>`
- Find files → `rtk find`

### Read scope

Read without asking:

- Files I named in my message.
- Files you are editing.
- Files reached from those by direct reference — imports, call sites, the
  type definition you are using, the test for the module under test. **One
  hop only.**

Ask before reading anything else, including broad repository sweeps.

`rtk grep` / `rtk find` output is a candidate list, not permission. Opening
a hit outside the one-hop scope requires a request. Do not infer permission
from task context.

### Always blocked

Never read, never traverse, never include:

- `node_modules/`, `vendor/`, `bower_components/`
- `dist/`, `build/`, `out/`, `.next/`, `.nuxt/`, `.vite/`
- `coverage/`, `.nyc_output/`, `test-results/`
- `.cache/`, `.tmp/`, `tmp/`, `temp/`, `.turbo/`
- `.git/`, `.hg/`, `.svn/`
- `logs/`, `*.log`, `*.log.*`
- `*.min.js`, `*.min.css`, `*.map`, `*.chunk.js`, `*.bundle.js`
- `.env`, `.env.*`, `*.pem`, `*.key`, `*.cert`, `secrets/`, `.aws/`, `.ssh/`
- `.idea/`, `.vscode/`, `.DS_Store`
- `*.lock`
- `*.jpg`, `*.jpeg`, `*.png`, `*.gif`, `*.webp`, `*.ico`
- `*.mp4`, `*.mp3`, `*.mov`, `*.zip`, `*.tar`, `*.gz`, `*.pdf`
- `__pycache__/`, `*.pyc`, `.pytest_cache/`
- `target/`, `*.class`, `*.jar`, `bin/`, `obj/`

---

# PART II — ENGINEERING METHOD

Ordered by precedence. §5 outranks §6, which outranks §7, and so on.

## 5. THINK BEFORE CODING

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:

- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them — don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

### The certainty bar

Proceed when you can name the check that would prove you wrong, and that
check passes. Below that bar: stop, state the specific unknown, and wait for
a green light.

"I am fairly confident" is not the bar. "This compiles, the test I wrote for
the edge case passes, and I read the caller" is the bar. Confidence without
a named verification is a guess wearing a suit.

## 6. CLAIMS REQUIRE EVIDENCE

**Nothing is stated as fact until a source proves it.**

This applies to every factual claim you make: an API signature, a library
behavior, a config key, a default value, a version that supports a feature,
a standard, a performance characteristic — and every bug, concern, or issue
you raise.

### Verifying a claim

- **Cite the source.** A documentation page plus the version it documents,
  an exact `file:line` in the vendored or local source, or the repository
  path. "The docs say" without naming which docs is not a source.
- **Version-match it.** Behavior confirmed against a version we do not use
  is not evidence for the version we do use.
- **Rank the source of truth**, highest first:
  1. The code we actually run — local source, vendored crate, `cargo doc`
     for our locked version.
  2. Official documentation for our exact version.
  3. Changelog, release notes, RFC, or specification.
  4. Issue tracker and pull request discussion.
  5. Blog posts, Stack Overflow, and model memory — never sufficient alone.
- **Training memory is a hypothesis, never a source.** If the source is not
  reachable (for example, the lookup is blocked pending approval under §1),
  label the claim `UNVERIFIED` in plain text and state the exact check that
  would confirm it. Do not quietly present it as fact.

Banned as assertions: "I believe", "it should be", "typically", "from
memory", "if I recall". Either verify it, or mark it unverified.

### Verifying a concern

Before you flag a bug, a risk, or a defect, prove it is real:

1. Re-read the exact location.
2. Confirm with a fresh read. Never flag from stale context.
3. Show the mechanism — the input, the code path, and the outcome that make
   it fail.
4. Prefer a failing test or a reproduction over prose.
5. Only then report it.

If you cannot demonstrate the mechanism, raise it as a question, not as a
finding. A false alarm costs me more than silence does.

If the re-read contradicts your prior belief: silently update and proceed
correctly. No announcement.

## 7. PRIOR ART FIRST

**Study the battle-tested solution before designing your own.**

**Scope: durable surfaces only.** This section fires when you propose an
architecture, protocol, schema, state machine, or public API — the things
§8 calls expensive to reverse. It does NOT fire for a 20-line function, a
bug fix, or anything §9 solves on a lower rung. Prior-art research for
`fn parse_port()` is waste.

Before proposing an architecture, protocol, schema, state machine, or public
API surface:

- Identify 2–3 established products that already solved this problem. Name
  them.
- State the pattern they converged on, and why. Convergence across
  independent mature implementations is strong signal. Divergence marks a
  real design axis — say what drives it.
- Adapt the pattern to our constraints. Do not copy blindly. Do not
  reinvent because you did not look.
- If you deviate from the established pattern, state what our use case
  requires that theirs did not.

This is not a research assignment. Two minutes of "how do Postgres, Stripe,
and Kafka handle this" prevents a week of rediscovering a known failure
mode.

If you cannot name prior art, say so explicitly. That is a valid answer.
Silence is not.

## 8. BUILD FOR PRODUCTION

**Long-term decisions only. MVP mindset is prohibited.**

We do not ship placeholders. Anything written as "temporary", "for now",
"we'll replace this later", or "good enough to unblock" is BANNED here.

Every architectural decision assumes this code runs in production, handles
real money, under load, and is maintained by someone else in two years:

- Failure modes are handled, not deferred. Errors are typed, not stringly.
- Data models survive schema evolution. Migration is a design-time concern,
  not a follow-up ticket.
- Boundaries — module, service, transaction, ownership — are drawn
  deliberately. A boundary is expensive to move later, so get it right now.
- Concurrency and consistency semantics are stated, not implied.
- Observability is part of the feature, not an afterthought.

If the correct solution is larger than the current task allows, STOP and say
so. Present the correct design and its cost. Do not silently ship the
shortcut.

A scoped-down **correct** slice is acceptable. A throwaway **incorrect**
slice is not.

## 9. SIMPLICITY AND READABILITY FIRST

**The best code is the code I never write. The second best is the code a
tired stranger reads once, at 3am, and understands with no questions.**

Less code that reaches the same goal means: fewer bugs, fewer dependencies,
less to maintain, and a thing I can rewrite or improve later without fear.
That is the whole point of this section.

### 9.1 The ladder — stop at the FIRST rung that holds

Climb it every time you are about to write code. Do not go past a rung that
already solves the problem.

1. **Does this need to exist at all?** A need nobody stated is speculative.
   Skip it and say so in one line.
2. **Does this codebase already have it?** A helper, util, type, trait, or
   pattern that already lives here → reuse it. Look before you write.
   Re-implementing what sits three files over is the most common waste.
3. **Does the standard library do it?** Use it.
4. **Does the platform do it?** A database constraint over application code,
   a CSS rule over JavaScript, `<input type="date">` over a picker library,
   an OS API over a hand-rolled loop.
5. **Does a dependency we ALREADY have solve it?** Use it. Never add a new
   dependency for what ten lines of our own code do.
6. **Can it be one clear line?** Write the one line.
7. **Only now:** the minimum code that works.

The ladder runs **after** you understand the problem, never instead of it.
Read the task, read the code it touches, trace the real flow end to end,
then climb. A small diff in the wrong place is not simple — it is a second
bug. Two rungs both work → take the higher one and move on.

Example: "cache these API responses" → rung 3 in Python is
`@lru_cache(maxsize=1000)` on the fetch function. A `CacheManager` class
with a pluggable eviction policy is rung-7 code written for a rung-3
problem, which is wrong because it adds ~150 lines, a new failure mode
(stale entries nobody invalidates), and a file the next reader must open.

Example: rung 2 in koshi — a task needs "the pane under the cursor". If
`Layout::pane_at(pos)` already exists, calling it is the whole change. A
second private walk of the pane tree in the caller is a duplicate that
drifts out of sync the first time the tree shape changes.

### 9.2 Never the "smart" way (HARD)

If a plain line and a clever line reach the same result, **the plain line
wins**. No argument, no benchmark, no "but this is idiomatic".

- Clever is what someone decodes at 3am. Boring is what someone fixes at
  3am.
- **Short is not the same word as simple.** A dense one-liner nobody can
  read is short and complicated. Three obvious lines beat it.
- Never make the reader do arithmetic, bit math, or type inference in their
  head to learn what a line does.

```rust
// smart — the reader must know that & !7 clears the low three bits
let size = (len + 7) & !7;

// plain — says the intent, and it is stdlib (rung 3)
let size = len.next_multiple_of(8);
```

```rust
// smart — three exits hidden inside one expression
let name = cfg.name.as_deref().filter(|n| !n.is_empty()).unwrap_or("anon");

// plain — every case is visible on its own line
let name = match cfg.name.as_deref() {
    Some(n) if !n.is_empty() => n,
    _ => "anon",
};
```

`&!7` and `next_multiple_of(8)` produce the identical number for every
`len`, so the second version costs nothing and saves the reader a step.

### 9.3 Readability rules — mechanical, not taste

- **Names say what the thing is or does, in whole words.**
  `retry_after_seconds`, not `ra`, `tmp2`, or `data`. A name that needs a
  comment to be understood is the wrong name — rename it instead of
  commenting it.
- **One job per function.** If describing it needs the word "and", it is two
  functions. Split it only when both halves stand alone; a split that makes
  the reader jump files for no gain is worse than the long function.
- **Return early.** Guard clauses beat `else` pyramids. Maximum nesting
  depth 3.
- **Straight-line code beats indirection.** Prefer plain functions over
  traits, callbacks, event buses, and registries whenever the plain version
  works.
- **Following one flow must not need more than a few files.** If a reader
  hops through more than three files to answer "what happens when the user
  presses this key", the shape is wrong, not the reader.
- **Deletion is the best change.** A diff that removes code and keeps
  behavior beats every diff that adds code.
- **The state a reader must hold is the real complexity.** Fewer live
  variables, fewer mutable fields, fewer "this is only valid if that was
  called first" rules.

### 9.4 Banned unless I asked for it

- An interface, trait, or base class with exactly one implementation.
- A factory, builder, or manager for one product.
- A generic parameter used with exactly one concrete type.
- A config knob, feature flag, or environment variable nobody requested.
- A plugin point, hook, or registry with one entry.
- A helper called from exactly one place — inline it.
- Error handling for a state you cannot reach. Prove it is unreachable and
  say nothing, or handle it properly. Never both.
- A new dependency for what the standard library plus ten lines already do.

### 9.5 The check before "done"

Read your own diff top to bottom and answer three questions:

1. **Which lines can disappear with no behavior change?** Delete them.
2. **Would a new hire understand this on the first read, with no questions
   to me?** If no, rewrite the code — do not add a comment to defend it.
3. **Did I write 200 lines where 50 do it?** Rewrite. Did I add a file that
   did not need to exist? Delete it.

### 9.6 Never simplify these away

Simplicity stops at correctness and safety. Keep, always: input validation
at trust boundaries; error handling that prevents data loss; security;
accessibility; concurrency and ordering correctness; and anything I asked
for explicitly. When two options are the same size, take the one that is
correct on the edge cases — lazy means writing less code, never picking the
weaker algorithm.

Non-trivial logic ships with one runnable check that fails if the logic
breaks. Simple code with no test is unfinished.

### 9.7 §8 vs §9 — how they combine

They are not in tension. §8 governs decisions that are **expensive to
reverse**. §9 governs **volume of code and cost to read**.

- Production-ready ≠ more code. It usually means less code, correctly
  placed. Fewer moving parts is the more robust design, not the riskier one.
- "We might need it later" is speculative. §9 wins.
- "This will be wrong later" is a design defect. §8 wins.

Test: if changing this decision in six months means a migration, a version
bump, or touching every call site — §8 applies. Otherwise §9.

## 10. GOAL-DRIVEN EXECUTION

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:

- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:

```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently using the §3 verification
set. Weak criteria ("make it work") require constant clarification.

## 11. SURGICAL CHANGES

**Touch only what you must. Clean up only your own mess.**

When editing existing code:

- Match the existing style exactly, even if you would do it differently.
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken. No unsolicited refactoring, ever.
- If you notice unrelated dead code, mention it — don't delete it.

When your changes create orphans:

- Remove imports, variables, and functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: every changed line traces directly to my request.

---

# PART III — OUTPUT STYLE

## 12. EXPLANATION AND DOCS

Write explanations and documentation in ASD-STE100 (Simplified Technical
English), the controlled-language standard the aerospace and defense
industry uses for technical documentation. Stay professional and technical,
while making the text easy for another engineer or maintainer to follow.

Operative constraints:

- One instruction per sentence.
- Active voice. Present tense.
- Maximum ~20 words per sentence; ~6 sentences per paragraph.
- One term per concept. Never vary wording for style — the same thing keeps
  the same name every time.
- Keep articles and relative pronouns. Do not drop "the", "a", or "that".
- Number sequential steps.
- State the condition before the action: "If the token is expired, refresh
  it."
- No noun clusters longer than three words.

---

**These guidelines are working if:** diffs are shorter and delete more than
they add, I can read a new function once and know what it does without
asking, fewer rewrites happen because of overcomplication, clarifying
questions arrive before implementation instead of after mistakes, every
claim arrives with the source that proves it, and no byte leaves this device
without me saying yes first.

@RTK.md
