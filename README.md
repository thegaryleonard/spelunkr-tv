# Spelunkr TV

Remote-friendly TV apps for [spelunkr.tv](https://spelunkr.tv), the free cable network made of
Internet Archive tapes. Unofficial; built with the Spelunkr devs' blessing.

Controls on both: **▲▼** change channel · **OK** guide · **◀▶** what's on / next · **Back** close, twice to exit.

| Folder | Platform | Status |
|---|---|---|
| `lg/` | LG webOS (tested on webOS 23, 32LR600BZUC) | installed and working |
| `roku/` | Roku (SceneGraph / BrightScript) | built and simulator-tested; not yet on a real Roku |

## Current state (data access)
In November 2026 `data.spelunkr.tv` began rejecting requests that don't come from spelunkr.tv
(Cloudflare 403). The devs have agreed to give us an approved way to pull the data. Until then:
- the LG TV runs `lg/app-wrapper/` (v2.1.0), which just loads spelunkr.tv full-screen;
- `lg/app/` (v2.0.0, the remote-first UI) and `roku/` wait on the new access method.

## LG (`lg/`)
- `app/` — the remote-first app. `js/engine.js` is the site's own schedule engine, extracted from
  its JS bundle by `build/build.mjs` (do **not** run it blind after a site update: the minified
  function names change; re-map `ROOTS` in build.mjs first).
- `app-wrapper/` — the plain full-screen launcher.
- `tools/cdp.mjs` — screenshots, key presses and JS eval on the TV over the web inspector
  (`ares-inspect -d lgtv tv.spelunkr.app` prints the port).
- Install: `ares-package lg/app -o lg && ares-install -d lgtv lg/tv.spelunkr.app_<ver>_all.ipk && ares-launch -d lgtv tv.spelunkr.app`
- Developer Mode expires after ~50 h unless **Extend** is pressed in the Developer Mode app.

## Roku (`roku/`)
See [`roku/README.md`](roku/README.md). `cd roku/tools && npm ci` for the lint/sim/test tooling.

## Notes
- `lg/discord-message-v2.txt` — the request we sent the Spelunkr devs (with the 403 evidence).
- Fonts, logos, colors and data belong to Spelunkr; programming courtesy of the Internet Archive.
