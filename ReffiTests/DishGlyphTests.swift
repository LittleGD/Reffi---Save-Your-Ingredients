import Testing
import Foundation
import SwiftUI
@testable import Reffi

/// 시드 레시피는 테스트 호스트(Reffi.app) 번들에 있다. `.main`이 비면 로드된 번들을 훑어 찾는다.
func seedRecipesForTests() -> [Recipe] {
    let main = RecipeCatalog.loadSeed()
    if !main.isEmpty { return main }
    for b in Bundle.allBundles + Bundle.allFrameworks {
        let r = RecipeCatalog.loadSeed(bundle: b)
        if !r.isEmpty { return r }
    }
    return []
}

/// 요리 아이콘 시스템(§13.4) — **매핑 계약**을 잠근다.
/// 시드 80개가 전부 명시 매핑을 받는지, 매핑 밖 레시피가 폴백으로 항상 아이콘을 얻는지,
/// 폴백이 실행마다 흔들리지 않는지가 이 스위트가 막는 회귀다.
struct DishGlyphCatalogTests {

    @Test func everySeedRecipeIsExplicitlyMapped() {
        let recipes = seedRecipesForTests()
        #expect(recipes.count == 80, "시드가 80개가 아니다(\(recipes.count)) — 매핑 표를 함께 갱신해야 한다")
        for r in recipes {
            #expect(DishGlyphCatalog.table[r.id] != nil,
                    "\(r.id)(\(r.name.ko ?? r.name.en))가 매핑 표에 없다 — 폴백으로 새고 있다")
        }
    }

    @Test func mappingTableHasNoOrphanEntries() {
        // 표에만 있고 시드엔 없는 id = 레시피가 이름을 바꿨는데 표가 안 따라온 것.
        let seedIDs = Set(seedRecipesForTests().map(\.id))
        for id in DishGlyphCatalog.table.keys {
            #expect(seedIDs.contains(id), "\(id)는 시드에 없는 id다(표에 유령 항목)")
        }
    }

    @Test func everyArchetypeIsActuallyUsed() {
        // 쓰이지 않는 원형 = 그려놓고 아무 요리도 안 붙은 죽은 코드.
        let used = Set(DishGlyphCatalog.table.values.map(\.archetype))
        for a in DishArchetype.allCases {
            #expect(used.contains(a), "\(a.rawValue) 원형에 배정된 레시피가 없다")
        }
    }

    @Test func sameArchetypeRecipesDifferInVariation() {
        // 원형이 같으면 **변주값이 달라야** 한다 — 같은 DishLook 둘은 옆에 놓으면 같은 요리로 읽힌다.
        var seen: [DishLook: String] = [:]
        for r in seedRecipesForTests() {
            let look = DishGlyphCatalog.look(for: r)
            if let twin = seen[look] {
                Issue.record("\(r.id)와 \(twin)의 변주가 완전히 같다 — 구분이 안 된다")
            }
            seen[look] = r.id
        }
    }

    // MARK: 폴백 — 매핑 밖 레시피(커스텀·AI·미래 시드)

    @Test func fallbackReadsArchetypeFromKoreanName() {
        let cases: [(String, DishArchetype)] = [
            ("된장찌개", .stewPot), ("소고기 미역국", .soupBowl), ("김치 칼국수", .noodleBowl),
            ("연어 덮밥", .riceBowl), ("감자전", .discStack), ("삼겹살구이", .grillPlate),
            ("가지볶음", .skillet), ("참치 김밥", .rollSlices), ("병아리콩 커리", .curryPlate),
            ("양배추 샐러드", .sideBowl), ("치즈 그라탕", .bakeDish), ("불고기 타코", .foldedWrap),
            ("돼지고기 탕수육", .skillet), ("설렁탕", .stewPot),   // 합성어(그라탕·탕수육) vs 진짜 `탕`
            ("새우 파스타", .pastaPlate), ("햄 샌드위치", .sandwichStack), ("새우 볶음밥", .platedMound),
        ]
        for (name, expected) in cases {
            let look = DishGlyphCatalog.look(id: "custom-\(name)", name: name, cuisine: nil)
            #expect(look.archetype == expected, "\(name) → \(look.archetype.rawValue)(기대 \(expected.rawValue))")
        }
    }

    @Test func fallbackReadsArchetypeFromEnglishName() {
        let cases: [(String, DishArchetype)] = [
            ("Chicken Noodle Soup", .noodleBowl),   // 더 구체적인 noodle 규칙이 soup보다 먼저다
            ("Pumpkin Soup", .soupBowl), ("Beef Stew", .stewPot), ("Shrimp Fried Rice", .platedMound),
            ("Club Sandwich", .sandwichStack), ("Veggie Burrito", .foldedWrap),
            ("Lemon Risotto", .platedMound), ("Grilled Chicken", .grillPlate),
        ]
        for (name, expected) in cases {
            let look = DishGlyphCatalog.look(id: "custom-\(name)", name: name, cuisine: nil)
            #expect(look.archetype == expected, "\(name) → \(look.archetype.rawValue)(기대 \(expected.rawValue))")
        }
    }

    @Test func countryNamesDoNotHijackTheArchetype() {
        // "중국"의 `국`이 수프 규칙에, "태국"의 `국`이 같은 규칙에 걸리면 요리가 통째로 엉뚱해진다.
        #expect(DishGlyphCatalog.look(id: "x1", name: "중국식 가지볶음", cuisine: "chinese").archetype == .skillet)
        #expect(DishGlyphCatalog.look(id: "x2", name: "태국식 삼겹살구이", cuisine: "thai").archetype == .grillPlate)
        #expect(DishGlyphCatalog.look(id: "x3", name: "일본식 함박스테이크", cuisine: "japanese").archetype == .grillPlate)
    }

    @Test func fallbackFallsBackToCuisineWhenNoKeywordMatches() {
        #expect(DishGlyphCatalog.look(id: "y1", name: "Halmeoni Special", cuisine: "korean").archetype == .stewPot)
        #expect(DishGlyphCatalog.look(id: "y2", name: "Nonna Special", cuisine: "italian").archetype == .pastaPlate)
        // cuisine조차 없어도 원형이 나온다 — 빈 아이콘은 없다.
        #expect(DishGlyphCatalog.look(id: "y3", name: "Mystery Plate", cuisine: nil).archetype == .soupBowl)
    }

    @Test func fallbackIsStableAcrossRuns() {
        // `String.hashValue`는 실행마다 시드가 달라진다 — 그걸 쓰면 같은 레시피가 런치마다 색이 바뀐다.
        #expect(DishGlyphCatalog.stableHash("kimchi-jjigae") == DishGlyphCatalog.stableHash("kimchi-jjigae"))
        #expect(DishGlyphCatalog.stableHash("a") != DishGlyphCatalog.stableHash("b"))
        let a = DishGlyphCatalog.look(id: "same-id", name: "Mystery", cuisine: "korean")
        let b = DishGlyphCatalog.look(id: "same-id", name: "Mystery", cuisine: "korean")
        #expect(a == b)
    }

    @Test func unmappedRecipesInTheSameBucketStillDiffer() {
        // 폴백이 몰리는 상황(커스텀 레시피 여럿)에서도 id 해시로 색이 갈린다.
        let looks = (1...8).map {
            DishGlyphCatalog.look(id: "custom-\($0)", name: "Mystery Plate", cuisine: "korean")
        }
        #expect(Set(looks).count == looks.count, "폴백 레시피들이 서로 같은 아이콘을 받았다")
    }
}

