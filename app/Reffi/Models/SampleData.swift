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

        // 구매처·수량은 영수증 스캔이 채울 값 — 여기선 영수증에서 읽었다고 가정한 샘플.
        let seeds: [Ingredient] = [
            // 만료일을 -2~45일로 고르게 펴 스택 위쪽부터 빨강→주황→노랑→초록 그라데이션이 보이게.
            Ingredient(name: "Tofu",           category: "other",      addedDate: day(-4), expiryDate: day(-2), storage: "Fridge", purchasePlace: "Emart",       quantity: "300 g"),
            Ingredient(name: "Chicken breast", category: "meat",       addedDate: day(-2), expiryDate: day(0),  storage: "Fridge", purchasePlace: "Costco",      quantity: "500 g"),
            Ingredient(name: "Greek yogurt",   category: "dairy",      addedDate: day(-2), expiryDate: day(2),  storage: "Fridge", purchasePlace: "Emart",       quantity: "4 cups"),
            Ingredient(name: "Salmon fillet",  category: "seafood",    addedDate: day(-2), expiryDate: day(4),  storage: "Fridge", purchasePlace: "Costco",      quantity: "2 ea"),
            Ingredient(name: "Spinach",        category: "vegetables", addedDate: day(-3), expiryDate: day(6),  storage: "Fridge", purchasePlace: "Emart",       quantity: "1 bunch"),
            Ingredient(name: "Milk",           category: "dairy",      addedDate: day(-3), expiryDate: day(8),  storage: "Fridge", purchasePlace: "GS25",        quantity: "900 ml"),
            Ingredient(name: "Sliced bread",   category: "grains",     addedDate: day(-3), expiryDate: day(11), storage: "Pantry", purchasePlace: "Paris Baguette", quantity: "1 loaf"),
            Ingredient(name: "Eggs",           category: "dairy",      addedDate: day(-3), expiryDate: day(14), storage: "Fridge", purchasePlace: "Emart",       quantity: "10 ea"),
            Ingredient(name: "Bananas",        category: "fruit",      addedDate: day(-3), expiryDate: day(17), storage: "Room",   purchasePlace: "Hanaro Mart", quantity: "1 bunch"),
            Ingredient(name: "Carrot",         category: "vegetables", addedDate: day(-4), expiryDate: day(20), storage: "Fridge", purchasePlace: "Emart",       quantity: "3 ea"),
            Ingredient(name: "Bell pepper",    category: "vegetables", addedDate: day(-4), expiryDate: day(24), storage: "Fridge", purchasePlace: "Emart",       quantity: "2 ea"),
            Ingredient(name: "Apple",          category: "fruit",      addedDate: day(-4), expiryDate: day(28), storage: "Fridge", purchasePlace: "Hanaro Mart", quantity: "5 ea"),
            Ingredient(name: "Cheddar",        category: "dairy",      addedDate: day(-5), expiryDate: day(32), storage: "Fridge", purchasePlace: "Costco",      quantity: "200 g"),
            Ingredient(name: "Potato",         category: "vegetables", addedDate: day(-5), expiryDate: day(36), storage: "Pantry", purchasePlace: "Costco",      quantity: "1 kg"),
            Ingredient(name: "Onion",          category: "vegetables", addedDate: day(-6), expiryDate: day(40), storage: "Pantry", purchasePlace: "Emart",       quantity: "5 ea"),
            Ingredient(name: "Rice",           category: "grains",     addedDate: day(-6), expiryDate: day(45), storage: "Pantry", purchasePlace: "Costco",      quantity: "5 kg"),
        ]
        for item in seeds { context.insert(item) }

        seedRemovalLogIfEmpty(context, day: day)
    }

    /// 누적 낭비율 마커가 의미 있는 값을 보이도록 샘플 폐기/소비 이력을 시드한다.
    /// (실데이터에선 삭제 시점에 항목이 만료였는지로 자동 집계 — 이건 데모용 과거 이력.)
    private static func seedRemovalLogIfEmpty(_ context: ModelContext, day: (Int) -> Date) {
        let count = (try? context.fetchCount(FetchDescriptor<RemovalLog>())) ?? 0
        guard count == 0 else { return }

        // (name, category, dayOffset, wasted) — History 데모용 과거 이력(최근 30일 + 전월 일부).
        let logs: [(String, String, Int, Bool)] = [
            // 소비
            ("Eggs", "dairy", -1, false), ("Yogurt", "dairy", -2, false),
            ("Banana", "fruit", -3, false), ("Lettuce", "vegetables", -4, false),
            ("Cheese", "dairy", -6, false), ("Bread", "grains", -8, false),
            ("Onion", "vegetables", -9, false), ("Pork belly", "meat", -11, false),
            ("Apple", "fruit", -14, false), ("Rice", "grains", -16, false),
            // 버림
            ("Strawberries", "fruit", -3, true), ("Cilantro", "vegetables", -5, true),
            ("Spinach", "vegetables", -10, true), ("Milk", "dairy", -13, true),
            ("Lettuce", "vegetables", -20, true),
            // 전월(추세 비교용, 30일 밖)
            ("Tofu", "other", -34, true), ("Carrot", "vegetables", -36, true),
            ("Yogurt", "dairy", -38, false), ("Bread", "grains", -40, false),
        ]
        for (name, cat, off, w) in logs {
            context.insert(RemovalLog(name: name, category: cat, removedDate: day(off), wasted: w))
        }
    }
}
