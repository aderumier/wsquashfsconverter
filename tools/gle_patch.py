# gle_patch.py <exe> [patch]: find "CreateWindowExW; GetLastError; test eax,eax; jne" (game treats a stale last error as failure: window never shown, render size 0x0) and NOP the jne. Keep a .orig copy first.
import struct, sys
f=sys.argv[1]; d=bytearray(open(f,'rb').read())
pe=struct.unpack_from('<I',d,0x3c)[0]; n=struct.unpack_from('<H',d,pe+6)[0]; opt=struct.unpack_from('<H',d,pe+20)[0]
base=struct.unpack_from('<Q',d,pe+24+24)[0]; sec=pe+24+opt
secs=[struct.unpack_from('<IIII',d,sec+i*40+8) for i in range(n)]
def r2o(r):
    for vs,va,rs,rp in secs:
        if va<=r<va+max(vs,rs): return rp+r-va
imp_rva=struct.unpack_from('<I',d,pe+24+0x78)[0]
iat={}
o=r2o(imp_rva)
while True:
    oft,ts,fc,nm,ft=struct.unpack_from('<IIIII',d,o)
    if nm==0: break
    t=r2o(oft or ft); k=0
    while True:
        v=struct.unpack_from('<Q',d,t+8*k)[0]
        if v==0: break
        if not v>>63:
            name=d[r2o(v)+2:r2o(v)+40].split(b'\0')[0].decode()
            iat[name]=ft+8*k
        k+=1
    o+=20
gle=iat['GetLastError']; cw=iat['CreateWindowExW']
hits=[]
for vs,va,rs,rp in secs:
    for i in range(rp, rp+rs-6):
        if d[i]==0xff and d[i+1]==0x15:
            rip=va+(i-rp)+6; tgt=rip+struct.unpack_from('<i',d,i+2)[0]
            if tgt==cw:
                # look ahead 40 bytes for call GetLastError; test eax,eax; jne short
                for j in range(i+6,i+48):
                    if d[j]==0xff and d[j+1]==0x15:
                        rip2=va+(j-rp)+6; t2=rip2+struct.unpack_from('<i',d,j+2)[0]
                        if t2==gle and d[j+6:j+8]==b'\x85\xc0' and d[j+8]==0x75:
                            hits.append(j+8)
print('hits', [hex(h) for h in hits])
if len(sys.argv)>2 and sys.argv[2]=='patch' and len(hits)==1:
    d[hits[0]:hits[0]+2]=b'\x90\x90'; open(f,'wb').write(d); print('patched')
