import Testing
import Foundation
@testable import Reffi

/// 취향 옵션 ↔ 시드 taxonomy 정합(64차).
///
/// 이 스위트가 지키는 것은 "위약 UI 금지"(CLAUDE.md) 한 줄이다. 그동안 그 규칙을 지키던 것은
/// 코드가 아니라 **주석과 기억**이었다: `CuisineStyle`에 케이스를 하나 더해도 컴파일러가 강제하는
/// 것은 `label` switch(=표시 문자열)뿐이고, `seedCuisines` 매핑 누락은 아무도 막지 않았다.
/// 게다가 옛 `?? [c.rawValue]` 폴백이 그 누락을 조용한 no-op으로 삼켜, 어떤 레시피에도 닿지
/// 않는 칩이 살아 있는 것처럼 출시될 수 있었다(brazilian이 지워진 바로 그 사고).
/// 64차에 폴백을 지웠으므로, 이제 그 문을 지키는 것은 여기 세 테스트다.
struct CuisineOptionCoverageTests {

    private var seed: [Recipe] { RecipeCatalog.loadSeed() }

    /// 모든 취향 옵션은 시드 레시피에 **실제로** 닿는다 — 하나라도 0편이면 그 칩은 위약이다.
    @Test func everyCuisineOptionReachesSeedRecipes() {
        let recipes = seed
        for style in CuisineStyle.allCases where style != .vegetarian {
            let mapped = RecipePreferences.seedCuisines[style]
            #expect(mapped != nil, "\(style.rawValue)에 seedCuisines 매핑이 없다 — 폴백이 사라졌으므로 이 옵션은 아무 레시피에도 닿지 않는다")
            guard let mapped else { continue }
            let hits = recipes.filter { $0.cuisine.map(mapped.contains) ?? false }
            #expect(!hits.isEmpty, "\(style.rawValue)가 매칭하는 시드 레시피가 0편이다(매핑: \(mapped.sorted()))")
        }
    }

    /// 시드의 모든 cuisine 문자열은 **어떤 옵션으로든** 도달 가능하다 — 아니면 죽은 데이터다.
    /// nasi-goreng이 thai로, 슈니첼이 french로 잘못 붙어 있던 44차 사고의 재발 방지선이기도 하다:
    /// 값을 제자리로 돌리면서 매핑을 같이 고치지 않으면 여기서 걸린다.
    @Test func everySeedCuisineIsReachableByAnOption() {
        let reachable = RecipePreferences.seedCuisines.values.reduce(into: Set<String>()) { $0.formUnion($1) }
        let present = Set(seed.compactMap(\.cuisine))
        #expect(present.subtracting(reachable).isEmpty,
                "어떤 취향 옵션으로도 닿지 않는 시드 cuisine: \(present.subtracting(reachable).sorted())")
        #expect(reachable.subtracting(present).isEmpty,
                "매핑은 있는데 시드에 한 편도 없는 cuisine: \(reachable.subtracting(present).sorted())")
    }

    /// 시드 cuisine은 비어 있지 않고 정규화된 소문자 슬러그다(대소문자·공백 혼입 방지).
    @Test func seedCuisineValuesAreWellFormed() {
        for recipe in seed {
            guard let c = recipe.cuisine else {
                Issue.record("\(recipe.id)에 cuisine이 없다")
                continue
            }
            #expect(c == c.lowercased(), "\(recipe.id)의 cuisine '\(c)'에 대문자가 섞였다")
            #expect(!c.contains(" "), "\(recipe.id)의 cuisine '\(c)'에 공백이 있다")
            #expect(!c.isEmpty)
        }
    }

    /// 64차 정정 두 건을 값으로 고정 — 되돌아가면 여기서 걸린다.
    @Test func correctedMisclassificationsStayCorrected() {
        let byID = Dictionary(uniqueKeysWithValues: seed.map { ($0.id, $0) })
        #expect(byID["nasi-goreng"]?.cuisine == "indonesian")
        #expect(byID["schnitzel-style-cutlet"]?.cuisine == "german")
    }
}

/// 프로필 기본값(64차) — "고른 적 없음"이 "한식을 골랐음"으로 저장되지 않는다.
struct ProfileCuisineDefaultTests {

    private func scratch(_ name: String) -> UserDefaults {
        let suite = UserDefaults(suiteName: name)!
        suite.removePersistentDomain(forName: name)
        return suite
    }

