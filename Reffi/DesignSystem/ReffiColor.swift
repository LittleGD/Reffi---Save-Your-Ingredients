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

    // MARK: - Neutral · Reffi 크림 램프 (§2.3)
    // 다크에서 램프가 뒤집힌다 — ink는 크림 글자, canvas/paper는 웜 차콜 면.

    /// neutral-900 · 본문/제목 — L .25/.012/80 · D .93/.010/85
    static let ink    = dynamic(light: (0.25, 0.012, 80),  dark: (0.93, 0.010, 85))
    /// neutral-700 · 보조/캡션 — L .43/.014/80 · D .76/.012/82
    static let ink2   = dynamic(light: (0.43, 0.014, 80),  dark: (0.76, 0.012, 82))
    /// neutral-500 · 약한/placeholder — L .51/.013/80 · D .71/.012/80
    /// (라이트 .56→.51 · 다크 .60→.71: 옛 값은 종이 면 위에서 라이트 4.53 / 다크 3.04였다.
    ///  약해 보이라는 뜻이지 작으라는 뜻이 아니라 이 램프도 본문 크기로 쓰인다 — 요건은 4.5다.
    ///  새 값은 paper/receipt/canvas/paperPass/sub 다섯 면 위에서 라이트 5.59~4.75 · 다크 6.81~4.66.
    ///  통과 구간의 ink2 반대편 끝(라이트 L≤.52 · 다크 L≥.702)에서 한 눈금만 들여 잡았다 —
    ///  여유는 그 한 눈금이면 되고, 더 밀면 ink(.25/.93)→ink2(.43/.76)→muted 3단 위계가 두 단으로 붙는다)
    static let muted  = dynamic(light: (0.51, 0.013, 80),  dark: (0.71, 0.012, 80))
    /// neutral-200 · 서브 면 — L .935/.008/85 · D .32/.008/80
    /// (다크 L .30→.32: 캔버스 위 면 대비 1.29→1.38. secondary 버튼 면이라 이 값이 그대로 CTA 대비다)
    static let sub    = dynamic(light: (0.935, 0.008, 85), dark: (0.32, 0.008, 80))
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

    /// 밝은 종이 면의 단면 헤어라인 — ink α 0.06. 면을 나누는 보더가 아니라 "종이 두께"다(§13.1).
    /// `ink`가 다크에서 크림으로 뒤집혀 헤어라인도 밝아지는 건 의도된 반전이다(§2.8).
    static let paperEdge       = ink.opacity(0.06)
    /// 입력 필드 단면 — 같은 헤어라인이지만 ink α 0.10. 필드는 "여기에 쓴다"를 형태로 말해야 해
    /// 종이 카드보다 한 단 진하다(카드는 그림자가 경계를 만들지만 필드는 면 안에 눌러 앉아 있다).
    static let paperEdgeField  = ink.opacity(0.10)
    /// 채도 면(버튼) 위 흰 종이 헤어라인 — L white 0.14 · D white 0.10
    static let paperEdgeOnFill = dynamic(light: (1, 0, 0), lightAlpha: 0.14,
                                         dark:  (1, 0, 0), darkAlpha:  0.10)
    /// 메인 배경(리퀴드글래스) 상단 흰 시노 — L white 0.22 · D white 0.045
    static let bgSheen         = dynamic(light: (1, 0, 0), lightAlpha: 0.22,
                                         dark:  (1, 0, 0), darkAlpha:  0.045)
    /// 모달·결정 오버레이 딤 — L ink 틴트 0.22 · D 순검정 0.55
    /// (다크에선 아래 면이 이미 어두워 ink 틴트로는 딤이 안 먹는다 → 검정으로 더 깊게)
    static let scrim           = dynamic(light: (0.25, 0.012, 80), lightAlpha: 0.22,
                                         dark:  (0, 0, 0),         darkAlpha:  0.55)

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

    // MARK: - Semantic aliases (§12)

    static let primary = blue
    static let action  = blue
    static let recipe  = blue

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
