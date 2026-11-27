#!/bin/bash
# rmwow64.sh prep|pack "<image.wsquashfs>": redo an image without ENV WINEARCH=wow64 (only needed when the host lacked lib32-libxcomposite; see CLAUDE.md).
# prep: extract to <pack>/<game>.wine (test it with WC_PACK=<pack> run.sh), drop WINEARCH=wow64 from the ENV line (the line goes if nothing is left).
# pack: mksquashfs with the original image's block size/zstd level to <image>.new, check it, replace the image, remove the .wine.
set -e
A="$1"; F=$(realpath "$2"); P=$(dirname "$F"); G=$(basename "$F" .wsquashfs); W="$P/$G.wine"
case "$A" in
prep)
  [[ -e "$W" ]] && { echo "exists: $W" >&2; exit 1; }
  sudo unsquashfs -q -d "$W" "$F" >/dev/null; sudo chown -R "$(id -u):$(id -g)" "$W"
  sed -i -E 's/^(ENV=.*)WINEARCH=wow64 ?/\1/; /^ENV=[[:space:]]*\r?$/d' "$W/autorun.cmd"
  tr -d '\r' < "$W/autorun.cmd" | grep -E '^(CMD|ENV)=' ;;
pack)
  [[ -f "$W/autorun.cmd" ]] || { echo "no $W" >&2; exit 1; }
  st=$(unsquashfs -s "$F"); bs=$(sed -n 's/^Block size //p' <<<"$st"); lv=$(sed -n 's/^[[:space:]]*compression-level //p' <<<"$st")
  rm -f "$F.new"
  nice -n 19 ionice -c3 mksquashfs "$W" "$F.new" -comp zstd -b "$bs" ${lv:+-Xcompression-level $lv} -quiet -no-progress -processors 8
  unsquashfs -cat "$F.new" autorun.cmd | grep -q 'WINEARCH=wow64' && { echo "verify failed: $F.new" >&2; exit 1; }
  mv "$F.new" "$F"; rm -rf "$W"; echo "packed $G" ;;
*) echo "usage: rmwow64.sh prep|pack <image.wsquashfs>" >&2; exit 1 ;;
esac
