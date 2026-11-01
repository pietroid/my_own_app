// How many common app types each tier of the architecture can build.
//
// data/archetypes.csv is judgment-coded (by the RFC's author, not measured
// from a store): one row per kind of app people use, with the capabilities it
// cannot do without. A tier covers an app when it offers all of them.
// Run: node coverage.mjs > ../data/coverage.csv

import { readFileSync } from 'node:fs';

const rows = readFileSync(new URL('../data/archetypes.csv', import.meta.url), 'utf8')
  .trim().split('\n').slice(1)
  .map((line) => { const [app, needs] = line.split(','); return { app, needs: needs.split(';') }; });

// Each tier adds to the one before it.
const tiers = [
  ['0 today: app_ui (2 widgets), no data, no actions', []],
  ['1 A2UI basic catalog + data JSON + stored actions', ['crud']],
  ['2 + chart, map, photo components', ['chart', 'map', 'photo']],
  ['3 + host calls: schedule, fetch, ai', ['schedule', 'fetch', 'ai']],
  ['4 + an app shared by several people', ['multi_user']],
];

let offered = new Set();
console.log('tier,apps_covered,of,percent,newly_covered');
let before = new Set();
for (const [name, adds] of tiers) {
  adds.forEach((it) => offered.add(it));
  const covered = rows.filter((r) => r.needs.every((n) => offered.has(n)));
  const fresh = covered.filter((r) => !before.has(r.app)).map((r) => r.app);
  before = new Set(covered.map((r) => r.app));
  console.log([JSON.stringify(name), covered.length, rows.length, Math.round((100 * covered.length) / rows.length), JSON.stringify(fresh.join('; '))].join(','));
}
const out = rows.filter((r) => !r.needs.every((n) => offered.has(n)));
console.log(`"out of reach",${out.length},${rows.length},${Math.round((100 * out.length) / rows.length)},${JSON.stringify(out.map((r) => `${r.app} (${r.needs.filter((n) => !offered.has(n)).join('+')})`).join('; '))}`);
