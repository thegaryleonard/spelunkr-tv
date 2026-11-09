/* Fake webOS bits for running the app in a desktop browser (see server.mjs). ES5 so old Chromium can run it. */
(function () {
  window.__errors = [];
  window.addEventListener('error', function (e) { window.__errors.push((e.message || 'error') + ' @' + (e.filename || '').split('/').pop() + ':' + e.lineno); });
  window.addEventListener('unhandledrejection', function (e) { window.__errors.push('unhandled: ' + (e.reason && e.reason.message || e.reason)); });
  window.PalmServiceBridge = function () {};
  window.PalmServiceBridge.prototype.call = function (uri, params) {
    var self = this, x = new XMLHttpRequest();
    x.open('POST', '/__svc');
    x.onload = function () { if (self.onservicecallback) self.onservicecallback(x.responseText); };
    x.onerror = function () { if (self.onservicecallback) self.onservicecallback('{"returnValue":false,"errorText":"shim xhr failed"}'); };
    x.send(JSON.stringify({ uri: uri, params: JSON.parse(params || '{}') }));
  };
})();
