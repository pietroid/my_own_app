# Internal tools

Scripts for working on My Own App, not part of the app or the server.
Node ≥ 22 and nothing to install. Run them from the repo root.

Each one does in one call what used to take several, and prints only what
matters (paths, ✓/✗, the lines of a failure). That's the point: an agent
re-reads the whole conversation on every call, so fewer calls and shorter
output are what make a session cheap.

| Tool | One line |
|------|----------|
| `check` | CI's checks on what changed, one line per step |
| `preview` | Build a preview entry point, screenshot it, lay out the board |
| `cost` | What a Claude Code session cost, per message, from its transcript |
| `doc` | List, open and comment on the Markdown under `product/`; check an RFC's slides and print them |
| `queue` | GitHub issues worked by Claude Code on this Mac, gate by gate |
| `review.html` | The PR's README as a page on GitHub Pages, commented on by selecting text; drawn as a deck |

## `check`: what CI runs, on what changed

```bash
.tool/check                  # what changed against HEAD (untracked included)
.tool/check --all            # everything, as CI does
```

The server's eslint, tsc and tests (under `TZ=UTC`, as CI) run beside the
app's `flutter analyze`, its own tests and the tests of each changed
package. A change to `app_ui` or `l10n` tests every package. Each step
prints `✓ name (12s)`, or `✗` with the lines that explain it and its log.

## `preview`: prints of a preview entry point

```bash
.tool/preview <slug> 1 2 3 [--out dir] [--board board.json] [--no-build]
```

Builds `app/lib/<slug>_preview.dart` (or `app/lib/<slug>.dart`),
screenshots each scene (`?s=<n>`) as a 390×844 phone into
`<out>/shots/<n>.png` plus `strip.png`, and with `--board` lays out the
annotated board in `<out>/board/`. A failed build prints its errors.

## `cost`: what a session cost

```bash
.tool/cost                 # the session running now
.tool/cost --usd 7.42      # with its running USD (from usage-bars), before it ends
.tool/cost --list          # recent sessions, to pick an earlier one
.tool/cost 2258bb8e        # that one
.tool/cost --from 20:40    # only from that hour on
```

Reads `~/.claude/projects/<this repo>/<session>.jsonl` and prints a
Markdown table, one row per message from you: when, how long, turns, peak
context, tokens in (cache reads in brackets), tokens out (thinking in
brackets), USD. The transcript gets its total USD when the session ends;
before that pass `--usd`. The total is spread over the rows by the usual
price ratios (cache read 0.1× input, cache write 1.25× or 2×, output 5×).

Reading it: tokens in ≈ turns × context. A late turn in a long session reads
several times what an early one does, so the expensive rows are the ones
with many turns at a high peak.

## `doc`: the Markdown under `product/`

```bash
.tool/doc ls [words]                 # docs, newest first, with their open questions
.tool/doc open [file|words]          # open it as a page you can comment on
.tool/doc notes [file|words] [--open]  # print only the notes (--open: unanswered Qs)
.tool/doc shape [file|words]         # an RFC as slides: words, visual, ✓/✗; the headlines alone
.tool/doc shot [file|words] [--out dir] [--slides 1,3]  # each slide as a PNG at phone width
```

A doc is named by its path or by words from its path (`.tool/doc open agent
reliab`); a topic's `README.md` wins over its notes, then the newest
match, and no name at all means the newest doc.

`open` starts `annotate.mjs` for that file in the background and opens the
browser. A second `open` of the same file reuses the page already running,
and a server nobody has looked at for 20 minutes exits by itself.

On the page, hover a block and press **+**, or select some text, to leave a
**Q**, **Learn**, **Decision** or **Note**. It is written into the file
itself, as a blockquote under that block:

```markdown
> **Q:** _“the quoted text”_ — why not cache the whole prompt?

> **A:** The answer, written by whoever answers it.
```

