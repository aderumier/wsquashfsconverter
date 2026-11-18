#!/bin/bash
# retry.sh <listfile> <start> <count>: rerun games from a list in slots 1..count (env NODXVK/DUR/IN passed through), then review
. "$(dirname "$0")/env.sh"
L="$1"; st=${2:-1}; n=${3:-8}
k=1; sed -n "${st},$((st+n-1))p" "$L" | while IFS= read -r g; do rm -f "$S/slot$k.out"; (K=$k IN=${IN:-$T/in_a.txt} DUR=${DUR:-70} "$T/next.sh" "$g" > "$S/slot$k.out" 2>&1 &); sleep 3; k=$((k+1)); done
c=$(sed -n "${st},$((st+n-1))p" "$L" | wc -l)
"$T/wait.sh" $(seq $c) | paste -s -d' ' | sed 's/SLOT=/\n/g; s/ GAME=/ /g; s/nonsilent_s/ns/g' | cut -c1-110
h=$(( (c+1)/2 )); "$T/review.sh" $(seq 1 $h) >/dev/null && mv "$S/review.jpg" "$S/reviewA.jpg"; (( c > h )) && "$T/review.sh" $(seq $((h+1)) $c) >/dev/null && mv "$S/review.jpg" "$S/reviewB.jpg"; echo reviewed
