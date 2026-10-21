---
name: docs-writer
description: Rewrite existing documentation — doc comments and prose docs — so it is as short and easy to read as possible without losing a single real detail, and so it states only WHAT the code does (no rationale, no history, no alternatives). Targets changed files by default; falls back to the whole repo; or takes explicit files, folders, or "whole repo" from the user. Use when asked to simplify docs, clean up doc comments, make docs easier to read, rewrite documentation, or "/docs-writer". Never edits code.
---

# docs-writer

Take documentation that already exists and make it plain. Same facts, fewer and easier words.

Two hard limits:

1. **No detail is lost.** Shorter wording, never fewer facts. If a sentence carries a parameter unit, a bound, a panic condition, or an error case, that survives the rewrite.
2. **Docs say WHAT, not WHY.** A doc describes what the function, type, field, or snippet does. Reasoning, motivation, design history, rejected alternatives, and comparisons are deleted. Exception: a fact the reader cannot use the thing correctly without — a spec/protocol requirement, or a non-obvious constraint. One short clause, never a paragraph.

**This skill edits documentation only. Code is never edited.** A doc that contradicts the code is a finding to report, not a reason to change the code. Report the mismatch; if the user says fix the docs, rewrite the doc to match what the code actually does.

## Step 1: Pick the scope

Work down this ladder. Stop at the first rung that gives you files.

1. **The user named a target** — specific files, a folder, or "whole repo". That wins over everything else. Use it exactly as given.

2. **Changed files.** Find the base branch: `git symbolic-ref refs/remotes/origin/HEAD` (fallback: whichever of `main` / `master` / `develop` exists). Collect:
   - `git diff <base>...HEAD --name-only` — commits on this branch
   - `git diff HEAD --name-only` — uncommitted edits
   - `git ls-files --others --exclude-standard` — untracked files

   Any files → **those files are the scope.** Inside them, every doc attached to something the change touched, plus any doc file that describes it.

3. **No changes → whole repo.** Every source file with doc comments, plus the prose docs tree (`docs/`, `README`, rustdoc/module docs).

**Whole repo means whole repo.** When the user asks for it, or rung 3 lands there, do the entire repo in one pass. Do not ask for confirmation, do not sample a subset, do not stop partway and offer to continue. Size is not a reason to narrow the scope.

## Step 2: Learn the house style — before writing anything

- **Read `CLAUDE.md` / `AGENTS.md` / `CONTRIBUTING.md` if present.** Repo doc rules override this skill's defaults on every point they cover.
- **Read the surrounding docs.** Match the existing voice, person, tense, and structure. A rewrite that reads foreign to the file is wrong even when each sentence is clearer.
- **Note the doc form** the language uses: `///` and `//!` (Rust), docstrings (Python), JSDoc/TSDoc, godoc. Keep the form; change the prose.

## Step 3: Read the code before rewriting its doc

Never simplify from the old doc alone — the old doc may be wrong.

- Read the actual function body, type definition, or snippet the doc sits on.
- Confirm each claim against the code: every parameter, the return value, each error and panic, side effects, units, ranges, defaults.
- Doc and code disagree → **the code is the truth.** Write what the code does, and record the contradiction as a finding for Step 6.
- A claim you cannot confirm from the code in front of you gets confirmed from its callers or the spec it implements — never from memory.

## Step 4: Rewrite

**Cut these — always:**

- Rationale and motivation: "we do this because…", "this is needed so that…"
- Arguments against other designs: "otherwise it would…", "we don't X because Y breaks", "unlike the naive approach…"
- History and status: "previously this…", "TODO/later/for now", ticket ids, task codes, codenames, phase names
- Filler: "simply", "just", "basically", "note that", "it is important to", "in order to"
- Restating the name: `/// Gets the name.` on `fn name()` says nothing — say what it returns and when it is empty
- Praise and hedging: "elegant", "robust", "should generally"

**Keep these — always:**

- Every parameter's meaning, unit, valid range, and what an out-of-range value does
- The return value: what it is, and what each variant/`None`/error means
- Errors, panics, and the exact condition for each
- Side effects: what it mutates, writes, spawns, locks, blocks on
- Invariants and preconditions the caller must satisfy
- Exact values, literals, and names — never soften `<C-t>`, `0`, `core:lock`, or a field name into "the key" / "the value" / "some state"
- Concrete examples that show input → exact output. If one exists, keep it. If a behavior is non-obvious and no example exists, one tiny example is worth adding.

**How to word it:**

- **Easiest word that still says the thing.** Real established technical terms are fine (`mutex`, `PTY`, `epoch`); invented phrases are not. Never coin a phrase and then use it as if it were a known term.
- **Lead with the verb, in one line.** `/// Returns the pane under the cursor, or `None` when the point is on a border.`
- **One idea per sentence.** A sentence over two lines splits.
- **Present tense, active.** "Writes the buffer", not "the buffer will be written".
- **A newcomer test:** an engineer who has never read this codebase understands every phrase on first read, without scrolling back. If not, rewrite.
- **Structure per item:** one summary line, then the details that survived the cut, then the example. Skip anything that does not apply.

**Prose doc files** (`docs/`, `README`, module docs) follow the same rules, one level up: what the thing does and how the data flows, top-down — concept, then mechanism, then a real before → after. No design-defence sections.

## Step 5: Check every rewrite

For each doc you changed, before moving on:

- **Fact diff.** List the facts in the old doc. List the facts in the new one. New must contain all of the old's true facts. A dropped fact is a defect, not a simplification.
- **Code match.** Re-read the code and confirm the new doc is true of it as written.
- **No leaks.** No task ids, codenames, phase names, or internal tracker language anywhere.
- **Neighbours.** Docs elsewhere describing the same item stay consistent — fix them in the same pass, they are in scope.
- **Gates.** Run whatever the repo runs on docs: `cargo doc` (with `-D warnings` if the repo sets it), doc tests, linters, link checkers. Report the real numbers.

## Step 6: Report

Short, plain, in this order:

1. **Files rewritten** — one line each: what the docs in that file now say differently.
2. **Facts removed** — anything cut that was not rationale/filler, with the reason. Should normally be empty; if it is not, name every item.
3. **Contradictions found** — docs that disagreed with the code. State the doc's claim, the code's actual behavior, and the file:line. These may be real code bugs. Code is never edited; if the user says fix the docs, rewrite them to match the code.
4. **Missing docs** — public items in scope with no doc at all. List them, do not write them unless asked; this skill simplifies what exists.
5. **Gates** — what ran, real numbers. If a gate did not run, say so.
