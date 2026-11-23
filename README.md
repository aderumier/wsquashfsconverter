# Windows pack → batocera `.wsquashfs` conversion

Converts each game folder `X/` of a batocera Windows pack into `X.wsquashfs`.
The image holds a GE-Proton wine prefix with the game in `game/` and an `autorun.cmd` at its root.
Every game is test-launched headless, with a virtual Xbox pad, before it is packed.

## Layout

| Path | What |
|------|------|
| `tools/` | all scripts (copy this folder to reuse on another pack) |
| `done.tsv` | packed games: `game <TAB> gamelist entry <TAB> ok <TAB> notes` |
| `todo.tsv` | games set aside: `game <TAB> reason` (folder left untouched) |
| `work/` | per-session scratch: slot logs, screenshots, review images, `games.txt` |
| `ov<K>/` | overlay mounts of the running test slots (cleaned after each run) |
| `keyboard.keys`, `mouse.keys` | evmapy templates for keyboard/mouse-only games |
| `../gamelist.xml.orig` | untouched original gamelist; `gamelist.xml` is regenerated from it |
| `../dontconvert/` | DOSBox / ScummVM games, not converted (own `gamelist.xml`) |

## Requirements

- GE-Proton runner: `~/code/windowsarcadeloader/wine-runners/GE-Proton11-14-x86_64` (override with `WC_RUNNER`).
- Passwordless `sudo` (overlay mounts and `/dev/uinput` for the virtual pad).
- `gamescope`, `bwrap`, `xdotool`, `pactl`/`parec`, ImageMagick (`magick`, `montage`), `mksquashfs`/`unsquashfs`, `gcc`.
- 32-bit host libraries, or 32-bit games test silent: `sudo pacman -S --needed lib32-libpulse lib32-libva lib32-libusb`.

## Install on a pack

Either copy `tools/` to `<pack>/.wineconvert/tools/` (then no setting is needed),
or run from a checkout with `export WC_PACK=/path/to/pack` (the folder that holds `gamelist.xml`).
State files (`done.tsv`, `todo.tsv`, `work/`, overlays) always go to `<pack>/.wineconvert/`.

## Per-session start

```sh
cd /mnt/test/pack4/.wineconvert/tools
./setup.sh            # builds tools/vpad, backs up gamelist.xml once, writes work/games.txt
```

Environment overrides: `WC_PACK` (pack folder, default: the parent of `.wineconvert`), `WC_WORK`, `WC_RUNNER`.

## The loop

```sh
./batch.sh 16         # prep + test the next 16 games in parallel (8 is safer on <32 GB RAM)
```

`batch.sh` prints for each slot:
- `streams:` audio streams the game opened on its own null sink at 30 s
- `audio: peak … nonsilent_s …`
- `mean:` brightness per 5 s frame
- `exited at`, if the game died early

It also writes `work/reviewA.jpg` and `work/reviewB.jpg`: one row per slot, 4 frames at 20/40/55/70 s.
Look at them, then for each game run one of:

```sh
./pack.sh "<game>" "<gamelist entry>" "<notes>"   # clean prefix, mksquashfs zstd, verify, delete .wine, add to done.tsv, rebuild gamelist.xml
./defer.sh "<game>" "<reason>"                    # move game/ back to <game>/, delete the .wine, add to todo.tsv
```

`<gamelist entry>` is the `<path>` the game had in `gamelist.xml.orig`, e.g. `./X/X.exe` (see `work/games.txt`).
The new `gamelist.xml` points that entry to `./X.wsquashfs` and drops the game's other entries.

Single game, or a different input script / duration:

```sh
K=3 IN=tools/in_key.txt DUR=90 ./next.sh "<game>"   # K = slot number (1..16)
NODXVK=1 ./next.sh "<game>"                         # test with wine's own d3d (wined3d) instead of DXVK
D7VK=1 ./next.sh "<game>"                          # D3D7/ddraw game with D7VK, like batocera's per-game d7vk=1 setting
WDEBUG="err+all,+loaddll" K=1 ./run.sh "<game>" 30  # raw run with a custom WINEDEBUG
```

## What each script does

