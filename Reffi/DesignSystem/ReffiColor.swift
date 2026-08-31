import SwiftUI
import UIKit
import Foundation

/// Reffi 색 토큰.
///
/// 정본은 OKLCH(`design_system.md` §12). hex는 "참고용 근삿값"이라 코드에 넣지 않고,
/// OKLCH 값을 런타임에 sRGB로 변환한다(Björn Ottosson). 색은 장식이 아니라 신선도 정보다(§1).
///
/// **시맨틱 토큰은 전부 적응형**이다 — `dynamic(light:dark:)`이 라이트/다크 두 OKLCH를 묶어
/// 동적 UIColor로 만든다. 다크 컨셉은 "밤의 주방 패스": 순검정이 아니라 웜 차콜(hue 78~90)이라
/// 종이 표면이 어둠 속에서 온기를 유지한다. **일러스트 팔레트는 고정**이라 `oklch()`를 그대로 쓴다
/// (음식 색이 스킴에 따라 바뀌면 재료 식별이 깨진다).
enum ReffiColor {

    // MARK: - Brand · Freshness (파스텔) + Blue (§2.2)
    // 각 토큰 주석의 (L / D)는 라이트 / 다크 OKLCH — 문서 동기화의 근거.

    /// 신선 · 여유 (D-4+) — L .86/.120/136 · D .42/.075/138
    static let fresh       = dynamic(light: (0.86, 0.120, 136), dark: (0.42, 0.075, 138))
    /// freshDark — L .50/.115/142 · D .74/.105/140
    static let freshDark   = dynamic(light: (0.50, 0.115, 142), dark: (0.74, 0.105, 140))
    /// freshLight — L .95/.040/132 · D .30/.035/136
    static let freshLight  = dynamic(light: (0.95, 0.040, 132), dark: (0.30, 0.035, 136))

    /// 곧 · 임박 (D-3~1) — L .85/.125/84 · D .44/.080/82
    static let soon        = dynamic(light: (0.85, 0.125, 84),  dark: (0.44, 0.080, 82))
    /// soonDark — L .53/.120/71 · D .78/.110/76
    /// (라이트 L을 .54에서 .53으로 내렸다: soonLight 면 위 4.48 → 4.67로 4.5 기준 통과)
    static let soonDark    = dynamic(light: (0.53, 0.120, 71),  dark: (0.78, 0.110, 76))
    /// soonLight — L .95/.045/84 · D .31/.038/82
    static let soonLight   = dynamic(light: (0.95, 0.045, 84),  dark: (0.31, 0.038, 82))

    /// 오늘 · 지남 (D-0-) — L .75/.135/36 · D .45/.095/34
    static let urgent      = dynamic(light: (0.75, 0.135, 36),  dark: (0.45, 0.095, 34))
    /// urgentDark — L .52/.150/32 · D .74/.130/34
    static let urgentDark  = dynamic(light: (0.52, 0.150, 32),  dark: (0.74, 0.130, 34))
    /// urgentLight — L .93/.050/33 · D .30/.042/33
    static let urgentLight = dynamic(light: (0.93, 0.050, 33),  dark: (0.30, 0.042, 33))

    /// 브랜드 · 레시피/AI · 기본 액션 — L .514/.134/249.8 · D .56/.115/250
    /// 다크 L 상한은 .565다(PaperButton primary가 흰 글자 → white on blue 4.5:1). .58은 4.27로 미달.
    /// **면(fill) 전용이다** — 흰 글자를 받는 채운 면의 색이라, 종이·캔버스 위에 얹는 잉크(글자·아이콘)는
    /// 언제나 `blueDark`를 쓴다. 다크에서 blue는 면으로 밝아지는 쪽이라 잉크로 쓰면 대비가 무너진다.
    static let blue        = dynamic(light: (0.514, 0.134, 249.8), dark: (0.56, 0.115, 250))
    /// blueDark — L .40/.12/250 · D .76/.095/250
    static let blueDark    = dynamic(light: (0.40, 0.12, 250),  dark: (0.76, 0.095, 250))
    /// blueLight — L .93/.045/250 · D .30/.045/250
    static let blueLight   = dynamic(light: (0.93, 0.045, 250), dark: (0.30, 0.045, 250))

