#!/bin/bash
# batch.sh [N]: test the next N unconverted games in parallel (default 8), then print results and build review images
. "$(dirname "$0")/env.sh"
N=${1:-8}
for k in $(seq $N); do rm -f "$S/slot$k.out"; (K=$k IN=${IN:-$T/in_a.txt} DUR=${DUR:-70} "$T/next.sh" > "$S/slot$k.out" 2>&1 &); sleep 3; done
"$T/wait.sh" $(seq $N)
half=$(( (N+1)/2 ))
"$T/review.sh" $(seq 1 $half) >/dev/null && mv "$S/review.jpg" "$S/reviewA.jpg" && echo "review: $S/reviewA.jpg"
(( N > half )) && "$T/review.sh" $(seq $((half+1)) $N) >/dev/null && mv "$S/review.jpg" "$S/reviewB.jpg" && echo "review: $S/reviewB.jpg"