- `prep.sh` resolves the gamelist entry (`.lnk` targets and arguments too, via `resolve.py`/`lnk.py`). It creates `X.wine` with `wineboot -u`, moves `X/` to `X.wine/game`, and writes `autorun.cmd` (`CMD="exe" args`, `DIR=game/sub`).
- `run.sh` bind-mounts `X.wine` and mounts an overlay on top, so test writes never reach the image. It sets up the prefix like batocera does: DXVK/vkd3d-proton symlinks and overrides, the runner FFmpeg in `LD_LIBRARY_PATH`, a US locale, and `wineserver -w`. It then starts gamescope headless and a uinput Xbox 360 pad (`vpad`). bubblewrap gives the game only its own pad node, so slots don't see each other's pads. Audio goes to the null sink `claude_null<K>`. It takes a screenshot every 5 s and copies the game's own logs to `ov<K>/glogs/`.
- Input scripts (`in_*.txt`) are read one line at a time. `sleep MS`, `tap a|b|x|y|start|back|lb|rb|up|down|left|right [MS]`, `btn NAME 0|1` and `axis lx|ly|rx|ry|lt|rt VALUE` go to the pad. `key NAME`, `click X Y` and `move X Y` go through xdotool at 1280x720. `in_a.txt` is the default: pad presses first, then Enter/Space, then mouse clicks.
- `stop.sh` kills slot K and unmounts it.
- `fullscan.sh <list>` scans a list of games in rounds of 8 (brightness, audio, exit time; `OUT=` file), e.g. with `WC_RUNNER=` to compare runners. `desktop.sh "<game>"` shows a game on the real desktop for a human check.
- `bisect.sh` builds vanilla wine plus a growing prefix of the enabled wine-staging patch sets (`patchinstall.py`) and bisects which set breaks a game that runs on vanilla (audio as the pass test). Sources in `$B/src` (wine git) and `$B/stg` (wine-staging), log in `$B/bisect.log`.
- `pack.sh` removes host-specific `dosdevices` entries and the runner symlinks from `system32`/`syswow64`, which batocera recreates. It then runs `mksquashfs -comp zstd` and checks the file count before deleting the folder.

## Fixes that live in the image (no prefix tricks needed)

- Unreal Engine launcher stub asking for "Visual C++ 2015-2022 Redistributable": point `autorun.cmd` at `…/Binaries/Win64/*-Shipping.exe`.
- Game exe launched through a launcher or config tool: point `CMD` at the real exe (Bullet Soul, Mecha Ritz).
- Per-game environment in `autorun.cmd`: `ENV=WINEDLLOVERRIDES="winemenubuilder.exe=;d3d9=b"` forces wine d3d when DXVK breaks (Arcana Heart 3).
- Missing font file: copy wine's own `share/wine/fonts/tahoma*.ttf` into `drive_c/windows/Fonts` (Demons of Asteborg).
- Exe renamed but Unity data folder not: symlink `X_Data` to the real folder (Nongunz).
- Keyboard/mouse-only menus, or a start dialog the pad can't click: put `<Game>.wsquashfs.keys` next to the image (batocera evmapy looks for `{rom.name}.keys`). Start from `keyboard.keys` or `mouse.keys`; for Unity resolution dialogs, Start→Enter only is enough.

## todo.tsv groups (open work)

- WEBVIEW2: needs the Edge WebView2 runtime.
- chromium-black: NW.js/Electron games, black or exit; `--no-sandbox` / `--in-process-gpu` / `--disable-gpu` did not help. They run on vanilla wine 11.22. `bisect.sh` found the wine-staging set `dcomp-DCompositionCreateDevice2` breaks them (vanilla + all staging minus that set works). GE has a second, Proton-side cause: Chromium starts only its crashpad handler, no GPU process, and `dcomp=d` or a vanilla `dcomp.dll` don't help.
- black group: black screen with working audio; investigate as one class.
- input group: menus that ignore pad, Enter and centre clicks.
- VIDEO GROUP: Media Foundation errors (`0xc00d36bb`). If GE-Proton is at fault, fix it in `~/code/protonge` on a new branch for an upstream PR.
- TRICK: winetricks needs (`physx`, `openal`, `d3dcompiler_47`).
- Steam DRM / cracks / Steam emulators / Xbox GDK builds: open group, can be worked on.

## Pitfalls found

- Never put `SDL_AUDIODRIVER` in the test env; Windows SDL has no `pulseaudio` driver.
- Overlayfs `lowerdir=` breaks on commas in the path; run.sh bind-mounts first.
- Launchers that start a child process and exit: wait on `wineserver -w`, like batocera.
- Don't `pgrep -f` for a pattern that also appears in your own command line.
- With `WC_RUNNER=` a vanilla wine updates the GE prefix first ("The Wine configuration … is being updated"), which eats 30 s+ of a 60 s run; use 150 s.
- D3D12 games (vanilla wine: "Could not create a DirectX 12.1 device") need vkd3d-proton, so compare them on GE only.
- Editing `run.sh` while slots are running breaks those runs; bash reads the script as it goes.
