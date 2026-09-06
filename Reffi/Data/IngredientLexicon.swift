import Foundation

/// 정본 재료 사전 — 재료명 지식의 **단일 소스**. 글리프·카테고리·동의어(영/한)·상비 여부·
/// 보관별 기본 소비기한이 전부 여기(번들 `ingredient-lexicon.json`) 한 곳에서 나온다.
/// 글리프 매칭(`FoodGlyph.match`)·추천 매칭(`RecipeRecommender`)·등록 폼의 스마트 기본값·
/// 자동완성이 모두 이 사전을 소비한다 — 새 재료 지식은 코드가 아니라 JSON에 추가한다.
struct IngredientLexicon {

    struct Entry: Decodable {
        var id: String                 // canonical ID ("green-onion")
        var names: Names
        var glyph: String              // FoodGlyph rawValue
        var staple: Bool
        var shelfLife: ShelfLife
        /// 동물성 재료인데 글리프가 Meat/Seafood 계열이 아닌 항목(스팸=can, 액젓·굴소스·쯔유=
        /// sauceBottle)용 명시 플래그 — 채식 하드 필터가 글리프만 보면 이들이 통과한다.
        /// 생략(nil) = 글리프 판정에 맡긴다. 지식은 코드가 아니라 JSON에 둔다(프로젝트 규칙).
        var animal: Bool?
        /// 상위(총칭) 캐논 — 구체 재료가 총칭을 요구하는 레시피를 **채울 수 있다**는 단방향 선언(44차).
        /// 팽이버섯은 "버섯" 레시피를 만들 수 있지만(parent: mushroom), 총칭 버섯이 표고 전용
        /// 레시피를 채우지는 못한다 — 방향이 뒤집히면 오매칭이 재고 파괴로 이어진다(발주=소비).
        /// 한 단계만 본다(체인 없음). 가향유(flavored-milk)처럼 총칭 레시피에 넣으면 다른 음식이
        /// 되는 변형에는 **일부러 달지 않는다**.
        var parent: String?
        /// 밀봉 가공식품(캔·병·레토르트) 플래그 — 개봉 전에는 장기, 개봉 후에는 `shelfLife.opened`가
        /// 기한이 된다(44차 오너 결정: 미개봉 방치 방지를 위해 2주 주기 개봉 확인을 묻는다).
        var sealed: Bool?
        /// 함유 알레르겐 원천(64차) — 이 가공품이 **담고 있는** 재료의 캐논 목록.
        /// `parent`와 다른 관계다. parent는 "이 재고가 저 레시피 줄을 채울 수 있다"는 대체
        /// 가능성이고, 여기는 "이 줄에는 저것이 들어 있다"는 함유 관계다. 땅콩버터는 땅콩의
        /// 하위 품목이 아니라 땅콩을 함유한 가공품이라, parent로 이으면 냉장고의 땅콩버터가
        /// "땅콩" 줄을 채워버린다(오매칭 = 발주 시 재고 파괴). 그래서 필드를 나눴고,
        /// **알레르기 하드 필터만** 이 간선을 읽는다(기피 감점·매칭·IDF는 읽지 않는다).
        /// 한계는 알려져 있다: 빵의 우유·계란처럼 제조사마다 갈리는 것은 싣지 않았고,
        /// 정제 대두유(cooking-oil)처럼 통상 알레르겐으로 보지 않는 것도 뺐다.
        var allergens: [String]?
        /// 대체 간선(45차, 일방향) — **이 재고가** `fills` 캐논을 요구하는 레시피 줄을 대신할 수 있다
        /// (생크림→우유). 요리 실무 표준 대체표(USU·King Arthur) 근거의 수작업 40간선. 체이닝 금지
        /// (1홉), parent와 조합 금지, 랭킹에서는 감점 — 정품 매칭보다 항상 뒤에 선다.
        /// `block`: 줄 텍스트에 이 토큰이 있으면 그 줄에는 이 간선을 쓰지 않는다(레몬 "웨지" 줄을
        /// 식초로 채우지 않는다 — 대체 안전성은 캐논이 아니라 줄 텍스트가 결정한다는 시드 실측).
        struct Sub: Decodable {
            var fills: String
            var block: [String]?
        }
        var subs: [Sub]?

        struct Names: Decodable {
            var en: [String]
            var ko: [String]
        }
        /// 보관 위치별 기본 소비기한(일). null = 해당 보관 부적합/무의미.
        struct ShelfLife: Decodable {
            var fridge: Int?
            var freezer: Int?
            var pantry: Int?
            var room: Int?
            /// **개봉 후** 냉장 소비기한(일) — `sealed` 항목 전용(44차). 개봉 전 값은 위 슬롯이
            /// 그대로 담당한다(스팸: pantry 1095 = 미개봉, opened 5 = 개봉 후).
            var opened: Int?
        }