So the notes live in git with the doc, and an agent reads them with
`.tool/doc notes <doc> --open` instead of reading the whole document. The
page redraws whenever the file changes, from any editor.

**An RFC is a deck** (`/research`): each `##` a slide, a sentence headline
over one visual. Both pages draw it that way, with one stylesheet and
script (`<style id="deck">`, `<script id="deck">` in `review.html`, which
`annotate.mjs` copies): its own dark look, Onest, true black, Mermaid
diagrams in the same colours (`:::key` draws a node in the accent), GitHub alerts
(`> [!IMPORTANT]` the point, `> [!TIP]` an idea to keep).

- `shape` prints a row per slide (words, visual, ✓ within budget: ≤ 150
  words, a visual on each `##`, a headline of ≤ 12 words), then the
  headlines alone, which should read as the story. Q/A notes don't count.
- `shot` serves the repo locally, loads `review.html?md=<file>` in
  headless Chrome (`shot.mjs`, the DevTools protocol, no dependencies) at
  390 px, and saves each slide as a PNG (default: the temp dir), printing
  ✗ for every diagram that failed to draw. `CHROME=` points at another
  browser binary.

## `queue`: issues in, merged PRs out

```bash
.tool/queue setup        # once: labels, a push topic, the runner, the LaunchAgent, a test push
.tool/queue ls           # the runner's commit, then each issue, where it is, what it has used
.tool/queue log 12       # the tail of #12's last run
.tool/queue tick         # one pass in the foreground (stop the agent first)
.tool/queue implement product/research/<topic>/README.md [--dry-run]
                         # open the create issue that builds an RFC (it must be on main)
.tool/queue stop|start   # unload / load the LaunchAgent
.tool/queue adopt        # move a LaunchAgent that runs elsewhere onto the runner (it does it alone)
```

Open an issue with the **Create**, **Research** or **Improve** template
(it adds the label). A LaunchAgent polls every minute and works up to two
issues at a time (only one of them merging), so a short round never waits
behind a long build; each phase is a fresh `claude -p` in its own worktree
(`../<repo>-queue/<n>-<slug>`, branch `queue/<n>-<slug>`). `ls` marks the ones
running and for how long:

```
issue ─▶ 👀 ─▶ design ─▶ draft PR + comment + push ─▶ you reply
                  ▲                                   │
                  └──────── anything else ◀───────────┤
                                                      ▼ "approve"
          build + .tool/check ─▶ PR ready + comment + push ─▶ you reply
                  ▲                                   │
                  └───────── what to fix ◀────────────┤
                                                      ▼ "approve"
          merge origin/main (a run resolves conflicts, .tool/check --all)
          ─▶ squash into main ─▶ issue closed ─▶ push
```

On a feature with nothing to draw (tooling, CI, a server rule), the design
is a one-page plan instead of a board, and the gate says **Plan ready**.
Research and improve skip the design gate. **An approved RFC goes on**:
once merged, the queue opens `Implement: <RFC title>` as a `create` issue
pointing at it, and the next pass plans it and opens its PR, so research
flows into a build with one "approve". **The PR description is short**:
the run's summary, the link to the review page (and to the README at that
commit), the board if there is one, the open questions, and the usage
folded under a line (per run, time, turns, tokens, API-equivalent USD and
the 5-hour and weekly windows before and after, from `claude -p /usage`,
free). The topic's README itself (delivery, RFC or report) is read on the
page, or in *Files changed*. Each push carries the totals.

