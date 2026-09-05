#!/usr/bin/env python3
"""Pack-Ice ('Ice!') decoder for Dalek Attack resource investigation.

Implements the 32-bit backward bit-reader form used by the game's embedded
68000 depacker. Input is an Ice container: magic, packed size, unpacked size.
"""
from __future__ import annotations
import struct, sys

LEN_EXTRA = [9,1,0,-1,-1]
LEN_BASE  = [8,4,2,1,0]
DIST_EXTRA = [11,4,7]
DIST_BASE = [0x120,0,0x20]
LIT_TABLE = [
    (1,0x0003,1),   # n is DBRA value => reads n+1 bits
    (1,0x0003,4),
    (2,0x0007,7),
    (7,0x00ff,14),
    (14,0x7fff,269),
]

class IceError(Exception): pass

class Decoder:
    def __init__(self, src: bytes, packed_size: int, out_size: int):
        self.src=src
        self.a5=packed_size
        self.d7=0
        self.out=bytearray(out_size)
        self.wpos=out_size
        self.out_size=out_size

    def read_byte_back(self):
        self.a5-=1
        if self.a5<0: raise IceError('source underrun')
        return self.src[self.a5]

    def prime(self):
        if self.a5<4: raise IceError('source underrun at prime')
        self.a5-=4
        self.d7=int.from_bytes(self.src[self.a5:self.a5+4],'big')

    def bit(self):
        shifted=self.d7<<1
        b=(shifted>>32)&1
        self.d7=shifted & 0xffffffff
        if self.d7==0:
            if self.a5<4: raise IceError('source underrun on bit refill')
            self.a5-=4
            nw=int.from_bytes(self.src[self.a5:self.a5+4],'big')
            b=(nw>>31)&1
            self.d7=((nw<<1)|1)&0xffffffff
        return b

    def bits(self, dbra_n):
        # original routine gets DBRA count, hence dbra_n+1 bits
        v=0
        for _ in range(dbra_n+1): v=(v<<1)|self.bit()
        return v

    def write(self,v):
        if self.wpos<=0: raise IceError('output overflow')
        self.wpos-=1; self.out[self.wpos]=v&255

    def literal_extra(self):
        for n,target,add in LIT_TABLE:
            v=self.bits(n)
            if v!=target: return v+add
        return v+LIT_TABLE[-1][2]

    def unary(self,start,count):
        d=start
        for _ in range(count):
            if self.bit()==0: return d
            d-=1
        return d

    def match_code(self):
        d2=self.unary(3,4)
        idx=d2+1
        ex=LEN_EXTRA[idx]
        v=self.bits(ex) if ex>=0 else 0
        return LEN_BASE[idx]+v

    def distance(self):
        d2=self.unary(1,2)
        idx=d2+1
        return self.bits(DIST_EXTRA[idx])+DIST_BASE[idx]

    def reduced_distance(self):
        if self.bit()==0: return self.bits(5)
        return self.bits(8)+0x40

    def scatter(self, groups):
        # 4 packed words -> 4 bitplane words, walking backward in place.
        a3=self.out_size
        for _ in range(groups):
            regs=[0,0,0,0]
            for _ in range(4):
                a3-=2
                if a3<0: raise IceError('picture scatter underrun')
                w=(self.out[a3]<<8)|self.out[a3+1]
                for r in range(4):
                    regs[r]=((regs[r]<<1)|((w>>15)&1))&0xffff
                    w=(w<<1)&0xffff
            p=a3
            for w in regs:
                self.out[p:p+2]=w.to_bytes(2,'big'); p+=2

    def run(self, picture_mode='auto'):
        self.prime()
        while True:
            first=self.bit()
            lit=None
            if first:
                lit=0 if self.bit()==0 else self.literal_extra()
            if lit is not None:
                for _ in range(lit+1): self.write(self.read_byte_back())
                if self.wpos<=0: break
            d4=self.match_code()
            dist=self.reduced_distance() if d4==0 else self.distance()
            mlen=d4+2
            spos=self.wpos+2+d4+dist
            for _ in range(mlen):
                if spos>self.out_size: raise IceError(f'match source out of range {spos}>{self.out_size}')
                spos-=1
                self.write(self.out[spos] if spos<self.out_size else 0)
            if self.wpos<=0: break
        # Old Ice has an optional picture bit-transpose signalled after the data.
        # It uses 0x0f9f+1 groups unless an explicit 16-bit DBRA count follows.
        if picture_mode!='never':
            flag=self.bit()
            if flag:
                groups=0x0fa0
                if self.bit(): groups=self.bits(15)+1
                if groups*8>self.out_size:
                    if picture_mode=='force': raise IceError(f'picture scatter count {groups} too large')
                else:
                    self.scatter(groups)
        return bytes(self.out)

def depack(blob: bytes, picture_mode='auto'):
    if len(blob)<12 or blob[:4] not in (b'Ice!',b'ICE!'):
        raise IceError('not an Ice container')
    p=int.from_bytes(blob[4:8],'big'); q=int.from_bytes(blob[8:12],'big')
    if p<12 or p>len(blob): raise IceError(f'bad packed size {p} for blob {len(blob)}')
    return Decoder(blob[:p],p,q).run(picture_mode)

def main(argv):
    if len(argv)!=3:
        print('usage: dalek_unice32.py input output',file=sys.stderr); return 2
    data=open(argv[1],'rb').read(); out=depack(data)
    open(argv[2],'wb').write(out); print(len(out)); return 0
if __name__=='__main__': raise SystemExit(main(sys.argv))
