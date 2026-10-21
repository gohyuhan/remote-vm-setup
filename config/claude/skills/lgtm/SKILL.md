---
name: lgtm
description: Build a change and keep looping over it — correct, then simplify, optimize, document, then audit against real evidence — until it earns a genuine LGTM. Each round ends in a verdict; anything short of LGTM sends it back for another round, scoped to what actually changed. Use when asked to build/fix/refactor something and get it to production quality, to "loop until it's right", to run the full quality pipeline, or when invoked as /lgtm. Language- and framework-agnostic.
---

# LGTM

A change is not done when it works. It is done when a reviewer who is trying to
find fault cannot find any. This skill is that reviewer, run in a loop, on your
own work.

## The loop

```
Round N:
  0. Understand + freeze the goal   (round 1 only)
  1. Build + make it correct        code-on-steroid, unit-tester
  2. Simplify → optimize → document code-simplicity, optimize-code, docs-writer
  3. Audit against evidence         implementation-audit, ground-truth
  4. Verdict: LGTM or REQUEST CHANGES
     LGTM            → stop, report
     REQUEST CHANGES → round N+1, scoped to the findings
```

Hard cap: **3 rounds.** Round 4 does not start. If round 3 does not reach
LGTM, stop and report what is blocking it and why the last two rounds did not
close it. A loop that will not converge is information, not a reason to keep
spending.

## Size the loop to the change first

The full loop is six skills and up to three rounds. On a two-line change that
is not thoroughness, it is waste, and it buries the one thing that mattered
under five clean bills of health.

Before round 1, size it:

- **Trivial** — a rename, a typo, a constant, a comment. Make the change, run
  the gates, done. No loop. Say you skipped it and why.
- **Small** — one function, no new state, no new caller. Steps 0 → 1 → 4. Pull
  in step 2 or 3 only if step 4 finds something.
- **Full loop** — new state, a new flow, a public surface, concurrency, a data
  model, anything crossing a process/OS/network boundary, or anything the user
  called risky.

When it is genuinely between two sizes, take the larger one. Guessing small on
something that was large is the expensive mistake; the reverse costs one pass.

## One owner per phase per round

`code-on-steroid` runs all four phases (correct → simple → fast → documented).
The standalone skills run one phase each, deeper. Running both means every
phase runs twice per round for no gain.

So each phase has exactly one owner in a round:

| Phase | Owner | The other one does NOT run |
|---|---|---|
| Correct | `code-on-steroid` (step 1) | — |
| Simplify | `code-simplicity` (step 2) | code-on-steroid's phase 2 |
| Optimize | `optimize-code` (step 2) | code-on-steroid's phase 3 |
| Document | `docs-writer` (step 2) | code-on-steroid's phase 4 |
| Audit | `implementation-audit` (step 3) | — |

When you invoke `code-on-steroid` in step 1, say so explicitly: *implement and
make correct; stop after the correctness phase, the later phases have their own
owner.*

**Never reorder.** Simplifying wrong logic gives compact wrong logic.
Optimizing duplicated logic optimizes it in two places and lets them drift.
Documenting code that is about to change wastes the pass.

---

## Step 0 — Understand, and freeze the goal (round 1 only)

Before any code. This step is the difference between three cheap rounds and
three expensive ones.

1. **Read the house rules.** The repo's `CLAUDE.md` / `AGENTS.md` /
   `CONTRIBUTING.md`. If it says logic edits need the owner's sign-off, this
   skill **proposes and waits** at every point it would otherwise edit logic.
   If it forbids subagents, worktrees, or commits without say-so, that binds
   here too. House rules outrank this skill everywhere they touch.
2. **Trace the real flow end to end** — every file the change touches, who
   calls it, what outlives it. Not the file the task names; the whole path.
3. **Write the frozen goal** to `<scratchpad>/lgtm-ledger.md`:
   - **Goal** — one line, in plain words, what the change must make true.
   - **Acceptance** — the exact checks that prove it. Exact input → exact
     output, not "works correctly".
   - **Out of scope** — what this change deliberately does not do.
   - **Baseline** — the gate numbers before you start (tests passing, lint,
     build) and what the code does today for each flow you will touch.

