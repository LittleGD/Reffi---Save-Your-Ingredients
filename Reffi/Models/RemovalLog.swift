import Foundation

/// 소비/버림 이력 한 줄 — History·낭비율의 소스. (디자인 빌드라 daysAgo로 과거를 표현)
struct RemovalLog: Identifiable {
    let id = UUID()
    var name: String
    var glyph: FoodGlyph
    var daysAgo: Int     // 며칠 전에 처리했는지
    var wasted: Bool     // true = 버림(Tossed), false = 먹음(Ate)

    var dateText: String {
        let d = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        return d.formatted(date: .abbreviated, time: .omitted)
    }
}
