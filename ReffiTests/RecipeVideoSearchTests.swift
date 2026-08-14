import Testing
import Foundation
@testable import Reffi

/// 레시피 영상 검색 URL — 조리 화면·티켓 덱 브리지가 **공유하는** 단일 공급원.
/// 조립 규칙이 갈리면 한쪽만 조용히 유튜브 홈으로 떨어지고, 조리법을 못 찾는 사용자에겐
/// 그 버튼이 유일한 출구라 침묵이 비싸다.
struct RecipeVideoSearchTests {

    @Test func buildsSearchQueryURL() throws {
        let url = RecipeVideoSearch.url(query: "kimchi stew recipe")
        #expect(url.absoluteString == "https://www.youtube.com/results?search_query=kimchi%20stew%20recipe")
        let comps = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(comps.host == "www.youtube.com")
        #expect(comps.path == "/results")
        // 디코드된 값이 원문 그대로여야 유튜브가 같은 검색을 연다.
        #expect(comps.queryItems?.first?.name == "search_query")
        #expect(comps.queryItems?.first?.value == "kimchi stew recipe")
    }

    @Test func percentEncodesKoreanAndSpaces() throws {
        let url = RecipeVideoSearch.url(query: "두부 recipe")
        // 한글은 UTF-8 퍼센트 인코딩, 공백은 %20 — 원문이 URL에 날것으로 새지 않는다.
        #expect(url.absoluteString.contains("%EB%91%90%EB%B6%80%20recipe"))
        let comps = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(comps.queryItems?.first?.value == "두부 recipe")
    }

    @Test func ingredientHelperAppendsRecipeKeyword() {
        // 재료 브리지는 "<재료> recipe" 한 가지 모양만 만든다(조리 화면의 레시피명 경로와 같은 꼴).
        #expect(RecipeVideoSearch.urlForIngredient("두부") == RecipeVideoSearch.url(query: "두부 recipe"))
    }

    @Test func emptyQueryStillReturnsAUsableURL() {
        // 빈 문자열이라도 죽은 버튼(nil URL)을 만들지 않는다 — 최악이 유튜브 검색 결과 화면이다.
        let url = RecipeVideoSearch.url(query: "")
        #expect(url.scheme == "https")
        #expect(url.host == "www.youtube.com")
    }
}
