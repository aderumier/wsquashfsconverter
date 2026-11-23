#!/bin/bash
# prep.sh "<game dir>" "<gamelist entry>": build <game>.wine prefix, move game into game/, write autorun.cmd
. "$(dirname "$0")/env.sh"
G="$1"; E="$2"; W="$P/$G.wine"
set -e
[[ -d "$P/$G" ]] || { echo "no dir $G"; exit 1; }
[[ -e "$W" ]] && { echo "$W exists"; exit 1; }
AC="$P/.wineconvert/autorun/$G.cmd"   # launch lines kept from an old image (importimg.sh)
if [[ -f "$AC" ]]; then out=$(cat "$AC"); else out=$(python3 -I $T/resolve.py "$G" "$E"); fi
echo "$out"
mkdir "$W"
WINEPREFIX="$W" WINEDEBUG=-all WINEDLLOVERRIDES="winegstreamer=" DISPLAY= "$WINE" wineboot -u >/dev/null 2>&1
WINEPREFIX="$W" "$WINESERVER" -w
mv "$P/$G" "$W/game"
if [[ -f "$AC" ]]; then cp "$AC" "$W/autorun.cmd"; else printf '%s\n' "$(grep ^CMD= <<<"$out")" "$(grep ^DIR= <<<"$out")" > "$W/autorun.cmd"; fi
cat "$W/autorun.cmd"
