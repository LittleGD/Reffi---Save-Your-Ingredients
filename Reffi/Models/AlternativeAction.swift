import Foundation

/// 대안액션 — 재료를 (못) 먹기 전 취할 수 있는 다른 처리. (현재 메인 플로우에선 미사용, 보존용)
enum AlternativeAction {
    case freeze
    case prep
    case share
    case cook

    var title: String {
        switch self {
        case .freeze: "Freeze (2 wks)"
        case .prep:   "Prep & portion"
        case .share:  "Share"
        case .cook:   "Cook now"
        }
    }

    var actionLabel: String {
        switch self {
        case .freeze: "Freeze"
        case .prep:   "Portion"
        case .share:  "Share"
        case .cook:   "See recipe"
        }
    }
}
