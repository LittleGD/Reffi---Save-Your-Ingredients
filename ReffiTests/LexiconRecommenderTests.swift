import Testing
import Foundation
@testable import Reffi

/// 정본 재료 사전 — 번들 로드·한/영 매칭·한 글자 규칙·기본 소비기한.
struct LexiconTests {
    private let lex = IngredientLexicon.shared

    @Test func bundleLoads() {
        #expect(lex.entries.count >= 200)
    }

    @Test func matchesKoreanAndEnglishNames() {
        #expect(lex.canonicalID(for: "달걀") == "egg")
        #expect(lex.canonicalID(for: "계란") == "egg")
        #expect(lex.canonicalID(for: "egg") == "egg")
        #expect(lex.canonicalID(for: "양파") == "onion")
    }

    @Test func longerKeywordWinsOverSubstring() {
        // 대파/쪽파는 green-onion — "onion"(양파)으로 오분류되면 발주가 엉뚱한 재료를 소비한다.
        #expect(lex.canonicalID(for: "대파") == "green-onion")
        #expect(lex.canonicalID(for: "green onion") == "green-onion")
        #expect(lex.canonicalID(for: "onion") == "onion")
    }

    @Test func containsMatchForCompoundNames() {
        // 영수증 축약 상품명("서울우유1L")도 포함 매칭으로 잡힌다 — OCR 경로의 전제.
        #expect(lex.canonicalID(for: "서울우유1L") == "milk")
    }

    // MARK: 타이핑 검색 (To buy 직접 담기 시트)

    @Test func searchRanksPrefixAboveContains() {
        // "onion" — 양파(이름 자체가 prefix)가 대파("green onion", 포함)보다 앞.
        let ids = lex.search(query: "onion").map(\.id)
        #expect(ids.first == "onion")
        #expect(ids.contains("green-onion"))
    }

    @Test func searchRanksShorterNameFirstWithinPrefixHits() throws {
        // 같은 prefix 적중이면 쿼리를 더 꽉 채운(짧은) 이름이 먼저 — "배" → 배 > 배추 > 배추김치.
        let ids = lex.search(query: "배").map(\.id)
        #expect(ids.first == "pear")
        let napa = try #require(ids.firstIndex(of: "napa-cabbage"))
        let kimchi = try #require(ids.firstIndex(of: "kimchi"))
        #expect(napa < kimchi)
    }

    @Test func singleCharQueryMatchesPrefixOnly() {
        // 한 글자가 이름 안쪽에까지 걸리면 목록이 무의미해진다 — "양배추"(배가 중간)는 안 뜬다.
        let ids = lex.search(query: "배").map(\.id)
        #expect(!ids.contains("cabbage"))
        #expect(!ids.contains("brussels-sprout"))
        // 두 글자부터는 포함 매칭이 살아난다 — "양배추" → 양배추(prefix) + 방울양배추(포함).
        let two = lex.search(query: "양배추").map(\.id)
        #expect(two.first == "cabbage")
        #expect(two.contains("brussels-sprout"))
    }

    @Test func searchIsCappedAndEmptyForBlankQuery() {
        #expect(lex.search(query: "s").count == 20)        // 기본 상한
        #expect(lex.search(query: "s", limit: 3).count == 3)
        #expect(lex.search(query: "   ").isEmpty)          // 공백만 = 검색 아님
        #expect(lex.search(query: "zzz").isEmpty)
    }

    @Test func searchLimit60CoversToBuySearchSheetPath() {
        // `ToBuySearchSheet`가 실제로 넘기는 상한(60) — 기본값(20)만 덮던 공백. 쿼리 "c"의 자연
        // 히트는 44차 사전 278종 기준 60을 넘는다(부위·분리 신설의 en 표기들). 그래서 검증축이
        // 자연스러워졌다: 기본 호출은 20에서, 커스텀 60 호출은 60에서 각각 잘린다 — 두 상한이
        // 모두 관철된다는 직접 증거다.
        #expect(lex.search(query: "c").count == 20)              // 기본 상한(20)에 잘림
        #expect(lex.search(query: "c", limit: 60).count == 60)   // 커스텀 상한(60)에 잘림
    }

    /// **동률 최종 타이브레이크는 표시 이름의 로케일 알파벳순**이어야 한다(30차) — 내부 캐논 id는 항상
    /// 영문 슬러그라, id 오름차순으로 동률을 가르면 한국어 로케일에서 사용자가 보는 순서와 어긋난다.
    ///
    /// "고기" 포함 매칭에서 rank(1)·length(3)이 정확히 겹치는 동률 집합이 소고기(beef)·닭고기(chicken)·
    /// 양고기(lamb) 셋이다(`돼지고기`·`오리고기`는 length 4라 별도 동률 그룹 — 여기 대상이 아니다).
    @Test func searchBreaksRankAndLengthTiesByLocalizedDisplayNameOrder() {
        let tieIDs: Set<String> = ["beef", "chicken", "lamb"]
        let hits = lex.search(query: "고기", limit: 60)
        let tied = hits.filter { tieIDs.contains($0.id) }
        #expect(tied.count == 3, "사전 데이터가 바뀌었다 — 세 항목이 '고기' 동률 집합이어야 이 테스트가 유효하다")

        // 반환 순서는 표시 이름 오름차순(`localizedStandardCompare`)과 일치해야 한다 — 로케일 무관하게 성립.
        let expected = tied.sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
        #expect(tied.map(\.id) == expected.map(\.id))

        // 회귀 고정 — 이 앱의 기본/QA 로케일(한국어)에서는 표시 이름 순서(닭고기·소고기·양고기)가 내부 id
        // 알파벳순(beef·chicken·lamb)과 실제로 다르다. 이 값이 깨지면 표시 이름이 아니라 id로 도로 정렬된 것이다.
        if Recipe.isKorean {
            #expect(tied.map(\.id) == ["chicken", "beef", "lamb"])
        }
    }

    // MARK: 카테고리 섹션 (To buy 검색 시트의 재료 배열 — 2026-08 30차부터 UI 소비처 없음, 모델만 유지)

    @Test func categorySectionsCoverEveryEntryExactlyOnce() {
        // 섹션 그리드가 사전의 단일 뷰라는 계약 — 한 항목이 빠지면 UI에서 영영 도달 불가해지고,
        // 두 번 들어가면 같은 재료가 두 칸으로 뜬다.
        let sectioned = lex.categorySections.flatMap { $0.entries.map(\.id) }
        #expect(sectioned.count == lex.entries.count)
        #expect(Set(sectioned) == Set(lex.entries.map(\.id)))
    }

    @Test func categorySectionsFollowFixedOrderAndSkipEmpty() {
        let cats = lex.categorySections.map(\.category)
        #expect(!cats.isEmpty)
        // 순서는 `FoodGlyph.categoryOrder`(냉장고 필터 칩과 공유)의 부분 수열이어야 한다 — 항목 없는 카테고리만 빠지고, 남은 것들의
        // 상대 순서는 선언 순서 그대로다(빈 섹션 헤더도, 뒤죽박죽 순서도 안 된다).
        #expect(cats == FoodGlyph.categoryOrder.filter { cats.contains($0) })
        #expect(cats.first == "Veg")   // 사전에 채소가 없을 리 없다
    }

