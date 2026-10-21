---
name: code-simplicity
description: Simplify code and maximize readability without changing any logic or behavior. Targets files with uncommitted git changes; if the working tree is clean (or not a git repo), sweeps the whole repository. Use when the user asks to simplify code, improve readability, or clean up code without functional changes. Never spawns subagents.
---

# Code Simplicity

Make code simpler and more readable. Observable behavior must stay identical — same outputs, same side effects, same errors, same public API.

**Hard constraint: no subagents.** Do not use the Agent tool, Task tool, or Workflow tool. All reading, editing, and verifying happens inline in the main conversation, one file at a time.

## Step 1: Pick targets

Check for files with changes:

```bash
git diff --name-only HEAD              # staged + unstaged
git ls-files --others --exclude-standard   # untracked
```

- Any changed or untracked source files exist → those files are the full target set. Do not touch anything else.
- Working tree clean, or not a git repo → target the whole repository: every source file, excluding generated/vendored/build directories (`node_modules`, `target`, `dist`, `build`, `out`, `vendor`, `.git`, lockfiles, minified files) and non-code files.

List the chosen targets to the user before editing.

## Step 2: Establish a baseline

Run the project's test suite and/or build (whatever the repo provides: `cargo test`, `npm test`, `pytest`, `make`, etc.) and record the result.

- Baseline green → proceed. Every later verification must match it exactly.
- Baseline already failing → report the failures and stop. Behavior preservation cannot be verified against a broken baseline; ask the user how to proceed.
- No tests and no build → say so, proceed with extra caution, and rely on careful re-reading of each edit.

## Step 3: Simplify

Read each target file fully before editing it. Before touching any file, understand the flows it participates in — trace callers and callees enough to know what each function's behavior contract is; a simplification made without understanding the flow is where behavior drift comes from. Apply only transformations that are provably behavior-preserving:

**Allowed**
- **DRY**: extract repeated or near-identical code into one well-named shared function (or data table + loop for repeated literal blocks) and call it from every site — but only when the sites are truly identical in behavior, including error values and user-visible strings. Readability outranks deduplication: if the shared helper needs flags/branches to serve its callers, the duplication was not real — leave it.
- Do a step in fewer steps: collapse `match {Ok/Err => return}` boilerplate into `?`-style propagation (restructuring private function signatures is fine — public API stays), fold identity match arms into a catch-all binding, replace `let Some(x) = e else { return err }` chains with `ok_or_else(...)?` where the produced error is identical.
- Guard clauses / early returns to flatten deep nesting.
- Simplify boolean logic: remove double negatives, redundant conditions, `if x { true } else { false }` patterns.
- Merge duplicate or near-duplicate branches (e.g. two match arms differing only by an axis/direction — parameterize the axis).
- Extract a well-named local variable for a cryptic expression.
- **Naming**: rename local variables and private helpers so the name alone says what the value is or does — if a reader must look elsewhere to guess a name's meaning, it is the wrong name (`n` → `header_count`, `tmp` → `merged_spans`). Never rename public/exported names. Skip a rename when tests reference the symbol and tests are out of scope.
- Replace hand-rolled loops with idiomatic stdlib equivalents (iterator chains, comprehensions) only when semantics — evaluation order, laziness, short-circuiting, error propagation — are identical.
- Remove code that is unreachable or provably dead *within the target files*.
- Split an overly long function into private helpers in the same file when it genuinely reads better.
- Split a coherent part of a large file into its own new file/module when that genuinely improves navigation; pick a name that says what the contents are. Pure move — no logic edits in the same hunk as the move.

**Comments and doc comments**
- Rewrite doc comments and inline comments in the simplest possible wording — easy to understand at a glance — without dropping any detail they carry. If it can be shorter, make it shorter.
- Deduplicate docs like code: an explanation repeated across several items keeps one canonical copy; the other sites get a one-line summary plus a doc link to the canonical item.
- Comments describe *what* the code does, never *why*. Strip rationale: "we use X because Y" becomes a plain description of what X does. If removing the rationale would lose a detail about behavior (a constraint, an invariant, an edge case), restate that detail as a factual description of what the code does — do not keep it as a justification.
- Delete comments that merely restate code that is already obvious.
- Never delete details while simplifying — shorter wording yes, less information no. Domain-heavy comments (protocol/spec semantics, hard-won edge cases) err on the side of keeping.

**Forbidden**
- Any change to code flow or logic. After simplification the program must do exactly the same things in exactly the same order.
- Any change to public API: exported names, signatures, types, serialized formats.
- Reordering side effects or changing evaluation order.
- Changing user-visible strings: error messages, log lines, CLI output, reject/help hints.
- Touching anything test-related: test files, test modules, test helpers/fixtures. If a simplification would force a test edit (e.g. renaming a symbol tests call), skip that simplification instead.
- Fixing bugs found along the way — note them for the report, leave the code as-is.
- Performance rewrites, new abstractions, new dependencies, speculative flexibility.
- A shared helper whose call sites need different behavior — that is a new abstraction, not DRY.
- Style churn on lines that were already clear (no reformat-only diffs; match existing repo style).
- Repetition the project has explicitly chosen (e.g. a no-macros rule making newtype blocks repetitive): honor the project rule, note it in the report instead.

When unsure whether a transformation preserves behavior, skip it. Skipping is always correct; a clever simplification that shifts behavior is a failure of this skill.

**Where to look first.** LOC is the scent: sort source files by size and start with the largest — big files accumulate copy-paste (repeated error-handling boilerplate, per-variant blocks identical but for a literal, duplicated resolution logic). Declarative/data files (arg structs, seed tables, event payloads) usually only offer doc dedup and table-driven collapses; handler/dispatch files offer the structural wins.

## Step 4: Verify

After each file (or small coherent batch):

1. Re-read the diff and confirm every hunk is behavior-neutral.
2. Re-run the baseline command(s). Result must match Step 2 exactly — same passes, same failures if any were accepted.
3. Run the repo's formatter/linter if one is configured (`cargo fmt`, `prettier`, `ruff`, etc.) and confirm no new warnings.

Any mismatch → revert that file's edits, report what happened, and continue with the rest.

## Step 5: Report

Summarize per file: what was simplified and why it reads better. Confirm verification matches baseline. List separately, without having touched them: suspected bugs, pre-existing dead code outside the target set, and simplifications skipped because behavior preservation was uncertain.
