# Instructions for Claude Code

This repo converts a batocera Windows game pack (one folder per game + `gamelist.xml`) into
`<Game>.wsquashfs` images (GE-Proton prefix + `game/` + `autorun.cmd`), testing every game first.
Read `README.md` for the tools; this file holds the working rules.

## Workflow

1. `tools/setup.sh` (set `WC_PACK` if the tools are not in `<pack>/.wineconvert/tools`).
2. `tools/batch.sh 8`, then pack/defer the whole round before starting the next one. Never pack while a test round runs (it starves the games), and 16 slots were not faster.
3. Look at `work/reviewA.jpg` / `reviewB.jpg` + the per-slot summary, then per game:
   - works (renders, audio stream open, reaches menu/gameplay, reacts to some input): `tools/pack.sh "<game>" "<entry>" "<notes>"`
   - otherwise: try a cheap fix (see below) and rerun with `K=<slot> tools/next.sh "<game>"`, or `tools/defer.sh "<game>" "<reason / group>"`
4. Repeat until `next.sh` prints `ALL DONE`. Then work through `todo.tsv` by group.

Run long commands in the background and wait for completion; never poll with `pgrep -f` on a pattern that appears in your own command.
Don't edit `tools/run.sh` while slots are running.

## Rules from the user

- One game at a time on disk is not required any more, but never leave a `.wine` folder behind: pack or defer it.
- DOSBox, ScummVM and Win95-era games are not converted: move them to `<pack>/dontconvert/` (native remasters that only bundle a classic DOSBox version are converted). A PE header of Windows 4.00 alone does not make a game Win95-era.
- Use the GE-Proton runner from `~/code/windowsarcadeloader/wine-runners/` and DXVK by default. Try a game with no tricks first; add tricks to the prefix only when really needed.
- Check audio for every game (`streams:` / `audio:` lines); 32-bit games need the host lib32 packages.
- Video bugs that are GE-Proton bugs (winedmo / Media Foundation) are fixed in `~/code/protonge` on a new branch for an upstream PR, never worked around in the game.
- Keyboard/mouse-only games get a `<Game>.wsquashfs.keys` evmapy file next to the image (templates: `keyboard.keys`, `mouse.keys`).
- Keep token use low: review the small contact sheets, not full screenshots; filter logs.
- Commits: author `Alexandre Derumier <aderumier@gmail.com>`, no Co-Authored-By trailer.

## Prefix tricks

`tools/trick.sh "<game>" <verb>...` preps the game if needed and runs the runner's winetricks on the real `.wine` (kept in the image), e.g. `physx`, `openal`, `d3dcompiler_47`.

## Cheap fixes that worked (in the image, not the prefix)

- UE "Visual C++ Redistributable required" stub → `CMD` = `*/Binaries/Win64/*-Shipping.exe`.
- Launcher/config tool as gamelist entry → `CMD` = the real game exe.
- DXVK white/black screen → `ENV=WINEDLLOVERRIDES="winemenubuilder.exe=;d3d9=b"` (or the d3d dll the game uses) in `autorun.cmd`.
- Console-subsystem exe crashing on console calls, `.bat` entries, missing fonts, exe/data-folder name mismatch: see README "Fixes".
- Black screen with audio on a 32-bit (PE32) game, on DXVK and wined3d alike → `ENV=WINEARCH=wow64` in `autorun.cmd` (GE's old i386 path through host lib32 GL/Vulkan stays black; WoW64 renders). Check this first for the black group.
- Game exits/hangs on Steam (SteamAPI_Init failed, bundled Steam emulator, cracked steam_api 'No access to memory location') → `ENV=WINEDLLOVERRIDES="winemenubuilder.exe=;dxgi,d3d8,d3d9,d3d10core,d3d11,d3d12,d3d12core=n;nvapi64,nvapi=;lsteamclient=d"` (GE's Steam bridge; Proton sets the same without Steam). Fixed 12 games.
- Game needs the Steam client even with `lsteamclient=d` → Goldberg (gbe_fork, `~/.cache/wsquashfsconverter/gbe`): replace `steam_api(64).dll` (keep `.orig`), add `steam_appid.txt` and a `steam_interfaces.txt` listing the interface strings of the original dll (`strings | grep -E '^(Steam[A-Za-z]+[0-9]{3}|STEAM[A-Z_]+_VERSION[0-9]{3})$'`). Fixed Amabilly.
- SteamStub-wrapped exe ('Application load error S:...') → unwrap with Steamless CLI (`~/.cache/wsquashfsconverter/steamless`, run with the runner's wine; plugin dlls copied next to the exe for mono), keep `.orig`, then Goldberg as above and `CMD` = the unwrapped exe instead of any SmartSteamEmu launcher. Fixed VULKAISER.
- Bundled Java (JRE 17) dies with 'jimage file name is null' on GE: its path canonicalization fails on the test path (dot folder / overlay). Give the prefix a drive `dosdevices/w: -> ..` (pack.sh keeps `w:`) and start the game as `CMD="w:\game\<launcher>.exe"` (not at the drive root: the game needs a folder name). Fixed Cosmobreeder.
- Game crashes when a D3D9 shader fails ('E7002: Instruction "sincos" is not supported', Ogre.log) → wine's HLSL compiler; `tools/trick.sh "<game>" d3dx9_43 d3dcompiler_43` (native d3dx9 alone still uses the builtin compiler). Fixed Verisim Skies.
- Unity resolution dialog / "Full screen?" box at start → `.keys` with Start→KEY_ENTER.

## Comparing runners / prefixes

- `WC_RUNNER=<runner dir>` picks another runner for run.sh/fullscan.sh (vanilla wine, Kron4ek builds in `~/.cache/wsquashfsconverter/runners`).
- `FULL=1` runs on a copy of the windowsarcadeloader full prefix (`fullprefix/`), loader-like: isolated tricks builtin (`DSOUND=1` keeps native dsound, only for sound problems), pad re-enabled.
- `tools/fullscan.sh <list>` (OUT=file) scans a list in rounds of 8; `tools/desktop.sh "<game>"` shows a game on the real desktop for the user.

## Known open groups (todo.tsv)

WEBVIEW2 runtime, chromium-black (NW.js/Electron), black screen with audio, input ignored, VIDEO (MF `0xc00d36bb`),
TRICK (physx, openal, d3dcompiler_47), Steam DRM / cracks / Steam emulators / GDK (now allowed to work on).
