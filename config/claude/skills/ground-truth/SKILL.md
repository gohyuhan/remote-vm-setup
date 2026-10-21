---
name: ground-truth
description: Reach certainty about behaviour you cannot directly observe — another OS, a dependency's internals, a kernel API, a CI-only failure — and break out of repeat-failure loops. Use when a change has been attempted several times and keeps getting flagged, when CI fails on a platform you cannot run locally, when review keeps landing valid findings in one area, when a fix "should work" but doesn't, or when about to say "I can't verify this here, we'll have to rely on CI". Replaces guessing with the documentation, the dependency source, or a probe you actually ran; tells you when to stop patching and remodel; and stops you fixing at the layer that merely reported the failure. Language- and platform-agnostic.
---

# Ground Truth

For the work where being *approximately* right produces something that looks finished and fails anyway.

## When to use

- The same change has been attempted more than twice and review keeps finding real problems.
- CI fails on an OS you cannot run locally.
- You are about to write "on this machine I can't check that, so we rely on CI".
- A fix looked obviously correct and did not work.
- You are reasoning about a kernel API, another platform, a dependency's internals, or a protocol.

## The one belief this skill installs

**There is always a source, and you can go read it.** Almost nothing you need is genuinely unknowable — it is written down in a man page, a specification, the dependency's own source on this disk, or it can be printed by a ten-line probe. "I can't verify this from here" is nearly always false; what is true is "I have not looked yet."

Being unable to *run* a platform does not stop you being *correct* about it. It only stops you being correct **by trial and error** — which was never the reliable route anyway. A CI matrix is a check on work you already have reason to believe is right. It is not a way to discover how an operating system behaves; used that way it costs a full round trip per guess and teaches you almost nothing when it goes red.

*Lived:* seven or eight attempts at one PR failed, each excusing an unverified platform claim with "the dev box is macOS, CI will tell us". The pass that worked began by reading Microsoft's ConPTY documentation and the `winconpty.cpp` source, and the answer — *closing a pseudo-console blocks until its output has been read out of the pipe* — made the correct design obvious in one step. It had been documented the whole time.

---

## 1. The source ladder

Climb until something *states* the answer. Stop guessing the moment it does. Record which rung you got it from — a claim without its source is not yet a finding.

1. **The specification or man page.** POSIX, ECMA-48, an RFC, the vendor's API docs. This is what the thing promises, and it is the only rung that binds every implementation.
2. **The dependency's actual source**, on this disk, at the version in the lockfile. Not its README, not its docs, not your memory of it. Vendored crates and packages are already local; open the file.
3. **The reference implementation's source** — with care. It tells you what *one* program does, which may itself diverge from the spec.
4. **A probe you wrote and ran.** For anything the first three leave open, or anything you want to see with your own eyes.

Two failure modes worth naming:

**Popularity is not evidence.** A widely used, battle-tested implementation can be wrong for your purpose, and sometimes wrong against the spec. When a reference and the specification disagree, the specification wins and the reference gets re-checked against it.

**Matching a reference's code is not correctness.** The same code produces a different result under a different model. Before borrowing any behaviour: state what the reference does; state the assumption that makes it correct *there*; check whether that assumption holds *here*; if it does not, discard the borrowed mechanism and derive the answer from your own model plus the spec. "Matches how X does it" is not a justification. "Correct here because of these invariants, and it matches the spec's stated behaviour" is.

---

## 2. Write the probe

When no document settles it, do not reason harder. Print what actually happens.

A probe is small, throwaway, and beats any amount of argument. It usually takes a minute.

**A probe needs a control.** Build it so its two outcomes point at *different causes*. A check that can only confirm what you already believe proves nothing, however green it comes back.

*Lived:* every test for "a descendant keeps the terminal open after the child exits" used `sleep 30 & exit`. The assumption was that the descendant survives. A probe showed it does **not** — the session leader exiting sends a hangup to the foreground process group and kills it. Those tests had been passing through an ordinary end-of-input path and had never once exercised the mechanism they were named after. Only `trap '' HUP; sleep 30 &` actually survives. No amount of thinking would have surfaced that.

Delete probes when done, or promote them to real tests with names that say what they pin.

---

## 3. Stop patching. The model is wrong

The most expensive failure shape there is, because every step feels like progress.

**A second valid finding in the same subsystem means the abstraction is wrong.** One finding is a bug. Two is a signal. Stop fixing the case in front of you and ask what is mis-modelled, because patching cells regenerates the bugs somewhere else and burns a review round each time.

The smell you can catch yourself on: *"another special case at another transition."*

**Two contradictory findings prove the model must be two parts.** If review demands both "X must happen" and "X must not happen", do not pick a side and do not oscillate — the contradiction is proof that one mechanism cannot serve both, and two parts are needed, each serving one requirement.