/// 티켓 히어로 아이콘 폴백 체인(`Recipe.heroIcon` §13.5) — **두 일러스트 시스템 사이의 우선순위 계약**.
/// 요리 카탈로그(`DishSilhouette`)와 재료 글리프(`PaperSilhouette`)가 공존하므로, 어느 레시피가
/// 어느 쪽으로 가는지가 흔들리면 축약 티켓의 얼굴이 바뀐다(비빔밥이 시금치 잎으로 뜨던 회귀).
struct RecipeHeroIconTests {

    /// ① 시드는 전부 요리 그림 — 축약 티켓 146pt에서 재료 글리프가 뜨면 안 된다.
    @Test func everySeedRecipeShowsItsCuratedDish() {
        for r in seedRecipesForTests() {
            #expect(r.heroIcon == .dish(DishGlyphCatalog.look(for: r)),
                    "\(r.id)(\(r.name.ko ?? r.name.en))의 히어로가 요리 카탈로그를 타지 않는다")
        }
    }

    /// ① 사용자 불만 지점 3케이스 — 원형까지 못 박는다(비빔밥=덮밥 공기, 김밥=롤 단면, 잡채=면기).
    @Test func reportedSeedRecipesUseTheRightArchetype() {
        let expected: [String: DishArchetype] = [
            "bibimbap": .riceBowl, "gimbap": .rollSlices, "japchae": .noodleBowl,
        ]
        let seeds = seedRecipesForTests()
        for (id, archetype) in expected {
            guard let r = seeds.first(where: { $0.id == id }) else {
                Issue.record("시드 \(id)를 찾지 못했다"); continue
            }
            guard case .dish(let look) = r.heroIcon else {
                Issue.record("\(id)가 요리 그림이 아니다: \(r.heroIcon)"); continue
            }
            #expect(look.archetype == archetype, "\(id) → \(look.archetype.rawValue)")
        }
    }

    /// ② 커스텀 "김밥"은 **손으로 그린 요리형 글리프**를 유지한다 — 카탈로그 이름 추론(③)이
    /// 앞서면 원형만 롤이고 색은 id 해시라 아무 색 롤이 된다.
    @Test func customGimbapKeepsTheCuratedDishGlyph() {
        let recipe = Recipe.userRecipe(name: "김밥", ingredientNames: ["김", "밥", "계란", "당근"],
                                       minutes: 20, steps: ["말기"])
        #expect(recipe.heroIcon == .food(.gimbap))
        // 파생 표기도 같은 그림(이름 부분 일치).
        let tuna = Recipe.userRecipe(name: "참치김밥", ingredientNames: ["참치", "김"],
                                     minutes: 15, steps: ["말기"])
        #expect(tuna.heroIcon == .food(.gimbap))
    }

    /// ③ 이름이 요리를 지목하는 커스텀은 카탈로그 추론으로 **요리 그림**을 받는다.
    /// 결과가 `look(for:)`와 같아야 목록(`MyRecipesView`)과 티켓이 같은 그림을 쓴다.
    @Test func customDishNameFallsBackToCatalogInference() {
        let cases: [(String, DishArchetype)] = [
            ("된장찌개", .stewPot), ("새우 파스타", .pastaPlate), ("치즈 그라탕", .bakeDish),
        ]
        for (name, archetype) in cases {
            let r = Recipe.userRecipe(name: name, ingredientNames: ["두부", "양파"],
                                      minutes: 20, steps: ["끓이기"])
            #expect(r.heroIcon == .dish(DishGlyphCatalog.look(for: r)),
                    "\(name)이 카탈로그 추론을 타지 않는다: \(r.heroIcon)")
            guard case .dish(let look) = r.heroIcon else { continue }
            #expect(look.archetype == archetype, "\(name) → \(look.archetype.rawValue)")
        }
    }

    /// ④ 이름이 아무 요리도 지목하지 않으면 **재료**로 내려간다 — cuisine 기본값만 보고
    /// "한식이니 찌개"라고 단정하지 않는다(없는 요리를 그리느니 실제 재료를 보여준다).
    @Test func namelessDishFallsBackToTheIngredientGlyph() {
        let r = Recipe.userRecipe(name: "Halmeoni Special", ingredientNames: ["토마토", "양파"],
                                  minutes: 20, steps: ["섞기"])
        #expect(r.heroIcon == .food(r.glyph), "요리로 못 읽히는 이름인데 요리 그림이 나왔다: \(r.heroIcon)")
        #expect(r.glyph == .tomato, "첫 비상비 재료가 대표여야 한다")
        // 대조 — 같은 레시피를 카탈로그에 직접 물으면 cuisine 기본(대접)을 짐작해 돌려준다.
        #expect(DishGlyphCatalog.nameMatchedLook(for: r) == nil,
                "이름이 침묵하는데 카탈로그가 요리를 단정했다")
    }

    /// 체인이 카탈로그와 **갈리는 지점은 ②·④뿐**이다 — 그 밖에선 `look(for:)`와 같은 요리 그림이라
    /// 카탈로그를 직접 부르는 다른 표면(내 레시피 목록·조리 화면·공유 카드)과 그림이 어긋나지 않는다.
    /// 갈릴 때도 이유가 하나씩이라야 한다: ② 그려 둔 요리 글리프가 따로 있다 / ④ 이름이 침묵한다.
    @Test func heroIconDivergesFromTheCatalogOnlyWhereIntended() {
        let samples: [Recipe] = seedRecipesForTests() + [
            Recipe.userRecipe(name: "김밥", ingredientNames: ["김", "밥"], minutes: 20, steps: ["말기"]),
            Recipe.userRecipe(name: "된장찌개", ingredientNames: ["두부"], minutes: 20, steps: ["끓이기"]),
            Recipe.userRecipe(name: "Halmeoni Special", ingredientNames: ["토마토"], minutes: 20, steps: ["섞기"]),
        ]
        for r in samples {
            switch r.heroIcon {
            case .dish(let look):
                #expect(look == DishGlyphCatalog.look(for: r),
                        "\(r.name.en): 요리 그림인데 카탈로그와 변주가 다르다")
            case .food:
                let curated = Recipe.dishGlyph(for: r.name) != nil
                let silentName = DishGlyphCatalog.nameMatchedLook(for: r) == nil
                #expect(curated || silentName,
                        "\(r.name.en): 요리로 읽히는 이름인데 재료 그림으로 내려갔다")
            }
        }
    }
}

