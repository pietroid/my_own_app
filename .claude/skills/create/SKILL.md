---
description: /create - take a feature for My Own App from idea to delivery, fast - first pick the track: a UI change gets an annotated mockup drawn by the real Flutter app, with PNG prints; a change with nothing to draw (release tooling like Shorebird, CI, deploy, server-only rules, a migration) gets a one-page plan instead. Iterate on feedback, then, once approved, build it (`/create build <slug>`, a fresh session after a mockup) in the server and app, prove it (prints of the real build, or the commands that show it working), and record everything in a product/delivery/ folder. Use when asked for a design proposal, a mockup, "prints", "how would X look", to build a feature or a piece of tooling, or to implement an approved RFC from product/research/.
---

# Create: proposal → delivery

The flow has four phases. Stop after each phase, send what it produced,
and only go on when the user asks. Phases 1–2 (design) should be fast.
Phases 3–4 (build) are real engineering, and Phase 4 always closes a build.

## Phase 0: Pick the track

The design is only as heavy as what the person will see. Decide before
reading any widget, and say which track in the first message:

| Track | When | Phases 1–2 produce |
|-------|------|--------------------|
| **Mockup** | the feature changes what the person sees or does: a screen, a sheet, a card, a gesture, copy | a board drawn by the real app (Phase 1 below) |
| **Plan** | nothing to draw: release and build tooling (Shorebird code push, flavors, signing), CI, deploy, server-only rules, a migration, performance, a dependency bump | a one-page plan in the delivery README (Phase 1P below), no preview entry point, no board |

A plan-track feature with a small UI touch (an "update available" banner)
stays a plan: the plan names the widget and its copy, and Phase 4 shoots
it. Switch to a mockup only when there's a layout decision to approve.
A design session costs ~$3 and ~17 minutes (six deliveries, see
`../lunna/product/improvements/2026-10-21-skill-flow/`), all of it spent on prints;
for a feature with no screen those prints show nothing.

**From an RFC.** When the request points at an RFC in `product/research/`
(an `Implement: …` issue does), the RFC is the research: read its first
slide (or *Thesis* / *In one minute* in older ones), its change slides,
*Decisions* (*Decisions for you*) with the notes under them, and *Impact*
or *Rollout*, and nothing it already cites (`.tool/doc shape` lists the
headlines). A `> **Decision**` note is binding;
any other decision takes the option marked *(recommended)*. Pick the track
by what the RFC's first rollout phases change, and say in the plan or the
board which phases this delivery ships (Phase 0, the measuring, first).
Section 1 of the delivery links the RFC.

**The mockup's design session ends at approval.** When the user approves the
design ("great, now make the changes", "build it"), don't build in that
session: write the hand-off (end of Phase 2) and tell the user to run
`/clear` and then `/create build <slug>`. Every turn re-reads the whole
conversation, so a build that starts at ~55k of context instead of the
~150k the design left behind costs a third less. The draft delivery README
carries everything across. **A plan doesn't split**: its session never
grows past the reading, so on approval go straight on to Phase 3 in it.

`/create build <slug>` (or "build <slug>" in the arguments) starts at Phase 3,
from `product/delivery/*-<slug>/README.md`.

**Unattended** (`APP_QUEUE=1`, a run of `.tool/queue` for a GitHub
issue): nobody answers until the run ends. The queue's instructions in the
prompt replace every "stop and ask" here; the person answers on the issue,
and the next phase is a fresh session that starts from the files.

Worked example of the whole flow, in the sibling Lunna repo: `../lunna/product/delivery/2026-10-15-agent/README.md`.
The tools this skill runs are in `.tool/` (see `.tool/README.md`): `preview`,
`check`, `cost`, `doc`.

## Speed

Aim for the least wall-clock time and the fewest tokens that still give the
same quality. Every round trip and every re-read costs both.

- **Act on what you know.** The paths, tokens, commands and patterns are in
  this file and in `AGENTS.md` (already in context): go straight to them.
  No exploratory listing or searching for what is written here.
- **Batch.** Independent reads, edits and commands go in one message, in
  parallel. Read several files in one call; read only the lines you need.
- **Never re-read** a file you just wrote or edited, or one already in the
  conversation. Don't re-run a passing check to "make sure".
- **One call per routine step.** `.tool/preview` builds, shoots and lays
  out the board; `.tool/check` runs CI's checks on what changed and prints
  only failures. Never run their pieces by hand, and never read a log they
  didn't point at.
