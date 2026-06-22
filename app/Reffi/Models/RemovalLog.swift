import Foundation
import SwiftData

/// 냉장고에서 나간 항목 1건의 기록 (IA의 소진/폐기 이력 토대).
/// `wasted`로 "버림(유통기한 지나 폐기)" vs "소비(제때 먹음)"를 구분해
/// 누적 낭비율(버림 / 전체)을 낸다.
@Model
final class RemovalLog {
    var name: String
    var category: String   // 카테고리별 낭비 분석용 (IngredientCategory.rawValue)
    var removedDate: Date
    var wasted: Bool       // true = 유통기한 지나 버림, false = 제때 소비

    init(name: String, category: String = "other", removedDate: Date = .now, wasted: Bool) {
        self.name = name
        self.category = category
        self.removedDate = removedDate
        self.wasted = wasted
    }
}
