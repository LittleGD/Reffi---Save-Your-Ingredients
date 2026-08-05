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

**컬러 스킴.** 시맨틱 컬러 토큰은 전량 **라이트/다크 적응형**(`ReffiColor.dynamic(light:dark:)`)이다 — 앱은 `preferredColorScheme` 고정을 없애고 시스템 스킴을 그대로 따른다. 다크 컨셉·병기 토큰 표·측정 대비는 §2.8. **일러스트(FoodGlyph) 팔레트는 스킴과 무관한 고정색**이다(§13.3) — 음식 색이 스킴에 따라 바뀌면 재료 식별이 깨지므로 `ReffiColor.oklch()` 리터럴을 그대로 쓴다.

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

> **행동 표면 예외(§13.3).** 메인의 떨어지는 재료 일러스트는 **재료의 실제 색**(자연색)을 쓴다 — 신선도 색-코딩이 빠지므로, 신선도는 뱃지 인디케이터 바·이름 라벨의 신선도 점·D-N으로 전한다. 정보 표면(카드 스택 등)은 위 규칙 그대로.

### 2.6 대비(접근성) 규칙 — *팀 시스템의 약점을 메운 핵심*
팀 시스템에서 아쉬웠던 **글자·배경 대비**를 측정 기반으로 다시 짠다. 모든 값은 실측 WCAG 대비. **다크 모드에도 동일 요구치**(본문 ≥4.5 / 큰글자 ≥3 / 비텍스트 ≥3)를 그대로 적용한다 — 스킴이 바뀐다고 기준을 낮추지 않는다. 다크 실측표는 §2.8.

**텍스트 대비 (본문 4.5 / 큰글자 3)**

| 면(배경) | 권장 텍스트 | 대비 | 판정 |
|---|---|---|---|
| `neutral-50` 캔버스 | `neutral-900` / `neutral-700` | 14.7 / 7.5 | AAA / AAA |
| `neutral-50` 캔버스 | `neutral-500` | 4.27 | AA-large만(≥24px·장식) |
| **Fresh** main | **ink** | **10.81** | AAA |
| **Soon** main | **ink** | **10.07** | AAA |
| **Urgent** main | **ink** | **6.83** | AA+ |
| **Blue** main | **white** | **5.64** | AA (ink는 2.84 **금지**) |
| 각 색-light 틴트 | **ink** | 12.6 ~ 14.0 | AAA |
| 각 색-dark 솔리드 | **white** | fresh 5.73 · soon 5.21 · urgent 5.92 · blue 9.16 | AA+ |
| 캔버스 위 색-as-텍스트 | 각 색-**dark** | fresh 5.25 · soon 4.78 · urgent 5.43 · blue 8.41 | AA+ |

**비-텍스트 대비 (면 경계·아이콘·점, 3:1)**

| 캔버스 위 요소 | 대비 | 판정 |
|---|---|---|
| Fresh / Soon / Urgent **main** 면 경계 | 1.36 / 1.46 / 2.15 | ✗ — 파스텔은 크림과 명도차가 작다 |
| Blue main | 5.17 | ✓ |
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
- **일러스트 팔레트는 고정.** `FoodGlyph`(§13.3)의 자연색은 스킴 불변 — 음식 색이 다크에서 바뀌면 재료 식별이 깨진다. 단, 실루엣 디테일 중 `ReffiColor.ink`를 직접 쓰던 곳(눈·패싯 등)은 다크에서 크림으로 뒤집혀 실루엣이 망가지므로 **`oklch(0.25, 0.012, 80)` 고정값**으로 박아 넣는다 — `ink` 토큰이 아니라 리터럴을 쓰는 것 자체가 "일러스트는 스킴 불변" 원칙의 적용이다.
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
- **화면당 텍스트 계층 상한: 정보 표면 4 · 행동 표면 7.** 정보 표면은 §3.2의 5단계 중 최대 4종(위 규칙과 동일 취지), 행동 표면(§3.5)은 §3.2 잔존 1~2종 + §3.5 9종 중 화면에 실제 쓰인 조합을 합쳐 최대 7종 — 한 화면에 인접한 텍스트가 서로 구분 안 될 만큼 촘촘한 계단을 쌓지 않는다.
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
- 의무: 카드의 "D-2", 수량·날짜, 카운트다운, 표/대시보드 수치. 문장 속 숫자는 비례숫자(기본).

### 3.5 보조 스케일 (행동 표면) — §3.2 5단계 밖, 9종

§3.2의 5단계는 **정보 표면**(카드 스택·리스트·설정 등 "읽는" 화면) 전용이다. **행동 표면**(재료·버튼·티켓 등 "지금 행동"하는 §13 표면)은 별도 보조 스케일 9종만 쓴다 — 정보 표면에는 쓰지 않는다(§3.3). iOS 구현은 `ReffiActionRole`(`ReffiTypography.swift`) — `ReffiTextRole`과 동일 패턴(`reffiType(_:)` 오버로드)으로 폰트·자간을 role에 내장한다.