- **Run long things in the background** (`.tool/preview`, `.tool/check`)
  and write the next thing (specs, `board.json`, the README) meanwhile.
- **Verify narrowly first, broadly once.** While iterating, run the one spec
  or package you touched (`flutter test -r failures-only <file>`); the
  full `.tool/check` once, at the end.
- **Write with Edit or Write**, not long edit scripts in Bash: a script
  repeats the code it replaces, and it all stays in context.
- **No subagents** unless the user asks: they start cold and re-read
  everything.
- **Short messages.** Progress lines while working, one compact report at the
  end of a phase. Don't narrate options you won't take.
- **One fix pass.** Render, look, fix everything you saw in one go,
  re-render once. Don't polish what the user hasn't seen yet.
- **Look at the strip, not every shot.** One `strip.png` shows every
  scene; open a single shot only to place pins.

Quality is not negotiable: the pins still state every decision, the specs
still cover the rules, every touched package is still checked.

## Cost and time

Every delivery records what it cost, in dollars and tokens, and how long it
took, from the session transcript: `.tool/cost` prints a Markdown table with
one row per user message (when, how long, turns, peak context, tokens in
with the cache reads, tokens out with the thinking, USD) and the totals. It
costs one call and needs no readings along the way.

- USD comes from the transcript once the session has ended. While it runs,
  pass the running total: call `mcp__usage-bars__session_cost` and run
  `.tool/cost --usd <usd>`. Without either, the USD column is a dash; say so.
- Run it at the end of each session: at the hand-off for the design session
  (into the draft README), at the end of Phase 4 for the build session.
  `.tool/cost --list` finds an earlier session's id.
- In the README, merge rows into phases if that reads better, keep the
  totals, and add the two sessions together. The figures include the talk
  around the work, and wall-clock time includes the user's pauses; say so.

## Phase 1: Mockup and prints (mockup track)

**The mockup is always drawn by the real Flutter app**, never by HTML or an
image editor: the same widgets, tokens, fonts and icons the build will ship,
so the proposal can't drift from the product and Phase 3 starts from the
widgets Phase 1 already wrote.

A proposal is a **board of 3–5 phone screens** telling one flow left to right,
each with a title, a one-line why, and **lettered pins** (A, B, C…) that point
at the decisions: where a button sits, which icon, what colour, what it does,
when it goes away. The pins are the point. The user wants placement and icon
decisions stated, not just pretty screens.

1. **Ground it in the app** (2 min max).
   - Widgets: `app/packages/app_ui/lib/src/widgets/`, tokens in `app_colors.dart`, icons in `app_icons.dart` (Phosphor). Reuse before writing anything new; a widget two screens need goes into `app_ui`.
   - Screens that exist: `lib/home/` (the home), `lib/assistant/` (the conversation), and every feature package under `app/packages/`. `lib/preview.dart` draws them against fakes.
2. **References.** Name 2–3 apps whose pattern you're borrowing (Mobbin-style catalogue: ChatGPT, Notion, Motion, Structured, Sunsama, Linear, Arc…). Mobbin needs a login. If Chrome tools are connected and signed in, browse it. Otherwise say you drew from known patterns and don't pretend you browsed.
3. **Write the screens in Flutter.**
   - New UI is real widgets where it will live (the feature's package under `app/packages/`, or the package it changes), built from `app_ui` and tokens, every string in `app_pt.arb` (`flutter gen-l10n`). This is the start of Phase 3's view layer, so write it to that standard, not as a sketch.
   - No server yet. The data comes from fakes in the preview entry point.
   - Entry point `app/lib/<slug>_preview.dart`, shaped like `lib/preview.dart` (`AppTheme.current`, pt-BR l10n, a signed-in `AppBloc`, fake repositories with canned replies). `?s=<n>` (`Uri.base.queryParameters`) picks the scene: each scene seeds its state directly (a cubit built with that state, a sheet opened in a post-frame callback) rather than replaying taps.
   - Copy is in **Brazilian Portuguese**, mocked but believable: real-sounding tasks, hours that add up.
   - Accent on one primary action per screen.
   - **No generic AI iconography.** No sparkles, magic wands or robots. The assistant is `AppIcons.assistant`. Anything new gets a brand-derived or Phosphor icon, named in a pin; a new brand icon is an SVG in `app/brand/` on the 64-unit grid, wired through `AppIcons`.
4. **Build and shoot.**
   - `.tool/preview <slug> 1 2 3 4 --out <scratchpad>/design` (background, about a minute) builds the app and shoots each scene: `<out>/shots/<n>.png` and `strip.png`. Write `board.json` while it runs.
   - `board.json` (in the scratchpad) lists each screen's `png`, `title`, `why` and `pins` (`id`, `x`, `y` in logical px on the 390×844 shot, the pin's centre; `label`, `text`). Read the shots to place the pins.
   - `node .tool/mockup/board.mjs <board.json> <out>/board` writes `board.png` and `screen1..n.png` (2x), with the pins and their notes. On later rounds, `.tool/preview … --board <board.json>` does all three in one call.
