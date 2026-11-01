// Draws the RFC's two charts from data/, as PNGs in img/, in the review
// page's dark colours, 390 px wide at 2x (a phone).
// Run: node charts.mjs   (needs Google Chrome)

import { execFileSync } from 'node:child_process';
import { mkdtempSync, readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const here = (p) => new URL(p, import.meta.url).pathname;
const CHROME = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const C = { bg: '#0d0d0d', ink: '#f5f5f5', ink2: '#a1a1a1', ink3: '#6b6b6b', line: '#232323', blue: '#3987e5', orange: '#d95926', aqua: '#199e70' };
const W = 390;
const font = `font-family="-apple-system, Inter, Helvetica, sans-serif"`;

function csv(path) {
  const [head, ...rows] = readFileSync(here(path), 'utf8').trim().split('\n');
  const keys = head.split(',');
  return rows.map((line) => {
    const cells = line.match(/("([^"]*)"|[^,]*)(,|$)/g).map((c) => c.replace(/,$/, '').replace(/^"|"$/g, ''));
    return Object.fromEntries(keys.map((k, i) => [k, cells[i]]));
  });
}

function png(name, svg, height) {
  const dir = mkdtempSync(join(tmpdir(), 'chart-'));
  const html = join(dir, 'c.html');
  writeFileSync(html, `<html><body style="margin:0;background:${C.bg}">${svg}</body></html>`);
  execFileSync(CHROME, ['--headless=new', '--hide-scrollbars', '--force-device-scale-factor=2', `--window-size=${W},${height}`, `--screenshot=${here(`../img/${name}`)}`, `file://${html}`], { stdio: 'ignore' });
}

// 1. Coverage: the share of 42 app types each tier reaches.
{
  const rows = csv('../data/coverage.csv').filter((r) => !r.tier.startsWith('out'));
  const labels = ['Today: app_ui', '+ A2UI catalog, data, actions', '+ chart, map, photo', '+ schedule, fetch, ai', '+ shared by several people'];
  const H = 330, left = 16, top = 56, barH = 26, gap = 22, maxW = W - left - 64;
  let s = `<svg width="${W}" height="${H}" ${font}>`;
  s += `<text x="${left}" y="24" fill="${C.ink}" font-size="15" font-weight="600">Share of 42 common app types it can build</text>`;
  s += `<text x="${left}" y="42" fill="${C.ink2}" font-size="12">each tier adds to the one above · judgment-coded</text>`;
  const x80 = left + maxW * 0.8;
  rows.forEach((r, i) => {
    const y = top + i * (barH + gap);
    const p = Number(r.percent);
    s += `<text x="${left}" y="${y + 12}" fill="${C.ink2}" font-size="12">${labels[i]}</text>`;
    s += `<rect x="${left}" y="${y + 18}" width="${maxW}" height="${barH - 12}" rx="4" fill="${C.line}"/>`;
    if (p > 0) s += `<rect x="${left}" y="${y + 18}" width="${(maxW * p) / 100}" height="${barH - 12}" rx="4" fill="${C.blue}"/>`;
    s += `<text x="${left + maxW + 8}" y="${y + 29}" fill="${C.ink}" font-size="13" font-weight="600">${p}%</text>`;
  });
  s += `<line x1="${x80}" x2="${x80}" y1="${top + 10}" y2="${top + 5 * (barH + gap) - 8}" stroke="${C.ink3}" stroke-dasharray="3 3"/>`;
  s += `<text x="${x80}" y="${top + 5 * (barH + gap) + 8}" fill="${C.ink3}" font-size="11" text-anchor="middle">the 80% asked for</text>`;
  s += `</svg>`;
  png('coverage.png', s, H);
}

// 2. Sandbox: ms per action against the size of the state handed in.
{
  const rows = csv('../data/sandbox-bench.csv');
  const H = 376, l = 44, r = 20, t = 76, b = 52;
  const xs = [1, 5000], ys = [0.1, 100];
  const X = (kb) => l + ((Math.log10(kb) - Math.log10(xs[0])) / (Math.log10(xs[1]) - Math.log10(xs[0]))) * (W - l - r);
  const Y = (ms) => t + (1 - (Math.log10(ms) - Math.log10(ys[0])) / (Math.log10(ys[1]) - Math.log10(ys[0]))) * (H - t - b);
  const series = [
    ['quickjs', 'whole', C.orange, 'QuickJS, whole state'],
    ['isolated-vm', 'whole', C.blue, 'isolated-vm, whole state'],
    ['isolated-vm', 'slice', C.aqua, 'either, a declared slice'],
  ];
  let s = `<svg width="${W}" height="${H}" ${font}>`;
  s += `<text x="16" y="24" fill="${C.ink}" font-size="15" font-weight="600">ms per action, by state handed in</text>`;
  s += `<text x="16" y="42" fill="${C.ink2}" font-size="12">"add an expense" to a trip · median · M-series Mac</text>`;
  for (const ms of [0.1, 1, 10, 100]) {
    s += `<line x1="${l}" x2="${W - r}" y1="${Y(ms)}" y2="${Y(ms)}" stroke="${C.line}"/>`;
    s += `<text x="${l - 6}" y="${Y(ms) + 4}" fill="${C.ink3}" font-size="11" text-anchor="end">${ms}</text>`;
  }
  for (const [kb, label] of [[1, '1 KB'], [10, '10 KB'], [100, '100 KB'], [1000, '1 MB']]) {
    s += `<text x="${X(kb)}" y="${H - b + 18}" fill="${C.ink3}" font-size="11" text-anchor="middle">${label}</text>`;
  }
  s += `<text x="${(l + W - r) / 2}" y="${H - 12}" fill="${C.ink2}" font-size="12" text-anchor="middle">size of the app's state (10 → 50,000 expenses)</text>`;
  series.forEach(([sb, mode, color, label], i) => {
    const pts = rows.filter((q) => q.sandbox === sb && q.mode === mode && !q.median_ms.startsWith('refused'));
    const d = pts.map((q, k) => `${k ? 'L' : 'M'}${X(+q.state_kb).toFixed(1)},${Y(+q.median_ms).toFixed(1)}`).join(' ');
    s += `<path d="${d}" fill="none" stroke="${color}" stroke-width="2"/>`;
    pts.forEach((q) => (s += `<circle cx="${X(+q.state_kb)}" cy="${Y(+q.median_ms)}" r="4" fill="${color}" stroke="${C.bg}" stroke-width="2"/>`));
    const last = pts[pts.length - 1];
    // QuickJS: left of its last point; isolated-vm: under its 1 MB point; slice: above its line.
    const at = i === 1 ? pts.find((q) => q.expenses === '10000') : last;
    const [lx, ly, anchor] = {
      0: [X(+at.state_kb) - 10, Y(+at.median_ms) + 4, 'end'],
      1: [X(+at.state_kb) + 10, Y(+at.median_ms) + 18, 'start'],
      2: [X(+at.state_kb) - 6, Y(+at.median_ms) - 10, 'end'],
    }[i];
    // A long label near the right edge wraps after its comma.
    const [a, b2] = i === 1 ? label.split(', ') : [label];
    s += `<text x="${lx}" y="${ly}" fill="${C.ink}" font-size="12" text-anchor="${anchor}">${b2 ? `<tspan>${a},</tspan><tspan x="${lx}" dy="15">${b2}</tspan>` : a}</text>`;
  });
  const refused = rows.find((q) => q.sandbox === 'quickjs' && q.median_ms.startsWith('refused'));
  if (refused) {
    const x = X(+refused.state_kb), y = Y(90);
    s += `<text x="${x}" y="${y + 5}" fill="${C.orange}" font-size="16" text-anchor="middle">×</text>`;
    s += `<text x="16" y="60" fill="${C.ink2}" font-size="12"><tspan fill="${C.orange}">×</tspan> QuickJS refused 4.4 MB: over its 50 ms limit</text>`;
  }
  s += `</svg>`;
  png('sandbox.png', s, H);
}
