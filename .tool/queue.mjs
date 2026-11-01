#!/usr/bin/env node
// The queue: GitHub issues worked by Claude Code on this Mac, two at a time.
//
//   .tool/queue setup            labels, a push topic, the runner, the LaunchAgent, Pages; sends a test push
//   .tool/queue run              the loop the LaunchAgent keeps alive (a pass a minute)
//   .tool/queue tick             one pass, in the foreground
//   .tool/queue ls               the issues it knows and where each one is
//   .tool/queue log <issue>      the tail of that issue's last run
//   .tool/queue stop | start     unload or load the LaunchAgent
//   .tool/queue implement <rfc> [--dry-run]   open the create issue that builds an RFC on main
//   .tool/queue adopt            move the LaunchAgent onto the runner by itself, once main has it
//
// An open issue of yours labelled create, research or improve is queued. Each
// phase is a fresh headless `claude -p` in the issue's own worktree and
// branch; the queue commits, pushes, keeps a PR whose description is the
// topic's README with the usage on top, and stops at each gate with a
// comment on the issue and a push to your phone. Your next comment on the
// issue (or the PR) is the answer: "approve" alone goes on, anything else is
// feedback for another round. At the last gate "approve" merges into main
// (conflicts resolved by another run), closes the issue and tells you. An
// approved RFC, once merged, opens its own `create` issue (`implement`), so
// research flows on into a build.
//
// The LaunchAgent runs the queue from its own worktree of origin/main
// (<worktrees>/.runner), moved to main's tip on every pass, so what merges
// is what runs: a run from the main checkout ran whatever it last pulled.
//
// The repo is public: only issues and comments by its owner are ever read.
// State and logs live in .git/queue/, never in the tree.
import { spawn, execFileSync } from 'node:child_process';
import { copyFileSync, createWriteStream, existsSync, mkdirSync, readFileSync, readdirSync, realpathSync, rmSync, statSync, utimesSync, writeFileSync } from 'node:fs';
import { randomBytes } from 'node:crypto';
import { homedir } from 'node:os';
import { basename, dirname, join, posix, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const root = resolve(here, '..');
// .git/queue of the main checkout, also from a worktree (where .git is a file).
const home = join(execFileSync('git', ['rev-parse', '--path-format=absolute', '--git-common-dir'], { cwd: root, encoding: 'utf8' }).trim(), 'queue');
// The checkout the person works in, whose .git holds home.
const checkout = resolve(home, '..', '..');
const configPath = join(home, 'config.json');
const stateDir = join(home, 'issues');
const logDir = join(home, 'logs');
const AGENT = process.env.QUEUE_AGENT ?? 'dev.pietroid.my-own-app-queue'; // another label only to test a handover
const plistPath = join(homedir(), 'Library', 'LaunchAgents', `${AGENT}.plist`);
const MARK = '<!-- my-own-app-queue -->';
const KINDS = ['create', 'research', 'improve'];
const STATUS = { working: 'agent:working', waiting: 'agent:waiting', failed: 'agent:failed', done: 'agent:done' };
const APPROVE = /^(approved?|aprovad[oa]|aprovo|aprova|lgtm|ok(ay)?|go|ship( it)?|build( it)?|merge( it)?|sim|pode|👍|✅|🚀)[\s.!]*$/iu;
// A short reply that says go and asks for nothing else ("Great. Build it",
// "ok, pode seguir") approves too; one with a but, a change or a question is feedback.
const GO = /\b(approved?|aprovad[oa]|aprovo|lgtm|ship it|build it|merge it|go ahead|pode seguir|pode mandar|manda ver)\b|👍|✅|🚀/iu;
const BUT = /\b(but|mas|except|exceto|change|muda|mude|troca|troque|remove|tira|tire|fix|however|porém|só que|instead|em vez)\b|\?/iu;
const isApproval = (text) => { const t = text.trim(); return APPROVE.test(t) || (t.split(/\s+/).length <= 8 && GO.test(t) && !BUT.test(t)); };
const RETRY = /^(retry|again|de novo|tenta de novo)[\s.!]*$/iu;
const RUN_LIMIT_MS = 4 * 3600e3;
// Issues worked at once, so a short round waits for no long build. Only one
// of them merges at a time: both would push to main and run .tool/check --all.
const JOBS = 2;
const running = new Map(); // issue → phase

const sh = (cmd, args, opts = {}) =>
  execFileSync(cmd, args, { cwd: root, encoding: 'utf8', stdio: ['pipe', 'pipe', 'pipe'], maxBuffer: 64 << 20, ...opts }).trim();
const trySh = (...a) => { try { return sh(...a); } catch { return null; } };
// For what takes minutes: sh would hold up the other job and the ticks.
// Rejects like execFileSync, with the output on e.stdout and e.stderr.
const shAsync = (cmd, args, { timeout, ...opts } = {}) => new Promise((done, failed) => {
  const child = spawn(cmd, args, { cwd: root, stdio: ['ignore', 'pipe', 'pipe'], ...opts });
  let stdout = '', stderr = '';
  child.stdout.on('data', (c) => { stdout = (stdout + c).slice(-(1 << 20)); });
  child.stderr.on('data', (c) => { stderr = (stderr + c).slice(-(1 << 20)); });
  const timer = timeout && setTimeout(() => child.kill('SIGTERM'), timeout);
  child.on('error', failed);
  child.on('close', (code, signal) => {
    clearTimeout(timer);
    if (code === 0) return done(stdout.trim());
    failed(Object.assign(new Error(`${cmd} exited with ${code ?? signal}`), { stdout, stderr }));
  });
});
const gh = (args, input) => sh('gh', args, input === undefined ? {} : { input });
const ghJson = (args, input) => JSON.parse(gh(args, input) || 'null');
const git = (wt, ...args) => sh('git', args, { cwd: wt });
const log = (...a) => console.log(new Date().toISOString().slice(0, 19), ...a);
const fail = (m) => { console.error(m); process.exit(1); };
const readJson = (p, d = null) => (existsSync(p) ? JSON.parse(readFileSync(p, 'utf8')) : d);
const writeJson = (p, v) => { mkdirSync(dirname(p), { recursive: true }); writeFileSync(p, JSON.stringify(v, null, 2) + '\n'); };
const slugify = (s) => s.normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '').slice(0, 40) || 'task';

const config = () => readJson(configPath) ?? fail('No config: run .tool/queue setup first.');
const load = (n) => readJson(join(stateDir, `${n}.json`));
const save = (st) => writeJson(join(stateDir, `${st.issue}.json`), st);
const states = () => (existsSync(stateDir) ? readdirSync(stateDir).filter((f) => f.endsWith('.json')).map((f) => readJson(join(stateDir, f))) : []);

// ---------------------------------------------------------------- the phone

async function push(cfg, { title, message, tags = [], priority = 3, click }) {
  try {
    await fetch('https://ntfy.sh/', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ topic: cfg.topic, title, message, tags, priority, click, actions: click ? [{ action: 'view', label: 'Open', url: click }] : undefined }),
    });
  } catch (e) { log('push failed:', e.message); }
}

// ---------------------------------------------------------------- usage

