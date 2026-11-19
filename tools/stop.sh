#!/bin/bash
# stop.sh: stop slot $K (default 0) game, pad, audio capture, overlay
. "$(dirname "$0")/env.sh"
K=${K:-0}; O=$P/.wineconvert/ov$K
for p in $(pgrep -f "gamescope --backend headless -W"); do grep -q "$O/launch.sh" /proc/$p/cmdline 2>/dev/null && kill $p; done
for p in $(pgrep -f "[p]arec -d claude_null$K.monitor"); do kill $p; done
if mountpoint -q $O/mnt; then
  WINEPREFIX=$O/mnt "$WINESERVER" -k 2>/dev/null; sleep 2
  sudo fuser -km $O/mnt >/dev/null 2>&1; sleep 1
  sudo umount $O/mnt || sudo umount -l $O/mnt || { echo "UMOUNT FAILED"; exit 1; }
fi
mountpoint -q $O/glayer/game && { sudo umount $O/glayer/game || sudo umount -l $O/glayer/game; }
mountpoint -q $O/lower && { sudo umount $O/lower || sudo umount -l $O/lower; }
# the pad exits when its fifo writer closes; force it if still there
[[ -p $O/pad.fifo ]] && { timeout 1 bash -c "echo quit > $O/pad.fifo" 2>/dev/null; rm -f $O/pad.fifo; }
sudo rm -rf "${O:?}/upper" "${O:?}/work"
rm -f $O/info
true
