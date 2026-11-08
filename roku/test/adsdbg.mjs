import fs from 'node:fs'; import { s0, Wi } from './ads.js.mjs';
const m=JSON.parse(fs.readFileSync('fixtures/manifests/rocket-punch/v10.json'));
const plan=s0(m.ads.slices, m.items, {block:null, gapMs:20*6e4, channelId:'rocket-punch', start:m.ads.start, decades:m.ads.decades});
const out=[];
out.push('start '+plan.start, 'cycle '+plan.rates.cycleMs+' total '+plan.rates.total);
out.push('phases '+plan.phases.slice(0,20).join(','));
for (const y of [null,1981,1985,1987,1992,2026]) for (const t of plan.tiers(y)) out.push(`tier ${y} tol=${t.tol} n=${t.list.length} round=${t.roundMs} healthy=${t.healthy} first=${t.list.slice(0,8).join(',')}`);
fs.writeFileSync('ads_js.txt', out.join('\n')+'\n'); console.log(out.join('\n'));
