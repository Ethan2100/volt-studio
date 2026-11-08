# Makes self-contained, recolored .glb files for THE NIGHTSHIFT out of the Kenney kits (CC0).
import json, struct, io, colorsys, os, sys
from PIL import Image
P='/home/claude/packs/'
OUT='/home/claude/work/game/models/'
MOD=P+'kenney_modular-space-kit_1.0/Models/GLB format/'
STA=P+'kenney_space-station-kit/Models/GLB format/'
CHR=P+'kenney_blocky-characters_20/Models/GLB format/'

def kit_recolor(im):
    """Nightshift look: concrete grey walls, lavender floors, warning-amber stripes."""
    im=im.convert('RGBA'); px=im.load(); w,h=im.size
    for y in range(h):
        for x in range(w):
            r,g,b,a=px[x,y]
            if a==0 or (r,g,b)==(0,0,0): continue
            hh,s,v=colorsys.rgb_to_hsv(r/255,g/255,b/255)
            deg=hh*360
            if 10<=deg<=50 and s>0.45:            # orange/yellow -> amber, a little dim
                hh,s,v=48/360,0.85,v*0.42
            elif v>0.80 and s<0.35:               # the near-white wall paint -> concrete
                hh,s,v=212/360,0.12,0.30+(v-0.8)*0.6
            elif 200<=deg<=290:                   # blue/lavender -> darker lavender
                s,v=s*0.55,v*0.36
            else:
                s,v=s*0.7,v*0.6
            r,g,b=colorsys.hsv_to_rgb(hh,min(1,s),min(1,v))
            px[x,y]=(int(r*255),int(g*255),int(b*255),a)
    return im

def hunter_recolor(im):
    """Black monster: everything near black, only the light pixels (eyes, teeth) glow red."""
    im=im.convert('RGBA'); px=im.load(); w,h=im.size
    for y in range(h):
        for x in range(w):
            r,g,b,a=px[x,y]
            if a==0: continue
            l=(0.3*r+0.59*g+0.11*b)/255
            if l>0.82: px[x,y]=(255,255,255,a)
            else:
                k=0.05+l*0.13
                px[x,y]=(int(k*255),int(k*255),int(k*262)%256 if k*262<256 else 255,a)
    return im

def embed(src_glb, new_png, out, texname=None):
    b=open(src_glb,'rb').read()
    jl=struct.unpack('<I',b[12:16])[0]; j=json.loads(b[20:20+jl])
    off=20+jl; bl=struct.unpack('<I',b[off:off+4])[0]; binc=bytearray(b[off+8:off+8+bl])
    while len(binc)%4: binc.append(0)
    png=io.BytesIO(); new_png.save(png,'PNG',optimize=True); pb=png.getvalue()
    start=len(binc); binc+=pb
    while len(binc)%4: binc.append(0)
    j['bufferViews'].append({'buffer':0,'byteOffset':start,'byteLength':len(pb)})
    for im in j['images']:
        im.pop('uri',None); im['bufferView']=len(j['bufferViews'])-1; im['mimeType']='image/png'
    j['buffers'][0]['byteLength']=len(binc)
    js=json.dumps(j,separators=(',',':')).encode()
    while len(js)%4: js+=b' '
    total=12+8+len(js)+8+len(binc)
    o=struct.pack('<III',0x46546C67,2,total)+struct.pack('<II',len(js),0x4E4F534A)+js+struct.pack('<II',len(binc),0x004E4942)+bytes(binc)
    open(out,'wb').write(o)

kit_mod=kit_recolor(Image.open(MOD+'Textures/colormap.png'))
kit_sta=kit_recolor(Image.open(STA+'Textures/colormap.png'))
mods=['corridor','corridor-corner','corridor-end','corridor-intersection','corridor-junction','corridor-wide','room-small','room-large','room-wide','gate','gate-door','stairs','template-floor','template-wall']
stas=['door-single','door-double','wall','wall-door','computer','computer-wide','container','container-tall','container-wide','pipe','pipe-bend','pipe-ring','table','table-large','chair','floor','structure-barrier','wall-switch','display-wall']
n=0
for m in mods: embed(MOD+m+'.glb',kit_mod,OUT+'k_'+m.replace('-','_')+'.glb'); n+=1
for m in stas: embed(STA+m+'.glb',kit_sta,OUT+'s_'+m.replace('-','_')+'.glb'); n+=1
def raider_recolor(im):
    im=im.convert('RGBA'); px=im.load(); w,h=im.size
    for y in range(h):
        for x in range(w):
            r,g,b,a=px[x,y]
            if a==0: continue
            l=(0.3*r+0.59*g+0.11*b)/255
            if l>0.80: px[x,y]=(255,170,60,a)
            else:
                k=0.10+l*0.55
                px[x,y]=(int(min(255,k*330)),int(k*70),int(k*72),a)
    return im
rai=raider_recolor(Image.open(CHR+'Textures/texture-r.png'))
embed(CHR+'character-r.glb',rai,OUT+'raider.glb')
embed(CHR+'character-e.glb',Image.open(CHR+'Textures/texture-e.png'),OUT+'coworker.glb')
hun=hunter_recolor(Image.open(CHR+'Textures/texture-o.png'))
embed(CHR+'character-o.glb',hun,OUT+'hunter.glb')
print(n+3,'models written')
