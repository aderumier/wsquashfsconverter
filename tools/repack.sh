#!/bin/bash
# repack.sh <pack> <game>...: rebuild images whose .wine was updated (old image kept as .prev until the new one verifies)
P=$1; shift; cd "$P/.wineconvert"
for g in "$@"; do
  F="../$g.wsquashfs"; [ -d "../$g.wine" ] || { echo "$g: no .wine"; continue; }
  E=$(grep -F "|$g|" work/games.txt | head -1 | cut -d'|' -f4); N=$(grep -F "$g	" done.tsv | tail -1 | cut -f4-)
  mv -f "$F" "$F.prev" 2>/dev/null
  if tools/pack.sh "$g" "$E" "${N:-repacked} + SAVEDIR/SAVEFILES" > /dev/null 2>&1 && [ -e "$F" ]; then rm -f "$F.prev"; echo "$g: repacked"; else [ -e "$F" ] || mv -f "$F.prev" "$F"; echo "$g: REPACK FAILED (old image restored)"; fi
done