| role | 스펙 (family·size·tracking·relativeTo) | 용도 |
|---|---|---|
| `monoTicketLabel` | Pretendard Bold 13 / 자간 2.5 / `.caption` | 오더 티켓 모노 헤더 — "ORDER"·"ORDER · FIRED" |
| `monoEyebrow` | Pretendard Bold 10 / 자간 1.6 / `.caption2` | 초소형 올캡 라벨 — "TABLE · REFFI KITCHEN"·"MORNING ALERTS"·AI 미니 배지·영수증 푸터 |
| `sectionLabel` | Pretendard SemiBold 11 / 자간 1.4 / `.caption2` | 섹션 라벨 — "ON THE TICKET"·"PREP"·카테고리 |
| `menuName` | Pretendard Bold 26 / 자간 −0.3 / `.title2` | 티켓·레시피 메뉴명 |
| `metaText` | Pretendard Medium 13 / `.caption` | 보조 메타 — 시간·개수·설명·힌트 |
| `pillLabel` | Pretendard SemiBold 13 / `.caption` | 필/버튼 라벨 — Undo·Add·Skip·Turn on·Later·판정 키커 |
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

### 6.4 레이어링 (z-index 스케일)
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
| 판정·확정 | Ate/Tossed/Freeze 판정, 레시피 발주(Fire the Ticket) | `.impact` |
| 성공 완료 | 저장·추가·재입고 | `.success` |
| 파괴 확인 | 삭제·초기화 확정(계정삭제·전체초기화·재료/레시피 삭제 등) | `.warning` |

- 같은 의미면 화면 불문 동일 햅틱. 판정 로직을 화면마다 복붙하며 햅틱 유무가 갈리지 않도록, 판정/저장/파괴 확인 핸들러 레벨에서 매핑을 강제한다.
- 순수 정보성 전환(탭 전환·스크롤 등)에는 햅틱을 쓰지 않는다.
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
- [ ] 데이터성 숫자에 `.num`(tabular)을 적용했는가
- [ ] 텍스트가 `word-break:keep-all` + orphan 방지를 따르는가
- [ ] 아이콘이 SVG이고 **색 채운 아이콘 박스가 없는가**
- [ ] 인터랙티브 요소가 hover·active·focus·disabled를 모두 갖고 hover에 포인터 가드가 있는가
- [ ] 터치 타깃 44×44(권장 48) 이상, 간격 ≥8px인가
- [ ] `prefers-reduced-motion`을 존중하고 `transition:all`을 안 썼는가
- [ ] 보더·이모지·순백배경·순흑텍스트·네온을 쓰지 않았는가
- [ ] 곡률이 요소 패딩에 비례하고, 카드/필/배지 곡률 대비를 살렸는가
- [ ] 1200px 분기로 타이포·그리드·스택이 함께 전환되는가
- [ ] (행동 표면) 종이컷 셰이프(`PaperRect`/`PaperBlob`)에 완벽한 원·사각·캡슐을 쓰지 않았는가(§13.1)
- [ ] 종이 단면 헤어라인을 면-분리 보더로 오용하지 않았는가(동일 톤·재질 표현, §13.1)
- [ ] 리퀴드글래스를 네비·시노·떠있는 컨트롤에만, 버튼 색을 머티리얼로 덮지 않았는가(§13.2)
- [ ] 통통 스프링(§7.5)을 행동 표면에만 쓰고 정보 표면(§8)엔 남용하지 않았는가
- [ ] 재료 뱃지가 캡슐이 아니라 좌측 인디케이터 바 + `PaperRect`인가(§13.5)
- [ ] 추천 캐러셀에 네비가 없고 닫기(X)가 있는가(§13.6)

---

