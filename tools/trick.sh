#!/bin/bash
# trick.sh "<game>" verb...: prep <game>.wine if needed, then install winetricks verbs into its prefix (kept in the image)
. "$(dirname "$0")/env.sh"
G="$1"; shift
W="$P/$G.wine"
if [[ ! -d "$W" ]]; then
  E=$(grep -F "|$G|" $S/games.txt | head -1 | cut -d'|' -f4 | sed 's/ ; /\n/g' | grep -viE 'unins|redist|crash|\.url$|\.bat$|setup' | head -1)
  "$T/prep.sh" "$G" "$E" || exit 1
fi
mountpoint -q "$W" && { echo "$W is mounted"; exit 1; }
WINEPREFIX="$W" WINE="$WINE" WINESERVER="$WINESERVER" WINEDEBUG=-all DISPLAY= PATH="$R/bin:$PATH" \
  "$R/bin/winetricks" -q --unattended "$@" > "$S/trick-$(echo "$G" | tr -c 'A-Za-z0-9' _).log" 2>&1
rc=$?
WINEPREFIX="$W" "$WINESERVER" -w
echo "winetricks $* -> rc=$rc"
exit $rc
