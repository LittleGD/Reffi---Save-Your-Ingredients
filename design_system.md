# Reffi 디자인 시스템

> Reffi는 냉장고 속 재료가 버려지기 전에 "오늘 먹을 수 있게" 행동을 유도하는 앱이다.
> 그래서 이 시스템의 목표는 **식욕을 돋우고(appetizing), 명료하며(clear), 지금 행동하게 만드는(action-first)** 화면을 일관되게 찍어내는 것이다.
>
> 비주얼 언어는 무드보드 + 팀 "Reffie" 시스템에서 가져온다 — 따뜻한 크림 종이(Dusty Folk) 위의 **파스텔 색 블로킹**, 둥글고 친근한 형태, 지갑처럼 쌓이는 **카드 스택**. 장식적 테두리·그림자·이모지 대신 **색과 여백과 타이포의 위계**로 말한다.

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

### 2.2 브랜드 컬러 (4) — 각 main / dark / light
팀 색의 칙칙함(중간 명도 + 탁한 채도)을 **명도를 올리고 채도를 높여** 화사한 파스텔로 바꿨다. (원본 → 보정: Sage `oklch(78.8% 0.110 116)` → `oklch(86% 0.12 136)` / Amber `oklch(78.8% 0.119 82)` → `oklch(85% 0.125 84)` / Terracotta `oklch(61.2% 0.154 36)` → `oklch(75% 0.135 36)`. 명도는 유지하되 채도를 올려 더 선명하게 — 네온은 금지라 sRGB 게이머트 안쪽으로.)

| 토큰 | 역할 | main (파스텔) | dark (딥 앵커) | light (틴트) |
|---|---|---|---|---|
| **Fresh** (Sage) | 신선 · 여유 (D-4+) | `oklch(86% 0.12 136)` `#ADE393` | `oklch(50% 0.115 142)` `#387332` | `oklch(95% 0.040 132)` `#E5F5D9` |
| **Soon** (Amber) | 곧 · 임박 (D-3~1) | `oklch(85% 0.125 84)` `#F4C767` | `oklch(54% 0.120 71)` `#996000` | `oklch(95% 0.045 84)` `#FDEDCD` |
| **Urgent** (Terracotta) | 오늘 · 지남 (D-0-) | `oklch(75% 0.135 36)` `#F68D70` | `oklch(52% 0.150 32)` `#AE3F2C` | `oklch(93% 0.050 33)` `#FFDDD3` |
| **Blue** (Reffi) | 브랜드 · 레시피/AI · 기본 액션 | `oklch(51.4% 0.134 249.8)` `#176AB0` | `oklch(40% 0.12 250)` `#004985` | `oklch(93% 0.045 250)` `#D2EBFF` |

- **main** = 기본. 신선도 3색은 **파스텔 면**(카드·칩)으로 쓰고 그 위 글자는 **ink**(§2.6). Blue main은 딥 톤이라 그 위 글자는 **흰색**.
- **dark** = 딥 앵커. 캔버스 위 색-as-텍스트, 흰 글자 얹는 솔리드 버튼, 긴급 강조, hover/pressed.
- **light** = 가장 옅은 틴트. 배너·보조 면, 위에는 ink 텍스트.

### 2.3 뉴트럴 (5단계) — Reffi 고유 (변경 없음)
크림빛 무드보드에 맞춘 H≈80–90의 따뜻한 회색 램프. 팀의 다층 뉴트럴 대신 **이 5단계를 그대로** 쓴다. (순백/순흑을 피하는 Dusty Folk 톤과도 합치.)

