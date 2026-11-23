#!/bin/bash
# next.sh [game]: in slot $K, prep the next unconverted game (or the given one) and run its test
. "$(dirname "$0")/env.sh"
K=${K:-0}; G="$1"; L=$S/claims
mkdir -p $L
skip=$(cut -f1 $P/.wineconvert/done.tsv $P/.wineconvert/todo.tsv)
if [[ -z "$G" ]]; then
  exec 9>$L/.lock; flock 9
  while IFS='|' read n t g e; do
    [[ -d "$P/$g" || -d "$P/$g.wine" ]] || continue
    grep -qxF "$g" <<<"$skip" && continue
    [[ -e "$L/$g" ]] && continue
    G="$g"; break
  done < $S/games.txt
  [[ -n "$G" ]] && echo $K > "$L/$G"
  flock -u 9
fi
[[ -z "$G" ]] && { echo "ALL DONE"; exit 0; }
E=$(grep -F "|$G|" $S/games.txt | head -1 | cut -d'|' -f4)
[[ -f "$P/.wineconvert/autorun/$G.cmd" ]] || E=$(sed 's/ ; /\n/g' <<<"$E" | grep -viE 'unins|redist|crash|\.url$|\.bat$|dxsetup|setup' | head -1)
echo "SLOT=$K GAME=$G"; echo "ENTRY=$E"
[[ -z "$E" && ! -d "$P/$G.wine" ]] && { echo "PREP FAILED: no usable gamelist entry (bat/url only?)"; exit 1; }
if [[ ! -d "$P/$G.wine" ]]; then
  out=$($T/prep.sh "$G" "$E" 2>&1) || { echo "PREP FAILED: $out"; exit 1; }
fi
grep -iqE 'dosbox|scummvm' "$P/$G.wine/autorun.cmd" && echo "WARNING DOSBOX/SCUMMVM"
cat "$P/$G.wine/autorun.cmd"
K=$K $T/run.sh "$G" ${DUR:-60} ${IN:-$T/in.txt} 2>&1 | grep -E "^(audio|streams|mean|exited|no shots|UMOUNT|sheet)"
cp "$S/upper$K.txt" "$S/upper_$(echo "$G" | tr ' /' '__').txt" 2>/dev/null   # files the run created, for pack.sh SAVEDIR
grep -ihE "exception|error" $P/.wineconvert/ov$K/glogs/* 2>/dev/null | sort | uniq -c | sort -rn | head -3 | cut -c1-150
