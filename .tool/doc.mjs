#!/usr/bin/env node
// The way into the Markdown under product/: list it, open one in the
// annotate page, print only the notes left on it, check an RFC's shape
// as a deck, or photograph its slides.
//
//   .tool/doc ls [words]            docs, newest first, with open questions
//   .tool/doc open [file|words]     serve it with annotate.mjs and open the browser
//   .tool/doc notes [file|words]    the notes alone, with line and heading
//         [--open]                  only questions nobody answered yet
//   .tool/doc shape [file|words]    a row per slide: words, visual, ✓/✗ against the
//                                   budget; then the headings alone, the storyline
//   .tool/doc shot [file|words]     each slide as the review page draws it, a PNG at
//         [--out dir] [--slides 1,3]  phone width (headless Chrome); diagram errors
//
// A doc is named by its path, or by words that all appear in its path
// ("agent reliab"); a folder's README.md wins over the files beside it,
// then the newest match. No name means the newest doc.
import { spawn, execFileSync } from 'node:child_process';
import { existsSync, readdirSync, readFileSync, statSync, writeFileSync, mkdirSync } from 'node:fs';
import { createServer } from 'node:net';
import { createServer as createHttpServer } from 'node:http';
import { createHash } from 'node:crypto';
import { tmpdir } from 'node:os';
import { dirname, extname, join, relative, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const root = resolve(here, '..');
const docsDir = join(root, 'product');
const NOTE = /^> \*\*(Q|A|Learn|Decision|Note)\b[^:]*:\*\* ?(.*)$/;

function docs() {
  const found = [];
  const walk = (dir) => {
    for (const entry of readdirSync(dir, { withFileTypes: true })) {
      const path = join(dir, entry.name);
      if (entry.isDirectory()) walk(path);
      else if (entry.name.endsWith('.md')) found.push({ path, mtime: statSync(path).mtimeMs });
    }
  };
  if (existsSync(docsDir)) walk(docsDir);
  return found.sort((a, b) => b.mtime - a.mtime);
}

function pick(args) {
  const name = args.filter((a) => !a.startsWith('--'));
  const direct = name.length === 1 && resolve(name[0]);
  if (direct && existsSync(direct) && statSync(direct).isFile()) return direct;
  const words = name.map((w) => w.toLowerCase());
  const hits = docs().filter(({ path }) => words.every((w) => relative(root, path).toLowerCase().includes(w)));
  const hit = hits.find(({ path }) => path.endsWith('/README.md')) ?? hits[0];
  if (!hit) fail(`no doc under product/ matches "${name.join(' ')}"`);
  return hit.path;
}

// Every note in the file, with the heading it sits under. A question is
// answered when an `A` note follows it before anything else does.
function notesOf(file) {
  const lines = readFileSync(file, 'utf8').split('\n');
  const notes = [];
  const trail = [];
  let fence = false;
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    if (/^\s*(```|~~~)/.test(line)) fence = !fence;
    if (fence) continue;
    const heading = line.match(/^(#{1,6})\s+(.*)/);
    if (heading) {
      trail.length = heading[1].length - 1;
      trail[heading[1].length - 1] = heading[2].trim();
      continue;
    }
    const note = line.match(NOTE);
    if (!note) continue;
    const body = [note[2]];
    while (lines[i + 1]?.startsWith('>') && !NOTE.test(lines[i + 1])) body.push(lines[++i].replace(/^> ?/, ''));
    notes.push({ line: i + 2 - body.length, kind: note[1], text: body.join('\n'), under: trail.filter(Boolean).slice(1).join(' › ') });
  }
  notes.forEach((n, k) => {
    if (n.kind !== 'Q') return;
    let j = k + 1;
    while (notes[j] && notes[j].kind !== 'A' && notes[j].kind !== 'Q') j++;
    n.answered = notes[j]?.kind === 'A';
  });
  return notes;
}

// An RFC is a deck: each heading a slide, each slide one point and one
// visual. Prints a row per slide, flags the ones over budget, then the
// headings alone, which should read as the whole story.
const SLIDE_WORDS = 150;
const HEADLINE_WORDS = 12;
const EXEMPT = /^(references|go deeper|decided unattended|the request)/i;

function slidesOf(file) {
  const lines = readFileSync(file, 'utf8').split('\n');
  const slides = [];
  let slide = null;
  let fence = null;
  let inNote = false;
  for (const line of lines) {
    const marker = line.match(/^\s*(```|~~~)\s*(\w*)/);
    if (fence) {
      if (marker?.[1] === fence) fence = null;
      continue;
    }
    if (marker) {
      fence = marker[1];
      if (slide) slide.visuals.push(marker[2] === 'mermaid' ? 'diagram' : 'code');
      continue;
    }
    const heading = line.match(/^(#{1,3})\s+(.*)/);
    if (heading) {
      slide = { level: heading[1].length, title: heading[2].trim(), words: 0, bullets: 0, visuals: [] };
      slides.push(slide);
      inNote = false;
      continue;
    }
    if (!slide) continue;
    if (NOTE.test(line)) inNote = true;
    else if (!line.startsWith('>')) inNote = false;
    if (inNote) continue;
    if (/^\s*\|/.test(line)) {
      if (slide.visuals.at(-1) !== 'table' || !slide.inTable) slide.visuals.push('table');
      slide.inTable = true;
      continue;
    }
    slide.inTable = false;
    if (/!\[[^\]]*\]\([^)]*\)|<img\b/.test(line)) slide.visuals.push('image');
    if (/^\s*([-*+]|\d+\.)\s/.test(line)) slide.bullets++;
    slide.words += line.replace(/!?\[([^\]]*)\]\([^)]*\)/g, '$1').split(/\s+/).filter((w) => /\w/.test(w)).length;
  }
  return slides;
}

