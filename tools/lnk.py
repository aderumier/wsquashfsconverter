import struct, sys
def parse(path):
    d = open(path,'rb').read()
    flags = struct.unpack_from('<I', d, 20)[0]
    off = 76
    if flags & 1:
        off += 2 + struct.unpack_from('<H', d, off)[0]
    base = None
    if flags & 2:
        size, hsize, liflags, vidoff, lbpoff = struct.unpack_from('<IIIII', d, off)[:5]
        if liflags & 1:
            e = d.index(b'\0', off+lbpoff); base = d[off+lbpoff:e].decode('cp1252')
            if hsize >= 0x24:
                uo = struct.unpack_from('<I', d, off+28)[0]
                e = off+uo
                while d[e:e+2] != b'\0\0': e += 2
                base = d[off+uo:e].decode('utf-16le')
        off += size
    uni = flags & 0x80
    out = {'target': base}
    for bit, name in ((4,'name'),(8,'relpath'),(0x10,'workdir'),(0x20,'args'),(0x40,'icon')):
        if flags & bit:
            n = struct.unpack_from('<H', d, off)[0]; off += 2
            if uni: s = d[off:off+2*n].decode('utf-16le'); off += 2*n
            else: s = d[off:off+n].decode('cp1252'); off += n
            out[name] = s
    return out
if __name__ == '__main__':
    for k, v in parse(sys.argv[1]).items(): print(f"{k}={v or ''}")
