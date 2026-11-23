#!/bin/bash
# importimg.sh <dir of old images> [N]: rebuild old .wsquashfs images as if they were new games.
# For the next N images of <dir> (X.wine.wsquashfs or X.wsquashfs) not imported yet: extract only game/ to <pack>/X/,
# keep the old launch lines in .wineconvert/autorun/X.cmd (prep.sh uses them), add a gamelist.xml.orig entry,
# and log the source in .wineconvert/sources.tsv (pack.sh deletes the old image once the new one is packed).
. "$(dirname "$0")/env.sh"
SRC=$1; N=${2:-8}
A=$P/.wineconvert/autorun; SL=$P/.wineconvert/sources.tsv
mkdir -p "$A"; touch "$SL"
n=0
for f in "$SRC"/*.wsquashfs; do
  (( n >= N )) && break
  g=$(basename "$f"); g=${g%.wsquashfs}; g=${g%.wine}
  cut -f1 "$SL" | grep -qxF "$g" && continue
  [[ -e "$P/$g" || -e "$P/$g.wine" || -e "$P/$g.wsquashfs" ]] && continue
  old=$(unsquashfs -cat "$f" autorun.cmd 2>/dev/null | tr -d '\r')
  cmd=$(grep -m1 '^CMD=' <<<"$old"); dir=$(grep -m1 '^DIR=' <<<"$old")
  [[ -n "$cmd" ]] || { echo "$g: no CMD in autorun.cmd, skipped"; printf '%s\t%s\tskipped: no CMD\n' "$g" "$f" >> "$SL"; continue; }
  sudo unsquashfs -q -d "$P/.import_$g" "$f" game >/dev/null 2>&1 && sudo chown -R "$(id -u):$(id -g)" "$P/.import_$g" \
    && mv "$P/.import_$g/game" "$P/$g" && rmdir "$P/.import_$g" || { echo "$g: extract failed"; rm -rf "${P:?}/.import_${g:?}"; continue; }
  # a stray wine prefix inside game/ (wineboot run in the wrong folder): junk, and its dosdevices/z: -> / loops scans
  [[ -f "$P/$g/system.reg" && -d "$P/$g/drive_c/windows" ]] && { echo "$g: removing stray prefix from game/"; rm -rf "${P:?}/${g:?}/"{dosdevices,drive_c,system.reg,user.reg,userdef.reg,.update-timestamp}; }
  grep -vE '^(ENV|WINE|DXVK|VKD3D)' <<<"$old" > "$A/$g.cmd"   # old prefix tricks are not carried over
  # gamelist entry ./X/<sub>/<exe> (CMD may be quoted, have arguments or a w:\game\ path)
  exe=$(sed -E 's/^CMD="([^"]*)".*/\1/; t; s/^CMD=([^ ]*).*/\1/' <<<"$cmd" | sed 's|\\|/|g; s|^[wWzZcC]:/game/||')
  sub=${dir#DIR=}; sub=${sub#game}; sub=${sub#/}
  [[ "$exe" == */* ]] && path="./$g/$exe" || path="./$g/${sub:+$sub/}$exe"
  grep -qF "<path>./$g/" "$P/gamelist.xml.orig" || python3 -I - "$P/gamelist.xml.orig" "$path" "$g" <<'E'
import html, sys
f, p, n = sys.argv[1:4]
t = open(f, encoding='utf-8').read()
e = f"\t<game>\n\t\t<path>{html.escape(p, quote=False)}</path>\n\t\t<name>{html.escape(n, quote=False)}</name>\n\t</game>\n"
open(f, 'w', encoding='utf-8').write(t.replace('</gameList>', e + '</gameList>'))
E
  printf '%s\t%s\n' "$g" "$f" >> "$SL"
  echo "$g: imported ($path)"
  n=$((n+1))
done
(( n )) && python3 -I "$T/listgames.py" > "$S/games.txt"
echo "imported $n"
