# Reffi 디자인 시스템

> Reffi는 냉장고 속 재료가 버려지기 전에 "오늘 먹을 수 있게" 행동을 유도하는 앱이다.
> 그래서 이 시스템의 목표는 **식욕을 돋우고(appetizing), 명료하며(clear), 지금 행동하게 만드는(action-first)** 화면을 일관되게 찍어내는 것이다.
>
> 비주얼 언어는 무드보드 + 팀 "Reffie" 시스템에서 가져온다 — 따뜻한 크림 종이(Dusty Folk) 위의 **파스텔 색 블로킹**, 둥글고 친근한 형태, 지갑처럼 쌓이는 **카드 스택**. 장식적 테두리·그림자·이모지 대신 **색과 여백과 타이포의 위계**로 말한다.
>
> 메인 플로우의 **행동 표면**(재료·버튼·티켓)에는 그 위로 한 겹 — **손으로 자른 종이 + 리퀴드글래스 + 일러스트 + 통통 튀는 모션**(§13) — 을 더해 "지금 먹자"는 활기를 준다. 단, 이 레이어는 행동 표면에 한정하고 정보 표면(§2~§9)의 규율은 그대로 둔다.

---

## 1. 디자인 원칙 (Design Principles)

1. **색 = 신선도.** 색은 장식이 아니라 정보다. 재료의 남은 날짜(신선→임박→오늘)를 색으로 직결한다(§2.5). 단, **색만으로 의미를 싣지 않는다** — 항상 텍스트 라벨("D-2"·"오늘")을 함께 둔다.
2. **파스텔로, 화사하게.** 신선도 색(fresh/soon/urgent)은 부드럽고 밝은 **파스텔**이다. 네온·완전 채도의 디지털 컬러를 쓰지 않고, 칙칙해지지 않도록 명도를 높게 유지한다.
3. **납작하게, 색으로 나눈다.** 면을 구분할 때 보더를 쓰지 않는다. 배경 틴트(색-light)·뉴트럴·여백으로 블로킹한다. 그림자는 "떠 있는 요소"와 **카드 스택**에서만(§6).
4. **메인을 기본값으로.** 모든 브랜드 컬러는 main/dark/light 3종을 갖지만, 평소엔 **main만** 쓴다. dark/light는 §2.6의 대비 요건이나 hover/pressed 같은 *예외적인 경우*에만.
5. **카드 스택이 기본 레이아웃.** 재료 리스트는 지갑형 **카드 스택** 하나로 통일한다(§8). 두 번째 레이아웃 시스템(벤토 그리드 등)을 섞지 않는다.
6. **한 화면에 위계는 최대 3개, 브랜드 색도 최대 3색.** 타이포 위계(§3)와 브랜드 색을 각각 3개 이하로 제한한다.
7. **고아 단어 금지.** 모든 텍스트는 어절(단어) 경계에서만 줄바꿈하고, 마지막 줄에 단어 하나만 남기지 않는다(§3.3).
8. **이모지 금지 / 색 채운 아이콘 박스 금지.** 기능 아이콘은 SVG만(§7). 의미 전달은 컬러·타이포·아이콘으로.
9. **순백 배경·순흑 텍스트 금지.** 바탕은 크림(`neutral-50`), 잉크는 코코아(`neutral-900`).
10. **장식보다 행동.** 화면당 "지금 할 일"(오늘 먹기/조리하기)을 가장 분명하게.

> **보더 금지 / 이모지 금지 / 색박스 금지 / 색 단독 의미 금지**는 시스템 전역 규칙이다. 그림자는 §6의 예외(떠 있는 요소·카드 스택)에서만. 모션은 항상 `prefers-reduced-motion`을 존중한다(§7).

---

## 2. 컬러 (Color)

> 신선도 3색은 팀 "Reffie" 팔레트(Sage/Amber/Terracotta)를 **파스텔로 보정**해 가져왔고(Lilac은 제외), 네 번째 색은 **Reffi Blue**(레시피·AI·기본 액션). 뉴트럴은 Reffi 고유 크림 램프를 그대로 쓴다.

### 2.1 컬러 모델 — OKLCH
모든 색은 **OKLCH**(`oklch(L C H / a)`)로 표기·연산한다. 명도(L)가 지각적으로 균일해 위계·대비 계산이 정확하고, H를 고정한 채 L만 움직여 main → dark/light 변형을 만들기 쉽다. 파스텔 보정도 L↑·C 정돈으로 직관적. hex는 참고용 근삿값일 뿐 정본이 아니다.

**컬러 스킴.** 시맨틱 컬러 토큰은 전량 **라이트/다크 적응형**(`ReffiColor.dynamic(light:dark:)`)이다 — 앱은 `preferredColorScheme` 고정을 없애고 시스템 스킴을 그대로 따른다. 다크 컨셉·병기 토큰 표·측정 대비는 §2.8. **일러스트(FoodGlyph) 팔레트는 스킴과 무관한 고정색**이다(§13.3) — 음식 색이 스킴에 따라 바뀌면 재료 식별이 깨지므로 `ReffiColor.oklch()` 리터럴을 그대로 쓴다. 이 고정색 위에 **신선도에 따른 시듦(Wilt, §13.3)** — 채도·명도 감쇠 + 재질별 자세(처짐·퍼짐·꼭짓점 라운딩) — 이 얹히지만, 스킴과는 무관하게 라이트·다크 동일 배수로 적용된다(다크라고 더 빨리 시들지 않는다).

### 2.2 브랜드 컬러 (4) — 각 main / dark / light
팀 색의 칙칙함(중간 명도 + 탁한 채도)을 **명도를 올리고 채도를 높여** 화사한 파스텔로 바꿨다. (원본 → 보정: Sage `oklch(78.8% 0.110 116)` → `oklch(86% 0.12 136)` / Amber `oklch(78.8% 0.119 82)` → `oklch(85% 0.125 84)` / Terracotta `oklch(61.2% 0.154 36)` → `oklch(75% 0.135 36)`. 명도는 유지하되 채도를 올려 더 선명하게 — 네온은 금지라 sRGB 게이머트 안쪽으로.)

| 토큰 | 역할 | main (파스텔) | dark (딥 앵커) | light (틴트) |
|---|---|---|---|---|
| **Fresh** (Sage) | 신선 · 여유 (D-4+) | `oklch(86% 0.12 136)` `#ADE393` | `oklch(50% 0.115 142)` `#387332` | `oklch(95% 0.040 132)` `#E5F5D9` |
| **Soon** (Amber) | 곧 · 임박 (D-3~1) | `oklch(85% 0.125 84)` `#F4C767` | `oklch(53% 0.120 71)` `#965D00` | `oklch(95% 0.045 84)` `#FDEDCD` |
| **Urgent** (Terracotta) | 오늘 · 지남 (D-0-) | `oklch(75% 0.135 36)` `#F68D70` | `oklch(52% 0.150 32)` `#AE3F2C` | `oklch(93% 0.050 33)` `#FFDDD3` |
| **Blue** (Reffi) | 브랜드 · 레시피/AI · 기본 액션 | `oklch(51.4% 0.134 249.8)` `#176AB0` | `oklch(40% 0.12 250)` `#004985` | `oklch(93% 0.045 250)` `#D2EBFF` |

- **main** = 기본. 신선도 3색은 **파스텔 면**(카드·칩)으로 쓰고 그 위 글자는 **ink**(§2.6). Blue main은 딥 톤이라 그 위 글자는 **흰색**.
- **dark** = 딥 앵커. 캔버스 위 색-as-텍스트, 흰 글자 얹는 솔리드 버튼, 긴급 강조, hover/pressed.
- **light** = 가장 옅은 틴트. 배너·보조 면, 위에는 ink 텍스트.
- 위 표는 **라이트 스킴** 값이다(다크 스킴에서 각 토큰이 어떻게 바뀌는지는 §2.7·§2.8). `soonDark`는 다크 팔레트 도입 측정에서 라이트 값도 `54% → 53%`로 미세 조정했다(soonDark on soonLight 대비가 4.48로 4.5 미달 → L −0.01로 4.67 확보, §2.8 대비표).

### 2.3 뉴트럴 (5단계) — Reffi 고유, 라이트/다크 적응형
크림빛 무드보드에 맞춘 H≈80–90의 따뜻한 회색 램프. 팀의 다층 뉴트럴 대신 **이 5단계를 그대로** 쓴다(순백/순흑을 피하는 Dusty Folk 톤과도 합치). **램프 자체(토큰 구성·용도)는 변경 없음** — 다만 각 토큰이 이제 `ReffiColor.dynamic(light:dark:)`로 라이트/다크 두 값을 갖는다. 다크에서 램프가 **뒤집힌다**: ink(글자)는 크림으로 밝아지고 canvas/sub(면)는 웜 차콜로 어두워진다 — 컨셉·원칙은 §2.8.

| 토큰 | 용도 | 라이트 | 다크 |
|---|---|---|---|
| `neutral-900` (ink) | 본문/제목 텍스트 | `oklch(25% 0.012 80)` `#25211B` | `oklch(93% 0.010 85)` `#EBE7E0` |
| `neutral-700` (ink2) | 보조 텍스트 · 캡션 | `oklch(43% 0.014 80)` `#544F47` | `oklch(76% 0.012 82)` `#B5B0A9` |
| `neutral-500` (muted) | 약한 텍스트 · placeholder | `oklch(56% 0.013 80)` `#78746C` | `oklch(60% 0.012 80)` `#848078` |
| `neutral-200` (sub) | 서브 면 · 스켈레톤 · 약한 구분 | `oklch(93.5% 0.008 85)` `#ECE9E4` | `oklch(30% 0.008 80)` `#302D29` |
| `neutral-50` (canvas) | **Canvas** · 페이지 배경 | `oklch(97% 0.012 90)` `#F8F5EC` | `oklch(21.5% 0.010 78)` `#1C1914` |

### 2.4 60 : 30 : 5 : 5 운용 비율 (페이지당)
| 비율 | 영역 | 색 |
|---|---|---|
| **60%** | 바탕 — 캔버스 + 본문/제목 텍스트 | `neutral-50` + `neutral-900/700` |
| **30%** | 주조 색 — 그 화면을 지배하는 색. 카드 스택 화면에선 **신선도 파스텔 군(群)** | Fresh/Soon/Urgent (최대 3색) |
| **5%** | 액션 / AI — 기본 버튼·레시피 추천 | **Blue** |
| **5%** | 단일 강조 — 그 화면에서 가장 급한 것(맨 위 카드·"오늘") | **Urgent**(또는 해당 색의 dark) |

- **신선도 색은 신선도에만.** 일반 액션·정보·AI는 신선도와 무관한 **Blue**로 분리해 의미 혼선을 막는다.
- 한 화면 브랜드 색 ≤ 3 (원칙 6). 카드 스택은 보통 인접 신선도 2~3색의 그라데이션으로 채워진다.

### 2.5 카운트다운 → 색 매핑
앱의 핵심인 "버리기 전에 먹기"를 색으로 직결한다. **항상 색 + 텍스트 라벨**을 함께(색 단독 금지, §2.6).

| 남은 일수 | 상태 | 색 |
|---|---|---|
| D-4 이상 | 신선 · 여유 | **Fresh** (Sage 파스텔) |
| D-3 ~ D-1 | 곧 먹어야 | **Soon** (Amber 파스텔) |
| D-0 / 지남 | 오늘 · 초과 | **Urgent** (Terracotta 파스텔) |
| — | 레시피 · AI 추천 | **Blue** |

**UI 표기.** 이 매핑을 리스트로 보일 땐 **색을 점(dot)에만 main으로** 포인트로 준다. 행 면은 **뉴트럴(`neutral-200`)**, 라벨·메타 텍스트는 **뉴트럴(ink / `neutral-700`)** 로 둔다(틴트 면·색 텍스트 미사용). 상태 의미는 **텍스트 라벨**("D-4+ · Fresh" 등)이 전달하므로 dot은 장식 포인트다 — 그래서 dark가 아닌 **main**을 쓴다(§2.6 예외).

> **행동 표면 예외(§13.3).** 메인의 떨어지는 재료 일러스트는 **재료의 실제 색**(자연색, hue 고정)을 베이스로 쓴다 — 색상(hue)을 신선도색으로 갈아끼우는 코딩은 하지 않으므로, 신선도의 확정 신호는 여전히 뱃지 인디케이터 바·D-N 텍스트다. 다만 그 자연색 위에 **신선도에 따라 시듦(Wilt)** 이 얹힌다 — 채도·명도가 낮아지고 밑변 가운데를 축으로 숙으며 각이 무뎌진다 — 다만 **얼마나 무너지는지는 재질이 정한다**(캔·갑·병은 색만 바래고 형태는 그대로, 정확한 값은 §13.3 두 표). 즉 일러스트는 완전히 신선도-무관이 아니라 "정체성 색은 불변, 생기만 감쇠"하는 2차 신호다. 정보 표면(카드 스택 등)은 위 규칙(색=신선도) 그대로.

### 2.6 대비(접근성) 규칙 — *팀 시스템의 약점을 메운 핵심*
팀 시스템에서 아쉬웠던 **글자·배경 대비**를 측정 기반으로 다시 짠다. 모든 값은 실측 WCAG 대비. **다크 모드에도 동일 요구치**(본문 ≥4.5 / 큰글자 ≥3 / 비텍스트 ≥3)를 그대로 적용한다 — 스킴이 바뀐다고 기준을 낮추지 않는다. 다크 실측표는 §2.8.

**텍스트 대비 (본문 4.5 / 큰글자 3)**

| 면(배경) | 권장 텍스트 | 대비 | 판정 |
|---|---|---|---|
| `neutral-50` 캔버스 | `neutral-900` / `neutral-700` | 14.68 / 7.44 | AAA / AAA |
| `neutral-50` 캔버스 | `neutral-500` | 4.27 | AA-large만(≥24px·장식) |
| **Fresh** main | **ink** | **10.84** | AAA |
| **Soon** main | **ink** | **10.06** | AAA |
| **Urgent** main | **ink** | **6.84** | AA+ |
| **Blue** main | **white** | **5.65** | AA (ink는 2.84 **금지**) |
| 각 색-light 틴트 | **ink** | 12.57 ~ 13.99 | AAA |
| 각 색-dark 솔리드 | **white** | fresh 5.72 · soon 5.41 · urgent 5.92 · blue 9.18 | AA+ |
| 캔버스 위 색-as-텍스트 | 각 색-**dark** | fresh 5.24 · soon 4.96 · urgent 5.43 · blue 8.42 | AA+ |

**비-텍스트 대비 (면 경계·아이콘·점, 3:1)**

| 캔버스 위 요소 | 대비 | 판정 |
|---|---|---|
| Fresh / Soon / Urgent **main** 면 경계 | 1.35 / 1.46 / 2.15 | ✗ — 파스텔은 크림과 명도차가 작다 |
| Blue main | 5.18 | ✓ |
| `neutral-200` 서브 면 경계 | 1.11 | ✗ |

정리 (가드레일):
- **따뜻한 파스텔(Fresh·Soon·Urgent) 면 위 글자 = ink.** 흰 글자 금지(파스텔이라 대비 부족).
- **Blue 면 위 글자 = white.** ink 금지(블루는 딥 톤).
- **캔버스 위에 색을 글자·세선·작은 점으로 쓸 땐 반드시 그 색의 dark 변형.** (전부 ≥4.5 / 비텍스트 ≥3 충족)
  - **예외:** 옆에 **텍스트 라벨이 함께 있는 장식용 점(dot)** 은 뉴트럴 면 위에 **main**을 포인트로 쓸 수 있다(예: 카운트다운 매핑 리스트, §2.5). 의미는 라벨이 전달하고 dot은 강조 포인트이므로 비-텍스트 3:1을 적용하지 않는다. 색이 **단독으로** 의미를 지는 마크일 때만 dark(≥3:1)를 지킨다.
- **파스텔 카드/면의 경계는 색만으로 표현하지 않는다.** 크림 캔버스와 명도차(1.4~2.2:1)가 부족하므로, 경계는 **카드 스택 그림자(§6.3)·여백·라벨**로 만든다.
- **불투명도로 글자색을 만들지 않는다.** (팀의 "라벨 72% opacity" 같은 처리 금지 — `neutral-700` 솔리드로.)
- 캡션/작은 본문은 `neutral-700` 이상. `neutral-500`은 큰 텍스트·비필수 장식만. 포커스/링크 기능 색은 Blue.

### 2.7 컬러 토큰 — 라이트/다크 전량
> CSS 커스텀 프로퍼티 형태는 §12 통합 `:root`. 여기는 **모든 시맨틱 토큰의 라이트/다크 OKLCH 값**(L / C / H)을 한 표로 모은 정본이다 — 신규 토큰 4개(`receipt`·`shadowTint`·`toast`·`onInk`) 포함. 조정 사유가 있는 행만 비고에 적는다.

| 토큰 | 라이트 | 다크 | 비고 |
|---|---|---|---|
| `fresh` | .86 / .120 / 136 | .42 / .075 / 138 | |
| `freshDark` | .50 / .115 / 142 | .74 / .105 / 140 | |
| `freshLight` | .95 / .040 / 132 | .30 / .035 / 136 | |
| `soon` | .85 / .125 / 84 | .44 / .080 / 82 | |
| `soonDark` | **.53** / .120 / 71 | .78 / .110 / 76 | 라이트 L .54→.53(§2.2 각주) |
| `soonLight` | .95 / .045 / 84 | .31 / .038 / 82 | |
| `urgent` | .75 / .135 / 36 | .45 / .095 / 34 | |
| `urgentDark` | .52 / .150 / 32 | .74 / .130 / 34 | |
| `urgentLight` | .93 / .050 / 33 | .30 / .042 / 33 | |
| `blue` | .514 / .134 / 249.8 | **.56** / .115 / 250 | 다크 L 상한 .565(white on blue 4.5:1) — .58은 4.27로 미달 |
| `blueDark` | .40 / .12 / 250 | .76 / .095 / 250 | |
| `blueLight` | .93 / .045 / 250 | .30 / .045 / 250 | |
| `ink` (neutral-900) | .25 / .012 / 80 | .93 / .010 / 85 | |
| `ink2` (neutral-700) | .43 / .014 / 80 | .76 / .012 / 82 | |
| `muted` (neutral-500) | .56 / .013 / 80 | .60 / .012 / 80 | |
| `sub` (neutral-200) | .935 / .008 / 85 | .30 / .008 / 80 | |
| `canvas` (neutral-50) | .97 / .012 / 90 | .215 / .010 / 78 | |
| `paper` | .99 / .006 / 90 | .285 / .008 / 82 | |
| `paperPass` | .95 / .016 / 90 | .255 / .010 / 84 | |
| **`receipt`** (신규) | .985 / .004 / 90 | .29 / .007 / 83 | 인라인 `oklch(0.985,0.004,90)` 13곳의 정본 토큰화 |
| **`shadowTint`** (신규) | .25 / .012 / 80 (= 라이트 ink 고정) | 0 / 0 / 0 (순검정) | 그림자 전용. `ink`는 다크에서 크림으로 뒤집히므로 그림자엔 항상 이 토큰 |
| **`toast`** (신규) | .25 / .012 / 80 (= 라이트 ink) | .33 / .010 / 80 | 양 모드 어두운 면(잉크 캡슐 토스트). 위 텍스트는 고정 `.white`(§2.8) |
| **`onInk`** (신규) | 흰색 (L 1 / C 0) | .22 / .010 / 78 | `ink`로 채운 면 위 콘텐츠 전용 |
| **`toastAction`** (신규) | .90 / .05 / 250 | (고정, 비적응) | `toast` 위 액션 라벨(Undo) 전용. 면이 양 모드 어두워 적응 불필요 — "toast 위 텍스트 고정" 규칙의 액션 변형(실측 대비 라이트 11.92 · 다크 9.11) |
| `paperEdgeOnFill` | white α .14 | white α .10 | |
| `bgSheen` | white α .22 | white α .045 | |
| `scrim` | ink 틴트 α .22 | 순검정 α .55 | 다크는 아래 면이 이미 어두워 ink 틴트로 안 먹혀 순검정으로 |