    /// 아무것도 고르지 않은 새 프로필은 빈 집합이고, 그래서 랭킹이 순수 freshness다.
    /// 옛 기본값 `[.korean]`은 시드 128편 중 55편(43%)에 아무도 고르지 않은 +2를 주고 있었다.
    @Test func freshProfileHasNoCuisinePreference() {
        let store = ProfileStore(defaults: scratch("test.profile.freshDefault"))
        #expect(store.cuisines.isEmpty)
        #expect(RecipePreferences(profile: store).isEmpty)
    }

    /// 계정 전환·탈퇴가 지나간 자리에도 한식이 다시 심기지 않는다(`resetAll`은 save()까지 탄다).
    @Test func resetAllLeavesCuisinesEmpty() {
        let store = ProfileStore(defaults: scratch("test.profile.resetDefault"))
        store.cuisines = [.korean, .italian]
        store.resetAll()
        #expect(store.cuisines.isEmpty)
    }

    /// 명시적으로 고른 값은 그대로 살아 돌아온다 — 기본값 변경이 저장 경로를 건드리지 않았다.
    @Test func explicitSelectionRoundTrips() {
        let suite = scratch("test.profile.explicitRoundTrip")
        let first = ProfileStore(defaults: suite)
        first.cuisines = [.japanese, .italian]
        #expect(ProfileStore(defaults: suite).cuisines == [.japanese, .italian])
    }
}

/// 알레르기·기피 판정의 상위(총칭) 확장(64차) — 안전 P0.
///
/// 시드가 아니라 **합성 레시피**로 검증한다: 시드 구성이 바뀌어도 이 규칙 자체는 흔들리지
/// 않아야 하고, 시드로 재면 "재고가 없어 애초에 랭킹에 안 올라온 것"과 "필터가 막은 것"을
/// 구별할 수 없다(첫 작성에서 실제로 그 함정에 빠져 128편 전부가 차단됨으로 집계됐다).
struct AllergenParentExpansionTests {

    private func ing(_ name: String, daysLeft: Int = 3) -> Ingredient {
        var i = Ingredient(name: name, category: "Dairy", daysLeft: daysLeft,
                           quantity: Quantity(value: 1, unit: .piece), glyph: .generic)
        i.canonicalID = IngredientLexicon.shared.canonicalID(for: name)
        return i
    }

    private func recipe(_ id: String, ref: String, en: String) -> Recipe {
        Recipe(id: id, name: .init(en: id, ko: nil), cuisine: "italian", minutes: 10,
               ingredients: [.init(ref: ref, en: en, ko: nil)],
               steps: .init(en: ["step"], ko: nil), isUser: nil)
    }

    private func prefs(allergies: [String]) -> RecipePreferences {
        RecipePreferences(cuisines: [], favoriteIDs: [], dislikedIDs: [],
                          allergenIDs: RecipePreferences.normalize(allergies))
    }

    /// 사전 전제 — 이 테스트가 기대는 부모 간선이 실제로 사전에 있다.
    @Test func lexiconHasTheParentEdgeUnderTest() {
        #expect(IngredientLexicon.shared.parentID(of: "mozzarella") == "cheese")
    }

    /// 총칭 태그(cheese)가 하위 재료(mozzarella)만 쓰는 레시피를 막는다.
    /// 확장 전 실측 누수: cheese 태그가 mozzarella 레시피 7편, mushroom이 6편, chicken이
    /// chicken-breast 2편, pork가 pork-belly 1편, tomato가 cherry-tomato 3편을 통과시켰다.
    @Test func genericAllergenTagBlocksSpecificChildIngredient() {
        let mozz = recipe("mozz-dish", ref: "mozzarella", en: "mozzarella")
        let stock = [ing("모차렐라")]
        // 취향 없음이면 정상적으로 추천된다 — 아래 차단이 "재고 없음" 때문이 아님을 먼저 못박는다.
        #expect(RecipeRecommender.rank(for: stock, from: [mozz]).contains { $0.recipe.id == "mozz-dish" })
        #expect(!RecipeRecommender.rank(for: stock, from: [mozz],
                                        preferences: prefs(allergies: ["cheese"]))
                    .contains { $0.recipe.id == "mozz-dish" },
                "치즈 알레르기가 모차렐라만 쓰는 레시피를 통과시킨다")
        // 한글 태그도 같은 캐논으로 정규화되므로 동일하게 막혀야 한다(영-한 동치).
        #expect(!RecipeRecommender.rank(for: stock, from: [mozz],
                                        preferences: prefs(allergies: ["치즈"]))
                    .contains { $0.recipe.id == "mozz-dish" })
    }

    /// 정확히 일치하는 태그는 당연히 막는다 — 확장이 기존 동작을 깨지 않았다는 회귀선.
    @Test func exactAllergenTagStillBlocks() {
        let mozz = recipe("mozz-dish", ref: "mozzarella", en: "mozzarella")
        #expect(!RecipeRecommender.rank(for: [ing("모차렐라")], from: [mozz],
                                        preferences: prefs(allergies: ["mozzarella"]))
                    .contains { $0.recipe.id == "mozz-dish" })
    }

    /// 방향은 한쪽뿐이다 — 하위 태그(mozzarella)가 총칭 줄(cheese)까지 막지는 않는다.
    /// 반대 방향까지 열면 "모차렐라만 못 먹는 사람"에게서 치즈 요리 전체가 사라진다(과차단).
    @Test func specificTagDoesNotBlockGenericLine() {
        let generic = recipe("cheese-dish", ref: "cheese", en: "cheese")
        let stock = [ing("치즈")]
        #expect(RecipeRecommender.rank(for: stock, from: [generic]).contains { $0.recipe.id == "cheese-dish" })
        #expect(RecipeRecommender.rank(for: stock, from: [generic],
                                       preferences: prefs(allergies: ["mozzarella"]))
                    .contains { $0.recipe.id == "cheese-dish" },
                "하위 태그가 총칭 줄까지 막으면 확장 방향이 뒤집힌 것이다")
    }
}

