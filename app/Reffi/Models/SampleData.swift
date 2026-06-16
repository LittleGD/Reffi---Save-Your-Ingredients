import Foundation
import SwiftData

/// 첫 실행 시 비어 있으면 샘플 식재료를 시드한다.
/// 스켈레톤이 시뮬레이터에서 바로 카드 스택을 보여주기 위함 — 실제 데이터 흐름(영수증 스캔)은 이후 단계.
enum SampleData {
    static func seedIfEmpty(_ context: ModelContext) {
        let count = (try? context.fetchCount(FetchDescriptor<Ingredient>())) ?? 0
        guard count == 0 else { return }

        let cal = Calendar.current
        func day(_ offset: Int) -> Date {
            cal.date(byAdding: .day, value: offset, to: cal.startOfDay(for: .now)) ?? .now
        }

        let seeds: [Ingredient] = [
            Ingredient(name: "Tofu",           category: "Soy",   expiryDate: day(0),  storage: "Fridge"),
            Ingredient(name: "Chicken breast", category: "Meat",  expiryDate: day(1),  storage: "Fridge"),
            Ingredient(name: "Spinach",        category: "Veg",   expiryDate: day(2),  storage: "Fridge"),
            Ingredient(name: "Milk",           category: "Dairy", expiryDate: day(3),  storage: "Fridge"),
            Ingredient(name: "Carrot",         category: "Veg",   expiryDate: day(6),  storage: "Fridge"),
            Ingredient(name: "Apple",          category: "Fruit", expiryDate: day(9),  storage: "Fridge"),
            Ingredient(name: "Potato",         category: "Veg",   expiryDate: day(14), storage: "Pantry"),
        ]
        for item in seeds { context.insert(item) }
    }
}
