#!/bin/bash
# defer.sh "<game>" "<reason>": undo prep (game back to its folder) and log it in todo.tsv
. "$(dirname "$0")/env.sh"
G="$1"
mountpoint -q $S/ov/mnt && { echo "overlay mounted"; exit 1; }
if [[ -d "$P/$G.wine/game" && ! -e "$P/$G" ]]; then mv "$P/$G.wine/game" "$P/$G" && rm -rf "${P:?}/${G:?}.wine"; fi
printf '%s\t%s\n' "$G" "$2" >> $P/.wineconvert/todo.tsv
ls -d "$P/$G"
