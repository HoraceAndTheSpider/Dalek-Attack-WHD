from pathlib import Path
from PIL import Image,ImageDraw
import sys,math
DBG=[(0,0,0),(255,255,255),(255,0,0),(0,255,0),(0,0,255),(255,255,0),(255,0,255),(0,255,255),(128,128,128),(255,128,0),(128,255,0),(0,128,255),(128,0,255),(255,128,128),(128,255,255),(220,220,220)]
pal=sum((list(c) for c in DBG),[])+[0]*(768-48)
def tile(raw):
 im=Image.new('P',(16,16)); im.putpalette(pal); px=im.load();o=0
 for y in range(16):
  ws=[int.from_bytes(raw[o+p*2:o+p*2+2],'big') for p in range(4)];o+=8
  for x in range(16):px[x,y]=sum(((ws[p]>>(15-x))&1)<<p for p in range(4))
 return im.convert('RGB')
for n in range(1,6):
 d=Path(f'/mnt/data/dalek_attack_extract/blocks/BLOCK00{n}.bin').read_bytes()[64:]
 assert len(d)==1080*128
 sheet=Image.new('RGB',(40*16,27*16),(0,0,0))
 for i in range(1080): sheet.paste(tile(d[i*128:(i+1)*128]),((i%40)*16,(i//40)*16))
 sheet=sheet.resize((sheet.width*2,sheet.height*2),Image.Resampling.NEAREST)
 sheet.save(f'/mnt/data/dalek_attack_extract/blocks/BLOCK00{n}_tiles_guess.png')
