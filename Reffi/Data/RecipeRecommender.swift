import Foundation

/// 레시피 추천 — "지금 가장 빠르게 소비해야 하는 재료들을 가장 많이 쓰는" 레시피를 점수순으로.
/// 임박할수록 큰 가중치(urgent3/soon2/fresh1). 스와이프 덱은 이 순서대로 위→아래.
///
/// 매칭은 정본 재료 사전(`IngredientLexicon`)의 **canonical ID 동일성**이 원칙이다 —
/// 양방향 부분문자열 비교(Green onion↔Onion, Pineapple↔Apple 오탐)는 쓰지 않는다.
/// 발주가 곧 재고 소비이므로 매칭 오탐은 데이터 파괴다.
enum RecipeRecommender {

    struct Result: Identifiable {
        let id: String               // = recipe.id (안정적 정체성)
        var recipe: Recipe
        var used: [Ingredient]       // 보유 재료 중 이 레시피가 쓰는 것(임박 순, 대체 투입분 포함)
        var total: Int               // 비-상비 재료 수(매치 분모)
        /// 대체로 채워진 줄(45차) — (부족했던 줄, 투입되는 재고). 그 재고는 `used`에도 들어가
        /// 발주 시 정상 예약·소비된다(대체로 요리하면 그 재료가 실제로 없어진다). 랭킹에서는
        /// 줄당 `substitutionPenalty` 감점 — 정품 매칭 티켓이 항상 앞선다.
        var substituted: [(item: Recipe.Item, with: Ingredient)] = []
        /// 비-상비 중 미보유 — **표시명이 아니라 레시피 항목 그대로** 들고 있는다.
        /// "Short:" 한 줄은 `displayName`만 있으면 되지만, 그 재료를 장보기 메모로 옮기려면
        /// `ref`(캐논 ID)가 필요하다. 표시명만 남기면 되돌릴 방법이 없다(`toBuyEntry(for:)` 참고).
        var missing: [Recipe.Item]
        var urgentUsedCount: Int     // 그중 오늘(urgent) 소진되는 수
    }

