import Observation
import Foundation

/// 사용자 프로필·선호도(§5) — 앱의 두 번째 소스(FridgeStore와 병렬).
/// 백엔드가 없는 디자인 빌드라 값은 `UserDefaults`에 로컬 영속한다(CardStyle 선례, §영속화).
/// 각 속성의 `didSet`에서 저장 → 바인딩·칩 토글 어디서 바꿔도 자동 유지.
@Observable
final class ProfileStore {
    var nickname: String            { didSet { save() } }
    var cuisines: Set<CuisineStyle> { didSet { save() } }
    var favorites: [String]         { didSet { save() } }   // 좋아하는 재료(§5.2 선호)
    var disliked: [String]          { didSet { save() } }
    var allergies: [String]         { didSet { save() } }
    var household: HouseholdSize    { didSet { save() } }   // 가구 인원 — 레시피 양 근거

    // 알림 설정(토글·시각)의 SSOT는 `ExpiryNotifier`의 @AppStorage 키(enabledKey/hourKey)로 단일화했다.
    // 프로필의 알림 UI는 그 키를 직접 읽고 실제 스케줄(reschedule)에 반영한다 —
    // ProfileStore에 있던 notifyEnabled/leadDays/notifyHour/notifyMinute는 스케줄에 물리지 않던
    // 죽은 플래그라 제거했다(중복 진실 소스 제거).

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var owner: String?
    @ObservationIgnored private var loading = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        owner = defaults.string(forKey: DataOwner.key)
        // 초기화 단계 대입은 didSet을 트리거하지 않음 → 로드 중 불필요한 재저장 없음.
        nickname   = defaults.string(forKey: Key.nickname) ?? "Reffi"
        // 미응답 기본값은 **빈 집합**이다(64차). 예전 기본값 [.korean]은 "화면을 연 적 없음"을
        // "한식을 골랐음"으로 디스크에 굳혀버렸다 — init 말미의 닉네임 배정이 didSet → save()를
        // 때리므로 첫 실행에서 그대로 영속화됐고, 그 결과 시드 128편 중 55편(43%)이 아무도
        // 고르지 않은 +2를 받았다. 빈 집합이면 `RecipePreferences.isEmpty`가 참이라 순수
        // freshness 경로를 탄다(`preferenceScore`의 guard, `prune`의 cuisineMatch 모두 무발화).
        let rawCui = defaults.stringArray(forKey: Key.cuisines) ?? []
        cuisines   = Set(rawCui.compactMap(CuisineStyle.init(rawValue:)))
        favorites  = defaults.stringArray(forKey: Key.favorites) ?? []
        disliked   = defaults.stringArray(forKey: Key.disliked) ?? []
        allergies  = defaults.stringArray(forKey: Key.allergies) ?? []
        household  = HouseholdSize(rawValue: defaults.string(forKey: Key.household) ?? "") ?? .one
        #if DEBUG
        // QA — 자동 닉네임 생성 스크린샷 검증용(-resetOnboarding 선례). 저장된 닉네임이 있어도
        // 이번 런치에서 강제로 미설정 취급해 곧장 새 위트 있는 이름을 보게 한다.
        if ProcessInfo.processInfo.arguments.contains("-resetNickname") { nickname = "" }
        #endif
        // 신규 프로필 최초 시드 — 저장된 닉네임이 없거나(첫 설치) 예전 기본값 "Reffi" 그대로면
        // 위트 있는 이름을 즉시 배정한다. 위 대입들로 모든 저장 프로퍼티가 이미 초기값을 받은
        // 뒤라(2단계 초기화 완료), 이 메서드 호출 내부의 재대입은 일반 호출과 동일하게 didSet →
        // save()가 정상 발동해 곧바로 영속화된다.
        if let data = defaults.data(forKey: accountKey),
           let saved = try? JSONDecoder().decode(Snapshot.self, from: data) { restore(saved) }
        assignGeneratedNicknameIfUnset()
        // 옛 기본값 청소(64차, 1회) — 기본값을 바꾸는 것만으로는 **이미 디스크에 적힌 값**이
        // 지워지지 않는다. 기존 설치는 첫 실행 때 저장된 ["korean"]을 그대로 들고 있어서,
        // 고른 적 없는 취향이 계속 시드 55편(43%)에 +2를 준다. 저장값이 정확히 한 칸 ["korean"]일
        // 때만 비우고, 두 칸 이상이거나 한식을 뺀 사용자, 키 자체가 없는 새 설치는 건드리지 않는다.
        // 플래그는 조건과 무관하게 한 번만 쓴다 — 나중에 사용자가 진짜로 한식만 고르면 그 선택은
        // 다시는 지워지지 않는다. (한 칸 ["korean"]이 "고른 적 없음"과 "한식만 고름" 둘 다일 수
        // 있다는 것은 알려진 비용이다 — 디스크에서 둘은 바이트가 같다. 오너 판정: 편향 제거 우선.)
        if !defaults.bool(forKey: Key.cuisinesDefaultMigrated) {
            if rawCui == [CuisineStyle.korean.rawValue] { cuisines = [] }
            defaults.set(true, forKey: Key.cuisinesDefaultMigrated)
        }
    }

    func toggleCuisine(_ c: CuisineStyle) {
        if cuisines.contains(c) { cuisines.remove(c) } else { cuisines.insert(c) }
    }

    /// 미설정 닉네임에 위트 있는 자동 생성 이름(`NicknameGenerator`)을 배정한다.
    /// 호출부 셋: ① 이 클래스의 `init`(신규 프로필 최초 시드) ② 이 클래스의 `resetAll`(파괴적
    /// 초기화 직후) ③ `ReffiApp.reconcileDataOwner`(가입 완료·다른 계정 전환 재기록 직후) —
    /// 세 지점 모두 "이 로컬 프로필의 닉네임이 방금 미설정 상태로 (재)확정됐을 수 있다"는
    /// 공통점이 있어 같은 가드를 공유한다. 가드가 멱등이라 ②·③이 잇달아 도는 경로
    /// (계정 전환 와이프)에서도 두 번 생성되지 않는다 — ② 뒤엔 이미 미설정이 아니다.
    /// **이미 사용자가 지은 닉네임은 절대 건드리지 않는다** — `isUnsetNickname`이 아니면 즉시 반환.
    func assignGeneratedNicknameIfUnset(locale: Locale = .current) {
        guard Self.isUnsetNickname(nickname) else { return }
        nickname = NicknameGenerator.generate(locale: locale)
    }

    /// "닉네임 미설정" 판정 — 빈 문자열이거나 손대지 않은 오리지널 기본값 "Reffi" 그대로인 경우만.
    /// 사용자가 실제로 "Reffi"라는 이름을 스스로 다시 지은 경우와 구분할 방법은 없지만(둘 다 저장값이
    /// 동일), 그 경우는 값이 사실상 기본값과 같아 자동 생성으로 덮여도 실사용자 피해가 없다.
    static func isUnsetNickname(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty || trimmed == "Reffi"
    }

    /// 회원 탈퇴(§6.5) — 로컬 프로필 데이터 초기화(백엔드 없으므로 기본값 복구).
    /// 마지막 줄이 자동 닉네임을 다시 배정한다: `nickname = "Reffi"`는 `isUnsetNickname`이
    /// **미설정으로 판정하는 값**이라, 그대로 두면 탈퇴 직후 세션 내내 프로필이 옛 기본값
    /// "Reffi"(아바타 이니셜 "R")로 보인다 — 그 자리는 로그아웃 뒤 익명 게스트라
    /// `reconcileDataOwner`의 재배정 훅이 닿지 않고, 다음 콜드 런치의 `init`에서야 고쳐졌다.
    func resetAll() {
        nickname = "Reffi"
        cuisines = []          // 64차 — init과 같은 이유로 [.korean]을 다시 심지 않는다
        favorites = []
        disliked = []
        allergies = []
        household = .one
        assignGeneratedNicknameIfUnset()   // 어느 파괴적 경로로 들어와도 새 이름을 받고 나간다
    }

    struct Snapshot: Codable, Equatable {
        var nickname: String
        var cuisines: Set<CuisineStyle>
        var favorites: [String]
        var disliked: [String]
        var allergies: [String]
        var household: HouseholdSize
    }

    var snapshot: Snapshot {
        Snapshot(nickname: nickname, cuisines: cuisines, favorites: favorites,
                 disliked: disliked, allergies: allergies, household: household)
    }
    private var accountKey: String { "profile.account." + (owner ?? "guest") }

    func switchAccount(to newOwner: String?, inheritGuest: Bool) {
        let previous = snapshot
        save()
        owner = newOwner
        if let data = defaults.data(forKey: accountKey),
           let saved = try? JSONDecoder().decode(Snapshot.self, from: data) {
            restore(saved)
        } else if inheritGuest {
            restore(previous)
        } else {
            resetAll()
        }
        save()
        if inheritGuest && newOwner != nil { defaults.removeObject(forKey: "profile.account.guest") }
    }

    func eraseDeviceData() {
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix("profile.") {
            defaults.removeObject(forKey: key)
        }
        resetAll()
    }

    private func restore(_ value: Snapshot) {
        loading = true
        nickname = value.nickname
        cuisines = value.cuisines
        favorites = value.favorites
        disliked = value.disliked
        allergies = value.allergies
        household = value.household
        loading = false
    }

    private func save() {
        guard !loading else { return }
        if let data = try? JSONEncoder().encode(snapshot) { defaults.set(data, forKey: accountKey) }
        defaults.set(nickname, forKey: Key.nickname)
        defaults.set(cuisines.map(\.rawValue), forKey: Key.cuisines)
        defaults.set(favorites, forKey: Key.favorites)
        defaults.set(disliked, forKey: Key.disliked)
        defaults.set(allergies, forKey: Key.allergies)
        defaults.set(household.rawValue, forKey: Key.household)
    }

    private enum Key {
        static let nickname = "profile.nickname"
        static let cuisines = "profile.cuisines"
        static let favorites = "profile.favorites"
        static let disliked = "profile.disliked"
        static let allergies = "profile.allergies"
        static let household = "profile.household"
        /// 64차 1회 마이그레이션 표식 — 옛 기본값 ["korean"] 청소를 이미 했는지.
        static let cuisinesDefaultMigrated = "profile.cuisinesDefaultMigrated"
    }
}
