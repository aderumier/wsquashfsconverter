#!/bin/bash
# webview2.sh "<game>": prep <game>.wine if needed, copy the WebView2 Fixed Version runtime to C:\webview2
# and point the game at it with ENV=WEBVIEW2_BROWSER_EXECUTABLE_FOLDER in autorun.cmd (the Evergreen installer fails under wine)
. "$(dirname "$0")/env.sh"
G="$1"
W="$P/$G.wine"
RT=$(ls -d $HOME/.cache/wsquashfsconverter/webview2/fixed/Microsoft.WebView2.FixedVersionRuntime.*.x64 2>/dev/null | tail -1)
[[ -x "$RT/msedgewebview2.exe" || -f "$RT/msedgewebview2.exe" ]] || { echo "unpack the Fixed Version x64 cab into ~/.cache/wsquashfsconverter/webview2/fixed first"; exit 1; }
if [[ ! -d "$W" ]]; then
  E=$(grep -F "|$G|" $S/games.txt | head -1 | cut -d'|' -f4 | sed 's/ ; /\n/g' | grep -viE 'unins|redist|crash|\.url$|\.bat$|setup' | head -1)
  "$T/prep.sh" "$G" "$E" >/dev/null || exit 1
fi
mountpoint -q "$W" && { echo "$W is mounted"; exit 1; }
rm -rf "${W:?}/drive_c/webview2"
cp -a "$RT" "$W/drive_c/webview2" || exit 1
A="$W/autorun.cmd"
grep -v '^ENV=' "$A" > "$A.new"
echo "ENV=WEBVIEW2_BROWSER_EXECUTABLE_FOLDER='C:\\webview2' ${WV2_EXTRA}" >> "$A.new"
mv "$A.new" "$A"
cat "$A"
