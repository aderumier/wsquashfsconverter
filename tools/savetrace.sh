#!/bin/bash
# savetrace.sh <list file> [N]: for games the save scan found nothing in, run N at a time with a wine file trace
# and keep the save-like paths each game opened or tried to open (work/trace_<game>.txt).
# Games whose trace file exists are skipped; prints "ALL DONE" when the list is finished.
. "$(dirname "$0")/env.sh"
LIST=$1; N=${2:-4}
cd "$P"
todo=()
while IFS= read -r g; do
  (( ${#todo[@]} >= N )) && break
  t="$S/trace_$(echo "$g" | tr ' /' '__').txt"
  [[ -f "$t" || -d "$g.wine" ]] && continue
  todo+=("$g")
done < "$LIST"
(( ${#todo[@]} )) || { echo "ALL DONE"; exit 0; }
for g in "${todo[@]}"; do
  sudo unsquashfs -q -d "$g.wine" "$g.wsquashfs" >/dev/null 2>&1 && sudo chown -R "$(id -u):$(id -g)" "$g.wine"
done
k=1
for g in "${todo[@]}"; do
  (WDEBUG=+file K=$k "$T/run.sh" "$g" "${DUR:-60}" "$T/in_play.txt" > /dev/null 2>&1
   grep -aoE 'name=L"[^"]*"' "$S/run$k.log" | sed 's/^name=L"//; s/"$//; s/\\\\/\\/g' | grep -viE '\\windows\\|\\dosdevices|\.(dll|exe|pak|png|ogg|wav|ttf|dds|bmp|jpg|mp3|mp4|bik|xnb)$' \
     | grep -iE 'sav|save|\.ini$|\.cfg$|score|nvram|profile|record|progress|\.dat$|\.bin$|My Games|Saved Games|AppData|Documents' | sort -u > "$S/trace_$(echo "$g" | tr ' /' '__').txt"
   : > "$S/run$k.log") &
  k=$((k+1)); sleep 3
done
wait
for g in "${todo[@]}"; do rm -rf "./${g:?}.wine"; done
for g in "${todo[@]}"; do echo "== $g"; head -12 "$S/trace_$(echo "$g" | tr ' /' '__').txt" | cut -c1-160; done
