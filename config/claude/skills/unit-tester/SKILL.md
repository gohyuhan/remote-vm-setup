---
name: unit-tester
description: Write unit, integration, and end-to-end tests that verify expected behavior AND actively try to break the system — edge cases, malformed input, out-of-order calls, failure injection — to prove it degrades gracefully. Targets the diff against the default branch first; if there is no diff, asks the user for a target (function/endpoint/flow) or audits the whole repo and tightens its existing tests. Use when asked to write tests, add test coverage, test a feature/endpoint/flow, harden the test suite, or "try to break" the system. Language- and framework-agnostic. Never edits product code.
---

# Unit Tester

Two jobs, always both:

1. **Prove the expected behavior.** Every documented/intended flow has a test that fails if the logic breaks.
2. **Try to break the system.** Interact with it in ways no happy-path user would — boundary values, garbage input, calls in the wrong order, dependencies failing mid-flight — and assert it handles each **gracefully**: a clear error, no crash, no data corruption, no half-committed state, and the system still usable afterward.

**Hard rule: this skill writes tests only. Product code is never edited.** A bug found along the way is a finding to report, never a thing to quietly patch — and never a reason to bend an assertion until it passes.

## Step 1: Pick the target

Work down this ladder; stop at the first rung that gives you a target.

1. **Diff against the default branch.**
   - Find the base: `git symbolic-ref refs/remotes/origin/HEAD` (fallback: whichever of `main`/`master`/`develop` exists).
   - Collect all changes: `git diff <base>...HEAD` (branch commits), `git diff HEAD` (uncommitted), `git ls-files --others --exclude-standard` (untracked source files).
   - Changes found → **the changed behavior is the target.** Test what the change *does*, not each hunk: trace every changed function/endpoint to the behavior it alters, and test that behavior plus its blast radius (existing callers now reachable in new states).

2. **No changes → ask the user.** Offer the choice plainly:
   - Name a target — specific functions, endpoints, modules, or a user-facing flow — and this skill tests exactly that, or
   - Say "whole repo" → run **Repo audit mode** (below).

   Do not guess a target when the diff is empty; ask.

## Step 2: Learn the repo's testing conventions — before writing anything

Read before you write. Tests that ignore the house style get rewritten or deleted.

- **Framework & runner:** find it in the manifest/CI config (`cargo test`, `pytest`, `jest`/`vitest`, `go test`, JUnit, `playwright`/`cypress`, …). Use what the repo uses; never introduce a new test framework unless the repo has none.
- **Placement & naming:** where do existing tests live (`tests/` dir, `<module>/tests.rs`, `*_test.go`, `*.spec.ts`, …) and how are they named? Match exactly.
- **Fixtures/helpers:** find the existing test helpers, factories, fakes, and harnesses. Reuse them — a second parallel fixture stack is slop.
- **Run the existing suite first** and record the result. Already-red tests are recorded as-is; they are context, not your job to fix, and your later runs must not be blamed for them.

## Step 3: Understand the behavior under test

You cannot break what you don't understand, and you cannot assert behavior you haven't verified.

- Read the target code fully. Trace each flow end to end: entry point → each step → side effects → result.
- Establish the **expected behavior from the spec/docs/types/callers — not from the code's own happy path.** If the intent is genuinely ambiguous (the code does X, a caller expects Y), stop and ask; a test that pins the wrong expectation is worse than no test.
- List every trust boundary the flow crosses (user input, network, file, DB, IPC, env) — each one is an attack surface for Step 4.

## Step 4: Design the test set

For each behavior, choose the **lowest level that can prove it**, then cover all three axes:

