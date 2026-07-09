#!/usr/bin/env python3
"""Reffi 앱 아이콘 — 완전히 다른 스타일 세트(타이포 + 오브젝트 + 상징).
번들 폰트(Story Script / Google Sans Flex / Pretendard) 사용. Pillow 직접 렌더."""
import math
from PIL import Image, ImageDraw, ImageFilter, ImageFont

S=1024; SUP=4; W=S*SUP
FONTS="/Users/heejaeeo/Library/CloudStorage/OneDrive-AcademyofArtUniversity/Reffie/repo/Reffi/Resources/Fonts"
def font(name, size): return ImageFont.truetype(f"{FONTS}/{name}", int(size*SUP))

def C(h,a=255):
    h=h.lstrip('#'); return (int(h[0:2],16),int(h[2:4],16),int(h[4:6],16),a)
BLUE=C("#176AB0"); BLUE_DARK=C("#004985"); BLUE_LT=C("#5AA0DE"); NAVY=C("#00335F")
CREAM=C("#F8F5EC"); CREAM_D=C("#EFE9DA"); CREAM_LT=C("#FDFBF4")
RECEIPT=C("#FCFBF7"); INK=C("#25211B"); MUTED=C("#C3BDB1")
TOMATO=C("#E4593A"); TOMATO_D=C("#C8442A")
LEAF=C("#3E8B3A"); LEAF_D=C("#2E6E2C"); LEAF_LT=C("#7FBF6A")
FRESH=C("#ADE393"); FRESH_D=C("#387332")
SOON=C("#F4C767"); SOON_D=C("#996000"); URGENT=C("#F68D70"); URGENT_D=C("#AE3F2C")
WHITE=C("#FFFFFF")

def lerp(a,b,t): return tuple(int(a[i]+(b[i]-a[i])*t) for i in range(4))
def s(v): return v*SUP
def layer(): return Image.new("RGBA",(W,W),(0,0,0,0))

def radial(inner,mid,outer,cx=0.32,cy=0.24):
    bg=Image.new("RGBA",(W,W)); px=bg.load(); ccx,ccy=W*cx,W*cy; md=math.hypot(W,W)*0.92
    for y in range(W):
        for x in range(W):
            d=min(1.0,math.hypot(x-ccx,y-ccy)/md)
            px[x,y]=lerp(inner,mid,d/0.55) if d<0.55 else lerp(mid,outer,(d-0.55)/0.45)
    return bg

def draw_text_center(img, xy, text, fnt, fill, tilt=0, shadow=None):
    """텍스트를 중앙 정렬로 별도 레이어에 그려 (선택)기울임+그림자 후 합성."""
    tl=layer(); d=ImageDraw.Draw(tl)
    bbox=d.textbbox((0,0),text,font=fnt); tw=bbox[2]-bbox[0]; th=bbox[3]-bbox[1]
    ox=s(xy[0])-tw/2-bbox[0]; oy=s(xy[1])-th/2-bbox[1]
    if shadow:
        sl=layer(); ImageDraw.Draw(sl).text((ox,oy+s(8)),text,font=fnt,fill=shadow)
        sl=sl.filter(ImageFilter.GaussianBlur(W*0.006))
        if tilt: sl=sl.rotate(tilt,center=(s(512),s(512)),resample=Image.BICUBIC)
        img.alpha_composite(sl)
    d.text((ox,oy),text,font=fnt,fill=fill)
    if tilt: tl=tl.rotate(tilt,center=(s(512),s(512)),resample=Image.BICUBIC)
    img.alpha_composite(tl)
    return img

def paper_square(d, cx, cy, half, seed_pts, fill, dogear=0):
    """손으로 자른 종이 사각(약간 불규칙). dogear>0이면 우상단 접힘."""
    j=half*0.03
    pts=[(cx-half, cy-half+j),(cx+half-dogear, cy-half-j),
         (cx+half, cy-half+dogear),
         (cx+half+j, cy+half),(cx-half-j, cy+half+j*0.5),(cx-half+j, cy-half+half*0.9)]
    # 간단한 라운드 사각 대체(불규칙 4각)
    pts=[(cx-half, cy-half),(cx+half-dogear, cy-half),(cx+half, cy-half+dogear),
         (cx+half, cy+half),(cx-half, cy+half)]
    d.polygon([(s(a),s(b)) for a,b in pts], fill=fill)

