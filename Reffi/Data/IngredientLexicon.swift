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
    private let containsKeywords: [(keyword: String, id: String)]  // 2글자+ — 길이 내림차순
    /// 타이핑 검색용 정규화 이름(en+ko) — `entries`와 같은 순서. 키 입력마다 사전 전체를
    /// 다시 정규화하지 않으려고 로드 때 한 번만 만든다(어차피 아래 키워드 색인이 같은 값을 훑는다).
    private let searchNames: [[String]]

    /// 사전 전체를 `FoodGlyph.categoryLabel`로 묶은 섹션 — 항목이 있는 카테고리만,
    /// `FoodGlyph.categoryOrder`(냉장고 필터 칩과 공유하는 단일 순서 상수)대로, 섹션 안은 표기 오름차순.
    /// To buy 검색 시트의 재료 배열이 소비한다.
    /// 로드 때 한 번만 만든다: 그리드가 body 평가마다 223종을 다시 묶고 정렬하면 키 입력이 끊긴다.
    let categorySections: [(category: String, entries: [Entry])]

    init(bundle: Bundle = .main) {
        struct File: Decodable { var version: Int; var entries: [Entry] }
        var loaded: [Entry] = []
        if let url = bundle.url(forResource: "ingredient-lexicon", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let file = try? JSONDecoder().decode(File.self, from: data) {
            loaded = file.entries
        }
        entries = loaded
        byID = Dictionary(loaded.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })

        var exact: [String: String] = [:]
        var contains: [(String, String)] = []
        var names: [[String]] = []
        for e in loaded {
            let displayNames = (e.names.en + e.names.ko).map(Self.norm).filter { !$0.isEmpty }
            names.append(displayNames)
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
        exactKeyword = exact
        // 긴 키워드 우선("green onion"이 "onion"보다 먼저) — 포함 매칭의 특이도 보장.
        containsKeywords = contains.sorted { $0.0.count > $1.0.count }

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
    private static let cacheMiss = "\u{1}"

    /// 자유 표기 → canonical ID. ① 정확 일치 ② 긴 키워드 우선 포함 매칭("서울우유1L" → milk).
    func canonicalID(for rawName: String) -> String? {
        let n = Self.norm(rawName)
        guard !n.isEmpty else { return nil }
        if let cached = matchCache.object(forKey: n as NSString) {
            let s = cached as String
            return s == Self.cacheMiss ? nil : s
        }
        let result: String?
        if let id = exactKeyword[n] {
            result = id
        } else {
            result = containsKeywords.first { n.contains($0.keyword) }?.id
        }
        matchCache.setObject((result ?? Self.cacheMiss) as NSString, forKey: n as NSString)
        return result
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
    /// | `paprika powder` | bell-pepper ✗ | nil ✓ |
    /// | `파히타 시즈닝` | green-onion ✗ | nil ✓ |
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
        if let id = exactKeyword[n] { return id }
        for (keyword, id) in containsKeywords {
            for suffix in [keyword, keyword + "s", keyword + "es"] where n.hasSuffix(suffix) {
                let boundary = n.index(n.endIndex, offsetBy: -suffix.count)
                guard boundary > n.startIndex else { continue }
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
    /// - 정렬: prefix 적중 > 짧은 이름(쿼리를 더 꽉 채운 이름) > id(동률에서도 순서가 흔들리지 않게).
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
                return entries[$0.index].id < entries[$1.index].id
            }
            .prefix(limit)
            .map { entries[$0.index] }
    }

    func entry(id: String) -> Entry? { byID[id] }
    func entry(for name: String) -> Entry? { canonicalID(for: name).flatMap { byID[$0] } }

    func glyph(for name: String) -> FoodGlyph? {
        entry(for: name).flatMap { FoodGlyph(rawValue: $0.glyph) }
    }

    /// 상비재 여부 — canonical ID 또는 자유 표기 둘 다 받는다.
    func isStaple(_ nameOrID: String) -> Bool {
        if let e = byID[nameOrID] { return e.staple }
        return entry(for: nameOrID)?.staple ?? false
    }

    /// 보관 위치별 기본 소비기한(일). 해당 보관에 값이 없으면 냉장값으로 폴백.
    func shelfLifeDays(for name: String, storage: StorageLocation) -> Int? {
        guard let life = entry(for: name)?.shelfLife else { return nil }
        let days: Int? = switch storage {
        case .fridge: life.fridge
        case .freezer: life.freezer
        case .pantry: life.pantry
        case .room: life.room
        }
        return days ?? life.fridge
    }

    /// 등록 폼의 스마트 기본 소비기한 — 사전에 없는 재료는 nil(호출부가 D+3 폴백).
    func defaultExpiry(for name: String, storage: StorageLocation, from now: Date = Date()) -> Date? {
        shelfLifeDays(for: name, storage: storage).map { Ingredient.day(offset: $0, from: now) }
    }
}
