import Testing
import Foundation
@testable import Reffi

/// NicknameGenerator — 위트 있는 자동 닉네임("형용사 + 식재료") 생성기.
/// 시드 결정성 · 풀 형식(빈 문자열·중복 없음) · 조합 형태(형용사+명사)를 검증한다.
struct NicknameGeneratorTests {

    /// 결정적 시드 난수 — 같은 시드로 새로 만들면 항상 같은 시퀀스(splitmix 계열 LCG).
    /// 실제 프로덕션 코드에는 없다 — `generate(locale:using:)`의 시드 주입 지점만 테스트에서 채운다.
    private struct SeededGenerator: RandomNumberGenerator {
        private var state: UInt64
        init(seed: UInt64) { state = seed }
        mutating func next() -> UInt64 {
            state = 6364136223846793005 &* state &+ 1442695040888963407
            return state
        }
    }

    @Test func sameSeedProducesSameNickname() {
        // 같은 시드로 "새로" 만든 두 제너레이터는 같은 위치에서 시작하므로 같은 결과를 내야 한다.
        var rngA = SeededGenerator(seed: 42)
        var rngB = SeededGenerator(seed: 42)
        let a = NicknameGenerator.generate(locale: Locale(identifier: "ko_KR"), using: &rngA)
        let b = NicknameGenerator.generate(locale: Locale(identifier: "ko_KR"), using: &rngB)
        #expect(a == b)

        var rngC = SeededGenerator(seed: 7)
        var rngD = SeededGenerator(seed: 7)
        let c = NicknameGenerator.generate(locale: Locale(identifier: "en_US"), using: &rngC)
        let d = NicknameGenerator.generate(locale: Locale(identifier: "en_US"), using: &rngD)
        #expect(c == d)
    }

    @Test func poolsHaveNoEmptyOrDuplicateEntries() {
        let pools: [[String]] = [
            NicknameGenerator.adjectivesKo, NicknameGenerator.adjectivesEn,
            NicknameGenerator.nounsKo, NicknameGenerator.nounsEn,
        ]
        for pool in pools {
            #expect(!pool.isEmpty)
            #expect(pool.allSatisfy { !$0.trimmingCharacters(in: .whitespaces).isEmpty })
            #expect(Set(pool).count == pool.count)   // 중복 없음
        }
        // 스펙 하한(형용사 ~24개·명사 ~30개) — 정확한 개수가 아니라 하한만 고정해 풀 보강엔 열려 있다.
        #expect(NicknameGenerator.adjectivesKo.count >= 20)
        #expect(NicknameGenerator.adjectivesEn.count >= 20)
        #expect(NicknameGenerator.nounsKo.count >= 24)
        #expect(NicknameGenerator.nounsEn.count >= 24)
    }

    @Test func generatedNicknameComposesAdjectiveAndNounFromPools() {
        var rngKo = SeededGenerator(seed: 123)
        let ko = NicknameGenerator.generate(locale: Locale(identifier: "ko_KR"), using: &rngKo)
        let koParts = ko.split(separator: " ", maxSplits: 1)
        #expect(koParts.count == 2)
        #expect(NicknameGenerator.adjectivesKo.contains(String(koParts[0])))
        #expect(NicknameGenerator.nounsKo.contains(String(koParts[1])))

        var rngEn = SeededGenerator(seed: 456)
        let en = NicknameGenerator.generate(locale: Locale(identifier: "en_US"), using: &rngEn)
        // "Sweet Potato"·"Cherry Tomato"처럼 명사 자체가 공백을 포함할 수 있어 첫 공백에서만 자른다.
        let enParts = en.split(separator: " ", maxSplits: 1)
        #expect(enParts.count == 2)
        #expect(NicknameGenerator.adjectivesEn.contains(String(enParts[0])))
        #expect(NicknameGenerator.nounsEn.contains(String(enParts[1])))
    }
}

/// ProfileStore의 자동 닉네임 배정 가드 — "미설정일 때만" 생성하고, 사용자가 지은 닉네임은
/// 절대 건드리지 않는지 검증한다(§가입 직후 자동 닉네임 생성, ProfileStore.assignGeneratedNicknameIfUnset).
struct ProfileStoreNicknameSeedingTests {

    /// 격리된 임시 UserDefaults 스위트 — 실행 전 잔여값 제거(LexiconRecommenderTests 선례).
    private func freshSuite(_ name: String) -> UserDefaults {
        let suite = UserDefaults(suiteName: name)!
        suite.removePersistentDomain(forName: name)
        return suite
    }

    @Test func freshProfileStoreReplacesUnsetOrDefaultNicknameWithGenerated() {
        // 케이스 ① 저장값 자체가 없음 — 순수 신규 설치(신규 프로필 최초 시드).
        let nameA = "test.nickname.fresh"
        let freshStore = ProfileStore(defaults: freshSuite(nameA))
        #expect(!freshStore.nickname.isEmpty)
        #expect(freshStore.nickname != "Reffi")
        #expect(freshStore.nickname.contains(" "))   // "형용사 + 명사" 형태
        UserDefaults(suiteName: nameA)?.removePersistentDomain(forName: nameA)

        // 케이스 ② 이 기능 이전 빌드가 남긴, 손대지 않은 기본값 "Reffi" 그대로.
        let nameB = "test.nickname.legacyDefault"
        let suiteB = freshSuite(nameB)
        suiteB.set("Reffi", forKey: "profile.nickname")
        let legacyStore = ProfileStore(defaults: suiteB)
        #expect(legacyStore.nickname != "Reffi")
        #expect(!legacyStore.nickname.isEmpty)
        UserDefaults(suiteName: nameB)?.removePersistentDomain(forName: nameB)
    }

    @Test func assignGeneratedNicknameIfUnsetPreservesUserChosenNickname() {
        let name = "test.nickname.custom"
        let suite = freshSuite(name)
        suite.set("Chef Kevin", forKey: "profile.nickname")
        let store = ProfileStore(defaults: suite)
        #expect(store.nickname == "Chef Kevin")   // init 시점부터 이미 보존(가드가 덮어쓰지 않음)

        // 명시 재호출도 가드가 막아야 한다 — 가입 완료 훅(ReffiApp.reconcileDataOwner)이
        // 이미 커스터마이즈된 프로필에 대해 재호출하는 경로를 재현.
        store.assignGeneratedNicknameIfUnset()
        #expect(store.nickname == "Chef Kevin")
        UserDefaults(suiteName: name)?.removePersistentDomain(forName: name)
    }
}