        /// 로케일 대표 표기.
        ///
        /// JSON의 영문 표기는 **매칭용 소문자 캐논**이다(223개 전부 "onion"·"green onion" 꼴).
        /// 저장은 캐논으로, 표시만 다듬는다는 규칙대로 **표시 시점에** 단어 첫 글자를 올린다 —
        /// 안 그러면 To buy 그리드만 "onion"이고 냉장고·레시피는 "Onion"이라 한 화면 건너 표기가 갈린다.
        /// 한글은 대소문자 개념이 없어 그대로 둔다(`localizedCapitalized`는 한글에서 무동작이지만
        /// 의도를 분명히 하려고 분기를 유지한다).
        var displayName: String {
            if Recipe.isKorean, let ko = names.ko.first { return ko }
            guard let en = names.en.first else { return id }
            return en.localizedCapitalized
        }
    }

    static let shared = IngredientLexicon()

    let entries: [Entry]
    private let byID: [String: Entry]
    private let exactKeyword: [String: String]          // 정규화 표기 → id (한 글자 포함)
    /// 오타 허용 계층용 자모 분해 색인 — 정확 표기 전수의 (자모열, id). 로드 때 한 번 분해해 둔다:
    /// 퍼지 조회는 전 계층 미스에서만 돌지만, 그때마다 1,100여 표기를 다시 분해하면 미스가 비싸진다.
    private let fuzzyKeys: [(key: [Character], id: String)]
    private let containsKeywords: [(keyword: String, id: String)]  // 2글자+ — 길이 내림차순
    /// 타이핑 검색용 정규화 이름(en+ko) — `entries`와 같은 순서. 키 입력마다 사전 전체를
    /// 다시 정규화하지 않으려고 로드 때 한 번만 만든다(어차피 아래 키워드 색인이 같은 값을 훑는다).
    private let searchNames: [[String]]
    /// id → 그 항목의 정규화 표기 집합. `displayName(stored:canonicalID:)`의 가드가 읽는다 —
    /// 목록은 행마다 그 가드를 부르므로, 호출마다 표기 배열을 새로 만들어 정규화하면 스크롤에서 값이 나간다.
    private let normalizedNamesByID: [String: Set<String>]

    /// 사전 전체를 `FoodGlyph.categoryLabel`로 묶은 섹션 — 항목이 있는 카테고리만,
    /// `FoodGlyph.categoryOrder`(냉장고 필터 칩과 공유하는 단일 순서 상수)대로, 섹션 안은 표기 오름차순.
    /// 로드 때 한 번만 만든다: 그리드가 body 평가마다 223종을 다시 묶고 정렬하면 키 입력이 끊긴다.
    ///
    /// **UI 소비처 없음(2026-08, 30차)** — To buy 검색 시트가 빈 쿼리 상태에서 이 섹션 배열 대신
    /// `Frequent`만 보여주도록 단순화되면서 화면상의 유일한 소비처가 사라졌다. 그래도 이 프로퍼티와
    /// 아래 테스트(`LexiconTests.categorySections*`)는 그대로 둔다 — 모델 계약은 UI 사용 여부와 무관하게
    /// 유지한다는 저장소 선례(사전 전체를 카테고리로 묶어 노출하는 다른 화면이 생기면 바로 재사용 가능).
    let categorySections: [(category: String, entries: [Entry])]

    /// 수식 토큰(45차) — 재료 토큰 **바로 뒤**에 이 토큰이 오면 그 상품은 재료가 아니라 파생품이다
    /// ("onion powder"는 양파가 아니다). 지식은 코드가 아니라 JSON에 둔다(프로젝트 규칙).
    let modifierTokens: Set<String>

