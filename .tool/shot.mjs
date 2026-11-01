// Headless Chrome over the DevTools protocol, no dependencies: load a page
// at phone width, wait for it to say it is ready, and save each element a
// selector finds as its own PNG. Used by `.tool/doc shot`.
//
//   const { files, errors } = await capture(url, { selector: '.slide', out, width: 390, hide: 'footer' });
import { spawn } from 'node:child_process';
import { mkdtempSync, mkdirSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const CHROME = process.env.CHROME ?? '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';

export async function capture(url, { selector = 'body', out, width = 390, scale = 2, ready = 'document.body?.dataset.ready', maxHeight = Infinity, hide = '', timeout = 20000 } = {}) {
  const profile = mkdtempSync(join(tmpdir(), 'my-own-app-shot-'));
  const chrome = spawn(CHROME, ['--headless=new', '--remote-debugging-port=0', `--user-data-dir=${profile}`, '--hide-scrollbars', 'about:blank'], { stdio: ['ignore', 'ignore', 'pipe'] });
  try {
    const ws = await new Promise((done, fail) => {
      let err = '';
      chrome.stderr.on('data', (d) => {
        err += d;
        const m = err.match(/ws:\/\/\S+/);
        if (m) done(m[0]);
      });
      chrome.on('exit', () => fail(new Error(`Chrome exited: ${err.slice(-300)}`)));
    });
    const cdp = await connect(ws);
    const { targetId } = await cdp.send('Target.createTarget', { url: 'about:blank' });
    const { sessionId } = await cdp.send('Target.attachToTarget', { targetId, flatten: true });
    const page = (method, params) => cdp.send(method, params, sessionId);
    const errors = [];
    cdp.on('Runtime.consoleAPICalled', (p) => p.type === 'error' && errors.push(p.args.map((a) => a.value ?? a.description).join(' ')));
    cdp.on('Runtime.exceptionThrown', (p) => errors.push(p.exceptionDetails.exception?.description ?? p.exceptionDetails.text));
    await page('Runtime.enable');
    await page('Emulation.setDeviceMetricsOverride', { width, height: 800, deviceScaleFactor: scale, mobile: true });
    await page('Emulation.setEmulatedMedia', { features: [{ name: 'prefers-color-scheme', value: 'dark' }] });
    await page('Page.enable');
    await page('Page.navigate', { url });
    const until = Date.now() + timeout;
    while (!(await evaluate(page, `!!(${ready})`))) {
      if (Date.now() > until) throw new Error(`page never got ready (${ready})`);
      await new Promise((r) => setTimeout(r, 200));
    }
    await evaluate(page, 'document.fonts.ready.then(() => true)');
    if (hide) await evaluate(page, `document.head.insertAdjacentHTML('beforeend', '<style>${hide} { display: none !important; }</style>')`);
    const rects = await evaluate(page, `[...document.querySelectorAll(${JSON.stringify(selector)})].map((el) => {
      const r = el.getBoundingClientRect();
      return { x: r.x + scrollX, y: r.y + scrollY, width: r.width, height: Math.min(r.height, ${maxHeight === Infinity ? 1e9 : maxHeight}) };
    })`);
    mkdirSync(out, { recursive: true });
    const files = [];
    for (const [i, clip] of rects.entries()) {
      const { data } = await page('Page.captureScreenshot', { format: 'png', captureBeyondViewport: true, clip: { ...clip, scale: 1 } });
      const file = join(out, `${String(i + 1).padStart(2, '0')}.png`);
      writeFileSync(file, Buffer.from(data, 'base64'));
      files.push(file);
    }
    cdp.close();
    return { files, errors };
  } finally {
    const exited = new Promise((r) => (chrome.exitCode !== null ? r() : chrome.once('exit', r)));
    chrome.kill();
    await exited;
    rmSync(profile, { recursive: true, force: true, maxRetries: 5, retryDelay: 100 });
  }
}

async function evaluate(page, expression) {
  const { result, exceptionDetails } = await page('Runtime.evaluate', { expression, awaitPromise: true, returnByValue: true });
  if (exceptionDetails) throw new Error(exceptionDetails.exception?.description ?? exceptionDetails.text);
  return result.value;
}

function connect(url) {
  const socket = new WebSocket(url);
  const waiting = new Map();
  const listeners = new Map();
  let id = 0;
  socket.onmessage = ({ data }) => {
    const msg = JSON.parse(data);
    if (msg.id && waiting.has(msg.id)) {
      const { done, fail } = waiting.get(msg.id);
      waiting.delete(msg.id);
      msg.error ? fail(new Error(msg.error.message)) : done(msg.result);
    } else if (msg.method) {
      listeners.get(msg.method)?.(msg.params);
    }
  };
  return new Promise((ready, fail) => {
    socket.onerror = () => fail(new Error(`could not reach Chrome at ${url}`));
    socket.onopen = () => ready({
      send: (method, params = {}, sessionId) => new Promise((done, fail) => {
        waiting.set(++id, { done, fail });
        socket.send(JSON.stringify({ id, method, params, ...(sessionId ? { sessionId } : {}) }));
      }),
      on: (method, fn) => listeners.set(method, fn),
      close: () => socket.close(),
    });
  });
}