    @Test func categorySectionsGroupByGlyphCategoryAndSortByName() throws {
        for section in lex.categorySections {
            for entry in section.entries {
                let glyph = try #require(FoodGlyph(rawValue: entry.glyph))
                #expect(glyph.categoryLabel == section.category)
            }
            // 인접 쌍만 본다 — 동명이인(같은 표기)이 있으면 `sorted`와의 전량 비교는 불안정하다.
            let names = section.entries.map(\.displayName)
            for (a, b) in zip(names, names.dropFirst()) {
                #expect(a.localizedStandardCompare(b) != .orderedDescending,
                        "\(section.category): '\(a)' before '\(b)'")
            }
        }
        // 대표 샘플 — 분류 축이 글리프라는 사실이 바뀌면 여기가 먼저 깨진다.
        let veg = try #require(lex.categorySections.first { $0.category == "Veg" })
        #expect(veg.entries.contains { $0.id == "onion" })
        let dairy = try #require(lex.categorySections.first { $0.category == "Dairy" })
        #expect(dairy.entries.contains { $0.id == "milk" })
        #expect(!dairy.entries.contains { $0.id == "onion" })
    }

    @Test func staplesAreFlagged() {
        #expect(lex.isStaple("소금"))
        #expect(lex.isStaple("soy-sauce"))
        #expect(!lex.isStaple("beef"))
    }

    @Test func shelfLifeVariesByStorage() {
        let fridge = lex.shelfLifeDays(for: "소고기", storage: .fridge)
        let freezer = lex.shelfLifeDays(for: "소고기", storage: .freezer)
        #expect(fridge != nil && freezer != nil)
        #expect(freezer! > fridge!)   // 냉동이 냉장보다 길어야 정상
    }

    /// 신규 12종 글리프 재배정(§13.3 — corn·cucumber·pea·cabbage·chili·pumpkin·avocado·banana·
    /// noodles·rice·sauceBottle·can) 전수 검증. `GlyphTests`는 enum 자체의 계약만 보고 이쪽에서
    /// 미루기로 한 몫 — JSON의 `glyph` 문자열이 `FoodGlyph` rawValue 집합 밖으로 새면 픽커 그리드
    /// (일러스트 사전 픽커)가 조용히 `.generic`으로 무너진다. 디코드는 톨러런트해도 데이터 품질은 아니다.
    @Test func allEntryGlyphsAreValidFoodGlyphCases() {
        let validGlyphs = Set(FoodGlyph.allCases.map(\.rawValue))
        for entry in lex.entries {
            #expect(validGlyphs.contains(entry.glyph), "unknown glyph '\(entry.glyph)' for entry '\(entry.id)'")
        }
    }

    @Test func newGlyphsAreActuallyAssignedInLexicon() {
        // 재배정이 빠지면(예: 스크립트 재실행 실수) 픽커의 신규 종 타일이 전부 죽은 코드가 된다.
        let assigned = Set(lex.entries.map(\.glyph))
        for glyph in ["corn", "cucumber", "pea", "cabbage", "chili", "pumpkin",
                      "avocado", "banana", "noodles", "rice", "sauceBottle", "can"] {
            #expect(assigned.contains(glyph), "no lexicon entry uses new glyph '\(glyph)'")
        }
    }

    @Test func v2GlyphsAreActuallyAssignedInLexicon() {
        // v2 신규 17종도 사전에 실제 배정돼야 픽커 타일이 산다(seaweed는 미역·김·다시마 공용).
        let assigned = Set(lex.entries.map(\.glyph))
        for glyph in ["eggplant", "sweetPotato", "ginger", "seaweed",
                      "grape", "watermelon", "pineapple", "mango",
                      "sausage", "bacon", "crab", "squid", "clam",
                      "yogurt", "butter", "honey", "dumpling"] {
            #expect(assigned.contains(glyph), "no lexicon entry uses v2 glyph '\(glyph)'")
        }
    }

    /// **실제품명 해석(41차)** — 장보기에서 실제로 오는 라벨 표기가 맞는 캐논에 붙는지 배터리로 고정한다.
    /// 오탐(남의 캐논)은 장보기 줄 소멸·레시피 오매칭·소비기한 오염으로 번지는 데이터 파괴라,
    /// 여기 실린 각 줄은 실측에서 실제로 틀렸거나(수정 전) 틀리기 직전이었던 케이스다.
    @Test func realProductNamesResolveToTheRightCanon() {
        let cases: [(String, String?)] = [
            // 가공 토마토 — 신선 tomato로 흡수되면 소비기한이 540일 → 7일로 무너진다.
            ("통조림토마토", "canned-tomato"), ("홀토마토", "canned-tomato"),
            ("canned diced tomatoes", "canned-tomato"), ("토마토퓨레", "tomato-sauce"),
            // 케첩 — 띄어쓰기·맞춤법 변형("케챂"은 오뚜기 실라벨 표기).
            ("하인즈 케찹", "ketchup"), ("오뚜기 케챂", "ketchup"),
            ("하인즈 토마토 케첩", "ketchup"), ("Heinz Tomato Ketchup", "ketchup"),
            // 우유 — 지방·유당 변형은 전부 milk(의도된 동일시).
            ("2%우유", "milk"), ("저지방우유", "milk"), ("멸균우유", "milk"),
            ("커클랜드 락토스프리 저지방우유", "milk"), ("서울우유1L", "milk"),
            // 동률 의존이었던 케이스 — 등재·머리말 규칙으로 결정 확정.
            ("고추참치", "tuna"), ("초코우유", "flavored-milk"), ("오이소박이", "kimchi"),
            // 사전 밖 브랜드는 어느 캐논에도 붙지 않아야 한다(안전한 실패).
            ("코카콜라 1.5L", nil),
        ]
        for (name, want) in cases {
            #expect(lex.canonicalID(for: name) == want, "\(name) → \(want ?? "nil")")
        }
    }

    /// **가향유·식물성 대체유 분리(41차)** — 딸기우유가 strawberry에 붙으면 존재하지 않는 딸기가
    /// '있다'로 계산돼 딸기 레시피가 오탐되고 To buy의 딸기 줄이 사라진다. milk에 붙는 것도 오답이다
    /// (우유 레시피에 딸기우유가 매칭되면 조리 결과가 다른 음식이 된다) — 전용 캐논으로만 간다.
    @Test func flavoredAndPlantMilksSeparateFromFruitAndNut() {
        for (name, want) in [("딸기우유", "flavored-milk"), ("바나나맛우유", "flavored-milk"),
                             ("strawberry milk", "flavored-milk"),
                             ("아몬드브리즈", "almond-milk"), ("almond milk", "almond-milk"),
                             ("오트밀크", "oat-milk"), ("buttermilk", "buttermilk")] {
            #expect(lex.canonicalID(for: name) == want, "\(name) → \(want)")
        }
        // 반대 방향 회귀 — 진짜 우유·두유·코코넛밀크는 그대로.
        #expect(lex.canonicalID(for: "두유") == "soy-milk")
        #expect(lex.canonicalID(for: "coconut milk") == "coconut-milk")
    }

    /// **자유 표기 해석은 정확 → 머리말 → 포함 순(41차)** — 한국어·영어 복합명사는 뒤가 머리라,
    /// 포함 매칭을 먼저 돌리면 앞의 수식어(딸기·고추·토마토)가 재료를 가로챈다.
    /// 포함 매칭은 머리에 용량이 붙는 실표기("서울우유1L")의 마지막 폴백으로만 남는다.
    @Test func headNounTierBeatsContainsInFreeTextResolution() {
        #expect(lex.canonicalID(for: "빙그레 바나나우유") == "flavored-milk")   // 머리말(바나나우유)
        #expect(lex.canonicalID(for: "델몬트 토마토주스") == "juice")           // 머리말(주스) > 포함(토마토)
        #expect(lex.canonicalID(for: "양파피클") == "pickle")                   // 머리말(피클) > 포함(양파)
        #expect(lex.canonicalID(for: "whole milk yogurt") == "yogurt")          // 머리말(yogurt) > 포함(whole milk)
        #expect(lex.canonicalID(for: "서울우유1L") == "milk")                   // 포함 폴백은 살아 있다
    }

    /// **오타 허용 계층(44차)** — 전 계층 미스에서만, 자모 편집 거리 1·유일 승자·**한글 3음절/영문
    /// 5자 이상**일 때만 교정한다(적대 검증에서 강화 — 2음절 지대에서는 방어→장어, 율무→열무처럼
    /// 사전 밖 실존 재료가 흡수됐다). 교정 성공과 **교정 거부**를 함께 고정한다.
    @Test func typoToleranceCorrectsSingleJamoSlips() {
        #expect(lex.canonicalID(for: "양송기") == "button-mushroom")   // ㅇ→ㄱ 한 획(3음절)
        #expect(lex.canonicalID(for: "tomatoe") == "tomato")           // 영문 삽입 1
        #expect(lex.canonicalID(for: "brocoli") == "broccoli")         // 영문 탈락 1
    }

    @Test func typoToleranceRefusesShortAmbiguousAndDistance2() {
        // 2음절 한글은 **전면 제외** — 식재료 최소쌍의 지대다. 사전에 없는 실존 재료가 등재 표기와
        // 1획 차이면 그대로 흡수됐던 실측(방어→장어, 냉이→팽이, 율무→열무, 타임→라임)의 회귀 고정.
        for name in ["방어", "냉이", "민어", "율무", "타임", "크릴", "게란", "오디"] {
            #expect(lex.canonicalID(for: name) == nil, "\(name): 2음절 지대는 교정하지 않는다")
        }
        // 영문 4자 이하도 동일(malt→salt, port→pork 실측 회귀 고정).
        for name in ["malt", "port", "mild", "silk"] {
            #expect(lex.canonicalID(for: name) == nil, "\(name)")
        }
        // 거리 2는 받지 않는다 — 공격적 교정 금지("도마도"는 ㄷ→ㅌ 두 획).
        #expect(lex.canonicalID(for: "도마도") == nil)
        #expect(lex.canonicalID(for: "qqzzxx") == nil)
    }

    /// **정육 부위 해석(44차)** — 종 접두 관행(소는 무접두, 돼지는 돼지/돈)과 종 토큰 가드를 고정한다.
    /// 등재 안 된 조합("돼지고기 등심")은 부위 정밀도를 버리고 종 총칭으로 강등한다 — 종이 뒤집혀
    /// 소 재고가 소비되는 것이 최악의 실패다.
    @Test func meatCutsResolveWithSpeciesGuard() {
        #expect(lex.canonicalID(for: "등심") == "beef-loin")            // 무접두 = 소(소매 관행)
        #expect(lex.canonicalID(for: "1++한우 등심") == "beef-loin")
        #expect(lex.canonicalID(for: "돼지등심") == "pork-loin")
        #expect(lex.canonicalID(for: "돼지고기 등심") == "pork")        // 미등재 조합 → 종 총칭 강등
        #expect(lex.canonicalID(for: "닭안심") == "chicken-tenderloin") // 최장 일치가 '안심'(소)보다 먼저
        #expect(lex.canonicalID(for: "갈비") == nil, "소·돼지·닭 3중 충돌 — 단독 갈비는 매핑 금지")
        #expect(lex.canonicalID(for: "등갈비") == "pork-rib")           // 등갈비는 돼지 전용 표기
        #expect(lex.canonicalID(for: "차돌박이") == "beef-brisket-point")
        #expect(lex.canonicalID(for: "닭다리살") == "chicken-thigh")    // 닭다리(북채)와 다른 부위
        #expect(lex.canonicalID(for: "닭다리") == "chicken-drumstick")
        // 적대 검증 회귀 고정 — 종 가드의 오리·외래어 토큰과 총칭 강등.
        #expect(lex.canonicalID(for: "오리안심") == "duck", "오리 부위가 소 안심으로 뒤집히면 안 된다")
        #expect(lex.canonicalID(for: "치킨 안심") == "chicken")
        #expect(lex.canonicalID(for: "돼지 불고기용") == "pork", "용도명이 beef 기본이어도 종 토큰이 이긴다")
        #expect(lex.canonicalID(for: "불고기용") == "beef")             // 종 생략 정육 라벨 최빈 표기
        // 전지·후지는 분유·사과를 삼키던 맨몸 토큰이라 뺐다(부사 후지 = 사과 품종).
        #expect(lex.canonicalID(for: "부사 후지") == "apple")
        #expect(lex.canonicalID(for: "전지분유") == nil)
    }

    /// **신선/가공 분리(44차)** — 같은 이름 아래 섞여 있던 형태를 갈라, 보관 칩 하나로 기한이
    /// 2년↔2일을 널뛰던 결함을 데이터에서 제거한다.
    @Test func processedFormsSeparateFromFreshOnes() {
        for (name, want) in [("절임배추", "salted-napa"), ("사골육수", "broth-liquid"),
                             ("훈제오리", "smoked-duck"), ("훈제연어", "smoked-salmon"),
                             ("자반고등어", "salted-mackerel"), ("굴비", "salted-croaker"),
                             ("다진마늘", "minced-garlic"), ("생미역", "fresh-seaweed"),
                             ("착즙주스", "fresh-juice"), ("밥", "cooked-rice"),
                             ("칼국수면", "fresh-noodle"), ("앤초비", "anchovy-fillet")] {
            #expect(lex.canonicalID(for: name) == want, "\(name) → \(want)")
        }
        // 신선 쪽은 그대로 — 분리가 원형을 밀어내면 안 된다.
        #expect(lex.canonicalID(for: "배추") == "napa-cabbage")
        #expect(lex.canonicalID(for: "미역") == "seaweed")
        #expect(lex.canonicalID(for: "멸치") == "anchovy")
        // 분리 항목의 총칭 매칭(단방향): 사골육수는 stock 레시피 줄을 채운다.
        #expect(RecipeRecommender.matches(
            Ingredient(name: "사골육수", category: "기타", daysLeft: 3,
                       quantity: Quantity(value: 1, unit: .pack), glyph: .generic),
            Recipe.Item(ref: "stock", en: "stock", ko: "육수")))
        // 훈제오리는 생오리 레시피(오리주물럭)를 채우지 않는다 — parent를 일부러 안 달았다.
        #expect(!RecipeRecommender.matches(
            Ingredient(name: "훈제오리", category: "육류", daysLeft: 10,
                       quantity: Quantity(value: 1, unit: .pack), glyph: .poultry),
            Recipe.Item(ref: "duck", en: "duck", ko: "오리고기")))
    }

    /// **경합 표기 퍼지 제외(44차)** — 서로 다른 재료끼리 자모 1획 차인 실표기(새우/생수, 오이/오리)는
    /// 퍼지 목적지가 될 수 없다. "샤우"는 새우와 1획 차지만 새우 자체가 경합 지대라 교정하지 않는다.
    @Test func contestedNamesAreExcludedFromTypoTolerance() {
        #expect(lex.canonicalID(for: "샤우") == nil)
        // 경합 없는 3음절+ 표기는 계속 교정된다(위 typoTolerance 테스트의 양송기가 그 증거).
        #expect(lex.canonicalID(for: "양송기") == "button-mushroom")
    }

    /// **소비기한 폴백 체인(41차)** — fridge가 null인 건조·상온 식품(소금·파스타)이 냉장 선택 시
    /// nil로 떨어지면 등록 경로의 D+3 최후 폴백이 "소금이 3일 뒤 임박"을 만든다.
    /// fridge → pantry → room 순으로 폴백해 사전이 아는 값이 반드시 나온다.
    @Test func shelfLifeFallsBackThroughPantryWhenFridgeIsNull() {
        let salt = lex.shelfLifeDays(for: "소금", storage: .fridge)
        #expect(salt != nil && salt! > 365, "소금 냉장 기본값이 pantry로 폴백돼야 한다(D+3 방지)")
        let pasta = lex.shelfLifeDays(for: "파스타", storage: .fridge)
        #expect(pasta != nil && pasta! > 100, "파스타도 동일 — 건조식품은 냉장에서도 장기 보관이다")
    }
}

/// 추천 매칭 — canonical ID 동일성 원칙(부분문자열 오탐 금지)·랭킹.
struct RecommenderTests {

    private func recipe(id: String, refs: [String], en: [String]) -> Recipe {
        Recipe(id: id,
               name: Recipe.LocalizedName(en: id, ko: nil),
               cuisine: nil, minutes: 10,
               ingredients: zip(refs, en).map { Recipe.Item(ref: $0.0.isEmpty ? nil : $0.0, en: $0.1, ko: nil) },
               steps: Recipe.LocalizedSteps(en: ["step"], ko: nil),
               isUser: nil)
    }

    private func ing(_ name: String, daysLeft: Int = 3) -> Ingredient {
        Ingredient(name: name, category: "Veg", daysLeft: daysLeft,
                   quantity: Quantity(value: 1, unit: .piece), glyph: .generic)
    }

    @Test func noSubstringFalsePositives() {
        // 대파(green-onion)는 onion 항목에 매칭되면 안 된다 — 발주 = 재고 소비라 오탐은 데이터 파괴.
        let onionItem = Recipe.Item(ref: "onion", en: "onion", ko: nil)
        #expect(!RecipeRecommender.matches(ing("대파"), onionItem))
        #expect(RecipeRecommender.matches(ing("양파"), onionItem))
        // Pineapple ↔ Apple 유형의 교차 오탐도 차단.
        let appleItem = Recipe.Item(ref: "apple", en: "apple", ko: nil)
        #expect(!RecipeRecommender.matches(ing("pineapple"), appleItem))
    }

    /// **시드 ref 전수 무결성(41차)** — ref는 사전 조회 없이 그대로 신뢰되므로(`canonicalID(of:)`),
    /// 오타 ref는 크래시 없이 영구 미매칭으로만 남는다. 시드에 레시피를 추가할 때마다 이 테스트가
    /// 고아 ref를 잡는다.
    @Test func seedRefsAllResolveInLexicon() {
        let recipes = RecipeCatalog.loadSeed()
        #expect(recipes.count >= 120, "시드가 통째로 로드 실패하면 여기서 먼저 죽는다")
        let lex = IngredientLexicon.shared
        for r in recipes {
            for item in r.ingredients {
                guard let ref = item.ref else { continue }
                #expect(lex.entry(id: ref) != nil, "\(r.id): 고아 ref '\(ref)' (\(item.en))")
            }
        }
    }

