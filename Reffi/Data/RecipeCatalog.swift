import Foundation

/// 번들 시드 레시피 로더 — `recipes-seed.json`(영-한 이중언어, 다국적)을 읽는다.
/// 레시피 하드코딩 금지(프로젝트 규칙): 코드에는 로더만 있고 데이터는 전부 번들 JSON에.
enum RecipeCatalog {
    private struct File: Decodable {
        var version: Int
        var recipes: [Recipe]
    }

    static func loadSeed(bundle: Bundle = .main) -> [Recipe] {
        guard let url = bundle.url(forResource: "recipes-seed", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(File.self, from: data) else { return [] }
        return file.recipes
    }

    // MARK: - 시드 공출현(48차 E5 — 빈 덱 초대의 파트너 선정 근거)

    /// 두 캐논이 **같은 시드 레시피의 비상비 줄**에 함께 등장한 횟수. 대칭이고, 미관측 쌍은 0.
    ///
    /// 0은 "나쁜 궁합"의 증거가 아니다 — 128편 코퍼스에서 공출현 부재는 기대값 그 자체다
    /// (음성 증거 무정보). 그래서 소비자는 이 값을 **소프트 선호로만** 쓴다(최대값 파트너 선택,
    /// 0이면 폴백) — 하드 필터로 쓰는 순간 "같이 요리된 적 없음"이 "같이 못 쓴다"로 승격된다.
    /// 같은 캐논끼리는 0 — 자기 공출현은 "함께"의 의미가 없다.
    static func cooccurrence(_ a: String, _ b: String) -> Int {
        guard a != b else { return 0 }
        let key = a < b ? "\(a)\u{1F}\(b)" : "\(b)\u{1F}\(a)"
        return cooccurrenceTable[key] ?? 0
    }

    /// 시드 1패스 희소 사전(관측 쌍만, 수 KB) — `static let`이라 첫 조회 때 1회 구축·캐시된다
    /// (Swift의 정적 지연 초기화는 스레드 안전 — 수동 캐시 변수의 경합을 만들지 않는다).
    /// 키는 캐논 쌍의 사전순 결합 — 구분자 U+001F는 캐논 슬러그(소문자·하이픈)에 못 나오는
    /// 문자라 "a-b"+"c" 대 "a"+"b-c" 류의 키 충돌이 없다.
    private static let cooccurrenceTable: [String: Int] = {
        var counts: [String: Int] = [:]
        for recipe in loadSeed() {
            var canons = Set<String>()
            for item in recipe.ingredients where !RecipeRecommender.isStaple(item) {
                if let id = RecipeRecommender.canonicalID(of: item) { canons.insert(id) }
            }
            let sorted = canons.sorted()
            for (i, a) in sorted.enumerated() {
                for b in sorted[(i + 1)...] {
                    counts["\(a)\u{1F}\(b)", default: 0] += 1
                }
            }
        }
        return counts
    }()
}
