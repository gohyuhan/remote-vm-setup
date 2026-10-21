---
name: optimize-code
description: >-
  Make existing code do the same work with less: fewer CPU cycles, less memory,
  less allocation, fewer round trips, and less indirection. Use for optimization,
  speed, memory, allocation, latency, hot-path overhead, binary or bundle size,
  or overly indirect flows. Behavior-preserving by definition: changed output is
  a bug, not an optimization. Language- and framework-agnostic.
---

# Optimize Code

One question: **does this code produce the same result with less time, less memory, and a shorter path to follow?**

Behavior is frozen. An optimization that changes an observable result is a bug. Correctness comes first — if the logic is wrong, fix it with `implementation-audit`, not here.

## When to use

- "Optimize / speed this up / make it faster"
- "Too much memory / too many allocations / it leaks"
- "This flow jumps around too much" — indirection, layer hops, call-chain depth
- "Cut the latency / reduce the round trips"
- "The binary / bundle / image is too big"

## Core stance

- **Measure before you cut.** The bottleneck is almost never where it feels. Profile, time, count allocations, count queries — then optimize what the numbers name. No numbers = a guess. Say so if you can't measure.
- **One run is not a number.** A single timing measures noise as much as code. Repeat, report the median, warm up first, and only believe a win larger than the run-to-run spread.
- **Free wins before clever wins.** A release build, a compiler flag, a right-sized pool cost zero readability. Take those before editing a single line.
- **Big-O before constants.** An O(n²) scan rewritten to O(n) beats any micro-tweak. Do the algorithm first; only then touch constants.
- **Hot path only.** Code that runs once at startup is not worth making unreadable. Optimize what runs per-request, per-frame, per-item, per-key.
- **Readability is a real cost.** Trade it only for a measured win, and leave a comment naming the win.
- **Don't optimize what you can delete.** The fastest work is work not done — check for dead paths and redundant calls first.

## Do NOT optimize

Leave these alone even when they look wasteful — the "waste" is the point.

- **Input validation at a trust boundary.** Removing a check is not a speedup, it is a hole.
- **Constant-time comparison** of secrets, tokens, signatures, password hashes. Early exit is faster and leaks the secret.
- **Error handling and cleanup paths.** A path that runs rarely still has to run correctly.
- **Retries, timeouts, backoff.** They exist because the happy path is not the only path.
- **Cold code** — startup, config parsing, CLI arg handling, one-shot migrations. Nobody is waiting on it.
- **Anything you can neither measure nor reason about.** Say it is unmeasurable and stop; do not guess.

## Procedure

### 0. Scope + baseline

1. Name the target: the function, endpoint, loop, or flow. Name the metric that matters — wall time, p99 latency, peak RSS, allocations/op, query count, cache misses, binary/bundle size.
2. Take a **baseline number** for that metric (benchmark, profiler, timer, query log, `time`, `/usr/bin/time -l`, `hyperfine`). Record it — the final report compares against it.
3. **Measure it honestly**, or the number is a story: at least 5 runs, take the **median** (not the best, not the mean); discard the first run as warm-up unless startup *is* the metric; keep the machine otherwise idle; identical input data every run; change one thing per measurement.
4. Take a **behavior baseline**: the tests covering this code, or the exact input → exact output you will re-check after. Without one you cannot prove the optimization kept behavior.

If no metric can be measured in this environment, say so plainly and restrict yourself to changes that are unambiguous wins (see below).

### 1. Free wins — configuration, not code

Zero readability cost, often the biggest single jump. Check before editing anything.

- **Measuring a debug build?** Switch to release/optimized first. A debug build can be 10×+ slower; an "optimization" measured against it is measuring the flag.
- Compiler/linker settings the project supports but has not enabled: optimization level, link-time optimization, dead-code stripping, symbol stripping, target-cpu.
- Bundler/packager: tree-shaking, minification, code splitting, dropping a dev build of a dependency that shipped to production.
- Runtime knobs: connection-pool size, worker/thread count, batch size, buffer size, heap/GC settings, log level on a hot path.
- Verify these like any code change. A flag can alter floating-point results or strip an assertion the code leaned on.

### 2. Delete work

Cheapest wins first — no code gets faster than code that doesn't run.

- Work whose result is discarded, recomputed, or overwritten
- Same call made twice with the same inputs in one pass → compute once, reuse
- Eager work that's only sometimes needed → do it lazily, at the branch that needs it
- Validation/lookups repeated at every layer of a call chain that already validated upstream
- Dead branches, unused fields carried around, logging/serialization on a hot path that nobody reads
- Per-item work that doesn't depend on the item → hoist it out of the loop

### 3. Algorithm & data structure

