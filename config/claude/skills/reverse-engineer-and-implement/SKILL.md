---
name: reverse-engineer-and-implement
description: Study a feature or effect in another app, website, or binary with REA, then build the same behavior in the current project.
disable-model-invocation: true
argument-hint: "<target: URL, app, or file> <feature or effect to copy>"
---

# Reverse engineer and implement

This is a clean-room rebuild. REA turns the target into a behavior spec, and the project gets its own implementation of that spec.

## 1. Pin the brief

Name three things from the arguments and the conversation:

- **Target**: a URL, an installed app, or a local file (ASAR, APK, binary, HAR capture).
- **Feature**: what a user observes, in concrete terms. Example: "the header shrinks from 64 px to 40 px after 80 px of scroll, with a 200 ms ease-out".
- **Destination**: the project, and the area of it that gets the feature.

If one of the three is missing, ask once. The step is done when all three have a concrete value.

## 2. Gate the network

REA's skill says that its tools need no per-call approval. That holds for local targets only: an installed app, a local file, or a page on `localhost`.

Before a REA call or command loads a remote URL, drives a live page, fetches source maps, or downloads a tool or artifact, state the exact URL and action. Then wait for the user's explicit yes. Each such call needs its own yes.

## 3. Investigate with REA

Load the `reverse-engineer-anything` skill and follow it. Turn the feature into a checklist of questions:

- the trigger, and every input that starts the feature
- every state, and every transition between states
- exact values: durations, easing curves, thresholds, sizes, key codes, colors
- the data flow from the trigger to the result
- edge cases: empty data, errors, resize, rapid repeated input, focus loss, the reduced-motion setting
- the libraries and platform APIs that the target uses

The step is done when every question is marked answered, partial, or unresolved, and each answer cites its REA Evidence IDs.

## 4. Write the behavior spec

Show the spec in chat as one table with these columns: behavior, exact value, evidence type (observed, inferred, or unknown), and Evidence ID. The spec holds behavior only, never the target's source code.

Check the target's license. If the license permits reuse and the user approves, a direct port with attribution is an option. In all other cases, the spec is the only input to the build.

## 5. Plan the build in the destination

Map each spec row to the destination code that already serves it, and reuse that code. Present the plan, with one recommendation for each design choice, and wait for approval. The project's own task workflow overrides the order of this step and the next one.

## 6. Build and prove

Implement the plan in the project's own idioms. Give each spec row a test or an observable check. For a visual effect on a local page, use REA's screenshot and capture tools to compare the build against the spec values.

The step is done when every spec row has a passing check, or the user accepts the row as unresolved.

## 7. Report

Give one line per spec row: where the row lives in the project, and the check that proves it. Then list two things separately:

- the design choices that the evidence did not decide
- the unresolved rows, and their effect on the user