    init(bundle: Bundle = .main) {
        struct File: Decodable {
            var version: Int
            var entries: [Entry]
            var modifierTokens: [String]?
        }
        var loaded: [Entry] = []
        var modifiers: [String] = []
        if let url = bundle.url(forResource: "ingredient-lexicon", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let file = try? JSONDecoder().decode(File.self, from: data) {
            loaded = file.entries
            modifiers = file.modifierTokens ?? []
        }
        entries = loaded
        modifierTokens = Set(modifiers.map(Self.norm))
        byID = Dictionary(loaded.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })

        var exact: [String: String] = [:]
        var contains: [(String, String)] = []
        var names: [[String]] = []
        var normalizedByID: [String: Set<String>] = [:]
        for e in loaded {
            let displayNames = (e.names.en + e.names.ko).map(Self.norm).filter { !$0.isEmpty }
            names.append(displayNames)
            // 같은 id가 두 번 실렸으면 앞선 항목이 이긴다(byID와 같은 규칙 — 가드와 조회가 갈리면 안 된다).
            if normalizedByID[e.id] == nil { normalizedByID[e.id] = Set(displayNames) }
            var keywords = e.names.en + e.names.ko
            keywords.append(e.id.replacingOccurrences(of: "-", with: " "))
            for raw in keywords {
                let k = Self.norm(raw)
                guard !k.isEmpty else { continue }
                if exact[k] == nil { exact[k] = e.id }
                // 한 글자 표기("배"·"무"·"파")는 정확 일치만 — 포함 매칭에서 제외해 오분류를 막는다.
                if k.count > 1 { contains.append((k, e.id)) }
            }
        }
        searchNames = names
        normalizedNamesByID = normalizedByID
        exactKeyword = exact
        // 퍼지 대상에서 **경합 표기**를 제외한다(44차 리서치: 서로 다른 재료끼리 문자 1획 차인
        // 실표기 쌍이 342건 — 오이/오리, 새우/생수, beef/beet). 다른 id의 표기와 자모 거리 1 이내인
        // 표기는 오타 교정의 목적지가 될 수 없다 — 그 지대에서는 한 획 차이가 오타가 아니라
        // 다른 재료다. 로드 때 한 번 전산으로 걸러 두면 런타임 규칙이 데이터를 따라 자란다.
        let decomposed = exact.filter { Self.fuzzyEligible($0.key) }
            .map { (key: Self.typoKey($0.key), id: $0.value) }
        var byLen: [Int: [(key: [Character], id: String)]] = [:]
        for e in decomposed { byLen[e.key.count, default: []].append(e) }
        fuzzyKeys = decomposed.filter { e in
            for len in (e.key.count - 1)...(e.key.count + 1) {
                for other in byLen[len] ?? [] where other.id != e.id {
                    if Self.withinOneEdit(e.key, other.key) { return false }
                }
            }
            return true
        }
        // 긴 키워드 우선("green onion"이 "onion"보다 먼저) — 포함 매칭의 특이도 보장.
        // 길이 동률은 **등재 순서**를 명시적 2차 키로 고정한다. 동률 승자에 실제 판정이 걸려 있는데
        // ("초코우유"의 우유 vs 초코 — 둘 다 2글자), Swift `sorted(by:)`는 안정 정렬을 보장하지
        // 않으므로 등재 순서 유지를 stdlib 구현의 우연에 맡기지 않고 계약으로 승격한다.
        containsKeywords = contains.enumerated()
            .sorted { a, b in
                if a.element.0.count != b.element.0.count { return a.element.0.count > b.element.0.count }
                return a.offset < b.offset
            }
            .map(\.element)

        // 카테고리 버킷 — 글리프가 곧 카테고리다(사전에 카테고리 필드를 새로 만들지 않는다).
        var buckets: [String: [Entry]] = [:]
        for e in loaded {
            let glyph = FoodGlyph(rawValue: e.glyph) ?? .generic
            buckets[glyph.categoryLabel, default: []].append(e)
        }
        categorySections = FoodGlyph.categoryOrder.compactMap { category in
            guard let items = buckets[category], !items.isEmpty else { return nil }
            return (category, items.sorted {
                $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending
            })
        }
    }