**다크 대비 실측표(§2.8)** 는 위 표의 값으로 계산한 WCAG 대비다 — 추정치가 아니라 `oklch→sRGB→상대휘도→대비비` 스크립트 실측.

### 2.8 다크 모드 — "밤의 주방 패스"

**컨셉.** 다크는 라이트를 반전한 흑백이 아니라 **"밤의 주방 패스"** — 크림 종이가 조명 낮은 주방에서 보이는 웜 차콜(hue 78~90 유지)이다. **순검정(`#000`) 면은 쓰지 않는다** — 캔버스·종이·서브 면은 전부 hue가 살아 있는 어두운 크림 톤이고, 순검정은 `shadowTint`(그림자)와 `scrim`(모달 딤)에만 예외적으로 등장한다(둘 다 "빛이 없는" 레이어라 온기가 필요 없다).

**원칙.**
- **시맨틱 토큰만 적응한다.** 브랜드 4색(§2.2/§2.7)·뉴트럴 5단계(§2.3)·신규 4종(`receipt`·`shadowTint`·`toast`·`onInk`)이 전부 `ReffiColor.dynamic(light:dark:)`로 라이트/다크 두 값을 가진다.
- **일러스트 팔레트는 고정.** `FoodGlyph`(§13.3)의 자연색은 스킴 불변 — 음식 색이 다크에서 바뀌면 재료 식별이 깨진다. 단, 실루엣 디테일 중 `ReffiColor.ink`를 직접 쓰던 곳(눈·패싯 등)은 다크에서 크림으로 뒤집혀 실루엣이 망가지므로 **`oklch(0.25, 0.012, 80)` 고정값**으로 박아 넣는다 — `ink` 토큰이 아니라 리터럴을 쓰는 것 자체가 "일러스트는 스킴 불변" 원칙의 적용이다. 신선도에 따른 시듦(Wilt, §13.3)도 이 원칙을 따른다 — 채도·명도 배수와 재질별 형태 값은 스킴과 무관한 순수 상수라 라이트·다크에서 동일하게 적용된다.
- **공유 카드는 라이트 고정.** `ImageRenderer`로 굽는 뷰(레시피 공유 카드 등)는 항상 밝은 카드로 내보낸다 — SNS에 다크 스킴 그대로 캡처된 카드가 배포되면 맥락 없이 읽기 어렵다. `ImageRenderer` 콘텐츠는 `.environment(\.colorScheme, .light)`를 명시해야 이 원칙이 지켜진다(명시하지 않으면 항상 라이트로 렌더되긴 하나, 의도를 코드로 남기는 쪽을 권장).
- **그림자는 항상 `shadowTint`.** `ink` 위에 그림자를 얹으면 다크에서 밝은 글로우가 되므로, `ReffiElevation`(§6.2/§6.3)과 콜사이트의 모든 `.shadow(color:)`는 예외 없이 `shadowTint`를 쓴다.
- **`paperEdge` 헤어라인의 반전은 의도적으로 둔다.** 종이 단면 헤어라인(`--paper-edge`, §13.1)은 `ink` 틴트라 다크에서 밝은 헤어라인으로 뒤집히는데, 이건 버그가 아니라 "종이 두께"를 다크에서도 표현하는 의도된 결과다 — 별도 다크 변형을 만들지 않는다.

**라이트/다크 병기 토큰 표** — §2.7의 표가 정본이다(중복 게재하지 않음). 브랜드 4색·뉴트럴 5단계·신규 4종·paper 계열이 전부 그 표에 있다.

**다크 대비 실측표.** `python3` 로 OKLCH → sRGB → 상대휘도 → WCAG 대비비를 계산한 실측값(추정 아님). 요구치는 §2.6과 동일(본문 ≥4.5 / 큰글자 ≥3 / 비텍스트 ≥3, 로고·헤딩류는 AAA ≥7 지향).

| 항목 | 요구 | 라이트 | 다크 |
|---|---|---|---|
| ink on canvas | ≥7.0 | 14.68 | 14.26 |
| ink on paper | ≥7.0 | 15.56 | 11.68 |
| ink on receipt | ≥7.0 | 15.33 | 11.49 |
| ink on paperPass | ≥7.0 | 13.84 | 12.83 |
| ink2 on canvas | ≥4.5 | 7.44 | 8.16 |
| muted on canvas | ≥3.0 | 4.27 | 4.44 |
| freshDark on canvas | ≥4.5 | 5.24 | 7.89 |
| freshDark on freshLight | ≥4.5 | 5.00 | 6.07 |
| soonDark on canvas | ≥4.5 | 4.96 | 8.64 |
| soonDark on soonLight | ≥4.5 | 4.67 | 6.51 |
| urgentDark on canvas | ≥4.5 | 5.43 | 7.23 |
| urgentDark on urgentLight | ≥4.5 | 4.65 | 5.71 |
| blueDark on canvas | ≥4.5 | 8.42 | 8.21 |
| blueDark on blueLight | ≥4.5 | 7.46 | 6.37 |
| white on blue | ≥4.5 | 5.65 | 4.64 |
| ink on fresh main | ≥4.5 | 10.84 | 6.68 |
| ink on soon main | ≥4.5 | 10.06 | 6.37 |
| ink on urgent main | ≥4.5 | 6.84 | 6.33 |
| onInk on ink | ≥7.0 | 16.01 | 14.09 |
| (참고) white on toast | ≥4.5 | 16.01 | 12.22 |
| (참고) ink on sub | ≥7.0 | 13.22 | 11.10 |
| (참고) ink2 on receipt | ≥4.5 | 7.77 | 6.57 |
| (참고) muted on receipt | ≥3.0 | 4.46 | 3.57 |

- **`white on toast`가 정답이다 — `onInk on toast`는 쓰지 않는다.** `toast`는 양 모드 모두 어두운 면이라 그 위 콘텐츠는 고정 `.white`가 맞다(다크 12.22:1). `onInk`(다크에서 L .22, 어두운 색)를 얹으면 1.42:1로 깨진다. `onInk`는 **`ink`로 채운 면 위에서만**(다크에서 ink가 크림으로 뒤집히는 면) 쓴다.
- 에셋 다크 sRGB(실측 변환): `AccentColor` dark = `#3978B5`(blue 다크 .56) · `LaunchBackground` dark = `#1C1914`(canvas 다크).

---

## 3. 타이포그래피 (Typography)

> **폰트만** 바꾸고, 위계·크기·행간·자간·반응형 등 **타이포 시스템은 Reffi 것을 그대로** 유지한다.

### 3.1 서체
- **Display = Story Script** — Google Fonts 스크립트(브러시) 서체. 브랜드 모먼트(워드마크·온보딩·표지 타이틀)의 영문 디스플레이에만. **라틴 전용·단일 weight 400**(아래 확인 결과). 한글 디스플레이는 **Pretendard Bold**로 폴백.
- **그 외 위계(Heading·Subhead·Body·Caption)**: **한글 = Pretendard**, **영문/숫자 = Google Sans Flex**. 스택 맨 앞에 GSF를 두면 라틴은 GSF, 한글은 글리프 부재로 Pretendard로 렌더된다.

> **확인 결과(2026-05, Google Fonts CSS API 직접 검증):**
> - **Story Script** — 서브셋 `latin / latin-ext / vietnamese`, 한글(U+AC00–) **없음**, weight **400 단일**. → 디스플레이는 영문 브랜드용, 한글은 Pretendard.
> - **Google Sans Flex** — 서브셋에 `korean` 및 한글 범위 **없음**. → 한글은 Pretendard 담당.
> - (이전 안의 SUIT 폴백은 이번 지시에 따라 **Pretendard로 대체**.)

```css
--font-display: "Story Script", "Pretendard Variable", Pretendard, "Apple SD Gothic Neo", system-ui, cursive;
--font:         "Google Sans Flex", "Pretendard Variable", Pretendard, -apple-system, "Apple SD Gothic Neo", system-ui, sans-serif;
```
```html
<link href="https://fonts.googleapis.com/css2?family=Story+Script&family=Google+Sans+Flex:wght@400..700&display=swap" rel="stylesheet" />
<!-- Pretendard: cdn.jsdelivr.net/gh/orioncactus/pretendard 등에서 로드 -->
```
- **메트릭 보정**: Pretendard·GSF의 x-height·기준선이 달라 한·영 혼용 줄이 어긋나면 `@font-face`의 `size-adjust`/`ascent-override` 또는 `font-size-adjust`로 맞춘다.
- **Story Script 예외**: 스크립트·단일 weight라 Display는 **weight 400**, 자간은 **0(normal)** 로 둔다(연결 글자라 음수 트래킹 부적합). 한글 폴백(Pretendard)일 때만 700.
- **iOS 구현 주의**: SwiftUI(`ReffiTextRole`)는 UI 텍스트(Heading·Subhead·Body·Caption)를 **Pretendard 단일 패밀리**로 렌더한다(라틴 포함). 데이터성 숫자만 Google Sans Flex(`reffiNum`, §3.4). 즉 라틴=GSF 규칙은 **웹 쇼케이스 한정**이고, 앱은 Pretendard로 통일한다(혼용 줄 어긋남 방지).

### 3.2 위계 (5단계) — 시스템 동일
역할은 4개(**Display · Heading · Body · Caption/Label**)이며, Heading을 크기 2단(**Heading / Subhead**)으로 나눠 **총 5위계**. **행간**: Display·Heading·Subhead = 120% / Body·Caption = 140%. **자간**: Display·Heading·Subhead·Body = −1% / Caption = +1% (단 Story Script Display는 0, §3.1).

#### 데스크탑/태블릿 (≥1200px) — 최소 16px
| 위계 | size | line-height | letter-spacing | weight |
|---|---|---|---|---|
| Display | 48px | 1.2 (57.6px) | −0.01em* | 700 / *Story Script 400 |
| Heading | 32px | 1.2 (38.4px) | −0.01em | 700 |
| Subhead | 22px | 1.2 (26.4px) | −0.01em | 600 |
| Body | 18px | 1.4 (25.2px) | −0.01em | 400 |
| Caption / Label | **16px** | 1.4 (22.4px) | **+0.01em** | 500 |

#### 모바일 (<1200px) — 최소 14px
| 위계 | size | line-height | letter-spacing | weight |
|---|---|---|---|---|
| Display | 34px | 1.2 (40.8px) | −0.01em* | 700 / *Story Script 400 |
| Heading | 24px | 1.2 (28.8px) | −0.01em | 700 |
| Subhead | 18px | 1.2 (21.6px) | −0.01em | 600 |
| Body | 16px | 1.4 (22.4px) | −0.01em | 400 |
| Caption / Label | **14px** | 1.4 (19.6px) | **+0.01em** | 500 |

> 태블릿은 데스크탑 시스템을 그대로 따른다(§9). Body·Caption은 2px 차이뿐이므로 **위계 구분은 weight·색(ink↔neutral-700)으로 함께** 준다.

### 3.3 운용 규칙
- **화면당 위계 ≤ 3.** 예: Heading + Body + Caption. Display는 표지/온보딩/빈 상태에서 단독 주인공으로.
- **화면당 텍스트 계층 상한: 7종.** 표면 종류와 무관한 **단일 상한**이다 — §3.2 5단계와 §3.5 보조 스케일 중 한 화면에 실제 렌더되는 서로 다른 처리를 모두 합쳐 7종을 넘기지 않는다. 한 화면에 인접한 텍스트가 서로 구분 안 될 만큼 촘촘한 계단을 쌓지 않는다.
  옛 규칙은 "정보 표면 4 · 행동 표면 7" 이원 상한이었지만, 표면 구분의 전제(§3.5는 행동 표면에만 쓴다)가 출하 코드에서 이미 무너져 있었고(냉장고 리스트·설정·전역 탭바가 모두 보조 role을 쓴다) 위반이 예외가 아니라 기본값이면 상한 자체가 강제력을 잃는다. 코드를 정본으로 인정하고 상한을 하나로 합쳤다.
- **줄바꿈은 어절 경계에서만, 고아 단어 금지.**
  ```css
  word-break: keep-all;     /* 한글: 어절(공백) 경계에서만 줄바꿈 */
  overflow-wrap: anywhere;  /* 컨테이너를 넘는 초장문 토큰만 예외 분절 */
  text-wrap: pretty;        /* 마지막 줄 단어 1개(orphan) 방지 */
  ```
  짧은 제목은 `text-wrap: balance`. 그래도 고아가 생기면 끊지 말 두 단어 사이에 `&nbsp;`.
- **이모지 금지**(별도 지정 시 제외).

### 3.4 숫자 (Numerals)
소비기한·D-day·수량·날짜가 화면을 채우므로 **데이터성 숫자는 고정폭(tabular)·라이닝**으로. (팀 시스템도 동일 규칙.)
```css
.num { font-variant-numeric: tabular-nums lining-nums; font-feature-settings: "tnum" 1, "lnum" 1; }
```
- **숫자 스케일은 3단뿐이다**(`ReffiNumScale`) — `hero` 32(화면당 하나뿐인 주지표) · `body` 15(본문·리스트 행과 나란한 값) · `meta` 12(칩·푸터·카운트 등 보조 수치). 사이즈를 자유 파라미터로 두었더니 호출부가 옆 텍스트에 맞춰 매번 즉흥 결정해 11·12·13·14·15·16·17·32 여덟 종이 유통됐고, 숫자 계열에만 위계가 없었다. 예외는 **컴포넌트가 크기를 파라미터로 받는 경우**뿐이고(`DDayStamp` → `Font.reffiStamp(size:)`), 그 탈출구는 도장 계열 하나로 한정한다.
- 의무: D-day 라벨, 수량·날짜, 카운트다운, 표/대시보드 수치. 문장 속 숫자는 비례숫자(기본). D-day 도장(`DDayStamp`)은 Pretendard Bold 계열이라 `tnum`이 없어 `.monospacedDigit()`을 붙인다 — 자릿수가 바뀔 때 도장 폭이 흔들리지 않게.
- **D-day 표기는 앱 전역 한 포맷터에서만 나온다** — `Ingredient.dDayText`(`Overdue` / `Today` / `Nd`). 온보딩 데모·장식 티켓도 예외 없이 이 포맷터를 타고, 색도 같은 `Freshness(daysLeft:)`에서 파생시킨다. 화면마다 표기를 손으로 적으면 온보딩이 가르친 표기("D-2")를 본 앱이 한 번도 쓰지 않는 일이 실제로 생긴다.
- **수치는 로케일 포맷터(`FormatStyle`)로 만든다** — `String(format:)`·문자열 접합은 로케일을 타지 않아 소수 구분자를 항상 마침표로 찍고 그룹 구분자를 빼먹는다. 수량은 `value.formatted(.number.precision(.fractionLength(0...1)))`(`Quantity.text`), 비율은 `.formatted(.percent)`(퍼센트 기호 위치·간격도 로케일이 정한다), 날짜는 `.formatted(date:time:)`. **숫자와 단위 사이는 줄바꿈 없는 공백**(`\u{00A0}`)으로 묶어 행 끝에서 "300"과 "g"가 갈라지지 않게 한다.

### 3.5 보조 스케일 — §3.2 5단계 밖, 9종

§3.2의 5단계(Display~Caption)가 문서 위계라면, 여기 9종은 **컴포넌트 위계**다 — 라벨·크롬·칩·리스트 항목처럼 문장이 아니라 부품에 붙는 글자를 다룬다. **표면을 가리지 않는 공통 스케일**이고, 화면당 총량은 §3.3의 단일 상한(≤7)이 잡는다. iOS 구현은 `ReffiActionRole`(`ReffiTypography.swift`) — `ReffiTextRole`과 동일 패턴(`reffiType(_:)` 오버로드)으로 폰트·자간을 role에 내장한다.

> 옛 문구는 "행동 표면 전용 · 정보 표면에는 쓰지 않는다"였다. 그러나 `sectionLabel`·`monoEyebrow`·`metaText`·`checklistItem` 네 종은 냉장고 리스트·프로필 설정·전역 탭바에서 **이미 기본값**으로 쓰이고 있었고(코드 정본 원칙), 지킬 수 없는 경계는 상한 규칙까지 무력화한다. 이 네 종을 공통 보조 스케일로 승격하고 표면 구분 문구를 삭제했다.

**용도가 겹치는 두 쌍은 아래 기준으로 가른다.**

| 갈림길 | 쓰는 쪽 | 기준 |
|---|---|---|
| `caption`(14) vs `metaText`(13) | `caption` | **문장형 메타** — 부제·설명·안내처럼 읽는 문장(§3.2 위계의 막내) |
| | `metaText` | **데이터형 메타** — "35 min · 4 to use", 라벨=값, 타임스탬프처럼 훑는 값 |
| `monoTicketLabel`/`monoEyebrow`/`sectionLabel` | 셋 다 | **번역하지 않는 라틴 크롬 전용**(verbatim). 올캡·광자간이 시각 문법인데 한글엔 대문자가 없어, 번역되는 라벨에 쓰면 `.uppercased()`가 no-op이 되고 10~11pt에 자간만 남는다 |
| | 대신 `caption` | 번역되는 섹션 라벨(취향·가구 인원·알림·자주 쓰는 재료 등)은 `caption`으로 내린다 |