// `claude -p /usage` is a local command: no model call, no tokens.
function usageNow() {
  const out = trySh('claude', ['-p', '/usage', '--output-format', 'json'], { timeout: 30e3 });
  if (!out) return null;
  const text = JSON.parse(out).result ?? '';
  const pct = (label) => { const m = text.match(new RegExp(`${label}[^\\n]*?(\\d+)% used`)); return m ? +m[1] : null; };
  return { session: pct('Current session'), week: pct('Current week \\(all models\\)') };
}

const fmtTokens = (n) => (n >= 1e6 ? `${(n / 1e6).toFixed(1)}M` : n >= 1e3 ? `${Math.round(n / 1e3)}k` : `${n}`);
const fmtMin = (ms) => { const m = Math.round(ms / 60e3); return m >= 60 ? `${Math.floor(m / 60)} h ${String(m % 60).padStart(2, '0')}` : `${m} min`; };
const fmtWindow = (b, a) => (b == null || a == null ? '—' : `${b}→${a}%`);
const delta = (r) => (r.before?.week == null || r.after?.week == null ? null : r.after.week - r.before.week);

function totals(runs) {
  const t = { ms: 0, turns: 0, tin: 0, cache: 0, tout: 0, usd: 0, week: 0 };
  for (const r of runs) {
    t.ms += r.ms; t.turns += r.turns; t.tin += r.tin; t.cache += r.cache; t.tout += r.tout; t.usd += r.usd; t.week += delta(r) ?? 0;
  }
  return t;
}

function usageLine(runs) {
  const t = totals(runs);
  const last = runs.at(-1);
  const week = last?.after?.week ?? last?.before?.week;
  return `${fmtMin(t.ms)} · ${fmtTokens(t.tin)} in / ${fmtTokens(t.tout)} out · ~$${t.usd.toFixed(2)} API-eq · week +${t.week} pts${week != null ? ` (now ${week}%)` : ''}`;
}

function usageTable(runs) {
  if (!runs.length) return '_No runs yet._';
  const rows = runs.map((r) => {
    const d = delta(r);
    return `| ${r.phase} | ${r.started.slice(5, 16).replace('T', ' ')} | ${fmtMin(r.ms)} | ${r.turns} | ${fmtTokens(r.tin)} (${fmtTokens(r.cache)}) | ${fmtTokens(r.tout)} | $${r.usd.toFixed(2)} | ${fmtWindow(r.before?.session, r.after?.session)} | ${fmtWindow(r.before?.week, r.after?.week)}${d != null ? ` (+${d})` : ''} |`;
  });
  const t = totals(runs);
  return [
    '| Phase | Started (UTC) | Time | Turns | Tokens in (cache read) | Out | API-eq. | 5-hour window | Week |',
    '|---|---|---|---|---|---|---|---|---|',
    ...rows,
    `| **Total** | | **${fmtMin(t.ms)}** | **${t.turns}** | **${fmtTokens(t.tin)}** (${fmtTokens(t.cache)}) | **${fmtTokens(t.tout)}** | **$${t.usd.toFixed(2)}** | | **+${t.week} pts** |`,
    '',
    '<sub>Billed to the subscription. API-eq. is what the same tokens would cost at API prices, not money spent. Window figures are `/usage` before and after each run, so they also count anything else on the account meanwhile.</sub>',
  ].join('\n');
}

// ---------------------------------------------------------------- the engine

const SCHEMA = JSON.stringify({
  type: 'object',
  properties: {
    summary: { type: 'string', description: 'Two to four sentences for the person, in the language of the issue: what you did and what to look at.' },
    doc: { type: 'string', description: 'Path from the repo root of the README the PR shows (the delivery README, the RFC or the improvement report).' },
    questions: { type: 'array', items: { type: 'string' }, description: 'Open questions for the person, if any.' },
    replies: {
      type: 'array',
      items: { type: 'object', properties: { thread: { type: 'integer' }, body: { type: 'string' } }, required: ['thread', 'body'] },
      description: 'One answer per comment the person left on a line of the PR, by its thread id: what you changed there, or the answer to the question. The queue posts each under their comment.',
    },
  },
  required: ['summary', 'doc'],
});

const rules = (st) => `You are running unattended, started by the My Own App queue (.tool/queue.mjs) for GitHub issue #${st.issue}: ${st.url}
Nobody is at the keyboard and nobody answers until you finish: AskUserQuestion is not available.
- Work only in this worktree (${st.worktree}), branch ${st.branch}. Leave the work in its files: the queue commits, pushes and keeps the PR. Don't run git commit, push, checkout, merge, rebase or stash pop of anything you didn't stash, and don't run .tool/doc open.
- Where a skill says to ask, or to stop for the person, take the option you would recommend, list it in the document under "Decided unattended", and go on. Write a question you can't decide into the document and into the structured output's questions.
- Skip .tool/cost and session_cost: the queue measures every run and writes the figures in the PR.
- Images the person must see go in the topic folder (img/ next to its README), not only in the scratchpad: they read the README on the review page, on a phone.
- This worktree is fresh: run npm ci in server/ or flutter pub get if a command needs them.
- A reply that starts "On \`<file>\` line N (thread T)" is a comment the person left on that line of the PR: work on that spot of the file, and answer it in replies under thread T.
- Finish with the structured output.`;

const quote = (s) => s.split('\n').map((l) => `> ${l}`).join('\n');
const slugOf = (doc) => basename(dirname(doc)).replace(/^\d{4}-\d{2}-\d{2}-/, '');

function prompt(st, phase, reply) {
  const ask = `${st.title}\n\n${st.body ?? ''}`.trim();
  switch (`${st.kind}:${phase}`) {
    case 'create:design':
      return `/create ${ask}\n\n---\nThis is the design session, unattended. Pick the track (Phase 0) and say which in the summary. Mockup track: do Phase 1, then write the hand-off at once instead of waiting for approval (the person approves on the issue): the draft product/delivery/<YYYY-MM-DD>-<slug>/README.md with sections 1 and 2 and the Build brief, the board as img/mockup-board.png with board.json, and each screen as img/mockup-<n>.png; keep the preview entry point and the new widgets in the worktree. Plan track: do Phase 1P and stop there, with no preview and no board. Section 1 quotes the issue.`;
    case 'create:revise':
      return `/create ${st.title}\n\nThe design in ${st.doc} was reviewed on the issue, and the person replied:\n\n${quote(reply)}\n\n---\nDo Phase 2 on it, unattended: change the widgets, re-shoot what changed, update the board, img/ and the README (the reply goes in section 1; update the decisions and the Build brief). On the plan track, change the plan instead. Stop at the hand-off again.`;
    case 'create:build':
      return `/create build ${slugOf(st.doc)}\n\nThe design was approved on the issue. Do Phases 3 and 4 unattended. .tool/check must pass before you finish; a failure your change didn't cause is proved (stash, rerun) and named in the README. In section 5 write "Measured by the queue: see the pull request." instead of .tool/cost tables.`;
    case 'create:fix':
      return `/create build ${slugOf(st.doc)}\n\nThis is a follow-up: the build in ${st.doc} was reviewed on the issue, and the person replied:\n\n${quote(reply)}\n\n---\nDo what they ask, unattended, by the rules of Phases 3 and 4: keep .tool/check green, re-shoot the prints if the UI changed, and update the README (the reply in section 1, what was built).`;
    case 'research:start':
      return `/research ${ask}\n\n---\nUnattended: do Phases 1 to 3 and write the RFC in its product/research/ folder. Leave Phase 4 (the deep-research pass) until the person asks for it.`;
    case 'research:fix':
      return `/research ${st.title}\n\nThe RFC at ${st.doc} was reviewed on the issue, and the person replied:\n\n${quote(reply)}\n\n---\nAnswer it the way the skill answers the user's notes, unattended, and run Phase 4 if they ask for it. Update the RFC.`;
    case 'improve:start':
      return `/improve ${ask}\n\n---\nUnattended: at step 2 take the recommended option of each fork and list them in the report; do the whole run through step 5.`;
    case 'improve:fix':
      return `/improve ${st.title}\n\nThe change reported in ${st.doc} was reviewed on the issue, and the person replied:\n\n${quote(reply)}\n\n---\nDo what they ask, unattended, verify it for real and update the report.`;
    case `${st.kind}:conflicts`:
      return `Merging origin/main into this branch (${st.branch}, for issue #${st.issue}: ${st.title}) stopped on conflicts in:\n\n${reply}\n\nResolve every one keeping both intents: main's side is already shipped, this branch's side is the feature. Then run .tool/check --all and fix what fails. Don't commit. In the summary, say what conflicted and how you resolved it; doc is ${st.doc}.`;
    case `${st.kind}:checks`:
      return `After merging origin/main into this branch (${st.branch}, for issue #${st.issue}: ${st.title}), .tool/check --all fails:\n\n\`\`\`\n${reply}\n\`\`\`\n\nFix it (stash and rerun to prove a failure isn't this branch's). Don't commit. doc is ${st.doc}.`;
  }
  throw new Error(`no prompt for ${st.kind}:${phase}`);
}

