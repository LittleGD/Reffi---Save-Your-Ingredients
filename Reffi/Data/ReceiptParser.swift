import Foundation

/// 영수증 OCR 텍스트 → 재료 후보 — **순수 로직**(Vision 의존 없음, 유닛 테스트 대상).
/// 마트 영수증의 축약 상품명("서울우유1L", "삼겹살 500g")을 정본 재료 사전 매칭으로
/// canonical ID에 매핑하고, 합계/카드/전화번호 같은 소음 라인을 걸러낸다.
///
/// **매칭 실패 라인도 후보로 남긴다(44차)** — 예전엔 버렸는데, 그 물건은 실제로 산 물건이라
/// 확인 화면에 아예 안 뜨면 사용자가 직접 입력으로 다시 쳐야 한다. 대신 확실한 후보와 구분한다:
/// canonicalID nil + 상품명 꼴 게이트(아래 `looksLikeProduct`) + 상한 — 뷰가 기본 선택을 끄고
/// "사전에 없음" 배지를 달아, '확실한 후보만 기본 켬' 원칙은 그대로 산다.
enum ReceiptParser {

    struct Candidate: Identifiable {
        let id = UUID()
        var rawLine: String        // OCR 원문(확인 화면 참고용)
        var canonicalID: String?   // nil = 사전 미매칭(자유 표기로 등록 가능, 기본 미선택)
        var name: String           // 매칭 시 사전 대표 표기, 미매칭 시 정규화된 원문
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

    /// 미매칭 후보 상한 — 흐릿한 사진의 OCR 파편이 확인 리스트를 점령하지 않게. 매칭 후보는 무제한.
    static let unmatchedCap = 12

    /// OCR 라인들 → 재료 후보(매칭 후보는 canonical 기준, 미매칭 후보는 표기 기준 중복 제거,
    /// 등장 순서 유지). 매칭은 원문 → 영수증 정규화(접두 코드·가격 꼬리 제거) 2단으로 시도한다.
    static func candidates(from lines: [String],
                           lexicon: IngredientLexicon = .shared) -> [Candidate] {
        var seenIDs = Set<String>()
        var seenNames = Set<String>()
        var out: [Candidate] = []
        var unmatched = 0
        // 상호(구매처) 줄은 상품이 아니다 — 미매칭 후보 게이트가 상품명 꼴만 보면 "이마트 성수점"이
        // 첫 후보로 올라온다. 상호 판별은 storeName 한 곳의 규칙을 그대로 재사용하고(규칙 분열 금지),
        // **한 줄만** 건너뛴다 — 같은 문자열이 아래에 또 오면 그건 상호가 아니라 상품 줄이다.
        let store = storeName(from: lines, lexicon: lexicon)
        var storeSkipped = false
        for raw in lines {
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard line.count >= 2 else { continue }
            if !storeSkipped, line == store { storeSkipped = true; continue }
            let lower = line.lowercased()
            if noiseKeywords.contains(where: { lower.contains($0) }) { continue }
            // 숫자·기호뿐인 라인(가격·바코드·날짜) 제외.
            if line.allSatisfy({ $0.isNumber || $0.isPunctuation || $0.isWhitespace || $0.isSymbol }) {
                continue
            }
            let cleaned = normalizedProductLine(line)
            // 약어 전개본을 **먼저** 조회한다 — "GV ALMD MILK"를 원문부터 조회하면 포함 매칭이
            // ALMD를 못 읽은 채 MILK에 붙어, 전개가 도달하기 전에 오답(milk)이 확정된다.
            // 전개는 대문자 단독 토큰만 건드리므로 한글·소문자 라인에는 원문 조회와 동일하다.
            if let id = lexicon.canonicalID(for: expandedAbbreviations(cleaned))
                ?? lexicon.canonicalID(for: line) ?? lexicon.canonicalID(for: cleaned) {
                // 중복 제거는 **정규화 표기** 기준(45차) — 캐논 기준으로 지우면 같은 캐논으로
                // 떨어지는 서로 다른 상품(서울우유 1L + 저지방우유 900ml)의 두 번째 줄이
                // 확인 화면에서 통째로 사라진다. 산 물건을 화면에서 지우면 안 된다.
                // 같은 캐논의 두 번째 상품은 이름을 원문(정규화)으로 남겨 행이 구분되게 한다.
                guard seenNames.insert(cleaned.lowercased()).inserted else { continue }
                let headword = seenIDs.insert(id).inserted
                out.append(Candidate(rawLine: line,
                                     canonicalID: id,
                                     name: headword ? (lexicon.entry(id: id)?.displayName ?? cleaned)
                                                    : cleaned,
                                     quantity: extractQuantity(from: lower)))
            } else {
                // 사전 미매칭 — 상품명 꼴일 때만, 정규화 표기로 담는다(가격·코드 꼬리를 뗀 이름이
                // 그대로 재고 이름이 된다). 등록되면 자유 표기 재고다(캐논 없음 = 안전한 실패).
                guard unmatched < unmatchedCap, looksLikeProduct(cleaned),
                      seenNames.insert(cleaned.lowercased()).inserted else { continue }
                unmatched += 1
                out.append(Candidate(rawLine: line,
                                     canonicalID: nil,
                                     name: cleaned,
                                     quantity: extractQuantity(from: lower)))
            }
        }
        return out
    }