## 11. 가정 & 미확정 (Open Questions)
1. **신선도 매핑 구간**: 팀 표의 D-4~6 공백을 **Fresh = D-4+**, Soon = D-3~1, Urgent = D-0/지남으로 메웠다. 실제 임계값은 제품 기준에 맞춰 조정.
2. **파스텔 강도(특히 Urgent)**: Urgent main을 `oklch(74% …)`로 잡아 "오늘!"의 무게를 약간 남겼다(다른 두 색보다 살짝 진함). 더 파스텔하게 원하면 L을 ~80%까지 올릴 수 있으나 ink 대비(현 6.66)가 낮아진다.
3. **카드 곡률 20 vs 24**: 팀의 20px를 내 곡률 스케일의 `radius-xl(24)`로 흡수했다. 지갑 무드에 20을 꼭 쓰려면 스케일에 20을 정식 토큰으로 추가할지 결정 필요.
4. **Story Script**: 라틴 전용·단일 weight 400 확인 → Display는 영문 브랜드 모먼트용, 한글은 Pretendard Bold. 스크립트라 Display 자간 0·weight 400로 운용(타이포 시스템의 −1%/700에 대한 폰트 기인 예외).
5. **한글 폰트**: 이번 지시로 한글=Pretendard 확정(이전 안의 SUIT 대체). GSF·Pretendard 혼용 줄 메트릭 보정(§3.1)은 실제 텍스트로 점검 권장.
6. **본문 자간 −1%**: 라틴 기준 0 권고가 있으나 한글(Pretendard) 본문에 자연스러운 네 스펙을 유지.
7. **데스크탑 그리드 마진**: §9.3 주석 참조.

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

  /* ---- Dark-only surfaces (§2.8) — 라이트 스킴에선 미사용, 다크 오버라이드에서만 값이 실효 ---- */
  --shadow-tint: oklch(25% 0.012 80);  /* 그림자 전용. 다크에서 0 0 0(순검정)으로 뒤집힘 — ink 대신 항상 이 토큰 */
  --toast:       oklch(25% 0.012 80);  /* 잉크 토스트 캡슐 면(= 라이트 ink). 위 텍스트는 고정 white */
  --on-ink:      white;                /* ink로 채운 면 위 콘텐츠. 다크에서 어두운 값으로 뒤집힘 */

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
  --shadow-tint:        black;
  --toast:              oklch(33% 0.010 80);
  --on-ink:              oklch(22% 0.010 78);
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
- 프리미티브: **`PaperRect(cornerRadius, seed)`** — 변이 살짝 휘고 코너 반지름이 변마다 다른 둥근 사각(뱃지·카드). **`PaperBlob(sides, seed)`** — 직선 변 불규칙 다각/9각형(아이콘 버튼·스탬프). **`PaperCutRect(seed)`** — 네 모서리를 잘라낸 **길쭉한 8각형**(와이드 CTA 버튼; 아이콘 버튼 octagon과 통일).
- **종이 단면(`--paper-edge` / `--paper-edge-onfill`)** — 면과 같은 톤의 ~1px 헤어라인을 면 위에 겹쳐 "종이 두께"를 표현. 캔버스 위 밝은 면은 잉크 톤(`--paper-edge`, 0.07), **채도 면(버튼)은 흰 톤**(`--paper-edge-onfill`, 0.14)을 쓴다. **이는 §6.1의 분리용 보더가 아니다**(면을 나누지 않는 동일 톤 재질 표현). 분리는 여전히 색·여백·그림자로.

### 13.2 리퀴드글래스 (Liquid Glass)
- iOS 26 네이티브 `.glassEffect`(폴백 `.ultraThinMaterial`). **사용처:** 메인 **배경**(컬러 블롭 위 글래스 프로스트), 하단 캡슐 네비(`--glass-tint`), 떠 있는 닫기 버튼.
- **메인 배경 = 리퀴드글래스** — 신선도/블루 틴트 블롭을 깔고 글래스로 흐려 프로스트 면을 만들고, **상단에 옅은 흰 시노**(`--bg-sheen`)를 얹는다. 그 위로 재료가 떨어진다.
- **버튼엔 글래스 시노가 없다** — 색(Blue/sub) 솔리드 + 종이 질감(`PaperGrain`) + 흰 단면 헤어라인(`--paper-edge-onfill`)만. 시노는 배경 전용이다.

