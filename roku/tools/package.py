# Build out/spelunkr-roku.zip (device) and out/spelunkr-sim.zip (browser simulator, uses the local CORS proxy)
import zipfile, os, json, sys
HERE = os.path.dirname(os.path.abspath(__file__))
BASE = os.path.dirname(HERE)
root = os.path.join(BASE, 'app')
os.makedirs(os.path.join(BASE, 'out'), exist_ok=True)
def build(out, extra=None):
    with zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED) as z:
        for d, _, files in os.walk(root):
            for f in files:
                p = os.path.join(d, f); a = os.path.relpath(p, root).replace(os.sep, '/')
                if a == 'config.json': continue
                z.write(p, a)
        if extra:
            for a, txt in extra.items(): z.writestr(a, txt)
    print(out, os.path.getsize(out))
build(os.path.join(BASE, 'out', 'spelunkr-roku.zip'))
build(os.path.join(BASE, 'out', 'spelunkr-sim.zip'), {'config.json': json.dumps({'dataBase': 'http://localhost:8787/data/', 'audioBase': 'http://localhost:8787/audio/'})})
