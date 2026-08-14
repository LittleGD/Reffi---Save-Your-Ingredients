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
}

extension View {
    /// Reffi 타이포 위계 적용(폰트+자간+행간). 색은 면에 따라(§2.6) 별도로 준다.
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
    static func reffiNum(_ scale: ReffiNumScale) -> Font {
        .custom("GoogleSansFlex-Regular", size: scale.size, relativeTo: scale.textStyle).monospacedDigit()
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
    case pillLabel         // 필/버튼 라벨 — Undo·Add·Skip·Turn on·Later
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
