---
name: pr-desc
description: Generate a plain-English, anyone-can-understand pull request description from a PR number or the current branch's diff. Trigger when the user says "pr desc", "describe this PR", "write a PR description", "/pr-desc", or asks for an easy-to-understand summary of a PR.
---

# pr-desc

Produce a PR description that a non-engineer can follow. No jargon dumps. Explain *why it matters* before *what changed*.

## Steps

1. **Get the PR data.**
   - If the user gives a PR number: `gh pr view <N> --json title,body,additions,deletions,changedFiles,files,commits`
   - Then the diff: `gh pr diff <N>`
   - If no number: use the current branch's diff (`git diff <base>...HEAD`, base usually `develop`/`main`).

2. **Understand the change before writing.** Read the diff. Identify: the user-facing problem, the root cause, what actually changed, what was deleted vs reformatted. Do not write until you can explain it in one sentence to a layperson.

3. **Write using this exact format:**

```
## Summary
<2-4 sentences. The problem in plain words + what this fixes. Use a concrete real-world analogy if it helps. State the "before" behavior and the "after" behavior.>

## What changes
<Bullet list. Each bullet = one concrete change in plain English. Name the new behavior, not the line numbers.>

## How it works
<Numbered steps walking through the flow end to end, as a story. "A request comes in → system checks X → if Y then Z.">

## What gets removed
<What was deleted or replaced. Be honest: if nothing was functionally removed and lines were only reformatted, say so explicitly in parentheses.>
```

## Rules for the writing

- **Plain language.** Translate codes/enums/identifiers into what they *mean* (e.g. "response code 85 = a $0 card-verification check"). Keep the literal value too, in parentheses.
- **Why before what.** Lead each section with impact, not implementation.
- **No file paths or line numbers in the body** unless they genuinely aid understanding.
- **Honesty.** Separate real behavior changes from cosmetic reformatting. Never inflate.
- **Short.** If a bullet runs over two lines, it's too dense — split it.
- Output the description as plain markdown for the user to copy. Do not post it to GitHub unless asked.

## After writing

4. **Offer to update the PR.** After outputting the description, ask the user whether they want the PR description updated directly on GitHub (e.g. via `gh pr edit <N> --body ...`). NEVER update the PR without the user's explicit approval — always ask first and wait for a clear yes. If the user declines or doesn't answer, do nothing.
