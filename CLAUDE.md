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
- 'Error compiling shaders' box on a D3D12 game (Mechstermination Force) → the prefix had wine's builtin `d3dcompiler_47`; `tools/trick.sh "<game>" d3dcompiler_47` and check `user.reg` has `"*d3dcompiler_47"="native"`.
- 'unimplemented function msvcp140_atomic_wait.dll.__std_atomic_wait_get_deadline' → winetricks vcrun2022 fails on GE (vc_redist status 2); `cabextract` the x64/x86 dll from `~/.cache/winetricks/vcrun2022/vc_redist.*.exe` (cabs a11/a12) into system32/syswow64 (the override is already native,builtin). Fixed Cannonball DX.
- SDL 'Could not initialize OpenGL / GLES library' on a game without ANGLE dlls → add `libEGL.dll` + `libGLESv2.dll` (+ their `zlib1.dll`) to `game/` (copy from Cannonball DX). Fixed Moon Child FE.
- Old Ageia PhysX 2.x game ('Ageia PhysX failed') when winetricks physx isn't enough → install the PhysX System Software the game ships (`Support/PhysX/*.exe /s /v"/qn"` with the runner's wine on the real prefix). Fixed Lost Via Domus.
- 32-bit DirectDraw game with a gray window → `ENV=WINEARCH=wow64`; if a mod loader (JJ2+) is in the way, `CMD` = the unmodded exe. Fixed Jazz Jackrabbit 2.
- SDL game ignoring the pad because its config has the buttons at -1 → `.keys` mapping the pad to its keyboard keys (Cannonball DX).
- Console exe failing on console calls without a tty ('Incorrect access to Shell-no-window console', .NET Console.set_Title IOException 'Invalid access') → `CMD=start /wait <exe>` gives it a real console. Fixed Absolum.
- D3D9 effects fail ('no effect compiler', 'E5033: Unknown target profile fx_2_0', black/solid 3D with HUD drawn) → native compiler matching the game's d3dx9 (`trick.sh "<game>" d3dcompiler_42` for d3dx9_42). Fixed Rigid Force Alpha.
- Unity game 'black' headless but fine for the user: check `magick ... -auto-level` before calling it black (very dark first screens). Bloodecay.
- Wrong gamelist entry (level editor, mod menu) → `CMD` = the real game exe (Mayhem Triple: Mayhem3Steam.exe).
- Game aborting in win32u 'alloc_user_handle: Assertion index < MAX_USER_HANDLES' → find the leaked user object type with `WINEDEBUG=+server` (alloc_user_handle type); TriggerHeart's LoadAccelerators leak is fixed in protonge branch user32-loadaccelerators-cache.
- Xbox GDK build (MicrosoftGame.config, gamelaunchhelper.exe) shipping a GDK emulator (`ms_emu.json` + proxy `winmm.dll`, maybe `xgameruntime.dll`) → `ENV=...;winmm,xgameruntime=n,b` so the proxy loads instead of wine's builtin winmm. Any proxy dll next to the exe needs `=n,b` (TENOKE crack loader = `version.dll`: DAVE THE DIVER needed `version=n,b`). Fixed MIO, REPLACED, DAVE THE DIVER.
- Config-file fixes keep paths relative to the game folder (Dusk `backend.isoPath`, Simpsons `--game_data_root=gamedata`); N64Recomp ports want the ROM as `AppData/Local/<Game>Recompiled/<id>.z64` (byteswap .v64 with `dd conv=swab`).
- Black screen with audio and an invisible (unmapped) window, even on the desktop: check for `CreateWindowExW` followed by `if (GetLastError()==0)` (wine leaves a stale last error, so ShowWindow and the render size are skipped -> 0x0 viewport). `tools/gle_patch.py <exe> patch` (keep `.orig`) NOPs the jne. Fixed Mechstermination Force and Super Punch Patrol (Hugecalf Skrot engine; also black on some Windows setups).
- Debugging live: GE relocates exes (base from `WINEDEBUG=+loaddll` 'Loaded ... at'), so rebase static addresses before gdb breakpoints; gdb attach needs `kernel.yama.ptrace_scope=0`.
- Game crashes on COM from a worker thread that never called CoInitialize ('apartment not initialised', null deref): Windows usually has an implicit MTA, wine doesn't. Drop `tools/mta_proxy/SensApi.dll` (or rebuild the source as another small dll the exe imports) into `game/` with `ENV=...;sensapi=n`: it keeps an MTA thread alive. Fixed Arcade Classics.
- 32-bit D3D9 game crashing on a null COM call at vtbl+0x11c (ID3DXEffect) → effect compile failed in builtin d3dx9: `trick.sh "<game>" d3dx9 d3dcompiler_43 d3dcompiler_47`. Fixed Ms. Splosion Man.
- Unity IL2CPP exception in game code: rea `inspect_il2cpp_metadata` (with GameAssembly.dll) maps method names <-> addresses; objdump the method (Ghidra times out on 50 MB GameAssembly) and read the live values with gdb (rebased). Bye Sweet Carole: AC default language -1 -> patched GenerateDefaultOptionsData to English (keep `.orig`).
- Defold game exiting with code 1 and no output: release builds keep their log silent; read it with gdb on the engine's dmLog (format string in r8, first arg in r9). Tameshi: 'Could not find gl function glGenPrograms' (Mesa core profile lacks ARB_vertex_program) -> `ENV=MESA_GL_VERSION_OVERRIDE=4.6COMPAT ...`.
- Another session may run its own headless gamescope (windowsarcadeloader tests): if a slot's screenshots show a foreign game, its display number collides; rerun in another slot.
- Game quitting cleanly (exit 0) at a frame/scene change with no error: relay-trace the quit (`RelayInclude` user32.PostQuitMessage/DestroyWindow, then a full +relay of the last calls before it) instead of guessing. HORGIHUGH (Clickteam): GetPrivateProfileStringA("", "disk") on data/hugh.ini returned nothing because wine never reads an explicit '[]' section (protonge branch kernel32-profile-empty-section); workaround: delete the '[]' line so the keys come before any header (keep `.orig`).
- Chromium-based game (NW.js, Electron, CEF, WebView2) black and silent on GE: DirectWrite lost Tahoma (win32u deletes the Fonts keys of fonts in C:\windows\Fonts, upstream wine 5ba6d469, GE PR #987) and Chromium recurses for its default font until the browser overflows its stack (thousands of `uisettings2_get_TextScaleFactor` fixmes + "stack overflow"). `tools/trick.sh "<game>" corefonts tahoma` (corefonts alone has no Tahoma). Fixed 9 games.
- Then still black with audio, log `eglCreateWindowSurface ... EGL_BAD_ALLOC` / ANGLE `SwapChain11::reset ... 0x80004001`: append `--disable-gpu` to CMD (NW.js) or `ENV=... WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS=--disable-gpu` (older Construct WebView2 wrappers). Fixed Cyber mission, Dreaming Sarah, Resurrection of Mind, Awita, Codename Black Crow, DaemonClaw, Dragon Blazers.
- Old NW.js (2018, `natives_blob.bin`) too slow with --disable-gpu: replace the runtime with official NW.js 0.94.0 win-x64 (old files to `game/_nw_orig/`, keep package.nw); native node modules built for the old NW.js then fail to load ("Module not found ...node") and halt the game: wrap their `require` in package.nw in try/catch with a stub (`package.nw.orig` kept). Read page errors with CMD `--enable-logging=stderr --v=0` (CONSOLE lines). Fixed Maytroid (GPU on).
- WebView2 app showing "requires the Microsoft Edge WebView2 runtime" although tools/webview2.sh ran (newest Construct wrapper, loader built into the exe, ignores the WEBVIEW2_* env): runtime in `C:\Program Files (x86)\Microsoft\EdgeWebView\Application\<ver>` + HKLM (both views) `EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}` pv=<ver> and `EdgeUpdate\ClientState\{F3017226-...}` EBWebView=<version folder>; GPU on. Construct wrappers pass `chromium-args` from game/package.json (add `--enable-logging --v=0` for chrome_debug.log). Fixed PizzaBoy.
- Electron + steamworks.js 'No SteamClient021' with a Goldberg ColdClientLoader: `lsteamclient=d` in ENV. Project X: online leaderboard JSON with empty rows -> patched `JSON.parse(data_string)` in menu.js/arcade_nebula_new.js (.orig kept).
- `EXTRAENV='WINEDLLOVERRIDES=...'` to run.sh is overwritten by run.sh: test DLL overrides through the autorun `ENV=` line and check with +loaddll.
- Pack without gamelist.xml: `python3 -I tools/mkgamelist.py <pack> > <pack>/gamelist.xml` picks each folder's game exe (skips installers/redists/crash handlers/helpers, prefers the folder-name match near the top, UE stub before -Shipping) and prints OK/CHECK picks to stderr; review the CHECK lines (collections: prefer the launcher, e.g. dmcLauncher.exe) before setup.sh. Run listgames.py with `WC_PACK=<pack>` (it defaults to pack4).
- next.sh skips entries whose path contains "crash" (meant for crash handlers): a game like "Castle Crashers" gets PREP FAILED; prep it by hand with prep.sh.
- GOG builds whose steam_api64.dll is "GalaxySteamWrapper" (Galaxy64.dll next to it): '[GalaxySteamWrapper] Authentication failed' then a null deref in Galaxy64.dll. Replace steam_api64.dll with Goldberg regular x64 (keep .orig, steam_interfaces.txt from the wrapper strings, steam_appid.txt 480) + lsteamclient=d. Fixed Atari 50.
- GOG builds shipping their own ddraw.dll/dinput.dll (dxcfg.ini): 'error from DirectDraw (80004001)' until `ENV=WINEARCH=wow64 WINEDLLOVERRIDES="...;ddraw,dinput=n,b"`. Fixed Dino Crisis.
- Steam crack with Goldberg + SteamAPICheckBypass on a SteamStub exe whose anti-tamper smashes its own stack frame (__fastfail 2, then garbage return): unpacking with Steamless and skipping the cookie check do not help (Gal Guardians, deferred).
- Unity resolution dialog / "Full screen?" box at start → `.keys` with Start→KEY_ENTER.

- Slime Changer: inspect shipped `*_BackUpThisFolder_ButDontShipItWithYourGame/il2cppOutput/` before decompiling; this build includes generated C++ and PDBs. Runtime loads Steam, not the bundled STOVE SDKs. Startup blocks on PlayFab login/hash verification. `python3 tools/slime_local_patch.py "<prefix>/game/GameAssembly.dll" patch --prefix "<prefix>"` selects the existing local-save path and disables the cloud-upload coroutine (exact build hashes, `.orig` preserved). Seed missing SlimeChanger.json with a GetUserDataResult containing `Data.PlayerData.Value` = serialized `{"dataList":[]}`; an empty Data dictionary initializes gameplay but cannot persist changes. Existing saves are preserved. Local saving remains in DataManager.bea.

## Comparing runners / prefixes

- `WC_RUNNER=<runner dir>` picks another runner for run.sh/fullscan.sh (vanilla wine, Kron4ek builds in `~/.cache/wsquashfsconverter/runners`).
- `FULL=1` runs on a copy of the windowsarcadeloader full prefix (`fullprefix/`), loader-like: isolated tricks builtin (`DSOUND=1` keeps native dsound, only for sound problems), pad re-enabled.
- A vanilla runner updates the prefix first (30 s+): run it 150 s. D3D12 games only run on vkd3d-proton (GE).
- `tools/bisect.sh` bisects the wine-staging patch sets against a game that works on vanilla (found `dcomp-DCompositionCreateDevice2` for the Chromium games; GE has a second Proton-side cause, no Chromium GPU process).
- Use a separate prefix made with the other runner for runner comparisons (WC_RUNNER on the GE prefix makes it update/downgrade the prefix and the result is meaningless): `X=$(tools/runnerpfx.sh "<game>" <runner>)`, then `WC_RUNNER=<runner> WC_WINEPFX="$X" tools/run.sh "<game>" ...` (also desktop.sh). Delete `.wineconvert/rp/` after.
- Input: when the pad doesn't move a screen, run `tools/in_kbd.txt` (Enter, Space, Z/X/C, 5, 1, S, A, Esc, arrows) before asking the user.
- `tools/fullscan.sh <list>` (OUT=file) scans a list in rounds of 8; `tools/desktop.sh "<game>"` shows a game on the real desktop for the user.

## Known open groups (todo.tsv)

- Scott Pilgrim follow-up (2026-11-20): native dbdata/voices38 overrides still fail on GE11-12. First observed AV is in Scott.exe RVA0xd6e2ff6 writing to unmapped address0x1307f8; recursive RtlVirtualUnwind2 failures follow. Independent Wine11.22-staging instead faults in ntdll heap_allocate_block+0x746 writing into read-only Scott.exe data. No game or Wine binary patch; deferred for further protected-executable analysis. Evidence in pack4/.wineconvert/work/handoff-slime-scott/. Further compatibility checks: WDEBUG=-all still exits at5s, silent/no screenshots, both with ntsync and with WINEESYNC=0 WINEFSYNC=0 PROTON_NO_NTSYNC=1. Quiet logs do not identify the final exception; this only rules out those settings as sufficient fixes. Static disassembly saved as scott-*.asm, indexed in scott-disassembly-index.json: fault bytes 4c8917 = mov [rdi],r10; fault and reported return RVA0x1160d407 have no covering PE exception-table entry. On-disk analysis does not establish why RDI is invalid.

Chromium/WebView2 groups solved 2026-11-22 (see above); black screen with audio, input ignored, VIDEO (MF `0xc00d36bb`),
TRICK (physx, openal, d3dcompiler_47), Steam DRM / cracks / Steam emulators / GDK (now allowed to work on).
