// CORS proxy for running the Roku app in the browser-based BrightScript simulator.
import http from 'node:http';
const map = { '/data/': 'https://data.spelunkr.tv/', '/audio/': 'https://audio.spelunkr.tv/bumps/', '/ia/': 'https://archive.org/' };
http.createServer(async (req, res) => {
  const pre = Object.keys(map).find(p => req.url.startsWith(p));
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Headers', '*');
  if (req.method === 'OPTIONS') { res.end(); return; }
  if (!pre) { res.statusCode = 404; res.end('no'); return; }
  try {
    const up = await fetch(map[pre] + req.url.slice(pre.length), { headers: req.headers.range ? { range: req.headers.range } : {} });
    res.statusCode = up.status;
    for (const h of ['content-type', 'content-range', 'accept-ranges']) if (up.headers.get(h)) res.setHeader(h, up.headers.get(h));
    res.end(Buffer.from(await up.arrayBuffer()));
  } catch (e) { res.statusCode = 502; res.end(String(e)); }
}).listen(8787, () => console.log('proxy on 8787'));