The frozen goal is what step 4 judges against. Without it, round 3 grades
against whatever the code drifted into and passes itself.

**Re-read the ledger at the start of every round, and append each round's
verdict to it.** A three-round loop is long enough that the conversation gets
summarized part way through. The ledger is what survives that — it is the only
place the original goal, the baseline, and the finding history stay exact
instead of becoming a paraphrase of a paraphrase.

**If the goal is genuinely ambiguous, ask now.** One question before round 1
is cheaper than three rounds aimed at the wrong target.

---

## Step 1 — Build and make it correct

Invoke `code-on-steroid`, scoped to implement + correctness.

Then `unit-tester`, **only if the change has logic worth breaking** — a branch,
a loop, a parser, state, money, security, anything with an edge. A renamed
variable does not need a test; YAGNI applies to tests too.

Tests must assert the **exact** expected value. A test that still passes when
the result is wrong is worse than no test, because it reports safety.

Gates green before step 2. Not "mostly green".

---

## Step 2 — Simplify, then optimize, then document

Three skills, in this order, each finishing before the next starts:

1. `code-simplicity` — reuse what already exists, kill duplicate logic.
2. `optimize-code` — same result, less work.
3. `docs-writer` — every doc and inline comment matches the code as it now
   stands.

**Re-run the gates after each one, not once at the end.** If behavior changed,
you then know which of the three did it. Running all three and finding a
regression at the end costs you the bisect.

**Behavior is frozen for this whole step.** These three phases may not change
what the code does. A phase that changed behavior it was not allowed to change
is a defect — revert it, do not rationalize it.

### The resource ledger

After `optimize-code` finishes, write to the ledger what it actually removed —
the allocation in the loop, the clone, the extra pass, the redundant round
trip, the layer of indirection.

From that point on, **any edit that puts work back onto a path optimize-code
touched must be named in the verdict**, with why it was unavoidable. Rounds 2
and 3 are where a correctness fix quietly re-adds the clone that round 1 spent
a phase removing. Naming it is the only thing that catches it.

No invented benchmarks. Record what you can actually measure and say what you
could not.

---

## Step 3 — Audit against evidence

Invoke `implementation-audit`. Its job is not "does this do what I meant" —
that can only ever confirm your own intent. Its job is **what does this change
do to everything else**: existing callers in the states the change newly makes
reachable, whatever outlives it, what a public contract legally permits, the
platform you are not sitting on.

Invoke `ground-truth` for **every behavior claim about something you cannot
directly see** — another OS, a dependency's internals, a kernel API, a
protocol, a shell. Read the man page, the spec, the dependency's source, or run
a probe. Cite which.

Banned as audit output: "should be fine", "presumably", "I believe", "this is
standard behavior", "matches how X does it". A claim with no evidence behind it
is not a finding and it is not a clearance — it is a guess wearing a verdict's
clothes.

**Reach for `ground-truth` early, not as a last resort**, when: the same area
has been flagged twice, a fix "should work" but does not, or you catch yourself
about to write "we will have to rely on CI".

---

## Step 4 — The verdict

Answer one question with evidence: **would a reviewer trying to find fault find
any?**

Walk all of these. A skipped line is an automatic REQUEST CHANGES:

- [ ] **Goal met** — against the frozen goal in the ledger, not against what
      the code turned into. Every acceptance check passes, with real values.
- [ ] **Scope held** — nothing built that was not asked for, nothing quietly
      dropped that was. If scope moved, that is the user's call, not yours.
- [ ] **Blast radius walked** — every existing caller of what you touched,
      evaluated in the *new* states this change makes reachable.
- [ ] **Edge cases enumerated** — empty, one, many, max, malformed,
      out-of-order, concurrent, failure mid-way. Each one named and answered.
- [ ] **No resource regression** — nothing put back onto a path optimize-code
      cleaned. Anything added is named here with its reason.
