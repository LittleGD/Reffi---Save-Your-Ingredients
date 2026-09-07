import SwiftUI

/// Reffi 타이포 위계(§3.2). iOS는 항상 모바일 스케일(<1200px 시스템)을 쓰고,
/// `relativeTo`로 Dynamic Type에 맞춰 스케일한다. Display·Heading=OK단단체(한·영 공통),
/// 소제목·본문·캡션=Pretendard,
/// 데이터성 숫자=Google Sans Flex(§3.4 `reffiNum`).
enum ReffiTextRole {
    case display   // 워드마크·표지, OK단단체
    case heading   // 제목
    case subhead   // 소제목 · 카드 이름
    case body      // 본문

    /// 캡션 · 라벨 — **읽는 문장**형 메타(부제·설명·안내).
    /// 데이터형 메타(시간·개수·라벨=값의 값)는 §3.5 `metaText`, 행 묶음의 이름표는 §3.5 `groupLabel`.
    ///
    /// **같은 블록 안에서 `body`의 상위 계층으로 쓰지 않는다.** 14/Medium은 16/Regular보다 작으면서
    /// 더 굵어, 크기와 굵기가 서로 반대를 가리킨다 — 두 신호가 상쇄돼 위계가 약해지는 게 아니라
    /// 아예 없는 것으로 읽힌다(§3.2 표 주석의 "weight·색으로 함께"는 같은 방향으로 준다는 뜻이다).
    /// 접근성 크기에서는 크기 차이마저 사라진다: `.caption` 곡선(12→43)이 `.body`(17→53)보다 가팔라
    /// AX5쯤이면 caption 14가 body 16을 따라잡는다(둘 다 ≈50pt — Apple 공표 Dynamic Type 표 기준).
    /// 상위 라벨이 필요하면 `groupLabel`.
    case caption
}

extension ReffiTextRole {
    var font: Font {
        switch self {
        case .display: return .custom("OkDanDan-Bold",       size: 34, relativeTo: .largeTitle)
        case .heading: return .custom("OkDanDan-Bold",       size: 24, relativeTo: .title)
        case .subhead: return .custom("Pretendard-SemiBold", size: 18, relativeTo: .title3)
        case .body:    return .custom("Pretendard-Regular",  size: 16, relativeTo: .body)
        case .caption: return .custom("Pretendard-Medium",   size: 14, relativeTo: .caption)
        }
    }

    /// 자간: Display·Heading −2%, Subhead·Body −1%, Caption +1%.
    var tracking: CGFloat {
        switch self {
        case .display: return 34 * -0.02
        case .heading: return 24 * -0.02
        case .subhead: return 18 * -0.01
        case .body:    return 16 * -0.01
        case .caption: return 14 *  0.01
        }
    }

    /// Display·Heading은 추가 행간 없이 원본 폰트 메트릭을 쓴다.
    var lineSpacing: CGFloat {
        switch self {
        case .display, .heading: return 0
        case .subhead: return 2
        case .body:    return 5
        case .caption: return 3
        }
    }

}

extension String {
    /// 한글 포함 여부. 한글을 지원하지 않는 Google Sans Flex 숫자 폰트의 폴백에 쓴다.
    var hasHangul: Bool {
        unicodeScalars.contains {
            (0xAC00...0xD7A3).contains($0.value)      // 완성형
            || (0x1100...0x11FF).contains($0.value)   // 자모
            || (0x3130...0x318F).contains($0.value)   // 호환 자모
        }
    }
}

/// 축소 계수 팔레트(§3.3·42차) — `minimumScaleFactor`는 role 크기를 임의 실수로 만드는 도피구라,
/// 콜사이트가 값을 지어내지 못하게 **실측으로 검증된 계수만** 이름으로 노출한다. 21개 콜사이트에
/// 5계수(0.6/0.7/0.75/0.8/0.85)가 유통됐는데, 그중 0.75(3등분 탭)·0.6(38×44 칩)은 §13에 잘림
/// 실측이 남아 있는 값이라 뭉개지 않고 승격했다. **새 표면은 이 팔레트에서만 고른다** —
/// §3.2 문서 role(display~caption)에는 §13에 실측 근거를 등록한 예외 외 축소를 걸지 않는다.
enum ReffiShrink {
    static let chrome: CGFloat = 0.8    // 크롬 라벨 기본 — 커버 타이틀·판정 버튼·발주 알약
    static let fit: CGFloat = 0.7       // 폭이 빠듯한 크롬 — 티켓 크라운·메뉴명·아이콘버튼 라벨
    static let tab: CGFloat = 0.75      // 3등분 고정 폭 탭(§13.5 실측 — 잘림 하한)
    static let dense: CGFloat = 0.6     // 물리적으로 못 키우는 칸 — 7칸 요일 그리드·38×44 칩(실측)
    static let subtle: CGFloat = 0.85   // 큰 디스플레이의 마지막 한 뼘 — 워드마크·커버 부제
}

