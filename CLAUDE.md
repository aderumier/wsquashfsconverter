# Instructions for Claude Code

This repo converts a batocera Windows game pack (one folder per game + `gamelist.xml`) into
`<Game>.wsquashfs` images (GE-Proton prefix + `game/` + `autorun.cmd`), testing every game first.
Read `README.md` for the tools; this file holds the working rules.

## Workflow

1. `tools/setup.sh` (set `WC_PACK` if the tools are not in `<pack>/.wineconvert/tools`).
2. `tools/batch.sh 16` (fewer slots if RAM < 32 GB; check `free -g` after a round).
3. Look at `work/reviewA.jpg` / `reviewB.jpg` + the per-slot summary, then per game:
   - works (renders, audio stream open, reaches menu/gameplay, reacts to some input): `tools/pack.sh "<game>" "<entry>" "<notes>"`
   - otherwise: try a cheap fix (see below) and rerun with `K=<slot> tools/next.sh "<game>"`, or `tools/defer.sh "<game>" "<reason / group>"`
4. Repeat until `next.sh` prints `ALL DONE`. Then work through `todo.tsv` by group.

Run long commands in the background and wait for completion; never poll with `pgrep -f` on a pattern that appears in your own command.
Don't edit `tools/run.sh` while slots are running.

## Rules from the user

- One game at a time on disk is not required any more, but never leave a `.wine` folder behind: pack or defer it.
- DOSBox and ScummVM games are not converted: move them to `<pack>/dontconvert/` (native remasters that only bundle a classic DOSBox version are converted).
- Use the GE-Proton runner from `~/code/windowsarcadeloader/wine-runners/` and DXVK by default. Try a game with no tricks first; add tricks to the prefix only when really needed.
- Check audio for every game (`streams:` / `audio:` lines); 32-bit games need the host lib32 packages.
- Video bugs that are GE-Proton bugs (winedmo / Media Foundation) are fixed in `~/code/protonge` on a new branch for an upstream PR, never worked around in the game.
- Keyboard/mouse-only games get a `<Game>.wsquashfs.keys` evmapy file next to the image (templates: `keyboard.keys`, `mouse.keys`).
- Keep token use low: review the small contact sheets, not full screenshots; filter logs.
- Don't bypass DRM: games that need the Steam client, ship cracks/Steam emulators that fail, or are Xbox GDK builds are deferred with a note, not patched.
- Commits: author `Alexandre Derumier <aderumier@gmail.com>`, no Co-Authored-By trailer.

## Cheap fixes that worked (in the image, not the prefix)

- UE "Visual C++ Redistributable required" stub → `CMD` = `*/Binaries/Win64/*-Shipping.exe`.
- Launcher/config tool as gamelist entry → `CMD` = the real game exe.
- DXVK white/black screen → `ENV=WINEDLLOVERRIDES="winemenubuilder.exe=;d3d9=b"` (or the d3d dll the game uses) in `autorun.cmd`.
- Console-subsystem exe crashing on console calls, `.bat` entries, missing fonts, exe/data-folder name mismatch: see README "Fixes".
- Unity resolution dialog / "Full screen?" box at start → `.keys` with Start→KEY_ENTER.

## Known open groups (todo.tsv)

WEBVIEW2 runtime, chromium-black (NW.js/Electron), black screen with audio, input ignored, VIDEO (MF `0xc00d36bb`),
TRICK (physx, openal, d3dcompiler_47), Steam DRM / cracks / GDK (leave alone).
