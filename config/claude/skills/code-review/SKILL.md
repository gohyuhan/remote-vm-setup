---
name: code-review
description: >-
  Two-phase code review. Phase 1 reads the target COLD — no memory, no project
  docs, no task description, no commit messages, no PR body — and records every
  flaw found in the raw bytes, across correctness, feature implementation,
  simplicity, readability, efficiency, security, concurrency, error handling,
  API contracts, portability, tests, and docs. Phase 2 then opens the context
  and marks any finding the context invalidates with an explicit tag, never
  deleting it. Every finding carries a review tag — [issue], [question],
  [suggestion], or [optional] — and the report opens with an APPROVED or
  CHANGES REQUESTED verdict. Use when asked to review code, review a PR or
  branch, audit a codebase, or when invoked as /code-review. Language- and
  framework-agnostic.
---

# Code Review (cold first, context second)

A review that starts from the task description inherits the author's
assumptions and stops seeing what the code actually says. This skill splits
the review in two.

**Phase 1 is cold.** Judge the bytes on disk and nothing else. Record every
flaw, with no severity filter and no self-censoring.

**Phase 2 is warm.** Open the context, then mark which Phase 1 findings the
context kills — by tagging them in place. A finding is never deleted. The
user must be able to see what was raised cold and what the context dismissed,
so they can disagree with the dismissal.

Never use a subagent and never create a git worktree. This skill runs inline.

---

## Phase 0 — Fix the target

Accept, in order of precedence:

1. An explicit path or glob (`/code-review src/auth/`) — review those files.
2. A branch or PR number — review the change against the main branch.
3. No argument, working tree dirty — review the uncommitted changes.
4. No argument, working tree clean — review the whole repository.

Compute a change target with the merge base, so drift on the base branch does
not pollute the diff:

```bash
BASE=$(git merge-base <baseRef> HEAD)
git diff "$BASE"...HEAD --stat
git diff "$BASE"...HEAD
```

Write the target down as a file list. That list is frozen for Phase 1. Do not
read the PR title, the PR body, the branch name, or the commit log to build
it — `--stat` gives the file names without them.

---

## Phase 1 — Cold read

### Banned sources (HARD)

While Phase 1 runs, do not open, quote, recall, or reason from any of these:

- Persistent memory of any kind, and anything recalled from an earlier session.
- `CLAUDE.md`, `AGENTS.md`, `.cursorrules`, and every other agent instruction
  file in the repo.
- Architecture folders, design docs, roadmaps, task files, ADRs, issue text.
- The PR title, the PR body, the branch name, commit messages, `git blame`,
  `git log`.
- Anything the user said in this conversation about what the code is meant to
  do, and any belief carried in from earlier work in this session.
- `README.md` and `docs/`, unless the review target itself includes them.

If a fact you want to use came from one of those, you may not use it in
Phase 1. Note it as a Phase 2 question instead and keep reading.

The code and its own comments are inside the target, so they are readable —
but a comment is a claim, not a fact. Verify it against the code it sits on.
A comment that lies is itself a Phase 1 finding.

### How to read

1. Read every file in the target **in full**, top to bottom, before writing a
   single finding. No skimming to the hunks.
2. Open every helper, type, and constant the target calls. A name is not
   evidence: a function called `is_valid` is not proof that it validates, and
   `safe_write` is not proof that it is safe. Read the body.
3. Trace every caller of every function the target changes or defines. Grep
   the symbol repo-wide and open each call site. A consumer you did not read
   can be called neither broken nor fine.
4. Trace data end to end for at least one real input: where it enters, every
   transform, where it is stored, where it leaves.
5. Read the tests covering the target. Note what they pin down and what they
   leave free.

### The angles (cover all of them)

Walk the target once per angle. Do not stop at the first angle that yields
findings.

**Correctness** — wrong result, wrong branch, off-by-one, inverted condition,
sign, precedence, integer overflow, float comparison, wrong operator, wrong
variable used, unreachable branch, missing case in a match, silent fallthrough.

**Feature implementation** — does the code do the whole job it sets out to do,
judged from the code alone? Half-built paths, a flag that is read but never
honored, a parameter that is accepted and ignored, a return value that is
computed and dropped, a branch that is stubbed.

**State and data model** — a field that can hold a value the code cannot
handle, two fields that must agree with nothing enforcing it, a state the type
permits but the logic does not survive, data that outlives the process and now
receives a shape the readers do not expect.

**Error handling** — swallowed errors, errors turned into a default value,
`catch`/`unwrap`/`panic`/`??` on a reachable path, an error message that names
the wrong thing, a failure that leaves partial state behind, a retry with no
bound, a cleanup that does not run on the failure path.

