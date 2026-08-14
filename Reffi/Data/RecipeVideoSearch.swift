import Foundation

/// 레시피 영상 검색 URL — 조리법의 1차 경로(§13.6 4-1)를 만드는 **단일 공급원**.
///
/// 조리 화면의 "Open recipe videos" CTA와 티켓 덱의 영상 브리지(빈 상태·미커버 임박 행)가 같은
/// 함수를 쓴다. 표면마다 URL 조립을 다시 쓰면 인코딩 규칙이 갈려 한쪽만 조용히 유튜브 홈으로
/// 떨어진다 — 조리법을 못 찾는 사용자에게 남는 유일한 출구라 그 침묵이 비싸다.
enum RecipeVideoSearch {

    /// 인코딩·URL 생성 실패 시의 폴백(유튜브 홈) — 빈 URL을 만들어 버튼을 죽이지 않는다.
    static let home = URL(string: "https://www.youtube.com")!

    /// 검색 URL — 쿼리를 퍼센트 인코딩해 유튜브 검색 결과로 보낸다.
    /// `.urlQueryAllowed`는 `&`·`+`·`=`를 통과시키지만(이전 `CookingStepsView.youtubeSearchURL`과
    /// 동일한 동작을 그대로 옮긴 것이다) 레시피명·재료명에는 사실상 나타나지 않는다.
    static func url(query: String) -> URL {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return home
        }
        return URL(string: "https://www.youtube.com/results?search_query=\(encoded)") ?? home
    }

    /// 재료 이름 하나로 여는 검색 — "<재료> recipe". 티켓이 못 다루는 임박 재료의 출구다.
    static func urlForIngredient(_ name: String) -> URL {
        url(query: "\(name) recipe")
    }
}
