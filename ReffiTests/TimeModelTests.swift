import Testing
import Foundation
@testable import Reffi

/// 시간 모델 — 절대 시각 원본 + asOf 주입 계산의 자정 경계·냉동 유예 검증.
struct TimeModelTests {

    private func date(_ y: Int, _ m: Int, _ d: Int, hour: Int = 12) -> Date {
        Calendar.current.date(from: DateComponents(year: y, month: m, day: d, hour: hour))!
    }

    @Test func daysLeftCountsCalendarDaysNotHours() {
        // 만료가 내일 자정이면 오늘 23시에도 D-1이어야 한다(시각이 아니라 달력 일수).
        let ing = Ingredient(name: "Milk", category: "Dairy",
                             expiresAt: date(2026, 7, 3, hour: 0))
        #expect(ing.daysLeft(asOf: date(2026, 7, 2, hour: 23)) == 1)
        #expect(ing.daysLeft(asOf: date(2026, 7, 3, hour: 0)) == 0)
        #expect(ing.daysLeft(asOf: date(2026, 7, 4, hour: 1)) == -1)
    }

    @Test func effectiveClockUsesFreezerGrace() {
        // 냉동 전환(frozenAt) 시 유예 14일의 새 시계 — 원본 expiresAt은 불변.
        var ing = Ingredient(name: "Beef", category: "Meat",
                             expiresAt: date(2026, 7, 2))
        ing.storage = .freezer
        ing.frozenAt = date(2026, 7, 2)
        #expect(ing.effectiveDaysLeft(asOf: date(2026, 7, 2)) == Ingredient.freezerGraceDays)
        #expect(ing.daysLeft(asOf: date(2026, 7, 2)) == 0)   // 원본 시계는 그대로
        // 해동(냉장 복귀) — 원본 시계로 돌아온다.
        ing.storage = .fridge
        #expect(ing.effectiveDaysLeft(asOf: date(2026, 7, 2)) == 0)
    }

    @Test func boughtFrozenUsesOwnExpiry() {
        // 처음부터 냉동으로 산 재료(frozenAt 없음)는 등록된 소비기한 그대로.
        let ing = Ingredient(name: "Dumpling", category: "Other",
                             expiresAt: date(2026, 9, 1),
                             storage: .freezer)
        #expect(ing.effectiveDaysLeft(asOf: date(2026, 7, 2)) == ing.daysLeft(asOf: date(2026, 7, 2)))
    }

    @Test func refreezeIsBlocked() {
        var ing = Ingredient(name: "Beef", category: "Meat", expiresAt: date(2026, 7, 2))
        #expect(ing.canFreeze)
        ing.storage = .freezer
        ing.frozenAt = date(2026, 7, 1)
        #expect(!ing.canFreeze)
        ing.storage = .fridge   // 해동해도 frozenAt이 남아 재냉동 불가(1회 제한)
        #expect(!ing.canFreeze)
    }

    @Test func freshnessFollowsEffectiveClock() {
        var ing = Ingredient(name: "Beef", category: "Meat", expiresAt: Ingredient.day(offset: 0))
        #expect(ing.freshness == .urgent)
        ing.storage = .freezer
        ing.frozenAt = Date()
        #expect(ing.freshness == .fresh)   // 유예 14일 → fresh
    }
}

/// 수량 — 레거시 파싱·단위 환산·절반.
struct QuantityTests {

    /// 표시 문자열은 로케일 포맷터가 만든다 — 포맷 문자열(%.1f)이 찍던 고정 마침표·무그룹 회귀 방지.
    @Test func textUsesLocaleFormatter() {
        let nbsp = "\u{00A0}"
        #expect(Quantity(value: 3, unit: .gram).text == "3\(nbsp)g")
        #expect(Quantity(value: 0.5, unit: .block).text.hasPrefix("½\(nbsp)"))
        let fractional = 2.5.formatted(.number.precision(.fractionLength(0...1)))
        #expect(Quantity(value: 2.5, unit: .gram).text == "\(fractional)\(nbsp)g")
        // 천 단위는 로케일 그룹 구분자를 따른다(예전엔 항상 "1500").
        #expect(Quantity(value: 1500, unit: .gram).text
                == "\(1500.formatted(.number.precision(.fractionLength(0...1))))\(nbsp)g")
    }

    @Test func parsesLegacyStrings() {
        #expect(Quantity.parseLegacy("300 g") == Quantity(value: 300, unit: .gram))
        #expect(Quantity.parseLegacy("2 ea") == Quantity(value: 2, unit: .piece))
        #expect(Quantity.parseLegacy("1 L") == Quantity(value: 1, unit: .liter))
        #expect(Quantity.parseLegacy("1") == Quantity(value: 1, unit: .piece))
        #expect(Quantity.parseLegacy("½모 남음") == Quantity(value: 0.5, unit: .block))
        #expect(Quantity.parseLegacy("1 pack") == Quantity(value: 1, unit: .pack))
        // "l"(리터) 접두 오파싱 회귀 — "½ loaf"는 리터가 아니라 덩이(block).
        #expect(Quantity.parseLegacy("½ loaf") == Quantity(value: 0.5, unit: .block))
        #expect(Quantity.parseLegacy("1 liter") == Quantity(value: 1, unit: .liter))
        // 파싱 불가 — 1개 폴백.
        #expect(Quantity.parseLegacy("조금") == Quantity(value: 1, unit: .piece))
    }

    @Test func convertsWithinDimension() {
        let kg = Quantity(value: 1.5, unit: .kilogram)
        #expect(kg.converted(to: .gram) == Quantity(value: 1500, unit: .gram))
        let ml = Quantity(value: 500, unit: .milliliter)
        #expect(ml.converted(to: .liter) == Quantity(value: 0.5, unit: .liter))
        // 차원이 다르면 환산 불가.
        #expect(kg.converted(to: .piece) == nil)
        #expect(Quantity(value: 2, unit: .piece).converted(to: .pack) == nil)
    }

    @Test func halvedKeepsFloor() {
        #expect(Quantity(value: 2, unit: .piece).halved == Quantity(value: 1, unit: .piece))
        #expect(Quantity(value: 0.25, unit: .piece).halved.value == 0.25)   // 바닥 유지
    }
}