    /// **미역·김 ref 회귀(41차)** — 시드에서 4줄이 통째로 뒤바뀌어 '김'을 등록한 사용자가
    /// 미역국을 추천받았다. 표기와 ref가 같은 재료를 가리키는지 데이터로 고정한다.
    @Test func seedSeaweedAndGimRefsAreNotSwapped() throws {
        let recipes = RecipeCatalog.loadSeed()
        let gimbap = try #require(recipes.first { $0.id == "gimbap" })
        let gimLine = try #require(gimbap.ingredients.first { $0.en.lowercased().contains("gim") })
        #expect(gimLine.ref == "dried-seaweed", "김밥의 김은 dried-seaweed(김)다")
        let miyeokGuk = try #require(recipes.first { $0.id == "miyeok-guk" })
        let miyeokLine = try #require(miyeokGuk.ingredients.first { $0.en.lowercased().contains("seaweed") })
        #expect(miyeokLine.ref == "seaweed", "미역국의 미역은 seaweed(미역)다")
    }

    /// **커스텀 레시피 ref는 정확·머리말 일치까지만(41차)** — 포함 매칭으로 ref를 붙이면
    /// "감자 전분"이 potato가 되어 발주 시 감자 재고가 예약·삭제된다. 해석 실패는 nil이 정답이다
    /// (표기 정확 일치 매칭이 받는다 — 잘못된 캐논보다 안전한 실패).
    @Test func userRecipeRefUsesExactOrHeadNounOnly() {
        let r = Recipe.userRecipe(name: "테스트",
                                  ingredientNames: ["감자 전분", "양파", "서울우유1L"], minutes: 10)
        #expect(r.ingredients[0].ref == "starch", "머리말(전분)이 재료다 — potato 오귀속 금지")
        #expect(r.ingredients[1].ref == "onion")
        #expect(r.ingredients[2].ref == nil, "용량 붙은 실표기는 포함 매칭 없이 nil로 남긴다(안전한 실패)")
    }

    /// **채식 필터의 animal 플래그(41차)** — 스팸(글리프 can)·액젓(sauceBottle)처럼 글리프가
    /// Meat/Seafood 계열이 아닌 동물성 재료는 사전의 `animal: true`가 잡는다.
    @Test func vegetarianFilterCatchesAnimalFlaggedEntries() {
        let spamDish = recipe(id: "spam-dish", refs: ["spam"], en: ["spam"])
        let fishSauceDish = recipe(id: "fish-sauce-dish", refs: ["fish-sauce"], en: ["fish sauce"])
        let tofuDish = recipe(id: "tofu-dish", refs: ["tofu"], en: ["tofu"])
        let stock = [ing("스팸"), ing("멸치액젓"), ing("두부")]
        let veg = RecipePreferences(cuisines: [], favoriteIDs: [], dislikedIDs: [],
                                    allergenIDs: [], vegetarian: true)
        let ids = RecipeRecommender.rank(for: stock, from: [spamDish, fishSauceDish, tofuDish],
                                         preferences: veg).map(\.id)
        #expect(!ids.contains("spam-dish"), "스팸은 글리프(can)로는 안 걸린다 — animal 플래그가 잡아야 한다")
        #expect(!ids.contains("fish-sauce-dish"), "액젓도 동일(sauceBottle)")
        #expect(ids.contains("tofu-dish"))
    }

    /// **총칭 매칭은 단방향(44차)** — 구체 재고(팽이버섯)는 총칭 레시피(버섯)를 채우고,
    /// 총칭 재고는 구체 전용 레시피(표고)를 채우지 못한다. 방향이 뒤집히면 발주가 엉뚱한 재고를
    /// 소비한다(사전 `parent` 필드가 정본).
    @Test func specificIngredientSatisfiesGenericRecipeLineOneWay() {
        let generic = Recipe.Item(ref: "mushroom", en: "mushrooms", ko: "버섯")
        #expect(RecipeRecommender.matches(ing("팽이버섯"), generic))
        #expect(RecipeRecommender.matches(ing("표고버섯"), generic))
        let specific = Recipe.Item(ref: "shiitake", en: "shiitake", ko: "표고버섯")
        #expect(!RecipeRecommender.matches(ing("모둠버섯"), specific), "총칭이 구체를 채우면 안 된다")
        // 부위·형태에도 같은 축: 삼겹살은 '돼지고기' 레시피를 채운다(김치찌개가 실사용 사례).
        #expect(RecipeRecommender.matches(ing("삼겹살"), Recipe.Item(ref: "pork", en: "pork", ko: "돼지고기")))
        #expect(RecipeRecommender.matches(ing("닭가슴살"), Recipe.Item(ref: "chicken", en: "chicken", ko: "닭고기")))
        // 가향유는 일부러 parent가 없다 — 우유 레시피에 딸기우유가 들어가면 다른 음식이 된다.
        #expect(!RecipeRecommender.matches(ing("딸기우유"), Recipe.Item(ref: "milk", en: "milk", ko: "우유")))
    }

