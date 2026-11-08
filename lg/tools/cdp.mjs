// Tiny CDP client for the TV's web inspector.
// usage: node cdp.mjs <port> eval "<js>" | shot <out.png> | key <Key> [n]
import fs from 'node:fs';
const [port, cmd, ...args] = process.argv.slice(2);
const list = await (await fetch(`http://localhost:${port}/json/list`)).json();
const page = list.find(p => p.type === 'page');
const ws = new WebSocket(page.webSocketDebuggerUrl);
let id = 0; const pending = new Map();
ws.onmessage = m => { const d = JSON.parse(m.data); if (pending.has(d.id)) { pending.get(d.id)(d); pending.delete(d.id); } };
await new Promise(r => ws.onopen = r);
const send = (method, params = {}) => new Promise(r => { const i = ++id; pending.set(i, r); ws.send(JSON.stringify({ id: i, method, params })); });
const KEYS = { ArrowUp: 38, ArrowDown: 40, ArrowLeft: 37, ArrowRight: 39, Enter: 13, Back: 461 };
if (cmd === 'eval') {
  const r = await send('Runtime.evaluate', { expression: args[0], awaitPromise: true, returnByValue: true });
  console.log(JSON.stringify(r.result?.exceptionDetails ? r.result.exceptionDetails : (r.result?.result?.value ?? r), null, 1));
} else if (cmd === 'shot') {
  const r = await send('Page.captureScreenshot', { format: 'png' });
  if (r.result?.data) { fs.writeFileSync(args[0], Buffer.from(r.result.data, 'base64')); console.log('saved', args[0]); }
  else console.log(JSON.stringify(r));
} else if (cmd === 'key') {
  const key = args[0], n = +(args[1] || 1), code = KEYS[key];
  for (let i = 0; i < n; i++) {
    for (const type of ['rawKeyDown', 'keyUp']) {
      await send('Input.dispatchKeyEvent', { type, key: key === 'Back' ? 'GoBack' : key, code: key, windowsVirtualKeyCode: code, nativeVirtualKeyCode: code });
    }
    await new Promise(r => setTimeout(r, 400));
  }
  console.log('sent', key, n);
} else if (cmd === 'url') {
  console.log(page.url, '|', page.title);
}
ws.close(); process.exit(0);