| role | 스펙 (family·size·tracking·relativeTo) | 용도 |
|---|---|---|
| `monoTicketLabel` | Pretendard Bold 13 / 자간 2.5 / `.caption` | **티켓 위 인쇄 크롬 전부** — 크라운 행("ORDER · REFFI KITCHEN"·"ORDER · FIRED") + 번호("#NN") + "ON THE TICKET". 한 티켓의 크롬은 한 role·한 크기이고 **색(ink ↔ ink2)으로만** 갈린다 |
| `monoEyebrow` | Pretendard Bold 10 / 자간 1.6 / `.caption2` | 초소형 올캡 라벨 — "MORNING ALERTS"·"COOKING NOW"·"REFFI · KEEP IT FRESH"(영수증 푸터) |
| `sectionLabel` | Pretendard SemiBold 11 / 자간 1.4 / `.caption2` | 섹션 라벨 — "RECIPE"·"INGREDIENTS"·"ITEM"·"DETAILS"(폼·영수증 명세) |
| `menuName` | Pretendard Bold 26 / 자간 −0.3 / `.title2` | 티켓·레시피 메뉴명 |
| `metaText` | Pretendard Medium 13 / `.caption` | **데이터형 메타** — 시간·개수·타임스탬프·판정 키커. 문장형 메타는 `caption`(14) |
| `pillLabel` | Pretendard SemiBold 13 / `.caption` | 필/버튼 라벨 — Undo·Add·Skip·Turn on·Later |
| `badgeLabel` | Pretendard SemiBold 15 / 자간 −0.15 / `.subheadline` | 뱃지·아이콘버튼·칩 라벨(`PaperIconButton`·`IngredientBadge`·`AddBadge`) |
| `checklistItem` | Pretendard SemiBold 16 / `.body` | 체크리스트·재료 리스트 항목명 |
| `stampLabel` | Pretendard Bold 34 / 자간 3 / `.largeTitle` | START 등 도장 텍스트(고정 34pt) |

`DDayStamp`처럼 같은 문법을 **가변 크기**로 재사용하는 컴포넌트는 role이 아니라 `Font.reffiStamp(size:relativeTo:)`(=Pretendard Bold, `reffiNum`과 동일한 파라미터화 패턴)를 쓴다 — `stampLabel`은 그 34pt 고정 인스턴스다.

---

## 4. 스페이싱 & 곡률 (Spacing & Radius)

### 4.1 스페이싱 스케일 (타이포 기준, px)
`6 · 8 · 12 · 16 · 24 · 28 · 32`

| 토큰 | px | 주 용도 |
|---|---|---|
| `space-1` | 6 | 아이콘-텍스트 간격, 칩 내부 |
| `space-2` | 8 | 작은 요소 간격, 모바일 거터, 인접 터치 타깃 간격 |
| `space-3` | 12 | 인풋/버튼 내부 패딩 |
| `space-4` | 16 | 기본 간격, 모바일 마진 |
| `space-5` | 24 | 카드 패딩, 데스크탑 거터, 섹션 내 간격 |
| `space-6` | 28 | 넓은 패딩 |
| `space-7` | 32 | 섹션 간 분리 |

> `6`은 4-그리드의 의도적 예외(칩/아이콘 미세 간격), `28`은 4×7로 그리드 위반은 아니다.

### 4.2 곡률 (스페이싱에 종속)
곡률은 고정값이 아니라 **요소의 내부 패딩(스페이싱)에 맞춰 변한다.**

| 토큰 | radius | 적용 |
|---|---|---|
| `radius-xs` | 6 | 칩·태그·D-day 배지 |
| `radius-sm` | 8 | 보조 컨트롤 |
| `radius-md` | 12 | 버튼(표준)·인풋·미니 카드 |
| `radius-lg` | 16 | 카드 |
| `radius-xl` | 24 | 큰 카드 · **스택 카드** · 시트 · 모달 |
| `radius-pill` | 999 | 필 버튼·칩·내비·아바타·토글 |

규칙:
- **요소 곡률 ≈ 그 요소의 내부 패딩 토큰.** 패딩 `space-5(24)` 카드 → `radius-lg~xl`. 칩 → `radius-xs~sm`.
- **중첩 시 안쪽 곡률 = 바깥 곡률 − 사이 여백.**
- **둥근 카드 + 필(999) 버튼 + 작은 배지의 곡률 대비**가 "지갑" 무드를 만든다 — 모든 모서리를 한 값으로 통일하지 않는다.
- **§13 행동표면 버튼은 예외** — 메인·캐러셀의 종이컷 CTA(`PaperButton`)·아이콘 버튼(`PaperIconButton`)은 `radius-md`가 아니라 손으로 자른 다각(`PaperCutRect`/`PaperBlob`)을 쓴다(§13.5).

---

## 5. 아이콘 (Icon)

- **SVG 라인/플랫 아이콘만.** 이모지·이미지 폰트를 기능 아이콘으로 쓰지 않는다.
- **색은 `currentColor` 상속.** 캔버스 위 단독 상태 아이콘은 §2.6에 따라 Fresh/Soon/Urgent는 **dark 변형**으로.
- **색으로 채운 아이콘 박스 금지.** 아이콘 뒤에 단색으로 채운 정사각/둥근 타일(컬러 칩)을 두지 않는다. 아이콘은 면 위에 **직접**. 강조는 박스가 아니라 아이콘 색·여백·타이포로.
  - 좁은 예외: 아바타·로고마크처럼 박스 자체가 콘텐츠인 경우.
- **크기:** 본문 옆 16/20px, 단독 24px. **터치:** 탭 가능 아이콘은 §7.3의 최소 44×44 히트영역(투명 패딩).

---

## 6. 엘리베이션 & 보더 (Elevation & Border)

### 6.1 보더 — 기본 금지
카드·박스·면에 **테두리를 쓰지 않는다.** 분리는 §2.3 틴트 차이 + 여백으로(§2.6 가드레일).
- **예외(기능적):** 키보드 포커스 링 — 보더가 아닌 **outline 링**.
  ```css
  :focus-visible { outline: none; box-shadow: var(--focus-ring); transition: box-shadow var(--dur-1) var(--ease-out); }
  ```

### 6.2 그림자 — 기본 금지, 떠 있는 요소만 예외
평소엔 그림자를 쓰지 않는다. **떠 있는 요소(모달·드롭다운·토스트·바텀시트)** 에만 엘리베이션 토큰.
- **이중 그림자**: 낮은 블러 **10%** + 높은 블러 **5%**. 투명도 **10% 이하**, 색은 `shadowTint`(§2.7/§2.8) — 라이트는 ink 틴트, **다크는 순검정**(ink가 다크에서 크림으로 뒤집히므로 그대로 쓰면 밝은 글로우가 된다).
  ```css
  --shadow-1:
    0 1px 3px        oklch(25% 0.012 80 / 0.10),
    0 10px 24px -6px oklch(25% 0.012 80 / 0.05);
  ```

### 6.3 스택 엘리베이션 — 카드 스택 전용
카드 스택(§8)은 파스텔 면이 크림 캔버스와 명도차가 작아(§2.6) **그림자로 카드 경계를 만든다.** 카드가 위로 겹치므로 그림자는 **위쪽**으로 드리운다. 팀 값(`0 -4px 14px /0.14`)을 내 규칙(≤10%, 이중)으로 보정.
  ```css
  --shadow-stack:
    0 -2px 6px       oklch(25% 0.012 80 / 0.10),   /* 낮은 블러 10% */
    0 -8px 20px -4px oklch(25% 0.012 80 / 0.05);   /* 높은 블러 5%  */
  ```

### 6.4 카드 엘리베이션 — 오린 영수증 한 장
영수증 카드는 떠 있는 요소도 스택도 아니라 **크림 캔버스에서 종이가 살짝 들린 만큼**의 단일 그림자를 쓴다. 이 단은 오래도록 토큰 없이 카드마다 손으로 적혔고, 그 결과 같은 종이가 radius 5·4·3으로 갈렸다. 두 자리만 둔다.

| 토큰 | 값 | 용도 |
|---|---|---|
| `reffiShadowCard()` | ink 6% · blur 5 · y2 | 독립 영수증 카드(장보기·이력·편집 시트·스캔·펼친 상세) |
| `reffiShadowCardCompact()` | ink 6% · blur 4 · y2 | 겹쳐 쌓이거나 한 화면에 여러 장 반복되는 면(냉장고 카드 스택·간편보기 행·프로필 섹션 카드) |

떠 있는 네비(`RootTabView`)는 이 축이 아니라 §6.2 떠 있는 요소라 별개 값을 유지한다.

### 6.5 레이어링 (z-index 스케일)
| 토큰 | z | 용도 |
|---|---|---|
| `--z-base` | 0 | 일반 흐름 (스택 카드는 여기서 자체 순서) |
| `--z-sticky` | 100 | 스티키 헤더·하단 액션바·스캐너 버튼 |
| `--z-dropdown` | 1000 | 드롭다운·팝오버 |
| `--z-modal` | 2000 | 모달·바텀시트(카드 상세) + 딤 |
| `--z-toast` | 3000 | 토스트·스낵바 |

---

## 7. 인터랙션 & 모션 (Interaction & Motion)

> 상태 피드백은 분명하되 모션은 짧고 절제되게. 항상 `transform`·`opacity`만 애니메이트.

### 7.1 모션 토큰
```css
--dur-1: 120ms;  /* 마이크로: 포커스·press */
--dur-2: 180ms;  /* 표준 UI: hover·색 전환 */
--dur-3: 240ms;  /* 면 전환: 모달·시트·카드 확장 */
--ease-out: cubic-bezier(0.23, 1, 0.32, 1);  /* 진입 */
--ease-in:  cubic-bezier(0.32, 0, 0.67, 0);  /* 이탈(더 빠르게) */
--ease-std: cubic-bezier(0.40, 0, 0.20, 1);  /* 상태 전환 */
```
- **`transition: all` 금지.** 속성 명시(`transform`·`opacity`·`box-shadow`·`color`/`background-color`).
- 진입은 `scale(0.95)` + `opacity:0`에서 시작(`scale(0)` 금지), **이탈은 더 빠르게**(`--dur-1` + `--ease-in`).
- 팝오버 `transform-origin`은 트리거 기준(모달은 center). 키보드 고빈도 동작은 애니메이션 최소화.

### 7.2 인터랙션 상태
| 상태 | 처리 | 전환 |
|---|---|---|
| hover | 색 면 main→**dark** (`@media (hover:hover) and (pointer:fine)` 가드 필수) | `background-color var(--dur-2) var(--ease-std)` |
| pressed/active | **`transform: scale(0.97)`** | `transform var(--dur-1) var(--ease-std)` |
| disabled | **`opacity: .45`** + `cursor: not-allowed` (색 변경 X) | `opacity var(--dur-1) var(--ease-std)` |
| focus-visible | `--focus-ring` (§6.1) | `box-shadow var(--dur-1) var(--ease-out)` |

- 모든 인터랙티브 요소는 hover·active·focus·disabled를 빠짐없이 정의.

### 7.3 터치 타깃
- 탭 가능 요소는 **최소 44×44px(권장 48)**, 인접 간격 **≥ 8px(`space-2`)**. 시각 크기가 작아도 투명 히트영역으로 44 확보.

### 7.4 모션 축소 (필수)
```css
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after { animation-duration:.01ms !important; transition-duration:.01ms !important; scroll-behavior:auto !important; }
}
```

### 7.5 통통 튀는 스프링 (Bouncy Spring) — 종이컷 표면 전용(§13)
물리 낙하·모핑·종이 버튼처럼 **종이컷 표면(§13)** 에만 가벼운 오버슈트 스프링을 허용한다. 그 외 일반 UI는 §7.1 듀레이션·이징을 유지한다(스프링 남용 금지). 여전히 `transform`·`opacity`만, `prefers-reduced-motion`이면 제거.

| 토큰 | 스프링(response / damping) | 용도 |
|---|---|---|
| `--spring-pop`   | 0.34 / 0.56 | 뱃지 pop-in · **재료 제거**(살짝 커졌다 뿅 사라짐, 뱃지·실루엣) |
| `--spring-settle`| 0.50 / 0.74 | 뱃지 reflow(제거·추가), 페이지 인디케이터 |
| `--spring-press` | 0.25 / 0.55 | 종이 버튼·뱃지 누름(scale 0.96→1) |

- **재료 낙하·바운스는 진짜 물리 엔진**(SpriteKit, 레퍼런스 École Vision의 gravity-based). 큰 중력(`gravity = -42`) + 낮은 반발(`restitution ≈ 0.12`) + 무거운 질량으로 묵직하게 떨어져 거의 안 튀고, 끌어서 던질 수 있다. 스프링 토큰이 아니라 물리 시뮬레이션 — 재료는 쌓여서 **사라지지 않고 남는다**(§13.6).
- 누름 = `scale(0.96)`(종이) — §7.2의 `0.97`보다 살짝 더 들어가고 스프링으로 되돌린다.
- **재료 제거 팝은 스프링이 아니라 SpriteKit 명시 커브** — `--spring-pop`은 뱃지·실루엣의 SwiftUI scale 트랜지션에만 적용하고, SpriteKit 노드 제거는 `scale ×1.25 ease-out 0.13s → 0 ease-in 0.17s + fade`로 처리한다(§13.6).

### 7.6 햅틱 (Haptics)
> 같은 의미의 액션은 화면이 달라도 항상 같은 햅틱을 낸다 — 트리거가 속한 화면이 아니라 **의미**가 매핑 기준이다.

| 의미 | 트리거 예시 | 햅틱 |
|---|---|---|
| 판정·확정 | Ate/Tossed/Freeze 판정, 레시피 발주(Fire the Ticket), 장보기 Skip(이번엔 안 사기) | `.impact` |
| 성공 완료 | 저장·추가·재입고 | `.success` |
| 파괴 확인 | 삭제·초기화 확정(계정삭제·전체초기화·재료/레시피 삭제 등) | `.warning` |

- 같은 의미면 화면 불문 동일 햅틱. 판정 로직을 화면마다 복붙하며 햅틱 유무가 갈리지 않도록, 판정/저장/파괴 확인 핸들러 레벨에서 매핑을 강제한다.
- 순수 정보성 전환(탭 전환·스크롤 등)에는 햅틱을 쓰지 않는다.
- **매핑 밖 강도를 새로 만들지 않는다** — `.impact`는 판정(`.light`)과 발주(`.medium`) 두 강도뿐이다. 온보딩 완료 도장처럼 "셋업 저장 완료"에 해당하는 순간은 표대로 `.success`다(`.heavy`는 표에도 예외에도 근거가 없다). 유일한 예외는 SpriteKit 달그락의 물리 질감 계열(CoreHaptics, 아래 §13 참고)이고, 그건 의미 매핑이 아니라 재질 표현이라 별도 축이다.
- 로그아웃은 파괴 햅틱 대상이 아니다 — 세션만 해지하고 데이터를 지우지 않는 상태 전환(커먼 룰 ⑦·⑧, `docs/INTERACTION_COMMON_RULES.md`).

---

## 8. 카드 스택 (Card Stack)

> 팀 "Reffie"의 시그니처 패턴. 재료가 지갑 속 카드처럼 쌓이고, **색은 신선도, 정렬은 마감 임박 오름차순** — 위→아래로 읽는 순서가 곧 먹어야 할 순서다.

### 8.1 개념
- **색 = 신선도** (§2.5). 한 덱(deck)은 위(Urgent)→아래(Fresh)로 신선도가 흐른다.
- **정렬 = 마감 오름차순.** 가장 급한 카드(D-0/D-1)가 맨 위.
- 위에서부터 읽으면 그대로 "오늘 먹을 순서".

### 8.2 토큰 · 구조
| 속성 | 값 | 비고 |
|---|---|---|
| 카드 높이 | 98–112px | |
| 겹침(`margin-top`) | −50 ~ −58px | 보이는 띠 ~48–62px (카테고리 + 이름 + D-N) |
| 곡률 | `radius-xl` (24) | 내 곡률 스케일로 흡수(팀 20 → 24) |
| 그림자 | `--shadow-stack` (§6.3) | 위쪽 드리움, ≤10% |
| 정렬 | 마감 오름차순 | Urgent 위 → Fresh 아래 |
| 면 색 | 흰 영수증(`receipt`) 단일 | 깊이감은 면 색 단차가 아니라 **겹침 오프셋 + `--shadow-stack`(§6.3)** 이 담당. 신선도색은 면이 아니라 D-N 스탬프·칩에만(§2.5). 파스텔 면 단차(`Freshness.face(depth:)`)는 구현되지 않아 코드에서 제거됨 — 코드가 정본 |

### 8.3 애너토미 (보이는 띠, 상단 정렬)
```
┌─────────────────────────────┐
│ 콩                          │  ← 카테고리 (Caption/Label, neutral-700 솔리드)
│ 두부                  D-1   │  ← 이름 (Subhead) + D-N (.num, Subhead)
│                             │  ← 나머지는 다음 카드 뒤로 가림
└─────────────────────────────┘
```
- **글자색은 ink**(파스텔 면 위, §2.6). 카테고리는 `neutral-700` **솔리드**(불투명도 X). D-N은 `.num`(tabular).
- 한 카드에 위계 ≤ 3 (카테고리=Caption / 이름=Subhead / D-N=Subhead).

### 8.4 인터랙션 (모션은 §7)
| 동작 | 결과 | 모션 |
|---|---|---|
| 카드 탭 | 상세로 확장(보관법·등록일·레시피) | `--dur-3` `--ease-out`, 바텀시트는 `translateY` |
| 스와이프 | 다 먹은 재료 삭제 | 이탈 `--dur-1` `--ease-in`(더 빠르게) |
| 영수증 스캔 | 새 재료가 신선도 위치(아래쪽)로 삽입 | 진입 `scale(.95)+opacity:0`, 리스트 stagger 30–80ms |
| 맨 위 카드 | 항상 "이거 먼저 먹기" | — |

### 8.5 반응형
- 카드 스택은 두 폭 모두 **기본 재료 뷰**. `<1200px`(모바일, §9)에선 **단일 컬럼**으로 스택이 화면을 채운다. `≥1200px`에선 콘텐츠 컬럼(2–13) 안에 스택을 배치.
- 하단 중앙 내비 버튼 = 영수증 스캐너(`--z-sticky`).
> 팀 문서의 880px 분기는 **Reffi 단일 1200px 분기(§9)** 로 통일했다.

---

## 9. 그리드 & 반응형 (Grid & Responsive)

### 9.1 브레이크포인트
- **단일 분기점: `width 1200px`.**
  - `≥1200px` → 데스크탑 시스템(데스크탑 타이포 + 14컬럼). 대형 태블릿 포함 → "태블릿=데스크탑".
  - `<1200px` → 모바일 시스템(모바일 타이포 + 4컬럼).