    /// **한계이득 덱(45차)** — 같은 임박 재고를 무는 티켓이 나란히 서지 않는다. 예전 점수순 소비는
    /// 최고점 셋이 같은 소고기 한 덩이를 물었다("세 가지 선택지"처럼 보이지만 한 장을 발주하면
    /// 나머지 둘의 전제가 무너진다). 이제 한 장을 고를 때마다 덮인 재고의 가중치를 0으로 보고
    /// 재정렬한다 — 방치되던 연어 티켓이 두 번째 소고기 티켓보다 앞선다.
    @Test func deckDiversifiesByMarginalGain() {
        let beefA = recipe(id: "beef-a", refs: ["beef"], en: ["beef"])
        let beefB = recipe(id: "beef-b", refs: ["beef"], en: ["beef"])
        let salmon = recipe(id: "salmon-c", refs: ["salmon"], en: ["salmon"])
        let stock = [ing("소고기", daysLeft: 0), ing("연어", daysLeft: 1)]
        let ids = RecipeRecommender.rank(for: stock, from: [beefA, beefB, salmon]).map(\.id)
        #expect(ids == ["beef-a", "salmon-c", "beef-b"],
                "소고기(3점) 두 장이 연어(2점)를 사이에 두고 갈라져야 한다 — 두 번째 소고기의 한계이득은 0이다")
    }

    /// **오늘 요리 핀(47차)** — 핀 재료를 쓰는 티켓은 임박도만으로는 뒤집히지 않는다.
    /// 가점(+4)이 freshness 최고 한 단(urgent 3)보다 큰 이유가 이 테스트다: fresh(1)+핀(4)=5 >
    /// urgent(3). 이게 성립하지 않으면 오른쪽 존은 "꽂아도 덱이 안 바뀌는" 위약이 된다.
    @Test func pinnedStockLiftsItsTicketAboveFresherOnes() {
        let beefDish = recipe(id: "beef-dish", refs: ["beef"], en: ["beef"])
        let carrotDish = recipe(id: "carrot-dish", refs: ["carrot"], en: ["carrot"])
        let beef = ing("소고기", daysLeft: 0)    // urgent 3 — 임박도의 최대치
        let carrot = ing("당근", daysLeft: 9)    // fresh 1 — 임박도의 최소치
        // 무핀 기준선 — 임박도가 순서를 정한다.
        #expect(RecipeRecommender.rank(for: [beef, carrot], from: [beefDish, carrotDish])
            .first?.id == "beef-dish")
        // 당근 핀 — 가장 신선한 재료의 티켓이 가장 임박한 재료의 티켓을 넘는다.
        let pinned = RecipeRecommender.rank(for: [beef, carrot], from: [beefDish, carrotDish],
                                            pinnedIDs: [carrot.id])
        #expect(pinned.first?.id == "carrot-dish",
                "핀(+4)이 urgent(3)를 못 이기면 '고정'이 아니라 위약이다")
    }

    /// **핀은 점수 경쟁이 아니라 자리 보장이다(47차 실측 마감)** — 점수 가산(+4)만으로는 재고
    /// 4종을 무는 임박 티켓(8점)이 핀 연어 티켓(2+4=6점)을 그대로 눌렀다(시뮬 실측: 연어를
    /// 핀했는데 덱 1번이 여전히 비빔밥). 미커버 핀 재료를 쓰는 티켓이 덱 선발에서 **사전식
    /// 1순위 키**를 갖는다 — 점수 차가 아무리 커도 핀 티켓이 맨 앞이다.
    @Test func pinnedTicketTakesTheFrontEvenAgainstBigTickets() {
        let feast = recipe(id: "feast", refs: ["beef", "spinach", "egg", "carrot"],
                           en: ["beef", "spinach", "egg", "carrot"])
        let salmonDish = recipe(id: "salmon-dish", refs: ["salmon"], en: ["salmon"])
        let stock = [ing("소고기", daysLeft: 0), ing("시금치", daysLeft: 1),
                     ing("계란", daysLeft: 2), ing("당근", daysLeft: 4),
                     ing("연어", daysLeft: 8)]
        // 무핀 기준선 — 4재료 임박 티켓이 앞선다.
        #expect(RecipeRecommender.rank(for: stock, from: [feast, salmonDish]).first?.id == "feast")
        let pinned = RecipeRecommender.rank(for: stock, from: [feast, salmonDish],
                                            pinnedIDs: [stock[4].id])
        #expect(pinned.first?.id == "salmon-dish",
                "핀 재료를 쓰는 티켓이 점수와 무관하게 덱 맨 앞이어야 '고정'이다")
        // 핀이 덮인 뒤의 나머지 덱은 종전 규칙 그대로다.
        #expect(pinned.dropFirst().first?.id == "feast")
    }

    /// **핀 파리티(47차)** — `pinnedIDs` 기본값(빈 집합)이면 결과가 종전과 완전히 같다.
    /// deckDiversifiesByMarginalGain 픽스처를 그대로 재사용해 파라미터 추가가 무핀 경로의
    /// 답(순서까지)을 바꾸지 않았음을 고정한다 — 기존 호출부·테스트 전부가 이 동치에 기대 무수정이다.
    @Test func emptyPinnedIDsMatchBaselineDeck() {
        let beefA = recipe(id: "beef-a", refs: ["beef"], en: ["beef"])
        let beefB = recipe(id: "beef-b", refs: ["beef"], en: ["beef"])
        let salmon = recipe(id: "salmon-c", refs: ["salmon"], en: ["salmon"])
        let stock = [ing("소고기", daysLeft: 0), ing("연어", daysLeft: 1)]
        let base = RecipeRecommender.rank(for: stock, from: [beefA, beefB, salmon]).map(\.id)
        let explicitEmpty = RecipeRecommender.rank(for: stock, from: [beefA, beefB, salmon],
                                                   pinnedIDs: []).map(\.id)
        #expect(base == ["beef-a", "salmon-c", "beef-b"])   // 45차 기준선 그대로
        #expect(explicitEmpty == base, "빈 핀 집합은 무핀과 동치여야 한다(파리티)")
    }

    /// **핀 가점도 한계화(47차)** — `marginalGainRecomputesPreferenceBonuses`와 같은 축.
    /// 핀 재고를 이미 덮은 중복 티켓이 +4를 상수로 물고 서면, 핀 하나에 같은 재료 티켓들이
    /// 덱을 도배하며 D-1 연어를 유일하게 구하는 티켓을 밀어낸다 — 그리디가 고치려던 바로 그
    /// 증상이 핀이 켜지는 경로에서만 재발한다.
    @Test func marginalGainRecomputesPinBonus() {
        let a = recipe(id: "a-covers", refs: ["beef", "onion", "carrot"],
                       en: ["beef", "onion", "carrot"])
        let b = recipe(id: "b-duplicate", refs: ["beef", "onion", "carrot"],
                       en: ["beef", "onion", "carrot"])
        let c = recipe(id: "c-rescues-salmon", refs: ["salmon"], en: ["salmon"])
        let beef = ing("소고기", daysLeft: 0)
        let stock = [beef, ing("양파", daysLeft: 9), ing("당근", daysLeft: 9),
                     ing("연어", daysLeft: 1)]
        // 소고기 핀: a·b 원점수 3+1+1+4=9, c는 2. 상수 유지 버그라면 b(9 또는 +4 잔존)가
        // c(2)를 앞선다 — 한계화가 맞으면 b의 이득은 0으로 접힌다.
        let ids = RecipeRecommender.rank(for: stock, from: [a, b, c],
                                         pinnedIDs: [beef.id]).map(\.id)
        #expect(ids == ["a-covers", "c-rescues-salmon", "b-duplicate"],
                "중복 티켓의 핀 가점은 미커버 기준으로 0이어야 한다 — 연어 티켓이 2번 자리를 가져간다")
    }

    /// **대체 그래프(45차)** — 생크림 재고가 우유 줄을 채운다(사전 subs `cream→milk`, 일방향).
    /// 대체 티켓은 감점을 받아 정품 매칭 티켓보다 항상 뒤에 서고, 레시피 이름이 그 재료를 부르면
    /// (우유푸딩의 milk 줄) 대체를 잠근다 — 사용자가 즉시 알아채는 종류의 거짓 방지.
    @Test func substitutionFillsMissingWithPenaltyAndTitleGuard() {
        // 픽스처 이름에 재료명을 넣으면 제목 가드가 (정확하게) 대체를 잠근다 — 중립 이름을 쓴다.
        let needsMilk = recipe(id: "bechamel", refs: ["milk"], en: ["milk"])
        let needsCream = recipe(id: "panna", refs: ["cream"], en: ["cream"])
        let stock = [ing("생크림", daysLeft: 2)]
        let results = RecipeRecommender.rank(for: stock, from: [needsMilk, needsCream])
        #expect(results.map(\.id) == ["panna", "bechamel"], "정품 매칭이 대체보다 앞선다(감점)")
        let milkResult = results.first { $0.id == "bechamel" }!
        #expect(milkResult.missing.isEmpty, "생크림이 milk 줄을 대체로 채운다")
        #expect(milkResult.substituted.count == 1)
        #expect(milkResult.used.contains { $0.name == "생크림" }, "대체 투입분은 used에 들어가 발주 시 소비된다")
        // 제목 가드 — 이름이 우유를 부르는 요리의 milk 줄은 잠긴다.
        var titled = recipe(id: "milk-pudding", refs: ["milk"], en: ["milk"])
        titled.name = Recipe.LocalizedName(en: "Milk Pudding", ko: "우유푸딩")
        let guarded = RecipeRecommender.result(for: titled, ingredients: stock)
        #expect(guarded.substituted.isEmpty && guarded.missing.count == 1,
                "우유푸딩의 우유는 생크림으로 대신하지 않는다")
    }

    /// **레시피 명시 대체(altRefs, 45차)** — "pork (or beef)"가 산문으로만 들고 있던 지식의 구조화.
    /// 소고기 재고가 그 줄을 채우고(감점 없음 — 저자가 동급이라 했다), 알레르기는 any-of 전체를 본다.
    @Test func altRefsMatchAndTriggerAllergens() throws {
        let seedRecipes = RecipeCatalog.loadSeed()
        let curry = try #require(seedRecipes.first { $0.id == "japanese-curry-rice" })
        let porkLine = try #require(curry.ingredients.first { $0.en.lowercased().hasPrefix("pork") })
        #expect(porkLine.altRefs == ["beef"], "시드 변환이 괄호 대체어를 altRefs로 구조화했다")
        #expect(RecipeRecommender.matches(ing("소고기"), porkLine), "소고기가 pork(or beef) 줄을 채운다")
        // 알레르기 보수 판정 — 대체 캐논도 알레르겐 검사에 걸린다.
        let beefAllergy = RecipePreferences(cuisines: [], favoriteIDs: [],
                                            dislikedIDs: [], allergenIDs: ["beef"])
        let stock = [ing("돼지고기", daysLeft: 1), ing("양파", daysLeft: 2), ing("감자", daysLeft: 3)]
        let ids = RecipeRecommender.rank(for: stock, from: seedRecipes, preferences: beefAllergy).map(\.id)
        #expect(!ids.contains("japanese-curry-rice"), "or beef 줄은 소고기 알레르기에 걸린다(안전 P0)")
    }

    /// **선택 줄(optional, 45차)** — 없어도 요리가 성립하는 줄은 부족을 만들지 않는다.
    /// 있으면 그만인 재료가 missing 문턱(3)을 앞당겨 티켓을 덱에서 밀어내던 결함의 마감.
    @Test func optionalLinesDoNotCountAsMissing() {
        var r = recipe(id: "opt-dish", refs: ["tofu", "egg"], en: ["tofu", "boiled eggs (optional)"])
        r.ingredients[1].optional = true
        let result = RecipeRecommender.result(for: r, ingredients: [ing("두부", daysLeft: 1)])
        #expect(result.missing.isEmpty, "선택 줄은 부족이 아니다")
        #expect(result.total == 2, "분모(비상비 줄 수)에는 그대로 선다")
        // 있으면 정상 참여한다.
        let with = RecipeRecommender.result(for: r, ingredients: [ing("두부", daysLeft: 1),
                                                                  ing("계란", daysLeft: 2)])
        #expect(with.used.count == 2)
    }

    /// **커버리지 래칫(45차)** — "이 재료만 가진 냉장고가 추천 0장"인 비상비 캐논 수가 늘지 못하게
    /// 못 박는다(엔진 실측 기준선 89종 — parent 승격·altRefs·대체 간선 리프트 포함, 잔여는 대부분
    /// 그냥 먹는 과일·즉석식품). 사전에 항목을 더할 때 이 수가 늘면 여기서 깨진다 — 사전만 커지고
    /// 레시피가 못 따라오면 빈 덱 확률만 올라간다는 41차 실측의 CI 고정.
    /// 판정은 문서가 아니라 **실제 엔진**(rank — parent·altRefs·대체가 전부 작동하는 경로)으로 한다.
    @Test func coverageOrphanCountDoesNotGrow() {
        let seedRecipes = RecipeCatalog.loadSeed()
        let lexEntries = IngredientLexicon.shared.entries
        var orphans: [String] = []
        for entry in lexEntries where !entry.staple {
            let stock = [Ingredient(name: entry.displayName, category: "t",
                                    daysLeft: 1, quantity: Quantity(value: 1, unit: .piece),
                                    glyph: .generic)]
            var probe = stock[0]
            probe.canonicalID = entry.id
            let results = RecipeRecommender.rank(for: [probe], from: seedRecipes)
            if results.isEmpty { orphans.append(entry.id) }
        }
        #expect(orphans.count <= 89,
                "레시피 0장 재료가 \(orphans.count)종으로 늘었다(기준 89): \(orphans.prefix(12))…")
    }

    /// **역색인 파리티(45차)** — rank의 벌크 경로(bulkResults)는 result(for:) 기준 경로와 의미가
    /// 같아야 한다. 시드 전수 × 냉장고 여럿에서 두 경로의 최종 덱이 일치함을 고정한다 —
    /// 빨라진 경로가 조용히 다른 답을 내기 시작하면 여기서 즉시 깨진다.
    @Test func bulkRankMatchesReferencePipeline() {
        let seedRecipes = RecipeCatalog.loadSeed()
        let fridges: [[Ingredient]] = [
            [ing("소고기", daysLeft: 0), ing("시금치", daysLeft: 1), ing("계란", daysLeft: 2),
             ing("양파", daysLeft: 4), ing("우유", daysLeft: 6)],
            [ing("두부", daysLeft: 1), ing("김치", daysLeft: 30), ing("대파", daysLeft: 3)],
            [ing("팽이버섯", daysLeft: 2), ing("닭가슴살", daysLeft: 1), ing("밥알수없는것", daysLeft: 5)],
            [ing("연어", daysLeft: 1), ing("브로콜리", daysLeft: 3), ing("파스타면", daysLeft: 200),
             ing("방울토마토", daysLeft: 2)],
        ]
        for stock in fridges {
            let fast = RecipeRecommender.rank(for: stock, from: seedRecipes).map(\.id)
            let slow = RecipeRecommender.prune(
                seedRecipes
                    .map { RecipeRecommender.result(for: $0, ingredients: stock) }
                    .filter { !$0.used.isEmpty }
                    .map { (result: $0, score: $0.used.reduce(0) { $0 + RecipeRecommender.weight($1) }
                                              - RecipeRecommender.substitutionPenalty * $0.substituted.count) }
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
            ).map(\.id)
            #expect(fast == slow, "냉장고 \(stock.map(\.name)): 벌크와 기준 경로의 덱이 갈렸다")
        }
    }

    @Test func urgencyWeightsRanking() {
        let r1 = recipe(id: "uses-urgent", refs: ["beef"], en: ["beef"])
        let r2 = recipe(id: "uses-fresh", refs: ["carrot"], en: ["carrot"])
        let stock = [ing("소고기", daysLeft: 0), ing("당근", daysLeft: 9)]
        let ranked = RecipeRecommender.rank(for: stock, from: [r2, r1])
        #expect(ranked.first?.id == "uses-urgent")   // urgent(3) > fresh(1)
    }

    // MARK: 커버리지 점검 — 덱이 못 다룬 오늘 만료 재료(영상 브리지의 판별 근거)

    @Test func uncoveredUrgentSkipsIngredientsSomeTicketUses() {
        // 티켓이 실제로 쓰는 urgent 재료는 미커버가 아니다 — 덱이 이미 답을 주고 있다.
        let r = recipe(id: "beef-dish", refs: ["beef"], en: ["beef"])
        let stock = [ing("소고기", daysLeft: 0)]
        let results = RecipeRecommender.rank(for: stock, from: [r])
        #expect(results.count == 1)
        #expect(RecipeRecommender.uncoveredUrgent(ingredients: stock, results: results).isEmpty)
    }

    @Test func uncoveredUrgentReportsIngredientNoTicketUses() {
        // 덱은 살아 있는데(소고기 티켓) 오늘 만료 두부는 어느 티켓에도 없다 — 배너만 압박하고
        // 티켓은 침묵하는 그 상태가 정확히 브리지 행이 말해야 하는 것이다.
        let r = recipe(id: "beef-dish", refs: ["beef"], en: ["beef"])
        let beef = ing("소고기", daysLeft: 0)
        let tofu = ing("두부", daysLeft: 0)
        let results = RecipeRecommender.rank(for: [beef, tofu], from: [r])
        let uncovered = RecipeRecommender.uncoveredUrgent(ingredients: [beef, tofu], results: results)
        #expect(uncovered.map(\.name) == ["두부"])
    }

    @Test func uncoveredUrgentExcludesFreshAndSoon() {
        // urgent만 호명한다 — soon·fresh까지 세면 브리지 행이 상시 표시돼 경고가 배경이 된다.
        let r = recipe(id: "beef-dish", refs: ["beef"], en: ["beef"])
        let stock = [ing("소고기", daysLeft: 0), ing("당근", daysLeft: 2), ing("감자", daysLeft: 9)]
        let results = RecipeRecommender.rank(for: stock, from: [r])
        #expect(RecipeRecommender.uncoveredUrgent(ingredients: stock, results: results).isEmpty)
    }

    @Test func uncoveredUrgentReportsEverythingWhenDeckIsEmpty() {
        // 극단(덱 0장) — 모든 urgent가 미커버다. 순서는 입력(마감 임박순) 그대로 유지된다.
        let stock = [ing("두부", daysLeft: 0), ing("계란", daysLeft: -1), ing("당근", daysLeft: 5)]
        let uncovered = RecipeRecommender.uncoveredUrgent(ingredients: stock, results: [])
        #expect(uncovered.map(\.name) == ["두부", "계란"])
    }

    @Test func staplesExcludedFromMissing() {
        let r = recipe(id: "soup", refs: ["beef", "salt"], en: ["beef", "salt"])
        let result = RecipeRecommender.result(for: r, ingredients: [ing("소고기", daysLeft: 1)])
        #expect(result.missing.isEmpty)   // salt는 상비재 — 부족으로 표기하지 않는다
        #expect(result.total == 1)
    }

    @Test func customTextMatchesExactOnly() {
        // 사전 밖 커스텀 표기는 정확 일치만 — 부분문자열 매칭 금지.
        let custom = Recipe.Item(ref: nil, en: "homemade chili paste", ko: nil)
        #expect(!RecipeRecommender.matches(ing("chili"), custom))
        #expect(RecipeRecommender.matches(ing("homemade chili paste"), custom))
    }

    @Test func noRefDescriptiveLineNeverContainsMatches() {
        // 시드의 no-ref 서술형 라인("chicken or vegetable stock")이 포함 매칭으로
        // chicken에 붙으면 발주가 실재고 닭고기를 소비한다 — 정확 일치만 허용해야 한다.
        let stock = Recipe.Item(ref: nil, en: "chicken or vegetable stock (kept warm)", ko: nil)
        #expect(RecipeRecommender.canonicalID(of: stock) == nil)
        #expect(!RecipeRecommender.matches(ing("chicken"), stock))
        #expect(!RecipeRecommender.matches(ing("닭고기"), stock))
        // ref가 있으면 그대로 신뢰.
        let chicken = Recipe.Item(ref: "chicken", en: "chicken thigh", ko: nil)
        #expect(RecipeRecommender.matches(ing("닭고기"), chicken))
    }

    // MARK: - 부족 재료 과다 레시피 제외 (덱은 '지금 비우는 요리'만)

    /// 경계 정확도 — 2개 부족은 남고 **3개부터 탈락**한다. 이 숫자가 흔들리면 덱의 성격이 바뀐다
    /// (장 봐야 하는 레시피가 오늘 상해가는 재료를 밀어낸다).
    @Test func rankDropsRecipesMissingThreeOrMore() {
        // 재고는 소고기 하나. 나머지 재료 수만 늘려 부족 개수를 0/1/2/3으로 만든다.
        let stock = [resolvedIng("소고기", daysLeft: 0)]
        let none = recipe(id: "miss0", refs: ["beef"], en: ["beef"])
        let one = recipe(id: "miss1", refs: ["beef", "carrot"], en: ["beef", "carrot"])
        let two = recipe(id: "miss2", refs: ["beef", "carrot", "onion"],
                         en: ["beef", "carrot", "onion"])
        let three = recipe(id: "miss3", refs: ["beef", "carrot", "onion", "egg"],
                           en: ["beef", "carrot", "onion", "egg"])
        let ranked = RecipeRecommender.rank(for: stock, from: [none, one, two, three])
        let ids = ranked.map(\.id)
        #expect(ids.contains("miss0"))
        #expect(ids.contains("miss1"))
        #expect(ids.contains("miss2"), "부족 2개는 경계 안 — 남아야 한다")
        #expect(!ids.contains("miss3"), "부족 3개는 경계 밖 — 덱에서 빠져야 한다")
        // 남은 티켓의 missing 계산 자체는 그대로다(Short 줄·담기 칩이 쓴다).
        #expect(ranked.first(where: { $0.id == "miss2" })?.missing.count == 2)
    }

    /// **후보가 있으면 덱은 비지 않는다.** 제외 규칙은 더 나은 티켓에 자리를 내주라는 것이지,
    /// 보여 줄 게 없어도 빈 화면을 내라는 것이 아니다. 재료가 1~3종뿐인 냉장고(신규 사용자)에서는
    /// 문턱 ①(`clearedCount >= missing.count`)이 구조적으로 못 넘겨져 후보가 전부 탈락한다.
    @Test func rankNeverReturnsEmptyWhileCandidatesExist() {
        let stock = [resolvedIng("소고기", daysLeft: 0)]
        let heavy = recipe(id: "heavy", refs: ["beef", "carrot", "onion", "egg"],
                           en: ["beef", "carrot", "onion", "egg"])
        #expect(RecipeRecommender.rank(for: stock, from: [heavy]).map(\.id) == ["heavy"],
                "제외 규칙에 다 걸려도 덱 장수만큼은 점수 순으로 채워야 한다")
    }

    /// 바닥은 **덱 장수까지만** 채운다 — 통과한 티켓이 이미 충분하면 탈락분이 따라 들어오지 않는다.
    @Test func rankFloorDoesNotResurrectDropsOnceTheDeckIsFull() {
        let stock = [resolvedIng("소고기", daysLeft: 0), resolvedIng("당근", daysLeft: 1),
                     resolvedIng("양파", daysLeft: 2), resolvedIng("감자", daysLeft: 3)]
        let light = (1...3).map { i in
            recipe(id: "light\(i)", refs: ["beef", "carrot"], en: ["beef", "carrot"])
        }
        let heavy = recipe(id: "heavy", refs: ["beef", "bean-sprouts", "zucchini", "garlic"],
                           en: ["beef", "bean sprouts", "zucchini", "minced garlic"])
        let ids = RecipeRecommender.rank(for: stock, from: light + [heavy]).map(\.id)
        #expect(!ids.contains("heavy"), "통과한 티켓이 덱 장수를 채우면 탈락분은 살아나지 않는다")
    }

    /// 덱 바닥(`deckSize`)이 탈락분을 되살리지 않도록 **통과 티켓으로 덱을 채우는 들러리**.
    /// 제외 규칙만 따로 보려면 통과분이 덱 장수를 채워야 한다 — 안 그러면 바닥이 탈락분을 끌어올려
    /// "빠져야 할 티켓이 보인다"가 되고, 그건 규칙이 아니라 바닥을 보는 것이다.
    private func fillers(_ refs: [String], count: Int = 3) -> [Recipe] {
        (0..<count).map { recipe(id: "filler\($0)", refs: refs, en: refs) }
    }

    /// 같은 캐논을 다른 표기 두 줄로 등록해 둔 사용자에게 문턱이 공짜로 낮아지면 안 된다.
    /// (`양파`·`적양파`는 사전상 둘 다 `onion` — 이름 편집만으로 한 로케일에서도 만들어진다.)
    @Test func rankCountsCanonicalIdentityNotWrittenName() {
        let stock = [resolvedIng("양파", daysLeft: 1), resolvedIng("적양파", daysLeft: 1),
                     resolvedIng("감자", daysLeft: 1)]
        // 재고 3줄이지만 실제 소진 재료는 2종(onion·potato) → 부족 3개를 못 넘긴다.
        let plan = recipe(id: "plan", refs: ["onion", "potato", "beef", "carrot", "spinach"],
                          en: ["onion", "potato", "beef", "carrot", "spinach"])
        let easy = recipe(id: "easy", refs: ["onion", "potato"], en: ["onion", "potato"])
        let ids = RecipeRecommender.rank(for: stock, from: [plan, easy] + fillers(["onion"], count: 2)).map(\.id)
        #expect(ids.contains("easy"))
        #expect(!ids.contains("plan"),
                "표기만 다른 같은 캐논 두 줄이 '서로 다른 재료 2종'으로 세어지면 안 된다")
    }

    @Test func missingCountStillComputedForExcludedRecipes() {
        // 제외는 **덱 구성 단계**에서만 한다 — `result(for:)`는 그대로 전부 계산한다.
        let stock = [resolvedIng("소고기", daysLeft: 0)]
        let heavy = recipe(id: "heavy", refs: ["beef", "carrot", "onion", "egg"],
                           en: ["beef", "carrot", "onion", "egg"])
        #expect(RecipeRecommender.result(for: heavy, ingredients: stock).missing.count == 3)
    }

    /// 제외 기준의 **예외** — 임박 재료를 혼자 다루면서 채우는 게 사는 것보다 적지 않으면 남는다.
    ///
    /// 이 예외가 없으면 재고를 4종 소진하는 티켓이 부족 3개라는 이유만으로 사라지고, 그 티켓만
    /// 쓰던 임박 재료는 어느 티켓에도·어느 브리지에도 남지 않는다(커버리지 브리지는 urgent만
    /// 호명하므로 soon 재료는 이름조차 불리지 않는다). 배너는 "위험"이라 압박하는데 화면 어디에도
    /// 행동 경로가 없는 상태가 된다.
    @Test func rankKeepsHeavyTicketThatAloneRescuesAtRiskStock() {
        // 재고 4종(전부 임박) 중 시금치는 `clearsSpinach`만 쓴다.
        let stock = [resolvedIng("시금치", daysLeft: 1), resolvedIng("소고기", daysLeft: 0),
                     resolvedIng("당근", daysLeft: 2), resolvedIng("계란", daysLeft: 2)]
        // 부족 3개지만 재고를 4종 소진한다 — 채우는 게 사는 것보다 많다.
        let clearsSpinach = recipe(id: "clears", refs: ["spinach", "beef", "carrot", "egg",
                                                        "bean-sprouts", "zucchini", "garlic"],
                                   en: ["spinach", "beef", "carrot", "egg",
                                        "bean sprouts", "zucchini", "minced garlic"])
        // 재고는 소고기 하나만 쓰면서 3종을 사야 한다 — 장보기 계획이라 예외를 못 받는다.
        let shoppingPlan = recipe(id: "plan", refs: ["beef", "bean-sprouts", "zucchini", "garlic"],
                                  en: ["beef", "bean sprouts", "zucchini", "minced garlic"])
        // 들러리 둘은 시금치를 건드리지 않는다 — clears의 "혼자 구해 낸다"가 흐려지지 않게.
        let deck = [clearsSpinach, shoppingPlan] + [recipe(id: "filler0", refs: ["beef"], en: ["beef"]),
                                                    recipe(id: "filler1", refs: ["egg"], en: ["egg"])]
        let ids = RecipeRecommender.rank(for: stock, from: deck).map(\.id)
        #expect(ids.contains("clears"), "재고 4종을 소진하며 시금치를 혼자 다루는 티켓은 남아야 한다")
        #expect(!ids.contains("plan"), "재고 1종에 3종을 사야 하는 티켓은 덱에 오를 자격이 없다")
    }

    /// 같은 임박 재료를 이미 덮은 뒤라면 무거운 티켓은 더 남을 이유가 없다 — 예외는 **한 번만** 쓴다.
    ///
    /// 무게 조건(`used >= missing`)은 **통과시켜 놓고** 커버리지 조건만으로 탈락시킨다 — 그래야
    /// `rescuesSomethingNew`를 지웠을 때 이 테스트가 실제로 깨진다(무게 조건만 남으면 통과해 버린다).
    @Test func rankDropsHeavyTicketOnceItsAtRiskStockIsAlreadyCovered() {
        let stock = [resolvedIng("소고기", daysLeft: 0), resolvedIng("당근", daysLeft: 1),
                     resolvedIng("양파", daysLeft: 9), resolvedIng("감자", daysLeft: 9)]
        // light는 같은 4종을 쓰면서 살 게 없다 — 점수가 같고 부족이 적어 **먼저** 선다(tie-break).
        let light = recipe(id: "light", refs: ["beef", "carrot", "onion", "potato"],
                           en: ["beef", "carrot", "onion", "potato"])
        // 재고 4종을 쓰고 3종을 사므로 무게 조건은 통과한다. 그런데 임박(소고기·당근)은 light가
        // 이미 덮었고 나머지(양파·감자)는 fresh라 새로 구해 내는 것이 없다 → 탈락해야 한다.
        let heavy = recipe(id: "heavy",
                           refs: ["beef", "carrot", "onion", "potato", "egg", "spinach", "tofu"],
                           en: ["beef", "carrot", "onion", "potato", "egg", "spinach", "tofu"])
        let deck = [light, heavy] + [recipe(id: "filler0", refs: ["beef"], en: ["beef"]),
                                     recipe(id: "filler1", refs: ["carrot"], en: ["carrot"])]
        let ids = RecipeRecommender.rank(for: stock, from: deck).map(\.id)
        #expect(ids.contains("light"))
        #expect(!ids.contains("heavy"), "임박 재료를 앞 티켓이 이미 덮었으면 무거운 티켓은 빠진다")
    }

    /// 무게 조건도 단독으로 검증한다 — 임박 재료를 혼자 구해 내도 사는 게 더 많으면 못 남는다.
    @Test func rankDropsHeavyTicketThatBuysMoreThanItClears() {
        let stock = [resolvedIng("시금치", daysLeft: 1)]
        let plan = recipe(id: "plan", refs: ["spinach", "beef", "carrot", "onion"],
                          en: ["spinach", "beef", "carrot", "onion"])
        // 부족 1~2개짜리 들러리로 덱을 채워 바닥이 안 돌게 한다.
        let deck = [plan, recipe(id: "f0", refs: ["spinach", "beef"], en: ["spinach", "beef"]),
                    recipe(id: "f1", refs: ["spinach", "carrot"], en: ["spinach", "carrot"]),
                    recipe(id: "f2", refs: ["spinach", "onion"], en: ["spinach", "onion"])]
        #expect(!RecipeRecommender.rank(for: stock, from: deck).map(\.id).contains("plan"),
                "재고 1종에 3종을 사야 하는 티켓은 임박 재료를 혼자 다뤄도 덱에 오를 자격이 없다")
    }

    /// 같은 재료를 여러 줄로 등록해 둔 사용자에게 무게 문턱이 공짜로 낮아지면 안 된다 —
    /// `used`의 줄 수가 아니라 **서로 다른 재료 수**를 센다.
    @Test func rankCountsDistinctIngredientsNotDuplicateRows() {
        // 시금치를 세 줄로 등록(장 볼 때마다 새 줄) → used는 3줄이지만 실제로 비우는 재료는 1종.
        let stock = [resolvedIng("시금치", daysLeft: 1), resolvedIng("시금치", daysLeft: 1),
                     resolvedIng("시금치", daysLeft: 1)]
        let plan = recipe(id: "plan", refs: ["spinach", "beef", "carrot", "onion"],
                          en: ["spinach", "beef", "carrot", "onion"])
        let deck = [plan, recipe(id: "f0", refs: ["spinach", "beef"], en: ["spinach", "beef"]),
                    recipe(id: "f1", refs: ["spinach", "carrot"], en: ["spinach", "carrot"]),
                    recipe(id: "f2", refs: ["spinach", "onion"], en: ["spinach", "onion"])]
        #expect(!RecipeRecommender.rank(for: stock, from: deck).map(\.id).contains("plan"),
                "중복 등록으로 used 줄 수가 늘어도 비우는 재료는 1종이라 문턱을 못 넘는다")
    }

    /// 냉장고가 전부 신선하면 "오늘 비우는 순서"라는 기준이 안 선다 — 그때는 커버리지 조건을
    /// 요구하지 않는다. 안 그러면 잘 채워진 냉장고가 빈 덱을 받고, 빈 상태 문안("재료 이름 확인·장보기")이
    /// 그 사용자에겐 둘 다 틀린 말이 된다.
    @Test func rankKeepsSubstantialTicketsWhenNothingIsAtRisk() {
        let stock = [resolvedIng("소고기", daysLeft: 9), resolvedIng("당근", daysLeft: 9),
                     resolvedIng("양파", daysLeft: 9), resolvedIng("감자", daysLeft: 9)]
        let heavy = recipe(id: "heavy",
                           refs: ["beef", "carrot", "onion", "potato", "egg", "spinach", "tofu"],
                           en: ["beef", "carrot", "onion", "potato", "egg", "spinach", "tofu"])
        #expect(RecipeRecommender.rank(for: stock, from: [heavy]).map(\.id) == ["heavy"],
                "임박한 게 없으면 재고를 많이 쓰는 티켓은 부족이 3개여도 남아야 한다")
    }

    // MARK: - 번들 시드로 도는 랭킹 (합성 픽스처가 못 보는 것)

    /// 덱 구성 규칙은 **실제 시드 80종**으로도 돌려 본다 — 합성 4개짜리 픽스처는 상수를 함께 고치면
    /// 그대로 통과하므로, "이 규칙이 진짜 덱을 얼마나 깎는가"를 못 잡는다.
    ///
    /// 여기서 잠그는 것은 숫자가 아니라 **성립 조건**이다: 앱이 온보딩에서 실제로 주는 샘플 냉장고로
    /// ① 덱이 비지 않고 ② 임박 재료가 덱 어딘가에 실제로 남는다. 둘 중 하나라도 깨지면 사용자는
    /// 첫 화면에서 빈 덱이나 "행동 경로 없는 위험 배너"를 본다.
    @Test func rankOverBundledSeedKeepsSampleFridgeActionable() throws {
        let recipes = RecipeCatalog.loadSeed()
        #expect(recipes.count >= 50, "번들 시드를 못 읽었다")
        let stock: [Ingredient] = SampleData.ingredients
        let ranked = RecipeRecommender.rank(for: stock, from: recipes)
        #expect(!ranked.isEmpty, "샘플 냉장고로 덱이 통째로 비면 첫 화면이 빈 상태가 된다")

        // 임박(urgent·soon) 재고가 덱에서 실제로 다뤄지는가 — 배너가 세는 것과 덱이 다루는 것이 갈리면
        // 사용자는 "위험하다"는 말만 듣고 할 일을 못 받는다.
        let atRisk = stock.filter { $0.freshness != Freshness.fresh }
        #expect(!atRisk.isEmpty, "샘플 냉장고에는 임박 재료가 있어야 한다(시드 전제)")
        let coveredIDs = Set(ranked.prefix(3).flatMap { $0.used.map(\.id) })
        let uncovered = atRisk.filter { !coveredIDs.contains($0.id) }
        #expect(uncovered.count < atRisk.count,
                "상위 3장이 임박 재료를 하나도 안 다루면 덱이 오늘의 할 일을 말하지 못한다")
    }

    /// **신규 사용자의 작은 냉장고**(재료 2~3종, 전부 신선) — 여기가 첫 화면이다.
    ///
    /// 제외 문턱 ①(`clearedCount >= missing.count`)은 재고 종수가 곧 상한이라, 이 구간에서는
    /// 부족 3개 이상인 후보가 통째로 탈락한다(실측: 3종 조합의 45%, 2종이면 56%가 덱 0장이었다).
    /// 게다가 전부 신선하면 빈 상태의 atRisk 분기를 못 타서 **버튼 하나 없는 정적 문구**만 남고,
    /// 그 문구의 조언("재료 이름을 확인하라")은 이 사용자에게 틀린 말이다 — 이름이 맞았으니 후보가
    /// 수십 장이었기 때문이다. 덱 바닥(`deckSize`)이 그 구간을 메운다.
    @Test func rankOverBundledSeedFillsSmallFreshFridges() {
        let recipes = RecipeCatalog.loadSeed()
        for names in [["양파", "두부", "닭고기"], ["양파", "양배추", "돼지고기"], ["계란", "우유"]] {
            let stock = names.map { resolvedIng($0, daysLeft: 7) }   // 전부 신선
            let ranked = RecipeRecommender.rank(for: stock, from: recipes)
            #expect(!ranked.isEmpty, "\(names): 후보가 있는데 신규 사용자에게 빈 덱을 준다")
        }
    }

    // MARK: - 부족 재료 → 장보기 메모 매핑 (표시명 역조회 금지)

    @Test func toBuyEntryTrustsRefOverParentheticalText() {
        // 시드 표기는 괄호 주석을 달고 다닌다("pork (or beef)") — 이름 역조회는 포함 매칭이라
        // 괄호 **안** 단어에 먼저 걸린다. ref가 있으면 그게 정본이고, 표기도 사전 표제어로 정리된다.
        // (44차 종 토큰 가드가 이 옛 함정을 부수효과로 고쳐, 이제 역조회도 pork를 돌려준다 —
        //  ref 우선 원칙의 근거는 가드가 못 미치는 서술형 일반 케이스에 그대로 남는다.)
        let pork = Recipe.Item(ref: "pork", en: "pork (or beef)", ko: nil)
        #expect(IngredientLexicon.shared.canonicalID(for: pork.en) == "pork")   // 종 가드가 함정을 정정
        let entry = RecipeRecommender.toBuyEntry(for: pork)
        #expect(entry.canonicalID == "pork")
        #expect(entry.glyph == .meat)
        #expect(!entry.name.contains("("))   // 장보기 목록은 조리 지시가 아니라 살 것을 적는 자리

        // 괄호가 다른 재료를 통째로 품는 경우("gim (seaweed sheets)")도 ref가 이긴다.
        let gim = RecipeRecommender.toBuyEntry(for: Recipe.Item(ref: "seaweed",
                                                                en: "gim (seaweed sheets)", ko: "김밥용 김"))
        #expect(gim.canonicalID == "seaweed")
        #expect(gim.glyph == .seaweed)
    }

    @Test func toBuyEntryStripsParentheticalsFromUnresolvedLines() {
        // ref도 없고 정확 일치도 없는 서술형 라인 — 괄호를 떼야 재료명이 남는다.
        // 원문 그대로 store에 넘기면 이름 역조회가 멸치(anchovy)에 붙는다.
        let water = Recipe.Item(ref: nil, en: "water (or anchovy stock)", ko: nil)
        #expect(RecipeRecommender.canonicalID(of: water) == nil)
        #expect(IngredientLexicon.shared.canonicalID(for: water.en) == "anchovy")   // 함정 고정
        let entry = RecipeRecommender.toBuyEntry(for: water)
        // 괄호를 뗀 "water"는 그 자체로 사전 표제어라 캐논까지 확정된다(표기는 표제어로 정리된다).
        #expect(entry.canonicalID == "water")
        #expect(entry.name.lowercased() == "water")
    }

    /// **머리말 일치** — 사전 표제어가 이름의 *끝*에 올 때만 캐논으로 채택한다.
    ///
    /// 포함 매칭을 그대로 쓰면 앞에 걸리는 키워드가 대개 딴 재료라(시드 실측 4건) 그 품목이 남의
    /// 줄에 흡수돼 **목록에 들어가지도 않는다**. 여기서 두 방향을 다 고정한다: 진짜 머리말은 살리고,
    /// 수식어 자리에 걸린 이름은 캐논 없이 표기 그대로 남긴다.
    @Test func toBuyEntryUsesHeadNounNotSubstringMatch() {
        let lex = IngredientLexicon.shared
        // ① 수식어·괄호 안에 걸린 이름 — 원문 전체를 포함 매칭에 넣는 것의 함정. 담기 경로(toBuyEntry)는
        //    그 캐논을 붙이면 안 된다. 함정의 정체는 사전 판본에 따라 바뀐다(41차: paprika 줄은
        //    괄호 **안** 대체재 "mild chili powder"가 chili-powder로 걸린다 — bell-pepper 함정은
        //    머리말 우선 도입으로 소멸).
        for (en, trap) in [("paprika powder (or mild chili powder)", "chili-powder"),
                           ("chicken or vegetable stock (kept warm)", "chicken")] {
            let item = Recipe.Item(ref: nil, en: en, ko: nil)
            #expect(lex.canonicalID(for: en) == trap, "\(en): 원문 전체 매칭의 함정이 그대로여야 한다(회귀 고정)")
            let entry = RecipeRecommender.toBuyEntry(for: item)
            #expect(entry.canonicalID != trap, "\(en): 수식어·괄호에 걸린 캐논이 붙으면 안 된다")
        }
        // "chicken or vegetable stock"은 머리말이 stock이라 그쪽으로 붙는다 — 이건 정답이다.
        #expect(RecipeRecommender.toBuyEntry(
            for: Recipe.Item(ref: nil, en: "chicken or vegetable stock (kept warm)", ko: nil)
        ).canonicalID == "stock")
        // "paprika powder"는 41차에 표제어로 등재됐다 — 괄호를 뗀 뒤 정확 일치로 자기 캐논에 붙는다
        // (등재 전에는 머리말(powder)이 사전에 없어 캐논 없이 표기 그대로가 정답이었다).
        #expect(RecipeRecommender.toBuyEntry(
            for: Recipe.Item(ref: nil, en: "paprika powder (or mild chili powder)", ko: nil)
        ).canonicalID == "paprika-powder")

        // ② 진짜 머리말은 살린다 — 수식이 붙어도 끝에 오는 표제어가 재료다.
        // (minced garlic은 44차 신선/가공 분리로 자기 캐논(minced-garlic)이 됐다 — 다진마늘 병제품은
        //  통마늘과 산화 속도가 달라 별도 항목이고, garlic 레시피 줄은 parent로 계속 채운다.)
        #expect(RecipeRecommender.toBuyEntry(
            for: Recipe.Item(ref: nil, en: "minced garlic", ko: nil)).canonicalID == "minced-garlic")
        #expect(RecipeRecommender.toBuyEntry(
            for: Recipe.Item(ref: nil, en: "cold water", ko: nil)).canonicalID == "water")
    }

    /// **머리말 일치는 `en`으로만 본다** — 기기 언어가 장보기 키를 바꾸면 안 된다(CLAUDE.md: 데이터는
    /// 영문 캐논으로 저장하고 표시만 로컬라이즈).
    ///
    /// `미소 된장`은 41차 전까지 머리말이 `된장`이라 ko로 읽으면 사전의 `doenjang`에 붙었다 — 미소와
    /// 된장은 다른 제품이라 한국어 기기에서만 **미소 대신 된장**이 담기는 함정이었다. 41차에 `miso`가
    /// 표제어로 등재되면서(`미소 된장` 포함) 두 로케일 모두 정확 일치로 `miso`에 확정된다 —
    /// 로케일 무관 동일 결과라는 계약 자체는 그대로다.
    @Test func toBuyEntryResolvesTheSameWayInEveryLocale() {
        let miso = Recipe.Item(ref: nil, en: "miso paste", ko: "미소 된장")
        #expect(IngredientLexicon.shared.headNounCanonicalID(for: "미소 된장") == "miso")   // 등재로 함정 소멸
        #expect(RecipeRecommender.toBuyEntry(for: miso).canonicalID == "miso",
                "en(miso paste)과 ko(미소 된장)가 같은 캐논으로 떨어져야 한다")

        // 반대 방향도 같다 — ko가 못 잡는 표기라도 en이 잡으면 두 로케일 모두 캐논이 붙는다.
        let basil = Recipe.Item(ref: nil, en: "fresh basil", ko: "바질 잎")
        #expect(IngredientLexicon.shared.headNounCanonicalID(for: "바질 잎") == nil)
        #expect(RecipeRecommender.toBuyEntry(for: basil).canonicalID == "basil")
    }

    /// 상비재는 Short 줄에도, 장보기 목록에도 나오면 안 된다 — `isStaple`과 담기가 **같은 눈**으로 읽는다.
    /// 정확 일치만 보던 시절 `cold water`는 비-상비로 분류돼 Short에 뜬 뒤 담을 때만 `water`로 풀려
    /// 장보기 목록에 "물"이 적혔다.
    @Test func stapleDetectionUsesTheSameResolutionAsShopping() {
        for en in ["cold water", "water (or anchovy stock)", "sweet soy sauce (kecap manis)"] {
            let item = Recipe.Item(ref: nil, en: en, ko: nil)
            #expect(RecipeRecommender.isStaple(item), "\(en): 상비재로 잡혀 Short 줄에서 빠져야 한다")
        }
    }

    @Test func toBuyEntryKeepsTextWhenParenthesesAreUnbalanced() {
        // 커스텀 레시피의 오타로 괄호가 안 닫히면, 뒤를 통째로 잘라 이름을 조용히 줄이는 것보다
        // 사용자가 적은 표기를 그대로 두는 편이 안전하다("Sauce (soy" → "Sauce"가 되면 안 된다).
        let typo = Recipe.Item(ref: nil, en: "Sauce (soy", ko: nil)
        #expect(RecipeRecommender.toBuyEntry(for: typo).name == "Sauce (soy")
        // 짝이 맞는 경우는 종전대로 괄호를 떼고 정리한다(회귀 대비 대조군).
        let balanced = Recipe.Item(ref: nil, en: "Sauce (soy sauce)", ko: nil)
        #expect(RecipeRecommender.toBuyEntry(for: balanced).name == "Sauce")
    }

    // MARK: - 프로필 취향 반영(§5.2 선호 → 랭킹 실배선)

    /// 스토어 로드처럼 canonicalID를 해석해 둔 재료(matchKey가 캐논 키가 되게).
    private func resolvedIng(_ name: String, daysLeft: Int = 9) -> Ingredient {
        var i = ing(name, daysLeft: daysLeft)
        i.canonicalID = IngredientLexicon.shared.canonicalID(for: name)
        return i
    }

    private func prefs(cuisines: Set<String> = [], favorites: [String] = [],
                       disliked: [String] = [], allergies: [String] = []) -> RecipePreferences {
        RecipePreferences(cuisines: cuisines,
                          favoriteIDs: RecipePreferences.normalize(favorites),
                          dislikedIDs: RecipePreferences.normalize(disliked),
                          allergenIDs: RecipePreferences.normalize(allergies))
    }

    @Test func koreanTagNormalizesToCanonicalID() {
        // 한국어 태그도 canonical ID로 정규화("새우"→shrimp) — 매칭·필터가 표기 무관.
        #expect(RecipePreferences.normalize(["새우"]).contains("shrimp"))
        #expect(RecipePreferences.normalize(["Shrimp"]).contains("shrimp"))
        // 사전 밖 커스텀 태그는 소문자 원문 보관(no-ref exact 비교용).
        #expect(RecipePreferences.normalize(["My Secret Sauce"]).contains("my secret sauce"))
    }

    @Test func allergenHardFilterExcludesRecipe() {
        // 새우(shrimp) 알레르기 → 새우를 쓰는 레시피는 순위에서 통째로 빠진다(안전 P0).
        let shrimpDish = recipe(id: "shrimp-dish", refs: ["shrimp"], en: ["shrimp"])
        let safeDish = recipe(id: "carrot-dish", refs: ["carrot"], en: ["carrot"])
        let stock = [resolvedIng("새우", daysLeft: 1), resolvedIng("당근", daysLeft: 1)]
        let ranked = RecipeRecommender.rank(for: stock, from: [shrimpDish, safeDish],
                                            preferences: prefs(allergies: ["새우"]))
        #expect(!ranked.contains { $0.id == "shrimp-dish" })
        #expect(ranked.contains { $0.id == "carrot-dish" })
    }

    @Test func stapleAllergenIsAlsoFiltered() {
        // 간장(soy-sauce)은 상비재지만 알레르기는 상비재도 거른다(예외 없음).
        #expect(RecipeRecommender.isStaple(Recipe.Item(ref: "soy-sauce", en: "soy sauce", ko: nil)))
        let soyDish = recipe(id: "soy-dish", refs: ["beef", "soy-sauce"], en: ["beef", "soy sauce"])
        let plainDish = recipe(id: "plain-dish", refs: ["beef"], en: ["beef"])
        let stock = [resolvedIng("소고기", daysLeft: 1)]
        let ranked = RecipeRecommender.rank(for: stock, from: [soyDish, plainDish],
                                            preferences: prefs(allergies: ["간장"]))
        #expect(!ranked.contains { $0.id == "soy-dish" })   // 상비재 간장 때문에 제외
        #expect(ranked.contains { $0.id == "plain-dish" })
    }

    @Test func dislikedPenaltyReordersRanking() {
        // beef urgent(3) > carrot soon(2): 무취향이면 beefDish 먼저.
        let carrotDish = recipe(id: "carrot-dish", refs: ["carrot"], en: ["carrot"])
        let beefDish = recipe(id: "beef-dish", refs: ["beef"], en: ["beef"])
        let stock = [resolvedIng("당근", daysLeft: 1), resolvedIng("소고기", daysLeft: 0)]
        #expect(RecipeRecommender.rank(for: stock, from: [carrotDish, beefDish]).first?.id == "beef-dish")
        // 소고기 기피(-2) → beefDish 3-2=1 < carrotDish 2 → 역전.
        let ranked = RecipeRecommender.rank(for: stock, from: [carrotDish, beefDish],
                                            preferences: prefs(disliked: ["소고기"]))
        #expect(ranked.first?.id == "carrot-dish")
    }

    @Test func favoriteBonusRaisesRanking() {
        // rF(당근·계란, fresh) base 2 vs rO(소고기·양파·새우, fresh) base 3 → 무취향이면 rO 먼저.
        let rF = recipe(id: "fav-dish", refs: ["carrot", "egg"], en: ["carrot", "egg"])
        let rO = recipe(id: "other-dish", refs: ["beef", "onion", "shrimp"],
                        en: ["beef", "onion", "shrimp"])
        let stock = [resolvedIng("당근"), resolvedIng("계란"), resolvedIng("소고기"),
                     resolvedIng("양파"), resolvedIng("새우")]
        #expect(RecipeRecommender.rank(for: stock, from: [rF, rO]).first?.id == "other-dish")
        // 당근·계란 선호(+2) → rF 4 > rO 3 → 역전.
        let ranked = RecipeRecommender.rank(for: stock, from: [rF, rO],
                                            preferences: prefs(favorites: ["당근", "계란"]))
        #expect(ranked.first?.id == "fav-dish")
    }

    @Test func cuisineBonusRaisesRanking() {
        let korean = Recipe(id: "kr-dish", name: .init(en: "kr", ko: nil), cuisine: "korean",
                            minutes: 10, ingredients: [.init(ref: "carrot", en: "carrot", ko: nil)],
                            steps: .init(en: ["step"], ko: nil), isUser: nil)
        let american = Recipe(id: "us-dish", name: .init(en: "us", ko: nil), cuisine: "american",
                              minutes: 10, ingredients: [.init(ref: "beef", en: "beef", ko: nil)],
                              steps: .init(en: ["step"], ko: nil), isUser: nil)
        // beef urgent(3) > carrot soon(2): 무취향이면 미국식(beef) 먼저.
        let stock = [resolvedIng("당근", daysLeft: 3), resolvedIng("소고기", daysLeft: 0)]
        #expect(RecipeRecommender.rank(for: stock, from: [korean, american]).first?.id == "us-dish")
        // 한식 선호(+2) → korean 2+2=4 > american 3 → 역전.
        let ranked = RecipeRecommender.rank(for: stock, from: [korean, american],
                                            preferences: prefs(cuisines: ["korean"]))
        #expect(ranked.first?.id == "kr-dish")
    }

    /// 프로필 팩토리 경로 테스트용 — 임시 UserDefaults 스위트에 저장값을 심고 ProfileStore를 만든다.
    private func profileStore(cuisines: [String], suite suiteName: String) -> ProfileStore {
        let suite = UserDefaults(suiteName: suiteName)!
        suite.removePersistentDomain(forName: suiteName)
        suite.set(cuisines, forKey: "profile.cuisines")
        return ProfileStore(defaults: suite)
    }

    @Test func westernMappingBonusFires() {
        // 프로필 western → 시드 taxonomy(american·french·spanish)로 매핑돼 가점이 실제 발화한다.
        let p = RecipePreferences(profile: profileStore(cuisines: ["western"],
                                                        suite: "test.profile.western"))
        #expect(p.cuisines.isSuperset(of: ["american", "french", "spanish"]))
        let american = Recipe(id: "us-dish", name: .init(en: "us", ko: nil), cuisine: "american",
                              minutes: 10, ingredients: [.init(ref: "carrot", en: "carrot", ko: nil)],
                              steps: .init(en: ["step"], ko: nil), isUser: nil)
        let korean = Recipe(id: "kr-dish", name: .init(en: "kr", ko: nil), cuisine: "korean",
                            minutes: 10, ingredients: [.init(ref: "beef", en: "beef", ko: nil)],
                            steps: .init(en: ["step"], ko: nil), isUser: nil)
        // beef urgent(3) > carrot soon(2): 무취향이면 한식(beef) 먼저 → western 가점(+2)으로 역전.
        let stock = [resolvedIng("당근", daysLeft: 3), resolvedIng("소고기", daysLeft: 0)]
        #expect(RecipeRecommender.rank(for: stock, from: [american, korean]).first?.id == "kr-dish")
        let ranked = RecipeRecommender.rank(for: stock, from: [american, korean], preferences: p)
        #expect(ranked.first?.id == "us-dish")
        UserDefaults(suiteName: "test.profile.western")?.removePersistentDomain(forName: "test.profile.western")
    }

    @Test func vegetarianFiltersMeatAndSeafoodRecipes() {
        // vegetarian 선택 → cuisine 가점이 아니라 식이 하드 필터로 승격.
        let p = RecipePreferences(profile: profileStore(cuisines: ["vegetarian"],
                                                        suite: "test.profile.veg"))
        #expect(p.vegetarian)
        #expect(p.cuisines.isEmpty)   // cuisine 집합엔 들어가지 않는다
        let beefDish = recipe(id: "beef-dish", refs: ["beef"], en: ["beef"])
        let shrimpDish = recipe(id: "shrimp-dish", refs: ["shrimp"], en: ["shrimp"])
        let vegDish = recipe(id: "veg-dish", refs: ["carrot", "tofu"], en: ["carrot", "tofu"])
        let stock = [resolvedIng("소고기"), resolvedIng("새우"),
                     resolvedIng("당근"), resolvedIng("두부")]
        let ranked = RecipeRecommender.rank(for: stock, from: [beefDish, shrimpDish, vegDish],
                                            preferences: p)
        #expect(ranked.map(\.id) == ["veg-dish"])   // 고기·해산물 제외, 채소는 통과
        UserDefaults(suiteName: "test.profile.veg")?.removePersistentDomain(forName: "test.profile.veg")
    }

    @Test func legacyBrazilianRawValueDecodesSafely() {
        // 케이스 삭제된 brazilian이 저장값에 남아 있어도 compactMap이 무시(안전 디코드) —
        // 크래시·데이터 오염 없이 나머지 선택만 복원된다.
        let store = profileStore(cuisines: ["brazilian", "korean"], suite: "test.profile.brazilian")
        #expect(store.cuisines == [.korean])
        UserDefaults(suiteName: "test.profile.brazilian")?.removePersistentDomain(forName: "test.profile.brazilian")
    }

    @Test func nonePreferencesMatchesBaseline() {
        // preferences == .none → 기존 순위와 완전 동일(후방호환 회귀).
        let a = recipe(id: "a", refs: ["beef"], en: ["beef"])
        let b = recipe(id: "b", refs: ["carrot", "onion"], en: ["carrot", "onion"])
        let c = recipe(id: "c", refs: ["egg"], en: ["egg"])
        let stock = [resolvedIng("소고기", daysLeft: 0), resolvedIng("당근", daysLeft: 2),
                     resolvedIng("양파", daysLeft: 3), resolvedIng("계란", daysLeft: 9)]
        let base = RecipeRecommender.rank(for: stock, from: [a, b, c])
        let withNone = RecipeRecommender.rank(for: stock, from: [a, b, c], preferences: .none)
        #expect(base.map(\.id) == withNone.map(\.id))
    }
}

