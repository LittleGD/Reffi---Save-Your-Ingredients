import SwiftUI

/// 신선도 상태 (§2.5 카운트다운 → 색 매핑).
/// 색은 항상 텍스트 라벨과 함께 쓴다(색 단독 금지).
enum Freshness: Hashable {
    case fresh   // D-4 이상 · 여유
    case soon    // D-3 ~ D-1 · 곧 먹어야
    case urgent  // D-0 / 지남 · 오늘·초과

    /// 남은 일수로 신선도 판정.
    init(daysLeft: Int) {
        switch daysLeft {
        case ..<1:  self = .urgent   // D-0 또는 지남
        case 1...3: self = .soon
        default:    self = .fresh    // D-4+
        }
    }

    /// 카드/칩 파스텔 면 색 (main). 위 글자는 ink.
    var color: Color {
        switch self {
        case .fresh:  return ReffiColor.fresh
        case .soon:   return ReffiColor.soon
        case .urgent: return ReffiColor.urgent
        }
    }

    /// 캔버스 위 색-텍스트·세선·솔리드 강조용 (dark).
    var colorDark: Color {
        switch self {
        case .fresh:  return ReffiColor.freshDark
        case .soon:   return ReffiColor.soonDark
        case .urgent: return ReffiColor.urgentDark
        }
    }

    var label: String {
        switch self {
        case .fresh:  return "Fresh"
        case .soon:   return "Soon"
        case .urgent: return "Today"
        }
    }
}
