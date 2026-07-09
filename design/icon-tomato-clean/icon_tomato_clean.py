#!/usr/bin/env python3
"""Reffi 앱 아이콘 — 깔끔한 컷페이퍼 토마토(매끈한 곡선 실루엣, 단색 플랫).
그라데이션·그림자 없음. 풀블리드(iOS 자동 라운딩). Pillow 슈퍼샘플 AA."""
import math
from PIL import Image, ImageDraw

S=1024; SUP=4; W=S*SUP
def C(h): h=h.lstrip('#'); return (int(h[0:2],16),int(h[2:4],16),int(h[4:6],16),255)
def s(v): return v*SUP

# 팔레트
BUTTER = C("#FBE7B0")   # 레퍼런스 버터크림
CREAM  = C("#F6EFDE")   # 앱 캔버스 톤
BLUE   = C("#176AB0")   # Reffi Blue(브랜드)
TOMATO = C("#E75E28")   # 오렌지-레드
TOMATO_R=C("#E24631")   # 레드
CALYX  = C("#256B2E")   # 딥 그린
CALYX_HI=C("#3E8B3A")   # 밝은 그린(잎 하이라이트)

def smooth_body(cx, cy, R, squash=0.95, n=280):
    """매끈한 유기적 토마토 실루엣 — 저주파 변조만(각진 면 없음)."""
    pts=[]
    for i in range(n):
        th=(i/n)*2*math.pi
        # 아주 완만한 로브(2·3차) — 손맛은 있되 매끈
        r=R*(1 + 0.022*math.cos(2*th) + 0.014*math.cos(3*th+0.6))
        x=cx + r*math.cos(th)
        y=cy + r*squash*math.sin(th)
        # 상단 중앙 살짝 눌림(꼭지 자리) — 부드럽게
        if math.sin(th) < -0.2:
            y += R*0.05*math.exp(-((math.cos(th))/0.42)**2)*(-math.sin(th)-0.2)
        pts.append((s(x),s(y)))
    return pts

def leaf(cx, cy, ang, length, width):
    """매끈한 잎 하나 — 부드러운 곡선 마름모(끝 뾰족, 중앙 볼록)."""
    def P(dist, off): return (cx+dist*math.cos(ang+off), cy+dist*math.sin(ang+off))
    tip=P(length,0)
    l1=P(length*0.62, 0.20); l2=P(width, 0.95); base=P(width*0.35, math.pi)
    r2=P(width, -0.95); r1=P(length*0.62, -0.20)
    return [tip,l1,l2,base,r2,r1]

def build(name, bg, tomato=TOMATO):
    img=Image.new("RGBA",(W,W),bg); d=ImageDraw.Draw(img)
    cx,cy = 512, 560
    R=322
    # 바디
    d.polygon(smooth_body(cx,cy,R), fill=tomato)
    # 꼭지 — 중앙 상단, 5갈래 정돈된 잎 + 짧은 줄기
    kx,ky = cx, cy-R*0.86
    for i in range(5):
        a=-math.pi/2 + i*(2*math.pi/5)
        pts=leaf(kx,ky,a, R*0.34, R*0.12)
        d.polygon([(s(p[0]),s(p[1])) for p in pts], fill=CALYX)
    # 위쪽 두 잎에 밝은 하이라이트(살짝) — 깔끔한 결
    for i in (0,):   # 정상 잎
        a=-math.pi/2
        pts=leaf(kx,ky,a, R*0.26, R*0.07)
        d.polygon([(s(p[0]),s(p[1])) for p in pts], fill=CALYX_HI)
    # 중앙 허브
    d.ellipse([s(kx-R*0.075),s(ky-R*0.075),s(kx+R*0.075),s(ky+R*0.075)], fill=CALYX)
    # 짧은 줄기(위로)
    d.rounded_rectangle([s(kx-R*0.028),s(ky-R*0.30),s(kx+R*0.028),s(ky+R*0.02)],
                        radius=s(R*0.028), fill=CALYX)
    out=img.resize((S,S),Image.LANCZOS).convert("RGB")
    out.save(f"icn-{name}-1024.png")
    out.resize((180,180),Image.LANCZOS).save(f"icn-{name}-180.png")
    out.resize((120,120),Image.LANCZOS).save(f"icn-{name}-120.png")
    print("wrote",name)

build("A-butter", BUTTER)                    # 레퍼런스 버터크림
build("B-cream",  CREAM)                      # 앱 캔버스 톤
build("C-blue",   BLUE)                       # 브랜드 블루(대비 강함)
build("D-red-butter", BUTTER, tomato=TOMATO_R)  # 레드 토마토 + 버터
print("all done")
