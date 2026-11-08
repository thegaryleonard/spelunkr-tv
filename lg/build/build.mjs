// Build: extract the schedule engine from the live Spelunkr bundle into app/js/engine.js, then package
// the app + its data service into an .ipk.
// usage: node build.mjs [--no-fetch] [--no-package]
// The bundle's minified names change on every site deploy; find-names.mjs locates the functions by content.
import fs from 'node:fs';
import { execSync } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..').replace(/\\/g, '/');
const ORDER = ['nowAt', 'walk', 'addVersion', 'makePlaylist', 'versionFrom', 'inPoint', 'mediaUrl', 'isAd', 'isBreak', 'isVideo', 'runtime', 'palette', 'pixelRects', 'pixelSize'];
const UA = { 'User-Agent': 'spelunkr-lg-build/1.0' };

fs.mkdirSync(`${ROOT}/research`, { recursive: true });
if (!process.argv.includes('--no-fetch')) {
  const html = await (await fetch('https://spelunkr.tv/', { headers: UA })).text();
  const js = html.match(/\/assets\/index-[^"]+\.js/)[0];
  fs.writeFileSync(`${ROOT}/research/bundle.js`, await (await fetch('https://spelunkr.tv' + js, { headers: UA })).text());
  console.log('bundle:', js);
}
const found = JSON.parse(execSync(`node find-names.mjs ${ROOT}/research/bundle.js`, { cwd: `${ROOT}/build` }).toString());
const names = {};
for (const k of ORDER) {
  if (!found[k] || !found[k].length) throw new Error(`could not find ${k} in the bundle — the site's engine changed shape; update find-names.mjs`);
  names[k] = found[k][0];
}
console.log('engine names:', JSON.stringify(names));
const roots = ORDER.map(k => names[k]).join(',');
execSync(`node extract.mjs ${ROOT}/research/bundle.js engine.raw.js ${roots}`, { cwd: `${ROOT}/build`, stdio: 'inherit' });
const raw = fs.readFileSync(`${ROOT}/build/engine.raw.js`, 'utf8').replace(/\nexport \{[^}]*\};\s*$/, '\n');
// Node copy for tests (ESM, friendly names)
fs.writeFileSync(`${ROOT}/build/engine.node.mjs`, raw + `export { ${ORDER.map(k => `${names[k]} as ${k}`).join(', ')} };\n`);
// browser copy for the app
const eng = `/* Spelunkr schedule engine — extracted verbatim from spelunkr.tv's bundle by build/build.mjs. Do not edit. */\n(function(){\n${raw}\nwindow.SpelunkrEngine = { ${ORDER.map(k => `${k}: ${names[k]}`).join(', ')} };\n})();\n`;
fs.writeFileSync(`${ROOT}/app/js/engine.js`, eng);
console.log('engine.js', eng.length, 'chars');

if (process.argv.includes('--no-package')) process.exit(0);
for (const f of fs.readdirSync(ROOT)) if (f.endsWith('.ipk')) fs.unlinkSync(`${ROOT}/${f}`);
execSync(`ares-package ${ROOT}/app ${ROOT}/service -o ${ROOT}`, { stdio: 'inherit' });
