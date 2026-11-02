---
name: research
description: /research - research a problem in My Own App and present it as an RFC that reads like a short talk - one Markdown deck in its own product/research/<date>-<slug>/ folder, each heading a slide that states one point over one diagram, table, picture or piece of code, in story order (the finding, today, examples, the change, trade-offs, impact, decisions, where to go deeper) - with the data, code and reports behind it, and a deck.html presentation of the same story cut to the goal, published on GitHub Pages. Trace the symptoms to the code, read the literature, measure the impact, build the visuals and check them with .tool/doc shape and shot, answer the person's notes (GitHub line comments or .tool/doc), then verify the weakest claims with a deep-research pass. When the RFC is approved it lands on main and its implementation is opened as a /create issue the queue builds into a PR. Use when asked to "research", "investigate how to improve", write an RFC, a proposal, a thesis, or to compare approaches before building.
---

# Research: the digging is long, the RFC is a short talk

The person reads the RFC on a phone, in a few minutes, and should come out
with the finding, what to decide, and at least one idea they did not know.
So **80% of the work is preparing material** (the code traced, the numbers
measured, the diagram drawn, the case found) and the RFC shows only what
that work produced, one point per slide.

Worked example of the format, in the sibling Lunna repo:
`../lunna/product/improvements/2026-10-22-rfcs-as-decks/` (its README is a
deck about decks). Of the whole flow, with notes and a deep-research pass:
`../lunna/product/research/2026-10-16-agent-reliability/`.

**Unattended** (`APP_QUEUE=1`, a run of `.tool/queue` for a GitHub
issue): the queue's instructions replace every "ask" here.

## Where things go

```
product/research/YYYY-MM-DD-<slug>/
  README.md          the RFC (a deck), what the person comments on
  deck.html          the presentation: the same story cut to the goal, served on Pages
  img/               every picture it shows: charts, screenshots, rendered figures
  data/              what was measured (CSV, JSON, log extracts)
  code/              the scripts that produced data/ and img/, runnable again
  reports/<topic>.md deep-research reports (phase 4), notes/<topic>/ beside them
```

Only the folders it uses. A number names the script behind it. English
throughout; Portuguese UI copy is quoted as is.

## 1. Dig in the code (before any web search)

1. Read the code that owns the problem in full (AGENTS.md is the map).
2. Trace each symptom to a root cause with a `file:line`. Look for two
   paths that should be one, a rule living only in a prompt, defaults
   that hide data, errors collapsed into one message.
3. **Measure** what can be measured: counts, sizes, timings, costs, how
   often it happens. Write the script in `code/`, its output in `data/`.
   A finding with a number beats three without.
4. Note what the tests don't exercise.

## 2. Read the literature (one batch)

Send the searches in parallel, then **open** the 3–8 pages you will cite
(a snippet is not a source): vendor engineering posts for practice,
papers for numbers (read the full text where the claim depends on it),
the docs of the exact stack for what it does today. Each finding gets one
sentence of "for us that means…", or it doesn't go in. Read
`product/research/concepts.md` first: an idea already there is one line
and a link, and this RFC goes a level deeper on it. Load the matching
project skill (`tool-design`, `context-degradation`, `evaluation`…).

## 3. Build the material, then write the deck

Make the visuals **before** the prose; the prose is their caption.

