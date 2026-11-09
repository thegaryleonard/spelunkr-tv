// Check the Chrome-68 (down-levelled) app/js/engine.js computes the same schedule as the original engine.
import fs from 'node:fs';
import vm from 'node:vm';
import * as ORIG from './engine.node.mjs';
const ctx = { window: {}, console, Promise, fetch, URL, setTimeout };
vm.createContext(ctx);
vm.runInContext(fs.readFileSync('../app/js/compat.js', 'utf8') + '\n' + fs.readFileSync('../app/js/engine.js', 'utf8'), ctx);
const LOW = ctx.window.SpelunkrEngine;
const UA = { headers: { 'User-Agent': 'spelunkr-lg-build/1.0' } }, D = 'https://data.spelunkr.tv/', cache = {};
const j = async p => cache[p] ??= await (await fetch(D + p, UA)).json();
const L = await j('lineup.json');
const now = Date.now(), times = [0, 3600e3, 86400e3, 7 * 86400e3].map(o => now + o);
const sig = n => { const i = n.item; return `${n.key}|${i.type}|${n.startMs}|${n.endMs}|${i.title || ''}|${i.id || ''}`; };
let same = 0, diff = 0, urls = 0;
for (const c of L.channels) {
  const ms = []; for (const p of c.versions) { const m = await j(p.manifest); ms.push([m, m.platform ? await j(m.platform) : null, p]); }
  for (const t of times) {
    const run = E => { const pl = E.makePlaylist(c.id, ms.map(([m, pf, p]) => E.versionFrom(structuredClone(m), pf && structuredClone(pf), p))); const out = []; let k = 0; for (const n of E.walk(pl, t)) { if (k++ >= 15) break; out.push(n); } return out; };
    const a = run(ORIG), b = run(LOW);
    a.forEach((x, i) => sig(x) === sig(b[i]) ? same++ : (diff++, diff < 4 && console.log('DIFF', c.id, sig(x), sig(b[i]))));
    if (t === now) { const va = a.find(n => n.item.type === 'video'), vb = b.find(n => n.item.type === 'video'); if (va) { const [ua, ub] = await Promise.all([ORIG.mediaUrl(va.item), LOW.mediaUrl(vb.item)]); ua === ub ? urls++ : console.log('URL DIFF', c.id, ua, ub); } }
  }
}
console.log({ channels: L.channels.length, same, diff, mediaUrlsMatched: urls });
