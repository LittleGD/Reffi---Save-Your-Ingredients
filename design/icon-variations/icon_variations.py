#!/usr/bin/env python3
"""Reffi 앱 아이콘 베리에이션 — 영수증 + 토마토(도장 없음).
배경/구도/토마토 스케일을 바꿔 여러 안 생성. Pillow 직접 렌더."""
import math, sys
from PIL import Image, ImageDraw, ImageFilter

S = 1024; SUP = 4; W = S * SUP

def C(hexs, a=255):
    h = hexs.lstrip('#'); return (int(h[0:2],16), int(h[2:4],16), int(h[4:6],16), a)

# 팔레트
BLUE=C("#176AB0"); BLUE_DARK=C("#004985"); BLUE_LT=C("#5AA0DE")
CREAM=C("#F8F5EC"); CREAM_D=C("#EFE9DA"); CREAM_LT=C("#FDFBF4")
RECEIPT=C("#FCFBF7"); MUTED=C("#C3BDB1")
TOMATO=C("#E4593A"); TOMATO_D=C("#C8442A")
LEAF=C("#3E8B3A"); LEAF_D=C("#2E6E2C")
FRESH=C("#ADE393"); FRESH_D=C("#387332")

def lerp(a,b,t): return tuple(int(a[i]+(b[i]-a[i])*t) for i in range(4))
def s(v): return v*SUP
def layer(): return Image.new("RGBA",(W,W),(0,0,0,0))

def radial_bg(inner, mid, outer, cx=0.32, cy=0.24):
    bg=Image.new("RGBA",(W,W)); px=bg.load()
    ccx,ccy=W*cx,W*cy; maxd=math.hypot(W,W)*0.92
    for y in range(W):
        for x in range(W):
            d=min(1.0,math.hypot(x-ccx,y-ccy)/maxd)
            px[x,y]= lerp(inner,mid,d/0.55) if d<0.55 else lerp(mid,outer,(d-0.55)/0.45)
    return bg

def receipt_poly(d, x0,x1,y0,y1, teeth, th, fill):
    pts=[]; step=(x1-x0)/teeth
    for i in range(teeth+1):
        pts.append((x0+step*i, y0+(th if i%2==1 else 0)))
    for i in range(teeth+1):
        pts.append((x1-step*i, y1-(th if i%2==1 else 0)))
    d.polygon([(s(a),s(b)) for a,b in pts], fill=fill)

def tomato(tcx, tcy, tr, leaf_color=LEAF, leaf_dark=LEAF_D):
    tom=layer(); tpx=tom.load()
    scx,scy,sr=s(tcx),s(tcy),s(tr)
    x0,x1=int(scx-sr-4),int(scx+sr+4); y0,y1=int(scy-sr-4),int(scy+sr+4)
    for yy in range(y0,y1):
        for xx in range(x0,x1):
            if (xx-scx)**2+(yy-scy)**2<=sr*sr:
                t=(yy-(scy-sr))/(2*sr); tpx[xx,yy]=lerp(TOMATO,TOMATO_D,max(0,min(1,t)))
    hl=layer(); hld=ImageDraw.Draw(hl)
    hld.ellipse([s(tcx-tr*0.6),s(tcy-tr*0.66),s(tcx-tr*0.07),s(tcy-tr*0.25)], fill=(255,255,255,64))
    tom=Image.alpha_composite(tom, hl.filter(ImageFilter.GaussianBlur(W*0.004)))
    td=ImageDraw.Draw(tom)
    star=[]; sx,sy=tcx,tcy-tr+tr*0.12; n=5
    for i in range(n*2):
        ang=-math.pi/2+i*math.pi/n; rad=(tr*0.46) if i%2==0 else (tr*0.19)
        star.append((s(sx+rad*math.cos(ang)), s(sy+rad*math.sin(ang)*0.82)))
    td.polygon(star, fill=leaf_color)
    td.ellipse([s(sx-tr*0.093),s(sy-tr*0.093),s(sx+tr*0.093),s(sy+tr*0.093)], fill=leaf_dark)
    return tom

