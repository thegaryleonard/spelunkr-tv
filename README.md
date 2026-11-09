# Spelunkr TV

Remote-friendly TV apps for [spelunkr.tv](https://spelunkr.tv), the free cable network made of
Internet Archive tapes. Unofficial.

Controls on both: **▲▼** change channel · **OK** guide · **◀▶** what's on / next · **Back** close, twice to exit.

| Folder | Platform | Status |
|---|---|---|
| `lg/` | LG webOS (tested on webOS 23, 32LR600BZUC) | v2.2.0 installed and working |
| `roku/` | Roku (SceneGraph / BrightScript) | built and simulator-tested; not yet on a real Roku |

## Data access (agreed with the Spelunkr devs)
`data.spelunkr.tv` only answers clients that name themselves, so both apps identify in their User-Agent:
`spelunkr-lg/<version>` and `spelunkr-roku/<version>`. Polling rules from the devs:
- poll `live.json` (the heartbeat) once a minute;
- fetch `lineup.json` and new manifests **only** when live.json shows a new version (never on a timer);
- take the clock from live.json's response (its `Date` header / `written` time) — no requests to spelunkr.tv itself (Vercel).

The webOS web runtime can't set a User-Agent, so the LG app routes its JSON requests through its own small
JS service (`lg/service/`, luna://tv.spelunkr.app.service/get), which can. Fonts ship inside both apps;
video comes from archive.org and bump audio from audio.spelunkr.tv.

## LG (`lg/`)
- `app/` — the remote-first app. `js/engine.js` is the site's own schedule engine, extracted from
  its JS bundle by `build/build.mjs` (`build/find-names.mjs` finds the functions by content, since the
  minified names change every deploy; `build/cmp-engines.mjs` checks a new engine against the old one).
- `service/` — the data fetcher that sets the User-Agent (packaged into the same .ipk).
- `app-wrapper/` — the old plain full-screen launcher (fallback; the devs' other suggested route).
- `tools/cdp.mjs` — screenshots, key presses and JS eval on the TV over the web inspector
  (`ares-inspect -d lgtv tv.spelunkr.app` prints the port).
- Install: `ares-package lg/app lg/service -o lg && ares-install -d lgtv lg/tv.spelunkr.app_<ver>_all.ipk && ares-launch -d lgtv tv.spelunkr.app`
- Developer Mode expires after ~50 h unless **Extend** is pressed in the Developer Mode app.

## Roku (`roku/`)
See [`roku/README.md`](roku/README.md). `cd roku/tools && npm ci` for the lint/sim/test tooling.

## Notes
- `lg/discord-message-v2.txt` — the request we sent the Spelunkr devs (with the 403 evidence).
- Fonts, logos, colors and data belong to Spelunkr; programming courtesy of the Internet Archive.