// One headless session. Resolves with its figures and the structured output;
// never throws for a failed run.
async function claude(st, phase, text) {
  const before = usageNow();
  const started = new Date();
  mkdirSync(logDir, { recursive: true });
  const logPath = join(logDir, `${st.issue}-${started.toISOString().replace(/[:.]/g, '-')}-${phase}.jsonl`);
  const out = createWriteStream(logPath);
  const args = ['-p', text, '--output-format', 'stream-json', '--verbose', '--permission-mode', 'auto', '--permission-prompts', 'none',
    '--max-turns', '500', '--json-schema', SCHEMA, '--append-system-prompt', rules(st)];
  const child = spawn('claude', args, { cwd: st.worktree, env: { ...process.env, APP_QUEUE: '1' }, stdio: ['ignore', 'pipe', 'pipe'] });
  const awake = spawn('caffeinate', ['-i', '-w', String(child.pid)], { stdio: 'ignore' });
  awake.on('error', () => {});
  const timer = setTimeout(() => child.kill('SIGINT'), RUN_LIMIT_MS);
  let result = null, limit = null, lastText = '', buf = '', stderr = '';
  child.stdout.on('data', (chunk) => {
    out.write(chunk);
    buf += chunk;
    let i;
    while ((i = buf.indexOf('\n')) >= 0) {
      const line = buf.slice(0, i); buf = buf.slice(i + 1);
      let ev; try { ev = JSON.parse(line); } catch { continue; }
      if (ev.type === 'result') result = ev;
      if (ev.type === 'rate_limit_event') limit = ev.rate_limit_info;
      if (ev.type === 'assistant') for (const c of ev.message?.content ?? []) if (c.type === 'text' && c.text.trim()) lastText = c.text;
    }
  });
  child.stderr.on('data', (c) => { stderr += c; out.write(c); });
  const code = await new Promise((done) => child.on('close', done));
  clearTimeout(timer);
  out.end();
  const tokens = Object.values(result?.modelUsage ?? {});
  const sum = (k) => tokens.reduce((n, m) => n + (m[k] ?? 0), 0);
  const run = {
    phase, started: started.toISOString(), ms: Date.now() - started, turns: result?.num_turns ?? 0,
    tin: sum('inputTokens') + sum('cacheReadInputTokens') + sum('cacheCreationInputTokens'), cache: sum('cacheReadInputTokens'),
    tout: sum('outputTokens'), usd: result?.total_cost_usd ?? 0, before, after: usageNow(), session: result?.session_id, log: logPath,
  };
  const output = result?.structured_output ?? null;
  const ok = code === 0 && result && !result.is_error && output;
  const limited = !ok && (limit?.status === 'rejected' || /usage limit|rate limit|limit reached/i.test(`${result?.result ?? ''} ${stderr} ${lastText}`));
  const why = ok ? null : (result?.result || lastText || stderr || `claude exited with ${code}`).slice(-1500);
  const resetsAt = limited ? Math.max(...Object.values(limit?.unifiedWindows ?? {}).filter((w) => w.utilization >= 1).map((w) => w.resetsAt), limit?.resetsAt ?? 0) : null;
  return { run, output, ok, limited, resetsAt, why };
}

// ---------------------------------------------------------------- GitHub

function setStatus(cfg, st, status) {
  const current = ghJson(['issue', 'view', String(st.issue), '-R', cfg.repo, '--json', 'labels']).labels.map((l) => l.name);
  const labels = [...current.filter((l) => !l.startsWith('agent:')), STATUS[status]];
  gh(['api', '-X', 'PUT', `repos/${cfg.repo}/issues/${st.issue}/labels`, '--input', '-'], JSON.stringify({ labels }));
  st.status = status;
  save(st);
}

function comment(cfg, n, body) {
  const c = ghJson(['api', '-X', 'POST', `repos/${cfg.repo}/issues/${n}/comments`, '--input', '-'], JSON.stringify({ body: `${body}\n\n${MARK}` }));
  return c.created_at;
}

const react = (cfg, path) => trySh('gh', ['api', '-X', 'POST', `repos/${cfg.repo}/${path}/reactions`, '-f', 'content=eyes']);

// What the owner said since the gate opened: comments on the issue and the
// PR, the text of PR reviews, and comments on lines of the PR's files.
export function answers(cfg, st) {
  const read = (path) => ghJson(['api', '--paginate', '--slurp', `repos/${cfg.repo}/${path}`]).flat();
  const mine = (c, at) => c.user?.login === cfg.owner && !(c.body ?? '').includes(MARK) && at > st.gateAt;
  const said = [st.issue, st.pr].filter(Boolean).flatMap((n) => read(`issues/${n}/comments`))
    .filter((c) => mine(c, c.created_at)).map((c) => ({ kind: 'comment', id: c.id, at: c.created_at, body: c.body.trim() }));
  if (st.pr) {
    said.push(...read(`pulls/${st.pr}/reviews`).filter((r) => r.body?.trim() && mine(r, r.submitted_at ?? ''))
      .map((r) => ({ kind: 'review', id: r.id, at: r.submitted_at, body: r.body.trim() })));
    said.push(...read(`pulls/${st.pr}/comments`).filter((c) => mine(c, c.created_at)).map(lineComment));
  }
  return said.sort((a, b) => a.at.localeCompare(b.at));
}

// A comment on lines of a file in the PR, with the lines it is about (the
// end of its diff hunk) and the thread a reply goes to.
export function lineComment(c) {
  const line = c.line ?? c.original_line ?? null;
  const start = c.start_line ?? c.original_start_line;
  const span = start && line ? line - start + 1 : 1;
  const lines = c.subject_type === 'file' || !c.diff_hunk ? [] : c.diff_hunk.split('\n').slice(-span).map((l) => l.slice(1));
  return { kind: 'line', id: c.id, thread: c.in_reply_to_id ?? c.id, at: c.created_at, body: c.body.trim(), path: c.path, line, lines };
}

