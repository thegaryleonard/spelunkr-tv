// Compare the previously shipped engine (old site bundle) with the current one on live data.
import * as NEW from './engine.node.mjs';
import * as OLDm from '../../roku/test/engine.js.mjs';
const OLD = { nowAt: OLDm.on, walk: OLDm.ho, makePlaylist: OLDm.g0, versionFrom: OLDm.ev };
const UA = { headers: { 'User-Agent': 'spelunkr-lg-build/1.0' } };
const D = 'https://data.spelunkr.tv/';
const cache = {};
const j = async p => cache[p] ??= await (await fetch(D + p, UA)).json();
const L = await j('lineup.json');
const now = Date.now(), times = [0, 3600e3, 86400e3, 7 * 86400e3].map(o => now + o);
const sig = n => { const i = n.item; return `${n.key}|${i.type}|${n.startMs}|${n.endMs}|${i.id || i.sliceIndex || (i.channelBump && i.channelBump.id) || ''}|${i.platformBump ? i.platformBump.id : ''}`; };
let same = 0, diff = 0, maxEngine = 0;
for (const c of L.channels) {
  const ms = []; for (const p of c.versions) { const m = await j(p.manifest); maxEngine = Math.max(maxEngine, m.engine); ms.push([m, m.platform ? await j(m.platform) : null, p]); }
  for (const t of times) {
    const run = E => { const pl = E.makePlaylist(c.id, ms.map(([m, pf, p]) => E.versionFrom(structuredClone(m), pf && structuredClone(pf), p))); const out = []; let k = 0; for (const n of E.walk(pl, t)) { if (k++ >= 15) break; out.push(sig(n)); } return out; };
    const a = run(OLD), b = run(NEW);
    a.forEach((x, i) => x === b[i] ? same++ : (diff++, diff < 4 && console.log('DIFF', c.id, x, '\n    ', b[i])));
  }
}
console.log({ channels: L.channels.length, same, diff, maxManifestEngine: maxEngine, lineupEngine: L.engine });
