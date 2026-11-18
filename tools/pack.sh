#!/bin/bash
# pack.sh "<game>" "<gamelist entry>" "<notes>": clean prefix, mksquashfs zstd, verify, delete .wine, update state + gamelist
. "$(dirname "$0")/env.sh"
G="$1"; E="$2"; N="$3"; W="$P/$G.wine"; F="$P/$G.wsquashfs"
set -e
[[ -d "$W/game" && -f "$W/autorun.cmd" ]] || { echo "bad $W"; exit 1; }
mountpoint -q $P/.wineconvert/ov0/mnt && { echo "overlay still mounted"; exit 1; }
find "$W/dosdevices" -mindepth 1 -maxdepth 1 ! -name 'c:' ! -name 'z:' -exec rm -f {} +
find "$W/drive_c/windows/system32" "$W/drive_c/windows/syswow64" -maxdepth 1 -type l -delete
[[ -e "$F" ]] && { echo "$F exists"; exit 1; }
mksquashfs "$W" "$F" -comp zstd -quiet -no-progress
unsquashfs -l "$F" | grep -q "squashfs-root/autorun.cmd" || { echo "verify failed"; rm -f "$F"; exit 1; }
n1=$(find "$W" | wc -l); n2=$(($(unsquashfs -l "$F" | grep -c '^squashfs-root')))
[[ $n1 -eq $n2 ]] || { echo "count mismatch $n1 $n2"; rm -f "$F"; exit 1; }
rm -rf "${P:?}/${G:?}.wine"
printf '%s\t%s\tok\t%s\n' "$G" "$E" "$N" >> $P/.wineconvert/done.tsv
python3 -I $T/gamelist.py
ls -la "$F" | awk '{print $5}'
df -h /mnt/test | tail -1 | awk '{print "free " $4}'