**Level**
- **Unit** — pure logic, one function/type, dependencies faked. Most edge cases live here: cheap, fast, precise.
- **Integration** — real components wired together (handler + store, parser + state machine, service + real DB/queue if the repo's harness supports it). Proves the seams.
- **End-to-end** — the user-visible flow through the real entry point (CLI invocation, HTTP request, UI action). Few, expensive, reserved for the flows a user actually runs.

**Axis 1 — expected behavior.** The documented flow, each meaningful variant, exact outputs asserted.

**Axis 2 — edge cases.** Work through this catalog for every input and state; skip a row only when it's genuinely impossible (unrepresentable in the type system), not merely unlikely:

- **Boundaries:** empty, zero, one, exactly-at-limit, one-past-limit, max value, negative, overflow.
- **Malformed input:** null/None, wrong type, truncated, oversized, invalid encoding, control characters, injection-shaped strings (`'; DROP`, `../../`, `<script>`, format specifiers) at every trust boundary.
- **Text:** non-ASCII, emoji, combining characters, right-to-left, zero-width — anywhere text is parsed, measured, or displayed.
- **Time:** timezone boundaries, DST transitions, leap days, clock going backwards, epoch edges — anywhere time is compared or stored.
- **Ordering & state:** operations out of order, called twice (idempotency), re-entered, called before init / after close / after error, stale or concurrent state.
- **Failure injection:** each dependency erroring, timing out, returning partial data, failing mid-side-effect. The graceful-handling assertions: correct error surfaced, no orphaned/half-written state, retry or next call works.
- **Scale:** large N, deep nesting, resource exhaustion where testable.
- **Concurrency:** races and interleavings, where the repo's harness can drive them deterministically.

**Axis 3 — blast radius.** Existing behaviors the target touches: tests proving the old flows still work in the states the new code makes reachable.

## Step 5: Write the tests

- **Exact assertions, never wildcard.** Assert the exact value, the exact error variant, the exact message the user sees — not "is some", not "no exception", not a length check. A test that still passes when the result is wrong is not a test.
- **One behavior per test, named for what it pins:** `rejects_empty_header`, `retries_once_then_surfaces_timeout` — not `test_edge_case_7`. A reader must know what broke from the name alone.
- **Deterministic.** No sleeps-as-synchronization, no real clocks/network/randomness without injection or fakes. A flaky test is a defect.
- **Independent.** Any order, any subset, no shared mutable fixtures leaking between tests.
- **Arrange minimal.** The setup shows exactly what the behavior depends on; a 50-line arrange for a 1-line assert means the test is at the wrong level.
- Graceful-handling tests assert the **full** contract: the error/response AND the state afterward (nothing corrupted, nothing half-committed, next operation succeeds).

## Step 6: Run and settle

1. Run the suite. Every new test must run. Compare against the Step 2 baseline — pre-existing reds stay theirs, new reds are yours to explain.
2. **A new test that fails has found a bug — or a wrong expectation. Never bend the assertion to the code.** For each red: re-verify the expectation against spec/docs/callers.
   - Expectation confirmed correct → the code is buggy. Keep the test asserting the correct behavior, report it as a bug finding (below), touch no product code. The human decides the fix; a red repro test is the finding at its most useful.
   - Expectation was wrong → fix the test's expectation to the verified behavior and say so in the report.
3. **Mutation check on a sample:** for a few critical new tests, mentally (or actually, then revert) flip the guarded condition and confirm the test would fail. A suite that stays green under a broken implementation proves nothing.
4. Lint/format the test code with the repo's tools.

## Repo audit mode (whole repo, when the user chooses it)

Scope like a review, not a rewrite — module by module, shared code first:

1. **Map:** list the modules/subsystems and their existing test files. Use the repo's architecture docs/wiki/graph if present. State the unit list before working it.
2. **Understand each unit** (Step 3 depth) before judging its tests.
3. **Tighten per unit:**
   - **Weak assertions** → exact (a `matches!(_, _)`/`is_ok()`/not-throws check becomes the exact expected value).
   - **Coverage gaps** → new tests from the Step 4 catalog, priority to trust boundaries, error paths, and state transitions with no test at all.
   - **Dud tests** (test nothing, can't fail, assert the mock) → flag for deletion in the report; don't silently delete.
   - **Flaky patterns** (real time, real network, order dependence) → flag; fix only when the fix is test-local.
4. One unit = one coherent batch; run the suite after each.

## Report format

```
## Target: <diff vs <base> | user-named: X | repo audit>

Written: <n> unit · <n> integration · <n> e2e
  <test file> — <behaviors pinned, one line each>

Edge cases covered: <the catalog rows exercised, one line each — and any row
  skipped as impossible, with the reason it cannot occur>

Bugs found — product code untouched, human call needed
  [SEV] file:line — <defect>
  Repro test: <test name, currently red>
  Expected (per <spec/doc/caller>): <exact> · Actual: <exact>

Tightened (audit mode): <file:line — weak assertion → exact | dud flagged | gap filled>

Suite: <n> passed · <n> new-red (all listed above as bugs) · <n> pre-existing-red (untouched)
```

## Checklist

- [ ] Target from diff first; asked the user only when the diff was empty
- [ ] Repo's framework/placement/naming/fixtures reused — nothing parallel invented
- [ ] Expected behavior verified from spec/docs/callers, not the code's happy path
- [ ] Every input walked through the edge-case catalog; skips justified as impossible
- [ ] Each test at the lowest level that proves it; e2e reserved for real user flows
- [ ] Assertions exact; tests named for the behavior; deterministic; independent
- [ ] Graceful-handling tests assert error AND post-state
- [ ] No product code edited; red tests reported as bugs, never assertion-bent
- [ ] Mutation-checked a sample of critical tests
- [ ] Suite run; new vs pre-existing reds separated honestly
