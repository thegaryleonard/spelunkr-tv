// Run the LG app (or the diagnostics app) on a PC in an old Chromium, to check compatibility with older webOS TVs.
// usage: node tools/oldtv/server.mjs <appDir> [port]
//   then open http://localhost:<port>/index.html in e.g. Chromium 68 (= webOS 5) with --remote-debugging-port.
// The TV's luna services are faked by shim.js; data requests go to data.spelunkr.tv identified as spelunkr-lg-test.
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(process.argv[2] || path.join(HERE, '../../app'));
const PORT = +(process.argv[3] || 8899);
const UA = 'spelunkr-lg-test/1.0';
const HOST_OK = /^(data\.spelunkr\.tv|audio\.spelunkr\.tv|archive\.org|([a-z0-9-]+\.)+archive\.org)$/;
const TYPES = { '.html': 'text/html', '.js': 'application/javascript', '.css': 'text/css', '.png': 'image/png', '.ttf': 'font/ttf', '.json': 'application/json' };

async function upstream(url, range, maxBytes) {
  const u = new URL(url);
  if (u.protocol !== 'https:' || !HOST_OK.test(u.hostname)) return { error: 'host not allowed' };
  const t0 = Date.now(), headers = { 'User-Agent': UA };
  if (range) headers.Range = 'bytes=' + range;
  try {
    const r = await fetch(url, { headers, redirect: 'follow' });
    const ttfb = Date.now() - t0;
    const buf = Buffer.from(await r.arrayBuffer());
    const total = Date.now() - t0;
    const h = {}; for (const k of ['date', 'cf-ray', 'cf-cache-status', 'content-type', 'server']) if (r.headers.get(k)) h[k] = r.headers.get(k);
    return { status: r.status, headers: h, bytes: buf.length, body: buf.toString('utf8'), ip: null, url: r.url,
      timing: { dns: null, connect: null, tls: null, ttfb, total }, mbps: buf.length > 100000 ? Math.round(buf.length * 8 / Math.max(1, total - ttfb) / 10) / 100 : null,
      hops: [{ url, status: r.redirected ? 302 : r.status }].concat(r.redirected ? [{ url: r.url, status: r.status }] : []) };
  } catch (e) { return { error: String(e.cause && e.cause.code || e.message) }; }
}

http.createServer(async (req, res) => {
  const u = new URL(req.url, 'http://x');
  if (u.pathname === '/__svc') {
    const body = await new Promise(r => { let s = ''; req.on('data', d => s += d).on('end', () => r(s)); });
    const { uri, params } = JSON.parse(body);
    let out;
    const m = uri.match(/^luna:\/\/([^/]+)\/(.+)$/) || [];
    const [svc, method] = [m[1], m[2]];
    if (/^tv\.spelunkr\.(app|diag)\.service$/.test(svc)) {
      if (method === 'get') { const r = await upstream('https://data.spelunkr.tv/' + params.path); out = r.error ? { returnValue: false, errorText: r.error } : { returnValue: true, status: r.status, date: r.headers.date, body: r.body }; }
      else if (method === 'probe') { const r = await upstream(params.url, params.range, params.maxBytes); if (!params.bodyText) delete r.body; out = Object.assign({ returnValue: true }, r); }
      else if (method === 'dns') out = { returnValue: true, host: params.host, ms: 0, error: null, addrs: ['(pc test)'] };
      else if (method === 'about' || method === 'version') out = { returnValue: true, userAgent: UA, node: '(pc test)', uptimeS: 0, interfaces: [{ name: 'pc', address: '127.0.0.1' }], freeMemMB: 0 };
      else out = { returnValue: false, errorText: 'unknown method' };
    } else out = { returnValue: false, errorText: 'not available on PC' };
    res.setHeader('content-type', 'application/json'); res.end(JSON.stringify(out)); return;
  }
  if (u.pathname === '/__shim.js') { res.setHeader('content-type', TYPES['.js']); res.end(fs.readFileSync(path.join(HERE, 'shim.js'))); return; }
  const f = path.join(ROOT, decodeURIComponent(u.pathname === '/' ? '/index.html' : u.pathname));
  if (!f.startsWith(ROOT) || !fs.existsSync(f) || fs.statSync(f).isDirectory()) { res.statusCode = 404; res.end('404'); return; }
  let data = fs.readFileSync(f);
  if (f.endsWith('index.html')) data = Buffer.from(data.toString('utf8').replace(/<script/, '<script src="/__shim.js"></script>\n<script'));
  res.setHeader('content-type', TYPES[path.extname(f)] || 'application/octet-stream');
  res.end(data);
}).listen(PORT, () => console.log(`serving ${ROOT} on http://localhost:${PORT}/`));
