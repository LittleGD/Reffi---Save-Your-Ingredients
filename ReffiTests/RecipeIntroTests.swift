import Testing
import Foundation
@testable import Reffi

/// 요리 소개 한 줄(`Recipe.intro`) — 시드 데이터 무결성 + 로케일 표시 규칙.
///
/// 소개문은 UI 문자열이 아니라 **레시피 데이터의 일부**라 `Localizable.xcstrings`가 아니라
/// `recipes-seed.json`이 en·ko를 함께 들고 있다(`name`과 같은 구조). 그래서 번역 누락을
/// 잡아 주는 카탈로그 도구가 없고, **이 테스트가 유일한 방지선**이다: 시드에 레시피를 새로
/// 추가하면서 소개를 빠뜨리거나 한쪽 언어만 채우면 여기서 즉시 드러난다.
///
/// 길이 상한은 티켓 폭에서 캡션이 **최대 2줄**로 앉게 하는 실측 기준이다(§13.6 4-1) —
/// 넘치면 `lineLimit(2)`가 말줄임해 문장이 잘린 채 남는다.
struct RecipeIntroTests {

    /// 상한 — **실측에서 되짚은 값**이다. iPhone 17 조리 티켓 스크린샷에서 비빔밥 영문 소개
    /// 79자가 정확히 2줄을 채웠고(1줄 ≈ 43자), 줄바꿈 지점에 따라 2줄 한계는 대략 86자다.
    /// 그래서 처음 잡았던 90자는 `lineLimit(2)`에 말줄임될 수 있어 상한 구실을 못 한다.
    /// 한글은 글자폭이 넓어(영문 대비 약 2배) 같은 2줄 예산을 글자 수로 환산해 잡았다 —
    /// 영문만 스크린샷으로 확인했으므로 한글 값은 환산 추정임을 밝혀 둔다(현재 최대 37자).
    private let enCap = 86
    private let koCap = 45

    private var seed: [Recipe] { RecipeCatalog.loadSeed() }

    @Test func seedLoadsWithEveryRecipeIntroduced() throws {
        let recipes = seed
        #expect(recipes.count == 80, "시드 레시피 수가 바뀌었다 — 새 레시피에도 소개가 필요하다")
        for r in recipes {
            let intro = try #require(r.intro, "\(r.id): intro 누락")
            #expect(!intro.en.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                    "\(r.id): 영문 소개가 비었다")
            let ko = try #require(intro.ko, "\(r.id): 한글 소개 누락(en만 채우면 한국어에서 영문이 뜬다)")
            #expect(!ko.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                    "\(r.id): 한글 소개가 비었다")
        }
    }

