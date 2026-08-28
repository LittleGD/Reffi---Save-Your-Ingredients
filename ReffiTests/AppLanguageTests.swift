import Testing
@testable import Reffi

/// `AppLanguage.resolve(stored:)`(2026-08, 38차) — 저장된 원시값에서 실제 선택으로 가는 판정을
/// 뷰 없이 고정한다(`FridgeTab.initial(from:)`과 같은 문법). 미설정·구버전 잔재 문자열 모두
/// system으로 안전하게 접혀야 한다 — 잘못 접히면 앱이 조용히 엉뚱한 언어로 뜬다.
struct AppLanguageTests {
    @Test func unsetStoredResolvesToSystem() {
        #expect(AppLanguage.resolve(stored: nil) == .system)
    }

    @Test func knownCodesResolveToThemselves() {
        #expect(AppLanguage.resolve(stored: "en") == .en)
        #expect(AppLanguage.resolve(stored: "ko") == .ko)
        #expect(AppLanguage.resolve(stored: "system") == .system)
    }

    @Test func unknownStoredValueFallsBackToSystem() {
        #expect(AppLanguage.resolve(stored: "fr") == .system)
        #expect(AppLanguage.resolve(stored: "") == .system)
    }
}
