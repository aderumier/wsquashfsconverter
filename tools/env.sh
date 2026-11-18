# shared settings; override with WC_PACK / WC_WORK / WC_RUNNER
T=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
if [[ -z "$WC_PACK" && "$(basename "$(dirname "$T")")" == .wineconvert ]]; then WC_PACK=$(dirname "$(dirname "$T")"); fi
[[ -n "$WC_PACK" && -f "$WC_PACK/gamelist.xml" ]] || { echo "set WC_PACK to the pack folder (the one with gamelist.xml)" >&2; exit 1; }
P=$WC_PACK
S=${WC_WORK:-$P/.wineconvert/work}
R=${WC_RUNNER:-/home/aderumier/code/windowsarcadeloader/wine-runners/GE-Proton11-12-x86_64}
WINE=$R/bin/wine
WINESERVER=$R/bin/wineserver
mkdir -p "$S"
export WC_PACK="$P"