### 9.2 모바일 (<1200px)
- **4 컬럼 / 마진 16px / 거터 8px.**
  ```css
  .grid { display:grid; grid-template-columns:repeat(4,1fr); gap:8px; padding-inline:16px; }
  ```

### 9.3 데스크탑·태블릿 (≥1200px)
- **14 컬럼 / 거터 24px.** 양 끝 컬럼(1·14번)은 비워 **유동 마진**, 콘텐츠는 **2–13번(=12컬럼)**.
  ```css
  .grid { display:grid; grid-template-columns:repeat(14,1fr); gap:24px; }
  .grid > .content { grid-column: 2 / 14; }
  ```
> **가정/확인요청:** 원문 "1·12번 컬럼을 최대한 안 쓰는 쪽" → 양 끝(1·14번)을 마진으로 비워 콘텐츠 12컬럼으로 해석. 비대칭 마진을 의도했다면 알려주면 수정.

---

## 10. 적용 체크리스트
- [ ] 신선도 색이 카운트다운(§2.5)과 일치하고, **색 + 라벨**을 함께 썼는가
- [ ] 따뜻한 파스텔 면 위 글자는 ink, Blue 면 위 글자는 white인가
- [ ] 캔버스 위 색-텍스트·점·세선에 dark 변형을 썼는가
- [ ] 파스텔 카드 경계를 색이 아니라 스택 그림자·여백으로 만들었는가
- [ ] 불투명도로 글자색을 만들지 않았는가(neutral-700 솔리드)
- [ ] 페이지 색이 60 : 30(신선도 ≤3색) : 5(Blue) : 5(긴급 강조)인가
- [ ] 화면 내 타이포 위계 ≤ 3, 브랜드 색 ≤ 3인가
- [ ] 화면당 텍스트 계층이 상한(정보 표면 4·행동 표면 7, §3.3)을 넘지 않는가
- [ ] 행동 표면 텍스트가 §3.2 5단계가 아니라 §3.5 보조 스케일 9종(`ReffiActionRole`)에서만 왔는가
- [ ] Display=Story Script(영문)/Pretendard(한글), 그 외 GSF(영문)/Pretendard(한글)인가
- [ ] 데이터성 숫자에 `.num`(tabular)을 적용했는가 · D-day 표기가 `Ingredient.dDayText` 한 포맷터에서 나왔는가 · 수치를 로케일 포맷터(`FormatStyle`)로 만들었는가(§3.4)
- [ ] 텍스트가 `word-break:keep-all` + orphan 방지를 따르는가
- [ ] 아이콘이 SVG이고 **색 채운 아이콘 박스가 없는가**
- [ ] 인터랙티브 요소가 hover·active·focus·disabled를 모두 갖고 hover에 포인터 가드가 있는가
- [ ] 터치 타깃 44×44(권장 48) 이상, 간격 ≥8px인가
- [ ] `prefers-reduced-motion`을 존중하고 `transition:all`을 안 썼는가
- [ ] 보더·이모지·순백배경·순흑텍스트·네온을 쓰지 않았는가
- [ ] 곡률이 요소 패딩에 비례하고, 카드/필/배지 곡률 대비를 살렸는가
- [ ] 1200px 분기로 타이포·그리드·스택이 함께 전환되는가
- [ ] (행동 표면) 종이컷 셰이프(`PaperRect`/`PaperBlob`/`PaperCutRect`)에 완벽한 원·사각·캡슐을 쓰지 않았는가 — 소형 칩·필도 `PaperCutRect`인가(§13.1)
- [ ] 종이 단면 헤어라인을 면-분리 보더로 오용하지 않았는가(동일 톤·재질 표현, §13.1)
- [ ] 리퀴드글래스를 네비·시노·떠있는 컨트롤에만, 버튼 색을 머티리얼로 덮지 않았는가(§13.2)
- [ ] 통통 스프링(§7.5)을 행동 표면에만 쓰고 정보 표면(§8)엔 남용하지 않았는가
- [ ] 재료 뱃지가 캡슐이 아니라 좌측 인디케이터 바 + `PaperRect`인가(§13.5)
- [ ] 추천 캐러셀에 네비가 없고 닫기(X)가 있는가(§13.6)
- [ ] 레시피 대표 아이콘을 그리는 새 표면이 뷰에서 `DishGlyphCatalog`를 직접 부르지 않고 `Recipe.heroIcon`/`RecipeHeroIcon.session`만 쓰는가(§13.7)
- [ ] 영수증 종이를 새로 그릴 때 톱니를 `ReffiTooth`로 지정하고 면은 `receiptSurface(...)`로 얹었는가 — 숫자 리터럴·손조립 금지(§13.8)
- [ ] 재료 실루엣·요리 아이콘 크기를 `ReffiFoodIcon`/`ReffiDishIcon`으로 지정했는가 — 표면마다 숫자를 흩뿌리지 않는가(§13.3/§13.7)
- [ ] 점선 구분을 손으로 그리지 않고 `ReffiRule(.receipt|.ticket)`을 썼는가(§13.8)
- [ ] 카드 그림자를 인라인 `.shadow(...)`가 아니라 `reffiShadowCard()`/`reffiShadowCardCompact()`로 얹었는가(§6.4)

---

## 11. 가정 & 미확정 (Open Questions)
1. **신선도 매핑 구간**: 팀 표의 D-4~6 공백을 **Fresh = D-4+**, Soon = D-3~1, Urgent = D-0/지남으로 메웠다. 실제 임계값은 제품 기준에 맞춰 조정.
2. **파스텔 강도(특히 Urgent)**: Urgent main을 `oklch(74% …)`로 잡아 "오늘!"의 무게를 약간 남겼다(다른 두 색보다 살짝 진함). 더 파스텔하게 원하면 L을 ~80%까지 올릴 수 있으나 ink 대비(현 6.66)가 낮아진다.
3. **카드 곡률 20 vs 24**: 팀의 20px를 내 곡률 스케일의 `radius-xl(24)`로 흡수했다. 지갑 무드에 20을 꼭 쓰려면 스케일에 20을 정식 토큰으로 추가할지 결정 필요.
4. **Story Script**: 라틴 전용·단일 weight 400 확인 → Display는 영문 브랜드 모먼트용, 한글은 Pretendard Bold. 스크립트라 Display 자간 0·weight 400로 운용(타이포 시스템의 −1%/700에 대한 폰트 기인 예외).
5. **한글 폰트**: 이번 지시로 한글=Pretendard 확정(이전 안의 SUIT 대체). GSF·Pretendard 혼용 줄 메트릭 보정(§3.1)은 실제 텍스트로 점검 권장.
6. **본문 자간 −1%**: 라틴 기준 0 권고가 있으나 한글(Pretendard) 본문에 자연스러운 네 스펙을 유지.
7. **데스크탑 그리드 마진**: §9.3 주석 참조.
8. **AI 레시피 생성 제거(2026-08-08, owner decision).** MVP 스코프에서 인앱 AI 레시피 생성(온디바이스·클라우드 프록시 엔진 체인, 동의 토글, 일일 캡, 발주 덱의 sparkle/AI 배지, 캐러셀 진행 힌트 "Cooking up an AI ticket…")을 전면 제거했다 — 단서 카드 방향으로 정리하면서 생성형 레시피가 불필요해졌다(§13.5·§13.6). Supabase `recipe-generate` 함수와 `docs/AI_SETUP.md`는 향후 재활성화를 위해 그대로 유지한다(제거는 앱 표면 한정). Blue 토큰의 "레시피·AI·기본 액션" 역할 설명(§2.2 등)은 바꾸지 않았다 — 온보딩 개인화 문구의 AI 아이콘 등 생성과 무관한 다른 용도가 남아 있다.

---

## 12. 통합 토큰 (`:root`) — 정본
```css
:root {
  /* ---- Brand · Fresh / Soon / Urgent (파스텔) + Blue (Reffi) ---- */
  --color-fresh:       oklch(86%   0.12  136);   /* #ADE393 신선 */
  --color-fresh-dark:  oklch(50%   0.115 142);   /* #387332 */
  --color-fresh-light: oklch(95%   0.040 132);   /* #E5F5D9 */
  --color-soon:        oklch(85%   0.125 84);    /* #F4C767 곧 */
  --color-soon-dark:   oklch(53%   0.120 71);    /* #965D00 */
  --color-soon-light:  oklch(95%   0.045 84);    /* #FDEDCD */
  --color-urgent:      oklch(75%   0.135 36);    /* #F68D70 오늘 */
  --color-urgent-dark: oklch(52%   0.150 32);    /* #AE3F2C */
  --color-urgent-light:oklch(93%   0.050 33);    /* #FFDDD3 */
  --color-blue:        oklch(51.4% 0.134 249.8); /* #176AB0 브랜드/액션/AI */
  --color-blue-dark:   oklch(40%   0.12  250);   /* #004985 */
  --color-blue-light:  oklch(93%   0.045 250);   /* #D2EBFF */

  /* ---- Neutral (5) · Reffi 고유 ---- */
  --neutral-900: oklch(25% 0.012 80); /* ink   #25211B */
  --neutral-700: oklch(43% 0.014 80); /*        #544F47 */
  --neutral-500: oklch(56% 0.013 80); /*        #78746C */
  --neutral-200: oklch(93.5% 0.008 85); /*      #ECE9E4 */
  --neutral-50:  oklch(97% 0.012 90); /* canvas #F8F5EC */

  /* ---- Semantic aliases ---- */
  --color-primary: var(--color-blue);   /* 브랜드 · 기본 액션 */
  --color-action:  var(--color-blue);   /* CTA */
  --color-recipe:  var(--color-blue);   /* 레시피 · AI */
  --color-canvas:  var(--neutral-50);
  --color-ink:     var(--neutral-900);
  --color-ink-2:   var(--neutral-700);
  --color-muted:   var(--neutral-500);

  /* ---- Spacing ---- */
  --space-1: 6px;  --space-2: 8px;  --space-3: 12px; --space-4: 16px;
  --space-5: 24px; --space-6: 28px; --space-7: 32px;

  /* ---- Radius (패딩에 종속) ---- */
  --radius-xs: 6px;  --radius-sm: 8px;  --radius-md: 12px;
  --radius-lg: 16px; --radius-xl: 24px; --radius-pill: 999px;

  /* ---- Elevation + Stack + Layering ---- */
  --shadow-1:
    0 1px 3px        oklch(25% 0.012 80 / 0.10),
    0 10px 24px -6px oklch(25% 0.012 80 / 0.05);
  --shadow-stack:
    0 -2px 6px       oklch(25% 0.012 80 / 0.10),
    0 -8px 20px -4px oklch(25% 0.012 80 / 0.05);
  --focus-ring: 0 0 0 3px oklch(51.4% 0.134 249.8 / 0.45);
  --scrim:      oklch(25% 0.012 80 / 0.22);   /* 모달·결정 오버레이 딤(ink 틴트) */
  --z-base: 0; --z-sticky: 100; --z-dropdown: 1000; --z-modal: 2000; --z-toast: 3000;

  /* ---- Motion ---- */
  --dur-1: 120ms; --dur-2: 180ms; --dur-3: 240ms;
  --ease-out: cubic-bezier(0.23, 1, 0.32, 1);
  --ease-in:  cubic-bezier(0.32, 0, 0.67, 0);
  --ease-std: cubic-bezier(0.40, 0, 0.20, 1);
  /* 통통 스프링 — 종이컷 표면 전용(§7.5/§13). response / dampingFraction.
     재료 낙하 자체는 스프링이 아니라 물리 엔진(SpriteKit restitution). */
  --spring-pop:    0.34 / 0.56;
  --spring-settle: 0.50 / 0.74;
  --spring-press:  0.25 / 0.55;
  --ease-bounce: cubic-bezier(0.34, 1.56, 0.64, 1);   /* 웹 쇼케이스용 스프링 근사(오버슈트) */

  /* ---- Paper / Glass (§13) ---- */
  --paper-surface:     oklch(99% 0.006 90);          /* 밝은 종이 면 — 뱃지·티켓·글리프 타일 */
  --paper-pass:        oklch(95% 0.016 90);          /* 따뜻한 주방 패스 종이 — 캐러셀 배경 */
  --paper-edge:        oklch(25% 0.012 80 / 0.07);   /* 종이 단면 헤어라인(캔버스 위 면, 분리 보더 아님) */
  --paper-edge-onfill: oklch(100% 0 0 / 0.14);       /* 채도 면(버튼) 위 흰 종이 헤어라인 */
  --bg-sheen:          oklch(100% 0 0 / 0.22);        /* 메인 배경(리퀴드글래스) 상단 흰 시노 */
  --glass-tint:        oklch(85% 0.04 242 / 0.30);    /* 네이티브 글래스 틴트(네비) */
  --receipt:           oklch(98.5% 0.004 90);         /* "흰 영수증" 면의 정본(§2.7 신규) */

  /* ---- Wilt (§13.3) — 시듦 두 축. 스킴 불변(라이트/다크 동일 값) ---- */
  /* 강도 축 — 신선도 3단계. weight는 재질 축 값을 항등에서 보간하는 가중치(배율이 아니다). */
  --wilt-fresh-saturation:  1.00; --wilt-fresh-brightness:  1.00; --wilt-fresh-weight:  0;
  --wilt-soon-saturation:   0.85; --wilt-soon-brightness:   0.97; --wilt-soon-weight:   0.5;
  --wilt-urgent-saturation: 0.68; --wilt-urgent-brightness: 0.93; --wilt-urgent-weight: 1;
  /* 재질 축 — 글리프별 강성(w=1일 때 최대치). rigidContainer는 기하 불변이라 토큰이 없다. */
  --wilt-leafy-tilt: -7.0deg; --wilt-leafy-squash: 0.935; --wilt-leafy-spread: 1.030; --wilt-leafy-rounding: 0.17;
  --wilt-soft-tilt:  -4.5deg; --wilt-soft-squash:  0.955; --wilt-soft-spread:  1.022; --wilt-soft-rounding:  0.15;
  --wilt-firm-tilt:  -4.5deg; --wilt-firm-squash:  0.965; --wilt-firm-spread:  1.000; --wilt-firm-rounding:  0.09;

  /* ---- Dark-only surfaces (§2.8) — 라이트 스킴에선 미사용, 다크 오버라이드에서만 값이 실효 ---- */
  --shadow-tint: oklch(25% 0.012 80);  /* 그림자 전용. 다크에서 0 0 0(순검정)으로 뒤집힘 — ink 대신 항상 이 토큰 */
  --toast:       oklch(25% 0.012 80);  /* 잉크 토스트 캡슐 면(= 라이트 ink). 위 텍스트는 고정 white */
  --on-ink:      white;                /* ink로 채운 면 위 콘텐츠. 다크에서 어두운 값으로 뒤집힘 */
  --toast-action: oklch(90% 0.05 250); /* toast 위 액션 라벨(Undo) — 고정, 다크 오버라이드 없음(실측 대비 L 11.92 · D 9.11) */

  /* ---- Interaction ---- */
  --tap-min: 44px;

  /* ---- Fonts ---- */
  --font-display: "Story Script", "Pretendard Variable", Pretendard, "Apple SD Gothic Neo", system-ui, cursive;
  --font:         "Google Sans Flex", "Pretendard Variable", Pretendard, -apple-system, "Apple SD Gothic Neo", system-ui, sans-serif;

  /* ---- Type (Desktop ≥1200 / min 16px) ---- */
  --d-display: 400 48px/1.2 var(--font-display);  /* Story Script 400 */
  --d-heading: 700 32px/1.2 var(--font);
  --d-subhead: 600 22px/1.2 var(--font);
  --d-body:    400 18px/1.4 var(--font);
  --d-caption: 500 16px/1.4 var(--font);
  --d-display-size: 48px;   /* 한글 디스플레이(Pretendard Bold) 크기 */

  /* ---- Grid ---- */
  --bp: 1200px;
  --grid-margin-mobile: 16px; --grid-gutter-mobile: 8px;  /* 4 cols */
  --grid-gutter-desktop: 24px;                            /* 14 cols, 1·14 = margin */
}

/* ---- Dark scheme overrides (§2.8) — "밤의 주방 패스", 순검정 없음(예외: shadow-tint·scrim) ----
   [data-theme] 명시 오버라이드가 media query보다 우선하도록 순서·특이성을 맞춘다(라이트 강제 토글 지원). */
@media (prefers-color-scheme: dark) {
  :root:not([data-theme="light"]) {
    --color-fresh:        oklch(42%   0.075 138);
    --color-fresh-dark:   oklch(74%   0.105 140);
    --color-fresh-light:  oklch(30%   0.035 136);
    --color-soon:         oklch(44%   0.080 82);
    --color-soon-dark:    oklch(78%   0.110 76);
    --color-soon-light:   oklch(31%   0.038 82);
    --color-urgent:       oklch(45%   0.095 34);
    --color-urgent-dark:  oklch(74%   0.130 34);
    --color-urgent-light: oklch(30%   0.042 33);
    --color-blue:         oklch(56%   0.115 250);
    --color-blue-dark:    oklch(76%   0.095 250);
    --color-blue-light:   oklch(30%   0.045 250);

    --neutral-900: oklch(93%   0.010 85);
    --neutral-700: oklch(76%   0.012 82);
    --neutral-500: oklch(60%   0.012 80);
    --neutral-200: oklch(30%   0.008 80);
    --neutral-50:  oklch(21.5% 0.010 78);

    --paper-surface:     oklch(28.5% 0.008 82);
    --paper-pass:        oklch(25.5% 0.010 84);
    --paper-edge:        oklch(93% 0.010 85 / 0.07);   /* ink가 뒤집혀도 헤어라인은 동일 알파(§2.8, 의도된 반전) */
    --paper-edge-onfill: oklch(100% 0 0 / 0.10);
    --bg-sheen:          oklch(100% 0 0 / 0.045);
    --receipt:           oklch(29%   0.007 83);
    --scrim:             oklch(0% 0 0 / 0.55);
    --shadow-tint:        oklch(0% 0 0);
    --toast:              oklch(33% 0.010 80);
    --on-ink:              oklch(22% 0.010 78);
    /* 그림자는 항상 shadow-tint(§2.8) — 다크에서 순검정으로 뒤집혀야 ink 위 밝은 글로우를 피한다 */
    --shadow-1:
      0 1px 3px        oklch(0% 0 0 / 0.10),
      0 10px 24px -6px oklch(0% 0 0 / 0.05);
    --shadow-stack:
      0 -2px 6px       oklch(0% 0 0 / 0.10),
      0 -8px 20px -4px oklch(0% 0 0 / 0.05);
  }
}
:root[data-theme="dark"] {
  --color-fresh:        oklch(42%   0.075 138);
  --color-fresh-dark:   oklch(74%   0.105 140);
  --color-fresh-light:  oklch(30%   0.035 136);
  --color-soon:         oklch(44%   0.080 82);
  --color-soon-dark:    oklch(78%   0.110 76);
  --color-soon-light:   oklch(31%   0.038 82);
  --color-urgent:       oklch(45%   0.095 34);
  --color-urgent-dark:  oklch(74%   0.130 34);
  --color-urgent-light: oklch(30%   0.042 33);
  --color-blue:         oklch(56%   0.115 250);
  --color-blue-dark:    oklch(76%   0.095 250);
  --color-blue-light:   oklch(30%   0.045 250);
  --neutral-900: oklch(93%   0.010 85);
  --neutral-700: oklch(76%   0.012 82);
  --neutral-500: oklch(60%   0.012 80);
  --neutral-200: oklch(30%   0.008 80);
  --neutral-50:  oklch(21.5% 0.010 78);
  --paper-surface:     oklch(28.5% 0.008 82);
  --paper-pass:        oklch(25.5% 0.010 84);
  --paper-edge:        oklch(93% 0.010 85 / 0.07);
  --paper-edge-onfill: oklch(100% 0 0 / 0.10);
  --bg-sheen:          oklch(100% 0 0 / 0.045);
  --receipt:           oklch(29%   0.007 83);
  --scrim:             oklch(0% 0 0 / 0.55);
  --shadow-tint:       oklch(0% 0 0);
  --toast:             oklch(33% 0.010 80);
  --on-ink:            oklch(22% 0.010 78);
  --shadow-1:
    0 1px 3px        oklch(0% 0 0 / 0.10),
    0 10px 24px -6px oklch(0% 0 0 / 0.05);
  --shadow-stack:
    0 -2px 6px       oklch(0% 0 0 / 0.10),
    0 -8px 20px -4px oklch(0% 0 0 / 0.05);
}

/* Tracking helpers (−1% / +1%, Display(Story Script)는 0) */
.t-heading,.t-subhead,.t-body { letter-spacing: -0.01em; }
.t-display { letter-spacing: 0; }
.t-caption { letter-spacing: 0.01em; }

/* Tabular numerals (데이터성 숫자) */
.num { font-variant-numeric: tabular-nums lining-nums; font-feature-settings: "tnum" 1, "lnum" 1; }

/* Interaction states */
.is-interactive { transition: background-color var(--dur-2) var(--ease-std),
                              transform var(--dur-1) var(--ease-std); }
@media (hover: hover) and (pointer: fine) {
  .is-interactive:hover { background-color: var(--color-blue-dark); }
}
.is-interactive:active { transform: scale(0.97); }
.is-interactive:disabled,[aria-disabled="true"] { opacity: .45; cursor: not-allowed; }
:focus-visible { outline: none; box-shadow: var(--focus-ring);
                 transition: box-shadow var(--dur-1) var(--ease-out); }

/* Mobile type (<1200px / min 14px) */
@media (max-width: 1199.98px) {
  :root {
    --d-display: 400 34px/1.2 var(--font-display);
    --d-heading: 700 24px/1.2 var(--font);
    --d-subhead: 600 18px/1.2 var(--font);
    --d-body:    400 16px/1.4 var(--font);
    --d-caption: 500 14px/1.4 var(--font);
    --d-display-size: 34px;
  }
}

/* 텍스트 줄바꿈 기본값 */
.text { word-break: keep-all; overflow-wrap: anywhere; text-wrap: pretty; }
.text--title { text-wrap: balance; }

/* 카드 스택 */
.stack-card {
  min-height: 98px; margin-top: -54px; border-radius: var(--radius-xl);
  box-shadow: var(--shadow-stack); color: var(--color-ink);
}
.stack-card:first-child { margin-top: 0; }
/* 면 색은 신선도에 따라: --color-fresh / --color-soon / --color-urgent */

/* 모션 축소 (필수) */
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after { animation-duration:.01ms !important; transition-duration:.01ms !important; scroll-behavior:auto !important; }
}
```

