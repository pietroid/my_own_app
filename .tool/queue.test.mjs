// node --test .tool/*.test.mjs   (.tool/check runs it when .tool/ changes)
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { pagesPolicy, reviewUrl } from './queue.mjs';

const cfg = { repo: 'me/app' };
const st = { pr: 2, doc: 'product/research/2026-11-01-apps-as-data/README.md' };

test('reviewUrl links the page when it answers 200, on https', () => {
  const asked = [];
  const url = reviewUrl(cfg, st, { site: () => 'http://me.dev/app/', live: (u) => (asked.push(u), true), deploy: () => assert.fail('no deploy') });
  assert.deepEqual(asked, ['https://me.dev/app/review.html']);
  assert.equal(url, 'https://me.dev/app/review.html?repo=me/app&pr=2&path=product/research/2026-11-01-apps-as-data/README.md');
});

test('reviewUrl leaves a 404 page out and dispatches the deploy once', () => {
  let deploys = 0;
  const url = reviewUrl(cfg, st, { site: () => 'https://me.dev/app', live: () => false, deploy: () => deploys++ });
  assert.equal(url, null);
  assert.equal(deploys, 1);
});

test('reviewUrl without Pages, a PR or a doc asks nothing more', () => {
  const never = () => assert.fail('not asked');
  assert.equal(reviewUrl(cfg, st, { site: () => null, live: never, deploy: never }), null);
  assert.equal(reviewUrl(cfg, { doc: st.doc }, { site: never, live: never, deploy: never }), null);
});

// A fake gh api: the environment's policies, and the writes it was asked for.
const fakeApi = (custom, names) => {
  const writes = [];
  const api = (args) => {
    if (args[0] === '-X') { writes.push(args); if (args[1] === 'POST') names.push(args.find((a) => a.startsWith('name=')).slice(5)); if (args[1] === 'PUT') custom = true; return null; }
    if (args[0].endsWith('/deployment-branch-policies')) return [...names];
    return custom;
  };
  return { api, writes };
};

test('pagesPolicy adds queue/* when only main is allowed', () => {
  const { api, writes } = fakeApi(true, ['main']);
  assert.equal(pagesPolicy('me/app', api), true);
  assert.deepEqual(writes, [['-X', 'POST', 'repos/me/app/environments/github-pages/deployment-branch-policies', '-f', 'name=queue/*', '-f', 'type=branch']]);
});

test('pagesPolicy writes nothing when queue/* is there', () => {
  const { api, writes } = fakeApi(true, ['main', 'queue/*']);
  assert.equal(pagesPolicy('me/app', api), true);
  assert.deepEqual(writes, []);
});

test('pagesPolicy turns custom policies on, then adds main and queue/*', () => {
  const { api, writes } = fakeApi(false, []);
  assert.equal(pagesPolicy('me/app', api), true);
  assert.deepEqual(writes.map((w) => w[1]), ['PUT', 'POST', 'POST']);
});