- [ ] **Gates green** — build, tests, lint, format, docs. Real numbers, not
      "passing".
- [ ] **Tests still watch** — pick each guarantee, break it on purpose, confirm
      a test fails, restore. Green proves nothing broke that a test *watches*;
      it never proves the tests still watch.
- [ ] **House rules honored** — the repo's own constraints from step 0.
- [ ] **Docs true** — no comment describing behavior that no longer exists.

**LGTM** requires every box. Write it out with the evidence.

A **round-1 LGTM on a full-loop change is suspicious.** Not impossible, but the
usual cause is a reviewer who checked that the code does what it meant to and
called that a review. Before accepting it, name one thing you checked that
could have failed and did not — a specific caller in a specific new state. If
you cannot name one, you did not walk the blast radius; go walk it.

Do not invent findings to look thorough either. A padded finding costs a real
round.

**REQUEST CHANGES** — every finding gets:
- `file:line`
- what is wrong, in one plain sentence
- a concrete failure: *these inputs → this wrong result*
- which round introduced it

A finding with no concrete failure scenario is a hunch. Do not send a round
back for a hunch.

---

## Rounds 2 and 3 — scoped, not repeated

A later round is **not** a re-run of the pipeline. Full re-sweeps are where the
cost goes and they find nothing new.

Round N+1 runs only:

1. The fix for each finding — **at the layer that is actually wrong**, not the
   layer that reported it. Before editing at the reported location, prove every
   layer above it is right. Fixing below a broken layer looks like progress and
   the bug comes back next round.
2. The step-2 phases, **on the touched files only**.
3. Step 3, scoped to the fix and its blast radius — plus a direct re-check that
   each previous finding is actually closed.
4. Step 4, full checklist. This one is never scoped down.

### Two findings in one area means the model is wrong

One finding is a bug. A **second** finding in the same subsystem is a signal:
stop patching cells. The abstraction is wrong, and every further patch is built
on it. Step back, name the mis-modeled thing, and fix that — the whole class of
bugs disappears by construction.

If the repo says logic is the owner's, **propose the remodel and stop.** Do not
redesign their model unilaterally.

Two findings that **contradict** each other ("X must happen" and "not-X must
happen") are proof the model needs two parts. Do not pick a side and do not
oscillate — one tier cannot serve both.

### Never repeat a failed approach

If a round tried something and it was flagged, round N+1 does not try it again
with a small variation. Change layer or change approach.

### Check that it is converging

At the end of each round, compare this round's findings to the last one:

- **Fewer and less severe** → converging. Continue.
- **Same severity, different spot** → you are patching symptoms. Go up a layer.
- **A finding reopened** → the previous fix did not hold. Do not re-fix it the
  same way; find out why it did not hold first.
- **More findings than last round** → the change is fighting the design. Stop
  the loop early and take that to the user. Burning round 3 will not fix a
  design problem, and stopping at round 2 with a clear diagnosis is worth more
  than a third round of patches.

Stopping early with a real diagnosis is a success, not a failure to finish.

---

## Reporting

**Between rounds** — three lines, no essay:

```
Round N: <verdict>. <count> findings.
  <file:line> — <one line> — <concrete failure>
Next: <what round N+1 will touch>
```

**At the end** — the ledger's frozen goal, what actually changed (one line per
file, plain words), the resource ledger, the real gate numbers, and anything
the user should push back on: decisions you made, things you deleted, behavior
you traded away. If you removed something that used to work, say so on its own
line.

Then delete the ledger. It is scratch.

## Boundaries

- The loop runs **inline** in this session. No subagents, no workflows, unless
  the user asks for them.
- **No commits, no pushes, no PRs.** Not at LGTM, not ever, unless the user
  says so for that specific action.
- The loop fixes the change under review. It does not clean up adjacent code it
  happened to read. Mention what you noticed; do not edit it.
- Reaching the round cap is a valid outcome. Report it honestly. Three rounds
  and an honest "here is what is still wrong" beats a fourth round and a
  self-granted LGTM.