**It runs what is merged.** The LaunchAgent runs `queue.mjs` from its own
worktree, `<worktrees>/.runner`, detached at `origin/main` and moved to
its tip after every pass; a changed `queue.mjs` starts no new run and restarts it once none is going. Before this,
it ran from the main checkout, which nobody pulled, so merged changes to
the queue (the page link, an RFC's build issue) never ran. Env files for
the issue worktrees still come from the main checkout (the one whose
`.git` holds `.git/queue`). `ls` prints the runner's commit, or ✗ and
where the handover is.

**It moves onto the runner by itself.** A LaunchAgent that runs some other
`queue.mjs` (an old one, from the main checkout) is handed over without
anyone at the Mac: `adopt` loads a one-off job,
`dev.pietroid.my-own-app-queue-handover`, that waits for `origin/main` to have
the handover, brings the runner to main, waits for the running pass to end
(it touches that script, so the old queue exits after its pass), rewrites
the LaunchAgent onto the runner, reloads it, sends a push and unloads
itself (`.git/queue/handover.log`). A queue running outside the runner
calls `adopt` when it starts. It is its own launchd job because launchd
kills everything a job leaves behind when it exits, so a child of the old
queue would die with it. After that, a merge is all it takes: the runner
moves to main after each pass and the new `queue.mjs` restarts it.

- **Answering.** Your comments on the issue or its PR after the gate.
  `approve` (or `ok`, `lgtm`, `aprovado`, 👍) **alone in its comment** goes
  on; anything else is feedback for another round. After a failure,
  `retry` reruns the phase. Closing the issue drops it.
- **Commenting on a line.** In the PR's *Files changed* (the GitHub app
  too), tap a line of the README and comment; start it with `Q:`,
  `Learn:`, `Decision:` or `Note:` to say what it is. Submit them as one
  review and the whole review is one round. The next run gets each with
  its file, line and the line's text, writes it into the doc as a note
  (`.tool/doc notes` reads them), and the queue posts the run's answer
  under your comment. A line comment is never an approval.
- **Commenting on the page.** Each gate's comment and the PR's description
  link 📝 *Read it as a page*: the README drawn as on GitHub, at
  `https://<owner's Pages>/<repo>/review.html?pr=N&path=…` (Pages, under
  the owner's domain), with the
  PR's threads under the blocks they're about. Select text (or tap a
  block's **+**), pick `Q`/`Learn`/`Decision`/`Note`, write, **Add**;
  drafts wait in the phone's browser until **Send** posts them all as one
  review of line comments, so it's the same round as above. The first
  Send asks for a fine-grained token (this repo only, *Pull requests: read
  and write*), kept in that browser's localStorage. The page is
  `.tool/review.html`, static, published by
  `.github/workflows/review-page.yml` on every push to `main` or a
  `queue/*` branch that changes it (the `github-pages` environment allows
  both), so a PR that changes the page can be reviewed on itself. Pages
  is on (`setup` turns it on in a fork); without it the link is left out. A line outside the PR's diff makes
  GitHub refuse the review, and the page sends the drafts as one plain PR
  comment instead, each naming its line.
- **Phone.** ntfy.sh: install the app and subscribe to the topic `setup`
  printed (it's in `.git/queue/config.json`). No account, no server.
- **Only the owner.** The repo is public: issues and comments by anyone
  else are never read.
- **Limits.** A run that hits the usage limit pauses until the window
  resets and picks up from its files. Two runs at once spend the window
  twice as fast, and a run's before/after window figures include the other
  run's use. The Mac must be awake (`caffeinate`
  holds it while a run goes; closing the lid still sleeps it).
- **State** is in `.git/queue/`: one JSON per issue, the stream-json log of
  every run in `logs/`, the agent's own output in `daemon.log`.

## `mockup/`: the pieces under `preview`

Used by `preview` and the `/create` skill (`.claude/skills/create/SKILL.md`).
macOS and Google Chrome.

| Script | What it does |
|--------|--------------|
| `shoot-flutter.sh <web_build> <out> <scene>…` | Screenshots a Flutter web build as a 390×844 phone, one `<n>.png` per `?s=<n>` scene, plus `strip.png` |
| `shoot.mjs` | One screenshot over the DevTools protocol; used by `shoot-flutter.sh` |
| `board.mjs <board.json> <out>` | Lays the screenshots out as an annotated board with lettered pins: `board.png` and `screen1..n.png` |