    @Test func introsFitTheCaptionLineBudget() throws {
        for r in seed {
            let intro = try #require(r.intro)
            #expect(intro.en.count <= enCap,
                    "\(r.id): 영문 소개 \(intro.en.count)자 — 상한 \(enCap)자를 넘겨 2줄에 안 들어간다")
            let ko = try #require(intro.ko)
            #expect(ko.count <= koCap,
                    "\(r.id): 한글 소개 \(ko.count)자 — 상한 \(koCap)자를 넘겨 2줄에 안 들어간다")
        }
    }

    /// 대시 금지 — **사용자 카피 선호**다(2026-08, "큰 하이픈 빼 주세요").
    /// em 대시(—)·en 대시(–) 모두 쓰지 않고, 쉼표로 갈아끼우는 대신 문장을 다시 쓴다.
    /// 단어 안의 보통 하이픈("stir-fried")은 대상이 아니다.
    @Test func introsAvoidEmAndEnDashes() {
        for r in seed {
            guard let intro = r.intro else { continue }
            for (locale, text) in [("en", intro.en), ("ko", intro.ko ?? "")] {
                #expect(!text.contains("\u{2014}"), "\(r.id).\(locale): em 대시(—)는 쓰지 않는다 — \(text)")
                #expect(!text.contains("\u{2013}"), "\(r.id).\(locale): en 대시(–)는 쓰지 않는다 — \(text)")
            }
        }
    }

    /// 소개는 **요리를 설명해야** 한다 — 이름만 되풀이하거나 템플릿을 복사한 문장을 막는다.
    /// (전수 검사가 아니라 명백한 퇴행만 잡는 얕은 그물이다: 문장이 전부 같거나, 한 단어짜리거나.)
    @Test func introsAreDistinctAndNotBoilerplate() {
        let recipes = seed
        let ens = Set(recipes.compactMap { $0.intro?.en })
        let kos = Set(recipes.compactMap { $0.intro?.ko })
        #expect(ens.count == recipes.count, "영문 소개에 중복 문장이 있다(복붙 보일러플레이트)")
        #expect(kos.count == recipes.count, "한글 소개에 중복 문장이 있다(복붙 보일러플레이트)")
        for r in recipes {
            #expect((r.intro?.en.split(separator: " ").count ?? 0) >= 4,
                    "\(r.id): 영문 소개가 설명이라기엔 너무 짧다")
        }
    }

    // MARK: - displayIntro 표시 규칙

    private func recipe(intro: Recipe.LocalizedName?) -> Recipe {
        Recipe(id: "t", name: Recipe.LocalizedName(en: "Test", ko: "테스트"), intro: intro,
               cuisine: nil, minutes: 10,
               ingredients: [Recipe.Item(ref: nil, en: "x", ko: nil)],
               steps: Recipe.LocalizedSteps(en: [], ko: nil), isUser: nil)
    }

    @Test func displayIntroFollowsLocaleLikeDisplayName() {
        let r = recipe(intro: Recipe.LocalizedName(en: "English intro.", ko: "한글 소개."))
        // 이름과 **같은 축**으로 고른다 — 한 티켓에서 이름은 한글인데 소개만 영문이면 안 된다.
        #expect(r.displayIntro == (Recipe.isKorean ? "한글 소개." : "English intro."))
        #expect(r.displayName == (Recipe.isKorean ? "테스트" : "Test"))
    }

    @Test func displayIntroFallsBackToEnglishWhenKoreanMissing() {
        // ko가 없으면 영문으로 — 빈 자리를 남기지 않는다(`displayName`의 `ko ?? en`과 같은 규칙).
        let r = recipe(intro: Recipe.LocalizedName(en: "Only English.", ko: nil))
        #expect(r.displayIntro == "Only English.")
    }

    @Test func displayIntroIsNilForRecipesWithoutIntro() {
        // 사용자 커스텀 레시피는 소개가 없다 — nil이어야 조리 티켓이 캡션 자리를 아예 비운다.
        #expect(recipe(intro: nil).displayIntro == nil)
        let custom = Recipe.userRecipe(name: "내 레시피", ingredientNames: ["계란"], minutes: 10)
        #expect(custom.intro == nil)
        #expect(custom.displayIntro == nil)
    }

    @Test func displayIntroFoldsWhitespaceOnlyIntroToNil() {
        // 공백만 남은 값이 통과하면 캡션이 여백만 벌린다.
        #expect(recipe(intro: Recipe.LocalizedName(en: "   ", ko: "  ")).displayIntro == nil)
    }

    @Test func recipeDecodesWithoutIntroKey() throws {
        // 구버전 저장 파일·커스텀 레시피는 intro 키가 없다 — 디코드가 깨지면 사용자 레시피가 사라진다.
        let json = """
        {"id":"legacy","name":{"en":"Legacy","ko":null},"cuisine":null,"minutes":10,
        "ingredients":[{"ref":null,"en":"egg","ko":null}],"steps":{"en":[],"ko":null},"isUser":true}
        """.replacingOccurrences(of: "\n", with: "")
        let decoded = try JSONDecoder().decode(Recipe.self, from: Data(json.utf8))
        #expect(decoded.intro == nil)
        #expect(decoded.displayIntro == nil)
        #expect(decoded.displayName == "Legacy")
    }
}
