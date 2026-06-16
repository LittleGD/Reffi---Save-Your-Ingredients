import Foundation
import SwiftData

/// 식재료 — SwiftData 영속 모델.
/// 핵심은 "버리기 전에 먹기": 유통기한까지 남은 날(daysLeft)을 색·정렬의 기준으로 쓴다.
@Model
final class Ingredient {
    var name: String
    var category: String
    var addedDate: Date
    var expiryDate: Date
    var storage: String   // 보관법 (예: 냉장·냉동·실온)

    init(
        name: String,
        category: String,
        addedDate: Date = .now,
        expiryDate: Date,
        storage: String = "Fridge"
    ) {
        self.name = name
        self.category = category
        self.addedDate = addedDate
        self.expiryDate = expiryDate
        self.storage = storage
    }

    /// 오늘 자정 기준 유통기한까지 남은 일수. 오늘 = 0, 지남 = 음수.
    var daysLeft: Int {
        let cal = Calendar.current
        let start = cal.startOfDay(for: .now)
        let end = cal.startOfDay(for: expiryDate)
        return cal.dateComponents([.day], from: start, to: end).day ?? 0
    }

    /// 신선도 — daysLeft에서 파생(§2.5).
    var freshness: Freshness { Freshness(daysLeft: daysLeft) }

    /// 카드의 D-N 표기. D-0 / 지남 분리.
    var countdownLabel: String {
        if daysLeft > 0 { return "D-\(daysLeft)" }
        if daysLeft == 0 { return "Today" }
        return "\(-daysLeft)d over" // 지남
    }
}
