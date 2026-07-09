#!/usr/bin/env python3
"""École Vision 느낌의 부드러운 매트(claymorphic) 토마토 — numpy 셰이딩 + Pillow.
둥근 유기적 형태 · 은은한 폼 라이트/AO림 · 소프트 하이라이트 · 소프트 접지 그림자 · 따뜻한 크림."""
import math, numpy as np
from PIL import Image, ImageDraw, ImageFilter

S=1600                      # 최종 해상도
def C(h): h=h.lstrip('#'); return np.array([int(h[0:2],16),int(h[2:4],16),int(h[4:6],16)],float)

# 팔레트(따뜻·플레이풀)
HI   =C("#F5794F")   # 하이라이트 존(웜 라이트)
MID  =C("#E4573A")   # 바디 중간
DEEP =C("#BE3B26")   # 그림자
RIM  =C("#9C3020")   # 가장자리 AO(림)
SPEC =C("#FFE4D2")   # 스펙큘러(부드러운)
CAL_HI=C("#7FC157"); CAL_MID=C("#4E9A3C"); CAL_D=C("#2E6E2C")
STEM =C("#6E5A34")
BG_I =C("#F7F0E2"); BG_O=C("#EADFCB")     # 크림 비네트
SHAD =C("#B79B78")

cx, cy = S*0.5, S*0.545     # 살짝 아래 배치(접지감)
Rx, Ry = S*0.315, S*0.285   # 가로가 더 넓은 토마토

# ---- 좌표 그리드 ----
yy, xx = np.mgrid[0:S, 0:S].astype(float)
nx = (xx-cx)/Rx; ny=(yy-cy)/Ry

# 유기적 실루엣: 기본 원 + 아주 완만한 로브(각도 변조) + 상단 중앙 부드러운 눌림
ang = np.arctan2(ny, nx)
lobe = 1.0 + 0.012*np.cos(3*ang)                              # 은은한 굴곡(과하지 않게)
top_dimple = 0.055*np.exp(-(nx/0.42)**2)*np.clip(-ny,0,1)**2  # 가우시안(하드 경계 없음)
rr = np.sqrt(nx*nx + ny*ny) / lobe + top_dimple
inside = rr <= 1.0

# ---- 폼 셰이딩(좌상단 광원) ----
# 구면 노멀 근사: z = sqrt(1-r^2)
z = np.sqrt(np.clip(1-rr*rr,0,1))
Lx,Ly,Lz = -0.45,-0.5,0.74                                    # 광원 방향(좌상단·앞)
Ln = math.sqrt(Lx*Lx+Ly*Ly+Lz*Lz); Lx,Ly,Lz=Lx/Ln,Ly/Ln,Lz/Ln
ndotl = np.clip(nx*Lx + ny*Ly + z*Lz, 0, 1)                   # 0~1
# 매트 확산(감마로 부드럽게) + 앰비언트
diff = 0.30 + 0.70*(ndotl**1.15)
# 색: DEEP→MID→HI 를 diff로 보간(2구간)
t = diff
col = np.empty((S,S,3))
lo = t<0.62
th = np.where(lo, t/0.62, (t-0.62)/0.38)[...,None]
col = np.where(lo[...,None], DEEP+(MID-DEEP)*th, MID+(HI-MID)*th)
# 가장자리 AO 림(rr가 1에 가까울수록 어둡게) — 매트 클레이 느낌
rim = np.clip((rr-0.72)/0.28,0,1)[...,None]
col = col*(1-0.30*rim) + RIM*(0.30*rim)

img = np.zeros((S,S,4))
img[...,:3] = col
img[...,3] = np.where(inside,255,0)

# ---- 소프트 스펙큘러(좌상단) — 매트하게 은은히 ----
sx,sy = cx-Rx*0.40, cy-Ry*0.46
sd = ((xx-sx)/(Rx*0.38))**2 + ((yy-sy)/(Ry*0.34))**2
spec = np.clip(1-sd,0,1)**1.8 * inside
tomato = Image.fromarray(img.astype('uint8'),'RGBA')
sp = Image.fromarray((np.dstack([np.ones((S,S))*SPEC[0],np.ones((S,S))*SPEC[1],
                                 np.ones((S,S))*SPEC[2],spec*95]).astype('uint8')),'RGBA')