/// 표시 이름 — **가드형 단일 정책**(`IngredientLexicon.displayName(stored:canonicalID:)`).
/// 저장 스키마(`name`)는 손대지 않고, 저장 표기가 사전 표제어(en/ko)와 일치할 때만 지금 로케일
/// 표제어로 다시 읽는다. "사용자가 적은 표기는 데이터다 — 사전이 아는 말일 때만 사전이 말한다."
struct DisplayNameTests {

    /// 표제어로 담은 것은 언어를 따라온다 — **반대 로케일 표기를 넣어** 왕복을 세운다.
    /// 테스트에서 호스트 언어를 못 바꾸므로(`Recipe.isKorean`은 `Locale.current`를 읽는다),
    /// 지금 호스트가 아닌 *반대쪽* 표기를 저장값으로 주고 지금 쪽 표제어가 나오는지 본다 —
    /// 어느 호스트에서 돌려도 실제 언어 전환 왕복(ko 입력 → en 표시)을 재현한다.
    @Test func lexiconHeadwordIsRedrawnInTheCurrentLocale() throws {
        let entry = try #require(IngredientLexicon.shared.entry(id: "onion"))
        let ko = try #require(entry.names.ko.first)        // "양파"
        let en = try #require(entry.names.en.first)        // "onion"(사전의 영문은 매칭용 소문자 캐논)
        let stored = Recipe.isKorean ? en : ko
        let ing = Ingredient(name: stored, category: "Veg", expiresAt: Date(), canonicalID: "onion")
        #expect(ing.displayName == entry.displayName)
        #expect(ing.displayName == (Recipe.isKorean ? ko : en.localizedCapitalized))
        #expect(ing.name == stored)                        // 저장값 자체는 건드리지 않는다
    }

