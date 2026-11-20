#!/usr/bin/env python3
"""Select Slime Changer's existing local-save startup path (one known build)."""
import argparse
import hashlib
import json
import pathlib
import struct

ORIGINAL = "f1e9bbf256679ed4cbef24db70201df8b3a3386f354ff71e8fb65240f573295f"
PATCHED = "01fd08a337a70c9f78c23bce2958e23aecedacf52a7c5ec87cfb23a30af21775"
RVA = 0xA35B5D
OFFSET = 0xA3495D
BEFORE = bytes.fromhex("754f488b0d")
AFTER = b"\xe9" + struct.pack("<i", 0xA35F02 - RVA - 5)
PATCHES = [(OFFSET, BEFORE, AFTER),
           # SaveCoroutine.MoveNext only uploads cloud records. Local writes
           # occur separately in DataManager.bea, before cloud scheduling.
           (0x9F3750, bytes.fromhex("488bc4"), bytes.fromhex("31c0c3"))]
SEED = json.dumps({"Data": {"PlayerData": {
    "Value": json.dumps({"dataList": []})}}}) + "\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("dll", type=pathlib.Path)
    parser.add_argument("action", choices=["inspect", "patch", "restore"])
    parser.add_argument("--prefix", type=pathlib.Path,
                        help="On patch, seed missing local data in this Wine prefix")
    args = parser.parse_args()
    data = args.dll.read_bytes()
    digest = hashlib.sha256(data).hexdigest()
    if digest not in (ORIGINAL, PATCHED):
        raise SystemExit("Unsupported GameAssembly.dll SHA256: " + digest)
    print("patched" if digest == PATCHED else "original", digest)
    backup = args.dll.with_name(args.dll.name + ".orig")
    if args.action == "inspect":
        return
    if args.action == "restore":
        saved = backup.read_bytes()
        if hashlib.sha256(saved).hexdigest() != ORIGINAL:
            raise SystemExit("Backup SHA256 mismatch")
        args.dll.write_bytes(saved)
        return
    if digest == ORIGINAL and backup.exists():
        if backup.read_bytes() != data:
            raise SystemExit("Existing backup differs")
    elif digest == ORIGINAL:
        backup.write_bytes(data)
    if digest == ORIGINAL:
        result = bytearray(data)
        for offset, before, after in PATCHES:
            if data[offset:offset + len(before)] != before:
                raise SystemExit("Instruction mismatch")
            result[offset:offset + len(after)] = after
        if hashlib.sha256(result).hexdigest() != PATCHED:
            raise SystemExit("Patched SHA256 mismatch")
        args.dll.write_bytes(result)
    if args.prefix:
        # bdy/bdr/bdu create default player data from an empty collection.
        # The PlayerData key must exist for bea to persist subsequent changes.
        save = args.prefix / ("drive_c/users/steamuser/AppData/LocalLow/"
                              "DefaultCompany/Slime Changer/SlimeChanger.json")
        save.parent.mkdir(parents=True, exist_ok=True)
        if not save.exists():
            with save.open("x") as output:
                output.write(SEED)
            print("Seeded local data:", save)
    print("Selected local-save startup; preserved", backup)


if __name__ == "__main__":
    main()