sp = sp.filter(ImageFilter.GaussianBlur(S*0.02))
tomato = Image.alpha_composite(tomato, sp)

# ---- 칼릭스(통통한 둥근 잎 5갈래) + 스템 — 소프트 셰이드, 부드러운 가장자리 ----
def calyx_layer(base, hi, alpha=255):
    cal = Image.new('RGBA',(S,S),(0,0,0,0)); d=ImageDraw.Draw(cal)
    ccx,ccy = cx, cy-Ry*0.80
    def leaflet(a, ln, wd, col):
        tip=(ccx+ln*math.cos(a), ccy+ln*math.sin(a))
        # 통통하게: 밑변 넓게 + 중간 볼록 2점(둥근 삼각)
        p1=(ccx+wd*math.cos(a+1.9), ccy+wd*math.sin(a+1.9))
        p2=(ccx+ln*0.5*math.cos(a+0.5), ccy+ln*0.5*math.sin(a+0.5))
        p3=(ccx+ln*0.5*math.cos(a-0.5), ccy+ln*0.5*math.sin(a-0.5))
        p4=(ccx+wd*math.cos(a-1.9), ccy+wd*math.sin(a-1.9))
        d.polygon([p1,p2,tip,p3,p4], fill=tuple(col.astype(int))+(alpha,))
    for i in range(5):
        a=-math.pi/2 + i*(2*math.pi/5)
        leaflet(a, Ry*0.50, Ry*0.20, base)
    # 밝은 상단 하이라이트 잎(살짝 작게, 위쪽만)
    for i in range(5):
        a=-math.pi/2 + i*(2*math.pi/5)
        if math.sin(a) < 0.2:
            tip=(ccx+Ry*0.36*math.cos(a), ccy+Ry*0.36*math.sin(a))
            p1=(ccx+Ry*0.14*math.cos(a+1.9), ccy+Ry*0.14*math.sin(a+1.9))
            p4=(ccx+Ry*0.14*math.cos(a-1.9), ccy+Ry*0.14*math.sin(a-1.9))
            d.polygon([p1,tip,p4], fill=tuple(hi.astype(int))+(int(alpha*0.9),))
    d.ellipse([ccx-Rx*0.075,ccy-Ry*0.075,ccx+Rx*0.075,ccy+Ry*0.075], fill=tuple(CAL_D.astype(int))+(alpha,))
    # 짧은 둥근 스템 nub
    d.rounded_rectangle([ccx-S*0.012, ccy-Ry*0.30, ccx+S*0.012, ccy+S*0.005],
                        radius=S*0.012, fill=tuple(STEM.astype(int))+(alpha,))
    return cal
# 칼릭스 소프트 접지 그림자(토마토 표면에)
cal_sh = calyx_layer(CAL_D, CAL_D, alpha=90).filter(ImageFilter.GaussianBlur(S*0.012))
tomato = Image.alpha_composite(tomato, cal_sh)
cal = calyx_layer(CAL_MID, CAL_HI).filter(ImageFilter.GaussianBlur(S*0.0016))  # 살짝 소프트 엣지
tomato = Image.alpha_composite(tomato, cal)

# ---- 배경(크림 비네트) ----
d2 = np.sqrt((xx-cx)**2+(yy-cy)**2)/(S*0.72)
d2 = np.clip(d2,0,1)[...,None]
bg = (BG_I*(1-d2)+BG_O*d2).astype('uint8')
bg = np.dstack([bg, np.full((S,S),255,'uint8')])
canvas = Image.fromarray(bg,'RGBA')

# ---- 소프트 접지 그림자 ----
sh = Image.new('RGBA',(S,S),(0,0,0,0)); ds=ImageDraw.Draw(sh)
ds.ellipse([cx-Rx*0.92, cy+Ry*0.78, cx+Rx*0.92, cy+Ry*1.06],
           fill=tuple(SHAD.astype(int))+(150,))
sh = sh.filter(ImageFilter.GaussianBlur(S*0.028))
canvas = Image.alpha_composite(canvas, sh)
canvas = Image.alpha_composite(canvas, tomato)

canvas.convert('RGB').save('tomato-soft-cream.png')
# 투명 배경본(배치용)
tomato.save('tomato-soft-alpha.png')
# 미리보기 축소
canvas.convert('RGB').resize((400,400), Image.LANCZOS).save('tomato-soft-400.png')
print("done")
