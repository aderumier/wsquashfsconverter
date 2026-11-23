# savedir.py <upper list> [<game dir>]: propose SAVEDIR / SAVEFILES from the files a test run created
# (work/upper<K>.txt written by run.sh: "<path relative to the prefix>\t<size>" per line).
# Prints "SAVEDIR=...", optional "SAVEFILES=...", then "# confidence <high|medium|low>: <reason>".
import os, re, sys

U = 'drive_c/users/steamuser/'
NOISE = re.compile(r'(^|/)(dxvk|vkd3d|D3DSCache|mesa_shader_cache|GPUCache|ShaderCache|shader_cache|mod\.io|GrShaderCache|Code Cache|'
                   r'Crashpad|CrashDumps|CrashReports?|Crashes|[^/]*Crash Reporter|sentry|NVIDIA|Microsoft|GOG\.com|StreamingAssets|CrashReportClient|winbackup|[0-9]+/stats|[^/]*_Data/Plugins|cache|Cache|logs?|Logs?|Temp|temp|'
                   r'Unity/[0-9a-f-]{36}|Analytics|webcache|EBWebView|nw[0-9_]+|\.cache)(/|$)')
NOISEFILE = re.compile(r'(__sentry[^/]*|logger-data[^/]*\.db|[a-z]*list[0-9]*\.txt|shader-error\.txt|[^/]*log\.(txt|html)|ds\.ini|[^/]*ShaderCache[^/]*|steam_appid\.txt|listen_port\.txt|achiev\.ini|ldb\.ini|CrashReportClient\.ini|vkd3d-proton\.cache.*|achievements\.(ini|json)|leaderboards\.ini|stats\.(ini|bin|json)|configs\.[a-z]+\.ini|account_name\.txt|user_steam_id\.txt|language\.txt|\.log|\.dmp|\.tmp|output_log\.txt|Player(-prev)?\.log|\.lock|LOCK|\.ldb|CURRENT|MANIFEST.*|LOG(\.old)?)$', re.I)
SAVELIKE = re.compile(r'(sav|save|slot|profile|progress|persistent|record|\.dat$|\.json$|\.bin$|remote/)', re.I)


def rel_root(path):
    """map a created file to the folder that should become SAVEDIR, with the rule that picked it"""
    p = path
    m = re.match(re.escape(U) + r'AppData/LocalLow/([^/]+)/([^/]+)/', p)
    if m:
        return U + f'AppData/LocalLow/{m.group(1)}/{m.group(2)}', 'unity'
    m = re.match(re.escape(U) + r'AppData/Roaming/Godot/app_userdata/([^/]+)/', p)
    if m:
        return U + f'AppData/Roaming/Godot/app_userdata/{m.group(1)}', 'godot'
    m = re.match(re.escape(U) + r'AppData/Local/([^/]+)/Saved/', p)
    if m:
        base = U + f'AppData/Local/{m.group(1)}/Saved'
        return (base + '/SaveGames' if '/Saved/SaveGames/' in p else base), 'unreal'
    m = re.match(re.escape(U) + r'AppData/Roaming/(GSE Saves|Goldberg SteamEmu Saves)/', p)
    if m:
        return U + f'AppData/Roaming/{m.group(1)}', 'steamemu'
    m = re.match(r'drive_c/users/Public/Documents/Steam/(RUNE|CODEX|OnlineFix|EMPRESS)/([^/]+)/', p)
    if m:
        return f'drive_c/users/Public/Documents/Steam/{m.group(1)}/{m.group(2)}', 'steamemu'
    m = re.match(re.escape(U) + r'Documents/([^/]+)/([0-9]+)/SteamEmu/', p)
    if m:
        return U + f'Documents/{m.group(1)}/{m.group(2)}', 'steamemu'
    m = re.match(r'(game/(?:.*/)?SteamEmu)/', p)
    if m:
        return m.group(1), 'steamemu'
    m = re.match(r'(game/(?:.*/)?Saved)/', p)
    if m:
        return m.group(1), 'unreal'
    m = re.match(re.escape(U) + r'(Documents/My Games|Documents/Saved Games|Saved Games|Documents)/([^/]+)/', p)
    if m:
        return U + f'{m.group(1)}/{m.group(2)}', 'documents'
    m = re.match(re.escape(U) + r'AppData/(Roaming|Local)/([^/]+)/', p)
    if m:
        return U + f'AppData/{m.group(1)}/{m.group(2)}', 'appdata'
    m = re.match(r'(game/(?:.*/)?)[^/]+$', p)
    if m:
        return m.group(1).rstrip('/'), 'gamedir'
    return None, None