---

## 13. 종이컷 · 리퀴드글래스 · 통통 모션 (Paper · Glass · Bounce)

> 메인 플로우의 **행동 표면**(재료·버튼·티켓)에 입히는 추가 레이어. 파스텔 색-블로킹(§2)·카드 스택(§8)의 정보 규율은 그대로 두고, "지금 행동" 표면만 **손으로 자른 종이 + 리퀴드글래스 + 일러스트 + 통통 튀는 모션**으로 식욕과 활기를 더한다. 색·대비·타이포·터치 규칙(§2·3·5·7.3)은 모두 유효.

### 13.1 손으로 자른 종이 셰이프 (Hand-cut Paper)
- **완벽한 원·사각·캡슐 금지(행동 표면 한정).** 정점 반지름·각도, 변의 휘는 정도를 **고정 시드**로 미세하게 흩뜨려 손으로 오린 종이 느낌을 낸다. 시드가 같으면 항상 같은 모양(레이아웃·애니메이션 안정).
- 프리미티브: **`PaperRect(cornerRadius, seed)`** — 변이 살짝 휘고 코너 반지름이 변마다 다른 둥근 사각(뱃지·카드). **`PaperBlob(sides, seed)`** — 직선 변 불규칙 다각/9각형(아이콘 버튼·스탬프). **`PaperCutRect(seed)`** — 네 모서리를 잘라낸 **길쭉한 8각형**(와이드 CTA 버튼·소형 칩/필; 아이콘 버튼 octagon과 통일).
- **칩·필도 예외가 아니다 — 소형 면의 정본은 `PaperCutRect`다.** `PaperRect`는 코너 반지름이 `min(w,h)/2`로 클램프돼 pill 반지름을 넘기면 정확한 캡슐로 퇴화하고, 변 휨(≈1pt)도 칩 크기에선 지각되지 않는다. 그래서 D-day 칩·상태 칩·추정 기한 배지·취향 칩·알림 배너 액션처럼 **작고 반복되는 행동 표면 면**은 `Capsule()`이 아니라 `PaperCutRect(seed:)`를 쓴다(잘린 모서리는 크기와 무관하게 형태로 보인다). 예외는 §13.2 글래스 네비와 §13.6 잉크 토스트 두 곳뿐 — 둘 다 종이가 아닌 재질이라 이 규칙 밖이다.
- **종이 단면(`--paper-edge` / `--paper-edge-onfill`)** — 면과 같은 톤의 ~1px 헤어라인을 면 위에 겹쳐 "종이 두께"를 표현. 캔버스 위 밝은 면은 잉크 톤(`--paper-edge`, 0.07), **채도 면(버튼)은 흰 톤**(`--paper-edge-onfill`, 0.14)을 쓴다. **이는 §6.1의 분리용 보더가 아니다**(면을 나누지 않는 동일 톤 재질 표현). 분리는 여전히 색·여백·그림자로.

### 13.2 리퀴드글래스 (Liquid Glass)
- iOS 26 네이티브 `.glassEffect`(폴백 `.ultraThinMaterial`). **사용처:** 메인 **배경**(컬러 블롭 위 글래스 프로스트), 하단 캡슐 네비(`--glass-tint`), 떠 있는 닫기 버튼.
- **메인 배경 = 리퀴드글래스** — 신선도/블루 틴트 블롭을 깔고 글래스로 흐려 프로스트 면을 만들고, **상단에 옅은 흰 시노**(`--bg-sheen`)를 얹는다. 그 위로 재료가 떨어진다.
- **버튼엔 글래스 시노가 없다** — 색(Blue/sub) 솔리드 + 종이 질감(`PaperGrain`) + 흰 단면 헤어라인(`--paper-edge-onfill`)만. 시노는 배경 전용이다.

### 13.3 일러스트 (Illustration) — 각진 면분할 컷페이퍼 · 자연색 멀티컬러
- 재료는 **각진 면분할(faceted) 컷페이퍼** 일러스트 — 곡선 대신 **5~9각 직선 면**으로 오려 붙인 종이 조각처럼, 몸통을 **2~3톤으로 면분할**(대각선 직선 경계의 밝은/어두운 면)하고, 초록 잎/줄기·최소 디테일(점·씨·결)을 **플랫 색면**(아웃라인 없음, 옅은 종이 그림자)으로 조합한다. **장난기 있는 오프컬러 액센트 1포인트**(예: 양파 뿌리 보라)를 더한다. 당근=각진 오렌지 원뿔+초록 잎, 토마토=8각 빨강+초록 별꼭지, 오이=단면 원+씨앗 별무늬, 아보카도=반쪽+밤색 씨, 고기=빨강 살+크림 지방, 생선=파랑 몸+꼬리+눈 등.
- **글리프 라이브러리(`FoodGlyph`, 53종)**는 채소·과일·고기·생선·유제품·**곡류·저장식품**을 폭넓게 커버한다: 채소(leaf·root·squash·onion·tomato·pepper·mushroom·broccoli·potato·garlic·cucumber·pea·cabbage·chili·pumpkin·eggplant·sweetPotato·ginger·seaweed), 과일(apple·citrus·berry·avocado·banana·grape·watermelon·pineapple·mango), 단백질(egg·tofu·meat·poultry·fish·shrimp·sausage·bacon·crab·squid·clam), 유제품(milk·cheese·bread·yogurt·butter), 곡류(rice·noodles·corn), 저장식품(sauceBottle·can·honey), 기타(dumpling), **요리형(gimbap — 재료가 아니라 메뉴 자체가 모티프인 v3 신규 1종. `categoryLabel`은 Other가 아니라 Grain으로 붙인다 — 정체가 밥이라 History 도넛에서 그쪽이 읽힌다)**, generic. 재료명→글리프는 `FoodGlyph.match(name)`. 검증은 `-glyphGallery` 런치 인자(전 글리프 그리드). **카테고리 라벨**은 `FoodGlyph.categoryLabel`이 파생 — 기존 Veg·Fruit·Dairy·Meat·Seafood·Protein·Bakery·Other에 **Grain(곡류)·Pantry(저장식품)** 2종을 더한다(`Localizable.xcstrings` en+ko 등록). v2 신규 17종은 전부 기존 카테고리 라벨로 편입(신규 라벨 없음): 채소 4·과일 4는 Veg·Fruit, sausage·bacon→Meat, crab·squid·clam→Seafood, yogurt·butter→Dairy, honey→Pantry, dumpling→Other.
- **두 일러스트 시스템의 분업** — **완성된 요리는 요리 카탈로그**(`DishGlyphCatalog` 원형 15종 × 변주 → `DishSilhouette`, §13.7), **재료는 글리프**(`FoodGlyph` → `PaperSilhouette`)가 그린다. 요리형 글리프(`gimbap`)는 둘 사이의 다리지만 **히어로 체인 안에서만** 그 역할을 한다 — 레시피 이름이 요리를 지목할 때의 큐레이션 층(§13.7 히어로 체인 ②)이고, 재료명 매칭 경로(`FoodGlyph.match`)에는 넣지 않는다. 카탈로그 추론은 원형만 맞히고 색·고명은 id 해시로 흔들어, 손으로 그린 김밥이 있는데 짐작으로 덮을 이유가 없다.
- **FoodGlyph 팔레트(정본 출처 = `PaperSilhouette.swift`의 `enum C`)** — 재료별 자연색을 OKLCH로 고정하고, 몸통마다 base/shade/highlight 3톤으로 면을 나눈다. 대표값: 잎/줄기 `oklch(0.43~0.78, 0.11~0.13, 142~150)`, 당근 `oklch(0.70, 0.16, 56)`, 토마토 `oklch(0.62, 0.18, 32)`, 노랑(레몬/파프리카/옥수수) `oklch(0.85, 0.15, 96)`, 호박 `oklch(0.66, 0.15, 62)`, 고추 `oklch(0.55, 0.19, 32)`, 아보카도 과육 `oklch(0.86, 0.10, 110)`·껍질 `oklch(0.36, 0.07, 148)`, 바나나 `oklch(0.84, 0.15, 92)`, 고기 `oklch(0.54, 0.14, 22)`, 생선 `oklch(0.64, 0.07, 240)`, 치즈 `oklch(0.83, 0.13, 92)`, 소스병 `oklch(0.40, 0.055, 44)`, 캔 금속 `oklch(0.82, 0.008, 250)`, 오프컬러 액센트(양파 뿌리 보라 `oklch(0.46, 0.10, 330)`·래디시 핑크 `oklch(0.72, 0.16, 350)`). **v2 신규 대표값**: 포도 자주 `oklch(0.44, 0.12, 320)`, 수박 과육 `oklch(0.63, 0.17, 18)`·껍질 `oklch(0.52, 0.13, 148)`, 파인애플 `oklch(0.75, 0.13, 78)`, 망고 노랑 `oklch(0.83, 0.15, 82)`·붉은면 `oklch(0.66, 0.16, 44)`, 가지 보라 `oklch(0.36, 0.09, 318)`, 고구마 자주빛 `oklch(0.47, 0.11, 14)`, 생강 베이지 `oklch(0.79, 0.05, 74)`, 소시지 `oklch(0.55, 0.12, 34)`, 베이컨 살 `oklch(0.60, 0.15, 20)`, 게 주홍 `oklch(0.60, 0.16, 34)`, 오징어 크림 `oklch(0.91, 0.03, 18)`, 조개껍질 `oklch(0.83, 0.045, 68)`, 버터 `oklch(0.87, 0.10, 96)`, 꿀 앰버 `oklch(0.72, 0.14, 74)`, 김/미역 진초록 `oklch(0.33, 0.055, 156)`, 만두피 크림 `oklch(0.91, 0.03, 84)`. 색은 **신선도 코딩과 분리**(§2.5 행동표면 예외) — 쇼케이스(`design-system.html`)의 실루엣도 신선도색이 아니라 이 자연색으로 칠한다.
- **신선도에 따라 시든다(Wilt) — 팔레트는 안 바뀌고 자세·각이 바뀐다.** 재료 정체성(hue)은 색-코딩되지 않지만, 소비기한이 다가올수록 눈에 보이게 시들어 촉각적 압박을 준다. `WiltStyle`(`Reffi/Features/Main/WiltStyle.swift`)이 **두 축을 곱해** 적용한다 — 색은 Canvas 그리기 이음매 한 곳의 **색행렬 1장**, 형태는 같은 이음매의 좌표 변환(밑변 가운데 앵커 회전·스케일) + `poly()`의 **꼭짓점 라운딩** 한 곳. 53종 글리프 draw 함수는 전부 무수정으로 상속한다.

  **① 강도 축(신선도 3단계)** — 색은 계속 빠지고 형태 가중치 `w`가 올라간다. D-3에서 시각 예산을 다 쓰지 않고 D-0까지 계속 시든다.

  | 신선도 | 채도 | 명도 | 형태 가중치 `w` | 캐시 토큰 |
  |---|---|---|---|---|
  | Fresh (D-4+) | 1.00 | 1.00 | 0.0 | `f` |
  | Soon (D-3~1) | 0.85 | 0.97 | 0.5 | `s` |
  | Urgent (D-0/지남) | 0.68 | 0.93 | 1.0 | `u` |

  **② 재질 축(글리프별 강성 `Rigidity`)** — 아래는 `w = 1`(Urgent)일 때의 최대치다. 중간 단계는 **항등에서 선형 보간**한다(`tilt·w`, `1+(squash−1)·w`, `1+(spread−1)·w`, `rounding·w`) — 배율로 곱하면 `squash`·`spread`가 1 기준 값이라 `w = 0.5`에서 글리프가 반토막 난다.

  | 재질 | 해당 글리프 | 기울임(밑변 가운데 앵커) | 스쿼시(scaleY) | 퍼짐(scaleX) | 꼭짓점 라운딩 |
  |---|---|---|---|---|---|
  | `rigidContainer` | milk·yogurt·butter·can·sauceBottle·honey·egg | — | — | — | — |
  | `firm` | 뿌리채소·양파·감자·마늘·호박·고구마·생강·옥수수·덩어리 단백질·해산물·generic | −4.5° | 0.965 | 1.000 | 0.09 |
  | `soft` | 과일 전종·토마토·오이·고추·가지·두부·치즈·빵·만두·밥·면·김밥 | −4.5° | 0.955 | 1.022 | 0.15 |
  | `leafy` | leaf·cabbage·seaweed·broccoli·pea·mushroom | −7.0° | 0.935 | 1.030 | 0.17 |

  **용기류(`rigidContainer`)는 색 감쇠만 받고 기하는 불변이다** — 캔·갑·병·단지·달걀 껍질은 시들어도 주저앉지 않는다. 좌표계도 패스도 건드리지 않아 실루엣 마스크가 픽셀 단위로 동일하다(`WiltRenderTests.containersKeepAnIdenticalSilhouette`가 0px로 고정). 축은 `categoryLabel`(History 도넛·분석 taxonomy 소유)이 아니라 **일러스트 전용 강성 enum**을 쓴다 — 통계 목적의 재분류가 일러스트를 조용히 다시 튜닝하지 못하게 하고, 면(面)마다 문자열 비교를 하지 않게 한다. `default` 없는 전수 스위치라 글리프가 늘면 컴파일이 막아 선다.

  Fresh는 항등이라 필터·트랜스폼 자체를 건너뛴다(렌더 비용 0). 색행렬은 상수항(5열) 0의 선형 변환(Rec.709 휘도 가중 saturate × 명도 배수)이라 프리멀티플라이 알파에서도 테두리가 뜨지 않고, 회색축은 정확히 `brightness`로 맵핑된다 — **채도 필터 + 누런 워시를 겹치지 않는다**(곱하기 워시는 hue를 밀어 버터 포일·생선 몸통 같은 파랑 계열을 올리브로 만든다). 라운딩은 그 도형 자신의 **바운딩 박스 짧은 변** 비율이라 34pt 행이든 70pt 갤러리든 같은 인상을 주고, 잎맥·씨앗 같은 가느다란 조각은 자기 폭에 비례해 거의 그대로 남는다. 물리 콜라이더는 `.fresh` 실측 그대로 유지한다(시각 변형으로 생기는 3~7% 오차는 허용 — 콜라이더까지 줄이면 이미 쌓인 더미가 재정렬되며 무너진다).
- **신선도는 색-코딩이 아니라 시듦 + 뱃지로 전한다(§2.5 행동표면 예외).** 일러스트는 정체성 색(hue)을 유지한 채 위 두 표의 시듦으로 생기만 감쇠하고, 확정적인 신선도 신호는 여전히 ① 뱃지 좌측 인디케이터 바, ② D-N 텍스트가 맡는다. 씬 위에는 이름 라벨을 얹지 않는다 — 재료 식별은 실루엣 + 아래 뱃지 행이 담당한다. (정보 표면·카드 스택의 §2.5 색=신선도 규칙은 그대로.)

