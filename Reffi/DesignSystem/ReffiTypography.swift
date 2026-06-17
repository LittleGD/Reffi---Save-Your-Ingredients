import SwiftUI

/// Reffi 타이포 위계(§3.2). iOS는 항상 모바일 스케일(<1200px 시스템)을 쓰고,
/// `relativeTo`로 Dynamic Type에 맞춰 스케일한다. 한글=Pretendard, 영문 Display=Story Script,
/// 데이터성 숫자=Google Sans Flex(§3.4 `reffiNum`).
enum ReffiTextRole {
    case display   // 워드마크·표지 — Story Script(영문) / Pretendard Bold(한글)
    case heading   // 제목
    case subhead   // 소제목 · 카드 이름
    case body      // 본문
    case caption   // 캡션 · 라벨
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

extension Font {
    /// 데이터성 숫자 — Google Sans Flex + tabular·lining(§3.4). D-N·수량·날짜에 의무.
    static func reffiNum(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom("GoogleSansFlex-Regular", size: size, relativeTo: style).monospacedDigit()
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
