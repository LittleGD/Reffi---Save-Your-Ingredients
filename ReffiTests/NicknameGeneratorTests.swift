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

    /// **드리프트 가드** — 명사 풀 60개는 `ingredient-lexicon.json`의 1순위 표기를 손으로 복사한
    /// 두 번째 사본이다(생성기가 번들 로드 실패와 무관하게 동작해야 해서 런타임 조회를 안 한다).
    /// 사본이라 사전 표기를 고치면 여기가 조용히 어긋나고, 닉네임만 앱의 다른 화면과 다른 재료
    /// 이름을 쓰게 된다. 그 침묵을 이 테스트가 깨뜨린다 — 표기가 갈리는 순간 빌드가 빨개진다.
    ///
    /// 세 가지를 한꺼번에 못 박는다:
    /// ① 두 풀의 모든 표기가 정본 사전에 **정확 일치**로 존재한다(포함 매칭 폴백을 허용하지 않는다).
    /// ② 각 표기가 그 항목의 **1순위 표기**다(`displayName`이 고르는 바로 그 값 = 다른 화면과 동일).
    /// ③ ko/en 풀이 같은 인덱스에서 **같은 사전 항목**을 가리킨다(로케일이 바뀌어도 같은 재료).
    @Test func nounPoolsMatchTheLexiconVerbatim() {
        let lexicon = IngredientLexicon.shared
        try? #require(!lexicon.entries.isEmpty)   // 번들 리소스가 안 실렸으면 아래 단언이 전부 무의미

        #expect(NicknameGenerator.nounsKo.count == NicknameGenerator.nounsEn.count)

        for (ko, en) in zip(NicknameGenerator.nounsKo, NicknameGenerator.nounsEn) {
            guard let koID = lexicon.exactCanonicalID(for: ko) else {
                Issue.record("닉네임 명사 '\(ko)'가 정본 사전에 없다"); continue
            }
            guard let enID = lexicon.exactCanonicalID(for: en) else {
                Issue.record("닉네임 명사 '\(en)'가 정본 사전에 없다"); continue
            }
            #expect(koID == enID, "'\(ko)'와 '\(en)'가 서로 다른 항목을 가리킨다(\(koID) vs \(enID))")

            guard let entry = lexicon.entry(id: koID) else {
                Issue.record("\(koID) 항목 조회 실패"); continue
            }
            // 사전의 영문 캐논은 소문자라, 비교 대상은 `displayName`이 쓰는 표시형(첫 글자 대문자)이다.
            let enDisplay = entry.names.en.first?.localizedCapitalized
            #expect(entry.names.ko.first == ko, "\(koID)의 1순위 한글 표기가 바뀌었다(\(entry.names.ko.first ?? "nil") ≠ \(ko))")
            #expect(enDisplay == en, "\(koID)의 1순위 영문 표기가 바뀌었다(\(enDisplay ?? "nil") ≠ \(en))")
        }
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

    /// 회원 탈퇴·계정 전환 와이프 경로 — `resetAll()`이 옛 기본값 "Reffi"를 남기면 안 된다.
    /// 그 값은 `isUnsetNickname`이 **미설정으로 판정하는 값**이라, 남겨두면 탈퇴 직후 세션 내내
    /// 프로필이 "Reffi"(아바타 "R")로 보인다(익명 게스트 구간엔 재배정 훅이 안 돈다).
    @Test func resetAllRegeneratesNicknameInsteadOfLeavingTheDefault() {
        let name = "test.nickname.resetAll"
        let suite = freshSuite(name)
        suite.set("Chef Kevin", forKey: "profile.nickname")
        let store = ProfileStore(defaults: suite)
        #expect(store.nickname == "Chef Kevin")

        store.resetAll()
        #expect(store.nickname != "Reffi", "탈퇴 직후 옛 기본값이 그대로 남았다")
        #expect(!store.nickname.trimmingCharacters(in: .whitespaces).isEmpty)
        #expect(!ProfileStore.isUnsetNickname(store.nickname))   // 미설정 상태로 나가지 않는다
        #expect(store.nickname != "Chef Kevin")                  // 초기화 자체는 됐다
        #expect(suite.string(forKey: "profile.nickname") == store.nickname)   // 영속화까지

        // 재배정 훅(reconcileDataOwner)이 뒤이어 돌아도 이름이 두 번 바뀌지 않는다(가드 멱등).
        let assigned = store.nickname
        store.assignGeneratedNicknameIfUnset()
        #expect(store.nickname == assigned)
        UserDefaults(suiteName: name)?.removePersistentDomain(forName: name)
    }
}