| 토큰 | 용도 | 값 | hex |
|---|---|---|---|
| `neutral-900` | Ink · 본문/제목 텍스트 | `oklch(25% 0.012 80)` | `#25211B` |
| `neutral-700` | 보조 텍스트 · 캡션 | `oklch(43% 0.014 80)` | `#544F47` |
| `neutral-500` | 약한 텍스트 · placeholder | `oklch(56% 0.013 80)` | `#78746C` |
| `neutral-200` | 서브 면 · 스켈레톤 · 약한 구분 | `oklch(93.5% 0.008 85)` | `#ECE9E4` |
| `neutral-50`  | **Canvas** · 페이지 배경(크림) | `oklch(97% 0.012 90)` | `#F8F5EC` |

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

### 2.6 대비(접근성) 규칙 — *팀 시스템의 약점을 메운 핵심*
팀 시스템에서 아쉬웠던 **글자·배경 대비**를 측정 기반으로 다시 짠다. 모든 값은 실측 WCAG 대비.

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

### 2.7 컬러 토큰
> 전체 토큰은 §12 통합 `:root`에 모았다.

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
- **줄바꿈은 어절 경계에서만, 고아 단어 금지.**
  ```css
  word-break: keep-all;     /* 한글: 어절(공백) 경계에서만 줄바꿈 */
  overflow-wrap: anywhere;  /* 컨테이너를 넘는 초장문 토큰만 예외 분절 */
  text-wrap: pretty;        /* 마지막 줄 단어 1개(orphan) 방지 */
  ```
  짧은 제목은 `text-wrap: balance`. 그래도 고아가 생기면 끊지 말 두 단어 사이에 `&nbsp;`.
- **이모지 금지**(별도 지정 시 제외).

### 3.4 숫자 (Numerals)
유통기한·D-day·수량·날짜가 화면을 채우므로 **데이터성 숫자는 고정폭(tabular)·라이닝**으로. (팀 시스템도 동일 규칙.)
```css
.num { font-variant-numeric: tabular-nums lining-nums; font-feature-settings: "tnum" 1, "lnum" 1; }
```
- 의무: 카드의 "D-2", 수량·날짜, 카운트다운, 표/대시보드 수치. 문장 속 숫자는 비례숫자(기본).

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
| `radius-md` | 12 | 버튼·인풋(기본)·미니 카드 |
| `radius-lg` | 16 | 카드 |
| `radius-xl` | 24 | 큰 카드 · **스택 카드** · 시트 · 모달 |
| `radius-pill` | 999 | 필 버튼·칩·내비·아바타·토글 |

규칙:
- **요소 곡률 ≈ 그 요소의 내부 패딩 토큰.** 패딩 `space-5(24)` 카드 → `radius-lg~xl`. 칩 → `radius-xs~sm`.
- **중첩 시 안쪽 곡률 = 바깥 곡률 − 사이 여백.**
- **둥근 카드 + 필(999) 버튼 + 작은 배지의 곡률 대비**가 "지갑" 무드를 만든다 — 모든 모서리를 한 값으로 통일하지 않는다.

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
- **이중 그림자**: 낮은 블러 **10%** + 높은 블러 **5%**. 투명도 **10% 이하**, 색은 ink 틴트.
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
| 면 색 | 신선도 main(파스텔) | 인접 카드는 L을 ±3% 미세 단차로 깊이감 |

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
  --color-soon-dark:   oklch(54%   0.120 71);    /* #996000 */
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
  --z-base: 0; --z-sticky: 100; --z-dropdown: 1000; --z-modal: 2000; --z-toast: 3000;

  /* ---- Motion ---- */
  --dur-1: 120ms; --dur-2: 180ms; --dur-3: 240ms;
  --ease-out: cubic-bezier(0.23, 1, 0.32, 1);
  --ease-in:  cubic-bezier(0.32, 0, 0.67, 0);
  --ease-std: cubic-bezier(0.40, 0, 0.20, 1);

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

  /* ---- Grid ---- */
  --bp: 1200px;
  --grid-margin-mobile: 16px; --grid-gutter-mobile: 8px;  /* 4 cols */
  --grid-gutter-desktop: 24px;                            /* 14 cols, 1·14 = margin */
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
