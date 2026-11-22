# mkgamelist.py: build a batocera gamelist.xml for a pack without one, picking each folder's game exe
# usage: python3 -I mkgamelist.py <pack> > gamelist.xml   (writes the picks and scores to stderr)
import os, re, sys, html, difflib
P = sys.argv[1]
SKIP = re.compile(r'unins|setup|install|redist|vcredist|vc_redist|dxsetup|directx|dotnet|crash|report|'
                  r'notification_helper|ue4prereq|prereq|helper|update|patcher|config|settings|'
                  r'easyanticheat|eac|battleye|7z|python|qtwebengine|cef|subprocess|server|dedicated|'
                  r'editor|benchmark|cmd|console|steamless|vulkan|d3d|dxwebsetup', re.I)
SKIPDIR = re.compile(r'(^|/)(_commonredist|redist|redistributables|directx|dotnet|vcredist|support|installers?|'
                     r'engine/binaries/thirdparty|engine/extras|__installer|_redist|tools)(/|$)', re.I)

def norm(s):
    return re.sub(r'[^a-z0-9]', '', s.lower())

def pick(folder):
    cands = []
    for root, dirs, files in os.walk(folder):
        rel = os.path.relpath(root, folder).replace('\\', '/')
        depth = 0 if rel == '.' else rel.count('/') + 1
        if depth > 4 or SKIPDIR.search(rel + '/'):
            dirs[:] = []
            continue
        for f in files:
            if not f.lower().endswith('.exe') or SKIP.search(f[:-4]):
                continue
            path = os.path.join(root, f)
            cands.append((path, depth, os.path.getsize(path)))
    if not cands:
        return None, []
    name = norm(os.path.basename(folder))
    scored = []
    for path, depth, size in cands:
        stem = norm(os.path.basename(path)[:-4].replace('-Win64-Shipping', '').replace('-Win32-Shipping', ''))
        sim = difflib.SequenceMatcher(None, name, stem).ratio()
        if stem and (stem in name or name in stem):
            sim = max(sim, 0.9)
        score = sim * 10 - depth * 1.5 + min(size / 50e6, 2)
        if 'shipping' in os.path.basename(path).lower():
            score -= 1      # the UE stub at the top level comes first (CMD can be changed to the shipping exe later)
        if 'launcher' in os.path.basename(path).lower():
            score -= 3
        scored.append((score, path))
    scored.sort(reverse=True)
    return scored[0][1], scored

out = ['<?xml version="1.0"?>', '<gameList>']
for d in sorted(os.listdir(P)):
    full = os.path.join(P, d)
    if not os.path.isdir(full) or d.startswith('.') or d.startswith('@') or d in ('dontconvert', 'media') or d.endswith('.wine'):
        continue
    exe, scored = pick(full)
    if not exe:
        print(f'NOEXE\t{d}', file=sys.stderr)
        continue
    rel = './' + os.path.relpath(exe, P).replace(os.sep, '/')
    close = len(scored) > 1 and scored[0][0] - scored[1][0] < 2
    alts = ' | '.join(os.path.relpath(p, full) for s, p in scored[1:3])
    print(f"{'CHECK' if close else 'OK'}\t{d}\t{os.path.relpath(exe, full)}\t{('alt: ' + alts) if close else ''}", file=sys.stderr)
    out.append(f'\t<game>\n\t\t<path>{html.escape(rel, quote=False)}</path>\n\t\t<name>{html.escape(d, quote=False)}</name>\n\t</game>')
out.append('</gameList>')
print('\n'.join(out))
