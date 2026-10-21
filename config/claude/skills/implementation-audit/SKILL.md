---
name: implementation-audit
description: >-
  Audit current code changes for correctness, completeness, compatibility, and
  production readiness before commit or PR. Check changed code, its consumers,
  survivors, public contracts, other platforms, borrowed behavior, concurrency,
  re-entrancy, edge cases, tests, and project gates. Trace behavior claims to
  authoritative sources or probes, and report only findings that survive
  refutation. Language- and framework-agnostic.
---

# Implementation Audit

Quality gate for a set of code changes. Answers one question: **are these changes correct, complete, non-breaking, and production-ready — or not yet?** Language-agnostic; adapts to whatever stack the repo uses.

This is NOT a generic bug hunt over the whole codebase. Scope = **what changed**, plus everything the change can reach or break.

## When to use

- "Audit / review / check my changes"
- "Is this feature fully implemented?"
- "Did I break anything / is this compatible with existing behavior?"
- "Make sure this is correct and bug-free before I commit / open the PR"

## Core stance

Three rules decide whether this was an audit at all. An audit missing any one of them is not an audit, whatever it concluded.

**1. Audit what the change does to EVERYTHING ELSE — not whether it does what the author intended.**

"Does this do what it meant to do?" can only ever confirm the intent. It is structurally incapable of finding the defects that actually ship, because those live in what the change does to parties it was not thinking about. Reviewers land findings in that gap; a self-audit that only re-checks intent will keep passing while they keep finding things.

So for every change, walk **outward** — see pass 5.

**2. Verify every behaviour claim against the authoritative source. "I think" is not a finding, and neither is "it should."**

An audit states what a thing *does*, evidenced. Before asserting any behaviour — of an OS, a dependency, a protocol, a runtime, a shell — read the thing that defines it: the man page, the spec/RFC text, the dependency's actual source, or a probe you ran. Say which one. If you cannot get evidence, mark the claim **unverified** and stop treating it as true.

Banned as audit output: "should be fine", "presumably", "I believe", "this is standard behaviour", "matches how X does it". Required instead: what the source says, or what the probe printed.

**When only a probe can settle it, write the probe.** A throwaway script that prints what the system actually did beats any amount of reasoning and costs a minute. Give it a **control** whose two outcomes point at different causes — a check that can only confirm what you already believe proves nothing.

For the deeper version of this — the source ladder, probes with controls, and diagnosing a *failure* rather than a diff — use the `ground-truth` skill alongside this one.

**3. A finding you have not tried to kill is not a finding yet.**

Rule 1 makes you look outward; rule 2 makes you evidence what you see. This one governs what you are allowed to *report*. Every candidate defect gets an honest attempt at refutation **before** it reaches the report — see pass 8.

Noticing costs nothing and is frequently wrong. A speculative finding is not free: it costs the reader's time, it competes for attention with the real ones, and a report padded with three unverified guesses gets the two genuine defects treated with the same shrug. **Signal ratio is the deliverable.** Three findings that all survive refutation beat fifteen that might.

The rest:

- **Re-read at the point of claim.** Before calling something wrong, missing, or broken, re-read the exact code and confirm. A stale mental model is the #1 source of false findings.
- **Evidence, not vibes.** Every finding cites `file:line` and states the concrete failure (input → wrong output/crash), not "this looks risky."
- **Green gates are necessary, not sufficient.** A passing build/test run with one unhandled edge case is still incomplete.
- **A passing test is not a covering test.** Confirm the test would actually fail if the behaviour broke; a test that passes through a different path than the one it is named for is worth nothing. Break the logic on purpose and check something goes red.
- **An unreachable case is not a gap — do not report it.** Verify reachability against the code before flagging a missing case. If it genuinely cannot occur, say nothing at all; padding a report with impossible "limitations" is hedging dressed as thoroughness, and it dilutes the findings that matter.
- **Check whether it was already decided.** Some code looks wrong and is deliberate. Before reporting, look for the decision: a comment giving the reason, an architecture doc, a closed-decisions ledger, or a test that deliberately pins the odd-looking behaviour. Re-raising a settled ruling burns trust and buries the new findings underneath it. If the decision exists but is undocumented where a reader would look, *that* is the finding.
- **No half-fixes, no deferral.** A real, reachable defect gets reported as must-fix this pass — not filed as "future" to dodge it. (Report it; the human decides the fix.)

## Procedure

Run the passes in order. Earlier passes are higher-leverage — a wrong model makes every line-level check moot.

### 0. Scope the change

