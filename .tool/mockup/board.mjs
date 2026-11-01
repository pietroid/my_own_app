// Lays real Flutter screenshots out as an annotated proposal board.
// Usage: node board.mjs <board.json> <out_dir>
// Writes board.html + board.png, and screenN.html + screenN.png (one column each).
//
// board.json (paths relative to it; x/y in logical px on the 390x844 screenshot):
// { "screens": [ { "png": "shots/1.png", "title": "Tempo", "why": "Onde começa.",
//     "pins": [ { "id": "A", "x": 8, "y": 722, "label": "Entrada", "text": "..." } ] } ] }
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { execFileSync } from 'node:child_process';

const [specPath, outArg] = process.argv.slice(2);
const spec = JSON.parse(readFileSync(specPath, 'utf8'));
const base = dirname(resolve(specPath));
const out = resolve(outArg);
mkdirSync(out, { recursive: true });
const chrome = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const H = 1320;

const esc = (s = '') => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
const column = (s) => `<div class="col">
<div class="head"><h2>${esc(s.title)}</h2><p>${esc(s.why)}</p></div>
<div class="phone"><img src="file://${resolve(base, s.png)}">
${(s.pins ?? []).map((p) => `<div class="pin" style="left:${p.x - 12}px;top:${p.y - 12}px">${esc(p.id)}</div>`).join('')}
</div>
${s.pins?.length ? `<div class="note">${s.pins.map((p) => `<div><span class="pin">${esc(p.id)}</span><b>${esc(p.label)}:</b> ${esc(p.text)}</div>`).join('')}</div>` : ''}
</div>`;
const page = (cols) => `<!doctype html><html><head><meta charset="utf-8">
<link href="https://fonts.googleapis.com/css2?family=Onest:wght@400;500;600&display=swap" rel="stylesheet">
<style>
*{box-sizing:border-box;margin:0}
body{font-family:Onest,sans-serif;background:#EFE9EA;color:#1F1416;padding:48px;-webkit-font-smoothing:antialiased}
.board{display:flex;gap:56px;align-items:flex-start}
.col{display:flex;flex-direction:column;gap:16px;width:390px}
.head h2{font-size:18px;font-weight:600}.head p{font-size:13px;color:#6B5A5D;margin-top:4px}
.phone{width:390px;height:844px;border-radius:44px;overflow:hidden;position:relative;box-shadow:0 30px 60px -20px rgba(60,20,30,.35)}
.phone img{width:390px;height:844px;display:block}
.pin{position:absolute;width:24px;height:24px;border-radius:99px;background:#2563EB;color:#fff;font-size:12px;font-weight:600;display:grid;place-items:center;box-shadow:0 0 0 3px #fff;z-index:9}
.note{font-size:12.5px;color:#6B5A5D;background:#fff;border-radius:14px;padding:12px 14px;line-height:1.5;display:flex;flex-direction:column;gap:6px}
.note b{color:#1F1416;font-weight:500}
.note .pin{position:static;display:inline-grid;margin-right:6px;box-shadow:none;vertical-align:-6px}
</style></head><body><div class="board">${cols.join('')}</div></body></html>`;

const shoot = (name, cols) => {
  writeFileSync(`${out}/${name}.html`, page(cols));
  const w = 96 + cols.length * 390 + (cols.length - 1) * 56;
  execFileSync(chrome, ['--headless=new', '--disable-gpu', '--hide-scrollbars', '--allow-file-access-from-files',
    '--force-device-scale-factor=2', '--virtual-time-budget=5000', `--window-size=${w},${H}`,
    `--screenshot=${out}/${name}.png`, `file://${out}/${name}.html`], { stdio: 'ignore' });
};

const cols = spec.screens.map(column);
shoot('board', cols);
cols.forEach((c, i) => shoot(`screen${i + 1}`, [c]));
console.log([`${out}/board.png`, ...cols.map((_, i) => `${out}/screen${i + 1}.png`)].join('\n'));
