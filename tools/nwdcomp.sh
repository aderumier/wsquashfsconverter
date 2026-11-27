#!/bin/bash
# nwdcomp.sh prep|pack "<image.wsquashfs>": redo an existing NW.js image with ENV dcomp=d instead of CMD --disable-gpu (see CLAUDE.md).
# prep: extract to <pack>/<game>.wine (run.sh tests it with WC_PACK=<pack>), drop --disable-gpu from CMD, merge dcomp=d into ENV.
# pack: mksquashfs the .wine with the original image's block size/zstd level to <image>.new, check it, replace the image, remove the .wine.
set -e
A="$1"; F=$(realpath "$2"); P=$(dirname "$F"); G=$(basename "$F" .wsquashfs); W="$P/$G.wine"; T=$(dirname "$0")
case "$A" in
prep)
  [[ -e "$W" ]] && { echo "exists: $W" >&2; exit 1; }
  sudo unsquashfs -q -d "$W" "$F" >/dev/null; sudo chown -R "$(id -u):$(id -g)" "$W"
  sed -i -E 's/^(CMD=.*) --disable-gpu/\1/' "$W/autorun.cmd"
  python3 "$T/envsteam.py" "$W/autorun.cmd" dcomp=d
  tr -d '\r' < "$W/autorun.cmd" | grep -E '^(CMD|ENV)=' ;;
pack)
  [[ -f "$W/autorun.cmd" ]] || { echo "no $W" >&2; exit 1; }
  st=$(unsquashfs -s "$F"); bs=$(sed -n 's/^Block size //p' <<<"$st"); lv=$(sed -n 's/^[[:space:]]*compression-level //p' <<<"$st")
  rm -f "$F.new"
  nice -n 19 ionice -c3 mksquashfs "$W" "$F.new" -comp zstd -b "$bs" ${lv:+-Xcompression-level $lv} -quiet -no-progress -processors 8
  unsquashfs -cat "$F.new" autorun.cmd | grep -q 'dcomp=d' || { echo "verify failed: $F.new" >&2; exit 1; }
  mv "$F.new" "$F"; rm -rf "$W"; echo "packed $G" ;;
*) echo "usage: nwdcomp.sh prep|pack <image.wsquashfs>" >&2; exit 1 ;;
esac