// The answers as one reply for the next run's prompt. A line comment names
// its file, line and thread, and quotes the lines it was left on.
export function feedback(said) {
  return said.map((c) => {
    if (c.kind !== 'line') return c.body;
    const where = `On \`${c.path}\`${c.line ? ` line ${c.line}` : ''} (thread ${c.thread})`;
    return c.lines.length ? `${where}, about:\n${quote(c.lines.join('\n'))}\n\n${c.body}` : `${where}:\n\n${c.body}`;
  }).join('\n\n---\n\n');
}

// "approve" alone in each, and no comment on a line: a line comment is
// always something to work on.
export const approves = (said) => said.every((c) => c.kind !== 'line' && isApproval(c.body));

const raw = (cfg, sha, path) => `https://raw.githubusercontent.com/${cfg.repo}/${sha}/${path}`;

// The review page (.tool/review.html on GitHub Pages) for the PR's README,
// once Pages is on: the RFC drawn, commented on by selecting its text.
export function reviewUrl(cfg, st) {
  const site = st.pr && st.doc && trySh('gh', ['api', `repos/${cfg.repo}/pages`, '--jq', '.html_url']);
  // Pages answers http:// for a custom domain until its certificate is issued.
  return site ? `${site.replace(/^http:/, 'https:').replace(/\/?$/, '/')}review.html?repo=${cfg.repo}&pr=${st.pr}&path=${encodeURI(st.doc)}` : null;
}
const pageLine = (url) => (url ? `\n\n📝 [Read it as a page and comment on its text](${url})` : '');
const boardOf = (st) => st.doc && posix.join(posix.dirname(st.doc), 'img/mockup-board.png');
const hasBoard = (st) => !!st.doc && existsSync(join(st.worktree, boardOf(st)));

// Short on purpose: the README is read on the review page (or in Files
// changed, where its lines take comments), not pasted here. A board stays,
// since it is the design at a glance.
export function prBody(cfg, st, sha, line, page = reviewUrl(cfg, st)) {
  const file = st.doc ? `📄 [${posix.basename(posix.dirname(st.doc))}/README.md](https://github.com/${cfg.repo}/blob/${sha}/${st.doc})` : '';
  const read = page ? `📝 **[Read it as a page and comment on its text](${page})**${file ? ` · ${file}` : ''}` : file;
  const board = hasBoard(st) ? `\n\n![board](${raw(cfg, sha, boardOf(st))})` : '';
  const qs = st.questions?.length ? `\n\n**Open questions**\n${st.questions.map((q) => `- ${q}`).join('\n')}` : '';
  const usage = st.runs.length ? `\n\n<details><summary>Usage: ${usageLine(st.runs)}</summary>\n\n${usageTable(st.runs)}\n\n</details>` : '';
  return `Closes #${st.issue} · \`${st.kind}\` · ${line}\n\n${st.summary ?? ''}${read ? `\n\n${read}` : ''}${board}${qs}${usage}`;
}

function syncPr(cfg, st, line) {
  const sha = git(st.worktree, 'rev-parse', 'HEAD');
  if (!st.pr) {
    const url = sh('gh', ['pr', 'create', '-R', cfg.repo, '--draft', '--base', 'main', '--head', st.branch, '--title', st.title, '--body-file', '-'], { input: prBody(cfg, st, sha, line, null) });
    st.pr = +url.split('/').pop();
    save(st);
  }
  // Again once the PR has a number: the page's link needs it.
  gh(['pr', 'edit', String(st.pr), '-R', cfg.repo, '--body-file', '-'], prBody(cfg, st, sha, line));
  return sha;
}

// ---------------------------------------------------------------- the worktree

async function worktree(cfg, st) {
  if (existsSync(st.worktree)) return;
  sh('git', ['fetch', '-q', 'origin', 'main']);
  const exists = trySh('git', ['rev-parse', '--verify', '-q', `refs/heads/${st.branch}`]);
  sh('git', ['worktree', 'add', '-q', ...(exists ? [st.worktree, st.branch] : ['-b', st.branch, st.worktree, 'origin/main'])]);
  // What git ignores but the app and the server need to run.
  // From the checkout the person works in: the runner has none of them.
  const src = checkout;
  const envs = ['server/.env', 'server/.env.local', ...readdirSync(join(src, 'app/env')).filter((f) => f.endsWith('.json') && !f.includes('example')).map((f) => `app/env/${f}`)];
  for (const f of envs) if (existsSync(join(src, f))) copyFileSync(join(src, f), join(st.worktree, f));
  await shAsync('npm', ['ci', '--prefer-offline', '--no-audit', '--no-fund', '--silent'], { cwd: join(st.worktree, 'server'), timeout: 600e3 }).catch(() => {});
}

function commit(st, message) {
  git(st.worktree, 'add', '-A');
  if (trySh('git', ['diff', '--cached', '--quiet'], { cwd: st.worktree }) !== null) return false; // nothing staged
  git(st.worktree, 'commit', '-q', '-m', message);
  return true;
}

function removeWorktree(st) {
  trySh('git', ['worktree', 'remove', '--force', st.worktree]);
  trySh('git', ['branch', '-D', st.branch]);
}

// ---------------------------------------------------------------- phases

const FIRST = { create: 'design', research: 'start', improve: 'start' };
const GATE = { 'create:design': 'design', 'create:revise': 'design' };
const gateOf = (st, phase) => GATE[`${st.kind}:${phase}`] ?? 'review';
const NEXT = { design: { approve: 'build', feedback: 'revise' }, review: { approve: 'merge', feedback: 'fix' } };
const HEADLINE = {
  design: ['🎨', 'Design ready', 'Reply **approve** to build it, or write what to change: here, or on any line of the PR\'s **Files changed**.', 'art'],
  plan: ['📝', 'Plan ready', 'Reply **approve** to build it, or write what to change: here, or on any line of the PR\'s **Files changed**.', 'memo'],
  review: ['✅', 'Ready for review', 'Reply **approve** to merge it into main (that deploys), or write what to fix: here, or on any line of the PR\'s **Files changed**.', 'white_check_mark'],
  rfc: ['✅', 'RFC ready', 'Reply **approve** to merge it and queue its build as a new issue, or write what to change: here, or on any line of the PR\'s **Files changed**.', 'white_check_mark'],
};
// A design gate with no board is the plan track (nothing to draw).
const headline = (st, gate, board) => HEADLINE[gate === 'design' ? (board ? 'design' : 'plan') : st.kind === 'research' ? 'rfc' : 'review'];