    /// 영수증 상품명 정규화 — 매칭을 막는 장식만 뗀다(공격적 변형 금지, 원문은 rawLine에 남는다).
    /// 규칙과 순서는 44차 실측 리서치(CU·GS25·이마트24 상품 마스터 + 국세청 면세 표기) 근거다:
    /// ① 묶음 곱셈 꼬리("2L*6") — 면세 별표(*)보다 **먼저** 소비해야 한다(같은 기호의 두 의미).
    /// ② 앞의 면세 별표·행사 코드("1+1 ") — "\d+\d" 꼴만: "한우 1+등급"의 1+는 등급이라 건드리면
    ///    정육 라인이 파괴된다(숫자+숫자 요구가 그 함정을 구조적으로 피한다).
    /// ③ 접두 코드 "농심)"·"미트)"·"7P)" — 편의점 POS 관행(1~6자 + 짝 없는 닫는 괄호).
    /// ④ 대괄호 짧은 코드("[냉장]") ⑤ 카테고리 꼬리("…/돼지고기") ⑥ 가격 꼬리 ⑦ 공백 정리.
    static func normalizedProductLine(_ line: String) -> String {
        var s = line
        for pattern in [#"\s*[*xX×]\s*\d+\s*$"#,
                        #"^\*+\s*"#, #"^\d\+\d\s+"#, #"^행사\s+"#,
                        #"^[^\s()\[\]]{1,6}\)\s*"#, #"\[[^\]]{1,6}\]"#,
                        #"\s*/\s*(?:돼지고기|소고기|닭고기|수산물?|채소|과일)\s*$"#,
                        #"\s+[\d,]{3,}원?$"#] {
            s = s.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }
        return s.split(separator: " ", omittingEmptySubsequences: true).joined(separator: " ")
    }

    /// 미국 영수증 약어 전개(44차) — 실물 영수증(Walmart·Costco·TJ's)과 CA WIC 품목파일 8,048행에서
    /// **실측 확인된 high-confidence 토큰만** 싣는다. 2차 블로그발 추정(MLK·CHZ·BF)은 넣지 않는다 —
    /// BF는 실측 0건에 breakfast·buffalo와 충돌하고, GRN은 같은 영수증에서 green과 grain 두 뜻으로
    /// 쓰였다(둘 다 제외). 대문자 단독 토큰일 때만 전개한다(소문자 일반 단어 오폭 방지).
    static let receiptTokenExpansion: [String: String] = [
        "BRST": "breast", "CKN": "chicken", "CHED": "cheddar", "CRM": "cream",
        "TOM": "tomato", "ALMD": "almond", "SAUS": "sausage", "BROC": "broccoli",
        "HNY": "honey", "CHOC": "chocolate", "GRK": "greek", "SWT": "sweet",
        "CNUT": "coconut", "PNUT": "peanut", "OJ": "orange juice",
        // 수식·브랜드·단위 — 의미가 아니라 소음이라 전개 대신 제거한다.
        "ORG": "", "FZN": "", "BNLS": "", "DK": "", "W/": "",
        "GV": "", "KS": "", "TJ'S": "",
        "OZ": "", "LB": "", "CT": "", "EA": "", "QT": "", "GAL": "",
    ]