### 13.4 진짜 물리 + 통통 모션
- **재료 낙하는 물리 엔진**(SpriteKit, §7.5): 위에서 떨어져 충돌하며 쌓이고, **끌어서 던질 수 있다**. **묵직하게** — 큰 중력(기본 크기 `42`) + 낮은 반발(`restitution≈0.12`)로 쿵 떨어져 거의 안 튄다. UI 스프링(`pop`·`settle`·`press`)은 뱃지/버튼에만. `prefers-reduced-motion`이면 낙하 생략하고 바닥에 즉시 배치.
- **기기를 기울이면 중력도 기운다(자이로 중력, `GravityMapper`).** 방향 = `normalize(deviceGravity.x, y)`, 크기 = `42 × clamp(hypot(x, y), 0.35, 1.0)`(= 14.7…42) — 세로로 똑바로 들면 정확히 기존 상수 중력 `(0, -42)`와 일치해 회귀가 없다. 손떨림으로 중력을 계속 갈아끼우지 않도록 **재적용 데드밴드**(방향차 > 2° 또는 크기차 > 5%)를 두고, 씬이 조용해져 잠들면(force-settle) **깨우기 임계 6°**를 넘을 때만 다시 굴린다 — 그 아래는 무시한다(안 그러면 느린 회전이 6° 문턱을 영영 못 넘고 중력장이 굳어버린다). **깨우는 것만으로는 부족해서 감쇠 유예(≈1.5s, 90프레임)를 함께 둔다** — 잔여 운동 감쇠(프레임당 ×0.8)가 그대로 돌면 기울임이 만든 느린 가속이 매 프레임 20%씩 깎여 종단 ~2pt/s에 갇히고, 그 상태로 안착 판정이 다시 통과해 더미가 1pt도 못 움직이고 재차 잠든다. 중력이 실제로 적용되는 순간(깨우기·비유휴 재적용 양쪽)마다 이 창을 다시 채우고, 손을 멈추면 창이 소진되며 평소의 감쇠·안착으로 돌아간다. 모션 불가(시뮬레이터)·Reduce Motion·씬이 안 떠 있음 중 하나라도면 상수 중력 `(0, -42)`로 폴백. 프라이버시 문구(`NSMotionUsageDescription`): "Reffi tilts the ingredients on your counter with your device's motion." / "기기 기울임에 따라 재료가 움직이도록 모션 데이터를 사용합니다."
- **흔들면 재료가 달그락거린다(셰이크 킥).** 중력 벡터만으론 흔들기가 전달되지 않는다 — `deviceMotion.gravity`는 저역 통과된 자세 신호라 흔드는 동안에도 거의 변하지 않는다. 그래서 센서 래퍼가 **`userAcceleration`(중력 제외 고역)**을 함께 넘기고, 씬이 그걸 임펄스 킥으로 바꾼다. **0.35G 미만은 손떨림·걷기로 보고 무시**하고, 킥 사이 **최소 간격 90ms**(매 프레임 밀면 흔들기가 아니라 연속 가속이 된다), 킥 하나의 속도 변화는 `(mag − 0.35) × 150`을 **210pt/s로 클램프**한다(60fps에서 프레임당 3.5pt — 두께 0인 벽 edge loop도 못 뚫는 **터널링 상한**이고, 킥은 항상 wake를 거쳐 CCD가 켜진 상태다). **칩마다 각도 ±0.65rad · 세기 0.65~1.35배로 흩뿌린다** — 전부 같은 벡터로 밀면 더미가 통째로 평행이동해 서로 부딪히지 않고, 부딪히지 않으면 달그락도 없다. 흩는 값은 UUID 바이트를 접는 결정적 해시라 **실행마다 같다**(스크린샷 QA가 흔들리지 않는다). Reduce Motion이면 셰이크 킥 자체를 건너뛴다(§7.4).
- **필드 컨테인먼트 — 안쪽 벽 + 2단 천장 + 표류칩 회수.** 중력을 사용자가 아무 방향으로나 돌릴 수 있게 된 이상 "재료가 화면 밖으로 나가 안 돌아온다"는 **구조적으로 불가능**해야 한다. ① **좌·우 벽은 `wallInset ≈ chipSide × 0.09`만큼 안쪽**에 세운다 — 충돌체는 알파 bbox의 90%라 바디가 화면 끝 벽에 닿아도 그림은 계속 바깥으로 삐져나가 잘려 보인다(삐져나감 ≈ 바디폭 × 0.056, 최대 바디폭 0.68s → 약 0.038s, 여기에 가로 중심 오프셋·회전 여유를 얹어 0.09s). ② **천장은 2단**이다 — 낙하 중엔 **스폰 천장**(화면 위 `+700pt`, 기존 값 유지: 스폰 클램프가 이 값을 읽어 낙하 스태거 구성을 정한다), 모든 칩이 가시 영역 안으로 들어오면 **밀폐 천장**(`size.height - wallInset`)으로 내려와 상자가 화면과 일치한다. 새 재료를 화면 위에 놓기 직전엔 반드시 천장을 먼저 연다(밀폐된 채 스폰하면 칩이 천장 **위**에 얹혀 영영 안 보인다). ③ **표류칩 회수** — 천장이 `sealTimeout`(현재 **6s**) 넘게 열려 있으면(= 기울기 탓에 위쪽에 갇혔다는 뜻) 밀폐 천장 바로 아래로 끌어내리고 속도를 죽인 뒤 닫는다. 리사이즈로 천장이 내려올 때도 즉시 회수한다(상자 밖의 칩은 스스로 못 들어온다). 6s는 런치 캐스케이드를 넉넉히 넘도록 잡은 안전값이며, 정상 낙하 중인 칩을 순간이동시키지 않는 것이 상한의 유일한 기준이다 — 계산식이 아니라 **기기 실측(tiltLab)으로 다시 유도할 예정**. 드래그 클램프도 같은 선(`wallInset` / 밀폐 천장)을 쓴다.
- **던지면 회전한다.** 잡은 지점의 중심 오프셋과 릴리스 속도로 토크 암을 계산해 `ω = (r × v) / (side² × 0.25)`, `±6 rad/s`로 클램프한다. 집을 때는 항상 각속도를 0으로 리셋.
- **착지가 통통 튄다.** `SKPhysicsContactDelegate`로 충돌 임펄스를 질량으로 나눈 근사 Δv(pt/s)를 재서, **30 이상**이면 눈에 보이는 스쿼시(가로 +3~6% / 세로 −3~6%, `--dur-2` 180ms, 눌림 35% ease-out + 복귀 65% ease-out, 배율은 항상 정확히 1로 복귀, 상한 **260**에서 최대 눌림). Reduce Motion·유휴 상태·드래그 중인 칩은 스쿼시를 생략한다.
- **부딪히면 달그락 — 재료별 촉감(CoreHaptics).** 햅틱은 스쿼시와 **다른 축**을 쓴다: 눌림은 질량으로 나눈 Δv(같은 높이서 떨어진 무거운/가벼운 칩이 같게 눌려야 한다), 촉감은 **질량으로 나누지 않은 생 임펄스**(운동량 전달이 곧 체감 크기 — 소고기가 잎사귀보다 묵직해야 한다). 충돌마다 `.hapticTransient` 하나를 치되 **세 관문**을 모두 통과한 것만 발화한다: ① 임펄스 **6 미만** 무시(안착 중 스치는 접촉 제거) ② 전역 최소 간격 **45ms**(= 22Hz 상한, 이보다 촘촘하면 개별 '달그락'이 뭉개져 연속 진동으로 들린다) ③ 같은 쌍 쿨다운 **140ms**(두 재료가 비빌 때의 연타 방지, 쌍 테이블 상한 64). 세기는 임펄스 6에서 `0.18`로 시작해 **90**에서 `1.0`으로 포화하고, 물성 클래스의 세기 배율(0.42~1.0)을 곱한다. **날카로움은 물성이 정한다** — `0.10`(두부·밥, 뭉툭한 '퍽') ~ `0.95`(캔·병, 쨍한 '클링'). 칩끼리면 **무거운 쪽**이 촉감을 주도한다. **§7.6의 의미별 햅틱 매핑(판정·성공·파괴)은 그대로다** — 이건 그 옆에 새로 놓는 **물리 질감 계열**이고, `.sensoryFeedback`은 세기·날카로움 파라미터가 없고 trigger 변경마다 물리 필드까지 다시 그려 여기엔 쓸 수 없어 CoreHaptics를 직접 쓴다. 엔진은 **씬이 보이는 동안만** 켠다(가려지면 내리고 쿨다운 테이블도 비운다). **Reduce Motion에서도 햅틱은 살아 있다** — 그건 시각 배려지 촉각 배려가 아니다(§7.4). 햅틱 하드웨어가 없으면(시뮬레이터) 조용히 무시한다.
- **질량은 실루엣 크기에서 나온다.** 글리프 실측 bbox 면적비(53종 평균 대비) × `0.7`을 `[0.45, 1.1]`로 클램프(실효 0.45~1.06 — 사과가 가장 무겁고 고구마·만두 등 2종만 하한에 걸린다, 상한에 걸리는 글리프는 없다). 드래그·던지기는 속도를 직접 조종해 조작감은 질량과 무관하고, 질량은 서로 충돌해 밀칠 때만 드러난다.
- **물성은 6종 클래스로 묶되 회전·마찰 축만 차등한다.** `standard`(기본값 그대로 — 표에 없는 글리프는 완전 무변화) · `light`(잎·해조·버섯·빵) · `rolling`(계란·토마토·사과 등 둥글고 매끈) · `heavy`(덩어리 단백질·큰 과채) · `container`(갑·병·캔·유제품) · `soft`(두부·밥·면·만두). 차등하는 축은 **마찰**(0.30 rolling ~ 0.82 soft — 기울였을 때 미끄러지나 붙나), **각감쇠**(0.78 rolling ~ 0.98 soft — 구르나 안 구르나), **반발**(기준 0.12에서 클래스별 ±0.02), 그리고 위 햅틱의 **날카로움·세기 배율**이다. **낙하 축은 차등하지 않는다** — 중력 `42`와 `linearDamping 0.2`는 전 클래스 공통으로 유지한다. 클래스별 종단속도(= 중력/감쇠)를 다르게 주면 재료가 둥둥 뜨며 가라앉는 수중감이 되는데, 그건 이 절이 규정한 "쿵" 감각의 정반대이고 매 실행마다 CTA 앞에 수 초의 대기를 만든다. 클래스의 `mass` 필드는 **햅틱 대표자 선정용 랭킹 키일 뿐** `body.mass`에 대입하지 않는다(실제 질량은 위 실측 면적비 파생이 정본).
- **터치는 한 손가락만 추적** — 드래그 중 추가 손가락은 무시(멀티터치로 상태가 꼬이지 않음). 탭/드래그 판정은 시작점 기준 **누적 이동 8pt** — 아무리 느리게 끌어도 탭으로 오판하지 않는다. 씬은 다른 탭·오버레이에 가려진 동안 **일시정지**(배터리).
- **씬 위 이름 라벨 없음** — 실루엣 더미는 일러스트만으로 깨끗하게 둔다. 이름·신선도·D-N은 아래 뱃지 행(§13.5 `IngredientBadge`)이 전달한다.

### 13.5 컴포넌트
**종이컷 아이콘 버튼(`PaperIconButton`)** — 첨부 레퍼런스(Tossed/Ate) 폼. **손으로 자른 종이 9각형**(`PaperBlob`) **솔리드** 면 + **종이 질감**(`PaperGrain`) + **가운데 채운 아이콘** + **아래 라벨**. 인텐트: `primary`(Blue/흰 아이콘) · `soft`(블러시 `urgent-light`/`urgent-dark` = Tossed) · `fresh/soon/urgent/neutral`(§2.6). 그라데이션 없음. `--shadow-1` + 통통 프레스. Ate/Tossed/Freeze(urgent 한정, `neutral` + 눈꽃) 결정 등. 냉동 재료는 냉장고 카드에서 **FROZEN 도장**(`DDayStamp` 재사용, `blue-dark` 잉크)으로 구분 — 스택은 쪼개지 않는다(영수증 더미 메타포 유지).

**종이 버튼(`PaperButton`)** — 와이드 1차 CTA. **`PaperCutRect`(모서리 잘린 길쭉한 8각형)** **솔리드** 면 — 아이콘 버튼 octagon과 같은 계열. **종이 질감(`PaperGrain`)** + 통통 프레스. **아이콘·그라데이션 없음(텍스트만)**. `primary`=Blue/white, `secondary`=sub/ink. `--shadow-1`(§6.2 예외). `요리시작`에 사용. **면(라벨)은 `PaperButtonLabel`로 떼어져 있다** — `PhotosPicker`·`ShareLink`처럼 `Button`이 아닌 컨트롤에도 같은 CTA 재질을 씌우기 위해서다(호출부가 `.buttonStyle(.paperPress)`를 함께 건다). 표면을 손으로 재조립하지 않는다 — fill 토큰·질감·그림자가 갈려 앱에 secondary CTA가 두 종류로 보인다.

**재료 뱃지(`IngredientBadge`)** — **캡슐 아닌 `PaperRect`** 면 + **좌측 인디케이터 바**(둥근 직사각, 신선도 dark색) + 이름(+ D-N). **탭 = Ate/Tossed 판정 묻기**(§13.6 — 고르면 뱃지·실루엣 모두 뿅 사라짐, `--spring-pop`). 히트 영역은 시각과 무관하게 **최소 44pt**(§7.3, `AddBadge` 동일). `AddBadge`(점선 종이 사각 ＋)로 추가.

**오더 메모 카드(`OrderMemoCard`) — 단서 카드로 축소(2026-08 owner decision).** 티켓은 "무엇을 만들지"의 단서까지만 준다 — 조리법(단계)은 카드에 싣지 않고, 발주 후 조리 화면의 영상 링크가 그 역할을 맡는다(아래 §13.6). 콘텐츠는 순서대로: ① **모노 크롬 크라운 한 줄** — 좌 "ORDER · REFFI KITCHEN" + 우 "#NN"(둘 다 `monoTicketLabel`, 색만 ink/ink2로 갈린다) ② 점선 룰 ③ **판정문 키커**("Saves N expiring today" / "Clears N before they spoil" / "Use these while fresh" — urgentDark/soonDark/freshDark, role은 `metaText`이고 강조는 신선도 색이 맡는다) ④ 메뉴명(최대 2줄) ⑤ 메타 행(시계 아이콘 + "N min · M to use") — ④·⑤ 오른쪽에 **요리 아이콘**(`RecipeHeroIconView`, `ReffiDishIcon.ticket` 68pt, 정체는 §13.7 히어로 체인이 정한다). 글이 주인공이고 그림은 오른쪽 여백에 얹힌다 — 이름 위에 한 줄로 올리면 주문서가 메뉴판이 되고, 이름+시간 블록 높이를 넘겨 키우면 같은 문제가 생긴다. 조리 티켓과 같은 자리·같은 크기다 ⑥ 점선 룰 ⑦ "ON THE TICKET" 섹션 라벨(크라운과 **같은** `monoTicketLabel`·verbatim — 다른 모노 티켓 크롬과 함께 번역하지 않는다) ⑧ **재료 이름 블록**(최대 5줄 + "+N more on the ticket" — 체크박스 없음. 체크하며 따라가는 목록이 아니라 "무엇이 들어가나"를 한눈에 읽는 단서 블록이다. D-day 종이 칩(`PaperCutRect`, §13.1)은 **soon·urgent에만** 붙인다 — 아직 여유 있는 재료의 카운트다운은 노이즈일 뿐이라 지금 급한 것만 남긴다) ⑨ 부족한 재료가 있을 때만 "Short: …" 문구(최대 2줄) ⑩ **"이걸로 요리" 발주 CTA**(파랑 `PaperCutRect`). 크림 종이(`ReceiptShape` 상·하 톱니 절취, `--paper-surface`). 발주(Fire the Ticket)하면 START 스탬프가 쾅 찍히고 재료 줄이 그어진다(muted + strikethrough). 내부 스크롤 + 하단 페이드는 극단 Dynamic Type(접근성 큰 글씨)에서만 발동하는 **오버플로 안전망**으로만 남긴다 — 기본 텍스트 크기에선 항상 다 들어간다. **PREP 단계 미리보기는 제거했다** — 조리 중 텍스트 단계를 실제로 따라가는 사용자가 없어, 상세는 조리 화면의 영상 링크 하나로 정리했다(§11 참고).

**타이포(행동 표면).** §3의 5단계 밖 보조 스케일 9종(§3.5 표 정본)을 **행동 표면에만** 쓴다: **뱃지·아이콘버튼 라벨 = `badgeLabel`**(Pretendard SemiBold 15 / 자간 −0.15 — `PaperIconButton`·`IngredientBadge`·`AddBadge`), **오더 티켓** = 모노 헤더 `monoTicketLabel`(Bold 13 / 자간 2.5) + 서브 `monoEyebrow`(Bold 10 / 자간 1.6) + 메뉴명 `menuName`(Bold 26) + 체크리스트 `checklistItem`(SemiBold 16) + START 스탬프 `stampLabel`(Bold 34). 정보 표면엔 쓰지 않는다(§3.3).

**입력 시트도 행동표면 언어를 따른다 — 그리고 재료 추가는 이제 영수증 스캔 하나뿐이다.** 사용자 결정(2026-08-01): 일러스트 사전 픽커·검색 필드·직접 입력 폼을 주 추가 플로우에서 **전부 제거**했다 — 지금 냉장고가 비었는데 뭔가 사려는 상황을 상정하지 않고, 장 본 뒤 영수증으로 한 번에 등록하는 사용 패턴에 집중한다. `AddIngredientSheet`는 얇은 래퍼로, 실제 내용은 `ReceiptScanView`에 전부 위임한다. 플로우는 3단계: ① **소스 선택** — 크림 캔버스 위 카메라(`VNDocumentCameraViewController`, 자동 크롭·다중 페이지)와 사진 선택(`PhotosPicker`, 최대 3장, 면은 `PaperButtonLabel` `secondary` + `paperPress`) 중 고른다. ② **처리** — 온디바이스 Vision OCR(ko+en)로 텍스트를 읽고 `ReceiptParser`가 사전 매칭 후보로 바꾼다(네트워크 전송 없음, "Everything is read on this device" 카피로 명시). ③ **확인 리스트** — 인식된 각 줄이 후보 행(체크·이름·원문·수량·연필)으로 뜨고 **기본 전체 선택**(빼는 쪽이 마찰 적음). 선택 체크는 종이 상자(`PaperRect` `radius-sm`) + Phosphor 체크 글리프이고 체크·연필 모두 `paperPress`다 — SF Symbol과 `.plain` 버튼 스타일은 쓰지 않는다(§13.4 아이콘 단일 계열, §7.5 종이 프레스), 사전 미매칭이거나 shelfLife 데이터가 없으면 **"Est. date: check" 배지**(soonDark 종이 칩 `PaperCutRect`)로 추정 기한임을 알린다. 연필 아이콘이 여는 **`CandidateEditSheet`**(흰 영수증 카드 `ReceiptShape` + `DashedRule` 행)에서 이름·수량·보관·소비기한·구매처를 직접 고칠 수 있다 — **여기가 사전 밖 이름을 만드는 경로**다(별도 커스텀 시트가 아니라 후보 편집 자체가 그 역할을 겸한다). 하단 `PaperButton`("Add N items")로 선택분을 일괄 등록한다. 상단은 **`SheetHeader`**(좌측 "Scan a receipt" + 종이 X). 쇼핑리스트 **재입고**(`ShoppingListView`)는 여전히 시트조차 열지 않는다 — Add 탭이 직전 이력 스냅샷(보관·구매처·수량, 냉동이었다면 냉장으로) + 사전 기본 기한으로 곧장 재고에 채운다.

