#!/bin/bash
# desktop.sh "<game>" [seconds]: run the game on the real desktop (DISPLAY), batocera-like env, overlay so nothing is written
# to the image; for a human to look at it. Slot $K (default 20). NODXVK=1 for wined3d.
. "$(dirname "$0")/env.sh"
G="$1"; DUR=${2:-120}; K=${K:-20}; W="${WC_WINEPFX:-$P/$G.wine}"; O=$P/.wineconvert/ov$K
if [[ ! -d "$W" ]]; then
  E=$(grep -F "|$G|" $S/games.txt | head -1 | cut -d'|' -f4 | sed 's/ ; /\n/g' | grep -viE 'unins|redist|crash|\.url$|\.bat$|setup' | head -1)
  "$T/prep.sh" "$G" "$E" >/dev/null || exit 1
fi
K=$K "$T/stop.sh" >/dev/null 2>&1
mkdir -p $O/upper $O/work $O/mnt $O/lower
sudo mount --bind "$W" $O/lower && sudo mount -t overlay overlay -o lowerdir=$O/lower,upperdir=$O/upper,workdir=$O/work,redirect_dir=on $O/mnt || exit 1
sudo chown $(id -u):$(id -g) $O/mnt
PFX=$O/mnt; S32=$PFX/drive_c/windows/system32; W64=$PFX/drive_c/windows/syswow64
ln -sf $R/lib/vkd3d/x86_64-windows/*.dll $S32 2>/dev/null; ln -sf $R/lib/vkd3d/i386-windows/*.dll $W64 2>/dev/null
ln -sf $R/lib/wine/icu/x86_64-windows/*.dll $S32 2>/dev/null; ln -sf $R/lib/wine/icu/i386-windows/*.dll $W64 2>/dev/null
if [[ "${NODXVK:-0}" = 1 ]]; then
  ln -sf $R/lib/wine/x86_64-windows/{d3d8,d3d12,d3d12core,d3d11,d3d10core,d3d9,dxgi}.dll $S32
  ln -sf $R/lib/wine/i386-windows/{d3d8,d3d12,d3d12core,d3d11,d3d10core,d3d9,dxgi}.dll $W64
  OVR="dxgi,d3d8,d3d9,d3d10core,d3d11,d3d12,d3d12core=b"
else
  ln -sf $R/lib/wine/dxvk/x86_64-windows/{d3d8,d3d9,d3d10core,d3d11,dxgi}.dll $S32
  ln -sf $R/lib/wine/dxvk/i386-windows/{d3d8,d3d9,d3d10core,d3d11,dxgi}.dll $W64
  ln -sf $R/lib/wine/vkd3d-proton/x86_64-windows/{d3d12,d3d12core}.dll $S32
  ln -sf $R/lib/wine/vkd3d-proton/i386-windows/{d3d12,d3d12core}.dll $W64
  OVR="dxgi,d3d8,d3d9,d3d10core,d3d11,d3d12,d3d12core=n"
fi
ln -sf $R/lib/wine/i386-windows/ddraw.dll $W64/ddraw.dll
CMD=$(tr -d '\r' < $PFX/autorun.cmd | grep ^CMD= | sed 's/^CMD=//' | head -1)
DIR=$(tr -d '\r' < $PFX/autorun.cmd | grep ^DIR= | sed 's/^DIR=//' | head -1)
AENV=$(tr -d '\r' < $PFX/autorun.cmd | grep ^ENV= | sed 's/^ENV=//' | head -1)
cat > $O/launch.sh <<EOS
cd "$PFX/$DIR" || exit 1
export WINEPREFIX="$PFX" WINEDEBUG="err+all" DXVK_LOG_LEVEL=none WINE_ENABLE_HIDRAW=0 WINE_FULLSCREEN_FSR=0
export WINE_MONO_OVERRIDES="Microsoft.Xna.Framework.*,Gac=n" WINE_ALLOW_XIM=0 DXVK_ASYNC=1 DXVK_STATE_CACHE=0 STAGING_SHARED_MEMORY=1
export WINEDLLOVERRIDES="winemenubuilder.exe=;$OVR;nvapi64,nvapi="
export LD_LIBRARY_PATH="/usr/lib32:$R/lib/wine/i386-unix:/usr/lib:$R/lib/wine/x86_64-unix:$R/lib/x86_64-linux-gnu:$R/lib/i386-linux-gnu"
export WINEDLLPATH="$R/lib/wine/i386-windows:$R/lib/wine/x86_64-windows" PATH="$R/bin:\$PATH" WINEDISABLEFASTSYNC=0 LC_ALL=en_US.UTF-8 LANGUAGE=en_US VKD3D_DEBUG=none
$AENV ${WRAP} "$WINE" $CMD
"$WINESERVER" -w
EOS
echo "launching $G on $DISPLAY for ${DUR}s"
timeout $DUR bash $O/launch.sh > $S/desktop.log 2>&1
K=$K "$T/stop.sh"
echo "done; log $S/desktop.log"
