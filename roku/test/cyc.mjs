import fs from 'node:fs'; import { on, g0, ev } from './engine.js.mjs';
const j=p=>JSON.parse(fs.readFileSync('fixtures/'+p,'utf8')); const L=j('lineup.json'); const c=L.channels.find(c=>c.id==='rocket-punch');
const vs=c.versions.map(p=>{const m=j(p.manifest);return ev(m,m.platform?j(m.platform):null,p)}); const pl=g0(c.id,vs);
on(pl, 1793498284943); const v=pl.versions[0]; const b=[...v.built.values()][0];
fs.writeFileSync('cyc_js.txt', b.entries.map(e=>`${e.key}|${e.type}|${e.durMs}|${e.type==='ad'?e.sliceIndex:e.type==='video'?e.id:(e.channelBump?e.channelBump.id:'')+'/'+(e.platformBump?e.platformBump.id:'')}`).join('\n')+'\n');
console.log(b.entries.length, v.epochMs, b.k);
