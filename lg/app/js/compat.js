/* Polyfills for older webOS (webOS 5 = Chrome 68). Loaded before engine.js. Harmless on newer TVs. */
(function () {
  'use strict';
  function def(o, k, f) { if (!o[k]) Object.defineProperty(o, k, { value: f, configurable: true, writable: true }); }
  def(Array.prototype, 'flat', function flat(depth) {
    var d = depth === undefined ? 1 : Math.floor(depth) || 0, out = [];
    (function walk(a, n) {
      for (var i = 0; i < a.length; i++) {
        if (!(i in a)) continue;
        if (Array.isArray(a[i]) && n > 0) walk(a[i], n - 1); else out.push(a[i]);
      }
    })(this, d);
    return out;
  });
  def(Array.prototype, 'flatMap', function flatMap(fn, self) { return Array.prototype.map.call(this, fn, self).flat(1); });
  def(Object, 'fromEntries', function fromEntries(it) {
    var o = {};
    Array.from(it).forEach(function (e) { o[e[0]] = e[1]; });
    return o;
  });
  def(String.prototype, 'replaceAll', function replaceAll(a, b) {
    if (a instanceof RegExp) return this.replace(a, b);
    return this.split(a).join(b);
  });
  def(Array.prototype, 'at', function at(i) { i = Math.trunc(i) || 0; if (i < 0) i += this.length; return this[i]; });
  def(Promise, 'allSettled', function allSettled(ps) {
    return Promise.all(Array.from(ps).map(function (p) {
      return Promise.resolve(p).then(function (v) { return { status: 'fulfilled', value: v }; }, function (r) { return { status: 'rejected', reason: r }; });
    }));
  });
  if (typeof globalThis === 'undefined') window.globalThis = window;
})();
