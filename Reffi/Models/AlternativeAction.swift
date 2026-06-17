import Foundation

/// 대안액션 — 재료를 (못) 먹기 전 취할 수 있는 다른 처리.
/// 카드에서 "지금 행동"을 한 줄로 제시(§1 행동 우선).
enum AlternativeAction {
    case freeze   // 냉동 보관
    case prep     // 손질 · 소분
    case share    // 나눔
    case cook     // 바로 레시피로

    /// 카드 본문에 들어가는 짧은 제안.
    var title: String {
        switch self {
        case .freeze: "얼리면 2주 더"
        case .prep:   "손질해 소분"
        case .share:  "이웃과 나눔"
        case .cook:   "지금 바로 조리"
        }
    }

    /// 빠른 액션 버튼 라벨.
    var actionLabel: String {
        switch self {
        case .freeze: "냉동하기"
        case .prep:   "소분하기"
        case .share:  "나눔하기"
        case .cook:   "레시피 보기"
        }
    }
}