    /// 캐논이 붙어 있어도 **사전이 모르는 표기는 덮지 않는다**(가드형의 핵심).
    /// 영수증 줄 "서울우유1L"은 포함 매칭으로 캐논이 milk지만, 사용자가 산 그 물건의 이름이
    /// 화면에서 "Milk"로 바뀌면 안 된다.
    @Test func freeTextSurvivesEvenWhenItMatchedACanon() {
        #expect(IngredientLexicon.shared.canonicalID(for: "서울우유1L") == "milk")   // 전제
        let ing = Ingredient(name: "서울우유1L", category: "Dairy",
                             expiresAt: Date(), canonicalID: "milk")
        #expect(ing.displayName == "서울우유1L")
    }

    @Test func freeTextKeepsStoredName() {
        let ing = Ingredient(name: "할머니표 장아찌", category: "Other", expiresAt: Date())
        #expect(ing.displayName == "할머니표 장아찌")
    }

    /// 한 품목은 **어느 화면에서든 같은 이름으로 불린다**. 표면마다 규칙이 갈렸던 전례를 못 박는다:
    /// 같은 이력 로그가 History에선 "Milk", To buy에선 "서울우유1L"로 읽혔다(재고 카드·뱃지·알림은
    /// `Ingredient`, 타임라인은 `RemovalLog`, 장보기 메모는 `ManualBuyItem`을 그린다).
    @MainActor   // `FridgeStore.displayName(for:)`는 스토어와 함께 메인 액터에 산다
    @Test func everySurfaceAgreesOnTheSameName() throws {
        let entry = try #require(IngredientLexicon.shared.entry(id: "milk"))
        let headword = try #require(entry.names.ko.first)
        for stored in [headword, "서울우유1L"] {          // 표제어 / 자유 입력 양쪽
            let ing = Ingredient(name: stored, category: "Dairy",
                                 expiresAt: Date(), canonicalID: "milk")
            let log = RemovalLog(name: stored, glyph: .milk, canonicalID: "milk",
                                 removedAt: Date(), wasted: false)
            let memo = FridgeStore.ManualBuyItem(name: stored, canonicalID: "milk", glyph: .milk)
            #expect(ing.displayName == log.displayName)
            #expect(log.displayName == FridgeStore.displayName(for: memo))
        }
    }

