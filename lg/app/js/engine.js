(function() {
  let av = 2500;
  let cv = 1500;
  let lv = 55;
  let mp = 300;
  let Sl = 3500;
  let Hs = 1e3;
  function vc(e) {
    return Math.max(av, cv + e.length * lv);
  }
  let uo = 1e3;
  let ho = (e) => e.reduce((t, n) => t + vc(n.text), 0);
  function hv(e, t) {
    return Sl + ho(e.slides) + Hs + uo + mp + ho(t.slides) + Hs + uo;
  }
  function cs(e) {
    let t = e | 0;
    return function() {
      t = t + 1831565813 | 0;
      let n = Math.imul(t ^ t >>> 15, 1 | t);
      return n ^= n + Math.imul(n ^ n >>> 7, 61 | n), ((n ^ n >>> 14) >>> 0) / 4294967296;
    };
  }
  function Xn(e) {
    let t = 0;
    for (let n = 0; n < e.length; n++) t = (t << 5) - t + e.charCodeAt(n) | 0;
    return t;
  }
  function yc(e, t) {
    const [n, r] = e;
    if (/^\d{4}-/.test(n)) return t >= Date.parse(`${n}T00:00:00Z`) && t <= Date.parse(`${r}T23:59:59.999Z`);
    const s = (u) => {
      const [d, f] = u.split("-").map(Number);
      return d * 100 + f;
    }, i = new Date(t), o = (i.getUTCMonth() + 1) * 100 + i.getUTCDate(), a = s(n), l = s(r);
    return a <= l ? o >= a && o <= l : o >= a || o <= l;
  }
  let hd = /* @__PURE__ */ new WeakMap();
  function vp(e) {
    let t = hd.get(e);
    if (!t) {
      const n = e.filter((r) => r.active !== false);
      t = { live: n, yearRound: n.filter((r) => !r.date_range), seasonal: n.filter((r) => r.date_range) }, hd.set(e, t);
    }
    return t;
  }
  function fd(e, t, n, r, s) {
    if (!e || e.length === 0) return null;
    const i = yp(e, s);
    if (i.length === 0) return null;
    const o = Xn(`${n}-break-${t}-${r}`), a = cs(o), l = Math.floor(a() * i.length);
    return i[l];
  }
  function yp(e, t) {
    const { live: n, yearRound: r, seasonal: s } = vp(e);
    return s.some((i) => yc(i.date_range, t)) ? n.filter((i) => !i.date_range || yc(i.date_range, t)) : r;
  }
  let fv = (e) => Math.floor(e / 2);
  function pv(e, t, n) {
    const r = cs(n), s = e.slice();
    for (let l = s.length - 1; l > 0; l--) {
      const u = Math.floor(r() * (l + 1));
      [s[l], s[u]] = [s[u], s[l]];
    }
    const i = fv(s.length), o = /* @__PURE__ */ new Map();
    for (let l = Math.min(i, t.length); l >= 1; l--) o.set(t[t.length - l], i + 1 - l);
    if (!o.size) return s;
    const a = (l) => {
      var _a;
      return (_a = o.get(l)) != null ? _a : 0;
    };
    for (let l = 1; l <= Math.min(i, t.length); l++) {
      const u = t[t.length - l], d = s.indexOf(u);
      if (d < 0 || d >= a(u)) continue;
      const f = [];
      for (let p = a(u); p < s.length; p++) a(s[p]) <= d && f.push(p);
      const h = f[Math.floor(r() * f.length)];
      [s[d], s[h]] = [s[h], s[d]];
    }
    return s;
  }
  function mv(e) {
    return e ? { order: e.order, pos: e.pos, key: e.key, recent: e.recent.slice(), rounds: 0 } : { order: [], pos: 0, key: null, recent: [], rounds: 0 };
  }
  function gv(e, t, n, r, s) {
    if (!t || t.length === 0) return null;
    const i = yp(t, s);
    if (i.length === 0) return null;
    const { seasonal: o } = vp(t), a = o.length ? o.filter((u) => yc(u.date_range, s)).map((u) => u.id).join("|") : "";
    (e.key !== a || e.pos >= e.order.length) && (e.order = pv(i, e.recent, Xn(`${n}-deck-${r}-${e.rounds++}`)), e.pos = 0, e.key = a);
    const l = e.order[e.pos++];
    return e.recent.push(l), e.recent.length > e.order.length && e.recent.shift(), l;
  }
  function pd(e, t, n, r) {
    if (!e || e.length === 0) return null;
    const s = Xn(`${t}-audio-${n}-${r}`), i = cs(s), o = Math.floor(i() * e.length), a = e[o], l = Math.floor(i() * 60), u = [];
    for (let d = 1; d < e.length && u.length < 3; d++) u.push(e[(o + d) % e.length]);
    return { ...a, startOffset: l, fallbacks: u };
  }
  function vv(e, t, n, r) {
    if (!e || e.length === 0) return null;
    const s = cs(Xn(`${n}-card-${t}-${r}`));
    return e[Math.floor(s() * e.length)];
  }
  let yv = [3, 6];
  let kl = 20 * 6e4;
  let md = 336 * 36e5;
  let Ut = 1e6;
  let Ci = 2e4;
  let bp = 24 * 36e5;
  let bv = 36e5;
  let fo = (e) => {
    const t = parseInt(e == null ? void 0 : e.year, 10);
    return Number.isFinite(t) ? t : null;
  };
  let _v = (e) => Math.floor(cs(Xn(`ad-${e.id}`))() * Ut);
  function wv(e) {
    const t = e.map(_v), n = new Array(e.length);
    return e.map((r, s) => s).sort((r, s) => t[r] - t[s] || (e[r].id < e[s].id ? -1 : e[r].id > e[s].id ? 1 : r - s)).forEach((r, s) => {
      n[r] = Math.floor(s * Ut / e.length);
    }), n;
  }
  function Sv(e, t) {
    return (Number.isInteger(e == null ? void 0 : e.start) && e.start >= 0 && e.start < 1e3 ? e.start : (Xn(`ads-${t}`) >>> 0) % 1e3) * (Ut / 1e3);
  }
  function kv(e, { block: t = null, gapMs: n = kl, sliceMs: r = 105e3 } = {}) {
    let s = 0, i = 0, o = 0, a = 0;
    const l = /* @__PURE__ */ new Map();
    return e.forEach((u, d) => {
      const f = u.duration * 1e3;
      if (s += f, i += f, o += f, t && d < e.length - 1 && o < t.lengthMs) {
        s += t.cardMs, i += t.cardMs, o += t.cardMs;
        return;
      }
      o = 0;
      const h = e[(d + 1) % e.length];
      u.offAir !== true && (h == null ? void 0 : h.offAir) !== true && i >= n ? (a += 1, l.set(fo(u), (l.get(fo(u)) || 0) + 1), s += Ci + r, i = Ci / 2) : (s += Ci, i += Ci);
    }), { cycleMs: s, total: a, byYear: l };
  }
  function Ev(e, t, { block: n = null, gapMs: r = kl, channelId: s = "", start: i, decades: o } = {}) {
    const a = wv(e), l = e.reduce((v, g) => v + g.lengthMs, 0) / e.length, u = kv(t, { block: n, gapMs: r, sliceMs: l }), d = e.map(fo), f = /* @__PURE__ */ new Map(), h = Number.isInteger(o) && o >= 1 ? `d${o}` : null, p = (v, g) => {
      const y = `${v}|${g}`;
      if (f.has(y)) return f.get(y);
      const _ = typeof g == "string" ? Number(g.slice(1)) : null, b = (I) => g === 1 / 0 || I != null && v != null && (_ != null ? Math.abs(Math.floor(I / 10) - Math.floor(v / 10)) <= _ : Math.abs(I - v) <= g), k = e.map((I, O) => O).filter((I) => e[I].anywhere === true || b(d[I])).sort((I, O) => a[I] - a[O] || (e[I].id < e[O].id ? -1 : e[I].id > e[O].id ? 1 : I - O));
      let $ = 0;
      for (const [I, O] of u.byYear) b(I) && ($ += O);
      const P = u.cycleMs > 0 ? $ * md / u.cycleMs : 0, x = k.length > 0 && k.length >= P, K = x || k.length === 0 ? md : Math.max(bv, Math.floor(k.length * u.cycleMs / $)), R = { tol: g, list: k, places: k.map((I) => a[I]), roundMs: K, healthy: x };
      return f.set(y, R), R;
    }, m = /* @__PURE__ */ new Map();
    return { phases: a, start: Sv({ start: i }, s), rates: u, tiers(v) {
      if (m.has(v)) return m.get(v);
      const g = v == null ? [p(null, 1 / 0)] : [...yv, ...h ? [h] : [], 1 / 0].map((_) => p(v, _)), y = g.slice(g.findIndex((_) => _.healthy || _.tol === 1 / 0));
      return m.set(v, y), y;
    } };
  }
  function gd(e, t, n) {
    const r = (e % t + t) % t;
    return (Math.floor(r * Ut / t) + n) % Ut;
  }
  function Tv(e, t) {
    let n = 0, r = e.length;
    for (; n < r; ) {
      const s = n + r >>> 1;
      e[s] < t ? n = s + 1 : r = s;
    }
    return n;
  }
  function Av(e, t, n, r, s = r) {
    t.size >= e.phases.length && t.clear();
    const i = e.tiers(n).filter((l) => l.list.length), o = (l) => (t.add(l), l), a = [];
    for (const l of i) {
      const u = l.list.length, d = gd(s, l.roundMs, e.start), f = gd(r, l.roundMs, e.start), h = r <= s ? 0 : r - s >= l.roundMs ? Ut : (f - d + Ut) % Ut, p = Math.floor(Math.min(bp, l.roundMs) * Ut / l.roundMs), m = Tv(l.places, d + 1);
      a.push(m);
      for (let v = 0; v < u; v++) {
        const g = (m + v) % u;
        if (((l.places[g] - d + Ut) % Ut || Ut) > h) break;
        if (!t.has(l.list[g])) return o(l.list[g]);
      }
      for (let v = 1; v <= u; v++) {
        const g = (m - v + u * 2) % u;
        if ((d - l.places[g] + Ut) % Ut >= p) break;
        if (!t.has(l.list[g])) return o(l.list[g]);
      }
    }
    for (let l = 0; l < i.length; l++) {
      const u = i[l], d = u.list.length;
      for (let f = 1; f <= d; f++) {
        const h = u.list[(a[l] - f + d * 2) % d];
        if (!t.has(h)) return o(h);
      }
    }
    return -1;
  }
  let vd = /* @__PURE__ */ new WeakMap();
  function Rv(e, t, n) {
    const r = vd.get(e);
    if (r && r.lineup === t && r.channelId === n.channelId && r.gapMs === n.gapMs && r.block === n.block) return r.plan;
    const s = Ev(e.slices, t, { ...n, start: e.start, decades: e.decades });
    return vd.set(e, { lineup: t, channelId: n.channelId, gapMs: n.gapMs, block: n.block, plan: s }), s;
  }
  function Ov(e, t) {
    var _a;
    var K, R, I;
    if (!t || !t.channelBumps || !t.platformBumps) return e.map((O) => ({ ...O, type: "video" }));
    const { channelBumps: n, platformBumps: r, channelAudio: s, platformAudio: i, channelId: o, seed: a } = t, l = t.block || null, u = t.firstIndex || 0, d = t.seasonAtMs;
    let f = t.cycleStartMs || 0, h = 0, p = 0;
    const m = [], v = (R = (K = t.ads) == null ? void 0 : K.slices) != null && R.length ? t.ads.slices : null, g = v ? t.adCarry : null, y = new Set(((g == null ? void 0 : g.recent) || []).map(([O]) => O).filter((O) => Number.isInteger(O) && O >= 0 && O < ((v == null ? void 0 : v.length) || 0)));
    let _ = Number.isInteger(g == null ? void 0 : g.fromMs) ? g.fromMs : null;
    const b = [], k = Number.isInteger((I = t.ads) == null ? void 0 : I.gapMs) ? t.ads.gapMs : kl, $ = v ? Rv(t.ads, t.adLineup || e, { block: l, gapMs: k, channelId: o }) : null;
    let P = 0;
    const x = t.deck ? mv(t.deckCarry) : null;
    if (e.forEach((O, D) => {
      const U = u + D;
      if (m.push({ ...O, type: "video" }), f += O.duration * 1e3, h += O.duration * 1e3, P += O.duration * 1e3, l && D < e.length - 1 && h < l.lengthMs) {
        const le = vv(l.stings, U, o, a), se = le ? le.lengthMs : l.cardMs;
        m.push({ type: "up-next", breakIndex: U, cardIndex: p++, sting: le, duration: se / 1e3, durationMs: se }), f += se, h += se, P += se;
        return;
      }
      h = 0;
      const N = d != null ? d : f, X = x ? gv(x, n, o, a, N) : fd(n, U, o, a, N), G = fd(r, U, "spelunkr", a, N);
      if (X && G) {
        const le = pd(s || [], X.id, U, a), se = pd(i || [], G.id, U, a), ye = D < e.length - 1 ? e[D + 1] : t.wrapItem;
        if (v && O.offAir !== true && (ye == null ? void 0 : ye.offAir) !== true && P >= k) {
          const ee = Av($, y, fo(O), f, _ != null ? _ : f - P);
          _ = null, b.push([ee, f]);
          const Z = v[ee], q = Sl + ho(X.slides) + Hs + uo, V = ho(G.slides) + Hs + uo;
          m.push({ type: "bump-break", half: "open", breakIndex: U, channelBump: X, channelAudio: le, duration: q / 1e3, durationMs: q }, { type: "ad", breakIndex: U, slice: Z, sliceIndex: ee, duration: Z.lengthMs / 1e3, durationMs: Z.lengthMs }, { type: "bump-break", half: "close", breakIndex: U, platformBump: G, platformAudio: se, duration: V / 1e3, durationMs: V }), f += q + Z.lengthMs + V, P = V, t.adOut && (t.adOut.fromMs = f);
          return;
        }
        const we = hv(X, G);
        m.push({ type: "bump-break", breakIndex: U, channelBump: X, platformBump: G, channelAudio: le, platformAudio: se, duration: we / 1e3, durationMs: we }), f += we, P += we;
      }
    }), v && t.adOut) {
      const O = t.adOut;
      b.length || (O.fromMs = (_a = _ != null ? _ : t.cycleStartMs) != null ? _a : 0);
      const D = f - bp;
      O.recent = [...(g == null ? void 0 : g.recent) || [], ...b].filter(([, U]) => U >= D);
    }
    if (x && t.deckOut) {
      const { order: O, pos: D, key: U, recent: N } = x;
      Object.assign(t.deckOut, { order: O, pos: D, key: U, recent: N });
    }
    return m;
  }
  let xv = 5;
  let $o = (e) => (e == null ? void 0 : e.type) === "bump-break" || (e == null ? void 0 : e.type) === "up-next" || (e == null ? void 0 : e.type) === "ad";
  let Mo = (e) => (e == null ? void 0 : e.type) === "video";
  let Nv = 8;
  function Lv(e, t = []) {
    const n = { channelId: e, versions: [] };
    for (const r of t) Po(n, r);
    return n;
  }
  function Po(e, t) {
    var _a, _b, _c2;
    var o, a;
    if (e.versions.some((l) => l.v === t.v)) return false;
    const { items: n } = t;
    if (!Array.isArray(n) || n.length === 0) throw new Error(`${e.channelId} v${t.v}: no items`);
    for (const l of n) if (!Number.isInteger(l.duration) || l.duration <= 0) throw new Error(`${e.channelId} v${t.v}: item ${l.id} has runtime ${l.duration} (need whole seconds > 0)`);
    if (!Number.isInteger(t.epochMs)) throw new Error(`${e.channelId} v${t.v}: epochMs must be whole milliseconds`);
    const r = t.startIndex || 0;
    if (!Number.isInteger(r) || r < 0 || r >= n.length) throw new Error(`${e.channelId} v${t.v}: startIndex ${r} out of range`);
    const s = t.block || null;
    if (s) {
      const l = (u) => Number.isInteger(u) && u > 0;
      if (!l(s.lengthMs) || !l(s.cardMs)) throw new Error(`${e.channelId} v${t.v}: block lengthMs and cardMs must be whole milliseconds > 0`);
      for (const u of s.stings || []) if (!l(u.lengthMs) || !Number.isInteger(u.startMs) || u.startMs < 0) throw new Error(`${e.channelId} v${t.v}: sting ${u.track} needs whole startMs >= 0 and lengthMs > 0`);
    }
    const i = (a = (o = t.ads) == null ? void 0 : o.slices) != null && a.length ? t.ads : null;
    for (const l of (i == null ? void 0 : i.slices) || []) if (!Number.isInteger(l.lengthMs) || l.lengthMs <= 0 || !Number.isInteger((_a = l.inMs) != null ? _a : 0) || ((_b = l.inMs) != null ? _b : 0) < 0) throw new Error(`${e.channelId} v${t.v}: ad slice ${l.id} needs whole inMs >= 0 and lengthMs > 0`);
    if (i && i.gapMs !== void 0 && (!Number.isInteger(i.gapMs) || i.gapMs < 0)) throw new Error(`${e.channelId} v${t.v}: ads.gapMs must be whole ms >= 0`);
    if (i && i.start !== void 0 && (!Number.isInteger(i.start) || i.start < 0 || i.start > 999)) throw new Error(`${e.channelId} v${t.v}: ads.start must be a whole number from 0 to 999`);
    if (i && i.decades !== void 0 && (!Number.isInteger(i.decades) || i.decades < 1 || i.decades > 3)) throw new Error(`${e.channelId} v${t.v}: ads.decades must be a whole number from 1 to 3`);
    return e.versions.push({ ...t, channelId: e.channelId, startIndex: r, block: s, ads: i, effectiveAtMs: (_c2 = t.effectiveAtMs) != null ? _c2 : t.epochMs, videoMs: n.reduce((l, u) => l + u.duration * 1e3, 0), fwd: [], back: [], built: /* @__PURE__ */ new Map(), adCarry: [], deckCarry: [] }), e.versions.sort((l, u) => l.v - u.v), true;
  }
  function ui(e, t) {
    const { versions: n } = e;
    for (let s = n.length - 1; s >= 0; s--) if (n[s].effectiveAtMs <= t) return n[s];
    let r = n[0] || null;
    for (const s of n) (s.effectiveAtMs < r.effectiveAtMs || s.effectiveAtMs === r.effectiveAtMs && s.v > r.v) && (r = s);
    return r;
  }
  function Dv(e, t, n) {
    let r = null;
    for (const s of e.versions) s.v > t.v && s.effectiveAtMs > n && (r === null || s.effectiveAtMs < r) && (r = s.effectiveAtMs);
    return r;
  }
  function bc(e, t, n) {
    const r = t === 0 ? e.startIndex : 0, s = r ? e.items.slice(r) : e.items, i = e.ads && e.bumps && t >= 0, o = i ? {} : null, a = e.bumps && e.engine >= xv, l = a && t >= 0 ? {} : null, u = Ov(s, e.bumps ? { ...e.bumps, block: e.block, ...e.ads ? { ads: e.ads, adLineup: e.items, wrapItem: e.items[0], adCarry: t >= 1 ? e.adCarry[t] : null, adOut: o } : {}, ...a ? { deck: true, deckCarry: t >= 1 ? e.deckCarry[t] : null, deckOut: l } : {}, channelId: e.channelId, seed: `${e.v}.${t}`, firstIndex: r, ...n } : null);
    if (i && e.adCarry[t + 1] === void 0) {
      if (t >= 1 && e.adCarry[t] === void 0) throw new Error(`${e.channelId} v${e.v}: cycle ${t} built before cycle ${t - 1}`);
      e.adCarry[t + 1] = o;
    }
    if (l && e.deckCarry[t + 1] === void 0) {
      if (t >= 1 && e.deckCarry[t] === void 0) throw new Error(`${e.channelId} v${e.v}: cycle ${t} built before cycle ${t - 1}`);
      e.deckCarry[t + 1] = l;
    }
    return u;
  }
  let yd = (e) => e.reduce((t, n) => {
    var _a;
    return t + ((_a = n.durationMs) != null ? _a : n.duration * 1e3);
  }, 0);
  function _c(e, t) {
    if (t >= 0) {
      const { fwd: s } = e;
      for (; s.length <= t; ) {
        const i = s.length ? s[s.length - 1].startMs + s[s.length - 1].lengthMs : e.epochMs, o = bc(e, s.length, { cycleStartMs: i });
        s.push({ startMs: i, lengthMs: yd(o) });
      }
      return s[t];
    }
    const { back: n } = e, r = -t - 1;
    for (; n.length <= r; ) {
      const s = n.length ? n[n.length - 1].startMs : e.epochMs, i = bc(e, -(n.length + 1), { seasonAtMs: e.epochMs }), o = yd(i);
      n.push({ startMs: s - o, lengthMs: o });
    }
    return n[r];
  }
  function Uv(e, t) {
    if (t >= e.epochMs) {
      const { fwd: r } = e, s = r[r.length - 1];
      if (s && t < s.startMs + s.lengthMs) {
        let o = 0, a = r.length - 1;
        for (; o < a; ) {
          const l = o + a + 1 >>> 1;
          r[l].startMs <= t ? o = l : a = l - 1;
        }
        return o;
      }
      let i = r.length ? r.length - 1 : 0;
      for (; ; ) {
        const o = _c(e, i);
        if (t < o.startMs + o.lengthMs) return i;
        i++;
      }
    }
    let n = -1;
    for (; _c(e, n).startMs > t; ) n--;
    return n;
  }
  function jv(e, t) {
    const n = e.built.get(t);
    if (n) return e.built.delete(t), e.built.set(t, n), n;
    const r = _c(e, t), s = bc(e, t, t >= 0 ? { cycleStartMs: r.startMs } : { seasonAtMs: e.epochMs }), i = t === 0 ? e.startIndex : 0;
    let o = 0, a = i;
    const l = s.map((d, f) => {
      var _a;
      const h = (_a = d.durationMs) != null ? _a : d.duration * 1e3, p = { ...d, index: f, v: e.v, key: `${e.v}:${t}:${f}`, offMs: o, durMs: h, startOffset: o / 1e3 };
      return d.type === "video" && (p.videoIndex = a++), o += h, p;
    }), u = { k: t, startMs: r.startMs, lengthMs: r.lengthMs, seed: `${e.v}.${t}`, entries: l };
    return e.built.set(t, u), e.built.size > Nv && e.built.delete(e.built.keys().next().value), u;
  }
  function un(e, t) {
    const n = ui(e, t);
    if (!n) throw new Error(`${e.channelId}: no published version`);
    const r = jv(n, Uv(n, t)), { entries: s } = r, i = t - r.startMs;
    let o = 0, a = s.length - 1;
    for (; o < a; ) {
      const p = o + a + 1 >>> 1;
      s[p].offMs <= i ? o = p : a = p - 1;
    }
    const l = s[o], u = r.startMs + l.offMs;
    let d = u + l.durMs;
    const f = Dv(e, n, t);
    f !== null && f < d && (d = f);
    const h = t - u;
    return { item: l, index: o, key: l.key, offset: Math.floor(h / 1e3), offsetExact: h / 1e3, remaining: (d - t) / 1e3, startMs: u, endMs: d, version: n.v, cycle: r.k, seed: r.seed, elapsed: i / 1e3, cycleLength: r.lengthMs / 1e3, cycleProgress: i / r.lengthMs, count: s.length };
  }
  function* di(e, t) {
    let n = t;
    for (; ; ) {
      const r = un(e, n);
      yield r, n = r.endMs;
    }
  }
  function Hv(e) {
    if (Array.isArray(e)) return e.find((t) => t.format === "h.264 IA") || e.find((t) => t.format === "h.264") || e.find((t) => t.format === "512Kb MPEG4") || e.find((t) => t.format === "MPEG4") || e.find((t) => {
      var n;
      return (n = t.name) == null ? void 0 : n.endsWith(".mp4");
    });
  }
  function _d(e, t) {
    return `https://archive.org/download/${e}/${encodeURIComponent(t)}`;
  }
  let is = (e) => Number.isInteger(e == null ? void 0 : e.outS) && e.outS > 0 && Number.isInteger(e.duration) && e.outS < e.duration;
  let Do = (e) => !Number.isInteger(e == null ? void 0 : e.inS) || e.inS <= 0 || !Number.isInteger(e.duration) ? false : e.inS < (is(e) ? e.outS : e.duration);
  let po = (e) => (is(e) ? e.outS : e.duration) - (Do(e) ? e.inS : 0);
  function xy(e, t, n) {
    var _a;
    const r = e.bumps || [], s = (t == null ? void 0 : t.bumps) || [];
    return { v: n.v, epochMs: n.epochMs, effectiveAtMs: (_a = n.effectiveAtMs) != null ? _a : n.epochMs, startIndex: n.startIndex || 0, items: e.items, bumps: r.length && s.length ? { channelBumps: r, platformBumps: s, channelAudio: e.audioOverlay ? Object.values(e.audioPools || {}).flat() : e.audio || [], platformAudio: t.audio || [] } : null, audioPools: e.audioPools || null, block: e.block || null, ads: e.ads || null, engine: e.engine };
  }
  let lr = /* @__PURE__ */ new Map();
  let kS = (e) => e;
  function ji(e, t) {
    return ES(e, t).then(kS);
  }
  function ES(e, t) {
    if (!e) return Promise.resolve(null);
    if (t) {
      const i = `${e}/${t}`;
      if (lr.has(i)) return lr.get(i);
      const o = Promise.resolve(_d(e, t));
      return lr.set(i, o), o;
    }
    if (lr.has(e)) return lr.get(e);
    const n = new AbortController(), r = setTimeout(() => n.abort(), 8e3), s = fetch(`https://archive.org/metadata/${e}`, { signal: n.signal }).then((i) => (clearTimeout(r), i.json())).then((i) => {
      const o = Hv(i.files || []);
      if (!o) throw new Error(`No video file found for ${e}`);
      return _d(e, o.name);
    }).catch((i) => {
      throw clearTimeout(r), lr.delete(e), i;
    });
    return lr.set(e, s), s;
  }
  function ni(e, { skipBaked: t = false } = {}) {
    var n, r;
    return (e == null ? void 0 : e.type) === "ad" ? (n = e.slice) != null && n.tape && ((r = e.slice) != null && r.file) ? ji(e.slice.tape, e.slice.file) : Promise.resolve(null) : e != null && e.id ? e.file ? ji(e.id, e.file) : e.mp4 && !t ? ji(e.id, e.mp4) : ji(e.id) : Promise.resolve(null);
  }
  let At = (e) => (e == null ? void 0 : e.type) === "ad";
  let Kl = (e) => {
    var t;
    return (e == null ? void 0 : e.type) === "ad" ? Number.isInteger((t = e.slice) == null ? void 0 : t.inMs) && e.slice.inMs > 0 ? e.slice.inMs / 1e3 : 0 : Number.isInteger(e == null ? void 0 : e.inS) && e.inS > 0 ? e.inS : 0;
  };
  let dT = { k: "#0b0f26", n: "#2a3580", s: "#8899cc", p: "#e8eaf0", g: "#ffd740", o: "#d2500c" };
  let hT = { shade: { hueToward: 255, hueStep: 14, satMul: 1.1, valueMul: 0.6 }, light: { hueToward: 50, hueStep: 10, satMul: 0.6, valueLift: 0.6 } };
  let fT = "#666666";
  function pT(e) {
    const [t, n, r] = [1, 3, 5].map((l) => parseInt(e.slice(l, l + 2), 16) / 255), s = Math.max(t, n, r), i = Math.min(t, n, r), o = s - i;
    let a = 0;
    return o && (s === t ? a = ((n - r) / o + (n < r ? 6 : 0)) / 6 : s === n ? a = ((r - t) / o + 2) / 6 : a = ((t - n) / o + 4) / 6), [a * 360, s ? o / s * 100 : 0, s * 100];
  }
  function Lh(e, t, n) {
    t /= 100, n /= 100;
    const r = (s) => {
      const i = (s + e / 60) % 6;
      return Math.round(255 * (n - n * t * Math.max(0, Math.min(i, 4 - i, 1)))).toString(16).padStart(2, "0");
    };
    return `#${r(5)}${r(3)}${r(1)}`;
  }
  function Dh(e, t, n) {
    const r = (t - e + 540) % 360 - 180;
    return (e + Math.sign(r) * Math.min(n, Math.abs(r)) + 360) % 360;
  }
  function Gl(e) {
    const t = /^#[0-9a-f]{6}$/i.test(e || "") ? e.toLowerCase() : fT, [n, r, s] = pT(t), { shade: i, light: o } = hT;
    return { ...dT, c: t, d: Lh(Dh(n, i.hueToward, i.hueStep), Math.min(100, r * i.satMul), s * i.valueMul), l: Lh(Dh(n, o.hueToward, o.hueStep), r * o.satMul, s + (100 - s) * o.valueLift) };
  }
  function mT(e) {
    const t = [], n = /* @__PURE__ */ new Map();
    for (let r = 0; r < e.length; r++) {
      const s = e[r], i = /* @__PURE__ */ new Set();
      for (let o = 0; o < s.length; ) {
        const a = s[o];
        let l = o + 1;
        for (; l < s.length && s[l] === a; ) l++;
        if (a !== ".") {
          const u = `${o}:${l - o}:${a}`, d = n.get(u);
          if (d && d.y + d.h === r) d.h++;
          else {
            const f = { x: o, y: r, w: l - o, h: 1, t: a };
            t.push(f), n.set(u, f);
          }
          i.add(u);
        }
        o = l;
      }
      for (const o of [...n.keys()]) i.has(o) || n.delete(o);
    }
    return t;
  }
  function vT(e, t) {
    return t * Math.max(1, Math.floor(e / t));
  }
  window.SpelunkrEngine = { nowAt: un, walk: di, addVersion: Po, makePlaylist: Lv, versionFrom: xy, inPoint: Kl, mediaUrl: ni, isAd: At, isBreak: $o, isVideo: Mo, runtime: po, palette: Gl, pixelRects: mT, pixelSize: vT };
})();
