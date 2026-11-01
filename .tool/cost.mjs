#!/usr/bin/env node
// What a Claude Code session in this repo cost, read from its transcript:
// one row per message from the user, so phases split where the user spoke.
//
//   .tool/cost [session] [--from HH:MM] [--usd N]
//   .tool/cost --list
//
// No session means the newest one, which is the one running. A session is
// its id, or the start of it. In is everything the model read (cache reads,
// cache writes, raw input); out is everything it wrote, thinking included.
//
// USD: a transcript only gets its total cost when the session ends. Pass
// `--usd` (the running figure, from `mcp__usage-bars__session_cost`) before
// then. Either total is spread over the rows by the usual price ratios:
// cache read 0.1x input, cache write 1.25x (5 min) or 2x (1 h), output 5x.
import { readdirSync, readFileSync, statSync } from 'node:fs';
import { homedir } from 'node:os';
import { join, resolve } from 'node:path';

const repo = resolve(new URL('..', import.meta.url).pathname);
const dir = join(homedir(), '.claude', 'projects', repo.replace(/[/.]/g, '-'));
const args = process.argv.slice(2);
const flag = (name) => {
  const i = args.indexOf(name);
  return i < 0 ? undefined : args.splice(i, 2)[1];
};

const sessions = () =>
  readdirSync(dir)
    .filter((f) => f.endsWith('.jsonl'))
    .map((f) => ({ id: f.slice(0, -6), path: join(dir, f), mtime: statSync(join(dir, f)).mtimeMs }))
    .sort((a, b) => b.mtime - a.mtime);

// The words of a message the user typed; undefined for tool results,
// image captions and the harness's own messages.
function said(entry) {
  if (entry.type !== 'user' || entry.isMeta || entry.isSidechain) return undefined;
  const content = entry.message?.content;
  const text = typeof content === 'string' ? content : content?.find?.((c) => c.type === 'text')?.text;
  if (!text || content?.some?.((c) => c.type === 'tool_result')) return undefined;
  const command = text.match(/<command-name>(\S+)<\/command-name>[\s\S]*?<command-args>([\s\S]*?)<\/command-args>/);
  if (command) return `${command[1]} ${command[2]}`.trim();
  if (text.startsWith('<') || text.startsWith('[Image') || text.startsWith('[Request interrupted')) return undefined;
  return text;
}

function read(path) {
  const rows = [];
  const usage = new Map(); // message id -> { row, usage }: a reply spans several entries
  let total;
  for (const line of readFileSync(path, 'utf8').split('\n')) {
    if (!line) continue;
    let e;
    try { e = JSON.parse(line); } catch { continue; }
    const text = said(e);
    if (text !== undefined) rows.push({ at: new Date(e.timestamp), text, turns: 0, read: 0, write: 0, raw: 0, out: 0, think: 0, units: 0, peak: 0 });
    const m = e.message;
    if (e.type === 'assistant' && m?.usage && m.id && rows.length) usage.set(m.id, { row: rows.at(-1), u: m.usage, at: new Date(e.timestamp) });
    const cost = line.includes('"costUSD"') && line.match(/"modelUsage":\{.*?"costUSD":([\d.]+)/);
    if (cost) total = Number(cost[1]);
  }
  for (const { row, u, at } of usage.values()) {
    const w1h = u.cache_creation?.ephemeral_1h_input_tokens ?? 0;
    const write = u.cache_creation_input_tokens ?? 0;
    row.turns++;
    row.read += u.cache_read_input_tokens ?? 0;
    row.write += write;
    row.raw += u.input_tokens ?? 0;
    row.out += u.output_tokens ?? 0;
    row.think += u.output_tokens_details?.thinking_tokens ?? 0;
    row.peak = Math.max(row.peak, (u.cache_read_input_tokens ?? 0) + write + (u.input_tokens ?? 0));
    row.units += (u.input_tokens ?? 0) + 0.1 * (u.cache_read_input_tokens ?? 0) + 2 * w1h + 1.25 * (write - w1h) + 5 * (u.output_tokens ?? 0);
    row.end = at;
  }
  return { rows, total };
}

const k = (n) => (n >= 1e6 ? `${(n / 1e6).toFixed(2)}M` : n >= 1e3 ? `${Math.round(n / 1e3)}k` : `${n}`);
const hm = (d) => d.toTimeString().slice(0, 5);
const mins = (a, b) => (b ? `${Math.max(1, Math.round((b - a) / 60000))} min` : '—');

if (args.includes('--list')) {
  for (const s of sessions().slice(0, 15)) {
    const first = read(s.path).rows[0];
    console.log(`${s.id.slice(0, 8)}  ${new Date(s.mtime).toLocaleString('sv-SE').slice(0, 16)}  ${(first?.text ?? '').replace(/\s+/g, ' ').slice(0, 70)}`);
  }
  process.exit(0);
}

const from = flag('--from');
const usdFlag = flag('--usd');
const name = args[0];
const session = name ? sessions().find((s) => s.id.startsWith(name)) : sessions()[0];
if (!session) {
  console.error(`no session ${name ?? ''} in ${dir}`);
  process.exit(1);
}
let { rows, total } = read(session.path);
if (usdFlag) total = Number(usdFlag);
const allUnits = rows.reduce((a, r) => a + r.units, 0);
if (from) {
  const [h, m] = from.split(':').map(Number);
  rows = rows.filter((r) => r.at.getHours() * 60 + r.at.getMinutes() >= h * 60 + m);
}
const usd = (units) => (total ? `$${((total * units) / allUnits).toFixed(2)}` : '—');

const zone = Intl.DateTimeFormat().resolvedOptions().timeZone;
console.log(`Session ${session.id.slice(0, 8)}, times in ${zone}. In = cache read + cache write + raw input; out includes thinking.`);
console.log(`USD: ${total ? (usdFlag ? 'the figure passed with --usd' : "the transcript's own total") + ', spread by token weight' : 'unknown until the session ends (pass --usd)'}.\n`);
console.log('| # | At | Took | Message | Turns | Peak context | In (cache read) | Out (thinking) | USD |');
console.log('|---|---|---|---|---|---|---|---|---|');
const sum = { turns: 0, read: 0, write: 0, raw: 0, out: 0, think: 0, units: 0 };
rows.forEach((r, i) => {
  const words = r.text.replace(/\s+/g, ' ').replace(/\|/g, '/');
  const label = words.length > 48 ? `${words.slice(0, 47)}…` : words;
  console.log(`| ${i + 1} | ${hm(r.at)} | ${mins(r.at, r.end)} | ${label} | ${r.turns} | ${k(r.peak)} | ${k(r.read + r.write + r.raw)} (${k(r.read)}) | ${k(r.out)} (${k(r.think)}) | ${usd(r.units)} |`);
  for (const key of Object.keys(sum)) sum[key] += r[key];
});
const span = rows.length ? mins(rows[0].at, rows.findLast((r) => r.end)?.end) : '—';
console.log(`| | | **${span}** | **Total** | **${sum.turns}** | | **${k(sum.read + sum.write + sum.raw)}** (${k(sum.read)}) | **${k(sum.out)}** (${k(sum.think)}) | **${usd(sum.units)}** |`);