    @Test func removalLogFollowsSameRule() {
        let log = RemovalLog(name: "우유", glyph: .milk, canonicalID: "milk",
                             removedAt: Date(), wasted: false)
        #expect(log.displayName == IngredientLexicon.shared.entry(id: "milk")?.displayName)
        // 캐논이 있어도 사전 밖 표기는 그대로 — 타임라인이 사용자가 산 물건 이름을 지우지 않는다.
        let kept = RemovalLog(name: "old label", glyph: .milk, canonicalID: "milk",
                              removedAt: Date(), wasted: false)
        #expect(kept.displayName == "old label")
        let free = RemovalLog(name: "직접 만든 잼", glyph: .generic, removedAt: Date(), wasted: true)
        #expect(free.displayName == "직접 만든 잼")
    }
}

/// 45차 적대 검증 후속 — 다단어 영문 표제어의 복수형·소매 라벨 실꼴이 **자기 캐논**으로 돌아온다.
/// 검증 실측: 표제어+s 450건 중 125건이 다른 재료의 캐논(bell peppers→black-pepper, chicken
/// breasts→chicken)에 붙었다 — 이 파일 서두가 규정한 데이터 파괴 등급(소비기한 오염·오예약) 그대로.
struct PluralMatchingTests {

    /// 사전 전수 래칫 — 영문 표제어의 +s 꼴은 **자기 id 아니면 nil**(안전한 실패)이다.
    /// 다른 id로 떨어지는 순간이 데이터 파괴의 시작이라, 개별 사례가 아니라 전수로 못 박는다.
    /// (-y→-ies 같은 불규칙 복수는 nil로 남는다 — 오귀속만 아니면 실패는 허용.)
    @Test func pluralFormsNeverLandOnAnotherCanon() {
        let lex = IngredientLexicon.shared
        for entry in lex.entries {
            for name in entry.names.en where !name.hasSuffix("s") {
                let got = lex.canonicalID(for: name + "s")
                #expect(got == nil || got == entry.id,
                        "'\(name)s'가 \(entry.id)이 아니라 \(got ?? "nil")로 갔다 — 남의 캐논 오귀속")
            }
        }
    }

    /// 소매 라벨 최빈형 고정 — 부위 정밀도(44차 정육 분리)와 밀봉 기한(소스·시럽)이 복수형에서
    /// 무효화되지 않는다. 마지막 셋은 수량·단위가 붙은 실표기(토큰 창 매칭 경로).
    @Test func retailPluralFormsKeepTheirPrecision() {
        let lex = IngredientLexicon.shared
        let cases: [(String, String)] = [
            ("green onions", "green-onion"),
            ("bell peppers", "bell-pepper"),
            ("chicken breasts", "chicken-breast"),
            ("pork chops", "pork-loin"),
            ("rice cakes", "rice-cake"),
            ("tomato sauces", "tomato-sauce"),
            ("red pepper pastes", "gochujang"),
            ("paprika powders", "paprika-powder"),
            ("sea mustards", "seaweed"),
            ("water dropworts", "water-parsley"),
            ("boneless skinless chicken breasts 2.1LB", "chicken-breast"),
            ("rice cakes 500g", "rice-cake"),
            ("GREEN ONIONS 1단", "green-onion"),
            ("onions 1kg", "onion"),
            ("fresh-pressed juice 2", "fresh-juice"),
        ]
        for (input, want) in cases {
            #expect(lex.canonicalID(for: input) == want, "\(input) → \(want)")
        }
    }
}

