// Ground truth from the site's own JS engine: walks each channel from several instants and prints signatures.
import fs from 'node:fs';
import { on, ho, g0, ev } from './engine.js.mjs';
const F = 'fixtures/';
const j = p => JSON.parse(fs.readFileSync(F + p, 'utf8'));
const L = j('lineup.json');
const T0 = Number(fs.statSync(F + 'lineup.json').mtimeMs | 0) ;
const base = Math.floor(fs.statSync(F + 'lineup.json').mtimeMs);
const offs = [0, 3600e3, 6*3600e3, 86400e3, 3*86400e3, 7*86400e3, 13*86400e3, 21*86400e3, 1234567, 98765432];
const times = offs.slice(0, +(process.env.NT || offs.length)).map(o => base + o);
fs.writeFileSync('times.json', JSON.stringify({ times, steps: +(process.argv[2] || 20), only: process.argv[3] || '' }));
const only = process.argv[3] || '';
const sig = n => { const i = n.item, a = x => x ? `${x.filename}@${x.startOffset}/${x.fallbacks.map(f=>f.filename).join(',')}` : '-';
  let d = '';
  if (i.type === 'video') d = i.id;
  else if (i.type === 'up-next') d = i.sting ? i.sting.track : '-';
  else if (i.type === 'ad') d = `${i.sliceIndex}`;
  else d = `${i.half||''}|${i.channelBump?i.channelBump.id:'-'}|${i.platformBump?i.platformBump.id:'-'}|${a(i.channelAudio)}|${a(i.platformAudio)}`;
  return `${n.key}|${i.type}|${n.startMs}|${n.endMs}|${d}`; };
const lines = [];
for (const c of L.channels) {
  if (only && !only.split(',').includes(c.id)) continue;
  const vs = c.versions.map(p => { const m = j(p.manifest); if (m.engine > 5) return null; return ev(m, m.platform ? j(m.platform) : null, p); }).filter(Boolean);
  if (!vs.length) continue;
  for (const t of times) {
    const pl = g0(c.id, vs);   // fresh playlist per instant, like a cold app start
    let k = 0;
    for (const n of ho(pl, t)) { if (k++ >= +(process.argv[2] || 20)) break; lines.push(`${c.id}|${t}|${sig(n)}`); }
  }
}
fs.writeFileSync('expected.txt', lines.join('\n') + '\n');
console.log('expected lines', lines.length);
