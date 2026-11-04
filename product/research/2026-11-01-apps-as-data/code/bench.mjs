// What one stored action costs, by sandbox and by how much state it is handed.
//
// The action is the travel app's "add an expense": take the state, append the
// expense, recompute the totals by category, return the new state. It runs in
// three sandboxes (node:vm as a baseline that is NOT a security boundary,
// isolated-vm, quickjs-emscripten) and two ways of handing it data:
//   whole: the entire app state goes in and comes out, as the issue proposes;
//   slice: only what the action declares (the totals + the new expense) goes in,
//          and a JSON Patch-like list of changes comes out.
//
// Run: npm install && npm run bench   (writes ../data/sandbox-bench.csv)

import { createRequire } from 'node:module';
import vm from 'node:vm';
import { performance } from 'node:perf_hooks';

const require = createRequire(import.meta.url);
const ivm = require('isolated-vm');
const { getQuickJS } = require('quickjs-emscripten');

// The action, as the agent would store it: a tiny pure function.
const WHOLE = `
function run(state, input) {
  const expenses = [...state.trip.expenses, input];
  const totals = {};
  for (const e of expenses) totals[e.category] = (totals[e.category] ?? 0) + e.amount;
  return { ...state, trip: { ...state.trip, expenses, totals } };
}`;
const SLICE = `
function run(slice, input) {
  const totals = { ...slice.totals };
  totals[input.category] = (totals[input.category] ?? 0) + input.amount;
  return [
    { op: 'add', path: '/trip/expenses/-', value: input },
    { op: 'replace', path: '/trip/totals', value: totals },
  ];
}`;

const CATEGORIES = ['voo', 'hotel', 'comida', 'passeio', 'transporte'];
function stateWith(n) {
  const expenses = Array.from({ length: n }, (_, i) => ({
    id: `e${i}`,
    title: `Despesa ${i}`,
    category: CATEGORIES[i % CATEGORIES.length],
    amount: 10 + (i % 97),
    date: '2026-12-0' + (1 + (i % 9)),
  }));
  const totals = {};
  for (const e of expenses) totals[e.category] = (totals[e.category] ?? 0) + e.amount;
  return {
    trip: { title: 'Lisboa', from: '2026-12-01', to: '2026-12-10', budget: 8000, expenses, totals },
  };
}
const input = { id: 'new', title: 'Pastéis', category: 'comida', amount: 12, date: '2026-12-03' };

// Every runner takes JSON text in and gives JSON text back, so the cost of
// crossing into the sandbox is counted, as it would be on the server.
const runners = {
  'node:vm': (code) => {
    const script = new vm.Script(`${code}; JSON.stringify(run(JSON.parse(__s), JSON.parse(__i)))`);
    return (s, i) => script.runInNewContext({ __s: s, __i: i }, { timeout: 50 });
  },
  'isolated-vm': (code) => {
    const isolate = new ivm.Isolate({ memoryLimit: 32 });
    const script = isolate.compileScriptSync(`${code}; JSON.stringify(run(JSON.parse(__s), JSON.parse(__i)))`);
    return (s, i) => {
      const context = isolate.createContextSync();
      context.global.setSync('__s', s);
      context.global.setSync('__i', i);
      const out = script.runSync(context, { timeout: 50 });
      context.release();
      return out;
    };
  },
  quickjs: (code, QuickJS) => (s, i) => {
    const runtime = QuickJS.newRuntime();
    runtime.setMemoryLimit(32 * 1024 * 1024);
    const deadline = Date.now() + 50;
    runtime.setInterruptHandler(() => Date.now() > deadline);
    const ctx = runtime.newContext();
    const hs = ctx.newString(s);
    const hi = ctx.newString(i);
    ctx.setProp(ctx.global, '__s', hs);
    ctx.setProp(ctx.global, '__i', hi);
    hs.dispose();
    hi.dispose();
    const result = ctx.evalCode(`${code}; JSON.stringify(run(JSON.parse(__s), JSON.parse(__i)))`);
    const out = ctx.dump(ctx.unwrapResult(result));
    ctx.dispose();
    runtime.dispose();
    return out;
  },
};

function median(xs) {
  const s = [...xs].sort((a, b) => a - b);
  return s[Math.floor(s.length / 2)];
}

const QuickJS = await getQuickJS();
const sizes = [10, 100, 1_000, 10_000, 50_000];
console.log('sandbox,mode,expenses,state_kb,median_ms');
for (const n of sizes) {
  const state = stateWith(n);
  const whole = JSON.stringify(state);
  const slice = JSON.stringify({ totals: state.trip.totals });
  const i = JSON.stringify(input);
  for (const [name, make] of Object.entries(runners)) {
    for (const [mode, code, s] of [['whole', WHOLE, whole], ['slice', SLICE, slice]]) {
      const run = make(code, QuickJS);
      const reps = n >= 10_000 ? 7 : 31;
      try {
        run(s, i); // warm
      } catch (error) {
        // Over the 50 ms deadline or the 32 MB limit: the sandbox said no.
        const why = String(error?.message ?? error).split('\n')[0].replaceAll(',', ' ').slice(0, 60);
        console.log([name, mode, n, (whole.length / 1024).toFixed(1), `refused: ${why}`].join(','));
        continue;
      }
      const times = [];
      for (let r = 0; r < reps; r++) {
        const t = performance.now();
        // The server's side of it: parse what came back.
        JSON.parse(run(s, i));
        times.push(performance.now() - t);
      }
      console.log([name, mode, n, (whole.length / 1024).toFixed(1), median(times).toFixed(3)].join(','));
    }
  }
}