function shape(args) {
  const file = pick(args);
  const slides = slidesOf(file).filter((s) => s.level > 1);
  const total = slides.reduce((n, s) => n + s.words, 0);
  const visuals = slides.reduce((n, s) => n + s.visuals.length, 0);
  let over = 0;
  console.log(`${shown(file)} · ${slides.length} slides · ${total} words · ${visuals} visuals\n`);
  console.log('  #  words  visual            slide');
  slides.forEach((s, i) => {
    const flags = [];
    if (!EXEMPT.test(s.title)) {
      if (s.words > SLIDE_WORDS) flags.push(`>${SLIDE_WORDS} words`);
      if (!s.visuals.length && s.level === 2) flags.push('no visual');
      if (s.title.split(/\s+/).length > HEADLINE_WORDS) flags.push('long headline');
    }
    if (flags.length) over++;
    const seen = [...new Set(s.visuals)].join('+') || '—';
    const title = `${s.level === 3 ? '  ' : ''}${s.title}`.slice(0, 60);
    console.log(`${String(i + 1).padStart(3)} ${String(s.words).padStart(6)}  ${seen.padEnd(16)}  ${flags.length ? '✗' : '✓'} ${title}${flags.length ? `  (${flags.join(', ')})` : ''}`);
  });
  console.log(`\n${over ? `✗ ${over} of ${slides.length}` : '✓ every'} slide${over > 1 ? 's' : ''} ${over ? 'over budget' : 'within budget'} (≤${SLIDE_WORDS} words, one visual, headline ≤${HEADLINE_WORDS} words)`);
  console.log('\nThe story, headings alone:');
  for (const s of slides.filter((s) => s.level === 2)) console.log(`  · ${s.title}`);
}

