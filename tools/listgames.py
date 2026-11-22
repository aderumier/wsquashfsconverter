# list game folders with their gamelist entries: visible|total|folder|entries (" ; " separated)
import re, os, sys, collections, html
P = os.environ.get('WC_PACK', os.getcwd())
src = P + '/gamelist.xml.orig' if os.path.exists(P + '/gamelist.xml.orig') else P + '/gamelist.xml'
txt = open(src, encoding='utf-8').read()
by = collections.defaultdict(list)
for blk in re.findall(r'<game>(.*?)</game>', txt, re.S):
    m = re.search(r'<path>(.*?)</path>', blk)
    if not m: continue
    p = html.unescape(m.group(1))
    if not p.startswith('./'): continue
    by[p[2:].split('/')[0]].append(('<hidden>true</hidden>' in blk, p))
skip = {'media', 'dontconvert'}
dirs = sorted(d for d in os.listdir(P) if os.path.isdir(P + '/' + d) and d not in skip and not d.startswith('.') and not d.endswith('.wine'))
for d in dirs:
    ents = by.get(d, [])
    vis = [e for e in ents if not e[0]]
    print(f"{len(vis)}|{len(ents)}|{d}|" + " ; ".join(e[1] for e in vis))
