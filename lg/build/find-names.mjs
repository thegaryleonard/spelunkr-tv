// Find the current minified names of the engine functions in a new Spelunkr bundle by content markers.
// usage: node find-names.mjs <bundle.js>
import fs from 'node:fs';
import * as acorn from 'acorn';
const src = fs.readFileSync(process.argv[2], 'utf8');
const ast = acorn.parse(src, { ecmaVersion: 'latest', sourceType: 'module' });
const units = [];
for (const st of ast.body) {
  if (st.type === 'FunctionDeclaration') units.push({ name: st.id.name, text: src.slice(st.start, st.end), gen: st.generator });
  else if (st.type === 'VariableDeclaration') for (const d of st.declarations) if (d.id.type === 'Identifier') units.push({ name: d.id.name, text: src.slice(d.start, d.end) });
}
const markers = {
  nowAt: t => t.includes('no published version'),
  walk: (t, u) => u.gen && /for\(;;\)\{const \w+=\w+\(\w+,\w+\);yield \w+,\w+=\w+\.endMs\}/.test(t),
  addVersion: t => t.includes('need whole seconds > 0') && t.includes('videoMs'),
  makePlaylist: t => /\{channelId:\w+,versions:\[\]\}/.test(t) && t.length < 200,
  versionFrom: t => t.includes('channelBumps:') && t.includes('platformBumps:') && t.includes('audioPools'),
  inPoint: t => t.includes('.slice.inMs/1e3') && t.length < 300,
  mediaUrl: t => t.includes('skipBaked'),
  isAd: t => /^\w+=\w+=>\(\w+==null\?void 0:\w+\.type\)==="ad"$/.test(t),
  isBreak: t => t.includes('"bump-break"') && t.includes('"up-next"') && t.includes('"ad"') && t.length < 250,
  isVideo: t => /^\w+=\w+=>\(\w+==null\?void 0:\w+\.type\)==="video"$/.test(t),
  runtime: t => /^\w+=\w+=>\(\w+\(\w+\)\?\w+\.outS:\w+\.duration\)-\(\w+\(\w+\)\?\w+\.inS:0\)$/.test(t),
  palette: t => t.includes('hueToward') && t.includes('return{') || (t.includes('.shade') && t.includes('.light') && t.includes('valueMul')),
  pixelRects: t => t.includes('-o}:${c}') || /`\$\{\w+\}:\$\{\w+-\w+\}:\$\{\w+\}`/.test(t),
  pixelSize: t => /\w+\*Math\.max\(1,Math\.floor\(\w+\/\w+\)\)/.test(t) && t.length < 120,
};
const found = {};
for (const [k, f] of Object.entries(markers)) {
  const hits = units.filter(u => { try { return f(u.text, u); } catch { return false; } });
  found[k] = hits.map(h => h.name);
}
console.log(JSON.stringify(found));
