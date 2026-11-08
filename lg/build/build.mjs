// Build: extract the schedule engine from the live Spelunkr bundle into app/js/engine.js, then package.
// usage: node build.mjs [--no-fetch]
import fs from 'node:fs';
import { execSync } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..').replace(/\\/g, '/');
const ROOTS = 'on,ho,lo,g0,ev,ll,Ks,At,ao,co,Wc,ul,OS,$S';
const NAMES = { on: 'nowAt', ho: 'walk', lo: 'addVersion', g0: 'makePlaylist', ev: 'versionFrom', ll: 'inPoint', Ks: 'mediaUrl', At: 'isAd', ao: 'isBreak', co: 'isVideo', Wc: 'runtime', ul: 'palette', OS: 'pixelRects', $S: 'pixelSize' };

fs.mkdirSync(`${ROOT}/research`, { recursive: true });
if (!process.argv.includes('--no-fetch')) {
  const html = await (await fetch('https://spelunkr.tv/')).text();
  const js = html.match(/\/assets\/index-[^"]+\.js/)[0];
  fs.writeFileSync(`${ROOT}/research/bundle.js`, await (await fetch('https://spelunkr.tv' + js)).text());
  console.log('bundle:', js);
}
execSync(`node extract.mjs ${ROOT}/research/bundle.js engine.raw.js ${ROOTS}`, { cwd: `${ROOT}/build`, stdio: 'inherit' });
let eng = fs.readFileSync(`${ROOT}/build/engine.raw.js`, 'utf8').replace(/\nexport \{[^}]*\};\s*$/, '\n');
const map = ROOTS.split(',').map(k => `${NAMES[k]}: ${k}`).join(', ');
eng = `/* Spelunkr schedule engine — extracted verbatim from spelunkr.tv's bundle by build/build.mjs. Do not edit. */\n(function(){\n${eng}\nwindow.SpelunkrEngine = { ${map} };\n})();\n`;
fs.writeFileSync(`${ROOT}/app/js/engine.js`, eng);
console.log('engine.js', eng.length, 'chars');

for (const f of fs.readdirSync(ROOT)) if (f.endsWith('.ipk')) fs.unlinkSync(`${ROOT}/${f}`);
execSync(`ares-package ${ROOT}/app -o ${ROOT}`, { stdio: 'inherit' });
