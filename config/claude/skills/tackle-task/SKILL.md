---
name: tackle-task
description: Take the next task off the tracker and run it through the team until it earns an LGTM.
disable-model-invocation: true
---

# tackle-task

Pull the next task off the project's tracker and run it to production quality.
The team does the work; `lgtm` decides when the work is done.

## 0. The instruction files govern every step (HARD)

Before step 1, read every instruction file that applies to this task:

1. The global `~/.claude/CLAUDE.md`, and every file it imports.
2. The repository's `CLAUDE.md` (also `.claude/CLAUDE.md`), if one exists.
3. The repository's `AGENTS.md`, if one exists.

When a `CLAUDE.md` and an `AGENTS.md` disagree, the `CLAUDE.md` wins. When the
global file and the repository file disagree, the precedence the files state
decides.

Follow every rule in those files, strictly, at every step of this skill and of
every skill it invokes. No rule is skipped, bent, or traded for speed. No step
of this skill and no skill it invokes overrides a rule: where one seems to, the
rule wins.

A failure to follow a rule is irresponsible and arrogant behavior, and it is not
acceptable. Before you call any step done, check the work against each rule
that applies to it. A rule not met means the step is not done: go back and meet
it before you report anything to the owner.

**Done when:** you have read each file above and can name the rules that apply
to this task.

## 1. Name the task

Read the project's task tracker and state the next task in one line: what it
does, and who triggers it. When the tracker names no clear next task, ask which
one.

**Done when:** the owner has seen the task named and agreed it is the one.

## 2. Clear the fog before any code

Answer all three, from the task text and the code it touches:

- What is the observable behavior, as a before → after with real values?
- Which existing modules does it touch, and what do they already guarantee?
- Which forks does it open, and which option wins, and why over the others?

An answer that stays fuzzy sends you to the matching skill:

| What is fuzzy | Skill |
| --- | --- |
| The plan, the decision, the assumption under it | `/mattpocock-skills:grilling` |
| The terms, the entities, what a word means here | `/mattpocock-skills:domain-modeling` |
| The seam, the interface, where a module boundary sits | `/mattpocock-skills:codebase-design` |
| The shape of the whole codebase around this task | `/mattpocock-skills:improve-codebase-architecture` — the owner types this one; ask them to run it |

**Done when:** every question above has an answer with a concrete example
behind it, and every genuine fork is resolved with the owner.

## 3. Run the team under LGTM rules

Invoke `/claude-teams` to do the work, and `/lgtm` to govern it: `lgtm` owns
the loop and the verdict, and each round runs correctness, then
`/code-simplicity`, `/optimize-code`, `/docs-writer`, `/unit-tester`, then the
audit. A verdict short of LGTM sends the change back for another round, scoped
to what that round changed.

**Done when:** a round closes on a genuine LGTM, with the gates green and their
real numbers reported.
