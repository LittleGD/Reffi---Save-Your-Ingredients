import Foundation

/// 영수증 OCR 텍스트 → 재료 후보 — **순수 로직**(Vision 의존 없음, 유닛 테스트 대상).
/// 마트 영수증의 축약 상품명("서울우유1L", "삼겹살 500g")을 정본 재료 사전의 포함 매칭으로
/// canonical ID에 매핑하고, 합계/카드/전화번호 같은 소음 라인을 걸러낸다.
/// 매칭 실패 라인은 버린다 — 확인 화면에서 사용자가 고르는 건 '확실한 후보'만.
enum ReceiptParser {

    struct Candidate: Identifiable {
        let id = UUID()
        var rawLine: String        // OCR 원문(확인 화면 참고용)
        var canonicalID: String
        var name: String           // 사전 대표 표기(로케일)
        var quantity: Quantity     // 라인에서 추출(500g, 1L…), 실패 시 1개
    }

    /// 상품명이 아닌 영수증 상용구 — 포함되면 라인 전체를 버린다.
    static let noiseKeywords: [String] = [
        // ko
        "합계", "총액", "총 액", "부가세", "과세", "면세", "카드", "현금", "승인", "거스름",
        "포인트", "할인", "쿠폰", "봉투", "반품", "교환", "전화", "사업자", "대표", "주소",
        "감사합니다", "영수증", "결제", "잔액", "매장", "번호",
        // en
        "total", "subtotal", "tax", "cash", "card", "change", "approval", "thank",
        "receipt", "balance", "tel", "store no",
    ]

    /// OCR 라인들 → 재료 후보(canonical 기준 중복 제거, 등장 순서 유지).
    static func candidates(from lines: [String],
                           lexicon: IngredientLexicon = .shared) -> [Candidate] {
        var seen = Set<String>()
        var out: [Candidate] = []
        for raw in lines {
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard line.count >= 2 else { continue }
            let lower = line.lowercased()
            if noiseKeywords.contains(where: { lower.contains($0) }) { continue }
            // 숫자·기호뿐인 라인(가격·바코드·날짜) 제외.
            if line.allSatisfy({ $0.isNumber || $0.isPunctuation || $0.isWhitespace || $0.isSymbol }) {
                continue
            }
            guard let id = lexicon.canonicalID(for: line) else { continue }
            guard seen.insert(id).inserted else { continue }
            out.append(Candidate(rawLine: line,
                                 canonicalID: id,
                                 name: lexicon.entry(id: id)?.displayName ?? line,
                                 quantity: extractQuantity(from: lower)))
        }
        return out
    }

    /// 라인에서 수량 추출 — "500g", "1L", "2개", "3 ea" 패턴. 가격("2,500")은 단위가 없어 안 잡힌다.
    static func extractQuantity(from line: String) -> Quantity {
        let pattern = #"([0-9]+(?:\.[0-9]+)?)\s*(kg|g|ml|l|개|ea|팩|병|봉)"#
        guard let match = line.range(of: pattern, options: .regularExpression) else {
            return Quantity(value: 1, unit: .piece)
        }
        return Quantity.parseLegacy(String(line[match]))
    }
}