5. **Look at the prints** (Read `board.png`) before sending: overflow stripes, grey boxes (a build exception), pins off their target or over text, clipped text. Fix and re-shoot once.
6. **Send** the absolute paths of `board.png` and each screen, a short list of the decisions (entry point, icon, placement, the main rule of the flow), and any open questions. The preview entry point and the new widgets stay uncommitted; if the proposal is dropped, delete them.

## Phase 1P: The plan (plan track)

Instead of Phase 1. Write the draft
`product/delivery/<YYYY-MM-DD>-<slug>/README.md` straight away, with
section 1 (the prompt) and, as section 2, **The plan**, one screen of it:

- **Approach**: what gets built and where, in 3–6 lines (the files or
  folders, a new env var, a CI job, a route).
- **References**: the docs of the exact tool and version (Shorebird's,
  the SDK's), 2–4 links, each with the one line it supports. Open them;
  a snippet is not a source.
- **Decisions**: a table, `# | Decision | Chosen | Why`, the rows a
  reviewer might want otherwise (a paid service, a new secret, a release
  channel, what's left out).
- **How it will be proved**: the commands or runs that will show it working
  (a dry-run release, a test, a log line), since there are no prints.

Then the **Build brief** (as at the end of Phase 2), and stop for approval.
Feedback changes the plan in place; on approval go on to Phase 3 in the
same session (it doesn't split).

## Phase 2: Iterate

Feedback usually arrives as one-liners ("button location, icon, etc.", "remove that ugly icon"). Change the widgets, re-run `.tool/preview` (background) with only the scenes that changed, move the pins, look, re-send. When only pins moved, re-run `board.mjs` alone. An icon that changes becomes a real asset (SVG in `app/brand/`, wired through `AppIcons`), never a stand-in.

**Hand-off, when the user approves.** Write the draft
`product/delivery/<YYYY-MM-DD>-<slug>/README.md` with sections 1 and 2 done
(below, Phase 4), the approved board in `img/mockup-board.png` and
`board.json` next to it, and a **Build brief** section that Phase 3 starts
from and Phase 4 removes:

- the preview entry point and every file Phase 1 wrote or changed
  (uncommitted, kept for the build), on the mockup track;
- what the build must do on the server and in the app, as a short list;
- the decisions taken in conversation that aren't in the pins;
- the open questions;
- the design session's `.tool/cost` table.

Then stop, and tell the user, in two lines: the README path, and
"run `/clear`, then `/create build <slug>`".

## Phase 3: Build it

Starts a new session with `/create build <slug>` (a plan goes on in its own
session, with all of this already read). Read the draft README
(`product/delivery/*-<slug>/README.md`, its Build brief first) and the files
it lists, and nothing of the design you can take from it. `AGENTS.md` is
already in context: it is the spec of how the app works, and the build must
respect it. Read also the `product/spec/<feature>.md` of any feature the
build touches.

1. **Look for prior art.** The sibling repos made from the same template (Lunna is the fullest: an agent with tools, plans and undo, a timeline, reminders, notes with links) often already have the piece. Port their approach rather than reinvent it. Read the git history of this repo for what was removed and why (`git log --stat`).
2. **Ask only real forks.** Use AskUserQuestion for decisions that are genuinely the user's (which model provider, a new container vs inside the server, a paid dependency), with a recommended option first. Don't ask what the code or `AGENTS.md` already answers.
3. **Server** (`server/src/<feature>/`, a Nest module):
   - Validate input the way `assistant/assistant.controller.ts` does: refuse, never guess, and write user-facing refusals in Portuguese.
   - Every route that reads or writes a person's data takes `SessionGuard` and `@CurrentUser()`, and scopes every query to that user's id.
   - New tables go in `db/schema.ts`; then `npm run db:generate` and commit `drizzle/`.
   - A new write route gets its row in `analytics/events.ts`.
   - Anything the user must confirm or undo keeps enough state to undo exactly.
   - New env vars go in `server/.env.example` and `SETUP.md`.
   - Specs beside the code (`*.spec.ts`), the store behind an interface with an in-memory version for them (`assistant/assistant.controller.spec.ts` builds its controller over a fake). Never depend on the machine's zone or hour.
4. **App:**
   - A new feature is its own package under `app/packages/` (copy `analysis_options.yaml` and the pubspec shape from `auth`), added to `app/pubspec.yaml`.
   - Every string goes in `app_pt.arb` (run `flutter gen-l10n`).
   - Colours come from tokens. Add a token rather than writing a literal.
   - A modal sheet is its own route: hand it the blocs and repositories it reads (`BlocProvider.value`). A grey box in a release build is a build exception, very often this.
   - Inside a `BlocBuilder` builder, read `bloc.state`; `context.select` there throws.
5. **Tooling** (release, CI, deploy): follow the vendor's docs for the exact versions in use (`app/pubspec.yaml`, `.github/workflows/`). Secrets go in GitHub Actions secrets or the env files and in `SETUP.md`, never in the tree. A step that needs a credential or an account this machine lacks is written, run as far as it goes (a dry run, `--help`, a local build), and named in section 4 as not run.
6. **Verify** with `.tool/check` (background): CI's checks on what changed,
   the server's eslint, tsc and tests, `flutter analyze`, and every touched
   package's tests, one line per step. A failure prints
   the lines that explain it and the log's path; read more of the log only
   if those aren't enough.
   - If a test is flaky, stash your tracked changes and rerun it to prove it isn't yours.

## Phase 4: Prints of the real build, and the delivery folder

1. **Screenshot the finished build** when it changed what the person sees (always on the mockup track; on the plan track only for its UI touch, through a small `app/lib/<slug>_preview.dart`). With nothing to see, the proof is the plan's "How it will be proved" run for real: the commands and the lines they printed, in section 3. Through the same entry point:
   - Bring `app/lib/<slug>_preview.dart` up to the final code: its fakes now stand in for the real repositories (canned replies behind the real cubits), `?s=<n>` per scene (open the sheet, send a message, show the result).
   - `.tool/preview <slug> 1 2 3 4 --out <scratchpad>/build` (background) builds and shoots it: `<out>/shots/strip.png`, one `<n>.png` per scene.
   - Read the strip: it catches real bugs (the grey sheet above was one).
   - **Delete the preview entry point** afterwards; it is not committed.
2. **Finish `product/delivery/<YYYY-MM-DD>-<slug>/README.md`**, one Markdown document, with images in `img/` next to it. Sections 1 and 2 are there from the hand-off; replace the Build brief with sections 3–5:
   1. **The prompt**: every user message of the request, verbatim and in order, plus answers given to questions.
   2. **The design**: the board as approved (`img/mockup-board.png`, plus `board.json`), the references, the decisions table matching the pins, and the icon. On the plan track, **The plan** as approved.
   3. **What was built**: the strip of the real build (or, with nothing to see, the commands that prove it and what they printed), the contract (the rule that matters), the server files and routes, the app pieces, the tests (with counts, and any flaky test named), and **where the build differs from the mockup or the plan** and why.
   4. **How to turn it on**: env vars, commands, and what happens without them.
   5. **Cost and time**: the `.tool/cost` tables of both sessions (see Cost
      and time above), and the totals of the two. Say where USD came from,
      and any spend outside Claude that the build caused (e.g. OpenRouter
      calls), or that there was none.
3. Write the feature's spec (what it does, its contract, its routes) in `product/spec/<feature>.md`, and give it a short pointer section in `AGENTS.md` (the one rule that matters, the folders it owns, the link) plus its folders in the Layout block. `AGENTS.md` is in every session's context, so it keeps only what most tasks need; a rule every task must respect still goes there in full.
4. Report in a few lines: what it cost (USD, tokens in, tokens out) and how long it took, what works, what was verified and how, the deviations, what wasn't tested (e.g. "never run against a real model"), and the delivery path. Then open it for the user, in the background:
   `.tool/doc open <slug>` (it serves the README as a page they can comment
   on; their notes land in the file, and `.tool/doc notes <slug> --open`
   reads back only the unanswered questions). Don't commit unless asked.