    static func expandedAbbreviations(_ s: String) -> String {
        s.split(separator: " ").map { token -> String in
            guard token == token.uppercased() else { return String(token) }
            return receiptTokenExpansion[String(token)] ?? String(token)
        }
        .filter { !$0.isEmpty }
        .joined(separator: " ")
    }

    /// 상품명 꼴 판정 — 미매칭 라인이 후보가 되기 위한 최소 요건. OCR 파편("ㅁ1ㅐ", "x2")과
    /// 실제 상품명("코카콜라 1.5L")을 가른다: 한글 음절 2+ 또는 연속 영문 3+, 길이 2~30,
    /// 글자 수가 숫자 수보다 많아야 한다(가격 조각 배제).
    static func looksLikeProduct(_ s: String) -> Bool {
        guard (2...30).contains(s.count) else { return false }
        let hangul = s.unicodeScalars.filter { (0xAC00...0xD7A3).contains($0.value) }.count
        var asciiRun = 0, maxRun = 0
        for ch in s {
            if ch.isLetter && ch.isASCII { asciiRun += 1; maxRun = max(maxRun, asciiRun) }
            else { asciiRun = 0 }
        }
        guard hangul >= 2 || maxRun >= 3 else { return false }
        let letters = s.filter(\.isLetter).count
        let digits = s.filter(\.isNumber).count
        return letters > digits
    }

    /// 라인에서 수량 추출 — "500g", "1L", "2개", "3 ea" 패턴. 가격("2,500")은 단위가 없어 안 잡힌다.
    static func extractQuantity(from line: String) -> Quantity {
        let pattern = #"([0-9]+(?:\.[0-9]+)?)\s*(kg|g|ml|l|개|ea|팩|병|봉)"#
        guard let match = line.range(of: pattern, options: .regularExpression) else {
            return Quantity(value: 1, unit: .piece)
        }
        return Quantity.parseLegacy(String(line[match]))
    }

    /// 상호(구매처) 추출 — **순수 함수**. 영수증 최상단 몇 줄 중, 소음 라인·날짜 라인·가격/숫자뿐인 라인·
    /// 재료 사전에 매칭되는 라인(=상품명이지 상호가 아님)을 제외한 첫 텍스트 라인을 상호 후보로 본다.
    /// 길이 2~20자 — 너무 짧은 토막(단위 등)이나 긴 안내문은 상호가 아닐 확률이 높아 배제.
    static func storeName(from lines: [String], lexicon: IngredientLexicon = .shared) -> String? {
        for raw in lines.prefix(5) {
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard (2...20).contains(line.count) else { continue }
            let lower = line.lowercased()
            if noiseKeywords.contains(where: { lower.contains($0) }) { continue }
            // 숫자·기호뿐인 라인(가격·바코드) 제외.
            if line.allSatisfy({ $0.isNumber || $0.isPunctuation || $0.isWhitespace || $0.isSymbol }) {
                continue
            }
            // 날짜/시각 라인("2026-07-02 21:11") 제외.
            if line.range(of: #"^\d{4}[-./]\d{1,2}[-./]\d{1,2}"#, options: .regularExpression) != nil {
                continue
            }
            // 재료 사전에 매칭되는 라인은 상품명 — 상호 후보에서 제외. 후보 생성과 **같은 눈**으로
            // 본다(정규화·약어 전개 포함) — 아니면 "BNLS CKN BRST"가 상품인 줄 모르고 상호가 된다.
            if lexicon.canonicalID(for: line) != nil
                || lexicon.canonicalID(for: expandedAbbreviations(normalizedProductLine(line))) != nil {
                continue
            }
            return line
        }
        return nil
    }
}
