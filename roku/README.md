# Spelunkr for Roku

Remote-first player for [spelunkr.tv](https://spelunkr.tv): the same live channels, schedule, bumps and
"up next" cards as the website, in the site's Weather-Star look.

| Button | Watching | Guide open |
|---|---|---|
| ▲ / ▼ | channel up / down | move through channels |
| OK (or ✱) | open the guide | tune in |
| ◀ / ▶ | show what's on / next | page up / down |
| Back | hide info, press twice to exit | close guide |

## Layout
- `app/` — the Roku channel (SceneGraph). `source/engine.brs` is a BrightScript port of the site's
  scheduling engine; `components/BroadcastTask.*` does network + schedule maths on a background thread;
  `components/MainScene.*` is the UI.
- `test/` — equivalence test: `expected.mjs` runs the site's own JS engine, `compare_main.brs` runs the
  port on the same data via `@rokucommunity/brs`; outputs must match line for line.
- `tools/package.py` → `out/spelunkr-roku.zip` (the file you sideload).
- `tools/deploy.sh` — install / screenshot / remote keys / console log for a Roku in developer mode.

## Put it on a Roku
1. On the Roku remote: **Home ×3, Up ×2, Right, Left, Right, Left, Right**. Enable the installer, accept,
   choose a password, let it reboot. Note the IP it shows.
2. Either open `http://<roku-ip>` in a browser (user `rokudev` + your password) and upload
   `out/spelunkr-roku.zip`, or run `ROKU_IP=<ip> ROKU_PASS=<password> tools/deploy.sh install`.
3. It appears as the **dev** channel on the home screen. It stays installed until another dev
   channel replaces it (no 50-hour expiry like LG).

## Re-checking against the site
```
cd test && node snapshot.mjs && NT=6 node expected.mjs 20 && bash run_compare.sh && tail -1 run_all.log
```
`DIFF: 0 of N` means the port still agrees with the site's engine.