    /// **채도 면(blue) 위 콘텐츠 색** — 양 모드 고정 흰색.
    /// 고정인 것이 이 토큰의 내용이다: `blue`의 다크 L 상한 .565가 바로 "흰 글자로 4.5:1"에서 나온 값이라
    /// (위 `blue` 주석 · §2.7), 면이 적응해도 그 위 콘텐츠는 적응할 필요가 없다(실측 라이트 5.65 · 다크 4.64).
    /// `.white` 리터럴을 호출부에 흩뿌리면 그 근거가 코드에서 사라져, 다음 사람이 `onInk`(다크에서 어두워지는
    /// 잉크 면 전용)와 헷갈리거나 파스텔 면에까지 흰 글자를 얹는다. **`ink` 면 위는 `onInk`, blue 면 위는 여기다.**
    /// 예외는 `toast` 위 고정 흰색 하나뿐 — 그건 양 모드 어두운 잉크 캡슐이라 별도 규칙이다(§2.8).
    static let onAccent    = oklch(1, 0, 0)

    // MARK: - Neutral · Reffi 크림 램프 (§2.3)
    // 다크에서 램프가 뒤집힌다 — ink는 크림 글자, canvas/paper는 웜 차콜 면.

    /// neutral-900 · 본문/제목 — L .25/.012/80 · D .93/.010/85
    static let ink    = dynamic(light: (0.25, 0.012, 80),  dark: (0.93, 0.010, 85))
    /// neutral-700 · 보조/캡션 — L .43/.014/80 · D .81/.012/82
    ///
    /// (다크 .76→.81) `muted`를 4.5로 끌어올려 .71에 세운 순간, 다크 잉크 램프가
    /// .93 → .76 → .71 이 됐다 — 간격 .17 / .05다. 앞은 넓고 뒤는 붙어 3단이 2.5단으로 읽힌다.
    /// 가운데 단을 .81로 올려 .12 / .10 으로 다시 벌렸다(paper 면 위 9.94 / 6.77 / 4.75,
    /// 단계비 1.47 / 1.43 — 두 계단이 거의 같은 높이다). ink 쪽 계단을 아주 조금 크게 남긴 것도
    /// 의도다: 본문↔캡션이 캡션↔placeholder보다 큰 층위 차이라는 건 라이트 램프(.18/.08)의 형태이기도 하다.
    ///
    /// **아래(muted)가 아니라 가운데를 움직인 이유.** muted의 바닥은 종이 면 밝기가 잡고 있다 —
    /// 다크 면을 §2.8 면 분리 구간(1.35~1.5, field는 ≥1.19) 안에서 통째로 내려도 가장 밝은 정보 면
    /// (receipt)이 따라 내려가는 폭이 작아 muted는 .701까지밖에 못 간다(canvas를 .185까지 내린
    /// 극단에서도 .679). 면 여섯 개를 흔들어 한 단당 .008을 얻는 거래라, 위계는 잉크 쪽에서 푼다.
    static let ink2   = dynamic(light: (0.43, 0.014, 80),  dark: (0.81, 0.012, 82))
    /// neutral-500 · 약한/placeholder — L .51/.013/80 · D .71/.012/80
    /// (라이트 .56→.51 · 다크 .60→.71: 옛 값은 종이 면 위에서 라이트 4.53 / 다크 3.04였다.
    ///  약해 보이라는 뜻이지 작으라는 뜻이 아니라 이 램프도 본문 크기로 쓰인다 — 요건은 4.5다.
    ///  새 값은 paper/receipt/canvas/paperPass/sub 다섯 면 위에서 라이트 5.59~4.75 · 다크 6.81~4.66.
    ///  통과 구간의 ink2 반대편 끝(라이트 L≤.52 · 다크 L≥.702)에서 한 눈금만 들여 잡았다 —
    ///  여유는 그 한 눈금이면 되고, 더 밀면 ink→ink2→muted 3단 위계가 두 단으로 붙는다.
    ///  다크는 이 값만으로도 붙어서, 위계는 muted를 더 내리는 대신 가운데 단을 올려 되찾았다
    ///  — `ink2` 다크 .76→.81, 이유는 그쪽 주석)
    static let muted  = dynamic(light: (0.51, 0.013, 80),  dark: (0.71, 0.012, 80))
    /// neutral-200 · 서브 면 — L .935/.008/85 · D .32/.008/80
    /// (다크 L .30→.32: 캔버스 위 면 대비 1.29→1.38. secondary 버튼 면이라 이 값이 그대로 CTA 대비다)
    /// **캔버스 위 전용이다**(§2.8·42차) — 종이 카드(paper .33 · receipt .335) 위에 얹으면 다크에서
    /// 1.04~1.06으로 붙어 면이 사라진다. 카드 안에 앉는 컨트롤 면은 아래 `subRaised`를 쓴다.
    static let sub    = dynamic(light: (0.935, 0.008, 85), dark: (0.32, 0.008, 80))
    /// **카드 위 서브 면**(42차 신설) — 종이 카드(paper/receipt) **안**에 앉는 미선택 칩·OFF 트랙·
    /// 카드 위 secondary 면. `sub`(캔버스 위 1.38)와 역할이 갈리는 이유: 다크에서 canvas 밴드
    /// [1.35~1.5]는 L .320~.342를, paper 위 ≥1.19는 L ≥.377을 강제해 **한 값이 두 부모를 동시에
    /// 만족할 수 없다**(§2.8 면 분리 실측 — field가 ≥1.19 하한만 받는 것과 같은 축).
    /// 다크 .41 실측: paper 위 1.38 · receipt 위 1.36 · ink 7.50 · ink2 5.10. 라이트는 sub와 동일
    /// (§2.8이 라이트를 이 요건의 대상에서 제외한다 — 라이트 경계는 헤어라인·그림자가 만든다).
    static let subRaised = dynamic(light: (0.935, 0.008, 85), dark: (0.41, 0.008, 80))
    /// neutral-50 · 캔버스(크림 → 밤의 웜 차콜) — L .97/.012/90 · D .215/.010/78
    static let canvas = dynamic(light: (0.97, 0.012, 90),  dark: (0.215, 0.010, 78))

