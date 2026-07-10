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

    @Test func dedupesByCanonicalID() {
        let lines = ["서울우유 1L", "저지방우유 500ml", "우유"]
        let found = ReceiptParser.candidates(from: lines)
        #expect(found.filter { $0.canonicalID == "milk" }.count == 1)
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
