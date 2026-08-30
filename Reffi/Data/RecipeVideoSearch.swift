import Foundation

/// 레시피 영상 검색 URL — 조리법의 1차 경로(§13.6 4-1)를 만드는 **단일 공급원**.
///
/// 조리 화면의 "Videos" CTA(AX 라벨 "Open recipe videos")와 티켓 덱의 빈 상태 영상 안내가 같은
/// 함수를 쓴다(미커버 임박 행은 41차에 빠졌다). 표면마다 URL 조립을 다시 쓰면 인코딩 규칙이 갈려 한쪽만 조용히 유튜브 홈으로
/// 떨어진다 — 조리법을 못 찾는 사용자에게 남는 유일한 출구라 그 침묵이 비싸다.
enum RecipeVideoSearch {

    /// 인코딩·URL 생성 실패 시의 폴백(유튜브 홈) — 빈 URL을 만들어 버튼을 죽이지 않는다.
    static let home = URL(string: "https://www.youtube.com")!

    /// 쿼리 값에 허용할 문자 — `.urlQueryAllowed`에서 **쿼리 문법 문자**(`&`·`+`·`=`·`?`)를 뺀다.
    /// 표준 집합은 이 넷을 그대로 통과시키므로 "Mac & Cheese" 같은 이름이 들어오면 `search_query`
    /// 값이 "Mac "에서 끊기고 나머지가 별개 파라미터가 된다(`+`는 유튜브가 공백으로 읽는다).
    /// 두 호출부 모두 사용자 자유 입력(커스텀 레시피명·사전 밖 재료명)이라 실제로 나타날 수 있다.
    private static let queryAllowed = CharacterSet.urlQueryAllowed
        .subtracting(CharacterSet(charactersIn: "&+=?"))

    /// 검색 URL — 쿼리를 퍼센트 인코딩해 유튜브 검색 결과로 보낸다.
    static func url(query: String) -> URL {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: queryAllowed) else {
            return home
        }
        return URL(string: "https://www.youtube.com/results?search_query=\(encoded)") ?? home
    }

    /// 검색어 접미사 조립의 **단일 지점**(42차) — "recipe"는 영어 키워드라 한국어 사용자의 질의어로는
    /// 틀린다(ko 정답은 "레시피" — 검색 결과 품질을 직접 정한다). 카탈로그 키 `"%@ recipe"`를 타서
    /// 접미사 낱말을 언어가 정하게 한다. 세 호출부(재료 1종·재료 여럿·레시피명)가 전부 여기를 지난다.
    private static func query(for subject: String) -> String {
        String(localized: "\(subject) recipe")
    }

    /// 레시피명으로 여는 검색 — 조리 화면 "Open recipe videos"의 목적지(42차, 접합 단일화).
    static func urlForRecipe(_ name: String) -> URL {
        url(query: query(for: name))
    }

    /// 재료 이름 하나로 여는 검색 — "<재료> recipe". 티켓이 못 다루는 임박 재료의 출구다.
    static func urlForIngredient(_ name: String) -> URL {
        url(query: query(for: name))
    }

    /// **호명된 이름 전부**로 여는 검색 — "<재료> <재료> recipe". 브리지 문구가 최대 2종을 부르는데
    /// 버튼이 첫 번째만 열면 두 번째 재료에는 같은 침묵이 그대로 남는다(문구와 버튼의 책임 범위 일치).
    /// 공백으로 잇는다 — `", "`는 검색어에 구두점을 섞고, 유튜브는 공백 나열을 함께 쓰는 레시피로 읽는다.
    /// 빈 배열이면 "recipe"뿐인 무의미한 검색 대신 홈으로 떨어진다.
    static func urlForIngredients(_ names: [String]) -> URL {
        let joined = names
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        guard !joined.isEmpty else { return home }
        return url(query: query(for: joined))
    }
}