    // MARK: - Paper / Glass 표면 (§13)

    /// 밝은 종이 면 — 뱃지·티켓·글리프 타일. L .99/.006/90 · D .33/.008/82
    /// (다크 L .285→.33: 캔버스 위 면 대비 1.22→1.43. 다크에선 그림자가 거의 안 보여
    ///  종이 한 장의 존재를 면 밝기가 혼자 짊어진다 — §2.8 "밤의 주방 패스" 면 분리선)
    static let paper     = dynamic(light: (0.99, 0.006, 90), dark: (0.33, 0.008, 82))
    /// 따뜻한 주방 패스 종이 — 캐러셀·조리 커버의 **바탕**. L .95/.016/90 · D .24/.010/84
    /// (다크 L .255→.24: 이 토큰은 커버의 캔버스라 카드가 아니라 바탕으로 내린다 —
    ///  올라간 paper/receipt 카드가 이 바탕 위에서도 1.35:1을 넘게)
    static let paperPass = dynamic(light: (0.95, 0.016, 90), dark: (0.24, 0.010, 84))
    /// "흰 영수증" 면의 정본 — 영수증 시트·행. L .985/.004/90 · D .335/.007/83
    /// (인라인 `oklch(0.985, 0.004, 90)`으로 흩어져 있던 값을 토큰화 · 다크 L .29→.335,
    ///  캔버스 위 1.24→1.46. 라이트에서 paper보다 살짝 눌린 관계를 다크에선 뒤집어 유지한다)
    static let receipt   = dynamic(light: (0.985, 0.004, 90), dark: (0.335, 0.007, 83))
    /// 입력 필드 면 — "여기에 쓴다"는 자리. L .935/.008/85 · D .28/.010/80
    ///
    /// 같은 역할이 canvas / paper / receipt+그레인 / 면 없음 네 갈래로 흩어져 있었다. 필드는 캔버스 위에도
    /// 종이 카드 위에도 서므로, **두 부모 사이에 앉는 값**이어야 한 토큰으로 통일된다(라이트는 헤어라인이
    /// 경계를 만드니 다크가 기준이다 — 캔버스 위 1.20 · paper 아래 1.19 · receipt 아래 1.22).
    ///
    /// 라이트에선 종이보다 **눌린** 자리(canvas 1.11 · paper 1.18 아래)인데 다크에선 캔버스보다 **올라온**
    /// 면이 된다. 뒤집힘이 아니라 어두운 쪽 대비 압축 때문이다: 다크 canvas(L .215) 아래로는 L .13까지
    /// 내려도 1.15밖에 안 벌어져 "눌림"을 밝기로 말할 수 없다 — 그래서 §2.8의 "다크에선 면 밝기가
    /// 그림자의 일을 대신한다"를 따라 한 단 올린다. 라이트 값이 `sub`와 같은 것은 우연이 아니라
    /// "크림 한 단 눌린 면"이 같은 자리여서고, 다크에서 갈린다(sub .32 = 올라온 CTA 면 / field .28).
    /// 면이 아니라 **형태**가 버튼과 필드를 가른다 — 행동 표면은 종이컷 8각형, 필드는 `PaperRect`(§13.1).
    static let field     = dynamic(light: (0.935, 0.008, 85), dark: (0.28, 0.010, 80))

