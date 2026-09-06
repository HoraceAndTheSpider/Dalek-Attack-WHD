#!/usr/bin/env python3
from pathlib import Path
from PIL import Image,ImageDraw
import sys, json, csv, math
BASE=0x17800
DESC_RT=0x1EDA6
LIST_RTS=[0x1F882,0x1F8A0,0x1F8B1,0x1F8C7,0x1F8DF]
BANK_OFFSETS=[0x13000,0x31800,0x4E200,0x6CC00,0x8C400]
DBG=[(0,0,0),(240,240,240),(240,40,40),(40,220,60),(50,80,240),(240,220,40),(230,60,230),(50,220,220),(120,120,120),(240,140,30),(140,240,40),(30,140,240),(140,40,240),(240,140,140),(140,240,240),(200,200,200)]

def descriptors(d1):
    o=BASE+DESC_RT; out=[]
    for i in range(80):
        r=d1[o+i*22:o+(i+1)*22]
        if len(r)<22: break
        words=[int.from_bytes(r[j:j+2],'big') for j in range(0,22,2)]
        out.append({'id':i,'width':words[0],'height':words[1],'frames':words[2],'plane_bytes':words[3],
                    'flags':words[8],'param1':words[9],'param2':words[10]})
    return out

def lists(d1):
    out=[]
    for rt in LIST_RTS:
        p=BASE+rt; a=[]
        while d1[p]!=0xff: a.append(d1[p]);p+=1
        out.append(a)
    return out

def decode_frame(data,w,h):
    wb=w//8; need=wb*h*4
    if len(data)<need: raise ValueError((len(data),need))
    im=Image.new('P',(w,h),0); pix=im.load(); off=0
    for y in range(h):
        planes=[data[off+p*wb:off+(p+1)*wb] for p in range(4)]; off+=wb*4
        for x in range(w):
            bi=x>>3; bit=7-(x&7)
            pix[x,y]=sum(((planes[p][bi]>>bit)&1)<<p for p in range(4))
    pal=[]
    for c in DBG: pal.extend(c)
    pal += [0]*(768-len(pal)); im.putpalette(pal)
    return im

def split_bank(bank, descs, ids):
    p=0; out=[]
    for idx in ids:
        d=descs[idx]; sz=d['plane_bytes']*4
        frames=[]
        for f in range(d['frames']):
            raw=bank[p:p+sz]; p+=sz
            frames.append(raw)
        out.append((idx,d,frames))
    if p!=len(bank): raise ValueError(f'bank consumed {p}, size {len(bank)}')
    return out

def contact(bank_no, chunks, outpath, scale=2):
    # one row per descriptor, frames laid horizontally, wrap if needed
    maxw=1200//scale
    sections=[]; totalh=0
    for idx,d,frames in chunks:
        fw=d['width']; fh=d['height']; labelw=90//scale; gap=2
        cols=max(1,(maxw-labelw)//(fw+gap)); rows=math.ceil(len(frames)/cols)
        sh=max(fh*rows + 16//scale, 24//scale)
        sections.append((idx,d,frames,cols,sh)); totalh+=sh+gap
    im=Image.new('RGB',(maxw,totalh),(20,20,20)); dr=ImageDraw.Draw(im); y=0
    for idx,d,frames,cols,sh in sections:
        dr.text((2,y+2),f'{idx:02d} {d["width"]}x{d["height"]} x{d["frames"]}',fill=(255,255,255))
        x0=90//scale
        yy=y+2
        for f,raw in enumerate(frames):
            row=f//cols; col=f%cols
            spr=decode_frame(raw,d['width'],d['height']).convert('RGB')
            im.paste(spr,(x0+col*(d['width']+2),yy+row*d['height']))
        y+=sh+2
    if scale!=1: im=im.resize((im.width*scale,im.height*scale),Image.Resampling.NEAREST)
    im.save(outpath)

def main(outdir='/mnt/data/dalek_attack_extract'):
    out=Path(outdir); out.mkdir(exist_ok=True)
    d1=Path('/mnt/data/Disk.1').read_bytes(); d2=Path('/mnt/data/Disk.2').read_bytes()
    sys.path.insert(0,'/mnt/data'); from dalek_unice32 import depack
    descs=descriptors(d1); ids_by=lists(d1)
    manifest=[]
    for n,(off,ids) in enumerate(zip(BANK_OFFSETS,ids_by),1):
        p=int.from_bytes(d2[off+4:off+8],'big'); bank=depack(d2[off:off+p])
        chunks=split_bank(bank,descs,ids)
        contact(n,chunks,out/f'SPRITES{n}_descriptor_atlas.png',scale=2)
        bd=out/f'SPRITES{n}_frames'; bd.mkdir(exist_ok=True)
        pos=0
        for idx,d,frames in chunks:
            sz=d['plane_bytes']*4
            dd=bd/f'desc_{idx:02d}_{d["width"]}x{d["height"]}_x{d["frames"]}'; dd.mkdir(exist_ok=True)
            for fi,raw in enumerate(frames):
                decode_frame(raw,d['width'],d['height']).save(dd/f'frame_{fi:02d}.png')
            manifest.append({'bank':n,'disk_offset':hex(off),'descriptor':idx,'width':d['width'],'height':d['height'],'frames':d['frames'],'frame_bytes':sz,'bank_data_offset':hex(pos),'flags':hex(d['flags']),'param1':hex(d['param1']),'param2':hex(d['param2'])})
            pos+=sz*d['frames']
    with open(out/'sprite_manifest.csv','w',newline='') as f:
        w=csv.DictWriter(f,fieldnames=manifest[0].keys());w.writeheader();w.writerows(manifest)
    with open(out/'descriptor_table.json','w') as f:json.dump(descs,f,indent=2)
    print('wrote',len(manifest),'descriptor-bank entries')
if __name__=='__main__': main(sys.argv[1] if len(sys.argv)>1 else '/mnt/data/dalek_attack_extract')