### 13.3 일러스트 (Illustration) — 각진 면분할 컷페이퍼 · 자연색 멀티컬러
- 재료는 **각진 면분할(faceted) 컷페이퍼** 일러스트 — 곡선 대신 **5~9각 직선 면**으로 오려 붙인 종이 조각처럼, 몸통을 **2~3톤으로 면분할**(대각선 직선 경계의 밝은/어두운 면)하고, 초록 잎/줄기·최소 디테일(점·씨·결)을 **플랫 색면**(아웃라인 없음, 옅은 종이 그림자)으로 조합한다. **장난기 있는 오프컬러 액센트 1포인트**(예: 양파 뿌리 보라)를 더한다. 당근=각진 오렌지 원뿔+초록 잎, 토마토=8각 빨강+초록 별꼭지, 오이=단면 원+씨앗 별무늬, 아보카도=반쪽+밤색 씨, 고기=빨강 살+크림 지방, 생선=파랑 몸+꼬리+눈 등.
- **글리프 라이브러리(`FoodGlyph`, 52종)**는 채소·과일·고기·생선·유제품·**곡류·저장식품**을 폭넓게 커버한다: 채소(leaf·root·squash·onion·tomato·pepper·mushroom·broccoli·potato·garlic·cucumber·pea·cabbage·chili·pumpkin·eggplant·sweetPotato·ginger·seaweed), 과일(apple·citrus·berry·avocado·banana·grape·watermelon·pineapple·mango), 단백질(egg·tofu·meat·poultry·fish·shrimp·sausage·bacon·crab·squid·clam), 유제품(milk·cheese·bread·yogurt·butter), 곡류(rice·noodles·corn), 저장식품(sauceBottle·can·honey), 기타(dumpling), generic. 재료명→글리프는 `FoodGlyph.match(name)`. 검증은 `-glyphGallery` 런치 인자(전 글리프 그리드). **카테고리 라벨**은 `FoodGlyph.categoryLabel`이 파생 — 기존 Veg·Fruit·Dairy·Meat·Seafood·Protein·Bakery·Other에 **Grain(곡류)·Pantry(저장식품)** 2종을 더한다(`Localizable.xcstrings` en+ko 등록). v2 신규 17종은 전부 기존 카테고리 라벨로 편입(신규 라벨 없음): 채소 4·과일 4는 Veg·Fruit, sausage·bacon→Meat, crab·squid·clam→Seafood, yogurt·butter→Dairy, honey→Pantry, dumpling→Other.
- **FoodGlyph 팔레트(정본 출처 = `PaperSilhouette.swift`의 `enum C`)** — 재료별 자연색을 OKLCH로 고정하고, 몸통마다 base/shade/highlight 3톤으로 면을 나눈다. 대표값: 잎/줄기 `oklch(0.43~0.78, 0.11~0.13, 142~150)`, 당근 `oklch(0.70, 0.16, 56)`, 토마토 `oklch(0.62, 0.18, 32)`, 노랑(레몬/파프리카/옥수수) `oklch(0.85, 0.15, 96)`, 호박 `oklch(0.66, 0.15, 62)`, 고추 `oklch(0.55, 0.19, 32)`, 아보카도 과육 `oklch(0.86, 0.10, 110)`·껍질 `oklch(0.36, 0.07, 148)`, 바나나 `oklch(0.84, 0.15, 92)`, 고기 `oklch(0.54, 0.14, 22)`, 생선 `oklch(0.64, 0.07, 240)`, 치즈 `oklch(0.83, 0.13, 92)`, 소스병 `oklch(0.40, 0.055, 44)`, 캔 금속 `oklch(0.82, 0.008, 250)`, 오프컬러 액센트(양파 뿌리 보라 `oklch(0.46, 0.10, 330)`·래디시 핑크 `oklch(0.72, 0.16, 350)`). **v2 신규 대표값**: 포도 자주 `oklch(0.44, 0.12, 320)`, 수박 과육 `oklch(0.63, 0.17, 18)`·껍질 `oklch(0.52, 0.13, 148)`, 파인애플 `oklch(0.75, 0.13, 78)`, 망고 노랑 `oklch(0.83, 0.15, 82)`·붉은면 `oklch(0.66, 0.16, 44)`, 가지 보라 `oklch(0.36, 0.09, 318)`, 고구마 자주빛 `oklch(0.47, 0.11, 14)`, 생강 베이지 `oklch(0.79, 0.05, 74)`, 소시지 `oklch(0.55, 0.12, 34)`, 베이컨 살 `oklch(0.60, 0.15, 20)`, 게 주홍 `oklch(0.60, 0.16, 34)`, 오징어 크림 `oklch(0.91, 0.03, 18)`, 조개껍질 `oklch(0.83, 0.045, 68)`, 버터 `oklch(0.87, 0.10, 96)`, 꿀 앰버 `oklch(0.72, 0.14, 74)`, 김/미역 진초록 `oklch(0.33, 0.055, 156)`, 만두피 크림 `oklch(0.91, 0.03, 84)`. 색은 **신선도 코딩과 분리**(§2.5 행동표면 예외) — 쇼케이스(`design-system.html`)의 실루엣도 신선도색이 아니라 이 자연색으로 칠한다.
- **신선도는 색이 아니라 뱃지로(§2.5 행동표면 예외).** 일러스트는 재료의 **실제 색**을 쓰므로 신선도 색-코딩이 빠진다 — 대신 신선도는 ① 뱃지 좌측 인디케이터 바, ② D-N 텍스트로 전한다. 씬 위에는 이름 라벨을 얹지 않는다 — 재료 식별은 실루엣 + 아래 뱃지 행이 담당한다. (정보 표면·카드 스택의 §2.5 색=신선도 규칙은 그대로.)

