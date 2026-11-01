---
name: improve
description: /improve - improve how this repo is worked on, not what the product does - its docs and their structure, the skills, the internal tools in .tool/, the harness (settings, permissions, hooks), and the cost in tokens and time of working here. Measure first, change, verify for real, and leave a short report with references in product/improvements/. Use when asked to "improve", tidy, restructure, speed up, make cheaper, or fix the way we work; not for product features (/create) or open-ended research (/research).
---

# Improve: evidence → change → verified → reported

`/research` studies a problem and `/create` ships a feature. `/improve` is
for everything around them: where documents live, how skills read, which
tools exist, what the harness allows, and what a session costs. It runs
often and should stay small. The test for every change is whether it makes
the next session faster, cheaper or less confusing, for the user and for
the agent.

Worked example, in the sibling Lunna repo: `../lunna/product/improvements/2026-10-17-docs-tooling-tokens/`.

**Unattended** (`APP_QUEUE=1`, a run of `.tool/queue` for a GitHub
issue): nobody answers until the run ends. The queue's instructions in the
prompt replace every "stop and ask" here; the person answers on the issue,
and the next phase is a fresh session that starts from the files.

## 1. Find the evidence before proposing

Don't recommend from intuition. Every claim of "this costs too much" or
"this is confusing" gets a number or a `file:line`.

- **The repo:** list what the request touches and `grep` for every
  reference to it (paths, skill names, commands) across the repo, the
  skills, `AGENTS.md`, the READMEs and the memory directory. This list is
  the checklist for step 3.
- **Cost of working:** `.tool/cost --list` and `.tool/cost <session>` give
  turns, context, tokens and USD per message. For *why*, attribute the
  input tokens to their causes (each turn's growth in context, times the
  turns that re-read it). The worked example's `code/attribute.mjs` does
  this. Tokens in ≈ turns × context, so the levers are fewer turns and
  smaller context. Reading less code is a smaller lever than it seems.
- **Tools and checks:** run them and read what they print. A tool that
  prints a wall of text costs every later turn.
- When a measurement contradicts something said earlier in the session,
  say so plainly and use the measured figure.

## 2. Ask only the real forks

Use AskUserQuestion, recommended option first, for choices that are the
user's: what to delete, whether to commit, a trade-off between cost and
visibility (a subagent, a split session). Batch them in one call. Don't
ask what the repo or the request already answers. If the user offers a
skill ("use /research if necessary"), use it only when the evidence needs
literature; data from the repo usually doesn't.

## 3. Change

- **Move with `git mv`** (`mv` for untracked files), then fix every
  reference from step 1, the memory files included. End with a grep that
  finds none of the old paths. Historical records (a delivery's verbatim
  prompt) keep the words they were written with.
- **Tools go in `.tool/`**: one call per routine step, printing only what
  matters (paths, ✓/✗, the lines of a failure, a table). Node ≥ 22 or
  bash, no dependencies. A short `#!/bin/sh` shim when the tool is Node.
  Document each one in `.tool/README.md`, and allow it in
  `.claude/settings.json`.
- **Docs go in `product/`**: one folder per topic or per piece of work,
  `README.md` first, then `data/`, `code/` and `img/` beside it.
  `AGENTS.md` is in every session's context: keep in it only what most
  tasks need, and move feature detail to `product/spec/` behind a short
  pointer.
- **Skills** (`.claude/skills/<name>/SKILL.md`): when a change alters how
  a skill works, edit the skill in the same pass, its `description` too
  (that's what triggers it). A rule in a skill says why, briefly.
- Write files with Write and Edit, not long edit scripts in Bash: the
  script repeats the code it changes, and all of it stays in context.

## 4. Verify for real

Run every tool you wrote or changed end to end on real inputs, not just a
syntax check, and run what it wraps (builds, tests) once. First runs find
bugs: concurrent builds colliding, a glob expanded in the wrong directory,
a failure that printed no reason. Fix those, re-run once, and report them.
If something can't be verified here (a browser click, a future session),
say so.

## 5. Report

Write `product/improvements/<YYYY-MM-DD>-<slug>/README.md`, short, with
whatever it cites in `data/` (measurements) and `code/` (the scripts that
produced them, runnable again). Sections:

1. **The request**: the user's messages, verbatim, and the answers they
   gave to questions.
2. **What changed**: a table, `Area | Before | After`, then any detail a
   future reader needs (a new tool's commands, a new folder layout).
3. **Evidence**: the numbers behind the changes, each with the script or
   command that produced it, and any earlier claim the numbers corrected.
4. **Verified**: what was run and what it printed (✓/✗ in a line each),
   bugs found on the way, and what wasn't verified.
5. **Not done**: proposals the user declined or deferred, one line each,
   so the next `/improve` can pick them up.
6. **References**: the files changed (paths), the external sources (links,
   one line each on what they support), and related reports in
   `product/`.
7. **Cost and time**: `.tool/cost` for the session (pass `--usd` from
   `mcp__usage-bars__session_cost` while it runs).

Add it to nothing else: `.tool/doc ls improvements` lists them all. Then
end with a few lines to the user: what changed, what was verified, what
was not done, the report path, and open the report with `.tool/doc open
<slug>` in the background. Don't commit unless asked.
