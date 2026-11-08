// Node test: compute what's on every channel right now using the extracted engine.
import { on, ho, g0, ev, ll, Ks, co, Wc } from './engine.raw.js';
const D = 'https://data.spelunkr.tv/';
const j = u => fetch(D + u).then(r => r.json());
const lineup = await j('lineup.json');
const now = Date.now();
for (const ch of lineup.channels.slice(0, 40)) {
  if (!ch.versions?.length) continue;
  let cur = null; for (const p of ch.versions) if (p.effectiveAtMs <= now && (!cur || p.v > cur.v)) cur = p;
  const ptrs = cur ? ch.versions.filter(p => p.v >= cur.v) : ch.versions;
  try {
    const vers = [];
    for (const p of ptrs) { const m = await j(p.manifest); const plat = m.platform ? await j(m.platform) : null; vers.push(ev(m, plat, p)); }
    const pl = g0(ch.id, vers);
    const n = on(pl, now);
    const it = n.item;
    const url = await Ks(it);
    console.log(`${String(ch.dial ?? '-').padStart(3)} ${ch.name.padEnd(22)} ${it.type.padEnd(10)} ${(it.title || it.slice?.tape || '').slice(0, 40).padEnd(40)} off=${n.offset}s rem=${Math.round(n.remaining)}s seek=${co(it) || it.type === 'ad' ? (ll(it) + n.offsetExact).toFixed(1) : '-'} ${url ? url.slice(0, 70) : ''} ${ch.comingSoon ? 'SOON' : ''}${ch.debugOnly ? 'DEBUG' : ''}`);
  } catch (e) { console.log(ch.id, 'ERR', e.message); }
}