    /// 밝은 종이 면의 단면 헤어라인 — ink α 0.06. 면을 나누는 보더가 아니라 "종이 두께"다(§13.1).
    /// `ink`가 다크에서 크림으로 뒤집혀 헤어라인도 밝아지는 건 의도된 반전이다(§2.8).
    static let paperEdge       = ink.opacity(0.06)
    /// 입력 필드 단면 — 같은 헤어라인이지만 ink α 0.10. 필드는 "여기에 쓴다"를 형태로 말해야 해
    /// 종이 카드보다 한 단 진하다(카드는 그림자가 경계를 만들지만 필드는 면 안에 눌러 앉아 있다).
    static let paperEdgeField  = ink.opacity(0.10)
    /// 채도 면(버튼) 위 흰 종이 헤어라인 — L white 0.14 · D white 0.10
    static let paperEdgeOnFill = dynamic(light: (1, 0, 0), lightAlpha: 0.14,
                                         dark:  (1, 0, 0), darkAlpha:  0.10)
    /// **채워지지 않은 상태 컨트롤의 경계**(42차 신설) — 미체크 체크박스처럼 라벨 없이 경계 하나가
    /// 상태 전부를 말하는 자리. ink α .18은 카드 면 위 1.4:1대라 WCAG 1.4.11(비텍스트 3:1)에 걸렸다 —
    /// α .50 실측: paper 위 3.16/3.75 · canvas 위 3.12/4.47 · paperPass 위 3.07/4.36 · receipt 위
    /// 3.15/3.71(라이트/다크). **라이트 여유가 3.07~3.16으로 얇다** — paper·canvas 계열 L을 다시
    /// 튜닝하면 이 하한부터 재실측한다. 값이 같아 보여도 `paperEdgeAccent`(장식 단면)와 축이 다르다.
    static let paperEdgeState  = ink.opacity(0.50)
    /// **컨트롤 재단선** — 조각의 실루엣을 혼자 지는 단면. 위 세 단면이 "종이 두께"라는 **재질**이라면
    /// 이건 **정보**다: 상태를 형태로 말하는 컨트롤(`PaperToggleStyle`)에서 면색 대비가 원천적으로
    /// 설 수 없을 때 §2.6 비텍스트 기준(3:1, WCAG 1.4.11)을 이 선이 진다.
    ///
    /// **`ink2`인 것이 이 토큰의 내용이다.** 종이 램프(`paper`/`receipt`/`sub`)는 라이트·다크 모두
    /// 서로 1.2:1 안쪽에 몰려 있어(실측 `paper`↔`sub` 라이트 1.18 · 다크 1.04) 종이끼리는 밝기로
    /// 3:1을 만들 수 없다 — 잉크 램프로 건너와야 한다. 그중 `ink2`는 다섯 종이 면 위에서
    /// 라이트 7.77~7.89 · 다크 6.64~6.77로 기준선의 두 배를 갖고도 `ink`(15.33/9.75)처럼
    /// 새까만 테두리로 읽히지 않는 자리다. `muted`(5.51/4.66)도 수치는 통과하지만 그 토큰의 역할이
    /// **약함/placeholder**라 조작 가능한 컨트롤에 쓰면 비활성으로 읽힌다.
    ///
    /// **§6.1의 보더 금지와 충돌하지 않는다** — 그 절은 면을 나누는 선을 금지하고 분리는 틴트·여백으로
    /// 하라는 규율이고, 이 선은 나누는 선이 아니라 **컴포넌트 그 자체의 윤곽**이다(§6.1이 포커스 링을
    /// "보더가 아닌 기능적 예외"로 둔 것과 같은 급). 정보 표면에는 쓰지 않는다.
    static let paperCut        = ink2
    /// 강조 상태 종이의 단면 — 그 카드가 지금 말하고 있는 색(`urgentDark`·`blueDark`)의 α 0.18.
    /// 평상시 종이는 `paperEdge`(ink α .06)지만, "지금 이 카드가 뜨거운 상태다"를 면색이 아니라 **단면**으로
    /// 말하는 자리가 넷 있었고(임박 재료 편집·내 레시피·조리 스텝·발주 티켓) 전부 `.opacity(0.18)`을 손으로
    /// 적고 있었다. 숫자가 콜사이트에 있으면 다음 튜닝에서 한 곳만 움직인다 — 값이 아니라 역할을 부른다.
    static func paperEdgeAccent(_ accent: Color) -> Color { accent.opacity(0.18) }

