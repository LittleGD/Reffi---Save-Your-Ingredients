import Foundation
import SwiftUI

/// 요리 스타일 선호(§5.2) — 프로필에서 멀티 선택, 추후 레시피 추천 가중치의 소스가 된다.
/// rawValue는 UserDefaults 영속화용 안정 키(라벨 바뀌어도 저장값 유지).
/// brazilian은 제거 — 시드 레시피에 대응 cuisine이 0건이라 어떤 실동작(가점)도 못 만드는
/// 위약 옵션이었다(MVP 원칙). 저장된 rawValue는 ProfileStore가 compactMap으로 무시(안전 디코드).
enum CuisineStyle: String, CaseIterable, Identifiable, Codable {
    case korean, western, japanese, chinese, italian, mexican
    case indian, thai, mediterranean, vietnamese, vegetarian

    var id: String { rawValue }

    /// 칩 라벨 **키**(42차) — `SelectableChip`이 키를 그대로 받아 SwiftUI가 `\.locale` 환경으로
    /// 리졸브하게 한다. `label`(String)은 조회 시점의 번들에 굳어 인앱 언어 전환이 재실행 전까지
    /// 안 먹었다. 조인이 필요한 `summaryText`는 계속 `label`을 쓴다(문자열이 구조상 필요한 자리).
    var labelKey: LocalizedStringKey { LocalizedStringKey(rawValue.capitalized) }

    /// 칩·요약 라벨 — 저장값은 영문 식별자 그대로, 표시만 로컬라이즈.
    var label: String {
        switch self {
        case .korean:        AppLanguage.localizedNow("Korean")
        case .western:       AppLanguage.localizedNow("Western")
        case .japanese:      AppLanguage.localizedNow("Japanese")
        case .chinese:       AppLanguage.localizedNow("Chinese")
        case .italian:       AppLanguage.localizedNow("Italian")
        case .mexican:       AppLanguage.localizedNow("Mexican")
        case .indian:        AppLanguage.localizedNow("Indian")
        case .thai:          AppLanguage.localizedNow("Thai")
        case .mediterranean: AppLanguage.localizedNow("Mediterranean")
        case .vietnamese:    AppLanguage.localizedNow("Vietnamese")
        case .vegetarian:    AppLanguage.localizedNow("Vegetarian")
        }
    }
}

extension Set where Element == CuisineStyle {
    /// 프로필 행 요약 — "한식 · 양식 +1" (CaseIterable 순서로 안정 정렬).
    var summaryText: String {
        guard !isEmpty else { return AppLanguage.localizedNow("None yet") }
        let ordered = CuisineStyle.allCases.filter { contains($0) }
        let head = ordered.prefix(2).map(\.label).joined(separator: " · ")
        let extra = ordered.count - Swift.min(2, ordered.count)
        return extra > 0 ? "\(head) +\(extra)" : head
    }
}