/// 옛 기본값 1회 청소(64차) — 오너 판정: 편향 제거를 진짜 한식-only 선택 보존보다 우선한다.
struct ProfileCuisineMigrationTests {

    private func scratch(_ name: String) -> UserDefaults {
        let suite = UserDefaults(suiteName: name)!
        suite.removePersistentDomain(forName: name)
        return suite
    }

    /// 이미 디스크에 적힌 ["korean"] 한 칸은 비운다 — 기본값 변경만으로는 안 지워지기 때문이다.
    @Test func migrationClearsStoredKoreanDefault() {
        let suite = scratch("test.profile.migrate.korean")
        suite.set(["korean"], forKey: "profile.cuisines")
        let store = ProfileStore(defaults: suite)
        #expect(store.cuisines.isEmpty)
        #expect(suite.bool(forKey: "profile.cuisinesDefaultMigrated"))
    }

    /// 두 칸 이상은 사용자가 실제로 손댄 증거라 건드리지 않는다.
    @Test func migrationKeepsMultiSelection() {
        let suite = scratch("test.profile.migrate.multi")
        suite.set(["korean", "italian"], forKey: "profile.cuisines")
        #expect(ProfileStore(defaults: suite).cuisines == [.korean, .italian])
    }

    /// 한식이 아닌 한 칸도 건드리지 않는다.
    @Test func migrationKeepsNonKoreanSingleSelection() {
        let suite = scratch("test.profile.migrate.single")
        suite.set(["japanese"], forKey: "profile.cuisines")
        #expect(ProfileStore(defaults: suite).cuisines == [.japanese])
    }

    /// 청소는 한 번뿐이다 — 이후 사용자가 진짜로 한식만 고르면 다음 실행에서 살아남는다.
    @Test func migrationRunsOnlyOnce() {
        let suite = scratch("test.profile.migrate.once")
        suite.set(["korean"], forKey: "profile.cuisines")
        _ = ProfileStore(defaults: suite)                 // 1회차: 청소 + 플래그
        let second = ProfileStore(defaults: suite)
        second.cuisines = [.korean]                       // 사용자가 이번엔 직접 고른다
        #expect(ProfileStore(defaults: suite).cuisines == [.korean])
    }
}

/// 함유 알레르겐 확장(64차) — 가공품이 담고 있는 원재료로 하드 필터가 걸린다.
struct AllergenSourceExpansionTests {

    private func ing(_ name: String) -> Ingredient {
        var i = Ingredient(name: name, category: "Etc", daysLeft: 3,
                           quantity: Quantity(value: 1, unit: .piece), glyph: .generic)
        i.canonicalID = IngredientLexicon.shared.canonicalID(for: name)
        return i
    }

    /// 검사 대상 재료 + **비상비 앵커**(당근). 앵커가 없으면 상비재만 든 레시피(간장·된장)는
    /// 애초에 랭킹에 오르지 않아 "필터가 막았다"와 "재고가 없었다"를 구별할 수 없다.
    private func recipe(_ id: String, ref: String) -> Recipe {
        Recipe(id: id, name: .init(en: id, ko: nil), cuisine: "american", minutes: 10,
               ingredients: [.init(ref: "carrot", en: "carrot", ko: nil),
                             .init(ref: ref, en: ref, ko: nil)],
               steps: .init(en: ["step"], ko: nil), isUser: nil)
    }

