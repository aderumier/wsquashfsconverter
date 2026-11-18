#!/bin/bash
# setup.sh: one-time / per-session setup (build pad, back up gamelist, build the game list)
. "$(dirname "$0")/env.sh"
gcc -O2 -o "$T/vpad" "$T/vpad.c" || exit 1
[[ -f "$P/gamelist.xml.orig" ]] || cp "$P/gamelist.xml" "$P/gamelist.xml.orig"
mkdir -p "$P/dontconvert" "$S/claims"
touch "$P/.wineconvert/done.tsv" "$P/.wineconvert/todo.tsv"
python3 -I "$T/listgames.py" > "$S/games.txt"
echo "games to look at: $(wc -l < "$S/games.txt"), done: $(wc -l < "$P/.wineconvert/done.tsv"), todo: $(wc -l < "$P/.wineconvert/todo.tsv")"
for p in lib32-libpulse lib32-libva lib32-libusb; do pacman -Q $p >/dev/null 2>&1 || echo "missing host package $p (32-bit game audio/video)"; done
