# Plan: a new app for cents

Status: **plan, not built.** Every app starts from this template, so the
only Claude spend left is (1) giving it its look, (2) each feature, and
(3) the session overhead every run pays. This plan cuts all three, and
keeps the design review as images.

## Where the tokens go

- **Output costs 5x input.** Anything Claude writes and then throws away
  (an HTML mockup, a long edit script) is the costliest thing in a session.
- **Every turn re-reads the whole context** (cache reads at 0.1x). So
  the number of turns, and how big the context has grown when they happen,
  counts for more than any one file read.
- **Images are cheap when they're small.** A shot costs about
  `width × height / 750` tokens: 390×844 ≈ 440, the same shot at 2x ≈ 1.8k.
  One strip at 1x is cheaper than four 2x shots.
- **Prompts for permission don't cost tokens, but they cost wall-clock
  time** and stall the queue.

## 1. `/design-system`: show the real app, stop drawing HTML (the big one)

**Today.** Step 2 has Claude hand-write an HTML page: swatches, the type
scale, a mocked sign-in, home and assistant, the mark. That's thousands of
output tokens of throwaway markup. Step 3 then writes the same look again
in Dart, and the contrast numbers get worked out in Claude's head. So you
pay for the look twice, and the proposal can drift from what ships.

**Change.** The proposal *is* the apply step, shown by the real app:

1. Commit `app/lib/design_preview.dart` (shaped like `lib/preview.dart`)
   with fixed scenes:
   1. sign-in, 2. home empty state, 3. assistant mid-conversation,
   4. **token sheet**: each `AppColors` swatch with its name and hex, the
      contrast ratios worked out in Dart (`Color.computeLuminance`) and
      marked pass/fail against the skill's rules, the type scale, radii,
      button/field/bubble, and the mark at 29 pt on light and dark,
   5. **directions** (first round only): 3 candidate looks side by side,
      each a card with palette chips, a heading in its face, a primary
      button and a field. They come from 3 `const` specs in the preview
      file, so `AppColors` is untouched until a direction is picked.
2. Round 1: a one-question interview (with "just pick from the app's
   description" as an option), write the 3 specs (~60 lines),
   `.tool/preview design 5`, send the picture. The person picks A/B/C.
3. Round 2: edit the five token files for real (`app_colors`,
   `app_typography`, `app_spacing`, `app_brand`, `app_theme`: 293 lines in
   all, the edit is ~40), plus the three brand SVGs, then
   `.tool/preview design 1 2 3 4` and send the strip. Feedback is
   one-liners against the picture; re-shoot only the scenes that changed.
   If they reject it, `git checkout app/` and nothing is lost.
4. On approval: icons, splash and web colours (deterministic commands that
   already exist), then `.tool/check`. No separate "apply" step left.

The skill drops the HTML page and the hand-done contrast maths, and reads
only `strip.png` at 1x, never every shot.

**Target:** one look, start to finish, in ≤ 2 picture rounds and well under
$1. Measured with `.tool/cost`, not assumed.

## 2. Bootstrap a new app with no model at all

`scripts/rename.mjs`, `gh_setup.sh`, `pi_setup.sh` and
`cloudflare_add_domain.sh` are already deterministic, but "the setup CLI
has Claude run it". Wrap them in one `scripts/new_app.sh <slug> <label>`
the person runs themselves. Claude's first spend on a new app is then
`/design-system`.

## 3. Ship less context in every session

- **Drop the four generic vendored skills** (`advanced-evaluation`,
  `context-degradation`, `evaluation`, `tool-design`, ~230 KB). They have
  nothing to do with building an app, their descriptions sit in every
  session's skill list, and every new app inherits them. Move them to
  `~/.claude/skills` if you want them yourself.
- **Split `/create`** (19 KB ≈ 5k tokens, loaded whole): the design
  session doesn't need Phases 3–4 and the build session doesn't need
  Phases 1–2. Keep Phase 0, Speed and Cost in `SKILL.md`; move each half to
  `design.md` / `build.md`, read only by its own phase.
- **The `../lunna/...` links** (5 in the skills) point at a sibling repo
  that a new app's machine may not have, and a failed lookup costs a turn.
  Mark them optional or copy the one worked example in.

## 4. Use the cheaper model where the thinking is done

| Work | Model | Why |
|---|---|---|
| Design rounds, research, plan-track plans | Opus | taste and trade-offs |
| `/create build` from an approved Build brief, `.tool/check` fixes | Sonnet | the decisions are already written down |
| Cleanup, cost tables, renames | a script, or Haiku | mechanical |

In `.tool/queue.mjs`, pass `--model` (and an effort level) per phase when
it spawns `claude -p`, so unattended builds don't run on the priciest
model by default.

## 5. Stop the permission prompts

Add to `.claude/settings.json` allow: `Bash(.tool/preview:*)`,
`Bash(.tool/check:*)`, `Bash(.tool/cost:*)`, `Bash(.tool/doc:*)`,
`Bash(node .tool/mockup/board.mjs:*)`. This saves time (and the queue's stalls), not tokens.

## 6. Habits that cost nothing to adopt

- `/clear` between tasks; the `/create` hand-off already does this.
- Send all your feedback on a board in one message, by pin letter
  ("B: icon smaller, D: drop it"). Every message re-reads the context.
- No UI to draw means the plan track: no prints.

## Order and proof

1. Section 3 (delete skills, split `/create`) and section 5: an hour,
   zero risk.
2. Section 1: `design_preview.dart` + the rewritten skill; the biggest
   saving.
3. Sections 2 and 4.

Before you start, run `.tool/cost` on one `/design-system` run and one
small `/create` the way they work today, to get a baseline. Run the same
two after, and put both tables here.
