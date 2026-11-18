#!/bin/bash
# wait.sh k...: wait until each slot's output file has its final line
. "$(dirname "$0")/env.sh"
for k in "$@"; do
  until grep -qE "^(audio:|PREP FAILED|ALL DONE)" $S/slot$k.out 2>/dev/null; do sleep 3; done
done
sleep 4
for k in "$@"; do grep -E "^(SLOT|streams|audio|mean|exited|no shots|PREP|WARN|ALL)" $S/slot$k.out; done
