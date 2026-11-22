# usage: resolve.py <game dir> <entry path from gamelist> -> prints DIR and CMD relative to the game dir
import os, sys, ntpath
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lnk import parse
root = os.environ.get('WC_PACK', os.getcwd())
game, entry = sys.argv[1], sys.argv[2]
gdir = os.path.join(root, game)
p = os.path.normpath(os.path.join(root, entry))
def ci(path):
    # case-insensitive existing path lookup under root
    if os.path.exists(path): return path
    cur = '/'
    for part in path.strip('/').split('/'):
        try: m = [x for x in os.listdir(cur) if x.lower() == part.lower()]
        except OSError: return None
        if not m: return None
        cur = os.path.join(cur, m[0])
    return cur
def winmap(w, base):
    if not w: return None
    w = w.replace('\\', '/')
    if w.startswith('./') or w.startswith('../') or ':' not in w:
        return ci(os.path.normpath(os.path.join(base, w)))
    parts = w.split('/')
    low = [x.lower() for x in parts]
    if game.lower() in low:
        i = len(low) - 1 - low[::-1].index(game.lower())
        return ci(os.path.join(gdir, *parts[i+1:]))
    return None
args = ''
wd = None
if p.lower().endswith('.lnk'):
    l = parse(ci(p) or p)
    ldir = os.path.dirname(p)
    exe = winmap(l.get('relpath'), ldir) or winmap(l.get('target'), ldir)
    if not exe:
        bn = ntpath.basename(l.get('target') or l.get('relpath') or '')
        hits = [os.path.join(dp, f) for dp, _, fs in os.walk(gdir) for f in fs if f.lower() == bn.lower()]
        exe = hits[0] if hits else None
    if not exe: sys.exit(f"cannot resolve lnk {l}")
    args = l.get('args') or ''
    wd = winmap(l.get('workdir'), ldir)
    if wd and not os.path.isdir(wd): wd = None
else:
    exe = ci(p)
    if not exe: sys.exit(f"missing {p}")
d = wd or os.path.dirname(exe)
rel_d = os.path.relpath(d, gdir)
rel_exe = os.path.relpath(exe, d)
print("DIR=" + ("game" if rel_d == '.' else "game/" + rel_d))
print("CMD=" + '"' + rel_exe.replace('/', '\\') + '"' + (" " + args if args else ''))
