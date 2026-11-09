// node hold.mjs <port> <holdMs>  — press and hold OK (Enter) on the TV, then release
const [port, holdMs = '1200', shotPath] = process.argv.slice(2);
const list = await (await fetch(`http://localhost:${port}/json/list`)).json();
const page = list.find(p => p.type === 'page');
const ws = new WebSocket(page.webSocketDebuggerUrl); let id = 0; const pend = new Map();
ws.onmessage = e => { const m = JSON.parse(e.data); if (pend.has(m.id)) { pend.get(m.id)(m.result); pend.delete(m.id); } };
await new Promise(r => ws.onopen = r);
const send = (method, params) => new Promise(r => { pend.set(++id, r); ws.send(JSON.stringify({ id, method, params })); });
const key = { key: 'Enter', code: 'Enter', windowsVirtualKeyCode: 13, nativeVirtualKeyCode: 13 };
await send('Input.dispatchKeyEvent', Object.assign({ type: 'rawKeyDown' }, key));
await new Promise(r => setTimeout(r, +holdMs));
if (shotPath) { const s = await send('Page.captureScreenshot', { format: 'png' }); (await import('node:fs')).writeFileSync(shotPath, Buffer.from(s.data, 'base64')); }
await send('Input.dispatchKeyEvent', Object.assign({ type: 'keyUp' }, key));
const r = await send('Runtime.evaluate', { expression: "JSON.stringify({cc: __spelunkr.subs().on, guide: !document.getElementById('guide').classList.contains('hidden'), toast: document.getElementById('toast').className + ' ' + document.getElementById('toast').textContent})", returnByValue: true });
console.log(r.result.value);
ws.close();