    private func allergy(_ tags: [String]) -> RecipePreferences {
        RecipePreferences(cuisines: [], favoriteIDs: [], dislikedIDs: [],
                          allergenIDs: RecipePreferences.normalize(tags))
    }

    /// 태그를 걸었을 때 이 레시피가 덱에서 사라지는가. 기준선(취향 없으면 반드시 추천된다)을
    /// 같은 자리에서 확인해, 차단이 재고 부족으로 위장되지 않게 한다.
    private func blocked(recipeRef: String, tag: String) -> Bool {
        let r = recipe("dish", ref: recipeRef)
        let stock = [ing("당근")]
        let shown: (RecipePreferences?) -> Bool = { prefs in
            let ranked = prefs.map { RecipeRecommender.rank(for: stock, from: [r], preferences: $0) }
                ?? RecipeRecommender.rank(for: stock, from: [r])
            return ranked.contains { $0.recipe.id == "dish" }
        }
        #expect(shown(nil), "기준선 실패 — \(recipeRef) 레시피가 취향 없이도 추천되지 않는다")
        return !shown(allergy([tag]))
    }

    /// 땅콩 알레르기가 땅콩버터를 막는다 — 이 확장 전에는 통과했다(pb-banana-toast 실측).
    @Test func peanutAllergyBlocksPeanutButter() {
        #expect(blocked(recipeRef: "peanut-butter", tag: "peanut"))
        #expect(blocked(recipeRef: "peanut-butter", tag: "땅콩"))
    }

    /// 우유 알레르기가 유제품 가공품을 막는다. 모차렐라는 parent(치즈) → allergens(우유)
    /// 두 관계를 연달아 타야 걸리므로, 사슬이 고정점까지 도는지까지 함께 검증한다.
    @Test func milkAllergyBlocksDairyDerivatives() {
        for ref in ["butter", "cheese", "yogurt", "mozzarella"] {
            #expect(blocked(recipeRef: ref, tag: "milk"), "우유 알레르기가 \(ref)를 통과시킨다")
        }
    }

    /// 대두·밀 알레르기가 장류·면류를 막는다.
    @Test func soyAndWheatAllergiesBlockProcessedStaples() {
        #expect(blocked(recipeRef: "tofu", tag: "soybean"))
        #expect(blocked(recipeRef: "doenjang", tag: "콩"))
        #expect(blocked(recipeRef: "pasta", tag: "wheat"))
        #expect(blocked(recipeRef: "bread", tag: "밀가루"))
        // 양조간장은 대두와 밀을 모두 함유한다 — 어느 쪽 태그로도 걸려야 한다.
        #expect(blocked(recipeRef: "soy-sauce", tag: "soybean"))
        #expect(blocked(recipeRef: "soy-sauce", tag: "wheat"))
    }

    /// 방향은 한쪽뿐이다 — 원재료 요리가 가공품 태그로 막히지는 않는다(과차단 방지).
    @Test func rawSourceIsNotBlockedByDerivativeTag() {
        #expect(!blocked(recipeRef: "peanut", tag: "peanut-butter"))
        #expect(!blocked(recipeRef: "milk", tag: "butter"))
    }

    /// 함유 간선은 **알레르기 전용**이다 — 기피(disliked)는 감점이지 필터가 아니므로,
    /// "우유가 싫다"가 치즈 요리를 덱에서 지워버리면 안 된다.
    @Test func allergenEdgeDoesNotLeakIntoDislikes() {
        let r = recipe("dish", ref: "cheese")
        let stock = [ing("치즈")]
        let disliked = RecipePreferences(cuisines: [], favoriteIDs: [],
                                         dislikedIDs: RecipePreferences.normalize(["milk"]),
                                         allergenIDs: [])
        #expect(RecipeRecommender.rank(for: stock, from: [r], preferences: disliked)
            .contains { $0.recipe.id == "dish" })
    }

    /// 사전의 모든 allergens 원천은 실재하는 캐논이다 — 오타 한 글자가 조용한 무발화가 된다.
    @Test func everyAllergenSourceResolves() {
        let lex = IngredientLexicon.shared
        let ids = Set(lex.entries.map(\.id))
        for entry in lex.entries {
            for source in entry.allergens ?? [] {
                #expect(ids.contains(source), "\(entry.id)의 allergens에 없는 캐논 '\(source)'")
            }
        }
        #expect(lex.entries.contains { ($0.allergens?.isEmpty == false) })
    }
}
