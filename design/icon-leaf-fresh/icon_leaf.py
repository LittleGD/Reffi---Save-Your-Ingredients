#!/usr/bin/env python3
"""Reffi 앱 아이콘 — 나뭇잎 기반 프레시 베리에이션. Pillow 직접 렌더."""
import math
from PIL import Image, ImageDraw, ImageFilter

S=1024; SUP=4; W=S*SUP
def C(h,a=255):
    h=h.lstrip('#'); return (int(h[0:2],16),int(h[2:4],16),int(h[4:6],16),a)

# 초록 팔레트(프레시)
FRESH=C("#ADE393"); FRESH_D=C("#387332"); FRESH_LT=C("#C6ECB3")
LEAF=C("#4FA83C"); LEAF_LT=C("#8FD14F"); LEAF_D=C("#2E6E2C"); LIME=C("#9BDB4F")
MINT=C("#DFF3E4"); MINT_D=C("#BFE6C9"); TEAL_LT=C("#CDEDE6"); SAGE=C("#B7D9A0")
CREAM=C("#F8F5EC"); CREAM_LT=C("#FDFBF4"); CREAM_D=C("#EFE9DA")
BLUE=C("#176AB0"); DEW=C("#7FC3E8"); WHITE=C("#FFFFFF"); INK=C("#25211B")

def lerp(a,b,t): return tuple(int(a[i]+(b[i]-a[i])*t) for i in range(4))
def s(v): return v*SUP
def layer(): return Image.new("RGBA",(W,W),(0,0,0,0))

def radial(inner,mid,outer,cx=0.34,cy=0.26):
    bg=Image.new("RGBA",(W,W)); px=bg.load(); ccx,ccy=W*cx,W*cy; md=math.hypot(W,W)*0.92
    for y in range(W):
        for x in range(W):
            d=min(1.0,math.hypot(x-ccx,y-ccy)/md)
            px[x,y]=lerp(inner,mid,d/0.55) if d<0.55 else lerp(mid,outer,(d-0.55)/0.45)
    return bg

def leaf(dst, cx, cy, H, Wd, rot, main, light, vein, veins=True):
    """손으로 자른 두 톤 잎(위·아래 뾰족). dst 레이어에 합성."""
    def rp(x,y):
        rr=math.radians(rot)
        return (s(cx+x*math.cos(rr)-y*math.sin(rr)), s(cy+x*math.sin(rr)+y*math.cos(rr)))
    N=64; right=[]; left=[]
    for i in range(N+1):
        t=i/N; y=-H+2*H*t; hw=Wd*(math.sin(math.pi*t)**0.72)
        right.append((hw,y)); left.append((-hw,y))
    lf=layer(); d=ImageDraw.Draw(lf)
    d.polygon([rp(x,y) for x,y in right+list(reversed(left))], fill=main)
    d.polygon([rp(x,y) for x,y in [(0,-H)]+left+[(0,H)]], fill=light)   # 밝은 왼쪽 절반
    if veins:
        d.line([rp(0,-H+18), rp(0,H-18)], fill=vein, width=int(s(13)))
        for t in (0.34,0.5,0.66):
            y=-H+2*H*t; hw=Wd*(math.sin(math.pi*t)**0.72)*0.8
            d.line([rp(0,y), rp(hw*0.9,y+64)], fill=vein, width=int(s(7)))
            d.line([rp(0,y), rp(-hw*0.9,y+64)], fill=(*vein[:3],150), width=int(s(7)))
    # 그림자
    sh=lf.filter(ImageFilter.GaussianBlur(W*0.011))
    dst.alpha_composite(sh); dst.alpha_composite(lf)

def stem(dst, x0,y0,x1,y1, col, wpx):
    d=ImageDraw.Draw(dst); d.line([(s(x0),s(y0)),(s(x1),s(y1))], fill=col, width=int(s(wpx)))

def finalize(bg,name):
    out=bg.resize((S,S),Image.LANCZOS).convert("RGB")
    out.save(f"lf-{name}-1024.png"); out.resize((120,120),Image.LANCZOS).save(f"lf-{name}-120.png")
    print("wrote",name)

# 1) 단일 잎 — 선명한 프레시 그린 그라운드(가장 상큼)
def v1():
    bg=radial(FRESH_LT,FRESH,C("#5FB03F"))
    leaf(bg,512,512,320,182,-18,LEAF,LEAF_LT,LEAF_D)
    finalize(bg,"1-single-fresh")

# 2) 새싹 — 줄기 + 두 잎이 위로 자람(새로움·성장), 밝은 민트
def v2():
    bg=radial(WHITE,MINT,MINT_D)
    stem(bg,512,760,512,470,LEAF_D,26)
    leaf(bg,406,470,196,116,-46,LEAF,LEAF_LT,LEAF_D)
    leaf(bg,618,430,210,122,42,LIME,C("#B6E86B"),LEAF_D)
    finalize(bg,"2-sprout")

# 3) 잎 + 이슬방울(신선·촉촉), 크림
def v3():
    bg=radial(CREAM_LT,CREAM,CREAM_D)
    leaf(bg,486,520,320,182,-20,LEAF,LEAF_LT,LEAF_D)
    # 이슬방울
    dl=layer(); d=ImageDraw.Draw(dl)
    dx,dy,dr=640,392,58
    d.ellipse([s(dx-dr),s(dy-dr*0.9),s(dx+dr),s(dy+dr*1.25)], fill=(*DEW[:3],235))
    d.ellipse([s(dx-dr*0.5),s(dy-dr*0.55),s(dx-dr*0.05),s(dy-dr*0.05)], fill=(255,255,255,180))
    dl=dl.filter(ImageFilter.GaussianBlur(W*0.001))
    bg.alpha_composite(dl.filter(ImageFilter.GaussianBlur(W*0.006)))  # soft shadow
    bg.alpha_composite(dl)
    finalize(bg,"3-leaf-dew")

# 4) 두 잎 팬(부채꼴) — 풍성·활기, 세이지→프레시
def v4():
    bg=radial(C("#DDF0CE"),SAGE,C("#7FB562"))
    leaf(bg,470,556,300,168,-40,LEAF,LEAF_LT,LEAF_D)
    leaf(bg,566,536,300,168,20,LIME,C("#BCEA74"),LEAF_D)
    finalize(bg,"4-duo-fan")

# 5) 볼드 단일 잎 — 크림/화이트에 큰 잎(미니멀·선명)
def v5():
    bg=radial(WHITE,CREAM_LT,CREAM)
    leaf(bg,512,512,380,224,-14,LEAF,LEAF_LT,LEAF_D)
    finalize(bg,"5-bold-cream")

# 6) 잎 배지 — 프레시 원 안에 흰 잎(플랫 로고 느낌)
def v6():
    bg=radial(FRESH,C("#6FBF55"),FRESH_D)
    # 흰 잎(단색) + 살짝 밝은 절반
    leaf(bg,512,512,330,190,-16, WHITE, C("#EAF7E3"), C("#CDE9BE"))
    finalize(bg,"6-white-on-green")

for f in (v1,v2,v3,v4,v5,v6): f()
print("all done")