// The doc as the person reads it: review.html (?md=) at phone width, each
// slide a PNG. Prints the files and every diagram that failed to draw.
async function shot(args) {
  const file = pick(args.filter((a, i) => !['--out', '--slides'].includes(args[i - 1])));
  const flag = (name) => args[args.indexOf(name) + 1];
  const only = args.includes('--slides') ? flag('--slides').split(',').map(Number) : null;
  const out = resolve(args.includes('--out') ? flag('--out') : join(tmpdir(), 'my-own-app-doc', 'shots', relative(docsDir, dirname(file)).replaceAll('/', '_')));
  const types = { '.html': 'text/html', '.md': 'text/markdown', '.png': 'image/png', '.jpg': 'image/jpeg', '.svg': 'image/svg+xml', '.gif': 'image/gif', '.webp': 'image/webp' };
  const server = createHttpServer((req, res) => {
    const path = resolve(root, '.' + decodeURIComponent(req.url.split('?')[0]));
    const type = types[extname(path).toLowerCase()];
    if (!type || !path.startsWith(root) || !existsSync(path)) return res.writeHead(404).end();
    res.writeHead(200, { 'content-type': `${type}; charset=utf-8` }).end(readFileSync(path));
  });
  const port = await freePort();
  await new Promise((r) => server.listen(port, '127.0.0.1', r));
  try {
    const { capture } = await import('./shot.mjs');
    const url = `http://127.0.0.1:${port}/.tool/review.html?md=${encodeURIComponent(relative(root, file))}`;
    const { files, errors } = await capture(url, { selector: '.slide:not(.cover)', out, hide: 'header, footer, .add' });
    for (const [i, f] of files.entries()) if (!only || only.includes(i + 1)) console.log(f);
    for (const e of errors) console.log(`✗ ${e.split('\n')[0]}`);
    if (!errors.length) console.log(`✓ ${files.length} slides, no errors`);
  } finally {
    server.close();
  }
}

function ls(args) {
  const words = args.map((w) => w.toLowerCase());
  for (const { path, mtime } of docs()) {
    const rel = relative(root, path);
    if (!words.every((w) => rel.toLowerCase().includes(w))) continue;
    const open = notesOf(path).filter((n) => n.kind === 'Q' && !n.answered).length;
    const day = new Date(mtime).toLocaleDateString('sv-SE');
    console.log(`${day}  ${rel}${open ? `  (${open} open Q)` : ''}`);
  }
}

function notes(args) {
  const file = pick(args);
  const onlyOpen = args.includes('--open');
  const list = notesOf(file).filter((n) => !onlyOpen || (n.kind === 'Q' && !n.answered));
  console.log(shown(file));
  if (!list.length) return console.log(onlyOpen ? '  no open questions' : '  no notes');
  for (const n of list) {
    const flag = n.kind === 'Q' ? (n.answered ? ' (answered)' : ' (open)') : '';
    console.log(`\nL${n.line} ${n.kind}${flag}${n.under ? ` · ${n.under}` : ''}`);
    console.log(n.text.replace(/^/gm, '  '));
  }
}

// One server per file: a running one is reused, its port kept in the temp dir.
async function open(args) {
  const file = pick(args);
  const state = join(tmpdir(), 'my-own-app-doc');
  mkdirSync(state, { recursive: true });
  const portFile = join(state, createHash('sha1').update(file).digest('hex').slice(0, 12));
  let port = existsSync(portFile) ? Number(readFileSync(portFile, 'utf8')) : 0;
  if (!port || !(await serves(port, file))) {
    port = await freePort();
    const child = spawn(process.execPath, [join(here, 'annotate.mjs'), file, String(port)], {
      detached: true,
      stdio: 'ignore',
    });
    child.unref();
    writeFileSync(portFile, String(port));
    for (let i = 0; i < 40 && !(await serves(port, file)); i++) await new Promise((r) => setTimeout(r, 100));
  }
  const url = `http://localhost:${port}`;
  console.log(`${shown(file)} → ${url}`);
  if (!args.includes('--no-browser')) execFileSync(process.platform === 'darwin' ? 'open' : 'xdg-open', [url]);
}

async function serves(port, file) {
  try {
    const res = await fetch(`http://127.0.0.1:${port}/doc`, { signal: AbortSignal.timeout(500) });
    return (await res.json()).path === file;
  } catch {
    return false;
  }
}

function freePort() {
  return new Promise((done) => {
    const probe = createServer().listen(0, '127.0.0.1', () => {
      const { port } = probe.address();
      probe.close(() => done(port));
    });
  });
}

function shown(path) {
  const rel = relative(root, path);
  return rel.startsWith('..') ? path : rel;
}

function fail(message) {
  console.error(message);
  process.exit(1);
}

const [command, ...args] = process.argv.slice(2);
const commands = { ls, open, notes, shape, shot };
if (!commands[command]) fail('usage: .tool/doc ls [words] | open [file|words] [--no-browser] | notes [file|words] [--open] | shape [file|words] | shot [file|words] [--out dir] [--slides 1,3]');
await commands[command](args);
