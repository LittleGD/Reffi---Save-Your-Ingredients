import Foundation

/// AI 레시피 파이프라인 — **끼울 자리(스캐폴드)**. 지금 실동작하는 소스는 시드/커스텀뿐이고,
/// 온디바이스 모델·클라우드 프록시는 자리만 예약되어 있다(isAvailable = false).
/// 소스 교체·추가 시 뷰/스토어는 손대지 않는다 — `RecipeEngine.standard`만 갱신하면 된다.
///
/// 로드맵(2026-07 리서치 확정):
///  1차  온디바이스 Foundation Models(iOS 26+, Apple Intelligence 기기) — @Generable 구조화 생성
///  2차  PCC(AFM 3 Cloud, iOS 27+) — Small Business Program 무료, 32K 컨텍스트
///  3차  Supabase Edge Function 프록시 → Groq(gpt-oss-120b) → OpenRouter :free → Cerebras 폴백 체인
///       (모델 ID는 앱이 아니라 서버 측 설정 — 무료 티어 조건이 수시로 바뀐다)
protocol RecipeSuggesting {
    var sourceID: String { get }
    /// 이 소스가 현 기기·현 시점에 실사용 가능한가(기기 지원·네트워크·권한).
    var isAvailable: Bool { get }
    /// 보유 재료 기반 레시피 제안. 실패는 throw — 엔진이 다음 소스로 폴백한다.
    func suggest(for ingredients: [Ingredient]) async throws -> [Recipe]
}

/// 시드 + 사용자 커스텀 — 항상 사용 가능한 최종 폴백(오프라인 포함).
struct SeedRecipeSource: RecipeSuggesting {
    let sourceID = "seed"
    var isAvailable: Bool { true }
    /// 스토어의 현재 레시피(시드+커스텀)를 늦게 평가 — 커스텀 추가가 즉시 반영된다.
    var provider: () -> [Recipe]

    func suggest(for ingredients: [Ingredient]) async throws -> [Recipe] { provider() }
}

/// 온디바이스 생성 — TODO(1차): FoundationModels `LanguageModelSession` + @Generable Recipe 스키마.
/// 켜는 조건: iOS 26+ && SystemLanguageModel.default.isAvailable (Apple Intelligence 기기).
/// 주의: 4K 컨텍스트(iOS 26) — 재료 목록은 이름만 직렬화해 보낼 것. 생성 결과는 Recipe로 매핑 후
/// 스토어 캐시에 영속화(오프라인 재사용).
struct OnDeviceModelRecipeSource: RecipeSuggesting {
    let sourceID = "on-device-fm"
    var isAvailable: Bool { false }   // TODO: FoundationModels 통합 시 가용성 검사로 교체

    func suggest(for ingredients: [Ingredient]) async throws -> [Recipe] {
        throw RecipeEngineError.sourceUnavailable(sourceID)
    }
}

/// 클라우드 프록시 — TODO(3차): Supabase Edge Function(키는 서버 secrets, 익명 로그인 + 사용자별
/// rate limit) 경유. 응답 스키마는 recipes-seed.json과 동일한 Recipe JSON.
/// Apple 심사 5.1.2(i): 재료 목록의 외부 전송은 앱 내 명시 동의 UI 후에만 호출할 것.
struct CloudProxyRecipeSource: RecipeSuggesting {
    let sourceID = "cloud-proxy"
    /// TODO: 엔드포인트 구성 + 사용자 동의 확인으로 교체.
    var isAvailable: Bool { false }

    func suggest(for ingredients: [Ingredient]) async throws -> [Recipe] {
        throw RecipeEngineError.sourceUnavailable(sourceID)
    }
}

enum RecipeEngineError: Error {
    case sourceUnavailable(String)
}

/// 소스 우선순위대로 시도, 첫 성공을 채택. 모두 실패하면 빈 배열(호출부가 빈 상태 UX).
struct RecipeEngine {
    var sources: [RecipeSuggesting]

    func recipes(for ingredients: [Ingredient]) async -> [Recipe] {
        for source in sources where source.isAvailable {
            if let result = try? await source.suggest(for: ingredients), !result.isEmpty {
                return result
            }
        }
        return []
    }

    /// 표준 구성 — 온디바이스 → 클라우드 → 시드/커스텀 순.
    static func standard(seed provider: @escaping () -> [Recipe]) -> RecipeEngine {
        RecipeEngine(sources: [
            OnDeviceModelRecipeSource(),
            CloudProxyRecipeSource(),
            SeedRecipeSource(provider: provider),
        ])
    }
}
