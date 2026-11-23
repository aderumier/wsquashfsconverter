#!/bin/bash
# retest.sh <list of .wsquashfs images> [N]: quick re-test of packed images (after a runner or batocera-wine change),
# N at a time (default 8): each image is loop-mounted read-only and run like a test (run.sh on an overlay, DUR default 60 s).
# Appends to work/retest.tsv: image, max brightness, audio peak, nonsilent seconds, exited at, flag (ok|BLACK|SILENT|EXIT);
# images already in it are skipped. Review sheets of each round: work/retest_<round>.jpg. Prints "ALL DONE" at the end.
. "$(dirname "$0")/env.sh"
L="$1"; N=${2:-8}; out=$S/retest.tsv; touch "$out"
todo=()
while IFS= read -r f; do
  (( ${#todo[@]} >= N )) && break
  [[ -f "$f" ]] || continue
  cut -f1 "$out" | grep -qxF "$f" && continue
  todo+=("$f")
done < "$L"
(( ${#todo[@]} )) || { echo "ALL DONE"; exit 0; }
k=1
for f in "${todo[@]}"; do
  m=$P/.wineconvert/img$k; mkdir -p "$m"
  mountpoint -q "$m" && sudo umount "$m"
  sudo mount -o loop,ro -t squashfs "$f" "$m" || { printf '%s\t\t\t\t\tMOUNT\n' "$f" >> "$out"; k=$((k+1)); continue; }
  g=$(basename "$f" .wsquashfs)
  (echo "SLOT=$k GAME=$g"; WC_WINEPFX="$m" K=$k "$T/run.sh" "$g" "${DUR:-60}" "${IN:-$T/in_a.txt}" 2>&1) > "$S/slot$k.out" &
  k=$((k+1)); sleep 3
done
wait
r=$(( $(wc -l < "$out") / N + 1 ))
k=1
for f in "${todo[@]}"; do
  m=$P/.wineconvert/img$k; mountpoint -q "$m" || { k=$((k+1)); continue; }   # mount failed: already logged
  o=$S/slot$k.out
  mx=$(grep -m1 '^mean:' "$o" | grep -oE '=[0-9]+' | tr -d = | sort -n | tail -1)
  pk=$(sed -n 's/^audio: peak \([0-9]*\).*/\1/p' "$o"); ns=$(sed -n 's/.*nonsilent_s \([0-9.]*\).*/\1/p' "$o")
  ex=$(sed -n 's/^exited at //p' "$o")
  flag=ok
  [[ -z "$mx" || "${mx:-0}" -le 2 ]] && flag=BLACK
  [[ "$flag" = ok && "${pk:-0}" -le 50 ]] && flag=SILENT
  [[ -n "$ex" && "$ex" -lt 40 ]] && flag=EXIT
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$f" "$mx" "$pk" "$ns" "$ex" "$flag" >> "$out"
  sudo umount "$m"
  k=$((k+1))
done
"$T/review.sh" $(seq 1 ${#todo[@]}) >/dev/null 2>&1 && mv "$S/review.jpg" "$S/retest_$r.jpg"
tail -n ${#todo[@]} "$out" | awk -F'\t' '{n=split($1,a,"/"); print a[n] "\t" $6}'