extension View {
    /// Reffi 타이포 위계 적용(폰트+자간+행간). 색은 면에 따라(§2.6) 별도로 준다.
    /// 모든 역할이 한글·영문을 지원하므로 언어별 디스플레이 폰트 분기가 필요 없다.
    func reffiType(_ role: ReffiTextRole) -> some View {
        self.font(role.font)
            .tracking(role.tracking)
            .lineSpacing(role.lineSpacing)
    }

    /// 어절 경계 줄바꿈 + 고아 단어 방지(§3.3).
    func reffiWrap() -> some View {
        self.lineLimit(nil)
    }
}

/// 데이터성 숫자 3단 스케일(§3.4). 사이즈를 자유 파라미터로 두었더니 호출부가 옆 텍스트에 맞춰
/// 매번 즉흥 결정해 11·12·13·14·15·16·17·32 여덟 종이 유통됐다 — 숫자 계열에 위계가 없던 이유다.
/// 세 단만 남긴다: 화면당 하나뿐인 주지표 / 본문과 나란한 값 / 칩·푸터의 보조 수치.
enum ReffiNumScale {
    case hero   // 32 — 리포트 주지표처럼 화면당 하나
    case body   // 15 — 본문·리스트 행과 나란히 서는 값
    case meta   // 12 — 칩·푸터·카운트 등 보조 수치

    var size: CGFloat {
        switch self {
        case .hero: return 32
        case .body: return 15
        case .meta: return 12
        }
    }

    var textStyle: Font.TextStyle {
        switch self {
        case .hero: return .largeTitle
        case .body: return .subheadline
        case .meta: return .caption2
        }
    }
}

extension Font {
    /// 데이터성 숫자 — Google Sans Flex + tabular·lining(§3.4). D-N·수량·날짜에 의무.
    /// **순수 숫자·라틴만 흐르는 자리 전용** — ko 문자열이 섞일 수 있는 값은 아래 `reffiNum(_:for:)`.
    static func reffiNum(_ scale: ReffiNumScale) -> Font {
        .custom("GoogleSansFlex-Regular", size: scale.size, relativeTo: scale.textStyle).monospacedDigit()
    }

    /// **표시될 문자열에 맞춘** 숫자 폰트(§3.4·42차).
    /// GSF는 한글 미지원(§3.1 검증)이고 `.custom()`엔 폰트 스택이 없어, "오늘"·"3일"·"오전 9:00"이
    /// 흐르면 누락 글리프가 Pretendard가 아니라 **시스템 한글 서체**로 조용히 캐스케이드된다 —
    /// 재료 뱃지 하나에 세 서체가 서는 원인. 폴백은 Pretendard **Regular**다: GSF-Regular와
    /// usWeightClass 400 동급이고 잉크 커버리지 실측(0.315 vs 0.311)도 같아, Medium(+15%)을 쓰면
    /// 오히려 혼용 줄의 무게가 어긋난다(§3.1 "혼용 줄 어긋남 방지"). `relativeTo`는 동일 스케일 유지.
    static func reffiNum(_ scale: ReffiNumScale, for text: String) -> Font {
        text.hasHangul
            ? .custom("Pretendard-Regular", size: scale.size, relativeTo: scale.textStyle).monospacedDigit()
            : .custom("GoogleSansFlex-Regular", size: scale.size, relativeTo: scale.textStyle).monospacedDigit()
    }

    /// 도장(Stamp) 계열 — Pretendard Bold, 크기 파라미터화(`reffiNum`과 동일 패턴). `DDayStamp`(§13.5)처럼
    /// 같은 글자 성격을 여러 크기로 재사용하는 컴포넌트 전용 — `ReffiActionRole.stampLabel`(34)도 내부적으로 이걸 쓴다.
    /// 새 역할이 아니라 헬퍼: 고정 10종 밖의 "동일 문법·가변 크기" 컴포넌트를 위한 탈출구.
    static func reffiStamp(_ size: CGFloat, relativeTo style: Font.TextStyle = .subheadline) -> Font {
        .custom("Pretendard-Bold", size: size, relativeTo: style)
    }
}