### 13.4 진짜 물리 + 통통 모션
- **재료 낙하는 물리 엔진**(SpriteKit, §7.5): 위에서 떨어져 충돌하며 쌓이고, **끌어서 던질 수 있다**. **묵직하게** — 큰 중력(`gravity = -42`) + 낮은 반발(`restitution≈0.12`)로 쿵 떨어져 거의 안 튄다. 스폰은 항상 닫힌 상자 천장 아래로 클램프(재료가 화면 밖으로 새지 않음). UI 스프링(`pop`·`settle`·`press`)은 뱃지/버튼에만. `prefers-reduced-motion`이면 낙하 생략하고 바닥에 즉시 배치.
- **터치는 한 손가락만 추적** — 드래그 중 추가 손가락은 무시(멀티터치로 상태가 꼬이지 않음). 탭/드래그 판정은 시작점 기준 **누적 이동 8pt** — 아무리 느리게 끌어도 탭으로 오판하지 않는다. 씬은 다른 탭·오버레이에 가려진 동안 **일시정지**(배터리).
- **씬 위 이름 라벨 없음** — 실루엣 더미는 일러스트만으로 깨끗하게 둔다. 이름·신선도·D-N은 아래 뱃지 행(§13.5 `IngredientBadge`)이 전달한다.

### 13.5 컴포넌트
**종이컷 아이콘 버튼(`PaperIconButton`)** — 첨부 레퍼런스(Tossed/Ate) 폼. **손으로 자른 종이 9각형**(`PaperBlob`) **솔리드** 면 + **종이 질감**(`PaperGrain`) + **가운데 채운 아이콘** + **아래 라벨**. 인텐트: `primary`(Blue/흰 아이콘) · `soft`(블러시 `urgent-light`/`urgent-dark` = Tossed) · `fresh/soon/urgent/neutral`(§2.6). 그라데이션 없음. `--shadow-1` + 통통 프레스. Ate/Tossed/Freeze(urgent 한정, `neutral` + 눈꽃) 결정 등. 냉동 재료는 냉장고 카드에서 **FROZEN 도장**(`DDayStamp` 재사용, `blue-dark` 잉크)으로 구분 — 스택은 쪼개지 않는다(영수증 더미 메타포 유지).

**종이 버튼(`PaperButton`)** — 와이드 1차 CTA. **`PaperCutRect`(모서리 잘린 길쭉한 8각형)** **솔리드** 면 — 아이콘 버튼 octagon과 같은 계열. **종이 질감(`PaperGrain`)** + 통통 프레스. **아이콘·그라데이션 없음(텍스트만)**. `primary`=Blue/white, `secondary`=sub/ink. `--shadow-1`(§6.2 예외). `요리시작`에 사용.

**재료 뱃지(`IngredientBadge`)** — **캡슐 아닌 `PaperRect`** 면 + **좌측 인디케이터 바**(둥근 직사각, 신선도 dark색) + 이름(+ D-N). **탭 = Ate/Tossed 판정 묻기**(§13.6 — 고르면 뱃지·실루엣 모두 뿅 사라짐, `--spring-pop`). 히트 영역은 시각과 무관하게 **최소 44pt**(§7.3, `AddBadge` 동일). `AddBadge`(점선 종이 사각 ＋)로 추가.

**오더 메모 카드(`OrderMemoCard`)** — 주방 오더 티켓. 크림 종이(`ReceiptShape` 상·하 톱니 절취, `--paper-surface`) + 모노 "ORDER" 헤더는 **두 상태 공통**이고, 그 아래 본문만 갈린다.

- **축약(기본)** — 카드에 **음식 아이콘 + 메뉴명**만. 아이콘은 레시피 대표 글리프(`Recipe.glyph` = 첫 비상비 재료)를 앱 공통 종이컷 일러스트(`PaperSilhouette`, 146pt)로 그린다(이모지 금지, §5). 이름은 `menuName`(Bold 26), 아이콘·이름·펼침 기표(caret-up + "Pull up for details", §13.6 룰⑩) 묶음이 헤더 아래 남는 공간의 **세로 중앙**에 놓인다. 판정문·체크리스트·PREP·발주 CTA는 **여기 없다** — 덱을 넘길 땐 "뭘 만들지"만 읽으면 되고, 상세는 고른 뒤에 온다.
- **펼침** — 축약 티켓을 **위로 끌어올리거나 탭하면** 같은 카드 안에서 본문이 상세로 갈린다: 점선 룰 + **판정문 키커**(이 티켓이 구하는 임박 재료 수) + 메뉴명/시간 + 재료 체크리스트(신선도, 최대 5줄 미리보기 + N more) + **PREP 조리 메모**(`Recipe.steps`, **최대 3단계 미리보기(+N more)** — 발주 전부터 payoff가 보이게, 전체 단계는 발주 후 단계별 조리 화면(`CookingStepsView`)이 정본) + **"이걸로 요리" 발주 CTA**. **접기**는 헤더를 아래로 끌거나 헤더를 탭한다 — 펼친 헤더엔 축약의 caret-up과 거울상인 **caret-down 접기 기표**가 붙어 두 방향이 모두 화면에 예고된다(룰⑩). **카드 크기는 두 상태가 같다 — 바뀌는 건 콘텐츠뿐이다**: 톱니 밑단이 제자리에 있어 겹쳐 쌓인 덱의 기하가 전환 중에 흔들리지 않고, 크기 애니메이션이 없으니 전환이 값싸다. 펼침/접힘은 순수 정보성 전환이라 **햅틱이 없다**(§7.6).

