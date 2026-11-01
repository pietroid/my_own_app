#!/usr/bin/env node
// Serves a Markdown file as a page you can comment on. Each comment is
// written back into the file as a tagged blockquote under the block it is
// about (`> **Q:** …`), so the notes live in the Markdown and in git.
//
//   node .tool/annotate.mjs product/research/<file>.md [port]
//
// The page follows the file: edit it anywhere (VS Code, Claude) and it redraws.
// Usually started by `.tool/doc open`, which reuses a running server. With no
// request for IDLE_MINUTES (the page polls every 2 s), the server exits.
import { createServer } from 'node:http';
import { existsSync, readFileSync, writeFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { basename, dirname, extname, resolve, sep } from 'node:path';

const file = process.argv[2] && resolve(process.argv[2]);
const port = Number(process.argv[3] ?? 4321);
if (!file || !existsSync(file)) {
  console.error('usage: node .tool/annotate.mjs <file.md> [port]');
  process.exit(1);
}

const IDLE_MINUTES = 20;
const KINDS = ['Q', 'Learn', 'Decision', 'Note'];
const NOTE = /^> \*\*(Q|A|Learn|Decision|Note)\b/;

const read = () => readFileSync(file, 'utf8');
const versionOf = (text) => createHash('sha1').update(text).digest('hex').slice(0, 12);

// A block is a run of non-blank lines; a fenced code block stays one block
// even with blank lines inside it. Line indexes, end exclusive.
function blocksOf(lines) {
  const blocks = [];
  let start = -1;
  let fence = null;
  for (let i = 0; i < lines.length; i++) {
    const marker = lines[i].match(/^\s*(```|~~~)/)?.[1];
    if (fence) {
      if (marker === fence) fence = null;
      continue;
    }
    if (marker) {
      if (start < 0) start = i;
      fence = marker;
    } else if (lines[i].trim() === '') {
      if (start >= 0) blocks.push({ start, end: i });
      start = -1;
    } else if (start < 0) {
      start = i;
    }
  }
  if (start >= 0) blocks.push({ start, end: lines.length });
  return blocks;
}

function doc() {
  const text = read();
  const lines = text.split('\n');
  return {
    name: basename(file),
    path: file,
    version: versionOf(text),
    blocks: blocksOf(lines).map(({ start, end }) => lines.slice(start, end).join('\n')),
  };
}

function noteLines({ kind, text, quote }) {
  const tag = kind === 'Decision' ? `Decision (${new Date().toLocaleDateString('sv-SE')})` : kind;
  const body = text.trim().split('\n');
  if (quote) body[0] = `_“${quote.trim().replace(/\s+/g, ' ')}”_ — ${body[0]}`;
  return body.map((line, i) => (i === 0 ? `> **${tag}:** ${line}` : `> ${line}`));
}

// The note goes under the block, after the notes already under it.
function addNote({ version, block, kind, text, quote }) {
  const current = read();
  if (versionOf(current) !== version) return { status: 409 };
  if (!KINDS.includes(kind) || !text?.trim()) return { status: 400 };
  const lines = current.split('\n');
  const blocks = blocksOf(lines);
  if (!blocks[block]) return { status: 400 };
  let after = block;
  while (blocks[after + 1] && NOTE.test(lines[blocks[after + 1].start])) after++;
  lines.splice(blocks[after].end, 0, '', ...noteLines({ kind, text, quote }));
  writeFileSync(file, lines.join('\n'));
  return { status: 200 };
}

function send(res, status, body, type = 'application/json') {
  res.writeHead(status, { 'content-type': `${type}; charset=utf-8` });
  res.end(type === 'application/json' ? JSON.stringify(body) : body);
}

// What sits next to the Markdown (img/, data/, board.json) is served as is,
// so the images the document points at show. Nothing outside its folder.
const TYPES = {
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.gif': 'image/gif',
  '.svg': 'image/svg+xml',
  '.webp': 'image/webp',
  '.json': 'application/json',
  '.md': 'text/markdown; charset=utf-8',
  '.txt': 'text/plain; charset=utf-8',
};
const root = dirname(file);

// The deck's look and its script (slides, diagrams, callouts) come from the
// review page, so a doc reads the same here as on the phone.
const review = readFileSync(new URL('./review.html', import.meta.url), 'utf8');
const DECK = [
  review.match(/<link rel="preconnect"[^>]*>\s*<link [^>]*fonts[^>]*>/)[0],
  review.match(/<script src="[^"]*marked[^"]*"><\/script>/)[0],
  review.match(/<style id="deck">[\s\S]*?<\/style>/)[0],
  review.match(/<script id="deck">[\s\S]*?<\/script>/)[0],
].join('\n');

function serveFile(url, res) {
  let path;
  try {
    path = resolve(root, '.' + decodeURIComponent(url.split('?')[0]));
  } catch {
    return false;
  }
  const type = TYPES[extname(path).toLowerCase()];
  if (!type || !path.startsWith(root + sep) || !existsSync(path)) return false;
  res.writeHead(200, { 'content-type': type });
  res.end(readFileSync(path));
  return true;
}

let lastSeen = Date.now();
setInterval(() => {
  if (Date.now() - lastSeen > IDLE_MINUTES * 60_000) process.exit(0);
}, 60_000).unref();

createServer((req, res) => {
  lastSeen = Date.now();
  if (req.method === 'GET' && req.url === '/') return send(res, 200, PAGE, 'text/html');
  if (req.method === 'GET' && req.url === '/doc') return send(res, 200, doc());
  if (req.method === 'POST' && req.url === '/note') {
    let body = '';
    req.on('data', (chunk) => (body += chunk));
    req.on('end', () => {
      let result;
      try {
        result = addNote(JSON.parse(body));
      } catch {
        result = { status: 400 };
      }
      send(res, result.status, doc());
    });
    return;
  }
  if (req.method === 'GET' && serveFile(req.url, res)) return;
  send(res, 404, { error: 'not found' });
}).listen(port, '127.0.0.1', () => {
  console.log(`${basename(file)} → http://localhost:${port}`);
});

const PAGE = /* html */ `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Annotate</title>
${DECK}
<style>
  * { box-sizing: border-box; }
  header { position: sticky; top: 0; z-index: 2; background: rgba(0, 0, 0, .82); backdrop-filter: blur(12px);
           padding: 12px 18px; display: flex; gap: 12px; align-items: baseline; font-size: 14px; color: var(--ink2); }
  header b { color: var(--ink); font-weight: 500; }
  #counts { margin-left: auto; display: flex; gap: 10px; }
  .block { position: relative; border-radius: 14px; padding: 1px 10px; margin: 0 -10px; }
  .block:hover { background: rgba(255, 255, 255, .03); }
  .block > :first-child { margin-top: 4px; }
  .block > :last-child { margin-bottom: 4px; }
  .add { position: absolute; left: -40px; top: 6px; width: 26px; height: 26px; border: 0;
         border-radius: 50%; background: var(--fill); color: var(--ink2); font: 18px/26px Onest, sans-serif;
         cursor: pointer; opacity: 0; }
  .block:hover .add { opacity: 1; }
  .add:hover { background: var(--accent); color: var(--on-accent); }
  .composer { margin: 6px 0 14px; padding: 12px; border-radius: 14px; background: var(--fill); }
  .composer .quote { font-size: 14px; color: var(--ink2); font-style: italic; margin-bottom: 8px; }
  .kinds { display: flex; gap: 6px; margin-bottom: 8px; }
  .kinds button, .actions button { border: 0; border-radius: 999px; padding: 5px 13px; cursor: pointer;
         font: 500 13px Onest, sans-serif; background: var(--fill2); color: var(--ink2); }
  .kinds button.on { background: var(--accent); color: var(--on-accent); }
  textarea { width: 100%; min-height: 70px; border: 0; border-radius: 12px; padding: 8px 10px;
             background: var(--bg); color: var(--ink); font: 15px/1.5 Onest, sans-serif; resize: vertical; }
  .actions { display: flex; gap: 6px; justify-content: flex-end; margin-top: 8px; align-items: center; }
  .actions span { margin-right: auto; font-size: 12px; color: var(--ink2); }
  .actions .save { background: var(--accent); color: var(--on-accent); }
  @media (max-width: 860px) { .add { left: auto; right: 6px; opacity: .6; } }
</style>
</head>
<body>
<header><b id="name"></b><span id="counts"></span></header>
<main id="doc" class="deck"></main>
<script>
const KINDS = ['Q', 'Learn', 'Decision', 'Note'];
let state = null;
let composing = null;

const noteKind = (text) => text.match(/^> \\*\\*(Q|A|Learn|Decision|Note)\\b/)?.[1];

function render() {
  document.getElementById('name').textContent = state.name;
  document.title = state.name;
  const counts = {};
  const main = document.getElementById('doc');
  main.innerHTML = '';
  state.blocks.forEach((text, i) => {
    const el = document.createElement('section');
    const kind = noteKind(text);
    el.className = 'block' + (kind ? ' note note-' + kind : '');
    if (kind) counts[kind] = (counts[kind] ?? 0) + 1;
    el.innerHTML = marked.parse(text);
    const add = document.createElement('button');
    add.className = 'add';
    add.textContent = '+';
    add.title = 'Comment on this block';
    add.onclick = () => compose(i, '');
    el.prepend(add);
    el.dataset.i = i;
    deckSlide(main, text).append(el);
  });
  deckNumber(main);
  deckFinish(main);
  document.getElementById('counts').textContent =
    Object.entries(counts).map(([k, n]) => k + ' ' + n).join(' · ');
  if (composing) drawComposer();
}

function compose(block, quote) {
  composing = { block, quote, kind: composing?.kind ?? 'Q', text: '' };
  render();
}

function drawComposer() {
  const host = document.querySelector('.block[data-i="' + composing.block + '"]');
  const box = document.createElement('div');
  box.className = 'composer';
  if (composing.quote) {
    const q = document.createElement('div');
    q.className = 'quote';
    q.textContent = '“' + composing.quote + '”';
    box.append(q);
  }
  const kinds = document.createElement('div');
  kinds.className = 'kinds';
  KINDS.forEach((k) => {
    const b = document.createElement('button');
    b.textContent = k;
    b.className = k === composing.kind ? 'on' : '';
    b.onclick = () => { composing.kind = k; render(); };
    kinds.append(b);
  });
  const area = document.createElement('textarea');
  area.value = composing.text;
  area.placeholder = 'Write a question, what you learned, or a decision…';
  area.oninput = () => (composing.text = area.value);
  area.onkeydown = (e) => {
    if (e.key === 'Enter' && (e.metaKey || e.ctrlKey)) save();
    if (e.key === 'Escape') { composing = null; render(); }
  };
  const actions = document.createElement('div');
  actions.className = 'actions';
  actions.innerHTML = '<span>⌘↵ save · esc cancel</span>';
  const cancel = document.createElement('button');
  cancel.textContent = 'Cancel';
  cancel.onclick = () => { composing = null; render(); };
  const ok = document.createElement('button');
  ok.textContent = 'Save';
  ok.className = 'save';
  ok.onclick = save;
  actions.append(cancel, ok);
  box.append(kinds, area, actions);
  host.after(box);
  area.focus();
}

async function save() {
  if (!composing.text.trim()) return;
  const res = await fetch('/note', {
    method: 'POST',
    body: JSON.stringify({ version: state.version, ...composing }),
  });
  const next = await res.json();
  if (res.status === 409) {
    alert('The file changed since this page drew it. It has been reloaded; your text is kept, save again.');
    state = next;
    render();
    return;
  }
  composing = null;
  state = next;
  render();
}

// Selecting text in a block opens a comment quoting it.
document.addEventListener('mouseup', (e) => {
  if (e.target.closest('.composer')) return;
  const sel = window.getSelection();
  const quote = sel.toString().trim();
  if (!quote) return;
  const block = sel.anchorNode?.parentElement?.closest('.block');
  if (block) compose(Number(block.dataset.i), quote);
});

async function poll() {
  try {
    const next = await (await fetch('/doc')).json();
    // While a comment is open the page keeps the version it drew, so a
    // change underneath is caught on save (409) rather than misplaced.
    if (!composing && (!state || next.version !== state.version)) {
      state = next;
      render();
    }
  } catch {}
}
poll();
setInterval(poll, 2000);
</script>
</body>
</html>`;