**예외 하나 — To buy 화면의 재료 검색(2026-08-05).** 위 단일 경로 결정에 **To buy 화면 한정 예외**를 둔다: 목록 아래 `PaperButton`("Add item", `secondary` — 1차 행동인 행별 파란 Add를 덮지 않게)이 **재료 검색 바텀시트**(`ToBuySearchSheet`)를 연다. 근거는 이 예외가 **추가 플로우가 아니라 장보기 메모**라는 데 있다 — To buy 목록은 소비 이력에서 파생되므로 **한 번도 안 써본 재료는 원천적으로 뜰 수 없고**, 습관 제안이 닿지 못하는 그 한 칸을 사용자가 손으로 채우는 것이다. 2026-08-01 결정이 겨냥한 "냉장고가 비었는데 뭔가 사려는 상황"과는 다른 국면이고, **재고에 재료를 넣는 메인 추가 플로우는 여전히 영수증 스캔 단일 경로**다(검색으로 고른 항목은 `manualToBuy`라는 '구매 전' 목록 상태로만 들어가고, 실제 반입은 그 뒤 Add 재입고나 영수증 스캔이 한다). 목록 카드는 **직접 담은 것(`Added by you`) / 이력 제안** 두 구역으로 나뉘고 사이는 `DashedRule`(보더 금지 §6), 두 구역은 같은 Add/Skip 문법을 쓴다. 시트는 `SheetHeader`("Add to list") + `.medium`/`.large` detent + dragIndicator(§14.5), 필드는 종이 인풋(돋보기 + 클리어 ×)이다. **검색어가 비어 있을 때는 삭제된 픽커의 재료 배열 UI가 그 자리를 채운다**(2026-08-05 이식 — 가로 칩 그리드를 대체) — 적응형 74~96pt 열의 **세로 타일**(56pt `PaperSilhouette` + 이름, 타일 간 s2 / 섹션 간 s5)을 모노 올캡 섹션 헤더로 묶고, `FREQUENT` → 사전 전체를 `FoodGlyph.categoryLabel`로 나눈 카테고리 섹션(`FoodGlyph.categoryOrder` 고정 순서 — 냉장고 필터 칩과 **같은 상수**를 본다, 항목 있는 카테고리만) 순으로 쌓는다. FREQUENT는 이력 빈도 상위 12종(제안 목록과 달리 **재고 보유·'이번엔 안 사기'를 안 본다**: 자주 쓰는 건 또 사고, 이건 제안이 아니라 빨리 담기 단축키다), 이력 상위가 12종에 못 미치면 **이력 종수와 무관하게 부족분을 항상** 큐레이션 시드로 채워 12종을 유지한다(중복 제거 — 시드 12종을 덧붙이는 게 아니라 12칸을 채운다). 4종 같은 문턱을 두면 이력이 3종에서 4종으로 느는 순간 칩이 12개에서 4개로 급감하는 계단식 역행이 생긴다. '빈 그리드는 기능이 아니라 고장으로 읽힌다'는 근거가 이력 규모와 무관하게 항상 성립해야 한다. **타이핑한 결과도 같은 타일 그리드**다 — 영수증 리스트로 바뀌지 않는다: 쿼리는 배열을 *거르는* 조작이지 다른 화면으로 가는 조작이 아니라, 결과는 빈 쿼리와 동일한 타일(`tile`)을 그대로 재사용해 표현·접근성·담기 규칙이 한 곳에 산다. 담긴 타일엔 **우상단 체크**가 남는다(`PaperDropdown`과 같은 선택 표시). 픽커 원본과 달리 **탭이 냉장고 반입이 아니라 `addToBuy`**다 — 표면만 픽커고 의미는 여전히 장보기 메모다. 카테고리 섹션까지 붙어 목록이 길어졌으므로 `.medium`은 진입 높이일 뿐이고 그리드는 스크롤·`.large` 승격을 전제한다. **두 상태의 타일은 탭 의미가 같고**, 둘 다 담김 여부로 미리 막지 않고 항상 store로 보낸다(이미 수동으로 담겼으면 no-op, 파생 제안이면 그 제안을 흡수 — 뷰가 막으면 흡수 경로가 UI에서 도달 불가해진다). 타일 탭은 `.success` 햅틱(§7.6 성공 완료) 후 **시트를 닫지 않는다** — 장보기 메모는 보통 한 번에 여럿 적는다. **사전 밖 이름을 자유 입력으로 만드는 경로는 여기 두지 않는다**(결과 없으면 "No match"에서 멈춘다) — 그 역할은 계속 영수증 스캔의 `CandidateEditSheet` 하나이고, 예외는 최소로 유지한다. **타일 라벨의 표기**는 사전 캐논을 그대로 쓰지 않는다 — 정본 사전의 영문 표기는 매칭용 소문자("bok choy")라 표시 시점에 단어 첫 글자를 올린다(`IngredientLexicon.Entry.displayName`). 캐논 그대로 그리면 이 그리드만 소문자이고 냉장고 카드·레시피는 대문자라 한 화면 건너 같은 재료의 표기가 갈린다. 한글은 대소문자가 없어 그대로다.

**냉장고 요약·정렬(`FridgeView`)도 §13 문법을 공유한다.** 헤더 아래 **요약 페이저**(장보기 · 무낭비 리포트, `TabView` 한 장씩 스와이프)는 `PaperCutRect` 종이컷 버튼 면(`PaperButton`·아이콘 버튼과 같은 계열) + 옅은 그레인 + `--shadow-1` + 점 인디케이터로 짓는다. 스택 위 **정렬 칩**(현재 정렬 라벨을 상시 노출)과 **간편보기 원탭 토글**은 둘 다 `PaperRect` 면 + `paperEdge`, 히트 영역 최소 44pt(§7.3). 정렬 칩을 탭하면 스톡 `Menu`/`Picker` 팝업(흰 시스템 라운드 렉트) 대신 **앱 최초 커스텀 드롭다운 `PaperDropdown`**이 칩 바로 아래에 뜬다 — `PaperRect` 면 + `paperEdge` 헤어라인 + 옅은 `PaperGrain` + `--shadow-1`, 행마다 라벨(좌) + **선택 행에만 체크 글리프**(우, `blue-dark`), 행 사이 `DashedRule`(절취선), 최소 44pt 히트·`paperPress`. 트리거 칩 앵커 아래에 `overlayPreferenceValue`로 띄워 `ScrollView`에 클리핑되지 않고(zIndex `dropdown`), 딤 없는 투명 탭 캐처가 바깥 탭을 받아 닫는다(가벼운 드롭다운 — 모달 아님, `scrim` 없음), 진입 `--spring-pop`·이탈은 더 빠르게(§7.5). **"탭 → 옵션 목록"은 앱 전체에서 이 한 문법이다** — 편집 시트(재료·스캔 후보)의 단위·보관 선택도 스톡 `Menu`/`Picker`가 아니라 같은 `PaperDropdown`이고, 트리거는 현재 값을 상시 노출하는 종이 칩(`PaperDropdownTrigger`, 히트 44pt)이다. 시트 안에서는 시스템 팝오버와 달리 오버레이가 시트 밖으로 나갈 수 없으므로 **아래/위 여유를 재 뒤집고 높이를 캡**하며, 넘치면 팝업이 내부 스크롤한다(단위 10종). 시각 선택(`NotifyTimeSheet`)만 `.wheel`로 남는다 — 다이얼은 목록이 아니다. **간편보기(`FridgeCompactRow`)**는 틸트·겹침 없는 납작한 흰 영수증 한 조각 — 실루엣 + 이름 + 수량 + D-day(냉동이면 + FROZEN 도장)를 한 줄에 정렬해 훑어보기(스캔)에 최적화한다.

**카테고리 필터 칩 행**(신규, 2026-08)은 헤더·요약 아래, 리스트 위에 가로 스크롤로 얹힌다 — 재고에 실제 있는 카테고리만 캐논 순서(Veg → Fruit → Dairy → Meat → Seafood → Protein → Bakery → Grain → Pantry → Other)로 노출하고, 맨 앞에 "All"이 붙는다. 정렬 칩과 같은 `PaperRect` 문법이되 **선택 상태는 면 반전**으로 표현한다 — 선택 = `ink` 면 + `onInk` 글자, 비선택 = `paper` 면 + `paperEdge` + `ink` 글자(정렬 칩은 라벨을 상시 노출하는 방식이라 문법이 다르다 — 드롭다운의 체크 문법은 팝업 전용으로 남긴다). 단일 선택, 재탭·"All" 탭으로 해제. **카테고리가 한 종류뿐이면 칩 행 자체를 그리지 않는다**(동작 없는 UI 금지). 세션 한정 `@State`(정렬과 달리 영속화하지 않음) — 필터링된 목록이 비면 자동으로 전체로 풀리고, 필터 밖으로 밀려난 펼침 카드는 접힌다(빈 화면에 가두지 않기 위한 안전망). 그룹 키는 저장된 `ingredient.category` 자유 문자열이 아니라 **`FoodGlyph.categoryLabel`**(글리프 파생, 항상 캐논 10종이라 전부 번역돼 있고 칩 집합이 안정적) — 레거시 자유 문자열("Meat · Beef" 등)도 한 칩으로 흡수된다(카드에 보이는 표시 텍스트는 그대로, 필터 키만 다르다). 히트 영역 최소 44pt(§7.3), 선택 칩엔 `.isSelected` 접근성 트레잇.