**발주(Fire the Ticket)는 펼친 상태에서만** — CTA가 축약 본문엔 없다. 발주하면 START 스탬프가 쾅 찍히고 체크리스트에 줄이 그어진다. AI 생성 레시피(`Recipe.isAI`)는 헤더 "ORDER" 줄의 "#NN" 왼쪽에 **sparkle + "AI" 미니 배지**(`blue-light` 종이 칩, `blue-dark` 잉크)로 구분한다 — 헤더 콘텐츠 분기라 카드 컨테이너 자체의 단일 정체성엔 영향 없다. 축약↔펼침도 같은 규율을 따른다: 컨테이너(배경·`compositingGroup`·그림자)는 상태와 무관하게 한 뷰 트리로 두고 **내부 콘텐츠만 분기**한다(뷰 트리를 갈아끼우면 제거+삽입이 일어나 번쩍인다).

**타이포(행동 표면).** §3의 5단계 밖 보조 스케일 9종(§3.5 표 정본)을 **행동 표면에만** 쓴다: **뱃지·아이콘버튼 라벨 = `badgeLabel`**(Pretendard SemiBold 15 / 자간 −0.15 — `PaperIconButton`·`IngredientBadge`·`AddBadge`), **오더 티켓** = 모노 헤더 `monoTicketLabel`(Bold 13 / 자간 2.5) + 서브 `monoEyebrow`(Bold 10 / 자간 1.6) + 메뉴명 `menuName`(Bold 26) + 체크리스트 `checklistItem`(SemiBold 16) + START 스탬프 `stampLabel`(Bold 34). 정보 표면엔 쓰지 않는다(§3.3).

**입력 시트도 행동표면 언어를 따른다 — 그리고 재료 추가는 이제 영수증 스캔 하나뿐이다.** 사용자 결정(2026-08-01): 일러스트 사전 픽커·검색 필드·직접 입력 폼을 주 추가 플로우에서 **전부 제거**했다 — 지금 냉장고가 비었는데 뭔가 사려는 상황을 상정하지 않고, 장 본 뒤 영수증으로 한 번에 등록하는 사용 패턴에 집중한다. `AddIngredientSheet`는 얇은 래퍼로, 실제 내용은 `ReceiptScanView`에 전부 위임한다. 플로우는 3단계: ① **소스 선택** — 크림 캔버스 위 카메라(`VNDocumentCameraViewController`, 자동 크롭·다중 페이지)와 사진 선택(`PhotosPicker`, 최대 3장) 중 고른다. ② **처리** — 온디바이스 Vision OCR(ko+en)로 텍스트를 읽고 `ReceiptParser`가 사전 매칭 후보로 바꾼다(네트워크 전송 없음, "Everything is read on this device" 카피로 명시). ③ **확인 리스트** — 인식된 각 줄이 후보 행(체크·이름·원문·수량·연필)으로 뜨고 **기본 전체 선택**(빼는 쪽이 마찰 적음), 사전 미매칭이거나 shelfLife 데이터가 없으면 **"Est. date: check" 배지**(soonDark 캡슐)로 추정 기한임을 알린다. 연필 아이콘이 여는 **`CandidateEditSheet`**(흰 영수증 카드 `ReceiptShape` + `DashedRule` 행)에서 이름·수량·보관·소비기한·구매처를 직접 고칠 수 있다 — **여기가 사전 밖 이름을 만드는 경로**다(별도 커스텀 시트가 아니라 후보 편집 자체가 그 역할을 겸한다). 하단 `PaperButton`("Add N items")로 선택분을 일괄 등록한다. 상단은 **`SheetHeader`**(좌측 "Scan a receipt" + 종이 X). 쇼핑리스트 **재입고**(`ShoppingListView`)는 여전히 시트조차 열지 않는다 — Add 탭이 직전 이력 스냅샷(보관·구매처·수량, 냉동이었다면 냉장으로) + 사전 기본 기한으로 곧장 재고에 채운다.