1. Get the diff: `git diff` (unstaged), `git diff --staged`, or `git diff <base>...HEAD` for a branch. Prefer whichever matches "the current changes."
2. State the **intent** in one line — what is this change supposed to do, and who/what triggers it? If the intent isn't obvious from the diff + commit messages + task, ask before auditing (you cannot judge correctness against an unknown goal).
3. List the touched files and the public surface that changed (functions, types, signatures, fields, endpoints, config).

### 1. Design / model correctness — FIRST

The highest-leverage check. A wrong abstraction regenerates bugs no matter how clean each line is.

- Does the data model / structure actually represent what the feature needs, across its **full state space** — not just the happy case in the diff?
- Is each new field/state stored at the **right scope and kind** (per-request vs global, per-user vs shared, owned vs borrowed)? A new field that needs special-casing its siblings don't is a mis-model.
- Check against the **observable behavior the spec/user expects**, not against the code's own stated assumptions (that just inherits the blind spot).
- **Signal:** if you find yourself about to flag a *second* defect in the same subsystem, stop patching cells — the abstraction is probably wrong. Report the model flaw, not the third symptom.

### 2. Completeness — fully implemented, not halfway

- Search the diff for `TODO`, `FIXME`, `unimplemented`, `todo!`, `NotImplementedError`, `pass`, `raise NotImplementedError`, empty bodies, `return null`/stub returns, commented-out logic, `throw new Error("not implemented")`.
- Every branch/case introduced is actually handled — no `switch`/`match` arm that falls through silently, no `else` that swallows.
- Every new function/param/field/flag is **wired to a real caller**. Dead new code (added but never called, or a flag never read) = half-done.
- Error/failure paths exist where the happy path was added (fallible I/O, network, parse, external side-effects). A side-effect that can fail half-way leaves no orphaned/inconsistent state.
- Docs/comments that describe the changed code are updated in the same change — a stale comment is a defect.

### 3. Correctness & edge cases

- Trace the new logic by hand on concrete inputs. Off-by-one, boundary (`<` vs `<=`), empty/null/zero, first/last element, overflow, concurrency/ordering.
- Assertions and validations are **exact**, not wildcard — a check that still passes when the value is wrong is not a check.
- Inputs at trust boundaries are validated. Security-sensitive paths (auth, secrets, injection, path traversal) get extra scrutiny — never simplified away.

### 4. Concurrency, ordering, and re-entrancy

Skip only if the change genuinely cannot run concurrently with anything. Most changes that touch shared state, callbacks, threads, async tasks, signal handlers, or event loops can, and this is where the defects that survive review live: each line is right, and the *interleaving* is wrong.

