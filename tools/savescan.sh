#!/bin/bash
# savescan.sh [N]: add SAVEDIR/SAVEFILES to the next N packed images that have none:
# unsquash, run in parallel (90 s, in_play.txt), propose lines with savedir.py, repack the found ones.
# Log: work/savescan.tsv (game, result, lines, confidence); games already in it are skipped.
. "$(dirname "$0")/env.sh"
N=${1:-8}
LOG="$S/savescan.tsv"; touch "$LOG"
cd "$P"
todo=()
for f in *.wsquashfs; do
  g="${f%.wsquashfs}"
  (( ${#todo[@]} >= N )) && break
  cut -f1 "$LOG" | grep -qxF "$g" && continue
  [[ -d "$g.wine" ]] && continue
  if unsquashfs -cat "$f" autorun.cmd 2>/dev/null | tr -d '\r' | grep -q '^SAVEDIR='; then
    printf '%s\tpresent\t\t\n' "$g" >> "$LOG"; continue
  fi
  todo+=("$g")
done
(( ${#todo[@]} )) || { echo "ALL DONE"; exit 0; }
for g in "${todo[@]}"; do
  sudo unsquashfs -q -d "$g.wine" "$g.wsquashfs" >/dev/null 2>&1 && sudo chown -R "$(id -u):$(id -g)" "$g.wine"
done
k=1
for g in "${todo[@]}"; do
  (K=$k "$T/run.sh" "$g" "${DUR:-90}" "$T/in_play.txt" > /dev/null 2>&1; cp "$S/upper$k.txt" "$S/upper_$(echo "$g" | tr ' /' '__').txt") &
  k=$((k+1)); sleep 3
done
wait
repack=()
for g in "${todo[@]}"; do
  out=$(python3 -I "$T/savedir.py" "$S/upper_$(echo "$g" | tr ' /' '__').txt")
  conf=$(echo "$out" | grep '^# confidence' | sed 's/^# confidence //')
  lines=$(echo "$out" | grep -E '^SAVE(DIR|FILES)=')
  # nothing written yet: an existing save folder shipped with the game (game/Save, game/Saves)
  if [[ -z "$lines" ]]; then
    d=$(cd "$g.wine" && find game -maxdepth 3 -type d -iregex '.*/save[sd]?\(ata\|games?\)?' | head -1)
    [[ -n "$d" ]] && { lines="SAVEDIR=$d"; conf="medium: existing save folder in the game"; }
  fi
  if [[ -n "$lines" ]]; then
    A="$g.wine/autorun.cmd"
    { tr -d '\r' < "$A" | grep -vE '^SAVE(DIR|FILES)='; echo "$lines"; } > "$A.new" && mv "$A.new" "$A"
    printf '%s\tadded\t%s\t%s\n' "$g" "$(echo "$lines" | tr '\n' ' ')" "$conf" >> "$LOG"
    repack+=("$g")
  else
    printf '%s\tnone\t\t%s\n' "$g" "$conf" >> "$LOG"
    rm -rf "./${g:?}.wine"
  fi
done
(( ${#repack[@]} )) && "$T/repack.sh" "$P" "${repack[@]}"
tail -n ${#todo[@]} "$LOG" | cut -c1-200