async function work(cfg, st) {
  const { phase, reply } = st.next;
  log(`#${st.issue} ${phase}`);
  st.since = Date.now();
  setStatus(cfg, st, 'working');
  await worktree(cfg, st);
  if (phase === 'merge') return merge(cfg, st);

  const res = await claude(st, phase, prompt(st, phase, reply));
  st.runs.push(res.run);
  if (!res.ok) return stopped(cfg, st, phase, reply, res);

  st.summary = res.output.summary;
  st.doc = res.output.doc || st.doc;
  st.questions = res.output.questions ?? [];
  commit(st, `${st.kind}(#${st.issue}): ${phase} · ${st.title}`);
  git(st.worktree, 'push', '-q', '-u', 'origin', st.branch);

  const gate = gateOf(st, phase);
  const [icon, head, ask, tag] = headline(st, gate, hasBoard(st));
  const sha = syncPr(cfg, st, `**${head}**, waiting for your reply on #${st.issue}.`);
  if (gate === 'review') trySh('gh', ['pr', 'ready', String(st.pr), '-R', cfg.repo]);
  for (const r of res.output.replies ?? []) {
    trySh('gh', ['api', '-X', 'POST', `repos/${cfg.repo}/pulls/${st.pr}/comments/${r.thread}/replies`, '--input', '-'], { input: JSON.stringify({ body: `${r.body}\n\n${MARK}` }) });
  }
  const board = hasBoard(st) ? `\n\n![board](${raw(cfg, sha, boardOf(st))})` : '';
  const qs = st.questions.length ? `\n\n**Open questions**\n${st.questions.map((q) => `- ${q}`).join('\n')}` : '';
  st.gate = gate;
  st.gateAt = comment(cfg, st.issue, `${icon} **${head}**: #${st.pr}\n\n${st.summary}${pageLine(reviewUrl(cfg, st))}${board}${qs}\n\n${ask}\n\n<sub>${usageLine(st.runs)}</sub>`);
  st.next = null;
  setStatus(cfg, st, 'waiting');
  await push(cfg, { title: `#${st.issue} ${head}: ${st.title}`, message: `${st.summary}\n\n${usageLine(st.runs)}`, tags: [tag], priority: 4, click: st.url });
}

async function stopped(cfg, st, phase, reply, res) {
  st.gate = 'failed';
  st.next = null;
  if (res.limited) {
    st.waitUntil = res.resetsAt ? res.resetsAt * 1000 : Date.now() + 3600e3;
    st.resume = { phase, reply };
    const at = new Date(st.waitUntil).toLocaleString('en-GB', { timeZone: cfg.timeZone, dateStyle: 'short', timeStyle: 'short' });
    st.gateAt = comment(cfg, st.issue, `⏸ **Usage limit reached** during \`${phase}\`. It picks up again at ${at}, from its files.\n\n<sub>${usageLine(st.runs)}</sub>`);
    setStatus(cfg, st, 'waiting');
    return push(cfg, { title: `#${st.issue} paused until ${at}`, message: `Usage limit reached during ${phase}. ${usageLine(st.runs)}`, tags: ['hourglass'], click: st.url });
  }
  st.resume = { phase, reply };
  st.gateAt = comment(cfg, st.issue, `⚠️ **Stopped** during \`${phase}\`:\n\n\`\`\`\n${res.why}\n\`\`\`\n\nReply **retry** to run it again, or write how to go on. Log: \`${res.run.log}\`\n\n<sub>${usageLine(st.runs)}</sub>`);
  setStatus(cfg, st, 'failed');
  await push(cfg, { title: `#${st.issue} failed: ${st.title}`, message: `${phase}: ${res.why.slice(0, 300)}`, tags: ['warning'], priority: 4, click: st.url });
}

const conflicted = (st) => git(st.worktree, 'diff', '--name-only', '--diff-filter=U');

async function merge(cfg, st, attempt = 0) {
  const wt = st.worktree;
  const fix = async (phase, detail) => {
    const res = await claude(st, phase, prompt(st, phase, detail));
    st.runs.push(res.run);
    save(st);
    if (!res.ok) { await stopped(cfg, st, 'merge', null, res); return false; }
    return true;
  };

  git(wt, 'fetch', '-q', 'origin', 'main');
  const behind = +git(wt, 'rev-list', '--count', 'HEAD..origin/main');
  if (behind) {
    if (trySh('git', ['merge', '--no-edit', '-q', 'origin/main'], { cwd: wt }) === null) {
      const files = conflicted(st);
      if (!files) return stopped(cfg, st, 'merge', null, { run: { log: '-' }, why: 'git merge origin/main failed without conflicts' });
      if (!(await fix('conflicts', files.split('\n').map((f) => `- ${f}`).join('\n')))) return;
      if (conflicted(st) || trySh('git', ['grep', '-nE', '^(<<<<<<<|>>>>>>>) ', '--', '.'], { cwd: wt })) {
        return stopped(cfg, st, 'merge', null, { run: { log: st.runs.at(-1).log }, why: 'conflict markers are still in the tree after the conflicts run' });
      }
      git(wt, 'add', '-A');
      git(wt, 'commit', '-q', '--no-edit');
    }
    // Main moved under the branch: CI's checks, here, before it lands.
    const check = async () => { try { await shAsync(join(wt, '.tool/check'), ['--all'], { cwd: wt, timeout: 3600e3 }); return null; } catch (e) { return `${e.stdout ?? ''}${e.stderr ?? ''}`.slice(-4000); } };
    let failure = await check();
    if (failure) {
      if (!(await fix('checks', failure))) return;
      commit(st, `${st.kind}(#${st.issue}): fix checks after merging main`);
      failure = await check();
      if (failure) return stopped(cfg, st, 'merge', null, { run: { log: st.runs.at(-1).log }, why: `.tool/check --all still fails:\n${failure}` });
    }
  }
  git(wt, 'push', '-q', 'origin', st.branch);
  syncPr(cfg, st, '**Merged.**');
  trySh('gh', ['pr', 'ready', String(st.pr), '-R', cfg.repo]);
  let merged;
  try {
    merged = ghJson(['api', '-X', 'PUT', `repos/${cfg.repo}/pulls/${st.pr}/merge`, '--input', '-'], JSON.stringify({
      merge_method: 'squash', commit_title: `${st.title} (#${st.pr})`, commit_message: `Closes #${st.issue}`,
    }));
  } catch (e) {
    if (attempt < 2) { await new Promise((r) => setTimeout(r, 10e3)); return merge(cfg, st, attempt + 1); } // main moved again
    return stopped(cfg, st, 'merge', null, { run: { log: '-' }, why: `GitHub refused the merge: ${e.stderr ?? e.message}` });
  }
  trySh('git', ['push', '-q', 'origin', '--delete', st.branch], { cwd: wt });
  const line = usageLine(st.runs);
  // An approved RFC goes on to its build: the next tick picks the issue up.
  let next = '';
  if (st.kind === 'research' && st.doc && existsSync(join(wt, st.doc))) {
    try {
      const url = implement(cfg, join(wt, st.doc), st.doc, { issue: st.issue, pr: st.pr });
      next = `\n\nIts build is queued as ${url}: the plan (or the board) comes there.`;
    } catch (e) {
      next = `\n\n⚠️ Couldn't open its build issue (${String(e.stderr || e.message).trim().slice(0, 300)}): run \`.tool/queue implement ${st.doc}\`.`;
    }
  }
  comment(cfg, st.issue, `🚀 **Merged** in ${merged.sha.slice(0, 7)} (#${st.pr}). Pushing to main deploys it.${next}\n\n### Usage\n\n${usageTable(st.runs)}`);
  trySh('gh', ['issue', 'close', String(st.issue), '-R', cfg.repo]);
  st.next = null;
  st.gate = null;
  setStatus(cfg, st, 'done');
  removeWorktree(st);
  await push(cfg, { title: `#${st.issue} merged: ${st.title}`, message: `Issue closed. ${line}`, tags: ['rocket'], priority: 4, click: `https://github.com/${cfg.repo}/pull/${st.pr}` });
}