- **Read between the lines — literally.** For each pair of consecutive statements touching shared state, ask what another participant can do in that gap. The classic: a check and the action it guards, split across a lock release, so the thing checked is no longer true when it is acted on. If a decision and its use must agree, they belong in one atomic step.
- **Ask what state can be observed mid-update.** A value written in two steps is visible half-written to anyone who reads between them. Bundle facts that must agree behind one lock rather than a field each — an observer must never see half of a transition.
- **Check every callback for re-entrancy.** If your code calls out to something the caller supplied — a sink, a handler, a listener, a virtual method — that callee may call straight back in, including calls that tear down the very thing currently executing. Ask specifically: can it destroy this object, close this resource, or remove this entry from inside the call? A join or lock taken afterwards then targets a thing the callback already disposed of.
- **Watch for self-directed waits.** A thread joining itself, a lock acquired twice non-reentrantly, an actor awaiting its own mailbox, a callback awaiting the queue it is running on. These deadlock permanently and only on the path where the caller happens to be that participant — so they pass every test that calls from somewhere else.
- **Name the ordering guarantee and prove it.** If the design says "A is always delivered after B", find what enforces it. A timer, a sleep, or "it's fast enough in practice" enforces nothing — under load the order flips. A guarantee should be *proven by state* (B's completion is recorded, and A reads that record) rather than *guessed from a clock*.
- **Setup and registration races.** Anything spawned before it is registered can complete and look for its own registration before it exists. Check that the window between "start the work" and "record the work" cannot be observed.

### 5. Blast radius — what this does to EVERYTHING ELSE

The highest-yield pass, and the one self-audits skip. Walk **outward** in all four directions and name what happens to each. "Nothing" is a valid answer only once you've looked.

**a. Neighbours — existing consumers, in the NEW states.**
The classic regression: the change makes an **old** code path reachable in a combination it never handled.

1. For each changed function/type/field, find **every existing caller and consumer** (grep the symbol repo-wide).
2. Verify each still behaves correctly **in the new states this change makes reachable** — not just that it compiles.
3. Walk both directions: "new feature vs old states" AND "every old feature vs the new state."
4. Behavioural changes to shared code: confirm no other feature silently relied on the old behaviour.

**b. Survivors — whatever outlives the thing being changed.**
Processes, threads, connections, file handles, timers, subscriptions, cached entries, background jobs. Ask: *who is still running when this finishes, and what do they now receive?* A cleanup step aimed at something already gone lands on whoever is still there instead.

**c. Public contracts — what a caller may LEGALLY do.**
For any exported trait/interface/function/endpoint: what can an implementer or caller do that the contract permits and the code cannot survive? Re-entrancy, calling back into the API from inside a callback, calling out of order, calling concurrently, never returning, returning an error. **"Our only implementation doesn't do that" is not an answer** — the contract is the API, not the current caller. Either the code survives it or the contract forbids it in writing.

**d. The other environment.**
The OS/runtime/browser/version you are *not* testing on. Does the change behave differently there, and does it now **diverge** from what the other one does? A behaviour copied from a dependency on one platform may not exist on the other.

**e. Borrowed behaviour — did anyone check it was right HERE?**
For anything replicated from a dependency, reference implementation, or another project: state the assumption that makes it correct *there*, then confirm that assumption holds *here*. Matching a reference's code is not correctness — the same code under a different model produces a different result.

### 6. The tests themselves are a target, not the verdict

A suite proves nothing broke **that a test watches**. It says nothing about whether the tests still watch it. Audit them as code, with the same suspicion as the change.

- **Read what a test runs, not what it is called.** A name states an intention; the body states the behaviour. A test can pass for years through a completely different path than the one it is named after, and it reports green the whole time — so the mechanism it claims to cover has *never* been exercised, and the day it breaks nothing goes red.
- **Run the mutation sweep on anything touching shared state or an invariant.** Break each guarantee on purpose, confirm a specific test fails, restore it. A guarantee that survives its own deletion is unguarded, whatever the suite total says. This also catches tests whose premise the change silently invalidated — a setup step that used to simulate something the new code now ignores by design.
- **Distrust wall-clock assertions.** A test asserting something took under N milliseconds fails on a loaded machine and passes on a fast one; it measures the runner, not the code. Prefer event-driven waits and lower-bound assertions ("not before X") over upper bounds.
- **Assert exact values.** A pattern match, a "not empty", or a length-only check still passes when the result is wrong.
- **New behaviour without a test that fails when it breaks is a gap** — report it as one.

### 7. Verification — run the project's own gates

Auto-detect what the repo uses; don't assume a language:

- **Build/compile:** `cargo build`, `npm run build`/`tsc`, `go build`, `make`, `mvn compile`, etc.
- **Tests:** `cargo test`, `npm test`, `pytest`, `go test ./...`, `mvn test`. Run the ones covering the touched area at minimum.
- **Lint/format/types:** `clippy`, `eslint`, `ruff`/`flake8`, `mypy`, `gofmt`/`vet`, whatever the repo configures (check `package.json` scripts, `Makefile`, CI config, pre-commit hooks).
- **Test coverage of the change itself:** does a new behavior have a test that would fail if the logic broke? If a non-trivial branch has none, that's a gap to report.

If a gate can't be run (no network, missing toolchain), say so explicitly — don't imply it passed.

### 8. Refute every finding — the last pass before the report

Passes 1–7 produce *candidates*. This pass decides which of them are real. Do not skip it because a finding looks obvious; the obvious ones are exactly where a wrong mental model hides.

Take each candidate and argue **against** it, in this order. Drop it the moment any step kills it:

1. **Re-read the code at the exact location, now.** Not the diff, not your notes — the file as it currently stands. A large share of candidates die here, killed by a detail three lines up.
2. **Is the triggering state reachable?** Construct the concrete path that gets there: the actual input, the call order, the configuration. If you cannot construct it, you do not have a finding — you have a shape that resembles one.
3. **Is it already handled somewhere else?** A guard in the caller, a validation at the boundary, a type that makes it impossible. Fixing what is already fixed is noise.
4. **Was it already decided?** Check for the comment, doc, or ledger that rules on it deliberately.
5. **Would the failure actually be observable?** If nothing downstream can see the difference, it is at most a nit — say so honestly rather than inflating it.
6. **State the evidence you would show a sceptic.** The spec line, the source you read, the probe output, or the exact trace. If the strongest thing you have is that it "looks wrong", it does not go in the report.

Then classify what survived:

- **CONFIRMED** — you can name the input and the wrong output, and the evidence for it.
- **PLAUSIBLE** — the reasoning holds but one step is unverified. Report it *labelled as such*, with the specific thing that would settle it. Never present it as confirmed.
- **DROPPED** — killed by a step above. It does not appear in the report at all.

**A second surviving finding in one subsystem changes what you report.** Stop listing symptoms and report the model flaw instead — see pass 1. Two findings in one area are usually one flaw wearing two hats, and a report that lists them separately sends the author off to patch two cells.

Where independent verification is cheap — a subagent, a fresh session, a colleague — use it on the survivors, and prompt it to *refute*, not to confirm. The mindset that found a defect is the worst judge of whether it is real.

## Report format

Report **only what survived pass 8**, ranked by severity, most severe first. For each:

```
[SEV] file:line — one-line defect                         CONFIRMED | PLAUSIBLE
  Failure:  <concrete input/state → wrong output / crash / regression>
  Evidence: <spec line / source read / probe output / exact trace>
  Fix:      <the smallest correct change, or the direction if it's the human's logic>
```

`PLAUSIBLE` additionally names the one unverified step and what would settle it. Anything you cannot mark at least PLAUSIBLE does not belong in the report.

Severity: **Blocker** (wrong result, data loss, crash, security) · **Major** (real bug on a reachable path, missing case) · **Minor** (edge case, quality) · **Nit** (style).

Calibrate honestly. Inflating a nit to Major to look thorough, or shading a Blocker down to avoid a FAIL, both destroy the report's usefulness — the author starts discounting every severity you assign.

Then, briefly, two things a bare findings list always omits:

- **Checked and clean** — the axes you walked that came back clean (neighbours, survivors, contracts, the other platform, concurrency). One line. This is what tells the reader you *looked*, and it is the difference between "nothing found" and "nothing there".
- **Not verified here** — anything you could not execute, reach, or evidence, and what would settle each. Name it plainly; a caveat stated is worth more than a confident summary.

End with a one-line verdict:
- **PASS** — correct, complete, compatible, gates green. Ready.
- **PASS w/ nits** — ship-able; listed nits are optional.
- **FAIL** — one or more Blocker/Major findings; not ready. List what must change.

Do not soften a FAIL into a PASS. If a gate didn't run or a case is unverified, the honest verdict is "incomplete," not "looks good."

**Never write "all good" or "no issues found" and stop there.** On its own it is unfalsifiable — it reads identically whether you audited everything or nothing, so it tells the reader precisely nothing. A clean audit still reports *what was checked, against what, and what remains unverified*. That is the difference between "I found nothing" and "there is nothing there", and only the second one is worth reading.

Equally: **passing an audit is not proof of correctness.** It proves the code matches a model you verified and stays compatible with what you walked. It does not prove the model is right for the outside world. Calibrate the verdict to that, and say which one you are claiming.

## Checklist (scan every audit)

- [ ] Intent stated; diff scoped
- [ ] Model/abstraction right across full state space (not just the diff's case)
- [ ] No TODO/stub/unwired/half-done code
- [ ] Every new branch & failure path handled
- [ ] Logic traced on boundary/empty/null inputs; assertions exact
- [ ] **Interleavings:** what another participant can do between any two statements touching shared state
- [ ] **Re-entrancy:** every callback checked for calling back in, including tearing down what is running
- [ ] **Ordering guarantees** proven by recorded state, not by a timer or "fast enough"
- [ ] **Neighbours:** every existing caller re-checked in the new states
- [ ] **Survivors:** named what still runs afterwards and what it now receives
- [ ] **Contracts:** every public surface survives what it legally permits (or forbids it in writing)
- [ ] **Other environment:** checked, and no silent divergence introduced
- [ ] **Borrowed behaviour:** its assumption re-confirmed for *this* codebase
- [ ] **Every behaviour claim** traced to a man page / spec / dependency source / probe — each one named
- [ ] No "should be", "presumably", "standard behaviour" anywhere in the findings
- [ ] Build + tests + lint run (or explicitly noted as un-runnable)
- [ ] **Tests read for what they RUN, not what they are named**; mutation sweep run on touched invariants
- [ ] New behavior has a test that fails if it breaks — **verified by breaking it**
- [ ] Docs/comments touching changed code updated
- [ ] **Every finding put through pass 8** and marked CONFIRMED or PLAUSIBLE; unreachable and already-decided ones dropped, not reported
- [ ] Findings cite file:line with concrete failure + evidence; "checked and clean" and "not verified here" both stated; verdict is honest