    /// 정규화 — 트림 + 소문자.
    private static func norm(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// 레시피 재료 한 줄의 canonical ID — ref 우선. ref 없는(no-ref) 표기는 **정확 일치**만
    /// 역조회한다 — "chicken or vegetable stock" 같은 서술형 라인이 포함 매칭으로 chicken에
    /// 오매핑되어 발주가 엉뚱한 재고를 소비하는 것을 막는다(포함 매칭은 재료명 쪽에만 허용).
    static func canonicalID(of item: Recipe.Item) -> String? {
        if let ref = item.ref { return ref }
        let lex = IngredientLexicon.shared
        return lex.exactCanonicalID(for: item.en) ?? item.ko.flatMap { lex.exactCanonicalID(for: $0) }
    }

    /// 부족 재료 한 줄 → 장보기 메모(`FridgeStore.addToBuy`) 페이로드. **표시명을 그대로 넘기면 안 된다** —
    /// 레시피 표기는 "pork (or beef)"·"gim (seaweed sheets)"처럼 괄호 주석을 달고 다니는데,
    /// store의 이름 역조회(`IngredientLexicon.canonicalID(for:)`)는 포함 매칭이라 괄호 **안** 단어에
    /// 먼저 걸린다(시드 실측: pork→beef, honey→corn-syrup, "water (or anchovy stock)"→anchovy).
    /// 그러면 장보기 메모가 엉뚱한 품목 키를 달고, 그 재료를 재입고할 때 이 줄이 안 지워진다.
    ///
    /// 그래서 해석을 **여기서 끝내** store에 넘긴다. 세 단계이고, 뒤로 갈수록 약하다:
    /// ① `canonicalID(of:)`(ref 우선, no-ref는 정확 일치만 — 이 파일의 매칭 규약 그대로).
    ///    장보기 목록은 "소고기 (얇게 썬 것)"이 아니라 "소고기"를 원하므로 사전 표제어·글리프까지 확정한다.
    /// ② 괄호 주석을 떼고 **머리말 일치**(`headNounCanonicalID`)를 한 번 더. 괄호는 조리 지시("얇게 썬 것")나
    ///    대체재("또는 멸치 육수")지 재료명이 아니라 떼는 편이 정확하고, 남은 표기의 **끝**에 표제어가 오면
    ///    그건 수식어가 아니라 진짜 재료다(`minced garlic` → garlic, `감자 전분` → starch).
    ///    포함 매칭을 쓰지 않는 이유가 여기 있다 — 앞에 걸리는 키워드는 대개 딴 재료다
    ///    (`paprika powder` → bell-pepper, `chicken or vegetable stock` → chicken).
    /// ③ 그래도 못 잡으면 캐논 없이 **표기 그대로** 담는다.
    ///
    /// **③은 store가 다시 추측하게 두지 않는다** — `FridgeStore.addToBuy(canonicalIsFinal:)`로 "해석
    /// 끝났다"를 알린다. 안 그러면 store가 그 이름으로 포함 매칭을 한 번 더 돌려, 이 함수가 방금
    /// 거부한 바로 그 오귀속을 되살린다. 그 결과는 단순한 오분류가 아니다: 잘못 붙은 캐논이 이미
    /// 목록에 있으면 그 품목은 **중복으로 취급돼 목록에 들어가지도 않는다**(시드 실측: 파프리카 가루가
    /// 파프리카 줄에 흡수돼 사라진다).
    ///
    /// **남는 한계**: ③으로 담긴 줄은 캐논이 없어 재입고가 자동으로 내려 주지 못한다(사용자가 직접
    /// 지운다). 잘못된 캐논으로 조용히 사라지는 것보다 눈에 보이는 실패라 이쪽을 택한다.
    static func toBuyEntry(for item: Recipe.Item) -> (name: String, canonicalID: String?, glyph: FoodGlyph) {
        let lex = IngredientLexicon.shared
        if let id = shoppingCanonicalID(of: item), let entry = lex.entry(id: id) {
            return (entry.displayName, id, FoodGlyph(rawValue: entry.glyph) ?? .generic)
        }
        let plain = withoutParentheticals(item.displayName)
        let name = plain.isEmpty ? item.displayName : plain
        return (name, nil, FoodGlyph.match(name))
    }

    /// 위 ①+②를 한 함수로 — `isStaple`도 **같은 눈**으로 읽게 하려고 뽑았다.
    ///
    /// 두 해석기가 갈리면 사전상 `staple: true`인 품목이 `missing`에 남았다가 장보기 메모로 넘어간다:
    /// `isStaple`이 정확 일치만 보던 시절 `water (or anchovy stock)`·`cold water`는 비-상비로 분류돼
    /// Short 줄에 뜨고, 담기에서는 `toBuyEntry`가 머리말로 `water`(상비재)를 찾아내 **목록에 "물"을 적었다**.
    /// `sweet soy sauce (kecap manis)`는 더 나빠서 케찹 마니스 자리에 `soy-sauce`가 적혔다.
    ///
    /// **머리말 일치는 `en`으로만 본다.** `displayName`으로 보면 기기 언어에 따라 다른 문자열이 들어가
    /// 같은 재료가 로케일마다 다른 캐논에 붙는다(실측: 시드 8줄이 갈렸고, `미소 된장`은 머리말이 `된장`이라
    /// 한국어 기기에서만 **미소 대신 된장**이 담겼다). 데이터는 영문 캐논으로 정규화하고 표시만
    /// 로컬라이즈한다는 규칙(CLAUDE.md)이 여기에도 그대로 적용된다 — 표기는 아래에서 사전 표제어로 푼다.
    static func shoppingCanonicalID(of item: Recipe.Item) -> String? {
        if let id = canonicalID(of: item) { return id }
        let plain = withoutParentheticals(item.en)
        return IngredientLexicon.shared.headNounCanonicalID(for: plain.isEmpty ? item.en : plain)
    }

    /// 괄호 주석 제거 + 공백 정리. 여는 괄호를 만나면 닫힐 때까지 버린다(중첩 없음 전제 — 시드 표기 실측).
    ///
    /// **괄호가 안 닫히면 원문을 그대로 돌려준다.** 시드는 짝이 맞지만(453/453) 이 함수는 사용자가 쓴
    /// 커스텀 레시피도 지나가는데, 오타로 `"Sauce (soy"`처럼 열기만 하면 뒤가 통째로 잘려
    /// `"Sauce"`가 된다 — 사용자가 적은 이름이 조용히 짧아지는 건 오히려 나쁜 실패다.
    /// 짝이 안 맞으면 "괄호 주석이 아니다"로 보고 손대지 않는 편이 안전하다.
    private static func withoutParentheticals(_ s: String) -> String {
        var out = ""
        var depth = 0
        for ch in s {
            if ch == "(" { depth += 1 }
            else if ch == ")" { depth = max(0, depth - 1) }
            else if depth == 0 { out.append(ch) }
        }
        guard depth == 0 else { return s }   // 안 닫힌 괄호 — 자르지 않고 원문 유지
        return out.split(separator: " ", omittingEmptySubsequences: true).joined(separator: " ")
    }

    /// 상비재 판별 — 사전의 staple 플래그가 정본.
    /// 해석은 `shoppingCanonicalID`와 **같은 눈**을 쓴다(ref → 정확 일치 → 영문 머리말).
    /// 담기 쪽만 머리말까지 보고 여기서 안 보면, `cold water`가 비-상비로 분류돼 Short 줄에 뜬 뒤
    /// 담을 때만 `water`(상비재)로 풀려 장보기 목록에 "물"이 적힌다.
    static func isStaple(_ item: Recipe.Item) -> Bool {
        if let id = shoppingCanonicalID(of: item) { return IngredientLexicon.shared.isStaple(id) }
        return false
    }

    /// 재료 ↔ 레시피 항목 매칭 — ① canonical ID 동일성(+총칭 한 단계) ② (사전 밖 커스텀 항목만)
    /// 정규화 정확 일치.
    ///
    /// **총칭 매칭은 단방향이다(44차)**: 구체 재고(팽이버섯)가 총칭을 요구하는 레시피(버섯)를
    /// 채울 수 있고, 그 반대는 안 된다 — 표고 전용 레시피에 총칭 버섯이 매칭되면 발주가 엉뚱한
    /// 재고를 소비한다. 어느 쌍이 총칭 관계인지는 사전의 `parent` 필드가 정본이다(지식은 JSON에).
    /// 레시피 줄이 받는 캐논 전부 — 1차 ref + 레시피가 명시한 대체(altRefs, 45차).
    static func itemKeys(of item: Recipe.Item) -> [String] {
        var keys: [String] = []
        if let primary = canonicalID(of: item) { keys.append(primary) }
        for alt in item.altRefs ?? [] where !keys.contains(alt) { keys.append(alt) }
        return keys
    }

    static func matches(_ ing: Ingredient, _ item: Recipe.Item) -> Bool {
        let ingName = norm(ing.name)
        guard !ingName.isEmpty else { return false }
        // 저장된 캐논 ID를 fast path로(해석 완료 재료) — nil이면 사전 조회(캐시)로 폴백.
        let ingID = ing.canonicalID ?? IngredientLexicon.shared.canonicalID(for: ing.name)
        let keys = itemKeys(of: item)
        if let a = ingID, !keys.isEmpty {
            if keys.contains(a) { return true }
            if let parent = IngredientLexicon.shared.parentID(of: a) { return keys.contains(parent) }
            return false
        }
        // 둘 중 하나라도 사전 밖(사용자 커스텀 표기) — 정확 일치만 허용, 부분문자열 금지.
        if ingName == norm(item.en) { return true }
        if let ko = item.ko, ingName == norm(ko) { return true }
        return false
    }

    static func weight(_ ing: Ingredient) -> Int {
        switch ing.freshness {
        case .urgent: 3
        case .soon:   2
        case .fresh:  1
        }
    }

    /// 랭킹에서 대체 줄 하나당 감점(45차) — 정품 매칭 티켓이 대체 티켓보다 항상 앞서게 하는 축.
    /// 크기는 freshness 한 단(1)과 같게 — 대체는 "가능"이지 "동급"이 아니다.
    static let substitutionPenalty = 1

    /// 대체 후보(45차) — 부족한 비상비 줄 하나를 대신할 재고 한 줄. 가드 셋:
    /// ① **제목 가드**: 레시피 이름이 그 재료를 부르면 잠근다 — 된장찌개의 된장 줄을 미소로 채우면
    ///    사용자가 즉시 알아채는 종류의 거짓이 된다. ② **줄 텍스트 차단**: 간선의 `block` 토큰이
    ///    줄에 있으면 건너뛴다(레몬 "웨지" 줄은 식초가 못 채운다 — 대체 안전성은 캐논이 아니라 줄
    ///    텍스트가 결정한다는 시드 실측). ③ **1홉**: 간선의 fills와 줄 키를 직접 비교만 —
    ///    parent 승격·대체 체이닝과 조합하지 않는다(허용하면 임의 재료가 임의 줄을 채우며 붕괴).
    /// stock은 임박순이라 첫 적격이 곧 최적(가장 임박한 대체재부터 소진).
    /// ④ **1재고 1줄**(45차 적대 검증): 이 레시피의 다른 줄이 이미 예약한 재고(`excluding`)는
    ///    대체 후보에서 뺀다 — 발주·완료가 재고 id 단위로 예약·삭제하므로, 한 알이 두 줄을 겸하면
    ///    missing이 거짓으로 줄어 "지금 만들 수 있다"가 된다(양파 1개가 onion 줄 정품 + green
    ///    onion 줄 대체를 겸하던 실측 15레시피).
    static func substitute(for item: Recipe.Item, in recipe: Recipe,
                           from stock: [Ingredient], excluding: Set<UUID> = []) -> Ingredient? {
        let lex = IngredientLexicon.shared
        let keys = Set(itemKeys(of: item))
        guard !keys.isEmpty else { return nil }
        let title = norm(recipe.name.en) + " " + norm(recipe.name.ko ?? "")
        for key in keys where lex.normalizedNames(of: key).contains(where: { title.contains($0) }) {
            return nil
        }
        let lineText = norm(item.en) + " " + norm(item.ko ?? "")
        for ing in stock where !excluding.contains(ing.id) {
            guard let canon = ing.canonicalID ?? lex.canonicalID(for: ing.name) else { continue }
            for sub in lex.substitutions(of: canon) where keys.contains(sub.fills) {
                if let blocks = sub.block,
                   blocks.contains(where: { lineText.contains(norm($0)) }) { continue }
                return ing
            }
        }
        return nil
    }

    /// `ingredients` = 티켓이 소비할 후보, `inventory` = 부족(missing) 판정 기준(전체 재고).
    /// inventory를 따로 주지 않으면 ingredients가 기준.
    /// 45차: 선택 줄(`optional`)은 부족을 만들지 않고, 부족 줄은 대체 그래프를 한 번 조회해
    /// 채워지면 `substituted`로 옮긴다 — 그 재고는 used에도 들어가 발주 시 실제로 소비된다.
    static func result(for recipe: Recipe, ingredients: [Ingredient],
                       inventory: [Ingredient]? = nil) -> Result {
        let nonStaple = recipe.ingredients.filter { !isStaple($0) }
        var used = ingredients.filter { ing in nonStaple.contains { matches(ing, $0) } }
        let stock = inventory ?? ingredients
        var missing: [Recipe.Item] = []
        var substituted: [(item: Recipe.Item, with: Ingredient)] = []
        var consumed = Set(used.map(\.id))   // 1재고 1줄 — 정품 매칭분 + 앞선 줄의 대체분
        for item in nonStaple where !stock.contains(where: { matches($0, item) }) {
            if item.isOptional { continue }
            if let sub = substitute(for: item, in: recipe, from: ingredients, excluding: consumed) {
                substituted.append((item, sub))
                consumed.insert(sub.id)
                if !used.contains(where: { $0.id == sub.id }) { used.append(sub) }
            } else {
                missing.append(item)
            }
        }
        used.sort { $0.effectiveDaysLeft < $1.effectiveDaysLeft }
        let urgent = used.filter { $0.freshness == .urgent }.count
        return Result(id: recipe.id, recipe: recipe, used: used, total: nonStaple.count,
                      substituted: substituted, missing: missing, urgentUsedCount: urgent)
    }

    /// 추천 제외 기준 — 부족 재료가 이 수 **이상**이면 덱에 올리지 않는다(2개는 통과, 3개는 탈락).
    /// 재료를 셋씩 사와야 하는 티켓은 "지금 냉장고를 비우는 요리"가 아니라 장보기 계획이다 —
    /// 이 앱의 덱은 **오늘 상해가는 재료를 쓰는 순서**이므로 그런 레시피는 애초에 후보가 아니다.
    /// 0~2개는 그대로 추천한다: 그 정도는 Short 줄이 알려 주고 To buy 원탭 알약이 처리한다(§13.5 ⑨).
    static let maxMissingForRecommendation = 3

    /// 위 기준의 **예외** — 부족이 많아도, 임박(urgent·soon) 재료를 이 덱에서 **혼자만** 다루는
    /// 티켓은 남긴다.
    ///
    /// 기준을 순위 계산 앞에 무조건 걸면 점수와 무관하게 후보가 지워진다. 앱 샘플 냉장고에서 실제로
    /// 최고점 두 장(비빔밥 8점·소고기 타코 7점)이 그렇게 빠졌는데, 둘 다 **재고를 4종씩 소진**하는
    /// 티켓이라 "장보기 계획"이라는 제외 근거가 성립하지 않았다. 더 나쁜 건 그때 D-1 시금치가 남는
    /// 어느 티켓에도 들어가지 않았다는 것이다 — 당시 커버리지 브리지(`uncoveredUrgent`)는 urgent만
    /// 호명해 soon 재료는 어디에서도 이름이 불리지 않았고(브리지 자체는 41차에 UI에서 빠졌다),
    /// 메인 배너만 "위험"이라고 압박한 채 화면 어디에도 행동 경로가 없었다.
    ///
    /// 그래서 정렬 **뒤에** 위에서부터 훑으며 거른다. 부족이 적으면 그냥 통과. 많으면 **두 조건을
    /// 모두** 만족할 때만 살린다:
    /// ① **채우는 것이 사는 것보다 적지 않다**(`clearedCount >= missing.count`) — 이게 "장보기 계획"과
    ///    "냉장고를 비우는 요리"를 가르는 선이다. 재고 4종을 소진하며 3종을 사는 티켓은 전자가 아니고,
    ///    재고 1종에 5종을 사야 하는 티켓은 임박 재료를 하나 건드린다는 이유만으로 덱에 오를 수 없다.
    ///    세는 것은 `used`의 **줄 수가 아니라 서로 다른 재료 수**다 — 같은 양파를 두 줄로 등록해 둔
    ///    사용자에게 이 문턱이 공짜로 낮아지면 안 된다.
    /// ② 앞선 티켓이 **아직 안 덮은** 임박 재료를 쓴다. "이 티켓만 그 재료를 다룬다"는 뜻은 아니다 —
    ///    자기보다 점수가 높은 티켓 중엔 없다는 뜻이고, 그거면 충분하다(덱은 위에서부터 채워진다).
    ///
    /// **임박한 재고가 애초에 하나도 없으면** ②는 성립할 수 없다. 그때는 ①만 본다 — 냉장고가 전부
    /// 신선하면 "오늘 비우는 순서"라는 기준 자체가 안 서는데, ②를 그대로 요구하면 잘 채워진 냉장고가
    /// 빈 덱을 받는다(빈 상태 문안은 "재료 이름 확인·장보기"를 권하는데 그 사용자에겐 둘 다 틀린 말이다).
    ///
    /// **후보가 있는데 덱이 비지는 않는다(바닥).** ①의 문턱은 재고 종수가 상한이라, 재료가 1~3종뿐인
    /// 냉장고에서는 부족 3개 이상인 후보가 통째로 탈락한다 — 시드+사전 실측으로 3종 조합의 45%,
    /// 2종이면 56%가 덱 0장이 됐다(`onion+tofu+chicken`: 후보 41장 → 0장). 그런데 전부 신선한 냉장고는
    /// 빈 상태의 atRisk 분기를 못 타서 **버튼 하나 없는 정적 문구**만 보고, 그 문구의 조언("재료 이름을
    /// 확인하라")은 이 사용자에게 틀린 말이다(이름이 맞았으니 후보가 41장이었다).
    /// 그래서 남은 게 덱 장수(`deckSize`)에 못 미치면 **점수 순으로 채운다**. 제외 규칙은 "더 나은 티켓에
    /// 자리를 내주라"는 것이지 "보여 줄 게 없어도 비우라"는 것이 아니다.
    static let deckSize = 3

    /// 45차: 정렬 순서 소비형 스캔 → **한계이득(marginal gain) 그리디**.
    ///
    /// 이전 방식은 점수 내림차순을 위에서부터 받아들여, 최고점 티켓 셋이 **같은 소고기 한 덩이**를
    /// 물고 나란히 서는 것을 막지 못했다(샘플 냉장고 실측: 비빔밥·버거 패티·타코가 전부 같은 D-0
    /// 소고기를 소비 — 한 장을 발주하면 나머지 두 장의 전제가 무너지는데 화면은 '세 가지 선택지'로
    /// 읽힌다). 이제 한 장을 고를 때마다 **이미 덮인 재고 줄의 가중치를 0으로** 보고 남은 후보의
    /// 한계이득을 다시 계산한다 — 같은 재고를 다시 무는 티켓은 이득이 0에 수렴해 자연히 밀리고,
    /// 방치되던 임박 재료(연어 D-1·버섯 D-2)를 잡는 티켓이 올라온다(실측: 임박 커버 4→5종, 최적 일치).
    ///
    /// 제외 문턱(missing ≥ 3)과 그 예외(①채우는 것 ≥ 사는 것 ②새 임박을 구한다)·바닥 채움 규칙은
    /// 종전 계약 그대로다 — ②의 "새 임박"이 그리디의 한계이득 축과 **같은 집합**을 보게 통일됐을
    /// 뿐이다. 타이브레이크는 전순서로 못 박는다(한계이득 → 미커버 urgent 수 → missing 오름차순 →
    /// 원점수 → id) — 잡채와 타코가 세 키 동률로 stdlib 정렬 안정성에 운명을 맡기던 구멍의 마감.
    /// 45차 적대 검증 두 건의 마감이 형태를 정한다:
    /// ① **그리디는 덱 장수까지만** — 화면이 쓰는 건 상위 `deckSize`장뿐인데 후보 전수를 그리디로
    ///   소비하면 비교자 안 marginal 재계산과 겹쳐 O(n²)가 된다(실측: 후보 106장에서 rank의 80%,
    ///   시드 2배마다 prune 4배 — "레시피 수에 둔감"이라는 역색인의 목표가 rank 수준에서 뒤집혔다).
    ///   덱을 채운 뒤 남는 후보는 정렬 순서 그대로 문턱만 보며 통과시킨다 — 덱 밖 순서는 화면
    ///   계약이 없고, 바닥 채움은 어차피 원점수 순이다.
    /// ② **취향 보정도 한계화** — 원점수에서 덮인 가중치만 걷어내면 cuisine·favorites 몫(최대 +5)이
    ///   상수로 남아, 새 재고 기여가 0인 중복 티켓이 임박 재료를 유일하게 구하는 티켓을 앞선다
    ///   (취향 주입 시 실측 — 바로 이 그리디가 고치려던 증상의 재발). 이득은 빼기가 아니라
    ///   **미커버 기준 직접 재계산**: 미커버 freshness 합 − 대체 감점 + 미커버 used로 다시 센
    ///   favorites 가점 + (미커버 기여가 있을 때만) cuisine 가점. disliked 감점은 레시피 자체의
    ///   속성이라 상수로 유지한다. `preferences == .none`이면 종전 산식과 동치.
    static func prune(_ ranked: [(result: Result, score: Int)],
                      preferences: RecipePreferences = .none) -> [Result] {
        let nothingAtRisk = !ranked.contains { $0.result.used.contains { $0.freshness != .fresh } }
        // 후보별 소비 줄을 1회 선계산 — marginal이 비교마다 사전·달력을 다시 두드리지 않게 한다.
        struct Cand {
            let result: Result
            let score: Int
            let rows: [(id: UUID, weight: Int, urgent: Bool, atRisk: Bool, favorite: Bool)]
            let cuisineMatch: Bool
            let dislikedScore: Int
        }
        let cands: [Cand] = ranked.map { e in
            Cand(result: e.result, score: e.score,
                 rows: e.result.used.map { ing in
                     (ing.id, weight(ing), ing.freshness == .urgent, ing.freshness != .fresh,
                      preferences.favoriteIDs.contains(ing.matchKey))
                 },
                 cuisineMatch: e.result.recipe.cuisine.map { preferences.cuisines.contains($0) } ?? false,
                 dislikedScore: dislikedScore(e.result, preferences: preferences))
        }
        var covered = Set<UUID>()          // 이미 덱이 소비하기로 한 재고 줄(재료 정체성 id)
        var out: [Result] = []
        var remaining = Array(cands.indices)
        var dropped: [(result: Result, score: Int)] = []

        func marginal(_ c: Cand) -> (gain: Int, urgentNew: Int) {
            var fresh = 0, favs = 0, urgentNew = 0, anyNew = false
            for row in c.rows where !covered.contains(row.id) {
                fresh += row.weight
                anyNew = true
                if row.urgent { urgentNew += 1 }
                if row.favorite { favs += 1 }
            }
            var gain = fresh - substitutionPenalty * c.result.substituted.count + c.dislikedScore
            if favs > 0 { gain += min(favs * favoriteBonusPerItem, favoriteBonusCap) }
            if anyNew, c.cuisineMatch { gain += cuisineBonus }
            return (gain, urgentNew)
        }
        func accepts(_ c: Cand) -> Bool {
            let clearedCount = Set(c.result.used.map(\.matchKey)).count
            let pullsItsWeight = clearedCount >= c.result.missing.count
            let rescuesSomethingNew = nothingAtRisk
                || c.rows.contains { $0.atRisk && !covered.contains($0.id) }
            return c.result.missing.count < maxMissingForRecommendation
                || (pullsItsWeight && rescuesSomethingNew)
        }

        while out.count < deckSize && !remaining.isEmpty {
            var bestPos = 0
            var bestKey: (gain: Int, urgentNew: Int) = marginal(cands[remaining[0]])
            for pos in remaining.indices.dropFirst() {
                let a = cands[remaining[pos]], b = cands[remaining[bestPos]]
                let ka = marginal(a)
                let better: Bool
                if ka.gain != bestKey.gain { better = ka.gain > bestKey.gain }
                else if ka.urgentNew != bestKey.urgentNew { better = ka.urgentNew > bestKey.urgentNew }
                else if a.result.missing.count != b.result.missing.count {
                    better = a.result.missing.count < b.result.missing.count
                } else if a.score != b.score { better = a.score > b.score }
                else { better = a.result.id < b.result.id }
                if better { bestPos = pos; bestKey = ka }
            }
            let c = cands[remaining.remove(at: bestPos)]
            guard accepts(c) else { dropped.append((c.result, c.score)); continue }
            out.append(c.result)
            covered.formUnion(c.rows.map(\.id))
        }
        // 덱 밖 — 정렬 순서 그대로 문턱만 본다(그리디 없음, O(n)).
        for idx in remaining {
            let c = cands[idx]
            guard accepts(c) else { dropped.append((c.result, c.score)); continue }
            out.append(c.result)
            covered.formUnion(c.rows.map(\.id))
        }
        guard out.count < deckSize else { return out }
        // 바닥 채움은 원점수 순 — 탈락분 사이의 한계 경쟁은 의미가 없다(어차피 문턱 미달).
        let fill = dropped.sorted { a, b in
            if a.score != b.score { return a.score > b.score }
            return a.result.id < b.result.id
        }
        return out + fill.prefix(deckSize - out.count).map(\.result)
    }

    /// 점수순 정렬된 추천 덱(보유 재료를 하나라도 쓰는 레시피만).
    /// `preferences`(프로필 취향, §5.2)가 주어지면 알레르기 하드 필터 + 선호/기피/요리스타일 보정을
    /// 적용한다. 기본 `.none`은 순수 freshness 랭킹(기존 호출·테스트 후방호환).
    static func rank(for ingredients: [Ingredient], inventory: [Ingredient]? = nil,
                     from recipes: [Recipe],
                     preferences: RecipePreferences = .none) -> [Result] {
        // 45차: 후보 계산이 레시피×재고 이중 스캔에서 **캐논 역색인**으로 바뀌었다(bulkResults).
        // 의미는 result(for:)와 동일해야 하며(파리티 테스트가 시드 전수로 고정), 점수는 정렬 전에
        // 한 번만 계산한다(decorate-sort). 초기 정렬에도 id 최종 타이브레이크를 둬 전순서를 만든다 —
        // 잡채·타코가 세 키 동률로 stdlib 정렬 안정성에 걸려 있던 비결정성의 마감.
        let eligible = recipes.filter { recipe in
            !containsAllergen(recipe, preferences.allergenIDs)   // 알레르기 하드 필터(안전 P0)
                && !(preferences.vegetarian && containsAnimalProtein(recipe))   // 채식 하드 필터
        }
        let ranked = bulkResults(for: eligible, ingredients: ingredients, inventory: inventory)
            .filter { !$0.used.isEmpty }
            .map { (result: $0, score: score($0, preferences: preferences)) }
            .sorted { a, b in
                if a.score != b.score { return a.score > b.score }
                if a.result.urgentUsedCount != b.result.urgentUsedCount {
                    return a.result.urgentUsedCount > b.result.urgentUsedCount
                }
                if a.result.missing.count != b.result.missing.count {
                    return a.result.missing.count < b.result.missing.count
                }
                return a.result.id < b.result.id
            }
        // 부족 재료가 너무 많은 레시피를 덱에서 뺀다 — **정렬 뒤에** 한계이득 커버리지를 보며 거른다.
        // missing 계산 자체는 건드리지 않는다 — 남는 티켓의 Short 줄이 그 값을 쓴다.
        return prune(ranked, preferences: preferences)
    }

    /// 역색인 벌크 계산(45차) — `result(for:)`와 **의미 동일**, 비용만 다르다.
    ///
    /// 종전에는 레시피마다 재고×비상비줄 이중 스캔에 matches()가 캐논·정규화를 매번 재계산해
    /// 재고 100종에서 rank 1회 33ms(맥 -O 실측, 아이폰 100ms+)였다. 이제 ① 레시피 줄과 재고의
    /// 캐논·정규화를 각 1회만 해석하고 ② 캐논→줄 포스팅으로 재고를 한 번만 훑는다.
    /// rank 전체(정렬·prune 포함)는 같은 조건에서 6ms — 첫 45차 구현은 전수 그리디 prune이
    /// O(후보²)로 자라 여기서 아낀 것을 도로 삼켰다(73ms — 적대 검증 실측). prune을 덱 장수로
    /// 한정한 뒤에야 "레시피 수에 둔감"이 rank 수준에서 성립해 시드 확충(커버리지 처방)의 전제가 된다.
    ///
    /// matches()의 텍스트 폴백 규약을 그대로 옮겼다: 캐논이 **양쪽 다** 있으면 ID(+parent)로만,
    /// 어느 한쪽이라도 없으면 정규화 정확 일치로만 — 캐논 있는 재고는 캐논 없는 줄과, 캐논 없는
    /// 재고는 모든 줄과 텍스트 비교한다. 파리티 테스트(시드×무작위 냉장고)가 이 등가를 고정한다.
    private static func bulkResults(for recipes: [Recipe], ingredients: [Ingredient],
                                    inventory: [Ingredient]?) -> [Result] {
        let lex = IngredientLexicon.shared
        // 레시피 줄 해석 1회 — (비상비 줄, 캐논들(1차+altRefs), 정규화 en/ko).
        struct Line { let item: Recipe.Item; let keys: [String]; let en: String; let ko: String? }
        var lines: [[Line]] = []
        var byKey: [String: [(r: Int, l: Int)]] = [:]          // 캐논 → 줄
        var byTextAll: [String: [(r: Int, l: Int)]] = [:]      // 정규화 표기 → 모든 줄
        var byTextNilKey: [String: [(r: Int, l: Int)]] = [:]   // 정규화 표기 → 캐논 없는 줄만
        lines.reserveCapacity(recipes.count)
        for (r, recipe) in recipes.enumerated() {
            var out: [Line] = []
            for item in recipe.ingredients where !isStaple(item) {
                let l = out.count
                let keys = itemKeys(of: item)
                let en = norm(item.en)
                let ko = item.ko.map(norm)
                out.append(Line(item: item, keys: keys, en: en, ko: ko))
                for key in keys { byKey[key, default: []].append((r, l)) }
                byTextAll[en, default: []].append((r, l))
                if let ko { byTextAll[ko, default: []].append((r, l)) }
                if keys.isEmpty {
                    byTextNilKey[en, default: []].append((r, l))
                    if let ko { byTextNilKey[ko, default: []].append((r, l)) }
                }
            }
            lines.append(out)
        }
        // 재고 한 줄이 닿는 (레시피, 줄) 집합 — matches() 규약 그대로.
        func hits(of ing: Ingredient) -> [(r: Int, l: Int)] {
            let name = norm(ing.name)
            guard !name.isEmpty else { return [] }
            var found: [(r: Int, l: Int)] = []
            if let canon = ing.canonicalID ?? lex.canonicalID(for: ing.name) {
                found += byKey[canon] ?? []
                if let parent = lex.parentID(of: canon) { found += byKey[parent] ?? [] }
                found += byTextNilKey[name] ?? []           // 캐논 있는 재고 ↔ 캐논 없는 줄(텍스트)
            } else {
                found += byTextAll[name] ?? []              // 캐논 없는 재고 ↔ 모든 줄(텍스트)
            }
            return found
        }
        // used: 소비 후보(ingredients, 이미 임박순) / missing 판정: inventory ?? ingredients.
        var used: [[Ingredient]] = Array(repeating: [], count: recipes.count)
        var usedSeen: [Set<UUID>] = Array(repeating: [], count: recipes.count)
        for ing in ingredients {
            for (r, _) in hits(of: ing) where !usedSeen[r].contains(ing.id) {
                usedSeen[r].insert(ing.id)
                used[r].append(ing)
            }
        }
        var lineHit: [[Bool]] = lines.map { Array(repeating: false, count: $0.count) }
        for ing in (inventory ?? ingredients) {
            for (r, l) in hits(of: ing) { lineHit[r][l] = true }
        }
        return recipes.indices.map { r in
            var missing: [Recipe.Item] = []
            var substituted: [(item: Recipe.Item, with: Ingredient)] = []
            for l in lines[r].indices where !lineHit[r][l] {
                let item = lines[r][l].item
                if item.isOptional { continue }   // 선택 줄은 부족을 만들지 않는다(45차)
                // usedSeen[r]이 곧 "이 레시피가 이미 예약한 재고" — 1재고 1줄(result(for:)와 동일 계약).
                if let sub = substitute(for: item, in: recipes[r], from: ingredients,
                                        excluding: usedSeen[r]) {
                    substituted.append((item, sub))
                    if usedSeen[r].insert(sub.id).inserted { used[r].append(sub) }
                } else {
                    missing.append(item)
                }
            }
            let rowUsed = used[r].sorted { $0.effectiveDaysLeft < $1.effectiveDaysLeft }
            let urgent = rowUsed.filter { $0.freshness == .urgent }.count
            return Result(id: recipes[r].id, recipe: recipes[r], used: rowUsed,
                          total: lines[r].count, substituted: substituted,
                          missing: missing, urgentUsedCount: urgent)
        }
    }

    // MARK: - 커버리지 점검(덱이 임박 재료를 실제로 다루는가)

    /// 덱이 **다루지 못한 오늘 만료(urgent) 재료** — 어떤 티켓의 `used`에도 들어가지 않은 것.
    ///
    /// 랭킹은 "가장 임박한 걸 가장 많이 쓰는" 레시피를 위로 올릴 뿐, 특정 재료를 쓰는 레시피가
    /// 하나도 없으면 그 재료는 조용히 빠진다 — 메인 배너는 "N at risk today"라고 압박하는데
    /// 티켓 어디에도 그 재료가 없는 상태다. 그 어긋남을 화면이 말할 수 있게, 판별을 **순수 함수**로
    /// 분리해 둔다(뷰 밖에서 검증 가능 — 커버 상태는 재료 정체성 `id`로만 본다).
    ///
    /// - Parameters:
    ///   - ingredients: 후보 재고(보통 `FridgeStore.available` — 이미 마감 임박순).
    ///   - results: 지금 덱에 올라간 티켓들(상위 3장 스냅샷).
    /// - Returns: 입력 순서를 유지한 미커버 urgent 재료. `.soon`·`.fresh`는 포함하지 않는다 —
    ///   오늘이 아닌 재료까지 호명하면 안내가 상시 표시돼 경고가 아니라 배경이 된다.
    ///
    /// **휴면 API(41차)** — 유일한 소비자였던 티켓 덱 위 브리지 행이 41차 덜어내기로 빠져 지금
    /// UI 호출부가 없다. `PaperRing`과 같은 근거로 계약·테스트째 남긴다(§13.10 — 표면에서 물러날
    /// 뿐, "덱이 안 쓰는 임박 재료" 판별이 다시 필요해지면 이 함수가 정답이다).
    ///   `LexiconRecommenderTests`의 uncovered* 4건이 계약을 계속 고정한다.
    static func uncoveredUrgent(ingredients: [Ingredient], results: [Result]) -> [Ingredient] {
        guard ingredients.contains(where: { $0.freshness == .urgent }) else { return [] }
        let covered = Set(results.flatMap { $0.used.map(\.id) })
        return ingredients.filter { $0.freshness == .urgent && !covered.contains($0.id) }
    }

    // MARK: - 취향 반영(§5.2 프로필 선호 → 랭킹 실배선)

    // 튜닝 상수(§근거) — freshness 합(urgent3/soon2/fresh1)이 1차 기준이고, 아래 보정은 그 합에
    // 더해진다. 크기를 freshness 가중치대(1~3)와 같은 급으로 잡아, 취향이 순위를 '기울이되'
    // 임박도를 뒤엎지 않게 한다(예: 여러 재료가 임박한 레시피는 취향과 무관하게 여전히 위).
    /// 선호 요리 스타일 일치 — 재료 한 개 임박(soon)만큼의 가점.
    static let cuisineBonus = 2
    /// 좋아하는 재료(used에 실제로 있는) 한 개당 가점과 상한(과대 편향 방지).
    static let favoriteBonusPerItem = 1
    static let favoriteBonusCap = 3
    /// 싫어하는 재료(레시피에 포함) 한 개당 감점과 하한(한 레시피가 무한정 내려가지 않게).
    static let dislikedPenaltyPerItem = -2
    static let dislikedPenaltyFloor = -6

    /// 정렬 점수 — freshness 합(1차 기준) + 취향 보정 − 대체 감점(45차).
    /// `.none`이면 취향 보정 0이라 순수 freshness. 대체 감점은 취향과 무관하게 항상 적용된다 —
    /// 대체 티켓이 정품 매칭 티켓을 이기면 "가능"이 "동급"으로 승격되는 셈이다.
    private static func score(_ result: Result, preferences: RecipePreferences) -> Int {
        result.used.reduce(0) { $0 + weight($1) }
            - substitutionPenalty * result.substituted.count
            + preferenceScore(for: result, preferences: preferences)
    }

    /// 취향 보정 점수 — cuisine 가점 + favorites 가점(used 기준) + disliked 감점(레시피 전체 재료 기준).
    static func preferenceScore(for result: Result, preferences p: RecipePreferences) -> Int {
        guard !p.isEmpty else { return 0 }
        var score = 0
        // ① 선호 요리 스타일 — recipe.cuisine(시드 cuisine 문자열, seedCuisines 매핑 후) 비교.
        if let cuisine = result.recipe.cuisine, p.cuisines.contains(cuisine) {
            score += cuisineBonus
        }
        // ② favorites — 보유하고 이 레시피가 쓰는(used) 재료 중 좋아하는 것(matchKey 기준). 상한 적용.
        if !p.favoriteIDs.isEmpty {
            let favs = result.used.reduce(0) { $0 + (p.favoriteIDs.contains($1.matchKey) ? 1 : 0) }
            score += min(favs * favoriteBonusPerItem, favoriteBonusCap)
        }
        // ③ disliked — 레시피 재료(전체) 중 싫어하는 항목 수만큼 감점. 하한 적용.
        score += dislikedScore(result, preferences: p)
        return score
    }

    /// disliked 감점만 따로 — 레시피 자체의 속성(재고 무관)이라 `prune`의 한계이득에도
    /// 상수로 그대로 들어간다(cuisine·favorites는 미커버 기준으로 재계산되는 것과 대조).
    private static func dislikedScore(_ result: Result, preferences p: RecipePreferences) -> Int {
        guard !p.dislikedIDs.isEmpty else { return 0 }
        let dis = result.recipe.ingredients.reduce(0) { $0 + (item($1, matchesAny: p.dislikedIDs) ? 1 : 0) }
        return max(dis * dislikedPenaltyPerItem, dislikedPenaltyFloor)
    }

    /// 알레르기 하드 필터 — 레시피 재료 중 하나라도 알레르겐이면 레시피 전체를 제외한다.
    /// **상비재 예외 없음**(알레르기는 상비재도 거른다 — 안전 함의).
    /// 한계: `canonicalID(of:)`/exact 비교에 기대므로, "chicken or vegetable stock" 같은 서술형
    /// no-ref 라인에 알레르겐이 **부분 포함**되면 검사할 수 없다(포함 매칭은 오탐 위험이라 안 씀).
    private static func containsAllergen(_ recipe: Recipe, _ allergenIDs: Set<String>) -> Bool {
        guard !allergenIDs.isEmpty else { return false }
        return recipe.ingredients.contains { item($0, matchesAny: allergenIDs) }
    }

    /// 채식 하드 필터가 배제하는 글리프 — Meat(meat·poultry·sausage·bacon) + Seafood(fish·shrimp·
    /// crab·squid·clam) 카테고리(`FoodGlyph.categoryLabel` 기준). 계란·유제품은 통과(락토오보 채식).
    private static let animalGlyphs: Set<FoodGlyph> = [.meat, .poultry, .sausage, .bacon,
                                                       .fish, .shrimp, .crab, .squid, .clam]

    /// 채식(§5.2 vegetarian 옵션) 하드 필터 — 비상비(non-staple) 재료 중 사전 글리프가
    /// Meat/Seafood 계열이거나 사전이 `animal: true`로 명시한 항목이면 레시피 전체 제외.
    /// 글리프만 보면 동물성인데 글리프가 다른 항목(스팸=can, 액젓·굴소스·쯔유=sauceBottle)이
    /// 전부 통과한다 — 그 예외 지식은 코드가 아니라 사전 플래그가 든다.
    /// canonical ID로 판별할 수 없는 항목(서술형 no-ref 라인 등)은 **통과**시킨다 —
    /// 보수성보다 가용성(판별 불가 라인 때문에 추천 풀이 말라붙지 않게).
    private static func containsAnimalProtein(_ recipe: Recipe) -> Bool {
        recipe.ingredients.contains { item in
            guard !isStaple(item),
                  let id = canonicalID(of: item),
                  let entry = IngredientLexicon.shared.entry(id: id) else { return false }
            if entry.animal == true { return true }
            guard let glyph = FoodGlyph(rawValue: entry.glyph) else { return false }
            return animalGlyphs.contains(glyph)
        }
    }

    /// 레시피 항목이 정규화 키 집합에 속하는지 — canonicalID(+altRefs, 45차) 우선, no-ref 항목은
    /// exact 텍스트(소문자). 대체 캐논도 검사한다 — "pork (or beef)" 줄은 소고기 알레르기에도
    /// 걸려야 한다(보수: any-of 중 하나라도 알레르겐이면 레시피 전체 제외, 안전 P0).
    private static func item(_ item: Recipe.Item, matchesAny ids: Set<String>) -> Bool {
        let keys = itemKeys(of: item)
        if !keys.isEmpty { return keys.contains { ids.contains($0) } }
        if ids.contains(norm(item.en)) { return true }
        if let ko = item.ko, ids.contains(norm(ko)) { return true }
        return false
    }
}

/// 프로필 취향(§5.2)을 레시피 랭킹에 반영하기 위한 값 타입.
/// 재료 태그(favorites/disliked/allergies)는 `IngredientLexicon.canonicalID`로 정규화해
/// 한/영 표기 무관 매칭한다. 사전 밖(커스텀) 태그는 정규화 실패 시 **소문자 원문**을 보관해,
/// ref 없는 레시피 항목의 exact 텍스트 비교(`canonicalID(of:)`와 대칭)에도 쓴다.
struct RecipePreferences {
    /// 선호 요리 스타일 — **시드 cuisine 문자열**(`seedCuisines` 매핑을 거친) 집합.
    /// `Recipe.cuisine`과 직접 비교하므로, 프로필 옵션(CuisineStyle)이 아니라 시드 taxonomy가 단위다.
    var cuisines: Set<String>
    /// 좋아하는 재료(canonical ID, 실패 시 소문자 원문) — used에 있으면 가점.
    var favoriteIDs: Set<String>
    /// 싫어하는 재료 — 레시피에 포함되면 감점.
    var dislikedIDs: Set<String>
    /// 알레르겐 — 하드 필터의 근거(안전 P0). 상비재도 예외 없이 거른다.
    var allergenIDs: Set<String>
    /// 채식(§5.2 vegetarian 옵션) — cuisine 가점이 아니라 **식이 하드 필터**로 승격
    /// (Meat/Seafood 글리프 재료를 쓰는 레시피 제외 — 가점으로는 실동작을 못 만든다).
    var vegetarian: Bool = false