/// 매핑이 **실제 픽셀에 도달하는지**를 시드 80개 전부에 대해 확인한다(`WiltRenderTests` 선례).
/// 갤러리 스크린샷은 첫 판만 담아 아래쪽이 사각지대로 남는다 — 여기서 오프스크린 래스터로 전수 검사한다.
@MainActor
struct DishRenderTests {

    /// 아이콘 하나를 side×side로 래스터해 RGBA와 실루엣 마스크(알파 > 127)를 뽑는다.
    /// 그림자를 꺼서(`shadowed: false`) 비교가 블러에 흔들리지 않게 한다.
    static func raster(_ look: DishLook, side: Int = 72) -> (rgba: [UInt8], drawn: Int)? {
        let renderer = ImageRenderer(content:
            DishSilhouette(look: look, shadowed: false)
                .frame(width: CGFloat(side), height: CGFloat(side)))
        renderer.scale = 1
        guard let cg = renderer.uiImage?.cgImage else { return nil }
        var data = [UInt8](repeating: 0, count: side * side * 4)
        guard let ctx = CGContext(data: &data, width: side, height: side, bitsPerComponent: 8,
                                  bytesPerRow: side * 4, space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: side, height: side))
        var drawn = 0
        for i in stride(from: 0, to: data.count, by: 4) where data[i + 3] > 127 { drawn += 1 }
        return (data, drawn)
    }

    /// 두 래스터가 눈에 띄게 다른 픽셀의 개수 — 알파가 다르거나, 그려진 자리의 색이 10 이상 어긋난 곳.
    static func differingPixels(_ a: [UInt8], _ b: [UInt8]) -> Int {
        var n = 0
        for i in stride(from: 0, to: a.count, by: 4) {
            let (aa, ab) = (a[i + 3], b[i + 3])
            if (aa > 127) != (ab > 127) { n += 1; continue }
            guard aa > 127 else { continue }
            for c in 0..<3 where abs(Int(a[i + c]) - Int(b[i + c])) >= 10 { n += 1; break }
        }
        return n
    }

    @Test func everySeedRecipeRendersSomething() {
        // 빈 아이콘 0 — 원형 draw가 좌표를 잘못 잡아 화면 밖으로 나가면 여기서 걸린다.
        for r in seedRecipesForTests() {
            guard let img = Self.raster(DishGlyphCatalog.look(for: r)) else {
                Issue.record("\(r.id) 래스터 실패"); continue
            }
            // 72×72 = 5184px. 요리 아이콘은 그릇이 화면 대부분을 차지하므로 15%는 최소선이다.
            #expect(img.drawn > 5184 * 15 / 100,
                    "\(r.id)(\(r.name.ko ?? r.name.en)): 그려진 픽셀이 너무 적다(\(img.drawn)/5184)")
        }
    }

    @Test func fallbackRecipesAlsoRender() {
        // 매핑 밖 경로도 픽셀까지 도달하는지 — 폴백이 원형만 고르고 색을 못 채우는 회귀를 막는다.
        for a in DishArchetype.allCases {
            let look = DishGlyphCatalog.fallback(name: "Mystery", koreanName: nil,
                                                 cuisine: nil, id: "z")
            var probe = look
            probe.archetype = a   // 원형 전수 — 폴백 색 조합이 어느 원형에 붙어도 그려져야 한다
            guard let img = Self.raster(probe) else { Issue.record("\(a.rawValue) 래스터 실패"); continue }
            #expect(img.drawn > 5184 * 10 / 100, "\(a.rawValue) 폴백이 거의 안 그려졌다(\(img.drawn))")
        }
    }

    @Test func recipesSharingAnArchetypeRenderDifferentPixels() {
        // 원형 시스템의 핵심 계약 — **같은 원형이라도 색·고명이 다르면 다른 요리로 읽혀야 한다.**
        // 변주가 렌더까지 도달하지 않으면(예: mark가 클립 밖에 놓임) 여기서 걸린다.
        var byArchetype: [DishArchetype: [(id: String, rgba: [UInt8], drawn: Int)]] = [:]
        for r in seedRecipesForTests() {
            let look = DishGlyphCatalog.look(for: r)
            guard let img = Self.raster(look) else { Issue.record("\(r.id) 래스터 실패"); continue }
            byArchetype[look.archetype, default: []].append((r.id, img.rgba, img.drawn))
        }
        for (archetype, items) in byArchetype where items.count >= 2 {
            for i in 0..<items.count {
                for j in (i + 1)..<items.count {
                    let diff = Self.differingPixels(items[i].rgba, items[j].rgba)
                    let base = max(items[i].drawn, 1)
                    #expect(diff * 100 / base >= 3,
                            """
                            \(archetype.rawValue): \(items[i].id) vs \(items[j].id)가 \
                            거의 같은 픽셀이다(\(diff)/\(base) = \(diff * 100 / base)%)
                            """)
                }
            }
        }
    }
}