def build(name, bg, receipt_fill=RECEIPT, tilt=-5, tr=118, tcy=470,
          teeth=9, zoom=1.16, lines=True, leaf=(LEAF,LEAF_D)):
    paper=layer(); pd=ImageDraw.Draw(paper)
    rx0,rx1,ry0,ry1=300,724,250,792
    receipt_poly(pd, rx0,rx1,ry0,ry1, teeth, 26, receipt_fill)
    if lines:
        pd.rounded_rectangle([s(352),s(328),s(502),s(346)], radius=s(9), fill=(*MUTED[:3],150))
        ly=tcy+170
        x=352
        while x<672-20:
            pd.line([(s(x),s(ly)),(s(x+18),s(ly))], fill=(*MUTED[:3],150), width=int(s(4))); x+=34
        pd.rounded_rectangle([s(352),s(ly+30),s(472),s(ly+46)], radius=s(8), fill=(*MUTED[:3],130))
        pd.rounded_rectangle([s(352),s(ly+66),s(548),s(ly+82)], radius=s(8), fill=(*MUTED[:3],130))
    # 토마토 + 그림자
    tsh=layer(); tshd=ImageDraw.Draw(tsh)
    tshd.ellipse([s(512-tr),s(tcy-tr+8),s(512+tr),s(tcy+tr+8)], fill=(60,20,10,70))
    paper=Image.alpha_composite(paper, tsh.filter(ImageFilter.GaussianBlur(W*0.008)))
    paper=Image.alpha_composite(paper, tomato(512,tcy,tr,leaf[0],leaf[1]))
    paper=paper.rotate(tilt, center=(s(512),s(512)), resample=Image.BICUBIC)
    # 영수증 그림자
    sh=layer(); shd=ImageDraw.Draw(sh)
    receipt_poly(shd, rx0,rx1,ry0+8,ry1+8, teeth, 26, (0,18,36,110))
    sh=sh.filter(ImageFilter.GaussianBlur(W*0.022)).rotate(tilt, center=(s(512),s(512)), resample=Image.BICUBIC)
    subject=Image.alpha_composite(sh, paper)
    zs=int(W*zoom); subject=subject.resize((zs,zs), Image.LANCZOS)
    off=(zs-W)//2
    subject=subject.crop((off, off+int(W*0.02), off+W, off+int(W*0.02)+W))
    out=Image.alpha_composite(bg, subject).resize((S,S), Image.LANCZOS).convert("RGB")
    out.save(f"var-{name}-1024.png")
    out.resize((120,120), Image.LANCZOS).save(f"var-{name}-120.png")
    print("wrote", name)

# ---- 베리에이션 ----
# A: 블루 그라운드(현행 계열, 도장만 제거)
build("A-blue", radial_bg(BLUE_LT,BLUE,BLUE_DARK))
# B: 크림 그라운드(인앱 캔버스 톤) — 따뜻·미니멀
build("B-cream", radial_bg(CREAM_LT,CREAM,CREAM_D), tilt=-4)
# C: 프레시 그린 그라운드(신선도 브랜드)
build("C-fresh", radial_bg(C("#C6ECB3"),FRESH,FRESH_D))
# D: 블루 + 큰 토마토(영수증 꽉 채움, 미니 라인 제거)
build("D-bigtom", radial_bg(BLUE_LT,BLUE,BLUE_DARK), tr=150, tcy=500, lines=False, zoom=1.20)
# E: 크림 + 큰 토마토·정렬(틸트 0, 미니 라인 제거) — 정돈된 느낌
build("E-flat", radial_bg(CREAM_LT,CREAM,CREAM_D), tilt=0, tr=150, tcy=500, lines=False, zoom=1.18)
# F: 블루-다크 단색 + 밝은 영수증(대비 강함)
build("F-navy", radial_bg(BLUE,BLUE_DARK,C("#00335F")), tr=132, tcy=486)
