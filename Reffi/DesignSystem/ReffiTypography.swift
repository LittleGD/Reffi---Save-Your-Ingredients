import SwiftUI

/// Reffi 타이포 위계(§3.2). iOS는 항상 모바일 스케일(<1200px 시스템)을 쓰고,
/// `relativeTo`로 Dynamic Type에 맞춰 스케일한다. 한글=Pretendard, 영문 Display=Story Script,
/// 데이터성 숫자=Google Sans Flex(§3.4 `reffiNum`).
enum ReffiTextRole {
    case display   // 워드마크·표지 — Story Script(영문) / Pretendard Bold(한글)
    case heading   // 제목
    case subhead   // 소제목 · 카드 이름
    case body      // 본문
    case caption   // 캡션 · 라벨 — 문장형 메타(부제·설명·안내). 데이터형 메타는 §3.5 metaText
}

extension ReffiTextRole {
    var font: Font {
        switch self {
        case .display: return .custom("StoryScript-Regular", size: 34, relativeTo: .largeTitle)
        case .heading: return .custom("Pretendard-Bold",     size: 24, relativeTo: .title)
        case .subhead: return .custom("Pretendard-SemiBold", size: 18, relativeTo: .title3)
        case .body:    return .custom("Pretendard-Regular",  size: 16, relativeTo: .body)
        case .caption: return .custom("Pretendard-Medium",   size: 14, relativeTo: .caption)
        }
    }

    /// 자간: Heading·Subhead·Body −1%, Caption +1%, Display 0(Story Script 연결 글자).
    var tracking: CGFloat {
        switch self {
        case .display: return 0
        case .heading: return 24 * -0.01
        case .subhead: return 18 * -0.01
        case .body:    return 16 * -0.01
        case .caption: return 14 *  0.01
        }
    }

    /// 행간 근사(120%/140%). 단일 행 텍스트에는 영향이 없다.
    var lineSpacing: CGFloat {
        switch self {
        case .display, .heading, .subhead: return 2
        case .body:    return 5
        case .caption: return 3
        }
    }

    /// 한글 Display 폴백(Story Script는 한글 미지원 → Pretendard Bold, §3.1).
    var koreanDisplayFont: Font {
        if case .display = self {
            return .custom("Pretendard-Bold", size: 34, relativeTo: .largeTitle)
        }
        return font
    }

    /// **표시될 문자열에 맞춘** 폰트 — Display에 한글이 섞이면 위 폴백으로 내려간다(§3.1).
    /// 번역되는 Display 텍스트(냉장고 타이틀·온보딩 타이틀·단계 표기·닉네임)는 전부 이 문을 지나야 한다:
    /// `.custom()`에는 폰트 스택이 없어, 폴백을 배선하지 않으면 누락 글리프가 Pretendard가 아니라
    /// **시스템 한글 서체**로 조용히 캐스케이드된다 — 브랜드 밖 서체가 한국어에만 나타난다.
    /// Display가 아닌 role은 이미 Pretendard라 그대로다.
    func font(for text: String) -> Font {
        text.hasHangul ? koreanDisplayFont : font
    }
}

extension String {
    /// 한글 포함 여부 — Story Script·Google Sans Flex는 한글 미지원(§3.1)이라 폴백 판별에 쓴다.
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
    /// **비번역 라틴(워드마크 등) 전용**이다 — 번역되는 Display 텍스트는 아래 `reffiType(_:for:)`를 쓴다.
    func reffiType(_ role: ReffiTextRole) -> some View {
        self.font(role.font)
            .tracking(role.tracking)
            .lineSpacing(role.lineSpacing)
    }

    /// 같은 위계에 **스크립트 폴백**까지 — 실제로 그려질 문자열을 넘겨 폰트를 고른다(§3.1).
    /// 문자열을 따로 받는 이유: SwiftUI는 `Text`가 들고 있는 `LocalizedStringKey`의 해석 결과를
    /// 밖으로 내주지 않아, 호출부가 `String(localized:)`로 한 번 풀어 같은 값을 둘에 함께 넘겨야 한다.
    func reffiType(_ role: ReffiTextRole, for text: String) -> some View {
        self.font(role.font(for: text))
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

    /// **표시될 문자열에 맞춘** 숫자 폰트(§3.4·42차) — `ReffiTextRole.font(for:)`와 같은 이유, 같은 문법.
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
    /// 16번째 역할이 아니라 헬퍼: 고정 9종 밖의 "동일 문법·가변 크기" 컴포넌트를 위한 탈출구.
    static func reffiStamp(_ size: CGFloat, relativeTo style: Font.TextStyle = .subheadline) -> Font {
        .custom("Pretendard-Bold", size: size, relativeTo: style)
    }
}

/// 보조 스케일(§3.5) — §3.2의 5단계가 **문서 위계**라면 이 9종은 **컴포넌트 위계**다:
/// 라벨·크롬·칩·리스트 항목처럼 문장이 아니라 부품에 붙는 글자. **표면을 가리지 않는 공통 스케일**이고,
/// 화면당 총량은 §3.3의 단일 상한(계층 ≤ 7종)이 잡는다.
/// `ReffiTextRole`과 동일 패턴(font/tracking + `reffiType` 오버로드)으로 raw `.custom("Pretendard-*")`
/// 산발 지정을 대체한다.
///
/// 갈림길 둘:
/// - `caption`(14) = **문장형** 메타(부제·설명·안내) / `metaText`(13) = **데이터형** 메타(시간·개수·타임스탬프).
/// - `monoTicketLabel`·`monoEyebrow`·`sectionLabel` = **번역하지 않는 라틴 크롬 전용**(verbatim).
///   올캡·광자간이 시각 문법인데 한글엔 대문자가 없어, 번역되는 라벨엔 쓰지 않는다 — 그건 `caption`.
enum ReffiActionRole {
    case monoTicketLabel   // 티켓 인쇄 크롬 전부 — 크라운("ORDER · REFFI KITCHEN"·"ORDER · FIRED")·"#NN"·"ON THE TICKET"
    case monoEyebrow       // 초소형 올캡 라벨(비번역 라틴) — "MORNING ALERTS"·"REFFI · KEEP IT FRESH"
    case sectionLabel      // 섹션 라벨(비번역 라틴) — "RECIPE"·"INGREDIENTS"·"ITEM"·"DETAILS"
    case menuName          // 티켓/레시피 메뉴명
    case metaText          // 데이터형 메타 — 시간·개수·타임스탬프·판정 키커(문장형은 caption)
    case pillLabel         // 필/버튼 라벨 — Undo·Add·Bought·Turn on·Later
    case badgeLabel        // 뱃지·아이콘버튼·칩 라벨
    case checklistItem     // 체크리스트·재료 리스트 항목명
    case stampLabel        // START 등 도장 텍스트(고정 34) — 가변 크기는 `Font.reffiStamp` 참고
}

extension ReffiActionRole {
    var font: Font {
        switch self {
        case .monoTicketLabel: return .custom("Pretendard-Bold", size: 13, relativeTo: .caption)
        case .monoEyebrow:     return .custom("Pretendard-Bold", size: 10, relativeTo: .caption2)
        case .sectionLabel:    return .custom("Pretendard-SemiBold", size: 11, relativeTo: .caption2)
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
        for want in ["Pretendard", "Google Sans Flex", "Story Script"] {
            let ok = UIFont.familyNames.contains { $0.localizedCaseInsensitiveContains(want) }
            print("[ReffiFont] \(want): \(ok ? "OK" : "MISSING")")
        }
    }
}
#endif
