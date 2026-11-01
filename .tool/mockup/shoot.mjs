// CDP screenshot of one URL as a phone; used by shoot-flutter.sh.
// Usage: node shoot.mjs <port> <url> <out.png> [waitMs]
import { writeFileSync } from 'node:fs';
const [port, url, out, wait = '3500'] = process.argv.slice(2);
const target = await (await fetch(`http://127.0.0.1:${port}/json/new?about:blank`, { method: 'PUT' })).json();
const ws = new WebSocket(target.webSocketDebuggerUrl);
await new Promise((r) => ws.addEventListener('open', r, { once: true }));
let id = 0; const pending = new Map();
ws.addEventListener('message', (e) => { const m = JSON.parse(e.data); if (m.id && pending.has(m.id)) { pending.get(m.id)(m); pending.delete(m.id); } });
const send = (method, params = {}) => new Promise((r) => { const i = ++id; pending.set(i, r); ws.send(JSON.stringify({ id: i, method, params })); });
await send('Emulation.setDeviceMetricsOverride', { width: 390, height: 844, deviceScaleFactor: 2, mobile: true });
await send('Page.enable');
await send('Page.navigate', { url });
await new Promise((r) => setTimeout(r, Number(wait)));
const shot = await send('Page.captureScreenshot', { format: 'png' });
writeFileSync(out, Buffer.from(shot.result.data, 'base64'));
await fetch(`http://127.0.0.1:${port}/json/close/${target.id}`);
ws.close();
