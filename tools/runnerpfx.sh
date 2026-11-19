#!/bin/bash
# runnerpfx.sh "<game>" <runner dir>: fresh prefix made by that runner for a runner comparison (never reuse the GE prefix).
# game/ is linked from <game>.wine, autorun.cmd copied. Prints the prefix path; use it as WC_WINEPFX with WC_RUNNER=<runner dir>.
. "$(dirname "$0")/env.sh"
G="$1"; RN="${2:?runner dir}"; SRC="$P/$G.wine"
X="$P/.wineconvert/rp/$(basename "$RN")/$G.wine"
[[ -d "$SRC/game" ]] || { echo "no $SRC/game" >&2; exit 1; }
if [[ ! -f "$X/system.reg" ]]; then
  mkdir -p "$X"
  WINEPREFIX="$X" WINEDEBUG=-all DISPLAY= WINEDLLOVERRIDES="mscoree,mshtml=;winemenubuilder.exe=" "$RN/bin/wine" wineboot -u >/dev/null 2>&1
  WINEPREFIX="$X" "$RN/bin/wineserver" -w
fi
ln -sfn "$SRC/game" "$X/game"
cp "$SRC/autorun.cmd" "$X/autorun.cmd"
echo "$X"