/// 45차 적대 검증 후속 — 대체 그래프의 두 불변식.
struct SubstitutionInvariantTests {

    private func recipe(id: String, refs: [String], en: [String]) -> Recipe {
        Recipe(id: id,
               name: Recipe.LocalizedName(en: id, ko: nil),
               cuisine: nil, minutes: 10,
               ingredients: zip(refs, en).map { Recipe.Item(ref: $0.0, en: $0.1, ko: nil) },
               steps: Recipe.LocalizedSteps(en: ["step"], ko: nil),
               isUser: nil)
    }

    private func ing(_ name: String, daysLeft: Int = 3) -> Ingredient {
        Ingredient(name: name, category: "Veg", daysLeft: daysLeft,
                   quantity: Quantity(value: 1, unit: .piece), glyph: .generic)
    }

    /// **1재고 1줄** — 발주·완료는 재고 id 단위로 예약·삭제하므로, 한 알이 정품 줄과 대체 줄을
    /// 겸하면 missing이 거짓으로 줄어 "지금 만들 수 있는 요리"가 된다(검증 실측: 양파 1개가
    /// onion+green onion 두 줄을 겸한 시드 15레시피). 두 경로(기준·벌크) 모두 고정한다.
    @Test func oneStockCannotFillTwoLines() {
        let dish = recipe(id: "gratin-fixture", refs: ["milk", "cream"], en: ["milk", "cream"])
        let stock = [ing("생크림", daysLeft: 2)]
        let r = RecipeRecommender.result(for: dish, ingredients: stock)
        #expect(r.used.count == 1)
        #expect(r.substituted.isEmpty, "생크림은 cream 줄에 정품으로 이미 예약됐다 — 겸직 금지")
        #expect(r.missing.count == 1 && r.missing.first?.en == "milk")
        let ranked = RecipeRecommender.rank(for: stock, from: [dish])
        #expect(ranked.first?.missing.count == 1, "벌크 경로도 같은 계약")
    }

    /// **간선·차단 어휘는 살아 있어야 한다** — 상비(staple) 캐논을 fills 하는 간선은 구조적으로
    /// 발화 불가(상비 줄은 missing이 되지 않는다)이고, 시드 표기에 0회 등장하는 block 토큰은
    /// 있는 척만 하는 가드다(검증 실측: 40간선 중 15간선·13토큰 중 9개가 죽어 있었다).
    @Test func subsEdgesAndBlockTokensAreLive() {
        let lex = IngredientLexicon.shared
        let seedRecipes = RecipeCatalog.loadSeed()
        for entry in lex.entries {
            for sub in entry.subs ?? [] {
                let target = lex.entry(id: sub.fills)
                #expect(target != nil, "\(entry.id)→\(sub.fills): 미등재 fills")
                #expect(target?.staple != true, "\(entry.id)→\(sub.fills): 상비 fills는 영구 사장")
                guard let blocks = sub.block else { continue }
                // 이 간선이 실제로 닿는 시드 줄(비상비 + fills 키 보유)의 표기 코퍼스.
                let targetLines: [String] = seedRecipes.flatMap { r in
                    r.ingredients.compactMap { item -> String? in
                        let keys = [item.ref].compactMap { $0 } + (item.altRefs ?? [])
                        guard keys.contains(sub.fills),
                              item.ref.flatMap({ lex.entry(id: $0)?.staple }) != true else { return nil }
                        return (item.en + " " + (item.ko ?? "")).lowercased()
                    }
                }
                for token in blocks {
                    let fires = targetLines.contains { $0.contains(token.lowercased()) }
                    #expect(fires, "\(entry.id)→\(sub.fills) block '\(token)': 시드 대상 줄 0회 발화(죽은 가드)")
                }
            }
        }
    }
}

/// 45차 적대 검증 후속 — 한계이득 그리디의 취향 보정 한계화.
struct MarginalPreferenceTests {

    private func recipe(id: String, refs: [String], cuisine: String? = nil) -> Recipe {
        Recipe(id: id,
               name: Recipe.LocalizedName(en: id, ko: nil),
               cuisine: cuisine, minutes: 10,
               ingredients: refs.map { Recipe.Item(ref: $0, en: $0, ko: nil) },
               steps: Recipe.LocalizedSteps(en: ["step"], ko: nil),
               isUser: nil)
    }

    private func ing(_ name: String, daysLeft: Int = 3) -> Ingredient {
        Ingredient(name: name, category: "Veg", daysLeft: daysLeft,
                   quantity: Quantity(value: 1, unit: .piece), glyph: .generic)
    }

    /// cuisine·favorites 가점이 상수로 남으면, 새 재고 기여가 0인 중복 티켓(+5)이 D-1 연어를
    /// 유일하게 구하는 티켓(+2)을 앞선다 — 이 그리디가 고치려던 바로 그 증상이 취향이 켜지는
    /// 실앱 경로에서만 재발한다(검증 실측 A/B/C). 가점도 미커버 기준으로 다시 세야 한다.
    @Test func marginalGainRecomputesPreferenceBonuses() {
        let a = recipe(id: "a-covers", refs: ["beef", "onion", "carrot"], cuisine: "korean")
        let b = recipe(id: "b-duplicate", refs: ["beef", "onion", "carrot"], cuisine: "korean")
        let c = recipe(id: "c-rescues-salmon", refs: ["salmon"])
        let stock = [ing("소고기", daysLeft: 0), ing("양파"), ing("당근"), ing("연어", daysLeft: 1)]
        let prefs = RecipePreferences(cuisines: ["korean"],
                                      favoriteIDs: ["beef", "onion", "carrot"],
                                      dislikedIDs: [], allergenIDs: [])
        let ids = RecipeRecommender.rank(for: stock, from: [a, b, c], preferences: prefs).map(\.id)
        #expect(ids == ["a-covers", "c-rescues-salmon", "b-duplicate"],
                "중복 티켓의 한계이득은 취향 가점까지 0으로 — 연어 티켓이 2번 자리를 가져간다")
    }
}

/// 45차 적대 검증 후속 — 냉동은 개봉 시계를 **멈추는 사건**이다(§13.6 두 번째 기회).
struct FreezeOpenedClockTests {

    /// 살아 있는 개봉 시계는 냉동이 멈추고 유예(14일)가 대신 돈다 — 어제 딴 코코넛밀크를 얼렸는데
    /// 기한이 하루도 안 늘면 냉동 버튼은 1회권만 태우는 위약이다(검증 실측: 밀봉 25종 전수).
    @Test func freezePausesLiveOpenedClock() {
        var coco = Ingredient(name: "코코넛밀크", category: "가공", daysLeft: 300,
                              quantity: Quantity(value: 1, unit: .piece), glyph: .can)
        coco.canonicalID = "coconut-milk"
        coco.openedAt = Calendar.current.date(byAdding: .day, value: -1, to: Date())
        #expect(coco.effectiveDaysLeft <= 4, "개봉 시계(개봉 후 5일)가 지배한다")
        #expect(coco.canFreeze)
        coco.storage = .freezer
        coco.frozenAt = Date()
        #expect(coco.effectiveDaysLeft >= 10, "냉동이 개봉 시계를 멈추고 유예가 돈다")
    }

    /// 이미 지난 개봉 시계는 냉동이 되살리지 않고(44차 크림치즈 케이스 유지), 그때는 버튼도
    /// 서지 않는다 — 효과 없는 냉동은 위약 UI다(MVP 원칙).
    @Test func freezeDoesNotReviveDeadOpenedClock() {
        var cheese = Ingredient(name: "크림치즈", category: "유제품", daysLeft: 300,
                                quantity: Quantity(value: 1, unit: .piece), glyph: .cheese)
        cheese.canonicalID = "cream-cheese"
        cheese.openedAt = Calendar.current.date(byAdding: .day, value: -20, to: Date())
        #expect(cheese.effectiveDaysLeft < 0, "개봉 후 10일이 지났다")
        #expect(!cheese.canFreeze, "되살릴 수 없는 항목에 냉동 버튼을 열지 않는다")
        cheese.storage = .freezer
        cheese.frozenAt = Date()
        #expect(cheese.effectiveDaysLeft < 0, "냉동이 지난 개봉 기한을 되살리지 않는다")
    }
}