/// 보조 스케일(§3.5) — §3.2의 5단계가 **문서 위계**라면 이 10종은 **컴포넌트 위계**다:
/// 라벨·크롬·칩·리스트 항목처럼 문장이 아니라 부품에 붙는 글자. **표면을 가리지 않는 공통 스케일**이고,
/// 화면당 총량은 §3.3의 단일 상한(계층 ≤ 7종)이 잡는다.
/// `ReffiTextRole`과 동일 패턴(font/tracking + `reffiType` 오버로드)으로 raw `.custom("Pretendard-*")`
/// 산발 지정을 대체한다.
///
/// **작은 글자 셋의 갈림길 — 크기가 아니라 역할로 고른다.** `caption`(14) · `metaText`(13) ·
/// `groupLabel`(12)은 셋 다 Pretendard Medium 계열이라 크기표만 보면 서로 대체 가능해 보이고,
/// 실제로 콜사이트가 옆 글자에 맞춰 아무거나 고른 결과가 "규칙 없이 섞였다"는 인상이었다.
/// 무엇처럼 보이는지가 아니라 **그 글자가 화면에서 하는 일**로 가른다:
/// - `caption` = **읽는 문장** — 부제·설명·안내. 문장이라 셋 중 가장 크다.
/// - `metaText` = **훑는 값** — 시간·개수·타임스탬프, 라벨=값 행의 오른쪽에 서는 데이터.
/// - `groupLabel` = **묶음의 이름표** — 아래 행/칩들을 여는 섹션 라벨. 자기가 읽히려고 있는 게
///   아니라 아래를 가리키므로 셋 중 가장 작고(12) 가장 옅다(호출부가 `ReffiColor.muted`).
///
/// 갈림길 하나 더:
/// - `monoTicketLabel`·`monoEyebrow`·`sectionLabel` = **번역하지 않는 라틴 크롬 전용**(verbatim).
///   올캡·광자간이 시각 문법인데 한글엔 대문자가 없어, 번역되는 라벨엔 쓰지 않는다 — 그건 `groupLabel`.
enum ReffiActionRole {
    case monoTicketLabel   // 티켓 인쇄 크롬 전부 — 크라운("ORDER · REFFI KITCHEN"·"ORDER · FIRED")·"#NN"·"ON THE TICKET"
    case monoEyebrow       // 초소형 올캡 라벨(비번역 라틴) — "MORNING ALERTS"·"REFFI · KEEP IT FRESH"
    case sectionLabel      // 섹션 라벨(비번역 라틴 올캡) — "RECIPE"·"INGREDIENTS"·"ITEM"·"DETAILS"

    /// 섹션 라벨(**번역됨**) — 행 묶음의 이름표. `sectionLabel`의 번역 가능한 쌍둥이다.
    ///
    /// **쓴다**: 아래에 행·칩이 딸린 묶음을 여는 한 줄(영수증 카드 제목·설정 그룹·담기 픽커 카테고리).
    /// 색은 호출부가 `ReffiColor.muted`로 준다 — 이름표는 자기가 아니라 아래 내용을 읽히게 한다.
    /// **안 쓴다**: ① 내용 블록의 제목(그건 `subhead` — "Tally"·"Timeline"처럼 그 줄 자체가 읽히는
    /// 제목이고, 아래를 여는 이름표가 아니다) ② 비번역 라틴 올캡 폼 라벨(그건 `sectionLabel`)
    /// ③ 문장으로 읽히는 안내문(그건 `caption`) ④ 라벨=값 행의 값(그건 `metaText`).
    ///
    /// **왜 role을 하나 더 만들었나.** 묶음 이름표를 `caption`(14/Medium)에 얹으면 그 아래 행 라벨
    /// `body`(16/Regular)와 비가 1.14라 계단이 서지 않고, 그 위에 굵기가 뒤집혀(작은 쪽이 더 굵다)
    /// 크기·색이 만든 신호를 상쇄한다. 12로 내리면 16/12 = 1.333으로 한 단이 확실히 서고,
    /// §3.5의 컴포넌트 하한 10pt 안이다(11까지 내리지 않은 것은 §3.5 본문이 지적한 한글 라벨의
    /// 10~11pt 리스크 때문이다 — 그 크기대에선 글자가 아니라 자간만 남는다).
    ///
    /// **굵기는 Medium이다(SemiBold로 올리지 말 것).** caption 14 → metaText 13 → groupLabel 12 의
    /// **Medium 라벨 램프**를 만드는 것이 이 role의 목적이다. 여기서 굵기를 올리면 지금 고치려는
    /// 병("더 작은 쪽이 더 굵다")을 한 단 아래에 그대로 재발명한다 — 크기와 색으로만 내린다.
    ///
    /// **올캡을 붙이지 않는다.** 번역되는 문자열이라 한국어에서 `.uppercased()`가 no-op이 되고,
    /// 라틴 올캡의 시각 문법(`sectionLabel`)이 한글에선 "그냥 작은 글자"로만 남는다.
    ///
    /// **`relativeTo`가 `.caption2`인 것이 하한 보장이다(§3.3 축소 금지를 지키는 방법).**
    /// `.caption2`는 xSmall~Large 구간이 전부 11pt(스케일 1.0)라, 12pt를 여기 매달면 **어떤 콘텐츠
    /// 크기에서도 12pt 아래로 내려가지 않는다** — `minimumScaleFactor`나 별도 클램프가 필요 없다.
    /// 더 완만한 `.footnote`(xSmall 12 / Large 13)에 매달면 12pt가 xSmall에서 11.1pt로 깨진다.
    /// 반대 끝의 대가는 계단이 얇아지는 것이다: `.caption2`(11→40)가 `.body`(17→53)보다 곡선이
    /// 가팔라 AX5에서 groupLabel ≈44pt · body ≈50pt로 1.333배 계단이 1.15배가 된다.
    /// 다만 **역전되는 구간은 없다**(Apple 공표 Dynamic Type 표로 전 구간 계산 — 실기기 실측은 아니다).
    /// 얇아진 계단을 색(muted)이 받치므로, 여기서 크기를 더 내려 계단을 벌리려 들지 말 것.
    case groupLabel

