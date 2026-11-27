# envsteam.py <autorun.cmd> [override]: add a wine DLL override to the image's ENV line (default lsteamclient=d, GE's Steam client bridge,
# for games behind a Steam emulator loader; dcomp=d for NW.js games).
# batocera-wine evals ENV in front of wine, so WINEDLLOVERRIDES extends its own value instead of replacing it.
import re, sys
f = sys.argv[1]
o = sys.argv[2] if len(sys.argv) > 2 else 'lsteamclient=d'
name = o.split('=')[0]
raw = open(f, 'rb').read().decode('utf-8', 'replace')
nl = '\r\n' if '\r\n' in raw else '\n'
lines = raw.replace('\r\n', '\n').split('\n')
env = [i for i, l in enumerate(lines) if l.startswith('ENV=')]
add = f'WINEDLLOVERRIDES="$WINEDLLOVERRIDES;{o}"'
if not env:
    while lines and lines[-1] == '':
        lines.pop()
    lines += ['ENV=' + add, '']
else:
    i = env[0]
    l = lines[i]
    if not re.search(r'[;"]' + re.escape(name) + r'=', l):
        m = re.search(r'WINEDLLOVERRIDES="([^"]*)"', l)
        if m:
            v = m.group(1)
            v = v if v.startswith('$WINEDLLOVERRIDES') else '$WINEDLLOVERRIDES;' + v
            l = l[:m.start()] + f'WINEDLLOVERRIDES="{v};{o}"' + l[m.end():]
        else:
            l = l + ' ' + add
        lines[i] = l
open(f, 'w', newline='').write(nl.join(lines))