**Resource lifecycle** — leaks of file handles, sockets, locks, memory,
subprocesses, threads, timers. Anything acquired on a path that can return
early before it is released.

**Concurrency** — data races, a lock held across an await or a blocking call,
lock ordering that can deadlock, check-then-act on shared state, a value read
twice that can change in between, an unbounded queue, cancellation that leaves
state torn.

**Security** — untrusted input reaching a sink without validation: injection
(SQL, shell, path, template, log), deserialization, SSRF, path traversal.
Secrets in code, logs, or error messages. Missing authentication or
authorization on a reachable path. Weak or hand-rolled crypto, a fixed IV, a
seeded-from-time RNG for a security purpose. Non-constant-time comparison of a
secret. Permissive CORS, missing TLS verification, an unbounded allocation
driven by an attacker-controlled length.

**Trust boundaries** — every place data crosses from outside to inside. State
what is validated there, and name what is not.

**Efficiency** — allocation inside a loop, an extra pass over data, a copy that
could be a borrow, a redundant round trip, an N+1 query, a linear scan where a
map exists, work repeated per item that could be hoisted. Only on a path that
runs hot; one-shot and error-path costs are not findings.

**Simplicity** — logic re-implemented that already exists in this repo (name
the existing one with `file:line`), duplicated rules that will drift, dead
code, an interface with one implementation, a wrapper that only forwards,
config for a value that never changes, speculative generality, a flag
parameter that splits a function into two functions.

**Readability** — a name that says the wrong thing, a name that says nothing,
deep nesting where an early return works, a function doing several unrelated
jobs, a magic number with no name, inconsistent naming for one concept, an
argument list long enough to be ordered wrong by a caller.

**API and contract** — a public signature that permits an input the body
cannot survive, a breaking change to an exported symbol, a serialized or wire
format changed without a version, a default that changes behavior for existing
callers.

**Portability** — path separators, line endings, case-sensitive filesystems,
signals and process groups, byte order, locale, timezone, integer width,
libc-specific strings. Name the platforms the repo targets and say which ones
this code was clearly not written for.

**Tests** — a test that passes when the value is wrong (wildcard match,
is-some, length-only assertion), a test that tests the mock, a missing case
for an edge the code has a branch for, a flaky sleep, shared mutable state
between tests.

**Docs and comments** — a comment that no longer matches the code it
describes, a doc comment whose parameters or return value are stale, a comment
that argues against a design not taken instead of stating what the code does,
a comment that explains a bad name instead of the name being fixed.

**Dependencies** — a dependency pulled in for what a few lines would do, an
unpinned version, a call into a dependency whose contract the code assumes
rather than reads.

**Observability** — a failure that produces no signal, a log that prints a
secret, a log in a hot loop, an error path with no way to tell which of three
causes fired.

### Evidence rules

Every finding carries all four:

1. **Location** — `file:line`.
2. **Quoted bytes** — the actual code, copied, from the file as it is now.
3. **Trigger** — real values that reach it (`limit = 0`, `name = "../../etc"`,
   two threads calling `close()` at once), never "an edge case".
4. **Consequence** — what actually goes wrong for a user, the data, or the
   next maintainer.

Banned as a finding: "looks wrong", "may not handle", "consider whether",
"seems risky", "could break". If the evidence is your expectation rather than
quoted code, it is not a finding — but it may still be recorded, see below.

**Record every single flaw.** No severity threshold, no "too minor to
mention", no trimming the list to look focused. If the mechanism is proven,
file it as a finding. If it is not proven, file it in the same document under
`OPEN QUESTIONS` with the exact check that would settle it. Neither list gets
silently dropped.

### Seal the cold findings

Before Phase 2 opens anything, write the full Phase 1 result to a file in the
session scratchpad directory (or `mktemp -d` if there is none):

```
<scratchpad>/code-review-cold.md
```

Format, one block per finding:

```
### C-07 · P1 · [issue] · security · src/api/upload.rs:142
**Code**
    let path = base.join(req.filename);
**Trigger** filename = "../../etc/passwd"
**Consequence** Writes outside the upload directory. Any authenticated
caller can overwrite arbitrary files the process can write.
**Smallest fix** Reject any component that is not `Component::Normal`.
**Verdict** (filled in Phase 2)
```

Number the findings `C-01`, `C-02`, … and never renumber them. The numbers
are how the user matches the Phase 2 report back to the cold pass.

Severity scale: **P0** breaks users or data on a path reachable today; **P1**
a real defect on a reachable path; **P2** proven but not reachable today, or a
simplicity, efficiency, readability, or doc defect worth acting on; **P3**
worth one line, not a blocker.

### Review tags

