#!/usr/bin/env python3
"""마티스 컷페이퍼 스타일 토마토 — 레퍼런스(손으로 오린 종이, 납작 단색, 불규칙 윤곽).
그라데이션·그림자 없음. Pillow 폴리곤 + 슈퍼샘플 AA."""
import math
from PIL import Image, ImageDraw

S=1024; SUP=4; W=S*SUP
def C(h): h=h.lstrip('#'); return (int(h[0:2],16),int(h[2:4],16),int(h[4:6],16),255)
def s(v): return int(v*SUP)

# 레퍼런스 팔레트
BG     = C("#FBE7B0")   # 버터크림 배경
TOMATO = C("#E75E28")   # 오렌지-레드(단색)
CALYX  = C("#256B2E")   # 딥 그린(꼭지)

# 결정적 지터(손맛) — 반경/각도 미세 흔들림
RJ=[1.00,0.97,1.01,0.985,1.005,0.975,1.008,0.99,1.0,0.98,1.006,0.99,1.004,0.978,1.002,0.99,1.007,0.982,1.0,0.988]
AJ=[0.0,0.03,-0.02,0.025,-0.03,0.02,-0.015,0.028,-0.02,0.018,-0.025,0.02,-0.018,0.03,-0.02,0.015,-0.028,0.022,-0.02,0.024]

def tomato_body(cx, cy, Rx, Ry, n=20):
    pts=[]
    for i in range(n):
        a=-math.pi/2 + (i/n)*2*math.pi + AJ[i%len(AJ)]
        rf=RJ[i%len(RJ)]
        # 위쪽은 살짝 납작(꼭지 자리), 아래는 통통
        yb = 1.0 + (0.06 if math.sin(a)>0.3 else 0.0)     # 하단 약간 늘림
        yt = 1.0 - (0.05 if math.sin(a)<-0.4 else 0.0)    # 상단 약간 눌림
        x=cx+Rx*rf*math.cos(a)
        y=cy+Ry*rf*yb*yt*math.sin(a)
        pts.append((s(x),s(y)))
    return pts

def leaflet(d, cx, cy, ang, length, width, col):
    """손으로 오린 얇은 잎 하나(끝 뾰족, 밑동 넓음, 살짝 굽음)."""
    tip=(cx+length*math.cos(ang), cy+length*math.sin(ang))
    mid=(cx+length*0.55*math.cos(ang+0.06), cy+length*0.55*math.sin(ang+0.06))
    bl =(cx+width*math.cos(ang+1.7), cy+width*math.sin(ang+1.7))
    br =(cx+width*math.cos(ang-1.7), cy+width*math.sin(ang-1.7))
    d.polygon([(s(p[0]),s(p[1])) for p in (bl,mid,tip,br)], fill=col)

def build(name, bg=BG, tomato=TOMATO, calyx=CALYX):
    img=Image.new("RGBA",(W,W),bg); d=ImageDraw.Draw(img)
    cx,cy = W/SUP*0.5, W/SUP*0.52
    Rx,Ry = 330, 312
    # 바디
    d.polygon(tomato_body(cx,cy,Rx,Ry), fill=tomato)
    # 꼭지(칼릭스) — 상단 살짝 오른쪽, 얇은 잎 몇 갈래 + 스템(딥그린), 레퍼런스처럼 위·우로 뻗음
    kx,ky = cx+Rx*0.30, cy-Ry*0.86
    leaflet(d,kx,ky, math.radians(-108), 150, 26, calyx)   # 위-좌
    leaflet(d,kx,ky, math.radians(-72),  170, 28, calyx)   # 위-우
    leaflet(d,kx,ky, math.radians(-40),  150, 24, calyx)   # 우
    leaflet(d,kx,ky, math.radians(-150), 120, 22, calyx)   # 좌
    # 스템(위로 뻗은 얇은 줄기, 살짝 꺾임)
    d.line([(s(kx),s(ky)),(s(kx+18),s(ky-140)),(s(kx+40),s(ky-210))], fill=calyx, width=s(22), joint="curve")
    out=img.resize((S,S),Image.LANCZOS).convert("RGB")
    out.save(f"cut-{name}-1024.png"); out.resize((400,400),Image.LANCZOS).save(f"cut-{name}-400.png")
    print("wrote",name)

# 기본(레퍼런스 매칭) + 색 베리에이션
build("A-ref")                                  # 레퍼런스 톤
build("B-red",  tomato=C("#E24631"))            # 더 레드
build("C-deep", tomato=C("#D8532A"), calyx=C("#1F5D28"))  # 딥 오렌지-레드
build("D-cream-bg", bg=C("#F6EFDE"))            # 앱 캔버스 톤 배경
print("all done")