def engine_fallback(wine):
    """nothing written during the run: the engine's standard save folder, from the game files"""
    import struct
    game = os.path.join(wine, 'game')
    files = []  # os.walk never follows symlinks (a stray dosdevices/z: -> / inside game/ loops a recursive glob)
    for dp, dns, fns in os.walk(game):
        files += [os.path.join(dp, f) for f in fns if f in ('data.win', 'app.info')]
    for w in [f for f in files if f.endswith('/data.win')]:  # GameMaker: %LOCALAPPDATA%/<GEN8 name>
        try:
            d = open(w, 'rb').read()
            o = d.find(b'GEN8') + 8
            q = struct.unpack_from('<I', d, o + 40)[0]
            n = d[q:q + struct.unpack_from('<I', d, q - 4)[0]].decode()
            if n and re.match(r'^[^/\\:*?"<>|]+$', n):
                return U + 'AppData/Local/' + n, 'GameMaker data.win name'
        except Exception:
            pass
    for a in [f for f in files if re.search(r'_Data/app\.info$', f)]:  # Unity: LocalLow/<company>/<product>
        parts = open(a, encoding='utf-8', errors='replace').read().split('\n')[:2]
        if len(parts) == 2 and all(parts):
            parts = [re.sub(r'\.$', '_', re.sub(r'[\\/:*?"<>|]', '_', x.strip())) for x in parts]
            return U + 'AppData/LocalLow/' + '/'.join(parts), 'Unity app.info'
    for dp, dns, _ in os.walk(game):  # a save folder shipped with the game (game/Save, game/Saves)
        if dp[len(game):].count('/') >= 3:
            dns[:] = []
            continue
        for dn in dns:
            if re.match(r'^save[sd]?(ata|games?)?$', dn, re.I):
                return os.path.relpath(os.path.join(dp, dn), wine), 'existing save folder in the game'
    return None


def main():
    lines = [l.rstrip('\n').split('\t')[0] for l in open(sys.argv[1], encoding='utf-8', errors='replace') if l.strip()]
    groups = {}
    for p in lines:
        if NOISE.search(p) or NOISEFILE.search(os.path.basename(p)) or p.endswith('desktop.ini'):
            continue
        root, rule = rel_root(p)
        if not root or (rule == 'gamedir' and re.match(r'(Error|stderr|stdout)\.txt$', os.path.basename(p), re.I)):
            continue  # console logs: noise in the game dir, but Nightdive/LRG games write them into their save folder
        g = groups.setdefault(root, {'rule': rule, 'files': [], 'score': 0})
        g['files'].append(p)
        g['score'] += 3 if SAVELIKE.search(p) else 1
    # many files dropped among game data (extracted levels, assets) are not saves
    for r in [r for r, g in groups.items() if g['rule'] == 'gamedir' and len(g['files']) > 6]:
        del groups[r]
    # a Unity folder that only got its Player.log still is the persistentDataPath
    if not groups:
        for p in lines:
            root, rule = rel_root(p)
            if rule in ('unity', 'godot', 'unreal'):
                print(f'SAVEDIR={root}')
                print(f'# confidence medium: {rule} data folder created (only logs so far)')
                return
        fb = engine_fallback(sys.argv[2]) if len(sys.argv) > 2 else None
        if fb:
            print(f'SAVEDIR={fb[0]}')
            print(f'# confidence medium: {fb[1]}')
            return
        for p in lines:
            root, rule = rel_root(p)
            if rule == 'steamemu' and not p.endswith('listen_port.txt') and '/settings/' not in p:
                print(f'SAVEDIR={root}')
                print('# confidence low: only the Steam emulator folder was written (cloud saves land there)')
                return
        print('# confidence none: no save-like file created')
        return
    pref = {'godot': 4, 'unreal': 4, 'unity': 3, 'documents': 3, 'appdata': 2, 'gamedir': 2, 'steamemu': 1}
    best = max(groups.items(), key=lambda kv: (kv[1]['score'] * 10 + pref[kv[1]['rule']]))
    root, g = best
    if g['rule'] == 'gamedir':
        # link a whole save-like ancestor (game/Profile/PLAYER/Stats -> game/Profile, game/Save/<id> -> game/Save)
        parts = root.split('/')
        for i in range(1, len(parts)):
            if re.search(r'^(save|saves|savegames?|savedata|profiles?|cloud|steamdata|userdata)$', parts[i], re.I):
                root = '/'.join(parts[:i + 1])
                break
    descend = 0
    # descend into a single publisher subfolder (Saved Games/Nightdive Studios/Blood EX)
    while True:
        subs = {f[len(root) + 1:].split('/')[0] for f in g['files'] if '/' in f[len(root) + 1:]}
        if g['rule'] not in ('documents', 'appdata') or len(subs) != 1 or any('/' not in f[len(root) + 1:] for f in g['files']) \
                or re.search(r'[0-9]{5}', next(iter(subs))) or descend:  # keep per-user id folders inside SAVEDIR; one level only
            break
        root = root + '/' + subs.pop()
        descend += 1
    print(f'SAVEDIR={root}')
    if g['rule'] == 'gamedir' and not re.search(r'sav|steamdata|userdata|cloud|profile', os.path.basename(root), re.I):
        names = sorted({p[len(root) + 1:] for p in g['files'] if p.startswith(root + '/') and '/' not in p[len(root) + 1:]})
        if names:
            print('SAVEFILES=' + ';'.join(names))
    conf = 'high' if g['score'] >= 3 and g['rule'] != 'steamemu' else 'medium'
    others = [r for r in groups if r != root]
    print(f"# confidence {conf}: {g['rule']}, {len(g['files'])} file(s): {', '.join(os.path.basename(f) for f in g['files'][:4])}"
          + (f" | also: {', '.join(others[:3])}" if others else ''))


main()