    static func norm(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    // MARK: - 조회

    /// 매칭 결과 캐시 — 포함 매칭 미스는 키워드 1,200여 개 전수 스캔이라, 추천 랭킹·자동완성이
    /// 같은 이름을 반복 조회할 때 비용이 쌓인다. NSCache는 스레드 안전(영수증 OCR 백그라운드 포함).
    private let matchCache = NSCache<NSString, NSString>()
    /// 머리말 일치 전용 캐시 — `headNounCanonicalID`는 추천 랭킹의 상비 판정(`isStaple`)이
    /// no-ref 레시피 줄마다 부르는데, 미스가 곧 키워드 전수 접미사 검사라 캐시 없이는
    /// 커스텀 레시피가 늘수록 rank 1회 비용이 선형으로 커진다.
    private let headNounCache = NSCache<NSString, NSString>()
    private static let cacheMiss = "\u{1}"

    /// 자유 표기 → canonical ID. ① 정확 일치 ② 머리말 일치 ③ **토큰 매칭** ④ 오타 허용.
    ///
    /// ②가 ③보다 먼저다 — 한국어·영어 복합명사는 **뒤가 머리**라, 앞에서 걸리는 키워드는 대개
    /// 재료가 아니라 수식어다(실측: 무제한 포함 매칭 시절 "딸기우유"가 strawberry에, "고추참치"가
    /// chili-pepper에 붙었다). 캐논 오귀속은 표시 오류가 아니라 데이터 파괴다 — 장보기 줄이 남의
    /// 캐논에 흡수돼 사라지고, 레시피 오매칭이 요리 완료 시 엉뚱한 재고를 삭제하며, 소비기한이
    /// 오탐 캐논 값(간장 730일 → 게장에)으로 오염된다.
    ///
    /// ③은 45차에 **경계 없는 포함 매칭에서 토큰 매칭으로 교체**됐다. 포함 매칭은 구조적으로 못
    /// 고치는 대문이었다 — "onion powder"→양파, "간장게장"→간장(730일), "cornstarch"→전분,
    /// "감자탕"→감자(전부 실행 확인). 토큰 규칙: 여러 단어 키워드는 연속 토큰열 일치(마지막
    /// 토큰만 +s/es 복수 허용 — "chicken breasts"가 부위를 잃고 chicken 총칭에 떨어지던 45차
    /// 검증 실측 125건의 마감), 한 단어
    /// 키워드는 토큰 전체 일치 또는 (한글 한정) 토큰 **끝** 일치("서울우유1L"의 서울우유 토큰).
    /// 토큰 **앞**에서 걸리는 합성어(간장게장·감자탕·새우깡)는 대개 완성요리·과자라 받지 않고,
    /// 재료 토큰 바로 뒤에 수식 토큰(가루·powder·오일…, 사전 `modifierTokens`)이 오면 강등한다.
    func canonicalID(for rawName: String) -> String? {
        let n = Self.norm(rawName)
        guard !n.isEmpty else { return nil }
        if let cached = matchCache.object(forKey: n as NSString) {
            let s = cached as String
            return s == Self.cacheMiss ? nil : s
        }
        let raw = exactKeyword[n]
            ?? headNounID(normalized: n)
            ?? tokenMatchID(normalized: n)
            ?? fuzzyCanonicalID(normalized: n)
        let result = raw.map { speciesGuarded($0, input: n) }
        matchCache.setObject((result ?? Self.cacheMiss) as NSString, forKey: n as NSString)
        return result
    }

    /// 표기 → 토큰열 — 유니코드 글자 연속만 토큰으로 남긴다(숫자·기호·공백이 경계).
    /// "서울우유1L" → [서울우유, l], "boneless skinless chicken breast 2.1LB" → [..., chicken, breast, lb].
    static func matchTokens(_ n: String) -> [String] {
        var out: [String] = []
        var cur = ""
        for ch in n {
            if ch.isLetter { cur.append(ch) }
            else if !cur.isEmpty { out.append(cur); cur = "" }
        }
        if !cur.isEmpty { out.append(cur) }
        return out
    }

    /// ③ 토큰 매칭 본체 — 키워드는 여전히 길이 내림차순(+등재순)이라 "chili powder"(재료)가
    /// chili(수식 강등 대상)보다 먼저 잡힌다. 수식 강등은 **한 단어 전체 일치**에만 적용한다 —
    /// 여러 단어 키워드는 수식어가 키워드의 일부이고, 한글 끝 일치는 수식어가 앞(안전한 방향)이다.
    private func tokenMatchID(normalized n: String) -> String? {
        let toks = Self.matchTokens(n)
        guard !toks.isEmpty else { return nil }
        for (keyword, id) in containsKeywords {
            if keyword.contains(" ") || keyword.contains("-") {
                // 키워드도 재고와 **같은 토크나이저**로 자른다 — split(" ")로 두면 "fresh-pressed
                // juice"의 하이픈 덩어리가 재고 토큰([fresh, pressed, juice])과 영원히 어긋난다.
                let kw = Self.matchTokens(keyword)
                guard !kw.isEmpty, kw.count <= toks.count else { continue }
                // 다단어도 **마지막 토큰만** 복수형을 받는다(영문 소매 라벨 최빈형: "chicken
                // breasts"·"pork chops"). 앞 토큰은 완전 일치 유지 — 앞이 굴절하는 표기는 없다.
                let last = kw[kw.count - 1]
                for start in 0...(toks.count - kw.count) {
                    guard toks[start..<(start + kw.count - 1)].elementsEqual(kw.dropLast()) else { continue }
                    let t = toks[start + kw.count - 1]
                    if t == last || t == last + "s" || t == last + "es" { return id }
                }
            } else {
                let hangul = keyword.unicodeScalars.contains { (0xAC00...0xD7A3).contains($0.value) }
                for (i, t) in toks.enumerated() {
                    if t == keyword || (!hangul && (t == keyword + "s" || t == keyword + "es")) {
                        // 재료 토큰 뒤에 수식 토큰이 붙으면 파생품이다("onion powder") — 이 키워드는
                        // 버리고 다음 후보를 계속 본다(다른 키워드가 정답일 수 있다).
                        if i + 1 < toks.count, modifierTokens.contains(toks[i + 1]) { break }
                        return id
                    }
                    // 한글 키워드는 토큰 **끝** 일치도 받는다(수량이 붙어 굳은 실표기: 서울우유1L).
                    // 토큰 앞 일치는 받지 않는다 — 간장게장·감자탕·새우깡은 재료가 아니다.
                    if hangul, t.count > keyword.count, t.hasSuffix(keyword) {
                        if i + 1 < toks.count, modifierTokens.contains(toks[i + 1]) { break }
                        return id
                    }
                }
            }
        }
        return nil
    }

    /// 정육 부위의 **종 토큰 가드**(44차 리서치 요구사항) — 부위명은 접두 관행으로 종이 갈리는데
    /// ("등심"=소, "돼지등심"=돼지), 등재 안 된 조합("돼지고기 등심")은 머리말이 부위(소 기본값)를
    /// 잡아 종이 뒤집힌다. 해석 결과가 부위(parent가 정육 총칭)인데 입력에 **다른 종**의 토큰이
    /// 있으면 그 종의 총칭으로 강등한다 — 부위 정밀도는 잃지만 종은 절대 틀리지 않는다
    /// (발주=재고 소비: 돼지 등심이 소 재고를 지우면 안 된다).
    private static let speciesTokens: [(species: String, tokens: [String])] = [
        ("beef", ["한우", "육우", "소고기", "쇠고기", "비프", "beef"]),
        ("pork", ["돼지", "한돈", "포크", "돈까스", "돈가스", "pork"]),
        ("chicken", ["닭", "치킨", "chicken"]),
        ("duck", ["오리", "duck"]),
        ("lamb", ["양고기", "양갈비", "램", "lamb", "mutton"]),
    ]

    private func speciesGuarded(_ id: String, input n: String) -> String {
        // 가드 대상: 부위(parent가 정육 종) **또는 종 총칭 자체**(44차 검증 보강) — "돼지 불고기용"이
        // 용도명 매칭으로 beef에 떨어질 때도 종 토큰이 판정을 뒤집어야 한다.
        let parent = byID[id]?.parent
            ?? (Self.speciesTokens.contains { $0.species == id } ? id : nil)
        guard let parent, Self.speciesTokens.contains(where: { $0.species == parent }) else { return id }
        for (species, tokens) in Self.speciesTokens where species != parent {
            if tokens.contains(where: { n.contains($0) }) { return species }
        }
        return id
    }

    // MARK: - 오타 허용(퍼지) 계층 — 44차

    /// ④ 오타 허용 — 앞 세 계층이 전부 미스일 때만, **정확 표기 사전에 대해서만** 편집 거리 1을
    /// 받는다("양송기"→양송이, "tomatoe"→tomato). 발주=재고 소비라 공격적 교정은 금지 — 가드 셋:
    /// ① **한글 3음절/영문 5자 미만은 입력·목적지 모두 제외**(44차 검증에서 강화). 자모 수 게이트는
    ///   받침 하나면 2음절도 통과해(방어=자모 5), 사전 **밖** 실존 재료가 흡수됐다 — 방어→장어,
    ///   냉이→팽이, 율무→열무, malt→salt 실측. 2음절 한글은 식재료 최소쌍의 지대라 통째로 뺀다.
    /// ② 거리 1 안에 **서로 다른 두 재료**가 다투면 교정하지 않는다(nil).
    /// ③ 부분문자열이 아니라 표기 전체끼리만 비교한다(포함 매칭에 퍼지를 얹으면 특이도가 무너진다).
    /// 비교 축은 여전히 **자모**다 — 음절 비교로는 "계/게"(1획)와 "계/닭"(전혀 다름)이 같은 거리다.
    private func fuzzyCanonicalID(normalized n: String) -> String? {
        guard Self.fuzzyEligible(n) else { return nil }
        let key = Self.typoKey(n)
        var found: String?
        for (k, id) in fuzzyKeys {
            guard abs(k.count - key.count) <= 1, Self.withinOneEdit(key, k) else { continue }
            if let f = found, f != id { return nil }   // 두 재료가 다투면 교정 포기(안전한 실패)
            found = id
        }
        return found
    }

    /// 퍼지 입력·목적지 공통 길이 게이트 — 한글 음절 3+ 또는 순수 비한글 5자+.
    static func fuzzyEligible(_ s: String) -> Bool {
        let syllables = s.unicodeScalars.filter { (0xAC00...0xD7A3).contains($0.value) }.count
        if syllables > 0 { return syllables >= 3 }
        return s.count >= 5
    }

    private static let choseong = Array("ㄱㄲㄴㄷㄸㄹㅁㅂㅃㅅㅆㅇㅈㅉㅊㅋㅌㅍㅎ")
    private static let jungseong = Array("ㅏㅐㅑㅒㅓㅔㅕㅖㅗㅘㅙㅚㅛㅜㅝㅞㅟㅠㅡㅢㅣ")
    private static let jongseong: [Character?] =
        [nil] + Array("ㄱㄲㄳㄴㄵㄶㄷㄹㄺㄻㄼㄽㄾㄿㅀㅁㅂㅄㅅㅆㅇㅈㅊㅋㅌㅍㅎ").map { Optional($0) }

    /// 오타 비교 키 — 한글 음절은 초/중/종 자모로 분해하고 그 외 문자는 그대로 잇는다.
    static func typoKey(_ s: String) -> [Character] {
        var out: [Character] = []
        for ch in s {
            guard ch.unicodeScalars.count == 1, let scalar = ch.unicodeScalars.first,
                  (0xAC00...0xD7A3).contains(scalar.value) else { out.append(ch); continue }
            let idx = Int(scalar.value - 0xAC00)
            out.append(Self.choseong[idx / 588])
            out.append(Self.jungseong[(idx % 588) / 28])
            if let jong = Self.jongseong[idx % 28] { out.append(jong) }
        }
        return out
    }

    /// 편집 거리 ≤ 1 판정(치환 1 또는 삽입/삭제 1) — 전체 DP 없이 한 번의 선형 스캔으로 끝낸다.
    static func withinOneEdit(_ a: [Character], _ b: [Character]) -> Bool {
        let (n, m) = (a.count, b.count)
        if abs(n - m) > 1 { return false }
        if n == m {
            var diff = 0
            for i in 0..<n where a[i] != b[i] { diff += 1; if diff > 1 { return false } }
            return true
        }
        let (long, short) = n > m ? (a, b) : (b, a)
        var i = 0, j = 0, skipped = false
        while i < long.count && j < short.count {
            if long[i] == short[j] { i += 1; j += 1 }
            else if skipped { return false }
            else { skipped = true; i += 1 }
        }
        return true
    }

    /// 정확 일치 전용 조회 — 서술형 텍스트(레시피 no-ref 라인)가 포함 매칭으로
    /// 엉뚱한 재료에 붙는 것을 막아야 하는 호출부용.
    func exactCanonicalID(for rawName: String) -> String? {
        exactKeyword[Self.norm(rawName)]
    }

    /// **머리말(head noun) 일치** — 표제어가 이름의 *끝*에 올 때만 채택하는 중간 강도 조회.
    ///
    /// `canonicalID`의 포함 매칭은 서술형 레시피 표기에서 절반쯤 틀린다. 한국어도 영어도 복합명사는
    /// **뒤가 머리**라서, 앞에 걸린 키워드는 대개 재료가 아니라 수식어이기 때문이다(시드 실측):
    /// | 표기 | 포함 매칭 | 머리말 일치 |
    /// |---|---|---|
    /// | `감자 전분` | potato ✗ | **starch** ✓ |
    /// | `chicken or vegetable stock` | chicken ✗ | **stock** ✓ |
    /// | `소고기 육수` | beef ✗ | **stock** ✓ |
    /// | `paprika powder` | bell-pepper ✗ | paprika-powder ✓ (41차 사전 등재 후 정확 일치) |
    /// | `파히타 시즈닝` | green-onion ✗ | chili-powder ✓ (41차 사전 등재 후 정확 일치) |
    /// | `minced garlic`·`볶은 통깨`·`cold water` | 정답 | 정답 유지 |
    ///
    /// 시드 no-ref 라인 전수에서 **오귀속 0건**이고, 놓치는 것은 한국어의 형태 접미사
    /// (`병아리콩 통조림`·`바질 잎`)뿐이다 — 그건 nil로 떨어져 표기 그대로 담기므로 **안전한 실패**다.
    /// 잘못된 캐논은 그 품목을 남의 줄에 흡수시켜 목록에서 사라지게 하지만, 캐논 없음은 줄 하나가
    /// 재입고로 자동으로 안 내려갈 뿐이고 눈에 보인다.
    ///
    /// 영문 복수형(`toasted sesame seeds` → `sesame seed`)은 받아 준다. 경계는 공백이거나
    /// 비-ASCII(한글은 붙여 쓰므로)여야 한다 — 안 그러면 `stock`이 `livestock`에 걸린다.
    func headNounCanonicalID(for rawName: String) -> String? {
        let n = Self.norm(rawName)
        guard !n.isEmpty else { return nil }
        if let cached = headNounCache.object(forKey: n as NSString) {
            let s = cached as String
            return s == Self.cacheMiss ? nil : s
        }
        let result = exactKeyword[n] ?? headNounID(normalized: n)
        headNounCache.setObject((result ?? Self.cacheMiss) as NSString, forKey: n as NSString)
        return result
    }

    /// 머리말 스캔 본체 — `canonicalID`(②단계)와 `headNounCanonicalID`가 공유한다.
    /// 두 진입점이 스캔을 따로 들면 경계 규칙이 조용히 갈라진다.
    private func headNounID(normalized n: String) -> String? {
        for (keyword, id) in containsKeywords {
            for suffix in [keyword, keyword + "s", keyword + "es"] where n.hasSuffix(suffix) {
                let boundary = n.index(n.endIndex, offsetBy: -suffix.count)
                // 문자열 **전체**가 표제어(+s/es)면 그대로 채택 — 맨 표제어는 ①정확 일치가 먼저
                // 잡으므로 여기 닿는 전체 일치는 복수형뿐이다("green onions"·"bell peppers").
                // 45차 검증에서 이 가드가 continue였던 탓에 다단어 복수형이 ②③ 모두 새어
                // 단어 키워드(onion·pepper)에 오귀속됐다 — 표기 125건 실측.
                guard boundary > n.startIndex else { return id }
                let prev = n[n.index(before: boundary)]
                if prev == " " || !prev.isASCII { return id }
            }
        }
        return nil
    }

    /// 타이핑 검색 — 이름(en/ko)이 쿼리로 **시작**하는 항목이 먼저, 그 다음 포함하는 항목.
    /// `canonicalID`(단건 정규화)와 목적이 다르다: 여기선 후보 **목록**을 만든다.
    /// - 한 글자 쿼리는 prefix만 본다 — "무"·"배" 같은 한 글자가 아무 이름 안쪽에나 걸리면 목록이 무의미해진다
    ///   (색인이 한 글자 표기를 포함 매칭에서 빼는 것과 같은 이유).
    /// - 정렬: prefix 적중 > 짧은 이름(쿼리를 더 꽉 채운 이름) > 표시 이름의 로케일 알파벳순(`categorySections`와
    ///   같은 `localizedStandardCompare`) > id(그래도 완전히 같으면 — 동의어 등 — 결정성을 지킨다).
    ///   내부 캐논 id(항상 영문 슬러그)로 동률을 가르면 한국어 로케일에서 사용자가 보는 순서와 어긋난다
    ///   (예: "고기" 검색의 동률 집합 소고기·닭고기·양고기는 id순 beef·chicken·lamb이 아니라 표시 이름
    ///   가나다순 닭고기·소고기·양고기여야 한다 — `LexiconRecommenderTests` 30차 회귀 고정).
    /// - 초성 검색은 범위 밖(자모 분해 유틸이 앱에 없다).
    func search(query: String, limit: Int = 20) -> [Entry] {
        let q = Self.norm(query)
        guard !q.isEmpty else { return [] }
        let prefixOnly = q.count < 2
        var hits: [(index: Int, rank: Int, length: Int)] = []
        for (index, names) in searchNames.enumerated() {
            var best: (rank: Int, length: Int)?
            for n in names {
                let rank: Int
                if n.hasPrefix(q) { rank = 0 }
                else if !prefixOnly, n.contains(q) { rank = 1 }
                else { continue }
                if let b = best, (b.rank, b.length) <= (rank, n.count) { continue }
                best = (rank, n.count)
            }
            if let best { hits.append((index, best.rank, best.length)) }
        }
        return hits
            .sorted {
                if $0.rank != $1.rank { return $0.rank < $1.rank }
                if $0.length != $1.length { return $0.length < $1.length }
                let (a, b) = (entries[$0.index], entries[$1.index])
                let byDisplayName = a.displayName.localizedStandardCompare(b.displayName)
                if byDisplayName != .orderedSame { return byDisplayName == .orderedAscending }
                return a.id < b.id   // 표시 이름까지 같으면(동의어 등) id로 완전 결정성을 지킨다.
            }
            .prefix(limit)
            .map { entries[$0.index] }
    }

    func entry(id: String) -> Entry? { byID[id] }
    func entry(for name: String) -> Entry? { canonicalID(for: name).flatMap { byID[$0] } }

    // MARK: - 표시 이름 (앱 전역 단일 정책)

    /// 저장 표기 + 캐논 ID → **화면에 그릴 이름**. 앱의 모든 표면이 이 한 곳을 거친다
    /// (`Ingredient.displayName`·`RemovalLog.displayName`·`FridgeStore.displayName(for:)` →
    /// 재고 카드·뱃지·알림·History 타임라인·To buy 제안·FREQUENT 칩).
    ///
    /// **정책(가드형): 사용자가 적은 표기는 데이터다 — 사전이 아는 말일 때만 사전이 말한다.**
    ///
    /// 두 요구가 정면으로 부딪힌다.
    /// - 저장 `name`은 담던 **순간의 표기**라 로케일이 박제된다: 한국어 기기에서 사전 타일로 담은
    ///   "양파"는 앱 언어를 영어로 바꿔도 "양파"로 남아, 크롬만 영어인 반쪽 화면이 된다.
    /// - 그런데 캐논만 보고 무조건 덮으면 자유 입력이 사라진다: 영수증 줄 "서울우유1L"은 포함 매칭으로
    ///   캐논이 `milk`라, 사용자가 산 그 물건이 화면에서 "Milk"로 바뀌어 버린다.
    ///
    /// 그래서 **저장 표기가 사전 표제어(en/ko)와 실제로 일치할 때만** 지금 로케일의 표제어로 다시 푼다.
    /// 표제어를 골라 담은 대다수 경로(검색 그리드·영수증 캐논 매칭·샘플 시드)는 언어를 따라오고,
    /// 사용자가 직접 친 표기는 어느 화면에서도 원문 그대로 남는다. 판정을 이 한 함수로 모으는 이유는
    /// 표면마다 규칙이 갈렸던 전례 때문이다: 같은 이력 로그가 History에선 "Milk", To buy에선
    /// "서울우유1L"로 읽혔다. 한 품목은 어느 화면에서든 같은 이름으로 불려야 한다.
    ///
    /// 비교는 `norm`(트림 + 소문자)이라 영문 표시형("Onion")도 캐논("onion")과 같은 말로 본다.
    /// 마이그레이션은 필요 없다 — 저장 스키마는 그대로 두고 표시 시점에만 판정한다.
    func displayName(stored: String, canonicalID: String?) -> String {
        guard let id = canonicalID, let entry = byID[id],
              normalizedNamesByID[id]?.contains(Self.norm(stored)) == true else {
            return stored   // 사전 밖이거나 사용자 표기 — 그대로 둔다
        }
        return entry.displayName
    }

    func glyph(for name: String) -> FoodGlyph? {
        entry(for: name).flatMap { FoodGlyph(rawValue: $0.glyph) }
    }

    /// 상비재 여부 — canonical ID 또는 자유 표기 둘 다 받는다.
    func isStaple(_ nameOrID: String) -> Bool {
        if let e = byID[nameOrID] { return e.staple }
        return entry(for: nameOrID)?.staple ?? false
    }

    /// 총칭(상위) 캐논 — 한 단계만, 실존하는 id일 때만(44차 계층 매칭).
    /// 자기 참조·오타 parent는 nil로 접어 무한 루프·유령 매칭을 원천 차단한다.
    func parentID(of id: String) -> String? {
        guard let p = byID[id]?.parent, p != id, byID[p] != nil else { return nil }
        return p
    }

    /// 밀봉 가공식품 여부(44차 개봉 라이프사이클) — 캐논 ID 기준.
    func isSealed(id: String) -> Bool { byID[id]?.sealed ?? false }

    /// **개봉 후** 냉장 소비기한(일) — sealed 항목 전용. 없으면 nil(개봉 추적 대상 아님).
    func openedShelfLifeDays(id: String) -> Int? { byID[id]?.shelfLife.opened }

    /// 대체 간선(45차) — 이 재고 캐논이 대신할 수 있는 레시피 줄 캐논들. 방향은 재고→줄 하나뿐이다.
    func substitutions(of stockID: String) -> [Entry.Sub] { byID[stockID]?.subs ?? [] }

    /// 항목의 정규화 표기 전수(en+ko) — 대체의 제목 가드가 "레시피 이름이 그 재료를 부르는가"를
    /// 판정할 때 쓴다(된장찌개의 된장 줄은 미소로 채우지 않는다).
    func normalizedNames(of id: String) -> Set<String> { normalizedNamesByID[id] ?? [] }

    /// 보관 위치별 기본 소비기한(일). 해당 보관에 값이 없으면 냉장 → 실온보관 → 실온 순으로 폴백.
    /// 냉장 하나만 폴백하면 fridge=null인 건조·상온 식품(소금·파스타 등)이 사전에 pantry 값을
    /// 갖고 있는데도 nil로 떨어져, 영수증 등록 경로의 D+3 최후 폴백이 "3일 뒤 임박"을 만들어 낸다.
    func shelfLifeDays(for name: String, storage: StorageLocation) -> Int? {
        guard let life = entry(for: name)?.shelfLife else { return nil }
        let days: Int? = switch storage {
        case .fridge: life.fridge
        case .freezer: life.freezer
        case .pantry: life.pantry
        case .room: life.room
        }
        return days ?? life.fridge ?? life.pantry ?? life.room
    }

    /// 등록 폼의 스마트 기본 소비기한 — 사전에 없는 재료는 nil(호출부가 D+3 폴백).
    func defaultExpiry(for name: String, storage: StorageLocation, from now: Date = Date()) -> Date? {
        shelfLifeDays(for: name, storage: storage).map { Ingredient.day(offset: $0, from: now) }
    }
}