def rounded(d, box, r, **kw): d.rounded_rectangle([s(v) for v in box], radius=s(r), **kw)

def tomato_glyph(cx,cy,r):
    tom=layer(); tpx=tom.load(); scx,scy,sr=s(cx),s(cy),s(r)
    for yy in range(int(scy-sr-4),int(scy+sr+4)):
        for xx in range(int(scx-sr-4),int(scx+sr+4)):
            if (xx-scx)**2+(yy-scy)**2<=sr*sr:
                t=(yy-(scy-sr))/(2*sr); tpx[xx,yy]=lerp(TOMATO,TOMATO_D,max(0,min(1,t)))
    d=ImageDraw.Draw(tom); star=[]; sx,sy=cx,cy-r+r*0.12
    for i in range(10):
        ang=-math.pi/2+i*math.pi/5; rad=r*0.46 if i%2==0 else r*0.19
        star.append((s(sx+rad*math.cos(ang)),s(sy+rad*math.sin(ang)*0.82)))
    d.polygon(star,fill=LEAF); d.ellipse([s(sx-r*0.09),s(sy-r*0.09),s(sx+r*0.09),s(sy+r*0.09)],fill=LEAF_D)
    return tom

def finalize(out, name):
    out=out.resize((S,S),Image.LANCZOS).convert("RGB")
    out.save(f"v2-{name}-1024.png"); out.resize((120,120),Image.LANCZOS).save(f"v2-{name}-120.png")
    print("wrote",name)

# ============ 1) Story Script "R" 모노그램 (블루) ============
def v_monogram():
    bg=radial(BLUE_LT,BLUE,BLUE_DARK)
    bg.alpha_composite(draw_text_center(layer(),(512,512),"R",font("StoryScript-Regular.ttf",720),WHITE,shadow=(0,20,40,90)))
    finalize(bg,"1-mono-R")

# ============ 2) "Reffi" 워드마크 (크림, 블루 글자) ============
def v_wordmark():
    bg=radial(CREAM_LT,CREAM,CREAM_D)
    bg.alpha_composite(draw_text_center(layer(),(512,512),"Reffi",font("StoryScript-Regular.ttf",340),BLUE,shadow=(120,140,170,80)))
    finalize(bg,"2-wordmark")

# ============ 3) "D-2" 신선도 도장 (크림, 어반저 도장) ============
def v_stamp():
    bg=radial(CREAM_LT,CREAM,CREAM_D)
    st=layer(); d=ImageDraw.Draw(st)
    rounded(d,[236,356,788,668],72,fill=RECEIPT)
    rounded(d,[236,356,788,668],72,outline=URGENT_D,width=int(22))
    st=draw_text_center(st,(512,512),"D-2",font("GoogleSansFlex-Regular.ttf",240),URGENT_D)
    st=st.rotate(-8,center=(s(512),s(512)),resample=Image.BICUBIC)
    # 도장 그림자
    sh=layer(); ImageDraw.Draw(sh).rounded_rectangle([s(236),s(366),s(788),s(678)],radius=s(72),fill=(80,20,10,80))
    sh=sh.filter(ImageFilter.GaussianBlur(W*0.012)).rotate(-8,center=(s(512),s(512)),resample=Image.BICUBIC)
    bg.alpha_composite(sh); bg.alpha_composite(st)
    finalize(bg,"3-stamp-D2")

# ============ 4) 손으로 자른 종이 냉장고 (블루) ============
def v_fridge():
    bg=radial(BLUE_LT,BLUE,BLUE_DARK)
    fr=layer(); d=ImageDraw.Draw(fr)
    # 몸통(둥근 사각, 종이 크림)
    bx0,bx1,by0,by1=340,684,236,812
    rounded(d,[bx0,by0,bx1,by1],56,fill=RECEIPT)
    # 상단 도어 분할선
    d.line([(s(bx0+18),s(452)),(s(bx1-18),s(452))],fill=(*MUTED[:3],200),width=int(s(7)))
    # 손잡이 2개(세로 바)
    rounded(d,[bx0+42,300,bx0+42+22,404],11,fill=BLUE)
    rounded(d,[bx0+42,500,bx0+42+22,660],11,fill=BLUE)
    # 신선도 점(상단 도어 우측) — fresh
    d.ellipse([s(bx1-96),s(316),s(bx1-52),s(360)],fill=FRESH_D)
    # 그림자
    sh=layer(); ImageDraw.Draw(sh).rounded_rectangle([s(bx0),s(by0+10),s(bx1),s(by1+10)],radius=s(56),fill=(0,18,36,110))
    sh=sh.filter(ImageFilter.GaussianBlur(W*0.02))
    bg.alpha_composite(sh); bg.alpha_composite(fr)
    finalize(bg,"4-fridge")

