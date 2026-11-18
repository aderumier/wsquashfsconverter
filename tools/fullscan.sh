#!/bin/bash
# fullscan.sh <listfile>: run every game of the list in rounds of 8 (env FULL/DSOUND/NODXVK/DUR/IN passed through);
# writes work/scan.tsv: game, max frame brightness, audio peak, nonsilent seconds, exited at
. "$(dirname "$0")/env.sh"
L="$1"; out=${OUT:-$S/scan.tsv}; : > "$out"
n=$(wc -l < "$L"); st=1
while (( st <= n )); do
  "$T/retry.sh" "$L" $st 8 >/dev/null 2>&1
  for k in $(seq 8); do
    f=$S/slot$k.out; [[ -f $f ]] || continue
    g=$(grep -m1 "^SLOT=" $f | sed 's/.*GAME=//'); [[ -z $g ]] && continue
    mx=$(grep -m1 "^mean:" $f | grep -oE "=[0-9]+" | tr -d = | sort -n | tail -1)
    pk=$(grep -m1 "^audio:" $f | grep -oE "peak [0-9]+" | cut -d' ' -f2)
    ns=$(grep -m1 "^audio:" $f | grep -oE "nonsilent_s [0-9.]+" | cut -d' ' -f2)
    ex=$(grep -m1 "exited at" $f | grep -oE "[0-9]+$")
    printf '%s\t%s\t%s\t%s\t%s\n' "$g" "${mx:-0}" "${pk:-0}" "${ns:-0}" "${ex:--}" >> "$out"
    d="$S/scanshots-$(echo "$g" | tr -c A-Za-z0-9 _)"; rm -rf "${d:?}"; cp -r "$S/shots$k" "$d" 2>/dev/null
    rm -f "$f"
  done
  st=$((st+8))
done
echo "scan done: $out"