### 13.6 메인 플로우 (물리 낙하 → 더미+뱃지 공존 → 티켓)
1. 사용 가능한 임박 재료를 백그라운드 계산 → 추천.
2. 재료가 **위에서 진짜 물리로 떨어져 충돌·바운스하며 쌓여 그대로 남는다**(SpriteKit). 사라지지 않고, 끌어서 던질 수 있다.
3. 같은 재료의 **뱃지가 요리시작 버튼 위에 함께 남는다**(실루엣 더미 ↔ 뱃지 두 표현 공존). 실루엣·뱃지 **어느 쪽을 탭하면 "먹었나/버렸나(Ate/Tossed)" 결정**(종이 카드 + `PaperIconButton` 쌍 + 명시적 "Keep it" 취소, §13.5)이 뜨고, 고르면 그 재료가 **뿅 사라진다**(SpriteKit 스케일 팝 + SwiftUI scale 트랜지션, `--spring-pop`) + 이력 기록(낭비 추적). **오늘 만료(urgent)이고 아직 얼린 적 없는 재료엔 3번째 선택지 Freeze**가 나타난다 — 버리기 직전의 구제(미리 얼려두기 아님). 얼리면 원본 소비기한은 그대로 두고 `frozenAt + 유예 14일`의 **새 D-day**를 받으며(무기한 아님), 작업대에서 빠졌다가 **유예 D-3에 재등장**한다("해동해서 요리해" 재약속). 재냉동 불가(1회 제한 — 미루기 버튼 방지). 빈 자리는 냉장고의 다음 임박 재료가 떨어져 채운다(`FridgeStore.counter` 작업대, **보충 목표 6** — 직접 추가·되돌리기로 일시 초과 가능, 예약·유예 넉넉한 냉동 재료 제외). ＋로 추가 — **영수증 스캔이 추가 플로우의 전부**다(§13.5, 일러스트 픽커·검색·직접 입력 폼 제거 — To buy의 재료 검색은 재고 추가가 아니라 장보기 메모라 이 규칙 밖이다, §13.5 예외).
3-1. **판정 바스켓(마그네틱)** — 칩을 드래그하면 **좌상 휴지통(Tossed)·우상 냄비(Ate)** 종이 블롭 바스켓이 나타난다(평소엔 숨김). 손가락이 바스켓 반경(≈88pt)에 들면 재료가 **자석처럼 바스켓 중심으로 끌려 들어가고**(추종 민첩도 상승 + 1.14× 확대), 벗어나면 풀린다. 캡처된 채 놓으면 오버레이 없이 바로 확정(되돌리기 토스트가 안전망). 탭 → 판정 오버레이는 접근성 경로로 유지.
3-2. **미션 헤더** — 헤더 카피는 오늘의 상태 한 문장(오늘 N개 위험 / 곧 먹을 N개 / 전부 신선). 누계 카운트는 MyPage로 이양, 신선도 점 행은 뱃지와 중복이라 없앴다.
4. **요리시작** → **티켓 덱**(풀스크린, **네비 없음**, 닫기 X). 클립 없이 **실제 티켓이 겹쳐 쌓인 덱** — 뒤에 보이는 종이가 다음 티켓이다(위로 머리를 내밈, 교대 틸트). **수평 플릭은 방향이 곧 의미다** — **왼쪽 = Pass**: 맨 앞 티켓이 뒤로 들어가고 다음이 스프링으로 올라온다(순환; reduce-motion이면 즉시 전환). **오른쪽 = Cook**: 카드의 "Cook this"와 **같은 발주**다(같은 상태 변화·햅틱·발주 후 덱 잠금) — 넘김이 아니므로 카드는 날아가지 않고 제자리로 스프링 복귀하고 그 위에 START 슬램이 찍힌다. 임계는 양쪽 모두 예측 변위 160pt이고, **세로 성분으로는 커밋하지 않는다** — 방향이 의미를 가진 뒤로는 세로로 크게 튕긴 드래그가 Cook인지 Pass인지 지목할 수 없다(옛 `|Δy| > 220` 폴백 제거). 단서 카드는 기본 텍스트 크기에서 본문이 다 들어가 안쪽 ScrollView가 세로 드래그를 삼키지 않으므로, 그 폴백은 카드 본문 어디서든 오발동했다. 드래그 중재는 **덱 한 곳**(`frontDrag`)에서만 하고, 한 제스처의 **우세 축을 처음 한 번만 판별해 고정**한다(|Δx| > |Δy|·1.4 = 수평 플릭) — 매 이벤트 재판정하면 곡선 드래그에서 분기가 오가며 카드가 손가락과 어긋난 자리에 굳는다. 축이 갈리지 않는 애매한 구간(대략 35.5°~54.5°)은 끝까지 **아무 것도 커밋하지 않는다**(추종 피드백 없이 상태가 뒤집히지 않게). 수평 드래그 중엔 카드 좌우 가장자리·카드 세로 중앙 높이에 **방향 예고 블롭**이 뜬다 — 홈 판정 바스켓(3-1)과 **같은 문법**(86pt `PaperBlob` 9각 면 + 같은 블롭의 0.35 스트로크 + 30pt 채운 아이콘, **글자 없음**): 왼쪽 Pass는 중립 잉크(`neutral-200`(sub) 면 + `neutral-700`(ink2) 잉크)의 **순환 화살표**(Pass의 실제 동작이 덱 순환이라 기호가 동작과 일치한다 — 파괴도 거절도 아니다), 오른쪽 Cook은 브랜드 블루(`blue-light` 면 + `blue-dark` 잉크)의 냄비다(Cook은 "Cook this" CTA·Ate 바스켓과 같은 긍정 액션 색족, Pass는 파괴가 아니므로 urgent 빨강을 쓰지 않는다). 등장·소멸은 0.15초 페이드(알파 0.96)이고 손을 떼면 **커밋 여부와 무관하게** 즉시 사라진다. 커밋 임계의 60%를 넘기면 그 방향 블롭만 **1.14× 확대**된다(색 변화 없음 — 바스켓과 동일). 블롭은 **시각 전용**이라 VoiceOver엔 노출하지 않는다 — 같은 동작의 접근성 경로는 카드의 "Cook this" 버튼과 덱의 "Next ticket" 커스텀 액션이다(바스켓이 탭 판정 오버레이에 접근성을 맡기는 것과 같은 분업). 넘길 티켓이 없는 1장짜리 덱에선 Pass 블롭을 띄우지 않는다(지키지 못할 예고) — 다만 오른쪽 Cook은 1장 덱에서도 성립한다. **발주(Fire the Ticket) = 예약** — 티켓의 사용 재료를 예약해 작업대·추천에서 빼되(START 슬램 = 비우기 연출), **재고 차감·이력 기록(`Cooked · 레시피명`)은 요리 완료(Finish)에서 확정**된다. 소비 후보는 작업대 6개가 아니라 **전체 가용 재고** — 티켓이 쓰는 재료가 냉장고에 있으면 함께 예약돼 유령 재고가 남지 않는다. 커버당 발주는 1회(더블 파이어 방지), 발주 후 덱 잠금. **카드는 화면 높이에 캡되고**(safe area 연동, 재료가 많아도 톱니 엣지가 잘리지 않는다) **중간 섹션은 필요 시 카드 안에서 스크롤**된다(접근성 큰 글씨 안전망 — 헤더·발주 밴드는 고정). **뒤 티켓의 노출 띠는 글자 없는 빈 종이다** — depth ≥ 1 카드는 크롬 텍스트(ORDER·#NN·TABLE 행)를 렌더하지 않는다. 앞 티켓의 절취 톱니는 골이 파인 지그재그라, 골 사이로 뒤 카드의 크롬 행이 가로로 잘린 반쪽 글리프가 되어 새어 나온다(라이트·다크 동일). 노출 띠는 "다음 종이가 한 장 더 있다"만 말하면 되므로 글을 싣지 않는다. 승격(뒤→앞)에서 헤더가 튀어나오지 않도록 레이아웃은 유지하고 **불투명도만** 되살려 덱 회전 애니메이션을 함께 탄다. 성능은 별도 장치로, **가장 깊은 티켓만 본문·CTA를 생략**(머리 높이까지만 그린다)해 전환 프레임드롭을 줄인다 — 바로 뒤 티켓은 풀 렌더라 플릭 승격이 내용 변화 없이 매끄럽다. **발주 덱은 시드 레시피 + 사용자 커스텀 레시피로 구성된다** — 인앱 AI 생성 레시피는 2026-08 owner decision으로 제거했다(§11 참고, 서버 `recipe-generate` 함수 자체는 유지). 덱에 별도 AI 트레이·sparkle 배지·진행 힌트는 더 이상 없다.
4-1. **조리 세션 화면 + 진행 카드(Cooking now)** — 발주하면 곧장 조리 화면이 열린다: 발주 티켓과 같은 모노 크롬("ORDER · FIRED" + "N used") + 메뉴명 + 점선 룰 + **"Open recipe videos" 아이콘+라벨 와이드 CTA**(유튜브 검색을 열어 조리법의 1차 경로로 승격 — blush `urgentLight` 종이컷 면, 아래 파랑 "Finish cooking" CTA와 색으로 역할을 가른다) + 옆의 보조 `Share` 아이콘(공유 카드는 아래 참고) + 기대치 한 줄("Cook it your way. The video has the details.") + 점선 룰 + **"Finish cooking"** + "조리 취소" 텍스트 버튼. **단계 체크리스트는 없앴다**(2026-08 owner decision, §11 참고) — 조리 중 텍스트 단계를 실제로 따라가는 사용자가 없어, 상세는 영상 하나로 정리했다. **"요리 완료"** 시 재료별 **"다 썼어요(기본)/조금 남았어요" 원탭 확인** — 남은 재료는 수량 절반으로 냉장고에 잔류하고, 나머지가 이력으로 확정된다. **"조리 취소"**는 예약을 해제해 재료를 그대로 되돌린다(기록 없음). 메인 헤더 아래엔 미니 영수증 스트립("COOKING NOW" + 메뉴명 + 경과 시간)이 남고, **탭하면 조리 화면으로 복귀**한다. 시작 시각은 영속화(재실행에도 유지), 발주 undo = 예약 회수.

**공유 카드(`RecipeShareCard`)도 단서까지만 담는다** — "ORDER · FIRED" + "N used" → 메뉴명 → "N min"(있을 때만) → 점선 룰 → "ON THE TICKET" → 재료 이름 최대 5개 + "+N more on the ticket" → 점선 룰 → "REFFI · KEEP IT FRESH" 푸터. 조리 단계는 싣지 않는다 — 앱 안에서도 단계를 보여주지 않으므로 공유 이미지만 다른 약속을 하면 안 된다. 항상 라이트 스킴 고정(§2.8) + `ImageRenderer` 3배 스케일, 카드 폭 340pt.
5. **되돌리기(통합 undo)** — 판정·발주 직후 6초 동안 상단 잉크 캡슐 토스트(**탭 공통**, 하단 CTA·네비 안 가림)로 되돌릴 수 있다 — 재료·이력을 되살리고 **작업대는 판정 전 스냅샷으로 원복**(자동 보충분 회수). 작업대·되돌리기 상태는 store에 살아 **탭을 오가도 유지**된다.

### 13.7 요리 아이콘 (Dish Icons)

- **왜 원형인가** — 레시피 80종(+커스텀 무한)을 하나씩 그리지 않기 위한 축: **원형(archetype) 15종** — `stewPot`(깊은 냄비) · `soupBowl`(대접) · `riceBowl`(덮밥 공기) · `noodleBowl`(면기) · `pastaPlate`(파스타 접시) · `skillet`(볶음 팬) · `platedMound`(밥 산 접시) · `grillPlate`(구이 접시) · `discStack`(원판) · `rollSlices`(롤 단면) · `sandwichStack`(샌드위치 층) · `foldedWrap`(반달 또띠아) · `curryPlate`(커리 두 존) · `sideBowl`(낮은 볼) · `bakeDish`(오븐 그릇). 60pt 섬네일에서 먼저 읽히는 건 색이 아니라 실루엣이라, 원형끼리는 외곽이 전부 다르다.
- **변주 축** — `DishLook`: `fill`(주 내용물) · `accent`(원형마다 해석이 다른 보조 면) · `vessel`(그릇 재질 6종: `clay`·`porcelain`·`indigo`·`wood`·`iron`·`glaze`) · `mark`/`mark2`(고명 — 모양 9종: `cube`·`ring`·`baton`·`disc`·`dot`·`leafy`·`yolk`·`strip`·`wedge`) · `layers`. 같은 원형이라도 색·고명 변주로 다른 요리로 읽힌다(김치찌개=두부 큐브 vs 순두부찌개=노른자).
- **역할 분담** — `DishSilhouette`는 **렌더러**다: 재료 글리프와 같은 컷페이퍼 문법(직선 면 5~12각, 몸통 2~3톤 면분할, 아웃라인 없음)으로 그리고, `Canvas` 기반이라 크기와 무관하게 항상 같은 그림이다. `DishGlyphCatalog`는 **정체를 결정**한다 — 시드 80종 손 배정 표(`table`) + 이름 키워드 추론(`keywordArchetype`) + cuisine 기본값 + `stableHash` id 변주(매핑 밖 레시피가 몰려도 서로 다른 색이 되게)로, 실행마다 값이 흔들리지 않는다. 팔레트(`DishPalette`)는 §13.3과 같은 규율 — OKLCH 정본, hex 금지, 스킴 불변 고정색.
- **`FoodGlyph`(§13.3)와의 분업** — 재료 글리프는 재료를, 요리 아이콘은 완성된 요리를 그린다. 다만 김밥처럼 **메뉴 자체가 모티프인 요리형 글리프**는 `FoodGlyph` 쪽에 손으로 그려 두었고(`FoodGlyph.dishKeywords` 큐레이션 표), 히어로 체인에서 카탈로그 이름 추론보다 앞선다. **이 표는 히어로 체인에서만 조회한다** — 재료명 매칭(`FoodGlyph.match`)에 끼워 넣으면 냉장고에 "김밥"이라 적었을 때 재료 목록에 완성 요리 그림이 뜬다.
- **히어로 체인**(`Recipe.heroIcon`) 4단 — ① 시드 매핑 표(`curatedLook`) → ② 요리형 글리프 큐레이션(`Recipe.dishGlyph`) → ③ 카탈로그 이름 추론(`nameMatchedLook` — 이름이 침묵하면 nil) → ④ 재료 글리프. 정체는 **모델**이 정하고 **뷰**(`RecipeHeroIconView`)는 switch 렌더만 한다 — 표면(오더 티켓 메뉴명 옆 아이콘, 조리 화면, 공유 카드, 내 레시피 목록)마다 조건을 다시 쓰면 같은 레시피가 다른 그림이 된다. **②가 ③보다 앞서는 이유** — 추론은 원형만 맞히고 색은 id 해시라, 손으로 그린 김밥이 있는데 커스텀 "김밥"이 짐작에 덮여 아무 색 롤이 된다.
- **이름만 남은 세션 폴백**(`RecipeHeroIcon.session(name:id:)`) — 발주 후 레시피가 삭제된 조리 세션용. ② 큐레이션이 먼저고, 나머지는 종전 카탈로그 호출과 동일해 기존 동작을 보존한다(빈 아이콘 없음). ④는 세션에 재료가 없어 원천 불가하다. 공유 카드 재렌더 키(`CookingStepsView.ShareCardKey`)가 이 아이콘까지 담는다 — 화면만 폴백으로 갈아타고 공유 이미지가 옛 그림을 들고 남지 않게.
- **재료 실루엣 크기 토큰** `ReffiFoodIcon`(§13.3 `PaperSilhouette`) — `rowMini` 32(조리 티켓 재료 행·온보딩 미니 영수증 행) · `row` 36(장보기·이력·냉장고 간편보기 목록 행) · `card` 46(냉장고 카드) · `tile` 56(검색 그리드 타일) · `hero` 64(펼친 상세). 토큰이 없던 시절 같은 목록 행 역할에 28·32·34·36 네 값이 공존했다 — 탭을 오가며 연달아 보는 행들이라 값이 갈릴 이유가 없어 각각 36·32로 수렴했다(큰 쪽이 정본: 목록 행은 이름 두 줄 블록과 높이를 맞춘다).
- **크기 토큰** `ReffiDishIcon` — `row` 36(내 레시피 행) · `card` 56(공유 카드 340pt 폭) · `ticket` 68(오더·조리 티켓 메뉴명 옆). 오더 티켓과 조리 티켓이 **같은 자리·같은 크기**를 쓴다 — 발주 전후로 아이콘이 점프하면 같은 티켓이라는 연결이 끊긴다.

### 13.8 종이 표면 토큰 (Paper Surface Tokens)

> 영수증 종이는 이 앱의 시그니처인데, 오래도록 토큰 없이 표면마다 손으로 조립됐다 — 같은 카드가 파일마다 다른 톱니·패딩·그림자·점선을 들고 갈라졌다. §13.7 요리 아이콘이 그랬듯 **자리를 몇 개만 두고 호출부는 전부 여기를 경유**한다.

- **영수증 면 모디파이어** `receiptSurface(tooth:seed:alignment:elevated:)` — 톱니 면 + 종이 헤어라인 + 엘리베이션을 한 번에 얹는다. **세로 패딩을 톱니에서 계산(`s5 + tooth`)하는 게 핵심**이다: 톱니는 면 안쪽으로 파고들어 그만큼 여백을 먹는데, 그 보정을 호출부가 손으로 적어 온 결과 같은 카드가 `s5+7`/`s5+3`/`s5`로 갈렸다(톱니를 7로 정해 놓고 보정은 3만 준 카드가 셋). `elevated`는 §6.4와 1:1 — `flat`(빈 상태·결과 없음) · `card`(기본) · `floating`(화면에 한 장만 뜨는 로그인·온보딩 질문 카드). 헤더 행이 따로 있어 위·아래 보정이 비대칭인 카드(`ReceiptCard`·`FridgeCard`)는 자체 프리셋으로 남되 톱니·엘리베이션은 같은 토큰을 쓴다.
- **네비 크롬 여백** `ReffiChrome` — `navHeight` 58(캡슐 네비 실측) · `navBottom` 2 · `navReserve`(= navHeight + navBottom + s6 + s2 = 96, 레이아웃이 네비 몫으로 비워 두는 정적 자리) · `navClearance`(= navReserve + s5 = 120, 끝까지 스크롤했을 때 마지막 카드가 네비 위로 올라오게 하는 스크롤 꼬리 여백). **두 값은 용도가 다르므로 상수도 둘**이다 — 예전엔 같은 목적처럼 보이는 120과 96이 토큰 없이 흩어져 있었고, 진짜 위험은 값 불일치보다 네비 높이를 바꿨을 때 다섯 곳이 조용히 어긋나는 것이었다.
- **판정 존 규격** `ReffiJudgeZone` — `side` 86 · `alpha` 0.96 · `hotScale` 1.14 · `fade` 0.15초 · `hotDuration` 0.1초. 홈의 판정 바스켓(SpriteKit)과 캐러셀의 플릭 예고 블롭(SwiftUI)이 **같은 문법**이라는 §13.4의 요구를 코드가 실제로 지키게 하는 자리다 — 예전엔 두 파일이 각자 `private let`으로 같은 숫자를 들고 "홈 존과 같은 값"이라는 주석으로만 묶여 있었고, 주석은 다음 튜닝을 막지 못한다.
- **절취선 컴포넌트** `ReffiRule(.receipt|.ticket)` — `receipt`는 ink 16% · dash 3/3(영수증 카드의 기본 절취선: 헤더 아래·구역 마감), `ticket`은 ink 22% · dash 4/4(오더 티켓 계열의 굵은 선: 티켓 본문 섹션·편집 시트 필드·드롭다운 행). 앱 전역의 유일한 점선 구분 어휘다(보더 금지 §6.1). 여섯 곳이 각자 구현하던 시절 잉크가 0.14·0.16·0.22로 갈렸고, 0.14는 "Fridge 상세와 동일"이라 적힌 주석과 어긋난 복사 드리프트였다 — `receipt`로 흡수했다.
- **톱니 토큰** `ReffiTooth` — `chip` 6(홈 미니 스트립·온보딩 소품처럼 폭이 좁은 조각) · `card` 7(목록·시트·이력의 영수증 카드) · `ticket` 9(오더·조리·공유 티켓). `ReceiptShape(tooth:seed:)`의 기본값도 `ticket`이다. `seed`는 톱니 **위상** 변주로, `PaperRect`·`PaperBlob`과 같은 시드 규약을 따른다(같은 시드 = 항상 같은 그림, `seed: 0` = 위상 0). 한 화면에 영수증이 여러 장 이어질 때만 쓴다 — 절취선이 자로 잰 듯 같은 자리에서 시작하면 오려 낸 종이가 아니라 찍어 낸 패턴으로 읽힌다. 숫자 리터럴을 호출부에 적지 않는다 — 종이 폭이 좁을수록 톱니를 줄여야 잘게 보이지 않고, 그 판단은 표면이 아니라 토큰이 한다.

> **경계(중요).** 이 레이어는 **메인·캐러셀의 행동 표면에 한정**한다. 냉장고 목록·카드 스택(§8)·일반 정보 화면은 §2~§9 규율(파스텔 색-블로킹·보더 금지·평소 그림자 금지)을 그대로 따른다. 종이컷/글래스/스프링을 정보 표면에 남용하지 않는다.

---

## 14. 모달 · 시트 · 닫기 시스템 (Modal, Sheet & Close System)

> 화면마다 제각각으로 조립되던 닫기·헤더·저장·detent 인터랙션을 컴포넌트와 규칙으로 수렴한다. 이 절의 규칙은 표면 종류(정보 표면/행동 표면)에 관계없이 **앱 전체**에 적용된다 — §13(종이컷·리퀴드글래스·통통 모션)이 행동 표면에 한정되는 것과는 범위가 다르다. 다만 `PaperCloseButton`의 시각 언어(`PaperRect`·`paperEdge`)는 §13.1의 어휘를 그대로 쓴다.

### 14.1 닫기 버튼 — `PaperCloseButton`
앱 전역의 종이 X 닫기 버튼은 **`PaperCloseButton` 단일 컴포넌트**로 통일한다 — 화면마다 다른 크기·색으로 다시 조립하지 않는다.
```
PaperCloseButton(seed: Int = 4, action: () -> Void)
```
- **시각 40pt · 히트 영역 44pt**(§7.3의 최소 터치 타깃 준수 — 시각과 히트를 분리해, `PaperRect` 자체는 40pt로 그리고 `.frame(minWidth:44, minHeight:44)`/`.contentShape`로 탭 영역만 44pt 확보).
- **채움은 `ReffiColor.paper` 단일 토큰**(`--paper-surface`, §13). `.white.opacity(0.9)`·`oklch(0.99, ...)` 같은 변형은 쓰지 않는다.
- `PaperRect(cornerRadius: .md)` 면 + `paperEdge` 단면 헤어라인(§13.1, 분리용 보더 아님) + `.paperPress`(§7.5) + `accessibilityLabel("Close")`.
- 커버 헤더·시트 헤더·doneBar 등, 앱에 있는 모든 종이 X 닫기는 이 컴포넌트로 대체한다.

### 14.2 헤더 — 목적별 2종
헤더는 목적에 따라 **2개 컴포넌트로 분리**하고, 화면마다 인라인으로 복붙하지 않고 재사용을 강제한다.

| 컴포넌트 | 용도 | 타이틀 정렬 | 타이포 | 닫기 |
|---|---|---|---|---|
| `CoverHeader` | 풀스크린 커버 | 중앙 | `.heading` | `PaperCloseButton`(X) |
| `SheetHeader` (신설) | 하단 시트 | 좌측 | `.heading` | 선택적 `PaperCloseButton`, dragIndicator 전제 |

```
SheetHeader(title: LocalizedStringKey, showsClose: Bool = false, onClose: (() -> Void)? = nil)
```
- **정렬로 두 헤더의 성격 차이를 표현한다**: 커버 헤더 = 중앙, 시트 헤더 = 좌측.
- **타이포는 둘 다 `.heading`으로 통일** — `.subhead`를 쓰는 예외를 두지 않는다.
- `CoverHeader`는 풀스크린 커버의, `SheetHeader`는 하단 시트의 **유일한 헤더 공급원**이다. 인라인 예외는 0이다.
- **동적 타이틀 보호는 컴포넌트가 흡수한다** — `SheetHeader` 타이틀은 한 줄·말줄임(`lineLimit(1)` + `.tail`)이라 재료명처럼 길이가 변하는 타이틀에도 헤더가 깨지지 않고 X가 자리를 지킨다. 호출부가 이 보호를 이유로 커스텀 HStack을 남기면 패딩(위 `s5`/아래 `s3`)이 갈려 시트 간 타이틀 기준선이 어긋난다.

### 14.3 모달 종류별 닫기 방법
| 모달 종류 | 헤더 | 닫는 방법 |
|---|---|---|
| 하단 시트 | `SheetHeader` | **dragIndicator(핸들) + 스와이프 다운**이 주 신호. X 버튼은 선택 |
| 풀스크린 커버 | `CoverHeader` | `PaperCloseButton`(X) |

- 시트는 **dragIndicator 필수** — 핸들 없는 시트를 두지 않는다.
- 편집·생성 시트는 위 닫기 동작에 §14.6 미저장 보호가 추가로 걸린다.

### 14.4 저장 모델 (Save Model)
시트의 저장(커밋) 방식은 성격에 따라 둘로 나눈다 — 한 시트에 두 방식을 섞지 않는다.
- **편집·생성 시트**(재료·레시피·커스텀 아이템·후보 등): 하단 도킹된 `PaperButton`(Save/Add)으로 **명시적 커밋**. 취소는 스와이프/닫기(§14.6).
- **설정·선택 시트**(취향·알림 시간 등 단일 선택): **자동저장** — 선택 즉시 반영, 별도 저장 버튼 없이 닫기만 하면 된다.

### 14.5 시트 높이(detent) 정책
하단 시트의 detent는 콘텐츠 분량에 맞춰 3단으로 정한다 — 미설정(무조건 풀높이) 상태로 두지 않는다.

| 콘텐츠 | detent |
|---|---|
| 짧은 단일 입력(닉네임·시간 등) | 고정 높이 `.height(...)` |
| 중간 목록·폼(추가·편집) | `.medium` 진입, 키보드·긴 내용 시 `.large`로 승격 |
| 긴 목록(레시피 목록 등) | `.large` |

### 14.6 미저장 보호 (Unsaved Changes Guard)
**편집·생성 시트**(§14.4)에서 변경 사항이 있는 상태로 닫힘 제스처(스와이프/닫기)가 들어오면, "변경을 취소할까요?" 확인(`confirmationDialog`, Discard Changes 패턴)을 띄운다. 변경이 없으면 자유롭게 닫힌다.
- 구현: `isDirty` 상태 추적 + `interactiveDismissDisabled(isDirty)` + Discard 다이얼로그.
- **설정·선택 시트(자동저장, §14.4)는 해당 없음** — 저장할 미확정 상태 자체가 없다.
