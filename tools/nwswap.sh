#!/bin/bash
# nwswap.sh "<game>": old NW.js (natives_blob.bin, ~2018) black on wine even with dcomp=d -> official NW.js 0.94.0 win-x64 runtime.
# Old runtime files go to game/_nw_orig/, the app (package.nw / package.json+www) stays; CMD becomes "nw.exe" (args and ENV kept). See CLAUDE.md.
. "$(dirname "$0")/env.sh"
G="$1"; W="$P/$G.wine"; D="$W/game"; NW=${NWJS:-$HOME/.cache/wsquashfsconverter/nwjs/nwjs-v0.94.0-win-x64}
[[ -d "$D" && -d "$NW" ]] || { echo "need $D and $NW" >&2; exit 1; }
[[ -e "$D/_nw_orig" ]] && { echo "already swapped" >&2; exit 1; }
exe=$(tr -d '\r' < "$W/autorun.cmd" | sed -n 's/^CMD="\([^"]*\)".*/\1/p' | head -1)
mkdir "$D/_nw_orig"
for f in "$exe" nw.exe nw.dll nw_elf.dll node.dll ffmpeg.dll libEGL.dll libGLESv2.dll d3dcompiler_47.dll d3dcompiler_47.dll.old vk_swiftshader.dll vulkan-1.dll \
         icudtl.dat natives_blob.bin snapshot_blob.bin v8_context_snapshot.bin resources.pak nw_100_percent.pak nw_200_percent.pak notification_helper.exe locales swiftshader; do
  [[ -e "$D/$f" ]] && mv "$D/$f" "$D/_nw_orig/"
done
cp -r "$NW"/. "$D/"
sed -i -E "s|^CMD=\"[^\"]*\"|CMD=\"nw.exe\"|" "$W/autorun.cmd"
tr -d '\r' < "$W/autorun.cmd" | grep -E '^(CMD|ENV)='
