# envsteam.py <autorun.cmd>: for a game that needs it (e.g. behind a Steam emulator loader), make its ENV line disable GE's Steam client bridge (lsteamclient=d)
# batocera-wine evals ENV in front of wine, so WINEDLLOVERRIDES extends its own value instead of replacing it.
import re, sys
f = sys.argv[1]
raw = open(f, 'rb').read().decode('utf-8', 'replace')
nl = '\r\n' if '\r\n' in raw else '\n'
lines = raw.replace('\r\n', '\n').split('\n')
env = [i for i, l in enumerate(lines) if l.startswith('ENV=')]
add = 'WINEDLLOVERRIDES="$WINEDLLOVERRIDES;lsteamclient=d"'
if not env:
    while lines and lines[-1] == '':
        lines.pop()
    lines += ['ENV=' + add, '']
else:
    i = env[0]
    l = lines[i]
    if 'lsteamclient' not in l:
        m = re.search(r'WINEDLLOVERRIDES="([^"]*)"', l)
        if m:
            v = m.group(1)
            v = v if v.startswith('$WINEDLLOVERRIDES') else '$WINEDLLOVERRIDES;' + v
            l = l[:m.start()] + f'WINEDLLOVERRIDES="{v};lsteamclient=d"' + l[m.end():]
        else:
            l = l + ' ' + add
        lines[i] = l
open(f, 'w', newline='').write(nl.join(lines))