    case menuName          // 티켓/레시피 메뉴명
    case metaText          // 데이터형 메타(훑는 값) — 시간·개수·타임스탬프·판정 키커·라벨=값 행의 값
    case pillLabel         // 버튼·필 라벨 — Undo·Add·Bought·Turn on·Later + QuietButton 등 1차 CTA 밖 전부
    case badgeLabel        // 뱃지·아이콘버튼·칩 라벨
    case checklistItem     // 행 자체가 콘텐츠인 목록의 항목명(재료명·체크 항목·선택지). 설정·폼 라벨은 body
    case stampLabel        // START 등 도장 텍스트(고정 34) — 가변 크기는 `Font.reffiStamp` 참고
}

extension ReffiActionRole {
    var font: Font {
        switch self {
        case .monoTicketLabel: return .custom("Pretendard-Bold", size: 13, relativeTo: .caption)
        case .monoEyebrow:     return .custom("Pretendard-Bold", size: 10, relativeTo: .caption2)
        case .sectionLabel:    return .custom("Pretendard-SemiBold", size: 11, relativeTo: .caption2)
        case .groupLabel:      return .custom("Pretendard-Medium", size: 12, relativeTo: .caption2)
        case .menuName:        return .custom("Pretendard-Bold", size: 26, relativeTo: .title2)
        case .metaText:        return .custom("Pretendard-Medium", size: 13, relativeTo: .caption)
        case .pillLabel:       return .custom("Pretendard-SemiBold", size: 13, relativeTo: .caption)
        case .badgeLabel:      return .custom("Pretendard-SemiBold", size: 15, relativeTo: .subheadline)
        case .checklistItem:   return .custom("Pretendard-SemiBold", size: 16, relativeTo: .body)
        case .stampLabel:      return .reffiStamp(34, relativeTo: .largeTitle)
        }
    }

    /// 자간 — 모노/올캡 라벨은 넓게(§13.5 헤더 문법), 그 외는 0 또는 살짝 좁게(badgeLabel).
    var tracking: CGFloat {
        switch self {
        case .monoTicketLabel: return 2.5
        case .monoEyebrow:     return 1.6
        case .sectionLabel:    return 1.4
        // 0.05em — 훑는 라벨은 벌려야 이름표로 읽히지만, 위 셋과 달리 **올캡이 자간을 받쳐 주지
        // 않고 한글도 이 값을 그대로 받는다**(위 셋은 비번역 라틴 전용이라 그 제약이 없었다).
        // 한글 음절은 이미 제 상자 안에 여백을 갖고 있어 더 벌리면 단어가 흩어지므로,
        // 라틴 올캡 크롬(1.4~1.6)의 절반 아래에서 멈춘다. 이 값을 올리려면 한글 라벨부터 볼 것.
        case .groupLabel:      return 0.6
        case .menuName:        return -0.3
        case .metaText:        return 0
        case .pillLabel:       return 0
        case .badgeLabel:      return -0.15
        case .checklistItem:   return 0
        case .stampLabel:      return 3
        }
    }
}

extension View {
    /// 보조 스케일 적용(폰트+자간) — §3.5. 표면 구분 없이 쓰고, 화면당 계층 상한(≤7)은 §3.3이 잡는다.
    func reffiType(_ role: ReffiActionRole) -> some View {
        self.font(role.font).tracking(role.tracking)
    }
}

#if DEBUG
import UIKit
enum ReffiFontCheck {
    /// 번들 폰트가 등록됐는지 콘솔로 확인(런치 시 1회).
    static func dump() {
        for want in ["Pretendard-Regular", "GoogleSansFlex-Regular", "OkDanDan-Bold"] {
            let ok = UIFont(name: want, size: 16) != nil
            print("[ReffiFont] \(want): \(ok ? "OK" : "MISSING")")
        }
    }
}
#endif