| To show | Use | How |
|---|---|---|
| a flow, a call sequence, states, before → after | Mermaid (```` ```mermaid ````) | ≤ 12 nodes; mark the one that matters `:::key` (drawn in the accent) |
| a comparison, a diagnosis, options | a table | ≤ 5 columns, first column the name |
| numbers over a range | a chart PNG in `img/` | a `code/` script; the `dataviz` skill; dark, the review page's colours |
| the app, a screen, a page | a screenshot in `img/` | `.tool/preview`, `.tool/doc shot` |
| how the code does it | an excerpt, ≤ 15 lines | with its `path:line` link above it |

GitHub draws Mermaid natively; the review page draws it in its own
colours. **Draw for a 390 px screen:** a diagram wider than the phone
shrinks until its text can't be read, so prefer `flowchart TD`, at most
three boxes side by side, and no sequence diagram past three participants.
Pictures go in `img/`, never only in the scratchpad.

### The story

Each `##` is a slide. The order is fixed; examples and changes take as
many slides as they need.

```
# <The finding, as a sentence>
<date> · RFC · <status> · scope

## <The point, as a claim>          the whole RFC: > [!IMPORTANT] thesis,
                                      the one picture (before → after),
                                      Do / Not needed / You decide, a line each
## <How it works today, as a claim> the flow as it is, with file:line
## <Example: a real case>           1–3 slides: one case each, before → after
## <Why: the mechanism>             the literature, each > [!TIP] idea to keep
## <The change, as a claim>         one slide per change, or one table
## <Trade-offs>                     option | gain | cost | when it wins
## <Impact>                         what it changes, measured or estimated, and its size
## Decisions                        decision | options | recommended | cost of the other
## Decided unattended               (queue runs only)
## Go deeper                        the ideas to keep, then what to read, the data, the code
```

### The slide

- **The headline states the point** in a sentence of ≤ 12 words ("The
  agent reaches 6 of 39 routes", not "Coverage"). Read alone, the
  headlines tell the story; `.tool/doc shape` prints them so you can check.
- **One visual**, then ≤ 5 bullets or two short lines: ≤ 150 words.
- **Dense subject: more slides, never a longer one.** A `###` inside a
  slide usually means it is two.
- `> [!IMPORTANT]` once, on the first slide. `> [!TIP]` for an idea to
  keep, on the slide whose example shows it (≤ 3 in the RFC): a quotable
  sentence, its source, *for us* in a line.
- A term the person may not know is explained in half a sentence.
- 8–16 slides; the prose under ~1,800 words. *Go deeper* recaps the ideas
  in a table (idea | the case here | read), adds them to `concepts.md`
  (and this RFC to *Met in* of the old ones), then lists sources, one line
  each on what they support, and links `data/`, `code/`, `reports/`.

Why this shape: a sentence headline over visual evidence is understood
and remembered better than a topic over bullets (Garner & Alley 2013),
and material split into learner-paced segments teaches better than one
continuous block (Mayer's segmenting principle). See the worked example.

### Check it as the person will see it

```
.tool/doc shape <slug>     a row per slide: words, visual, ✓/✗; then the headlines alone
.tool/doc shot <slug>      each slide as a PNG at phone width; ✗ for a diagram that failed
```

Fix every ✗ (or say why it stays), Read two or three of the PNGs, and
open the RFC for the person (`.tool/doc open <slug>`, in the background).

### The presentation: deck.html

The README is the record the person comments on; `deck.html` is what they
present and pass around. It tells the same story, **cut to the goal**: what
to do, how big it is, and what to decide. It holds less than the README,
never more. Worked example: `product/research/2026-11-01-apps-as-data/deck.html`.

- **Start from the shell.** Copy `.tool/deck.html` to the topic folder as
  `deck.html`, set its `<title>` (and fonts, if you change them), and put
  one `<section>` per slide where the slides comment is. Arrows, swipe and
  `#N` move between slides; N shows the notes; printing gives a PDF.
- **8–12 slides, in this order.** The cover is the thesis as a sentence.
  Slide 2 is the answer: what to do, its size, and what is new. Then how it
  works (an example each), the evidence, the impact (today against after),
  Decisions (recommended first), and Go deeper. *Today* and *Decided
  unattended* get a slide only when they change a decision; otherwise they
  go in the speaker notes.
- **The slide is a 1920×1080 `<section>` with inline styles only.** Use
  `padding:128px 128px 160px` and flex or grid, a sentence headline of
  ≤ 12 words, and one visual: a table, a row of cards, big numbers, bars
  drawn as `<div>`s, or code of ≤ 14 lines. Text is never under 24px.
  Nothing goes past y 920 except one pinned footer line, which names the
  source. Speaker notes are plain text in an `<aside>`, the section's last
  child.
- **One look across the deck.** Use one palette (a light tone, a dark tone,
  one accent and one warning colour, with the dark tone for the cover and
  the slide the reader must not miss), one type scale (120/64/40/30/24), and
  two typefaces.
- **Only true numbers.** Every figure comes from `data/` and names it in
  the footer. Anything not measured says so on the slide.
- **Check it.** Screenshot each slide and Read every PNG once. Fix any text
  past the footer and any word broken across lines.

  ```
  "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new \
    --hide-scrollbars --virtual-time-budget=4000 --window-size=1920,1080 \
    --screenshot="$TMPDIR/slide-3.png" "file://$PWD/product/research/<folder>/deck.html#3"
  ```

- **Published by Pages.** `review-page.yml` serves it at
  `https://<owner's Pages>/<repo>/research/<folder>/` on every push to
  main, and on a queue branch whose push changes it.

## 4. Verify (deep research)

When the person agrees, or the RFC rests on snippets, run
`anthropic-skills:deep-research` on the 2–4 weakest claims (vendor
behaviour, prices, per-model numbers, recent papers), in the topic folder
so it lands in `reports/`. Ask it to end with confirmed / corrected /
unverified; fix the claims in place and say what stays unverified.

## The person's notes

They comment on GitHub (a line of the README in *Files changed*, or a
selection on the review page; the prompt quotes each as ``On `<file>` line
N (thread T)``) or in `.tool/doc open` on the Mac. A leading `Q:`,
`Learn:`, `Decision:` or `Note:` is its kind (none: a question is a Q).

- Write it under the slide it is about: `> **Q:**`, `> **Learn:**`,
  `> **Decision (YYYY-MM-DD):**`, `> **Note:**`. Answer a question with
  `> **A:**` under it, a real case first, then the rule; on GitHub also
  in the structured output's `replies` under thread T, in two sentences.
- An answer that needs a picture or a page gets **a new slide** after the
  one asked about, and the `> **A:**` links it.
- A **Decision** is binding: change the RFC and drop what it rules out.
- **Learn** goes deeper; a new idea goes in `concepts.md`.
- `.tool/doc notes <slug> [--open]` lists them; leave them in place.

## Recommending skills or tools

Recommend skills to download, not to build. Check what is installed, then
the marketplaces. Before installing a third-party one: clone it into the
scratchpad, read every file, grep its scripts for network, shell, file
and eval use, install project-scoped with its license, leave it
uncommitted.

## Approval: from RFC to build

Unanswered decisions take the option marked *(recommended)*, so mark one
in each.

- **In the queue**, "approve" on the issue merges the RFC and opens
  `Implement: <RFC title>` as a `create` issue (`.tool/queue implement`).
- **In a session**, "approve" is the ask to land it: `git switch -c
  research/<slug>`, add the topic folder only, commit, push, `gh pr create
  --fill`, `gh pr merge --squash --delete-branch`, `git switch -`, then
  `.tool/queue implement <RFC path>` and send its issue URL. Without the
  queue running (`.tool/queue ls`): "run `/clear`, then `/create <RFC path>`".

## Delivering

End each phase with: the RFC path, the presentation's Pages link, its first slide's thesis, the ideas it
added to the ledger (a line each), anything skipped or unverified, and
"reply **approve** to merge it and queue its build". Don't commit unless
asked.
