# Build a simulator test zip that starts on <channel> with the clock shifted so "now" = <atMs> + <lead> ms,
# then run brs-cli under a PTY (driven by the agent: Ctrl+S = screenshot, ECP :8060 = remote keys).
# usage: python simtest.py <channel> <atMs> [leadMs]
import sys, json, time, zipfile, os
BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ch, at = sys.argv[1], int(sys.argv[2]); lead = int(sys.argv[3]) if len(sys.argv) > 3 else 0
root = os.path.join(BASE, 'app')
off = at + lead - int(time.time() * 1000) - 20000   # ~20 s for the app to load before the moment arrives
os.makedirs(os.path.join(BASE, 'out'), exist_ok=True)
out = os.path.join(BASE, 'out', 'simtest.zip')
with zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED) as z:
    for d, _, files in os.walk(root):
        for f in files:
            p = os.path.join(d, f); z.write(p, os.path.relpath(p, root).replace(os.sep, '/'))
    z.writestr('config.json', json.dumps({'clockOffsetMs': off}))
print(out, 'offset', off, 'channel', ch)
