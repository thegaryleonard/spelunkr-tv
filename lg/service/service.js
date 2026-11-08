/*
 * Spelunkr data service for the LG app.
 * The webOS web runtime can't change its User-Agent, and data.spelunkr.tv admits clients that name
 * themselves (agreed with the Spelunkr devs), so the app's JSON requests go through here.
 *
 * luna://tv.spelunkr.app.service/get  { path: "live.json" }
 *   -> { returnValue: true, status: 200, date: "<HTTP Date header>", body: "<text>" }
 * Only *.json paths on data.spelunkr.tv are allowed.
 */
/* eslint-disable no-var */
var https = require('https');
var pkg = require('./package.json');
var Service = require('webos-service');

var service = new Service(pkg.name);
var UA = 'spelunkr-lg/' + pkg.version;
var HOST = 'data.spelunkr.tv';
var PATH_OK = /^[A-Za-z0-9][A-Za-z0-9._\/-]*\.json$/;

service.register('get', function (message) {
  var p = message.payload && message.payload.path;
  if (typeof p !== 'string' || !PATH_OK.test(p) || p.indexOf('..') !== -1) {
    message.respond({ returnValue: false, errorText: 'bad path' });
    return;
  }
  var done = false;
  function reply(o) { if (!done) { done = true; message.respond(o); } }
  var req = https.get({
    host: HOST,
    path: '/' + p,
    headers: { 'User-Agent': UA, 'Accept': 'application/json' }
  }, function (res) {
    var chunks = [];
    res.on('data', function (c) { chunks.push(c); });
    res.on('end', function () {
      reply({
        returnValue: true,
        status: res.statusCode,
        date: res.headers.date || null,
        body: Buffer.concat(chunks).toString('utf8')
      });
    });
    res.on('error', function (e) { reply({ returnValue: false, errorText: String(e && e.message || e) }); });
  });
  req.setTimeout(15000, function () { req.abort(); reply({ returnValue: false, errorText: 'timeout' }); });
  req.on('error', function (e) { reply({ returnValue: false, errorText: String(e && e.message || e) }); });
});

service.register('version', function (message) {
  message.respond({ returnValue: true, userAgent: UA, node: process.version });
});