    // **배경 틴트 토큰은 없다** — 화면 배경은 `canvas` 단색 한 장이다(`PaperCanvasBackground`).
    // 여기엔 블롭 α 3단(`bgBlob*`)과 상하 흰 시노(`bgSheen`·`bgSheenBottom`)가 있었다. 색면을
    // 떠받치던 값이라 색면이 사라진 순간 쥘 사실이 없어졌다. 되살리기 전에 근거부터 다시 세워라:
    // 루트·시트·도킹 CTA·냉장고 하단 마스크가 전부 `canvas`를 칠하므로, 한 화면만 다른 바탕을
    // 깔면 그 경계에 톤이 갈린 띠가 남는다(그것이 이 토큰들을 지운 이유다).
    // 배경이 지는 유일한 신호는 메인의 오늘 만료 웜톤 시노 하나이고, 그건 `urgent`를 그대로 쓴다.

    /// 모달·결정 오버레이 딤 — L ink 틴트 0.22 · D 순검정 0.55
    /// (다크에선 아래 면이 이미 어두워 ink 틴트로는 딤이 안 먹는다 → 검정으로 더 깊게)
    static let scrim           = dynamic(light: (0.25, 0.012, 80), lightAlpha: 0.22,
                                         dark:  (0, 0, 0),         darkAlpha:  0.55)
    /// **슬램 플래시** 딤 — 순검정 α 0.10, 양 모드 동일. `scrim`과 값이 아니라 **역할**이 다르다.
    /// `scrim`은 "뒤가 지금 못 눌린다"를 말하는 모달 딤이라 손이 멈춰 있는 동안 계속 서 있지만, 이건
    /// 온보딩 완료 도장이 내려앉는 0.75초짜리 임팩트 그림자다 — 아래를 가리는 게 목적이 아니라 도장이
    /// 떨어지는 순간만 배경을 눌러 무게를 준다. `scrim`(라이트 .22 · 다크 순검정 .55)을 쓰면 셋업 화면이
    /// 통째로 어두워져 "모달이 떴다"로 읽히고, 다크에선 마지막 화면이 사실상 검게 덮인다.
    /// 적응시키지 않는 것도 의도다: 플래시는 면이 아니라 조명이라 양 모드 같은 세기로 눌러야 한다.
    static let scrimFlash      = dynamic(light: (0, 0, 0), lightAlpha: 0.10,
                                         dark:  (0, 0, 0), darkAlpha:  0.10)