- **Complexity:** nested loop over the same collection (O(n²)) → hash/index lookup (O(n)). Linear scan in a loop → build the map once outside it.
- **Right container:** membership checks → set, not list. Keyed lookup → map, not scan. Ordered scan → sorted/indexed structure. Frequent append+pop at both ends → deque, not array shift.
- **Batch:** N calls in a loop (DB query, HTTP request, file read, syscall, IPC message) → one batched call. This is usually the single biggest win in real systems (the "N+1" pattern).
- **Do less of it:** filter/limit/project at the source (DB, API, file) instead of fetching everything and discarding in code.
- **Precompute** what's stable; **cache** what's expensive, pure, and repeatedly asked for — with a bounded size and a clear invalidation rule. An unbounded cache is a memory leak.
- **Missing index:** a query that is slow only at scale is usually a missing index, not slow code. Read the query plan before rewriting the code around it.

### 4. Memory, allocation & layout

- Allocation in a loop → allocate once outside, reuse the buffer; size collections up front when the count is known.
- Copies that could be references/borrows/views — but never at the cost of a lifetime or aliasing bug.
- Whole file/response loaded into memory → stream/iterate it, when the consumer is sequential anyway.
- Growth that never shrinks: caches, maps keyed by a growing id, subscriptions/listeners/handles never released, retained closures. Every acquire has a matching release on **every** path, including errors.
- Cheap conversions that aren't: repeated string concat in a loop → one builder/join. Repeated serialize/deserialize across a boundary → pass the structure.
- **Layout, for data scanned in bulk:** memory the CPU walks in order is far faster than memory it chases pointers through. A contiguous array of values beats an array of pointers to values. If a loop reads 2 fields of a 20-field record, the other 18 are still dragged through cache — split hot fields from cold, or scan parallel arrays of just the hot ones. Only at real volume, only with a measured win.
- **Right-sized types where stored in bulk:** a million records each carrying a 64-bit counter that never exceeds 1000 wastes both RAM and memory bandwidth.

### 5. Flow shape — less jumping around

Fewer hops is both faster (fewer frames, better locality, better inlining) and cheaper for a human to follow.

- Indirection with one implementation and no second caller: collapse it.
- A value threaded through five layers untouched: pass it where it's used, or move the work to where the data is.
- Ping-pong between modules/services to assemble one result: fetch once, assemble once.
- Deep nesting → early return.
- Chatty boundaries (many small calls across process/network/lock) → one coarse call. Crossing a boundary is orders of magnitude more expensive than a local call.

### 6. Concurrency & I/O — only when it's the actual bottleneck

- Independent sequential I/O → run concurrently (join/gather/parallel). Dependent work stays sequential.
- Blocking call on an async/event/UI thread → move it off.
- Lock held across I/O or across the whole function → narrow it to the shared state. A coarse lock is a throughput ceiling.
- Never add concurrency to CPU-trivial work — the coordination costs more than the work.
- Concurrency added for speed must not add a race. If you cannot show the shared state is safe, it is not an optimization, it is an intermittent bug.

### 7. Verify — no optimization is done without this

1. **Behavior identical:** run the behavior baseline from step 0. Same output, same errors, same edge cases. A change here means revert or fix.
2. **Number improved:** re-measure the same metric the same way — same run count, same median. State before → after. **If it didn't improve past the run-to-run spread, revert it** — you paid readability for nothing.
3. **Memory claims need a memory tool.** "Fewer allocations" / "no leak" is proven by an allocation profiler, leak detector, sanitizer, or peak RSS over a long run — never by reading the diff.
4. Gates green: build, tests, lint (whatever the repo runs).
5. **Leave a guard behind** for any win worth keeping: a benchmark, a query-count assertion, a size budget. An unguarded optimization is silently undone by the next change.

## Report format

```
[target] file:line — what was slow
  Before: <measured number> · After: <measured number> (<x%/×>)
  Measured: <tool, run count, median>
  Change: <what you did, one line>
  Behavior: <how you proved it's unchanged>
```

Then, briefly:
- **Not done, and why** — wins that need a design change, or aren't worth the readability cost
- **Unmeasured** — anything you changed without a number, called out honestly
- **Guards** — benchmarks/budgets left behind, or "none" and why

## Checklist

- [ ] Metric named; baseline number recorded (or "unmeasurable" stated)
- [ ] Baseline is a median of repeated runs, warm-up run discarded
- [ ] Behavior baseline recorded before touching anything
- [ ] Free wins checked first — release build, compiler/bundler flags, runtime knobs
- [ ] Deletable work removed before anything was rewritten
- [ ] Complexity/data structure/batching/indexes checked before micro-tweaks
- [ ] Allocation, growth, release-on-every-path, and bulk layout checked
- [ ] Hot path only — startup/cold code left readable
- [ ] Nothing on the "Do NOT optimize" list was touched
- [ ] Every change re-measured; non-improvements and noise-level "wins" reverted
- [ ] Memory claims backed by a memory tool, not by reading the diff
- [ ] Behavior proven unchanged; gates green
- [ ] Guard (benchmark/budget/assertion) left behind, or its absence explained
- [ ] Report states before → after numbers, not adjectives
