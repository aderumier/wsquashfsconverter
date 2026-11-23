#!/bin/bash
# pack.sh "<game>" "<gamelist entry>" "<notes>": clean prefix, mksquashfs zstd, verify, delete .wine, update state + gamelist
. "$(dirname "$0")/env.sh"
G="$1"; E="$2"; N="$3"; W="$P/$G.wine"; F="$P/$G.wsquashfs"
set -e
[[ -d "$W/game" && -f "$W/autorun.cmd" ]] || { echo "bad $W"; exit 1; }
mountpoint -q $P/.wineconvert/ov0/mnt && { echo "overlay still mounted"; exit 1; }
find "$W/dosdevices" -mindepth 1 -maxdepth 1 ! -name 'c:' ! -name 'z:' ! -name 'w:' -exec rm -f {} +
find "$W/drive_c/windows/system32" "$W/drive_c/windows/syswow64" -maxdepth 1 -type l -delete
[[ -e "$F" ]] && { echo "$F exists"; exit 1; }
# saves: SAVEDIR/SAVEFILES from the files the test run created (next.sh keeps them), else the engine's save folder
UP="$S/upper_$(echo "$G" | tr ' /' '__').txt"
if ! tr -d '\r' < "$W/autorun.cmd" | grep -q '^SAVEDIR='; then
  out=$(python3 -I "$T/savedir.py" "${UP}" "$W" 2>/dev/null || python3 -I "$T/savedir.py" /dev/null "$W")
  lines=$(grep -E '^SAVE(DIR|FILES)=' <<<"$out" || true)
  [[ -n "$lines" ]] && echo "$lines" >> "$W/autorun.cmd"
  printf '%s\t%s\t%s\t%s\n' "$G" "$([[ -n "$lines" ]] && echo added || echo none)" "$(tr '\n' ' ' <<<"$lines")" "$(sed -n 's/^# confidence //p' <<<"$out")" >> "$S/savescan.tsv"
fi
nice -n 19 ionice -c3 mksquashfs "$W" "$F" -comp zstd ${SQOPTS:-} -quiet -no-progress -processors 8
unsquashfs -l "$F" | grep -q "squashfs-root/autorun.cmd" || { echo "verify failed"; rm -f "$F"; exit 1; }
n1=$(find "$W" | wc -l); n2=$(($(unsquashfs -l "$F" | grep -c '^squashfs-root')))
[[ $n1 -eq $n2 ]] || { echo "count mismatch $n1 $n2"; rm -f "$F"; exit 1; }
rm -rf "${P:?}/${G:?}.wine"
# rebuilt from an old image (importimg.sh): delete it, move its pad mapping next to the new one
old=$(awk -F'\t' -v g="$G" '$1 == g {print $2}' "$P/.wineconvert/sources.tsv" 2>/dev/null | tail -1)
if [[ -n "$old" && -f "$old" ]]; then
  ob=${old%.wsquashfs}; ob=${ob%.wine}
  for k in "$ob.wsquashfs.keys" "$ob.wine.wsquashfs.keys" "$old.keys"; do [[ -f "$k" ]] && mv -n "$k" "$F.keys"; done
  printf '%s\t%s\t%s\n' "$G" "$(stat -c %s "$old")" "$(stat -c %s "$F")" >> "$S/sizes.tsv"   # old and new image size
  rm -f "$old"
fi
printf '%s\t%s\tok\t%s\n' "$G" "$E" "$N" >> $P/.wineconvert/done.tsv
python3 -I $T/gamelist.py
ls -la "$F" | awk '{print $5}'
df -h "$P" | tail -1 | awk '{print "free " $4}'
