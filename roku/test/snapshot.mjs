// Snapshot lineup + every manifest/platform file into fixtures/ (same relative paths as data.spelunkr.tv)
import fs from 'node:fs'; import path from 'node:path';
const D='https://data.spelunkr.tv/', OUT='fixtures/';
const save=async p=>{const t=await (await fetch(D+p)).text(); fs.mkdirSync(path.dirname(OUT+p),{recursive:true}); fs.writeFileSync(OUT+p,t); return JSON.parse(t);};
const L=await save('lineup.json'); const plats=new Set(); const info=[];
for (const c of L.channels) for (const v of c.versions||[]) { const m=await save(v.manifest); if(m.platform&&!plats.has(m.platform)){plats.add(m.platform); await save(m.platform);}
  info.push(`${c.id} v${v.v} engine=${m.engine} items=${m.items.length} bumps=${(m.bumps||[]).length} audio=${(m.audio||[]).length} overlay=${!!m.audioOverlay} pools=${m.audioPools?Object.keys(m.audioPools).join('/'):''} block=${!!m.block} ads=${m.ads?m.ads.slices.length:0} file=${m.items.filter(i=>i.file).length} mp4=${m.items.filter(i=>i.mp4).length} bare=${m.items.filter(i=>!i.file&&!i.mp4).length} seasonal=${(m.bumps||[]).filter(b=>b.date_range).length}`); }
console.log(info.join('\n')); console.log('platforms', [...plats]);
