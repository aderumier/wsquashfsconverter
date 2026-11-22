# rebuild gamelist.xml from gamelist.xml.orig: packed games -> ./X.wsquashfs, dontconvert games -> dontconvert/gamelist.xml
import re, os, html
P = os.environ.get('WC_PACK', os.getcwd())
txt = open(P + '/gamelist.xml.orig', encoding='utf-8').read()
main = {}
for l in open(P + '/.wineconvert/done.tsv', encoding='utf-8'):
    f = l.rstrip('\n').split('\t')
    if len(f) >= 2 and os.path.exists(f"{P}/{f[0]}.wsquashfs"): main[f[0]] = f[1]
dc = set(os.listdir(P + '/dontconvert')) - {'gamelist.xml'}
dclow = {d.lower(): d for d in dc}
mainlow = {k.lower(): k for k in main}
out, dcout = [], []
pos = 0
parts = []
for m in re.finditer(r'(\t*)<game>.*?</game>\n?', txt, re.S):
    parts.append(txt[pos:m.start()]); pos = m.end()
    blk = m.group(0)
    pm = re.search(r'<path>(.*?)</path>', blk)
    p = html.unescape(pm.group(1)) if pm else ''
    top = p[2:].split('/')[0].lower() if p.startswith('./') else None
    if top in dclow:
        dcout.append(re.sub(r'>\./media/', '>../media/', blk)); continue
    if top in mainlow:
        g = mainlow[top]
        if p != main[g]: continue
        blk = blk.replace(pm.group(0), '<path>' + html.escape('./' + g + '.wsquashfs', quote=False) + '</path>')
    parts.append(blk)
parts.append(txt[pos:])
open(P + '/gamelist.xml', 'w', encoding='utf-8').write(''.join(parts))
open(P + '/dontconvert/gamelist.xml', 'w', encoding='utf-8').write('<?xml version="1.0"?>\n<gameList>\n' + ''.join(dcout) + '</gameList>\n')
print(f"packed {len(main)}, dontconvert entries {len(dcout)}")