**Verify the model *before* the first line, not after the second finding.** Name what the model must represent; check it against the observable specification (what a user or a client actually sees), not against the code's own stated invariants; enumerate the full state space and confirm every state yields the right observable result. An audit that takes the design as ground truth inherits the design's blind spot and cannot find a design bug — which is exactly why repeated self-audits can pass while a reviewer keeps landing hits.

**"No findings yet" is not evidence the model is right.** Neither is a green suite.

*Lived:* eight review findings across seven attempts, each fixed in isolation, each followed by a sworn-complete re-audit. All eight were one flaw: a thing was being *guessed from a clock* that could be *proven from state*. Once the model changed, the entire class disappeared and nothing further was flagged.

---

## 4. Fix the layer that is wrong, not the layer that reported it

A failing test, a red job, or a review comment gives you a **symptom** and a **location**. Neither is the cause. Fixing below a broken layer is worse than not fixing: it looks like progress, it costs a round, and the bug returns.

Before changing a line:

1. **Read the raw output.** The exact bytes, the exact assertion, the exact values — not the summary, not your reconstruction of it. Reasoning about what "probably" failed is how you fix the wrong layer.
2. **Go up, not down.** Ask "could the layer feeding this be wrong?" before "what did I get wrong here?" The reported location becomes a suspect only once everything upstream is proven right.
3. **Split the space with a control** — one experiment whose two outcomes indict different layers. Run it.
4. **Then fix**, at the layer the control indicted, and say which layer it was.

*Lived:* a Windows-only CI hang. Three rounds went into the code at the reported location; all three were wrong. The raw log contained `Output([27, 91, 54, 110])` — that is `ESC[6n`, a cursor-position query. Nothing answered it, so the child never started, so nothing ever exited. The defect was two layers up in the test harness and the product code had never been broken. What settled it was running the same child through a *different* route: it failed there too, which cleared the suspect code in one run. That control should have been the first move, not the fourth.

---

## 5. Green proves nothing about what the tests still watch

A passing suite proves nothing broke **that a test watches**. It says nothing about whether the tests still watch it.

After changing shared state or an invariant, run a **mutation sweep**: break each guarantee on purpose, confirm a specific test goes red, restore it. A guarantee that survives its own removal is unguarded, whatever the suite total says.

*Lived:* a suite green at 3287 tests. The sweep found a test whose premise had silently stopped testing anything — it pre-set a flag to simulate a busy reader, and the rewritten code ignores a pre-set flag by design. Green had been hiding a dead test.

Related: **assert the exact expected value.** A pattern match, a length check, or "is not empty" still passes when the result is wrong.

---

## 6. Audit your own fix as an opponent would

Before handing over anything non-trivial, attack it — deliberately, as a separate act from writing it, with the goal of *refuting* it rather than confirming it. The mindset that wrote the code cannot find the code's blind spot; that is what a reviewer keeps proving.

Ask specifically:

- What **outlives** this? Which threads, processes, handles, connections are still alive when this finishes, and what do they now receive?
- Which **existing consumers** read state I changed, and how do they behave in the states my change newly makes reachable? (Not "new feature versus old states" — also "every old feature versus the new state".)
- What does a **public contract** legally permit that this cannot survive? "Our only caller doesn't do that" is not an answer; the contract is the API, not the current caller.
- What happens on the **platform I am not sitting on**?

If this pass produces findings, they are real findings — treat them exactly like a reviewer's, including the rule in section 3 about the second one.

*Lived:* a fix for a Windows CI failure was adversarially audited before being offered, and produced seven findings against itself — enough to force a remodel rather than a patch. The remodel was what finally passed.

---

## 7. What "done" means here

- Every behaviour claim traceable to a rung of the ladder — name which one.
- Model verified against the observable specification, across the whole state space, not just the case in hand.
- Diagnosis anchored at a layer a control indicted, not at a layer that reported.
- Guarantees proven watched by a mutation sweep, not assumed watched by a green total.
- Residual risk stated plainly — what could not be executed here, and what would prove it.

**Never report "all good".** Report the axes checked, what each was checked against, and what remains unverified. A caveat named honestly is worth more than a confident summary, and it is the difference between "this passed" and "this is right".

## Anti-patterns

Banned as conclusions, every one of them a guess wearing a suit:

- "Should be fine" · "presumably" · "I believe" · "this is standard behaviour"
- "Matches how *X* does it" · "it's battle-tested, so it's correct"
- "Can't check that on this machine — CI will catch it"
- "Tests pass, so it's correct"
- "Fixed the reported line" (without proving the layers above it)
- Another special case at another transition, for the second time in one subsystem