# ============ 5) 눈송이(냉장 모티프) + 크림 (딥블루) ============
def v_snow():
    bg=radial(BLUE,BLUE_DARK,NAVY)
    fl=layer(); d=ImageDraw.Draw(fl); cx,cy=512,512; R=300; arm=int(s(26))
    for k in range(6):
        ang=math.pi/3*k
        ex,ey=cx+R*math.cos(ang),cy+R*math.sin(ang)
        d.line([(s(cx),s(cy)),(s(ex),s(ey))],fill=WHITE,width=arm)
        # 곁가지
        for f in (0.55,0.78):
            bx,by=cx+R*f*math.cos(ang),cy+R*f*math.sin(ang); bl=R*0.22
            for dd in (+1,-1):
                a2=ang+dd*math.pi/3
                d.line([(s(bx),s(by)),(s(bx+bl*math.cos(a2)),s(by+bl*math.sin(a2)))],fill=WHITE,width=int(s(18)))
    d.ellipse([s(cx-40),s(cy-40),s(cx+40),s(cy+40)],fill=WHITE)
    sh=fl.filter(ImageFilter.GaussianBlur(W*0.012))
    bg.alpha_composite(sh); bg.alpha_composite(fl)
    finalize(bg,"5-snowflake")

# ============ 6) 잎 상징(무낭비·신선) — 크림 그라운드 + 두 톤 잎 ============
def v_leaf():
    bg=radial(CREAM_LT,CREAM,CREAM_D)
    cx,cy,H,Wd,rot = 512, 512, 300, 168, -18

    def rot_pt(x,y):
        rr=math.radians(rot)
        return (s(cx + x*math.cos(rr) - y*math.sin(rr)), s(cy + x*math.sin(rr) + y*math.cos(rr)))

    # 잎 윤곽: 위·아래 뾰족한 타원(중앙이 가장 넓음, 위쪽이 살짝 통통)
    N=60
    right=[]; left=[]
    for i in range(N+1):
        t=i/N                      # 0=위 tip, 1=아래 tip
        y = -H + 2*H*t
        hw = Wd * (math.sin(math.pi*t)**0.72)
        right.append((hw, y)); left.append((-hw, y))
    outline = right + list(reversed(left))

    lf=layer(); d=ImageDraw.Draw(lf)
    d.polygon([rot_pt(x,y) for x,y in outline], fill=LEAF)
    # 밝은 왼쪽 절반(중앙맥 기준) — 두 톤 종이컷
    left_half = [(0,-H)] + left + [(0,H)]
    d.polygon([rot_pt(x,y) for x,y in left_half], fill=LEAF_LT)
    # 중앙맥
    d.line([rot_pt(0,-H+18), rot_pt(0,H-18)], fill=LEAF_D, width=int(s(14)))
    # 곁맥 3쌍
    for t in (0.32,0.5,0.68):
        y=-H+2*H*t; hw=Wd*(math.sin(math.pi*t)**0.72)*0.82
        d.line([rot_pt(0,y), rot_pt(hw*0.9, y+70)], fill=LEAF_D, width=int(s(8)))
        d.line([rot_pt(0,y), rot_pt(-hw*0.9, y+70)], fill=(*LEAF_D[:3],150), width=int(s(8)))

    sh=lf.filter(ImageFilter.GaussianBlur(W*0.012))
    off=layer(); off.alpha_composite(sh)   # 그림자(살짝 아래)
    bg.alpha_composite(sh); bg.alpha_composite(lf)
    finalize(bg,"6-leaf")

for f in (v_monogram,v_wordmark,v_stamp,v_fridge,v_snow,v_leaf):
    f()
print("all done")
