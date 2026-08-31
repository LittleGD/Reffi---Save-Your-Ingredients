import Testing
import Foundation
@testable import Reffi

/// 영수증 OCR 파싱 — 축약 상품명 매핑·소음 제거·수량 추출(순수 로직).
struct ReceiptParserTests {

    private let receipt = [
        "이마트 성수점",
        "2026-07-02 21:11",
        "서울우유1L        2,500",
        "삼겹살 500g      12,900",
        "대파               1,200",
        "코카콜라 1.5L     2,800",
        "합계             19,400",
        "카드승인 12345678",
        "감사합니다",
    ]

    @Test func mapsAbbreviatedProductNames() {
        let found = ReceiptParser.candidates(from: receipt)
        let ids = found.map(\.canonicalID)
        #expect(ids.contains("milk"))         // 서울우유1L → milk (포함 매칭)
        #expect(ids.contains("pork-belly"))   // 삼겹살 → pork-belly
        #expect(ids.contains("green-onion"))  // 대파 → green-onion (양파 오탐 아님)
        #expect(!ids.contains("onion"))
    }

    @Test func dropsNoiseLines() {
        let found = ReceiptParser.candidates(from: receipt)
        for c in found {
            #expect(!c.rawLine.contains("합계"))
            #expect(!c.rawLine.contains("카드"))
            #expect(!c.rawLine.contains("감사합니다"))
        }
        // 가격·날짜뿐인 라인도 후보가 되지 않는다.
        #expect(ReceiptParser.candidates(from: ["19,400", "2026-07-02"]).isEmpty)
    }

    @Test func extractsQuantities() {
        let found = ReceiptParser.candidates(from: receipt)
        let milk = found.first { $0.canonicalID == "milk" }
        let pork = found.first { $0.canonicalID == "pork-belly" }
        #expect(milk?.quantity == Quantity(value: 1, unit: .liter))
        #expect(pork?.quantity == Quantity(value: 500, unit: .gram))
        // 수량 표기가 없으면 1개 기본값.
        let onion = found.first { $0.canonicalID == "green-onion" }
        #expect(onion?.quantity == Quantity(value: 1, unit: .piece))
    }

    /// 45차: 중복 제거의 축이 캐논에서 **정규화 표기**로 바뀌었다 — 같은 캐논으로 떨어지는 서로
    /// 다른 상품(서울우유 1L + 저지방우유 500ml)은 각자 산 물건이라 둘 다 확인 화면에 남아야 한다.
    /// 예전 캐논 축은 두 번째 상품을 화면에서 통째로 지웠다(산 물건의 무성 소실).
    @Test func dedupesByNormalizedNameNotByCanon() {
        let found = ReceiptParser.candidates(from: ["서울우유 1L", "저지방우유 500ml", "우유",
                                                    "서울우유 1L"])
        let milk = found.filter { $0.canonicalID == "milk" }
        #expect(milk.count == 3, "서로 다른 상품 세 줄은 셋 다 남는다")
        #expect(found.count == 3, "같은 표기의 반복(네 번째 줄)만 접힌다")
        // 첫 줄만 사전 표제어 이름을 받고, 같은 캐논의 후속 상품은 원문(정규화)을 유지해 행이 구분된다.
        #expect(milk.dropFirst().allSatisfy { $0.name != milk[0].name })
    }

    /// **미매칭 라인 보존(44차)** — 사전에 없는 실구매 품목은 버리지 않고 캐논 없는 후보로 남긴다
    /// (뷰가 기본 선택을 끄고 배지를 단다). 상품명 꼴이 아닌 파편·중복은 여전히 버린다.
    @Test func keepsUnmatchedProductLinesAsUncheckedCandidates() {
        let found = ReceiptParser.candidates(from: receipt)
        let cola = found.first { $0.canonicalID == nil }
        #expect(cola != nil, "코카콜라는 사전 밖이지만 산 물건이다 — 후보에 남아야 한다")
        #expect(cola?.name == "코카콜라 1.5L")   // 가격 꼬리(2,800)는 정규화로 떨어진다
        // 파편·숫자 라인은 여전히 후보가 아니다.
        #expect(ReceiptParser.candidates(from: ["ㅁ1ㅐ", "x2", "19,400"]).isEmpty)
        // 같은 미매칭 표기는 한 줄만 남는다.
        #expect(ReceiptParser.candidates(from: ["코카콜라 1.5L", "코카콜라 1.5L"]).count == 1)
    }