// ---------------------------------------------------------------- RFC → build

// The `create` issue that builds an RFC already on main. `file` is where to
// read it now, `rfc` its path in the repo. Returns the issue's URL.
function implement(cfg, file, rfc, from = {}, dry = false) {
  const h1 = readFileSync(file, 'utf8').match(/^# (.+)$/m)?.[1]?.trim();
  const title = `Implement: ${(h1 ?? slugOf(rfc)).replace(/^RFC:\s*/i, '')}`.slice(0, 120);
  const source = from.issue ? `, approved in #${from.issue} and merged in #${from.pr}` : '';
  const body = `Build what the RFC [${rfc}](https://github.com/${cfg.repo}/blob/main/${rfc}) recommends${source}.

- Read it as the research (see "From an RFC" in the /create skill): what it recommends, in its priority order, and its Rollout are the spec.
- A \`> **Decision**\` note in it is binding; every other decision takes the option marked *(recommended)*.
- The plan (or the board, if it changes what the person sees) says which rollout phases this PR ships, Phase 0 first.`;
  if (dry) return console.log(`title:  ${title}\nlabel:  create\nbody:\n${body}`);
  return gh(['issue', 'create', '-R', cfg.repo, '--title', title, '--label', 'create', '--body-file', '-'], body);
}

function implementCli() {
  const [rfc] = rest.filter((a) => !a.startsWith('--'));
  if (!rfc) fail('usage: .tool/queue implement <product/research/…/README.md> [--dry-run]');
  const file = resolve(root, rfc);
  if (!existsSync(file)) fail(`${rfc}: no such file`);
  const path = posix.normalize(rfc.replace(/^\.\//, ''));
  const dry = rest.includes('--dry-run');
  // The build's worktree starts from origin/main: the RFC must be there.
  if (!dry && trySh('git', ['cat-file', '-e', `origin/main:${path}`]) === null) fail(`${path} is not on origin/main yet: merge the RFC first.`);
  const url = implement(config(), file, path, {}, dry);
  if (url) console.log(`✓ ${url}`);
}

// ---------------------------------------------------------------- the loop

async function tick(cfg) {
  const open = ghJson(['issue', 'list', '-R', cfg.repo, '--state', 'open', '--author', cfg.owner, '--limit', '100', '--json', 'number,title,body,url,labels']);
  for (const issue of open) {
    const kind = issue.labels.map((l) => l.name).find((l) => KINDS.includes(l));
    if (!kind) continue;
    let st = load(issue.number);
    if (!st) {
      const branch = `queue/${issue.number}-${slugify(issue.title)}`;
      st = { issue: issue.number, kind, title: issue.title, body: issue.body, url: issue.url, branch,
        worktree: join(cfg.worktrees, basename(branch)), runs: [], next: { phase: FIRST[kind] } };
      save(st);
      react(cfg, `issues/${st.issue}`);
      log(`#${st.issue} queued (${kind})`);
      continue;
    }
    if (st.status === 'done' || st.next) continue;
    if (st.waitUntil) {
      if (Date.now() < st.waitUntil) continue;
      st.next = st.resume; st.waitUntil = null; save(st);
      continue;
    }
    if (!st.gateAt) continue;
    const new_ = answers(cfg, st);
    if (!new_.length) continue;
    for (const c of new_) if (c.kind !== 'review') react(cfg, `${c.kind === 'line' ? 'pulls' : 'issues'}/comments/${c.id}`);
    const text = feedback(new_);
    const approved = approves(new_);
    if (st.status === 'failed') {
      const retry = new_.every((c) => c.kind !== 'line' && (RETRY.test(c.body) || isApproval(c.body)));
      st.next = { phase: st.resume.phase, reply: retry ? st.resume.reply : [st.resume.reply, text].filter(Boolean).join('\n\n') };
    } else {
      st.next = { phase: NEXT[st.gate][approved ? 'approve' : 'feedback'], reply: approved ? null : text };
    }
    save(st);
    log(`#${st.issue} answered: ${st.next.phase}`);
  }
  // Fill the free slots: merges first, then whatever was asked first. The
  // jobs go on in the background; the next passes keep reading the answers.
  const ready = states().filter((s) => s.next && !running.has(s.issue) && open.some((i) => i.number === s.issue))
    .sort((a, b) => (b.next.phase === 'merge') - (a.next.phase === 'merge') || a.issue - b.issue);
  for (const st of ready) {
    if (running.size >= JOBS) break;
    if (st.next.phase === 'merge' && [...running.values()].includes('merge')) continue;
    const { phase, reply } = st.next;
    running.set(st.issue, phase);
    work(cfg, st)
      // git, gh or the network, not the model: stop at a gate rather than loop on it.
      .catch((e) => stopped(cfg, st, phase, reply, { run: { log: join(home, 'daemon.log') }, why: String(e.stderr || e.message).slice(-1500) }))
      .catch((e) => log(`#${st.issue} failed to stop:`, e.stderr || e.message))
      .finally(() => running.delete(st.issue));
  }
}

const idle = async () => { while (running.size) await new Promise((r) => setTimeout(r, 5e3)); };

// ---------------------------------------------------------------- the runner

export const runnerDir = (cfg) => join(cfg.worktrees, '.runner');
export const isRunner = (cfg) => existsSync(runnerDir(cfg)) && realpathSync(runnerDir(cfg)) === realpathSync(root);

// The worktree the LaunchAgent runs from, detached at origin/main's tip.
// Nobody edits it, so a forced checkout loses nothing.
export function syncRunner(cfg) {
  const dir = runnerDir(cfg);
  sh('git', ['fetch', '-q', 'origin', 'main'], { cwd: checkout });
  if (!existsSync(dir)) sh('git', ['worktree', 'add', '-q', '--detach', dir, 'origin/main'], { cwd: checkout });
  else sh('git', ['checkout', '-q', '-f', '--detach', 'origin/main'], { cwd: dir });
  return dir;
}

// ---------------------------------------------------------------- the handover

// Moving the LaunchAgent onto the runner needs no person: `adopt` starts a
// handover whenever launchd runs another queue.mjs (from `run`, or by hand),
// and it waits for main to have the runner, so it can start before the PR
// that brings it is merged. It is a job of its own: launchd kills whatever a
// job leaves behind when it exits, detached or not, so a child of the queue
// would die with the queue it replaces. launchd starts it again if it fails
// and after a restart, until it unloads itself.
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const alive = (pid) => { try { return !!pid && process.kill(pid, 0); } catch { return false; } };
const HELPER = `${AGENT}-handover`;
const helperPlist = join(homedir(), 'Library', 'LaunchAgents', `${HELPER}.plist`);
const READY = 'async function handover(';

// What launchd has loaded under a label: its pid, node and the queue.mjs it runs.
function jobOf(label) {
  const out = trySh('launchctl', ['print', `gui/${uid()}/${label}`]);
  if (!out) return null;
  const args = out.match(/\n\targuments = \{\n([^}]*)\}/)?.[1].split('\n').map((l) => l.trim()).filter(Boolean) ?? [];
  return { pid: +(out.match(/\n\tpid = (\d+)/)?.[1] ?? 0), node: args[0], script: args.find((a) => a.endsWith('queue.mjs')) };
}

// Quiet and quick, and a no-op once the queue runs from the runner.
function adopt() {
  if (process.platform !== 'darwin' || !existsSync(configPath)) return;
  const job = jobOf(AGENT); // not loaded: stopped on purpose, or not set up
  if (!job || job.script === join(runnerDir(config()), '.tool/queue.mjs')) return;
  if (jobOf(HELPER)) return; // one is going: launchd restarts it if it fails
  // A copy: the worktree this one runs from is removed when its PR merges.
  const script = join(home, 'handover.mjs');
  copyFileSync(fileURLToPath(import.meta.url), script);
  const env = { PATH: process.env.PATH, ...(process.env.QUEUE_AGENT && { QUEUE_AGENT: AGENT }) };
  writeFileSync(helperPlist, plist({ label: HELPER, args: [process.execPath, script, 'handover'], cwd: checkout, env, keepAlive: false }));
  trySh('launchctl', ['bootout', `gui/${uid()}/${HELPER}`]);
  // A fresh log: launchd refuses (EX_CONFIG) an output file it can't open,
  // such as one a sandboxed session created, and the job never starts.
  rmSync(join(home, 'handover.log'), { force: true });
  sh('launchctl', ['bootstrap', `gui/${uid()}`, helperPlist]);
  sh('launchctl', ['kickstart', `gui/${uid()}/${HELPER}`]);
  console.log(`✓ handover started (${join(home, 'handover.log')})`);
}

async function handover() {
  const cfg = config();
  const runnerScript = join(runnerDir(cfg), '.tool/queue.mjs');
  const ready = () => trySh('git', ['fetch', '-q', 'origin', 'main'], { cwd: checkout }) !== null
    && (trySh('git', ['show', 'origin/main:.tool/queue.mjs'], { cwd: checkout }) ?? '').includes(READY);
  for (let tries = 0; !ready(); tries++) {
    if (tries === 0) log('handover: waiting for origin/main to have the runner');
    await sleep(120e3);
  }
  syncRunner(cfg);
  // Main's handover does the switch, not this copy, which may be older.
  if (resolve(here, 'queue.mjs') !== runnerScript) {
    return new Promise((r) => spawn(process.execPath, [runnerScript, 'handover'], { cwd: checkout, stdio: 'inherit' }).on('exit', (code) => r(process.exit(code ?? 1))));
  }
  const job = jobOf(AGENT);
  if (job && job.script !== runnerScript) {
    // The lock makes the copy launchd starts again exit at once ("Another
    // .tool/queue run is going"); a newer mtime on its script ends the
    // running one after its pass, so no run is cut off.
    writeFileSync(join(home, 'lock'), String(process.pid));
    if (alive(job.pid)) {
      if (job.script && existsSync(job.script)) utimesSync(job.script, new Date(), new Date());
      log(`handover: waiting for ${job.pid} (${job.script}) to finish its pass`);
      while (alive(job.pid)) await sleep(2e3);
    }
    const old = existsSync(plistPath) ? readFileSync(plistPath, 'utf8') : '';
    const path = old.match(/<key>PATH<\/key><string>([^<]*)<\/string>/)?.[1].replace(/&lt;/g, '<').replace(/&amp;/g, '&');
    writeQueuePlist(runnerDir(cfg), job.node ?? process.execPath, path ?? process.env.PATH);
    rmSync(join(home, 'lock'), { force: true });
    start();
    log(`handover: ✓ the LaunchAgent runs ${runnerScript} (${git(runnerDir(cfg), 'rev-parse', '--short', 'HEAD')})`);
    await push(cfg, { title: 'My Own App queue moved to its runner', message: 'From now on it runs what is merged into main.', tags: ['white_check_mark'] });
  } else log(job ? 'handover: ✓ already on the runner' : 'handover: the LaunchAgent is not loaded, nothing to move');
  // Done for good. Unloading this job ends this process, so it goes last.
  rmSync(helperPlist, { force: true });
  rmSync(join(home, 'handover.mjs'), { force: true });
  trySh('launchctl', ['bootout', `gui/${uid()}/${HELPER}`]);
}

function locked() {
  const lock = join(home, 'lock');
  const pid = existsSync(lock) && +readFileSync(lock, 'utf8');
  if (pid && pid !== process.pid && trySh('kill', ['-0', String(pid)]) !== null) return true;
  writeFileSync(lock, String(process.pid));
  return false;
}

// The queue merges through GitHub, so nothing pulls the checkout it runs
// from: fast-forward it to origin/main after each pass, so what was merged is
// what runs (the mtime check in loop then restarts it). Only on main with a
// clean tree: work in progress is never touched, and then it just waits.
// It matters only until the handover: the runner is detached, so a no-op there.
function pullCheckout() {
  if (trySh('git', ['symbolic-ref', '--short', 'HEAD']) !== 'main' || trySh('git', ['status', '--porcelain'])) return;
  if (trySh('git', ['fetch', '-q', 'origin', 'main']) === null) return;
  if (trySh('git', ['merge', '-q', '--ff-only', 'origin/main']) === null) log('checkout: main has diverged from origin/main, not pulled');
}

async function loop(once) {
  const loaded = statSync(fileURLToPath(import.meta.url)).mtimeMs;
  const cfg = config();
  if (locked()) fail('Another .tool/queue run is going.');
  const runner = isRunner(cfg);
  if (!once && !runner) { log(`running from ${root}, not ${runnerDir(cfg)}: handing over`); adopt(); }
  for (;;) {
    const edited = statSync(fileURLToPath(import.meta.url)).mtimeMs !== loaded;
    // An edited queue.mjs starts no job: it takes over once the running ones end.
    if (!edited) try { await tick(cfg); } catch (e) { log('tick failed:', e.stderr || e.message); }
    if (once) return idle();
    // Main's tip, so a merged queue.mjs takes over at the check below.
    if (runner) try { syncRunner(cfg); } catch (e) { log('runner sync failed:', e.stderr || e.message); }
    pullCheckout();
    // An edited queue.mjs takes over at the next pass with nothing running:
    // the restart kills every child of the job.
    if (statSync(fileURLToPath(import.meta.url)).mtimeMs !== loaded && !running.size) {
      // Not by exiting: launchd defers a KeepAlive job that exited cleanly ("inefficient").
      log('queue.mjs changed: restarting');
      // The lock only if it is ours: a handover holds it so the copy launchd
      // starts again exits at once, until it has moved the LaunchAgent.
      const lock = join(home, 'lock');
      if (existsSync(lock) && +readFileSync(lock, 'utf8') === process.pid) rmSync(lock, { force: true });
      if (trySh('launchctl', ['kickstart', '-k', `gui/${process.getuid()}/${AGENT}`]) !== null) await new Promise(() => {}); // killed by it
      return;
    }
    await new Promise((r) => setTimeout(r, 60e3));
  }
}

// ---------------------------------------------------------------- setup

const LABELS = [
  ['create', '1f883d', 'Queue: design, approve, build, approve, merge'],
  ['research', '0969da', 'Queue: an RFC under product/research, then its build'],
  ['improve', '8250df', 'Queue: an /improve run'],
  ['agent:working', 'fbca04', 'The queue is working on it'],
  ['agent:waiting', 'd93f0b', 'Waiting for your reply'],
  ['agent:failed', 'b60205', 'Stopped: reply retry, or how to go on'],
  ['agent:done', 'cccccc', 'Merged by the queue'],
];

async function setup() {
  const old = readJson(configPath, {});
  const repo = ghJson(['repo', 'view', '--json', 'nameWithOwner']).nameWithOwner;
  const cfg = {
    repo,
    owner: gh(['api', 'user', '--jq', '.login']),
    // QUEUE_TOPIC shares one ntfy topic across apps (the setup CLI passes it).
    topic: old.topic ?? process.env.QUEUE_TOPIC ?? `my-own-app-${randomBytes(12).toString('hex')}`,
    worktrees: old.worktrees ?? resolve(root, '..', `${basename(root)}-queue`),
    timeZone: Intl.DateTimeFormat().resolvedOptions().timeZone,
  };
  writeJson(configPath, cfg);
  for (const [name, color, description] of LABELS) gh(['label', 'create', name, '-R', repo, '--color', color, '--description', description, '--force']);
  // Pages built by Actions, for the review page (.github/workflows/review-page.yml).
  const pages = trySh('gh', ['api', `repos/${repo}/pages`, '--jq', '.html_url'])
    ?? trySh('gh', ['api', '-X', 'POST', `repos/${repo}/pages`, '-f', 'build_type=workflow', '--jq', '.html_url']);

  const runner = syncRunner(cfg);
  writeQueuePlist(runner, process.execPath, process.env.PATH);
  start();
  await push(cfg, { title: 'My Own App queue is on', message: `Watching ${repo} for issues labelled ${KINDS.join(', ')}.`, tags: ['white_check_mark'], click: `https://github.com/${repo}/issues` });
  console.log(`✓ labels on ${repo}, LaunchAgent ${AGENT} loaded, test push sent
  ✓ runs from ${runner}, at origin/main (${git(runner, 'rev-parse', '--short', 'HEAD')}), moved to its tip every pass
  ${pages ? `✓ review page: ${pages}review.html (live after the next push to main or a queue/* branch touching it, or: gh workflow run review-page.yml)` : '✗ GitHub Pages could not be turned on: Settings → Pages → Source: GitHub Actions'}
  phone: install ntfy (App Store / Play Store), tap +, topic ${cfg.topic}, server ntfy.sh
         (or open https://ntfy.sh/${cfg.topic} on the phone)
  then open an issue with the "Create" template and watch for the 👀`);
}

function writeQueuePlist(runner, node, path) {
  mkdirSync(dirname(plistPath), { recursive: true });
  writeFileSync(plistPath, plist({ label: AGENT, args: [node, join(runner, '.tool/queue.mjs'), 'run'], cwd: runner, env: { PATH: path }, keepAlive: true }));
}

function plist({ label, args, cwd, env, keepAlive }) {
  const xml = (s) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;');
  const out = join(home, keepAlive ? 'daemon.log' : 'handover.log');
  return `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>${label}</string>
  <key>ProgramArguments</key><array>${args.map((a) => `<string>${xml(a)}</string>`).join('')}</array>
  <key>WorkingDirectory</key><string>${xml(cwd)}</string>
  <key>EnvironmentVariables</key><dict>${Object.entries(env).map(([k, v]) => `<key>${k}</key><string>${xml(v)}</string>`).join('')}</dict>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key>${keepAlive ? '<true/>' : '<dict><key>SuccessfulExit</key><false/></dict>'}
  <key>ThrottleInterval</key><integer>60</integer>
  <key>StandardOutPath</key><string>${xml(out)}</string>
  <key>StandardErrorPath</key><string>${xml(out)}</string>
</dict></plist>
`;
}

const uid = () => process.getuid();
function start() {
  trySh('launchctl', ['bootout', `gui/${uid()}/${AGENT}`]);
  sh('launchctl', ['bootstrap', `gui/${uid()}`, plistPath]);
  // A KeepAlive job's first spawn is "speculative": launchd may hold it off.
  sh('launchctl', ['kickstart', `gui/${uid()}/${AGENT}`]);
}
function stop() {
  trySh('launchctl', ['bootout', `gui/${uid()}/${AGENT}`]);
  console.log(`✓ ${AGENT} unloaded`);
}

function ls() {
  const cfg = config();
  const at = (ref, cwd) => trySh('git', ['rev-parse', '--short', ref], { cwd }) ?? '?';
  const dir = runnerDir(cfg);
  const plist = existsSync(plistPath) ? readFileSync(plistPath, 'utf8') : '';
  console.log(jobOf(HELPER) ? `… handover waiting to move the LaunchAgent onto ${dir} (${join(home, 'handover.log')})`
    : !existsSync(dir) ? '✗ no runner: run .tool/queue adopt (or setup)'
    : !plist.includes(dir) ? `✗ the LaunchAgent doesn't run from ${dir} yet: it hands over on its own (${join(home, 'handover.log')}), or run .tool/queue adopt`
    : `✓ runner at ${at('HEAD', dir)} (origin/main ${at('origin/main')})`);
  const all = states().sort((a, b) => a.issue - b.issue);
  if (!all.length) return console.log('  nothing yet');
  for (const s of all) {
    const where = s.next && s.status === 'working' && s.since ? `running: ${s.next.phase} (${fmtMin(Date.now() - s.since)})`
      : s.next ? `next: ${s.next.phase}` : s.waitUntil ? `paused until ${new Date(s.waitUntil).toLocaleTimeString()}` : s.status === 'waiting' ? `waiting on you (${s.gate})` : s.status;
    console.log(`#${s.issue}  ${s.kind.padEnd(8)} ${where.padEnd(26)} ${s.pr ? `PR #${s.pr}  ` : ''}${s.title}`);
    if (s.runs.length) console.log(`      ${usageLine(s.runs)}`);
  }
}

function tail(n) {
  const st = load(n) ?? fail(`#${n}: not in the queue`);
  const last = st.runs.at(-1)?.log;
  if (!last || !existsSync(last)) return console.log('  no run yet');
  const lines = readFileSync(last, 'utf8').trim().split('\n').slice(-400);
  for (const line of lines) {
    let ev; try { ev = JSON.parse(line); } catch { continue; }
    for (const c of ev.message?.content ?? []) {
      if (c.type === 'text' && c.text.trim()) console.log(`  ${ev.type === 'assistant' ? '◆' : '·'} ${c.text.trim().split('\n')[0].slice(0, 160)}`);
      if (c.type === 'tool_use') console.log(`  → ${c.name} ${JSON.stringify(c.input).slice(0, 140)}`);
    }
    if (ev.type === 'result') console.log(`  = ${ev.subtype}, ${ev.num_turns} turns`);
  }
  console.log(`  ${last}`);
}

const [command, ...rest] = process.argv.slice(2);
// Run as a command, not imported (by a test of the functions it exports).
const main = !!process.argv[1] && realpathSync(process.argv[1]) === realpathSync(fileURLToPath(import.meta.url));
const commands = { setup, adopt, handover, run: () => loop(false), tick: () => loop(true), ls, log: () => tail(rest[0]), implement: implementCli, stop, start: () => { start(); console.log(`✓ ${AGENT} loaded`); } };
if (main && !commands[command]) fail('usage: .tool/queue setup | run | tick | ls | log <issue> | implement <rfc> [--dry-run] | stop | start | adopt');
if (main) await commands[command]();
