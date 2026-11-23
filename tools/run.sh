#!/bin/bash
# run.sh "<game>" <seconds> [inputfile]: batocera-like launch on an overlay of <game>.wine in slot $K (default 0),
# headless gamescope, own virtual pad only (bwrap), own null sink, screenshots every 5s
. "$(dirname "$0")/env.sh"
G="$1"; DUR=${2:-60}; IN="$3"; W="${WC_WINEPFX:-$P/$G.wine}"; K=${K:-0}
O=$P/.wineconvert/ov$K; OUT=$S/shots$K; LOG=$S/run$K.log; SINK=claude_null$K
K=$K "$T/stop.sh" >/dev/null 2>&1
mkdir -p $O/upper $O/work $O/mnt "$OUT"; rm -f "$OUT"/*.png
mkdir -p $O/lower; mountpoint -q $O/lower && sudo umount $O/lower
if [[ "${FULL:-0}" = 1 ]]; then
  # test against the windowsarcadeloader "full" prefix copy: game layer on top of it, nothing written to either
  FP=${FULLPREFIX:-$P/.wineconvert/fullprefix}
  # overlayfs does not see mounts nested in a lower layer: link game/ to the real folder instead
  mountpoint -q $O/glayer/game && sudo umount $O/glayer/game
  rm -rf "${O:?}/glayer"; mkdir -p $O/glayer
  cp "$W/autorun.cmd" $O/glayer/autorun.cmd
  ln -s "$W/game" $O/glayer/game
  sudo mount --bind "$FP" $O/lower || { echo "audio: MOUNT FAILED"; exit 1; }
  LOWER=$O/glayer:$O/lower
else
  sudo mount --bind "$W" $O/lower || { echo "audio: MOUNT FAILED"; exit 1; }
  LOWER=$O/lower
fi
sudo mount -t overlay overlay -o lowerdir=$LOWER,upperdir=$O/upper,workdir=$O/work,redirect_dir=on $O/mnt || { sudo umount $O/lower; echo "audio: MOUNT FAILED"; exit 1; }
sudo chown $(id -u):$(id -g) $O/mnt
PFX=$O/mnt
S32=$PFX/drive_c/windows/system32; W64=$PFX/drive_c/windows/syswow64
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
if [[ "${D7VK:-0}" = 1 ]]; then
  # like batocera's per-game d7vk=1: D7VK ddraw, wine's ddraw next to it as ddraw_.dll for 2D calls
  ln -sf $R/lib/wine/d7vk/i386-windows/ddraw.dll $W64/ddraw.dll
  ln -sf $R/lib/wine/i386-windows/ddraw.dll $W64/ddraw_.dll
  OVR="$OVR;ddraw=n,b"
else
  ln -sf $R/lib/wine/i386-windows/ddraw.dll $W64/ddraw.dll
fi
FULLOVR=""
if [[ "${FULL:-0}" = 1 ]]; then
  # like the loader: its isolated tricks stay builtin unless asked (DSOUND=1 keeps the native dsound for sound problems),
  # and the pad is turned back on (the loader prefix disables winebus input; its games read the I/O board instead)
  FULLOVR="dplaysvr.exe,dplayx,dpmodemx,dpnet,dpnhpast,dpnhupnp,dpnsvr.exe,dpwsockx,jscript,scrrun,vbscript,cscript.exe,wscript.exe=b"
  [[ "${DSOUND:-0}" = 1 ]] || FULLOVR="dsound=b;$FULLOVR"
  for v in "Enable SDL:1" "DisableInput:0" "DisableHidraw:1"; do
    WINEPREFIX=$PFX WINEDEBUG=-all DISPLAY= "$WINE" reg add 'HKLM\System\CurrentControlSet\Services\winebus' /v "${v%%:*}" /t REG_DWORD /d "${v##*:}" /f >/dev/null 2>&1
  done
  WINEPREFIX=$PFX "$WINESERVER" -w
fi
CMD=$(tr -d '\r' < $PFX/autorun.cmd | grep ^CMD= | sed 's/^CMD=//' | head -1)
DIR=$(tr -d '\r' < $PFX/autorun.cmd | grep ^DIR= | sed 's/^DIR=//' | head -1)
AENV=$(tr -d '\r' < $PFX/autorun.cmd | grep ^ENV= | sed 's/^ENV=//' | head -1)
pactl list short sinks | grep -q "$SINK\b" || pactl load-module module-null-sink sink_name=$SINK >/dev/null
# virtual pad first: the game sandbox only gets its event node
mkfifo $O/pad.fifo 2>/dev/null
( sudo $T/vpad < $O/pad.fifo > $O/vpad.log 2>&1 & )
exec 7>$O/pad.fifo
for i in $(seq 50); do grep -q ready $O/vpad.log 2>/dev/null && break; sleep 0.1; done
EV=$(grep -o '/dev/input/event[0-9]*' $O/vpad.log)
for i in $(seq 30); do [[ -r "$EV" ]] && break; sleep 0.1; done
cat > $O/launch.sh <<EOS
cd "$PFX/$DIR" || exit 1
export WINEPREFIX="$PFX" WINEDEBUG="${WDEBUG:-err+all}" DXVK_LOG_LEVEL=${DXVK_LOG:-none} WINE_ENABLE_HIDRAW=0 WINE_FULLSCREEN_FSR=0
export WINE_MONO_OVERRIDES="Microsoft.Xna.Framework.*,Gac=n" WINE_ALLOW_XIM=0 DXVK_ASYNC=1 DXVK_STATE_CACHE=0 STAGING_SHARED_MEMORY=1
export WINEDLLOVERRIDES="winemenubuilder.exe=;$OVR;nvapi64,nvapi=${FULLOVR:+;$FULLOVR}"
export PULSE_SINK=$SINK
export LD_LIBRARY_PATH="/usr/lib32:$R/lib/wine/i386-unix:/usr/lib:$R/lib/wine/x86_64-unix:$R/lib/x86_64-linux-gnu:$R/lib/i386-linux-gnu"
export WINEDLLPATH="$R/lib/wine/i386-windows:$R/lib/wine/x86_64-windows" PATH="$R/bin:\$PATH" WINEDISABLEFASTSYNC=0 LC_ALL=en_US.UTF-8 LANGUAGE=en_US VKD3D_DEBUG=none
$AENV ${EXTRAENV} "$WINE" $CMD
"$WINESERVER" -w
EOS
( gamescope --backend headless -W ${WW:-1280} -H ${WH:-720} -w ${WW:-1280} -h ${WH:-720} -- \
    bwrap --dev-bind / / --tmpfs /dev/input $( [[ "${NOCAM:-0}" = 1 ]] && for v in /dev/video*; do [[ -c $v ]] && echo --ro-bind /dev/null $v; done ) --dev-bind "$EV" "$EV" $( [[ "${UDEV:-0}" = 1 ]] || echo --tmpfs /run/udev ) \
    bash $O/launch.sh > $LOG 2>&1 ) &
GSPID=$!
parec -d $SINK.monitor --format=s16le --rate=8000 --channels=1 --raw > $O/audio.raw 2>/dev/null &
XD=""
for i in $(seq 50); do XD=$(grep -o "Starting Xwayland on :[0-9]*" $LOG 2>/dev/null | grep -o ':[0-9]*' | head -1); [[ -n $XD ]] && break; sleep 0.2; done
if [[ -n "$IN" ]]; then
  ( while read -r a b c d; do
      case "$a" in
        sleep) sleep $(awk "BEGIN{print $b/1000}") ;;
        click) DISPLAY=$XD xdotool mousemove $b $c click 1 ;;
        move) DISPLAY=$XD xdotool mousemove $b $c ;;
        key) DISPLAY=$XD xdotool key $b ;;
        *) echo "$a $b $c $d" >&7 ;;
      esac
    done < "$IN" ) &
fi
t=0
GS=""
for i in $(seq 50); do GS=$(grep -o "wayland display 'gamescope-[0-9]*'" $LOG 2>/dev/null | grep -o 'gamescope-[0-9]*' | head -1); [[ -n $GS ]] && break; sleep 0.2; done
echo "socket $GS ev $EV" >> $O/info
while (( t < DUR )); do
  sleep 5; t=$((t+5))
  GAMESCOPE_WAYLAND_DISPLAY=$GS gamescopectl screenshot "$OUT/$(printf %03d $t).png" >/dev/null 2>&1
  if (( t == 30 )); then sid=$(pactl list short sinks | awk -v n=$SINK '$2==n{print $1}'); echo "streams: $(pactl list short sink-inputs | awk -v s=$sid '$2==s' | wc -l)"; fi
  kill -0 $GSPID 2>/dev/null || { echo "exited at $t"; break; }
done
# files the run created (for SAVEDIR/SAVEFILES): skip wine's own dirs and temp files
find $O/upper -type f ! -path '*/drive_c/windows/*' ! -path '*/AppData/Local/Temp/*' ! -path '*/Temp/*' ! -name '*.reg' ! -path '*/.update-timestamp' -printf '%P\t%s\n' 2>/dev/null | sort > "$S/upper$K.txt"
rm -rf "${O:?}/glogs"; mkdir -p $O/glogs; find $O/upper \( -iname "*.log" -o -iname "*log*.txt" -o -iname "${GLOGX:-__none__}" \) -size -5M -exec cp {} $O/glogs/ \; 2>/dev/null
exec 7>&-
K=$K "$T/stop.sh"
echo "audio: $(python3 -I $T/audio.py $O/audio.raw)"
cd "$OUT" && ls *.png >/dev/null 2>&1 || { echo "no shots"; exit 0; }
echo "mean: $(for f in *.png; do printf '%s=%s ' ${f%.png} $(magick "$f" -alpha off -colorspace gray -format '%[fx:int(mean*100)]' info:); done)"
montage *.png -geometry 240x135+1+1 -tile 6x -pointsize 14 -label '%t' "$S/sheet$K.jpg" 2>/dev/null && echo "sheet $S/sheet$K.jpg"