    /// 그림자 전용 틴트 — L·D 모두 어두운 값(라이트=ink, 다크=순검정).
    /// ink는 다크에서 크림으로 뒤집히므로 그림자에 쓰면 밝은 글로우가 된다. 그림자는 항상 이 토큰.
    static let shadowTint = dynamic(light: (0.25, 0.012, 80), dark: (0, 0, 0))
    /// 잉크 토스트 캡슐 면 — 양 모드 모두 어두운 면. L ink(.25/.012/80) · D .38/.010/80
    /// (위 콘텐츠는 양 모드 모두 고정 흰색 — `onInk`가 아니다.
    ///  다크 L .33→.38: 종이 면이 .33으로 올라와 토스트와 값이 겹쳤다 — 라이트에서 토스트가
    ///  종이와 확연히 갈리듯 다크에서도 한 단 위로 떠 있어야 "떠 있는 잉크 캡슐"로 읽힌다)
    static let toast      = dynamic(light: (0.25, 0.012, 80), dark: (0.38, 0.010, 80))
    /// `ink` 면(강대비 면) 위 콘텐츠 색 — L 흰색 · D .22/.010/78
    /// (다크에선 ink가 크림 면이라 그 위 콘텐츠는 도로 어두워야 한다)
    static let onInk      = dynamic(light: (1, 0, 0), dark: (0.22, 0.010, 78))
    /// `toast` 면 위 액션 라벨(Undo 등) — 고정 라이트 블루 .90/.05/250, 양 모드 동일.
    /// toast 면이 양 모드 모두 어두워 적응이 불필요하고, blueLight는 다크에서 어두운 면색으로
    /// 뒤집혀 못 쓴다. "toast 위 텍스트는 고정" 규칙(§2.8)의 액션 변형.
    static let toastAction = oklch(0.90, 0.05, 250)
    /// `toast` 면 위 **본문** — 양 모드 고정 흰색(§2.8, 실측 라이트 16.01 · 다크 10.02).
    /// `onInk`를 얹으면 다크에서 1.73:1로 깨진다 — toast는 양 모드 어두운 면이라 적응할 이유가 없다.
    /// `.white` 리터럴을 콜사이트에 두면 이 근거가 코드에서 사라져 다음 사람이 `onInk`와 헷갈린다.
    static let onToast     = oklch(1, 0, 0)

    // MARK: - OKLCH → sRGB

    /// 라이트/다크 OKLCH 쌍 → 트레이트에 따라 해석되는 **적응형** `Color`.
    /// 튜플은 `(L, C, H)` — L·알파 0~1, H 도(degree). 양쪽 UIColor를 미리 만들어 두고
    /// 프로바이더에선 고르기만 한다(해석마다 색 변환이 돌지 않게).
    static func dynamic(light: (Double, Double, Double), lightAlpha: Double = 1,
                        dark: (Double, Double, Double),  darkAlpha: Double = 1) -> Color {
        let l = uiColor(light, lightAlpha)
        let d = uiColor(dark, darkAlpha)
        return Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? d : l })
    }

    /// `oklch(L C H / a)` → SwiftUI sRGB `Color`. L·a 0~1, H 도(degree).
    /// **고정색 전용**(일러스트 팔레트·스킴 불변 면). 시맨틱 토큰은 `dynamic`을 쓴다.
    static func oklch(_ L: Double, _ C: Double, _ H: Double, _ alpha: Double = 1) -> Color {
        let c = srgbComponents(L, C, H)
        return Color(.sRGB, red: c.r, green: c.g, blue: c.b, opacity: alpha)
    }

    private static func uiColor(_ p: (Double, Double, Double), _ alpha: Double) -> UIColor {
        let c = srgbComponents(p.0, p.1, p.2)
        return UIColor(red: CGFloat(c.r), green: CGFloat(c.g), blue: CGFloat(c.b), alpha: CGFloat(alpha))
    }

    /// OKLCH → 감마 인코딩된 sRGB 성분(0~1). `oklch()`·`dynamic()`이 공유하는 변환 코어.
    private static func srgbComponents(_ L: Double, _ C: Double, _ H: Double) -> (r: Double, g: Double, b: Double) {
        let hr = H * .pi / 180
        let a = C * cos(hr)
        let b = C * sin(hr)

        // OKLab → LMS' (cube)
        let l_ = L + 0.3963377774 * a + 0.2158037573 * b
        let m_ = L - 0.1055613458 * a - 0.0638541728 * b
        let s_ = L - 0.0894841775 * a - 1.2914855480 * b
        let l = l_ * l_ * l_
        let m = m_ * m_ * m_
        let s = s_ * s_ * s_

        // LMS → linear sRGB
        let r =  4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s
        let g = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s
        let bl = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s

        return (gammaEncode(r), gammaEncode(g), gammaEncode(bl))
    }

    private static func gammaEncode(_ x: Double) -> Double {
        let v = min(max(x, 0), 1)
        return v >= 0.0031308 ? 1.055 * pow(v, 1 / 2.4) - 0.055 : 12.92 * v
    }
}