**냉장고 요약·정렬(`FridgeView`)도 §13 문법을 공유한다.** 헤더 아래 **요약 페이저**(장보기 · 무낭비 리포트, `TabView` 한 장씩 스와이프)는 `PaperCutRect` 종이컷 버튼 면(`PaperButton`·아이콘 버튼과 같은 계열) + 옅은 그레인 + `--shadow-1` + 점 인디케이터로 짓는다. 스택 위 **정렬 칩**(현재 정렬 라벨을 상시 노출)과 **간편보기 원탭 토글**은 둘 다 `PaperRect` 면 + `paperEdge`, 히트 영역 최소 44pt(§7.3). 정렬 칩을 탭하면 스톡 `Menu`/`Picker` 팝업(흰 시스템 라운드 렉트) 대신 **앱 최초 커스텀 드롭다운 `PaperDropdown`**이 칩 바로 아래에 뜬다 — `PaperRect` 면 + `paperEdge` 헤어라인 + 옅은 `PaperGrain` + `--shadow-1`, 행마다 라벨(좌) + **선택 행에만 체크 글리프**(우, `blue-dark`), 행 사이 `DashedRule`(절취선), 최소 44pt 히트·`paperPress`. 트리거 칩 앵커 아래에 `overlayPreferenceValue`로 띄워 `ScrollView`에 클리핑되지 않고(zIndex `dropdown`), 딤 없는 투명 탭 캐처가 바깥 탭을 받아 닫는다(가벼운 드롭다운 — 모달 아님, `scrim` 없음), 진입 `--spring-pop`·이탈은 더 빠르게(§7.5). **간편보기(`FridgeCompactRow`)**는 틸트·겹침 없는 납작한 흰 영수증 한 조각 — 실루엣 + 이름 + 수량 + D-day(냉동이면 + FROZEN 도장)를 한 줄에 정렬해 훑어보기(스캔)에 최적화한다.

