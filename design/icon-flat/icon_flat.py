#!/usr/bin/env python3
"""Reffi 앱 아이콘 — 영수증+토마토, 완전 플랫(그라데이션·하이라이트·드롭섀도 없음).
분리는 색 대비로만. Pillow 직접 렌더."""
import math
from PIL import Image, ImageDraw

S=1024; SUP=4; W=S*SUP
def C(h,a=255):
    h=h.lstrip('#'); return (int(h[0:2],16),int(h[2:4],16),int(h[4:6],16),a)

RECEIPT_W=C("#FFFFFF")
TOMATO=C("#E1512F")            # 플랫 단색(중간 톤)
LEAF=C("#3E8B3A"); LEAF_D=C("#2E6E2C")
MUTED=C("#CFC9BC")             # 명세 라인(플랫)
def s(v): return v*SUP
def layer(): return Image.new("RGBA",(W,W),(0,0,0,0))

def receipt_poly(d, x0,x1,y0,y1, teeth, th, fill):
    pts=[]; step=(x1-x0)/teeth
    for i in range(teeth+1): pts.append((x0+step*i, y0+(th if i%2==1 else 0)))
    for i in range(teeth+1): pts.append((x1-step*i, y1-(th if i%2==1 else 0)))
    d.polygon([(s(a),s(b)) for a,b in pts], fill=fill)

def build(name, bg_hex, receipt=RECEIPT_W, edge=None, tilt=-4, tr=118, tcy=470, lines=True):
    bg=Image.new("RGBA",(W,W), C(bg_hex))
    paper=layer(); pd=ImageDraw.Draw(paper)
    rx0,rx1,ry0,ry1=300,724,250,792
    receipt_poly(pd, rx0,rx1,ry0,ry1, 9, 26, receipt)
    if edge:   # 종이 단면 헤어라인(3D 아님, 플랫 정의선)
        # 폴리곤 외곽선
        pts=[]; step=(rx1-rx0)/9
        for i in range(10): pts.append((rx0+step*i, ry0+(26 if i%2==1 else 0)))
        for i in range(10): pts.append((rx1-step*i, ry1-(26 if i%2==1 else 0)))
        pd.line([(s(a),s(b)) for a,b in pts]+[(s(pts[0][0]),s(pts[0][1]))], fill=edge, width=int(s(3)))
    if lines:
        # 상단 라인: 위로 올리고 짧게 — 토마토 별꼭지(~y312, x458~)와 간격 확보
        pd.rounded_rectangle([s(352),s(292),s(448),s(310)], radius=s(9), fill=MUTED)
        ly=tcy+170; x=352
        while x<672-20:
            pd.line([(s(x),s(ly)),(s(x+18),s(ly))], fill=MUTED, width=int(s(4))); x+=34
        pd.rounded_rectangle([s(352),s(ly+30),s(472),s(ly+46)], radius=s(8), fill=MUTED)
        pd.rounded_rectangle([s(352),s(ly+66),s(548),s(ly+82)], radius=s(8), fill=MUTED)
    # 플랫 토마토
    tom=layer(); td=ImageDraw.Draw(tom)
    td.ellipse([s(512-tr),s(tcy-tr),s(512+tr),s(tcy+tr)], fill=TOMATO)   # 단색 원
    star=[]; sx,sy=512,tcy-tr+tr*0.12
    for i in range(10):
        ang=-math.pi/2+i*math.pi/5; rad=tr*0.46 if i%2==0 else tr*0.19
        star.append((s(sx+rad*math.cos(ang)),s(sy+rad*math.sin(ang)*0.82)))
    td.polygon(star, fill=LEAF)
    td.ellipse([s(sx-tr*0.09),s(sy-tr*0.09),s(sx+tr*0.09),s(sy+tr*0.09)], fill=LEAF_D)
    paper=Image.alpha_composite(paper, tom)
    paper=paper.rotate(tilt, center=(s(512),s(512)), resample=Image.BICUBIC)
    # 확대(프레임 채움) — 그림자 없음
    subj=paper; zs=int(W*1.16); subj=subj.resize((zs,zs), Image.LANCZOS)
    off=(zs-W)//2; subj=subj.crop((off, off+int(W*0.02), off+W, off+int(W*0.02)+W))
    out=Image.alpha_composite(bg, subj).resize((S,S), Image.LANCZOS).convert("RGB")
    out.save(f"flat-{name}-1024.png"); out.resize((120,120),Image.LANCZOS).save(f"flat-{name}-120.png")
    print("wrote",name)

# 배경 대비 단계별(흰 영수증 분리를 색으로만)
build("A-soft",   "#F1EADB")                       # 부드러운 크림(권장 기본)
build("B-airy",   "#F8F5EC")                       # 원본 라이트 크림(대비 약함, 에어리)
build("C-edge",   "#F5F0E3", edge=C("#E3DDCE"))    # 헤어라인 단면(플랫 정의선)
build("D-warm",   "#EBE1CC")                        # 더 따뜻·깊은 크림(대비 강함)
build("E-sage",   "#E7EEDD")                        # 연한 세이지(식품·신선 톤)
print("all done")
