/* Spelunkr for webOS — a remote-first (▲▼◀▶ OK BACK) player for spelunkr.tv.
 * Schedule math comes from the site's own engine (js/engine.js, extracted by build/build.mjs),
 * so what plays here is what plays on the website at the same moment. */
(function () {
  'use strict';
  var E = window.SpelunkrEngine;
  var DATA = 'https://data.spelunkr.tv/';
  var $ = function (id) { return document.getElementById(id); };
  var video = $('video'), audio = $('audio');

  // ---------------------------------------------------------------- data access
  // All JSON comes from data.spelunkr.tv through the app's own webOS service (service/service.js),
  // because the gate wants the client to name itself in its User-Agent ("spelunkr-lg/<ver>") and the
  // web runtime can't set one. Agreed with the Spelunkr devs.
  var SERVICE = 'luna://tv.spelunkr.app.service/get';
  var bridges = [];   // keep bridges referenced until they answer
  var stats = {};   // request counts per path (debug: window.__spelunkr.stats())
  function luna(uri, params) {
    if (params && params.path) stats[params.path] = (stats[params.path] || 0) + 1;
    return new Promise(function (resolve, reject) {
      var b = new PalmServiceBridge(), done = false;
      bridges.push(b);
      var t = setTimeout(function () { finish(null, new Error('service timeout')); }, 20000);
      function finish(r, err) {
        if (done) return;
        done = true; clearTimeout(t);
        bridges.splice(bridges.indexOf(b), 1);
        if (err) reject(err); else resolve(r);
      }
      b.onservicecallback = function (msg) {
        var r; try { r = JSON.parse(msg); } catch (e) { return finish(null, e); }
        if (r.returnValue === false) finish(null, new Error(r.errorText || 'service error'));
        else finish(r);
      };
      b.call(uri, JSON.stringify(params || {}));
    });
  }
  var jsonCache = {};   // manifests/platform files are immutable per version
  function getJSON(path, fresh) {
    if (!fresh && jsonCache[path]) return Promise.resolve(JSON.parse(jsonCache[path]));
    return luna(SERVICE, { path: path }).then(function (r) {
      if (r.status !== 200) throw new Error('HTTP ' + r.status + ' ' + path);
      if (!fresh) jsonCache[path] = r.body;
      return JSON.parse(r.body);
    });
  }

  // ---------------------------------------------------------------- clock (from live.json, no extra requests)
  var skew = 0;
  function nowMs() { return Date.now() + skew; }
  function clockFromLive(httpDate, written, sentAt, gotAt) {
    var mid = sentAt + (gotAt - sentAt) / 2;
    var d = Date.parse(httpDate || '');
    if (isFinite(d)) {
      // Date header has 1 s resolution: only correct clocks that are clearly off.
      var s = d + 500 - mid;
      skew = Math.abs(s) > 1500 ? s : 0;
      return;
    }
    var w = Date.parse(written || '');
    if (isFinite(w) && mid + skew < w - 2000) skew = w - mid;   // we're behind a file that already exists
  }

  // ---------------------------------------------------------------- data
  var audioBase = 'https://audio.spelunkr.tv/bumps/';
  var channels = [];
  var knownSum = null;          // sum of the newest version of every lineup channel (= live.json publicVersionSum)
  var knownVersions = {};       // "channel:v" -> 1
  function loadLineup() {
    return getJSON('lineup.json', true).then(function (L) {
      if (L.audioBase) audioBase = L.audioBase;
      var sum = 0;
      (L.channels || []).forEach(function (c) {
        var mx = 0;
        (c.versions || []).forEach(function (p) { knownVersions[c.id + ':' + p.v] = 1; if (p.v > mx) mx = p.v; });
        sum += mx;
      });
      knownSum = sum;
      var byId = {};
      channels.forEach(function (c) { byId[c.id] = c; });
      var list = [];
      (L.channels || []).forEach(function (c) {
        if (c.debugOnly || c.comingSoon || !c.versions || !c.versions.length) return;
        var ch = byId[c.id] || { id: c.id, pointers: [], playlist: null, loading: null, logos: {} };
        ch.name = c.name; ch.color = c.color; ch.logomark = c.logomark; ch.dial = c.dial; ch.description = c.description || '';
        c.versions.forEach(function (p) {
          if (!ch.pointers.some(function (q) { return q.v === p.v; })) { ch.pointers.push(p); ch.fresh = true; }
        });
        ch.pointers.sort(function (a, b) { return a.v - b.v; });
        list.push(ch);
      });
      list.sort(function (a, b) { return (a.dial == null ? 1e9 : a.dial) - (b.dial == null ? 1e9 : b.dial); });
      channels = list;
      channels.forEach(function (ch) { if (ch.playlist && ch.fresh) addNewVersions(ch); });
    });
  }
  function relevantPointers(ch, t) {
    var cur = null;
    ch.pointers.forEach(function (p) { if (p.effectiveAtMs <= t && (!cur || p.v > cur.v)) cur = p; });
    return cur ? ch.pointers.filter(function (p) { return p.v >= cur.v; }) : ch.pointers.slice();
  }
  function buildVersion(p) {
    return getJSON(p.manifest).then(function (m) {
      if (m.engine > 5) throw new Error('needs a newer app (engine ' + m.engine + ')');
      return (m.platform ? getJSON(m.platform) : Promise.resolve(null)).then(function (plat) { return E.versionFrom(m, plat, p); });
    });
  }
  function ensurePlaylist(ch) {
    if (ch.playlist) return Promise.resolve(ch.playlist);
    if (!ch.loading) {
      ch.loading = Promise.all(relevantPointers(ch, nowMs()).map(function (p) {
        return buildVersion(p).then(function (v) { return { ok: v }; }, function (e) { return { err: e }; });
      })).then(function (res) {
        var vs = res.filter(function (r) { return r.ok; }).map(function (r) { return r.ok; });
        if (!vs.length) throw (res[0] && res[0].err) || new Error('no versions');
        ch.playlist = E.makePlaylist(ch.id, vs);
        ch.fresh = false;
        return ch.playlist;
      });
      ch.loading.then(function () { ch.loading = null; }, function () { ch.loading = null; });
    }
    return ch.loading;
  }
  function addNewVersions(ch) {
    ch.fresh = false;
    var have = {};
    ch.playlist.versions.forEach(function (v) { have[v.v] = 1; });
    relevantPointers(ch, nowMs()).forEach(function (p) {
      if (have[p.v]) return;
      buildVersion(p).then(function (v) { E.addVersion(ch.playlist, v); }).catch(function () {});
    });
  }
  // live.json heartbeat: once a minute; lineup.json + new manifests only when it shows a new version
  function pollLive() {
    var sent = Date.now();
    return luna(SERVICE, { path: 'live.json' }).then(function (r) {
      if (r.status !== 200) throw new Error('HTTP ' + r.status + ' live.json');
      var live = JSON.parse(r.body);
      clockFromLive(r.date, live.written, sent, Date.now());
      var changed = false;
      if (typeof live.publicVersionSum === 'number' && knownSum !== null && live.publicVersionSum !== knownSum) changed = true;
      if (live.latest && live.latest.channel_id && !knownVersions[live.latest.channel_id + ':' + live.latest.version]) changed = true;
      (live.versions || []).forEach(function (v) { if (v && v.channel_id && !knownVersions[v.channel_id + ':' + v.version]) changed = true; });
      if (changed) return loadLineup();
    }).catch(function () {});
  }

  // current + next *show* (skips bumps / up-next cards / ads)
  function nowNext(ch, t) {
    if (!ch.playlist) return null;
    var now = null, next = null, k = 0, it = E.walk(ch.playlist, t);
    while (k++ < 300) {
      var n = it.next().value;
      if (!n) break;
      if (n.item.type !== 'video') continue;
      if (!now) now = n; else { next = n; break; }
    }
    return { now: now, next: next };
  }

  // ---------------------------------------------------------------- formatting
  function clock(ms) {
    var d = new Date(ms), h = d.getHours(), m = d.getMinutes();
    return ((h % 12) || 12) + ':' + (m < 10 ? '0' : '') + m + ' ' + (h < 12 ? 'AM' : 'PM');
  }
  function dur(sec) {
    sec = Math.max(0, Math.round(sec));
    var h = Math.floor(sec / 3600), m = Math.floor(sec % 3600 / 60);
    return h ? h + ' HR ' + m + ' MIN' : (m || 1) + ' MIN';
  }
  function num(ch) { return ch.dial == null ? '--' : ch.dial < 100 ? ('0' + ch.dial).slice(-2) : String(ch.dial); }
  function esc(s) { return String(s == null ? '' : s).replace(/[&<>"]/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]; }); }
  function logo(ch, size) {
    if (!ch || !ch.logomark || !ch.logomark.rows) return '';
    if (ch.logos[size]) return ch.logos[size];
    var rows = ch.logomark.rows, n = rows.length, pal = E.palette(ch.color);
    var s = '<svg width="' + size + '" height="' + size + '" viewBox="0 0 ' + n + ' ' + n + '" shape-rendering="crispEdges">';
    E.pixelRects(rows).forEach(function (r) {
      s += '<rect x="' + r.x + '" y="' + r.y + '" width="' + r.w + '" height="' + r.h + '" fill="' + (pal[r.t] || pal.p) + '"/>';
    });
    return (ch.logos[size] = s + '</svg>');
  }
  // the 8s fonts have no dashes: swap them for plain hyphens
  function title(item) { return String((item && (item.title || item.id)) || '').replace(/\s*[‒-―]\s*/g, ' - '); }
  function withYear(item) {
    var t = title(item), y = item && item.year;
    return y && t.indexOf(String(y).slice(-2)) < 0 ? t + '  (' + y + ')' : t;
  }

  // ---------------------------------------------------------------- full-screen card + static
  var card = $('card'), staticCanvas = $('static'), staticRaf = null;
  function drawStatic() {
    var ctx = staticCanvas.getContext('2d'), img = ctx.createImageData(192, 108), d = img.data, last = 0;
    function frame(ts) {
      if (ts - last > 50) {
        last = ts;
        for (var i = 0; i < d.length; i += 4) { var v = Math.random() * 255 | 0; d[i] = d[i + 1] = d[i + 2] = v; d[i + 3] = 255; }
        ctx.putImageData(img, 0, 0);
      }
      staticRaf = requestAnimationFrame(frame);
    }
    if (!staticRaf) staticRaf = requestAnimationFrame(frame);
  }
  function setCard(o) {
    card.classList.remove('hidden');
    card.classList.toggle('static', !!o.static);
    if (o.static) drawStatic(); else if (staticRaf) { cancelAnimationFrame(staticRaf); staticRaf = null; }
    $('card-logo').innerHTML = o.logo || '';
    $('card-kicker').textContent = o.kicker || '';
    $('card-text').textContent = o.text || '';
    $('card-sub').innerHTML = o.sub || '';
  }
  function hideCard() {
    card.classList.add('hidden');
    if (staticRaf) { cancelAnimationFrame(staticRaf); staticRaf = null; }
  }

  // ---------------------------------------------------------------- player
  var cur = null, entry = null, seq = 0, timer = null, cardTimer = null, loadedUrl = null, mediaSince = 0, retryTimer = null;

  function stopVideo() { video.pause(); video.removeAttribute('src'); try { video.load(); } catch (e) {} loadedUrl = null; }
  function stopAudio() { audio.pause(); audio.removeAttribute('src'); audio._key = null; }
  function clearTimers() { clearTimeout(timer); clearInterval(cardTimer); clearTimeout(retryTimer); cardTimer = null; }

  function tune(ch) {
    var my = ++seq;
    cur = ch; entry = null;
    try { localStorage.setItem('spelunkr-tv-last', ch.id); } catch (e) {}
    clearTimers(); stopVideo(); stopAudio();
    setCard({ static: true, text: 'ADJUSTING THE ANTENNA…' });
    showBanner();
    ensurePlaylist(ch).then(function () { if (my === seq) play(my); }, function () {
      if (my !== seq) return;
      setCard({ logo: logo(ch, 160), kicker: 'CH ' + num(ch) + ' · ' + ch.name, text: 'NO SIGNAL', sub: 'trying again in a few seconds…' });
      retryTimer = setTimeout(function () { if (my === seq) tune(ch); }, 10000);
    });
  }

  function play(my) {
    if (my !== seq) return;
    clearTimers();
    if (cur.fresh) addNewVersions(cur);
    var n;
    try { n = E.nowAt(cur.playlist, nowMs()); } catch (e) { setCard({ text: 'NO SIGNAL' }); return; }
    entry = n;
    if (n.item.type === 'video' || n.item.type === 'ad') playMedia(my, n); else playCard(my, n);
    timer = setTimeout(function () { play(my); }, Math.max(250, n.endMs - nowMs() + 30));
    if (bannerShown()) renderBanner();
  }

  function target(n) { return E.inPoint(n.item) + (nowMs() - n.startMs) / 1000; }

  function playMedia(my, n) {
    stopAudio();
    E.mediaUrl(n.item).then(function (url) {
      if (my !== seq || entry !== n) return;
      if (!url) throw new Error('no url');
      var gain = n.item.type === 'ad' && n.item.slice && n.item.slice.gainDb;
      video.volume = gain ? Math.min(1, Math.pow(10, gain / 20)) : 1;
      if (loadedUrl === url && video.readyState >= 1) {
        if (Math.abs(video.currentTime - target(n)) > 2) video.currentTime = target(n);
        video.play().catch(function () {});
        return;
      }
      if (card.classList.contains('hidden')) setCard({ static: true, text: 'ADJUSTING THE ANTENNA…' });
      loadedUrl = url; mediaSince = Date.now();
      video.src = url + '#t=' + Math.floor(target(n));
      video.onloadedmetadata = function () {
        if (entry !== n) return;
        video.currentTime = target(n);
        video.play().catch(function () {});
      };
    }).catch(function () { noSignal(my, n); });
  }

  function noSignal(my, n) {
    if (my !== seq || entry !== n) return;
    stopVideo();
    setCard({ logo: logo(cur, 160), kicker: 'CH ' + num(cur) + ' · ' + cur.name, text: 'NO SIGNAL',
      sub: esc(title(n.item)) + '<br>this tape won\'t play right now — retrying…' });
    clearTimeout(retryTimer);
    retryTimer = setTimeout(function () { if (my === seq) play(my); }, 12000);
  }

  video.addEventListener('playing', function () {
    if (entry && (entry.item.type === 'video' || entry.item.type === 'ad')) hideCard();
  });
  video.addEventListener('error', function () {
    if (!video.getAttribute('src') || !entry) return;
    noSignal(seq, entry);
  });

  // watchdog: stalls and drift
  setInterval(function () {
    if (!entry || !(entry.item.type === 'video' || entry.item.type === 'ad') || !loadedUrl || document.hidden) return;
    var want = target(entry);
    if (video.readyState >= 3 && !video.paused) {
      mediaSince = Date.now();
      if (Math.abs(video.currentTime - want) > 6) video.currentTime = want;
    } else if (Date.now() - mediaSince > 30000) {
      loadedUrl = null; play(seq);  // stuck for 30 s: reload the tape at the live point
    } else if (video.paused && video.readyState >= 2) {
      video.play().catch(function () {});
    }
  }, 5000);

  // ---------------------------------------------------------------- bumps & up-next cards
  function slideMs(text) { return Math.max(2500, 1500 + String(text).length * 55); }
  function bumpSegments(item) {
    var segs = [], t = 0, ch = cur;
    function add(ms, o) { segs.push({ a: t, b: t + ms, o: o }); t += ms; }
    function slides(bump, who) {
      (bump.slides || []).forEach(function (s, i, all) {
        var last = i === all.length - 1;
        add(slideMs(s.text) + (last ? 2000 : 0), { logo: who === 'ch' ? logo(ch, 120) : spelunkrLogo(), text: s.text });
      });
    }
    var audioPlan = [];
    if (item.channelBump) {
      var a0 = t;
      add(3500, { logo: logo(ch, 260), kicker: 'CHANNEL ' + num(ch), text: ch.name });
      slides(item.channelBump, 'ch');
      if (item.channelAudio) audioPlan.push({ a: a0, b: t, track: item.channelAudio });
    }
    if (item.channelBump && item.platformBump) add(300, { text: '' });
    if (item.platformBump) {
      var a1 = t;
      slides(item.platformBump, 'sp');
      if (item.platformAudio) audioPlan.push({ a: a1, b: t, track: item.platformAudio });
    }
    return { segs: segs, audio: audioPlan };
  }
  function spelunkrLogo() { return '<span class="g-s" style="width:110px;height:110px;line-height:110px;font-size:96px">S</span>'; }

  function playCard(my, n) {
    stopVideo();
    var item = n.item, plan;
    if (item.type === 'up-next') {
      var nn = nowNext(cur, n.endMs + 1) || {};
      var sub = '';
      if (nn.now) sub += '<span class="k">NEXT</span>' + clock(nn.now.startMs) + '  ' + esc(title(nn.now.item));
      if (nn.next) sub += '<br><span class="k">LATER</span>' + clock(nn.next.startMs) + '  ' + esc(title(nn.next.item));
      plan = { segs: [{ a: 0, b: n.endMs - n.startMs, o: { logo: logo(cur, 160), kicker: 'UP NEXT ON ' + cur.name, text: nn.now ? title(nn.now.item) : cur.name, sub: sub } }],
        audio: item.sting ? [{ a: 0, b: item.durationMs, track: { filename: item.sting.track, startOffset: item.sting.startMs / 1000 } }] : [] };
    } else {
      plan = bumpSegments(item);
    }
    var shown = -1;
    function tick() {
      if (my !== seq || entry !== n) { clearInterval(cardTimer); return; }
      var el = nowMs() - n.startMs, i;
      for (i = 0; i < plan.segs.length - 1 && el >= plan.segs[i].b; i++);
      if (i !== shown) { shown = i; var s = plan.segs[i]; setCard(s ? s.o : { text: cur.name }); }
      var ap = null;
      plan.audio.forEach(function (p) { if (el >= p.a && el < p.b) ap = p; });
      if (ap) playTrack(ap.track, (el - ap.a) / 1000); else if (audio._key) stopAudio();
    }
    tick();
    cardTimer = setInterval(tick, 200);
  }
  function playTrack(track, into, fallbackIdx) {
    var list = [track].concat(track.fallbacks || []);
    var idx = fallbackIdx || 0, t = list[idx];
    if (!t) return;
    var key = track.filename + '|' + idx;
    if (audio._key === key || audio._key === track.filename + '|*') return;
    audio._key = key;
    audio.src = audioBase + encodeURIComponent(t.filename);
    audio.volume = 0.8;
    audio.onloadedmetadata = function () { audio.currentTime = (t.startOffset || track.startOffset || 0) + into; audio.play().catch(function () {}); };
    audio.onerror = function () { audio._key = null; if (idx + 1 < list.length) playTrack(track, into, idx + 1); else audio._key = track.filename + '|*'; };
  }

  // ---------------------------------------------------------------- banner
  var banner = $('banner'), bannerTimer = null;
  function bannerShown() { return !banner.classList.contains('hidden'); }
  function showBanner(ms) {
    banner.classList.remove('hidden');
    renderBanner();
    clearTimeout(bannerTimer);
    bannerTimer = setTimeout(hideBanner, ms || 6000);
  }
  function hideBanner() { banner.classList.add('hidden'); clearTimeout(bannerTimer); }
  function renderBanner() {
    if (!cur) return;
    var t = nowMs();
    $('b-num').textContent = num(cur);
    $('b-logo').innerHTML = logo(cur, 88);
    $('b-name').textContent = cur.name;
    $('b-clock').textContent = clock(t);
    var nn = nowNext(cur, t);
    if (!nn || !nn.now) {
      $('b-now').textContent = 'ADJUSTING THE ANTENNA…'; $('b-now-time').textContent = '';
      $('b-next').textContent = ''; $('b-next-time').textContent = ''; $('b-progress').style.width = '0';
      return;
    }
    var onBreak = entry && entry.item.type !== 'video' && nn.now.startMs > t;
    $('b-now').textContent = onBreak ? 'WE\'LL BE RIGHT BACK' : withYear(nn.now.item);
    $('b-now-time').textContent = onBreak ? 'BACK AT ' + clock(nn.now.startMs) : dur((nn.now.endMs - t) / 1000) + ' LEFT';
    var pct = onBreak ? 0 : (t - nn.now.startMs) / (nn.now.endMs - nn.now.startMs) * 100;
    $('b-progress').style.width = Math.max(0, Math.min(100, pct)) + '%';
    var nx = onBreak ? nn.now : nn.next;
    $('b-next').textContent = nx ? title(nx.item) : '';
    $('b-next-time').textContent = nx ? clock(nx.startMs) : '';
  }

  // ---------------------------------------------------------------- guide
  var guide = $('guide'), rowsEl = $('g-rows'), sel = 0, top = 0, VISIBLE = 6;
  function guideOpen() { return !guide.classList.contains('hidden'); }
  function openGuide() {
    hideBanner();
    sel = Math.max(0, channels.indexOf(cur));
    top = Math.max(0, Math.min(sel - 2, channels.length - VISIBLE));
    guide.classList.remove('hidden');
    document.body.classList.add('guide-open');
    renderGuide();
  }
  function closeGuide() { guide.classList.add('hidden'); document.body.classList.remove('guide-open'); }
  function moveSel(d) {
    sel = (sel + d + channels.length) % channels.length;
    if (sel < top) top = sel;
    if (sel >= top + VISIBLE) top = sel - VISIBLE + 1;
    renderGuide();
  }
  function renderGuide() {
    var t = nowMs(), html = '';
    $('g-clock').textContent = clock(t);
    for (var i = top; i < Math.min(channels.length, top + VISIBLE); i++) {
      var ch = channels[i], nn = ch.playlist ? nowNext(ch, t) : null;
      if (!ch.playlist) ensurePlaylist(ch).then(function () { if (guideOpen()) renderGuide(); }, function () {});
      var nowT = nn && nn.now ? esc(title(nn.now.item)) : 'ADJUSTING THE ANTENNA…';
      var nowM = nn && nn.now ? (nn.now.startMs > t ? 'STARTS ' + clock(nn.now.startMs) : dur((nn.now.endMs - t) / 1000) + ' LEFT' + (nn.now.item.year ? ' · ' + esc(nn.now.item.year) : '')) : '';
      var nxT = nn && nn.next ? esc(title(nn.next.item)) : '';
      var nxM = nn && nn.next ? clock(nn.next.startMs) : '';
      html += '<div class="g-row' + (i === sel ? ' sel' : '') + (ch === cur ? ' playing' : '') + '">' +
        '<div class="g-ch"><span class="g-num">' + num(ch) + '</span>' + logo(ch, 56) + '<span class="g-name">' + esc(ch.name) + '</span></div>' +
        '<div class="g-cell now"><div class="g-t">' + nowT + '</div><div class="g-m">' + nowM + '</div></div>' +
        '<div class="g-cell next"><div class="g-t">' + nxT + '</div><div class="g-m">' + nxM + '</div></div></div>';
    }
    rowsEl.innerHTML = html;
    renderPreview();
  }
  function renderPreview() {
    var ch = channels[sel], p = $('g-preview');
    if (!p || !ch) return;
    var nn = ch.playlist ? nowNext(ch, nowMs()) : null;
    p.innerHTML = '<div class="p-head">' + logo(ch, 72) + '<span class="p-num">' + num(ch) + '</span><span class="p-name">' + esc(ch.name) + '</span></div>' +
      '<div class="p-now">' + (nn && nn.now ? esc(withYear(nn.now.item)) : '') + '</div>' +
      '<div class="p-desc">' + esc(String(ch.description || '').replace(/\s*[\u2012-\u2015]\s*/g, ' - ')) + '</div>' +
      (ch === cur ? '<div class="p-hint">NOW WATCHING</div>' : '<div class="p-hint">PRESS OK TO TUNE IN</div>');
  }

  // ---------------------------------------------------------------- toast / exit
  var toastTimer = null, exitArmed = 0;
  function toast(msg, ms) {
    var t = $('toast');
    t.textContent = msg; t.classList.remove('hidden');
    clearTimeout(toastTimer);
    toastTimer = setTimeout(function () { t.classList.add('hidden'); }, ms || 2500);
  }
  function exitApp() {
    try { if (window.webOS && webOS.platformBack) return webOS.platformBack(); } catch (e) {}
    window.close();
  }

  // ---------------------------------------------------------------- channel flipping (debounced)
  var flipTimer = null, flipTo = null;
  function flip(d) {
    var base = flipTo || cur || channels[0];
    var i = channels.indexOf(base);
    flipTo = channels[(i + d + channels.length) % channels.length];
    // show where we're going right away; actually tune once the button stops being pressed
    var saved = cur; cur = flipTo; showBanner(); cur = saved;
    clearTimeout(flipTimer);
    flipTimer = setTimeout(function () { var ch = flipTo; flipTo = null; tune(ch); }, 450);
  }

  // ---------------------------------------------------------------- keys
  var K = { LEFT: 37, UP: 38, RIGHT: 39, DOWN: 40, OK: 13, BACK: 461, ESC: 27, BKSP: 8, CHUP: 33, CHDN: 34 };
  document.addEventListener('keydown', function (e) {
    var k = e.keyCode;
    if (!channels.length) { if (k === K.BACK || k === K.ESC) exitApp(); return; }
    var back = k === K.BACK || k === K.ESC || k === K.BKSP;
    e.preventDefault();
    if (guideOpen()) {
      if (k === K.UP) moveSel(-1);
      else if (k === K.DOWN) moveSel(1);
      else if (k === K.LEFT) moveSel(-VISIBLE);
      else if (k === K.RIGHT) moveSel(VISIBLE);
      else if (k === K.OK) { var ch = channels[sel]; closeGuide(); if (ch !== cur) tune(ch); else showBanner(); }
      else if (back) closeGuide();
      return;
    }
    if (k === K.UP || k === K.CHUP) flip(1);
    else if (k === K.DOWN || k === K.CHDN) flip(-1);
    else if (k === K.OK) openGuide();
    else if (k === K.LEFT || k === K.RIGHT) showBanner(8000);
    else if (back) {
      if (bannerShown()) { hideBanner(); return; }
      if (Date.now() - exitArmed < 3000) { exitApp(); return; }
      exitArmed = Date.now();
      toast('PRESS BACK AGAIN TO TURN OFF THE TV… ER, THE APP', 3000);
    }
  }, true);

  // ---------------------------------------------------------------- lifecycle
  document.addEventListener('visibilitychange', function () {
    if (document.hidden) { clearTimers(); stopVideo(); stopAudio(); }
    else if (cur) { pollLive(); tune(cur); }
  });
  setInterval(function () { if (bannerShown()) renderBanner(); if (guideOpen()) renderGuide(); }, 15000);
  setInterval(function () { if (!document.hidden) pollLive(); }, 60000);

  function preloadAll() {
    var q = channels.slice();
    function worker() { var ch = q.shift(); return ch ? ensurePlaylist(ch).catch(function () {}).then(worker) : null; }
    worker(); worker(); worker();
  }

  function start() {
    setCard({ static: true, text: 'ADJUSTING THE ANTENNA…' });
    Promise.all([pollLive(), loadLineup()]).then(function () {
      if (!channels.length) throw new Error('empty lineup');
      var last = null;
      try { last = localStorage.getItem('spelunkr-tv-last'); } catch (e) {}
      var ch = channels.filter(function (c) { return c.id === last; })[0] || channels[0];
      tune(ch);
      setTimeout(preloadAll, 4000);
      if (!last) setTimeout(function () { toast('UP/DOWN: CHANGE CHANNEL  ·  OK: GUIDE  ·  LEFT/RIGHT: INFO', 6000); }, 2500);
    }).catch(function () {
      setCard({ text: 'NO SIGNAL', sub: 'can\'t reach spelunkr.tv — check the TV\'s internet.<br>trying again…' });
      setTimeout(start, 10000);
    });
  }
  window.__spelunkr = { stats: function () { return { requests: stats, skewMs: skew, knownSum: knownSum }; }, skew: function (ms) { skew = ms; }, channels: function () { return channels; }, cur: function () { return cur; }, entry: function () { return entry; }, tune: tune };
  start();
})();