### 13.6 메인 플로우 (물리 낙하 → 더미+뱃지 공존 → 티켓)
1. 사용 가능한 임박 재료를 백그라운드 계산 → 추천.
2. 재료가 **위에서 진짜 물리로 떨어져 충돌·바운스하며 쌓여 그대로 남는다**(SpriteKit). 사라지지 않고, 끌어서 던질 수 있다.
3. 같은 재료의 **뱃지가 요리시작 버튼 위에 함께 남는다**(실루엣 더미 ↔ 뱃지 두 표현 공존). 실루엣·뱃지 **어느 쪽을 탭하면 "먹었나/버렸나(Ate/Tossed)" 결정**(종이 카드 + `PaperIconButton` 쌍 + 명시적 "Keep it" 취소, §13.5)이 뜨고, 고르면 그 재료가 **뿅 사라진다**(SpriteKit 스케일 팝 + SwiftUI scale 트랜지션, `--spring-pop`) + 이력 기록(낭비 추적). **오늘 만료(urgent)이고 아직 얼린 적 없는 재료엔 3번째 선택지 Freeze**가 나타난다 — 버리기 직전의 구제(미리 얼려두기 아님). 얼리면 원본 소비기한은 그대로 두고 `frozenAt + 유예 14일`의 **새 D-day**를 받으며(무기한 아님), 작업대에서 빠졌다가 **유예 D-3에 재등장**한다("해동해서 요리해" 재약속). 재냉동 불가(1회 제한 — 미루기 버튼 방지). 빈 자리는 냉장고의 다음 임박 재료가 떨어져 채운다(`FridgeStore.counter` 작업대, **보충 목표 6** — 직접 추가·되돌리기로 일시 초과 가능, 예약·유예 넉넉한 냉동 재료 제외). ＋로 추가 — **영수증 스캔이 추가 플로우의 전부**다(§13.5, 일러스트 픽커·검색·직접 입력 폼 제거).
3-1. **판정 바스켓(마그네틱)** — 칩을 드래그하면 **좌상 휴지통(Tossed)·우상 냄비(Ate)** 종이 블롭 바스켓이 나타난다(평소엔 숨김). 손가락이 바스켓 반경(≈88pt)에 들면 재료가 **자석처럼 바스켓 중심으로 끌려 들어가고**(추종 민첩도 상승 + 1.14× 확대), 벗어나면 풀린다. 캡처된 채 놓으면 오버레이 없이 바로 확정(되돌리기 토스트가 안전망). 탭 → 판정 오버레이는 접근성 경로로 유지.
3-2. **미션 헤더** — 헤더 카피는 오늘의 상태 한 문장(오늘 N개 위험 / 곧 먹을 N개 / 전부 신선). 누계 카운트는 MyPage로 이양, 신선도 점 행은 뱃지와 중복이라 없앴다.
4. **요리시작** → **티켓 덱**(풀스크린, **네비 없음**, 닫기 X). 클립 없이 **실제 티켓이 겹쳐 쌓인 덱** — 뒤에 보이는 종이가 다음 티켓이다(위로 머리를 내밈, 교대 틸트). **덱은 축약 상태로 열린다** — 앞 티켓에 음식 아이콘 + 메뉴명만 보이는 티켓(§13.5), 훑기(무엇을 만들지)와 읽기(무엇이 들어가는지)를 분리한 것이다. 맨 앞 티켓을 **튕겨(플릭) 넘기면** 뒤로 들어가고 다음이 스프링으로 올라온다(순환; reduce-motion이면 즉시 전환) — 새 앞 티켓은 **다시 축약부터** 시작한다. 앞 티켓을 **위로 끌어올리면(또는 탭하면) 본문이 상세로 펼쳐져** 판정문·체크리스트·PREP·발주 밴드가 나오고, **헤더를 아래로 끌면(또는 탭하면) 축약으로 되돌아온다**. **카드 크기는 축약·펼침이 같다 — 콘텐츠만 축약/전개된다**: 톱니 밑단이 제자리라 겹쳐 쌓인 덱의 기하가 전환 중 흔들리지 않는다(뒤 티켓 밑단이 삐져나오는 문제 자체가 없다). 드래그 중 카드가 따라 움직이는 값이 없으므로 **커밋은 놓는 순간에만** 일어난다 — 임계(예측 변위 56pt)를 못 넘기면 아무 것도 바뀌지 않는다. 드래그 중재는 **덱 한 곳**(`frontDrag`)에서만 하고, 한 제스처의 **우세 축을 처음 한 번만 판별해 고정**한다: 수평(|Δx| > |Δy|·1.4)은 플릭, 수직(|Δy| > |Δx|·1.4)은 축약↔펼침, 축이 갈리지 않는 애매한 구간은 **아무 것도 커밋하지 않는다**(추종 피드백 없이 상태가 뒤집히지 않게). 펼친 뒤 본문 위 세로 드래그는 카드 안 스크롤이 가져간다. **발주는 펼친 상태에서만**(CTA가 축약엔 없다). **발주(Fire the Ticket) = 예약** — 티켓의 사용 재료를 예약해 작업대·추천에서 빼되(START 슬램 = 비우기 연출), **재고 차감·이력 기록(`Cooked · 레시피명`)은 요리 완료(Finish)에서 확정**된다. 소비 후보는 작업대 6개가 아니라 **전체 가용 재고** — 티켓이 쓰는 재료가 냉장고에 있으면 함께 예약돼 유령 재고가 남지 않는다. 커버당 발주는 1회(더블 파이어 방지), 발주 후 덱 잠금. **카드는 화면 높이에 캡되고**(safe area 연동, 재료·단계가 많아도 톱니 엣지가 잘리지 않는다) **중간 섹션은 필요 시 카드 안에서 스크롤**된다(접근성 큰 글씨 안전망 — 헤더·발주 밴드는 고정). **가장 깊은 티켓만 머리(헤더)를 실제 렌더**해 전환 프레임드롭을 줄인다 — 바로 뒤 티켓은 앞 티켓과 같은 축약 본문을 그리므로 플릭 승격이 내용 변화 없이 매끄럽다(상세는 앞 티켓만 그린다). **발주 덱은 시드·커스텀·AI 생성 티켓이 한 덱**이다(AI는 §13.5 sparkle 배지로만 구분, 별도 트레이 없음) — 캐러셀이 열리는 순간 `FridgeStore.refreshAIRecipes`를 트리거해, 생성이 끝나는 대로 아직 덱에 없는 AI 티켓을 **최대 2장 뒤에 이어붙인다**(기존 카드는 그대로, 순서·정체성 불변). 진행 중엔 상단 바 아래에 작은 sparkle + 점 힌트("Cooking up an AI ticket…")가 뜨고, 도착이든 실패든 조용히 사라진다(실패 문구 없음 — 시드 덱이 이미 있다).
4-1. **단계별 조리 화면 + 진행 카드(Cooking now)** — 발주하면 곧장 **단계별 레시피 화면**(발주 티켓이 체크리스트가 된 조리 티켓: 단계 탭 = 체크)이 열린다. **"요리 완료"** 시 재료별 **"다 썼어요(기본)/조금 남았어요" 원탭 확인** — 남은 재료는 수량 절반으로 냉장고에 잔류하고, 나머지가 이력으로 확정된다. **"조리 취소"**는 예약을 해제해 재료를 그대로 되돌린다(기록 없음). 메인 헤더 아래엔 미니 영수증 스트립("COOKING NOW" + 메뉴명 + 경과 시간)이 남고, **탭하면 단계 화면으로 복귀**한다. 체크 진행·시작 시각은 영속화(재실행에도 유지), 발주 undo = 예약 회수.
5. **되돌리기(통합 undo)** — 판정·발주 직후 6초 동안 상단 잉크 캡슐 토스트(**탭 공통**, 하단 CTA·네비 안 가림)로 되돌릴 수 있다 — 재료·이력을 되살리고 **작업대는 판정 전 스냅샷으로 원복**(자동 보충분 회수). 작업대·되돌리기 상태는 store에 살아 **탭을 오가도 유지**된다.

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
- `CoverHeader`는 풀스크린 커버의, `SheetHeader`는 하단 시트의 **유일한 헤더 공급원**이다.

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