    /// 취향 미적용(기본) — 랭킹은 순수 freshness. 후방호환 회귀의 기준.
    static let none = RecipePreferences(cuisines: [], favoriteIDs: [],
                                        dislikedIDs: [], allergenIDs: [])

    /// 보정할 취향이 하나도 없으면 점수 계산을 건너뛴다(=.none 후방호환).
    var isEmpty: Bool {
        cuisines.isEmpty && favoriteIDs.isEmpty && dislikedIDs.isEmpty
            && allergenIDs.isEmpty && !vegetarian
    }

    /// 재료 태그 목록 → 정규화 키 집합. 사전 매칭 성공 시 canonical ID, 실패 시 소문자 원문
    /// (`Ingredient.matchKey`·`canonicalID(of:)`의 no-ref 규칙과 대칭이라 표기 무관 비교가 산다).
    static func normalize(_ tags: [String]) -> Set<String> {
        let lex = IngredientLexicon.shared
        var out: Set<String> = []
        for tag in tags {
            let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            out.insert(lex.canonicalID(for: trimmed) ?? trimmed.lowercased())
        }
        return out
    }
}

extension RecipePreferences {
    /// 프로필 옵션(CuisineStyle) → 시드 cuisine 문자열 매핑. 시드 taxonomy(128레시피 기준, 44차:
    /// korean 55 · american 20 · italian 12 · french 10 · chinese 8 · japanese 7 · mexican 5 ·
    /// thai 3 · indian 3 · vietnamese 2 · middle-eastern 2 · spanish 1)와 프로필 옵션이 1:1이
    /// 아니라서: western은 미국·프랑스·스페인 계열로, mediterranean은 이탈리아·스페인·중동
    /// 계열로 넓혀 가점이 실제로 발화하게 한다(위약 옵션 금지 — MVP 원칙).
    /// 겹치는 8종(korean 등)은 동일 문자열 그대로. vegetarian은 cuisine이 아니라 식이 필터.
    /// 'other'는 44차에 0이 됐다 — 어느 옵션도 못 닿는 값이라 5편을 실제 계통으로 재분류했다
    /// (감바스풍 새우 → spanish로 spanish 죽은 가지도 함께 해소).
    static let seedCuisines: [CuisineStyle: Set<String>] = [
        .korean:        ["korean"],
        .japanese:      ["japanese"],
        .chinese:       ["chinese"],
        .italian:       ["italian"],
        .mexican:       ["mexican"],
        .indian:        ["indian"],
        .thai:          ["thai"],
        .vietnamese:    ["vietnamese"],
        .western:       ["american", "french", "spanish"],
        .mediterranean: ["italian", "spanish", "middle-eastern"],
    ]

    /// 프로필(§5.2)에서 취향 스냅샷을 만든다 — cuisines는 시드 매핑을 거친 문자열 집합,
    /// vegetarian 선택은 식이 하드 필터 플래그로 승격, 재료 태그는 정규화 키.
    init(profile: ProfileStore) {
        var cuisines: Set<String> = []
        for c in profile.cuisines where c != .vegetarian {
            cuisines.formUnion(Self.seedCuisines[c] ?? [c.rawValue])
        }
        self.init(cuisines: cuisines,
                  favoriteIDs: Self.normalize(profile.favorites),
                  dislikedIDs: Self.normalize(profile.disliked),
                  allergenIDs: Self.normalize(profile.allergies),
                  vegetarian: profile.cuisines.contains(.vegetarian))
    }
}