Every finding and every open question carries exactly one tag. The severity
says how bad the item is. The tag says what the author must do with it.

| Tag | Use it when | Author must | Usual severity |
|-----|-------------|-------------|----------------|
| `[issue]` | The change breaks an existing feature, or does not do what it sets out to do. | Fix before merge. | P0, P1 |
| `[question]` | The intent behind a decision is unclear, and the answer decides if it is a defect. | Answer before merge. | any |
| `[suggestion]` | The code works, but a named alternative is better for readability, efficiency, or idiom. | Fix, or reply with a reason. | P2 |
| `[optional]` | The item is not critical. The reviewer would appreciate the change. | Nothing. The author may skip it. | P3 |

Tag rules:

- An `[issue]` states the break as "if <trigger>, then <feature> breaks". The
  trigger is a real input or a real user action. No demonstrated break, no
  `[issue]`.
- A `[question]` asks why. It names what each answer means: "If X is
  intended, this is fine. If not, Y breaks." Every item in `OPEN QUESTIONS`
  is a `[question]`.
- A `[suggestion]` shows the alternative as code, not only as prose.
- An `[optional]` is one line.
- Pick the tag by the action the author must take. If the tag and the usual
  severity disagree, keep both and give the reason in one line.

Say out loud that Phase 1 is sealed, then continue.

---

## Phase 2 — Context check

Now open everything Phase 1 banned: the memory, the agent instruction files,
the architecture and task documents, the PR body, the commit log, the
conversation. Read them for what they say about the reviewed code.

Walk the sealed file from `C-01` downward. For each finding, fill in
**Verdict**:

- **Stands** — the context does not excuse it. Leave the finding as written.
  If the context changes its severity, say the old and the new: `Stands ·
  P2 → P0, this path is on the documented restart flow`. Do the same for the
  tag: `Stands · [suggestion] → [issue], the PR body promises X and the code
  does Y`.
- **`[INVALID AFTER CONTEXT CHECK]`** — the context proves it is not a
  problem. Tag the finding with this exact string and add one line naming the
  source that kills it, with its location:
  `[INVALID AFTER CONTEXT CHECK] — .arch/decisions.md:88 rules this format
  is single-writer, so the race cannot occur.`

Rules for Phase 2:

- **Append only. Never delete a finding, never edit its text, never renumber.**
  The user asked to see what was raised cold, precisely so they can judge
  whether the dismissal was right.
- A dismissal needs a source with a location, the same as a finding does.
  "The task did not ask for that" is not a source; the task file line is.
- Intent does not excuse effect. A document saying the code is meant to be
  safe is not evidence that it is safe. Only a fact that breaks the finding's
  trigger or its consequence invalidates it — a caller that cannot produce the
  input, an invariant enforced elsewhere in code you read, a platform the repo
  does not target.
- A finding that the context merely *explains* still stands. Knowing why the
  bug exists does not unmake it.
- The context may also add findings. If a document states a requirement the
  code does not meet, file it as `X-01`, `X-02`, … in a separate section. A
  context-derived finding needs the same four pieces of evidence.
- Resolve `OPEN QUESTIONS` the same way: answered by the context and it turns
  out to be real → promote it to an `X-` finding; answered and it is fine →
  leave it in the questions list with the answer.

---

## Phase 3 — Report

Report in this order:

1. **Verdict** — `APPROVED` or `CHANGES REQUESTED`, on its own line.
   `APPROVED` means no standing `[issue]` and no unanswered `[question]`.
   Standing `[suggestion]` and `[optional]` items do not block the verdict.
   List them below all the same.
2. **Target** — what was reviewed, and how it was picked.
3. **Counts** — findings raised cold, findings still standing, findings tagged
   `[INVALID AFTER CONTEXT CHECK]`, findings added by the context. Give the
   standing count per review tag.
4. **Standing findings**, sorted by severity, correctness above all. One block
   each: `id · severity · tag · angle · file:line`, then the trigger, the
   consequence, and the smallest fix.
5. **`[INVALID AFTER CONTEXT CHECK]` findings**, in their own section, each
   with the source that dismissed it. Short — one or two lines each. This
   section is never omitted, even when it is long.
6. **Open questions** — each one tagged `[question]`. State what could not
   be settled, and the exact check that would settle each one.
7. **Angles covered** — list every angle from Phase 1 and say which produced
   nothing. A clean angle is a result; do not report it as silence.
8. **Path to the sealed file**, so the user can read the raw cold pass.

Do not invent findings to look thorough. Do not compress the list to look
focused. `APPROVED` is a verdict, not a summary: it never replaces the
counts, the angles checked, or the non-blocking items. Never write "all good"
— report the angles checked and what is left standing.