    /// **영수증 정규화(44차)** — 접두 코드(냉)·행사·1+1·괄호 코드)와 가격 꼬리를 뗀 뒤 한 번 더
    /// 매칭한다. 원문은 rawLine에 그대로 남는다(정규화는 매칭을 돕는 장식 제거지 개명이 아니다).
    @Test func normalizedPrefixCodesStillMatchTheDictionary() {
        let found = ReceiptParser.candidates(from: ["냉)삼겹살 500g 12,900", "*1+1 대파 1,200"])
        let ids = found.map(\.canonicalID)
        #expect(ids.contains("pork-belly"))
        #expect(ids.contains("green-onion"))
        #expect(ReceiptParser.normalizedProductLine("*1+1 코카콜라 1.5L 2,800") == "코카콜라 1.5L")
        #expect(ReceiptParser.normalizedProductLine("[냉장] 무항생제 특란 30구") == "무항생제 특란 30구")
    }

    /// **미국 영수증 약어 전개(44차)** — 실물 영수증 실측 high-confidence 토큰만.
    /// BF(근거 0건)·GRN(green/grain 중의)·MLK 같은 블로그발 추정은 일부러 없다.
    @Test func expandsVerifiedUSReceiptAbbreviations() {
        let found = ReceiptParser.candidates(from: ["GV ALMD MILK 64OZ", "BNLS CKN BRST 2.1LB",
                                                    "KS ORG BROC 3CT"])
        let ids = found.map(\.canonicalID)
        #expect(ids.contains("almond-milk"))
        #expect(ids.contains("chicken-breast"))
        #expect(ids.contains("broccoli"))
        // 묶음 곱셈 꼬리는 면세 별표보다 먼저 소비된다 — "2L*6"의 *는 면세 마크가 아니다.
        #expect(ReceiptParser.normalizedProductLine("삼다수 그린 2L*6") == "삼다수 그린 2L")
        // "한우 1+등급"의 1+는 행사 코드가 아니다 — 숫자+숫자 꼴만 행사로 본다.
        #expect(ReceiptParser.normalizedProductLine("한우 1+등급 등심 100G") == "한우 1+등급 등심 100G")
    }

    /// **개봉 라이프사이클(44차 오너 결정)** — 밀봉 가공식품은 미개봉 장기 기한으로 살다가,
    /// 2주 주기 확인에서 "개봉했다"가 되는 순간 개봉 후 기한으로 줄어든다.
    @Test func sealedLifecycleShortensExpiryOnOpen() {
        let spam = Ingredient(name: "스팸", category: "가공", daysLeft: 1000,
                              quantity: Quantity(value: 1, unit: .piece), glyph: .can,
                              boughtDaysAgo: 15)
        var s = spam
        s.canonicalID = "spam"
        #expect(s.sealedCheckDue(), "밀봉 + 미개봉 + 15일 경과 → 확인 대상")
        s.sealedCheckAt = Date()
        #expect(!s.sealedCheckDue(), "방금 '아직'이라고 답했다 — 2주 뒤에 다시 묻는다")
        s.openedAt = Date()
        #expect(!s.sealedCheckDue(), "개봉했으면 더는 묻지 않는다")
        #expect(s.effectiveDaysLeft <= 3, "개봉 후 기한(스팸 3일)으로 줄어든다")
        // 원 기한이 더 짧으면 개봉 기록이 기한을 늘리지 않는다(min).
        var short = spam
        short.canonicalID = "spam"
        short.expiresAt = Ingredient.day(offset: 1)
        short.openedAt = Date()
        #expect(short.effectiveDaysLeft <= 1)
        // 비밀봉 항목은 확인 대상이 아니다.
        let onion = Ingredient(name: "양파", category: "채소", daysLeft: 5,
                               quantity: Quantity(value: 1, unit: .piece), glyph: .onion,
                               boughtDaysAgo: 20)
        var o = onion
        o.canonicalID = "onion"
        #expect(!o.sealedCheckDue())
    }

    // MARK: 상호(구매처) 추출

    @Test func extractsStoreNameFromTopLine() {
        #expect(ReceiptParser.storeName(from: receipt) == "이마트 성수점")
    }

    @Test func storeNameNilWhenAbsent() {
        // 상단 몇 줄이 전부 날짜/소음/가격뿐 — 상호 후보가 없다.
        let lines = ["2026-07-02 21:11", "합계             19,400", "카드승인 12345678"]
        #expect(ReceiptParser.storeName(from: lines) == nil)
    }
}
