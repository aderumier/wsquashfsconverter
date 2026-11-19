#!/bin/bash
# bisect.sh: find the wine-staging patch set that breaks a game that runs on vanilla wine.
# env: B (work dir with src/ = vanilla wine git tree, stg/ = wine-staging), GAME, DUR, GOOD_NS (nonsilent audio seconds = works)
# log: $B/bisect.log
. "$(dirname "$0")/env.sh"
B=${B:-$HOME/.cache/wsquashfsconverter/bisect}; GAME=${GAME:-Devils Drizzle}; DUR=${DUR:-70}; GOOD_NS=${GOOD_NS:-5}
LOG=$B/bisect.log; BLD=$B/build; INST=$B/inst
log(){ echo "$(date +%H:%M) $*" | tee -a $LOG >&2; }

mapfile -t SETS < <(cd $B/stg/patches && for d in */; do d=${d%/}; [[ -f $d/definition ]] || continue; grep -qi '^Disabled:\s*true' $d/definition && continue; echo $d; done)

build(){ # build vanilla + given patch sets (deps added by patchinstall)
  cd $B/src && git reset -q --hard && git clean -fdxq
  if (( $# )); then python3 -I $B/stg/staging/patchinstall.py --destdir=$B/src --backend=patch "$@" > $B/patch.log 2>&1 || { log "patchinstall failed: $(tail -2 $B/patch.log | tr '\n' ' ')"; return 1; }; fi
  mkdir -p $BLD && cd $BLD
  [[ -f Makefile ]] || $B/src/configure -q --enable-archs=i386,x86_64 --prefix=$INST > $B/configure.log 2>&1 || { log "configure failed"; return 1; }
  nice make -j16 > $B/make.log 2>&1 || { log "make failed: $(grep -m1 -E 'error' $B/make.log)"; return 1; }
  rm -rf $INST && make install > $B/install.log 2>&1 || { log "install failed"; return 1; }
}
test_game(){ # prints GOOD/BAD
  cd $P && NODXVK=1 WC_RUNNER=$INST K=22 $T/run.sh "$GAME" $DUR /dev/null > $B/run.out 2>&1
  local ns=$(grep -m1 '^audio:' $B/run.out | grep -oE 'nonsilent_s [0-9.]+' | cut -d' ' -f2)
  log "  audio nonsilent ${ns:-0}s"
  awk -v n="${ns:-0}" -v g=$GOOD_NS 'BEGIN{exit !(n>=g)}' && echo GOOD || echo BAD
}
step(){ local n=$1; shift; log "build with $n sets: ${*: -1}"; build "$@" || { echo ERR; return; }; test_game; }

log "=== bisect $GAME over ${#SETS[@]} staging sets"
r=$(step 0); log "vanilla: $r"; [[ $r == GOOD ]] || { log "vanilla not GOOD, stop"; exit 1; }
r=$(step ${#SETS[@]} "${SETS[@]}"); log "all sets: $r"; [[ $r == BAD ]] || { log "all sets not BAD, stop"; exit 1; }
lo=0; hi=${#SETS[@]}   # prefix of lo sets is GOOD, prefix of hi sets is BAD
while (( hi - lo > 1 )); do
  mid=$(( (lo + hi) / 2 ))
  r=$(step $mid "${SETS[@]:0:mid}"); log "first $mid sets: $r"
  case $r in GOOD) lo=$mid;; BAD) hi=$mid;; *) log "error at $mid, stop"; exit 1;; esac
done
log "=== culprit: ${SETS[$((hi-1))]} (prefix $lo GOOD, $hi BAD)"