/// 공유 카드(`RecipeShareCard`)의 **오프스크린 경로**를 잠근다.
/// 공유 이미지는 화면이 아니라 `ImageRenderer`가 만든다 — 화면에선 멀쩡한 `Canvas` 요리 아이콘이
/// 래스터에서만 비어도 스크린샷 QA로는 안 잡힌다(공유된 영수증에만 그림이 빠진다).
@MainActor
struct ShareCardRenderTests {

    /// 실제 공유 경로(`CookingStepsView.renderShareImage`)와 같은 설정 — scale 3 · 라이트 고정.
    static func raster(recipe: Recipe, look: DishLook) -> [UInt8]? {
        let card = RecipeShareCard(recipeName: recipe.displayName, steps: recipe.displaySteps,
                                   count: recipe.ingredients.count, look: look)
            .environment(\.colorScheme, .light)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        guard let cg = renderer.uiImage?.cgImage else { return nil }
        let (w, h) = (cg.width, cg.height)
        var data = [UInt8](repeating: 0, count: w * h * 4)
        guard let ctx = CGContext(data: &data, width: w, height: h, bitsPerComponent: 8,
                                  bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        return data
    }

    @Test func shareCardCarriesTheDishIconThroughImageRenderer() {
        let seeds = seedRecipesForTests()
        guard let dish = seeds.first(where: { $0.id == "kimchi-jjigae" }),
              let other = seeds.first(where: { $0.id == "pancakes" }) else {
            Issue.record("시드 로드 실패 — 공유 카드 래스터를 검증할 수 없다"); return
        }
        guard let a = Self.raster(recipe: dish, look: DishGlyphCatalog.look(for: dish)) else {
            Issue.record("공유 카드가 ImageRenderer에서 래스터되지 않았다"); return
        }
        // 텍스트·레이아웃은 그대로 두고 **아이콘 변주만** 바꾼 두 번째 장.
        guard let b = Self.raster(recipe: dish, look: DishGlyphCatalog.look(for: other)),
              a.count == b.count else {
            Issue.record("대조군 래스터 실패"); return
        }
        var diff = 0
        for i in stride(from: 0, to: a.count, by: 4) where a[i] != b[i] || a[i + 1] != b[i + 1]
            || a[i + 2] != b[i + 2] { diff += 1 }
        // 아이콘은 56pt × scale 3 = 168² ≈ 28k px. 그 일부만 달라도 통과하되, 0이면 Canvas가 빈 것이다.
        #expect(diff > 1000,
                "아이콘 변주만 바꿨는데 공유 카드 래스터가 사실상 같다(\(diff)px) — 오프스크린에서 요리 아이콘이 비었다")
    }
}
